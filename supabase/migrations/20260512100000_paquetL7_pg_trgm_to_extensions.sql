-- =========================================================================
-- Paquet L.7 — Déplacement de pg_trgm vers le schéma extensions
-- =========================================================================
-- Contexte : pg_trgm est actuellement installée dans le schéma `public`,
-- ce qui pollue l'espace de noms applicatif et déclenche l'alerte linter
-- extension_in_public. Doctrine Supabase : les extensions doivent vivre
-- dans un schéma dédié (typiquement `extensions`).
--
-- AUDIT PRÉALABLE (session 2026-05-12 matin) :
--   - 16 indexes trigram sur tables critiques (books, authors,
--     author_name_aliases, 2 MV catalog) — restent fonctionnels après le
--     move, Postgres met à jour automatiquement les références d'opclass
--   - 47 objets dépendent de pg_trgm (31 fonctions, 10 opérateurs, 2
--     opclass, 2 opfamily, 2 types) — tous déplacés automatiquement
--   - 1 SEULE fonction métier appelle pg_trgm avec un search_path fixe :
--     api.search_catalog_v1 (similarity() et opérateur %)
--   - f_normalize_search utilisée dans les indexes ne fait PAS d'appel
--     trigram en interne, pas de risque
--
-- DOCTRINE CHOISIE (Q1 = A) :
--   Étendre le search_path de api.search_catalog_v1 pour inclure
--   `extensions`. Pratique standard Supabase. Pas de modification du code
--   de la fonction, donc zéro risque de régression de logique métier.
--
-- VÉRIFICATION AUTOMATIQUE (Q2 = OUI) :
--   Test fonctionnel : appel réel à api.search_catalog_v1('anarch') en
--   contexte anon simulé. Doit retourner >= 1 ligne. ROLLBACK auto sinon.
--
-- Rollback ciblé si régression imprévue :
--   ALTER EXTENSION pg_trgm SET SCHEMA public;
--   ALTER FUNCTION api.search_catalog_v1(text) SET search_path = public, api;
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Création du schema extensions et droits USAGE
-- -------------------------------------------------------------------------
-- USAGE pour anon et authenticated parce que api.search_catalog_v1 (et
-- toute future fonction utilisant une extension de ce schema) doit pouvoir
-- résoudre les fonctions/opérateurs via le search_path.

CREATE SCHEMA IF NOT EXISTS extensions;

GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;

COMMENT ON SCHEMA extensions IS
  'Schéma dédié aux extensions Postgres tierces. Contient pg_trgm depuis '
  'paquet L.7 (2026-05-12). Doctrine Supabase : ne pas installer '
  'd''extensions dans public. USAGE accordé à anon/authenticated car '
  'certaines fonctions métier (api.search_catalog_v1) référencent les '
  'opérateurs/fonctions de pg_trgm via leur search_path.';

-- -------------------------------------------------------------------------
-- 2. Déplacement de pg_trgm de public vers extensions
-- -------------------------------------------------------------------------
-- ALTER EXTENSION ... SET SCHEMA déplace TOUS les objets membres de
-- l'extension : fonctions (similarity, word_similarity, etc.), opérateurs
-- (%, <%, etc.), opclass (gin_trgm_ops, gist_trgm_ops), opfamily, types.
-- Les références internes des indexes existants (16 sur AnarBib) sont
-- mises à jour automatiquement par Postgres : les indexes continuent de
-- fonctionner sans interruption.

ALTER EXTENSION pg_trgm SET SCHEMA extensions;

-- -------------------------------------------------------------------------
-- 3. Ajustement du search_path de api.search_catalog_v1
-- -------------------------------------------------------------------------
-- Cette fonction utilise similarity() et l'opérateur % de pg_trgm sans
-- qualification explicite. Le search_path actuel ('public', 'api') ne
-- résoudra plus ces noms après le move. On ajoute 'extensions' à la fin
-- du search_path pour rétablir la résolution.

ALTER FUNCTION api.search_catalog_v1(text)
  SET search_path = public, api, extensions;

COMMENT ON FUNCTION api.search_catalog_v1(text) IS
  'Recherche full-text dans le catalogue (anon + authenticated). Utilise '
  'pg_trgm (similarity, opérateur %). search_path inclut extensions depuis '
  'paquet L.7 (2026-05-12) suite au déplacement de pg_trgm hors de public.';

-- -------------------------------------------------------------------------
-- 4. Vérifications automatiques en contexte anon PostgREST-like
-- -------------------------------------------------------------------------
-- 4 tests successifs. Le moindre échec déclenche un RAISE EXCEPTION qui
-- annule toute la transaction (BEGIN/COMMIT) et empêche la migration de
-- s'appliquer en prod.

DO $$
DECLARE
  v_pg_trgm_schema  text;
  v_n_indexes       int;
  v_n_results       int;
  v_test_query      text := 'anarch';
BEGIN
  -- Test 1 : pg_trgm est bien dans le schema extensions
  SELECT extnamespace::regnamespace::text INTO v_pg_trgm_schema
  FROM pg_extension
  WHERE extname = 'pg_trgm';

  IF v_pg_trgm_schema IS DISTINCT FROM 'extensions' THEN
    RAISE EXCEPTION 'Test 1 échec : pg_trgm est dans % au lieu de extensions. Rollback automatique.',
      COALESCE(v_pg_trgm_schema, '(NULL)');
  END IF;

  -- Test 2 : Les 16 indexes trigram existent toujours
  SELECT count(*) INTO v_n_indexes
  FROM pg_indexes
  WHERE indexdef ILIKE '%trgm%';

  IF v_n_indexes < 16 THEN
    RAISE EXCEPTION 'Test 2 échec : seulement % indexes trigram trouvés, attendu >= 16. '
                    'Le déplacement a peut-être détruit des indexes.', v_n_indexes;
  END IF;

  -- Test 3 : Recherche fonctionnelle en contexte anon
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';
  
  BEGIN
    SELECT count(*) INTO v_n_results
    FROM api.search_catalog_v1(v_test_query);
  EXCEPTION WHEN OTHERS THEN
    -- Capture toute erreur SQL (par exemple "function similarity does not exist")
    RAISE EXCEPTION 'Test 3 échec : api.search_catalog_v1(''%'') a planté (%). '
                    'Le search_path est probablement mal résolu.',
      v_test_query, SQLERRM;
  END;
  
  RESET ROLE;

  IF v_n_results < 1 THEN
    RAISE EXCEPTION 'Test 3 échec : api.search_catalog_v1(''%'') retourne % résultats, '
                    'attendu >= 1. La recherche trigram est cassée.',
      v_test_query, v_n_results;
  END IF;

  -- Test 4 : Vérifier que similarity() est appelable depuis extensions
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'similarity'
      AND n.nspname = 'extensions'
  ) THEN
    RAISE EXCEPTION 'Test 4 échec : extensions.similarity introuvable. '
                    'Le move pg_trgm est incomplet.';
  END IF;

  RAISE NOTICE 'Paquet L.7 vérifications OK :';
  RAISE NOTICE '  - pg_trgm dans schema : %', v_pg_trgm_schema;
  RAISE NOTICE '  - Indexes trigram préservés : %', v_n_indexes;
  RAISE NOTICE '  - api.search_catalog_v1(''%'') retourne : % résultats', v_test_query, v_n_results;
  RAISE NOTICE '  - extensions.similarity disponible : oui';
END $$;

COMMIT;

-- =========================================================================
-- Post-conditions attendues après push :
-- =========================================================================
-- - Le linter Supabase ne signale plus extension_in_public pour pg_trgm
-- - Le catalogue public continue de fonctionner identiquement
-- - Recherche full-text trigram opérationnelle
-- =========================================================================
-- Tests manuels recommandés après push (navigation privée) :
-- =========================================================================
-- 1. https://app.anarbib.org/catalogo (ou URL équivalente)
-- 2. Saisir une recherche : "anarchisme", "liberté", "kropotkine", etc.
-- 3. Vérifier que des résultats apparaissent et que le ranking trigram
--    fonctionne (titres partiels, fautes de frappe tolérées)
-- =========================================================================
-- Vérification SQL post-push :
-- =========================================================================
-- SELECT extname, extnamespace::regnamespace AS schema FROM pg_extension WHERE extname = 'pg_trgm';
-- Résultat attendu : pg_trgm | extensions
-- =========================================================================
-- Rollback ciblé si régression imprévue post-déploiement :
-- =========================================================================
-- BEGIN;
--   ALTER FUNCTION api.search_catalog_v1(text) SET search_path = public, api;
--   ALTER EXTENSION pg_trgm SET SCHEMA public;
-- COMMIT;
-- =========================================================================
-- Doctrine pour le futur :
-- =========================================================================
-- Toute extension ajoutée à l'avenir doit être installée dans le schema
-- `extensions` plutôt que `public` :
--   CREATE EXTENSION my_extension WITH SCHEMA extensions;
-- Les fonctions métier qui utilisent ces extensions doivent inclure
-- `extensions` dans leur search_path :
--   ALTER FUNCTION my.func(...) SET search_path = public, extensions, pg_temp;
-- =========================================================================
