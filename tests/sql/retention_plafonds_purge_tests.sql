-- =====================================================================
-- AnarBib — Tests : la rétention a des plafonds et une purge complète.
-- Date    : 2026-10-23
-- Session : Modele de menace
-- Réf     : supabase/migrations/20261023192006_la_retention_a_des_plafonds_et_une_purge_complete.sql
--
--   T1  la table refuse zéro et tout dépassement de plafond ;
--   T2  fn_set_retention_policy refuse de même, accepte une durée courte ;
--   T3  la purge n'est ouverte qu'à service_role, son travail à personne ;
--   T4  l'essai à blanc compte et ne retire rien ;
--   T5  prêts : la durée propre à la bibliothèque, puis le plafond ;
--   T6  notifications : lues de la bibliothèque, lues du réseau, non lues,
--       bibliothèque inactive comprise ;
--   T7  courriers sortants : final et ancien parti, échec rejouable et récent restent ;
--   T8  signalements : adresse effacée à la clôture, ligne après 12 mois ;
--   T9  PEB : la durée de la prêteuse ;
--   T10 messagerie : un échange part en entier, pas s'il vit encore ;
--   T11 lectures en cours et envies : 24 mois sans connexion ;
--   T12 journaux à 12 mois ; le journal de l'administration du réseau reste ;
--   T13 le journal inter-bibliothèques reste inaltérable hors de la purge ;
--   T14 le cron du dimanche appelle la nouvelle purge, plus l'ancienne (20261023201346).
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'RETENTION-PLAFONDS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf   text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_libA  uuid; v_libB uuid; v_libC uuid;
  v_coord uuid := gen_random_uuid(); v_r1 uuid := gen_random_uuid(); v_r2 uuid := gen_random_uuid();
  v_mem1  uuid; v_book bigint; v_res bigint;
  v_state text; v_n int; v_bilan jsonb; v_x text;
  -- lignes témoins
  e_a60 bigint; e_b60 bigint; e_b800 bigint;
  n_a60 bigint; n_c100 bigint; n_r100 bigint; n_r30 bigint; n_nl13 bigint; n_nl11 bigint;
  o_vieux bigint; o_echec bigint; o_recent bigint;
  b_recent uuid; b_vieux uuid; b_ouvert uuid;
  p_a bigint; p_b bigint;
  m_1 bigint; m_2 bigint; m_3 bigint; m_4 bigint;
  j_vieux bigint; j_recent bigint; x_vieux bigint; x_recent bigint; a_vieux bigint;
  v_avant text; v_apres text;
BEGIN
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-ret-a-' || v_suf, 'Essai rétention A', true, 'public') RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-ret-b-' || v_suf, 'Essai rétention B', true, 'public') RETURNING id INTO v_libB;
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-ret-c-' || v_suf, 'Essai rétention C', false, 'public') RETURNING id INTO v_libC;

  INSERT INTO auth.users (id, email, created_at, last_sign_in_at) VALUES
    (v_coord, 'ret-coord-' || v_suf || '@example.invalid', now() - interval '3 years', now()),
    (v_r1,    'ret-r1-'    || v_suf || '@example.invalid', now() - interval '3 years', now() - interval '30 months'),
    (v_r2,    'ret-r2-'    || v_suf || '@example.invalid', now() - interval '3 years', now() - interval '2 days');
  INSERT INTO public.profiles (id, email, first_name, last_name)
  SELECT u.id, u.email, 'Essai', 'Rétention' FROM auth.users u WHERE u.id IN (v_coord, v_r1, v_r2)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES
    (v_coord, v_libA, 'coordenador', 'active'),
    (v_r2, v_libA, 'reader', 'active'),
    (v_r1, v_libB, 'reader', 'active');
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_r1, v_libA, 'reader', 'active') RETURNING id INTO v_mem1;

  -- ── T1 ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la table refuse zéro et les dépassements';
  v_n := 0;
  BEGIN INSERT INTO public.library_retention_policies (library_id, retention_loans_days) VALUES (v_libB, 0);
  EXCEPTION WHEN check_violation THEN v_n := v_n + 1; END;
  BEGIN INSERT INTO public.library_retention_policies (library_id, retention_loans_days) VALUES (v_libB, 731);
  EXCEPTION WHEN check_violation THEN v_n := v_n + 1; END;
  BEGIN INSERT INTO public.library_retention_policies (library_id, retention_reservations_days) VALUES (v_libB, 366);
  EXCEPTION WHEN check_violation THEN v_n := v_n + 1; END;
  BEGIN INSERT INTO public.library_retention_policies (library_id, retention_consultations_days) VALUES (v_libB, 366);
  EXCEPTION WHEN check_violation THEN v_n := v_n + 1; END;
  BEGIN INSERT INTO public.library_retention_policies (library_id, retention_notifications_days) VALUES (v_libB, 91);
  EXCEPTION WHEN check_violation THEN v_n := v_n + 1; END;
  IF v_n = 5 AND NOT EXISTS (SELECT 1 FROM public.library_retention_policies WHERE library_id = v_libB) THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/5 refus'); END IF;

  -- ── T2 ─────────────────────────────────────────────────────────────────
  v_t := 'T2 fn_set_retention_policy borne les durées';
  v_n := 0; v_state := NULL;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  BEGIN PERFORM public.fn_set_retention_policy(v_libA, 0, NULL, NULL, NULL);
  EXCEPTION WHEN SQLSTATE '23514' THEN v_n := v_n + 1; END;
  BEGIN PERFORM public.fn_set_retention_policy(v_libA, NULL, 366, NULL, NULL);
  EXCEPTION WHEN SQLSTATE '23514' THEN v_n := v_n + 1; END;
  BEGIN PERFORM public.fn_set_retention_policy(v_libA, NULL, NULL, 400, NULL);
  EXCEPTION WHEN SQLSTATE '23514' THEN v_n := v_n + 1; END;
  BEGIN PERFORM public.fn_set_retention_policy(v_libA, NULL, NULL, NULL, 91);
  EXCEPTION WHEN SQLSTATE '23514' THEN v_n := v_n + 1; END;
  BEGIN PERFORM public.fn_set_retention_policy(v_libA, 30, 30, 30, 30, 'essai');
  EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE || ' ' || SQLERRM; END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);
  IF v_n = 4 AND v_state IS NULL
     AND EXISTS (SELECT 1 FROM public.library_retention_policies WHERE library_id = v_libA AND retention_loans_days = 30) THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||v_n||' '||COALESCE(v_state, '')); END IF;

  -- ── T3 ─────────────────────────────────────────────────────────────────
  v_t := 'T3 la purge n''est ouverte qu''à service_role';
  IF NOT has_function_privilege('anon', 'public.fn_purge_retention(boolean)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_purge_retention(boolean)', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.fn_purge_retention(boolean)', 'EXECUTE')
     AND NOT has_function_privilege('service_role', 'private.fn_purge_retention_appliquer()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'private.fn_purge_retention_appliquer()', 'EXECUTE') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── Jeu d'essai daté ───────────────────────────────────────────────────
  -- prêts clos sans exemplaire : A (30 j) à 60 j, B (défaut 730) à 60 j et à 800 j
  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at, created_at, updated_at)
  VALUES (v_r2, v_libA, 'encerrado', current_date - 70, now() - interval '70 days', now() - interval '60 days') RETURNING id INTO e_a60;
  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at, created_at, updated_at)
  VALUES (v_r1, v_libB, 'encerrado', current_date - 70, now() - interval '70 days', now() - interval '60 days') RETURNING id INTO e_b60;
  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at, created_at, updated_at)
  VALUES (v_r1, v_libB, 'encerrado', current_date - 810, now() - interval '810 days', now() - interval '800 days') RETURNING id INTO e_b800;

  -- notifications
  INSERT INTO public.user_notifications (user_id, library_id, category, title, is_read, read_at, created_at)
  VALUES (v_r2, v_libA, 'essai', 'lue A 60 j', true, now() - interval '60 days', now() - interval '61 days') RETURNING id INTO n_a60;
  INSERT INTO public.user_notifications (user_id, library_id, category, title, is_read, read_at, created_at)
  VALUES (v_r2, v_libC, 'essai', 'lue C inactive 100 j', true, now() - interval '100 days', now() - interval '101 days') RETURNING id INTO n_c100;
  INSERT INTO public.user_notifications (user_id, library_id, category, title, is_read, read_at, created_at)
  VALUES (v_r2, NULL, 'essai', 'lue réseau 100 j', true, now() - interval '100 days', now() - interval '101 days') RETURNING id INTO n_r100;
  INSERT INTO public.user_notifications (user_id, library_id, category, title, is_read, read_at, created_at)
  VALUES (v_r2, NULL, 'essai', 'lue réseau 30 j', true, now() - interval '30 days', now() - interval '31 days') RETURNING id INTO n_r30;
  INSERT INTO public.user_notifications (user_id, library_id, category, title, is_read, created_at)
  VALUES (v_r2, NULL, 'essai', 'non lue 13 mois', false, now() - interval '13 months') RETURNING id INTO n_nl13;
  INSERT INTO public.user_notifications (user_id, library_id, category, title, is_read, created_at)
  VALUES (v_r2, v_libA, 'essai', 'non lue 11 mois', false, now() - interval '11 months') RETURNING id INTO n_nl11;

  -- courriers sortants
  INSERT INTO public.team_notification_outbox (event, status, created_at, sent_at)
  VALUES ('team.essai', 'sent', now() - interval '100 days', now() - interval '100 days') RETURNING id INTO o_vieux;
  INSERT INTO public.team_notification_outbox (event, status, created_at)
  VALUES ('team.essai', 'failed', now() - interval '100 days') RETURNING id INTO o_echec;
  INSERT INTO public.team_notification_outbox (event, status, created_at, sent_at)
  VALUES ('team.essai', 'sent', now() - interval '10 days', now() - interval '10 days') RETURNING id INTO o_recent;
  -- l'envoi à l'insertion échoue sans secret de banc : on remet l'état voulu
  UPDATE public.team_notification_outbox SET status = 'sent', sent_at = now() - interval '100 days' WHERE id = o_vieux;
  UPDATE public.team_notification_outbox SET status = 'sent', sent_at = now() - interval '10 days' WHERE id = o_recent;

  -- signalements
  INSERT INTO public.bug_reports (what_happened, reporter_email, status, created_at, closed_at)
  VALUES ('essai rétention récent', 'ret-bug1-' || v_suf || '@example.invalid', 'closed', now() - interval '3 months', now() - interval '2 months')
  RETURNING id INTO b_recent;
  INSERT INTO public.bug_reports (what_happened, reporter_email, status, created_at, closed_at)
  VALUES ('essai rétention ancien', NULL, 'closed', now() - interval '14 months', now() - interval '13 months')
  RETURNING id INTO b_vieux;
  INSERT INTO public.bug_reports (what_happened, reporter_email, status, created_at)
  VALUES ('essai rétention ouvert', 'ret-bug2-' || v_suf || '@example.invalid', 'open', now() - interval '14 months')
  RETURNING id INTO b_ouvert;

  -- PEB clos depuis 60 j : prêteuse A (30 j) part, prêteuse B (730 j) reste
  INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id, status_global, created_at, updated_at, returned_at)
  VALUES (v_libA, v_libB, v_libB, 'devolvido', now() - interval '90 days', now() - interval '60 days', now() - interval '60 days') RETURNING id INTO p_a;
  INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id, status_global, created_at, updated_at, returned_at)
  VALUES (v_libB, v_libA, v_libA, 'devolvido', now() - interval '90 days', now() - interval '60 days', now() - interval '60 days') RETURNING id INTO p_b;
  INSERT INTO public.interlibrary_loan_notification_events (interlibrary_loan_id, event_type, event_key)
  VALUES (p_a, 'interlibrary_loan_returned', 'essai-' || v_suf);

  -- messagerie : l'échange de R1 est éteint, celui de R2 vit encore
  INSERT INTO public.reader_library_messages (library_id, sender_id, direction, body, created_at)
  VALUES (v_libA, v_r1, 'reader', 'question ancienne', now() - interval '14 months') RETURNING id INTO m_1;
  INSERT INTO public.reader_library_messages (library_id, sender_id, recipient_id, direction, body, created_at)
  VALUES (v_libA, v_coord, v_r1, 'library', 'réponse ancienne', now() - interval '13 months') RETURNING id INTO m_2;
  INSERT INTO public.reader_library_messages (library_id, sender_id, direction, body, created_at)
  VALUES (v_libA, v_r2, 'reader', 'question ancienne', now() - interval '14 months') RETURNING id INTO m_3;
  INSERT INTO public.reader_library_messages (library_id, sender_id, recipient_id, direction, body, created_at)
  VALUES (v_libA, v_coord, v_r2, 'library', 'réponse récente', now() - interval '1 month') RETURNING id INTO m_4;

  -- lectures et envies : R1 sans connexion depuis 30 mois, R2 connectée
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Essai rétention', 'RET-' || v_suf, 'livro') RETURNING id INTO v_book;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, source_url)
  VALUES (v_book, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'https://exemple.invalid/ret.pdf') RETURNING id INTO v_res;
  INSERT INTO public.reading_progress (user_id, resource_id) VALUES (v_r1, v_res), (v_r2, v_res);
  INSERT INTO public.user_wishlist (user_id, book_id) VALUES (v_r1, v_book), (v_r2, v_book);

  -- journaux
  INSERT INTO private.double_facteur_journal (le, par, compte, facteurs_retires, sessions_fermees, motif)
  VALUES (now() - interval '13 months', v_coord, v_r1, 1, 1, 'essai de rétention ancien') RETURNING id INTO j_vieux;
  INSERT INTO private.double_facteur_journal (le, par, compte, facteurs_retires, sessions_fermees, motif)
  VALUES (now() - interval '1 month', v_coord, v_r1, 1, 1, 'essai de rétention récent') RETURNING id INTO j_recent;
  INSERT INTO public.network_admin_cross_library_actions_log (actor_user_id, library_id, action_type, created_at)
  VALUES (v_coord, v_libA, 'essai_retention', now() - interval '13 months') RETURNING id INTO x_vieux;
  INSERT INTO public.network_admin_cross_library_actions_log (actor_user_id, library_id, action_type, created_at)
  VALUES (v_coord, v_libA, 'essai_retention', now() - interval '1 month') RETURNING id INTO x_recent;
  INSERT INTO public.library_membership_audit (library_id, target_user_id, action, role, status_after, created_at)
  VALUES (v_libA, v_r1, 'suspended', 'reader', 'suspended', now() - interval '13 months'),
         (v_libA, v_r1, 'unsuspended', 'reader', 'active', now() - interval '1 month');
  INSERT INTO public.membership_validation_log (membership_id, user_id, library_id, action, created_at)
  VALUES (v_mem1, v_r1, v_libA, 'validated', now() - interval '13 months'),
         (v_mem1, v_r1, v_libA, 'revalidated', now() - interval '1 month');
  INSERT INTO public.reader_membership_events (membership_id, library_id, user_id, role, new_status, event_type, changed_at)
  VALUES (v_mem1, v_libA, v_r1, 'reader', 'active', 'inscricao', now() - interval '13 months'),
         (v_mem1, v_libA, v_r1, 'reader', 'active', 'reativacao', now() - interval '1 month');
  INSERT INTO public.network_administrator_audit (user_id, event_type, created_at)
  VALUES (v_coord, 'foundational_admin_added', now() - interval '3 years') RETURNING id INTO a_vieux;

  -- Empreinte de toutes les lignes témoins
  v_x := $q$
    SELECT concat_ws('|',
      (SELECT count(*) FROM public.emprestimos_v2 WHERE library_id IN ($1, $2)),
      (SELECT count(*) FROM public.user_notifications WHERE user_id = $4),
      (SELECT count(*) FROM public.team_notification_outbox WHERE event = 'team.essai'),
      (SELECT count(*) FROM public.bug_reports WHERE what_happened LIKE 'essai rétention%'),
      (SELECT count(*) FILTER (WHERE reporter_email IS NOT NULL) FROM public.bug_reports WHERE what_happened LIKE 'essai rétention%'),
      (SELECT count(*) FROM public.interlibrary_loans_v2 WHERE lender_library_id IN ($1, $2)),
      (SELECT count(*) FROM public.reader_library_messages WHERE library_id = $1),
      (SELECT count(*) FROM public.reading_progress WHERE resource_id = $5),
      (SELECT count(*) FROM public.user_wishlist WHERE book_id = $6),
      (SELECT count(*) FROM private.double_facteur_journal WHERE par = $3),
      (SELECT count(*) FROM public.network_admin_cross_library_actions_log WHERE action_type = 'essai_retention'),
      (SELECT count(*) FROM public.library_membership_audit WHERE target_user_id = $7),
      (SELECT count(*) FROM public.membership_validation_log WHERE user_id = $7),
      (SELECT count(*) FROM public.reader_membership_events WHERE user_id = $7),
      (SELECT count(*) FROM public.network_administrator_audit WHERE user_id = $3))
  $q$;
  EXECUTE v_x INTO v_avant USING v_libA, v_libB, v_coord, v_r2, v_res, v_book, v_r1;

  -- ── T4 ─────────────────────────────────────────────────────────────────
  v_t := 'T4 l''essai à blanc compte et ne retire rien';
  v_bilan := public.fn_purge_retention(true);
  EXECUTE v_x INTO v_apres USING v_libA, v_libB, v_coord, v_r2, v_res, v_book, v_r1;
  IF v_bilan->>'mode' = 'essai_a_blanc' AND v_apres = v_avant
     AND (v_bilan->'totaux'->>'prets')::int >= 2
     AND (v_bilan->'par_bibliotheque'->('essai-ret-a-' || v_suf)->>'prets')::int = 1
     AND (v_bilan->'par_bibliotheque'->('essai-ret-c-' || v_suf)->>'notifications_lues')::int = 1
     AND (v_bilan->'totaux'->>'peb')::int >= 1
     AND (v_bilan->'totaux'->>'messages_lectorat')::int >= 2
     AND (v_bilan->'totaux'->>'signalements_adresses_effacees')::int >= 1
     AND (v_bilan->'courriers_sortants'->>'team_notification_outbox')::int >= 1
     AND (v_bilan->'journaux'->>'network_admin_cross_library_actions_log')::int >= 1
     AND COALESCE(current_setting('anarbib.purge_retention', true), '') = '' THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_avant||' -> '||v_apres||' '||left(v_bilan::text, 400)); END IF;

  -- La purge réelle (les tests suivants en lisent l'effet)
  v_state := NULL;
  BEGIN
    v_bilan := public.fn_purge_retention(false);
  EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE || ' ' || SQLERRM; END;
  IF v_state IS NOT NULL THEN
    RAISE EXCEPTION 'RETENTION-PLAFONDS ECHEC : la purge réelle a levé % (après %/% tests)', v_state, v_passed, v_passed + v_failed;
  END IF;

  -- ── T5 ─────────────────────────────────────────────────────────────────
  v_t := 'T5 prêts : la durée de la bibliothèque, puis le plafond';
  IF NOT EXISTS (SELECT 1 FROM public.emprestimos_v2 WHERE id = e_a60)
     AND EXISTS (SELECT 1 FROM public.emprestimos_v2 WHERE id = e_b60)
     AND NOT EXISTS (SELECT 1 FROM public.emprestimos_v2 WHERE id = e_b800)
     AND v_bilan->>'mode' = 'execute' THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T6 ─────────────────────────────────────────────────────────────────
  v_t := 'T6 notifications lues, réseau, non lues, bibliothèque inactive';
  SELECT string_agg(title, ',' ORDER BY id) INTO v_x FROM public.user_notifications WHERE user_id = v_r2 AND category = 'essai';
  IF v_x = 'lue réseau 30 j,non lue 11 mois' THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : restent '||COALESCE(v_x, '∅')); END IF;

  -- ── T7 ─────────────────────────────────────────────────────────────────
  v_t := 'T7 courriers sortants : seul le final ancien part';
  IF NOT EXISTS (SELECT 1 FROM public.team_notification_outbox WHERE id = o_vieux)
     AND EXISTS (SELECT 1 FROM public.team_notification_outbox WHERE id = o_echec)
     AND EXISTS (SELECT 1 FROM public.team_notification_outbox WHERE id = o_recent) THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T8 ─────────────────────────────────────────────────────────────────
  v_t := 'T8 signalements : adresse effacée à la clôture, ligne à 12 mois';
  IF EXISTS (SELECT 1 FROM public.bug_reports WHERE id = b_recent AND reporter_email IS NULL)
     AND NOT EXISTS (SELECT 1 FROM public.bug_reports WHERE id = b_vieux)
     AND EXISTS (SELECT 1 FROM public.bug_reports WHERE id = b_ouvert AND reporter_email IS NOT NULL) THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T9 ─────────────────────────────────────────────────────────────────
  v_t := 'T9 PEB : la durée de la prêteuse, événements en cascade';
  IF NOT EXISTS (SELECT 1 FROM public.interlibrary_loans_v2 WHERE id = p_a)
     AND NOT EXISTS (SELECT 1 FROM public.interlibrary_loan_notification_events WHERE interlibrary_loan_id = p_a)
     AND EXISTS (SELECT 1 FROM public.interlibrary_loans_v2 WHERE id = p_b) THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T10 ────────────────────────────────────────────────────────────────
  v_t := 'T10 messagerie : l''échange éteint part en entier, le vivant reste';
  SELECT string_agg(id::text, ',' ORDER BY id) INTO v_x FROM public.reader_library_messages WHERE library_id = v_libA;
  IF v_x = m_3 || ',' || m_4 THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : restent '||COALESCE(v_x, '∅')); END IF;

  -- ── T11 ────────────────────────────────────────────────────────────────
  v_t := 'T11 lectures et envies : 24 mois sans connexion';
  IF NOT EXISTS (SELECT 1 FROM public.reading_progress WHERE user_id = v_r1)
     AND NOT EXISTS (SELECT 1 FROM public.user_wishlist WHERE user_id = v_r1)
     AND EXISTS (SELECT 1 FROM public.reading_progress WHERE user_id = v_r2)
     AND EXISTS (SELECT 1 FROM public.user_wishlist WHERE user_id = v_r2) THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  -- ── T12 ────────────────────────────────────────────────────────────────
  v_t := 'T12 journaux à 12 mois, administration du réseau gardée';
  SELECT concat_ws('|',
    (SELECT count(*) FROM private.double_facteur_journal WHERE id IN (j_vieux, j_recent)),
    (SELECT count(*) FROM public.network_admin_cross_library_actions_log WHERE id IN (x_vieux, x_recent)),
    (SELECT count(*) FROM public.library_membership_audit WHERE target_user_id = v_r1 AND created_at < now() - interval '6 months'),
    (SELECT count(*) FROM public.library_membership_audit WHERE target_user_id = v_r1 AND action = 'unsuspended'),
    (SELECT count(*) FROM public.membership_validation_log WHERE user_id = v_r1 AND created_at < now() - interval '6 months'),
    (SELECT count(*) FROM public.membership_validation_log WHERE user_id = v_r1 AND action = 'revalidated'),
    (SELECT count(*) FROM public.reader_membership_events WHERE user_id = v_r1 AND changed_at < now() - interval '6 months'),
    (SELECT count(*) FROM public.reader_membership_events WHERE user_id = v_r1 AND event_type = 'reativacao'),
    (SELECT count(*) FROM public.network_administrator_audit WHERE id = a_vieux)) INTO v_x;
  IF v_x = '1|1|0|1|0|1|0|1|1'
     AND EXISTS (SELECT 1 FROM private.double_facteur_journal WHERE id = j_recent)
     AND EXISTS (SELECT 1 FROM public.network_admin_cross_library_actions_log WHERE id = x_recent) THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_x); END IF;

  -- ── T13 ────────────────────────────────────────────────────────────────
  v_t := 'T13 le journal inter-bibliothèques reste inaltérable hors purge';
  v_n := 0;
  INSERT INTO public.network_admin_cross_library_actions_log (actor_user_id, library_id, action_type, created_at)
  VALUES (v_coord, v_libA, 'essai_retention', now() - interval '13 months') RETURNING id INTO x_vieux;
  BEGIN DELETE FROM public.network_admin_cross_library_actions_log WHERE id = x_vieux;
  EXCEPTION WHEN OTHERS THEN v_n := v_n + 1; END;
  PERFORM set_config('anarbib.purge_retention', 'on', true);
  BEGIN DELETE FROM public.network_admin_cross_library_actions_log WHERE id = x_recent;
  EXCEPTION WHEN OTHERS THEN v_n := v_n + 1; END;
  BEGIN UPDATE public.network_admin_cross_library_actions_log SET action_type = 'x' WHERE id = x_vieux;
  EXCEPTION WHEN OTHERS THEN v_n := v_n + 1; END;
  PERFORM set_config('anarbib.purge_retention', '', true);
  IF v_n = 3 THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/3 refus'); END IF;

  -- ── T14 ────────────────────────────────────────────────────────────────
  -- 20261023201346 : la purge hebdomadaire passe à fn_purge_retention.
  v_t := 'T14 le cron du dimanche appelle la nouvelle purge, plus l''ancienne';
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-rgpd-purge-weekly' AND active
               AND schedule = '0 3 * * 0' AND command ILIKE '%fn_purge_retention(p_dry_run := false)%')
     AND EXISTS (SELECT 1 FROM private.fn_crons_attendus() c
                  WHERE c.jobname = 'anarbib-rgpd-purge-weekly' AND c.command ILIKE '%fn_purge_retention(p_dry_run := false)%')
     AND NOT EXISTS (SELECT 1 FROM cron.job WHERE command ILIKE '%fn_purge_expired_data%')
     AND NOT EXISTS (SELECT 1 FROM private.fn_crons_attendus() c WHERE c.command ILIKE '%fn_purge_expired_data%') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'RETENTION-PLAFONDS OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'RETENTION-PLAFONDS ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
