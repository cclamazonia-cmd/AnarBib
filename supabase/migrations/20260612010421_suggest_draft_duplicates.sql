-- ════════════════════════════════════════════════════════════════════════════
-- Détection de doublons dans la FILE ÉDITORIALE — api.suggest_draft_duplicates
-- Auteur  : Claude (Opus)
-- Session : Catalogação work completion
-- Date    : 2026-06-12 (UTC)
--
-- Pendant de `suggest_book_duplicates` (qui ne vise que `public.books`), pour les
-- BROUILLONS. Pour un brouillon donné, retourne les candidats doublons pris :
--   • parmi les AUTRES brouillons EN ATTENTE (status='draft') de la MÊME biblio
--     (owner_library_id) — pas de fuite inter-biblio des brouillons ;
--   • parmi le CATALOGUE PUBLIÉ (`public.books`, partagé), en excluant le livre que
--     le brouillon édite éventuellement (published_book_id) pour éviter l'auto-match.
-- Scoring IDENTIQUE à suggest_book_duplicates (logique éprouvée, persistée) :
--   ISBN normalisé exact → 'isbn' (1.0) ; sinon similarité titre (≥0.5) + auteur
--   (≥0.4 ou vide) via pg_trgm → 'approx' (score = similarity titre).
-- Renvoie les CHAMPS CRUCIAUX pour la comparaison côté UI + `source` (draft|book).
-- Staff-only (librarian/coordenador). Additif : aucune table/objet existant modifié.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.suggest_draft_duplicates(p_draft_id bigint)
RETURNS TABLE(
  candidate_id   bigint,
  source         text,        -- 'draft' (autre brouillon) | 'book' (publié)
  titulo         text,
  subtitulo      text,
  autor          text,
  ano            text,
  editora        text,
  isbn           text,
  cdd            text,
  colecao        text,
  idioma         text,
  tipo_material  text,
  match_kind     text,        -- 'isbn' | 'approx'
  score          real
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
DECLARE
  v_isbn   text;
  v_title  text;
  v_author text;
  v_lib    uuid;
  v_pub    bigint;
BEGIN
  -- Garde catalogage (même contrat que suggest_book_duplicates).
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  SELECT regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g'),
         public.fn_normalize_name(d.titulo),
         public.fn_normalize_name(d.autor),
         d.owner_library_id,
         d.published_book_id
    INTO v_isbn, v_title, v_author, v_lib, v_pub
    FROM public.book_drafts d
   WHERE d.id = p_draft_id;

  IF v_title IS NULL THEN
    RETURN;  -- brouillon inexistant ou sans titre : rien à comparer
  END IF;

  RETURN QUERY
  WITH cand AS (
    -- Autres brouillons EN ATTENTE de la même bibliothèque
    SELECT d.id AS cid, 'draft'::text AS src,
           d.titulo, d.subtitulo, d.autor, d.ano, d.editora, d.isbn, d.cdd,
           d.colecao, d.idioma, d.tipo_material,
           regexp_replace(upper(coalesce(d.isbn, '')), '[^0-9X]', '', 'g') AS ni,
           public.fn_normalize_name(d.titulo) AS nt,
           public.fn_normalize_name(d.autor)  AS na
    FROM public.book_drafts d
    WHERE d.status = 'draft'
      AND d.id <> p_draft_id
      AND (v_lib IS NULL OR d.owner_library_id = v_lib)
    UNION ALL
    -- Catalogue publié (toutes biblios), hors le livre éventuellement édité
    SELECT b.id, 'book'::text,
           b.titulo, b.subtitulo, b.autor, b.ano, b.editora, b.isbn, b.cdd,
           b.colecao, b.idioma, b.tipo_material,
           regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g'),
           public.fn_normalize_name(b.titulo),
           public.fn_normalize_name(b.autor)
    FROM public.books b
    WHERE b.id IS DISTINCT FROM v_pub
  )
  SELECT c.cid, c.src, c.titulo, c.subtitulo, c.autor, c.ano, c.editora, c.isbn,
         c.cdd, c.colecao, c.idioma, c.tipo_material,
         CASE WHEN v_isbn <> '' AND c.ni = v_isbn THEN 'isbn' ELSE 'approx' END,
         CASE WHEN v_isbn <> '' AND c.ni = v_isbn THEN 1.0::real
              ELSE similarity(c.nt, v_title)::real END
  FROM cand c
  WHERE c.nt <> ''
    AND ( (v_isbn <> '' AND c.ni = v_isbn)
       OR ( similarity(c.nt, v_title) >= 0.5
            AND (v_author = '' OR c.na = '' OR similarity(c.na, v_author) >= 0.4) ) )
  ORDER BY 14 DESC, c.src, c.titulo
  LIMIT 50;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.suggest_draft_duplicates(bigint) FROM PUBLIC, anon, service_role;
GRANT  EXECUTE ON FUNCTION api.suggest_draft_duplicates(bigint) TO authenticated;

COMMENT ON FUNCTION api.suggest_draft_duplicates(bigint) IS
  'Doublons d''un brouillon (file éditoriale) : autres brouillons en attente de la '
  'même biblio + catalogue publié. Scoring ISBN/titre+auteur (pg_trgm), comme '
  'suggest_book_duplicates. Staff-only. Champs cruciaux pour comparaison UI.';

NOTIFY pgrst, 'reload schema';
