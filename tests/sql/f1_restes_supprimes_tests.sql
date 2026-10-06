-- =====================================================================
-- AnarBib — Tests : les restes de F1 sans lecteur ont quitté la base (J11)
-- Date    : 2026-10-06
-- Ref     : migration 20261006190649_les_restes_de_f1_sans_lecteur_quittent_la_base
--
-- T1 la table loan_midpoint_message_log et les trois colonnes de
--    library_notification_policies n'existent plus ; aucune fonction ne les
--    nomme.
-- T2 v_library_notification_context reste ce qu'elle était, moins les deux
--    colonnes : security_invoker, lisible par authenticated, fermée à anon,
--    et toujours lisible (une ligne par bibliothèque).
-- T3 upsert_library_notification_policies (fermée aux comptes depuis le
--    02/09, sans appelant) marche encore, appelée par le système pour une
--    coordination, et ignore les clés retirées qu'une ancienne charge
--    enverrait.
-- T4 l'écriture de l'écran (Gestion de la bibliothèque > Communications :
--    update direct des drapeaux, BibliotecaPage saveComms) passe sous
--    authenticated pour la coordination.
--   Bilan OK : 'F1-RESTES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_n int; v_ok boolean; v_txt text;
BEGIN
  v_t := 'T1 table et colonnes supprimees, plus aucune fonction ne les nomme';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'library_notification_policies'
       AND column_name IN ('reservation_mail_retirada_reagendada_enabled', 'mid_loan_message_enabled', 'reading_recommendations_enabled');
    IF to_regclass('public.loan_midpoint_message_log') IS NULL AND v_n = 0
       AND NOT EXISTS (SELECT 1 FROM pg_proc WHERE prosrc ~ '(mid_loan_message_enabled|reading_recommendations_enabled|loan_midpoint_message_log)')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||format(' : table %s, %s colonne(s)', coalesce(to_regclass('public.loan_midpoint_message_log')::text, 'absente'), v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 la vue de contexte garde sa forme, ses options et ses droits';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'v_library_notification_context'
       AND column_name IN ('mid_loan_message_enabled', 'reading_recommendations_enabled');
    v_ok := v_n = 0
      AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                    AND table_name = 'v_library_notification_context' AND column_name = 'regulation_path')
      AND EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.v_library_notification_context'::regclass
                    AND reloptions @> ARRAY['security_invoker=true'])
      AND has_table_privilege('authenticated', 'public.v_library_notification_context', 'SELECT')
      AND NOT has_table_privilege('anon', 'public.v_library_notification_context', 'SELECT')
      AND (SELECT count(*) FROM public.v_library_notification_context) = (SELECT count(*) FROM public.libraries);
    IF v_ok THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||format(' : %s colonne(s) retiree(s) encore la, ou options/droits/lignes changes', v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 l''upsert des reglages marche et ignore les cles retirees';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.upsert_library_notification_policies(v_lib,
      '{"loan_overdue_enabled": false, "mid_loan_message_enabled": true, "reading_recommendations_enabled": true}'::jsonb);
    SELECT loan_overdue_enabled IS FALSE INTO v_ok FROM public.library_notification_policies WHERE library_id = v_lib;
    IF v_ok THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : reglage non enregistre'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 l''ecran enregistre les drapeaux sous authenticated';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.library_notification_policies
       SET loan_overdue_enabled = true, loan_reminders_enabled = false, task_alerts_enabled = true, updated_by = v_coord
     WHERE library_id = v_lib;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    SELECT loan_reminders_enabled IS FALSE INTO v_ok FROM public.library_notification_policies WHERE library_id = v_lib;
    IF v_n = 1 AND v_ok THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||format(' : %s ligne(s) ecrite(s)', v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'F1-RESTES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'F1-RESTES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
