-- =============================================================================
-- Tests SQL — Paquet 26 L2 — Triggers notifications consultations
-- À lancer dans Supabase Studio SQL Editor APRÈS application de la migration
-- via Woodpecker.
--
-- IMPORTANT : Ces tests sont EN LECTURE SEULE (introspection + smoke checks
-- non destructifs). Aucun INSERT/UPDATE/DELETE sur les tables consultas.
-- Pour des tests fonctionnels end-to-end, voir Phase 6 (paquet ultérieur).
-- =============================================================================

DO $$
DECLARE
  v_passed integer := 0;
  v_failed integer := 0;
  v_skipped integer := 0;
  v_msg text;

  v_def_lifecycle text;
  v_def_workflow text;
  v_trg_def_lifecycle text;
  v_trg_def_workflow text;
  v_security text;
  v_search_path text;
BEGIN
  RAISE NOTICE '=== Tests Paquet 26 L2 — Triggers notifications consultations ===';
  RAISE NOTICE '';

  -- ============================================================
  -- TEST 1 : Function trg_notify_consulta_lifecycle existe
  -- ============================================================
  BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def_lifecycle
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_lifecycle';

    IF v_def_lifecycle IS NOT NULL THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 1  OK : trg_notify_consulta_lifecycle existe (% chars)', length(v_def_lifecycle);
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 1 FAIL : trg_notify_consulta_lifecycle absente';
    END IF;
  END;

  -- ============================================================
  -- TEST 2 : Function trg_notify_consulta_workflow existe
  -- ============================================================
  BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def_workflow
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_workflow';

    IF v_def_workflow IS NOT NULL THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 2  OK : trg_notify_consulta_workflow existe (% chars)', length(v_def_workflow);
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 2 FAIL : trg_notify_consulta_workflow absente';
    END IF;
  END;

  -- ============================================================
  -- TEST 3 : Les 2 fns sont SECURITY DEFINER (calque reserva)
  -- ============================================================
  BEGIN
    SELECT
      CASE WHEN p.prosecdef THEN 'DEFINER' ELSE 'INVOKER' END INTO v_security
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_lifecycle';

    IF v_security = 'DEFINER' THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 3a OK : trg_notify_consulta_lifecycle est SECURITY DEFINER';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 3a FAIL : trg_notify_consulta_lifecycle est SECURITY % (attendu DEFINER)', v_security;
    END IF;

    SELECT
      CASE WHEN p.prosecdef THEN 'DEFINER' ELSE 'INVOKER' END INTO v_security
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_workflow';

    IF v_security = 'DEFINER' THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 3b OK : trg_notify_consulta_workflow est SECURITY DEFINER';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 3b FAIL : trg_notify_consulta_workflow est SECURITY % (attendu DEFINER)', v_security;
    END IF;
  END;

  -- ============================================================
  -- TEST 4 : Trigger trg_notify_consulta_lifecycle posé sur consulta_linhas_v2
  -- ============================================================
  BEGIN
    SELECT pg_get_triggerdef(t.oid) INTO v_trg_def_lifecycle
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'consulta_linhas_v2'
      AND t.tgname = 'trg_notify_consulta_lifecycle'
      AND NOT t.tgisinternal;

    IF v_trg_def_lifecycle IS NOT NULL THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 4  OK : trigger lifecycle declare sur consulta_linhas_v2';
      RAISE NOTICE '         def: %', v_trg_def_lifecycle;
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 4 FAIL : trigger lifecycle absent de consulta_linhas_v2';
    END IF;
  END;

  -- ============================================================
  -- TEST 5 : Trigger trg_notify_consulta_workflow posé sur consulta_item_workflow_v2
  -- ============================================================
  BEGIN
    SELECT pg_get_triggerdef(t.oid) INTO v_trg_def_workflow
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'consulta_item_workflow_v2'
      AND t.tgname = 'trg_notify_consulta_workflow'
      AND NOT t.tgisinternal;

    IF v_trg_def_workflow IS NOT NULL THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 5  OK : trigger workflow declare sur consulta_item_workflow_v2';
      RAISE NOTICE '         def: %', v_trg_def_workflow;
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 5 FAIL : trigger workflow absent de consulta_item_workflow_v2';
    END IF;
  END;

  -- ============================================================
  -- TEST 6 : Les fns référencent toutes les colonnes flag attendues
  -- ============================================================
  BEGIN
    IF v_def_lifecycle ~ 'consulta_mail_criada_enabled'
       AND v_def_lifecycle ~ 'consulta_mail_realizada_enabled'
       AND v_def_lifecycle ~ 'consulta_mail_cancelada_enabled'
       AND v_def_lifecycle ~ 'consulta_mail_expirada_enabled'
       AND v_def_lifecycle ~ 'local_consultation_enabled'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 6a OK : lifecycle reference les 4 flags lifecycle + master switch';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 6a FAIL : lifecycle ne reference pas tous les flags attendus';
    END IF;

    IF v_def_workflow ~ 'consulta_mail_agendada_enabled'
       AND v_def_workflow ~ 'consulta_mail_resposta_creneau_enabled'
       AND v_def_workflow ~ 'local_consultation_enabled'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 6b OK : workflow reference les 2 flags workflow + master switch';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 6b FAIL : workflow ne reference pas tous les flags attendus';
    END IF;
  END;

  -- ============================================================
  -- TEST 7 : Les fns référencent les 6 events consulta_v2_*
  -- ============================================================
  BEGIN
    IF v_def_lifecycle ~ 'consulta_v2_criada'
       AND v_def_lifecycle ~ 'consulta_v2_realizada'
       AND v_def_lifecycle ~ 'consulta_v2_cancelada'
       AND v_def_lifecycle ~ 'consulta_v2_expirada'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 7a OK : lifecycle emet les 4 events lifecycle';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 7a FAIL : lifecycle n''emet pas les 4 events attendus';
    END IF;

    IF v_def_workflow ~ 'consulta_v2_agendada'
       AND v_def_workflow ~ 'consulta_v2_resposta_creneau'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 7b OK : workflow emet les 2 events workflow';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 7b FAIL : workflow n''emet pas les 2 events attendus';
    END IF;
  END;

  -- ============================================================
  -- TEST 8 : Les fns appellent fn_dispatch_circulation_notify_event
  -- ============================================================
  BEGIN
    IF v_def_lifecycle ~ 'fn_dispatch_circulation_notify_event'
       AND v_def_workflow ~ 'fn_dispatch_circulation_notify_event'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 8  OK : les 2 fns utilisent le helper canonique fn_dispatch_circulation_notify_event';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 8 FAIL : helper canonique non utilise par toutes les fns';
    END IF;
  END;

  -- ============================================================
  -- TEST 9 : Cohérence définition trigger lifecycle
  --          (AFTER INSERT OR UPDATE OF item_status FOR EACH ROW)
  -- ============================================================
  BEGIN
    IF v_trg_def_lifecycle ~ 'AFTER INSERT OR UPDATE OF item_status'
       AND v_trg_def_lifecycle ~ 'FOR EACH ROW'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 9  OK : trigger lifecycle est AFTER INSERT OR UPDATE OF item_status FOR EACH ROW';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 9 FAIL : trigger lifecycle a une declaration inattendue';
    END IF;
  END;

  -- ============================================================
  -- TEST 10 : Cohérence définition trigger workflow
  -- ============================================================
  BEGIN
    IF v_trg_def_workflow ~ 'AFTER INSERT OR UPDATE OF'
       AND v_trg_def_workflow ~ 'workflow_stage'
       AND v_trg_def_workflow ~ 'schedule_reply_status'
       AND v_trg_def_workflow ~ 'FOR EACH ROW'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 10 OK : trigger workflow declare AFTER INSERT OR UPDATE OF workflow_stage, schedule_reply_status FOR EACH ROW';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 10 FAIL : trigger workflow a une declaration inattendue';
    END IF;
  END;

  -- ============================================================
  -- TEST 11 : Search path 'public' explicite (defensive)
  -- ============================================================
  BEGIN
    IF v_def_lifecycle ~ 'SET search_path TO ''public'''
       AND v_def_workflow ~ 'SET search_path TO ''public'''
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 11 OK : les 2 fns ont SET search_path TO public (defensive)';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 11 FAIL : search_path non force a public';
    END IF;
  END;

  -- ============================================================
  -- TEST 12 : Lecture explicite de cancelled_by dans lifecycle
  -- ============================================================
  BEGIN
    IF v_def_lifecycle ~ 'cancelled_by'
       AND v_def_lifecycle ~ 'leitor'
       AND v_def_lifecycle ~ 'biblioteca'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 12 OK : lifecycle construit le payload avec cancelled_by leitor/biblioteca';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 12 FAIL : lifecycle ne discrimine pas le cancelled_by';
    END IF;
  END;

  -- ============================================================
  -- TEST 13 : payload workflow contient schedule_reply_status
  -- ============================================================
  BEGIN
    IF v_def_workflow ~ 'schedule_reply_status'
       AND v_def_workflow ~ 'confirmado_leitor'
       AND v_def_workflow ~ 'recusado_leitor'
    THEN
      v_passed := v_passed + 1;
      RAISE NOTICE 'TEST 13 OK : workflow filtre confirmado_leitor/recusado_leitor + inclut dans payload';
    ELSE
      v_failed := v_failed + 1;
      RAISE WARNING 'TEST 13 FAIL : workflow ne traite pas le schedule_reply_status correctement';
    END IF;
  END;

  -- ============================================================
  -- Bilan final
  -- ============================================================
  RAISE NOTICE '';
  RAISE NOTICE '=== BILAN : % passes, % echecs, % skipped ===',
    v_passed, v_failed, v_skipped;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'Paquet 26 L2 — % tests ont echoue. Revoir la migration.', v_failed;
  ELSE
    RAISE NOTICE 'Paquet 26 L2 — Tous les tests passes. Triggers en place.';
    RAISE NOTICE '';
    RAISE NOTICE 'PROCHAINES ETAPES :';
    RAISE NOTICE '  1. Les triggers vont commencer a emettre des events des qu''une consulta est creee/modifiee';
    RAISE NOTICE '  2. notify-event recevra les events et retournera 200 ignored (dispatch.ts ne les route pas encore)';
    RAISE NOTICE '  3. AUCUN MAIL n''est envoye tant que L3 (i18n) + L4 (handler TS) ne sont pas en prod';
    RAISE NOTICE '  4. Comportement attendu — passer maintenant a L3 + L4';
  END IF;
END;
$$;
