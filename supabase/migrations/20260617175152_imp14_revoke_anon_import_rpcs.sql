-- ═══════════════════════════════════════════════════════════════════════════
-- IMP-14 — défense en profondeur : retirer l'EXECUTE gratuit d'anon sur les
-- RPC d'import (public.fn_import_*)
-- ───────────────────────────────────────────────────────────────────────────
-- Session : Audit 360 — correctifs P0
-- Auteur  : AnarBib (assist. Claude)
-- Réf     : Audit 360° 17/06/2026, IMP-14 + §10.1 (balayage REVOKE ciblé).
--
-- CONSTAT
--   Le contrôle de rôle des RPC d'import est DÉJÀ côté serveur (toutes les
--   fn_import_* font painel + coordenador-ou-netadmin + ownership, avec RAISE ;
--   register_oai_source est netadmin-only). L'item IMP-14 « garde purement
--   frontend » était périmé. Reste un résidu : 17 de ces fonctions portent un
--   `GRANT EXECUTE … TO anon` explicite — inutile (un anon est de toute façon
--   bloqué par le garde interne, my_access vide → RAISE) et c'est ce qui
--   déclenche l'advisor `anon_security_definer_function_executable`.
--
-- ACTION
--   REVOKE EXECUTE … FROM PUBLIC, anon sur ces 17 fonctions ; GRANT ré-affirmé
--   pour authenticated + service_role (idempotent). Effet : l'anonyme ne peut
--   plus invoquer (couche supplémentaire), −17 sur le compteur advisor anon.
--   AUCUN impact attendu : pas d'appelant anon légitime (import = staff-only) ;
--   le front appelle en `authenticated`, les Edge Functions en `service_role`.
--   REVOKE ciblé et justifié — PAS un revoke de masse (cf. doctrine advisors
--   SECDEF intentionnels).
--
-- ROLLBACK : bloc commenté en pied de fichier (manuel-only).
-- ═══════════════════════════════════════════════════════════════════════════

REVOKE EXECUTE ON FUNCTION public.fn_import_archive_run(p_run_id bigint, p_archived boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_archive_run(p_run_id bigint, p_archived boolean) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_create(p_source_id bigint, p_storage_path text, p_original_filename text, p_bucket_id text, p_mime_type text, p_size_bytes bigint, p_sha256 text, p_detected_format text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_create(p_source_id bigint, p_storage_path text, p_original_filename text, p_bucket_id text, p_mime_type text, p_size_bytes bigint, p_sha256 text, p_detected_format text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_delete_run(p_run_id bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_delete_run(p_run_id bigint) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_dispatch(p_run_id bigint, p_force_reparse boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_dispatch(p_run_id bigint, p_force_reparse boolean) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_harvest_oai(p_source_id bigint, p_max_lots integer) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_harvest_oai(p_source_id bigint, p_max_lots integer) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_ingest_candidate(p_candidate jsonb, p_source_id bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_ingest_candidate(p_candidate jsonb, p_source_id bigint) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_oai_sources() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_oai_sources() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_run_rows(p_run_id bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_run_rows(p_run_id bigint) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_runs(p_source_id bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_runs(p_source_id bigint) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_sources() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_sources() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_process_deposit(p_source_id bigint, p_storage_path text, p_original_filename text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_process_deposit(p_source_id bigint, p_storage_path text, p_original_filename text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_promote(p_run_id bigint, p_match_statuses text[], p_editorial_decisions text[], p_batch_name text, p_batch_notes text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_promote(p_run_id bigint, p_match_statuses text[], p_editorial_decisions text[], p_batch_name text, p_batch_notes text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_reconcile_duplicates(p_run_id bigint, p_row_ids bigint[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_reconcile_duplicates(p_run_id bigint, p_row_ids bigint[]) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_register_deposit_source(p_partner_name text, p_notes text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_register_deposit_source(p_partner_name text, p_notes text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_register_oai_source(p_partner_name text, p_oai_endpoint_url text, p_library_id uuid, p_oai_metadata_prefix text, p_oai_set text, p_lots_per_cycle integer, p_notes text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_register_oai_source(p_partner_name text, p_oai_endpoint_url text, p_library_id uuid, p_oai_metadata_prefix text, p_oai_set text, p_lots_per_cycle integer, p_notes text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_set_editorial(p_run_id bigint, p_row_ids bigint[], p_editorial_decision text, p_editorial_note text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_set_editorial(p_run_id bigint, p_row_ids bigint[], p_editorial_decision text, p_editorial_note text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_import_set_rows_review(p_run_id bigint, p_row_ids bigint[], p_review_status text, p_selected_for_draft boolean, p_match_status text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_set_rows_review(p_run_id bigint, p_row_ids bigint[], p_review_status text, p_selected_for_draft boolean, p_match_status text) TO authenticated, service_role;

-- ── Vérification (RAISE EXCEPTION = auto-rollback de la migration) ───────────
DO $$
DECLARE
  v_names text[] := ARRAY[
    'fn_import_archive_run','fn_import_create','fn_import_delete_run','fn_import_dispatch',
    'fn_import_harvest_oai','fn_import_ingest_candidate','fn_import_list_oai_sources',
    'fn_import_list_run_rows','fn_import_list_runs','fn_import_list_sources',
    'fn_import_process_deposit','fn_import_promote','fn_import_reconcile_duplicates',
    'fn_import_register_deposit_source','fn_import_register_oai_source',
    'fn_import_set_editorial','fn_import_set_rows_review'
  ];
  v_name text;
  v_anon boolean;
  v_auth boolean;
BEGIN
  FOREACH v_name IN ARRAY v_names LOOP
    SELECT EXISTS (SELECT 1 FROM information_schema.routine_privileges
                   WHERE routine_schema='public' AND routine_name=v_name
                     AND grantee='anon' AND privilege_type='EXECUTE') INTO v_anon;
    SELECT EXISTS (SELECT 1 FROM information_schema.routine_privileges
                   WHERE routine_schema='public' AND routine_name=v_name
                     AND grantee='authenticated' AND privilege_type='EXECUTE') INTO v_auth;
    IF v_anon THEN
      RAISE EXCEPTION 'IMP-14: anon a encore EXECUTE sur public.% (revoke incomplet)', v_name;
    END IF;
    IF NOT v_auth THEN
      RAISE EXCEPTION 'IMP-14: authenticated a perdu EXECUTE sur public.% (sur-revoke)', v_name;
    END IF;
  END LOOP;
  RAISE NOTICE 'IMP-14 OK : anon revoque sur 17 RPC import, authenticated/service_role preserves.';
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ROLLBACK MANUEL — NE PAS exécuter dans le cadre de la migration.
-- Si une régression VISIBLE apparaît (un appelant anon légitime — très
-- improbable, l'import est staff-only), ré-accorder EXECUTE à anon en appliquant
-- les lignes ci-dessous via MCP execute_sql (effet immédiat en prod), puis
-- committer une migration de revert pour réaligner repo↔live.
--
-- GRANT EXECUTE ON FUNCTION public.fn_import_archive_run(p_run_id bigint, p_archived boolean) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_create(p_source_id bigint, p_storage_path text, p_original_filename text, p_bucket_id text, p_mime_type text, p_size_bytes bigint, p_sha256 text, p_detected_format text) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_delete_run(p_run_id bigint) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_dispatch(p_run_id bigint, p_force_reparse boolean) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_harvest_oai(p_source_id bigint, p_max_lots integer) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_ingest_candidate(p_candidate jsonb, p_source_id bigint) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_list_oai_sources() TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_list_run_rows(p_run_id bigint) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_list_runs(p_source_id bigint) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_list_sources() TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_process_deposit(p_source_id bigint, p_storage_path text, p_original_filename text) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_promote(p_run_id bigint, p_match_statuses text[], p_editorial_decisions text[], p_batch_name text, p_batch_notes text) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_reconcile_duplicates(p_run_id bigint, p_row_ids bigint[]) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_register_deposit_source(p_partner_name text, p_notes text) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_register_oai_source(p_partner_name text, p_oai_endpoint_url text, p_library_id uuid, p_oai_metadata_prefix text, p_oai_set text, p_lots_per_cycle integer, p_notes text) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_set_editorial(p_run_id bigint, p_row_ids bigint[], p_editorial_decision text, p_editorial_note text) TO anon;
-- GRANT EXECUTE ON FUNCTION public.fn_import_set_rows_review(p_run_id bigint, p_row_ids bigint[], p_review_status text, p_selected_for_draft boolean, p_match_status text) TO anon;
-- ═══════════════════════════════════════════════════════════════════════════
