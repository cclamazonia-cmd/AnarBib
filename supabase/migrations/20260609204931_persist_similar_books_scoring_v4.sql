-- ════════════════════════════════════════════════════════════════════════════
-- Persister api.similar_books() scoring v4 (déployé par ALTER direct le 08/06)
-- Auteur  : Claude (Opus)
-- Session : Enrichissement données & backlog
-- Date    : 2026-06-09 (UTC)
--
-- La migration 20260607230829 contenait la v1 du scoring (3/2/1, LIMIT 8,
-- pas de sujets). La v4 a été déployée directement en prod via ALTER mais
-- n'était persistée dans aucune migration → risque de régression si la DB
-- est reconstruite depuis les migrations.
--
-- Scoring v4 :
--   5 × auteur·ice partagé·e
--   2 × count(sujets en commun via book_subjects)
--   2 × même division CDD (3 premiers caractères)
--   1 × CDD exact identique
--   1 × même collection
--   LIMIT 16
--
-- SECURITY INVOKER, search_path figé. Pas de changement de GRANTs
-- (déjà accordés dans la migration originale 20260607230829).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.similar_books(p_book_id bigint)
RETURNS TABLE (book_id bigint, titulo text, subtitulo text, author_label text,
               ano text, editora text, cover_object_path text, bib_ref text, score integer)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
WITH tgt AS (
  SELECT c.book_id AS bid,
         NULLIF(btrim(c.cdd), '') AS full_cdd,
         left(c.cdd, 3) AS cdd3,
         NULLIF(btrim(c.colecao), '') AS col,
    (SELECT array_agg(lower(btrim(ch->>'label')))
       FROM jsonb_array_elements(CASE jsonb_typeof(c.author_chips) WHEN 'array' THEN c.author_chips ELSE '[]'::jsonb END) ch
      WHERE btrim(ch->>'label') <> '') AS authors
  FROM api.catalog_list_anon_v1 c WHERE c.book_id = p_book_id LIMIT 1
),
tgt_subjects AS (
  SELECT array_agg(subject_id) AS sids
  FROM public.book_subjects WHERE book_id = p_book_id
),
scored AS (
  SELECT c.book_id, c.titulo, c.subtitulo, COALESCE(c.author_display, c.autor) AS author_label,
         c.ano, c.editora, c.cover_object_path, c.bib_ref,
    ( -- Auteur·ice partagé·e : 5 points
      (CASE WHEN t.authors IS NOT NULL AND EXISTS (
          SELECT 1 FROM jsonb_array_elements(CASE jsonb_typeof(c.author_chips) WHEN 'array' THEN c.author_chips ELSE '[]'::jsonb END) ch
          WHERE lower(btrim(ch->>'label')) = ANY(t.authors)) THEN 5 ELSE 0 END)
      -- Sujets partagés : 2 points PAR sujet en commun
      + COALESCE((SELECT 2 * count(*)
          FROM public.book_subjects bs
          WHERE bs.book_id = c.book_id
            AND ts.sids IS NOT NULL
            AND bs.subject_id = ANY(ts.sids)
        ), 0)
      -- Même division CDD (3 premiers caractères) : 2 points
      + (CASE WHEN t.cdd3 IS NOT NULL AND left(c.cdd, 3) = t.cdd3 THEN 2 ELSE 0 END)
      -- Bonus CDD exact : +1 point si CDD identique au complet
      + (CASE WHEN t.full_cdd IS NOT NULL AND btrim(c.cdd) = t.full_cdd THEN 1 ELSE 0 END)
      -- Même collection : 1 point
      + (CASE WHEN t.col IS NOT NULL AND NULLIF(btrim(c.colecao), '') = t.col THEN 1 ELSE 0 END)
    )::int AS score
  FROM api.catalog_list_anon_v1 c
  CROSS JOIN tgt t
  CROSS JOIN tgt_subjects ts
  WHERE c.book_id <> t.bid
)
SELECT book_id, titulo, subtitulo, author_label, ano, editora, cover_object_path, bib_ref, score
FROM scored WHERE score > 0
ORDER BY score DESC, ano DESC NULLS LAST, titulo
LIMIT 16;
$function$;

-- GRANTs déjà en place depuis 20260607230829 — pas besoin de les redéclarer.
-- NOTIFY PostgREST pour recharger le schéma API.
NOTIFY pgrst, 'reload schema';
