-- Suite d'acceptation — migration 20260902103305 (B20, lot circulation).
--
-- L'aile jamais ouverte est fermée à clé, les murs restent : les 8 fonctions
-- `api` sans appelant + les 3 implémentations `public.fn_v2_*_return*` que la
-- fermeture rend orphelines sont closes à anon et authenticated ; les jumelles
-- câblées (négociation de créneau, calcul d'échéance, flux brouillon) gardent
-- leur EXECUTE ; toutes les fonctions existent encore (restauration = GRANT).

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
BEGIN
  -- T1 : les onze fermées à la porte du navigateur
  v_test_name := 'T1 les onze fermées';
  SELECT string_agg(n.nspname||'.'||p.proname, ', ') INTO v_liste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE ((n.nspname = 'api' AND p.proname IN (
           'attach_exemplar','clear_loan_return_schedule','get_due_date_for_loan',
           'get_library_circulation_policy_rules_ui','get_remaining_renewals',
           'mark_loan_return_missed','refuse_pickup_slot','schedule_loan_return'))
     OR (n.nspname = 'public' AND p.proname IN (
           'fn_v2_schedule_emprestimo_return','fn_v2_clear_emprestimo_return_schedule',
           'fn_v2_mark_emprestimo_return_missed')))
    AND (has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore ouvertes — ' || v_liste); END IF;

  -- T2 : les onze existent toujours — les murs restent
  v_test_name := 'T2 les onze existent';
  SELECT string_agg(x.nsp||'.'||x.nom, ', ') INTO v_liste
  FROM (VALUES ('api','attach_exemplar'),('api','clear_loan_return_schedule'),
               ('api','get_due_date_for_loan'),('api','get_library_circulation_policy_rules_ui'),
               ('api','get_remaining_renewals'),('api','mark_loan_return_missed'),
               ('api','refuse_pickup_slot'),('api','schedule_loan_return'),
               ('public','fn_v2_schedule_emprestimo_return'),
               ('public','fn_v2_clear_emprestimo_return_schedule'),
               ('public','fn_v2_mark_emprestimo_return_missed')) x(nsp, nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = x.nsp AND p.proname = x.nom);
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : absentes — ' || v_liste); END IF;

  -- T3 : les jumelles câblées gardent leur EXECUTE (couples schéma+nom explicites)
  v_test_name := 'T3 jumelles câblées ouvertes';
  SELECT string_agg(a.nsp||'.'||a.nom, ', ') INTO v_liste
  FROM (VALUES ('api','confirm_pickup_slot'),('api','fn_confirm_pickup_slot_as_reader'),
               ('api','fn_propose_pickup_slot_as_reader'),('api','get_due_date_after_renewal'),
               ('api','resolve_circulation_rule'),('api','get_library_circulation_policy_sets_ui'),
               ('public','publish_book_draft')) a(nsp, nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = a.nsp AND p.proname = a.nom
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : fermées ou introuvables — ' || v_liste); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CIRCULATION_SUPPLANTEE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CIRCULATION_SUPPLANTEE OK : %/% tests passés', v_passed, v_passed;
END $$;
