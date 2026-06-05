-- =========================================================================
-- Paquet doublons P1 — detection + fusion d'autorites
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Doublons (spec-doublons-detection-fusion v0.1)
-- Auteur   : Xavier + Claude
--
-- DECISIONS (defauts recommandes, 05/06)
--   Q-5  autorites d'abord ; Q-A1 conflit bio -> garder canonique ;
--   Q-3  staff choisit le canonique ; Q-4 journaliser (merge_log) ;
--   Q-2  detection exact-normalise + trigramme.
--
-- CONTENU
--   1. Table merge_log (audit des fusions).
--   2. suggest_author_duplicates(author_id) : candidats doublons (exact/trgm).
--   3. merge_author(canonical, duplicate) : reassigne TOUTES les FK puis
--      supprime le doublon, journalise. Validation humaine cote UI.
--
-- FK vers authors traitees : book_contributors (set null->repoint, trigger sync
-- book_authors), book_authors (restrict->repoint+dedupe), author_translations
-- (cascade->deplacer langues absentes), author_name_aliases (cascade->deplacer),
-- author_drafts.published_author_id (set null->repoint).
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE PUBLIC + GRANT staff ;
-- table RLS + policy + grants.
-- =========================================================================

BEGIN;

-- 1. Journal des fusions -------------------------------------------------
CREATE TABLE IF NOT EXISTS public.merge_log (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  entity_type  text NOT NULL CHECK (entity_type IN ('author','book')),
  canonical_id bigint NOT NULL,
  duplicate_id bigint NOT NULL,
  details      jsonb,
  merged_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  merged_at    timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.merge_log TO authenticated;
GRANT ALL ON public.merge_log TO service_role;
ALTER TABLE public.merge_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS merge_log_staff_read ON public.merge_log;
CREATE POLICY merge_log_staff_read ON public.merge_log
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])));

COMMENT ON TABLE public.merge_log IS
  'Audit des fusions de doublons (autorites/documents). Paquet doublons du 05/06/2026.';

-- 2. Suggestion de doublons d'autorite -----------------------------------
CREATE OR REPLACE FUNCTION public.suggest_author_duplicates(p_author_id bigint)
RETURNS TABLE (
  author_id      bigint,
  preferred_name text,
  sort_name      text,
  linked_books   integer,
  match_kind     text,
  score          real
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
    SELECT al.alias_norm FROM public.author_name_aliases al WHERE al.author_id = p_author_id AND al.is_active
  ) s
  WHERE s.nf <> '';

  IF v_forms IS NULL OR array_length(v_forms, 1) IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH other AS (
    SELECT a.id, a.preferred_name, a.sort_name,
           public.fn_normalize_name(a.preferred_name) AS np
    FROM public.authors a
    WHERE a.id <> p_author_id
  )
  SELECT o.id, o.preferred_name, o.sort_name,
         (SELECT count(DISTINCT ba.book_id)::integer FROM public.book_authors ba WHERE ba.author_id = o.id),
         CASE WHEN o.np = ANY (v_forms) THEN 'exact' ELSE 'approx' END,
         CASE WHEN o.np = ANY (v_forms) THEN 1.0::real
              ELSE (SELECT max(similarity(o.np, f)) FROM unnest(v_forms) f) END
  FROM other o
  WHERE o.np <> ''
    AND ( o.np = ANY (v_forms)
          OR (SELECT max(similarity(o.np, f)) FROM unnest(v_forms) f) >= 0.45 )
  ORDER BY 6 DESC, o.preferred_name;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.suggest_author_duplicates(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.suggest_author_duplicates(bigint) TO authenticated;

-- 3. Fusion d'autorite ---------------------------------------------------
CREATE OR REPLACE FUNCTION public.merge_author(p_canonical_id bigint, p_duplicate_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_dup_name text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.';
  END IF;
  SELECT preferred_name INTO v_dup_name FROM public.authors WHERE id = p_duplicate_id;
  IF v_dup_name IS NULL THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.authors WHERE id = p_canonical_id) THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id;
  END IF;

  -- 1. Contributeurs : repoint (le trigger propage book_authors).
  UPDATE public.book_contributors SET author_id = p_canonical_id WHERE author_id = p_duplicate_id;

  -- 2. book_authors restants (liens legacy sans contributeur) : repoint + dedupe.
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
    SELECT book_id, p_canonical_id, role, ord FROM public.book_authors WHERE author_id = p_duplicate_id
  ON CONFLICT (book_id, author_id, role, ord) DO NOTHING;
  DELETE FROM public.book_authors WHERE author_id = p_duplicate_id;

  -- 3. Traductions : deplacer les langues absentes du canonique (Q-A1 : on garde
  --    le canonique sur conflit ; les traductions en conflit partent au DELETE).
  UPDATE public.author_translations t SET author_id = p_canonical_id
    WHERE t.author_id = p_duplicate_id
      AND NOT EXISTS (SELECT 1 FROM public.author_translations c
                      WHERE c.author_id = p_canonical_id AND c.lang = t.lang);

  -- 4. Alias de nom : deplacer vers le canonique (formes variantes preservees).
  UPDATE public.author_name_aliases SET author_id = p_canonical_id WHERE author_id = p_duplicate_id;

  -- 5. Brouillons pointant vers le doublon : repoint.
  UPDATE public.author_drafts SET published_author_id = p_canonical_id WHERE published_author_id = p_duplicate_id;

  -- 6. Journaliser.
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('author', p_canonical_id, p_duplicate_id,
          jsonb_build_object('duplicate_preferred_name', v_dup_name), auth.uid());

  -- 7. Supprimer le doublon (cascade : traductions restantes en conflit).
  DELETE FROM public.authors WHERE id = p_duplicate_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.merge_author(bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.merge_author(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.suggest_author_duplicates(bigint) IS
  'Autorites candidates doublons (exact-normalise + trigramme). Paquet doublons du 05/06/2026.';
COMMENT ON FUNCTION public.merge_author(bigint, bigint) IS
  'Fusionne le doublon dans le canonique (reassigne FK + journalise + supprime). Paquet doublons du 05/06/2026.';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   DROP FUNCTION IF EXISTS public.merge_author(bigint,bigint);
--   DROP FUNCTION IF EXISTS public.suggest_author_duplicates(bigint);
--   DROP TABLE IF EXISTS public.merge_log;
-- =========================================================================
