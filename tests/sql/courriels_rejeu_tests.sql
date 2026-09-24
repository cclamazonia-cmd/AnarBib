-- =====================================================================
-- AnarBib — Tests : un courriel refusé est rejoué, borné, puis abandonné et acquitté (F12)
-- Date    : 2026-09-25
-- Réf     : supabase/migrations/20260924214108_f12_rejeu_des_courriels_refuses.sql
--           src/tests/courriels-rejeu-banc.test.js (le rejeu par destinataire, côté code)
--
-- CE QUE CETTE SUITE PROUVE.
--   Les cinq files portent refused_recipients et next_attempt_at, et admettent
--   l'état « abandoned » ; une ligne qui passe à « failed » reçoit son prochain
--   essai selon le recul (15 min après le premier), une ligne servie le perd ;
--   private.fn_outbox_rejouer() abandonne une ligne à quatre essais et laisse en
--   paix une ligne dont l'heure n'est pas venue ; la sonde des notifications
--   compte à part « dont_en_rejeu » et « dont_abandonnees » ; l'acquittement est
--   refusé à qui n'est pas admin réseau, exige une raison, et fait sortir la ligne
--   (skipped, raison écrite) ; les droits sont fermés.
-- CE QU'ELLE NE PROUVE PAS.
--   Le POST vers notify-event (pg_net) : les triggers de dépêche sont désactivés
--   le temps de la suite, et le secret du webhook n'existe pas en CI. Le rejeu
--   par destinataire est éprouvé dans le banc vitest.
--
-- Convention : bilan « COURRIELS-REJEU OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

ALTER TABLE public.cartography_submission_notification_outbox DISABLE TRIGGER tg_cartography_outbox_dispatch;
ALTER TABLE public.lettre_notification_outbox DISABLE TRIGGER trg_lettre_outbox_dispatch;

DO $$
DECLARE
  ok int := 0; total int := 9;
  v_f text; v_n int; v_id bigint; v_id2 bigint; v_t timestamptz; v_res jsonb; v_sonde jsonb; v_raison text;
  v_admin uuid := '11111111-1111-1111-1111-111111111111';  -- compte du seed
  v_autre uuid := gen_random_uuid();
BEGIN
  -- T1 : les cinq files portent les deux colonnes et admettent « abandoned »
  SELECT count(*) INTO v_n
    FROM unnest(ARRAY['team_notification_outbox','lettre_notification_outbox','gazette_submission_notification_outbox',
                      'cartography_submission_notification_outbox','bug_report_notification_outbox']) f(t)
   WHERE (SELECT count(*) FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = f.t AND column_name IN ('refused_recipients', 'next_attempt_at')) = 2
     AND EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = ('public.' || f.t)::regclass AND k.contype = 'c'
                  AND pg_get_constraintdef(k.oid) LIKE '%status%' AND pg_get_constraintdef(k.oid) LIKE '%abandoned%')
     AND EXISTS (SELECT 1 FROM pg_trigger g WHERE g.tgrelid = ('public.' || f.t)::regclass AND g.tgname = 'tg_outbox_programmer_rejeu');
  IF v_n = 5 THEN ok := ok + 1; ELSE RAISE WARNING 'T1 : % file(s) sur 5 conformes', v_n; END IF;

  -- T2 : passer à « failed » programme le prochain essai (15 min après le premier) ; « sent » l'efface
  INSERT INTO public.lettre_notification_outbox (event, payload, status, attempts) VALUES ('lettre.essai', '{}', 'queued', 1) RETURNING id INTO v_id;
  UPDATE public.lettre_notification_outbox SET status = 'failed', last_error = 'essai', refused_recipients = ARRAY['x@exemple.test'] WHERE id = v_id;
  SELECT next_attempt_at INTO v_t FROM public.lettre_notification_outbox WHERE id = v_id;
  IF v_t BETWEEN now() + interval '14 minutes' AND now() + interval '16 minutes' THEN
    UPDATE public.lettre_notification_outbox SET status = 'sent', sent_at = now() WHERE id = v_id;
    SELECT next_attempt_at INTO v_t FROM public.lettre_notification_outbox WHERE id = v_id;
    IF v_t IS NULL THEN ok := ok + 1; ELSE RAISE WARNING 'T2 : next_attempt_at non effacé sur une ligne servie'; END IF;
  ELSE RAISE WARNING 'T2 : next_attempt_at = %', v_t; END IF;

  -- T3 : le recul — 1 h après le deuxième essai, 6 h après le troisième
  INSERT INTO public.lettre_notification_outbox (event, payload, status, attempts) VALUES ('lettre.essai', '{}', 'queued', 3) RETURNING id INTO v_id;
  UPDATE public.lettre_notification_outbox SET status = 'failed', last_error = 'essai' WHERE id = v_id;
  SELECT next_attempt_at INTO v_t FROM public.lettre_notification_outbox WHERE id = v_id;
  IF v_t BETWEEN now() + interval '5 hours 59 minutes' AND now() + interval '6 hours 1 minute'
     AND private.fn_outbox_prochain_essai(2) = interval '1 hour' THEN ok := ok + 1;
  ELSE RAISE WARNING 'T3 : recul inattendu (%)', v_t; END IF;

  -- T4 : le rejeu abandonne une ligne à quatre essais, laisse en paix une ligne dont l'heure n'est pas venue
  INSERT INTO public.cartography_submission_notification_outbox (event, payload, status, attempts, created_at)
  VALUES ('cartography.submission_received', '{}', 'queued', 4, now() - interval '1 day') RETURNING id INTO v_id;
  UPDATE public.cartography_submission_notification_outbox SET status = 'failed', last_error = 'panne' WHERE id = v_id;
  INSERT INTO public.cartography_submission_notification_outbox (event, payload, status, attempts, created_at)
  VALUES ('cartography.submission_received', '{}', 'queued', 1, now() - interval '1 day') RETURNING id INTO v_id2;
  UPDATE public.cartography_submission_notification_outbox SET status = 'failed', last_error = 'panne' WHERE id = v_id2;
  v_res := private.fn_outbox_rejouer();
  IF (SELECT status FROM public.cartography_submission_notification_outbox WHERE id = v_id) = 'abandoned'
     AND (SELECT status FROM public.cartography_submission_notification_outbox WHERE id = v_id2) = 'failed'
     AND (v_res->'abandonnees'->>'cartography_submission_notification_outbox')::int >= 1 THEN ok := ok + 1;
  ELSE RAISE WARNING 'T4 : rejeu inattendu — %', v_res; END IF;

  -- T5 : la sonde distingue le rejeu de l'abandon
  v_sonde := public.fn_healthcheck_notifications();
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_sonde->'files_non_traitees') e
   WHERE e->>'file' = 'cartography_submission_notification_outbox'
     AND (e->>'dont_abandonnees')::int >= 1 AND (e->>'dont_en_rejeu')::int >= 1;
  IF v_n = 1 AND (v_sonde->>'ok')::boolean = false THEN ok := ok + 1;
  ELSE RAISE WARNING 'T5 : sonde — %', v_sonde->'files_non_traitees'; END IF;

  -- T6 : l'acquittement est refusé à qui n'est pas admin réseau
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM api.fn_outbox_acquitter('cartography_submission_notification_outbox', v_id, 'essai');
    RAISE WARNING 'T6 : acquittement accepté pour un compte ordinaire';
  EXCEPTION WHEN insufficient_privilege THEN ok := ok + 1;
  END;

  -- T7 : l'admin réseau doit donner une raison ; avec elle, la ligne sort (skipped, raison écrite)
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM api.fn_outbox_acquitter('cartography_submission_notification_outbox', v_id, '   ');
    RAISE WARNING 'T7 : acquittement sans raison accepté';
  EXCEPTION WHEN invalid_parameter_value THEN
    SELECT count(*) INTO v_n FROM api.fn_outbox_abandonnees() a WHERE a.id = v_id;
    PERFORM api.fn_outbox_acquitter('cartography_submission_notification_outbox', v_id, 'adresse fermée, prévenue autrement');
    SELECT skip_reason INTO v_raison FROM public.cartography_submission_notification_outbox WHERE id = v_id AND status = 'skipped';
    IF v_n = 1 AND v_raison LIKE 'abandonné après 4 essais, acquitté le %adresse fermée%' THEN ok := ok + 1;
    ELSE RAISE WARNING 'T7 : liste % / raison %', v_n, v_raison; END IF;
  END;

  -- T8 : une file inconnue est refusée (pas d'identifiant de table libre)
  BEGIN
    PERFORM api.fn_outbox_acquitter('profiles', 1, 'essai');
    RAISE WARNING 'T8 : file inconnue acceptée';
  EXCEPTION WHEN invalid_parameter_value THEN ok := ok + 1;
  END;

  -- T9 : droits — le rejeu et le recul fermés à tous les rôles de l'API, les deux RPC à anon
  IF NOT has_function_privilege('authenticated', 'private.fn_outbox_rejouer()', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'private.fn_outbox_rejouer()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'private.fn_outbox_programmer_rejeu()', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.fn_outbox_acquitter(text, bigint, text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.fn_outbox_abandonnees()', 'EXECUTE')
     AND has_function_privilege('authenticated', 'api.fn_outbox_acquitter(text, bigint, text)', 'EXECUTE') THEN ok := ok + 1;
  ELSE RAISE WARNING 'T9 : droits inattendus'; END IF;

  IF ok = total THEN
    RAISE NOTICE 'COURRIELS-REJEU OK : %/% tests passés — colonnes et état final, recul, abandon à quatre essais, sonde qui distingue, acquittement réservé et motivé', ok, total;
  ELSE
    RAISE EXCEPTION 'COURRIELS-REJEU ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
