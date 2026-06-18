-- =========================================================================
-- Paquet CARTO-3 — RPC d'édition de la cartographie (doctrine RPC v3, MAP-D)
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Cartographie du réseau (spec-cartographie-reseau v1.0 ; REGISTRE §34)
-- Auteur   : AnarBib · Session : Carte réseau 10 locales
--
-- MAP-D — droits d'édition :
--   D1 (autonomie du collectif) : un·e staff actif·ve (librarian/coordenador) de
--      la biblio LIÉE édite SA fiche — champs identitaires uniquement (nom, notes,
--      ville/pays, langues, contacts, statut_public/contact_public).
--   D3 (validation coordination) : la coordination réseau (network admin) édite
--      TOUS les champs, dont les structurants partagés (GPS, catégorie, statut).
--   create/delete : coordination réseau uniquement.
--
-- RBAC : public.fn_caller_is_network_admin() ; staff via user_library_memberships
--        (status='active', role IN ('librarian','coordenador')).
-- Toutes SECURITY DEFINER (écrivent la table verrouillée), search_path fixé,
-- EXECUTE révoqué à PUBLIC puis accordé à authenticated. Schéma api (apiRpc).
-- =========================================================================

BEGIN;

-- ── create (coordination réseau) ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.fn_cartography_create_entry(p_payload jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.cartography_entries (
    library_id, slug, name_i18n, city_i18n, country_i18n, notes_i18n,
    categorie, statut_anarbib, statut_geo, statut_public, contact_public,
    lat, lon, reseau, langue_fonds, site_url, adresse, email, tel, source, updated_by
  ) VALUES (
    NULLIF(p_payload->>'library_id','')::uuid,
    NULLIF(p_payload->>'slug',''),
    COALESCE(p_payload->'name_i18n','{}'::jsonb),
    COALESCE(p_payload->'city_i18n','{}'::jsonb),
    COALESCE(p_payload->'country_i18n','{}'::jsonb),
    COALESCE(p_payload->'notes_i18n','{}'::jsonb),
    p_payload->>'categorie',
    COALESCE(NULLIF(p_payload->>'statut_anarbib',''),'cible'),
    COALESCE(NULLIF(p_payload->>'statut_geo',''),'ville'),
    COALESCE((p_payload->>'statut_public')::boolean, false),
    COALESCE((p_payload->>'contact_public')::boolean, false),
    (p_payload->>'lat')::numeric, (p_payload->>'lon')::numeric,
    NULLIF(p_payload->>'reseau',''),
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_payload->'langue_fonds')), '{}'::text[]),
    NULLIF(p_payload->>'site_url',''), NULLIF(p_payload->>'adresse',''),
    NULLIF(p_payload->>'email',''), NULLIF(p_payload->>'tel',''),
    NULLIF(p_payload->>'source',''), auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_create_entry(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_create_entry(jsonb) TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_create_entry(jsonb) IS 'Crée une fiche carto. Garde : network admin (MAP-D). Paquet CARTO-3.';

-- ── update_self (staff de la biblio liée — champs identitaires, D1) ───────────
CREATE OR REPLACE FUNCTION api.fn_cartography_update_self(p_entry_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
DECLARE v_lib uuid;
BEGIN
  SELECT library_id INTO v_lib FROM public.cartography_entries WHERE id = p_entry_id;
  IF v_lib IS NULL THEN
    RAISE EXCEPTION 'forbidden: entry not linked to a library' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid() AND m.library_id = v_lib
      AND m.status = 'active' AND m.role IN ('librarian','coordenador')
  ) THEN
    RAISE EXCEPTION 'forbidden: not active staff of this library' USING ERRCODE = '42501';
  END IF;
  UPDATE public.cartography_entries SET
    name_i18n      = COALESCE(p_payload->'name_i18n', name_i18n),
    city_i18n      = COALESCE(p_payload->'city_i18n', city_i18n),
    country_i18n   = COALESCE(p_payload->'country_i18n', country_i18n),
    notes_i18n     = COALESCE(p_payload->'notes_i18n', notes_i18n),
    langue_fonds   = CASE WHEN p_payload ? 'langue_fonds' THEN COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_payload->'langue_fonds')), '{}'::text[]) ELSE langue_fonds END,
    site_url       = CASE WHEN p_payload ? 'site_url' THEN NULLIF(p_payload->>'site_url','') ELSE site_url END,
    email          = CASE WHEN p_payload ? 'email' THEN NULLIF(p_payload->>'email','') ELSE email END,
    tel            = CASE WHEN p_payload ? 'tel' THEN NULLIF(p_payload->>'tel','') ELSE tel END,
    adresse        = CASE WHEN p_payload ? 'adresse' THEN NULLIF(p_payload->>'adresse','') ELSE adresse END,
    statut_public  = COALESCE((p_payload->>'statut_public')::boolean, statut_public),
    contact_public = COALESCE((p_payload->>'contact_public')::boolean, contact_public),
    updated_by     = auth.uid()
  WHERE id = p_entry_id;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_update_self(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_update_self(uuid, jsonb) TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_update_self(uuid, jsonb) IS 'Édite SA fiche (staff de la biblio liée) — champs identitaires D1 (jamais GPS/catégorie/statut_anarbib). Paquet CARTO-3.';

-- ── toggle_public (staff de la biblio liée, D1) ──────────────────────────────
CREATE OR REPLACE FUNCTION api.fn_cartography_toggle_public(p_entry_id uuid, p_value boolean)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
DECLARE v_lib uuid;
BEGIN
  SELECT library_id INTO v_lib FROM public.cartography_entries WHERE id = p_entry_id;
  IF v_lib IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid() AND m.library_id = v_lib
      AND m.status = 'active' AND m.role IN ('librarian','coordenador')
  ) THEN
    RAISE EXCEPTION 'forbidden: not active staff of this library' USING ERRCODE = '42501';
  END IF;
  UPDATE public.cartography_entries SET statut_public = p_value, updated_by = auth.uid()
  WHERE id = p_entry_id;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_toggle_public(uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_toggle_public(uuid, boolean) TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_toggle_public(uuid, boolean) IS 'Bascule statut_public de SA fiche (staff de la biblio liée, autonomie d''apparition D1/MAP-E). Paquet CARTO-3.';

-- ── update_admin (coordination réseau — tous champs, D3) ──────────────────────
CREATE OR REPLACE FUNCTION api.fn_cartography_update_admin(p_entry_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  UPDATE public.cartography_entries SET
    library_id     = CASE WHEN p_payload ? 'library_id' THEN NULLIF(p_payload->>'library_id','')::uuid ELSE library_id END,
    slug           = CASE WHEN p_payload ? 'slug' THEN NULLIF(p_payload->>'slug','') ELSE slug END,
    name_i18n      = COALESCE(p_payload->'name_i18n', name_i18n),
    city_i18n      = COALESCE(p_payload->'city_i18n', city_i18n),
    country_i18n   = COALESCE(p_payload->'country_i18n', country_i18n),
    notes_i18n     = COALESCE(p_payload->'notes_i18n', notes_i18n),
    categorie      = CASE WHEN p_payload ? 'categorie' THEN p_payload->>'categorie' ELSE categorie END,
    statut_anarbib = CASE WHEN p_payload ? 'statut_anarbib' THEN p_payload->>'statut_anarbib' ELSE statut_anarbib END,
    statut_geo     = CASE WHEN p_payload ? 'statut_geo' THEN p_payload->>'statut_geo' ELSE statut_geo END,
    statut_public  = COALESCE((p_payload->>'statut_public')::boolean, statut_public),
    contact_public = COALESCE((p_payload->>'contact_public')::boolean, contact_public),
    lat            = CASE WHEN p_payload ? 'lat' THEN (p_payload->>'lat')::numeric ELSE lat END,
    lon            = CASE WHEN p_payload ? 'lon' THEN (p_payload->>'lon')::numeric ELSE lon END,
    reseau         = CASE WHEN p_payload ? 'reseau' THEN NULLIF(p_payload->>'reseau','') ELSE reseau END,
    langue_fonds   = CASE WHEN p_payload ? 'langue_fonds' THEN COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_payload->'langue_fonds')), '{}'::text[]) ELSE langue_fonds END,
    site_url       = CASE WHEN p_payload ? 'site_url' THEN NULLIF(p_payload->>'site_url','') ELSE site_url END,
    adresse        = CASE WHEN p_payload ? 'adresse' THEN NULLIF(p_payload->>'adresse','') ELSE adresse END,
    email          = CASE WHEN p_payload ? 'email' THEN NULLIF(p_payload->>'email','') ELSE email END,
    tel            = CASE WHEN p_payload ? 'tel' THEN NULLIF(p_payload->>'tel','') ELSE tel END,
    source         = CASE WHEN p_payload ? 'source' THEN NULLIF(p_payload->>'source','') ELSE source END,
    updated_by     = auth.uid()
  WHERE id = p_entry_id;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_update_admin(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_update_admin(uuid, jsonb) TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_update_admin(uuid, jsonb) IS 'Édite tous les champs d''une fiche (network admin, D3 : GPS/catégorie/statut compris). Paquet CARTO-3.';

-- ── delete (coordination réseau) ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.fn_cartography_delete(p_entry_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: network admin only' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.cartography_entries WHERE id = p_entry_id;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_delete(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_delete(uuid) TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_delete(uuid) IS 'Supprime une fiche carto. Garde : network admin (MAP-D). Paquet CARTO-3.';

COMMIT;
