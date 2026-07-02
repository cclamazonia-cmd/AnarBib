-- =========================================================================
-- Paquet DURCISSEMENT-GRANTS #2b — correctif : retirer le GRANT PUBLIC oublié
-- =========================================================================
-- Date     : 2026-07-02
-- Chantier : advisor Supabase 0028 — suite corrective de 20260702103557
--
-- Bug : 20260702103557 a fait « REVOKE ... FROM anon » (groupe A) / « FROM anon,
-- authenticated » (groupe B). Or 3 fonctions tenaient leur accès `anon` du grant
-- par défaut à **PUBLIC** (ACL « =X/postgres »), pas d'un grant `anon` direct.
-- Un REVOKE FROM anon ne retire PAS le grant PUBLIC -> ces 3 restaient
-- exécutables par anon (qui hérite de PUBLIC). Vérifié via pg_proc.proacl.
--
-- Les 46 autres cibles avaient un grant `anon` direct -> déjà correctement
-- durcies. Seules ces 3 nécessitent le retrait de PUBLIC :
--
--   * fn_ensure_library_theme(uuid)          [groupe A — action staff]
--       ACL: {=X, authenticated=X, ...}. On retire PUBLIC uniquement ; le grant
--       `authenticated` DIRECT subsiste -> l'appel front (staff) reste OK.
--   * fn_gazette_build_call(text, integer)   [groupe B — cron]
--   * fn_rede_digest_call()                  [groupe B — cron]
--       ACL: {=X, ...} sans grant client direct. On retire PUBLIC (+ anon,
--       authenticated par prudence) -> plus aucun rôle client.
--
-- `service_role`, owner et `postgres` conservent leurs droits.
-- Idempotent, forward-only.
-- =========================================================================

BEGIN;

-- Groupe A : retirer PUBLIC, garder le grant authenticated direct
REVOKE EXECUTE ON FUNCTION public.fn_ensure_library_theme(uuid) FROM PUBLIC;

-- Groupe B (cron) : retirer PUBLIC + tout rôle client
REVOKE EXECUTE ON FUNCTION public.fn_gazette_build_call(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_rede_digest_call()               FROM PUBLIC, anon, authenticated;

COMMIT;
