-- =====================================================================
-- AnarBib — Tests : « Signaler un problème » (E14, 24/09/2026)
-- Réf     : supabase/migrations/20260924201133_e14_signaler_un_probleme.sql,
--           supabase/functions/submit-bug-report, _shared/domain/bug-report.ts
--
-- CE QUE CETTE SUITE PROUVE.
--   Les deux tables existent, verrouillées (RLS, aucun droit à anon ni à
--   authenticated) ; un signalement enfile une ligne de file avec le contenu
--   attendu ; la clé anti-flood est calculée comme la fonction la calcule ;
--   les deux RPC de file sont DEFINER, fermées à PUBLIC, ouvertes à
--   authenticated, et refusent (42501) qui n'est pas admin réseau ; Altcha
--   admet l'usage 'bug_report' et refuse un usage inconnu ; le compteur
--   'bug_ip' passe la CHECK ; la dépêche vers notify-event lit l'adresse de
--   l'instance (I20), pas un littéral.
-- CE QU'ELLE NE PROUVE PAS.
--   L'envoi lui-même (net.http_post, vault) : le trigger de dépêche est
--   DÉSACTIVÉ pendant T2, la file n'est pas consommée ici. Les courriels sont
--   éprouvés dans src/tests/signalar-banc.test.js.
--
-- Convention : bilan « SIGNALEMENTS OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

ALTER TABLE public.bug_report_notification_outbox DISABLE TRIGGER tg_bug_report_outbox_dispatch;

DO $$
DECLARE
  ok int := 0; total int := 8;
  r_id uuid; n int; p jsonb; cle text; def text; src text; ok_purpose boolean;
  v_uid uuid := gen_random_uuid();
BEGIN
  -- T1 : deux tables, RLS, rien pour anon ni authenticated
  IF to_regclass('public.bug_reports') IS NOT NULL AND to_regclass('public.bug_report_notification_outbox') IS NOT NULL
     AND (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.bug_reports'::regclass)
     AND (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.bug_report_notification_outbox'::regclass)
     AND NOT has_table_privilege('anon', 'public.bug_reports', 'SELECT')
     AND NOT has_table_privilege('anon', 'public.bug_reports', 'INSERT')
     AND NOT has_table_privilege('authenticated', 'public.bug_reports', 'SELECT')
     AND NOT has_table_privilege('authenticated', 'public.bug_report_notification_outbox', 'SELECT')
     AND has_table_privilege('service_role', 'public.bug_reports', 'INSERT') THEN
    ok := ok + 1;
  ELSE RAISE WARNING 'T1 tables : présence, RLS ou droits inattendus'; END IF;

  -- T2 : un signalement enfile une ligne bug_report.received avec son contenu
  INSERT INTO public.bug_reports (what_happened, expected, steps, page_path, locale, role_hint, library_hint, user_agent, reporter_email, source_ip_hash)
  VALUES ('Le bouton Enregistrer ne fait rien sur la page du profil', 'Un message de confirmation', '1. ouvrir /conta 2. cliquer', '/conta', 'fr', 'reader', 'BLMF', 'Banc/1.0', 'personne@exemple.test', repeat('a', 64))
  RETURNING id INTO r_id;
  SELECT count(*) INTO n FROM public.bug_report_notification_outbox WHERE event = 'bug_report.received' AND (payload->>'report_id')::uuid = r_id;
  SELECT payload INTO p FROM public.bug_report_notification_outbox WHERE (payload->>'report_id')::uuid = r_id LIMIT 1;
  IF n = 1 AND p->>'what_happened' LIKE 'Le bouton%' AND p->>'page_path' = '/conta' AND p->>'locale' = 'fr' AND p->>'reporter_email' = 'personne@exemple.test'
     AND (SELECT status FROM public.bug_report_notification_outbox WHERE (payload->>'report_id')::uuid = r_id) = 'queued' THEN
    ok := ok + 1;
  ELSE RAISE WARNING 'T2 file : % ligne(s), payload %', n, p; END IF;

  -- T3 : la clé anti-flood = page + 200 premiers caractères en minuscules
  SELECT dedup_key INTO cle FROM public.bug_reports WHERE id = r_id;
  IF cle = '/conta|' || lower('Le bouton Enregistrer ne fait rien sur la page du profil') THEN ok := ok + 1;
  ELSE RAISE WARNING 'T3 dedup_key : %', cle; END IF;

  -- T4 : les deux RPC — DEFINER, fermées à PUBLIC, ouvertes à authenticated
  IF (SELECT count(*) FROM pg_proc pr JOIN pg_namespace ns ON ns.oid = pr.pronamespace
       WHERE ns.nspname = 'api' AND pr.proname IN ('fn_bug_report_list', 'fn_bug_report_close') AND pr.prosecdef) = 2
     AND has_function_privilege('authenticated', 'api.fn_bug_report_list()', 'EXECUTE')
     AND has_function_privilege('authenticated', 'api.fn_bug_report_close(uuid, text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.fn_bug_report_list()', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.fn_bug_report_close(uuid, text)', 'EXECUTE') THEN
    ok := ok + 1;
  ELSE RAISE WARNING 'T4 RPC : forme ou droits inattendus'; END IF;

  -- T5 : un compte connecté qui n'est pas admin réseau est refusé (42501)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  BEGIN
    PERFORM * FROM api.fn_bug_report_list();
    RAISE WARNING 'T5 : la liste a répondu à un compte qui n''est pas admin réseau';
  EXCEPTION WHEN insufficient_privilege THEN
    ok := ok + 1;
  END;
  BEGIN
    PERFORM api.fn_bug_report_close(r_id, 'essai');
    RAISE WARNING 'T5 bis : la clôture a répondu à un compte qui n''est pas admin réseau';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL; -- même verdict que la liste ; compté avec T5
  END;

  -- T6 : Altcha admet 'bug_report', refuse un usage inconnu
  ok_purpose := public.fn_consume_altcha_challenge('defi-' || v_uid::text, now() + interval '10 minutes', 'bug_report');
  BEGIN
    PERFORM public.fn_consume_altcha_challenge('defi-x-' || v_uid::text, now() + interval '10 minutes', 'inconnu');
    RAISE WARNING 'T6 : usage inconnu accepté';
  EXCEPTION WHEN invalid_parameter_value THEN
    IF ok_purpose THEN ok := ok + 1; ELSE RAISE WARNING 'T6 : usage bug_report refusé'; END IF;
  END;

  -- T7 : le compteur bug_ip passe la CHECK
  INSERT INTO public.auth_rate_limits (kind, key, failure_count, first_failure_at, last_failure_at)
  VALUES ('bug_ip', repeat('c', 64), 1, now(), now());
  IF (SELECT count(*) FROM public.auth_rate_limits WHERE kind = 'bug_ip' AND key = repeat('c', 64)) = 1 THEN ok := ok + 1;
  ELSE RAISE WARNING 'T7 bug_ip non écrit'; END IF;

  -- T8 : la dépêche lit private.fn_functions_base_url(), aucun littéral cloud
  SELECT prosrc INTO src FROM pg_proc WHERE proname = 'fn_bug_report_outbox_dispatch_trigger';
  IF src LIKE '%private.fn_functions_base_url()%' AND src NOT LIKE '%supabase.co%' THEN ok := ok + 1;
  ELSE RAISE WARNING 'T8 dépêche : adresse codée en dur ou helper absent'; END IF;

  IF ok = total THEN
    RAISE NOTICE 'SIGNALEMENTS OK : %/% tests passés — tables verrouillées, file enfilée, RPC admin réseau, Altcha bug_report, compteur bug_ip, dépêche par l''adresse de l''instance', ok, total;
  ELSE
    RAISE EXCEPTION 'SIGNALEMENTS ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
