-- ════════════════════════════════════════════════════════════════════════════
-- Fix : similar_authors shared_count inclut les co-signatures
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-09 (UTC)
--
-- PROBLEME : shared_count ne comptait que les livres dans des categories CDD
-- communes (shared_cdd_books). Un co-auteur sans recouvrement CDD apparaissait
-- dans le reseau intellectuel SANS badge numerique (shared_count = 0).
-- Cas reel : Maurice Joyeux sur la fiche de Hugues Lenoir.
--
-- FIX : shared_count = UNION(livres en CDD communes, livres co-signes).
-- Le scoring reste inchange (CDD * 2 + coauth bonus 5).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.similar_authors(p_author_id bigint)
RETURNS TABLE (author_id bigint, label text, score integer, shared_count integer)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
WITH tgt_books AS (
  SELECT DISTINCT abp.book_id FROM public.author_books_public abp WHERE abp.author_id = p_author_id
),
tgt_cdd AS (
  SELECT DISTINCT left(c.cdd, 3) AS cdd3
  FROM api.catalog_list_anon_v1 c JOIN tgt_books tb ON tb.book_id = c.book_id
  WHERE c.cdd IS NOT NULL AND btrim(c.cdd) <> ''
),
coauth AS (
  SELECT DISTINCT abp.author_id AS aid
  FROM public.author_books_public abp JOIN tgt_books tb ON tb.book_id = abp.book_id
  WHERE abp.author_id <> p_author_id AND abp.author_id IS NOT NULL
),
cand AS (
  SELECT abp.author_id AS aid, max(COALESCE(abp.preferred_name, abp.author_name)) AS label,
    -- Score : base CDD uniquement (inchange)
    count(DISTINCT abp.book_id) FILTER (WHERE left(c.cdd, 3) IN (SELECT cdd3 FROM tgt_cdd))::int AS shared_cdd_books,
    -- Compteur affiche : union CDD communes + co-signatures (fix)
    count(DISTINCT abp.book_id) FILTER (
      WHERE left(c.cdd, 3) IN (SELECT cdd3 FROM tgt_cdd)
         OR abp.book_id IN (SELECT book_id FROM tgt_books)
    )::int AS shared_all
  FROM public.author_books_public abp JOIN api.catalog_list_anon_v1 c ON c.book_id = abp.book_id
  WHERE abp.author_id <> p_author_id AND abp.author_id IS NOT NULL
  GROUP BY abp.author_id
)
SELECT aid AS author_id, label,
  (shared_cdd_books * 2 + CASE WHEN aid IN (SELECT aid FROM coauth) THEN 5 ELSE 0 END)::int AS score,
  shared_all AS shared_count
FROM cand
WHERE shared_all > 0 OR aid IN (SELECT aid FROM coauth)
ORDER BY score DESC, label
LIMIT 10;
$function$;

-- Droits inchanges (deja en place, on les re-affirme par securite)
REVOKE EXECUTE ON FUNCTION api.similar_authors(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.similar_authors(bigint) TO anon, authenticated;
