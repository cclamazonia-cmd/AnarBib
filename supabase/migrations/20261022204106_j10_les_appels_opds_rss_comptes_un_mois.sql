-- ============================================================================
-- J10 / DOC-GEL-2 — les appels aux flux OPDS et RSS comptés (décision Xavier,
-- 22/10/2026 : « geler en l'état, mesurer un mois avant tout travail »).
--
-- Personne ne sait aujourd'hui si une application lit ces flux : aucune mesure
-- n'existe. Chaque appel servi ajoute un à un compteur du jour — flux, route
-- (racine ou « tout » pour l'OPDS, la bibliothèque pour le RSS) et famille
-- d'application (KOReader, Thorium, un agrégateur, un robot, un navigateur…),
-- déduite de l'en-tête User-Agent par une liste fermée côté Edge Function.
-- AUCUNE donnée personnelle : ni adresse IP, ni User-Agent complet, ni heure ;
-- un compte par jour. Les flux portent un cache HTTP d'une heure : on compte
-- les appels REÇUS, pas les lectures.
--
-- Lecture : à la console, `SELECT * FROM private.flux_appels ORDER BY jour` —
-- relevé du mois le 23/11/2026, puis décision (DOC-GEL-2).
-- Banc : tests/sql/flux_appels_comptes_tests.sql.
-- ============================================================================

CREATE TABLE IF NOT EXISTS private.flux_appels (
  jour   date   NOT NULL,
  flux   text   NOT NULL CHECK (flux IN ('opds', 'rss')),
  route  text   NOT NULL CHECK (route ~ '^[a-z0-9-]{1,64}$'),
  client text   NOT NULL CHECK (client ~ '^[a-z0-9-]{1,32}$'),
  n      bigint NOT NULL DEFAULT 0 CHECK (n >= 0),
  PRIMARY KEY (jour, flux, route, client)
);
ALTER TABLE private.flux_appels ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.flux_appels FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE private.flux_appels IS
  'J10 / DOC-GEL-2 (22/10/2026) : appels reçus par jour aux flux OPDS et RSS, par route et famille d''application ; '
  'aucune donnée personnelle. Relevé le 23/11/2026.';

CREATE OR REPLACE FUNCTION public.fn_flux_compter_v1(p_flux text, p_route text, p_client text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
  IF p_flux IS NULL OR p_flux NOT IN ('opds', 'rss') OR coalesce(p_route, '') !~ '^[a-z0-9-]{1,64}$' THEN
    RAISE EXCEPTION 'Compteur de flux : flux ou route invalide' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.flux_appels (jour, flux, route, client, n)
  VALUES ((now() AT TIME ZONE 'UTC')::date, p_flux, p_route,
          CASE WHEN coalesce(p_client, '') ~ '^[a-z0-9-]{1,32}$' THEN p_client ELSE 'autre' END, 1)
  ON CONFLICT (jour, flux, route, client) DO UPDATE SET n = private.flux_appels.n + 1;
END;
$fn$;

REVOKE ALL ON FUNCTION public.fn_flux_compter_v1(text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_flux_compter_v1(text, text, text) TO service_role;

COMMENT ON FUNCTION public.fn_flux_compter_v1(text, text, text) IS
  'J10 / DOC-GEL-2 (22/10/2026) : ajoute un appel au compteur du jour des flux OPDS/RSS ; service_role seul (Edge Functions opds, rss-novidades).';
