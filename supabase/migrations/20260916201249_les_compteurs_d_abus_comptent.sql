-- 16/09/2026 — B25 / B26 : les compteurs d'abus comptent, et ne savent plus qui.
--
-- Constaté au premier contrôle après la révocation HS256 (16/09) :
--   * la contrainte `auth_rate_limits_kind_check` du socle de mai n'acceptait que
--     'ip' et 'email' ; trois Edge Functions (geocode depuis le 19/06,
--     submit-cartography-entry depuis le 03/09, submit-gazette-contribution
--     depuis le 15/09) écrivaient d'autres kinds sans lire `error` → 23514
--     silencieux, aucun de ces freins n'a jamais bloqué personne (B26) ;
--   * `login` écrivait l'adresse IP et le courriel EN CLAIR comme clé, et son
--     DELETE mettait le courriel dans l'URL, donc dans les journaux edge (B25).
--
-- Désormais la clé est une empreinte SHA-256 (64 hexadécimaux), posée par
-- supabase/functions/_shared/core/rate-limit.ts pour les quatre fonctions, et
-- la table le garde par contrainte. Les lignes brutes existantes (IP et
-- courriels de connexion) sont purgées : elles ne correspondent plus à aucune
-- clé, et elles n'avaient pas à être là.
--
-- Garde CI : tests/sql/compteurs_d_abus_tests.sql.

DO $$
DECLARE
  n_total  int;
  n_brutes int;
BEGIN
  SELECT count(*), count(*) FILTER (WHERE key !~ '^[0-9a-f]{64}$')
    INTO n_total, n_brutes
    FROM public.auth_rate_limits;
  RAISE NOTICE 'auth_rate_limits : % ligne(s), dont % à clé brute (IP ou courriel) — purgées.', n_total, n_brutes;
  DELETE FROM public.auth_rate_limits WHERE key !~ '^[0-9a-f]{64}$';
END
$$;

ALTER TABLE public.auth_rate_limits
  DROP CONSTRAINT IF EXISTS auth_rate_limits_kind_check;

ALTER TABLE public.auth_rate_limits
  ADD CONSTRAINT auth_rate_limits_kind_check
  CHECK (kind = ANY (ARRAY[
    'ip'::text, 'email'::text,               -- login
    'geocode_ip'::text,                      -- geocode
    'carto_ip'::text,                        -- submit-cartography-entry
    'gazette_ip'::text, 'gazette_email'::text, 'gazette_prefill'::text  -- submit-gazette-contribution
  ]));

ALTER TABLE public.auth_rate_limits
  ADD CONSTRAINT auth_rate_limits_key_empreinte
  CHECK (key ~ '^[0-9a-f]{64}$');

COMMENT ON TABLE public.auth_rate_limits IS
  'Compteurs d''abus des Edge Functions (login, geocode, cartographie, gazette). '
  'La clé est une empreinte SHA-256 de l''IP ou du courriel, jamais la valeur : la table ne sait pas qui. '
  'Écrite uniquement par les fonctions (clé secrète) via _shared/core/rate-limit.ts ; fermée à anon et authenticated. '
  'Ajouter un kind = élargir auth_rate_limits_kind_check ET tests/sql/compteurs_d_abus_tests.sql (B25/B26, 16/09/2026).';

COMMENT ON CONSTRAINT auth_rate_limits_key_empreinte ON public.auth_rate_limits IS
  'La clé est une empreinte hexadécimale de 64 caractères : aucune IP ni courriel en clair (B25, 16/09/2026).';
