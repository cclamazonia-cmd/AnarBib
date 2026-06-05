-- =========================================================================
-- Paquet fix — suggest_author_book_matches : search_path + extensions
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Liaison autorites<->oeuvres
-- Auteur   : Xavier + Claude
--
-- PROBLEME
-- --------
-- suggest_author_book_matches utilise similarity() (pg_trgm), mais pg_trgm est
-- installe dans le schema `extensions` (defaut Supabase). La fonction avait
-- SET search_path = public, pg_catalog -> similarity() introuvable a l'execution
-- -> Postgres leve 42883 -> PostgREST renvoie 404 (proxy-status error=42883).
--
-- CORRECTIF
-- ---------
-- Recreer la fonction avec `extensions` dans le search_path. Corps inchange.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.suggest_author_book_matches(p_author_id bigint)
RETURNS TABLE (
  contributor_id   bigint,
  book_id          bigint,
  book_title       text,
  contributor_name text,
  role             text,
  match_kind       text,
  score            real
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $function$
DECLARE
  v_forms text[];
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  SELECT array_agg(DISTINCT nf) INTO v_forms
  FROM (
    SELECT public.fn_normalize_name(a.preferred_name) AS nf FROM public.authors a WHERE a.id = p_author_id
    UNION
    SELECT public.fn_normalize_name(a.sort_name) FROM public.authors a WHERE a.id = p_author_id
    UNION
    SELECT public.fn_normalize_name(vf)
    FROM public.authors a
    CROSS JOIN LATERAL (
      SELECT jsonb_array_elements_text(a.variant_forms) AS vf
      WHERE a.variant_forms IS NOT NULL AND jsonb_typeof(a.variant_forms) = 'array'
    ) v
    WHERE a.id = p_author_id
  ) s
  WHERE s.nf <> '';

  IF v_forms IS NULL OR array_length(v_forms, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH cand AS (
    SELECT bc.id AS cid, bc.book_id AS bid, bc.name AS cname, bc.role AS crole,
           public.fn_normalize_name(bc.name) AS cn
    FROM public.book_contributors bc
    WHERE bc.author_id IS NULL
  )
  SELECT c.cid, c.bid, b.titulo, c.cname, c.crole,
         CASE WHEN c.cn = ANY (v_forms) THEN 'exact' ELSE 'approx' END,
         CASE WHEN c.cn = ANY (v_forms) THEN 1.0::real
              ELSE (SELECT max(similarity(c.cn, f)) FROM unnest(v_forms) f) END
  FROM cand c
  JOIN public.books b ON b.id = c.bid
  WHERE c.cn <> ''
    AND ( c.cn = ANY (v_forms)
          OR (SELECT max(similarity(c.cn, f)) FROM unnest(v_forms) f) >= 0.45 )
  ORDER BY 7 DESC, b.titulo;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.suggest_author_book_matches(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.suggest_author_book_matches(bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
