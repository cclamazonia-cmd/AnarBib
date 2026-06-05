-- =========================================================================
-- Paquet fix — v_book_authors_canonical : tous les contributeurs dans le
-- catalogue liste (MV)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites / catalogue liste (#CAT-LIST-AUTEURS-INCOMPLETE)
-- Auteur   : Xavier + Claude
--
-- PROBLEME
-- --------
-- La MV mv_books_catalog_list_network_v1 joint v_book_authors_canonical pour
-- ses colonnes author_display / author_chips. Cette vue partait de
-- book_authors JOIN authors : elle ne voyait donc QUE les contributeurs LIES
-- a une autorite (author_id NOT NULL). Quand un livre a un mix de
-- contributeurs lies et non lies, les non lies disparaissent du catalogue.
--
-- Ex. "Maio de 68" (book_id 1633) : 4 contributeurs de role 'autor', mais
-- seuls JOYEUX (lie 10014) et LENOIR (lie 10120) avaient une ligne
-- book_authors. DUTEUIL et HERNANDEZ (author_id NULL) etaient absents de la
-- liste catalogue alors qu'ils figurent dans books.autor et sur la fiche.
--
-- Le COALESCE(c.author_display, b.autor) cote MV ne corrige rien :
-- c.author_display est non NULL des qu'un seul contributeur est lie — le
-- fallback b.autor ne se declenche jamais ici.
--
-- CORRECTIF
-- ---------
-- Reecrire v_book_authors_canonical pour partir de book_contributors (TOUS
-- les contributeurs) au lieu de book_authors (lies seulement), en
-- PRESERVANT le contrat existant :
--   * meme filtre role = 'autor' (traducteurs/organisateurs restent hors de
--     la colonne auteur) ;
--   * meme canonicalisation du nom (NOM de famille en majuscules avant la
--     virgule), avec la fiche authors comme source pour les contributeurs
--     lies et book_contributors.name (deja au meme format) en fallback pour
--     les non lies ;
--   * memes colonnes en sortie : book_id (bigint), author_display (text),
--     author_chips (jsonb) — compatible CREATE OR REPLACE VIEW.
-- Les chips conservent author_id (NULL si non lie) : le frontend rend un
-- lien /autor/:id si present, du texte sinon (cf. CatalogPage.AuthorLinks).
--
-- Definition d'origine sauvegardee en pied de fichier (rollback).
-- =========================================================================

BEGIN;

CREATE OR REPLACE VIEW public.v_book_authors_canonical
WITH (security_invoker = true)
AS
 WITH canon_source AS (
         SELECT bc.book_id,
            bc.author_id,
            bc.position AS ord,
            COALESCE(
              NULLIF(btrim(a.sort_name), ''),
              NULLIF(btrim(a.preferred_name), ''),
              NULLIF(btrim(bc.name), '')
            ) AS base_name
           FROM book_contributors bc
             LEFT JOIN authors a ON a.id = bc.author_id
          WHERE bc.role = 'autor'::text
        ), canon AS (
         SELECT canon_source.book_id,
            canon_source.author_id,
            canon_source.ord,
                CASE
                    WHEN canon_source.base_name IS NULL THEN NULL::text
                    WHEN POSITION((','::text) IN (canon_source.base_name)) > 0 THEN upper(TRIM(BOTH FROM split_part(canon_source.base_name, ','::text, 1))) ||
                    CASE
                        WHEN NULLIF(TRIM(BOTH FROM SUBSTRING(canon_source.base_name FROM POSITION((','::text) IN (canon_source.base_name)) + 1)), ''::text) IS NOT NULL THEN ', '::text || TRIM(BOTH FROM SUBSTRING(canon_source.base_name FROM POSITION((','::text) IN (canon_source.base_name)) + 1))
                        ELSE ''::text
                    END
                    ELSE canon_source.base_name
                END AS display_name
           FROM canon_source
        )
 SELECT book_id,
    string_agg(display_name, ' ; '::text ORDER BY ord, display_name) AS author_display,
    jsonb_agg(jsonb_build_object('author_id', author_id, 'label', display_name, 'ord', ord) ORDER BY ord, display_name) AS author_chips
   FROM canon
  GROUP BY book_id;

-- ---------------------------------------------------------------------------
-- Verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- a. la vue reference bien book_contributors
  SELECT count(*) INTO v_count
    FROM information_schema.view_column_usage
   WHERE view_schema = 'public'
     AND view_name   = 'v_book_authors_canonical'
     AND table_name  = 'book_contributors';
  IF v_count < 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : v_book_authors_canonical ne reference pas book_contributors';
  END IF;

  -- b. memes 3 colonnes en sortie (contrat MV inchange)
  SELECT count(*) INTO v_count
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'v_book_authors_canonical'
     AND column_name IN ('book_id', 'author_display', 'author_chips');
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'VERIF_FAIL_b : colonnes de v_book_authors_canonical alterees (%/3)', v_count;
  END IF;

  -- c. security_invoker = true preserve (doctrine vues)
  SELECT count(*) INTO v_count
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'v_book_authors_canonical'
     AND c.reloptions @> ARRAY['security_invoker=true'];
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_c : v_book_authors_canonical n''est pas security_invoker=true';
  END IF;

  RAISE NOTICE 'fix_catalog_list_all_contributors — v_book_authors_canonical reecrite sur book_contributors OK';
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Apres COMMIT : REFRESH pour propager les nouvelles donnees a la MV.
-- REFRESH NON concurrent, aligne sur le pattern de paquetC5
-- (20260519200000) : un REFRESH CONCURRENTLY ne peut pas s'executer dans un
-- bloc transactionnel, et la CLI Supabase peut envelopper la migration.
-- =========================================================================
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

-- =========================================================================
-- Rollback : restaurer la definition d'origine (basee sur book_authors).
-- -------------------------------------------------------------------------
-- CREATE OR REPLACE VIEW public.v_book_authors_canonical AS
--  WITH canon_source AS (
--          SELECT ba.book_id, ba.author_id, min(ba.ord) AS ord,
--             COALESCE(NULLIF(TRIM(BOTH FROM a.sort_name), ''::text),
--                      NULLIF(TRIM(BOTH FROM a.preferred_name), ''::text)) AS base_name
--            FROM book_authors ba JOIN authors a ON a.id = ba.author_id
--           WHERE ba.role = 'autor'::text
--           GROUP BY ba.book_id, ba.author_id, a.sort_name, a.preferred_name
--         ), canon AS ( ... idem ... )
--  SELECT book_id,
--     string_agg(display_name, ' ; ' ORDER BY ord, display_name) AS author_display,
--     jsonb_agg(jsonb_build_object('author_id', author_id, 'label', display_name, 'ord', ord)
--               ORDER BY ord, display_name) AS author_chips
--    FROM canon GROUP BY book_id;
-- Puis : REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
-- =========================================================================
