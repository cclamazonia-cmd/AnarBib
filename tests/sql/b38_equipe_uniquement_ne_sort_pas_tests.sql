-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — B38 (11/10/2026) : un exemplaire « équipe uniquement » (visibility
-- = 'staff_only') ou « consultation seule » (circulation_policy = 'consulta')
-- ne sort pas de la bibliothèque par un chemin détourné. Le prêt direct, la
-- consultation et la recherche PEB les refusaient déjà ; quatre fonctions de
-- circulation les prenaient encore (constat du lot 7 de H21).
--   T1 réservation : un fonds dont le seul exemplaire est « équipe uniquement »
--      n'a rien à réserver (« Sem exemplares disponíveis ») ;
--   T2 réservation : un fonds avec un « équipe uniquement » d'identifiant PLUS
--      BAS et un public se réserve ;
--   T3 conversion de T2 : l'emprunt porte l'exemplaire public, jamais celui
--      d'archive ;
--   T4 conversion quand le seul exemplaire libre est « équipe uniquement » :
--      « Nenhum exemplar disponível » ;
--   T5 PEB, ajout d'un exemplaire « équipe uniquement » désigné : refus P0001,
--      HINT error.circulation.item_staff_only ;
--   T6 PEB, ajout d'un « consultation seule » : refus, item_consult_only ;
--   T7 PEB, création avec un « équipe uniquement » : refus, item_staff_only ;
--   T8 PEB, création avec un « consultation seule » : refus, item_consult_only ;
--   T9 réservation : un fonds dont le seul exemplaire est public mais
--      « consultation seule » n'a rien à réserver.
-- Fixtures : BLMF du seed (sa politique de circulation, son lectorat, sa
-- coordination ; numéros d'inventaire posés à la main, le seed n'a pas de patron) pour la réservation et la conversion ; deux bibliothèques
-- fédérées créées ici pour le PEB. Tout se fait sous postgres avec un JWT
-- simulé (stub auth) ; la suite lève toujours (OK ou ECHEC) : rien ne reste.
-- Mutant éprouvé : sans les lignes « -- B38 » de la migration, T1, T3 à T9 rougissent.
--   Bilan OK : 'B38 OK : N/N tests passés'
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  c_leitor constant uuid := '44444444-4444-4444-4444-444444444444';
  v_coord uuid;
  v_book1 bigint; v_hold1 bigint; v_ex1 bigint;                 -- fonds 1 : un seul exemplaire, équipe uniquement
  v_book2 bigint; v_hold2 bigint; v_ex2s bigint; v_ex2p bigint; -- fonds 2 : équipe uniquement (id plus bas) + public
  v_book3 bigint; v_hold3 bigint; v_ex3 bigint;                 -- fonds 3 : public, consultation seule
  v_libA uuid; v_libB uuid; v_coordA uuid := gen_random_uuid();
  v_bookA bigint; v_holdA bigint; v_exAs bigint; v_exAc bigint;  -- fonds PEB : équipe uniquement, consultation seule
  v_loan bigint; v_res bigint; v_emp bigint; v_item bigint; v_n int; v_b boolean;
  v_txt text; v_hint text; v_state text; v_json jsonb;
BEGIN
  SELECT m.user_id INTO v_coord FROM public.user_library_memberships m
   WHERE m.library_id = c_blmf AND m.role = 'coordenador' AND m.status = 'active' LIMIT 1;
  IF v_coord IS NULL THEN RAISE EXCEPTION 'B38 : le seed ne fournit pas de coordination BLMF'; END IF;

  -- Trois fonds BLMF, créés ici.
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, loanable) VALUES ('B38 un (essai)', 'Essai, Autrice', 'B38-1-' || v_suf, 'livro', true) RETURNING id INTO v_book1;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (v_book1, c_blmf, true) RETURNING id INTO v_hold1;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('B38-1-' || v_suf, 'B38' || v_suf || '-1-001', c_blmf, v_hold1, 'ambos', 'staff_only') RETURNING id INTO v_ex1;

  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, loanable) VALUES ('B38 deux (essai)', 'Essai, Autrice', 'B38-2-' || v_suf, 'livro', true) RETURNING id INTO v_book2;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (v_book2, c_blmf, true) RETURNING id INTO v_hold2;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('B38-2-' || v_suf, 'B38' || v_suf || '-2-001', c_blmf, v_hold2, 'ambos', 'staff_only') RETURNING id INTO v_ex2s;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('B38-2-' || v_suf, 'B38' || v_suf || '-2-002', c_blmf, v_hold2, 'ambos', 'public') RETURNING id INTO v_ex2p;
  IF v_ex2s >= v_ex2p THEN RAISE EXCEPTION 'B38 : la fixture veut l''exemplaire d''archive AVANT le public (ids % / %)', v_ex2s, v_ex2p; END IF;

  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, loanable) VALUES ('B38 trois (essai)', 'Essai, Autrice', 'B38-3-' || v_suf, 'livro', true) RETURNING id INTO v_book3;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (v_book3, c_blmf, true) RETURNING id INTO v_hold3;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('B38-3-' || v_suf, 'B38' || v_suf || '-3-001', c_blmf, v_hold3, 'consulta', 'public') RETURNING id INTO v_ex3;

  -- Deux bibliothèques fédérées pour le PEB, une coordination côté prêteuse.
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('b38-a-' || v_suf, 'B38 A (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('b38-b-' || v_suf, 'B38 B (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libB;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_coordA, 'authenticated', 'authenticated', 'b38-coord-' || v_suf || '@anarbib.local', now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}');
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language) VALUES (v_coordA, 'b38-coord-' || v_suf || '@anarbib.local', 'B38', 'Coord', 'fr');
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES (v_coordA, v_libA, 'coordenador', 'active', true);
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, loanable) VALUES ('B38 PEB (essai)', 'Essai, Autrice', 'B38-P-' || v_suf, 'livro', true) RETURNING id INTO v_bookA;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (v_bookA, v_libA, true) RETURNING id INTO v_holdA;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('B38-P-' || v_suf, 'B38P' || v_suf || '-001', v_libA, v_holdA, 'ambos', 'staff_only') RETURNING id INTO v_exAs;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('B38-P-' || v_suf, 'B38P' || v_suf || '-002', v_libA, v_holdA, 'consulta', 'public') RETURNING id INTO v_exAc;
  INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id, status_global, created_by)
  VALUES (v_libA, v_libB, v_libA, 'preparacao', v_coordA) RETURNING id INTO v_loan;

  -- ───────────────────────────────────────────────────────
  v_t := 'T1 réservation : un fonds dont le seul exemplaire est « équipe uniquement » n''a rien à réserver';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_leitor, 'role', 'authenticated')::text, true);
    BEGIN
      v_res := public.fn_v2_create_reserva_by_holdings(c_leitor, ARRAY[v_hold1], NULL, 'B38 T1'); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt LIKE '%Sem exemplares disponíveis%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T2 réservation : un fonds avec un « équipe uniquement » (id plus bas) et un public se réserve';
  v_res := NULL;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_leitor, 'role', 'authenticated')::text, true);
    v_res := public.fn_v2_create_reserva_by_holdings(c_leitor, ARRAY[v_hold2], NULL, 'B38 T2');
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT count(*) INTO v_n FROM public.reserva_linhas_v2 rl WHERE rl.reserva_id = v_res AND rl.holding_id = v_hold2 AND rl.item_status = 'ativa';
    IF v_res IS NOT NULL AND v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : reserva %s, lignes %s', v_res, v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T3 conversion de T2 : l''emprunt porte l''exemplaire public, jamais celui d''archive';
  IF v_res IS NULL THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : sans réservation (T2)');
  ELSE
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_emp := public.fn_v2_convert_reserva_linhas_to_emprestimo(v_res, ARRAY[1], NULL, 'B38 T3');
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT i.item_id INTO v_item FROM public.emprestimo_itens_v2 i WHERE i.emprestimo_id = v_emp ORDER BY i.line_no LIMIT 1;
    IF v_item = v_ex2p THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : exemplaire %s (archive %s, public %s)', v_item, v_ex2s, v_ex2p)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  END IF;
  -- ───────────────────────────────────────────────────────
  v_t := 'T4 conversion quand le seul exemplaire libre est « équipe uniquement » : « Nenhum exemplar disponível »';
  BEGIN
    -- une réservation posée directement sur le fonds 1 (la fonction de réservation la refuse depuis T1)
    INSERT INTO public.reservas_v2 (user_id, library_id, notes, status_global) VALUES (c_leitor, c_blmf, 'B38 T4', 'ativa') RETURNING id INTO v_res;
    INSERT INTO public.reserva_linhas_v2 (reserva_id, line_no, book_id, holding_id, bib_ref, item_status, titulo_cache)
    VALUES (v_res, 1, v_book1, v_hold1, 'B38-1-' || v_suf, 'ativa', 'B38 un (essai)');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    BEGIN
      v_emp := public.fn_v2_convert_reserva_linhas_to_emprestimo(v_res, ARRAY[1], NULL, 'B38 T4'); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt LIKE '%Nenhum exemplar disponível%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T5 PEB, ajout d''un « équipe uniquement » désigné : refus P0001, error.circulation.item_staff_only';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_v2_add_emprestimo_interbibliotecas_itens(v_loan, ARRAY[v_exAs], NULL, NULL); v_txt := 'passé'; v_hint := NULL; v_state := NULL;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT count(*) INTO v_n FROM public.interlibrary_loan_items_v2 i WHERE i.interlibrary_loan_id = v_loan;
    IF v_txt = 'refusé' AND v_state = 'P0001' AND v_hint = 'error.circulation.item_staff_only' AND v_n = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s, lignes %s', v_txt, v_state, v_hint, v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T6 PEB, ajout d''un « consultation seule » : refus, error.circulation.item_consult_only';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_v2_add_emprestimo_interbibliotecas_itens(v_loan, ARRAY[v_exAc], NULL, NULL); v_txt := 'passé'; v_hint := NULL; v_state := NULL;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt = 'refusé' AND v_state = 'P0001' AND v_hint = 'error.circulation.item_consult_only' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s', v_txt, v_state, v_hint)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T7 PEB, création avec un « équipe uniquement » : refus, error.circulation.item_staff_only';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    BEGIN
      v_json := public.fn_peb_create_loan_with_items(
        jsonb_build_object('lender_library_id', v_libA, 'borrower_library_id', v_libB, 'initiated_by_library_id', v_libA),
        jsonb_build_array(jsonb_build_object('line_no', 1, 'holding_id', v_holdA, 'item_id', v_exAs, 'bib_ref', 'B38-P-' || v_suf)));
      v_txt := 'passé'; v_hint := NULL; v_state := NULL;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT count(*) INTO v_n FROM public.interlibrary_loan_items_v2 i WHERE i.item_id = v_exAs;
    IF v_txt = 'refusé' AND v_state = 'P0001' AND v_hint = 'error.circulation.item_staff_only' AND v_n = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s, lignes %s', v_txt, v_state, v_hint, v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T8 PEB, création avec un « consultation seule » : refus, error.circulation.item_consult_only';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    BEGIN
      v_json := public.fn_peb_create_loan_with_items(
        jsonb_build_object('lender_library_id', v_libA, 'borrower_library_id', v_libB, 'initiated_by_library_id', v_libA),
        jsonb_build_array(jsonb_build_object('line_no', 1, 'holding_id', v_holdA, 'item_id', v_exAc, 'bib_ref', 'B38-P-' || v_suf)));
      v_txt := 'passé'; v_hint := NULL; v_state := NULL;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt = 'refusé' AND v_state = 'P0001' AND v_hint = 'error.circulation.item_consult_only' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s', v_txt, v_state, v_hint)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T9 réservation : un fonds dont le seul exemplaire est public mais « consultation seule » n''a rien à réserver';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_leitor, 'role', 'authenticated')::text, true);
    BEGIN
      v_res := public.fn_v2_create_reserva_by_holdings(c_leitor, ARRAY[v_hold3], NULL, 'B38 T9'); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt LIKE '%Sem exemplares disponíveis%' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─── Bilan : tout est annulé ────────────────────────────
  IF v_failed > 0 THEN
    RAISE EXCEPTION 'B38 ECHEC : %/% tests passés — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'B38 OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
