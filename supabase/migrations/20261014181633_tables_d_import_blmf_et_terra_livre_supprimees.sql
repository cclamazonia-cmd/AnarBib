-- ===========================================================================
-- Trois tables de staging d'import supprimées, avec les deux vues qui
-- lisaient l'une d'elles. Décision de Xavier, par écrit, le 14/10/2026 :
-- « Supprime les trois tables d'import BLMF et Terra Livre. »
--
--   public.import_blmf_books_rows             (236 lignes, 120 kB)
--   public.import_blmf_exemplares_rows        (243 lignes,  56 kB)
--   public.import_terra_livre_zotero_staging  (2 265 lignes, 1,4 MB)
--   public.v_terra_livre_books_ready          (vue sur la précédente)
--   public.v_terra_livre_books_ready_stats    (vue sur la précédente)
--
-- Ce sont les dumps figés des imports d'avant le module d'importation (BLMF au
-- printemps 2026, Terra Livre par Zotero ; CADRAGE_importacoes_module
-- 2026-06-04). RLS active, aucune politique, aucun droit pour anon ni
-- authenticated : elles portaient trois des 32 avis `rls_enabled_no_policy`.
--
-- Qui les lisait, relevé en production le 14/10 : aucune fonction (prosrc),
-- aucune politique, aucun cron, aucune clé étrangère ; seules les deux vues,
-- qu'aucune fonction ni aucun fichier du dépôt ne lit. Leur dernier parcours
-- (11/10, 18 h 20 UTC) est celui du pg_dump du dimanche. Dans le dépôt :
--   * scripts/purge-orphelins-covers.py lisait import_blmf_books_rows comme
--     troisième source de références de capas. Une seule capa présente au
--     bucket n'était référencée que là — books/0000142/1773146137620-2.webp,
--     ancienne version d'une notice qui porte déjà front.jpg : la purge la
--     classera « B, version remplacée », ce qui est juste. Le script ne lit
--     plus que books et book_drafts (même commit) ;
--   * deploy/bootstrap.sh (tables sans politique attendues) et
--     deploy/bg2-known-tables.txt (classement des sauvegardes) : les trois
--     lignes retirées (même commit).
--
-- Les données restent dans les sauvegardes #BG2 (flux restic, rétention
-- 7 quotidiens / 4 hebdomadaires / 6 mensuels) jusqu'à leur expiration.
--
-- Sans CASCADE : un objet resté dessus ferait échouer la migration au lieu de
-- disparaître en silence. Les vues d'abord, la vue de vue en premier.
-- ===========================================================================

DROP VIEW public.v_terra_livre_books_ready_stats;
DROP VIEW public.v_terra_livre_books_ready;
DROP TABLE public.import_terra_livre_zotero_staging;
DROP TABLE public.import_blmf_exemplares_rows;
DROP TABLE public.import_blmf_books_rows;

DO $garde$
BEGIN
  IF to_regclass('public.import_blmf_books_rows') IS NOT NULL
     OR to_regclass('public.import_blmf_exemplares_rows') IS NOT NULL
     OR to_regclass('public.import_terra_livre_zotero_staging') IS NOT NULL
     OR to_regclass('public.v_terra_livre_books_ready') IS NOT NULL
     OR to_regclass('public.v_terra_livre_books_ready_stats') IS NOT NULL
     OR to_regclass('public.import_terra_livre_zotero_staging_id_seq') IS NOT NULL THEN
    RAISE EXCEPTION 'tables d''import : un objet a survécu au DROP';
  END IF;
  -- Un corps de fonction n'est pas dans pg_depend : son texte.
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
                AND p.prosrc ~ '\m(import_blmf_books_rows|import_blmf_exemplares_rows|import_terra_livre_zotero_staging|v_terra_livre_books_ready)\M') THEN
    RAISE EXCEPTION 'tables d''import : une fonction les nomme encore';
  END IF;
END
$garde$;
