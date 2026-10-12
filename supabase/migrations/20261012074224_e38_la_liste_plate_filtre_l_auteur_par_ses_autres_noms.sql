-- =====================================================================
-- AnarBib — E38, suite (12/10/2026) : la liste plate filtre l'auteur·rice
-- par ses autres noms, comme la liste par œuvre.
--
-- Constat de Xavier le 12/10 au matin, après la livraison de la veille
-- (20261011211012) : « Kropotkine » dans le champ Auteur·rice rend 37 lignes
-- par œuvre (catalog_works_v1 résout le nom par private.fn_auteurs_par_nom)
-- mais UNE notice en liste plate — là, le filtre est un ILIKE PostgREST sur
-- `autor` et `author_display`, bâti côté client (src/lib/catalogFilters.js),
-- qui ne lit ni les alias ni les variantes de l'autorité.
--
-- Ce que fait cette migration : une porte de lecture, api.catalog_author_ids_v1
-- (SECURITY INVOKER, search_path figé), qui rend les identifiants d'autorité
-- que private.fn_auteurs_par_nom trouve pour un nom — exact, ou à une ou deux
-- lettres près si on le demande. Aucune fonction DEFINER nouvelle : la seule
-- porte DEFINER est fn_auteurs_par_nom, déjà ouverte à anon et portée à
-- l'audit execute_anon le 11/10. Le client ajoute ces identifiants au filtre
-- (author_id, author_chips) à côté de l'ILIKE, qui garde les notices sans
-- autorité liée.
-- Suite : tests/sql/e38_liste_plate_auteur_par_ses_noms_tests.sql.
-- =====================================================================

CREATE OR REPLACE FUNCTION api.catalog_author_ids_v1(p_name text, p_approche boolean DEFAULT false)
RETURNS bigint[]
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT CASE WHEN coalesce(btrim(p_name), '') = '' THEN '{}'::bigint[]
              ELSE coalesce(private.fn_auteurs_par_nom(btrim(p_name), coalesce(p_approche, false)), '{}'::bigint[]) END;
$$;

COMMENT ON FUNCTION api.catalog_author_ids_v1(text, boolean) IS
  'E38 (12/10/2026) : les identifiants d''autorité que porte un nom — forme retenue, forme de tri, variantes, alias actifs — exact, ou à une ou deux lettres près (p_approche). Porte de lecture INVOKER sur private.fn_auteurs_par_nom, pour que la liste plate du catalogue filtre l''auteur·rice comme la liste par œuvre.';

REVOKE ALL ON FUNCTION api.catalog_author_ids_v1(text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.catalog_author_ids_v1(text, boolean) TO anon, authenticated, service_role;

-- Vérification : la porte est INVOKER, figée, ouverte à anon ; elle rend ce que rend l'aide.
DO $e38$
DECLARE v_e text := '';
BEGIN
  IF (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = 'api.catalog_author_ids_v1(text, boolean)'::regprocedure) THEN v_e := v_e || ' definer'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p, unnest(p.proconfig) c WHERE p.oid = 'api.catalog_author_ids_v1(text, boolean)'::regprocedure AND c LIKE 'search_path=%') THEN v_e := v_e || ' search_path'; END IF;
  IF NOT has_function_privilege('anon', 'api.catalog_author_ids_v1(text, boolean)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'api.catalog_author_ids_v1(text, boolean)', 'EXECUTE')
     OR has_function_privilege('public', 'api.catalog_author_ids_v1(text, boolean)', 'EXECUTE') THEN v_e := v_e || ' droits'; END IF;
  IF api.catalog_author_ids_v1('', false) <> '{}'::bigint[] OR api.catalog_author_ids_v1(NULL, NULL) <> '{}'::bigint[] THEN v_e := v_e || ' vide'; END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'E38 — vérification en échec :%', v_e; END IF;
END
$e38$;
