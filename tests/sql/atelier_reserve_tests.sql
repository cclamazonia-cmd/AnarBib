-- ═══════════════════════════════════════════════════════════════════════
-- AnarBib — E36 (10/10/2026) : l'Atelier des autorités dit à qui il est réservé.
--   T1 un compte lecteur : fn_authority_list → 42501, HINT error.atelier.reserved ;
--   T2 un compte lecteur : conv_revue_resume et conv_revue_list → 42501,
--      HINT error.atelier.reservedStaff ;
--   T3 un compte lecteur : fn_authority_propose → HINT error.atelier.notContributor ;
--      fn_authority_apply → error.atelier.notStaff (objecter : atelier_oeuvres T2) ;
--   T4 une coordination active lit la liste et le résumé (les gardes ne se sont
--      pas resserrées) ;
--   T5 aucune RPC fn_authority_* ne porte plus un HINT atelier.error.* (jamais traduit).
-- Tout se fait sous le rôle authenticated avec des claims ; la suite lève toujours.
-- ═══════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_lib uuid; v_lecteur uuid := gen_random_uuid(); v_coord uuid := gen_random_uuid(); v_u uuid;
  v_hint text; v_hint2 text; v_hint3 text; v_state text; v_txt text; v_n int; v_b boolean;
BEGIN
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level)
  VALUES ('e36-' || v_suf, 'E36 (essai)', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_lib;
  FOREACH v_u IN ARRAY ARRAY[v_lecteur, v_coord] LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', v_u, 'authenticated', 'authenticated', 'e36-' || v_u || '@anarbib.local', now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb);
    INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language) VALUES (v_u, 'e36-' || v_u || '@anarbib.local', 'E36', 'Essai', 'fr');
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES (v_lecteur, v_lib, 'reader', 'active'), (v_coord, v_lib, 'coordenador', 'active');

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 un compte lecteur : fn_authority_list refuse avec error.atelier.reserved (42501)';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lecteur, 'role', 'authenticated')::text, true);
    BEGIN PERFORM 1 FROM api.fn_authority_list(); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    RESET ROLE;
    v_b := v_txt = 'refusé' AND v_state = '42501' AND v_hint = 'error.atelier.reserved';
    IF v_b THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s', v_txt, v_state, v_hint)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 un compte lecteur : conv_revue_resume et conv_revue_list refusent avec error.atelier.reservedStaff';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lecteur, 'role', 'authenticated')::text, true);
    BEGIN PERFORM 1 FROM api.conv_revue_resume(); v_hint := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; END;
    BEGIN PERFORM 1 FROM api.conv_revue_list('autorite_patronyme', 'a_revoir', 10, 0); v_hint2 := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; END;
    RESET ROLE;
    v_b := v_hint = 'error.atelier.reservedStaff' AND v_hint2 = 'error.atelier.reservedStaff' AND v_state = '42501';
    IF v_b THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s / %s', v_hint, v_hint2)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 un compte lecteur : proposer et appliquer refusent avec des HINT error.atelier.* (objecter : atelier_oeuvres T2)';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lecteur, 'role', 'authenticated')::text, true);
    BEGIN PERFORM api.fn_authority_propose('edition', 'author', 1, NULL, '{}'::jsonb, 'essai E36 : un motif assez long'); v_hint := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    BEGIN PERFORM api.fn_authority_apply(gen_random_uuid()); v_hint2 := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; END;
    RESET ROLE;
    -- objecter : le HINT notCoordenador est tenu par atelier_oeuvres_tests (T2), sur une proposition réelle
    v_b := v_hint = 'error.atelier.notContributor' AND v_hint2 = 'error.atelier.notStaff';
    IF v_b THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s / %s', v_hint, v_hint2)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 une coordination active lit la liste des propositions et le résumé de la file';
  BEGIN
    SET ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM api.fn_authority_list();
    PERFORM 1 FROM api.conv_revue_resume();
    RESET ROLE;
    v_b := v_n >= 0;
    IF v_b THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 plus aucune fonction (public, api, private) ne porte un HINT atelier.error.* (jamais traduit)';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('public', 'api', 'private') AND p.prosrc LIKE '%atelier.error.%';
    v_b := v_n = 0;
    IF v_b THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s fonction(s)', v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'ATELIER-RESERVE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'ATELIER-RESERVE OK : %/%', v_passed, v_passed;
END $$;
