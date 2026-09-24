-- ============================================================================
-- E14, suite (24/09/2026) — les deux fonctions de trigger du signalement se ferment
-- à authenticated, anon et PUBLIC.
--
-- Attrapé par tests/sql/salle_des_machines_tests.sql sur la forge (run 9812451),
-- vingt minutes après le déploiement de 20260924201133 : « vault atteignable via
-- public.fn_bug_report_outbox_dispatch_trigger » et « http sortant hors
-- exceptions ». Cause : le schéma public porte un PRIVILÈGE PAR DÉFAUT
-- (pg_default_acl : postgres → {authenticated=X, service_role=X}) — toute fonction
-- neuve y naît exécutable par authenticated, et un `REVOKE … FROM PUBLIC` ne
-- retire pas ce grant nominatif. Les fonctions de cartography (juin) avaient été
-- fermées par la campagne B14 ; les miennes, créées ce soir, ne l'étaient pas.
-- Risque réel : nul — une fonction RETURNS trigger ne s'appelle pas directement
-- (« trigger functions can only be called as triggers ») ; le garde est
-- structurel et il a raison de ne pas faire cette distinction. Leçon : sur
-- public, REVOKE FROM authenticated ET anon ET PUBLIC, explicitement, à chaque
-- DEFINER neuve. La suite signalements_tests le garde désormais (T9).
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.fn_bug_report_enqueue() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_bug_report_outbox_dispatch_trigger() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  IF has_function_privilege('authenticated', 'public.fn_bug_report_enqueue()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_bug_report_outbox_dispatch_trigger()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_bug_report_outbox_dispatch_trigger()', 'EXECUTE') THEN
    RAISE EXCEPTION 'E14 : les fonctions de trigger doivent être fermées à authenticated et anon';
  END IF;
END $$;
