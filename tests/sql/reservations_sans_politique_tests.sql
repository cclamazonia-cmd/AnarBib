-- =====================================================================
-- AnarBib — Tests : F20, les crons de réservation tournent aussi dans une
-- bibliothèque sans ligne de politique.
-- Date    : 2026-10-04
-- Réf     : supabase/migrations/20261004210702_les_reservations_expirent_sans_ligne_de_politique.sql
--
-- La suite EMPRUNTE les trois crons (fn_expire_solicitada_reservations,
-- fn_expire_negotiation_timeout, fn_detect_no_show_reservations) :
--   · bibliothèque A SANS ligne de politique : une demande de 20 jours expire
--     (défaut 14), une négociation de 25 jours expire (défaut 21), une
--     non-venue de 30 heures est détectée (défaut 24) ; une demande de 10 jours
--     reste ;
--   · bibliothèque B AVEC une ligne (demande à 30 jours) : une demande de
--     20 jours reste — la politique garde la main ;
--   · les délais de repli des trois fonctions sont toujours les DEFAULT des
--     colonnes de library_notification_policies.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'RESERVATIONS-SANS-POLITIQUE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_lecteur uuid := gen_random_uuid();
  v_suf text;
  v_libA uuid; v_libB uuid;
  v_res bigint[] := ARRAY[]::bigint[];
  v_book bigint; v_hold bigint; v_r bigint; v_k int; v_lib uuid;
  v_stage text; v_note text; v_final text; v_txt text;
  -- cas : (bibliothèque, stage initial, âge de la réservation, créneau)
  v_cas record;
BEGIN
  v_suf := substr(replace(v_lecteur::text, '-', ''), 1, 8);
  INSERT INTO auth.users (id, email) VALUES (v_lecteur, 'f20-lect-' || v_suf || '@example.invalid');
  INSERT INTO public.profiles (id) VALUES (v_lecteur) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('f20-a-' || v_suf, 'F20 A (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('f20-b-' || v_suf, 'F20 B (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_libB;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_lecteur, v_libA, 'reader', 'active', true), (v_lecteur, v_libB, 'reader', 'active', false);
  -- A n'a AUCUNE ligne de politique ; B en a une, demande à 30 jours.
  DELETE FROM public.library_notification_policies WHERE library_id = v_libA;
  INSERT INTO public.library_notification_policies (library_id, reservation_solicitada_timeout_days)
  VALUES (v_libB, 30)
  ON CONFLICT (library_id) DO UPDATE SET reservation_solicitada_timeout_days = 30;

  -- Cinq réservations, une ligne chacune, chacune sur sa notice.
  FOR v_cas IN
    SELECT * FROM (VALUES
      (1, 'A', 'solicitada',           interval '20 days', NULL::interval),
      (2, 'A', 'em_preparacao',        interval '25 days', NULL),
      (3, 'A', 'pronta_para_retirada', interval '5 days',  interval '30 hours'),
      (4, 'A', 'solicitada',           interval '10 days', NULL),
      (5, 'B', 'solicitada',           interval '20 days', NULL)
    ) AS c(n, lib, stage, age, creneau_passe)
  LOOP
    v_lib := CASE v_cas.lib WHEN 'A' THEN v_libA ELSE v_libB END;
    INSERT INTO public.books (titulo, bib_ref, tipo_material)
    VALUES ('F20 cas ' || v_cas.n || ' (essai)', 'F20-' || v_cas.n || '-' || v_suf, 'livro') RETURNING id INTO v_book;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib) RETURNING id INTO v_hold;
    INSERT INTO public.reservas_v2 (user_id, library_id, status_global, created_at)
    VALUES (v_lecteur, v_lib, 'ativa', now() - v_cas.age) RETURNING id INTO v_r;
    INSERT INTO public.reserva_linhas_v2 (reserva_id, line_no, book_id, holding_id, bib_ref, item_status)
    VALUES (v_r, 1, v_book, v_hold, 'F20-' || v_cas.n || '-' || v_suf, 'ativa');
    INSERT INTO public.reserva_item_workflow_v2 (reserva_id, line_no, workflow_stage, pickup_scheduled_for)
    VALUES (v_r, 1, v_cas.stage, CASE WHEN v_cas.creneau_passe IS NOT NULL THEN now() - v_cas.creneau_passe END)
    ON CONFLICT (reserva_id, line_no) DO UPDATE
      SET workflow_stage = excluded.workflow_stage, pickup_scheduled_for = excluded.pickup_scheduled_for;
    v_res := v_res || v_r;
  END LOOP;

  PERFORM * FROM public.fn_expire_solicitada_reservations();
  PERFORM * FROM public.fn_expire_negotiation_timeout();
  PERFORM * FROM public.fn_detect_no_show_reservations();

  v_t := 'T1 sans ligne de politique, une demande de 20 jours expire (défaut 14)';
  SELECT workflow_stage INTO v_stage FROM public.reserva_item_workflow_v2 WHERE reserva_id = v_res[1] AND line_no = 1;
  IF v_stage = 'expirada' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_stage,'NULL')); END IF;

  v_t := 'T2 sans ligne de politique, une négociation de 25 jours expire (défaut 21)';
  SELECT workflow_stage INTO v_stage FROM public.reserva_item_workflow_v2 WHERE reserva_id = v_res[2] AND line_no = 1;
  IF v_stage = 'expirada' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_stage,'NULL')); END IF;

  v_t := 'T3 sans ligne de politique, une non-venue de 30 heures est détectée (défaut 24)';
  SELECT workflow_stage, workflow_note, final_reason INTO v_stage, v_note, v_final
    FROM public.reserva_item_workflow_v2 WHERE reserva_id = v_res[3] AND line_no = 1;
  -- trg_auto_liberate_after_no_show remet aussitôt l'exemplaire en circulation :
  -- la trace de la non-venue est la note système ou final_reason.
  IF v_stage IN ('retirada_no_show', 'liberada_para_circulacao')
     AND (v_note = '@@note:systemNote.noShowAuto' OR v_final = 'no_show')
    THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_stage,'NULL')||' / '||coalesce(v_note,'∅')||' / '||coalesce(v_final,'∅')); END IF;

  v_t := 'T4 une demande de 10 jours reste (sous le délai par défaut)';
  SELECT workflow_stage INTO v_stage FROM public.reserva_item_workflow_v2 WHERE reserva_id = v_res[4] AND line_no = 1;
  IF v_stage = 'solicitada' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_stage,'NULL')); END IF;

  v_t := 'T5 avec une ligne de politique (30 jours), une demande de 20 jours reste : la politique garde la main';
  SELECT workflow_stage INTO v_stage FROM public.reserva_item_workflow_v2 WHERE reserva_id = v_res[5] AND line_no = 1;
  IF v_stage = 'solicitada' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_stage,'NULL')); END IF;

  v_t := 'T6 les replis des trois crons sont les DEFAULT des colonnes';
  SELECT string_agg(c.column_name || '=' || c.column_default, ',' ORDER BY c.column_name) INTO v_txt
    FROM information_schema.columns c
   WHERE c.table_schema = 'public' AND c.table_name = 'library_notification_policies'
     AND c.column_name IN ('reservation_solicitada_timeout_days', 'reservation_negotiation_timeout_days', 'reservation_no_show_timeout_hours');
  IF v_txt = 'reservation_negotiation_timeout_days=21,reservation_no_show_timeout_hours=24,reservation_solicitada_timeout_days=14'
     AND pg_get_functiondef('public.fn_expire_solicitada_reservations()'::regprocedure) LIKE '%coalesce(lnp.reservation_solicitada_timeout_days, 14)%'
     AND pg_get_functiondef('public.fn_expire_negotiation_timeout()'::regprocedure) LIKE '%coalesce(lnp.reservation_negotiation_timeout_days, 21)%'
     AND pg_get_functiondef('public.fn_detect_no_show_reservations()'::regprocedure) LIKE '%coalesce(lnp.reservation_no_show_timeout_hours, 24)%'
    THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'RESERVATIONS-SANS-POLITIQUE OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'RESERVATIONS-SANS-POLITIQUE ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
