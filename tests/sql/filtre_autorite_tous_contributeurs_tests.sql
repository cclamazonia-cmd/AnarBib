-- =====================================================================
-- AnarBib — Tests : les livres d'une autorité, tous ses contributeurs liés
-- Date    : 2026-10-18
-- Ref     : 20261018110623_les_livres_d_une_autorite_tous_ses_contributeurs
--
-- « Élisée Reclus: Geografia » : Reclus en troisième contributeur, après la
-- coordination et l'organisation, et la notice absente de la liste des
-- livres de Reclus — le filtre par autorité ne voyait que le premier lié.
--
-- T1 une notice se trouve par l'autorité d'un contributeur qui n'est pas le
--    premier (l'auteur après la coordination)
-- T2 elle se trouve toujours par son premier contributeur
-- T3 elle ne se trouve pas par une autorité qui ne lui est pas liée
-- T4 les facettes acceptent le même filtre et comptent la notice
--
--   Bilan OK : 'FILTRE-AUTORITE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_lib uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_coord bigint; v_auteur bigint; v_autre bigint; v_b bigint;
  v_res jsonb; v_fac jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = v_lib) THEN
    RAISE EXCEPTION 'FILTRE-AUTORITE : la bibliotheque du seed est absente';
  END IF;
  UPDATE public.libraries SET is_active = true, visibility_level = 'public' WHERE id = v_lib;

  -- ── Fixtures : une notice, coordination en premier, l'auteur ensuite ──
  INSERT INTO public.authors (preferred_name) VALUES ('ZZCOORDFILTRE, Florestan') RETURNING id INTO v_coord;
  INSERT INTO public.authors (preferred_name) VALUES ('ZZAUTEURFILTRE, Elisee') RETURNING id INTO v_auteur;
  INSERT INTO public.authors (preferred_name) VALUES ('ZZAUTREFILTRE, Personne') RETURNING id INTO v_autre;
  INSERT INTO public.books (titulo, autor, idioma, ano)
  VALUES ('Zzfiltreautorite geografia', 'ZZCOORDFILTRE, Florestan ; ZZAUTEURFILTRE, Elisee', 'pt-BR', '1985') RETURNING id INTO v_b;
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary) VALUES
    (v_b, v_coord,  1, 'ZZCOORDFILTRE, Florestan', 'coordenador', false),
    (v_b, v_auteur, 2, 'ZZAUTEURFILTRE, Elisee',   'autor',       true);
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_b, v_lib, true, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  PERFORM set_config('request.jwt.claims', NULL, true);

  v_t := 'T1 trouvee par l''autorite d''un contributeur qui n''est pas le premier';
  BEGIN
    v_res := api.catalog_works_v1(jsonb_build_object('author_id', v_auteur::text), 'titulo.asc', 0, 50, 'pt-BR');
    IF (v_res->'works')::text LIKE '%Zzfiltreautorite geografia%' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : total='||coalesce(v_res->>'total','NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 trouvee par son premier contributeur';
  BEGIN
    v_res := api.catalog_works_v1(jsonb_build_object('author_id', v_coord::text), 'titulo.asc', 0, 50, 'pt-BR');
    IF (v_res->'works')::text LIKE '%Zzfiltreautorite geografia%' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : total='||coalesce(v_res->>'total','NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 pas trouvee par une autorite qui ne lui est pas liee';
  BEGIN
    v_res := api.catalog_works_v1(jsonb_build_object('author_id', v_autre::text), 'titulo.asc', 0, 50, 'pt-BR');
    IF coalesce((v_res->'works')::text, '') NOT LIKE '%Zzfiltreautorite%' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : trouvee a tort'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 les facettes acceptent le filtre et comptent la notice';
  BEGIN
    -- La notice (1985) compte dans la facette des décennies sous le filtre de son auteur ;
    -- sous une autorité sans notice, la facette est vide.
    v_fac := api.catalog_facets_v1(jsonb_build_object('author_id', v_auteur::text));
    IF (v_fac->'decade')::text LIKE '%"1980"%'
       AND jsonb_array_length(coalesce(api.catalog_facets_v1(jsonb_build_object('author_id', v_autre::text))->'decade', '[]'::jsonb)) = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_fac::text,'NULL'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Nettoyage ──
  DELETE FROM public.book_holdings WHERE book_id = v_b;
  DELETE FROM public.book_contributors WHERE book_id = v_b;
  DELETE FROM public.books WHERE id = v_b;
  DELETE FROM public.authors WHERE id IN (v_coord, v_auteur, v_autre);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'FILTRE-AUTORITE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE NOTICE 'FILTRE-AUTORITE OK : %/%', v_passed, v_passed + v_failed;
END $$;
