-- ════════════════════════════════════════════════════════════════════════════
-- Thésaurus matière — v1 Étape 2a : enrichir api.search_subjects
-- Session : Fédération — Communs & Entraide
-- Cadrage : docs/journal/cadrages/CADRAGE_thesaurus_matiere_2026-06-15.md
--
-- Le picker a besoin, dans le typeahead, du `status` (badge proposto/ativo) et
-- de la `scope_note` (guidage au point d'usage). On les ajoute en fin de TABLE
-- (rétro-compatible : les appelants existants ignorent les colonnes en plus) et
-- on EXCLUT les sujets `depreciado` (on n'indexe pas avec un terme déprécié).
-- Changement de signature RETURNS TABLE → DROP + CREATE (atomique dans la migration).
-- ════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS api.search_subjects(text, int);

CREATE FUNCTION api.search_subjects(p_query text, p_limit int DEFAULT 12)
RETURNS TABLE (id bigint, slug text, label_i18n jsonb, parent_id bigint,
               parent_label jsonb, status text, scope_note text)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
  SELECT s.id, s.slug, s.label_i18n, s.parent_id, p.label_i18n, s.status, s.scope_note
  FROM public.subjects s
  LEFT JOIN public.subjects p ON p.id = s.parent_id
  WHERE s.status <> 'depreciado'
    AND NULLIF(btrim(p_query), '') IS NOT NULL
    AND (
      s.slug ILIKE '%'||btrim(p_query)||'%'
      OR EXISTS (SELECT 1 FROM jsonb_each_text(s.label_i18n) kv
                 WHERE f_normalize_search(kv.value) LIKE '%'||f_normalize_search(btrim(p_query))||'%')
    )
  ORDER BY (s.label_i18n->>'pt-BR'), s.slug
  LIMIT LEAST(COALESCE(p_limit, 12), 50);
$function$;
REVOKE EXECUTE ON FUNCTION api.search_subjects(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.search_subjects(text, int) TO authenticated;

NOTIFY pgrst, 'reload schema';
