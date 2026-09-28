-- Hygiène gardée sur toute la base (06/09/2026, migration 20260906111308) :
-- T1 aucune fonction applicative sans search_path figé ;
-- T2 aucune policy qui appelle auth.uid() hors d'un (select auth.uid()) ;
-- T3 la policy des révisions garde son prédicat : depuis B29 (27/09, CAT-E18),
--    l'admin, ou qui possède tout le lot (fn_caller_owns_batch) —
--    avant : le staff de n'importe quelle bibliothèque.
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
     AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) c WHERE c LIKE 'search_path=%')
     -- B32 (28/09/2026), seule exception nommée : fn_locale_from_idioma est une
     -- fonction SQL IMMUTABLE réduite à une expression, toutes références
     -- qualifiées pg_catalog — un SET l'empêcherait d'être insérée en ligne
     -- (un appel par ligne au lieu d'une expression). Le search_path n'a pas
     -- de prise sur elle ; la migration 20260928122318 le vérifie et le dit.
     AND NOT (ns.nspname = 'public' AND p.proname = 'fn_locale_from_idioma');
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
     AND pg_get_expr(p.polqual, p.polrelid) ~ 'fn_caller_owns_batch\(batch_id\)';
  IF n <> 1 THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : catalog_batch_reviews_read_staff n''a plus son prédicat (admin ou lot entièrement à soi).'; END IF;
  v_ok := v_ok + 1; RAISE NOTICE 'TEST 3 OK — la policy des révisions garde son prédicat.';

  RAISE NOTICE 'HYGIENE OK : %/3 tests passés.', v_ok;
END $$;

ROLLBACK;
