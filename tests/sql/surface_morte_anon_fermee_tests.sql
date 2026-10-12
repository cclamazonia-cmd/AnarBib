-- Suite d'acceptation — migrations 20260902092104_morte_et_anonyme_aucune_des_deux
-- puis 20261012111851_sept_portes_sans_appelant_quittent_le_schema_api (DOC-SURFACE-1).
--
-- B20, premier geste (02/09/2026) : les trois fonctions mortes du schéma `api`
-- exécutables par `anon` ont été fermées, puis fermées à `authenticated` aussi
-- le jour même (lot circulation arbitré). Cette suite gardait les droits.
--
-- 12/10/2026 (DOC-SURFACE-1, décision Xavier sur le GLB v18 ch. 6.1) : une
-- fonction `api` sans appelant et fermée à tous les rôles se supprime. Les
-- trois n'existent plus ; la suite garde désormais leur ABSENCE — une aile
-- démolie ne se rouvre pas par un GRANT oublié — et la présence des murs :
-- les implémentations `public.fn_v2_*_return*` restent, fermées (voir
-- circulation_couche_supplantee_tests.sql, T1).

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
BEGIN
  -- T1 : les trois portes n'existent plus dans api
  v_test_name := 'T1 les trois portes supprimées';
  SELECT string_agg(p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('clear_loan_return_schedule','mark_loan_return_missed','schedule_loan_return');
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore présentes — ' || v_liste); END IF;

  -- T2 : les trois murs existent toujours dans public (une suite qui passe
  --      sur du vide ne prouve rien)
  v_test_name := 'T2 les trois implémentations public existent';
  SELECT string_agg(x.nom, ', ') INTO v_liste
  FROM (VALUES ('fn_v2_schedule_emprestimo_return'),
               ('fn_v2_clear_emprestimo_return_schedule'),
               ('fn_v2_mark_emprestimo_return_missed')) x(nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = x.nom);
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : absentes — ' || v_liste); END IF;

  -- T3 : et restent fermées à anon comme à authenticated
  v_test_name := 'T3 implémentations public fermées';
  SELECT string_agg(p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN ('fn_v2_schedule_emprestimo_return','fn_v2_clear_emprestimo_return_schedule','fn_v2_mark_emprestimo_return_missed')
    AND (has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : rouvertes — ' || v_liste); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'SURFACE_MORTE_ANON ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'SURFACE_MORTE_ANON OK : %/% tests passés', v_passed, v_passed;
END $$;
