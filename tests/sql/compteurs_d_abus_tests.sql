-- Compteurs d'abus (B25/B26, 16/09/2026, migration 20260916201249) :
-- T1 chaque kind qu'une fonction écrit s'insère avec une empreinte ;
-- T2 un kind inconnu est refusé (la liste est fermée : l'élargir ici ET dans la contrainte) ;
-- T3 une clé brute — un courriel, une adresse IP — est refusée ;
-- T4 la table ne porte aucune clé brute.
-- Rien n'est écrit : ROLLBACK par convention.
BEGIN;

DO $$
DECLARE
  v_ok int := 0;
  k text;
  n int;
  -- 24/09/2026 (E14) : + 'bug_ip', le compteur de submit-bug-report.
  kinds text[] := ARRAY['ip', 'email', 'geocode_ip', 'carto_ip', 'gazette_ip', 'gazette_email', 'gazette_prefill', 'bug_ip'];
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

  RAISE NOTICE 'COMPTEURS D''ABUS OK : %/4', v_ok;
END
$$;

ROLLBACK;
