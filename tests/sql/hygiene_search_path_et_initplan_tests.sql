-- Hygiène gardée sur toute la base (06/09/2026, migration 20260906111308) :
-- T1 aucune fonction applicative sans search_path figé ;
-- T2 aucune policy qui appelle auth.uid() hors d'un (select auth.uid()) ;
-- T3 la policy du 05/09 garde exactement son prédicat (admin ou staff actif).
-- Rien n'est écrit : ROLLBACK par convention.
BEGIN;

DO $$
DECLARE
  v_ok int := 0;
  n int;
  v_list text;
BEGIN
  -- T1
  SELECT count(*), string_agg(ns.nspname || '.' || p.proname, ', ') INTO n, v_list
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname IN ('public', 'api', 'ingest', 'private')
     AND p.prokind = 'f'
     AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) c WHERE c LIKE 'search_path=%');
  IF n <> 0 THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : % fonction(s) sans search_path figé : %', n, v_list; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 1 OK — toutes les fonctions applicatives ont un search_path figé.';

  -- T2 : autant d'occurrences de « auth.uid() » que de « SELECT auth.uid() » dans chaque policy.
  SELECT count(*), string_agg(c.relname || '.' || p.polname, ', ') INTO n, v_list
    FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
   WHERE (SELECT count(*) FROM regexp_matches(coalesce(pg_get_expr(p.polqual, p.polrelid), '') || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''), 'auth\.uid\(\)', 'g'))
      <> (SELECT count(*) FROM regexp_matches(coalesce(pg_get_expr(p.polqual, p.polrelid), '') || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), ''), 'SELECT auth\.uid\(\)', 'g'));
  IF n <> 0 THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : % policy(ies) réévaluent auth.uid() par ligne : %', n, v_list; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 2 OK — aucune policy ne réévalue auth.uid() par ligne.';

  -- T3
  SELECT count(*) INTO n FROM pg_policy p
   WHERE p.polname = 'catalog_batch_reviews_read_staff'
     AND p.polcmd = 'r'
     AND pg_get_expr(p.polqual, p.polrelid) ~ 'fn_caller_is_network_admin\(\)'
     AND pg_get_expr(p.polqual, p.polrelid) ~ 'user_library_memberships'
     AND pg_get_expr(p.polqual, p.polrelid) ~ 'librarian'
     AND pg_get_expr(p.polqual, p.polrelid) ~ 'coordenador';
  IF n <> 1 THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : catalog_batch_reviews_read_staff n''a plus son prédicat (admin ou staff actif).'; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 3 OK — la policy des révisions garde son prédicat.';

  RAISE NOTICE 'HYGIENE OK : %/3 tests passés.', v_ok;
END $$;

ROLLBACK;
