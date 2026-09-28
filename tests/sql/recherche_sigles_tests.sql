-- =====================================================================
-- AnarBib — Tests : la recherche du catalogue lit les sigles sans leurs points
-- Date    : 2026-09-28
-- Ref     : 20260928174350_la_recherche_du_catalogue_lit_les_sigles_sans_leurs_points
--
-- Le cas réel : les deux éditions d'une même œuvre, l'une écrite
-- « La C.N.T. y la revolución española », l'autre « La CNT en la revolución
-- española », restaient deux lignes au catalogue par œuvre selon la graphie
-- cherchée — chaque terme de la requête doit être une sous-chaîne de la
-- meule, et « c.n.t. » n'en est pas une de « cnt ». Depuis la migration, la
-- meule et chaque terme passent par public.fn_sigle_sans_points.
--
-- Couvre :
--   T1 fn_sigle_sans_points plie un sigle sur ses lettres et laisse une
--      abréviation ordinaire tranquille (table de cas) ;
--   T2 sans compte, « La C.N.T. » trouve les deux éditions ;
--   T3 sans compte, « La CNT » trouve les deux éditions ;
--   T4 sans compte, « C.N.T » (sans point final) trouve les deux, et « cnt »
--      seul aussi ;
--   T5 une graphie qui ne pliait pas déjà ne trouve pas plus qu'avant
--      (« C.N.T.X » ne trouve rien) — le pli n'est pas un joker ;
--   T6 pour un·e adhérent·e (branche session), « c.n.t. » trouve les deux ;
--   T7 le catalogue par œuvre rend UNE ligne à deux éditions pour
--      « La C.N.T. » comme pour « La CNT » — le symptôme du 28/09 ;
--   T8 le classement ne distingue plus les graphies : la similarité d'un
--      titre à points et d'un titre sans points à la même requête est égale.
--   Bilan OK : 'RECHERCHE-SIGLES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib    constant uuid := '51e1e500-0000-4000-8000-0000000000b1';
  c_membre constant uuid := '51e1e500-0000-4000-8000-000000000001';
  v_points bigint; v_sans bigint; v_autre bigint; v_work bigint;
  v_n int; v_n2 int; v_txt text; v_json jsonb; v_r1 real; v_r2 real;
  r record;
BEGIN
  -- ── Fixtures ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_lib, 'sigles-publique', 'Biblio publique (test sigles)', 'public', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', c_membre, 'authenticated', 'authenticated', 'sigles.membre@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (c_membre, 'sigles.membre@anarbib.local', 'Sigles', 'Lectrice', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_membre, c_lib, 'reader', 'active');

  -- Deux éditions de la même œuvre, deux graphies du sigle ; une notice
  -- étrangère au sigle, pour compter ce qui ne doit PAS sortir.
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('La C.N.T. y la revolución española Zqx', 'PEIRATS, José', 'SIG-1', 'livro', 'La Cuchilla', '1988', 'es')
  RETURNING id INTO v_points;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('La CNT en la revolución española Zqx', 'PEIRATS, José', 'SIG-2', 'livro', 'Ruedo ibérico', '1978', 'es')
  RETURNING id INTO v_sans;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('Contra viento y marea Zqx', 'PEIRATS, José', 'SIG-3', 'livro', 'Ruedo ibérico', '1978', 'es')
  RETURNING id INTO v_autre;
  -- Une seule œuvre pour les deux éditions (trg_books_ensure_work en crée une par notice).
  SELECT work_id INTO v_work FROM public.books WHERE id = v_points;
  UPDATE public.books SET work_id = v_work WHERE id = v_sans;
  -- La vue publique (catalog_list_anon_v1) ne rend qu'une notice avec au moins un exemplaire.
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_points, c_lib, true, 1, 1), (v_sans, c_lib, true, 1, 1), (v_autre, c_lib, true, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
  PERFORM set_config('request.jwt.claims', '', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 fn_sigle_sans_points plie un sigle, laisse une abréviation';
  BEGIN
    v_txt := NULL;
    FOR r IN SELECT * FROM (VALUES
        ('la c.n.t. y la revolucion espanola', 'la cnt y la revolucion espanola'),
        ('la cnt en la revolucion espanola',   'la cnt en la revolucion espanola'),
        ('c.n.t',                              'cnt'),
        ('C.N.T.',                             'CNT'),
        ('u.g.t.-c.n.t.',                      'ugt-cnt'),
        ('la f.a.i. et l''a.i.t.',             'la fai et l''ait'),
        ('s.a. de c.v.',                       'sa de cv'),
        ('j. peirats, ed. 2a ed.',             'j. peirats, ed. 2a ed.'),
        ('etc. p.m.',                          'etc. pm'),
        ('c.n.trabajo',                        'cn.trabajo'),
        ('sans point',                         'sans point'),
        ('',                                   '')
      ) AS t(entree, attendu)
    LOOP
      IF public.fn_sigle_sans_points(r.entree) IS DISTINCT FROM r.attendu THEN
        v_txt := coalesce(v_txt || ' ; ', '') || '« ' || r.entree || ' » → « ' || public.fn_sigle_sans_points(r.entree) || ' » (attendu « ' || r.attendu || ' »)';
      END IF;
    END LOOP;
    IF public.fn_sigle_sans_points(NULL) IS NOT NULL THEN v_txt := coalesce(v_txt || ' ; ', '') || 'NULL non conservé'; END IF;
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 sans compte, « La C.N.T. » trouve les deux éditions';
  BEGIN
    SELECT count(*) FILTER (WHERE s.book_id IN (v_points, v_sans)), count(*) FILTER (WHERE s.book_id = v_autre)
      INTO v_n, v_n2 FROM api.catalog_search_ids_v1('La C.N.T. Zqx') s;
    IF v_n = 2 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' des deux, ' || v_n2 || ' intruse'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 sans compte, « La CNT » trouve les deux éditions';
  BEGIN
    SELECT count(*) FILTER (WHERE s.book_id IN (v_points, v_sans)), count(*) FILTER (WHERE s.book_id = v_autre)
      INTO v_n, v_n2 FROM api.catalog_search_ids_v1('La CNT Zqx') s;
    IF v_n = 2 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' des deux, ' || v_n2 || ' intruse'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 « C.N.T » sans point final, et « cnt » seul : les deux éditions';
  BEGIN
    SELECT count(*) INTO v_n  FROM api.catalog_search_ids_v1('C.N.T Zqx') s WHERE s.book_id IN (v_points, v_sans);
    SELECT count(*) INTO v_n2 FROM api.catalog_search_ids_v1('cnt') s WHERE s.book_id IN (v_points, v_sans);
    IF v_n = 2 AND v_n2 = 2 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : C.N.T → ' || v_n || ', cnt → ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 le pli n''est pas un joker : « C.N.T.X Zqx » ne trouve rien';
  BEGIN
    SELECT count(*) INTO v_n FROM api.catalog_search_ids_v1('C.N.T.X Zqx') s;
    IF v_n = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' trouvée(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 pour un·e adhérent·e (branche session), « c.n.t. » trouve les deux';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM api.catalog_search_ids_v1('c.n.t. zqx') s WHERE s.book_id IN (v_points, v_sans);
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_n = 2 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' des deux'); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 le catalogue par œuvre rend UNE ligne à deux éditions, quelle que soit la graphie';
  BEGIN
    v_txt := NULL;
    FOR r IN SELECT unnest(ARRAY['La C.N.T. Zqx', 'La CNT Zqx']) AS q LOOP
      v_json := api.catalog_works_v1(jsonb_build_object('q', r.q), 'relevance', 0, 50, 'fr');
      SELECT count(*), max((g->>'edition_count')::int) INTO v_n, v_n2
        FROM jsonb_array_elements(v_json->'works') g WHERE (g->>'work_id')::bigint = v_work;
      IF v_n <> 1 OR v_n2 <> 2 THEN
        v_txt := coalesce(v_txt || ' ; ', '') || '« ' || r.q || ' » : ' || v_n || ' ligne(s), ' || coalesce(v_n2::text, '∅') || ' édition(s)';
      END IF;
    END LOOP;
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 le classement ne distingue plus les graphies';
  BEGIN
    SELECT max(s.rank) FILTER (WHERE s.book_id = v_points), max(s.rank) FILTER (WHERE s.book_id = v_sans)
      INTO v_r1, v_r2 FROM api.catalog_search_ids_v1('cnt revolución española peirats') s;
    -- Les deux titres ne diffèrent que par « y la » / « en la » : la similarité
    -- des deux à la requête doit être voisine (à 0,1 près), jamais nulle d'un côté.
    IF v_r1 IS NOT NULL AND v_r2 IS NOT NULL AND abs(v_r1 - v_r2) < 0.1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rangs ' || coalesce(v_r1::text, '∅') || ' / ' || coalesce(v_r2::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'RECHERCHE-SIGLES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'RECHERCHE-SIGLES OK : %/%', v_passed, v_passed;
END $$;
