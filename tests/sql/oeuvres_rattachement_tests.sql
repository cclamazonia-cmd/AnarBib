-- =====================================================================
-- AnarBib — Tests : les oeuvres se rattachent et se fusionnent (lot 1b)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre
-- Ref     : 20260904130000 (work_not_same, merge_works, fn_work_prune_if_empty,
--           suggest_split_works, mark_works_not_same, search_works_for_link)
--
-- Ce que le 04/09 a montre : group_books_as_editions laissait des oeuvres
-- vides derriere lui, et rien ne proposait de rapprocher deux oeuvres du
-- meme auteur au titre proche. T1/T2 verifient le balayage et sa memoire ;
-- T3/T4/T6 que plus aucun geste ne laisse une oeuvre vide ; T5 les grants.
-- Staff simule par le JWT du coordenador du seed (11111111-…).
--   Bilan OK : 'OEUVRES-RATTACHEMENT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_staff uuid := '11111111-1111-1111-1111-111111111111';
  v_author bigint; v_w1 bigint; v_w2 bigint; v_w3 bigint; v_b1 bigint; v_b2 bigint; v_b3 bigint;
  v_n int; v_id bigint; v_txt text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships WHERE user_id = v_staff AND status = 'active') THEN
    RAISE EXCEPTION 'OEUVRES-RATTACHEMENT : le coordenador du seed est absent, la suite ne peut pas simuler le staff';
  END IF;

  -- ── Fixtures ──────────────────────────────────────────────────────
  INSERT INTO public.authors (preferred_name) VALUES ('ZZTHOREAU, Henry David') RETURNING id INTO v_author;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id)
  VALUES ('Zzdesobediencia civil', public.fn_normalize_name('Zzdesobediencia civil'), v_author) RETURNING id INTO v_w1;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id)
  VALUES ('Zzdesobediencia civil e outros escritos', public.fn_normalize_name('Zzdesobediencia civil e outros escritos'), v_author) RETURNING id INTO v_w2;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id)
  VALUES ('Zzwalden', public.fn_normalize_name('Zzwalden'), v_author) RETURNING id INTO v_w3;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzdesobediencia civil', 'ZZTHOREAU, Henry David', 'pt-BR', '1987', v_w1) RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzdesobediencia civil e outros escritos', 'ZZTHOREAU, Henry David', 'es', '2009', v_w2) RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzwalden', 'ZZTHOREAU, Henry David', 'pt-BR', '2001', v_w3) RETURNING id INTO v_b3;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 le balayage propose la paire (meme auteur, titre proche), pas Walden';
  BEGIN
    SELECT count(*) INTO v_n FROM public.suggest_split_works(1000) s
     WHERE s.work_id_a = LEAST(v_w1, v_w2) AND s.work_id_b = GREATEST(v_w1, v_w2);
    IF v_n = 1 AND NOT EXISTS (SELECT 1 FROM public.suggest_split_works(1000) s WHERE v_w3 IN (s.work_id_a, s.work_id_b))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : paire trouvee '||v_n||' fois'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 « garder separees » retire la paire du balayage';
  BEGIN
    PERFORM public.mark_works_not_same(v_w2, v_w1, 'test');
    SELECT count(*) INTO v_n FROM public.suggest_split_works(1000) s
     WHERE s.work_id_a = LEAST(v_w1, v_w2) AND s.work_id_b = GREATEST(v_w1, v_w2);
    IF v_n = 0 AND EXISTS (SELECT 1 FROM public.work_not_same WHERE work_id_a = LEAST(v_w1, v_w2) AND work_id_b = GREATEST(v_w1, v_w2))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : paire encore proposee '||v_n||' fois'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 merge_works deplace la notice, supprime la source, oublie la paire';
  BEGIN
    UPDATE public.works SET notes = 'note source' WHERE id = v_w2;
    v_id := public.merge_works(v_w2, v_w1);
    SELECT work_id INTO v_id FROM public.books WHERE id = v_b2;
    SELECT notes INTO v_txt FROM public.works WHERE id = v_w1;
    IF v_id = v_w1
       AND NOT EXISTS (SELECT 1 FROM public.works WHERE id = v_w2)
       AND NOT EXISTS (SELECT 1 FROM public.work_not_same WHERE v_w2 IN (work_id_a, work_id_b))
       AND v_txt = 'note source'
       AND (SELECT count(*) FROM public.work_expressions WHERE work_id = v_w1) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : work_id='||coalesce(v_id::text,'NULL')||' notes='||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 assign_book_to_work ne laisse pas l''oeuvre quittee vide';
  BEGIN
    PERFORM public.assign_book_to_work(v_b3, v_w1);
    IF (SELECT work_id FROM public.books WHERE id = v_b3) = v_w1
       AND NOT EXISTS (SELECT 1 FROM public.works WHERE id = v_w3)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : Walden survit ou la notice n''a pas bouge'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 search_works_for_link trouve l''oeuvre par titre replie';
  BEGIN
    SELECT count(*) INTO v_n FROM public.search_works_for_link('zzdesobediência', 20) s WHERE s.work_id = v_w1 AND s.editions = 3;
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' resultat(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 detach garde l''oeuvre tant qu''une notice y reste, la supprime sinon';
  BEGIN
    PERFORM public.detach_book_from_work(v_b1);
    IF EXISTS (SELECT 1 FROM public.works WHERE id = v_w1)
       AND (SELECT work_id FROM public.books WHERE id = v_b1) IS NULL THEN
      PERFORM public.detach_book_from_work(v_b2);
      PERFORM public.detach_book_from_work(v_b3);
      IF NOT EXISTS (SELECT 1 FROM public.works WHERE id = v_w1) THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : l''oeuvre vide survit'); END IF;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : l''oeuvre a disparu trop tot'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 group_books_as_editions ne laisse pas d''oeuvre vide (defaut du 04/09)';
  BEGIN
    INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzgroup a', 'zzgroup a', v_author) RETURNING id INTO v_w2;
    INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzgroup b', 'zzgroup b', v_author) RETURNING id INTO v_w3;
    UPDATE public.books SET work_id = v_w2 WHERE id = v_b1;
    UPDATE public.books SET work_id = v_w3 WHERE id = v_b2;
    v_id := public.group_books_as_editions(ARRAY[v_b1, v_b2]);
    IF v_id = LEAST(v_w2, v_w3)
       AND NOT EXISTS (SELECT 1 FROM public.works WHERE id = GREATEST(v_w2, v_w3))
       AND (SELECT count(*) FROM public.books WHERE work_id = v_id) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cible='||coalesce(v_id::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  PERFORM set_config('request.jwt.claims', NULL, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 sans staff, merge_works refuse ; anon n''execute rien ; le prune reste interne';
  BEGIN
    v_txt := '';
    BEGIN PERFORM public.merge_works(v_id, v_id + 1); v_txt := '(aucun refus)';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
    IF v_txt ~ 'bibliotec'
       AND NOT has_function_privilege('anon', 'public.merge_works(bigint,bigint)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.suggest_split_works(integer)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_work_prune_if_empty(bigint)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Nettoyage ─────────────────────────────────────────────────────
  DELETE FROM public.books WHERE id IN (v_b1, v_b2, v_b3);
  DELETE FROM public.works WHERE primary_author_id = v_author;
  DELETE FROM public.authors WHERE id = v_author;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'OEUVRES-RATTACHEMENT ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE NOTICE 'OEUVRES-RATTACHEMENT OK : %/%', v_passed, v_passed + v_failed;
END $$;
