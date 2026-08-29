-- =====================================================================
-- AnarBib — Paquet 20 v2 : Tests d'acceptation des wrappers api.* emprunts
-- Date : 2026-05-11
-- Cible : helpers fn_check_loan_action + fn_get_loan_context
--         8 wrappers api.* (paquet 19 v1 + v2)
--
-- USAGE :
--   Coller dans Supabase Studio SQL Editor et cliquer Run.
--   A la fin, une EXCEPTION est levee avec le bilan : 'BILAN : X/N tests OK'.
--   Si tout passe : BILAN OK avec compteurs.
--   Si echecs : BILAN ECHEC suivi de la liste des tests qui ont echoue.
--
-- ARCHITECTURE :
--   Un seul gros bloc DO $$ qui accumule passed et failures.
--   Chaque "test" est un BEGIN ... EXCEPTION ... END; isole.
--   - increment passed sur succes, OR
--   - append to failures avec le motif de l'echec
--   Pas de ROLLBACK : tous les tests utilisent des IDs inexistants ou
--   plantent dans la fn DEFINER avant ecriture.
--
-- FIXTURES (UUIDs BLMF, verifies en base le 11/05/2026) :
--   - Coordination de test (staff BLMF) : 11111111-1111-1111-1111-111111111111
--   - Lectrice A (lecteur BLMF) : 33333333-3333-3333-3333-333333333333
--   - Lecteur B (lecteur BLMF) : 44444444-4444-4444-4444-444444444444
--   - Compte sans role BLMF : 22222222-2222-2222-2222-222222222222
-- =====================================================================

-- NOTE sur « emprunt inexistant » (29/08/2026, backlog v34, item I7).
-- Les wrappers levent un CODE machine -- `loan_not_found` -- et non une phrase
-- portugaise. Les gardes de 4.02, 5.02 et 8.03 ne cherchaient que
-- '%nao encontrado%' : le trait de soulignement de `loan_not_found` suffisait a
-- les faire manquer d'un caractere. Elles exigent desormais le code, EXACTEMENT,
-- plutot que d'accepter les deux formes -- un « ou bien » dans une garde
-- d'erreur est precisement ce qui laisse passer une regression. Le code est le
-- bon contrat : c'est lui que le frontend teste.
-- Les autres gardes de cette suite n'ont pas ete touchees : elles passaient.

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_skipped int := 0;
  v_failures text[] := ARRAY[]::text[];
  v_skips text[] := ARRAY[]::text[];

  v_test_emprestimo_id bigint;
  v_livia_loan_id bigint;
  v_xavier_loan_id bigint;
  v_ctx record;
  v_test_name text;

  c_coord constant uuid := '11111111-1111-1111-1111-111111111111';
  c_leitora_a constant uuid := '33333333-3333-3333-3333-333333333333';
  c_leitor_b constant uuid := '44444444-4444-4444-4444-444444444444';
  c_sem_papel constant uuid := '22222222-2222-2222-2222-222222222222';
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
BEGIN

  -- =====================================================================
  -- SECTION 1 : Helper fn_check_loan_action (12 tests)
  -- =====================================================================

  v_test_name := '1.01 helper create par librarian';
  BEGIN
    IF public.fn_check_loan_action('create_loan_at_counter', NULL, 'librarian') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.02 helper create par coordenador';
  BEGIN
    IF public.fn_check_loan_action('create_loan_at_counter', NULL, 'coordenador') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.03 helper create par leitor rejete';
  BEGIN
    IF NOT public.fn_check_loan_action('create_loan_at_counter', NULL, 'leitor') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.04 helper return_total par staff sur aberto/parcial';
  BEGIN
    IF public.fn_check_loan_action('return_total', 'aberto', 'librarian')
       AND public.fn_check_loan_action('return_total', 'parcialmente_devolvido', 'librarian') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.05 helper return par leitor rejete';
  BEGIN
    IF NOT public.fn_check_loan_action('return_total', 'aberto', 'leitor') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.06 helper return sur encerrado rejete';
  BEGIN
    IF NOT public.fn_check_loan_action('return_total', 'encerrado', 'librarian') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.07 helper renew par leitor';
  BEGIN
    IF public.fn_check_loan_action('renew_as_reader', 'aberto', 'leitor') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  -- `administrador` a ete retire de ce test le 29/08/2026 (backlog v34, item I7).
  -- Ce n'est pas un role de bibliotheque : le CHECK de user_library_memberships
  -- n'admet que reader, librarian et coordenador. `administrador` designe
  -- l'administration DU RESEAU, qui vit dans network_administrators. Le helper
  -- a donc raison de le refuser -- une administratrice de reseau n'a pas la main
  -- sur la circulation d'une bibliotheque locale, et c'est tout le principe.
  -- Le test encodait un modele de roles anterieur.
  v_test_name := '1.08 helper renew par staff local, pas par l''admin reseau';
  BEGIN
    IF public.fn_check_loan_action('renew_as_reader', 'aberto', 'coordenador')
       AND public.fn_check_loan_action('renew_as_reader', 'aberto', 'librarian')
       AND NOT public.fn_check_loan_action('renew_as_reader', 'aberto', 'administrador')
       AND NOT public.fn_check_loan_action('renew_as_reader', 'aberto', 'reader') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.09 helper renew par system rejete';
  BEGIN
    IF NOT public.fn_check_loan_action('renew_as_reader', 'aberto', 'system') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.10 helper action ou role vide rejete';
  BEGIN
    IF NOT public.fn_check_loan_action('', 'aberto', 'librarian')
       AND NOT public.fn_check_loan_action('return_total', 'aberto', '')
       AND NOT public.fn_check_loan_action(NULL, 'aberto', 'librarian') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.11 helper action inconnue rejetee';
  BEGIN
    IF NOT public.fn_check_loan_action('whatever_action', 'aberto', 'librarian') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '1.12 helper schedule_return roles autorises';
  BEGIN
    IF public.fn_check_loan_action('schedule_return', 'aberto', 'leitor')
       AND public.fn_check_loan_action('schedule_return', 'aberto', 'librarian')
       AND NOT public.fn_check_loan_action('schedule_return', 'aberto', 'system') THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  -- =====================================================================
  -- SECTION 2 : Helper fn_get_loan_context (3 tests)
  -- =====================================================================

  v_test_name := '2.01 fn_get_loan_context id inexistant';
  BEGIN
    SELECT * INTO v_ctx FROM public.fn_get_loan_context(99999999);
    IF v_ctx.library_id IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '2.02 fn_get_loan_context emprunt existant';
  BEGIN
    SELECT id INTO v_test_emprestimo_id FROM public.emprestimos_v2 LIMIT 1;
    IF v_test_emprestimo_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : aucun emprunt en base');
    ELSE
      SELECT * INTO v_ctx FROM public.fn_get_loan_context(v_test_emprestimo_id);
      IF v_ctx.library_id IS NOT NULL AND v_ctx.leitor_user_id IS NOT NULL AND v_ctx.status_global IS NOT NULL THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || v_test_name; END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  v_test_name := '2.03 fn_get_loan_context utilisable en JOIN LATERAL';
  BEGIN
    PERFORM (SELECT COUNT(*) FROM public.emprestimos_v2 e JOIN LATERAL public.fn_get_loan_context(e.id) ctx ON true LIMIT 5);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END;

  -- =====================================================================
  -- SECTION 3 : api.create_loan_at_counter (5 tests)
  -- =====================================================================

  v_test_name := '3.01 create rejette anon';
  BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.create_loan_at_counter(c_leitora_a, ARRAY[99999999]::bigint[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : appel anon aurait du echouer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLERRM LIKE '%uthenticat%' OR SQLERRM LIKE '%obrigat%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '3.02 create rejette leitor';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}', true);
    PERFORM api.create_loan_at_counter(c_leitor_b, ARRAY[99999999]::bigint[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : leitor ne doit pas creer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '42501' OR SQLERRM LIKE '%autorizada%' OR SQLERRM LIKE '%biblioteca ativa%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '3.03 create wrapper passe pour la coordination';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.create_loan_at_counter(c_leitora_a, ARRAY[99999999]::bigint[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : aurait du echouer dans fn DEFINER');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : auth a echoue : ' || SQLERRM);
    ELSIF SQLSTATE = '42501' THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : role a echoue : ' || SQLERRM);
    ELSE v_passed := v_passed + 1; END IF;
  END;

  v_test_name := '3.04 create rejette holdings vide';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.create_loan_at_counter(c_leitora_a, ARRAY[]::bigint[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : holdings vide doit etre rejete');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLSTATE = '42501' THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : aurait du atteindre fn DEFINER : ' || SQLERRM);
    ELSE v_passed := v_passed + 1; END IF;
  END;

  v_test_name := '3.05 create rejette le compte sans role BLMF';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}', true);
    PERFORM api.create_loan_at_counter(c_leitora_a, ARRAY[99999999]::bigint[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : le compte sans role ne doit pas creer');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  -- =====================================================================
  -- SECTION 4 : api.return_loan_total + api.return_loan_partial (8 tests)
  -- =====================================================================

  v_test_name := '4.01 return_total rejette anon';
  BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.return_loan_total(1);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : appel anon aurait du echouer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLERRM LIKE '%uthenticat%' OR SQLERRM LIKE '%obrigat%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '4.02 return_total emprunt inexistant';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.return_loan_total(99999999);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : emprunt inexistant doit etre rejete');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%loan_not_found%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '4.03 return_total rejette leitor';
  BEGIN
    SELECT id INTO v_test_emprestimo_id FROM public.emprestimos_v2 LIMIT 1;
    IF v_test_emprestimo_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : aucun emprunt en base');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        PERFORM api.return_loan_total(v_test_emprestimo_id);
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : le lecteur B ne doit pas retourner');
      EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' OR SQLERRM LIKE '%autorizada%' OR SQLERRM LIKE '%nao encontrado%' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
      END;
    END IF;
  END;

  v_test_name := '4.04 return_total sur emprunt encerrado';
  BEGIN
    SELECT id INTO v_test_emprestimo_id FROM public.emprestimos_v2 WHERE status_global = 'encerrado' LIMIT 1;
    IF v_test_emprestimo_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : aucun emprunt encerrado');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
        PERFORM api.return_loan_total(v_test_emprestimo_id);
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encerrado ne doit pas etre retournable');
      EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' OR SQLERRM LIKE '%autorizada%' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
      END;
    END IF;
  END;

  v_test_name := '4.05 return_partial rejette anon';
  BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.return_loan_partial(1, ARRAY[1]::integer[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : appel anon aurait du echouer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLERRM LIKE '%uthenticat%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '4.06 return_partial line_nos vide';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.return_loan_partial(1, ARRAY[]::integer[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : line_nos vide doit etre rejete');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  v_test_name := '4.07 return_partial line_nos NULL';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.return_loan_partial(1, NULL);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : line_nos NULL doit etre rejete');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  v_test_name := '4.08 return_partial rejette leitor';
  BEGIN
    SELECT id INTO v_test_emprestimo_id FROM public.emprestimos_v2 LIMIT 1;
    IF v_test_emprestimo_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : aucun emprunt en base');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}', true);
        PERFORM api.return_loan_partial(v_test_emprestimo_id, ARRAY[1]::integer[]);
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : la lectrice A ne doit pas retourner');
      EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' OR SQLERRM LIKE '%autorizada%' OR SQLERRM LIKE '%nao encontrado%' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
      END;
    END IF;
  END;

  -- =====================================================================
  -- SECTION 5 : api.extend_loan_as_library (3 tests)
  -- =====================================================================

  v_test_name := '5.01 extend rejette anon';
  BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.extend_loan_as_library(1);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : appel anon aurait du echouer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLERRM LIKE '%uthenticat%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '5.02 extend emprunt inexistant';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.extend_loan_as_library(99999999);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : emprunt inexistant doit etre rejete');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%loan_not_found%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '5.03 extend rejette leitor';
  BEGIN
    SELECT id INTO v_test_emprestimo_id FROM public.emprestimos_v2 LIMIT 1;
    IF v_test_emprestimo_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : aucun emprunt en base');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        PERFORM api.extend_loan_as_library(v_test_emprestimo_id);
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : le lecteur B ne doit pas prolonger');
      EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' OR SQLERRM LIKE '%autorizada%' OR SQLERRM LIKE '%nao encontrado%' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
      END;
    END IF;
  END;

  -- =====================================================================
  -- SECTION 6 : api.renew_my_loan (5 tests - ownership crucial)
  -- =====================================================================

  v_test_name := '6.01 renew rejette anon';
  BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.renew_my_loan(1);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : appel anon aurait du echouer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLERRM LIKE '%uthenticat%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '6.02 renew emprunt inexistant';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}', true);
    PERFORM api.renew_my_loan(99999999);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : emprunt inexistant doit etre rejete');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  v_test_name := '6.03 renew cross-ownership lecteur B sur lectrice A';
  BEGIN
    SELECT id INTO v_livia_loan_id FROM public.emprestimos_v2 WHERE user_id = c_leitora_a LIMIT 1;
    IF v_livia_loan_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : la lectrice A n''a aucun emprunt');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        PERFORM api.renew_my_loan(v_livia_loan_id);
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ECHEC CRITIQUE OWNERSHIP');
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%seus proprios%' OR SQLERRM LIKE '%nao encontrado%' OR SQLSTATE = '42501' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
      END;
    END IF;
  END;

  v_test_name := '6.04 renew coordination sur son emprunt (paquet 19 v2)';
  BEGIN
    SELECT id INTO v_xavier_loan_id FROM public.emprestimos_v2 
      WHERE user_id = c_coord AND status_global IN ('aberto', 'parcialmente_devolvido') LIMIT 1;
    IF v_xavier_loan_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : Xavier n''a aucun emprunt ouvert');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
        PERFORM api.renew_my_loan(v_xavier_loan_id);
        v_passed := v_passed + 1;
      EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '28000' THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : Xavier doit passer auth : ' || SQLERRM);
        ELSIF SQLSTATE = '42501' AND SQLERRM NOT LIKE '%seus proprios%' THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : Xavier doit pouvoir : ' || SQLERRM);
        ELSE v_passed := v_passed + 1; END IF;
      END;
    END IF;
  END;

  v_test_name := '6.05 renew lectrice A leitor sur son emprunt';
  BEGIN
    SELECT id INTO v_livia_loan_id FROM public.emprestimos_v2 
      WHERE user_id = c_leitora_a AND status_global IN ('aberto', 'parcialmente_devolvido') LIMIT 1;
    IF v_livia_loan_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : la lectrice A n''a aucun emprunt ouvert');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}', true);
        PERFORM api.renew_my_loan(v_livia_loan_id);
        v_passed := v_passed + 1;
      EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '28000' OR (SQLSTATE = '42501' AND SQLERRM NOT LIKE '%seus proprios%') THEN v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : la lectrice A doit passer : ' || SQLERRM);
        ELSE v_passed := v_passed + 1; END IF;
      END;
    END IF;
  END;

  -- =====================================================================
  -- SECTION 7 : schedule + clear (6 tests)
  -- =====================================================================

  v_test_name := '7.01 schedule rejette anon';
  BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.schedule_loan_return(1, ARRAY[1]::integer[], now() + interval '1 day');
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : appel anon aurait du echouer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLERRM LIKE '%uthenticat%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '7.02 schedule line_nos vide';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.schedule_loan_return(1, ARRAY[]::integer[], now() + interval '1 day');
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : line_nos vide doit etre rejete');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  v_test_name := '7.03 schedule lecteur B sur lectrice A';
  BEGIN
    SELECT id INTO v_livia_loan_id FROM public.emprestimos_v2 WHERE user_id = c_leitora_a LIMIT 1;
    IF v_livia_loan_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : la lectrice A n''a aucun emprunt');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        PERFORM api.schedule_loan_return(v_livia_loan_id, ARRAY[1]::integer[], now() + interval '1 day');
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : le lecteur B ne doit pas planifier sur la lectrice A');
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%seus proprios%' OR SQLERRM LIKE '%nao encontrado%' OR SQLSTATE = '42501' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
      END;
    END IF;
  END;

  v_test_name := '7.04 clear rejette anon';
  BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.clear_loan_return_schedule(1, ARRAY[1]::integer[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : appel anon aurait du echouer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLERRM LIKE '%uthenticat%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '7.05 clear lecteur B sur lectrice A';
  BEGIN
    SELECT id INTO v_livia_loan_id FROM public.emprestimos_v2 WHERE user_id = c_leitora_a LIMIT 1;
    IF v_livia_loan_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : la lectrice A n''a aucun emprunt');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        PERFORM api.clear_loan_return_schedule(v_livia_loan_id, ARRAY[1]::integer[]);
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : le lecteur B ne doit pas annuler sur la lectrice A');
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%seus proprios%' OR SQLERRM LIKE '%nao encontrado%' OR SQLSTATE = '42501' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
      END;
    END IF;
  END;

  v_test_name := '7.06 clear line_nos NULL';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.clear_loan_return_schedule(1, NULL);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : line_nos NULL doit etre rejete');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  -- =====================================================================
  -- SECTION 8 : api.mark_loan_return_missed (3 tests)
  -- =====================================================================

  v_test_name := '8.01 mark_missed rejette anon';
  BEGIN
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', NULL, true);
    PERFORM api.mark_loan_return_missed(1, ARRAY[1]::integer[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : appel anon aurait du echouer');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '28000' OR SQLERRM LIKE '%uthenticat%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  v_test_name := '8.02 mark_missed rejette leitor';
  BEGIN
    SELECT id INTO v_test_emprestimo_id FROM public.emprestimos_v2 LIMIT 1;
    IF v_test_emprestimo_id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_test_name || ' : aucun emprunt en base');
    ELSE
      BEGIN
        SET LOCAL ROLE authenticated;
        PERFORM set_config('request.jwt.claims', '{"sub": "44444444-4444-4444-4444-444444444444", "role": "authenticated"}', true);
        PERFORM api.mark_loan_return_missed(v_test_emprestimo_id, ARRAY[1]::integer[]);
        v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : le lecteur B ne doit pas marker');
      EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' OR SQLERRM LIKE '%autorizada%' OR SQLERRM LIKE '%nao encontrado%' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
      END;
    END IF;
  END;

  v_test_name := '8.03 mark_missed emprunt inexistant';
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
    PERFORM api.mark_loan_return_missed(99999999, ARRAY[1]::integer[]);
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : emprunt inexistant doit etre rejete');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%loan_not_found%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || SQLERRM); END IF;
  END;

  -- =====================================================================
  -- BILAN FINAL (raise une exception avec le resultat pour forcer l'affichage)
  -- =====================================================================

  RESET ROLE;

  IF v_failed = 0 AND v_skipped = 0 THEN
    RAISE EXCEPTION 'LOAN-WRAPPERS OK : %/% tests passes. Aucun skip, aucun echec.',
      v_passed, (v_passed + v_failed + v_skipped);
  ELSIF v_failed = 0 THEN
    RAISE EXCEPTION 'LOAN-WRAPPERS OK : %/% tests passes. % SKIPS : %',
      v_passed, (v_passed + v_failed + v_skipped),
      v_skipped, array_to_string(v_skips, ' || ');
  ELSE
    RAISE EXCEPTION 'BILAN ECHEC : % passes / % echecs / % skips. ECHECS : %',
      v_passed, v_failed, v_skipped,
      array_to_string(v_failures, ' || ');
  END IF;

END $$;
