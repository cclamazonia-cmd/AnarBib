-- Migration : RPC de suppression d'un run d'import (+ son fichier storage)
-- Auteur  : Claude Opus 4.8
-- Session : Unification partenaire <-> source d'import (suppression de runs)
-- Date    : 2026-06-11 (UTC)
--
-- Permet de supprimer un run d'import (en erreur ou traité) depuis la page
-- Importações. Les 4 tables enfants (import_files, staging_rows, row_to_draft,
-- dispatch_log) sont en ON DELETE CASCADE -> le DELETE du run nettoie tout.
-- Les book_drafts déjà créés RESTENT (seul le lien row_to_draft est supprimé).
-- L'objet storage (sans FK) est supprimé explicitement.
-- Coordenador-only, scopé à la biblio (admin réseau = transverse).

CREATE OR REPLACE FUNCTION public.fn_import_delete_run(p_run_id bigint)
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

  -- Objet storage (pas de FK) : best-effort
  IF v_run.bucket_id IS NOT NULL AND v_run.storage_path IS NOT NULL THEN
    DELETE FROM storage.objects
     WHERE bucket_id = v_run.bucket_id AND name = v_run.storage_path;
  END IF;

  -- Le run -> CASCADE sur import_files / staging_rows / row_to_draft / dispatch_log
  DELETE FROM ingest.partner_catalog_import_runs WHERE id = p_run_id;

  RETURN jsonb_build_object('ok', true, 'deleted_run', p_run_id);
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_import_delete_run(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_delete_run(bigint) TO authenticated;

COMMENT ON FUNCTION public.fn_import_delete_run(bigint) IS
  'Supprime un run d''import + son fichier storage (CASCADE sur les enfants). '
  'Les book_drafts déjà créés restent. Coordenador-only, scopé biblio.';

DO $verif$
BEGIN
  IF to_regprocedure('public.fn_import_delete_run(bigint)') IS NULL THEN
    RAISE EXCEPTION 'fn_import_delete_run absente.';
  END IF;
  RAISE NOTICE 'fn_import_delete_run OK.';
END
$verif$;
