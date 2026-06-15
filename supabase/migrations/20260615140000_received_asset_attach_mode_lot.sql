-- =========================================================================
-- Chantier « gestion des fichiers numériques », point 6 — sélecteur de destination.
--
-- Constat (smoke-test 14/06) : l'attache ne créait qu'un `digital_asset` (couche
-- export/partage). Or le LECTEUR lit `book_digital_resources` (couche catalogue) →
-- un fonds reçu attaché n'était PAS lisible localement. Décision Xavier : le
-- catalogueur CHOISIT la destination à l'attache (par défaut « les deux ») :
--   - export / partage  → digital_asset (to_review, bucket restreint) [point 1].
--   - lisible local      → book_digital_resources (MÊME fichier restreint,
--                          access_scope=conta_ativa : lisible par les membres actifs ;
--                          pas de déplacement). Géré ensuite comme tout fichier catalogué.
--   - les deux           → les deux.
--
-- fn_attach_received_asset_record gagne un paramètre p_mode (DROP+CREATE : +1 arg).
-- =========================================================================
BEGIN;

DROP FUNCTION IF EXISTS public.fn_attach_received_asset_record(bigint, bigint, text, text);

CREATE FUNCTION public.fn_attach_received_asset_record(
  p_received_asset_id bigint, p_book_id bigint, p_bucket_name text, p_object_path text,
  p_mode text DEFAULT 'both'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth, pg_catalog
AS $$
DECLARE
  ra ingest.partner_catalog_received_assets%rowtype;
  v_authorized boolean;
  v_kind text;
  v_title text;
  v_asset_id bigint;
  v_resource_id bigint;
  v_rtype text;
  v_utype text;
BEGIN
  IF p_received_asset_id IS NULL OR p_book_id IS NULL THEN RAISE EXCEPTION 'received_asset_id e book_id obrigatorios.'; END IF;
  IF p_mode NOT IN ('export','read','both') THEN RAISE EXCEPTION 'mode inválido (%).', p_mode; END IF;
  IF p_bucket_name NOT IN ('pdf-restrito','anarbib-media-restricted') THEN RAISE EXCEPTION 'Bucket destino inválido (%).', p_bucket_name; END IF;
  IF p_object_path IS NULL OR p_object_path LIKE 'http%' THEN RAISE EXCEPTION 'Caminho de destino inválido.'; END IF;

  SELECT * INTO ra FROM ingest.partner_catalog_received_assets WHERE id = p_received_asset_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recurso recebido % introuvável.', p_received_asset_id; END IF;
  -- Idempotence : déjà attaché (asset OU lecture-seule marquée attached).
  IF ra.attached_digital_asset_id IS NOT NULL OR ra.deposit_status = 'attached' THEN
    RETURN jsonb_build_object('ok', true, 'asset_id', ra.attached_digital_asset_id, 'created', false, 'book_id', p_book_id);
  END IF;

  -- Garde 0 : le fichier reçu appartient à une biblio coordonnée par l'appelant.
  IF NOT public.fn_caller_is_network_admin() AND NOT EXISTS (
    SELECT 1 FROM ingest.partner_catalog_import_runs run
      JOIN public.user_library_memberships m ON m.library_id = run.library_id
     WHERE run.id = ra.run_id AND m.user_id = auth.uid() AND m.status = 'active' AND m.role = 'coordenador'
  ) THEN RAISE EXCEPTION 'Recurso recebido não pertence a uma biblioteca que você coordena.'; END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = p_book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca detentora.'; END IF;

  v_kind := CASE
    WHEN p_bucket_name = 'pdf-restrito' THEN 'pdf'
    WHEN ra.mime_type LIKE 'image/%' THEN 'image'
    WHEN ra.mime_type LIKE 'audio/%' THEN 'audio'
    WHEN ra.mime_type LIKE 'video/%' THEN 'video'
    WHEN ra.asset_kind IN ('image','audio','video') THEN ra.asset_kind
    ELSE 'image' END;
  v_title := coalesce(nullif(trim(ra.title), ''), 'Recurso recebido');

  -- ── Export / partage : digital_asset to_review (couche curée) ──────────────
  IF p_mode IN ('export','both') THEN
    INSERT INTO public.digital_assets
      (asset_kind, title, book_id, source_name, attribution_text, source_license_name,
       rights_status, bucket_name, object_path, is_public, mime_type, file_size_bytes, checksum_sha256, notes)
    VALUES
      (v_kind, v_title, p_book_id, coalesce(nullif(trim(ra.source_name), ''), 'AnarBib'),
       ra.attribution_text, ra.source_license_name, 'to_review', p_bucket_name, p_object_path, false,
       coalesce(ra.mime_type, 'application/octet-stream'), ra.file_size_bytes, ra.checksum_sha256,
       'Attaché depuis un fonds reçu (received_asset ' || p_received_asset_id || ') — à vérifier')
    RETURNING id INTO v_asset_id;
  END IF;

  -- ── Lecture locale : book_digital_resources (couche catalogue, même fichier) ─
  IF p_mode IN ('read','both') THEN
    v_rtype := CASE WHEN v_kind = 'pdf' THEN 'pdf_restrito' WHEN v_kind = 'audio' THEN 'audio'
                    WHEN v_kind = 'video' THEN 'video' ELSE 'image' END;
    v_utype := CASE WHEN v_kind = 'pdf' THEN 'leitura_online' WHEN v_kind = 'audio' THEN 'escuta_online'
                    ELSE 'visualizacao_online' END;
    INSERT INTO public.book_digital_resources
      (book_id, resource_type, usage_type, access_scope, status, is_active,
       storage_bucket, storage_path, mime_type, label, source_name, attribution_text,
       rights_status, is_primary, bibliographic_match_validated, notes)
    VALUES
      (p_book_id, v_rtype, v_utype, 'conta_ativa', 'active', true,
       p_bucket_name, p_object_path, coalesce(ra.mime_type, 'application/octet-stream'), v_title,
       nullif(trim(ra.source_name), ''), ra.attribution_text,
       coalesce(nullif(trim(ra.rights_status), ''), 'to_review'), false, true,
       'Attaché (lisible local) depuis un fonds reçu (received_asset ' || p_received_asset_id || ')')
    RETURNING id INTO v_resource_id;
  END IF;

  UPDATE ingest.partner_catalog_received_assets
     SET attached_digital_asset_id = v_asset_id, deposit_status = 'attached'
   WHERE id = p_received_asset_id;

  RETURN jsonb_build_object('ok', true, 'asset_id', v_asset_id, 'resource_id', v_resource_id,
    'created', true, 'book_id', p_book_id, 'mode', p_mode,
    'rights_status', CASE WHEN v_asset_id IS NOT NULL THEN 'to_review' ELSE NULL END);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text, text) IS
  'Chantier fichiers numériques (b, MàJ point 6). Attache un fonds reçu selon p_mode : export → '
  'digital_asset to_review (bucket restreint) ; read → book_digital_resources (lecture locale '
  'conta_ativa, même fichier) ; both → les deux. Idempotent. Gardée coordenador de la biblio détentrice.';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_fn int;
BEGIN
  SELECT count(*) INTO v_fn FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='fn_attach_received_asset_record' AND p.pronargs = 5;
  IF v_fn <> 1 THEN RAISE EXCEPTION 'verify (pt6): fn_attach_received_asset_record(5 args) attendue, trouvé %', v_fn; END IF;
  RAISE NOTICE 'point 6 OK : attache avec sélecteur de destination (export/read/both).';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_attach_received_asset_record(bigint, bigint, text, text, text);
--   -- + restaurer la version 4-args (point 1, 20260615120000).
-- =========================================================================
