-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — l'effacement d'un compte traverse le profil des bibliothèques
-- et les notes de lecture (23/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- Constat (banc, 23/10/2026 ; les trois tables sont vides en production ce
-- jour-là) : elles pointent vers profiles ou auth.users en ON DELETE SET NULL,
-- et leurs déclencheurs refusent l'UPDATE que la suppression du compte y
-- provoque. L'effacement échouait pour une personne qui :
--   * a changé le profil d'une bibliothèque — library_profile_history.changed_by,
--     fn_block_lph_modification refuse tout UPDATE ;
--   * en a proposé ou annulé un changement — library_profile_proposals.proposed_by,
--     NOT NULL (le SET NULL échouerait de toute façon) et verrouillée par
--     fn_block_lpp_modification ; cancelled_by, libre, mais la CHECK
--     d'annulation exige qu'elle reste renseignée quand cancelled_at l'est ;
--   * a écrit une note de lecture — fn_reading_note_before_update remet
--     author_user_id à l'ancienne valeur et la FK refuse ;
--   * en a masqué une — pendant la cascade elle n'est plus de l'équipe, et le
--     même déclencheur lève « modification non autorisee ».
--
-- Même doctrine que pour les journaux du réseau (20261023203225), sous le
-- drapeau anarbib.effacement_compte que seule fn_delete_my_account pose :
--   * les actes de gouvernance du profil ne s'effacent pas, ils passent au
--     jeton pseudonyme ;
--   * les notes de lecture suivent ce que leurs FK prévoient : author_user_id
--     et hidden_by passent à NULL (la note reste, sous le pseudonyme choisi).
--   * fn_delete_my_account fait ces cinq UPDATE dans la fenêtre du drapeau,
--     avant la suppression du profil (le SET NULL ne trouve plus rien).
--   * fn_block_lph_modification : UPDATE admis seulement si drapeau = id de la
--     personne nommée, current_user = propriétaire de fn_delete_my_account,
--     changed_by → exactement son jeton, reste de la ligne identique.
--     DELETE toujours refusé.
--   * fn_block_lpp_modification : le verrou de proposed_by s'ouvre au même
--     geste exact, et à lui seul. Elle passe en SECURITY INVOKER : en DEFINER,
--     current_user y valait toujours son propriétaire et la garde ne prouvait
--     rien. Son corps ne lit que OLD et NEW ; elle n'a besoin d'aucun droit.
--   * fn_reading_note_before_update : en tête, le seul passage à NULL des
--     colonnes qui nomment la personne, reste de la ligne identique. Elle
--     passe aussi en SECURITY INVOKER (même raison) : elle ne lit aucune
--     table, et user_can_act_as_staff_on_library est accordée à authenticated.
--
-- Corps repris de la définition RÉELLE en production (pg_get_functiondef,
-- 23/10/2026). fn_delete_my_account n'y gagne que les cinq UPDATE.
--
-- Garde vivante : tests/sql/effacement_declencheurs_garde_tests.sql — toute
-- table que l'effacement met à jour (directement ou par un SET NULL) et dont
-- un déclencheur BEFORE UPDATE refuse sans connaître le drapeau la fait rougir.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Historique du profil : immuable, sauf le re-pointage de l'effacement ───
CREATE OR REPLACE FUNCTION public.fn_block_lph_modification()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  -- Effacement d'un compte (23/10/2026) : fn_delete_my_account re-pointe
  -- changed_by vers le jeton. Drapeau à l'id de la personne, propriétaire de
  -- la fonction, changed_by → exactement son jeton, rien d'autre ne change.
  IF TG_OP = 'UPDATE'
     AND current_setting('anarbib.effacement_compte', true) = OLD.changed_by::text
     AND current_user = (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p
                          WHERE p.oid = 'public.fn_delete_my_account()'::regprocedure) THEN
    IF NEW.changed_by = public.fn_pseudonymize_token(OLD.changed_by)
       AND to_jsonb(NEW) - 'changed_by' = to_jsonb(OLD) - 'changed_by' THEN
      RETURN NEW;
    END IF;
  END IF;
  RAISE EXCEPTION 'library_profile_history is immutable: % blocked', TG_OP
    USING ERRCODE = '42501', HINT = 'Cette table est un audit immutable. Aucune modification possible.';
  RETURN NULL;
END;
$function$;

-- ─── Propositions : le verrou de proposed_by s'ouvre au seul re-pointage ────
CREATE OR REPLACE FUNCTION public.fn_block_lpp_modification()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_repointe boolean := false;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'LIBRARY_PROFILE_PROPOSALS_IS_IMMUTABLE : suppression interdite (id=%)', OLD.id
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.id              IS DISTINCT FROM OLD.id              THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : id'              USING ERRCODE = 'check_violation'; END IF;
    IF NEW.library_id      IS DISTINCT FROM OLD.library_id      THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : library_id'      USING ERRCODE = 'check_violation'; END IF;
    IF NEW.axis            IS DISTINCT FROM OLD.axis            THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : axis'            USING ERRCODE = 'check_violation'; END IF;
    IF NEW.old_value       IS DISTINCT FROM OLD.old_value       THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : old_value'       USING ERRCODE = 'check_violation'; END IF;
    IF NEW.new_value       IS DISTINCT FROM OLD.new_value       THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : new_value'       USING ERRCODE = 'check_violation'; END IF;
    IF NEW.transition_type IS DISTINCT FROM OLD.transition_type THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : transition_type' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.governance_required IS DISTINCT FROM OLD.governance_required THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : governance_required' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.motivation      IS DISTINCT FROM OLD.motivation      THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : motivation'      USING ERRCODE = 'check_violation'; END IF;
    IF NEW.proposed_by     IS DISTINCT FROM OLD.proposed_by     THEN
      -- Effacement d'un compte (23/10/2026) : seul passe le re-pointage exact
      -- vers le jeton, sous le drapeau, par le propriétaire de fn_delete_my_account.
      IF current_setting('anarbib.effacement_compte', true) = OLD.proposed_by::text
         AND current_user = (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p
                              WHERE p.oid = 'public.fn_delete_my_account()'::regprocedure) THEN
        v_repointe := NEW.proposed_by = public.fn_pseudonymize_token(OLD.proposed_by)
                      AND to_jsonb(NEW) - 'proposed_by' = to_jsonb(OLD) - 'proposed_by';
      END IF;
      IF v_repointe IS NOT TRUE THEN
        RAISE EXCEPTION 'LPP_LOCKED_COLUMN : proposed_by'     USING ERRCODE = 'check_violation';
      END IF;
    END IF;
    IF NEW.proposed_at     IS DISTINCT FROM OLD.proposed_at     THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : proposed_at'     USING ERRCODE = 'check_violation'; END IF;
    IF NEW.expires_at      IS DISTINCT FROM OLD.expires_at      THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : expires_at'      USING ERRCODE = 'check_violation'; END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- ─── Notes de lecture : le SET NULL de l'effacement passe ───────────────────
CREATE OR REPLACE FUNCTION public.fn_reading_note_before_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO 'public'
AS $function$
declare
  v_is_author boolean := (auth.uid() is not null and auth.uid() = old.author_user_id);
  v_is_staff  boolean := public.user_can_act_as_staff_on_library(old.origin_library_id);
  v_qui       text := current_setting('anarbib.effacement_compte', true);
begin
  -- Effacement d'un compte (23/10/2026) : fn_delete_my_account met à NULL
  -- author_user_id et hidden_by qui nomment la personne (le SET NULL de leurs
  -- FK). Drapeau à son id, propriétaire de la fonction, chaque colonne
  -- inchangée ou passée de la personne à NULL, rien d'autre ne change.
  if v_qui <> ''
     and v_qui in (old.author_user_id::text, old.hidden_by::text)
     and current_user = (select pg_get_userbyid(p.proowner) from pg_proc p
                          where p.oid = 'public.fn_delete_my_account()'::regprocedure)
     and (new.author_user_id is not distinct from old.author_user_id
          or (old.author_user_id::text = v_qui and new.author_user_id is null))
     and (new.hidden_by is not distinct from old.hidden_by
          or (old.hidden_by::text = v_qui and new.hidden_by is null))
     and to_jsonb(new) - array['author_user_id', 'hidden_by']
       = to_jsonb(old) - array['author_user_id', 'hidden_by'] then
    return new;
  end if;

  -- champs jamais modifiables par un UPDATE applicatif
  new.id := old.id;
  new.work_id := old.work_id;
  new.origin_library_id := old.origin_library_id;
  new.author_user_id := old.author_user_id;
  new.author_pseudonym := old.author_pseudonym;
  new.created_at := old.created_at;

  if v_is_author then
    -- auteur-rice : edite body/language ; la moderation fige.
    new.status := old.status;
    new.hidden_reason := old.hidden_reason;
    new.hidden_by := old.hidden_by;
    new.hidden_at := old.hidden_at;
    if new.body is distinct from old.body or new.language is distinct from old.language then
      new.edited := true;
    end if;
    new.updated_at := now();
  elsif v_is_staff then
    -- staff de la biblio d'origine : modere le statut ; le contenu fige.
    new.body := old.body;
    new.language := old.language;
    new.edited := old.edited;
    if new.status is distinct from old.status then
      if new.status in ('hidden','removed') then
        new.hidden_by := auth.uid();
        new.hidden_at := now();
      else  -- retour a 'published'
        new.hidden_by := null; new.hidden_at := null; new.hidden_reason := null;
      end if;
    end if;
    new.updated_at := now();
  else
    raise exception 'reading_note: modification non autorisee' using errcode = '42501';
  end if;
  return new;
end;
$function$;

-- ─── fn_delete_my_account : cinq colonnes de plus dans la fenêtre du drapeau ─
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
  IF EXISTS (SELECT 1 FROM pg_proc WHERE prosecdef
               AND oid IN ('public.fn_block_lpp_modification()'::regprocedure,
                           'public.fn_reading_note_before_update()'::regprocedure)) THEN
    RAISE EXCEPTION 'effacement : les déclencheurs qui lisent current_user doivent être SECURITY INVOKER';
  END IF;
  IF (SELECT count(*) FROM pg_trigger
       WHERE NOT tgisinternal AND tgenabled <> 'D'
         AND tgname IN ('trg_lph_block_update', 'trg_lph_block_delete', 'trg_lpp_block_modification',
                        'trg_reading_note_before_update')) <> 4 THEN
    RAISE EXCEPTION 'effacement : un déclencheur du profil des bibliothèques manque';
  END IF;
END;
$verif$;

COMMIT;
