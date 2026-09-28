-- =========================================================================
-- B32 (levier b) — la visibilité par bibliothèque se calcule une fois par requête
-- =========================================================================
-- Date     : 2026-09-28
-- Chantier : B32 (constat de B10, AUDIT_performance_B10_2026-09-27.md §5)
--
-- LE CONSTAT. 21 policies de lecture appellent
-- fn_library_visible_to_caller(<bibliothèque de la ligne>) : une fonction
-- SECURITY DEFINER, donc jamais insérée en ligne, évaluée pour CHAQUE ligne
-- lue (books, exemplares, book_holdings, authors, …). En anonyme, `count(*)`
-- sur books coûtait 88 ms pour 2 634 notices ; à 100 000, la seule policy
-- dépasse les 3 s du rôle anon.
--
-- LE GESTE. public.fn_visible_library_ids() rend, une fois, l'ensemble des
-- bibliothèques visibles de l'appelant — défini PAR fn_library_visible_to_caller
-- elle-même (une évaluation par bibliothèque : la règle reste écrite à un seul
-- endroit). Chaque policy écrit désormais
--   <bibliothèque> = ANY ((SELECT public.fn_visible_library_ids())::uuid[])
-- : la sous-requête ne dépend pas de la ligne, PostgreSQL la calcule une fois
-- par requête (InitPlan) — même règle que la passe 1 bis de B10. Une
-- bibliothèque NULL donne NULL au lieu de false : dans une policy (OU, ET,
-- jamais NOT), la ligne reste invisible dans les deux cas.
--
-- Le texte des policies est réécrit depuis sa forme réelle (pg_get_expr), sans
-- recopie ; les deux copies de chaque lecture publique (anon, authenticated)
-- reçoivent la même réécriture, et restent donc identiques texte pour texte
-- (garde T3 de policies_permissives_uniques_tests).
--
-- Tenu par tests/sql/catalogue_grande_echelle_tests.sql.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_visible_library_ids()
RETURNS uuid[]
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT coalesce(array_agg(l.id ORDER BY l.id), '{}'::uuid[])
    FROM public.libraries l
   WHERE public.fn_library_visible_to_caller(l.id)
$$;

COMMENT ON FUNCTION public.fn_visible_library_ids() IS
  'B32 · les bibliothèques visibles de l''appelant, une fois par requête (InitPlan dans les policies). Définie par fn_library_visible_to_caller : la règle de visibilité reste écrite à un seul endroit.';

REVOKE ALL ON FUNCTION public.fn_visible_library_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_visible_library_ids() TO anon, authenticated, service_role;

DO $reecriture$
DECLARE
  r      record;
  v_new  text;
  v_n    int := 0;
BEGIN
  FOR r IN
    SELECT pol.polname, pol.polrelid::regclass AS rel, pg_get_expr(pol.polqual, pol.polrelid) AS qual
      FROM pg_policy pol
     WHERE pg_get_expr(pol.polqual, pol.polrelid) ~ 'fn_library_visible_to_caller\('
     ORDER BY 2, 1
  LOOP
    -- `= ANY ((SELECT f()))` serait lu comme ANY(sous-requête) — une comparaison
    -- à chaque LIGNE, donc au tableau entier (uuid = uuid[]) : le cast force la
    -- forme « = ANY (tableau) », calculé une fois (InitPlan).
    v_new := regexp_replace(r.qual, 'fn_library_visible_to_caller\(([a-z_]+(\.[a-z_]+)?)\)',
                            '(\1 = ANY ((SELECT public.fn_visible_library_ids())::uuid[]))', 'g');
    IF v_new ~ 'fn_library_visible_to_caller' THEN
      RAISE EXCEPTION 'B32 : policy % sur % — un appel n''a pas la forme attendue : %', r.polname, r.rel, r.qual;
    END IF;
    EXECUTE format('ALTER POLICY %I ON %s USING (%s)', r.polname, r.rel, v_new);
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'B32 : % policies réécrites', v_n;
END
$reecriture$;

-- Garde de sortie
DO $sortie$
DECLARE v_n int;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policy pol
              WHERE pg_get_expr(pol.polqual, pol.polrelid) ~ 'fn_library_visible_to_caller'
                 OR coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') ~ 'fn_library_visible_to_caller') THEN
    RAISE EXCEPTION 'B32 : une policy appelle encore fn_library_visible_to_caller ligne à ligne';
  END IF;
  SELECT count(*) INTO v_n FROM pg_policy pol
   WHERE pg_get_expr(pol.polqual, pol.polrelid) ~ 'fn_visible_library_ids';
  IF v_n < 21 THEN
    RAISE EXCEPTION 'B32 : % policies seulement portent fn_visible_library_ids (21 attendues)', v_n;
  END IF;
  IF NOT has_function_privilege('anon', 'public.fn_visible_library_ids()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_visible_library_ids()', 'EXECUTE') THEN
    RAISE EXCEPTION 'B32 : fn_visible_library_ids doit rester exécutable par anon et authenticated (les policies l''appellent sous leur rôle)';
  END IF;
END
$sortie$;

COMMIT;
