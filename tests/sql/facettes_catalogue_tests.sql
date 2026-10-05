-- =====================================================================
-- AnarBib — Tests : les facettes du catalogue disent au planificateur ce
-- qu'elles filtrent (suite de B32, 28/09/2026)
-- Ref     : 20260928162102_les_facettes_disent_ce_qu_elles_filtrent.sql
--           20260928164227_les_facettes_comptent_ce_que_la_page_montre.sql
--
-- api.catalog_facets_v1 assemble ses cinq prédicats (commun, auteur·rice,
-- années, CDD, sujet) à partir des filtres présents ; chaque facette ignore
-- son propre filtre (« expand »). Ces tests fixent ce que les filtres rendent
-- sur des notices construites pour matcher, dans une bibliothèque publique
-- créée ici.
--
-- Couvre :
--   T1 la fonction assemble ses prédicats (plus de « p.x IS NULL OR … ») et
--      reste exécutable par anon et authenticated ;
--   T2 sans filtre : les trois codes CDD, les trois décennies, l'auteur·rice
--      répétée et le sujet des notices du test sont comptés ;
--   T3 « expand » : le filtre CDD n'entame pas la facette CDD mais restreint
--      les décennies ; le filtre sujet n'entame pas la facette sujets mais
--      restreint la CDD ;
--   T4 les autres filtres restreignent toutes les facettes : matériel,
--      initiale, auteur·rice, éditeur, bornes d'années, bibliothèque, langue,
--      collection, lieu, recherche libre ;
--   T5 un filtre vide ou fait de blancs vaut absence ; un filtre sans aucune
--      notice rend des facettes vides ;
--   T6 la recherche « q » des facettes est celle de la page : chaque terme
--      n'importe où, sans accents ni casse (« memoria liberdade » compte les
--      deux notices, « MEMÓRIA » aussi ; « três » trouve « três ») ;
--   T7 pour une recherche, la somme des décennies vaut le nombre d'éditions
--      datées que catalog_search_ids_v1 rend — les facettes comptent ce que
--      la page montre.
--   Bilan OK : 'FACETTES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib constant uuid := 'fac3fac3-0000-4000-8000-0000000000c1';
  v_b1 bigint; v_b2 bigint; v_b3 bigint; v_b4 bigint; v_b5 bigint; v_b6 bigint; v_sujet bigint; v_auteur bigint;
  v_n int; v_m int;
  v_txt text; v_out jsonb; r record;
  -- compteur d'une entrée de facette (0 si absente)
BEGIN
  -- ── Fixtures : une bibliothèque publique, quatre notices, un sujet, une autorité ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_lib, 'facettes-test', 'Biblio facettes (test)', 'public', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Facettes, Autora', 'Facettes, Autora') RETURNING id INTO v_auteur;
  INSERT INTO public.subjects (slug, label_i18n) VALUES ('facettes-test', '{"pt-BR":"Facetas (teste)","fr":"Facettes (test)"}'::jsonb) RETURNING id INTO v_sujet;

  INSERT INTO public.books (titulo, autor, ano, editora, cdd, idioma, tipo_material, colecao, local_publicacao, bib_ref)
  VALUES ('Facettes um', 'Facettes, Autora', '1836', 'Editora Facettes', '998.1', 'pt-BR', 'livro', 'Coleção F', 'Belém', 'FAC-1') RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, autor, ano, editora, cdd, idioma, tipo_material, colecao, local_publicacao, bib_ref)
  VALUES ('Facettes dois', 'Facettes, Autora', '1849', 'Editora Facettes', '998.2', 'pt-BR', 'livro', 'Coleção F', 'Belém', 'FAC-2') RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, autor, ano, editora, cdd, idioma, tipo_material, colecao, local_publicacao, bib_ref)
  VALUES ('Facettes três', 'Zebra, Outra', '1901', 'Outra Editora', '997.0', 'fr', 'audio', 'Outra Coleção', 'Paris', 'FAC-3') RETURNING id INTO v_b3;
  INSERT INTO public.books (titulo, autor, ano, editora, cdd, idioma, tipo_material, bib_ref)
  VALUES ('Facettes quatro', 'Facettes, Autora', 'sem data', NULL, NULL, 'es', 'livro', 'FAC-4') RETURNING id INTO v_b4;
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  VALUES (v_b1, v_auteur, 1, 'Facettes, Autora', 'autor', true), (v_b2, v_auteur, 1, 'Facettes, Autora', 'autor', true), (v_b4, v_auteur, 1, 'Facettes, Autora', 'autor', true);
  -- deux notices pour la recherche : accents, ordre des mots
  INSERT INTO public.books (titulo, autor, ano, cdd, idioma, tipo_material, bib_ref)
  VALUES ('Memória e liberdade', 'Quinto, Autor', '1950', '996.1', 'pt-BR', 'livro', 'FAC-5') RETURNING id INTO v_b5;
  INSERT INTO public.books (titulo, autor, ano, cdd, idioma, tipo_material, bib_ref)
  VALUES ('A liberdade da memoria', 'Sexto, Autor', '1960', '996.2', 'pt-BR', 'livro', 'FAC-6') RETURNING id INTO v_b6;
  INSERT INTO public.book_subjects (book_id, subject_id) VALUES (v_b1, v_sujet), (v_b3, v_sujet);
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_b1, c_lib, true, 1, 1), (v_b2, c_lib, true, 1, 1), (v_b3, c_lib, true, 1, 1), (v_b4, c_lib, true, 1, 1), (v_b5, c_lib, true, 1, 1), (v_b6, c_lib, true, 1, 1);
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 catalog_facets_v1 assemble ses prédicats, exécutable par anon et authenticated';
  SELECT p.prosrc INTO v_txt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'api' AND p.proname = 'catalog_facets_v1';
  IF v_txt ~ '__PC__' AND v_txt ~ '__PSUB__' AND v_txt !~ 'p\.publisher IS NULL OR' AND v_txt !~ 'p\.subject IS NULL OR'
     AND v_txt ~ 'catalog_search_ids_v1' AND v_txt !~ 'c\.titulo ILIKE ''%''\|\|p\.q'
     AND has_function_privilege('anon', 'api.catalog_facets_v1(jsonb)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'api.catalog_facets_v1(jsonb)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : forme ou droits inattendus'); END IF;

  -- un lecteur : pour un jeu de filtres, le compte d'une entrée de chaque facette
  -- (0 si absente), sous le rôle anon ; rendu « cdd:998=2 decade:1830=1 … »
  CREATE TEMP TABLE facettes_cas (cas text, filtres jsonb, attendu text) ON COMMIT DROP;
  INSERT INTO facettes_cas VALUES
    ('sans filtre',      '{}',                                        'cdd998=2 cdd997=1 dec1830=1 dec1840=1 dec1900=1 auteur=3 sujet=2'),
    ('cdd 998 (expand)', '{"cdd":"998"}',                             'cdd998=2 cdd997=1 dec1830=1 dec1840=1 dec1900=0 auteur=2 sujet=1'),
    -- (la facette auteur·rices ne liste que les comptes >= 2 : une seule notice → absente → 0)
    ('sujet (expand)',   '{"subject":"facettes-test"}',               'cdd998=1 cdd997=1 dec1830=1 dec1840=0 dec1900=1 auteur=0 sujet=2'),
    ('matériel audio',   '{"material":"audio"}',                      'cdd998=0 cdd997=1 dec1830=0 dec1840=0 dec1900=1 auteur=0 sujet=1'),
    ('initiale Z',       '{"alpha":"Z"}',                             'cdd998=0 cdd997=1 dec1830=0 dec1840=0 dec1900=1 auteur=3 sujet=1'),
    ('auteur·rice',      format('{"author_id":"%s"}', v_auteur)::jsonb,      'cdd998=2 cdd997=0 dec1830=1 dec1840=1 dec1900=0 auteur=3 sujet=1'),
    ('éditeur',          '{"publisher":"Facettes"}',                  'cdd998=2 cdd997=0 dec1830=1 dec1840=1 dec1900=0 auteur=2 sujet=1'),
    ('années 1840-1950', '{"year_from":"1840","year_to":"1950"}',    'cdd998=1 cdd997=1 dec1830=1 dec1840=1 dec1900=1 auteur=0 sujet=1'),
    ('bibliothèque',     '{"library":"facettes-test"}',               'cdd998=2 cdd997=1 dec1830=1 dec1840=1 dec1900=1 auteur=3 sujet=2'),
    ('langue fr',        '{"language":"fr"}',                         'cdd998=0 cdd997=1 dec1830=0 dec1840=0 dec1900=1 auteur=0 sujet=1'),
    ('collection F',     '{"collection":"Coleção F"}',                'cdd998=2 cdd997=0 dec1830=1 dec1840=1 dec1900=0 auteur=2 sujet=1'),
    ('lieu Paris',       '{"place":"Paris"}',                         'cdd998=0 cdd997=1 dec1830=0 dec1840=0 dec1900=1 auteur=0 sujet=1'),
    ('recherche « três »', '{"q":"três"}',                            'cdd998=0 cdd997=1 dec1830=0 dec1840=0 dec1900=1 auteur=0 sujet=1'),
    ('vides et blancs',  '{"q":"  ","cdd":"","subject":" "}',         'cdd998=2 cdd997=1 dec1830=1 dec1840=1 dec1900=1 auteur=3 sujet=2'),
    ('aucune notice',    '{"q":"zzz-rien-zzz"}',                      'cdd998=0 cdd997=0 dec1830=0 dec1840=0 dec1900=0 auteur=0 sujet=0');

  FOR r IN SELECT * FROM facettes_cas LOOP
    BEGIN
      PERFORM set_config('request.jwt.claims', '', true);
      SET LOCAL ROLE anon;
      v_out := api.catalog_facets_v1(r.filtres);
      RESET ROLE;
      v_txt := format('cdd998=%s cdd997=%s dec1830=%s dec1840=%s dec1900=%s auteur=%s sujet=%s',
        coalesce((SELECT (x->>'count')::int FROM jsonb_array_elements(v_out->'cdd') x WHERE x->>'code' = '998'), 0),
        coalesce((SELECT (x->>'count')::int FROM jsonb_array_elements(v_out->'cdd') x WHERE x->>'code' = '997'), 0),
        coalesce((SELECT (x->>'count')::int FROM jsonb_array_elements(v_out->'decade') x WHERE x->>'decade' = '1830'), 0),
        coalesce((SELECT (x->>'count')::int FROM jsonb_array_elements(v_out->'decade') x WHERE x->>'decade' = '1840'), 0),
        coalesce((SELECT (x->>'count')::int FROM jsonb_array_elements(v_out->'decade') x WHERE x->>'decade' = '1900'), 0),
        coalesce((SELECT (x->>'count')::int FROM jsonb_array_elements(v_out->'author') x WHERE x->>'label' = 'Facettes, Autora'), 0),
        coalesce((SELECT (x->>'count')::int FROM jsonb_array_elements(v_out->'subjects') x WHERE x->>'slug' = 'facettes-test'), 0));
      IF v_txt = r.attendu THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || ('T2-5 ' || r.cas || ' : rendu « ' || v_txt || ' », attendu « ' || r.attendu || ' »'); END IF;
    EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || ('T2-5 ' || r.cas || ' : ' || SQLERRM); END;
  END LOOP;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 la recherche « q » des facettes est celle de la page : termes, accents, casse';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    SET LOCAL ROLE anon;
    SELECT string_agg(x.cas || '=' || coalesce((SELECT (e->>'count')::int FROM jsonb_array_elements(api.catalog_facets_v1(x.f::jsonb)->'cdd') e WHERE e->>'code' = '996'), 0), ' ; ' ORDER BY x.o)
      INTO v_txt
      FROM (VALUES (1, 'memoria liberdade', '{"q":"memoria liberdade"}'), (2, 'MEMÓRIA', '{"q":"MEMÓRIA"}'), (3, 'liberdade memória', '{"q":"liberdade memória"}'),
                   (4, 'memoria zzz', '{"q":"memoria zzz-rien"}'), (5, 'três', '{"q":"três"}')) x(o, cas, f);
    RESET ROLE;
    IF v_txt = 'memoria liberdade=2 ; MEMÓRIA=2 ; liberdade memória=2 ; memoria zzz=0 ; três=0' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rendu « ' || coalesce(v_txt, '∅') || ' »'); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 pour une recherche, les décennies des facettes = les éditions datées que catalog_search_ids_v1 rend';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    SET LOCAL ROLE anon;
    SELECT coalesce(sum((e->>'count')::int), 0)::int INTO v_n FROM jsonb_array_elements(api.catalog_facets_v1('{"q":"liberdade"}'::jsonb)->'decade') e;
    SELECT count(*)::int INTO v_m FROM api.catalog_search_ids_v1('liberdade') s JOIN api.catalog_list_anon_v1 c ON c.book_id = s.book_id WHERE c.ano ~ '^\d{4}$';
    RESET ROLE;
    IF v_n = v_m AND v_m >= 2 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : facettes %s, recherche %s', v_n, v_m)); END IF;
  EXCEPTION WHEN OTHERS THEN RESET ROLE; v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'FACETTES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'FACETTES OK : %/%', v_passed, v_passed;
END $$;
