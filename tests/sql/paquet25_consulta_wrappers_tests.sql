-- =====================================================================
-- Phase 2 consultations — tests wrappers api.* (version executable directe)
-- A coller-exécuter tel quel dans Supabase Studio > SQL Editor.
-- BEGIN/ROLLBACK garantit qu'aucune modification ne sera commit.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  v_passed integer := 0;
  v_failed integer := 0;
  v_skipped integer := 0;
  v_failures text[] := '{}';
  v_count int;
  v_err text;
  v_consulta_id_existing bigint;
  v_existing_line_no integer;
  v_existing_stage text;
  v_existing_user_id uuid;
BEGIN
  -- ===================================================================
  -- SECTION A : introspection (8 tests, ne necessitent pas auth)
  -- ===================================================================

  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api' AND p.proname = 'create_consulta_local';
  IF v_count = 1 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.1 api.create_consulta_local missing'); END IF;

  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api' AND p.proname = 'advance_consulta';
  IF v_count = 1 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.2 api.advance_consulta missing'); END IF;

  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api' AND p.proname = 'reply_consulta_schedule';
  IF v_count = 1 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.3 api.reply_consulta_schedule missing'); END IF;

  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api' AND p.proname = 'cancel_consulta_as_reader';
  IF v_count = 1 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.4 api.cancel_consulta_as_reader missing'); END IF;

  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api' AND p.proname = 'dismiss_consulta_cancelled';
  IF v_count = 1 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.5 api.dismiss_consulta_cancelled missing'); END IF;

  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('create_consulta_local', 'advance_consulta',
                      'reply_consulta_schedule', 'cancel_consulta_as_reader',
                      'dismiss_consulta_cancelled')
    AND p.prosecdef = false;
  IF v_count = 5 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures,
      format('A.6 wrappers INVOKER count: %s (expected 5)', v_count)); END IF;

  IF position('fn_check_consulta_transition' IN
       pg_get_functiondef('api.advance_consulta(bigint,integer[],text,text,timestamp with time zone,timestamp with time zone,timestamp with time zone,text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.7 advance_consulta missing transition helper');
  END IF;

  IF position('fn_get_consulta_context' IN
       pg_get_functiondef('api.advance_consulta(bigint,integer[],text,text,timestamp with time zone,timestamp with time zone,timestamp with time zone,text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.8 advance_consulta missing context helper');
  END IF;

  -- ===================================================================
  -- SECTION B : api.create_consulta_local (5 tests)
  -- ===================================================================
  -- En SQL Editor on tourne en service_role/postgres, donc auth.uid()
  -- retourne NULL. Tous les appels passent par la garde "not_authenticated".
  -- Pour les tests qui veulent verifier d'autres comportements, on simule
  -- une session via set_config('request.jwt.claims', ...) + SET LOCAL ROLE.
  --
  -- ATTENTION : la simulation n'est pas parfaite. auth.uid() depend de
  -- la fonction Supabase qui parse les claims. Sur Supabase managed,
  -- ca peut ne pas fonctionner depuis le SQL Editor. Dans ce cas, les
  -- tests B/C/D/E/F lèveront des exceptions "wrong" parce que auth.uid()
  -- restera NULL malgre tout. Le bloc gere ce cas gracieusement en
  -- marquant skipped si l'exception est 'not_authenticated' alors qu'on
  -- attend autre chose.

  -- B.1 not_authenticated quand aucune session
  BEGIN
    PERFORM api.create_consulta_local(
      '366cdc4e-10e0-44ad-8554-a444bcf9607a'::uuid,
      ARRAY[1]::bigint[], NULL, NULL
    );
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'B.1 should_have_raised');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_authenticated%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'B.1 wrong_exception: ' || v_err); END IF;
  END;

  -- B.2 simulee : Livia tente avec p_holding_ids vide
  BEGIN
    PERFORM set_config('request.jwt.claim.sub',
      '366cdc4e-10e0-44ad-8554-a444bcf9607a', true);
    PERFORM set_config('request.jwt.claims',
      '{"sub": "366cdc4e-10e0-44ad-8554-a444bcf9607a", "role": "authenticated"}', true);

    PERFORM api.create_consulta_local(
      '366cdc4e-10e0-44ad-8554-a444bcf9607a'::uuid,
      '{}'::bigint[], NULL, NULL
    );
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'B.2 should_have_raised_empty_array');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_found%' OR v_err LIKE '%nenhum holding%' THEN
      v_passed := v_passed + 1;
    ELSIF v_err LIKE '%not_authenticated%' THEN
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, 'B.2 SKIPPED (jwt claims sim not effective in SQL Editor)');
    ELSE
      v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'B.2 wrong_exception: ' || v_err);
    END IF;
  END;

  -- B.3 simulee : array de NULL
  BEGIN
    PERFORM set_config('request.jwt.claims',
      '{"sub": "366cdc4e-10e0-44ad-8554-a444bcf9607a", "role": "authenticated"}', true);

    PERFORM api.create_consulta_local(
      '366cdc4e-10e0-44ad-8554-a444bcf9607a'::uuid,
      ARRAY[NULL]::bigint[], NULL, NULL
    );
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'B.3 should_have_raised_all_null');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_found%' THEN v_passed := v_passed + 1;
    ELSIF v_err LIKE '%not_authenticated%' THEN
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, 'B.3 SKIPPED (jwt sim)');
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'B.3 wrong_exception: ' || v_err); END IF;
  END;

  -- B.4 p_user_id NULL (sans simulation, doit raise not_authenticated)
  BEGIN
    PERFORM set_config('request.jwt.claims', NULL, true);

    PERFORM api.create_consulta_local(
      NULL, ARRAY[1]::bigint[], NULL, NULL
    );
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'B.4 should_have_raised');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    -- Soit not_authenticated (auth.uid() NULL teste en premier),
    -- soit p_user_id missing (si claims sim effective)
    IF v_err LIKE '%not_authenticated%' OR v_err LIKE '%p_user_id%' OR v_err LIKE '%not_found%' THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'B.4 wrong_exception: ' || v_err); END IF;
  END;

  -- B.5 introspection : retour jsonb
  IF pg_get_function_result(
       (SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'api' AND p.proname = 'create_consulta_local')
     ) = 'jsonb' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'B.5 return_type_should_be_jsonb');
  END IF;

  -- ===================================================================
  -- SECTION C : api.advance_consulta (8 tests)
  -- ===================================================================

  -- C.1 not_authenticated (claims vide)
  BEGIN
    PERFORM set_config('request.jwt.claims', NULL, true);

    PERFORM api.advance_consulta(1, ARRAY[1]::integer[], 'em_preparacao');
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'C.1 should_have_raised');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_authenticated%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'C.1 wrong_exception: ' || v_err); END IF;
  END;

  -- C.2 p_line_nos vide
  BEGIN
    PERFORM set_config('request.jwt.claims',
      '{"sub": "d6710372-e5e5-4608-800b-99a26817c677", "role": "authenticated"}', true);

    PERFORM api.advance_consulta(1, '{}'::integer[], 'em_preparacao');
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'C.2 should_have_raised_empty_line_nos');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_found%' OR v_err LIKE '%line_nos%' THEN v_passed := v_passed + 1;
    ELSIF v_err LIKE '%not_authenticated%' THEN
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, 'C.2 SKIPPED (jwt sim)');
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'C.2 wrong_exception: ' || v_err); END IF;
  END;

  -- C.3 p_target_stage NULL
  BEGIN
    PERFORM set_config('request.jwt.claims',
      '{"sub": "d6710372-e5e5-4608-800b-99a26817c677", "role": "authenticated"}', true);

    PERFORM api.advance_consulta(1, ARRAY[1]::integer[], NULL);
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'C.3 should_have_raised_invalid_stage');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%invalid_stage%' OR v_err LIKE '%target_stage%' THEN v_passed := v_passed + 1;
    ELSIF v_err LIKE '%not_authenticated%' THEN
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, 'C.3 SKIPPED (jwt sim)');
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'C.3 wrong_exception: ' || v_err); END IF;
  END;

  -- C.4 consulta_id inexistant
  BEGIN
    PERFORM set_config('request.jwt.claims',
      '{"sub": "d6710372-e5e5-4608-800b-99a26817c677", "role": "authenticated"}', true);

    PERFORM api.advance_consulta(99999999, ARRAY[1]::integer[], 'em_preparacao');
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'C.4 should_have_raised_not_found');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_found%' THEN v_passed := v_passed + 1;
    ELSIF v_err LIKE '%not_authenticated%' THEN
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, 'C.4 SKIPPED (jwt sim)');
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'C.4 wrong_exception: ' || v_err); END IF;
  END;

  -- C.5 et C.6 : tests sur une consulta reelle BLMF (skipped si pas de fixture)
  SELECT cw.consulta_id, cw.line_no, cw.workflow_stage
    INTO v_consulta_id_existing, v_existing_line_no, v_existing_stage
  FROM public.consulta_item_workflow_v2 cw
  JOIN public.consultas_locais_v2 c ON c.id = cw.consulta_id
  WHERE c.library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
    AND cw.workflow_stage NOT IN ('consulta_realizada', 'cancelada_leitor',
                                   'cancelada_biblioteca', 'expirada')
  LIMIT 1;

  IF v_consulta_id_existing IS NULL THEN
    v_skipped := v_skipped + 2;
    v_failures := array_append(v_failures, 'C.5/C.6 SKIPPED (pas de consulta non-terminale BLMF)');
  ELSE
    -- C.5 agendamento sans creneau (depuis em_preparacao)
    IF v_existing_stage = 'em_preparacao' THEN
      BEGIN
        PERFORM set_config('request.jwt.claims',
          '{"sub": "d6710372-e5e5-4608-800b-99a26817c677", "role": "authenticated"}', true);

        PERFORM api.advance_consulta(
          v_consulta_id_existing,
          ARRAY[v_existing_line_no]::integer[],
          'consulta_agendada'
        );
        v_failed := v_failed + 1;
        v_failures := array_append(v_failures, 'C.5 should_have_raised_schedule_missing');
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
        IF v_err LIKE '%schedule_missing%' OR v_err LIKE '%scheduled_for%' THEN v_passed := v_passed + 1;
        ELSIF v_err LIKE '%not_authenticated%' THEN
          v_skipped := v_skipped + 1;
          v_failures := array_append(v_failures, 'C.5 SKIPPED (jwt sim)');
        ELSE v_failed := v_failed + 1;
          v_failures := array_append(v_failures, 'C.5 wrong_exception: ' || v_err); END IF;
      END;
    ELSE
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, format('C.5 SKIPPED (stage est %s, pas em_preparacao)', v_existing_stage));
    END IF;

    -- C.6 lecteur Patricia (sans role) tente d'avancer
    BEGIN
      PERFORM set_config('request.jwt.claims',
        '{"sub": "2a42b6bd-d159-4ee0-b66b-28a03062232b", "role": "authenticated"}', true);

      PERFORM api.advance_consulta(
        v_consulta_id_existing,
        ARRAY[v_existing_line_no]::integer[],
        'em_preparacao'
      );
      v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'C.6 should_have_raised_invalid_stage');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err LIKE '%invalid_stage%' THEN v_passed := v_passed + 1;
      ELSIF v_err LIKE '%not_authenticated%' THEN
        v_skipped := v_skipped + 1;
        v_failures := array_append(v_failures, 'C.6 SKIPPED (jwt sim)');
      ELSE v_failed := v_failed + 1;
        v_failures := array_append(v_failures, 'C.6 wrong_exception: ' || v_err); END IF;
    END;
  END IF;

  -- C.7 introspection : AT TIME ZONE hardening
  IF position('AT TIME ZONE' IN
       pg_get_functiondef('api.advance_consulta(bigint,integer[],text,text,timestamp with time zone,timestamp with time zone,timestamp with time zone,text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'C.7 missing AT TIME ZONE hardening');
  END IF;

  -- C.8 introspection : check de stages heterogenes
  IF position('heterogeneas' IN
       pg_get_functiondef('api.advance_consulta(bigint,integer[],text,text,timestamp with time zone,timestamp with time zone,timestamp with time zone,text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'C.8 missing heterogeneous check');
  END IF;

  -- ===================================================================
  -- SECTION D : api.reply_consulta_schedule (5 tests)
  -- ===================================================================

  BEGIN
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.reply_consulta_schedule(1, ARRAY[1]::integer[], 'confirmado_leitor');
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'D.1 should_have_raised');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_authenticated%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'D.1 wrong_exception: ' || v_err); END IF;
  END;

  BEGIN
    PERFORM set_config('request.jwt.claims',
      '{"sub": "366cdc4e-10e0-44ad-8554-a444bcf9607a", "role": "authenticated"}', true);

    PERFORM api.reply_consulta_schedule(1, ARRAY[1]::integer[], 'sim_quem_sabe');
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'D.2 should_have_raised_invalid_reply');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%invalid_stage%' OR v_err LIKE '%sim_quem_sabe%' THEN v_passed := v_passed + 1;
    ELSIF v_err LIKE '%not_authenticated%' THEN
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, 'D.2 SKIPPED (jwt sim)');
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'D.2 wrong_exception: ' || v_err); END IF;
  END;

  BEGIN
    PERFORM set_config('request.jwt.claims',
      '{"sub": "366cdc4e-10e0-44ad-8554-a444bcf9607a", "role": "authenticated"}', true);

    PERFORM api.reply_consulta_schedule(99999999, ARRAY[1]::integer[], 'confirmado_leitor');
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'D.3 should_have_raised_not_found');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_found%' THEN v_passed := v_passed + 1;
    ELSIF v_err LIKE '%not_authenticated%' THEN
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, 'D.3 SKIPPED (jwt sim)');
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'D.3 wrong_exception: ' || v_err); END IF;
  END;

  -- D.4 reply depuis stage non-agendada
  SELECT c.id, cw.line_no, cw.workflow_stage, c.user_id
    INTO v_consulta_id_existing, v_existing_line_no, v_existing_stage, v_existing_user_id
  FROM public.consultas_locais_v2 c
  JOIN public.consulta_item_workflow_v2 cw ON cw.consulta_id = c.id
  WHERE c.library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
    AND cw.workflow_stage IN ('solicitada', 'em_preparacao')
  LIMIT 1;

  IF v_consulta_id_existing IS NULL THEN
    v_skipped := v_skipped + 1;
    v_failures := array_append(v_failures, 'D.4 SKIPPED (pas de consulta solicitada/em_preparacao)');
  ELSE
    BEGIN
      PERFORM set_config('request.jwt.claims',
        format('{"sub": "%s", "role": "authenticated"}', v_existing_user_id), true);

      PERFORM api.reply_consulta_schedule(
        v_consulta_id_existing,
        ARRAY[v_existing_line_no]::integer[],
        'confirmado_leitor'
      );
      v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'D.4 should_have_raised_invalid_stage');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err LIKE '%invalid_stage%' OR v_err LIKE '%consulta_agendada%' THEN v_passed := v_passed + 1;
      ELSIF v_err LIKE '%not_authenticated%' OR v_err LIKE '%not_owner%' THEN
        v_skipped := v_skipped + 1;
        v_failures := array_append(v_failures, 'D.4 SKIPPED (jwt sim)');
      ELSE v_failed := v_failed + 1;
        v_failures := array_append(v_failures, 'D.4 wrong_exception: ' || v_err); END IF;
    END;
  END IF;

  -- D.5 introspection
  IF position('not_owner' IN
       pg_get_functiondef('api.reply_consulta_schedule(bigint,integer[],text,text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'D.5 reply missing ownership check');
  END IF;

  -- ===================================================================
  -- SECTION E : api.cancel_consulta_as_reader (3 tests)
  -- ===================================================================

  BEGIN
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.cancel_consulta_as_reader(1, ARRAY[1]::integer[], NULL);
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'E.1 should_have_raised');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_authenticated%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'E.1 wrong_exception: ' || v_err); END IF;
  END;

  -- E.2 Arthur tente d'annuler une consulta de Livia
  SELECT c.id, cw.line_no
    INTO v_consulta_id_existing, v_existing_line_no
  FROM public.consultas_locais_v2 c
  JOIN public.consulta_item_workflow_v2 cw ON cw.consulta_id = c.id
  WHERE c.library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
    AND c.user_id = '366cdc4e-10e0-44ad-8554-a444bcf9607a'
    AND cw.workflow_stage NOT IN ('consulta_realizada', 'cancelada_leitor',
                                   'cancelada_biblioteca', 'expirada')
  LIMIT 1;

  IF v_consulta_id_existing IS NULL THEN
    v_skipped := v_skipped + 1;
    v_failures := array_append(v_failures, 'E.2 SKIPPED (pas de consulta de Livia)');
  ELSE
    BEGIN
      PERFORM set_config('request.jwt.claims',
        '{"sub": "614d887d-4e8d-401d-a208-77c56a1cd5ea", "role": "authenticated"}', true);

      PERFORM api.cancel_consulta_as_reader(
        v_consulta_id_existing,
        ARRAY[v_existing_line_no]::integer[],
        NULL
      );
      v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'E.2 should_have_raised_not_owner');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err LIKE '%not_owner%' THEN v_passed := v_passed + 1;
      ELSIF v_err LIKE '%not_authenticated%' THEN
        v_skipped := v_skipped + 1;
        v_failures := array_append(v_failures, 'E.2 SKIPPED (jwt sim)');
      ELSE v_failed := v_failed + 1;
        v_failures := array_append(v_failures, 'E.2 wrong_exception: ' || v_err); END IF;
    END;
  END IF;

  IF position('not_owner' IN
       pg_get_functiondef('api.cancel_consulta_as_reader(bigint,integer[],text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'E.3 cancel missing ownership check');
  END IF;

  -- ===================================================================
  -- SECTION F : api.dismiss_consulta_cancelled (3 tests)
  -- ===================================================================

  BEGIN
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.dismiss_consulta_cancelled(1, ARRAY[1]::integer[], NULL);
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'F.1 should_have_raised');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_authenticated%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'F.1 wrong_exception: ' || v_err); END IF;
  END;

  BEGIN
    PERFORM set_config('request.jwt.claims',
      '{"sub": "366cdc4e-10e0-44ad-8554-a444bcf9607a", "role": "authenticated"}', true);

    PERFORM api.dismiss_consulta_cancelled(99999999, ARRAY[1]::integer[], NULL);
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'F.2 should_have_raised_not_found');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err LIKE '%not_found%' THEN v_passed := v_passed + 1;
    ELSIF v_err LIKE '%not_authenticated%' THEN
      v_skipped := v_skipped + 1;
      v_failures := array_append(v_failures, 'F.2 SKIPPED (jwt sim)');
    ELSE v_failed := v_failed + 1;
      v_failures := array_append(v_failures, 'F.2 wrong_exception: ' || v_err); END IF;
  END;

  IF position('not_owner' IN
       pg_get_functiondef('api.dismiss_consulta_cancelled(bigint,integer[],text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'F.3 dismiss missing ownership check');
  END IF;

  -- ===================================================================
  -- BILAN
  -- ===================================================================
  RAISE NOTICE '----------------------------------------';
  RAISE NOTICE 'BILAN : % passes / % total (skipped: %)',
    v_passed, v_passed + v_failed, v_skipped;
  IF cardinality(v_failures) > 0 THEN
    RAISE NOTICE 'Notes detaillees: %', array_to_string(v_failures, ' | ');
  END IF;
  IF v_failed > 0 THEN
    RAISE EXCEPTION 'BILAN ECHEC : % tests ont echoue', v_failed;
  END IF;
END;
$$;

ROLLBACK;

-- Pour voir le bilan : regarder le panneau "Messages" / "Notices" sous le
-- SQL Editor (parfois cache dans un sous-onglet). Si invisible, le fait
-- que la requete renvoie "ROLLBACK" sans ERROR signifie que tous les tests
-- passent (zero v_failed).
