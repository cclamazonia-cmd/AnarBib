-- =========================================================================
-- B31 — une relation accordée se lit sans erreur
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B31 (constat de B10, élargi par recensement le jour même)
--
-- LE CONSTAT. B10 avait vu trois tables qui, lues par `anon`, levaient une
-- erreur au lieu de rendre zéro ligne. Le recensement du 27/09 — toute relation
-- de `public` et `api` accordée en lecture, lue sous le rôle — en trouve 13
-- pour `anon` et 10 pour un compte connecté sans adhésion : un droit de lecture
-- qui ne donne qu'un 42501. Aucun écran n'en souffre (l'impression d'étiquettes
-- passe par la RPC get_exemplar_labels, la page d'import par ses RPC, les pages
-- publiques n'appellent my_library_context qu'une fois connecté), mais le droit
-- ment : un client de l'API reçoit une erreur là où la doctrine promet une
-- liste vide ou un refus net.
--
-- LA RÈGLE. Une table protégée par RLS reste lisible et rend zéro ligne à qui
-- n'a rien à y voir ; une vue qu'un rôle ne peut pas lire ne lui est pas
-- accordée.
--   * Tables (4). La lecture anonyme des règles de circulation (deux policies
--     TO anon qui appelaient fn_library_has_full_sigb, fermée à anon depuis le
--     socle du 10/05) disparaît : aucun écran anonyme ne les lit (BibliotecaPage
--     est derrière ProtectedRoute, la page publique d'une bibliothèque ne les
--     lit pas). library_deposit_rules et painel_task_suggestion_catalog passent
--     de TO public à TO authenticated : elles lisaient user_library_memberships,
--     que anon ne lit pas. Pour authenticated, rien ne change.
--   * Vues (9 pour anon, 10 pour authenticated). Le droit est retiré. Elles
--     échouaient déjà : rien de ce qui marchait ne passe par elles — les vues
--     qui les lisent sont fermées dans le même geste ou jamais accordées, et
--     les fonctions DEFINER qui les lisent tournent sous leur propriétaire.
--     Les ACL relues avant d'écrire : droits directs, aucun héritage de PUBLIC.
--
-- Garde de sortie : sous anon, puis sous un compte connecté sans adhésion,
-- chacune des relations touchées se lit sans erreur ou n'est plus accordée.
-- L'invariant, pour toute relation, est tenu par
-- tests/sql/lecture_accordee_sans_erreur_tests.sql.
-- =========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Tables : zéro ligne au lieu d'une erreur
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS library_circulation_policy_sets_public_read ON public.library_circulation_policy_sets;
DROP POLICY IF EXISTS library_circulation_policy_rules_public_read ON public.library_circulation_policy_rules;
ALTER POLICY library_deposit_rules_select ON public.library_deposit_rules TO authenticated;
ALTER POLICY painel_task_suggestion_catalog_select_staff ON public.painel_task_suggestion_catalog TO authenticated;

-- ---------------------------------------------------------------------------
-- Vues : le droit retiré là où il ne donnait qu'une erreur
-- ---------------------------------------------------------------------------
-- Pour anon seulement (un compte connecté les lit).
REVOKE ALL ON api.library_partnerships_ui, api.my_library_context, api.my_profile, api.peb_history_v1 FROM anon;
REVOKE ALL ON public.v_library_notification_context, public.v_membership_overview_panel FROM anon;
-- Pour anon et authenticated : resolve_library_holding_bridge n'est exécutable
-- par aucun des deux (l'impression passe par get_exemplar_labels, DEFINER).
REVOKE ALL ON public.v_catalog_queue, public.v_exemplar_drafts_resolved, public.v_exemplar_labels FROM anon, authenticated;
-- Vues d'import : les tables d'ingest sont fermées aux rôles applicatifs (B1).
REVOKE ALL ON api.partner_catalog_import_rows_match_ui, api.partner_catalog_import_rows_ui,
              api.partner_catalog_import_rows_workflow_ui, api.partner_catalog_import_run_bulk_summary_ui,
              api.partner_catalog_import_run_policy_ui, api.partner_catalog_import_runs_ui,
              api.partner_catalog_sources_ui
  FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- Garde de sortie
-- ---------------------------------------------------------------------------
DO $sortie$
DECLARE
  r record; v_n int; v_pb text := '';
BEGIN
  FOR r IN
    SELECT role, rel FROM (VALUES ('anon'), ('authenticated')) x(role)
    CROSS JOIN unnest(ARRAY[
      'public.library_circulation_policy_sets', 'public.library_circulation_policy_rules',
      'public.library_deposit_rules', 'public.painel_task_suggestion_catalog',
      'api.library_partnerships_ui', 'api.my_library_context', 'api.my_profile', 'api.peb_history_v1',
      'public.v_library_notification_context', 'public.v_membership_overview_panel',
      'public.v_catalog_queue', 'public.v_exemplar_drafts_resolved', 'public.v_exemplar_labels',
      'api.partner_catalog_import_rows_match_ui', 'api.partner_catalog_import_rows_ui',
      'api.partner_catalog_import_rows_workflow_ui', 'api.partner_catalog_import_run_bulk_summary_ui',
      'api.partner_catalog_import_run_policy_ui', 'api.partner_catalog_import_runs_ui',
      'api.partner_catalog_sources_ui']) rel
  LOOP
    CONTINUE WHEN NOT has_table_privilege(r.role, r.rel, 'SELECT');
    BEGIN
      IF r.role = 'anon' THEN
        PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
      ELSE
        PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000b031","role":"authenticated"}', true);
      END IF;
      EXECUTE format('SET LOCAL ROLE %I', r.role);
      EXECUTE format('SELECT count(*) FROM %s', r.rel) INTO v_n;
      RESET ROLE;
    EXCEPTION WHEN OTHERS THEN
      RESET ROLE;
      v_pb := v_pb || r.role || ' ' || r.rel || ' (' || SQLSTATE || ') ; ';
    END;
  END LOOP;
  IF v_pb <> '' THEN
    RAISE EXCEPTION 'B31 : lectures accordées encore en erreur : %', v_pb;
  END IF;
END
$sortie$;

COMMIT;
