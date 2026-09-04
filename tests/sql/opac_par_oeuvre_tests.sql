-- =====================================================================
-- AnarBib — Tests : l'OPAC se lit par oeuvre (lot 2)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre
-- Ref     : 20260904130200 (api.catalog_works_v1, api.book_copies_by_library_v1)
--
-- Le regroupement se fait COTE SERVEUR : une oeuvre a cheval sur deux pages
-- n'apparait plus deux fois (T2), le titre suit la locale (T1), les filtres
-- de la liste plate s'appliquent aux editions (T3), le tri se fait au niveau
-- oeuvre (T4). T5 : le second « + », avec la doctrine A1/A2/A3 (rien de plus
-- que le nombre d'exemplaires pour un visiteur non connecte).
-- Les vues du catalogue lisent une vue materialisee : la suite la rafraichit
-- apres avoir pose ses fixtures (livres + detentions dans la biblio du seed).
--   Bilan OK : 'OPAC-PAR-OEUVRE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_staff uuid := '11111111-1111-1111-1111-111111111111';
  v_lib uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_libname text;
  v_author bigint; v_w1 bigint; v_b1 bigint; v_b2 bigint; v_b3 bigint;
  v_res jsonb; v_res2 jsonb; v_n int; v_txt text; v_k1 text; v_k2 text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = v_lib) THEN
    RAISE EXCEPTION 'OPAC-PAR-OEUVRE : la bibliotheque du seed est absente';
  END IF;
  UPDATE public.libraries SET is_active = true, visibility_level = 'public' WHERE id = v_lib;
  SELECT COALESCE(short_name, name, slug) INTO v_libname FROM public.libraries WHERE id = v_lib;

  -- ── Fixtures : une oeuvre a deux editions (pt-BR 2003, es 2010), une notice seule (2005)
  INSERT INTO public.authors (preferred_name) VALUES ('ZZMALATESTA, Errico') RETURNING id INTO v_author;
  INSERT INTO public.works (uniform_title, sort_title, primary_author_id) VALUES ('Zzopacwork anarquia', 'zzopacwork anarquia', v_author) RETURNING id INTO v_w1;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzopacwork anarquia', 'ZZMALATESTA, Errico', 'pt-BR', '2003', v_w1) RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, autor, idioma, ano, work_id) VALUES ('Zzopacwork la anarquía', 'ZZMALATESTA, Errico', 'es', '2010', v_w1) RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, autor, idioma, ano) VALUES ('Zzopacwork sozinho', 'ZZMALATESTA, Errico', 'pt-BR', '2005') RETURNING id INTO v_b3;
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_b1, v_lib, true, 1, 1), (v_b2, v_lib, true, 2, 1), (v_b3, v_lib, false, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  PERFORM set_config('request.jwt.claims', NULL, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 une ligne par oeuvre, titre dans la locale, editions imbriquees';
  BEGIN
    v_res := api.catalog_works_v1('{"q": "zzopacwork"}'::jsonb, 'titulo.asc', 0, 50, 'es');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_res->'works') w WHERE (w->>'work_id')::bigint = v_w1;
    SELECT w->>'display_title' INTO v_txt FROM jsonb_array_elements(v_res->'works') w WHERE (w->>'work_id')::bigint = v_w1;
    IF (v_res->>'total')::int = 2 AND v_n = 1 AND v_txt = 'Zzopacwork la anarquía'
       AND (SELECT (w->>'edition_count')::int FROM jsonb_array_elements(v_res->'works') w WHERE (w->>'work_id')::bigint = v_w1) = 2
       AND (SELECT jsonb_array_length(w->'editions') FROM jsonb_array_elements(v_res->'works') w WHERE (w->>'work_id')::bigint = v_w1) = 2
       AND (SELECT w->'editions'->0->>'book_id' FROM jsonb_array_elements(v_res->'works') w WHERE (w->>'work_id')::bigint = v_w1) = v_b2::text
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : total='||coalesce(v_res->>'total','NULL')||' n='||v_n||' titre='||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la pagination se fait au niveau oeuvre, sans doublon entre pages';
  BEGIN
    v_res  := api.catalog_works_v1('{"q": "zzopacwork"}'::jsonb, 'titulo.asc', 0, 1, 'pt-BR');
    v_res2 := api.catalog_works_v1('{"q": "zzopacwork"}'::jsonb, 'titulo.asc', 1, 1, 'pt-BR');
    v_k1 := v_res->'works'->0->>'key'; v_k2 := v_res2->'works'->0->>'key';
    IF (v_res->>'total')::int = 2 AND jsonb_array_length(v_res->'works') = 1 AND jsonb_array_length(v_res2->'works') = 1
       AND v_k1 IS NOT NULL AND v_k2 IS NOT NULL AND v_k1 <> v_k2
       AND v_res->'works'->0->>'display_title' = 'Zzopacwork anarquia'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : k1='||coalesce(v_k1,'NULL')||' k2='||coalesce(v_k2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 les filtres s''appliquent aux editions (langue, bibliotheque)';
  BEGIN
    v_res  := api.catalog_works_v1('{"q": "zzopacwork", "language": "es"}'::jsonb, 'relevance', 0, 50, 'pt-BR');
    v_res2 := api.catalog_works_v1(jsonb_build_object('q', 'zzopacwork', 'libraries', jsonb_build_array(v_libname)), 'relevance', 0, 50, 'pt-BR');
    IF (v_res->>'total')::int = 1
       AND (v_res->'works'->0->>'edition_count')::int = 1
       AND (v_res2->>'total')::int = 2
       AND (SELECT count(*) FROM api.catalog_works_v1('{"q": "zzopacwork", "libraries": ["Zznulle part"]}'::jsonb) r, jsonb_array_elements(r->'works')) = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : es='||coalesce(v_res->>'total','NULL')||' lib='||coalesce(v_res2->>'total','NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 le tri par annee se fait au niveau oeuvre (annee la plus recente)';
  BEGIN
    v_res := api.catalog_works_v1('{"q": "zzopacwork"}'::jsonb, 'ano.desc', 0, 50, 'pt-BR');
    IF (v_res->'works'->0->>'work_id')::bigint = v_w1 AND (v_res->'works'->0->>'year_max')::int = 2010 AND (v_res->'works'->0->>'year_min')::int = 2003
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : premier='||coalesce(v_res->'works'->0->>'display_title','NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 exemplaires par bibliotheque : rien de plus que le compte pour l''anon, la dispo pour la lectrice';
  BEGIN
    v_res := api.book_copies_by_library_v1(v_b2);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);
    v_res2 := api.book_copies_by_library_v1(v_b2);
    PERFORM set_config('request.jwt.claims', NULL, true);
    IF jsonb_array_length(v_res->'libraries') = 1
       AND (v_res->'libraries'->0->>'exemplares_total')::int = 2
       AND (v_res->'libraries'->0->'available_count') = 'null'::jsonb
       AND (v_res->'libraries'->0->'loanable') = 'null'::jsonb
       AND (v_res2->'libraries'->0->>'available_count')::int = 1
       AND (v_res2->'libraries'->0->>'loanable')::boolean = true
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : anon='||coalesce(v_res::text,'NULL')||' auth='||coalesce(v_res2::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', NULL, true); v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 la page Oeuvre rend le titre affiche et les titres par langue';
  BEGIN
    v_res := api.work_public_detail(v_w1, 'es');
    IF v_res->>'display_title' = 'Zzopacwork la anarquía' AND v_res->'titles'->'pt-BR'->>'source' = 'edition'
       AND jsonb_array_length(v_res->'editions') = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 les deux RPC restent publiques';
  BEGIN
    IF has_function_privilege('anon', 'api.catalog_works_v1(jsonb,text,integer,integer,text)', 'EXECUTE')
       AND has_function_privilege('anon', 'api.book_copies_by_library_v1(bigint)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Nettoyage ─────────────────────────────────────────────────────
  DELETE FROM public.book_holdings WHERE book_id IN (v_b1, v_b2, v_b3);
  DELETE FROM public.books WHERE id IN (v_b1, v_b2, v_b3);
  DELETE FROM public.works WHERE primary_author_id = v_author OR uniform_title LIKE 'Zzopacwork%';
  DELETE FROM public.authors WHERE id = v_author;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'OPAC-PAR-OEUVRE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE NOTICE 'OPAC-PAR-OEUVRE OK : %/%', v_passed, v_passed + v_failed;
END $$;
