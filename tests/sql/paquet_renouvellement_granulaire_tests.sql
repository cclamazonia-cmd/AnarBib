-- =====================================================================
-- AnarBib — Tests d'acceptation : RENOUVELLEMENT GRANULAIRE (par item)
-- Date    : 2026-06-17
-- Session : Audit 360 — correctifs P0
-- Réf     : Audit 360° 17/06/2026, P1 — « tests d'emprunts pas à jour » :
--           les RPC granulaires du 29/05 (api.renew_my_loan_item,
--           api.extend_loan_item_as_library) n'étaient couvertes par aucun test.
--           paquet19 couvre les 8 wrappers d'origine ; ce fichier complète.
--
-- USAGE : coller dans Studio / psql / supabase db execute. Tout est dans UN
--   DO $$ qui se termine par une EXCEPTION (bilan) → ROLLBACK total, zéro effet
--   prod. Bilan OK : 'GRANULAIRE OK : N/N …'.
--
-- Fixtures : aucune codée en dur (les UUID du README tests/sql sont périmés).
--   Les cas déterministes utilisent un id de prêt inexistant + un JWT simulé ;
--   le cas E2E (best-effort) cherche un prêt ouvert réel et SKIP sinon.
-- =====================================================================

DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_skipped int := 0;
  v_failures text[] := ARRAY[]::text[]; v_skips text[] := ARRAY[]::text[];
  v_t text;
  v_json jsonb;
  v_loan record;
  v_bad bigint := 999999999;   -- id de prêt garanti inexistant
BEGIN
  -- ===================================================================
  -- SECTION 1 : existence + délégation au cœur (introspection)
  --   Les RPC granulaires délèguent à fn_v2_extend_core → elles héritent
  --   de la logique par-item ET du recheck d'éligibilité du fix §6.1.
  -- ===================================================================
  v_t := '1.01 les 4 objets granulaires existent';
  BEGIN
    PERFORM 'api.renew_my_loan_item(bigint,integer)'::regprocedure;
    PERFORM 'api.extend_loan_item_as_library(bigint,integer)'::regprocedure;
    PERFORM 'public.fn_renew_my_loan_item(bigint,integer)'::regprocedure;
    PERFORM 'public.fn_v2_extend_emprestimo_item_once(bigint,integer)'::regprocedure;
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := '1.02 fn_renew_my_loan_item délègue au cœur';
  BEGIN
    IF pg_get_functiondef('public.fn_renew_my_loan_item(bigint,integer)'::regprocedure) ~ 'fn_v2_extend_core'
    THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := '1.03 fn_v2_extend_emprestimo_item_once délègue au cœur';
  BEGIN
    IF pg_get_functiondef('public.fn_v2_extend_emprestimo_item_once(bigint,integer)'::regprocedure) ~ 'fn_v2_extend_core'
    THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := '1.04 le cœur porte le recheck d''éligibilité (§6.1) → hérité par le granulaire';
  BEGIN
    IF pg_get_functiondef('public.fn_v2_extend_core(bigint,integer[],boolean)'::regprocedure) ~ 'fn_membership_can_engage_circulation'
    THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : recheck absent du cœur'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := '1.05 api.renew_my_loan_item est réservé au propriétaire (ownership)';
  BEGIN
    IF pg_get_functiondef('api.renew_my_loan_item(bigint,integer)'::regprocedure) ~ 'not_your_loan'
    THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ===================================================================
  -- SECTION 2 : rejet anonyme (déterministe)
  -- ===================================================================
  PERFORM set_config('request.jwt.claims', '', true);

  v_t := '2.01 api.renew_my_loan_item anon → rejet';
  BEGIN
    PERFORM api.renew_my_loan_item(v_bad, 1);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  v_t := '2.02 api.extend_loan_item_as_library anon → rejet';
  BEGIN
    PERFORM api.extend_loan_item_as_library(v_bad, 1);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed := v_passed + 1; END;

  -- ===================================================================
  -- SECTION 3 : authentifié, prêt inexistant → loan_not_found (déterministe)
  -- ===================================================================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role','authenticated')::text, true);

  v_t := '3.01 api.renew_my_loan_item(inexistant) → not_found';
  BEGIN
    PERFORM api.renew_my_loan_item(v_bad, 1);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM ILIKE '%not_found%' OR SQLERRM ILIKE '%nao encontrado%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : motif inattendu ' || SQLERRM); END IF;
  END;

  v_t := '3.02 api.extend_loan_item_as_library(inexistant) → not_found';
  BEGIN
    PERFORM api.extend_loan_item_as_library(v_bad, 1);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM ILIKE '%not_found%' OR SQLERRM ILIKE '%nao encontrado%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : motif inattendu ' || SQLERRM); END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);

  -- ===================================================================
  -- SECTION 4 (best-effort) : renouvellement granulaire d'un item réel
  -- ===================================================================
  v_t := '4.01 renouvellement d''un item par le propriétaire → jsonb avec reason';
  BEGIN
    SELECT e.id, e.user_id, i.line_no INTO v_loan
    FROM public.emprestimos_v2 e
    JOIN public.emprestimo_itens_v2 i ON i.emprestimo_id = e.id AND i.item_status = 'aberto'
    WHERE e.user_id IS NOT NULL
    ORDER BY e.id LIMIT 1;

    IF v_loan.id IS NULL THEN
      v_skipped := v_skipped + 1; v_skips := v_skips || (v_t || ' : aucun item de prêt ouvert');
    ELSE
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_loan.user_id, 'role','authenticated')::text, true);
      SELECT public.fn_renew_my_loan_item(v_loan.id, v_loan.line_no) INTO v_json;
      PERFORM set_config('request.jwt.claims', '', true);
      -- on n'exige pas un renouvellement réussi (dépend des quotas/réserves) :
      -- on valide que la mécanique PAR ITEM répond avec un verdict structuré.
      IF v_json ? 'ok' AND v_json ? 'reason' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : retour inattendu ' || coalesce(v_json::text,'NULL')); END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ===================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'GRANULAIRE OK : %/% tests passés (% skips)%',
      v_passed, (v_passed + v_failed), v_skipped,
      CASE WHEN v_skipped > 0 THEN ' | SKIPS: ' || array_to_string(v_skips, ' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'GRANULAIRE ECHEC : %/% OK, % échec(s) | %  (skips: %)',
      v_passed, (v_passed + v_failed), v_failed, array_to_string(v_failures, ' || '), array_to_string(v_skips, ' ; ');
  END IF;
END $$;
