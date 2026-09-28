-- =====================================================================
-- AnarBib — Tests d'acceptation : un même ISBN est une même édition, sous ses
-- deux formes ; un éditeur ne change pas de nom pour un mot générique
-- Date : 2026-09-28 · Migration 20260928163920_un_meme_isbn_est_une_meme_edition
--
-- POURQUOI. BTL-TL-000504 et BTL-TL-000727 (Anarquistas, Suriano, Manantial,
-- 2001), ISBN-13 d'un côté, ISBN-10 de l'autre, même œuvre : jamais proposées
-- comme doublon — l'ISBN était comparé chiffre à chiffre, et « Manantial » /
-- « Ediciones Manantial » passaient pour deux éditeurs. Aucune suite
-- n'exerçait fn_editions_distinctes (DEDUP-14).
--   Bilan OK : 'EDITIONS DISTINCTES OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_coord constant uuid := '11111111-1111-1111-1111-111111111111';   -- coordenador blmf-test
  v_a bigint; v_b bigint; v_c bigint; v_work bigint;
  v_ids bigint[]; v_kind text; v_err text; v_n int;
BEGIN
  v_t := 'T1 l''ISBN-10 et l''ISBN-13 du même livre ont le même cœur ; ce qui n''est pas un ISBN n''en a pas';
  IF public.fn_isbn_coeur('987-500-069-8') = public.fn_isbn_coeur('978-987-500-069-8')
     AND public.fn_isbn_coeur('978-987-500-069-8') = '978987500069'
     AND public.fn_isbn_coeur('85-219-0351-0') = '978852190351'
     AND public.fn_isbn_coeur('abc') = '' AND public.fn_isbn_coeur(NULL) = '' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || public.fn_isbn_coeur('987-500-069-8') || ' / ' || public.fn_isbn_coeur('978-987-500-069-8')); END IF;

  v_t := 'T2 même ISBN sous deux formes = même édition, quoi qu''en disent l''éditeur et l''année';
  IF NOT public.fn_editions_distinctes('978-987-500-069-8', '987-500-069-8', '2001', '2001', 'Manantial', 'Ediciones Manantial', '', '')
     AND NOT public.fn_editions_distinctes('978-85-7715-072-4', '9788577150724', '2007', '2011', 'Hedra', 'Hedra', '', '') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  v_t := 'T3 deux ISBN différents = deux éditions, même titre, même année, même éditeur';
  IF public.fn_editions_distinctes('978-85-7715-072-4', '978-85-7935-000-9', '2007', '2007', 'Hedra', 'Hedra', '', '') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- (une faute de frappe — « L'Exixam » pour « L'Eixam », BTL-TL-001754 — n'est PAS un mot
  --  générique : similarité 0,44, la règle ne l'avale pas ; c'est une donnée à corriger)
  v_t := 'T4 sans ISBN, un mot générique ou une co-édition ne font pas deux éditeurs';
  IF public.fn_meme_editeur('Manantial', 'Ediciones Manantial')
     AND public.fn_meme_editeur('Editora Imaginario', 'Imaginário')
     AND public.fn_meme_editeur('Editora Imaginário', 'Editora Imaginário / Expressão & Arte Editora')
     AND NOT public.fn_editions_distinctes('', '', '2001', '2001', 'Manantial', 'Ediciones Manantial', '', '') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || public.fn_editeur_coeur('Ediciones Manantial') || ' / ' || public.fn_editeur_coeur('Editora Imaginário / Expressão & Arte Editora')); END IF;

  v_t := 'T5 sans ISBN, deux éditeurs vraiment différents, deux années ou deux mentions d''édition = deux éditions';
  IF NOT public.fn_meme_editeur('Manantial', 'Hedra')
     AND public.fn_editions_distinctes('', '', '2001', '2001', 'Manantial', 'Hedra', '', '')
     AND public.fn_editions_distinctes('', '', '2010', '2011', 'Imaginário', 'Imaginário', '', '')
     AND public.fn_editions_distinctes('', '', '2010', '2010', 'Imaginário', 'Imaginário', '1. ed.', '2. ed.')
     AND NOT public.fn_editions_distinctes('', '', '2010', '2010', 'Imaginário', '', '', '') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- Une paire à la Suriano : même œuvre, ISBN-13 / ISBN-10, éditeur avec et sans « Ediciones ».
  INSERT INTO public.books (titulo, subtitulo, autor, bib_ref, tipo_material, ano, isbn, editora, owner_library_id)
  VALUES ('Anarquistas', 'cultura y política libertaria', 'SURIANO, Juan', 'ED-A', 'livro', '2001', '978-987-500-069-8', 'Manantial', c_lib) RETURNING id, work_id INTO v_a, v_work;
  INSERT INTO public.books (titulo, subtitulo, autor, bib_ref, tipo_material, ano, isbn, editora, owner_library_id, work_id)
  VALUES ('Anarquistas', 'Cultura y Política Libertaria', 'SURIANO, Juan', 'ED-B', 'livro', '2001', '987-500-069-8', 'Ediciones Manantial', c_lib, v_work) RETURNING id INTO v_b;
  -- Et une vraie autre édition de la même œuvre : autre ISBN, autre année.
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, ano, isbn, editora, owner_library_id, work_id)
  VALUES ('Anarquistas', 'SURIANO, Juan', 'ED-C', 'livro', '2008', '978-987-500-123-7', 'Manantial', c_lib, v_work) RETURNING id INTO v_c;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_a, c_lib, 1, 1), (v_b, c_lib, 1, 1), (v_c, c_lib, 1, 1);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_coord, 'role', 'authenticated')::text, true);

  v_t := 'T6 suggest_book_duplicates propose la paire (isbn), pas l''autre édition';
  v_ids := NULL; v_kind := NULL; v_err := NULL;
  BEGIN
    SELECT array_agg(s.book_id ORDER BY s.book_id), max(s.match_kind) FILTER (WHERE s.book_id = v_b) INTO v_ids, v_kind
      FROM public.suggest_book_duplicates(v_a) s;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err IS NULL AND v_ids = ARRAY[v_b] AND v_kind = 'isbn' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, coalesce(v_ids::text, 'rien') || ' / ' || coalesce(v_kind, '-'))); END IF;

  v_t := 'T7 le balayage du catalogue voit la paire au niveau « isbn », pas l''autre édition';
  v_err := NULL; v_n := NULL; v_kind := NULL;
  BEGIN
    SELECT count(*), max(niveau_preuve) INTO v_n, v_kind FROM public.suggest_catalog_duplicates(2000) s
     WHERE least(s.book_id_a, s.book_id_b) = least(v_a, v_b) AND greatest(s.book_id_a, s.book_id_b) = greatest(v_a, v_b);
    IF v_err IS NULL AND v_n = 1 AND v_kind = 'isbn'
       AND NOT EXISTS (SELECT 1 FROM public.suggest_catalog_duplicates(2000) s WHERE v_c IN (s.book_id_a, s.book_id_b) AND (v_a IN (s.book_id_a, s.book_id_b) OR v_b IN (s.book_id_a, s.book_id_b))) THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : n=' || coalesce(v_n::text, '-') || ' niveau=' || coalesce(v_kind, '-')); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  PERFORM set_config('request.jwt.claims', '', true);

  v_t := 'T8 rien n''est ouvert à anon';
  IF NOT has_function_privilege('anon', 'public.fn_isbn_coeur(text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_editeur_coeur(text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_meme_editeur(text, text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_editions_distinctes(text, text, text, text, text, text, text, text)', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'EDITIONS DISTINCTES ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'EDITIONS DISTINCTES OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
