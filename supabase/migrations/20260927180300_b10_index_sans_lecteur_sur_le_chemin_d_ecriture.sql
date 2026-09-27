-- =========================================================================
-- B10, passe 3 bis — douze index sans lecteur sur le chemin d'écriture
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B10 (hygiène de performance), avis 0005 unused_index ; suit
--            20260927180200 (index redondants jamais empruntés)
--
-- L'INVENTAIRE. Hors clés étrangères et hors redondants, 108 index étaient à
-- zéro scan du 02/09 au 27/09. Chacun a été relu le 27/09 : migration
-- d'origine, puis tout ce qui pourrait l'emprunter — les requêtes réellement
-- exécutées (pg_stat_statements, complet depuis le 02/09), les corps de
-- fonctions et de vues, le front et les Edge Functions. Détail :
-- docs/journal/audits/AUDIT_performance_B10_2026-09-27.md.
--
-- CE QUI EST RETIRÉ ICI, ET POURQUOI CEUX-LÀ. Les index sans aucun lecteur
-- possible qui pèsent sur un chemin d'ÉCRITURE : `books` (27 index, 6,5 Mo,
-- pour 3,8 Mo de données) et `book_drafts` (16) — les tables que remplit un
-- import, chaque index retiré est une écriture de moins par notice —, la
-- table des sondes (5,6 Mo d'index pour 2,9 Mo de données, une écriture toutes
-- les cinq minutes), et un doublon strict. Les autres index sans lecteur sont
-- de petites tables où les retirer ne gagnerait rien, ou attendent une
-- décision de conception (index des vues matérialisées du catalogue,
-- inatteignables derrière leurs enveloppes DEFINER ; index de recherche
-- trigramme que la forme des requêtes empêche d'emprunter) : l'audit les
-- nomme, un par un.
--
-- Pourquoi chacun avait été créé, et pourquoi il ne sert plus :
--   books.holder_library, .owner_library, .partner_source (socle) — colonnes
--     texte héritées, seulement écrites ou recopiées à la publication ; les
--     filtres passent par holder_library_id / owner_library_id (FK indexées).
--   books.isbn, .issn (socle) — btree sur la valeur brute : le front ne fait
--     que `ILIKE '%…%'` (BookDraftForm, CatalogPanel), qu'un btree ne sert
--     pas ; les rapprochements passent par ingest.fn_normalize_isxn(…),
--     indexé à part (idx_books_isbn_norm, idx_books_issn_norm).
--   books.editora, trigramme (socle) — `editora ILIKE` n'existe que sur les
--     lignes de la vue du catalogue (catalog_works_v1, catalog_facets_v1 :
--     source `__VIEW__`), jamais sur books.
--   book_drafts.holder_library, .mutualization_status (socle) — seulement
--     écrites ou recopiées.
--   book_drafts.owner_library (socle) — un seul prédicat, `IS DISTINCT FROM`
--     dans un UPDATE borné par batch_id (fn_batch_reassign_library) : ni
--     indexable, ni sélectif.
--   book_drafts.partner_source (socle) — un seul prédicat, `IS NOT NULL`
--     dans un OU, à l'intérieur d'un EXISTS borné par batch_id
--     (fn_batch_is_imported).
--   service_health_probes (endpoint, checked_at DESC) (17/08, créé avec
--     l'index sur checked_at, sans commentaire) — aucune requête ne filtre ni
--     ne trie d'abord par endpoint : health-probe lit et purge par checked_at
--     (idx_shp_checked_at, 19 081 scans). Il pesait 3,5 Mo, 3,5 fois l'index
--     qui sert : cinq points d'insertion au milieu, la purge à l'autre bout.
--   reader_card_tokens (token_hash) WHERE status = 'active' (socle) — la
--     seule lecture (api.resolve_reader_card) filtre token_hash SANS prédicat
--     de statut : l'index partiel ne peut pas la servir, l'unique
--     reader_card_tokens_token_hash_key la sert.
--
-- Garde de sortie : aucune clé étrangère n'a perdu son index de support, et
-- les douze sont partis. Retour arrière : les CREATE INDEX du socle
-- (20260510000000) et de 20260817142739.
-- =========================================================================

BEGIN;

DO $garde$
DECLARE v_fk int;
BEGIN
  SELECT count(*) INTO v_fk
  FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
  WHERE c.contype = 'f' AND n.nspname IN ('public', 'ingest')
    AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.conrelid
                      AND (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey);
  PERFORM set_config('b10.fk_avant_3bis', v_fk::text, true);
END
$garde$;

DROP INDEX IF EXISTS public.idx_books_holder_library;
DROP INDEX IF EXISTS public.idx_books_owner_library;
DROP INDEX IF EXISTS public.idx_books_partner_source;
DROP INDEX IF EXISTS public.idx_books_isbn;
DROP INDEX IF EXISTS public.idx_books_issn;
DROP INDEX IF EXISTS public.idx_books_editora_trgm;
DROP INDEX IF EXISTS public.idx_book_drafts_holder_library;
DROP INDEX IF EXISTS public.idx_book_drafts_owner_library;
DROP INDEX IF EXISTS public.idx_book_drafts_partner_source;
DROP INDEX IF EXISTS public.idx_book_drafts_mutualization_status;
DROP INDEX IF EXISTS public.idx_shp_endpoint;
DROP INDEX IF EXISTS public.idx_reader_card_tokens_hash;

DO $sortie$
DECLARE v_fk int; v_reste text;
BEGIN
  SELECT count(*) INTO v_fk
  FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
  WHERE c.contype = 'f' AND n.nspname IN ('public', 'ingest')
    AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.conrelid
                      AND (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey);
  IF v_fk <> current_setting('b10.fk_avant_3bis')::int THEN
    RAISE EXCEPTION 'B10 passe 3 bis : % clés étrangères sans index après retrait, % avant', v_fk, current_setting('b10.fk_avant_3bis');
  END IF;
  SELECT string_agg(x, ', ') INTO v_reste
  FROM unnest(ARRAY['idx_books_holder_library', 'idx_books_owner_library', 'idx_books_partner_source',
                    'idx_books_isbn', 'idx_books_issn', 'idx_books_editora_trgm',
                    'idx_book_drafts_holder_library', 'idx_book_drafts_owner_library',
                    'idx_book_drafts_partner_source', 'idx_book_drafts_mutualization_status',
                    'idx_shp_endpoint', 'idx_reader_card_tokens_hash']) x
  WHERE to_regclass('public.' || x) IS NOT NULL;
  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'B10 passe 3 bis : toujours là : %', v_reste;
  END IF;
END
$sortie$;

COMMIT;
