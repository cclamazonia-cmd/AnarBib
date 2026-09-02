-- Suite d'acceptation — migration 20260902095935_la_carte_se_taille_elle_ne_s_efface_qu_a_la_main
--
-- B20, lot cartographie : les deux fonctions redondantes ou jamais servies
-- (`fn_cartography_create_entry`, `fn_cartography_toggle_public`) sont fermées
-- à anon ET authenticated ; `fn_cartography_delete`, branchée le même jour dans
-- CartographyEditModal, reste ouverte à authenticated (sa garde de rôle vit
-- dans son corps : fn_caller_is_network_admin).

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
BEGIN
  -- T1 : les deux fermées, pour anon comme pour authenticated
  v_test_name := 'T1 create_entry et toggle_public fermées';
  SELECT string_agg(p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('fn_cartography_create_entry','fn_cartography_toggle_public')
    AND (has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore ouvertes — ' || v_liste); END IF;

  -- T2 : les trois existent toujours (une suite qui passe sur du vide ne prouve rien)
  v_test_name := 'T2 les trois existent';
  SELECT string_agg(x.nom, ', ') INTO v_liste
  FROM (VALUES ('fn_cartography_create_entry'),('fn_cartography_toggle_public'),('fn_cartography_delete')) x(nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = x.nom);
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : absentes — ' || v_liste); END IF;

  -- T3 : delete reste ouverte à authenticated (le bouton de retrait en dépend)
  v_test_name := 'T3 delete ouverte à authenticated';
  IF has_function_privilege('authenticated', 'api.fn_cartography_delete(uuid)', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : fermée — le bouton serait muet'); END IF;

  -- T4 : et fermée à anon (le corps garde le rôle, l'EXECUTE garde la porte)
  v_test_name := 'T4 delete fermée à anon';
  IF NOT has_function_privilege('anon', 'api.fn_cartography_delete(uuid)', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ouverte à anon'); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CARTOGRAPHIE_TAILLEE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CARTOGRAPHIE_TAILLEE OK : %/% tests passés', v_passed, v_passed;
END $$;
