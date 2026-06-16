-- ════════════════════════════════════════════════════════════════════════════
-- Thésaurus matière — v2 étape E : modèle des synonymes (findabilité)
-- Session : Fédération — Communs & Entraide
-- Cadrage : docs/journal/cadrages/CADRAGE_thesaurus_matiere_v2_2026-06-16.md (E1)
--
-- Décision E1 (16/06) : colonnes SŒURS additives, plutôt que transformer
-- label_i18n (qui casserait l'OPAC/picker/export). label_i18n reste les `pref`.
--   • alt_i18n    {locale: [synonymes affichables]}   — « aussi appelé »
--   • hidden_i18n {locale: [variantes de recherche]}  — sigles, graphies, etc.
-- api.search_subjects scanne désormais pref + alt + hidden, et renvoie alt_i18n
-- (pour affichage). Rétro-compatible : les appelants ignorent la colonne en plus.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.subjects
  ADD COLUMN IF NOT EXISTS alt_i18n    jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS hidden_i18n jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Recherche étendue aux synonymes. Changement de signature (alt_i18n en sortie)
-- → DROP + CREATE (atomique dans la migration).
DROP FUNCTION IF EXISTS api.search_subjects(text, int);

CREATE FUNCTION api.search_subjects(p_query text, p_limit int DEFAULT 12)
RETURNS TABLE (id bigint, slug text, label_i18n jsonb, parent_id bigint,
               parent_label jsonb, status text, scope_note text, alt_i18n jsonb)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
  SELECT s.id, s.slug, s.label_i18n, s.parent_id, p.label_i18n, s.status, s.scope_note, s.alt_i18n
  FROM public.subjects s
  LEFT JOIN public.subjects p ON p.id = s.parent_id
  WHERE s.status <> 'depreciado'
    AND NULLIF(btrim(p_query), '') IS NOT NULL
    AND (
      s.slug ILIKE '%'||btrim(p_query)||'%'
      -- pref labels ({locale: "texte"})
      OR EXISTS (SELECT 1 FROM jsonb_each_text(s.label_i18n) kv
                 WHERE f_normalize_search(kv.value) LIKE '%'||f_normalize_search(btrim(p_query))||'%')
      -- synonymes affichables ({locale: ["..."]})
      OR EXISTS (SELECT 1 FROM jsonb_each(s.alt_i18n) kv
                 WHERE jsonb_typeof(kv.value) = 'array'
                   AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(kv.value) syn
                               WHERE f_normalize_search(syn) LIKE '%'||f_normalize_search(btrim(p_query))||'%'))
      -- variantes de recherche cachées ({locale: ["..."]})
      OR EXISTS (SELECT 1 FROM jsonb_each(s.hidden_i18n) kv
                 WHERE jsonb_typeof(kv.value) = 'array'
                   AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(kv.value) syn
                               WHERE f_normalize_search(syn) LIKE '%'||f_normalize_search(btrim(p_query))||'%'))
    )
  ORDER BY (s.label_i18n->>'pt-BR'), s.slug
  LIMIT LEAST(COALESCE(p_limit, 12), 50);
$function$;
REVOKE EXECUTE ON FUNCTION api.search_subjects(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.search_subjects(text, int) TO authenticated;

NOTIFY pgrst, 'reload schema';
