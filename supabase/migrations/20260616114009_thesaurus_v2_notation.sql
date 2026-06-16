-- ════════════════════════════════════════════════════════════════════════════
-- Thésaurus matière — v2 étape F : notation (code CDD anarchiste)
-- Session : Fédération — Communs & Entraide
-- Cadrage : docs/journal/cadrages/CADRAGE_thesaurus_matiere_v2_2026-06-16.md (F1)
--
-- Ajoute subjects.notation (code de la grille CDD anar du vademecum cotation) :
-- pont picker ↔ cotation, aide au rangement. F1 : stocker + afficher (navigation
-- OPAC par classe = v3). Additif :
--   • +1 colonne `notation` (nullable) ;
--   • api.search_subjects renvoie `notation` (colonne en plus → rétro-compatible) ;
--   • api.fn_subject_set_notation (RPC séparé, gardé coordination) — pas de
--     changement de signature de fn_subject_update_labels (zéro casse du front déployé).
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.subjects ADD COLUMN IF NOT EXISTS notation text;

-- search_subjects : ajoute `notation` en fin de TABLE (rétro-compatible).
DROP FUNCTION IF EXISTS api.search_subjects(text, int);
CREATE FUNCTION api.search_subjects(p_query text, p_limit int DEFAULT 12)
RETURNS TABLE (id bigint, slug text, label_i18n jsonb, parent_id bigint,
               parent_label jsonb, status text, scope_note text, alt_i18n jsonb, notation text)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog
AS $function$
  SELECT s.id, s.slug, s.label_i18n, s.parent_id, p.label_i18n, s.status, s.scope_note, s.alt_i18n, s.notation
  FROM public.subjects s
  LEFT JOIN public.subjects p ON p.id = s.parent_id
  WHERE s.status <> 'depreciado'
    AND NULLIF(btrim(p_query), '') IS NOT NULL
    AND (
      s.slug ILIKE '%'||btrim(p_query)||'%'
      OR EXISTS (SELECT 1 FROM jsonb_each_text(s.label_i18n) kv
                 WHERE f_normalize_search(kv.value) LIKE '%'||f_normalize_search(btrim(p_query))||'%')
      OR EXISTS (SELECT 1 FROM jsonb_each(s.alt_i18n) kv WHERE jsonb_typeof(kv.value)='array'
                 AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(kv.value) syn
                             WHERE f_normalize_search(syn) LIKE '%'||f_normalize_search(btrim(p_query))||'%'))
      OR EXISTS (SELECT 1 FROM jsonb_each(s.hidden_i18n) kv WHERE jsonb_typeof(kv.value)='array'
                 AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(kv.value) syn
                             WHERE f_normalize_search(syn) LIKE '%'||f_normalize_search(btrim(p_query))||'%'))
    )
  ORDER BY (s.label_i18n->>'pt-BR'), s.slug
  LIMIT LEAST(COALESCE(p_limit, 12), 50);
$function$;
REVOKE EXECUTE ON FUNCTION api.search_subjects(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.search_subjects(text, int) TO authenticated;

-- RPC d'écriture de la notation (gardé coordination, audité).
CREATE OR REPLACE FUNCTION api.fn_subject_set_notation(p_subject_id bigint, p_notation text)
RETURNS public.subjects LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
DECLARE r public.subjects;
BEGIN
  IF NOT public.fn_is_catalog_coordinator() THEN
    RAISE EXCEPTION 'Réservé à la coordination catalogage' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE public.subjects
    SET notation = NULLIF(btrim(p_notation), ''), updated_by = auth.uid(), updated_at = now()
    WHERE id = p_subject_id
    RETURNING * INTO r;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sujet introuvable : %', p_subject_id USING ERRCODE = 'no_data_found';
  END IF;
  RETURN r;
END $function$;
REVOKE EXECUTE ON FUNCTION api.fn_subject_set_notation(bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_subject_set_notation(bigint, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
