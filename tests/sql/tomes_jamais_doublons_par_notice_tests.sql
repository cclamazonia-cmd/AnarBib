-- =====================================================================
-- AnarBib — Tests d'acceptation : deux tomes différents ne sont jamais un
-- doublon, dans le détecteur par notice et dans celui des brouillons
-- Date : 2026-10-08 · Migration 20261008185800_deux_tomes_differents_ne_sont_jamais_un_doublon_par_notice
--
-- POURQUOI. Le balayage global écarte deux tomes différents depuis le lot 4
-- (04/09) ; l'assistant ouvert sur une fiche (suggest_book_duplicates) et le
-- formulaire (api.suggest_draft_duplicates) ne lisaient pas le tome : sur
-- BTL-TL-000323 (tome 1) ils proposaient MLEG-0017 et BTL-TL-000322 (tome 2)
-- à côté de MLEG-0016 (tome I, le vrai doublon). 64 paires de tomes à tort.
-- Fixtures calquées sur le cas réel (Thomas, A guerra civil espanhola, 1964).
--   Bilan OK : 'TOMES JAMAIS DOUBLONS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_coord constant uuid := '11111111-1111-1111-1111-111111111111';   -- coordenador blmf-test
  v_a bigint; v_b bigint; v_c bigint; v_d bigint; v_e bigint; v_work bigint;
  v_d2 bigint; v_d3 bigint; v_dn bigint;
  v_ids bigint[]; v_err text;
BEGIN
  v_t := 'T1 « 1 » et « I » sont le même tome, « 2 » et « 3 » non ; le marqueur se lit dans le titre';
  IF public.fn_volume_rank('1') = public.fn_volume_rank('I')
     AND public.fn_volume_rank('2') = public.fn_volume_rank('II')
     AND public.fn_volume_rank('2') <> public.fn_volume_rank('3')
     AND public.fn_volume_rank(public.fn_volume_marker('A Guerra Civil Espanhola Vol III')) = 3
     AND public.fn_volume_rank(NULL) IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- Cinq notices de la même œuvre, même édition (1964, Civilização Brasileira, sans ISBN) :
  --   A tome 2 (posé, sous-titre « volume 2 ») · B tome II (posé, titre « Vol II ») = le vrai doublon de A
  --   C tome 3 (posé) · D tome III lu dans le titre seulement · E sans tome.
  INSERT INTO public.books (titulo, subtitulo, autor, bib_ref, tipo_material, ano, editora, volume, owner_library_id)
  VALUES ('A guerra civil espanhola', 'volume 2', 'THOMAS, Hugh', 'TOME-A', 'livro', '1964', 'Civilização Brasileira', '2', c_lib)
  RETURNING id, work_id INTO v_a, v_work;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, ano, editora, volume, owner_library_id, work_id)
  VALUES ('A Guerra Civil Espanhola Vol II', 'THOMAS, Hugh', 'TOME-B', 'livro', '1964', 'Civilização Brasileira', 'II', c_lib, v_work)
  RETURNING id INTO v_b;
  INSERT INTO public.books (titulo, subtitulo, autor, bib_ref, tipo_material, ano, editora, volume, owner_library_id, work_id)
  VALUES ('A guerra civil espanhola', 'volume 3', 'THOMAS, Hugh', 'TOME-C', 'livro', '1964', 'Civilização Brasileira', '3', c_lib, v_work)
  RETURNING id INTO v_c;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, ano, editora, owner_library_id, work_id)
  VALUES ('A Guerra Civil Espanhola Vol III', 'THOMAS, Hugh', 'TOME-D', 'livro', '1964', 'Civilização Brasileira', c_lib, v_work)
  RETURNING id INTO v_d;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, ano, editora, owner_library_id, work_id)
  VALUES ('A guerra civil espanhola', 'THOMAS, Hugh', 'TOME-E', 'livro', '1964', 'Civilização Brasileira', c_lib, v_work)
  RETURNING id INTO v_e;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count)
  VALUES (v_a, c_lib, 1, 1), (v_b, c_lib, 1, 1), (v_c, c_lib, 1, 1), (v_d, c_lib, 1, 1), (v_e, c_lib, 1, 1);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_coord, 'role', 'authenticated')::text, true);

  v_t := 'T2 sur le tome 2, l''assistant propose le tome II et la notice sans tome — jamais les tomes 3 et III';
  v_ids := NULL; v_err := NULL;
  BEGIN
    SELECT array_agg(s.book_id ORDER BY s.book_id) INTO v_ids FROM public.suggest_book_duplicates(v_a) s;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err IS NULL AND v_ids = ARRAY[v_b, v_e] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, coalesce(v_ids::text, 'rien') || ' attendu ' || ARRAY[v_b, v_e]::text)); END IF;

  v_t := 'T3 sur le tome 3, l''assistant propose le tome III lu dans le titre et la notice sans tome — jamais 2 et II';
  v_ids := NULL; v_err := NULL;
  BEGIN
    SELECT array_agg(s.book_id ORDER BY s.book_id) INTO v_ids FROM public.suggest_book_duplicates(v_c) s;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err IS NULL AND v_ids = ARRAY[v_d, v_e] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, coalesce(v_ids::text, 'rien') || ' attendu ' || ARRAY[v_d, v_e]::text)); END IF;

  v_t := 'T4 sur la notice sans tome, tout reste candidat : c''est à une main de poser le tome';
  v_ids := NULL; v_err := NULL;
  BEGIN
    SELECT array_agg(s.book_id ORDER BY s.book_id) INTO v_ids FROM public.suggest_book_duplicates(v_e) s;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err IS NULL AND v_ids = ARRAY[v_a, v_b, v_c, v_d] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, coalesce(v_ids::text, 'rien'))); END IF;

  -- Trois brouillons de la bibliothèque : tome 2, tome 3, sans tome.
  INSERT INTO public.book_drafts (titulo, autor, tipo_material, ano, editora, volume, owner_library_id, created_by, status)
  VALUES ('A guerra civil espanhola', 'THOMAS, Hugh', 'livro', '1964', 'Civilização Brasileira', '2', c_lib, c_coord, 'draft')
  RETURNING id INTO v_d2;
  INSERT INTO public.book_drafts (titulo, autor, tipo_material, ano, editora, volume, owner_library_id, created_by, status)
  VALUES ('A guerra civil espanhola', 'THOMAS, Hugh', 'livro', '1964', 'Civilização Brasileira', '3', c_lib, c_coord, 'draft')
  RETURNING id INTO v_d3;
  INSERT INTO public.book_drafts (titulo, autor, tipo_material, ano, editora, owner_library_id, created_by, status)
  VALUES ('A guerra civil espanhola', 'THOMAS, Hugh', 'livro', '1964', 'Civilização Brasileira', c_lib, c_coord, 'draft')
  RETURNING id INTO v_dn;

  v_t := 'T5 le brouillon du tome 2 voit les notices 2, II et sans tome, et le brouillon sans tome — jamais 3, III ni le brouillon du tome 3';
  v_ids := NULL; v_err := NULL;
  BEGIN
    SELECT array_agg(s.candidate_id ORDER BY s.candidate_id) INTO v_ids FROM api.suggest_draft_duplicates(v_d2) s;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err IS NULL AND v_ids = (SELECT array_agg(x ORDER BY x) FROM unnest(ARRAY[v_a, v_b, v_e, v_dn]) x) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, coalesce(v_ids::text, 'rien') || ' attendu ' || ARRAY[v_a, v_b, v_e, v_dn]::text)); END IF;

  v_t := 'T6 le brouillon sans tome voit tout';
  v_ids := NULL; v_err := NULL;
  BEGIN
    SELECT array_agg(s.candidate_id ORDER BY s.candidate_id) INTO v_ids FROM api.suggest_draft_duplicates(v_dn) s;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err IS NULL AND v_ids = (SELECT array_agg(x ORDER BY x) FROM unnest(ARRAY[v_a, v_b, v_c, v_d, v_e, v_d2, v_d3]) x) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, coalesce(v_ids::text, 'rien'))); END IF;

  PERFORM set_config('request.jwt.claims', '', true);

  v_t := 'T7 les deux détecteurs restent fermés à anon';
  IF NOT has_function_privilege('anon', 'public.suggest_book_duplicates(bigint)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.suggest_draft_duplicates(bigint)', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'TOMES JAMAIS DOUBLONS ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'TOMES JAMAIS DOUBLONS OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
