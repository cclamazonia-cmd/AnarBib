-- =====================================================================
-- AnarBib — Tests : la recherche lit les autres noms de l'autorité et
-- pardonne une ou deux lettres de travers
-- Date    : 2026-10-11
-- Ref     : 20261011211012_la_recherche_lit_les_variantes_et_pardonne_les_fautes
--
-- Le cas réel : « kropotkin » → 42 œuvres, « kropotkine » → rien, alors que
-- l'autorité porte « Kropotkine » en alias et « Pierre Kropotkine » en
-- variante. Fixtures : une autorité « Piotr Kropotkwq » (alias
-- « Kropotkwqe », variante fr « Pierre Kropotkwqine »), une notice liée
-- dont `autor` = « KROPOTKWQ, Piotr », une voisine sans lien.
--
-- Couvre :
--   T1 l'alias trouve la notice liée (« kropotkwqe »), exact : approx_author faux ;
--   T2 la variante Wikidata la trouve (« Pierre Kropotkwqine ») ;
--   T3 une lettre de moins (« kropotkq ») : repli approché, approx_author vrai ;
--   T4 la saisie exacte ne passe pas en approché (« kropotkwq ») ;
--   T5 un mot de moins de 5 lettres n'est jamais approché (« Wqvx » ≠ « Wqvz ») ;
--   T6 l'approximation n'invente rien (« zzzzzzzz » → 0 œuvre) ;
--   T7 en session, l'alias trouve la notice ;
--   T8 recherche libre : un titre à une lettre près trouve la notice, rang < 0,
--      et catalog_works_v1 répond approx_search ;
--   T9 recherche libre : le nom de l'autorité liée (alias) satisfait le terme,
--      exact (rang ≥ 0) ;
--   T10 fn_mots_proches : 1 lettre de 5 à 7, 2 dès 8, rien en deçà de 5 ;
--   T11 les deux aides vivent dans private, ouvertes à anon, fermées à PUBLIC ;
--   T12 liste plate (api.catalog_author_book_ids_v1) : l'alias trouve la notice, exact ;
--   T13 liste plate : une notice SANS autorité liée sort en approché ; rien d'inventé ;
--   T14 liste plate en session : l'alias trouve la notice.
--   Bilan OK : 'VARIANTES-APPROCHE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib    constant uuid := '7ab00000-0000-4000-8000-0000000000b1';
  c_membre constant uuid := '7ab00000-0000-4000-8000-000000000001';
  v_livre bigint; v_voisine bigint; v_author bigint;
  v_n int; v_n2 int; v_json jsonb; v_rank real;

  -- nombre d'éditions de la notice dans une réponse de catalog_works_v1
  -- (écrit en ligne : pas de fonction de test persistante)
BEGIN
  -- ── Fixtures ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_lib, 'variantes-publique', 'Biblio publique (test variantes)', 'public', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', c_membre, 'authenticated', 'authenticated', 'variantes@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (c_membre, 'variantes@anarbib.local', 'Var', 'Lectrice', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_membre, c_lib, 'reader', 'active');

  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('La Conquista del pan Wqvx', 'KROPOTKWQ, Piotr', 'VAR-1', 'livro', 'Imaginário', '2001', 'es')
  RETURNING id INTO v_livre;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('Outro livro Wqvz', 'RECLUS, Élisée', 'VAR-2', 'livro', 'Imaginário', '2001', 'pt')
  RETURNING id INTO v_voisine;
  INSERT INTO public.authors (preferred_name, sort_name, authority_type, variant_forms)
  VALUES ('Piotr Kropotkwq', 'Kropotkwq, Piotr', 'person',
          '{"fr": ["Pierre Kropotkwqine"], "en": ["Peter Kropotkwq"]}'::jsonb)
  RETURNING id INTO v_author;
  INSERT INTO public.author_name_aliases (author_id, alias_text, alias_norm, match_kind, is_active)
  VALUES (v_author, 'Kropotkwqe', 'kropotkwqe', 'manual', true);
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  VALUES (v_livre, v_author, 1, 'KROPOTKWQ, Piotr', 'autor', true);
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_livre, c_lib, true, 1, 1), (v_voisine, c_lib, true, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
  PERFORM set_config('request.jwt.claims', '', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 l''alias « kropotkwqe » trouve la notice liée, en exact';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'kropotkwqe'), 'relevance', 0, 50, 'fr');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_livre;
    SELECT count(*) INTO v_n2 FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_voisine;
    IF v_n = 1 AND v_n2 = 0 AND (v_json->>'approx_author')::boolean IS FALSE THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : notice ' || v_n || ', voisine ' || v_n2 || ', approx ' || coalesce(v_json->>'approx_author', '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la variante « Pierre Kropotkwqine » trouve la notice';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'Pierre Kropotkwqine'), 'relevance', 0, 50, 'fr');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_livre;
    IF v_n = 1 AND (v_json->>'approx_author')::boolean IS FALSE THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ', approx ' || coalesce(v_json->>'approx_author', '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 une lettre de moins (« kropotkq ») : repli approché';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'kropotkq'), 'relevance', 0, 50, 'fr');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_livre;
    IF v_n = 1 AND (v_json->>'approx_author')::boolean IS TRUE THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ', approx ' || coalesce(v_json->>'approx_author', '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 la saisie exacte reste exacte (« kropotkwq »)';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'kropotkwq'), 'relevance', 0, 50, 'fr');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_livre;
    IF v_n = 1 AND (v_json->>'approx_author')::boolean IS FALSE THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ', approx ' || coalesce(v_json->>'approx_author', '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 un mot de moins de 5 lettres n''est jamais approché';
  BEGIN
    -- « Wqvy » est à une lettre de « Wqvx » et de « Wqvz » : quatre lettres, rien
    SELECT count(*) INTO v_n FROM api.catalog_search_ids_v1('Wqvy') s WHERE s.book_id IN (v_livre, v_voisine);
    IF v_n = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' notice(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 l''approximation n''invente rien';
  BEGIN
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'zzzzqqqqxx'), 'relevance', 0, 50, 'fr');
    v_n := jsonb_array_length(v_json->'works');
    IF v_n = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' œuvre(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 en session, l''alias trouve la notice';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    v_json := api.catalog_works_v1(jsonb_build_object('author', 'Kropotkwqe'), 'relevance', 0, 50, 'fr');
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_livre;
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 recherche libre : « Conqista Wqvx » (une lettre de moins) trouve la notice, approchée';
  BEGIN
    SELECT s.rank INTO v_rank FROM api.catalog_search_ids_v1('Conqista Wqvx') s WHERE s.book_id = v_livre;
    v_json := api.catalog_works_v1(jsonb_build_object('q', 'Conqista Wqvx'), 'relevance', 0, 50, 'fr');
    SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'works') g, jsonb_array_elements(g->'editions') e
     WHERE (e->>'book_id')::bigint = v_livre;
    IF v_rank < 0 AND v_n = 1 AND (v_json->>'approx_search')::boolean IS TRUE THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rang ' || coalesce(v_rank::text, '∅') || ', œuvres ' || v_n || ', approx ' || coalesce(v_json->>'approx_search', '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 recherche libre : l''alias de l''autorité liée satisfait le terme, en exact';
  BEGIN
    SELECT s.rank INTO v_rank FROM api.catalog_search_ids_v1('kropotkwqe conquista') s WHERE s.book_id = v_livre;
    v_json := api.catalog_works_v1(jsonb_build_object('q', 'kropotkwqe conquista'), 'relevance', 0, 50, 'fr');
    IF v_rank >= 0 AND (v_json->>'approx_search')::boolean IS FALSE THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rang ' || coalesce(v_rank::text, '∅') || ', approx ' || coalesce(v_json->>'approx_search', '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 fn_mots_proches : 1 lettre de 5 à 7, 2 dès 8, rien en deçà de 5';
  BEGIN
    IF private.fn_mots_proches('goldmn', 'goldman, emma')                -- 6 lettres, 1 écart
       AND private.fn_mots_proches('goldmnn', 'goldman, emma')           -- 7 lettres, 1 écart
       AND private.fn_mots_proches('malatesa', 'malatesta, errico')      -- 8 lettres, 1 écart
       AND private.fn_mots_proches('malatsa', 'malatesta, errico') IS FALSE -- 7 lettres, 2 écarts
       AND private.fn_mots_proches('kropotkne', 'kropotkin, piotr')       -- 9 lettres, 2 écarts
       AND private.fn_mots_proches('marx', 'mary shelley') IS FALSE       -- 4 lettres : jamais
       AND private.fn_mots_proches('arx', 'karl marx')                    -- sous-chaîne : toujours
    THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : un cas de la table ne tient pas'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 les deux aides : private, ouvertes à anon, fermées à PUBLIC';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'private' AND p.proname IN ('fn_auteurs_par_nom', 'fn_mots_proches')
       AND has_function_privilege('anon', p.oid, 'EXECUTE')
       AND NOT EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0);
    SELECT count(*) INTO v_n2 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('public', 'api') AND p.proname IN ('fn_auteurs_par_nom', 'fn_mots_proches');
    IF v_n = 2 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : private ' || v_n || ', ailleurs ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T12 liste plate : l''alias « kropotkwqe » trouve la notice, en exact';
  BEGIN
    SELECT count(*) FILTER (WHERE book_id = v_livre AND approx IS FALSE), count(*) FILTER (WHERE book_id = v_voisine)
      INTO v_n, v_n2 FROM api.catalog_author_book_ids_v1('kropotkwqe');
    IF v_n = 1 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : notice ' || v_n || ', voisine ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T13 liste plate : la notice sans autorité (« RECLUS, Élisée ») sort en approché pour « Reclos Elisee » ; rien d''inventé';
  BEGIN
    SELECT count(*) FILTER (WHERE book_id = v_voisine AND approx IS TRUE) INTO v_n FROM api.catalog_author_book_ids_v1('Reclos Elisee');
    SELECT count(*) INTO v_n2 FROM api.catalog_author_book_ids_v1('zzzzqqqqxx');
    IF v_n = 1 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : approché ' || v_n || ', invention ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T14 liste plate en session : l''alias trouve la notice';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM api.catalog_author_book_ids_v1('Kropotkwqe') WHERE book_id = v_livre;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'VARIANTES-APPROCHE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'VARIANTES-APPROCHE OK : %/%', v_passed, v_passed;
END $$;
