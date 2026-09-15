-- Suite d'acceptation — migration 20260915193525_une_breve_rejetee_dit_pourquoi_et_peut_revenir
--
-- GAZ-7 : un rejet porte un motif et se dit à la personne (si elle a laissé
-- un e-mail), avec un jeton de reprise d'usage unique dont la base ne garde
-- que l'empreinte ; quitter l'état rejeté révoque le jeton ; une reprise se
-- chaîne à son parent et l'avis au réseau le dit. Tout est rejoué sur des
-- lignes insérées ici puis annulé (le DO se termine par RAISE EXCEPTION).
--
-- Ce que le banc ne prouve PAS : l'envoi. La ligne d'outbox part vers
-- fn_gazette_outbox_dispatch_trigger, qui ne trouve pas de secret dans le
-- vault stubé et marque `failed` sans appel réseau — on lit le PAYLOAD, pas
-- le courriel. Le courriel est gardé côté vitest (gazette-decision-mail).

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_avec uuid;
  v_sans uuid;
  v_reprise uuid;
  v_row public.gazette_submissions%rowtype;
  v_pay jsonb;
  v_n int;
  v_txt text;
BEGIN
  -- Fixtures : une brève avec e-mail, une sans. L'INSERT enfile déjà
  -- gazette.contribution.received (avis au réseau) : on ne regarde ensuite
  -- que les événements de décision, par submission_id.
  INSERT INTO public.gazette_submissions(rubric, locale, title, body, contributor_name, contributor_email)
  VALUES ('reseau', 'fr', 'Brève avec e-mail', 'Un texte à relire.', 'Louise', 'louise@test.local')
  RETURNING id INTO v_avec;
  INSERT INTO public.gazette_submissions(rubric, locale, title, body)
  VALUES ('reseau', 'fr', 'Brève sans e-mail', 'Un texte à relire.')
  RETURNING id INTO v_sans;

  -- T1 : rejeter sans motif est refusé par la base (pas seulement par l'écran)
  v_test_name := 'T1 un rejet sans motif est refusé (23514)';
  BEGIN
    UPDATE public.gazette_submissions SET status = 'rejected' WHERE id = v_avec;
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : le rejet est passé sans motif');
  EXCEPTION WHEN check_violation THEN
    v_passed := v_passed + 1;
  END;

  -- T2 : rejet motivé, avec e-mail → jeton posé, événement enfilé, empreinte cohérente
  v_test_name := 'T2 rejet motivé avec e-mail : jeton + événement rejected';
  UPDATE public.gazette_submissions
     SET status = 'rejected', review_note = 'Trop long pour une brève : 300 mots maximum.'
   WHERE id = v_avec;
  SELECT * INTO v_row FROM public.gazette_submissions WHERE id = v_avec;
  SELECT payload INTO v_pay FROM public.gazette_submission_notification_outbox
   WHERE event = 'gazette.contribution.rejected' AND payload->>'submission_id' = v_avec::text;
  IF v_pay IS NULL THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : aucun événement rejected');
  ELSIF v_row.resubmit_token_hash IS NULL OR length(v_row.resubmit_token_hash) <> 64 THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : empreinte absente ou mal formée');
  ELSIF length(coalesce(v_pay->>'resubmit_token', '')) <> 64 THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : jeton absent du payload');
  ELSIF encode(extensions.digest(v_pay->>'resubmit_token', 'sha256'), 'hex') <> v_row.resubmit_token_hash THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : l''empreinte stockée n''est pas celle du jeton envoyé');
  ELSIF v_pay->>'to' <> 'louise@test.local' OR v_pay->>'review_note' NOT LIKE 'Trop long%' OR v_pay->>'locale' <> 'fr' THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : payload incomplet — ' || v_pay::text);
  ELSIF v_row.resubmit_token_expires_at IS NULL
     OR v_row.resubmit_token_expires_at < now() + interval '59 days'
     OR v_row.resubmit_token_expires_at > now() + interval '61 days' THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : échéance hors des 60 jours');
  ELSE
    v_passed := v_passed + 1;
  END IF;

  -- T3 : rejet motivé, SANS e-mail → personne à prévenir : ni jeton, ni événement
  v_test_name := 'T3 rejet sans e-mail : aucun jeton, aucun événement';
  UPDATE public.gazette_submissions
     SET status = 'rejected', review_note = 'Hors sujet pour la page réseau.'
   WHERE id = v_sans;
  SELECT * INTO v_row FROM public.gazette_submissions WHERE id = v_sans;
  SELECT count(*) INTO v_n FROM public.gazette_submission_notification_outbox
   WHERE event IN ('gazette.contribution.rejected', 'gazette.contribution.accepted')
     AND payload->>'submission_id' = v_sans::text;
  IF v_n = 0 AND v_row.resubmit_token_hash IS NULL AND v_row.resubmit_token_expires_at IS NULL THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || format(' : %s événement(s), empreinte %s', v_n, coalesce(v_row.resubmit_token_hash, 'NULL')));
  END IF;

  -- T4 : la reprise se chaîne au parent, et l'avis au réseau le dit
  v_test_name := 'T4 une reprise porte parent_submission_id jusque dans l''avis au réseau';
  INSERT INTO public.gazette_submissions(rubric, locale, title, body, contributor_name, contributor_email, parent_submission_id)
  VALUES ('reseau', 'fr', 'Brève avec e-mail (v2)', 'Un texte plus court.', 'Louise', 'louise@test.local', v_avec)
  RETURNING id INTO v_reprise;
  SELECT payload INTO v_pay FROM public.gazette_submission_notification_outbox
   WHERE event = 'gazette.contribution.received' AND payload->>'submission_id' = v_reprise::text;
  IF v_pay IS NOT NULL AND v_pay->>'parent_submission_id' = v_avec::text THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : parent absent du payload — ' || coalesce(v_pay::text, 'aucun événement'));
  END IF;

  -- T5 : quitter l'état rejeté révoque le jeton ; l'acceptation se dit
  v_test_name := 'T5 accepter révoque le jeton et enfile accepted';
  UPDATE public.gazette_submissions SET status = 'accepted' WHERE id = v_avec;
  SELECT * INTO v_row FROM public.gazette_submissions WHERE id = v_avec;
  SELECT count(*) INTO v_n FROM public.gazette_submission_notification_outbox
   WHERE event = 'gazette.contribution.accepted' AND payload->>'submission_id' = v_avec::text;
  IF v_n = 1 AND v_row.resubmit_token_hash IS NULL AND v_row.resubmit_token_expires_at IS NULL THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || format(' : %s événement(s) accepted, empreinte %s', v_n, coalesce(v_row.resubmit_token_hash, 'NULL')));
  END IF;

  -- T6 : redire le même statut ne redit pas la décision (trigger « OF status »
  -- déclenché dès que la colonne est dans le SET, même à valeur égale)
  v_test_name := 'T6 un UPDATE qui répète le statut n''émet rien';
  UPDATE public.gazette_submissions SET status = 'accepted', reviewed_at = now() WHERE id = v_avec;
  SELECT count(*) INTO v_n FROM public.gazette_submission_notification_outbox
   WHERE event = 'gazette.contribution.accepted' AND payload->>'submission_id' = v_avec::text;
  IF v_n = 1 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || format(' : %s événement(s) accepted', v_n)); END IF;

  -- T7 : les deux fonctions trigger sont fermées à anon et authenticated
  v_test_name := 'T7 fonctions trigger fermées à anon/authenticated';
  SELECT string_agg(p.proname, ', ') INTO v_txt
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN ('fn_gazette_submission_decision_enqueue', 'fn_gazette_submission_enqueue')
    AND (has_function_privilege('anon', p.oid, 'EXECUTE') OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_txt IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore ouvertes — ' || v_txt); END IF;

  -- T8 : l'empreinte est unique (deux rejets ne peuvent pas se confondre)
  v_test_name := 'T8 index unique sur l''empreinte du jeton';
  IF EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public'
              AND indexname = 'gazette_submissions_resubmit_token_hash_uidx'
              AND indexdef ILIKE 'CREATE UNIQUE INDEX%') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : absent ou non unique'); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'GAZETTE_REPRISE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'GAZETTE_REPRISE OK : %/% tests passés', v_passed, v_passed;
END $$;
