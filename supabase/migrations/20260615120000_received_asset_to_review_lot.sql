-- =========================================================================
-- Chantier « gestion des fichiers numériques », point 1 — palier to_review à la réception.
--
-- Décision Xavier : un fonds REÇU (origine externe) ne doit PAS être affirmé « domaine
-- public » d'un simple clic d'attache. L'attache le crée désormais en `to_review` +
-- `is_public=false` dans un bucket RESTREINT (pdf-restrito / anarbib-media-restricted).
-- La confirmation « domaine public » est un ACTE SÉPARÉ et explicite du coordenador, qui
-- voit la provenance avant de confirmer (cohérent ILL-5). Comme le point 4 (révocation)
-- existe, l'irréversibilité n'est plus un risque.
--
-- Confirmation = simple flip de droits (le fichier RESTE dans le bucket restreint) : l'asset
-- devient éligible export (EX-1) + partage ILL. La lecture publique locale reste un acte
-- distinct (point 6, couche book_digital_resources).
--
--   1. fn_attach_received_asset_record (réécrite) : crée en to_review + bucket restreint.
--   2. fn_confirm_digital_asset_rights(asset) : to_review → public_domain_confirmed
--      (verified_at/by). Gardée coordenador détenteur.
-- =========================================================================
BEGIN;

-- ─── 1. Attache : crée le digital_asset en to_review (bucket restreint) ──────
CREATE OR REPLACE FUNCTION public.fn_attach_received_asset_record(
  p_received_asset_id bigint, p_book_id bigint, p_bucket_name text, p_object_path text
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
BEGIN
  IF p_received_asset_id IS NULL OR p_book_id IS NULL THEN RAISE EXCEPTION 'received_asset_id e book_id obrigatorios.'; END IF;
  -- Point 1 : fonds reçu = droits NON encore vérifiés → bucket RESTREINT + to_review.
  IF p_bucket_name NOT IN ('pdf-restrito','anarbib-media-restricted') THEN
    RAISE EXCEPTION 'Bucket destino inválido (%).', p_bucket_name;
  END IF;
  IF p_object_path IS NULL OR p_object_path LIKE 'http%' THEN RAISE EXCEPTION 'Caminho de destino inválido.'; END IF;

  SELECT * INTO ra FROM ingest.partner_catalog_received_assets WHERE id = p_received_asset_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recurso recebido % introuvável.', p_received_asset_id; END IF;
  IF ra.attached_digital_asset_id IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'asset_id', ra.attached_digital_asset_id, 'created', false, 'book_id', p_book_id);
  END IF;

  -- Garde 0 : le fichier reçu appartient à une biblio coordonnée par l'appelant (anti cross-tenant).
  IF NOT public.fn_caller_is_network_admin() AND NOT EXISTS (
    SELECT 1 FROM ingest.partner_catalog_import_runs run
      JOIN public.user_library_memberships m ON m.library_id = run.library_id
     WHERE run.id = ra.run_id AND m.user_id = auth.uid()
       AND m.status = 'active' AND m.role = 'coordenador'
  ) THEN
    RAISE EXCEPTION 'Recurso recebido não pertence a uma biblioteca que você coordena.';
  END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = p_book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca detentora.'; END IF;

  -- Type d'asset cohérent avec le bucket restreint (CHECK digital_assets).
  v_kind := CASE
    WHEN p_bucket_name = 'pdf-restrito' THEN 'pdf'
    WHEN ra.mime_type LIKE 'image/%' THEN 'image'
    WHEN ra.mime_type LIKE 'audio/%' THEN 'audio'
    WHEN ra.mime_type LIKE 'video/%' THEN 'video'
    WHEN ra.asset_kind IN ('image','audio','video') THEN ra.asset_kind
    ELSE 'image' END;
  v_title := coalesce(nullif(trim(ra.title), ''), 'Recurso recebido');

  INSERT INTO public.digital_assets
    (asset_kind, title, book_id, source_name, attribution_text, source_license_name,
     rights_status, bucket_name, object_path, is_public, mime_type, file_size_bytes,
     checksum_sha256, notes)
  VALUES
    (v_kind, v_title, p_book_id, coalesce(nullif(trim(ra.source_name), ''), 'AnarBib'),
     ra.attribution_text, ra.source_license_name, 'to_review', p_bucket_name,
     p_object_path, false, coalesce(ra.mime_type, 'application/octet-stream'), ra.file_size_bytes,
     ra.checksum_sha256,
     'Attaché depuis un fonds reçu (received_asset ' || p_received_asset_id || ') — à vérifier')
  RETURNING id INTO v_asset_id;

  UPDATE ingest.partner_catalog_received_assets
     SET attached_digital_asset_id = v_asset_id, deposit_status = 'attached'
   WHERE id = p_received_asset_id;

  RETURN jsonb_build_object('ok', true, 'asset_id', v_asset_id, 'created', true,
    'book_id', p_book_id, 'rights_status', 'to_review');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text) IS
  'Chantier fichiers numériques (b, MàJ point 1). Crée le digital_asset d''un fonds reçu en '
  'rights_status=to_review + is_public=false dans un bucket RESTREINT (le fichier a été déplacé '
  'par l''EF attach-received-asset). La confirmation « domaine public » est un acte séparé '
  '(fn_confirm_digital_asset_rights). Idempotent. Gardée coordenador de la biblio détentrice.';

-- ─── 2. Confirmation « domaine public » (acte de vérification du coordenador) ─
CREATE OR REPLACE FUNCTION public.fn_confirm_digital_asset_rights(p_asset_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE da public.digital_assets%rowtype; v_authorized boolean;
BEGIN
  IF p_asset_id IS NULL THEN RAISE EXCEPTION 'asset_id obrigatorio.'; END IF;
  SELECT * INTO da FROM public.digital_assets WHERE id = p_asset_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Asset % introuvável.', p_asset_id; END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = da.book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca detentora.'; END IF;

  IF da.rights_status = 'public_domain_confirmed' THEN
    RETURN jsonb_build_object('ok', true, 'asset_id', p_asset_id, 'changed', false, 'rights_status', da.rights_status);
  END IF;
  IF da.rights_status <> 'to_review' THEN
    RAISE EXCEPTION 'Seuls les assets « à vérifier » peuvent être confirmés (statut actuel : %).', da.rights_status;
  END IF;

  UPDATE public.digital_assets
     SET rights_status = 'public_domain_confirmed', verified_at = now(), verified_by = auth.uid(), updated_at = now()
   WHERE id = p_asset_id;

  RETURN jsonb_build_object('ok', true, 'asset_id', p_asset_id, 'changed', true,
    'book_id', da.book_id, 'rights_status', 'public_domain_confirmed');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_confirm_digital_asset_rights(bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_confirm_digital_asset_rights(bigint) TO authenticated;

COMMENT ON FUNCTION public.fn_confirm_digital_asset_rights(bigint) IS
  'Chantier fichiers numériques (point 1). Confirme un digital_asset to_review en '
  'public_domain_confirmed (verified_at/by) — acte explicite du coordenador après vue de la '
  'provenance. Le fichier reste dans son bucket restreint (export-éligible ; lecture publique = '
  'point 6). Idempotent. Gardée coordenador de la biblio détentrice.';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_fns int;
BEGIN
  SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname IN ('fn_attach_received_asset_record','fn_confirm_digital_asset_rights');
  IF v_fns <> 2 THEN RAISE EXCEPTION 'verify (pt1): attendu 2 fn, trouvé %', v_fns; END IF;
  IF has_function_privilege('anon', 'public.fn_confirm_digital_asset_rights(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'verify (pt1): confirm ne doit pas être exécutable par anon';
  END IF;
  RAISE NOTICE 'point 1 OK : attache to_review (bucket restreint) + confirmation séparée.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_confirm_digital_asset_rights(bigint);
--   -- + restaurer fn_attach_received_asset_record depuis 20260614220000 (version public_domain_confirmed).
-- =========================================================================
