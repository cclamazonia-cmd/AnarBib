-- =========================================================================
-- Durcissement sécurité — REVOKE EXECUTE sur 7 fonctions-trigger SECDEF (anon/auth)
-- =========================================================================
-- Date     : 2026-06-19
-- Chantier : Audit 360° — durcissement P3 (préparation Bologne) ; « triage REVOKE
--            ciblé » (PAS de revoke de masse — cf. doctrine advisors DEFINER
--            intentionnels). Suite du lot-1-triggers du 15/06.
-- Auteur    : AnarBib · Session : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
--
-- POURQUOI
--   Les advisors signalent ces 7 fonctions en
--   anon_security_definer_function_executable / authenticated_…. Or ce sont des
--   fonctions-TRIGGER (RETURNS trigger, sans argument) : PostgreSQL REFUSE de les
--   appeler directement (« trigger functions can only be called as triggers »).
--   Le GRANT EXECUTE à anon/authenticated y est donc INERTE — le retirer ne change
--   RIEN au fonctionnement (les triggers se déclenchent via le mécanisme de trigger,
--   en tant que owner postgres), mais réduit la surface affichée et nettoie les
--   advisors. AUCUN risque : vérifié RETURNS trigger pour les 7 (lecture live 19/06).
--
-- Ne touche QUE ces 7 fonctions explicitement nommées (zéro effet de bord).
-- =========================================================================

REVOKE EXECUTE ON FUNCTION "public"."fn_cartography_outbox_dispatch_trigger"() FROM PUBLIC, "anon", "authenticated";
REVOKE EXECUTE ON FUNCTION "public"."fn_cartography_submission_enqueue"() FROM PUBLIC, "anon", "authenticated";
REVOKE EXECUTE ON FUNCTION "public"."fn_entraide_notify_circle_on_insert"() FROM PUBLIC, "anon", "authenticated";
REVOKE EXECUTE ON FUNCTION "public"."fn_lettre_outbox_dispatch_trigger"() FROM PUBLIC, "anon", "authenticated";
REVOKE EXECUTE ON FUNCTION "public"."fn_subjects_guard_status"() FROM PUBLIC, "anon", "authenticated";
REVOKE EXECUTE ON FUNCTION "public"."fn_sync_consulta_header_from_lines"() FROM PUBLIC, "anon", "authenticated";
REVOKE EXECUTE ON FUNCTION "public"."fn_sync_reserva_header_from_lines"() FROM PUBLIC, "anon", "authenticated";

-- Smoke (db push) : les 7 ne doivent plus être exécutables par anon NI authenticated.
-- (Elles restent pleinement fonctionnelles comme triggers — owner postgres.)
DO $smoke$
DECLARE v_bad int;
BEGIN
  SELECT count(*) INTO v_bad
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_cartography_outbox_dispatch_trigger','fn_cartography_submission_enqueue',
      'fn_entraide_notify_circle_on_insert','fn_lettre_outbox_dispatch_trigger',
      'fn_subjects_guard_status','fn_sync_consulta_header_from_lines','fn_sync_reserva_header_from_lines')
    AND (has_function_privilege('anon', p.oid, 'EXECUTE')
         OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_bad <> 0 THEN
    RAISE EXCEPTION 'SECU SMOKE ECHEC : % fonction(s) trigger encore exécutable(s) anon/authenticated', v_bad;
  END IF;
  RAISE NOTICE 'SECU SMOKE OK : 7 fonctions-trigger non exécutables anon/authenticated.';
END;
$smoke$;
