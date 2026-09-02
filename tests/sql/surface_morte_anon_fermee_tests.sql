-- Suite d'acceptation — migration 20260902092104_morte_et_anonyme_aucune_des_deux
--
-- B20, premier geste : les trois fonctions mortes du schéma `api` qui étaient
-- exécutables par `anon` ne le sont plus. Le comportement du corps est
-- déjà gardé par paquet19_loan_wrappers_tests.sql (7.01, 7.04) — cette suite
-- ne garde que les droits, c'est-à-dire le seul volet que la migration touche.
--
-- 02/09 après-midi : le T3 d'origine affirmait « authenticated inchangé tant
-- que B20 n'a pas arbitré les lots ». Le lot circulation a été arbitré le jour
-- même (20260902103305 : chaîne d'agendamento fermée entière) et le T3 a rougi
-- — une hypothèse écrite comme provisoire DOIT tomber avec l'arbitrage qu'elle
-- attendait, c'est le test qui avait un jour de retard, pas la migration.
-- T3 garde désormais l'état définitif : fermées à authenticated aussi.

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
BEGIN
  -- T1 : anon n'a plus EXECUTE sur aucune des trois
  v_test_name := 'T1 anon fermé sur les trois';
  SELECT string_agg(p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('clear_loan_return_schedule','mark_loan_return_missed','schedule_loan_return')
    AND has_function_privilege('anon', p.oid, 'EXECUTE');
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore ouvertes — ' || v_liste); END IF;

  -- T2 : les trois existent toujours (une suite qui passe sur du vide ne prouve rien)
  v_test_name := 'T2 les trois existent';
  SELECT string_agg(x.nom, ', ') INTO v_liste
  FROM (VALUES ('clear_loan_return_schedule'),('mark_loan_return_missed'),('schedule_loan_return')) x(nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = x.nom);
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : absentes — ' || v_liste); END IF;

  -- T3 : depuis l'arbitrage du lot circulation (20260902103305), les trois
  -- sont fermées à authenticated aussi — leur réouverture se décide (GRANT +
  -- écran), elle ne se constate pas.
  v_test_name := 'T3 authenticated fermé (lot arbitré)';
  SELECT string_agg(p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('clear_loan_return_schedule','mark_loan_return_missed','schedule_loan_return')
    AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : rouvertes — ' || v_liste); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'SURFACE_MORTE_ANON ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'SURFACE_MORTE_ANON OK : %/% tests passés', v_passed, v_passed;
END $$;
