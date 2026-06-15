-- =========================================================================
-- Chantier « gestion des fichiers numériques », point 3 — auto-suggestion du livre cible.
--
-- À l'attache d'un fonds reçu, le coordenador devait chercher le livre à la main. Or la
-- traçabilité existe : received_asset.staging_row_id → partner_catalog_staging_rows.
-- created_book_draft_id → book_drafts.published_book_id → public.books. On expose donc le
-- livre PUBLIÉ tracé (s'il est détenu par la biblio) comme SUGGESTION pré-remplie ; la
-- recherche manuelle reste le repli (chaîne nulle tant que le draft n'est pas publié, ou
-- notice rapprochée d'un livre existant sans draft).
--
-- DROP + CREATE (la signature RETURNS TABLE change : +suggested_book_id/title).
-- =========================================================================
BEGIN;

DROP FUNCTION IF EXISTS public.fn_list_received_assets_to_attach(uuid);

CREATE FUNCTION public.fn_list_received_assets_to_attach(p_library_id uuid)
RETURNS TABLE (
  received_asset_id     bigint,
  run_id                bigint,
  title                 text,
  asset_kind            text,
  mime_type             text,
  source_name           text,
  file_size_bytes       bigint,
  suggested_book_id     bigint,
  suggested_book_title  text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth, pg_catalog
AS $$
BEGIN
  IF p_library_id IS NULL THEN RAISE EXCEPTION 'library_id obrigatorio.'; END IF;
  IF NOT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.'; END IF;

  RETURN QUERY
    SELECT ra.id, ra.run_id, ra.title, ra.asset_kind, ra.mime_type, ra.source_name, ra.file_size_bytes,
           b.id, b.titulo
      FROM ingest.partner_catalog_received_assets ra
      JOIN ingest.partner_catalog_import_runs run ON run.id = ra.run_id
      LEFT JOIN ingest.partner_catalog_staging_rows sr ON sr.id = ra.staging_row_id
      LEFT JOIN public.book_drafts bd ON bd.id = sr.created_book_draft_id
      LEFT JOIN public.books b ON b.id = bd.published_book_id
        AND EXISTS (SELECT 1 FROM public.book_holdings h
                     WHERE h.book_id = b.id AND h.library_id = p_library_id)
     WHERE run.library_id = p_library_id
       AND ra.deposit_status = 'deposited'
       AND ra.attached_digital_asset_id IS NULL
     ORDER BY ra.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_list_received_assets_to_attach(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_list_received_assets_to_attach(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_list_received_assets_to_attach(uuid) IS
  'Chantier fichiers numériques (b, MàJ point 3). Fichiers de fonds reçus non encore attachés, '
  'avec le livre PUBLIÉ tracé (received→staging→draft→published_book, s''il est détenu par la biblio) '
  'comme suggestion d''attache. Reservé coordenador / admin réseau.';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_cols int;
BEGIN
  SELECT count(*) INTO v_cols FROM information_schema.routines r
    JOIN information_schema.parameters p ON p.specific_name = r.specific_name
   WHERE r.routine_schema='public' AND r.routine_name='fn_list_received_assets_to_attach'
     AND p.parameter_name IN ('suggested_book_id','suggested_book_title');
  IF v_cols <> 2 THEN RAISE EXCEPTION 'verify (pt3): colonnes suggested_* manquantes (%).', v_cols; END IF;
  RAISE NOTICE 'point 3 OK : auto-suggestion du livre cible.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_list_received_assets_to_attach(uuid);
--   -- + restaurer la version 20260614220000 (sans suggested_*).
-- =========================================================================
