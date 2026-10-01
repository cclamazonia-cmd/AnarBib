-- =========================================================================
-- La recherche du catalogue départage ses rangs par book_id, en toutes lettres
-- =========================================================================
-- Date     : 2026-10-01
-- Chantier : recherche du catalogue (suite de 20261001190729)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Recherche catalogue — auteur·rice et titres d'œuvre
--
-- LE CONSTAT. 20261001190729 a écrit l'ordre de api.catalog_search_ids_v1
-- par positions (`order by 2 desc nulls last, 1`). C'est le même ordre
-- total qu'avant (rang décroissant, book_id départage), mais le contrat que
-- garde tests/sql/catalogue_grande_echelle_tests.sql (T7) l'exige écrit
-- `nulls last, s.book_id` dans les deux branches — la suite sql-tests du
-- run 1486 est rouge pour cette seule raison.
--
-- LE GESTE. Remplacer `nulls last, 1` par `nulls last, s.book_id` dans les
-- deux branches (deux occurrences exactement, sur la définition réelle,
-- gardée par la présence des titres d'œuvre). Le rang reste désigné par sa
-- position : `rank` nu serait ambigu avec la colonne OUT du même nom.
-- Rien d'autre ne change.
-- =========================================================================

BEGIN;

DO $departage$
DECLARE
  v_old text := 'order by 2 desc nulls last, 1';
  v_new text := 'order by 2 desc nulls last, s.book_id';
  v_def text;
  v_n   int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  IF v_def NOT LIKE '%coalesce(o.titres, '''')%' THEN
    RAISE EXCEPTION 'départage : api.catalog_search_ids_v1 n''est pas la version 20261001190729 (titres d''œuvre absents)';
  END IF;
  v_n := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'départage : ordre par positions attendu deux fois, trouvé % fois', v_n;
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$departage$;

DO $verif$
DECLARE v_src text;
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  IF (SELECT count(*) FROM regexp_matches(v_src, 'nulls last, s\.book_id', 'g')) <> 2
     OR v_src LIKE '%nulls last, 1%' THEN
    RAISE EXCEPTION 'départage : api.catalog_search_ids_v1 n''a pas la forme attendue';
  END IF;
END
$verif$;

COMMIT;
