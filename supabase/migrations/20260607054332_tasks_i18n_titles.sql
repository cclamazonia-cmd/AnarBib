-- ════════════════════════════════════════════════════════════════════════════
-- Chantier #TASKS — i18n des titres/descriptions de taches-types et taches
-- Auteur  : Claude (Opus)
-- Session : Taches internes — catalogue & e-mail i18n
-- Date    : 2026-06-07 (UTC)
--
-- Probleme : le catalogue (painel_task_suggestion_catalog) porte title_i18n /
-- description_i18n (toutes locales), mais fn_task_adopt_suggestion n'en copiait
-- qu'UNE langue dans le modele (texte simple). L'i18n etait donc perdue des
-- l'adoption -> tache instanciee mono-langue -> e-mail mono-langue (d'ou un
-- titre/description FR dans un avis biblio PT).
--
-- Solution : preserver l'i18n de bout en bout.
--   1) Colonnes title_i18n / description_i18n (jsonb) sur les modeles ET les
--      taches (nullable ; NULL = modele/tache manuel en texte libre).
--   2) fn_task_adopt_suggestion : copie l'i18n complet de la suggestion.
--   3) fn_task_instantiate_template : copie l'i18n du modele dans la tache.
--   4) fn_recurring_task_rule_update : EFFACE l'i18n a l'edition (l'utilisateur·
--      rice fournit un texte explicite -> le modele devient "manuel").
--   5) Backfill : modeles (via adopted_from_suggestion_code) puis taches
--      recurrentes (via recurrence_rule_id -> modele). Les taches issues d'un
--      modele ponctuel pre-existant gardent leur texte (pas de regression ; les
--      nouvelles instanciations portent l'i18n directement).
--
-- Cote lecture (UI + e-mail) : on prefere l'i18n dans la locale cible, repli
-- pt-BR puis 1re cle, repli final = le texte simple.
-- ════════════════════════════════════════════════════════════════════════════

-- 1) ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.painel_recurring_task_rules
  ADD COLUMN IF NOT EXISTS title_i18n jsonb,
  ADD COLUMN IF NOT EXISTS description_i18n jsonb;

ALTER TABLE public.painel_internal_tasks
  ADD COLUMN IF NOT EXISTS title_i18n jsonb,
  ADD COLUMN IF NOT EXISTS description_i18n jsonb;

COMMENT ON COLUMN public.painel_recurring_task_rules.title_i18n
  IS 'Titre multilingue (jsonb {locale: texte}) herite du catalogue a l''adoption. NULL = modele manuel (texte simple template_title).';
COMMENT ON COLUMN public.painel_internal_tasks.title_i18n
  IS 'Titre multilingue (jsonb {locale: texte}) herite du modele a l''instanciation. NULL = tache manuelle (texte simple title).';

-- 2) ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_task_adopt_suggestion(
  p_suggestion_code text, p_library_id uuid, p_locale text DEFAULT 'pt-BR'::text
)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp'
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

  SELECT * INTO v_sugg
  FROM painel_task_suggestion_catalog
  WHERE code = p_suggestion_code AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_adopt_suggestion: suggestion % introuvable ou inactive', p_suggestion_code;
  END IF;

  -- Texte simple dans la locale demandee (repli pt-BR) : conserve pour repli et
  -- compatibilite. L'i18n complet est stocke en parallele (title_i18n).
  v_title := COALESCE(v_sugg.title_i18n ->> p_locale, v_sugg.title_i18n ->> 'pt-BR');
  v_desc  := COALESCE(v_sugg.description_i18n ->> p_locale, v_sugg.description_i18n ->> 'pt-BR');

  INSERT INTO painel_recurring_task_rules (
    library_id, interval_count, interval_unit, label,
    template_title, template_description, template_priority, template_tags,
    adopted_from_suggestion_code, title_i18n, description_i18n
  )
  VALUES (
    p_library_id, v_sugg.suggested_interval_count, v_sugg.suggested_interval_unit, v_title,
    v_title, v_desc, 'media', ARRAY[]::text[],
    v_sugg.code, v_sugg.title_i18n, v_sugg.description_i18n
  )
  RETURNING * INTO v_new;

  RETURN to_jsonb(v_new) || jsonb_build_object('adopted_from_suggestion', v_sugg.code);
END;
$function$;

-- 3) ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_task_instantiate_template(
  p_template_id uuid, p_due_date date DEFAULT NULL::date
)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_tpl  painel_recurring_task_rules%ROWTYPE;
  v_new  painel_internal_tasks%ROWTYPE;
  v_is_recurrent boolean;
BEGIN
  IF p_template_id IS NULL THEN
    RAISE EXCEPTION 'fn_task_instantiate_template: p_template_id obligatoire';
  END IF;

  SELECT * INTO v_tpl
  FROM painel_recurring_task_rules
  WHERE id = p_template_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_instantiate_template: modele % introuvable ou accès refusé', p_template_id;
  END IF;
  IF NOT v_tpl.is_active THEN
    RAISE EXCEPTION 'fn_task_instantiate_template: le modele % est inactif', p_template_id;
  END IF;
  IF v_tpl.template_title IS NULL OR btrim(v_tpl.template_title) = '' THEN
    RAISE EXCEPTION 'fn_task_instantiate_template: le modele % n''a pas de titre', p_template_id;
  END IF;

  v_is_recurrent := (v_tpl.interval_unit IS NOT NULL AND v_tpl.interval_count IS NOT NULL);

  INSERT INTO painel_internal_tasks (
    library_id, title, description, priority, status,
    due_date, tags, recurrence_rule_id, title_i18n, description_i18n
  )
  VALUES (
    v_tpl.library_id,
    btrim(v_tpl.template_title),
    NULLIF(btrim(COALESCE(v_tpl.template_description, '')), ''),
    COALESCE(v_tpl.template_priority, 'media'),
    'pendente',
    p_due_date,
    COALESCE(v_tpl.template_tags, ARRAY[]::text[]),
    CASE WHEN v_is_recurrent THEN v_tpl.id ELSE NULL END,
    v_tpl.title_i18n,
    v_tpl.description_i18n
  )
  RETURNING * INTO v_new;

  RETURN to_jsonb(v_new) || jsonb_build_object(
    'instantiated_from_template', v_tpl.id,
    'template_is_recurrent', v_is_recurrent
  );
END;
$function$;

-- 4) ─────────────────────────────────────────────────────────────────────────
-- Editer un modele = fournir un texte explicite -> on efface l'i18n herite du
-- catalogue (sinon l'UI/e-mail afficheraient l'i18n figee au lieu du texte edite).
CREATE OR REPLACE FUNCTION public.fn_recurring_task_rule_update(
  p_template_id uuid, p_template_title text, p_template_description text DEFAULT NULL::text,
  p_template_priority text DEFAULT 'media'::text, p_template_tags text[] DEFAULT ARRAY[]::text[],
  p_label text DEFAULT NULL::text, p_interval_count integer DEFAULT NULL::integer,
  p_interval_unit text DEFAULT NULL::text, p_is_active boolean DEFAULT NULL::boolean
)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row painel_recurring_task_rules%ROWTYPE;
BEGIN
  IF p_template_id IS NULL THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: p_template_id obligatoire';
  END IF;
  IF p_template_title IS NULL OR btrim(p_template_title) = '' THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: le titre du modele est obligatoire';
  END IF;
  IF COALESCE(p_template_priority, 'media') NOT IN ('baixa', 'media', 'alta') THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: priorite invalide (attendu baixa, media ou alta)';
  END IF;
  IF (p_interval_count IS NULL) <> (p_interval_unit IS NULL) THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: cadence incoherente — renseigner intervalle ET unite, ou aucun des deux';
  END IF;
  IF p_interval_count IS NOT NULL AND p_interval_count <= 0 THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: l''intervalle doit etre strictement positif';
  END IF;
  IF p_interval_unit IS NOT NULL AND p_interval_unit NOT IN ('dia', 'semana', 'mes') THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: unite invalide (attendu dia, semana ou mes)';
  END IF;

  UPDATE painel_recurring_task_rules SET
    template_title       = btrim(p_template_title),
    template_description = NULLIF(btrim(COALESCE(p_template_description, '')), ''),
    template_priority    = COALESCE(p_template_priority, 'media'),
    template_tags        = COALESCE(p_template_tags, ARRAY[]::text[]),
    label                = NULLIF(btrim(COALESCE(p_label, '')), ''),
    interval_count       = p_interval_count,
    interval_unit        = p_interval_unit,
    is_active            = COALESCE(p_is_active, is_active),
    title_i18n           = NULL,
    description_i18n      = NULL,
    updated_at           = now(),
    updated_by           = auth.uid()
  WHERE id = p_template_id
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_recurring_task_rule_update: modele % introuvable ou acces refuse', p_template_id;
  END IF;

  RETURN to_jsonb(v_row);
END;
$function$;

-- 5) ─────────────────────────────────────────────────────────────────────────
-- (5a) Modeles deja adoptes : i18n depuis leur suggestion d'origine.
UPDATE public.painel_recurring_task_rules r
SET title_i18n = s.title_i18n, description_i18n = s.description_i18n
FROM public.painel_task_suggestion_catalog s
WHERE r.adopted_from_suggestion_code = s.code
  AND r.title_i18n IS NULL;

-- (5b) Taches recurrentes deja instanciees : i18n depuis leur modele (precis,
-- via recurrence_rule_id ; pas de faux match sur les taches ad hoc).
UPDATE public.painel_internal_tasks tk
SET title_i18n = r.title_i18n, description_i18n = r.description_i18n
FROM public.painel_recurring_task_rules r
WHERE tk.recurrence_rule_id = r.id
  AND r.title_i18n IS NOT NULL
  AND tk.title_i18n IS NULL;
