-- =========================================================================
-- Paquet CARTO-5 — Support UI d'édition (can_edit + get_for_edit)
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Cartographie du réseau (REGISTRE §34) — UI d'édition (Phase 3)
-- Auteur   : AnarBib · Session : Carte réseau 10 locales
--
-- 1) api.cartography_network_v1 gagne une colonne `can_edit` (par ligne, selon
--    l'usager·ère appelant·e) : true si network admin OU staff actif de la biblio
--    liée. Permet au front d'afficher le bouton « Éditer » sur les seuls
--    marqueurs éditables. (N1 only — toujours sans adresse/email/tel.)
-- 2) api.fn_cartography_get_for_edit(entry_id) : révèle la fiche COMPLÈTE (avec
--    N2 : adresse/email/tel) AUX SEULS éditeurs autorisés (admin ou staff de la
--    biblio liée), pour pré-remplir le formulaire. Retourne can_admin (→ le front
--    montre les champs D3 structurants uniquement à la coordination).
-- =========================================================================

BEGIN;

-- ── (1) recréer la fonction réseau + la vue avec can_edit ─────────────────────
DROP VIEW IF EXISTS api.cartography_network_v1;
DROP FUNCTION IF EXISTS private.fn_cartography_network_rows();

CREATE OR REPLACE FUNCTION private.fn_cartography_network_rows()
RETURNS TABLE (
  id uuid, slug text, library_id uuid, categorie text, statut_anarbib text,
  statut_geo text, lat numeric, lon numeric, reseau text, langue_fonds text[],
  site_url text, name_i18n jsonb, city_i18n jsonb, country_i18n jsonb, notes_i18n jsonb,
  can_edit boolean
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT ce.id, ce.slug, ce.library_id, ce.categorie, ce.statut_anarbib, ce.statut_geo,
         ce.lat, ce.lon, ce.reseau, ce.langue_fonds, ce.site_url,
         ce.name_i18n, ce.city_i18n, ce.country_i18n, ce.notes_i18n,
         (a.is_admin OR (ce.library_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid() AND m.library_id = ce.library_id
              AND m.status = 'active' AND m.role IN ('librarian','coordenador')
         ))) AS can_edit
  FROM public.cartography_entries ce
  CROSS JOIN LATERAL (SELECT public.fn_caller_is_network_admin() AS is_admin) a;
$$;
ALTER FUNCTION private.fn_cartography_network_rows() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION private.fn_cartography_network_rows() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.fn_cartography_network_rows() TO authenticated;
COMMENT ON FUNCTION private.fn_cartography_network_rows() IS
  'Wrapper SECDEF (N1 + can_edit calculé par l''appelant·e) de TOUTES les fiches carto, '
  'pour la carte interne authentifiée. N''expose JAMAIS adresse/email/tel. Paquet CARTO-5.';

CREATE OR REPLACE VIEW api.cartography_network_v1
  WITH (security_invoker = true) AS
  SELECT id, slug, library_id, categorie, statut_anarbib, statut_geo, lat, lon,
         reseau, langue_fonds, site_url, name_i18n, city_i18n, country_i18n, notes_i18n, can_edit
  FROM private.fn_cartography_network_rows();
ALTER VIEW api.cartography_network_v1 OWNER TO postgres;
GRANT SELECT ON api.cartography_network_v1 TO authenticated;
COMMENT ON VIEW api.cartography_network_v1 IS
  'Carte interne (authentifié·e) : toutes les fiches, N1 + can_edit. security_invoker. Paquet CARTO-5 (étend CARTO-1).';

-- ── (2) get_for_edit : fiche complète (N2) pour éditeurs autorisés ────────────
CREATE OR REPLACE FUNCTION api.fn_cartography_get_for_edit(p_entry_id uuid)
RETURNS TABLE (
  id uuid, slug text, library_id uuid, categorie text, statut_anarbib text,
  statut_geo text, statut_public boolean, contact_public boolean,
  lat numeric, lon numeric, reseau text, langue_fonds text[], site_url text,
  adresse text, email text, tel text,
  name_i18n jsonb, city_i18n jsonb, country_i18n jsonb, notes_i18n jsonb,
  can_admin boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE v_lib uuid; v_admin boolean;
BEGIN
  SELECT ce.library_id INTO v_lib FROM public.cartography_entries ce WHERE ce.id = p_entry_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not found' USING ERRCODE = 'no_data_found';
  END IF;
  v_admin := public.fn_caller_is_network_admin();
  IF NOT (v_admin OR (v_lib IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid() AND m.library_id = v_lib
      AND m.status = 'active' AND m.role IN ('librarian','coordenador')
  ))) THEN
    RAISE EXCEPTION 'forbidden: not an editor of this entry' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
    SELECT ce.id, ce.slug, ce.library_id, ce.categorie, ce.statut_anarbib, ce.statut_geo,
           ce.statut_public, ce.contact_public, ce.lat, ce.lon, ce.reseau, ce.langue_fonds,
           ce.site_url, ce.adresse, ce.email, ce.tel,
           ce.name_i18n, ce.city_i18n, ce.country_i18n, ce.notes_i18n, v_admin
    FROM public.cartography_entries ce WHERE ce.id = p_entry_id;
END $$;
REVOKE EXECUTE ON FUNCTION api.fn_cartography_get_for_edit(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_cartography_get_for_edit(uuid) TO authenticated;
COMMENT ON FUNCTION api.fn_cartography_get_for_edit(uuid) IS
  'Fiche carto COMPLÈTE (avec N2 adresse/email/tel) pour pré-remplir le formulaire, réservée '
  'aux éditeurs (network admin OU staff actif de la biblio liée). Retourne can_admin (champs D3). Paquet CARTO-5.';

COMMIT;
