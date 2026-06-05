-- =========================================================================
-- Paquet liaison autorites P2 — RPC de matching et de rattachement
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Liaison autorites<->oeuvres (spec-liaison-autorites-oeuvres v0.2)
-- Auteur   : Xavier + Claude
--
-- OBJET (Q1/Q2 actees)
-- --------------------
--   - suggest_author_book_matches : candidats non lies dont le nom matche
--     l'autorite (exact-normalise OU trigramme >= seuil), avec score. Lecture.
--   - confirm_author_book_link    : pose book_contributors.author_id (le trigger
--     propage book_authors). Validation HUMAINE (jamais auto). Q2.
--   - unlink_author_book          : annule un rattachement.
--
-- DOCTRINE : SECURITY DEFINER + SET search_path + REVOKE EXECUTE FROM PUBLIC +
-- GRANT authenticated ; gating interne staff (librarian/coordenador).
-- =========================================================================

BEGIN;

-- Seuil de similarite trigramme pour les correspondances approximatives.
-- (0.45 : tolere "Hughes"/"Hugues", rejette les noms distincts.)

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
SET search_path = public, pg_catalog
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

  -- Formes normalisees de l'autorite : nom prefere, nom de tri, variantes.
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

-- ── confirm : pose le lien (validation humaine), trigger propage book_authors ─
CREATE OR REPLACE FUNCTION public.confirm_author_book_link(p_author_id bigint, p_contributor_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_book_id bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  UPDATE public.book_contributors
  SET author_id = p_author_id
  WHERE id = p_contributor_id AND author_id IS NULL
  RETURNING book_id INTO v_book_id;

  IF v_book_id IS NULL THEN
    RAISE EXCEPTION 'Contribuinte % inexistente ou ja vinculado.', p_contributor_id;
  END IF;

  RETURN v_book_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.confirm_author_book_link(bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_author_book_link(bigint, bigint) TO authenticated;

-- ── unlink : annule un rattachement (trigger retire book_authors) ────────────
CREATE OR REPLACE FUNCTION public.unlink_author_book(p_author_id bigint, p_contributor_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_found boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  UPDATE public.book_contributors
  SET author_id = NULL
  WHERE id = p_contributor_id AND author_id = p_author_id;

  GET DIAGNOSTICS v_found = ROW_COUNT;
  RETURN v_found > 0;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.unlink_author_book(bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.unlink_author_book(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.suggest_author_book_matches(bigint) IS
  'Candidats book_contributors non lies matchant l''autorite (exact/trigramme). Paquet liaison autorites du 05/06/2026.';
COMMENT ON FUNCTION public.confirm_author_book_link(bigint, bigint) IS
  'Rattache un contribuinte a une autorite (validation humaine). Paquet liaison autorites du 05/06/2026.';
COMMENT ON FUNCTION public.unlink_author_book(bigint, bigint) IS
  'Annule un rattachement contribuinte<->autorite. Paquet liaison autorites du 05/06/2026.';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   DROP FUNCTION IF EXISTS public.suggest_author_book_matches(bigint);
--   DROP FUNCTION IF EXISTS public.confirm_author_book_link(bigint, bigint);
--   DROP FUNCTION IF EXISTS public.unlink_author_book(bigint, bigint);
-- =========================================================================
