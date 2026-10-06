-- =====================================================================
-- AnarBib — Tests : le nom que le catalogue affiche est un nom qu'on peut chercher
-- Date    : 2026-10-06
-- Ref     : 20261006194628_le_nom_que_le_catalogue_affiche_se_cherche
--
-- Le cas réel : notice 1432, `autor` = « C.N.T. » (saisie libre), liée à
-- l'autorité « Confederación Nacional del Trabajo » que la ligne du
-- catalogue affiche. « Confederación » dans le champ Auteur·rice ne la
-- trouvait pas : seul `autor` était lu.
--
-- Couvre :
--   T0 la vue rend bien le nom de l'autorité en author_display (prémisse) ;
--   T1 sans compte, le filtre auteur·rice trouve la notice par le nom affiché ;
--   T2 la saisie libre la trouve toujours (« C.N.T. Wqv ») ;
--   T3 le sigle se plie comme dans la recherche libre (« CNT Wqv ») ;
--   T4 tous les mots restent exigés : « Confederación Zzz Wqv » ne trouve rien,
--      et la notice voisine sans autorité ne sort pas ;
--   T5 pour un·e adhérent·e (branche session), même chose qu'en T1 ;
--   T6 la recherche libre (catalog_search_ids_v1) trouve la notice par le nom
--      affiché, sans compte et en session.
--   Bilan OK : 'NOM-AFFICHE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib    constant uuid := '6ea00000-0000-4000-8000-0000000000b1';
  c_membre constant uuid := '6ea00000-0000-4000-8000-000000000001';
  v_cnt bigint; v_voisine bigint; v_author bigint;
  v_n int; v_n2 int; v_txt text; v_json jsonb;
BEGIN
  -- ── Fixtures ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_lib, 'nom-affiche-publique', 'Biblio publique (test nom affiché)', 'public', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', c_membre, 'authenticated', 'authenticated', 'nom.affiche@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (c_membre, 'nom.affiche@anarbib.local', 'Nom', 'Lectrice', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_membre, c_lib, 'reader', 'active');

  -- La notice à saisie libre « C.N.T. Wqv », liée à l'autorité développée ;
  -- une voisine du même éditeur, sans autorité, qui ne doit jamais sortir.
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('A Guerra civil nos documentos Wqv', 'C.N.T. Wqv', 'NAF-1', 'livro', 'Soma', '1999', 'pt')
  RETURNING id INTO v_cnt;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('Outro livro Wqv', 'PEIRATS, José', 'NAF-2', 'livro', 'Soma', '1999', 'pt')
  RETURNING id INTO v_voisine;
  INSERT INTO public.authors (preferred_name, sort_name, authority_type)
  VALUES ('Confederación Nacional del Trabajo Wqv', 'Confederación Nacional del Trabajo Wqv', 'collective')
  RETURNING id INTO v_author;
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  VALUES (v_cnt, v_author, 1, 'C.N.T. Wqv', 'autor', true);
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_cnt, c_lib, true, 1, 1), (v_voisine, c_lib, true, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
  PERFORM set_config('request.jwt.claims', '', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T0 la vue affiche le nom de l''autorité (prémisse)';
  BEGIN
    SELECT author_display INTO v_txt FROM api.catalog_list_anon_v1 WHERE book_id = v_cnt;
    IF v_txt = 'Confederación Nacional del Trabajo Wqv' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : author_display=' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 sans compte, « Confederación Wqv » trouve la notice par le nom affiché';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'Confederación Wqv'), 'relevance', 0, 50, 'fr');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_cnt;
    SELECT count(*) INTO v_n2 FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_voisine;
    IF v_n = 1 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : notice ' || v_n || ', voisine ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la saisie libre la trouve toujours';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'C.N.T. Wqv'), 'relevance', 0, 50, 'fr');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_cnt;
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 le sigle se plie : « CNT Wqv » trouve « C.N.T. Wqv »';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'CNT Wqv'), 'relevance', 0, 50, 'fr');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_cnt;
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 tous les mots restent exigés';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'Confederación Zzz Wqv'), 'relevance', 0, 50, 'fr');
    v_n := jsonb_array_length(v_json->'works');
    IF v_n = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' œuvre(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 pour un·e adhérent·e (branche session), le nom affiché se cherche';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'confederacion wqv'), 'relevance', 0, 50, 'fr');
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_cnt;
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 la recherche libre trouve la notice par le nom affiché (anon et session)';
  BEGIN
    SELECT count(*) INTO v_n FROM api.catalog_search_ids_v1('Confederación Trabajo Wqv') s WHERE s.book_id = v_cnt;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n2 FROM api.catalog_search_ids_v1('confederacion trabajo wqv') s WHERE s.book_id = v_cnt;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_n = 1 AND v_n2 = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : anon ' || v_n || ', session ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'NOM-AFFICHE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'NOM-AFFICHE OK : %/%', v_passed, v_passed;
END $$;
