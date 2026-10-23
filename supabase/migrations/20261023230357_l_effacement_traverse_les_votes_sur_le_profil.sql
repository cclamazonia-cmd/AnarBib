-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — l'effacement d'un compte traverse les votes sur le profil des
-- bibliothèques (24/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- Constat (banc, 24/10/2026 ; table vide en production ce jour-là) : la garde
-- des déclencheurs de refus, étendue aux suppressions en cascade, trouve
-- library_profile_votes. Sa FK voter_id → profiles est en ON DELETE CASCADE,
-- mais fn_block_lpv_modification refuse tout DELETE (et tout UPDATE) : une
-- personne qui a voté sur un changement de profil ne pouvait pas effacer son
-- compte.
--
-- Décision de Xavier (24/10/2026) : le vote reste, attribué au jeton
-- pseudonyme, comme les votes de l'administration du réseau (BG2-14). Le
-- décompte d'une proposition ne change pas après coup, le registre reste
-- inaltérable.
--   * fn_delete_my_account re-pointe voter_id vers le jeton dans la fenêtre du
--     drapeau anarbib.effacement_compte, avant la suppression du profil (la
--     cascade ne trouve plus rien).
--   * fn_block_lpv_modification : UPDATE admis seulement si drapeau = id de la
--     personne, current_user = propriétaire de fn_delete_my_account, voter_id
--     → exactement son jeton, reste de la ligne identique. DELETE toujours
--     refusé. Elle passe en SECURITY INVOKER : en DEFINER, current_user y
--     valait toujours son propriétaire. Son corps ne lit que OLD et NEW.
--
-- Corps repris de la définition RÉELLE en production (pg_get_functiondef,
-- 24/10/2026). fn_delete_my_account n'y gagne que l'UPDATE des votes.
--
-- Garde : tests/sql/effacement_declencheurs_garde_tests.sql (étendue aux
-- DELETE en cascade, aux déclencheurs AFTER et aux FK bloquantes vers une
-- table supprimée en cascade).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Votes : immuables, sauf le re-pointage de l'effacement ────────────────
CREATE OR REPLACE FUNCTION public.fn_block_lpv_modification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'LIBRARY_PROFILE_VOTES_IS_IMMUTABLE : suppression interdite (id=%)', OLD.id
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Effacement d'un compte (24/10/2026) : fn_delete_my_account re-pointe
    -- voter_id vers le jeton. Drapeau à l'id de la personne, propriétaire de
    -- la fonction, voter_id → exactement son jeton, rien d'autre ne change.
    IF current_setting('anarbib.effacement_compte', true) = OLD.voter_id::text
       AND current_user = (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p
                            WHERE p.oid = 'public.fn_delete_my_account()'::regprocedure) THEN
      IF NEW.voter_id = public.fn_pseudonymize_token(OLD.voter_id)
         AND to_jsonb(NEW) - 'voter_id' = to_jsonb(OLD) - 'voter_id' THEN
        RETURN NEW;
      END IF;
    END IF;
    RAISE EXCEPTION 'LIBRARY_PROFILE_VOTES_IS_IMMUTABLE : modification interdite (id=%)', OLD.id
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$function$;

-- ─── fn_delete_my_account : les votes dans la fenêtre du drapeau ────────────
CREATE OR REPLACE FUNCTION public.fn_delete_my_account()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id  uuid := auth.uid();
  v_removido constant uuid := '00000000-0000-0000-0000-000000000001';
  v_open_loans int;
  v_cancelled  int := 0;
  v_anon_res   int := 0;
  v_anon_loans int := 0;
  v_token      uuid;
  v_gov_rows   int := 0;
  v_act_rows   int := 0;
  v_n          int;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Nenhum usuário autenticado.');
  END IF;
  IF v_user_id = v_removido THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Conta técnica não pode ser excluída.');
  END IF;
  SELECT count(*) INTO v_open_loans
  FROM emprestimos_v2 e
  JOIN emprestimo_itens_v2 ei ON ei.emprestimo_id = e.id
  WHERE e.user_id = v_user_id AND ei.item_status = 'aberto';
  IF v_open_loans > 0 THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'Você tem ' || v_open_loans || ' empréstimo(s) em aberto. Devolva todos os itens antes de excluir sua conta.',
      'open_loans', v_open_loans
    );
  END IF;

  -- ==== CIRCULATION -> removido (EXISTANT, inchangé) ====
  UPDATE reserva_linhas_v2 l
     SET item_status = 'cancelada_biblioteca', cancelled_at = now()
    FROM reservas_v2 r
   WHERE l.reserva_id = r.id AND r.user_id = v_user_id AND l.item_status = 'ativa';
  GET DIAGNOSTICS v_cancelled = ROW_COUNT;
  UPDATE reservas_v2 SET status_global = 'encerrada'
   WHERE user_id = v_user_id AND status_global <> 'encerrada';
  UPDATE reservas_v2  SET user_id = v_removido WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_anon_res = ROW_COUNT;
  UPDATE emprestimos_v2 SET user_id = v_removido WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_anon_loans = ROW_COUNT;
  UPDATE reader_library_messages SET sender_id    = v_removido WHERE sender_id    = v_user_id;
  UPDATE reader_library_messages SET recipient_id = v_removido WHERE recipient_id = v_user_id;
  UPDATE entraide_help_offers    SET helper_user_id = v_removido WHERE helper_user_id = v_user_id;
  UPDATE entraide_help_requests  SET author_user_id = v_removido WHERE author_user_id = v_user_id;
  UPDATE emprestimo_itens_v2      SET return_scheduled_by = NULL WHERE return_scheduled_by = v_user_id;
  UPDATE reserva_item_workflow_v2 SET updated_by = NULL WHERE updated_by = v_user_id;

  -- ==== GOUVERNANCE -> jeton stable (NOUVEAU, BG2-14) ====
  v_token := public.fn_pseudonymize_token(v_user_id);

  -- CORRECTIF FK/PK (20260702) : materialiser le jeton comme COMPTE PSEUDONYME
  -- distinct AVANT les UPDATE, sinon les FK (17 -> auth.users, 2 -> profiles) et
  -- les PK (user_id ; proposal_id,voter_user_id) sont violees. Autonome : on cree
  -- auth.users ET profiles explicitement (independant du trigger, absent en CI).
  -- Aucune PII : id = jeton HMAC irreversible, email derive, meta neutres.
  INSERT INTO auth.users (id, email, role, aud, raw_app_meta_data, raw_user_meta_data)
  VALUES (v_token,
          v_token::text || '@pseudonimizado.anarbib.local',
          'authenticated', 'authenticated',
          '{"provider":"pseudonymized","providers":["pseudonymized"]}'::jsonb,
          '{"first_name":"Membro","last_name":"pseudonimizado"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO profiles (id) VALUES (v_token)
  ON CONFLICT (id) DO NOTHING;

  UPDATE network_admin_collective_removal_proposals SET proposed_user_id = v_token WHERE proposed_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_admin_collective_removal_proposals SET proposed_by = v_token WHERE proposed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_admin_collective_removal_proposals SET cancelled_by = v_token WHERE cancelled_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_admin_collective_removal_votes SET voter_user_id = v_token WHERE voter_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  -- Les deux journaux append-only (23/10/2026) : leurs déclencheurs ne laissent
  -- passer ce re-pointage que sous ce drapeau, posé à l'id de la personne.
  PERFORM set_config('anarbib.effacement_compte', v_user_id::text, true);
  UPDATE network_admin_cross_library_actions_log SET actor_user_id = v_token WHERE actor_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_audit SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_audit SET actor_user_id = v_token WHERE actor_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_audit SET target_user_id = v_token WHERE target_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  -- Profil des bibliothèques (23/10/2026) : SET NULL bloqué par leurs
  -- déclencheurs (et proposed_by est NOT NULL) ; re-pointés avant la suppression.
  UPDATE library_profile_history SET changed_by = v_token WHERE changed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE library_profile_proposals SET proposed_by = v_token WHERE proposed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE library_profile_proposals SET cancelled_by = v_token WHERE cancelled_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  -- Votes sur le profil (24/10/2026) : leur FK les supprimerait en cascade,
  -- leur déclencheur l'interdit ; ils passent au jeton, le décompte ne bouge pas.
  UPDATE library_profile_votes SET voter_id = v_token WHERE voter_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  -- Notes de lecture (23/10/2026) : le SET NULL que prévoient leurs FK, fait
  -- ici sous le drapeau ; leur déclencheur le refusait pendant la cascade.
  UPDATE book_reading_notes SET author_user_id = NULL WHERE author_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE book_reading_notes SET hidden_by = NULL WHERE hidden_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  PERFORM set_config('anarbib.effacement_compte', '', true);
  UPDATE network_administrator_cooptation_proposals SET proposed_user_id = v_token WHERE proposed_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_cooptation_proposals SET proposed_by = v_token WHERE proposed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrator_cooptation_votes SET voter_user_id = v_token WHERE voter_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_administrators SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_contributors SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_contributors SET sponsored_by = v_token WHERE sponsored_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_reviewers SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_reviewers SET added_by_user_id = v_token WHERE added_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_staff SET user_id = v_token WHERE user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_staff SET added_by_user_id = v_token WHERE added_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;
  UPDATE network_staff SET updated_by_user_id = v_token WHERE updated_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_gov_rows := v_gov_rows + v_n;

  UPDATE network_contributors SET display_name = v_token::text WHERE user_id = v_token;

  -- ==== ACTES NOMMÉS -> jeton (B28, 22/09/2026) ====
  -- Les 26 colonnes en NO ACTION / RESTRICT vers profiles ou auth.users que
  -- rien ne re-pointait. Un acte ne s'efface pas : il change d'auteur. La
  -- garde effacement_compte_fk_tests.sql relit pg_constraint et exige que
  -- toute colonne de ce type soit citée ici.
  UPDATE authority_proposals SET proposed_by = v_token WHERE proposed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE authority_proposal_objections SET objecting_by = v_token WHERE objecting_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE cartography_entries SET updated_by = v_token WHERE updated_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE cartography_submissions SET reviewed_by = v_token WHERE reviewed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE gazette_issue_locales SET updated_by = v_token WHERE updated_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE gazette_submissions SET reviewed_by = v_token WHERE reviewed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE lettre_issues SET created_by = v_token WHERE created_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE lettre_issues SET sent_by = v_token WHERE sent_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_opening_hours SET updated_by = v_token WHERE updated_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_public_contact SET updated_by = v_token WHERE updated_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_request_claims SET revoked_by_user_id = v_token WHERE revoked_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_request_comments SET author_admin_id = v_token WHERE author_admin_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_request_invitations SET initiated_by = v_token WHERE initiated_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_request_messages SET author_id = v_token WHERE author_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_requests SET proposed_by_admin_id = v_token WHERE proposed_by_admin_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_requests SET submitted_by_user_id = v_token WHERE submitted_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_retention_policies SET updated_by = v_token WHERE updated_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_team_invitation_ratifications SET ratifier_user_id = v_token WHERE ratifier_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_team_invitations SET proposed_by = v_token WHERE proposed_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE library_unarchive_log SET unarchived_by = v_token WHERE unarchived_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  -- B34 (27/09/2026) : le journal du catalogue — son acteur, et les comptes
  -- que nomment ses instantanés de brouillon (created_by, updated_by).
  UPDATE catalog_audit_log SET actor_id = v_token WHERE actor_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE catalog_audit_log SET details = jsonb_set(details, '{snapshot,created_by}', to_jsonb(v_token::text))
   WHERE details->'snapshot'->>'created_by' = v_user_id::text;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE catalog_audit_log SET details = jsonb_set(details, '{snapshot,updated_by}', to_jsonb(v_token::text))
   WHERE details->'snapshot'->>'updated_by' = v_user_id::text;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE publishers SET created_by = v_token WHERE created_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE publishers SET updated_by = v_token WHERE updated_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE reader_library_messages SET deleted_by = v_token WHERE deleted_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE reader_library_messages SET staff_archived_by = v_token WHERE staff_archived_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE user_library_memberships SET pending_removal_requested_by = v_token WHERE pending_removal_requested_by = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;
  UPDATE user_library_memberships SET physically_validated_by_user_id = v_token WHERE physically_validated_by_user_id = v_user_id;
  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;

  INSERT INTO erasure_log (pseudonym_token, erased_at) VALUES (v_token, now())
  ON CONFLICT (pseudonym_token) DO NOTHING;

  DELETE FROM reader_card_tokens WHERE user_id = v_user_id;
  DELETE FROM profiles WHERE id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'ok', true,
    'cancelled_reservations', v_cancelled,
    'anonymized_reservations', v_anon_res,
    'anonymized_loans', v_anon_loans,
    'pseudonymized_governance_rows', v_gov_rows,
    'pseudonymized_act_rows', v_act_rows,
    'message', 'Conta excluída. Histórico de circulação anonimizado, atos de governança pseudonimizados.'
  );
END;
$function$;

-- Droits inchangés (prod, 24/10/2026 : postgres et authenticated seulement).
REVOKE EXECUTE ON FUNCTION public.fn_delete_my_account() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fn_delete_my_account() TO authenticated;

-- ─── Vérification ──────────────────────────────────────────────────────────
DO $verif$
BEGIN
  IF has_function_privilege('anon', 'public.fn_delete_my_account()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_delete_my_account()', 'EXECUTE') THEN
    RAISE EXCEPTION 'effacement : les droits de fn_delete_my_account ont changé';
  END IF;
  IF (SELECT prosecdef FROM pg_proc WHERE oid = 'public.fn_block_lpv_modification()'::regprocedure) THEN
    RAISE EXCEPTION 'effacement : fn_block_lpv_modification doit être SECURITY INVOKER (sa garde lit current_user)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE NOT tgisinternal AND tgenabled <> 'D'
                  AND tgname = 'trg_lpv_block_modification') THEN
    RAISE EXCEPTION 'effacement : le déclencheur des votes sur le profil manque';
  END IF;
END;
$verif$;

COMMIT;
