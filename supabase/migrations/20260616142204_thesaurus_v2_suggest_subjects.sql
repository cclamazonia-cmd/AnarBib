-- ════════════════════════════════════════════════════════════════════════════
-- Thésaurus matière — v2 étape G : suggestions de sujets au catalogage
-- Session : Fédération — Communs & Entraide
-- Cadrage : docs/journal/cadrages/CADRAGE_thesaurus_matiere_v2_2026-06-16.md (G1)
--
-- G1 : « similaires + 135 d'abord ». Les 135 ne sont pas en base (liste de
-- travail) → différés. v1 = signal PAR AUTEUR·RICE, robuste pour un brouillon :
-- les contributeur·rices du brouillon (book_draft_contributors.author_id) → leurs
-- livres publiés (author_books_public) → les sujets les plus fréquents, hors ceux
-- déjà posés et hors `depreciado`. C'est « ça tend » : on propose, on n'impose pas
-- (accept/reject côté front). SECURITY INVOKER : la RLS catalogage gate l'accès au
-- brouillon (un non-catalogueur·euse n'obtient rien).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION api.fn_suggest_subjects_for_draft(p_book_draft_id bigint)
RETURNS TABLE (id bigint, slug text, label_i18n jsonb, notation text, freq integer)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
  WITH draft_authors AS (
    SELECT DISTINCT bdc.author_id
    FROM public.book_draft_contributors bdc
    WHERE bdc.draft_id = p_book_draft_id AND bdc.author_id IS NOT NULL
  ),
  author_books AS (
    SELECT DISTINCT abp.book_id
    FROM public.author_books_public abp
    JOIN draft_authors da ON da.author_id = abp.author_id
  ),
  already AS (
    SELECT subject_id FROM public.book_draft_subjects WHERE book_draft_id = p_book_draft_id
  )
  SELECT s.id, s.slug, s.label_i18n, s.notation, count(DISTINCT ab.book_id)::int AS freq
  FROM author_books ab
  JOIN public.book_subjects bs ON bs.book_id = ab.book_id
  JOIN public.subjects s ON s.id = bs.subject_id
  WHERE s.status <> 'depreciado'
    AND s.id NOT IN (SELECT subject_id FROM already)
  GROUP BY s.id, s.slug, s.label_i18n, s.notation
  ORDER BY freq DESC, (s.label_i18n->>'pt-BR'), s.slug
  LIMIT 8;
$function$;
REVOKE EXECUTE ON FUNCTION api.fn_suggest_subjects_for_draft(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_suggest_subjects_for_draft(bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';
