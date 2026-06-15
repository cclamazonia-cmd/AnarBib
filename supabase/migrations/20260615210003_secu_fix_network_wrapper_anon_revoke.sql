-- =========================================================================
-- Paquet SECU-MV-FIX — Colmatage : fn_catalog_network_rows interdit à anon
-- =========================================================================
-- Date     : 2026-06-15
-- Chantier : Nettoyage des security advisors Supabase (correctif urgent)
-- Auteur   : AnarBib
-- Session  : Perf UX + nettoyage advisors sécurité
--
-- CONTEXTE (régression introduite par le paquet SECU-MV 20260615210002)
--   Le wrapper SECDEF `fn_catalog_network_rows()` était censé n'être
--   exécutable que par `authenticated`. Mais les DEFAULT PRIVILEGES Supabase
--   ré-accordent EXECUTE à anon/authenticated sur toute nouvelle fonction du
--   schéma `public` AU MOMENT DE SA CRÉATION. Le paquet SECU-MV n'avait fait
--   que `REVOKE ... FROM PUBLIC` (insuffisant, cf. doctrine) → `anon` a
--   conservé EXECUTE.
--   Conséquence : anon pouvait appeler POST /rest/v1/rpc/fn_catalog_network_rows
--   et lire les 2673 lignes réseau (dont ~2174 network-only de Terra Livre)
--   → fuite ROUVERTE au public anonyme (pire que la fuite latente d'origine).
--
-- CORRECTIF
--   REVOKE EXECUTE FROM anon (et PUBLIC par sécurité). `authenticated` garde
--   EXECUTE (la vue session catalog_list_session_v1, security_invoker,
--   l'appelle ; elle applique le filtre d'appartenance réseau par-dessus).
--   Les MV elles-mêmes restent inaccessibles directement (paquet SECU-MV).
-- =========================================================================

BEGIN;

REVOKE EXECUTE ON FUNCTION public.fn_catalog_network_rows() FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- Vérification (rollback si anon peut encore, ou si authenticated ne peut plus)
-- -------------------------------------------------------------------------
DO $verify$
DECLARE
  v_anon boolean;
  v_auth boolean;
BEGIN
  v_anon := has_function_privilege('anon',          'public.fn_catalog_network_rows()', 'EXECUTE');
  v_auth := has_function_privilege('authenticated', 'public.fn_catalog_network_rows()', 'EXECUTE');
  IF v_anon THEN
    RAISE EXCEPTION 'Verif echouee : fn_catalog_network_rows reste executable par anon. Rollback.';
  END IF;
  IF NOT v_auth THEN
    RAISE EXCEPTION 'Verif echouee : fn_catalog_network_rows non executable par authenticated (casserait la vue session). Rollback.';
  END IF;
  RAISE NOTICE 'SECU-MV-FIX OK : network wrapper anon=false, authenticated=true.';
END
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;
