-- ════════════════════════════════════════════════════════════════════════════
-- Fix : merge_author repointe aussi book_draft_contributors
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
--
-- BUG : public.merge_author() repointait book_contributors, book_authors,
-- author_translations, author_name_aliases et author_drafts vers le canonique,
-- MAIS oubliait public.book_draft_contributors (qui porte aussi une FK
-- author_id -> authors.id). Conséquence : si un brouillon de notice référence
-- l'auteur·rice doublon, le DELETE final échoue (violation FK) ou laisse un
-- lien orphelin.
--
-- FIX : ajout du repoint book_draft_contributors avant le DELETE. La contrainte
-- d'unicité y porte sur (draft_id, position) — pas sur author_id — donc un
-- simple UPDATE author_id ne peut pas violer l'unicité ; aucune dédup requise.
--
-- Le reste de la fonction est reproduit À L'IDENTIQUE (garde staff, search_path,
-- SECURITY DEFINER, ordre des étapes, journalisation merge_log).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.merge_author(p_canonical_id bigint, p_duplicate_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
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

  -- 5b. Contributeurs de brouillons : repoint (FIX — oublie originel).
  --     Unicite sur (draft_id, position), pas sur author_id -> UPDATE direct sur.
  UPDATE public.book_draft_contributors SET author_id = p_canonical_id WHERE author_id = p_duplicate_id;

  -- 6. Journaliser.
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('author', p_canonical_id, p_duplicate_id,
          jsonb_build_object('duplicate_preferred_name', v_dup_name), auth.uid());

  -- 7. Supprimer le doublon (cascade : traductions restantes en conflit).
  DELETE FROM public.authors WHERE id = p_duplicate_id;
END;
$function$;

-- Droits inchanges (reaffirmes pour la doctrine pre-commit) : pas d'EXECUTE
-- par PUBLIC/anon ; appel reserve aux comptes authentifies (garde staff interne).
REVOKE EXECUTE ON FUNCTION public.merge_author(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merge_author(bigint, bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';
