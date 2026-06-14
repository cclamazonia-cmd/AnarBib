-- =========================================================================
-- Chantier « gestion des fichiers numériques », ENTRÉE (a) — promotion catalogage.
--
-- Contexte (cf. mémoire digital-assets-vs-book-digital-resources) : le catalogage
-- remplit `public.book_digital_resources` (rights_status texte libre / livre_de_direitos),
-- mais l'export de fonds (EX-1) exige un `public.digital_assets` à
-- `rights_status='public_domain_confirmed'` (couche CURÉE, P3 strict — Solution 1).
-- Cette migration pose le flux qui PEUPLE digital_assets depuis un book_digital_resources
-- PUBLIC : le fichier est déjà dans un bucket final → simple INSERT + mapping + acte de
-- vérification (verified_at/by) du coordenador. Rend la fiche éligible à l'export.
--
--   1. fn_export_publishable_resources(library) : liste les candidats (publics, validés,
--      bucket final) pas encore promus en digital_asset.
--   2. fn_publish_digital_asset_from_resource(resource) : promeut UN fichier → digital_asset
--      public_domain_confirmed (idempotent), gardé coordenador de la biblio détentrice.
-- =========================================================================
BEGIN;

-- ─── 1. Candidats à la promotion (face Export, coordenador) ─────────────────
CREATE OR REPLACE FUNCTION public.fn_export_publishable_resources(p_library_id uuid)
RETURNS TABLE (
  resource_id   bigint,
  book_id       bigint,
  book_title    text,
  label         text,
  bucket        text,
  path          text,
  mime_type     text,
  is_primary    boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
BEGIN
  IF p_library_id IS NULL THEN RAISE EXCEPTION 'library_id obrigatorio.'; END IF;
  IF NOT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  RETURN QUERY
    SELECT r.id, r.book_id, b.titulo, r.label, r.storage_bucket, r.storage_path,
           r.mime_type, coalesce(r.is_primary, false)
      FROM public.book_digital_resources r
      JOIN public.books b ON b.id = r.book_id
     WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                    WHERE h.book_id = r.book_id AND h.library_id = p_library_id)
       AND coalesce(r.is_active, true) = true
       AND r.status = 'active'
       AND r.access_scope = 'publico'
       AND coalesce(r.bibliographic_match_validated, false) = true
       AND r.storage_bucket IN ('anarbib-pdf-public', 'anarbib-media-public')
       AND r.storage_path IS NOT NULL AND r.storage_path NOT LIKE 'http%'
       -- pas déjà promu (même livre + même objet storage).
       AND NOT EXISTS (SELECT 1 FROM public.digital_assets da
                        WHERE da.book_id = r.book_id
                          AND da.bucket_name = r.storage_bucket
                          AND da.object_path = r.storage_path)
     ORDER BY b.titulo, r.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_export_publishable_resources(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_export_publishable_resources(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_export_publishable_resources(uuid) IS
  'Chantier fichiers numériques (a). Fichiers PUBLICS publiés (book_digital_resources) d''une biblio, '
  'validés et dans un bucket final, PAS encore promus en digital_asset → candidats à la curation pour '
  'l''export de fonds. Reservé coordenador / admin réseau.';

-- ─── 2. Promotion d'un fichier en digital_asset vérifié (P3 strict) ─────────
CREATE OR REPLACE FUNCTION public.fn_publish_digital_asset_from_resource(p_resource_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
  r public.book_digital_resources%rowtype;
  v_authorized boolean;
  v_kind text;
  v_title text;
  v_existing_id bigint;
  v_asset_id bigint;
BEGIN
  IF p_resource_id IS NULL THEN RAISE EXCEPTION 'resource_id obrigatorio.'; END IF;
  SELECT * INTO r FROM public.book_digital_resources WHERE id = p_resource_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recurso digital % introuvável.', p_resource_id; END IF;
  IF r.book_id IS NULL THEN RAISE EXCEPTION 'Recurso sem book_id (brouillon non publié).'; END IF;

  -- Garde : coordenador d'une biblio détentrice du livre (ou admin réseau).
  SELECT (
    EXISTS (SELECT 1 FROM public.book_holdings h
              JOIN public.user_library_memberships m ON m.library_id = h.library_id
             WHERE h.book_id = r.book_id AND m.user_id = auth.uid()
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca detentora.'; END IF;

  -- Éligibilité : fichier public, validé, dans un bucket public final, chemin propre.
  IF r.access_scope IS DISTINCT FROM 'publico' THEN RAISE EXCEPTION 'Recurso não é público.'; END IF;
  IF coalesce(r.bibliographic_match_validated, false) = false THEN RAISE EXCEPTION 'Correspondência bibliográfica não validada.'; END IF;
  IF r.storage_path IS NULL OR r.storage_path LIKE 'http%' THEN RAISE EXCEPTION 'Caminho de armazenamento inválido.'; END IF;

  v_kind := CASE
    WHEN r.mime_type = 'application/pdf' THEN 'pdf'
    WHEN r.mime_type LIKE 'image/%' THEN 'image'
    WHEN r.mime_type LIKE 'audio/%' THEN 'audio'
    WHEN r.mime_type LIKE 'video/%' THEN 'video'
    ELSE NULL END;
  IF v_kind IS NULL THEN RAISE EXCEPTION 'Tipo MIME % não suportado para asset.', r.mime_type; END IF;
  -- Cohérence kind ↔ bucket (CHECK digital_assets).
  IF (v_kind = 'pdf' AND r.storage_bucket <> 'anarbib-pdf-public')
     OR (v_kind IN ('image','audio','video') AND r.storage_bucket <> 'anarbib-media-public') THEN
    RAISE EXCEPTION 'Bucket % incompatível com o tipo %.', r.storage_bucket, v_kind;
  END IF;

  SELECT coalesce(nullif(trim(r.label), ''), nullif(trim(b.titulo), ''), 'Recurso digital')
    INTO v_title FROM public.books b WHERE b.id = r.book_id;

  -- Idempotence : si l'asset existe déjà (même objet), on le (re)marque vérifié.
  SELECT id INTO v_existing_id FROM public.digital_assets
   WHERE book_id = r.book_id AND bucket_name = r.storage_bucket AND object_path = r.storage_path
   LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    UPDATE public.digital_assets
       SET rights_status = 'public_domain_confirmed', is_public = true,
           verified_at = now(), verified_by = auth.uid(),
           source_name = coalesce(source_name, nullif(trim(r.source_name), ''), 'AnarBib'),
           attribution_text = coalesce(attribution_text, r.attribution_text),
           updated_at = now()
     WHERE id = v_existing_id;
    v_asset_id := v_existing_id;
    RETURN jsonb_build_object('ok', true, 'asset_id', v_asset_id, 'created', false, 'book_id', r.book_id);
  END IF;

  INSERT INTO public.digital_assets
    (asset_kind, title, language_code, book_id, source_name, source_url, attribution_text,
     rights_status, bucket_name, object_path, is_public, mime_type, verified_at, verified_by, notes)
  VALUES
    (v_kind, v_title, nullif(trim(r.language_code), ''), r.book_id,
     coalesce(nullif(trim(r.source_name), ''), 'AnarBib'), nullif(trim(r.source_url), ''),
     r.attribution_text, 'public_domain_confirmed', r.storage_bucket, r.storage_path, true,
     coalesce(r.mime_type, 'application/octet-stream'), now(), auth.uid(),
     'Curado para o export de fundo (Solução 1) a partir do recurso ' || p_resource_id)
  RETURNING id INTO v_asset_id;

  RETURN jsonb_build_object('ok', true, 'asset_id', v_asset_id, 'created', true, 'book_id', r.book_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_publish_digital_asset_from_resource(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_publish_digital_asset_from_resource(bigint) TO authenticated;

COMMENT ON FUNCTION public.fn_publish_digital_asset_from_resource(bigint) IS
  'Chantier fichiers numériques (a). Promeut un book_digital_resources public+validé en '
  'digital_asset public_domain_confirmed (acte de vérification du coordenador, verified_at/by). '
  'Le fichier est déjà dans un bucket final → INSERT + mapping, sans déplacement. Idempotent. '
  'Rend la fiche éligible à l''export de fonds (EX-1).';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_fns int;
BEGIN
  SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname IN ('fn_export_publishable_resources','fn_publish_digital_asset_from_resource');
  IF v_fns <> 2 THEN RAISE EXCEPTION 'verify (a): attendu 2 fn, trouvé %', v_fns; END IF;
  RAISE NOTICE 'chantier fichiers numériques (a) OK : liste + promotion digital_asset.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_publish_digital_asset_from_resource(bigint);
--   DROP FUNCTION IF EXISTS public.fn_export_publishable_resources(uuid);
-- =========================================================================
