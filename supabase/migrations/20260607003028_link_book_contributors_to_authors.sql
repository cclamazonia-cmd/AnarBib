-- ============================================================================
-- Migration : 20260607003028_link_book_contributors_to_authors.sql
-- Objet     : Replace the dead stub link_book_contributors_to_authors with
--             real matching logic: exact normalised-name match against authors.
-- Auteur    : Claude (session Catalogacao authority metadata)
-- Session   : Catalogacao authority metadata
-- ============================================================================

-- ── Replace stub with real name-based matching ──────────────────────────────
-- Called fire-and-forget after publish_book_draft.  For each book_contributor
-- without an author_id, try to find a unique exact match in the authors table
-- by fn_normalize_name.  Only links when the match is unambiguous (exactly 1).
CREATE OR REPLACE FUNCTION public.link_book_contributors_to_authors(p_book_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_row       RECORD;
  v_author_id bigint;
  v_count     int;
  v_linked    int := 0;
BEGIN
  FOR v_row IN
    SELECT bc.id, bc.name, public.fn_normalize_name(bc.name) AS norm_name
    FROM public.book_contributors bc
    WHERE bc.book_id = p_book_id
      AND bc.author_id IS NULL
      AND bc.name IS NOT NULL
      AND btrim(bc.name) != ''
  LOOP
    -- Skip empty normalised forms
    IF v_row.norm_name = '' THEN
      CONTINUE;
    END IF;

    -- Count exact matches to ensure unambiguous linking
    SELECT count(*) INTO v_count
    FROM public.authors a
    WHERE public.fn_normalize_name(a.preferred_name) = v_row.norm_name
       OR public.fn_normalize_name(a.sort_name) = v_row.norm_name;

    IF v_count = 1 THEN
      -- Exactly one match -> safe to auto-link
      SELECT a.id INTO v_author_id
      FROM public.authors a
      WHERE public.fn_normalize_name(a.preferred_name) = v_row.norm_name
         OR public.fn_normalize_name(a.sort_name) = v_row.norm_name
      LIMIT 1;

      UPDATE public.book_contributors
      SET author_id  = v_author_id,
          updated_at = now()
      WHERE id = v_row.id;

      v_linked := v_linked + 1;
    END IF;
  END LOOP;

  RETURN v_linked > 0;
END;
$$;

-- Permissions: same as before (revoked from anon/public, granted to service_role)
REVOKE EXECUTE ON FUNCTION public.link_book_contributors_to_authors(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.link_book_contributors_to_authors(bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.link_book_contributors_to_authors(bigint) TO authenticated;

-- ── Verification ────────────────────────────────────────────────────────────
DO $$
BEGIN
  -- Verify function body is no longer the stub
  IF EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'link_book_contributors_to_authors'
      AND prosrc ILIKE '%select true%'
      AND prosrc NOT ILIKE '%fn_normalize_name%'
  ) THEN
    RAISE EXCEPTION 'VERIFICATION FAILED: link_book_contributors_to_authors is still a stub';
  END IF;

  RAISE NOTICE 'OK: link_book_contributors_to_authors now has real matching logic';
END $$;
