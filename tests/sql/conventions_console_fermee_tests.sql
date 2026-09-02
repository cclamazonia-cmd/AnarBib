-- Suite d'acceptation — migration 20260902100917 (B20, lot conventions).
--
-- Les deux contrôles qualité des conventions sont fermés à la porte PostgREST
-- (anon + authenticated) mais restent des instruments de console entiers :
-- fonctions présentes, vues private.v_conv_controle_* présentes, postgres
-- garde son EXECUTE.

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
BEGIN
  -- T1 : fermées à anon et authenticated
  v_test_name := 'T1 conv_controle_* fermées à la porte du navigateur';
  SELECT string_agg(p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('conv_controle_qualite','conv_controle_resumo')
    AND (has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore ouvertes — ' || v_liste); END IF;

  -- T2 : les deux fonctions existent toujours
  v_test_name := 'T2 les deux existent';
  SELECT string_agg(x.nom, ', ') INTO v_liste
  FROM (VALUES ('conv_controle_qualite'),('conv_controle_resumo')) x(nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = x.nom);
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : absentes — ' || v_liste); END IF;

  -- T3 : l'instrument est entier — les vues qu'il lit existent
  v_test_name := 'T3 vues private.v_conv_controle_* présentes';
  IF to_regclass('private.v_conv_controle_qualite') IS NOT NULL
     AND to_regclass('private.v_conv_controle_resumo') IS NOT NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : une vue manque'); END IF;

  -- T4 : la console (postgres) garde son EXECUTE
  v_test_name := 'T4 postgres garde EXECUTE';
  IF has_function_privilege('postgres', 'api.conv_controle_resumo()', 'EXECUTE')
     AND has_function_privilege('postgres', 'api.conv_controle_qualite(text, integer)', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : la console serait muette'); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CONVENTIONS_CONSOLE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CONVENTIONS_CONSOLE OK : %/% tests passés', v_passed, v_passed;
END $$;
