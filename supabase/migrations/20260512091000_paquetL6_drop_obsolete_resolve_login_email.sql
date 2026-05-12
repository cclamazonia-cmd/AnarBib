-- =========================================================================
-- Paquet L.6 — DROP api.resolve_login_email obsolète
-- =========================================================================
-- Contexte : l'audit du chantier linter (session 2026-05-11/12) a révélé
-- deux variantes de resolve_login_email :
--   - api.resolve_login_email(text)    : anon=false, auth=false
--     Marquée OBSOLÈTE depuis 2026-04-28 (commentaire interne)
--     Remplacée par l'Edge Function login-with-identifier qui ne fuit plus
--     l'email résolu au client
--   - public.resolve_login_email(text) : anon=true, auth=true
--     Encore appelée par src/pages/public/LoginPage.jsx ligne 60
--     Conservée en liste blanche anon dans le paquet L.5 (à venir)
--
-- Vérifications préalables (session 2026-05-12 matin) :
--   - V1 : aucune autre fonction ne référence api.resolve_login_email
--   - V3 : aucune RLS ne la référence
--   - V4 : aucune dépendance formelle dans pg_depend
--
-- Risque : nul. La fonction est totalement isolée et révoquée à tous les
-- rôles depuis 2026-04-28.
--
-- En cas de besoin de rollback (extrêmement improbable), la fonction peut
-- être recréée depuis l'historique Git :
--   git log --all --diff-filter=A -- supabase/migrations/ |
--     grep -i "api.resolve_login_email"
-- =========================================================================

BEGIN;

DROP FUNCTION IF EXISTS api.resolve_login_email(text);

-- Trace dans les logs Supabase pour audit
DO $$
BEGIN
  RAISE NOTICE 'Paquet L.6 : api.resolve_login_email(text) supprimée. '
               'public.resolve_login_email(text) reste en place pour LoginPage.jsx.';
END $$;

COMMIT;

-- =========================================================================
-- Post-conditions attendues
-- =========================================================================
-- - Le linter Supabase ne signale plus api.resolve_login_email dans la
--   catégorie anon_security_definer_function_executable
-- - Le login utilisateur continue de fonctionner (utilise public.resolve_login_email)
-- - Vérification :
--     SELECT proname, pronamespace::regnamespace
--     FROM pg_proc
--     WHERE proname = 'resolve_login_email';
--   Résultat attendu : une seule ligne, public.resolve_login_email
-- =========================================================================
