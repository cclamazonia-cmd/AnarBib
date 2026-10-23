-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — l'effacement d'un compte traverse les journaux du réseau (23/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- Constat (production, 23/10/2026) : fn_delete_my_account re-pointe vers le
-- jeton pseudonyme l'acteur de network_admin_cross_library_actions_log et les
-- trois colonnes de personne de network_administrator_audit. Les deux tables
-- sont append-only : leurs déclencheurs BEFORE UPDATE lèvent à chaque fois.
-- Dès qu'une ligne nomme la personne — en pratique toute admin du réseau —
-- l'effacement entier est annulé. Celle qui en avait en production figure
-- dans les deux journaux.
--
-- Les deux journaux restent inaltérables. Seul passe le geste de
-- l'effacement, sur le modèle de l'exception de la purge (RET-3) :
--   * un drapeau transactionnel, anarbib.effacement_compte, que seule
--     fn_delete_my_account pose, à l'identifiant de la personne qui s'efface,
--     autour de ces seuls UPDATE, et qu'elle fait retomber aussitôt ;
--   * current_user = propriétaire de fn_delete_my_account, ce qu'aucun rôle
--     d'API ne peut devenir ;
--   * une colonne ne change que si elle nommait cette personne, et seulement
--     vers SON jeton (fn_pseudonymize_token) ; toutes les autres colonnes de la
--     ligne sont identiques. DELETE reste refusé (hors purge, inchangée).
--
-- Corps repris de la définition RÉELLE en production (pg_get_functiondef,
-- 23/10/2026) : fn_delete_my_account (B28 + B34) n'y gagne que la pose et la
-- retombée du drapeau ; tg_cross_lib_log_immutable garde sa branche de purge
-- à l'identique ; tg_network_administrator_audit_immutable n'avait que son
-- RAISE.
--
-- Tests : tests/sql/effacement_journaux_reseau_tests.sql
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Le journal inter-bibliothèques : purge (inchangée) et effacement ───────
CREATE OR REPLACE FUNCTION public.tg_cross_lib_log_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
    -- RET-3 (23/10/2026) : la purge de rétention efface les lignes de plus de
    -- 12 mois. Le drapeau ne suffit pas : il faut aussi être le propriétaire
    -- de fn_purge_retention, ce qu'aucun rôle d'API ne peut devenir.
    IF TG_OP = 'DELETE'
       AND current_setting('anarbib.purge_retention', true) = 'on'
       AND current_user = (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p
                            WHERE p.oid = 'public.fn_purge_retention(boolean)'::regprocedure)
       AND OLD.created_at < now() - interval '12 months' THEN
        RETURN OLD;
    END IF;
    -- Effacement d'un compte (23/10/2026) : fn_delete_my_account re-pointe
    -- l'acteur vers son jeton. Drapeau à l'id de la personne, propriétaire de
    -- la fonction, acteur → exactement son jeton, rien d'autre ne change.
    IF TG_OP = 'UPDATE'
       AND current_setting('anarbib.effacement_compte', true) = OLD.actor_user_id::text
       AND current_user = (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p
                            WHERE p.oid = 'public.fn_delete_my_account()'::regprocedure) THEN
        IF NEW.actor_user_id = public.fn_pseudonymize_token(OLD.actor_user_id)
           AND to_jsonb(NEW) - 'actor_user_id' = to_jsonb(OLD) - 'actor_user_id' THEN
            RETURN NEW;
        END IF;
    END IF;
    RAISE EXCEPTION 'cross_library_log_immutable: network_admin_cross_library_actions_log is append-only, UPDATE and DELETE are forbidden';
END;
$function$;

-- ─── Le journal de l'administration du réseau : effacement seulement ───────
CREATE OR REPLACE FUNCTION public.tg_network_administrator_audit_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_qui   text := current_setting('anarbib.effacement_compte', true);
    v_jeton uuid;
BEGIN
    -- Effacement d'un compte (23/10/2026) : sujet, actrice ou cible passent
    -- au jeton de la personne qui s'efface — chacune seulement si elle la
    -- nommait —, le reste de la ligne est identique. Mêmes gardes que le
    -- journal inter-bibliothèques.
    IF TG_OP = 'UPDATE'
       AND v_qui <> ''
       AND v_qui IN (OLD.user_id::text, OLD.actor_user_id::text, OLD.target_user_id::text)
       AND current_user = (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p
                            WHERE p.oid = 'public.fn_delete_my_account()'::regprocedure) THEN
        v_jeton := public.fn_pseudonymize_token(v_qui::uuid);
        IF (NEW.user_id IS NOT DISTINCT FROM OLD.user_id
              OR (OLD.user_id::text = v_qui AND NEW.user_id = v_jeton))
           AND (NEW.actor_user_id IS NOT DISTINCT FROM OLD.actor_user_id
              OR (OLD.actor_user_id::text = v_qui AND NEW.actor_user_id = v_jeton))
           AND (NEW.target_user_id IS NOT DISTINCT FROM OLD.target_user_id
              OR (OLD.target_user_id::text = v_qui AND NEW.target_user_id = v_jeton))
           AND to_jsonb(NEW) - ARRAY['user_id', 'actor_user_id', 'target_user_id']
             = to_jsonb(OLD) - ARRAY['user_id', 'actor_user_id', 'target_user_id'] THEN
            RETURN NEW;
        END IF;
    END IF;
    RAISE EXCEPTION 'audit_immutable: network_administrator_audit is append-only, UPDATE and DELETE are forbidden';
END;
$function$;

-- ─── fn_delete_my_account : pose et retombée du drapeau ─────────────────────
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

-- Droits inchangés (prod, 23/10/2026 : postgres et authenticated seulement).
REVOKE EXECUTE ON FUNCTION public.fn_delete_my_account() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fn_delete_my_account() TO authenticated;

-- ─── Vérification ──────────────────────────────────────────────────────────
DO $verif$
BEGIN
  IF has_function_privilege('anon', 'public.fn_delete_my_account()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_delete_my_account()', 'EXECUTE') THEN
    RAISE EXCEPTION 'effacement : les droits de fn_delete_my_account ont changé';
  END IF;
  IF (SELECT count(*) FROM pg_trigger
       WHERE NOT tgisinternal AND tgenabled <> 'D'
         AND tgname IN ('trg_cross_lib_log_no_update', 'trg_cross_lib_log_no_delete',
                        'trg_network_administrator_audit_no_update', 'trg_network_administrator_audit_no_delete')) <> 4 THEN
    RAISE EXCEPTION 'effacement : un déclencheur append-only des journaux du réseau manque';
  END IF;
END;
$verif$;

COMMIT;
