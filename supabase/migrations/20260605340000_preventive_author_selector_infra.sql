-- =========================================================================
-- Paquet liaison autorites P-prev — volet PREVENTIF (sélecteur d'autorité)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Liaison autorites<->oeuvres (spec-liaison-autorites-oeuvres v0.2, Q4)
-- Auteur   : AnarBib (assisté)
--
-- OBJET (Q4 actée : v1 = rétroactif + préventif ensemble)
-- ------------------------------------------------------
--   Le volet rétroactif (« Rattacher aux œuvres », CAT-G1) est en prod. Ici le
--   volet PREVENTIF : poser author_id EXPLICITEMENT dès le catalogage, par
--   ligne contributeur, via un sélecteur d'autorité dans le form livre.
--
--   1. Colonne book_draft_contributors.author_id (le brouillon porte le lien).
--   2. RPC search_authors_by_name : recherche locale dans `authors`
--      (exact-normalisé + substring + trigramme), pour le typeahead.
--   3. fn_seed_draft_contributors : copie aussi author_id à la reprise
--      (pré-remplit les liens existants dans l'éditeur).
--   4. fn_sync_book_contributors_on_publish : l'author_id EXPLICITE du
--      brouillon PRIME ; le filet « préserver par nom normalisé » reste en
--      repli (COALESCE).
--
-- DOCTRINE
--   - search_authors_by_name appelle similarity() (pg_trgm) → le schéma
--     `extensions` DOIT être dans search_path (sinon 42883 ; piège vérifié :
--     similarity vit dans `extensions`, pas `public`).
--   - SECURITY DEFINER + REVOKE EXECUTE FROM PUBLIC + GRANT authenticated +
--     gating staff (librarian/coordenador), comme les RPC liaison sœurs.
--   - Les 2 fonctions trigger gardent search_path = public, pg_catalog
--     (elles n'appellent pas d'extension). CREATE OR REPLACE à signature
--     identique (triggers déjà attachés, non recréés).
-- =========================================================================

BEGIN;

-- 1) Colonne author_id sur les contributeurs de brouillon -----------------
ALTER TABLE public.book_draft_contributors
  ADD COLUMN IF NOT EXISTS author_id bigint
  REFERENCES public.authors(id) ON DELETE SET NULL;

-- 2) RPC de recherche d'autorité locale (typeahead) -----------------------
CREATE OR REPLACE FUNCTION public.search_authors_by_name(p_query text, p_limit int DEFAULT 10)
RETURNS TABLE (
  id             bigint,
  preferred_name text,
  sort_name      text,
  birth_year     int,
  death_year     int,
  country        text,
  match_kind     text,
  score          real
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $function$
DECLARE
  v_nq   text;
  v_lim  int := least(greatest(coalesce(p_limit, 10), 1), 25);
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  v_nq := public.fn_normalize_name(p_query);
  IF v_nq = '' THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT a.id, a.preferred_name, a.sort_name,
           a.birth_year, a.death_year, a.country,
           public.fn_normalize_name(a.preferred_name) AS np,
           public.fn_normalize_name(a.sort_name)      AS ns
    FROM public.authors a
  ),
  scored AS (
    SELECT b.id, b.preferred_name, b.sort_name, b.birth_year, b.death_year, b.country,
           CASE
             WHEN b.np = v_nq OR b.ns = v_nq THEN 'exact'
             WHEN b.np LIKE v_nq || '%' OR b.ns LIKE v_nq || '%' THEN 'prefix'
             WHEN b.np LIKE '%' || v_nq || '%' OR b.ns LIKE '%' || v_nq || '%' THEN 'substring'
             ELSE 'approx'
           END AS match_kind,
           CASE
             WHEN b.np = v_nq OR b.ns = v_nq THEN 1.0::real
             WHEN b.np LIKE v_nq || '%' OR b.ns LIKE v_nq || '%' THEN 0.9::real
             WHEN b.np LIKE '%' || v_nq || '%' OR b.ns LIKE '%' || v_nq || '%' THEN 0.7::real
             ELSE greatest(similarity(b.np, v_nq), similarity(b.ns, v_nq))
           END AS score
    FROM base b
    WHERE b.np <> ''
      AND ( b.np LIKE '%' || v_nq || '%'
            OR b.ns LIKE '%' || v_nq || '%'
            OR similarity(b.np, v_nq) >= 0.30
            OR similarity(b.ns, v_nq) >= 0.30 )
  )
  SELECT s.id, s.preferred_name, s.sort_name, s.birth_year, s.death_year,
         s.country, s.match_kind, s.score
  FROM scored s
  ORDER BY s.score DESC, s.preferred_name
  LIMIT v_lim;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.search_authors_by_name(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_authors_by_name(text, int) TO authenticated;

COMMENT ON FUNCTION public.search_authors_by_name(text, int) IS
  'Recherche d''autorites locales par nom (exact/prefixe/substring/trigramme) pour le selecteur preventif du form livre. Volet preventif liaison autorites, 05/06/2026.';

-- 3) Seed : copier aussi author_id a la reprise ---------------------------
CREATE OR REPLACE FUNCTION public.fn_seed_draft_contributors()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.published_book_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.book_draft_contributors dc WHERE dc.draft_id = NEW.id) THEN
    INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary, author_id)
    SELECT NEW.id, bc.position, bc.name, bc.role, bc.is_primary, bc.author_id
    FROM public.book_contributors bc
    WHERE bc.book_id = NEW.published_book_id
    ORDER BY bc.position, bc.id;
  END IF;
  RETURN NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_seed_draft_contributors() FROM PUBLIC;

-- 4) Sync a la publication : author_id explicite du brouillon PRIME --------
CREATE OR REPLACE FUNCTION public.fn_sync_book_contributors_on_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_prior jsonb;
BEGIN
  IF NEW.published_book_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.book_draft_contributors dc WHERE dc.draft_id = NEW.id) THEN
    RETURN NULL;
  END IF;

  -- Filet : author_id existants par nom normalise (repli quand le brouillon
  -- ne porte pas de lien explicite).
  SELECT jsonb_object_agg(nf, author_id) INTO v_prior
  FROM (
    SELECT public.fn_normalize_name(name) AS nf, max(author_id) AS author_id
    FROM public.book_contributors
    WHERE book_id = NEW.published_book_id AND author_id IS NOT NULL
    GROUP BY public.fn_normalize_name(name)
  ) s;

  DELETE FROM public.book_contributors WHERE book_id = NEW.published_book_id;

  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id)
  SELECT NEW.published_book_id, dc.position, dc.name, dc.role, dc.is_primary,
         COALESCE(dc.author_id, NULLIF(v_prior ->> public.fn_normalize_name(dc.name), '')::bigint)
  FROM public.book_draft_contributors dc
  WHERE dc.draft_id = NEW.id
  ORDER BY dc.position, dc.id;

  RETURN NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_sync_book_contributors_on_publish() FROM PUBLIC;

-- -------------------------------------------------------------------------
-- Vérification automatique
-- -------------------------------------------------------------------------
DO $verif$
BEGIN
  -- Colonne presente
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'book_draft_contributors' AND column_name = 'author_id'
  ) THEN
    RAISE EXCEPTION 'VERIF_FAIL_1 : book_draft_contributors.author_id absent';
  END IF;

  -- search_authors_by_name a bien extensions dans son search_path
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'search_authors_by_name'
      AND array_to_string(p.proconfig, ',') LIKE '%extensions%'
  ) THEN
    RAISE EXCEPTION 'VERIF_FAIL_2 : search_authors_by_name sans extensions dans search_path (risque 42883)';
  END IF;

  -- Privilèges : authenticated EXECUTE, PUBLIC non
  IF NOT has_function_privilege('authenticated', 'public.search_authors_by_name(text, int)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_3 : authenticated sans EXECUTE sur search_authors_by_name';
  END IF;
  IF has_function_privilege('public', 'public.search_authors_by_name(text, int)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_4 : PUBLIC a EXECUTE sur search_authors_by_name (doit etre REVOKE)';
  END IF;

  -- Sync : le corps reference bien dc.author_id (explicite prime)
  IF position('dc.author_id' IN pg_get_functiondef('public.fn_sync_book_contributors_on_publish()'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_5 : fn_sync_book_contributors_on_publish ne lit pas dc.author_id';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   ALTER TABLE public.book_draft_contributors DROP COLUMN IF EXISTS author_id;
--   DROP FUNCTION IF EXISTS public.search_authors_by_name(text, int);
--   (les 2 fonctions trigger : restaurer la version 20260605280000)
-- =========================================================================
