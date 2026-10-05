-- =========================================================================
-- La liste du catalogue nomme aussi les coauteur·rices (CAT-G4).
-- =========================================================================
-- Date     : 2026-10-05
-- Chantier : OPAC — liste du catalogue (author_display, author_chips)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Doublons SNI & forme autorisée des contributeurs
--
-- Demande de Xavier, 05/10/2026 : aligner la liste du catalogue sur les
-- citations (3fc8656a), qui retiennent `autor` ET `coautor` comme
-- responsables principaux. v_book_authors_canonical — d'où viennent
-- author_display et author_chips de la liste, des vues matérialisées
-- mv_books_catalog_list_v1 / _network_v1 et de la fiche — ne retenait que
-- `autor` : un coauteur n'apparaissait ni dans la liste, ni comme auteur·rice
-- de repli ; et un livre n'ayant QUE des coauteurs basculait sur
-- l'organisation (has_autor = faux).
--
-- Deux changements, rien d'autre : `coautor` compte comme auteur·rice dans
-- per_book.has_autor et dans le filtre de canon_source. Vue reprise de sa
-- définition en production (pg_get_viewdef, 05/10) ; mêmes colonnes, donc
-- CREATE OR REPLACE ; security_invoker = true conservé (déjà le cas) ; les
-- droits sont gardés par le REPLACE. En production le 05/10 : un seul livre
-- a un coauteur (et un auteur). Les vues matérialisées se rafraîchissent par
-- le job cron refresh-mv-books-catalog-list (toutes les 15 min) : rien à
-- rafraîchir ici.
-- =========================================================================

CREATE OR REPLACE VIEW public.v_book_authors_canonical
WITH (security_invoker = true) AS
 WITH per_book AS (
         SELECT bc.book_id,
            bool_or((bc.role = ANY (ARRAY['autor'::text, 'coautor'::text]))) AS has_autor
           FROM book_contributors bc
          GROUP BY bc.book_id
        ), canon_source AS (
         SELECT bc.book_id,
            bc.author_id,
            bc."position" AS ord,
            COALESCE(NULLIF(btrim(a.sort_name), ''::text), NULLIF(btrim(a.preferred_name), ''::text), NULLIF(btrim(bc.name), ''::text)) AS base_name
           FROM (((book_contributors bc
             LEFT JOIN authors a ON ((a.id = bc.author_id)))
             LEFT JOIN books b ON ((b.id = bc.book_id)))
             LEFT JOIN per_book pb ON ((pb.book_id = bc.book_id)))
          WHERE ((bc.role = ANY (ARRAY['autor'::text, 'coautor'::text])) OR ((pb.has_autor = false) AND (((b.tipo_material = 'audiovisual'::text) AND (bc.role = 'realizador'::text)) OR ((b.tipo_material = 'audio'::text) AND (bc.role = 'compositor'::text)) OR ((COALESCE(b.tipo_material, ''::text) <> ALL (ARRAY['audiovisual'::text, 'audio'::text])) AND (bc.role = ANY (ARRAY['organizador'::text, 'organizacao'::text, 'coordenador'::text, 'coletivo'::text]))))))
        ), canon AS (
         SELECT cs.book_id,
            cs.author_id,
            cs.ord,
                CASE
                    WHEN (cs.base_name IS NULL) THEN NULL::text
                    WHEN (POSITION((','::text) IN (cs.base_name)) > 0) THEN (upper(btrim(split_part(cs.base_name, ','::text, 1))) ||
                    CASE
                        WHEN (NULLIF(btrim(SUBSTRING(cs.base_name FROM (POSITION((','::text) IN (cs.base_name)) + 1))), ''::text) IS NOT NULL) THEN (', '::text || btrim(SUBSTRING(cs.base_name FROM (POSITION((','::text) IN (cs.base_name)) + 1))))
                        ELSE ''::text
                    END)
                    ELSE cs.base_name
                END AS display_name
           FROM canon_source cs
        )
 SELECT book_id,
    string_agg(display_name, ' ; '::text ORDER BY ord, display_name) AS author_display,
    jsonb_agg(jsonb_build_object('author_id', author_id, 'label', display_name, 'ord', ord) ORDER BY ord, display_name) AS author_chips
   FROM canon
  GROUP BY book_id;
