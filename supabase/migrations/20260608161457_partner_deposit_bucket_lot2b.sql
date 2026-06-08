-- Migration : bucket partner-catalog-deposits + source partner_deposit
-- Auteur  : Claude Opus 4.6
-- Session : Lot 2 – Fontes externas bout-en-bout (format maison)
-- Date    : 2026-06-08
--
-- Crée le bucket de dépôt pour le circuit « format maison » :
-- une bibliothèque partenaire exporte son catalogue sous forme de
-- fichier (CSV, JSON, RIS, BibTeX…) et le dépose dans un bucket
-- dédié. Le staff de la bibliothèque cible déclenche l'import
-- via fn_import_create + fn_import_dispatch (pipeline existant).

-- ═══════════════════════════════════════════════════════════════
-- 1. BUCKET : partner-catalog-deposits
-- ═══════════════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'partner-catalog-deposits',
  'partner-catalog-deposits',
  false,
  52428800,  -- 50 MB
  ARRAY[
    'text/csv',
    'text/tab-separated-values',
    'text/plain',
    'application/json',
    'application/xml',
    'text/xml',
    'application/marc',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.oasis.opendocument.spreadsheet',
    'application/zip',
    'application/pdf',
    'application/octet-stream'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- 2. STORAGE POLICIES
-- ═══════════════════════════════════════════════════════════════
-- Convention de chemin : <library_id>/<source_id>/<filename>
-- Seul le staff avec can_access_painel peut lire/écrire dans
-- le dossier de sa bibliothèque.

CREATE POLICY "partner_deposit_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'partner-catalog-deposits'
    AND EXISTS (
      SELECT 1 FROM api.my_access ma
      WHERE ma.can_access_painel = true
        AND (storage.foldername(name))[1] = ma.library_id::text
    )
  );

CREATE POLICY "partner_deposit_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'partner-catalog-deposits'
    AND EXISTS (
      SELECT 1 FROM api.my_access ma
      WHERE ma.can_access_painel = true
        AND (storage.foldername(name))[1] = ma.library_id::text
    )
  );

CREATE POLICY "partner_deposit_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'partner-catalog-deposits'
    AND EXISTS (
      SELECT 1 FROM api.my_access ma
      WHERE ma.can_access_painel = true
        AND (storage.foldername(name))[1] = ma.library_id::text
    )
  );

-- ═══════════════════════════════════════════════════════════════
-- 3. RPC : fn_import_register_deposit_source
-- ═══════════════════════════════════════════════════════════════
-- Enregistre (ou retrouve) une source de type partner_deposit
-- pour la bibliothèque active de l'acteur.

CREATE OR REPLACE FUNCTION public.fn_import_register_deposit_source(
  p_partner_name text,
  p_notes        text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor     public.my_access%rowtype;
  v_source_id bigint;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  -- Cherche une source existante avec le même nom et kind
  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id  = v_actor.library_id
     AND source_kind = 'partner_deposit'
     AND partner_name = p_partner_name
   LIMIT 1;

  IF v_source_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true, 'source_id', v_source_id, 'created', false
    );
  END IF;

  INSERT INTO ingest.partner_catalog_sources
    (partner_name, library_id, relation_status, source_kind,
     import_enabled, notes)
  VALUES
    (p_partner_name, v_actor.library_id, 'active', 'partner_deposit',
     true, p_notes)
  RETURNING id INTO v_source_id;

  RETURN jsonb_build_object(
    'ok', true, 'source_id', v_source_id, 'created', true
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_register_deposit_source(text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_register_deposit_source(text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_import_register_deposit_source IS
  'Lot 2b — Enregistre une source de type partner_deposit pour la bibliothèque active. '
  'Idempotent : retourne la source existante si le nom correspond.';

-- ═══════════════════════════════════════════════════════════════
-- 4. RPC : fn_import_process_deposit
-- ═══════════════════════════════════════════════════════════════
-- Raccourci : crée un run + lance le dispatch pour un fichier
-- déposé dans le bucket partner-catalog-deposits.
-- Combine fn_import_create + fn_import_dispatch en un geste.

CREATE OR REPLACE FUNCTION public.fn_import_process_deposit(
  p_source_id         bigint,
  p_storage_path      text,
  p_original_filename text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor      public.my_access%rowtype;
  v_src_lib_id uuid;
  v_run_id     bigint;
  v_filename   text;
  v_format     text;
BEGIN
  -- 1. Contrôle d'accès
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  -- 2. Vérifier que la source appartient à la biblio
  SELECT library_id INTO v_src_lib_id
    FROM ingest.partner_catalog_sources
   WHERE id = p_source_id;
  IF v_src_lib_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Source % nao pertence a esta biblioteca', p_source_id;
  END IF;

  -- 3. Déduire le nom de fichier et le format
  v_filename := coalesce(p_original_filename,
    reverse(split_part(reverse(p_storage_path), '/', 1)));
  v_format := CASE
    WHEN v_filename ~* '\.csv$'  THEN 'csv'
    WHEN v_filename ~* '\.tsv$'  THEN 'tsv'
    WHEN v_filename ~* '\.ris$'  THEN 'ris'
    WHEN v_filename ~* '\.(bib|bibtex)$' THEN 'bibtex'
    WHEN v_filename ~* '\.(mrc|marc)$'   THEN 'marc21'
    WHEN v_filename ~* '\.json$' THEN 'json'
    WHEN v_filename ~* '\.xml$'  THEN 'xml'
    ELSE 'unknown'
  END;

  -- 4. Créer le run (délègue à ingest.fn_create_partner_catalog_import)
  v_run_id := ingest.fn_create_partner_catalog_import(
    p_source_id        := p_source_id,
    p_storage_path     := p_storage_path,
    p_original_filename := v_filename,
    p_bucket_id        := 'partner-catalog-deposits',
    p_detected_format  := v_format,
    p_requested_by     := v_actor.user_id
  );

  -- 5. Estampiller library_id si absent
  UPDATE ingest.partner_catalog_import_runs
     SET library_id = v_actor.library_id
   WHERE id = v_run_id AND library_id IS NULL;

  -- 6. Lancer le dispatch (parse → staging)
  PERFORM ingest.fn_dispatch_partner_catalog_import(v_run_id);

  RETURN jsonb_build_object(
    'ok',       true,
    'run_id',   v_run_id,
    'filename', v_filename,
    'format',   v_format
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_process_deposit(bigint, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_process_deposit(bigint, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_import_process_deposit IS
  'Lot 2b — Traite un fichier déposé par un partenaire : crée un run + lance le dispatch en un geste. '
  'Le fichier doit être dans le bucket partner-catalog-deposits.';
