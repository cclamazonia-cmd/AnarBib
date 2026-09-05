-- B7 — les homonymes de fonctions entre `ingest` et `public` sont départagés (05/09/2026).
-- Migration 20260905132602. Rien n'est écrit : ROLLBACK par convention.
BEGIN;

DO $$
DECLARE
  v_ok int := 0;
  nom text;
  noms constant text[] := array[
    'fn_bulk_create_book_drafts_from_run',
    'fn_bulk_set_partner_catalog_editorial_decision',
    'fn_set_partner_catalog_editorial_decision'
  ];
  n int;
  v_oid oid;
BEGIN
  -- T1 — aucune des trois n'existe plus dans public, sous quelque signature que ce soit.
  SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'public' AND p.proname = ANY (noms);
  IF n <> 0 THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : % homonyme(s) encore dans public.', n; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 1 OK — plus d''homonyme dans public.';

  -- T2 — chaque nom n'existe qu'une fois, dans ingest.
  FOREACH nom IN ARRAY noms LOOP
    SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname IN ('public', 'ingest', 'api') AND p.proname = nom;
    IF n <> 1 THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : % existe % fois (1 attendue, dans ingest).', nom, n; END IF;
  END LOOP;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 2 OK — un seul exemplaire par nom.';

  -- T3 — les versions ingest sont SECURITY DEFINER, search_path figé.
  FOREACH nom IN ARRAY noms LOOP
    SELECT p.oid INTO v_oid FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'ingest' AND p.proname = nom;
    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_oid) THEN
      RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : ingest.% n''est plus SECURITY DEFINER.', nom;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid = v_oid AND proconfig::text LIKE '%search_path%') THEN
      RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : ingest.% sans search_path figé.', nom;
    END IF;
  END LOOP;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 3 OK — ingest.* DEFINER, search_path figé.';

  -- T4 — fermées à anon et à authenticated : seul le service et les fonctions les appellent.
  FOREACH nom IN ARRAY noms LOOP
    SELECT p.oid INTO v_oid FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'ingest' AND p.proname = nom;
    IF has_function_privilege('anon', v_oid, 'EXECUTE') OR has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : ingest.% exécutable par anon ou authenticated.', nom;
    END IF;
  END LOOP;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 4 OK — ingest.* fermées à anon et authenticated.';

  -- T5 — les appelants vivants visent ingest, qualifié.
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_import_promote' AND prosrc ~ 'ingest\.fn_bulk_create_book_drafts_from_run\s*\(') THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : fn_import_promote n''appelle plus ingest.fn_bulk_create_book_drafts_from_run.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_import_set_editorial' AND prosrc ~ 'ingest\.fn_set_partner_catalog_editorial_decision\s*\(') THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : fn_import_set_editorial n''appelle plus ingest.fn_set_partner_catalog_editorial_decision.';
  END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 5 OK — les appelants visent ingest, qualifié.';

  -- T6 — aucun corps de fonction ni vue ne cite plus public.<nom>.
  SELECT count(*) INTO n FROM pg_proc p
   WHERE p.prosrc ~ 'public\.(fn_bulk_create_book_drafts_from_run|fn_bulk_set_partner_catalog_editorial_decision|fn_set_partner_catalog_editorial_decision)\s*\(';
  IF n <> 0 THEN RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : % fonction(s) citent encore public.<homonyme>.', n; END IF;
  SELECT count(*) INTO n FROM pg_views v
   WHERE v.definition ~ 'public\.(fn_bulk_create_book_drafts_from_run|fn_bulk_set_partner_catalog_editorial_decision|fn_set_partner_catalog_editorial_decision)\s*\(';
  IF n <> 0 THEN RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : % vue(s) citent encore public.<homonyme>.', n; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 6 OK — plus aucune citation de public.<homonyme>.';

  RAISE NOTICE 'B7 OK : %/6 tests passés.', v_ok;
END $$;

ROLLBACK;
