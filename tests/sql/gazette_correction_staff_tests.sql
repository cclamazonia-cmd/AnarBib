-- Suite d'acceptation — migration 20260915211224_le_staff_corrige_une_breve_avant_de_la_retenir
--
-- GAZ-9 : entre accepter tel quel et rejeter, le staff peut corriger une
-- brève et la retenir. La correction est tracée (qui, quand, version de la
-- personne gardée UNE fois), la traduction repart quand le texte change (pas
-- pour un lien seul), et l'acceptation dit à la personne que sa brève est
-- retenue AVEC corrections, texte à l'appui. Tout est annulé (RAISE EXCEPTION).

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_id uuid;
  v_sans uuid;
  v_row public.gazette_submissions%rowtype;
  v_pay jsonb;
  v_txt text;
BEGIN
  -- Fixture : une brève déjà traduite, avec e-mail.
  INSERT INTO public.gazette_submissions(rubric, locale, title, body, link, contributor_name, contributor_email,
                                         title_i18n, body_i18n, i18n_status)
  VALUES ('reseau', 'fr', 'Titre avec coqille', 'Un corps un peu long.', 'https://exemple.test/a', 'Louise', 'louise@test.local',
          '{"en":"Title with typo"}'::jsonb, '{"en":"A slightly long body."}'::jsonb, 'done')
  RETURNING id INTO v_id;

  -- T1 : la première correction garde la version d'origine, trace, et remet la traduction en attente
  v_test_name := 'T1 première correction : origine gardée, trace, traduction en attente';
  UPDATE public.gazette_submissions SET title = 'Titre sans coquille' WHERE id = v_id;
  SELECT * INTO v_row FROM public.gazette_submissions WHERE id = v_id;
  IF v_row.original_title = 'Titre avec coqille' AND v_row.original_body = 'Un corps un peu long.'
     AND v_row.original_link = 'https://exemple.test/a'
     AND v_row.staff_edited_at IS NOT NULL
     AND v_row.i18n_status = 'pending' AND v_row.title_i18n IS NULL AND v_row.body_i18n IS NULL THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_test_name || format(' : original_title=%s i18n=%s title_i18n=%s edited_at=%s',
      coalesce(v_row.original_title, 'NULL'), v_row.i18n_status, coalesce(v_row.title_i18n::text, 'NULL'), coalesce(v_row.staff_edited_at::text, 'NULL')));
  END IF;

  -- T2 : une seconde correction ne réécrit pas la version d'origine
  v_test_name := 'T2 seconde correction : la version d''origine reste celle de la personne';
  UPDATE public.gazette_submissions SET body = 'Un corps plus court.' WHERE id = v_id;
  SELECT * INTO v_row FROM public.gazette_submissions WHERE id = v_id;
  IF v_row.original_title = 'Titre avec coqille' AND v_row.original_body = 'Un corps un peu long.' AND v_row.body = 'Un corps plus court.' THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : original_body=' || coalesce(v_row.original_body, 'NULL'));
  END IF;

  -- T3 : un lien modifié seul ne touche pas aux traductions
  v_test_name := 'T3 lien seul : traductions intactes';
  UPDATE public.gazette_submissions SET i18n_status = 'done', title_i18n = '{"en":"x"}'::jsonb WHERE id = v_id; -- le cron a retraduit
  UPDATE public.gazette_submissions SET link = 'https://exemple.test/b' WHERE id = v_id;
  SELECT * INTO v_row FROM public.gazette_submissions WHERE id = v_id;
  IF v_row.i18n_status = 'done' AND v_row.title_i18n IS NOT NULL AND v_row.link = 'https://exemple.test/b' THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : i18n_status=' || v_row.i18n_status);
  END IF;

  -- T4 : accepter une brève corrigée → accepted dit corrected=true et porte le texte retenu
  v_test_name := 'T4 acceptée après correction : corrected=true, texte retenu dans le payload';
  UPDATE public.gazette_submissions SET status = 'accepted' WHERE id = v_id;
  SELECT payload INTO v_pay FROM public.gazette_submission_notification_outbox
   WHERE event = 'gazette.contribution.accepted' AND payload->>'submission_id' = v_id::text;
  IF v_pay IS NOT NULL AND (v_pay->>'corrected')::boolean AND v_pay->>'body' = 'Un corps plus court.' AND v_pay->>'title' = 'Titre sans coquille' THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || coalesce(v_pay::text, 'aucun événement'));
  END IF;

  -- T5 : corriger ET accepter dans le même UPDATE → corrected=true aussi (ordre des triggers indifférent)
  v_test_name := 'T5 corriger et accepter d''un seul geste : corrected=true';
  INSERT INTO public.gazette_submissions(rubric, locale, title, body, contributor_email)
  VALUES ('reseau', 'fr', 'Deuxième', 'Corps.', 'louise@test.local') RETURNING id INTO v_sans;
  UPDATE public.gazette_submissions SET body = 'Corps corrigé.', status = 'accepted' WHERE id = v_sans;
  SELECT payload INTO v_pay FROM public.gazette_submission_notification_outbox
   WHERE event = 'gazette.contribution.accepted' AND payload->>'submission_id' = v_sans::text;
  SELECT * INTO v_row FROM public.gazette_submissions WHERE id = v_sans;
  IF v_pay IS NOT NULL AND (v_pay->>'corrected')::boolean AND v_pay->>'body' = 'Corps corrigé.'
     AND v_row.original_body = 'Corps.' AND v_row.i18n_status = 'pending' THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || coalesce(v_pay::text, 'aucun événement') || ' / original_body=' || coalesce(v_row.original_body, 'NULL'));
  END IF;

  -- T6 : acceptée telle quelle → corrected=false, rien de tracé
  v_test_name := 'T6 acceptée telle quelle : corrected=false, aucune trace de correction';
  INSERT INTO public.gazette_submissions(rubric, locale, title, body, contributor_email)
  VALUES ('reseau', 'fr', 'Troisième', 'Corps.', 'louise@test.local') RETURNING id INTO v_sans;
  UPDATE public.gazette_submissions SET status = 'accepted' WHERE id = v_sans;
  SELECT payload INTO v_pay FROM public.gazette_submission_notification_outbox
   WHERE event = 'gazette.contribution.accepted' AND payload->>'submission_id' = v_sans::text;
  SELECT * INTO v_row FROM public.gazette_submissions WHERE id = v_sans;
  IF v_pay IS NOT NULL AND NOT (v_pay->>'corrected')::boolean AND v_row.staff_edited_at IS NULL AND v_row.original_body IS NULL THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || coalesce(v_pay::text, 'aucun événement'));
  END IF;

  -- T7 : les fonctions trigger sont fermées à anon/authenticated
  v_test_name := 'T7 fonctions trigger fermées';
  SELECT string_agg(p.proname, ', ') INTO v_txt
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN ('fn_gazette_submission_staff_edit', 'fn_gazette_submission_decision_enqueue')
    AND (has_function_privilege('anon', p.oid, 'EXECUTE') OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_txt IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore ouvertes — ' || v_txt); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'GAZETTE_CORRECTION_STAFF ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'GAZETTE_CORRECTION_STAFF OK : %/% tests passés', v_passed, v_passed;
END $$;
