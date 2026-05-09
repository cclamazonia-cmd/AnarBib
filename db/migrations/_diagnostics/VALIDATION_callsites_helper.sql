-- ============================================================================
-- VALIDATION_callsites_helper.sql
-- ============================================================================
-- À LANCER AVANT d'appliquer paquet6_fix_double_mails_optionD.sql
-- pour vérifier que tous les callsites de fn_v2_set_reserva_linhas_workflow
-- sont bien identifiés. La liste attendue (5 RPC affectés + 1 propre) :
--   - api.advance_reservation                  ← refactorée par le patch
--   - api.fn_propose_pickup_slot_as_library    ← refactorée par le patch
--   - api.fn_propose_pickup_slot_as_reader     ← refactorée par le patch
--   - api.fn_confirm_pickup_slot_as_library    ← refactorée par le patch
--   - api.fn_confirm_pickup_slot_as_reader     ← refactorée par le patch
--   - api.mark_no_show                         ← propre, pas de refactor
--
-- Si tu vois autre chose, signale-le avant d'appliquer le patch.
-- ============================================================================

-- Note technique : on utilise prosrc (le code source brut) au lieu de
-- pg_get_functiondef() qui plante actuellement sur cette base sur certaines
-- fonctions (erreur 42809 array_agg). Le filtre nspname IN ('public', 'api')
-- exclut les schémas système qui ne nous concernent pas et qui pourraient
-- héberger la fonction qui fait planter l'introspection.

SELECT 
  n.nspname AS schema, 
  p.proname AS routine_name,
  pg_get_function_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.prosrc ILIKE '%fn_v2_set_reserva_linhas_workflow%'
  AND p.proname <> 'fn_v2_set_reserva_linhas_workflow'
  AND n.nspname IN ('public', 'api')
ORDER BY n.nspname, p.proname;
