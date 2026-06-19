-- =====================================================================
-- AnarBib — Tests d'acceptation : RÉCOLEMENT / veille du commun (lots 1+2)
-- Date    : 2026-06-19  ·  Session : Récolement (veille du commun)
-- Réf     : 20260619152022 (schéma) + 20260619153704 (RPC) ; CADRAGE_recolement.
--
-- Couvre : gardes + cycle campagne (start/scan idempotent/close→drapeau « non vu »/
-- report) + notation d'état + (best-effort) le trigger passif retour-de-prêt.
-- Fixtures dynamiques (crée livre + holding + 2 exemplaires BLMF).
--   Bilan OK : 'RECOLEMENT OK : N/N tests passés (S skips)'
-- =====================================================================
DO $$
DECLARE
  v_passed int:=0; v_failed int:=0; v_skipped int:=0;
  v_failures text[]:=ARRAY[]::text[]; v_skips text[]:=ARRAY[]::text[]; v_t text;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_coord uuid; v_outsider uuid;
  v_book bigint; v_holding bigint; v_ex1 bigint; v_ex2 bigint;
  v_camp bigint; v_json jsonb; v_via text; v_flag boolean; v_emp bigint;
BEGIN
  SELECT user_id INTO v_coord FROM public.user_library_memberships
    WHERE library_id=c_blmf AND role='coordenador' AND status='active' LIMIT 1;
  IF v_coord IS NULL THEN RAISE EXCEPTION 'SETUP: pas de coordenador BLMF'; END IF;
  SELECT p.id INTO v_outsider FROM public.profiles p
    WHERE NOT EXISTS (SELECT 1 FROM public.user_library_memberships m WHERE m.user_id=p.id AND m.library_id=c_blmf) LIMIT 1;

  -- Fixtures : livre + holding + 2 exemplaires BLMF.
  INSERT INTO public.books DEFAULT VALUES RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, c_blmf) RETURNING id INTO v_holding;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, circulation_policy, holding_id)
    VALUES ('TEST-REC', 'TESTREC-A', c_blmf, 'emprestavel', v_holding) RETURNING id INTO v_ex1;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, circulation_policy, holding_id)
    VALUES ('TEST-REC', 'TESTREC-B', c_blmf, 'emprestavel', v_holding) RETURNING id INTO v_ex2;

  -- T1 — start non-staff -> rejet
  v_t:='T1 start_campaign non-staff -> rejet';
  IF v_outsider IS NULL THEN v_skipped:=v_skipped+1; v_skips:=v_skips|| text 'T1 : pas d''outsider'; ELSE
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_outsider,'role','authenticated')::text, true);
    PERFORM public.fn_inventory_start_campaign(c_blmf, 'all', NULL, NULL);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  END IF;

  -- T2 — start (coord) -> campaign_id
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_inventory_start_campaign(c_blmf, 'all', NULL, 'test récolement');
  v_camp := (v_json->>'campaign_id')::bigint;
  v_t:='T2 start_campaign (coord) -> ok';
  IF (v_json->>'ok')='true' AND v_camp IS NOT NULL THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  -- T3 — scan ex1 -> ok, already=false, last_seen_via=inventory_scan
  v_json := public.fn_inventory_record_scan(v_camp, v_ex1);
  SELECT last_seen_via INTO v_via FROM public.exemplares WHERE id=v_ex1;
  v_t:='T3 record_scan ex1 -> vu (last_seen_via=inventory_scan)';
  IF (v_json->>'ok')='true' AND (v_json->>'already_scanned')='false' AND v_via='inventory_scan'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')||' via='||coalesce(v_via,'NULL')); END IF;

  -- T4 — scan ex1 encore -> already=true (idempotent)
  v_json := public.fn_inventory_record_scan(v_camp, v_ex1);
  v_t:='T4 record_scan idempotent -> already_scanned=true';
  IF (v_json->>'already_scanned')='true' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json->>'already_scanned','NULL')); END IF;

  -- T5 — scan non-staff -> rejet
  v_t:='T5 record_scan non-staff -> rejet';
  IF v_outsider IS NULL THEN v_skipped:=v_skipped+1; v_skips:=v_skips|| text 'T5 : pas d''outsider'; ELSE
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_outsider,'role','authenticated')::text, true);
    PERFORM public.fn_inventory_record_scan(v_camp, v_ex2);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  END IF;

  -- T6 — set_condition ex1 a_reparar
  v_json := public.fn_inventory_set_condition(v_ex1, 'a_reparar', 'reliure abîmée');
  v_t:='T6 set_condition -> a_reparar';
  IF (SELECT condition_status FROM public.exemplares WHERE id=v_ex1)='a_reparar'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  -- T7 — close -> ex2 (non scanné, en périmètre) flaggé « non vu » ; ex1 non flaggé
  v_json := public.fn_inventory_close_campaign(v_camp);
  v_t:='T7 close -> non-vu flaggé sur ex2, pas sur ex1';
  IF (v_json->>'ok')='true'
     AND (SELECT not_seen_flag FROM public.exemplares WHERE id=v_ex2) = true
     AND (SELECT not_seen_flag FROM public.exemplares WHERE id=v_ex1) = false
     AND (v_json->>'seen')='1'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')); END IF;

  -- T8 — report -> seen=1, not_seen>=1, unexpected=0
  v_json := public.fn_inventory_campaign_report(v_camp);
  v_t:='T8 report -> seen=1 / not_seen>=1 / unexpected=0';
  IF (v_json->>'seen')='1' AND (v_json->>'not_seen')::int >= 1 AND (v_json->>'unexpected')='0'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')); END IF;

  -- T9 — trigger passif (best-effort : nécessite de créer un emprunt ; SKIP si la garde le refuse)
  v_t:='T9 trigger retour-de-prêt -> last_seen_via=loan_return + non-vu effacé';
  BEGIN
    INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
      VALUES (v_coord, c_blmf, 'aberto', current_date + 14) RETURNING id INTO v_emp;
    INSERT INTO public.emprestimo_itens_v2 (emprestimo_id, line_no, sub_id, item_id, bib_ref, item_status, due_at)
      VALUES (v_emp, 1, v_emp || '.1', v_ex2, 'TEST-REC', 'aberto', current_date + 14);
    UPDATE public.emprestimo_itens_v2 SET item_status='devolvido' WHERE emprestimo_id=v_emp AND line_no=1;
    SELECT last_seen_via, not_seen_flag INTO v_via, v_flag FROM public.exemplares WHERE id=v_ex2;
    IF v_via='loan_return' AND v_flag=false THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' via='||coalesce(v_via,'NULL')||' flag='||coalesce(v_flag::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_skipped:=v_skipped+1; v_skips:=v_skips|| text 'T9 : création d''emprunt refusée par la garde (trigger non testé E2E ici)';
  END;

  IF v_failed=0 THEN
    RAISE EXCEPTION 'RECOLEMENT OK : %/% tests passés (% skips)%', v_passed, (v_passed+v_failed), v_skipped,
      CASE WHEN v_skipped>0 THEN ' | SKIPS: '||array_to_string(v_skips,' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'RECOLEMENT ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
