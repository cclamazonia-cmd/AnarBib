-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — un site est une adresse web (19/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- RÈGLE POSÉE. Les colonnes site_url de la cartographie (fiches et
-- propositions) et des réseaux n'admettent qu'une adresse http(s) sans
-- espace ni guillemet — sur le modèle de library_commons_website_url_chk.
-- Les mêmes adresses sont rendues comme liens (popups de la carte, fiches) :
-- un autre schéma n'a rien à y faire.
--
-- Données vérifiées en production le 19/10 : 121 sites de fiches, 6 de
-- réseaux, aucune proposition — tous conformes. Les contraintes sont donc
-- posées et validées d'emblée.
--
-- Côté application, la même règle vit dans src/lib/html.js
-- (normaliserUrlWeb, urlWebSure) et dans l'Edge Function
-- submit-cartography-entry ; « exemple.org » y est complété en https://.
-- Tests : tests/sql/un_site_est_une_adresse_web_tests.sql.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE public.cartography_entries DROP CONSTRAINT IF EXISTS cartography_entries_site_url_chk;
ALTER TABLE public.cartography_entries ADD CONSTRAINT cartography_entries_site_url_chk
  CHECK (site_url IS NULL OR site_url ~* '^https?://[^[:space:]<>"''`]+$');

ALTER TABLE public.cartography_submissions DROP CONSTRAINT IF EXISTS cartography_submissions_site_url_chk;
ALTER TABLE public.cartography_submissions ADD CONSTRAINT cartography_submissions_site_url_chk
  CHECK (site_url IS NULL OR site_url ~* '^https?://[^[:space:]<>"''`]+$');

ALTER TABLE public.networks DROP CONSTRAINT IF EXISTS networks_site_url_chk;
ALTER TABLE public.networks ADD CONSTRAINT networks_site_url_chk
  CHECK (site_url IS NULL OR site_url ~* '^https?://[^[:space:]<>"''`]+$');

DO $verif$
BEGIN
  IF (SELECT count(*) FROM pg_constraint
       WHERE conname IN ('cartography_entries_site_url_chk', 'cartography_submissions_site_url_chk', 'networks_site_url_chk')
         AND convalidated) <> 3 THEN
    RAISE EXCEPTION 'un site est une adresse web : contrainte absente ou non validée';
  END IF;
END $verif$;

COMMIT;
