-- =====================================================================
-- AnarBib — Tests : les recherches empruntent leurs index trigramme (B33)
-- Date    : 2026-09-27  ·  Item B33
-- Ref     : 20260927193314_b33_les_recherches_empruntent_leurs_index_trigramme
--           20260927193315_b33_index_restes_sans_lecteur
--
-- Un index trigramme ne sert que si la requête écrit exactement son
-- expression, avec un OPÉRATEUR qu'il sait servir (LIKE, ILIKE, ~, %), dans
-- un OU dont chaque branche est indexée — et, sur une table sous RLS,
-- seulement dans une fonction SECURITY DEFINER (ces opérateurs ne sont pas
-- leakproof). La preuve ici : parcours séquentiels et parcours d'index complets
-- coupés (enable_seqscan, enable_indexscan, enable_indexonlyscan), il ne reste
-- au planificateur que les parcours bitmap, qui exigent une condition d'index.
-- Le compteur de la transaction (pg_stat_get_xact_numscans) dit si l'index a
-- servi ; une forme qui l'interdit retombe en parcours séquentiel, compteur
-- inchangé (vérifié au banc le 27/09 sur l'ancienne forme).
--
-- Deux pièges des index PARTIELS, vécus au banc le 27/09 : sur une petite
-- table, un index partiel dont le prédicat (is_active) est dans la requête peut
-- être parcouru EN ENTIER, sans condition — c'est souvent le moins cher, et un
-- tel parcours reste un « parcours bitmap ». Pour l'index des alias (lui-même
-- partiel), T1 retire donc les autres index partiels de la table dans la
-- transaction du test (annulée à la fin), et exige que le GIN rende MOINS
-- d'entrées que la table n'a d'alias actifs (pg_stat_get_xact_tuples_returned) :
-- l'ancienne forme le parcourait en entier (201 entrées sur 201), la nouvelle
-- par ses conditions (0).
--
-- Couvre :
--   T1 search_catalog_v1, sans compte, emprunte ses quatre index par leurs
--      conditions : alias, nom préféré, forme de tri, titres de la vue publique ;
--   T2 pour un·e adhérent·e, elle emprunte l'index des titres de la vue réseau ;
--   T3 un jeton porteur de métacaractères ne lève plus d'erreur et se cherche
--      tel quel (« c++ » levait 2201B) ;
--   T4 elle trouve une autorité par sa seule forme de tri (plus de COALESCE) ;
--   T5 search_authors_by_name emprunte ses deux index et trouve par la forme de tri ;
--   T6 elle trouve par proximité (%) même si la session a relevé le seuil ;
--   T7 search_publishers_by_name emprunte son index et trouve par proximité ;
--   T8 la publication trouve l'éditeur par son index (lower(name)).
--   Bilan OK : 'RECHERCHE-TRIGRAMME OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib    constant uuid := 'b33b33b3-0000-4000-8000-0000000000b1';
  c_membre constant uuid := 'b33b33b3-0000-4000-8000-000000000001';
  v_author bigint; v_book bigint; v_book2 bigint; v_pub bigint;
  v_idx text[]; v_avant bigint[]; v_apres bigint[]; v_n int; v_txt text; v_err text;
  v_tup bigint; r record;
BEGIN
  -- ── Fixtures ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_lib, 'b33-publique', 'Biblio publique (test B33)', 'public', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', c_membre, 'authenticated', 'authenticated', 'b33.membre@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (c_membre, 'b33.membre@anarbib.local', 'B33', 'Catalogueuse', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_membre, c_lib, 'librarian', 'active');

  -- Une autorité dont un mot (« zuleikha ») n'est que dans la forme de tri.
  INSERT INTO public.authors (preferred_name, sort_name, authority_type)
  VALUES ('Qwertz Fixturovna', 'Zuleikha, Qwertz', 'person') RETURNING id INTO v_author;
  INSERT INTO public.author_name_aliases (author_id, alias_text, alias_norm, match_kind, is_active)
  VALUES (v_author, 'Qwertz Fixturovna', public.f_normalize_search('Qwertz Fixturovna'), 'manual', true);
  INSERT INTO public.books (titulo, bib_ref, tipo_material, editora)
  VALUES ('Xylofonia libertária B33', 'B33-1', 'livro', 'Outra casa B33') RETURNING id INTO v_book;
  INSERT INTO public.books (titulo, bib_ref, tipo_material)
  VALUES ('Manual c++ b33x', 'B33-2', 'livro') RETURNING id INTO v_book2;
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  VALUES (v_book, v_author, 1, 'Qwertz Fixturovna', 'autor', true);
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, c_lib), (v_book2, c_lib);
  INSERT INTO public.publishers (name) VALUES ('Editora Fixtura B33') RETURNING id INTO v_pub;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

  -- Il ne reste au planificateur que les parcours bitmap.
  PERFORM set_config('enable_seqscan', 'off', true);
  PERFORM set_config('enable_indexscan', 'off', true);
  PERFORM set_config('enable_indexonlyscan', 'off', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 search_catalog_v1 (sans compte) emprunte ses quatre index, par leurs conditions';
  BEGIN
    -- 200 alias actifs qui ne répondent pas à la requête : un parcours sans
    -- condition de l'index des alias les rendrait tous.
    INSERT INTO public.author_name_aliases (author_id, alias_text, alias_norm, match_kind, is_active)
    SELECT v_author, 'B33 remplissage ' || g, 'b33 remplissage ' || md5(g::text), 'manual', true
      FROM generate_series(1, 200) g;
    -- Les index partiels concurrents (uq_author_name_aliases_norm_active,
    -- author_name_aliases_author_id_idx, même prédicat) sortent du jeu le temps
    -- de la transaction du test : il ne reste que le GIN comme chemin d'index.
    FOR r IN SELECT x.indexrelid::regclass AS idx FROM pg_index x
              WHERE x.indrelid = 'public.author_name_aliases'::regclass AND x.indpred IS NOT NULL
                AND x.indexrelid <> 'public.author_name_aliases_alias_norm_trgm_idx'::regclass
    LOOP
      EXECUTE format('DROP INDEX %s', r.idx);
    END LOOP;
    SELECT count(*) INTO v_n FROM public.author_name_aliases WHERE is_active;
    v_idx := ARRAY['public.author_name_aliases_alias_norm_trgm_idx', 'public.authors_preferred_name_norm_trgm_idx',
                   'public.authors_sort_name_norm_trgm_idx', 'public.mv_books_catalog_list_v1_titulo_norm_trgm_idx'];
    SELECT array_agg(pg_stat_get_xact_numscans(i::regclass) ORDER BY o) INTO v_avant FROM unnest(v_idx) WITH ORDINALITY u(i, o);
    v_tup := pg_stat_get_xact_tuples_returned('public.author_name_aliases_alias_norm_trgm_idx'::regclass);
    PERFORM set_config('request.jwt.claims', '', true);
    PERFORM count(*) FROM api.search_catalog_v1('zuleikha xylofonia');
    SELECT array_agg(pg_stat_get_xact_numscans(i::regclass) ORDER BY o) INTO v_apres FROM unnest(v_idx) WITH ORDINALITY u(i, o);
    v_tup := pg_stat_get_xact_tuples_returned('public.author_name_aliases_alias_norm_trgm_idx'::regclass) - v_tup;
    SELECT string_agg(v_idx[k], ', ') INTO v_txt FROM generate_series(1, 4) k WHERE v_apres[k] <= v_avant[k];
    IF v_txt IS NULL AND v_tup < v_n THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : jamais parcouru(s) : ' || coalesce(v_txt, '∅')
      || ' ; index des alias : ' || v_tup || ' entrées rendues pour ' || v_n || ' alias actifs (toutes = parcours sans condition)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 pour un·e adhérent·e, l''index des titres de la vue réseau';
  BEGIN
    v_avant := ARRAY[pg_stat_get_xact_numscans('public.mv_books_catalog_list_network_v1_titulo_norm_trgm_idx'::regclass)];
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    PERFORM count(*) FROM api.search_catalog_v1('xylofonia');
    PERFORM set_config('request.jwt.claims', '', true);
    IF pg_stat_get_xact_numscans('public.mv_books_catalog_list_network_v1_titulo_norm_trgm_idx'::regclass) > v_avant[1] THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : index jamais parcouru'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  PERFORM set_config('enable_seqscan', 'on', true);
  PERFORM set_config('enable_indexscan', 'on', true);
  PERFORM set_config('enable_indexonlyscan', 'on', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 les métacaractères ne lèvent plus d''erreur et se cherchent tels quels';
  BEGIN
    v_txt := NULL;
    FOR v_err IN SELECT unnest(ARRAY['c++ b33x', '[xylo', 'xylofonia (b33', 'zuleikha|qwertz', '.*.* b33', 'xylo\fonia', '{2} ^b33$'])
    LOOP
      BEGIN
        PERFORM count(*) FROM api.search_catalog_v1(v_err);
      EXCEPTION WHEN OTHERS THEN v_txt := coalesce(v_txt || ' ; ', '') || v_err || ' → ' || SQLSTATE;
      END;
    END LOOP;
    SELECT count(*) INTO v_n FROM api.search_catalog_v1('c++ b33x') s WHERE s.kind = 'book' AND s.id = v_book2;
    IF v_txt IS NULL AND v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : erreurs=' || coalesce(v_txt, '∅') || ' ; « c++ b33x » trouvée ' || v_n || ' fois'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 search_catalog_v1 trouve une autorité par sa seule forme de tri';
  BEGIN
    SELECT count(*) INTO v_n FROM api.search_catalog_v1('zuleikha') s WHERE s.kind = 'author' AND s.id = v_author;
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : trouvée ' || v_n || ' fois'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  PERFORM set_config('enable_seqscan', 'off', true);
  PERFORM set_config('enable_indexscan', 'off', true);
  PERFORM set_config('enable_indexonlyscan', 'off', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 search_authors_by_name emprunte ses deux index et trouve par la forme de tri';
  BEGIN
    v_idx := ARRAY['public.authors_fn_normalize_name_trgm_idx', 'public.authors_sort_name_fn_normalize_name_trgm_idx'];
    SELECT array_agg(pg_stat_get_xact_numscans(i::regclass) ORDER BY o) INTO v_avant FROM unnest(v_idx) WITH ORDINALITY u(i, o);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM public.search_authors_by_name('zuleikha') s WHERE s.id = v_author;
    SELECT array_agg(pg_stat_get_xact_numscans(i::regclass) ORDER BY o) INTO v_apres FROM unnest(v_idx) WITH ORDINALITY u(i, o);
    SELECT string_agg(v_idx[k], ', ') INTO v_txt FROM generate_series(1, 2) k WHERE v_apres[k] <= v_avant[k];
    IF v_n = 1 AND v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : trouvée ' || v_n || ' fois ; jamais parcouru(s) : ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 search_authors_by_name trouve par proximité même si la session a relevé le seuil';
  BEGIN
    PERFORM set_config('pg_trgm.similarity_threshold', '0.9', true);
    -- « zuleika » : ni préfixe ni sous-chaîne de « qwertz zuleikha », similarité 0,33.
    SELECT count(*) INTO v_n FROM public.search_authors_by_name('zuleika') s WHERE s.id = v_author AND s.match_kind = 'approx';
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : trouvée ' || v_n || ' fois'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 search_publishers_by_name emprunte son index et trouve par proximité';
  BEGIN
    v_avant := ARRAY[pg_stat_get_xact_numscans('public.publishers_fn_normalize_name_trgm_idx'::regclass)];
    SELECT count(*) INTO v_n FROM public.search_publishers_by_name('editora fixtora b33') s WHERE s.id = v_pub;
    IF v_n = 1 AND pg_stat_get_xact_numscans('public.publishers_fn_normalize_name_trgm_idx'::regclass) > v_avant[1] THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : trouvé ' || v_n || ' fois ; parcours '
      || pg_stat_get_xact_numscans('public.publishers_fn_normalize_name_trgm_idx'::regclass) || ' (avant ' || v_avant[1] || ')'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  PERFORM set_config('request.jwt.claims', '', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 la publication trouve l''éditeur par son index';
  BEGIN
    v_avant := ARRAY[pg_stat_get_xact_numscans('public.publishers_lower_name_idx'::regclass)];
    UPDATE public.books SET editora = '  EDITORA fixtura b33 ' WHERE id = v_book;
    IF (SELECT publisher_id FROM public.books WHERE id = v_book) = v_pub
       AND pg_stat_get_xact_numscans('public.publishers_lower_name_idx'::regclass) > v_avant[1] THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : publisher_id='
      || coalesce((SELECT publisher_id FROM public.books WHERE id = v_book)::text, 'NULL') || ' ; parcours '
      || pg_stat_get_xact_numscans('public.publishers_lower_name_idx'::regclass) || ' (avant ' || v_avant[1] || ')'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'RECHERCHE-TRIGRAMME ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'RECHERCHE-TRIGRAMME OK : %/%', v_passed, v_passed;
END $$;
