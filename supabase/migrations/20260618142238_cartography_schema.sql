-- =========================================================================
-- Paquet CARTO-1 — Socle données cartographie réseau (cartography_entries)
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Cartographie du réseau (spec-cartographie-reseau v1.0 ; REGISTRE §34)
-- Auteur   : AnarBib · Session : Carte réseau 10 locales
--
-- Décisions incarnées :
--   MAP-A/A2  : table dédiée public.cartography_entries (library_id nullable).
--   MAP-B     : i18n « préserver les 10 locales » (name/city/country/notes en
--               JSONB {locale:texte}) ; structurants (categorie/statut) = codes,
--               libellés via i18n applicatif (federacao.carte.cat.*).
--   MAP-E ⚠️  : confidentialité/consentement — statut_public défaut FALSE,
--               contact_public défaut FALSE (N2 = adresse/email/tel). Table
--               VERROUILLÉE (Scénario C) : aucun accès direct anon/authenticated.
--               Lecture des cartes via vues api SECDEF qui n'exposent QUE le N1
--               (jamais adresse/email/tel). Aucun import public en masse.
--   MAP-G/H   : statut_anarbib (membre/partenaire/cible) → filtre réseau/paysage
--               + icône membre côté front.
--
-- Accès :
--   - Écritures : RPC SECURITY DEFINER (paquet CARTO-3, à venir) + service_role.
--   - Lecture carte interne (authentifiée) : api.cartography_network_v1.
--   - Lecture carte publique (anon)        : api.cartography_public_v1 (opt-in).
--   Patron = catalog_list_anon_v1 (vue security_invoker → fn SECDEF private).
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1) Table
-- -------------------------------------------------------------------------
CREATE TABLE public.cartography_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id uuid REFERENCES public.libraries(id) ON DELETE SET NULL,
  slug text,                                           -- libellé/repère collectif (NON unique : ~3 collectifs distincts partagent un slug)
  -- contenu i18n (10 locales) — MAP-B « préserver les 10 locales »
  name_i18n    jsonb NOT NULL DEFAULT '{}'::jsonb,     -- {locale: texte}
  city_i18n    jsonb NOT NULL DEFAULT '{}'::jsonb,
  country_i18n jsonb NOT NULL DEFAULT '{}'::jsonb,
  notes_i18n   jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- structurants (codes ; libellés via i18n applicatif federacao.carte.cat.*)
  categorie text NOT NULL CHECK (categorie IN
    ('biblioteca','arquivo','centro_doc','ateneu','livraria','misto')),
  statut_anarbib text NOT NULL DEFAULT 'cible' CHECK (statut_anarbib IN
    ('membre','partenaire','cible')),
  statut_geo text NOT NULL DEFAULT 'ville' CHECK (statut_geo IN ('precis','ville')),
  -- confidentialité / consentement (MAP-E)
  statut_public  boolean NOT NULL DEFAULT false,       -- visible carte publique (opt-in N1)
  contact_public boolean NOT NULL DEFAULT false,       -- contacts visibles (opt-in N2)
  -- géo
  lat numeric(9,5) NOT NULL,
  lon numeric(9,5) NOT NULL,
  -- N1 (jamais sensible)
  reseau text,
  langue_fonds text[] NOT NULL DEFAULT '{}'::text[],
  site_url text,
  -- N2 (sensible — jamais exposé par les vues de carte ; opt-in contact_public)
  adresse text,
  email text,
  tel text,
  -- audit
  source text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id)
);

CREATE INDEX cartography_entries_library_id_idx ON public.cartography_entries(library_id);
CREATE INDEX cartography_entries_categorie_idx  ON public.cartography_entries(categorie);
CREATE INDEX cartography_entries_public_idx     ON public.cartography_entries(statut_public) WHERE statut_public;
CREATE INDEX cartography_entries_slug_idx        ON public.cartography_entries(slug);

-- Scénario C : table HORS Data API (accès uniquement via SECDEF / service_role).
REVOKE ALL ON public.cartography_entries FROM anon, authenticated;
GRANT ALL ON public.cartography_entries TO service_role;

ALTER TABLE public.cartography_entries ENABLE ROW LEVEL SECURITY;
-- Aucune policy permissive anon/authenticated : verrouillée (RLS = deny par
-- défaut). service_role et fonctions SECDEF (owner postgres) contournent la RLS.

CREATE TRIGGER cartography_entries_set_updated_at
  BEFORE UPDATE ON public.cartography_entries
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMENT ON TABLE public.cartography_entries IS
  'Cartographie du réseau (spec-cartographie-reseau v1.0, REGISTRE §34, paquet CARTO-1 du 18/06/2026). '
  'Source unique de vérité de l''annuaire géographique. library_id nullable (non-membres « cibles »). '
  'i18n 10 locales (MAP-B). Table verrouillée (Scénario C, MAP-E) : lecture via api.cartography_*_v1, '
  'écriture via RPC SECDEF. adresse/email/tel = N2 sensible, jamais exposé par les vues de carte.';

-- -------------------------------------------------------------------------
-- 2) Fonctions SECDEF de lecture (N1 uniquement — jamais adresse/email/tel)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.fn_cartography_public_rows()
RETURNS TABLE (
  id uuid, slug text, library_id uuid, categorie text, statut_anarbib text,
  statut_geo text, lat numeric, lon numeric, reseau text, langue_fonds text[],
  site_url text, name_i18n jsonb, city_i18n jsonb, country_i18n jsonb, notes_i18n jsonb
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT id, slug, library_id, categorie, statut_anarbib, statut_geo, lat, lon,
         reseau, langue_fonds, site_url, name_i18n, city_i18n, country_i18n, notes_i18n
  FROM public.cartography_entries
  WHERE statut_public = true;
$$;
ALTER FUNCTION private.fn_cartography_public_rows() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION private.fn_cartography_public_rows() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.fn_cartography_public_rows() TO anon, authenticated;
COMMENT ON FUNCTION private.fn_cartography_public_rows() IS
  'Wrapper SECDEF (N1) des fiches carto publiques (statut_public=true). Permet à la vue '
  'invoker api.cartography_public_v1 de lire la table verrouillée sans GRANT direct. '
  'N''expose JAMAIS adresse/email/tel (MAP-E). Paquet CARTO-1.';

CREATE OR REPLACE FUNCTION private.fn_cartography_network_rows()
RETURNS TABLE (
  id uuid, slug text, library_id uuid, categorie text, statut_anarbib text,
  statut_geo text, lat numeric, lon numeric, reseau text, langue_fonds text[],
  site_url text, name_i18n jsonb, city_i18n jsonb, country_i18n jsonb, notes_i18n jsonb
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT id, slug, library_id, categorie, statut_anarbib, statut_geo, lat, lon,
         reseau, langue_fonds, site_url, name_i18n, city_i18n, country_i18n, notes_i18n
  FROM public.cartography_entries;
$$;
ALTER FUNCTION private.fn_cartography_network_rows() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION private.fn_cartography_network_rows() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.fn_cartography_network_rows() TO authenticated;
COMMENT ON FUNCTION private.fn_cartography_network_rows() IS
  'Wrapper SECDEF (N1) de TOUTES les fiches carto (membres/partenaires/cibles), pour la carte '
  'interne authentifiée (api.cartography_network_v1). N''expose JAMAIS adresse/email/tel. Paquet CARTO-1.';

-- -------------------------------------------------------------------------
-- 3) Vues api (security_invoker = true)
-- -------------------------------------------------------------------------
GRANT USAGE ON SCHEMA private TO anon, authenticated;  -- idempotent (déjà accordé pour le catalogue)

CREATE OR REPLACE VIEW api.cartography_public_v1
  WITH (security_invoker = true) AS
  SELECT id, slug, library_id, categorie, statut_anarbib, statut_geo, lat, lon,
         reseau, langue_fonds, site_url, name_i18n, city_i18n, country_i18n, notes_i18n
  FROM private.fn_cartography_public_rows();
ALTER VIEW api.cartography_public_v1 OWNER TO postgres;
GRANT SELECT ON api.cartography_public_v1 TO anon, authenticated;
COMMENT ON VIEW api.cartography_public_v1 IS
  'Carte publique du réseau (visiteurs anon) : fiches statut_public=true, N1 uniquement '
  '(MAP-C/MAP-E). security_invoker=true → fn SECDEF private. Paquet CARTO-1.';

CREATE OR REPLACE VIEW api.cartography_network_v1
  WITH (security_invoker = true) AS
  SELECT id, slug, library_id, categorie, statut_anarbib, statut_geo, lat, lon,
         reseau, langue_fonds, site_url, name_i18n, city_i18n, country_i18n, notes_i18n
  FROM private.fn_cartography_network_rows();
ALTER VIEW api.cartography_network_v1 OWNER TO postgres;
GRANT SELECT ON api.cartography_network_v1 TO authenticated;
COMMENT ON VIEW api.cartography_network_v1 IS
  'Carte interne du réseau (membres authentifié·es) : toutes les fiches, N1 uniquement. '
  'security_invoker=true → fn SECDEF private. Paquet CARTO-1.';

COMMIT;
