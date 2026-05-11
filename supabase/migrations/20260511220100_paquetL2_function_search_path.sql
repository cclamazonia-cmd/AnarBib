-- =========================================================================
-- Paquet L.2 — Fixer search_path sur les 14 fonctions mutables (v2)
-- =========================================================================
-- Contexte : le linter Supabase détecte 14 fonctions sans `search_path` fixé.
-- Une fonction sans search_path explicite expose une surface d'attaque par
-- search_path hijacking (un schéma malveillant en tête de path pourrait
-- intercepter un appel de fonction non qualifié). La bonne pratique est de
-- forcer search_path à `public, pg_catalog`.
--
-- v2 : signatures vérifiées via pg_get_function_identity_arguments (2026-05-11).
-- Corrections vs v1 :
--   - fn_check_loan_action  : (text, text, text) au lieu de (bigint, text)
--   - fn_set_retention_policy : (uuid, integer, integer, integer, integer, text)
--                               au lieu de (uuid, jsonb)
--   - fn_internal_previous_iso_week : (date) au lieu de ()
--   - fn_format_holding_refs : (bigint[]) au lieu de (jsonb)
--
-- Risque : nul. Option de fonction, pas de changement de logique.
-- =========================================================================

BEGIN;

-- Fonctions utilitaires de recherche / formatage
ALTER FUNCTION public.f_normalize_search(text)
  SET search_path = public, pg_catalog;

ALTER FUNCTION public.fn_format_holding_refs(bigint[])
  SET search_path = public, pg_catalog;

-- Fonctions de contexte (loan, consulta, retention)
ALTER FUNCTION public.fn_get_loan_context(bigint)
  SET search_path = public, pg_catalog;

ALTER FUNCTION public.fn_get_consulta_context(bigint)
  SET search_path = public, pg_catalog;

ALTER FUNCTION public.fn_get_retention_policy(uuid)
  SET search_path = public, pg_catalog;

ALTER FUNCTION public.fn_set_retention_policy(
  uuid, integer, integer, integer, integer, text
) SET search_path = public, pg_catalog;

-- Fonction de vérification d'action de prêt
ALTER FUNCTION public.fn_check_loan_action(text, text, text)
  SET search_path = public, pg_catalog;

-- Fonction utilitaire calendaire
ALTER FUNCTION public.fn_internal_previous_iso_week(date)
  SET search_path = public, pg_catalog;

-- Triggers de mise à jour updated_at (sans arguments)
ALTER FUNCTION public.tg_set_updated_at_lmr()
  SET search_path = public, pg_catalog;

ALTER FUNCTION public.tg_set_updated_at_mp()
  SET search_path = public, pg_catalog;

ALTER FUNCTION public.tg_network_administrators_updated_at()
  SET search_path = public, pg_catalog;

ALTER FUNCTION public.tg_library_retention_policies_updated_at()
  SET search_path = public, pg_catalog;

-- Triggers de log et d'audit immutables (sans arguments)
ALTER FUNCTION public.tg_network_administrator_audit_immutable()
  SET search_path = public, pg_catalog;

ALTER FUNCTION public.tg_cross_lib_log_immutable()
  SET search_path = public, pg_catalog;

COMMIT;

-- =========================================================================
-- Post-conditions attendues
-- =========================================================================
-- - Le linter Supabase ne doit plus signaler aucune alerte
--   `function_search_path_mutable` pour ces 14 fonctions
-- - Aucun changement de comportement runtime
-- - Vérification rapide après application :
--     SELECT proname, proconfig
--     FROM pg_proc
--     WHERE pronamespace = 'public'::regnamespace
--       AND proname IN (
--         'f_normalize_search','fn_format_holding_refs','fn_get_loan_context',
--         'fn_get_consulta_context','fn_get_retention_policy','fn_set_retention_policy',
--         'fn_check_loan_action','fn_internal_previous_iso_week',
--         'tg_set_updated_at_lmr','tg_set_updated_at_mp',
--         'tg_network_administrators_updated_at','tg_library_retention_policies_updated_at',
--         'tg_network_administrator_audit_immutable','tg_cross_lib_log_immutable'
--       );
--   La colonne proconfig doit contenir 'search_path=public, pg_catalog' pour
--   chacune des 14 lignes.
-- =========================================================================
