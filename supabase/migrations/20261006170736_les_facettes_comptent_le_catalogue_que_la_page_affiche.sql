-- =====================================================================
-- E29 — Les facettes comptent le catalogue que la page affiche.
--
-- La page du catalogue lit api.catalog_list_session_v1 pour une personne
-- connectée et api.catalog_list_anon_v1 sinon (CatalogPage.jsx, comme
-- api.catalog_works_v1). api.catalog_facets_v1 lisait toujours la vue
-- publique : pour une session, ses compteurs pouvaient différer des lignes
-- affichées (limite écrite dans la clôture de B32 et dans 5f13ec86).
-- Aujourd'hui les deux catalogues coïncident (2 602 lignes de chaque côté,
-- différence vide, mesuré le 06/10) ; ils divergent dès qu'une bibliothèque
-- est en visibilité « network », ou publique sans catalogue publié au réseau.
--
-- La fonction choisit désormais sa vue comme catalog_works_v1 : la vue de
-- session si auth.uid() est connu, la vue publique sinon. Rien ne change en
-- anonyme (même requête, mêmes prédicats). Coût mesuré en production sous
-- authenticated, sans filtre : 47 ms.
--
-- Corps réécrit depuis la définition réelle (pg_get_functiondef), trois
-- ancres comptées : rien n'est retapé. CREATE OR REPLACE garde les droits
-- (anon et authenticated exécutent) et le commentaire.
-- Suite : tests/sql/facettes_catalogue_tests.sql, T8.
-- =====================================================================
DO $migration$
DECLARE
  v_def text := pg_get_functiondef('api.catalog_facets_v1(jsonb)'::regprocedure);
  a1 constant text := E'  v_out jsonb;\n';
  a2 constant text := E'  FROM api.catalog_list_anon_v1 c CROSS JOIN params p\n';
  a3 constant text := E'  EXECUTE v_sql INTO v_out USING p_filters;\n';
  r1 constant text := E'  v_out jsonb;\n'
    || E'  -- la vue que la page lit (E29) : celle de la session pour une personne\n'
    || E'  -- connectée, le catalogue public sinon — comme api.catalog_works_v1\n'
    || E'  v_view text := CASE WHEN auth.uid() IS NULL THEN ''api.catalog_list_anon_v1'' ELSE ''api.catalog_list_session_v1'' END;\n';
  r2 constant text := E'  FROM __VIEW__ c CROSS JOIN params p\n';
  r3 constant text := E'  v_sql := replace(v_sql, ''__VIEW__'', v_view);\n'
    || E'  EXECUTE v_sql INTO v_out USING p_filters;\n';
  v_src text;
BEGIN
  v_def := replace(v_def, E'\r', '');
  IF (length(v_def) - length(replace(v_def, a1, ''))) / length(a1) <> 1
     OR (length(v_def) - length(replace(v_def, a2, ''))) / length(a2) <> 1
     OR (length(v_def) - length(replace(v_def, a3, ''))) / length(a3) <> 1
     OR position('__VIEW__' in v_def) > 0 THEN
    RAISE EXCEPTION 'E29 : la définition de api.catalog_facets_v1 n''est pas celle attendue (ancres absentes ou déjà réécrites)';
  END IF;
  v_def := replace(replace(replace(v_def, a1, r1), a2, r2), a3, r3);
  EXECUTE v_def;

  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_facets_v1';
  IF v_src !~ 'catalog_list_session_v1' OR v_src !~ 'FROM __VIEW__ c' OR v_src ~ 'FROM api\.catalog_list_anon_v1 c'
     OR NOT has_function_privilege('anon', 'api.catalog_facets_v1(jsonb)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'api.catalog_facets_v1(jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'E29 : réécriture incomplète ou droits perdus';
  END IF;
END
$migration$;
