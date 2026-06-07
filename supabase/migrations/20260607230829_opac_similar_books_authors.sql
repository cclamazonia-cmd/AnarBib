-- ════════════════════════════════════════════════════════════════════════════
-- OPAC — Similarite PAR CONTENU (documents similaires + reseau d'auteur*rices)
-- Auteur  : Claude (Opus)
-- Session : Chantier OPAC etape 1 (similaires/reseau)
-- Date    : 2026-06-07 (UTC)
-- Registre: OPAC-SIM1 (#OPAC4 / #AUT1) — recommandation PAR CONTENU SEUL
--           (auteur*rice / CDD / collection), jamais comportementale, sans log
--           de navigation (INV-1 / INV-3 / INV-5). Agrege sur la vue publique.
--
-- api.similar_books(p_book_id bigint) -> documents proches d'une notice :
--   score = 3*(auteur*rice partagee) + 2*(meme division CDD) + 1*(meme collection).
-- api.similar_authors(p_author_id bigint) -> reseau intellectuel d'une autorite :
--   score = 2*(nb livres en aire CDD commune) + 5 si co-signature d'un meme livre.
--
-- SECURITY INVOKER, search_path fige. EXECUTE retire a PUBLIC, accorde a
-- anon + authenticated (catalogue public).
-- ════════════════════════════════════════════════════════════════════════════

-- ── #OPAC4 — Documents similaires ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.similar_books(p_book_id bigint)
RETURNS TABLE (book_id bigint, titulo text, subtitulo text, author_label text,
               ano text, editora text, cover_object_path text, bib_ref text, score integer)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
WITH tgt AS (
  SELECT c.book_id AS bid, left(c.cdd, 3) AS cdd3, NULLIF(btrim(c.colecao), '') AS col,
    (SELECT array_agg(lower(btrim(ch->>'label')))
       FROM jsonb_array_elements(CASE jsonb_typeof(c.author_chips) WHEN 'array' THEN c.author_chips ELSE '[]'::jsonb END) ch
      WHERE btrim(ch->>'label') <> '') AS authors
  FROM api.catalog_list_anon_v1 c WHERE c.book_id = p_book_id LIMIT 1
),
scored AS (
  SELECT c.book_id, c.titulo, c.subtitulo, COALESCE(c.author_display, c.autor) AS author_label,
         c.ano, c.editora, c.cover_object_path, c.bib_ref,
    ( (CASE WHEN t.authors IS NOT NULL AND EXISTS (
          SELECT 1 FROM jsonb_array_elements(CASE jsonb_typeof(c.author_chips) WHEN 'array' THEN c.author_chips ELSE '[]'::jsonb END) ch
          WHERE lower(btrim(ch->>'label')) = ANY(t.authors)) THEN 3 ELSE 0 END)
      + (CASE WHEN t.cdd3 IS NOT NULL AND left(c.cdd, 3) = t.cdd3 THEN 2 ELSE 0 END)
      + (CASE WHEN t.col IS NOT NULL AND NULLIF(btrim(c.colecao), '') = t.col THEN 1 ELSE 0 END)
    )::int AS score
  FROM api.catalog_list_anon_v1 c CROSS JOIN tgt t
  WHERE c.book_id <> t.bid
)
SELECT book_id, titulo, subtitulo, author_label, ano, editora, cover_object_path, bib_ref, score
FROM scored WHERE score > 0
ORDER BY score DESC, ano DESC NULLS LAST, titulo
LIMIT 8;
$function$;

-- ── #AUT1 — Reseau d'auteur*rices ───────────────────────────────────────────
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
    count(DISTINCT abp.book_id) FILTER (WHERE left(c.cdd, 3) IN (SELECT cdd3 FROM tgt_cdd))::int AS shared_cdd_books
  FROM public.author_books_public abp JOIN api.catalog_list_anon_v1 c ON c.book_id = abp.book_id
  WHERE abp.author_id <> p_author_id AND abp.author_id IS NOT NULL
  GROUP BY abp.author_id
)
SELECT aid AS author_id, label,
  (shared_cdd_books * 2 + CASE WHEN aid IN (SELECT aid FROM coauth) THEN 5 ELSE 0 END)::int AS score,
  shared_cdd_books AS shared_count
FROM cand
WHERE shared_cdd_books > 0 OR aid IN (SELECT aid FROM coauth)
ORDER BY score DESC, label
LIMIT 10;
$function$;

-- Doctrine : pas d'EXECUTE par PUBLIC ; catalogue public -> anon + authenticated.
REVOKE EXECUTE ON FUNCTION api.similar_books(bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api.similar_authors(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.similar_books(bigint) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION api.similar_authors(bigint) TO anon, authenticated;
