-- 13/10/2026 — B45 : le géocodage compte par compte, plus par adresse IP.
--
-- Depuis B44 (dbe8dc28), geocode exige une vraie session : le compteur par
-- adresse IP (kind 'geocode_ip') n'était plus la seule prise, et il gênait —
-- tout le local d'une bibliothèque derrière une même box partageait 40
-- géocodages par heure, et un en-tête x-forwarded-for se choisit. La fonction
-- compte désormais par compte : kind 'geocode_user', clé = SHA-256 du `sub` du
-- jeton (supabase/functions/geocode/index.ts, _shared/core/session-reelle.ts).
--
-- 'geocode_ip' quitte la liste fermée : plus aucune fonction ne l'écrit. Ses
-- lignes éventuelles (des compteurs d'une heure, aucune en production le
-- 13/10) sont supprimées d'abord, sans quoi la contrainte ne se poserait pas
-- sur une pile auto-hébergée qui en aurait.
--
-- Garde CI : tests/sql/compteurs_d_abus_tests.sql ; côté fonctions,
-- src/tests/adresse-sortante.test.js vérifie que chaque kind écrit par
-- freiner() figure dans cette contrainte.

BEGIN;

DELETE FROM public.auth_rate_limits WHERE kind = 'geocode_ip';

ALTER TABLE public.auth_rate_limits DROP CONSTRAINT IF EXISTS auth_rate_limits_kind_check;
ALTER TABLE public.auth_rate_limits
  ADD CONSTRAINT auth_rate_limits_kind_check
  CHECK (kind = ANY (ARRAY[
    'ip'::text, 'email'::text,               -- login
    'geocode_user'::text,                    -- geocode (B45, 13/10/2026 ; 'geocode_ip' avant)
    'carto_ip'::text,                        -- submit-cartography-entry
    'gazette_ip'::text, 'gazette_email'::text, 'gazette_prefill'::text,  -- submit-gazette-contribution
    'bug_ip'::text                           -- submit-bug-report (E14, 24/09/2026)
  ]));
COMMENT ON TABLE public.auth_rate_limits IS
  'Compteurs d''abus des Edge Functions (login, geocode par compte, cartographie, gazette, signalements). '
  'Ajouter un kind = élargir auth_rate_limits_kind_check ET tests/sql/compteurs_d_abus_tests.sql (B25/B26, 16/09/2026 ; E14, 24/09/2026 ; B45, 13/10/2026).';

-- ─── Vérification ─────────────────────────────────────────────────────────────
DO $$
DECLARE c text;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO c FROM pg_constraint WHERE conname = 'auth_rate_limits_kind_check';
  IF c IS NULL OR position('geocode_user' IN c) = 0 THEN
    RAISE EXCEPTION 'B45 : le kind geocode_user n''est pas admis';
  END IF;
  IF position('geocode_ip' IN c) > 0 THEN
    RAISE EXCEPTION 'B45 : le kind geocode_ip est encore admis';
  END IF;
END $$;

COMMIT;
