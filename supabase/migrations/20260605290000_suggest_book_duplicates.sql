-- =========================================================================
-- Paquet doublons P2a — detection de doublons de documents (lecture seule)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Doublons (spec-doublons-detection-fusion v0.1)
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- suggest_book_duplicates(book_id) : autres livres candidats doublons.
--   - ISBN normalise identique  -> match 'isbn' (signal fort, score 1.0)
--   - sinon titre proche ET auteur proche (trigramme) -> 'approx'
-- Lecture seule : aucune fusion ici (P2b traitera merge_book). Le staff juge
-- (edition distincte vs vrai doublon). Renvoie le nb d'exemplaires pour aider
-- a choisir le canonique.
--
-- DOCTRINE : SECURITY DEFINER + search_path (avec extensions pour pg_trgm) +
-- REVOKE PUBLIC + GRANT staff.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.suggest_book_duplicates(p_book_id bigint)
RETURNS TABLE (
  book_id     bigint,
  titulo      text,
  autor       text,
  ano         text,
  editora     text,
  isbn        text,
  exemplares  integer,
  match_kind  text,
  score       real
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $function$
DECLARE
  v_isbn   text;
  v_title  text;
  v_author text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  SELECT regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g'),
         public.fn_normalize_name(b.titulo),
         public.fn_normalize_name(b.autor)
    INTO v_isbn, v_title, v_author
    FROM public.books b WHERE b.id = p_book_id;

  IF v_title IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH other AS (
    SELECT b.id, b.titulo, b.autor, b.ano, b.editora, b.isbn,
           regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') AS ni,
           public.fn_normalize_name(b.titulo) AS nt,
           public.fn_normalize_name(b.autor) AS na
    FROM public.books b
    WHERE b.id <> p_book_id
  )
  SELECT o.id, o.titulo, o.autor, o.ano, o.editora, o.isbn,
         (SELECT coalesce(sum(h.exemplares_total), 0)::integer
            FROM public.book_holdings h WHERE h.book_id = o.id),
         CASE WHEN v_isbn <> '' AND o.ni = v_isbn THEN 'isbn' ELSE 'approx' END,
         CASE WHEN v_isbn <> '' AND o.ni = v_isbn THEN 1.0::real
              ELSE similarity(o.nt, v_title)::real END
  FROM other o
  WHERE (v_isbn <> '' AND o.ni = v_isbn)
     OR (o.nt <> ''
         AND similarity(o.nt, v_title) >= 0.5
         AND (v_author = '' OR o.na = '' OR similarity(o.na, v_author) >= 0.4))
  ORDER BY 9 DESC, o.titulo
  LIMIT 50;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.suggest_book_duplicates(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.suggest_book_duplicates(bigint) TO authenticated;

COMMENT ON FUNCTION public.suggest_book_duplicates(bigint) IS
  'Livres candidats doublons (ISBN exact + titre/auteur trigramme). Lecture seule. Paquet doublons P2a du 05/06/2026.';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : DROP FUNCTION IF EXISTS public.suggest_book_duplicates(bigint);
-- =========================================================================
