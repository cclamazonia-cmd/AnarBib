-- =====================================================================
-- catalogue-mesure.sql — les parcours réels de l'OPAC, chronométrés (B32).
--
-- ⚠ BANC LOCAL SEULEMENT (base jetable, voir catalogue-synthetique.sql).
--
-- Pour chaque parcours — page par œuvre (défaut, page 3, recherche, auteur,
-- éditeur, initiale, tri), facettes, liste plate (tri par titre, filtre,
-- nouveautés), count(*) sous RLS, autocomplétion — sans compte puis en
-- adhérent·e : quatre appels en instructions simples chronométrées par psql
-- (\timing) ; catalogue-mesure-resume.cjs en tire la moyenne des trois
-- derniers (le premier chauffe). Pas d'enveloppe PL/pgSQL : l'image Supabase
-- précharge plpgsql_check, dont la couche pldbgapi2 casse (« statement call
-- stack is broken ») après certains appels imbriqués depuis une fonction —
-- constaté le 28/09/2026 à 100 000 notices. Le rôle anon n'a pas son plafond
-- de 3 s sur le banc (réglage de rôle posé à la connexion, pas par SET ROLE) :
-- la durée affichée est la durée réelle, à comparer au plafond.
--
-- usage :
--   psql -X -d anarbib_perf -f scripts/loadtest/catalogue-mesure.sql > mesure-avant.log
--   node scripts/loadtest/catalogue-mesure-resume.cjs avant mesure-avant.log
-- =====================================================================
\set ON_ERROR_STOP off
\pset pager off
\pset footer off
SET statement_timeout = 0;
SELECT author_id::text AS auteur FROM public.mv_books_catalog_list_v1 WHERE author_id IS NOT NULL
 GROUP BY author_id ORDER BY count(*) DESC, author_id LIMIT 1 \gset
\timing on

SELECT set_config('request.jwt.claims', '', false);
SET ROLE anon;
\echo CAS anon · œuvres · page par défaut
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb)->'works') AS n;
\echo CAS anon · œuvres · page 3
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb, 'relevance', 100, 50)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb, 'relevance', 100, 50)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb, 'relevance', 100, 50)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb, 'relevance', 100, 50)->'works') AS n;
\echo CAS anon · œuvres · recherche « anarquia »
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"anarquia"}'::jsonb)->'works') AS n;
\echo CAS anon · œuvres · recherche « memória reclus »
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"memória reclus"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"memória reclus"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"memória reclus"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"memória reclus"}'::jsonb)->'works') AS n;
\echo CAS anon · œuvres · auteur·rice
SELECT jsonb_array_length(api.catalog_works_v1(('{"author_id":"' || :'auteur' || '"}')::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1(('{"author_id":"' || :'auteur' || '"}')::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1(('{"author_id":"' || :'auteur' || '"}')::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1(('{"author_id":"' || :'auteur' || '"}')::jsonb)->'works') AS n;
\echo CAS anon · œuvres · éditeur « Editora »
SELECT jsonb_array_length(api.catalog_works_v1('{"publisher":"Editora Anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"publisher":"Editora Anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"publisher":"Editora Anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"publisher":"Editora Anarquia"}'::jsonb)->'works') AS n;
\echo CAS anon · œuvres · initiale « M »
SELECT jsonb_array_length(api.catalog_works_v1('{"alpha":"M"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"alpha":"M"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"alpha":"M"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"alpha":"M"}'::jsonb)->'works') AS n;
\echo CAS anon · œuvres · tri auteur
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb, 'autor.asc')->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb, 'autor.asc')->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb, 'autor.asc')->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb, 'autor.asc')->'works') AS n;
\echo CAS anon · facettes · sans filtre
SELECT jsonb_array_length(api.catalog_facets_v1('{}'::jsonb)->'cdd') AS n;
SELECT jsonb_array_length(api.catalog_facets_v1('{}'::jsonb)->'cdd') AS n;
SELECT jsonb_array_length(api.catalog_facets_v1('{}'::jsonb)->'cdd') AS n;
SELECT jsonb_array_length(api.catalog_facets_v1('{}'::jsonb)->'cdd') AS n;
\echo CAS anon · facettes · recherche
SELECT jsonb_array_length(api.catalog_facets_v1('{"q":"anarquia"}'::jsonb)->'cdd') AS n;
SELECT jsonb_array_length(api.catalog_facets_v1('{"q":"anarquia"}'::jsonb)->'cdd') AS n;
SELECT jsonb_array_length(api.catalog_facets_v1('{"q":"anarquia"}'::jsonb)->'cdd') AS n;
SELECT jsonb_array_length(api.catalog_facets_v1('{"q":"anarquia"}'::jsonb)->'cdd') AS n;
\echo CAS anon · liste plate · titre, 50
SELECT count(*) AS n FROM (SELECT book_id, titulo, autor, ano FROM api.catalog_list_anon_v1 ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo, autor, ano FROM api.catalog_list_anon_v1 ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo, autor, ano FROM api.catalog_list_anon_v1 ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo, autor, ano FROM api.catalog_list_anon_v1 ORDER BY titulo LIMIT 50) x;
\echo CAS anon · liste plate · filtre titre
SELECT count(*) AS n FROM (SELECT book_id, titulo FROM api.catalog_list_anon_v1 WHERE titulo ILIKE '%liberdade%' ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo FROM api.catalog_list_anon_v1 WHERE titulo ILIKE '%liberdade%' ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo FROM api.catalog_list_anon_v1 WHERE titulo ILIKE '%liberdade%' ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo FROM api.catalog_list_anon_v1 WHERE titulo ILIKE '%liberdade%' ORDER BY titulo LIMIT 50) x;
\echo CAS anon · liste plate · nouveautés
SELECT count(*) AS n FROM (SELECT book_id, titulo FROM api.catalog_list_anon_v1 ORDER BY created_at DESC LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo FROM api.catalog_list_anon_v1 ORDER BY created_at DESC LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo FROM api.catalog_list_anon_v1 ORDER BY created_at DESC LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo FROM api.catalog_list_anon_v1 ORDER BY created_at DESC LIMIT 50) x;
\echo CAS anon · books · count(*) sous RLS
SELECT count(*)::int AS n FROM public.books;
SELECT count(*)::int AS n FROM public.books;
SELECT count(*)::int AS n FROM public.books;
SELECT count(*)::int AS n FROM public.books;
\echo CAS anon · autocomplétion (B33)
SELECT count(*)::int AS n FROM api.search_catalog_v1('reclus memória');
SELECT count(*)::int AS n FROM api.search_catalog_v1('reclus memória');
SELECT count(*)::int AS n FROM api.search_catalog_v1('reclus memória');
SELECT count(*)::int AS n FROM api.search_catalog_v1('reclus memória');
RESET ROLE;

SELECT set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', false);
SET ROLE authenticated;
\echo CAS authenticated · œuvres · page par défaut
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{}'::jsonb)->'works') AS n;
\echo CAS authenticated · œuvres · recherche « anarquia »
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"anarquia"}'::jsonb)->'works') AS n;
SELECT jsonb_array_length(api.catalog_works_v1('{"q":"anarquia"}'::jsonb)->'works') AS n;
\echo CAS authenticated · liste plate · titre, 50
SELECT count(*) AS n FROM (SELECT book_id, titulo, autor, ano FROM api.catalog_list_session_v1 ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo, autor, ano FROM api.catalog_list_session_v1 ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo, autor, ano FROM api.catalog_list_session_v1 ORDER BY titulo LIMIT 50) x;
SELECT count(*) AS n FROM (SELECT book_id, titulo, autor, ano FROM api.catalog_list_session_v1 ORDER BY titulo LIMIT 50) x;
\echo CAS authenticated · books · count(*) sous RLS
SELECT count(*)::int AS n FROM public.books;
SELECT count(*)::int AS n FROM public.books;
SELECT count(*)::int AS n FROM public.books;
SELECT count(*)::int AS n FROM public.books;
RESET ROLE;
\timing off
