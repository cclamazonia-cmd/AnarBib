-- Suite d'acceptation — migration 20260915203617_les_sources_se_testent_a_la_main
--
-- GAZ-8 : api.fn_gazette_probe_sources() n'est appelable que par un·e
-- network_staff actif·ve. La porte (EXECUTE) est ouverte à authenticated et
-- fermée à anon ; la garde de rôle vit dans le corps et refuse en 42501.
-- Tout est annulé (le DO se termine par RAISE EXCEPTION).
--
-- Ce que le banc ne prouve PAS : l'appel réseau. fn_gazette_build_call fait
-- net.http_post, que le banc n'a pas forcément ; T4 n'attend donc du staff que
-- de PASSER les gardes (toute erreur sauf 42501 et 55000 est acceptée).
--
-- 16/09/2026 (migration 20260916233000) : une seconde garde — refus 55000
-- « too_soon » si une source porte un last_fetched_at de moins d'une minute.
-- T4 vide donc les horodatages avant d'appeler ; T5 en pose un et attend le
-- refus. Tout est annulé par le RAISE EXCEPTION final.

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_staff uuid;
  v_sqlstate text;
BEGIN
  -- T1 : la fonction existe, fermée à anon, ouverte à authenticated
  v_test_name := 'T1 porte : fermée à anon, ouverte à authenticated';
  IF to_regprocedure('api.fn_gazette_probe_sources()') IS NULL THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : fonction absente');
  ELSIF has_function_privilege('anon', 'api.fn_gazette_probe_sources()', 'EXECUTE') THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ouverte à anon');
  ELSIF NOT has_function_privilege('authenticated', 'api.fn_gazette_probe_sources()', 'EXECUTE') THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : fermée à authenticated — le bouton serait muet');
  ELSE
    v_passed := v_passed + 1;
  END IF;

  -- T2 : sans session, la garde refuse (42501), rien d'autre ne se passe
  v_test_name := 'T2 sans session : 42501';
  PERFORM set_config('request.jwt.claims', '', true);
  BEGIN
    PERFORM api.fn_gazette_probe_sources();
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : passée sans session');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
    IF v_sqlstate = '42501' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || v_sqlstate || ' au lieu de 42501'); END IF;
  END;

  -- T3 : une session authentifiée qui n'est pas network_staff : 42501 aussi
  v_test_name := 'T3 authentifié non staff : 42501';
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid()::text, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM api.fn_gazette_probe_sources();
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : passée sans être staff');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
    IF v_sqlstate = '42501' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || v_sqlstate || ' au lieu de 42501'); END IF;
  END;

  -- T4 : un·e network_staff actif·ve passe les gardes (toute erreur SAUF 42501
  -- et 55000 est acceptée : l'appel réseau n'est pas l'objet du banc). Les
  -- horodatages sont vidés avant : la garde too_soon ne doit pas jouer ici.
  -- Si le seed n'a pas de staff, on le dit et on ne compte rien.
  v_test_name := 'T4 network_staff actif, aucune sonde recente : passe les gardes';
  SELECT ns.user_id INTO v_staff FROM public.network_staff ns WHERE ns.is_active LIMIT 1;
  IF v_staff IS NULL THEN
    RAISE NOTICE 'T4 non exercé : aucun network_staff actif dans le seed';
  ELSE
    UPDATE public.gazette_sources SET last_fetched_at = NULL;
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_staff::text, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM api.fn_gazette_probe_sources();
      v_passed := v_passed + 1;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
      IF v_sqlstate IN ('42501', '55000') THEN
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : refusé en ' || v_sqlstate);
      ELSE
        v_passed := v_passed + 1; -- gardes passées, l'erreur vient de l'appel réseau (net/vault absents au banc)
      END IF;
    END;
  END IF;

  -- T5 : une sonde de moins d'une minute → refus 55000 « too_soon », AVANT tout
  -- appel réseau. S'il n'y a aucune source dans le banc, on en pose une.
  v_test_name := 'T5 sonde recente : refus 55000 too_soon';
  IF v_staff IS NULL THEN
    RAISE NOTICE 'T5 non exercé : aucun network_staff actif dans le seed';
  ELSE
    IF NOT EXISTS (SELECT 1 FROM public.gazette_sources) THEN
      INSERT INTO public.gazette_sources (name, feed_url) VALUES ('banc T5', 'https://exemple.invalid/feed');
    END IF;
    UPDATE public.gazette_sources SET last_fetched_at = now()
     WHERE id = (SELECT id FROM public.gazette_sources LIMIT 1);
    BEGIN
      PERFORM api.fn_gazette_probe_sources();
      v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : passée malgré une sonde recente');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
      IF v_sqlstate = '55000' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || v_sqlstate || ' au lieu de 55000'); END IF;
    END;
  END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'GAZETTE_SOURCES_PROBE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'GAZETTE_SOURCES_PROBE OK : %/% tests passés', v_passed, v_passed;
END $$;
