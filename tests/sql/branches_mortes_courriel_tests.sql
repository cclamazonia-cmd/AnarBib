-- =====================================================================
-- AnarBib — Tests : F1, les branches mortes du courriel (côté base) et les
-- deux chantiers décidés le 30/09/2026.
-- Date    : 2026-10-01
-- Réf     : supabase/migrations/20261001194818_f1_branches_mortes_du_courriel.sql ;
--           carte docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md.
--
-- Ce que la suite EMPRUNTE (aucune relecture de corps ne suffit ici) :
--   · le déclencheur des réservations, ligne par ligne : chaque stage vivant
--     émet toujours son événement, le Bloc 3 (contre-proposition v3) aussi ;
--     le stage 're-retirada_agendada' et pickup_reply_status n'émettent plus ;
--   · l'acceptation d'une invitation librarian dépose team.promoted_to_librarian
--     dans team_notification_outbox, avec la personne et le proposeur ;
--   · le cron d'expiration des consultations : une ligne échue part en
--     'expirada' et émet consulta_v2_expirada, même dans une bibliothèque sans
--     ligne de politique ; une ligne non échue, sans échéance, en no-show ou
--     déjà consultée ne bouge pas ;
--   · la CHECK des événements PEB refuse 'interlibrary_loan_due_soon' À L'INSERTION ;
--   · fn_cron_notify_loan_cycle lit toujours le secret WEBHOOK_SECRET_NOTIFY_MID_LOAN,
--     qui ne part pas avec l'ancien mi-parcours.
-- Les émissions sont CAPTURÉES : fn_dispatch_notify_event est remplacée, le
-- temps de la transaction, par une fonction qui note l'événement.
--
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'BRANCHES-MORTES-COURRIEL OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_lecteur uuid := gen_random_uuid();
  v_suf text;
  v_lib uuid; v_book bigint; v_hold bigint; v_res bigint;
  v_cons bigint; v_n int; v_txt text; v_json jsonb; v_inv uuid;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_coord uuid; v_lib2 uuid := gen_random_uuid(); v_cible uuid := gen_random_uuid(); v_cible_pub text;
  v_avant bigint; v_x bigint[] := ARRAY[]::bigint[]; v_xid bigint; v_k int;
  v_cons2 bigint; v_cons3 bigint; v_def text;
BEGIN
  -- ── La capture ─────────────────────────────────────────────────────
  CREATE OR REPLACE FUNCTION public.fn_dispatch_notify_event(p_event text, p_record_id bigint, p_extra jsonb DEFAULT '{}'::jsonb)
  RETURNS bigint LANGUAGE plpgsql SET search_path = public, pg_temp AS $f$
  BEGIN
    PERFORM set_config('anarbib.capture', coalesce(current_setting('anarbib.capture', true), '') || p_event || ';', true);
    RETURN 0;
  END $f$;

  -- ── Décor ──────────────────────────────────────────────────────────
  v_suf := substr(replace(v_lecteur::text, '-', ''), 1, 8);
  INSERT INTO auth.users (id, email) VALUES (v_lecteur, 'f1-lect-' || v_suf || '@example.invalid');
  INSERT INTO public.profiles (id) VALUES (v_lecteur) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('f1-' || v_suf, 'F1 (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_lib;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_lecteur, v_lib, 'reader', 'active', true);
  -- Une bibliothèque SANS ligne de politique : tout doit rester fail-open.
  DELETE FROM public.library_notification_policies WHERE library_id = v_lib;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('F1 (essai)', 'F1-' || v_suf, 'livro') RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib) RETURNING id INTO v_hold;

  INSERT INTO public.reservas_v2 (user_id, library_id, status_global) VALUES (v_lecteur, v_lib, 'ativa') RETURNING id INTO v_res;
  INSERT INTO public.reserva_linhas_v2 (reserva_id, line_no, book_id, holding_id, bib_ref, item_status)
  VALUES (v_res, 1, v_book, v_hold, 'F1-' || v_suf, 'ativa');
  INSERT INTO public.reserva_item_workflow_v2 (reserva_id, line_no, workflow_stage)
  VALUES (v_res, 1, 'solicitada') ON CONFLICT (reserva_id, line_no) DO NOTHING;

  -- ── Déclencheur des réservations ───────────────────────────────────
  v_t := 'T1 em_preparacao émet toujours em_preparacao';
  PERFORM set_config('anarbib.capture', '', true);
  UPDATE public.reserva_item_workflow_v2 SET workflow_stage = 'em_preparacao' WHERE reserva_id = v_res AND line_no = 1;
  v_txt := current_setting('anarbib.capture', true);
  IF v_txt = 'em_preparacao;' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;

  v_t := 'T2 retirada_a_combinar émet toujours retirada_a_combinar';
  PERFORM set_config('anarbib.capture', '', true);
  UPDATE public.reserva_item_workflow_v2 SET workflow_stage = 'retirada_a_combinar', pickup_scheduled_for = now() + interval '3 days', pickup_proposed_by = 'biblio'
   WHERE reserva_id = v_res AND line_no = 1;
  v_txt := current_setting('anarbib.capture', true);
  IF v_txt = 'retirada_a_combinar;' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;

  v_t := 'T3 Bloc 3 vivant : une contre-proposition dans le même stage émet retirada_a_combinar';
  PERFORM set_config('anarbib.capture', '', true);
  -- Le déclencheur est « UPDATE OF workflow_stage, pickup_reply_status » : il ne
  -- s'éveille que si workflow_stage est dans le SET — ce que fait l'upsert de
  -- fn_v2_set_reserva_linhas_workflow_core (workflow_stage = excluded.workflow_stage).
  UPDATE public.reserva_item_workflow_v2 SET workflow_stage = 'retirada_a_combinar', pickup_proposed_by = 'leitor', pickup_scheduled_for = now() + interval '4 days'
   WHERE reserva_id = v_res AND line_no = 1;
  v_txt := current_setting('anarbib.capture', true);
  IF v_txt = 'retirada_a_combinar;' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;

  v_t := 'T4 pickup_reply_status (modèle v2) n''émet plus rien';
  PERFORM set_config('anarbib.capture', '', true);
  UPDATE public.reserva_item_workflow_v2 SET pickup_reply_status = 'confirmado_leitor' WHERE reserva_id = v_res AND line_no = 1;
  v_txt := current_setting('anarbib.capture', true);
  IF coalesce(v_txt, '') = '' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;

  v_t := 'T5 retirada_agendada émet toujours retirada_agendada';
  PERFORM set_config('anarbib.capture', '', true);
  UPDATE public.reserva_item_workflow_v2 SET workflow_stage = 'retirada_agendada', pickup_reply_status = NULL WHERE reserva_id = v_res AND line_no = 1;
  v_txt := current_setting('anarbib.capture', true);
  IF v_txt = 'retirada_agendada;' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;

  v_t := 'T6 le stage re-retirada_agendada n''émet plus retirada_reagendada';
  PERFORM set_config('anarbib.capture', '', true);
  UPDATE public.reserva_item_workflow_v2 SET workflow_stage = 're-retirada_agendada' WHERE reserva_id = v_res AND line_no = 1;
  v_txt := current_setting('anarbib.capture', true);
  IF coalesce(v_txt, '') = '' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;

  v_t := 'T7 pronta_para_retirada puis retirada_efetivada émettent toujours';
  PERFORM set_config('anarbib.capture', '', true);
  UPDATE public.reserva_item_workflow_v2 SET workflow_stage = 'pronta_para_retirada' WHERE reserva_id = v_res AND line_no = 1;
  UPDATE public.reserva_item_workflow_v2 SET workflow_stage = 'retirada_efetivada' WHERE reserva_id = v_res AND line_no = 1;
  v_txt := current_setting('anarbib.capture', true);
  IF v_txt = 'pronta_para_retirada;reserva_convertida_em_emprestimo;' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;

  v_t := 'T8 le corps du déclencheur ne nomme plus les deux émissions retirées';
  SELECT pg_get_functiondef('public.trg_notify_reserva_workflow_change()'::regprocedure) INTO v_txt;
  IF v_txt NOT LIKE '%retirada_reagendada%' AND v_txt NOT LIKE '%retirada_confirmada_leitor%' AND v_txt NOT LIKE '%retirada_recusada_leitor%'
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : un nom retiré est encore là'); END IF;

  -- ── Le cron du mi-parcours et la CHECK des PEB ─────────────────────
  v_t := 'T9 fn_cron_notify_mid_loan_reading n''existe plus';
  IF to_regprocedure('public.fn_cron_notify_mid_loan_reading()') IS NULL THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : présente'); END IF;

  v_t := 'T10 la CHECK des événements PEB refuse due_soon à l''insertion et garde les huit autres';
  BEGIN
    INSERT INTO public.interlibrary_loan_notification_events (interlibrary_loan_id, event_type, event_key)
    VALUES (-1, 'interlibrary_loan_due_soon', 'f1-' || v_suf);
    v_txt := 'acceptée';
  EXCEPTION
    WHEN check_violation THEN v_txt := 'refusée';
    WHEN OTHERS THEN v_txt := 'autre erreur : ' || SQLERRM;
  END;
  SELECT pg_get_constraintdef(oid) INTO v_def FROM pg_constraint WHERE conname = 'interlibrary_loan_notification_events_type_chk';
  IF v_txt = 'refusée'
     AND (SELECT count(*) FROM unnest(ARRAY['interlibrary_loan_created','interlibrary_loan_prepared','interlibrary_loan_dispatched',
            'interlibrary_loan_overdue','interlibrary_loan_return_started','interlibrary_loan_returned','interlibrary_loan_cancelled',
            'interlibrary_loan_partially_returned']) e WHERE v_def LIKE '%''' || e || '''%') = 8
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt||' ; '||coalesce(v_def,'NULL')); END IF;

  v_t := 'T10b le cycle de prêt lit toujours le secret du mi-parcours (il ne part pas avec lui)';
  IF to_regprocedure('public.fn_cron_notify_loan_cycle()') IS NOT NULL
     AND pg_get_functiondef('public.fn_cron_notify_loan_cycle()'::regprocedure) LIKE '%WEBHOOK_SECRET_NOTIFY_MID_LOAN%'
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  -- ── team.promoted_to_librarian ─────────────────────────────────────
  SELECT user_id INTO v_coord FROM public.user_library_memberships
   WHERE library_id = c_blmf AND role = 'coordenador' AND status = 'active' LIMIT 1;
  IF v_coord IS NULL THEN RAISE EXCEPTION 'SETUP : pas de coordenador BLMF seedé'; END IF;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_cible, 'authenticated', 'authenticated', 'f1-cible-' || v_suf || '@example.invalid',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb);
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (v_cible, 'f1-cible-' || v_suf || '@example.invalid', 'Cible', 'F1', 'fr') ON CONFLICT (id) DO NOTHING;
  SELECT public_id INTO v_cible_pub FROM public.profiles WHERE id = v_cible;
  UPDATE public.libraries SET team_admission_mode = 'coordenador_seul' WHERE id = c_blmf;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_cible_pub, 'librarian');
  v_inv := (v_json->>'invitation_id')::uuid;
  SELECT coalesce(max(id), 0) INTO v_avant FROM public.team_notification_outbox;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_cible, 'role', 'authenticated')::text, true);
  v_json := public.fn_team_accept_invitation(v_inv);

  v_t := 'T11 accepter une invitation librarian dépose team.promoted_to_librarian (personne, proposeur, audit)';
  SELECT count(*) INTO v_n FROM public.team_notification_outbox
   WHERE id > v_avant AND event = 'team.promoted_to_librarian'
     AND payload->>'target_user_id' = v_cible::text AND payload->>'actor_user_id' = v_coord::text
     AND payload->>'library_id' = c_blmf::text AND payload->>'audit_id' = v_json->>'audit_id';
  IF (v_json->>'ok') = 'true' AND v_n = 1 THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ok='||coalesce(v_json->>'ok','NULL')||', lignes='||v_n); END IF;

  v_t := 'T12 et rien d''autre : une seule ligne neuve dans la file';
  SELECT count(*) INTO v_n FROM public.team_notification_outbox WHERE id > v_avant;
  IF v_n = 1 THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' lignes'); END IF;
  PERFORM set_config('request.jwt.claims', '', true);

  v_t := 'T12b une émission de chaque promotion, la librarian dans sa branche';
  SELECT pg_get_functiondef('public.fn_team_accept_invitation(uuid)'::regprocedure) INTO v_def;
  IF (length(v_def) - length(replace(v_def, 'team.promoted_to_librarian', ''))) / length('team.promoted_to_librarian') = 1
     AND (length(v_def) - length(replace(v_def, 'team.promoted_to_coordenador', ''))) / length('team.promoted_to_coordenador') = 1
     AND strpos(v_def, 'team.promoted_to_librarian') < strpos(v_def, '=============== promotion collégiale')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  -- ── Expiration des consultations ───────────────────────────────────
  FOR v_k IN 1 .. 9 LOOP
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
    VALUES ('F1-' || v_suf, 'F1-' || v_suf || '-' || v_k, v_lib, v_hold, 'ambos', 'public') RETURNING id INTO v_xid;
    v_x := v_x || v_xid;
  END LOOP;
  INSERT INTO public.consultas_locais_v2 (user_id, library_id, status_global, notes)
  VALUES (v_lecteur, v_lib, 'ativa', 'F1 (essai)') RETURNING id INTO v_cons;
  -- 1 échue, sans workflow ; 2 échue en préparation, avec une note de l'équipe ;
  -- 3 échue en no-show ; 4 non échue ; 5 sans échéance ; 6 échue mais déjà
  -- consultée ; 7 échue, créneau proposé (consulta_agendada).
  INSERT INTO public.consulta_linhas_v2 (consulta_id, line_no, book_id, holding_id, item_id, bib_ref, titulo_cache, autor_cache, item_status, expires_at, consulted_at)
  VALUES (v_cons, 1, v_book, v_hold, v_x[1], 'F1-' || v_suf, 'F1', 'Essai', 'ativa', now() - interval '1 day', NULL),
         (v_cons, 2, v_book, v_hold, v_x[2], 'F1-' || v_suf, 'F1', 'Essai', 'ativa', now() - interval '2 days', NULL),
         (v_cons, 3, v_book, v_hold, v_x[3], 'F1-' || v_suf, 'F1', 'Essai', 'ativa', now() - interval '3 days', NULL),
         (v_cons, 4, v_book, v_hold, v_x[4], 'F1-' || v_suf, 'F1', 'Essai', 'ativa', now() + interval '3 days', NULL),
         (v_cons, 5, v_book, v_hold, v_x[5], 'F1-' || v_suf, 'F1', 'Essai', 'ativa', NULL, NULL),
         (v_cons, 6, v_book, v_hold, v_x[6], 'F1-' || v_suf, 'F1', 'Essai', 'consultada', now() - interval '4 days', now() - interval '5 days'),
         (v_cons, 7, v_book, v_hold, v_x[7], 'F1-' || v_suf, 'F1', 'Essai', 'ativa', now() - interval '1 hour', NULL);
  INSERT INTO public.consulta_item_workflow_v2 (consulta_id, line_no, workflow_stage, workflow_note) VALUES
    (v_cons, 2, 'em_preparacao', 'note de l''équipe'), (v_cons, 3, 'nao_compareceu', NULL), (v_cons, 7, 'consulta_agendada', NULL)
  ON CONFLICT (consulta_id, line_no) DO UPDATE SET workflow_stage = excluded.workflow_stage, workflow_note = excluded.workflow_note;
  DELETE FROM public.consulta_item_workflow_v2 WHERE consulta_id = v_cons AND line_no = 1;
  -- Une deuxième consultation échue (même tir) et une troisième, échue mais
  -- ARCHIVÉE (gelée par fn_archive_library_circulation) : elle ne bouge pas.
  INSERT INTO public.consultas_locais_v2 (user_id, library_id, status_global, notes)
  VALUES (v_lecteur, v_lib, 'ativa', 'F1 (essai) 2') RETURNING id INTO v_cons2;
  INSERT INTO public.consulta_linhas_v2 (consulta_id, line_no, book_id, holding_id, item_id, bib_ref, titulo_cache, autor_cache, item_status, expires_at)
  VALUES (v_cons2, 1, v_book, v_hold, v_x[8], 'F1-' || v_suf, 'F1', 'Essai', 'ativa', now() - interval '6 days');
  INSERT INTO public.consultas_locais_v2 (user_id, library_id, status_global, notes, archived_at, archive_reason)
  VALUES (v_lecteur, v_lib, 'ativa', 'F1 (essai) 3', now(), 'admin_manual') RETURNING id INTO v_cons3;
  INSERT INTO public.consulta_linhas_v2 (consulta_id, line_no, book_id, holding_id, item_id, bib_ref, titulo_cache, autor_cache, item_status, expires_at)
  VALUES (v_cons3, 1, v_book, v_hold, v_x[9], 'F1-' || v_suf, 'F1', 'Essai', 'ativa', now() - interval '7 days');

  PERFORM set_config('anarbib.capture', '', true);
  v_n := public.fn_cron_expire_consultas();

  v_t := 'T13 les lignes échues et ouvertes expirent (agendée comprise), et seulement elles';
  IF v_n = 4
     AND (SELECT array_agg(line_no ORDER BY line_no) FROM public.consulta_linhas_v2 WHERE consulta_id = v_cons AND item_status = 'expirada') = ARRAY[1, 2, 7]
     AND (SELECT item_status FROM public.consulta_linhas_v2 WHERE consulta_id = v_cons2 AND line_no = 1) = 'expirada'
     AND (SELECT count(*) FROM public.consulta_linhas_v2 WHERE consulta_id IN (v_cons, v_cons2) AND item_status = 'expirada' AND expired_at IS NULL) = 0
    THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rendu '||v_n||', expirées '||coalesce((SELECT string_agg(consulta_id||'.'||line_no, ',') FROM public.consulta_linhas_v2 WHERE consulta_id IN (v_cons, v_cons2, v_cons3) AND item_status = 'expirada'), 'aucune')); END IF;

  v_t := 'T14 leur workflow passe à expirada avec la note système, l''ancienne note est remplacée';
  IF (SELECT array_agg(line_no ORDER BY line_no) FROM public.consulta_item_workflow_v2 WHERE consulta_id = v_cons AND workflow_stage = 'expirada') = ARRAY[1, 2, 7]
     AND (SELECT count(*) FROM public.consulta_item_workflow_v2
           WHERE consulta_id IN (v_cons, v_cons2) AND workflow_stage = 'expirada'
             AND workflow_note = '@@note:systemNote.consultaExpiredAuto') = 4
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  v_t := 'T15 chacune émet consulta_v2_expirada, dans une bibliothèque sans ligne de politique';
  v_txt := current_setting('anarbib.capture', true);
  IF v_txt = repeat('consulta_v2_expirada;', 4) THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;

  v_t := 'T16 no-show, non échue, sans échéance, consultée et archivée ne bougent pas';
  IF (SELECT string_agg(line_no || '=' || item_status, ',' ORDER BY line_no) FROM public.consulta_linhas_v2 WHERE consulta_id = v_cons AND line_no BETWEEN 3 AND 6)
       = '3=ativa,4=ativa,5=ativa,6=consultada'
     AND (SELECT workflow_stage FROM public.consulta_item_workflow_v2 WHERE consulta_id = v_cons AND line_no = 3) = 'nao_compareceu'
     AND (SELECT item_status FROM public.consulta_linhas_v2 WHERE consulta_id = v_cons3 AND line_no = 1) = 'ativa'
     AND NOT EXISTS (SELECT 1 FROM public.consulta_item_workflow_v2 WHERE consulta_id = v_cons3 AND workflow_stage = 'expirada')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  v_t := 'T16b l''état global suit : partiellement close, close, active (archivée)';
  SELECT string_agg(status_global, ',' ORDER BY id) INTO v_txt FROM public.consultas_locais_v2 WHERE id IN (v_cons, v_cons2, v_cons3);
  IF v_txt = 'parcialmente_encerrada,encerrada,ativa' THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;

  v_t := 'T17 un second passage ne refait rien';
  PERFORM set_config('anarbib.capture', '', true);
  v_n := public.fn_cron_expire_consultas();
  IF v_n = 0 AND coalesce(current_setting('anarbib.capture', true), '') = '' THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n); END IF;

  v_t := 'T18 le cron est planifié, et ni anon ni authenticated ne peuvent l''appeler';
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-consultas-expire-daily' AND schedule = '10 3 * * *'
               AND command = 'select public.fn_cron_expire_consultas();')
     AND NOT has_function_privilege('anon', 'public.fn_cron_expire_consultas()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_cron_expire_consultas()', 'EXECUTE')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'BRANCHES-MORTES-COURRIEL OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'BRANCHES-MORTES-COURRIEL ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
