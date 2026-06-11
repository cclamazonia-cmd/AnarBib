-- Migration : archivage doux des runs d'import
-- Auteur  : Claude Opus 4.8
-- Session : Unification partenaire <-> source d'import (archivage doux)
-- Date    : 2026-06-11 (UTC)
--
-- Permet de masquer un run traité de la liste active sans le supprimer (garde
-- l'historique). Colonne archived_at + RPC toggle + fn_import_list_runs renvoie
-- archived_at (le front filtre / propose « afficher archivés »).
-- Coordenador-only, scopé biblio. Complète fn_import_delete_run (suppression dure).

-- ═══════════════════════════════════════════════════════════════
-- 1. Colonne archived_at
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE ingest.partner_catalog_import_runs
  ADD COLUMN IF NOT EXISTS archived_at timestamptz;

-- ═══════════════════════════════════════════════════════════════
-- 2. fn_import_archive_run — bascule archivé / désarchivé
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_import_archive_run(
  p_run_id   bigint,
  p_archived boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth
AS $fn$
DECLARE
  v_actor public.my_access%rowtype;
  v_run   ingest.partner_catalog_import_runs%rowtype;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  IF v_run.library_id IS DISTINCT FROM v_actor.library_id
     AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Run % nao pertence a esta biblioteca', p_run_id;
  END IF;

  UPDATE ingest.partner_catalog_import_runs
     SET archived_at = CASE WHEN p_archived THEN now() ELSE NULL END
   WHERE id = p_run_id;

  RETURN jsonb_build_object('ok', true, 'run_id', p_run_id, 'archived', p_archived);
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_import_archive_run(bigint, boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_archive_run(bigint, boolean) TO authenticated;

COMMENT ON FUNCTION public.fn_import_archive_run(bigint, boolean) IS
  'Archive (ou désarchive) un run d''import (archived_at). Coordenador-only, scopé biblio.';

-- ═══════════════════════════════════════════════════════════════
-- 3. fn_import_list_runs — renvoie désormais archived_at (DROP + CREATE :
--    CREATE OR REPLACE ne peut pas changer le type de retour)
-- ═══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.fn_import_list_runs(bigint);

CREATE FUNCTION public.fn_import_list_runs(p_source_id bigint DEFAULT NULL::bigint)
RETURNS TABLE(
  id bigint, source_id bigint, source_name text, library_id uuid,
  run_status text, detected_format text, original_filename text,
  imported_rows integer, selected_rows integer, created_drafts integer,
  summary jsonb, error_log jsonb,
  created_at timestamptz, started_at timestamptz, finished_at timestamptz,
  archived_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  RETURN QUERY
  SELECT r.id, r.source_id, s.partner_name,
         r.library_id, r.run_status, r.detected_format,
         r.original_filename,
         r.imported_rows, r.selected_rows, r.created_drafts,
         r.summary, r.error_log,
         r.created_at, r.started_at, r.finished_at,
         r.archived_at
  FROM ingest.partner_catalog_import_runs r
  JOIN ingest.partner_catalog_sources s ON s.id = r.source_id
  WHERE r.library_id = v_actor.library_id
    AND (p_source_id IS NULL OR r.source_id = p_source_id)
  ORDER BY r.created_at DESC;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_runs(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_runs(bigint) TO authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 4. Vérification
-- ═══════════════════════════════════════════════════════════════

DO $verif$
BEGIN
  IF to_regprocedure('public.fn_import_archive_run(bigint, boolean)') IS NULL
     OR to_regprocedure('public.fn_import_list_runs(bigint)') IS NULL THEN
    RAISE EXCEPTION 'RPC archive/list absente(s).';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='ingest' AND table_name='partner_catalog_import_runs'
                    AND column_name='archived_at') THEN
    RAISE EXCEPTION 'Colonne archived_at absente.';
  END IF;
  RAISE NOTICE 'Archivage doux OK : archived_at + fn_import_archive_run + list maj.';
END
$verif$;
