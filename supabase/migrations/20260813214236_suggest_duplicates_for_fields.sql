-- =========================================================================
-- Paquet doublons P2c — détection floue AVANT sauvegarde du brouillon
-- =========================================================================
-- Date     : 2026-08-13
-- Chantier : catalogage / dédoublonnage
-- Auteur   : Xavier (+ Claude)
--
-- Contexte : la vérif anti-doublon pré-sauvegarde (BookDraftForm.detectDuplicate)
-- faisait, côté client, un ISBN `ilike` + une comparaison titre/auteur EXACTE
-- (normalisée). Deux limites : (1) aucune tolérance aux variantes de titre ;
-- (2) désactivée dès qu'on éditait une fiche déjà publiée.
--
-- Cette fonction porte le même scoring trigramme que public.suggest_book_duplicates
-- / api.suggest_draft_duplicates, mais à partir de CHAMPS TEXTE (le brouillon
-- n'existe pas encore en base au moment du contrôle). Elle sait exclure la fiche
-- en cours d'édition (p_exclude_book_id) ET les paires déjà arbitrées
-- « ce n'est pas un doublon » (public.book_not_duplicate) — indispensable pour
-- étendre l'avertissement aux mises à jour sans re-harceler le staff.
--
-- CHECKLIST DOCTRINE (fonction SECURITY DEFINER) :
--   [x] SET search_path (public, extensions, pg_catalog — extensions pour pg_trgm)
--   [x] REVOKE EXECUTE ... FROM PUBLIC (+ anon)
--   [x] GRANT EXECUTE ... TO authenticated
--   [x] Garde staff interne (même contrat que suggest_book_duplicates)
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.suggest_duplicates_for_fields(
  p_title           text,
  p_author          text    DEFAULT NULL,
  p_isbn            text    DEFAULT NULL,
  p_exclude_book_id bigint  DEFAULT NULL
)
RETURNS TABLE(
  book_id      bigint,
  titulo       text,
  autor        text,
  ano          text,
  editora      text,
  isbn         text,
  bib_ref      text,
  library_name text,
  match_kind   text,
  score        real
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
DECLARE
  v_isbn   text;
  v_title  text;
  v_author text;
BEGIN
  -- Garde catalogage (même contrat que public.suggest_book_duplicates).
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  v_isbn   := regexp_replace(upper(coalesce(p_isbn, '')), '[^0-9X]', '', 'g');
  v_title  := coalesce(public.fn_normalize_name(p_title), '');
  v_author := coalesce(public.fn_normalize_name(p_author), '');

  -- Rien d'exploitable : ni ISBN ni titre normalisé → aucune comparaison.
  IF v_isbn = '' AND v_title = '' THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH other AS (
    SELECT b.id, b.titulo, b.autor, b.ano, b.editora, b.isbn, b.bib_ref,
           b.owner_library_id,
           regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') AS ni,
           public.fn_normalize_name(b.titulo) AS nt,
           public.fn_normalize_name(b.autor)  AS na
    FROM public.books b
    WHERE (p_exclude_book_id IS NULL OR b.id <> p_exclude_book_id)
      -- Paires déjà arbitrées « pas un doublon » (uniquement si on édite une fiche).
      AND (p_exclude_book_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.book_not_duplicate nd
            WHERE nd.book_id_a = least(b.id, p_exclude_book_id)
              AND nd.book_id_b = greatest(b.id, p_exclude_book_id)
          ))
  )
  SELECT o.id, o.titulo, o.autor, o.ano, o.editora, o.isbn, o.bib_ref,
         l.name,
         CASE WHEN v_isbn <> '' AND o.ni = v_isbn THEN 'isbn' ELSE 'approx' END,
         CASE WHEN v_isbn <> '' AND o.ni = v_isbn THEN 1.0::real
              ELSE similarity(o.nt, v_title)::real END
  FROM other o
  LEFT JOIN public.libraries l ON l.id = o.owner_library_id
  WHERE (v_isbn <> '' AND o.ni = v_isbn)
     OR (v_title <> '' AND o.nt <> ''
         AND similarity(o.nt, v_title) >= 0.5
         AND (v_author = '' OR o.na = '' OR similarity(o.na, v_author) >= 0.4))
  ORDER BY 10 DESC, o.titulo
  LIMIT 20;
END;
$function$;

ALTER FUNCTION public.suggest_duplicates_for_fields(text, text, text, bigint) OWNER TO postgres;

REVOKE EXECUTE ON FUNCTION public.suggest_duplicates_for_fields(text, text, text, bigint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.suggest_duplicates_for_fields(text, text, text, bigint) FROM anon;
GRANT  EXECUTE ON FUNCTION public.suggest_duplicates_for_fields(text, text, text, bigint) TO authenticated;

COMMENT ON FUNCTION public.suggest_duplicates_for_fields(text, text, text, bigint) IS
  'Doublons candidats à partir de champs texte (titre/auteur/ISBN), avant sauvegarde d''un brouillon. ISBN exact + titre/auteur trigramme (mêmes seuils que suggest_book_duplicates : titre 0.5, auteur 0.4). Exclut la fiche éditée (p_exclude_book_id) et les paires book_not_duplicate. Garde staff. Paquet doublons P2c du 13/08/2026.';

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.suggest_duplicates_for_fields(text, text, text, bigint);
--   COMMIT;
-- =========================================================================
