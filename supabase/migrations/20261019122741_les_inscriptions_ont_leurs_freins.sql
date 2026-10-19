-- 19/10/2026 — les inscriptions ont leurs freins.
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- L'Edge Function register compte désormais ses appels (freiner(),
-- _shared/core/rate-limit.ts) : par adresse IP lue dans un en-tête fiable
-- (_shared/core/ip-client.ts, kind 'register_ip') et par adresse destinataire
-- (kind 'register_dest'). Les deux kinds entrent dans la liste fermée.
--
-- Garde CI : tests/sql/compteurs_d_abus_tests.sql ; côté fonctions,
-- src/tests/adresse-sortante.test.js vérifie que chaque kind écrit par
-- freiner() figure dans cette contrainte.

BEGIN;

ALTER TABLE public.auth_rate_limits DROP CONSTRAINT IF EXISTS auth_rate_limits_kind_check;
ALTER TABLE public.auth_rate_limits
  ADD CONSTRAINT auth_rate_limits_kind_check
  CHECK (kind = ANY (ARRAY[
    'ip'::text, 'email'::text,               -- login
    'geocode_user'::text,                    -- geocode (B45, 13/10/2026 ; 'geocode_ip' avant)
    'carto_ip'::text,                        -- submit-cartography-entry
    'gazette_ip'::text, 'gazette_email'::text, 'gazette_prefill'::text,  -- submit-gazette-contribution
    'bug_ip'::text,                          -- submit-bug-report (E14, 24/09/2026)
    'register_ip'::text, 'register_dest'::text  -- register (19/10/2026)
  ]));
COMMENT ON TABLE public.auth_rate_limits IS
  'Compteurs d''abus des Edge Functions (login, inscription, geocode par compte, cartographie, gazette, signalements). '
  'Ajouter un kind = élargir auth_rate_limits_kind_check ET tests/sql/compteurs_d_abus_tests.sql (B25/B26, 16/09/2026 ; E14, 24/09/2026 ; B45, 13/10/2026 ; 19/10/2026).';

-- ─── Vérification ─────────────────────────────────────────────────────────────
DO $$
DECLARE c text;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO c FROM pg_constraint WHERE conname = 'auth_rate_limits_kind_check';
  IF c IS NULL OR position('register_ip' IN c) = 0 OR position('register_dest' IN c) = 0 THEN
    RAISE EXCEPTION 'les kinds register_ip / register_dest ne sont pas admis';
  END IF;
END $$;

COMMIT;
