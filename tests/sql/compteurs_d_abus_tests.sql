-- Compteurs d'abus (B25/B26, 16/09/2026, migration 20260916201249) :
-- T1 chaque kind qu'une fonction écrit s'insère avec une empreinte ;
-- T2 un kind inconnu est refusé (la liste est fermée : l'élargir ici ET dans la contrainte) ;
-- T3 une clé brute — un courriel, une adresse IP — est refusée ;
-- T4 la table ne porte aucune clé brute.
-- 19/10/2026 (migration 20261019155956), public.fn_compteur_frapper et fn_compteur_rendre :
-- T5 sous la limite → false ; la frappe de trop → true ; un bloc en cours refuse sans compter ;
-- T6 une première frappe plus vieille qu'une fenêtre : le compte repart de 1 ;
-- T7 un bloc expiré : le compte repart de 1, sans bloc ;
-- T8 la durée de blocage peut dépasser la fenêtre (login : 15 min / 60 min) ;
-- T9 rendre retire une frappe d'un compteur libre, jamais d'un compteur bloqué ;
-- T10 anon et authenticated n'exécutent ni l'une ni l'autre, service_role oui ;
-- T11 une limite ou une fenêtre hors bornes lève 22023 ;
-- T12 l'usage Altcha « gazette » est admis.
-- Rien n'est écrit : ROLLBACK par convention.
BEGIN;

DO $$
DECLARE
  v_ok int := 0;
  k text;
  n int;
  -- 24/09/2026 (E14) : + 'bug_ip', le compteur de submit-bug-report.
  -- 13/10/2026 (B45) : 'geocode_ip' devient 'geocode_user' (geocode compte par compte).
  -- 19/10/2026 : + 'register_ip', 'register_dest', les compteurs de register.
  kinds text[] := ARRAY['ip', 'email', 'geocode_user', 'carto_ip', 'gazette_ip', 'gazette_email', 'gazette_prefill', 'bug_ip', 'register_ip', 'register_dest'];
BEGIN
  -- T1
  FOREACH k IN ARRAY kinds LOOP
    INSERT INTO public.auth_rate_limits (kind, key, failure_count, first_failure_at, last_failure_at, blocked_until)
    VALUES (k, repeat('a', 64), 1, now(), now(), NULL);
  END LOOP;
  SELECT count(*) INTO n FROM public.auth_rate_limits WHERE key = repeat('a', 64);
  IF n <> array_length(kinds, 1) THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : % kind(s) écrits pour % attendus', n, array_length(kinds, 1);
  END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 1 OK — les % kinds des quatre fonctions s''écrivent.', array_length(kinds, 1);

  -- T2
  BEGIN
    INSERT INTO public.auth_rate_limits (kind, key, failure_count, first_failure_at, last_failure_at)
    VALUES ('inconnu', repeat('b', 64), 1, now(), now());
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : un kind inconnu a été accepté';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 2 OK — un kind hors liste est refusé.';

  -- T3
  FOREACH k IN ARRAY ARRAY['louise@test.local', '88.189.243.104', 'Louise'] LOOP
    BEGIN
      INSERT INTO public.auth_rate_limits (kind, key, failure_count, first_failure_at, last_failure_at)
      VALUES ('email', k, 1, now(), now());
      RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : la clé brute « % » a été acceptée', k;
    EXCEPTION WHEN check_violation THEN
      NULL;
    END;
  END LOOP;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 3 OK — une clé qui n''est pas une empreinte est refusée.';

  -- T4
  SELECT count(*) INTO n FROM public.auth_rate_limits WHERE key !~ '^[0-9a-f]{64}$';
  IF n <> 0 THEN RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : % clé(s) brute(s) dans la table', n; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 4 OK — aucune clé brute.';

  -- T5
  IF public.fn_compteur_frapper('carto_ip', repeat('c', 64), 3, 60)
     OR public.fn_compteur_frapper('carto_ip', repeat('c', 64), 3, 60)
     OR public.fn_compteur_frapper('carto_ip', repeat('c', 64), 3, 60) THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : une frappe sous la limite a été refusée';
  END IF;
  IF NOT public.fn_compteur_frapper('carto_ip', repeat('c', 64), 3, 60) THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : la frappe de trop est passée';
  END IF;
  IF NOT public.fn_compteur_frapper('carto_ip', repeat('c', 64), 3, 60) THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : un bloc en cours a laissé passer';
  END IF;
  SELECT failure_count INTO n FROM public.auth_rate_limits WHERE kind = 'carto_ip' AND key = repeat('c', 64);
  IF n <> 4 THEN RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : % frappes comptées, 4 attendues (le bloc ne compte pas)', n; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 5 OK — sous la limite, de trop, bloc en cours.';

  -- T6
  INSERT INTO public.auth_rate_limits (kind, key, failure_count, first_failure_at, last_failure_at, blocked_until)
  VALUES ('bug_ip', repeat('d', 64), 9, now() - interval '2 hours', now() - interval '2 hours', NULL);
  IF public.fn_compteur_frapper('bug_ip', repeat('d', 64), 3, 60) THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : une fenêtre périmée a refusé';
  END IF;
  SELECT failure_count INTO n FROM public.auth_rate_limits WHERE kind = 'bug_ip' AND key = repeat('d', 64);
  IF n <> 1 THEN RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le compte vaut % au lieu de 1', n; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 6 OK — une fenêtre périmée repart de 1.';

  -- T7
  INSERT INTO public.auth_rate_limits (kind, key, failure_count, first_failure_at, last_failure_at, blocked_until)
  VALUES ('bug_ip', repeat('e', 64), 4, now() - interval '10 minutes', now() - interval '10 minutes', now() - interval '1 minute');
  IF public.fn_compteur_frapper('bug_ip', repeat('e', 64), 3, 60) THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : un bloc expiré refuse encore';
  END IF;
  IF (SELECT failure_count <> 1 OR blocked_until IS NOT NULL FROM public.auth_rate_limits WHERE kind = 'bug_ip' AND key = repeat('e', 64)) THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : après un bloc expiré, le compte ne repart pas de 1 sans bloc';
  END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 7 OK — un bloc expiré repart de 1.';

  -- T8
  PERFORM public.fn_compteur_frapper('ip', repeat('f', 64), 1, 15, 60);
  IF NOT public.fn_compteur_frapper('ip', repeat('f', 64), 1, 15, 60) THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : la seconde frappe sur une limite de 1 est passée';
  END IF;
  IF (SELECT blocked_until < now() + interval '59 minutes' FROM public.auth_rate_limits WHERE kind = 'ip' AND key = repeat('f', 64)) THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : le blocage ne dure pas 60 minutes';
  END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 8 OK — blocage plus long que la fenêtre.';

  -- T9
  PERFORM public.fn_compteur_frapper('register_ip', repeat('1', 64), 5, 60);
  PERFORM public.fn_compteur_frapper('register_ip', repeat('1', 64), 5, 60);
  PERFORM public.fn_compteur_rendre('register_ip', repeat('1', 64));
  SELECT failure_count INTO n FROM public.auth_rate_limits WHERE kind = 'register_ip' AND key = repeat('1', 64);
  IF n <> 1 THEN RAISE EXCEPTION 'TEST 9 ÉCHOUÉ : rendre laisse % frappes au lieu de 1', n; END IF;
  PERFORM public.fn_compteur_rendre('ip', repeat('f', 64));   -- bloqué en T8 : rien ne bouge
  SELECT failure_count INTO n FROM public.auth_rate_limits WHERE kind = 'ip' AND key = repeat('f', 64);
  IF n <> 2 THEN RAISE EXCEPTION 'TEST 9 ÉCHOUÉ : rendre a touché un compteur bloqué (% frappes)', n; END IF;
  PERFORM public.fn_compteur_rendre('ip', repeat('2', 64));   -- compteur absent : sans erreur
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 9 OK — rendre, jamais sur un bloc.';

  -- T10
  FOREACH k IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    IF has_function_privilege(k, 'public.fn_compteur_frapper(text, text, integer, integer, integer)', 'EXECUTE')
       OR has_function_privilege(k, 'public.fn_compteur_rendre(text, text)', 'EXECUTE') THEN
      RAISE EXCEPTION 'TEST 10 ÉCHOUÉ : % peut exécuter un compteur', k;
    END IF;
  END LOOP;
  IF NOT has_function_privilege('service_role', 'public.fn_compteur_frapper(text, text, integer, integer, integer)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.fn_compteur_rendre(text, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 10 ÉCHOUÉ : service_role ne peut pas compter';
  END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 10 OK — compteurs réservés à service_role.';

  -- T11
  BEGIN
    PERFORM public.fn_compteur_frapper('ip', repeat('3', 64), 0, 60);
    RAISE EXCEPTION 'TEST 11 ÉCHOUÉ : une limite nulle a été acceptée';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM public.fn_compteur_frapper('ip', repeat('3', 64), 5, 0);
    RAISE EXCEPTION 'TEST 11 ÉCHOUÉ : une fenêtre nulle a été acceptée';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 11 OK — bornes gardées.';

  -- T12
  IF NOT public.fn_consume_altcha_challenge(repeat('9', 64), now() + interval '10 minutes', 'gazette') THEN
    RAISE EXCEPTION 'TEST 12 ÉCHOUÉ : un défi neuf pour la gazette est refusé';
  END IF;
  IF public.fn_consume_altcha_challenge(repeat('9', 64), now() + interval '10 minutes', 'gazette') THEN
    RAISE EXCEPTION 'TEST 12 ÉCHOUÉ : un défi de la gazette se rejoue';
  END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 12 OK — usage Altcha gazette admis, sans rejeu.';

  RAISE NOTICE 'COMPTEURS D''ABUS OK : %/12', v_ok;
END
$$;

ROLLBACK;
