-- ═══════════════════════════════════════════════════════════════════════════
-- Migration : table auth_rate_limits (anti-bruteforce / anti-énumération)
-- Date      : 2026-05-05
-- ═══════════════════════════════════════════════════════════════════════════
--
-- CONTEXTE
-- --------
-- Stocke les tentatives échouées de login pour appliquer un rate limit
-- combiné par IP (anti-bruteforce général) et par email (anti-énumération).
-- Lue et écrite uniquement par l'Edge Function `login` (SECURITY DEFINER).
--
-- STRATÉGIE
-- ---------
-- Une ligne par couple (kind, key) :
--   - kind = 'ip'    → key = adresse IP source (extraite des headers x-real-ip / cf-connecting-ip)
--   - kind = 'email' → key = email tenté (lowercased + trimmed)
--
-- Seuils :
--   - IP    : 10 échecs / 15 min → blocage 1h
--   - Email : 5  échecs / 30 min → blocage 1h
--
-- Politique d'écriture :
--   - login échoué → INSERT ou UPDATE avec last_failure_at = now() et increment failure_count
--   - login réussi → DELETE des lignes correspondantes (reset)
--   - Vieilles lignes (last_failure_at > 1h dans le passé sans blocage actif) :
--     nettoyées par cron (à mettre en place ultérieurement, optionnel)
--
-- ACCÈS
-- -----
-- RLS activée mais aucune policy : la table est inaccessible via REST.
-- Seule l'Edge Function `login` (SECURITY DEFINER + service_role key) y accède.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
  kind            text        NOT NULL CHECK (kind IN ('ip', 'email')),
  key             text        NOT NULL,
  failure_count   integer     NOT NULL DEFAULT 0,
  first_failure_at timestamptz NOT NULL DEFAULT now(),
  last_failure_at timestamptz NOT NULL DEFAULT now(),
  blocked_until   timestamptz,
  PRIMARY KEY (kind, key)
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_limits_blocked_until
  ON public.auth_rate_limits (blocked_until)
  WHERE blocked_until IS NOT NULL;

COMMENT ON TABLE public.auth_rate_limits IS
  'Compteurs anti-bruteforce/anti-énumération pour l''Edge Function login. '
  'Une ligne par couple (kind=ip|email, key). RLS activée sans policy : '
  'accessible uniquement via SECURITY DEFINER (service_role).';

-- RLS activée mais zéro policy : table imprenable via REST API
ALTER TABLE public.auth_rate_limits ENABLE ROW LEVEL SECURITY;

-- Aucune policy n'est créée. C'est volontaire : seule l'Edge Function
-- avec service_role key (qui contourne les RLS) peut y accéder.

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION POST-MIGRATION
-- ═══════════════════════════════════════════════════════════════════════════
-- 1. La table existe et RLS est activée :
--   SELECT relname, relrowsecurity FROM pg_class WHERE relname = 'auth_rate_limits';
--   -- attendu : (auth_rate_limits, t)
--
-- 2. Aucune policy (table imprenable via REST) :
--   SELECT polname FROM pg_policy WHERE polrelid = 'public.auth_rate_limits'::regclass;
--   -- attendu : 0 lignes
--
-- 3. Test fonctionnel (depuis service_role) :
--   INSERT INTO public.auth_rate_limits (kind, key, failure_count) 
--   VALUES ('ip', '127.0.0.1', 1);
--   SELECT * FROM public.auth_rate_limits;
--   DELETE FROM public.auth_rate_limits WHERE key = '127.0.0.1';
