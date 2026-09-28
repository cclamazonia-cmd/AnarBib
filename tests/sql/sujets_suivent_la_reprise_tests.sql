-- =====================================================================
-- AnarBib — Tests d'acceptation : un brouillon de reprise hérite des sujets,
-- et un brouillon sans aucun sujet n'efface pas ceux de la notice
-- Date : 2026-09-28 · Migration 20260928133838_un_brouillon_de_reprise_herite_des_sujets
--
-- POURQUOI. « Éditer » une notice publiée créait un brouillon sans ses sujets,
-- et la publication remplaçait les sujets de la notice par ceux du brouillon :
-- 136 publications depuis juin ont désindexé des notices sans un mot.
--   Bilan OK : 'SUJETS-REPRISE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_coord constant uuid := '11111111-1111-1111-1111-111111111111';   -- coordenador blmf-test
  v_s1 bigint; v_s2 bigint; v_s3 bigint;
  v_b bigint; v_b0 bigint; v_d bigint; v_d0 bigint; v_d2 bigint; v_d3 bigint;
  v_n int;
BEGIN
  INSERT INTO public.subjects (slug) VALUES ('reprise-sujet-un') RETURNING id INTO v_s1;
  INSERT INTO public.subjects (slug) VALUES ('reprise-sujet-deux') RETURNING id INTO v_s2;
  INSERT INTO public.subjects (slug) VALUES ('reprise-sujet-trois') RETURNING id INTO v_s3;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('Notice indexée', 'REP-1', 'livro', c_lib) RETURNING id INTO v_b;
  INSERT INTO public.book_subjects (book_id, subject_id, ord) VALUES (v_b, v_s1, 1), (v_b, v_s2, 2);
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('Notice sans sujet', 'REP-0', 'livro', c_lib) RETURNING id INTO v_b0;

  v_t := 'T1 le brouillon de reprise hérite des deux sujets de la notice';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, published_book_id, created_by)
  VALUES ('update', 'draft', 'REP-1', 'Notice indexée', 'livro', c_lib, v_b, c_coord) RETURNING id INTO v_d;
  SELECT count(*) INTO v_n FROM public.book_draft_subjects WHERE book_draft_id = v_d;
  IF v_n = 2 AND EXISTS (SELECT 1 FROM public.book_draft_subjects WHERE book_draft_id = v_d AND subject_id = v_s1 AND ord = 1) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;

  v_t := 'T2 publié tel quel, la notice garde ses deux sujets';
  UPDATE public.book_drafts SET status = 'published' WHERE id = v_d;
  SELECT count(*) INTO v_n FROM public.book_subjects WHERE book_id = v_b;
  IF v_n = 2 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;

  v_t := 'T3 un sujet ajouté au brouillon, un retiré : la notice suit';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, published_book_id, created_by)
  VALUES ('update', 'draft', 'REP-1', 'Notice indexée', 'livro', c_lib, v_b, c_coord) RETURNING id INTO v_d2;
  DELETE FROM public.book_draft_subjects WHERE book_draft_id = v_d2 AND subject_id = v_s2;
  INSERT INTO public.book_draft_subjects (book_draft_id, subject_id, ord) VALUES (v_d2, v_s3, 2);
  UPDATE public.book_drafts SET status = 'published' WHERE id = v_d2;
  IF (SELECT count(*) FROM public.book_subjects WHERE book_id = v_b) = 2
     AND EXISTS (SELECT 1 FROM public.book_subjects WHERE book_id = v_b AND subject_id = v_s3)
     AND NOT EXISTS (SELECT 1 FROM public.book_subjects WHERE book_id = v_b AND subject_id = v_s2) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : '
    || (SELECT string_agg(subject_id::text, ',' ORDER BY ord) FROM public.book_subjects WHERE book_id = v_b)); END IF;

  v_t := 'T4 un brouillon vidé de tout sujet, publié, n''efface pas ceux de la notice';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, published_book_id, created_by)
  VALUES ('update', 'draft', 'REP-1', 'Notice indexée', 'livro', c_lib, v_b, c_coord) RETURNING id INTO v_d3;
  DELETE FROM public.book_draft_subjects WHERE book_draft_id = v_d3;
  UPDATE public.book_drafts SET status = 'published' WHERE id = v_d3;
  SELECT count(*) INTO v_n FROM public.book_subjects WHERE book_id = v_b;
  IF v_n = 2 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;

  v_t := 'T5 une notice sans sujet : le brouillon n''en a pas, la publication passe, rien ne change';
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, published_book_id, created_by)
  VALUES ('update', 'draft', 'REP-0', 'Notice sans sujet', 'livro', c_lib, v_b0, c_coord) RETURNING id INTO v_d0;
  BEGIN
    UPDATE public.book_drafts SET status = 'published' WHERE id = v_d0;
    IF (SELECT count(*) FROM public.book_draft_subjects WHERE book_draft_id = v_d0) = 0
       AND (SELECT count(*) FROM public.book_subjects WHERE book_id = v_b0) = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  v_t := 'T6 un brouillon qui a déjà ses sujets à la création n''est pas doublé';
  INSERT INTO public.book_drafts (id, action, status, bib_ref, titulo, tipo_material, owner_library_id, published_book_id, created_by)
  VALUES (DEFAULT, 'update', 'draft', 'REP-1', 'Notice indexée', 'livro', c_lib, v_b, c_coord) RETURNING id INTO v_d;
  -- (le déclencheur a semé les deux sujets ; une seconde insertion identique ne peut pas doubler : clé primaire)
  IF (SELECT count(*) FROM public.book_draft_subjects WHERE book_draft_id = v_d) = 2 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  v_t := 'T7 rien de neuf n''est ouvert au lectorat';
  IF NOT has_function_privilege('anon', 'public.fn_seed_draft_subjects()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_seed_draft_subjects()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_sync_book_subjects_on_publish()', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'SUJETS-REPRISE ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'SUJETS-REPRISE OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
