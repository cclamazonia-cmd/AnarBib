-- =====================================================================
-- AnarBib — Phase 1 spec consultations — livrable 3 : tests SQL
-- =====================================================================
-- Fichier : tests/sql/paquet24_consulta_helpers_tests.sql
--   (paquet 24, Phase 1 consultations)
-- Date    : 2026-05-12
-- Auteur  : Xavier (AnarBib)
--
-- 20 tests dans un seul bloc DO avec accumulateurs v_passed/v_failed/
-- v_skipped. Pattern paquet 20 (45 tests reussis).
--
-- Lancement : Supabase Studio > SQL Editor.
-- Bilan attendu : 'BILAN OK : 20/20'.
--
-- Decoupage :
--   Section A : fn_check_consulta_transition          (~12 tests)
--   Section B : fn_get_consulta_context               (~3 tests)
--   Section C : invariant emprestimo vs consulta      (~5 tests)
--
-- Fixtures BLMF :
--   Xavier (staff coordenador) : d6710372-e5e5-4608-800b-99a26817c677
--   Livia  (lecteur)           : 366cdc4e-10e0-44ad-8554-a444bcf9607a
--   Arthur (lecteur)           : 614d887d-4e8d-401d-a208-77c56a1cd5ea
--   Patricia (sans role BLMF)  : 2a42b6bd-d159-4ee0-b66b-28a03062232b
--   BLMF library_id            : 1234825f-a0f9-4fbd-a875-6551c30ea4ca
-- =====================================================================

DO $$
DECLARE
  v_passed integer := 0;
  v_failed integer := 0;
  v_skipped integer := 0;
  v_failures text[] := '{}';
  v_ctx record;
  v_holding_id_loan_blocked bigint;
  v_holding_id_consulta_blocked bigint;
  v_holding_id_free bigint;
  v_holding_id_reservation_blocked bigint;
  v_result_id bigint;
  v_err text;
BEGIN
  -- ===================================================================
  -- SECTION A : fn_check_consulta_transition (12 tests)
  -- ===================================================================

  -- A.1 staff librarian : solicitada -> em_preparacao
  IF public.fn_check_consulta_transition('solicitada', 'em_preparacao', 'librarian') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.1 staff_solicitada_to_em_preparacao');
  END IF;

  -- A.2 staff coordenador : em_preparacao -> consulta_agendada
  IF public.fn_check_consulta_transition('em_preparacao', 'consulta_agendada', 'coordenador') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.2 staff_em_preparacao_to_consulta_agendada');
  END IF;

  -- A.3 staff administrador : consulta_agendada -> consulta_realizada
  IF public.fn_check_consulta_transition('consulta_agendada', 'consulta_realizada', 'administrador') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.3 staff_consulta_agendada_to_consulta_realizada');
  END IF;

  -- A.4 staff : consulta_agendada -> nao_compareceu
  IF public.fn_check_consulta_transition('consulta_agendada', 'nao_compareceu', 'librarian') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.4 staff_consulta_agendada_to_nao_compareceu');
  END IF;

  -- A.5 staff : boucle consulta_agendada -> consulta_agendada (re-proposition)
  IF public.fn_check_consulta_transition('consulta_agendada', 'consulta_agendada', 'librarian') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.5 staff_consulta_agendada_loop');
  END IF;

  -- A.6 staff : nao_compareceu -> cancelada_biblioteca (reclassement)
  IF public.fn_check_consulta_transition('nao_compareceu', 'cancelada_biblioteca', 'librarian') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.6 staff_nao_compareceu_to_cancelada_biblioteca');
  END IF;

  -- A.7 lecteur : annulation depuis solicitada
  IF public.fn_check_consulta_transition('solicitada', 'cancelada_leitor', 'leitor') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.7 leitor_solicitada_to_cancelada_leitor');
  END IF;

  -- A.8 lecteur : annulation depuis consulta_agendada
  IF public.fn_check_consulta_transition('consulta_agendada', 'cancelada_leitor', 'leitor') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.8 leitor_consulta_agendada_to_cancelada_leitor');
  END IF;

  -- A.9 system : solicitada -> expirada
  IF public.fn_check_consulta_transition('solicitada', 'expirada', 'system') = true THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.9 system_solicitada_to_expirada');
  END IF;

  -- A.10 etat terminal : consulta_realizada -> rien (refus)
  IF public.fn_check_consulta_transition('consulta_realizada', 'consulta_agendada', 'librarian') = false
     AND public.fn_check_consulta_transition('cancelada_leitor', 'em_preparacao', 'leitor') = false
     AND public.fn_check_consulta_transition('cancelada_biblioteca', 'consulta_agendada', 'coordenador') = false
     AND public.fn_check_consulta_transition('expirada', 'solicitada', 'system') = false THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.10 etats_terminaux_refusent_sortie');
  END IF;

  -- A.11 lecteur : transition interdite (solicitada -> em_preparacao)
  -- A.11bis staff : action transverse interdite (solicitada -> consulta_realizada saut)
  -- A.11ter nao_compareceu -> autre_que_cancelada_biblioteca
  IF public.fn_check_consulta_transition('solicitada', 'em_preparacao', 'leitor') = false
     AND public.fn_check_consulta_transition('solicitada', 'consulta_realizada', 'librarian') = false
     AND public.fn_check_consulta_transition('nao_compareceu', 'consulta_agendada', 'librarian') = false
     AND public.fn_check_consulta_transition('em_preparacao', 'nao_compareceu', 'librarian') = false THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.11 transitions_illegales_refusees');
  END IF;

  -- A.12 fail-closed sur NULL et chaines vides + action/role inconnus
  IF public.fn_check_consulta_transition(NULL, 'em_preparacao', 'librarian') = false
     AND public.fn_check_consulta_transition('solicitada', NULL, 'librarian') = false
     AND public.fn_check_consulta_transition('solicitada', 'em_preparacao', NULL) = false
     AND public.fn_check_consulta_transition('', 'em_preparacao', 'librarian') = false
     AND public.fn_check_consulta_transition('solicitada', 'em_preparacao', '') = false
     AND public.fn_check_consulta_transition('solicitada', 'em_preparacao', 'role_inconnu') = false
     AND public.fn_check_consulta_transition('stage_inconnu', 'em_preparacao', 'librarian') = false THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'A.12 fail_closed_nulls_empty_unknown');
  END IF;

  -- ===================================================================
  -- SECTION B : fn_get_consulta_context (3 tests)
  -- ===================================================================

  -- B.1 ID inexistant retourne library_id NULL
  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(99999999);
  IF NOT FOUND OR v_ctx.library_id IS NULL THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'B.1 id_inexistant_retourne_null');
  END IF;

  -- B.2 fonction est appelable et retourne 3 colonnes typees
  -- (test structurel : on appelle sur un ID arbitraire et on s'assure
  -- que le record a bien les 3 colonnes attendues sans erreur)
  BEGIN
    SELECT library_id, leitor_user_id, status_global
      INTO v_ctx
      FROM public.fn_get_consulta_context(99999999);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'B.2 colonnes_typees: ' || SQLERRM);
  END;

  -- B.3 utilisable en JOIN LATERAL (test syntaxique)
  BEGIN
    PERFORM 1
      FROM (VALUES (99999999::bigint)) AS t(consulta_id),
      LATERAL public.fn_get_consulta_context(t.consulta_id);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures, 'B.3 join_lateral_syntaxique: ' || SQLERRM);
  END;

  -- ===================================================================
  -- SECTION C : invariants emprunt-vs-consulta (5 tests)
  -- ===================================================================
  --
  -- Strategie : on identifie 3 holdings reels chez BLMF (1234825f...)
  --   - v_holding_id_loan_blocked        : holding avec emprunt actif
  --   - v_holding_id_reservation_blocked : holding avec reservation active
  --   - v_holding_id_consulta_blocked    : holding avec consultation active
  --   - v_holding_id_free                : holding libre
  --
  -- Pour chaque test, on appelle la fonction de creation et on attend une
  -- exception specifique. Aucune ecriture n'aboutit (les checks levent
  -- avant l'INSERT). On utilise SAVEPOINT pour isoler.
  --
  -- Si aucun holding ne correspond au pattern attendu, le test est skip.
  -- ===================================================================

  -- Detection des holdings :
  SELECT ei.holding_id INTO v_holding_id_loan_blocked
  FROM public.emprestimo_itens_v2 ei
  JOIN public.emprestimos_v2 e ON e.id = ei.emprestimo_id
  WHERE ei.item_status IN ('aberto', 'parcialmente_devolvido')
    AND e.library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
  LIMIT 1;

  SELECT rl.holding_id INTO v_holding_id_reservation_blocked
  FROM public.reserva_linhas_v2 rl
  JOIN public.reservas_v2 r ON r.id = rl.reserva_id
  WHERE rl.item_status = 'ativa'
    AND r.library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
  LIMIT 1;

  SELECT cl.holding_id INTO v_holding_id_consulta_blocked
  FROM public.consulta_linhas_v2 cl
  JOIN public.consultas_locais_v2 c ON c.id = cl.consulta_id
  WHERE cl.item_status = 'ativa'
    AND c.library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
  LIMIT 1;

  -- C.1 Creation consulta rejetee sur holding avec emprunt actif
  IF v_holding_id_loan_blocked IS NOT NULL THEN
    BEGIN
      -- SET LOCAL ROLE authenticated necessaire car la fn est DEFINER
      -- mais auth.uid() est lu en debut, donc on simule la session.
      PERFORM set_config('request.jwt.claims',
        '{"sub": "366cdc4e-10e0-44ad-8554-a444bcf9607a"}', true);
      PERFORM set_config('role', 'authenticated', true);

      v_result_id := public.fn_v2_create_consulta_local_by_holdings(
        '366cdc4e-10e0-44ad-8554-a444bcf9607a'::uuid,
        ARRAY[v_holding_id_loan_blocked]::bigint[],
        NULL,
        'TEST C.1 phase 1 invariant - DOIT ECHOUER'
      );
      v_failed := v_failed + 1;
      v_failures := array_append(v_failures,
        'C.1 holding_avec_emprunt_devrait_rejeter (id retourne: ' || v_result_id || ')');
    EXCEPTION
      WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
        IF v_err LIKE '%empréstimo em curso%' THEN
          v_passed := v_passed + 1;
        ELSE
          v_failed := v_failed + 1;
          v_failures := array_append(v_failures,
            'C.1 mauvaise_exception: ' || v_err);
        END IF;
    END;
  ELSE
    v_skipped := v_skipped + 1;
    v_failures := array_append(v_failures, 'C.1 SKIPPED (pas d''emprunt actif BLMF)');
  END IF;

  -- C.2 Creation consulta rejetee sur holding avec reservation active
  IF v_holding_id_reservation_blocked IS NOT NULL THEN
    BEGIN
      PERFORM set_config('request.jwt.claims',
        '{"sub": "366cdc4e-10e0-44ad-8554-a444bcf9607a"}', true);
      PERFORM set_config('role', 'authenticated', true);

      v_result_id := public.fn_v2_create_consulta_local_by_holdings(
        '366cdc4e-10e0-44ad-8554-a444bcf9607a'::uuid,
        ARRAY[v_holding_id_reservation_blocked]::bigint[],
        NULL,
        'TEST C.2 phase 1 invariant - DOIT ECHOUER'
      );
      v_failed := v_failed + 1;
      v_failures := array_append(v_failures,
        'C.2 holding_avec_reservation_devrait_rejeter (id retourne: ' || v_result_id || ')');
    EXCEPTION
      WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
        IF v_err LIKE '%reserva ativa%' THEN
          v_passed := v_passed + 1;
        ELSE
          v_failed := v_failed + 1;
          v_failures := array_append(v_failures,
            'C.2 mauvaise_exception: ' || v_err);
        END IF;
    END;
  ELSE
    v_skipped := v_skipped + 1;
    v_failures := array_append(v_failures, 'C.2 SKIPPED (pas de reservation active BLMF)');
  END IF;

  -- C.3 Creation emprunt rejetee si consulta active sur le holding
  -- On simule le contexte d'un staff : Xavier coordenador BLMF.
  IF v_holding_id_consulta_blocked IS NOT NULL THEN
    BEGIN
      PERFORM set_config('request.jwt.claims',
        '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}', true);
      PERFORM set_config('role', 'authenticated', true);

      PERFORM ok FROM public.fn_v2_create_emprestimo_by_holdings(
        '366cdc4e-10e0-44ad-8554-a444bcf9607a'::uuid,
        ARRAY[v_holding_id_consulta_blocked]::bigint[],
        NULL,
        'TEST C.3 phase 1 invariant - DOIT ECHOUER'
      );
      v_failed := v_failed + 1;
      v_failures := array_append(v_failures,
        'C.3 holding_avec_consulta_devrait_rejeter');
    EXCEPTION
      WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
        IF v_err LIKE '%consulta local em curso%' THEN
          v_passed := v_passed + 1;
        ELSE
          v_failed := v_failed + 1;
          v_failures := array_append(v_failures,
            'C.3 mauvaise_exception: ' || v_err);
        END IF;
    END;
  ELSE
    v_skipped := v_skipped + 1;
    v_failures := array_append(v_failures, 'C.3 SKIPPED (pas de consulta active BLMF)');
  END IF;

  -- C.4 Test syntaxique : le check emprunt actif accepte
  -- 'parcialmente_devolvido' en plus de 'aberto'.
  -- On verifie via une introspection de la fonction (pg_get_functiondef).
  IF position('parcialmente_devolvido' IN
       pg_get_functiondef('public.fn_v2_create_consulta_local_by_holdings(uuid,bigint[],timestamp with time zone,text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures,
      'C.4 fn_consulta_doit_inclure_parcialmente_devolvido');
  END IF;

  -- C.5 Test syntaxique : le check consulta active a bien ete ajoute
  -- dans fn_v2_create_emprestimo_by_holdings.
  IF position('consulta local em curso' IN
       pg_get_functiondef('public.fn_v2_create_emprestimo_by_holdings(uuid,bigint[],date,text)'::regprocedure)
     ) > 0 THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := array_append(v_failures,
      'C.5 fn_emprestimo_doit_avoir_check_consulta');
  END IF;

  -- ===================================================================
  -- BILAN
  -- ===================================================================
  IF v_failed = 0 THEN
    RAISE NOTICE 'BILAN OK : %/% (skipped: %)',
      v_passed, v_passed + v_failed, v_skipped;
    IF v_skipped > 0 THEN
      RAISE NOTICE 'Notes (skips ou warnings): %', array_to_string(v_failures, ' | ');
    END IF;
  ELSE
    RAISE EXCEPTION 'BILAN ECHEC : %/% passes, % failed, % skipped. Echecs: %',
      v_passed,
      v_passed + v_failed,
      v_failed,
      v_skipped,
      array_to_string(v_failures, ' | ');
  END IF;
END;
$$;

-- =====================================================================
-- Fin tests phase 1 consultations.
-- =====================================================================
