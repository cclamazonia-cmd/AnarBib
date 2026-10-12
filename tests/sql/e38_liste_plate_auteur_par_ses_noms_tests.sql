-- =====================================================================
-- AnarBib — Tests : E38, suite (12/10/2026) — la liste plate filtre
-- l'auteur·rice par ses autres noms, comme la liste par œuvre.
-- Réf : 20261012…_e38_la_liste_plate_filtre_l_auteur_par_ses_autres_noms
--
-- api.catalog_author_ids_v1(nom, approche) est la porte de lecture INVOKER
-- que le client appelle avant de bâtir son filtre PostgREST : elle rend les
-- identifiants d'autorité que private.fn_auteurs_par_nom trouve. Fixtures :
-- une autorité « Piotr Kropotkwq » (alias « Kropotkwqe », variante fr
-- « Pierre Kropotkwqine »), comme dans recherche_variantes_approchee.
--   T1 sous anon, l'alias « kropotkwqe » rend l'identifiant, en exact ;
--   T2 la variante « Pierre Kropotkwqine » aussi ;
--   T3 une lettre de moins (« kropotkq ») ne rend rien en exact, rend
--      l'identifiant en approché ;
--   T4 un nom vide ou nul rend un tableau vide, jamais NULL ;
--   T5 la porte est INVOKER, search_path figé, EXECUTE à anon et
--      authenticated, fermée à PUBLIC — et la vue publique répond au filtre
--      que le client bâtira (author_id ou author_chips).
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'E38-LISTE-PLATE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib constant uuid := '7ab00000-0000-4000-8000-0000000000e3';
  v_livre bigint; v_author bigint; v_ids bigint[]; v_ids2 bigint[]; v_n int; v_b boolean;
BEGIN
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_lib, 'e38-publique', 'Biblio publique (test E38)', 'public', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('La Conquista del pan E38', 'KROPOTKWQ, Piotr', 'E38-1', 'livro', 'Imaginário', '2001', 'es')
  RETURNING id INTO v_livre;
  INSERT INTO public.authors (preferred_name, sort_name, authority_type, variant_forms)
  VALUES ('Piotr Kropotkwq', 'Kropotkwq, Piotr', 'person', '{"fr": ["Pierre Kropotkwqine"], "en": ["Peter Kropotkwq"]}'::jsonb)
  RETURNING id INTO v_author;
  INSERT INTO public.author_name_aliases (author_id, alias_text, alias_norm, match_kind, is_active)
  VALUES (v_author, 'Kropotkwqe', 'kropotkwqe', 'manual', true);
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  VALUES (v_livre, v_author, 1, 'KROPOTKWQ, Piotr', 'autor', true);
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_livre, c_lib, true, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

  -- ───────────────────────────────────────────────────────
  v_t := 'T1 sous anon, l''alias « kropotkwqe » rend l''identifiant, en exact';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    v_ids := api.catalog_author_ids_v1('kropotkwqe', false);
    EXECUTE 'RESET ROLE';
    IF v_ids = ARRAY[v_author]::bigint[] THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T2 la variante « Pierre Kropotkwqine » rend l''identifiant';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    v_ids := api.catalog_author_ids_v1('Pierre Kropotkwqine', false);
    EXECUTE 'RESET ROLE';
    IF v_ids = ARRAY[v_author]::bigint[] THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T3 une lettre de moins (« kropotkq ») : rien en exact, l''identifiant en approché';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    v_ids := api.catalog_author_ids_v1('kropotkq', false);
    v_ids2 := api.catalog_author_ids_v1('kropotkq', true);
    EXECUTE 'RESET ROLE';
    IF coalesce(cardinality(v_ids), 0) = 0 AND v_author = ANY(v_ids2) THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : exact %s, approché %s', coalesce(v_ids::text, 'NULL'), coalesce(v_ids2::text, 'NULL'))); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T4 un nom vide ou nul rend un tableau vide, jamais NULL';
  BEGIN
    IF api.catalog_author_ids_v1('', false) = '{}'::bigint[] AND api.catalog_author_ids_v1('   ', true) = '{}'::bigint[] AND api.catalog_author_ids_v1(NULL, NULL) = '{}'::bigint[] THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(api.catalog_author_ids_v1('', false)::text, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T5 porte INVOKER, search_path figé, anon et authenticated, fermée à PUBLIC ; la vue publique répond au filtre du client';
  BEGIN
    SELECT NOT p.prosecdef AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%')
      INTO v_b FROM pg_proc p WHERE p.oid = 'api.catalog_author_ids_v1(text, boolean)'::regprocedure;
    v_b := v_b AND has_function_privilege('anon', 'api.catalog_author_ids_v1(text, boolean)', 'EXECUTE')
               AND has_function_privilege('authenticated', 'api.catalog_author_ids_v1(text, boolean)', 'EXECUTE')
               AND NOT has_function_privilege('public', 'api.catalog_author_ids_v1(text, boolean)', 'EXECUTE');
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    SELECT count(*) INTO v_n FROM api.catalog_list_anon_v1 c
     WHERE c.author_id = v_author OR c.author_chips @> jsonb_build_array(jsonb_build_object('author_id', v_author));
    EXECUTE 'RESET ROLE';
    IF v_b AND v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : droits %s, vue %s', v_b, v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'E38-LISTE-PLATE ECHEC : %/% tests passés — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'E38-LISTE-PLATE OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
