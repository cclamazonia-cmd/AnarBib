-- =========================================================================
-- Un contributeur lié se nomme d'une seule forme : son point d'accès
-- (authors.sort_name, casse naturelle — « Russell, Bertrand »).
-- =========================================================================
-- Date     : 2026-10-05
-- Chantier : OPAC — liste du catalogue, page Œuvre (CAT-G4, amende DOC-CONV-1)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Doublons SNI & forme autorisée des contributeurs
--
-- Décision de Xavier, 05/10/2026 : une forme unique pour nommer un
-- contributeur lié dans une notice, une liste ou une citation — le point
-- d'accès en casse naturelle. Jusqu'ici, trois rendus d'une même autorité
-- coexistaient (DOC-CONV-1, 20/08) : « Bertrand Russell » sur la fiche
-- (preferred_name), « RUSSELL, Bertrand » dans la liste (capitales calculées
-- par v_book_authors_canonical), « Russell, Bertrand » dans les citations
-- (sort_name). Le titre d'une page d'autorité reste en ordre direct
-- (preferred_name) : elle nomme la personne, pas un contributeur.
--
-- (1) v_book_authors_canonical (author_display / author_chips de la liste,
--     des vues matérialisées et de la fiche) : le nom n'est plus mis en
--     capitales ; un lié s'y nomme par son sort_name tel quel, un non lié
--     par sa transcription. Et `editor` rejoint les rôles de repli de
--     l'écrit, comme dans les citations (3fc8656a). Mêmes colonnes :
--     CREATE OR REPLACE, security_invoker = true conservé, droits gardés.
-- (2) api.work_public_detail (page Œuvre) : l'auteur·rice (author_name) et
--     les traducteur·rices se nomment par sort_name (repli preferred_name).
--     Fonction reprise de sa définition en production ; même signature,
--     droits gardés.
-- Les vues matérialisées suivent par le job cron (15 min).
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
          WHERE ((bc.role = ANY (ARRAY['autor'::text, 'coautor'::text])) OR ((pb.has_autor = false) AND (((b.tipo_material = 'audiovisual'::text) AND (bc.role = 'realizador'::text)) OR ((b.tipo_material = 'audio'::text) AND (bc.role = 'compositor'::text)) OR ((COALESCE(b.tipo_material, ''::text) <> ALL (ARRAY['audiovisual'::text, 'audio'::text])) AND (bc.role = ANY (ARRAY['organizador'::text, 'organizacao'::text, 'coordenador'::text, 'coletivo'::text, 'editor'::text]))))))
        ), canon AS (
         SELECT cs.book_id,
            cs.author_id,
            cs.ord,
            cs.base_name AS display_name
           FROM canon_source cs
        )
 SELECT book_id,
    string_agg(display_name, ' ; '::text ORDER BY ord, display_name) AS author_display,
    jsonb_agg(jsonb_build_object('author_id', author_id, 'label', display_name, 'ord', ord) ORDER BY ord, display_name) AS author_chips
   FROM canon
  GROUP BY book_id;

CREATE OR REPLACE FUNCTION api.work_public_detail(p_work_id bigint, p_lang text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  WITH rows AS (
    SELECT c.book_id, c.titulo, c.ano, c.editora, b.idioma, c.cover_object_path, c.bib_ref, b.expression_id,
           NULLIF(btrim(b.volume), '') AS volume
    FROM api.catalog_list_anon_v1 c
    JOIN public.books b ON b.id = c.book_id
    WHERE b.work_id = p_work_id
  ),
  eds AS (SELECT count(*) n FROM rows),
  counts AS (
    SELECT
      (SELECT count(*) FROM rows WHERE volume IS NULL)::int
      + (SELECT count(*) FROM (SELECT DISTINCT ano, editora, idioma FROM rows WHERE volume IS NOT NULL) k)::int AS edition_count,
      (SELECT count(DISTINCT volume) FROM rows WHERE volume IS NOT NULL)::int AS volume_count
  ),
  trans AS (
    SELECT r.expression_id AS eid,
           jsonb_agg(DISTINCT jsonb_build_object('author_id', a2.id, 'name', COALESCE(NULLIF(btrim(a2.sort_name), ''), a2.preferred_name))) tr
    FROM rows r
    JOIN public.book_contributors bc ON bc.book_id = r.book_id AND bc.role = 'tradutor' AND bc.author_id IS NOT NULL
    JOIN public.authors a2 ON a2.id = bc.author_id
    GROUP BY r.expression_id
  ),
  flat AS (
    SELECT jsonb_agg(jsonb_build_object('book_id', r.book_id, 'titulo', r.titulo, 'ano', r.ano, 'editora', r.editora, 'idioma', r.idioma, 'cover_object_path', r.cover_object_path, 'bib_ref', r.bib_ref, 'volume', r.volume)
           ORDER BY NULLIF(substring(r.ano FROM '\d{4}'), '')::int NULLS LAST,
                    public.fn_volume_rank(r.volume) NULLS LAST, r.volume NULLS LAST, r.titulo) arr
    FROM rows r
  ),
  expr AS (
    SELECT jsonb_agg(g.e ORDER BY g.lang) arr FROM (
      SELECT COALESCE(we.lang, '') AS lang,
        jsonb_build_object('lang', COALESCE(we.lang, ''),
          'editions', jsonb_agg(jsonb_build_object('book_id', r.book_id, 'titulo', r.titulo, 'ano', r.ano, 'editora', r.editora, 'idioma', r.idioma, 'cover_object_path', r.cover_object_path, 'bib_ref', r.bib_ref, 'volume', r.volume)
            ORDER BY NULLIF(substring(r.ano FROM '\d{4}'), '')::int NULLS LAST,
                     public.fn_volume_rank(r.volume) NULLS LAST, r.volume NULLS LAST, r.titulo),
          'translators', COALESCE((SELECT tr FROM trans WHERE trans.eid = r.expression_id), '[]'::jsonb)) AS e
      FROM rows r LEFT JOIN public.work_expressions we ON we.id = r.expression_id
      GROUP BY r.expression_id, COALESCE(we.lang, '')
    ) g
  ),
  titles AS (
    SELECT COALESCE(jsonb_object_agg(t.lang, jsonb_build_object('title', t.title, 'source', t.source, 'needs_review', t.needs_review)), '{}'::jsonb) obj
    FROM public.work_titles t WHERE t.work_id = p_work_id
  )
  SELECT CASE WHEN (SELECT n FROM eds) = 0 THEN NULL
    ELSE jsonb_build_object(
      'id', w.id, 'uniform_title', w.uniform_title,
      'display_title', public.fn_work_display_title(w.id, COALESCE(NULLIF(p_lang, ''), 'pt-BR')),
      'titles', (SELECT obj FROM titles),
      'primary_author_id', w.primary_author_id, 'author_name', COALESCE(NULLIF(btrim(a.sort_name), ''), a.preferred_name),
      'edition_count', (SELECT edition_count FROM counts),
      'volume_count', (SELECT volume_count FROM counts),
      'editions', COALESCE((SELECT arr FROM flat), '[]'::jsonb),
      'expressions', COALESCE((SELECT arr FROM expr), '[]'::jsonb)
    ) END
  FROM public.works w
  LEFT JOIN public.authors a ON a.id = w.primary_author_id
  WHERE w.id = p_work_id;
$function$;
