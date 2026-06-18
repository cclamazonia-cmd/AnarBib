-- =========================================================================
-- Paquet CARTO-6 — Statut PEB sur la carte interne (MAP-I)
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Cartographie du réseau (REGISTRE §34)
-- Auteur   : AnarBib · Session : Carte réseau 10 locales
--
-- api.cartography_network_v1 gagne un booléen `peb` : true si la fiche est liée à
-- une bibliothèque AnarBib éligible au prêt entre bibliothèques, c.-à-d. la moitié
-- « par bibliothèque » de la règle fn_peb_authorized (fédérée + circulation active).
-- Les non-membres (« cibles », sans library_id) ont peb=false. Le front affiche un
-- badge PEB + un filtre « PEB » sur la carte interne (MAP-I). N1 only conservé.
-- =========================================================================

BEGIN;

DROP VIEW IF EXISTS api.cartography_network_v1;
DROP FUNCTION IF EXISTS private.fn_cartography_network_rows();

CREATE OR REPLACE FUNCTION private.fn_cartography_network_rows()
RETURNS TABLE (
  id uuid, slug text, library_id uuid, categorie text, statut_anarbib text,
  statut_geo text, lat numeric, lon numeric, reseau text, langue_fonds text[],
  site_url text, name_i18n jsonb, city_i18n jsonb, country_i18n jsonb, notes_i18n jsonb,
  can_edit boolean, peb boolean
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
         ))) AS can_edit,
         (ce.library_id IS NOT NULL
            AND public.fn_library_is_federated(ce.library_id)
            AND public.fn_library_has_circulation(ce.library_id)) AS peb
  FROM public.cartography_entries ce
  CROSS JOIN LATERAL (SELECT public.fn_caller_is_network_admin() AS is_admin) a;
$$;
ALTER FUNCTION private.fn_cartography_network_rows() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION private.fn_cartography_network_rows() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.fn_cartography_network_rows() TO authenticated;
COMMENT ON FUNCTION private.fn_cartography_network_rows() IS
  'Wrapper SECDEF (N1 + can_edit + peb) de TOUTES les fiches carto pour la carte interne. '
  'peb = biblio liée fédérée + circulation active (moitié par-biblio de fn_peb_authorized). '
  'Jamais adresse/email/tel. Paquet CARTO-6 (étend CARTO-5).';

CREATE OR REPLACE VIEW api.cartography_network_v1
  WITH (security_invoker = true) AS
  SELECT id, slug, library_id, categorie, statut_anarbib, statut_geo, lat, lon,
         reseau, langue_fonds, site_url, name_i18n, city_i18n, country_i18n, notes_i18n,
         can_edit, peb
  FROM private.fn_cartography_network_rows();
ALTER VIEW api.cartography_network_v1 OWNER TO postgres;
GRANT SELECT ON api.cartography_network_v1 TO authenticated;
COMMENT ON VIEW api.cartography_network_v1 IS
  'Carte interne (authentifié·e) : toutes les fiches, N1 + can_edit + peb. security_invoker. Paquet CARTO-6.';

COMMIT;
