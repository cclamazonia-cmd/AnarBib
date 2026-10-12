-- Suite d'acceptation — migration 20260902100917 (B20, lot conventions),
-- puis 20261012111851_sept_portes_sans_appelant_quittent_le_schema_api (DOC-SURFACE-1).
--
-- 02/09/2026 : les deux contrôles qualité des conventions étaient fermés à la
-- porte PostgREST mais gardés comme instruments de console (fonctions
-- présentes, vues private.v_conv_controle_* présentes, postgres gardait
-- son EXECUTE).
--
-- 12/10/2026 (décision Xavier sur le GLB v18 ch. 6.1) : un instrument de
-- console n'a pas besoin d'une fonction `api` — la console lit les vues
-- `private` directement. Les deux fonctions sont supprimées ; les vues
-- restent. La suite garde l'absence des unes et la présence des autres.

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
BEGIN
  -- T1 : les deux portes api n'existent plus
  v_test_name := 'T1 conv_controle_* supprimées du schéma api';
  SELECT string_agg(p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('conv_controle_qualite','conv_controle_resumo');
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore présentes — ' || v_liste); END IF;

  -- T2 : l'instrument est entier — les vues que la console lit existent
  v_test_name := 'T2 vues private.v_conv_controle_* présentes';
  IF to_regclass('private.v_conv_controle_qualite') IS NOT NULL
     AND to_regclass('private.v_conv_controle_resumo') IS NOT NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : une vue manque'); END IF;

  -- T3 : et la console (postgres) les lit
  v_test_name := 'T3 postgres lit les vues';
  IF has_table_privilege('postgres', 'private.v_conv_controle_qualite', 'SELECT')
     AND has_table_privilege('postgres', 'private.v_conv_controle_resumo', 'SELECT') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : la console serait muette'); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CONVENTIONS_CONSOLE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CONVENTIONS_CONSOLE OK : %/% tests passés', v_passed, v_passed;
END $$;
