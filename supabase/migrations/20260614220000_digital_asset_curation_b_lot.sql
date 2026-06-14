-- =========================================================================
-- Chantier « gestion des fichiers numériques », ENTRÉE (b) — attache des fonds reçus.
--
-- Les fichiers d'un lot de fonds reçu (EX-3 ZIP / EX-4 direct) sont déposés dans
-- `partner-catalog-deposits` et parqués dans `ingest.partner_catalog_received_assets`.
-- Une fois la notice cataloguée (draft → livre), la réceptrice ATTACHE le fichier reçu
-- au livre : l'EF `attach-received-asset` DÉPLACE le fichier vers un bucket final, puis
-- cette RPC crée le `digital_asset` public_domain_confirmed et marque le parking `attached`.
--
--   1. fn_list_received_assets_to_attach(library) : fichiers reçus en attente d'attache.
--   2. fn_search_library_books(library, query)     : pour choisir le livre cible.
--   3. fn_attach_received_asset_record(...)         : INSERT digital_asset + marque attached
--      (appelée par l'EF après le déplacement storage). Gardée coordenador.
-- =========================================================================
BEGIN;

-- ─── 1. Fichiers reçus en attente d'attache ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_list_received_assets_to_attach(p_library_id uuid)
RETURNS TABLE (
  received_asset_id bigint, run_id bigint, title text, asset_kind text,
  mime_type text, source_name text, file_size_bytes bigint
)
LANGUAGE plpgsql SECURITY DEFINER
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
    SELECT ra.id, ra.run_id, ra.title, ra.asset_kind, ra.mime_type, ra.source_name, ra.file_size_bytes
      FROM ingest.partner_catalog_received_assets ra
      JOIN ingest.partner_catalog_import_runs run ON run.id = ra.run_id
     WHERE run.library_id = p_library_id
       AND ra.deposit_status = 'deposited'
       AND ra.attached_digital_asset_id IS NULL
     ORDER BY ra.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_list_received_assets_to_attach(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_list_received_assets_to_attach(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_list_received_assets_to_attach(uuid) IS
  'Chantier fichiers numériques (b). Fichiers de fonds reçus (EX-3/EX-4) déposés et non encore '
  'attachés à un livre. Reservé coordenador / admin réseau.';

-- ─── 2. Recherche d'un livre de la biblio (choix de la cible) ───────────────
CREATE OR REPLACE FUNCTION public.fn_search_library_books(p_library_id uuid, p_query text)
RETURNS TABLE (book_id bigint, title text, bib_ref text, isbn text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE v_q text;
BEGIN
  IF p_library_id IS NULL THEN RAISE EXCEPTION 'library_id obrigatorio.'; END IF;
  IF NOT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.'; END IF;

  v_q := '%' || coalesce(trim(p_query), '') || '%';
  RETURN QUERY
    SELECT b.id, b.titulo, b.bib_ref, b.isbn
      FROM public.books b
     WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                    WHERE h.book_id = b.id AND h.library_id = p_library_id)
       AND (b.titulo ILIKE v_q OR coalesce(b.isbn,'') ILIKE v_q OR coalesce(b.bib_ref,'') ILIKE v_q)
     ORDER BY b.titulo
     LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_search_library_books(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_search_library_books(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_search_library_books(uuid, text) IS
  'Chantier fichiers numériques (b). Recherche de livres d''une biblio (titre/ISBN/réf) pour '
  'choisir la cible d''attache d''un fichier reçu. Reservé coordenador / admin réseau.';

-- ─── 3. Attache : crée le digital_asset (le fichier a été déplacé par l'EF) ──
CREATE OR REPLACE FUNCTION public.fn_attach_received_asset_record(
  p_received_asset_id bigint, p_book_id bigint, p_bucket_name text, p_object_path text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
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
  IF p_bucket_name NOT IN ('anarbib-pdf-public','anarbib-media-public') THEN
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

  -- Type d'asset cohérent avec le bucket destination (CHECK digital_assets).
  v_kind := CASE
    WHEN p_bucket_name = 'anarbib-pdf-public' THEN 'pdf'
    WHEN ra.mime_type LIKE 'image/%' THEN 'image'
    WHEN ra.mime_type LIKE 'audio/%' THEN 'audio'
    WHEN ra.mime_type LIKE 'video/%' THEN 'video'
    WHEN ra.asset_kind IN ('image','audio','video') THEN ra.asset_kind
    ELSE 'image' END;
  v_title := coalesce(nullif(trim(ra.title), ''), 'Recurso recebido');

  INSERT INTO public.digital_assets
    (asset_kind, title, book_id, source_name, attribution_text, source_license_name,
     rights_status, bucket_name, object_path, is_public, mime_type, file_size_bytes,
     checksum_sha256, verified_at, verified_by, notes)
  VALUES
    (v_kind, v_title, p_book_id, coalesce(nullif(trim(ra.source_name), ''), 'AnarBib'),
     ra.attribution_text, ra.source_license_name, 'public_domain_confirmed', p_bucket_name,
     p_object_path, true, coalesce(ra.mime_type, 'application/octet-stream'), ra.file_size_bytes,
     ra.checksum_sha256, now(), auth.uid(),
     'Attaché depuis un fonds reçu (received_asset ' || p_received_asset_id || ')')
  RETURNING id INTO v_asset_id;

  UPDATE ingest.partner_catalog_received_assets
     SET attached_digital_asset_id = v_asset_id, deposit_status = 'attached'
   WHERE id = p_received_asset_id;

  RETURN jsonb_build_object('ok', true, 'asset_id', v_asset_id, 'created', true, 'book_id', p_book_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_attach_received_asset_record(bigint, bigint, text, text) IS
  'Chantier fichiers numériques (b). Crée le digital_asset public_domain_confirmed pour un fichier '
  'de fonds reçu (le fichier a été déplacé vers un bucket final par l''EF attach-received-asset) et '
  'marque le parking received_assets attached. Idempotent. Gardée coordenador de la biblio détentrice.';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_fns int;
BEGIN
  SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname IN
      ('fn_list_received_assets_to_attach','fn_search_library_books','fn_attach_received_asset_record');
  IF v_fns <> 3 THEN RAISE EXCEPTION 'verify (b): attendu 3 fn, trouvé %', v_fns; END IF;
  RAISE NOTICE 'chantier fichiers numériques (b) OK : liste + recherche + attache.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_attach_received_asset_record(bigint, bigint, text, text);
--   DROP FUNCTION IF EXISTS public.fn_search_library_books(uuid, text);
--   DROP FUNCTION IF EXISTS public.fn_list_received_assets_to_attach(uuid);
-- =========================================================================
