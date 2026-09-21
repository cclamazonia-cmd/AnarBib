-- =====================================================================
-- AnarBib — Tests : le catalogue par oeuvre repond au visiteur anonyme
-- Date    : 2026-09-21  ·  item B27
-- Ref     : 20260921111344 (api.catalog_works_v1, recrite sans changer son resultat)
--
-- Le 20/09, treize appels anonymes sur treize finissaient en 57014 : la RPC
-- depassait les 3 s du role anon et le front retombait en silence sur la
-- liste a plat. Deux couts, mesures en production le 21/09 : une sous-requete
-- correlee qui relisait tout le catalogue pour CHAQUE groupe de la page
-- (4,4 Go de fichiers temporaires pour 50 oeuvres, 70 Go pour 200), et
-- fn_work_display_title appelee une fois par oeuvre du catalogue (1,3 s).
--
-- Un banc ne mesure pas un temps : il garde ce qui rendait la requete lente,
-- et ce que la recriture ne devait pas changer.
--   T1  le corps ne porte plus les trois motifs couteux ;
--   T2  la requete reste dynamique, une seule vue nommee a la fois (sinon
--       42501 pour anon : les droits se verifient a la planification) ;
--   T3  le titre affiche suit EXACTEMENT la cascade de fn_work_display_title,
--       dans ses trois branches : work_titles, edition dans la langue,
--       titre uniforme ;
--   T4  les bibliotheques d'une oeuvre : une fois chacune, deux editions ou non ;
--   T5  les editions de la page portent la ligne entiere de la vue, plus
--       _pos et volume ;
--   T6  une notice sans oeuvre garde son propre titre et sa cle negative ;
--   T7  un visiteur anonyme obtient la meme page qu'avant, sous son role.
--   Bilan OK : 'CATALOGUE-PAR-OEUVRE-COUT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_lib uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_libname text;
  v_src text;
  v_author bigint; v_w1 bigint; v_w2 bigint; v_b1 bigint; v_b2 bigint; v_b3 bigint; v_b4 bigint; v_w4 bigint;
  v_res jsonb; v_w jsonb; v_n int; v_txt text; v_ref text; v_lang text; v_ecarts text := '';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = v_lib) THEN
    RAISE EXCEPTION 'CATALOGUE-PAR-OEUVRE-COUT : la bibliotheque du seed est absente';
  END IF;
  UPDATE public.libraries SET is_active = true, visibility_level = 'public' WHERE id = v_lib;
  SELECT COALESCE(short_name, name, slug) INTO v_libname FROM public.libraries WHERE id = v_lib;

  -- ── Fixtures ──────────────────────────────────────────────────────
  -- w1 : deux editions (pt-BR 2003, es 2010) ; w2 : une edition (fr 1999) ; b4 : notice sans oeuvre.
  INSERT INTO public.authors (preferred_name) VALUES ('ZZCOUT, Louise') RETURNING id INTO v_author;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzcoutwork titre uniforme', 'zzcoutwork titre uniforme', v_author) RETURNING id INTO v_w1;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzcoutwork second uniforme', 'zzcoutwork second uniforme', v_author) RETURNING id INTO v_w2;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzcoutwork a comuna', 'ZZCOUT, Louise', 'pt-BR', '2003', v_w1) RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzcoutwork la comuna', 'ZZCOUT, Louise', 'es', '2010', v_w1) RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzcoutwork la commune', 'ZZCOUT, Louise', 'fr', '1999', v_w2) RETURNING id INTO v_b3;
  INSERT INTO public.books (titulo, autor, idioma, ano) VALUES ('Zzcoutwork orpheline', 'ZZCOUT, Louise', 'pt-BR', '2005') RETURNING id INTO v_b4;
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_b1, v_lib, true, 1, 1), (v_b2, v_lib, true, 2, 1), (v_b3, v_lib, true, 1, 1), (v_b4, v_lib, false, 1, 1);
  -- trg_books_ensure_work (BEFORE INSERT) donne une oeuvre a toute notice : en production aucune
  -- n'en est privee. La branche « sans oeuvre » de la RPC est defensive ; on la met a l'epreuve en
  -- retirant l'oeuvre APRES l'insertion (le declencheur ne joue pas a la mise a jour).
  SELECT work_id INTO v_w4 FROM public.books WHERE id = v_b4;
  UPDATE public.books SET work_id = NULL WHERE id = v_b4;
  IF (SELECT work_id FROM public.books WHERE id = v_b4) IS NOT NULL THEN
    RAISE EXCEPTION 'CATALOGUE-PAR-OEUVRE-COUT : la fixture sans oeuvre n''a pas pu etre posee';
  END IF;

  -- Les trois branches de la cascade, posees expres (un declencheur seme work_titles
  -- a l'insertion d'une edition : on repart d'une table connue).
  DELETE FROM public.work_titles WHERE work_id IN (v_w1, v_w2);
  INSERT INTO public.work_titles (work_id, lang, title, source) VALUES (v_w1, 'fr', 'Zzcoutwork la Commune (titre pose)', 'manual');
  --   w1 en fr    : branche 1, work_titles
  --   w1 en es    : branche 2, l'edition espagnole (aucune ligne work_titles en es)
  --   w1 en de    : branche 3, le titre uniforme (ni work_titles ni edition allemande)
  --   w2 en fr    : branche 2, l'edition francaise
  --   w2 en pt-BR : branche 3, le titre uniforme

  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  PERFORM set_config('request.jwt.claims', NULL, true);

  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 le corps ne porte plus les trois motifs couteux';
  BEGIN
    IF v_src IS NOT NULL
       AND position('fn_work_display_title(' IN v_src) = 0   -- un appel par oeuvre du catalogue
       AND position('row_json' IN v_src) = 0                 -- la ligne entiere trainee dans tout le catalogue
       AND v_src !~ 'FROM\s+filtered\s+f2'                   -- le balayage de filtered par groupe de la page
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la requete reste dynamique : une seule vue nommee a la fois';
  BEGIN
    IF position('EXECUTE v_sql' IN v_src) > 0
       AND position('__VIEW__' IN v_src) > 0
       -- les deux noms de vue n'apparaissent QUE dans le CASE qui choisit, jamais dans la requete
       AND (length(v_src) - length(replace(v_src, 'api.catalog_list_anon_v1', ''))) / length('api.catalog_list_anon_v1') = 1
       AND (length(v_src) - length(replace(v_src, 'api.catalog_list_session_v1', ''))) / length('api.catalog_list_session_v1') = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 le titre affiche suit la cascade de fn_work_display_title, dans ses trois branches';
  BEGIN
    v_n := 0;
    FOREACH v_lang IN ARRAY ARRAY['fr', 'es', 'de', 'pt-BR'] LOOP
      v_res := api.catalog_works_v1('{"q": "zzcoutwork"}'::jsonb, 'titulo.asc', 0, 50, v_lang);
      FOR v_w IN SELECT w FROM jsonb_array_elements(v_res->'works') w WHERE w->>'work_id' IS NOT NULL LOOP
        v_ref := public.fn_work_display_title((v_w->>'work_id')::bigint, v_lang);
        v_n := v_n + 1;
        IF (v_w->>'display_title') IS DISTINCT FROM v_ref THEN
          v_ecarts := v_ecarts || format(' [%s oeuvre %s : « %s » au lieu de « %s »]', v_lang, v_w->>'work_id', v_w->>'display_title', v_ref);
        END IF;
      END LOOP;
    END LOOP;
    -- les valeurs attendues, dites en clair : le test ne se contente pas de comparer deux calculs
    SELECT w->>'display_title' INTO v_txt FROM jsonb_array_elements(api.catalog_works_v1('{"q": "zzcoutwork"}'::jsonb, 'titulo.asc', 0, 50, 'fr')->'works') w WHERE (w->>'work_id')::bigint = v_w1;
    IF v_txt IS DISTINCT FROM 'Zzcoutwork la Commune (titre pose)' THEN v_ecarts := v_ecarts || ' [branche 1 : ' || coalesce(v_txt, 'NULL') || ']'; END IF;
    SELECT w->>'display_title' INTO v_txt FROM jsonb_array_elements(api.catalog_works_v1('{"q": "zzcoutwork"}'::jsonb, 'titulo.asc', 0, 50, 'es')->'works') w WHERE (w->>'work_id')::bigint = v_w1;
    IF v_txt IS DISTINCT FROM 'Zzcoutwork la comuna' THEN v_ecarts := v_ecarts || ' [branche 2 : ' || coalesce(v_txt, 'NULL') || ']'; END IF;
    SELECT w->>'display_title' INTO v_txt FROM jsonb_array_elements(api.catalog_works_v1('{"q": "zzcoutwork"}'::jsonb, 'titulo.asc', 0, 50, 'de')->'works') w WHERE (w->>'work_id')::bigint = v_w1;
    IF v_txt IS DISTINCT FROM 'Zzcoutwork titre uniforme' THEN v_ecarts := v_ecarts || ' [branche 3 : ' || coalesce(v_txt, 'NULL') || ']'; END IF;

    IF v_n = 8 AND v_ecarts = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' comparaisons (8 attendues)'||v_ecarts); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 les bibliotheques d''une oeuvre : une fois chacune, deux editions ou non';
  BEGIN
    v_res := api.catalog_works_v1('{"q": "zzcoutwork"}'::jsonb, 'titulo.asc', 0, 50, 'pt-BR');
    IF (SELECT w->'library_names' FROM jsonb_array_elements(v_res->'works') w WHERE (w->>'work_id')::bigint = v_w1) = jsonb_build_array(v_libname)
       AND (SELECT w->'library_names' FROM jsonb_array_elements(v_res->'works') w WHERE (w->>'work_id')::bigint = v_w2) = jsonb_build_array(v_libname)
       AND (SELECT w->'library_names' FROM jsonb_array_elements(v_res->'works') w WHERE w->>'work_id' IS NULL AND w->>'rep_book_id' = v_b4::text) = jsonb_build_array(v_libname)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((SELECT string_agg(w->>'library_names', ' / ') FROM jsonb_array_elements(v_res->'works') w), 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 les editions de la page portent la ligne entiere de la vue, plus _pos et volume';
  BEGIN
    v_res := api.catalog_works_v1('{"q": "zzcoutwork"}'::jsonb, 'titulo.asc', 0, 50, 'pt-BR');
    SELECT w INTO v_w FROM jsonb_array_elements(v_res->'works') w WHERE (w->>'work_id')::bigint = v_w1;
    -- chaque cle de la vue anonyme se retrouve dans l'edition : rien n'a ete perdu en ne relisant que la page
    SELECT count(*) INTO v_n
      FROM (SELECT jsonb_object_keys(to_jsonb(c)) k FROM api.catalog_list_anon_v1 c WHERE c.book_id = v_b2) ks
     WHERE NOT (v_w->'editions'->0) ? ks.k;
    IF jsonb_array_length(v_w->'editions') = 2
       AND (v_w->'editions'->0->>'book_id') = v_b2::text           -- la plus recente d'abord (2010)
       AND (v_w->'editions'->1->>'book_id') = v_b1::text
       AND (v_w->'editions'->0) ? '_pos' AND (v_w->'editions'->0) ? 'volume'
       AND (v_w->'editions'->0->>'titulo') = 'Zzcoutwork la comuna'
       AND v_n = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cles de la vue absentes de l''edition = '||v_n||' ; editions = '||coalesce(jsonb_array_length(v_w->'editions')::text, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 une notice sans oeuvre garde son propre titre et sa cle negative';
  BEGIN
    v_res := api.catalog_works_v1('{"q": "zzcoutwork"}'::jsonb, 'titulo.asc', 0, 50, 'fr');
    SELECT w INTO v_w FROM jsonb_array_elements(v_res->'works') w WHERE w->>'rep_book_id' = v_b4::text;
    IF (v_res->>'total')::int = 3
       AND v_w->>'work_id' IS NULL
       AND (v_w->>'key')::bigint = -v_b4
       AND v_w->>'display_title' = 'Zzcoutwork orpheline'
       AND (v_w->>'edition_count')::int = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : total='||coalesce(v_res->>'total','NULL')||' titre='||coalesce(v_w->>'display_title','NULL')||' cle='||coalesce(v_w->>'key','NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 un visiteur anonyme obtient la page, sous son role';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    v_res := api.catalog_works_v1('{"q": "zzcoutwork"}'::jsonb, 'titulo.asc', 0, 50, 'fr');
    EXECUTE 'RESET ROLE';
    IF (v_res->>'total')::int = 3 AND jsonb_array_length(v_res->'works') = 3
       -- sans session, aucune oeuvre n'est « disponible dans ta bibliotheque »
       AND (SELECT bool_and((w->>'session_available') IS DISTINCT FROM 'true') FROM jsonb_array_elements(v_res->'works') w)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : total='||coalesce(v_res->>'total','NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── Nettoyage ─────────────────────────────────────────────────────
  DELETE FROM public.book_holdings WHERE book_id IN (v_b1, v_b2, v_b3, v_b4);
  DELETE FROM public.books WHERE id IN (v_b1, v_b2, v_b3, v_b4);
  DELETE FROM public.works WHERE id IN (v_w1, v_w2, v_w4);
  DELETE FROM public.authors WHERE id = v_author;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CATALOGUE-PAR-OEUVRE-COUT ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE NOTICE 'CATALOGUE-PAR-OEUVRE-COUT OK : %/%', v_passed, v_passed + v_failed;
END $$;
