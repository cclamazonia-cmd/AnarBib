-- =====================================================================
-- AnarBib — Tests : les tomes vivent dans l'oeuvre (lot 4)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre  ·  decision 6
-- Ref     : 20260904170000 (fn_volume_marker, fn_title_sans_volume, fn_volume_rank,
--           suggest_volume_groups, group_books_as_volumes, dismiss_volume_group,
--           api.catalog_works_v1 : editions triees par tome)
--
-- T1/T2 la lecture des marqueurs ; T3 le balayage trouve les tomes de BTL et de
-- MLEG dans un seul groupe ; T4 « meme oeuvre en plusieurs volumes » pose les
-- numeros et reunit les notices dans une seule oeuvre, les oeuvres quittees
-- disparaissent ; T5 « pas des tomes » retire le groupe ; T6 grants.
--   Bilan OK : 'TOMES-DANS-L-OEUVRE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_staff uuid := '11111111-1111-1111-1111-111111111111';
  v_author bigint; v_w1 bigint; v_w2 bigint; v_w3 bigint; v_b1 bigint; v_b2 bigint; v_b3 bigint; v_b4 bigint; v_b5 bigint;
  v_n int; v_key text; v_id bigint; v_txt text;
BEGIN
  -- ── Fixtures : BTL a mis deux tomes dans une oeuvre, MLEG un tome par oeuvre ; un homonyme sans tome
  INSERT INTO public.authors (preferred_name) VALUES ('ZZMECHOSO, Juan Carlos') RETURNING id INTO v_author;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzaccion directa', 'zzaccion directa', v_author) RETURNING id INTO v_w1;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzaccion directa - Tomo III', 'zzaccion directa tomo iii', v_author) RETURNING id INTO v_w2;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzaccion directa - Tomo IV', 'zzaccion directa tomo iv', v_author) RETURNING id INTO v_w3;
  INSERT INTO public.books (titulo, subtitulo, autor, idioma, ano, work_id) VALUES ('Zzaccion directa anarquista', 'Una historia de FAU: volume 1', 'ZZMECHOSO, Juan Carlos', 'es', '2005', v_w1) RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, subtitulo, autor, idioma, ano, work_id) VALUES ('Zzaccion directa anarquista', 'Una historia de FAU : volume 2', 'ZZMECHOSO, Juan Carlos', 'es', '2006', v_w1) RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzaccion directa anarquista - Tomo III', 'ZZMECHOSO, Juan Carlos', 'es', '2006', v_w2) RETURNING id INTO v_b3;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzaccion directa anarquista - Tomo IV', 'ZZMECHOSO, Juan Carlos', 'es', '2007', v_w3) RETURNING id INTO v_b4;
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
  SELECT b, v_author, 'autor', 1 FROM unnest(ARRAY[v_b1, v_b2, v_b3, v_b4]) b
  ON CONFLICT DO NOTHING;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 le marqueur de tome se lit dans toutes ses formes';
  BEGIN
    IF public.fn_volume_marker('Historia — Tomo III') = 'III'
       AND public.fn_volume_marker('A guerra civil espanhola : volume 2') = '2'
       AND public.fn_volume_marker('Obras, vol. 12') = '12'
       AND public.fn_volume_marker('Cartas, t. IV') = 'IV'
       AND public.fn_volume_marker('Manifesto contra o trabalho') IS NULL
       AND public.fn_volume_marker('Volta ao mundo') IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(public.fn_volume_marker('Historia — Tomo III'),'NULL')||'/'||coalesce(public.fn_volume_marker('Volta ao mundo'),'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 le titre sans tome et le rang (romain ou arabe)';
  BEGIN
    IF public.fn_title_sans_volume('Zzaccion directa anarquista - Tomo III') = public.fn_title_sans_volume('Zzaccion directa anarquista')
       AND public.fn_volume_rank('III') = 3 AND public.fn_volume_rank('iv') = 4 AND public.fn_volume_rank('12') = 12
       AND public.fn_volume_rank('XIV') = 14 AND public.fn_volume_rank('') IS NULL AND public.fn_volume_rank('abc') IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||public.fn_title_sans_volume('Zzaccion directa anarquista - Tomo III')||' | '||coalesce(public.fn_volume_rank('XIV')::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 le balayage reunit les quatre tomes dans un seul groupe, avec leurs numeros devines';
  BEGIN
    SELECT s.group_key INTO v_key FROM public.suggest_volume_groups(1000) s WHERE s.book_id = v_b3;
    SELECT count(*) INTO v_n FROM public.suggest_volume_groups(1000) s WHERE s.group_key = v_key;
    IF v_key IS NOT NULL AND v_n = 4
       AND (SELECT s.volume_guess FROM public.suggest_volume_groups(1000) s WHERE s.book_id = v_b1) = '1'
       AND (SELECT s.volume_guess FROM public.suggest_volume_groups(1000) s WHERE s.book_id = v_b4) = 'IV'
       AND (SELECT s.works FROM public.suggest_volume_groups(1000) s WHERE s.book_id = v_b1) = 3
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cle='||coalesce(v_key,'NULL')||' n='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 « meme oeuvre en plusieurs volumes » sur trois des quatre : numeros poses, une seule oeuvre, les vides supprimees, et le groupe ne revient pas';
  BEGIN
    SELECT s.group_key INTO v_key FROM public.suggest_volume_groups(1000) s WHERE s.book_id = v_b3;
    v_id := public.group_books_as_volumes(jsonb_build_array(
      jsonb_build_object('book_id', v_b1, 'volume', 'I'), jsonb_build_object('book_id', v_b2, 'volume', 'II'),
      jsonb_build_object('book_id', v_b3, 'volume', 'III')));
    IF v_id = v_w1
       AND (SELECT count(DISTINCT work_id) FROM public.books WHERE id IN (v_b1, v_b2, v_b3)) = 1
       AND (SELECT volume FROM public.books WHERE id = v_b3) = 'III'
       AND NOT EXISTS (SELECT 1 FROM public.works WHERE id = v_w2)
       AND EXISTS (SELECT 1 FROM public.works WHERE id = v_w3)
       -- Regle du 04/09 soir : une notice numerotee est reglee ; il ne reste que b4
       -- a decider, seul -> le groupe disparait (vecu : « El Hombre y la Tierra »).
       AND NOT EXISTS (SELECT 1 FROM public.suggest_volume_groups(1000) s WHERE s.group_key = v_key)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : oeuvre='||coalesce(v_id::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 deux notices restant a decider reforment le groupe ; « pas des tomes » le retire';
  BEGIN
    INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzaccion directa anarquista - Tomo V', 'ZZMECHOSO, Juan Carlos', 'es', '2008', v_w3) RETURNING id INTO v_b5;
    INSERT INTO public.book_authors (book_id, author_id, role, ord) VALUES (v_b5, v_author, 'autor', 1) ON CONFLICT DO NOTHING;
    SELECT count(*) INTO v_n FROM public.suggest_volume_groups(1000) s WHERE s.group_key = v_key;
    PERFORM public.dismiss_volume_group(v_key, 'test');
    IF v_n = 2
       AND NOT EXISTS (SELECT 1 FROM public.suggest_volume_groups(1000) s WHERE s.group_key = v_key)
       AND EXISTS (SELECT 1 FROM public.volume_group_dismissals WHERE group_key = v_key)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : n='||v_n||' cle='||coalesce(v_key,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5b deux tomes differents ne sont jamais un doublon, ni une oeuvre scindee';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.suggest_catalog_duplicates(5000) d
                    WHERE (d.book_id_a, d.book_id_b) IN ((v_b3, v_b4), (v_b4, v_b3), (v_b1, v_b2), (v_b2, v_b1)))
       AND NOT EXISTS (SELECT 1 FROM public.suggest_split_works(5000) s
                        WHERE (s.work_id_a, s.work_id_b) IN ((v_w1, v_w3), (v_w3, v_w1)))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  PERFORM set_config('request.jwt.claims', NULL, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 sans staff, refus ; anon n''execute rien et ne lit pas les ecartes';
  BEGIN
    v_txt := '';
    BEGIN PERFORM public.dismiss_volume_group('x', NULL); v_txt := '(aucun refus)';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
    IF v_txt ~ 'bibliotec'
       AND NOT has_function_privilege('anon', 'public.group_books_as_volumes(jsonb)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.suggest_volume_groups(integer)', 'EXECUTE')
       AND NOT has_table_privilege('anon', 'public.volume_group_dismissals', 'SELECT')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Nettoyage ─────────────────────────────────────────────────────
  DELETE FROM public.volume_group_dismissals WHERE group_key = v_key;
  DELETE FROM public.books WHERE id IN (v_b1, v_b2, v_b3, v_b4, v_b5);
  DELETE FROM public.works WHERE primary_author_id = v_author;
  DELETE FROM public.authors WHERE id = v_author;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'TOMES-DANS-L-OEUVRE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE NOTICE 'TOMES-DANS-L-OEUVRE OK : %/%', v_passed, v_passed + v_failed;
END $$;
