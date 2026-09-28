-- =====================================================================
-- AnarBib — Tests : le catalogue tient la grande échelle (B32)
-- Date    : 2026-09-27  ·  Item B32
-- Ref     : 20260928122316_b32_la_visibilite_par_bibliotheque_se_calcule_une_fois_par_requete.sql
--           20260928122317_b32_le_catalogue_lit_ses_vues_materialisees_sans_barriere.sql
--           20260928122318_b32_fn_locale_from_idioma_s_insere_en_ligne.sql
--
-- Deux mécanismes faisaient croître le coût d'une page avec le catalogue :
-- la visibilité par bibliothèque, calculée par une fonction DEFINER pour
-- chaque ligne lue (21 policies), et la lecture des vues matérialisées à
-- travers des fonctions DEFINER que PostgreSQL n'insère jamais en ligne.
--
-- Couvre :
--   T1 aucune policy n'appelle plus fn_library_visible_to_caller ligne à ligne ;
--      celles qui en dépendent lisent fn_visible_library_ids() ;
--   T2 fn_visible_library_ids() rend exactement les bibliothèques que
--      fn_library_visible_to_caller déclare visibles, pour cinq identités
--      (anonyme, lectrice d'une bibliothèque privée, membre du réseau,
--      compte sans adhésion, coordination) ;
--   T3 sous anon, le plan de `count(*)` sur books calcule l'ensemble une fois
--      (InitPlan) et n'appelle pas fn_library_visible_to_caller ;
--   T4 la liste du catalogue lit la vue matérialisée elle-même (plus de
--      parcours de fonction) : son index des titres sert un tri LIMIT ;
--   T5 work_id et l'éditeur affiché sont ceux qu'écrivaient les deux fonctions
--      retirées (livre, disque, film) ;
--   T6 la vue du réseau reste fermée à anon ; la liste de session ne montre à
--      un compte sans adhésion que les notices tenues par une bibliothèque
--      publique, et tout le réseau à un·e membre ;
--   T7 catalog_works_v1 assemble son WHERE à partir des filtres présents (plus
--      de « p.x IS NULL OR … »), lit volume par la vue et matérialise titres ;
--   T8 les filtres rendent ce qu'ils rendaient : matériel, initiale, éditeur,
--      langue, année (exclusion), combinés — sur les notices du test ;
--   T9 les tris et la pagination : total constant, pages disjointes, tri par
--      auteur·rice respecté.
--   Bilan OK : 'CATALOGUE-ECHELLE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_pub    constant uuid := 'b32b32b3-0000-4000-8000-0000000000c1';
  c_rede   constant uuid := 'b32b32b3-0000-4000-8000-0000000000c2';
  c_priv   constant uuid := 'b32b32b3-0000-4000-8000-0000000000c3';
  c_lect   constant uuid := 'b32b32b3-0000-4000-8000-000000000011';  -- lectrice de la privée
  c_membre constant uuid := 'b32b32b3-0000-4000-8000-000000000012';  -- membre du réseau (lectrice de la publique)
  c_sans   constant uuid := 'b32b32b3-0000-4000-8000-000000000013';  -- compte sans adhésion
  c_coord  constant uuid := 'b32b32b3-0000-4000-8000-000000000014';  -- coordination de la réseau
  v_livre bigint; v_disque bigint; v_film bigint; v_rede_seul bigint;
  v_n int; v_txt text; v_plan text; r record; v_ids uuid[]; v_attendu uuid[];
BEGIN
  -- ── Fixtures ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_pub,  'b32-publica', 'Biblio publique (test B32)', 'public',  'network_published', 'federated', true),
         (c_rede, 'b32-rede',    'Biblio réseau (test B32)',   'network', 'network_published', 'federated', true),
         (c_priv, 'b32-privada', 'Biblio privée (test B32)',   'private', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  FOR r IN SELECT * FROM (VALUES (c_lect, 'lectrice'), (c_membre, 'membre'), (c_sans, 'sans'), (c_coord, 'coord')) x(id, nom) LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', r.id, 'authenticated', 'authenticated', 'b32.' || r.nom || '@anarbib.local',
            now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
    VALUES (r.id, 'b32.' || r.nom || '@anarbib.local', 'B32', r.nom, 'fr') ON CONFLICT (id) DO NOTHING;
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_lect, c_priv, 'reader', 'active'), (c_membre, c_pub, 'reader', 'active'), (c_coord, c_rede, 'coordenador', 'active');

  -- (l'initiale du filtre « alpha » est celle de l'auteur·rice, pas du titre : Ferreira → F)
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora) VALUES ('Livro B32', 'Lima, B32', 'B32-1', 'livro', 'Editora B32') RETURNING id INTO v_livre;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, gravadora) VALUES ('Disco B32', 'Dias, B32', 'B32-2', 'audio', 'Editora B32', 'Gravadora B32') RETURNING id INTO v_disque;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, distribuidora) VALUES ('Filme B32', 'Ferreira, B32', 'B32-3', 'audiovisual', NULL, 'Distribuidora B32') RETURNING id INTO v_film;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Só na rede B32', 'B32-4', 'livro') RETURNING id INTO v_rede_seul;
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_livre, c_pub, true, 1, 1), (v_disque, c_pub, true, 1, 1), (v_film, c_pub, true, 1, 1), (v_rede_seul, c_rede, true, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 aucune policy n''appelle fn_library_visible_to_caller ; 21 lisent fn_visible_library_ids()';
  SELECT count(*) INTO v_n FROM pg_policy pol
   WHERE coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') ~ 'fn_library_visible_to_caller';
  SELECT string_agg(pol.polrelid::regclass::text || '.' || pol.polname, ', ') INTO v_txt FROM pg_policy pol
   WHERE coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') ~ 'fn_library_visible_to_caller';
  IF v_n = 0 AND (SELECT count(*) FROM pg_policy pol WHERE pg_get_expr(pol.polqual, pol.polrelid) ~ 'fn_visible_library_ids') >= 21 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : encore ligne à ligne : ' || coalesce(v_txt, '∅')); END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 fn_visible_library_ids() = ce que fn_library_visible_to_caller déclare visible, pour cinq identités';
  BEGIN
    v_txt := NULL;
    FOR r IN SELECT * FROM (VALUES ('anon', ''), ('lectrice', json_build_object('sub', c_lect, 'role', 'authenticated')::text),
                                   ('membre', json_build_object('sub', c_membre, 'role', 'authenticated')::text),
                                   ('sans', json_build_object('sub', c_sans, 'role', 'authenticated')::text),
                                   ('coord', json_build_object('sub', c_coord, 'role', 'authenticated')::text)) x(nom, claims)
    LOOP
      PERFORM set_config('request.jwt.claims', r.claims, true);
      v_ids := public.fn_visible_library_ids();
      SELECT coalesce(array_agg(l.id ORDER BY l.id), '{}') INTO v_attendu FROM public.libraries l WHERE public.fn_library_visible_to_caller(l.id);
      IF v_ids IS DISTINCT FROM v_attendu THEN v_txt := coalesce(v_txt || ' ; ', '') || r.nom; END IF;
      -- et le sens attendu sur nos trois bibliothèques
      IF (c_pub = ANY (v_ids)) IS DISTINCT FROM true
         OR (c_rede = ANY (v_ids)) IS DISTINCT FROM (r.nom IN ('lectrice', 'membre', 'coord'))
         OR (c_priv = ANY (v_ids)) IS DISTINCT FROM (r.nom = 'lectrice') THEN
        v_txt := coalesce(v_txt || ' ; ', '') || r.nom || ' (sens)';
      END IF;
    END LOOP;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : divergent pour ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 sous anon, count(*) sur books calcule l''ensemble une fois (InitPlan)';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    v_plan := NULL;
    SET LOCAL ROLE anon;
    FOR r IN EXECUTE 'EXPLAIN (VERBOSE, FORMAT TEXT) SELECT count(*) FROM public.books' LOOP
      v_plan := coalesce(v_plan || E'\n', '') || r."QUERY PLAN";
    END LOOP;
    RESET ROLE;
    IF v_plan ~ 'InitPlan' AND v_plan ~ 'fn_visible_library_ids' AND v_plan !~ 'fn_library_visible_to_caller' THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || left(v_plan, 400)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 la liste du catalogue lit la vue matérialisée elle-même, son index des titres sert un tri LIMIT';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    PERFORM set_config('enable_seqscan', 'off', true);
    PERFORM set_config('enable_sort', 'off', true);
    v_plan := NULL;
    SET LOCAL ROLE anon;
    FOR r IN EXECUTE 'EXPLAIN (FORMAT TEXT) SELECT book_id, titulo FROM api.catalog_list_anon_v1 ORDER BY titulo LIMIT 5' LOOP
      v_plan := coalesce(v_plan || E'\n', '') || r."QUERY PLAN";
    END LOOP;
    RESET ROLE;
    PERFORM set_config('enable_seqscan', 'on', true);
    PERFORM set_config('enable_sort', 'on', true);
    IF v_plan ~ 'mv_books_catalog_list_v1_titulo_idx' AND v_plan !~ 'Function Scan' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || left(v_plan, 400)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 work_id et éditeur affiché : ceux des fonctions retirées (livre, disque, film)';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    SET LOCAL ROLE anon;
    SELECT string_agg(c.titulo || '=' || coalesce(c.publisher_display, '∅') || '/' || (c.work_id IS NOT NULL)::text, ' ; ' ORDER BY c.titulo)
      INTO v_txt FROM api.catalog_list_anon_v1 c WHERE c.book_id IN (v_livre, v_disque, v_film);
    RESET ROLE;
    IF v_txt = 'Disco B32=Gravadora B32/true ; Filme B32=Distribuidora B32/true ; Livro B32=Editora B32/true'
       AND NOT EXISTS (SELECT 1 FROM api.catalog_list_anon_v1 c JOIN public.books b ON b.id = c.book_id
                        WHERE c.book_id IN (v_livre, v_disque, v_film) AND c.work_id IS DISTINCT FROM b.work_id) THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 la vue réseau reste fermée à anon ; la liste de session filtre comme avant';
  BEGIN
    IF has_table_privilege('anon', 'private.catalog_network_rows', 'SELECT') THEN
      RAISE EXCEPTION 'private.catalog_network_rows lisible par anon';
    END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_sans, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    SELECT count(*) INTO v_n FROM api.catalog_list_session_v1 WHERE book_id = v_rede_seul;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    SELECT v_n * 10 + count(*) INTO v_n FROM api.catalog_list_session_v1 WHERE book_id = v_rede_seul;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_n = 1 THEN v_passed := v_passed + 1;   -- 0 pour le compte sans adhésion, 1 pour la membre
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : sans adhésion×10 + membre = ' || v_n || ' (1 attendu)'); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 catalog_works_v1 : WHERE assemblé, volume par la vue, titres matérialisé';
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  IF v_txt ~ '__WHERE__' AND v_txt !~ 'p\.publisher IS NULL OR' AND v_txt !~ 'LEFT JOIN public\.books bk'
     AND v_txt ~ 'titres AS MATERIALIZED' AND v_txt ~ 'c\.volume AS volume_brut'
     -- titres_livres lit le catalogue (la vue), plus books sous RLS ; et pas de boucle imbriquée (réglage local, remis après)
     AND v_txt !~ 'FROM public\.books b CROSS JOIN params p' AND v_txt ~ 'set_config\(''enable_nestloop'', ''off'', true\)'
     AND v_txt ~ 'set_config\(''enable_nestloop'', v_nestloop, true\)'
     AND (SELECT count(*) FROM information_schema.columns WHERE table_schema = 'api'
           AND table_name IN ('catalog_list_anon_v1', 'catalog_list_session_v1') AND column_name = 'volume') = 2
     -- et la recherche d'identifiants a un ordre total (book_id départage les rangs égaux, deux branches)
     AND (SELECT count(*) FROM regexp_matches((SELECT p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                                 WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1'),
                                               'nulls last, s\.book_id', 'g')) = 2 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : la fonction, les vues ou catalog_search_ids_v1 n''ont pas la forme attendue'); END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 les filtres de catalog_works_v1 rendent ce qu''ils rendaient (matériel, initiale, éditeur, langue, année, combinés)';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    SET LOCAL ROLE anon;
    -- pour chaque filtre, les rep_book_id rendus parmi les quatre notices du test, en une chaîne
    SELECT string_agg(x.cas || '=' || coalesce(y.reps::text, '{}'), ' ; ' ORDER BY x.ord) INTO v_txt
      FROM (VALUES (1, 'audio',        '{"material":"audio"}'),
                   (2, 'initiale F',   '{"alpha":"F"}'),
                   (3, 'éditeur',      '{"publisher":"Editora B32"}'),
                   (4, 'année 1900',   '{"year":"1900"}'),
                   (5, 'combiné',      '{"material":"audio","publisher":"Editora B32"}'),
                   (6, 'combiné vide', '{"material":"audio","alpha":"F"}')) x(ord, cas, filtre)
      CROSS JOIN LATERAL (
        SELECT array_agg((w->>'rep_book_id')::bigint ORDER BY (w->>'rep_book_id')::bigint) AS reps
          FROM jsonb_array_elements(api.catalog_works_v1(x.filtre::jsonb, 'relevance', 0, 200)->'works') w
         WHERE (w->>'rep_book_id')::bigint IN (v_livre, v_disque, v_film, v_rede_seul)) y;
    RESET ROLE;
    v_plan := format('audio={%s} ; initiale F={%s} ; éditeur={%s,%s} ; année 1900={} ; combiné={%s} ; combiné vide={}',
                     v_disque, v_film, least(v_livre, v_disque), greatest(v_livre, v_disque), v_disque);
    IF v_txt = v_plan THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rendu « ' || coalesce(v_txt, '∅') || ' », attendu « ' || v_plan || ' »'); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 tris et pagination de catalog_works_v1 : total constant, pages disjointes, tri auteur·rice respecté';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    SET LOCAL ROLE anon;
    v_ids := NULL; v_txt := NULL;
    SELECT (a->>'total')::int, (b->>'total'),
           (SELECT count(*) FROM jsonb_array_elements(a->'works') w WHERE (w->>'key') IN (SELECT x->>'key' FROM jsonb_array_elements(b->'works') x))::text
      INTO v_n, v_plan, v_txt
      FROM (SELECT api.catalog_works_v1('{}'::jsonb, 'autor.asc', 0, 2) AS a, api.catalog_works_v1('{}'::jsonb, 'autor.asc', 2, 2) AS b) t;
    RESET ROLE;
    IF v_n IS NULL THEN RAISE EXCEPTION 'total absent'; END IF;
    IF v_n = v_plan::int AND v_txt = '0' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : total %s/%s, %s clé(s) en commun', v_n, v_plan, v_txt)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CATALOGUE-ECHELLE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CATALOGUE-ECHELLE OK : %/%', v_passed, v_passed;
END $$;
