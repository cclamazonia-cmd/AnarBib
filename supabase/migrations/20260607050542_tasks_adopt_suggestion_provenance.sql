-- ════════════════════════════════════════════════════════════════════════════
-- Chantier #TASKS — provenance d'adoption (catalogue -> tache-type)
-- Auteur  : Claude (Opus)
-- Session : Taches internes — catalogue & e-mail i18n
-- Date    : 2026-06-07 (UTC)
--
-- But : quand une suggestion du catalogue est adoptee en tache-type, on garde le
-- lien vers le `code` de suggestion. Le frontend masque alors les suggestions
-- deja adoptees (elles "basculent" dans le sous-onglet modeles). Supprimer le
-- modele fait reapparaitre la suggestion.
--
-- 1) Colonne de provenance (nullable, texte simple — les codes catalogue sont
--    stables ; pas de FK pour ne pas bloquer si une suggestion est retiree).
-- 2) fn_task_adopt_suggestion : stocke le code adopte (INVOKER, RLS inchangee).
-- 3) Backfill : relie les taches-types existantes a une suggestion dont un des
--    titres localises (title_i18n) correspond exactement au template_title.
-- ════════════════════════════════════════════════════════════════════════════

-- 1) ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.painel_recurring_task_rules
  ADD COLUMN IF NOT EXISTS adopted_from_suggestion_code text;

COMMENT ON COLUMN public.painel_recurring_task_rules.adopted_from_suggestion_code
  IS 'Code de la suggestion (painel_task_suggestion_catalog.code) dont cette tache-type est issue, ou NULL si creee a la main. Sert a masquer la suggestion du catalogue cote UI.';

-- 2) ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_task_adopt_suggestion(
  p_suggestion_code text,
  p_library_id uuid,
  p_locale text DEFAULT 'pt-BR'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_sugg painel_task_suggestion_catalog%ROWTYPE;
  v_new  painel_recurring_task_rules%ROWTYPE;
  v_title text;
  v_desc  text;
BEGIN
  IF p_suggestion_code IS NULL OR p_library_id IS NULL THEN
    RAISE EXCEPTION 'fn_task_adopt_suggestion: p_suggestion_code et p_library_id obligatoires';
  END IF;

  -- La RLS painel_task_suggestion_catalog_select filtre l'acces (staff).
  SELECT * INTO v_sugg
  FROM painel_task_suggestion_catalog
  WHERE code = p_suggestion_code AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_adopt_suggestion: suggestion % introuvable ou inactive', p_suggestion_code;
  END IF;

  -- Libelle/description dans la locale demandee, repli sur pt-BR.
  v_title := COALESCE(v_sugg.title_i18n ->> p_locale, v_sugg.title_i18n ->> 'pt-BR');
  v_desc  := COALESCE(v_sugg.description_i18n ->> p_locale, v_sugg.description_i18n ->> 'pt-BR');

  -- INSERT de la tache-type locale. La RLS painel_recurring_task_rules_insert
  -- verifie user_can_act_as_staff_on_library(p_library_id).
  INSERT INTO painel_recurring_task_rules (
    library_id,
    interval_count,
    interval_unit,
    label,
    template_title,
    template_description,
    template_priority,
    template_tags,
    adopted_from_suggestion_code
  )
  VALUES (
    p_library_id,
    v_sugg.suggested_interval_count,
    v_sugg.suggested_interval_unit,
    v_title,
    v_title,
    v_desc,
    'media',
    ARRAY[]::text[],
    v_sugg.code
  )
  RETURNING * INTO v_new;

  RETURN to_jsonb(v_new) || jsonb_build_object('adopted_from_suggestion', v_sugg.code);
END;
$function$;

-- 3) ─────────────────────────────────────────────────────────────────────────
-- Backfill : relie les taches-types existantes (sans provenance) a une
-- suggestion dont un titre localise correspond exactement au template_title.
UPDATE public.painel_recurring_task_rules r
SET adopted_from_suggestion_code = s.code
FROM public.painel_task_suggestion_catalog s
WHERE r.adopted_from_suggestion_code IS NULL
  AND EXISTS (
    SELECT 1
    FROM jsonb_each_text(s.title_i18n) AS kv(k, v)
    WHERE v = r.template_title
  );
