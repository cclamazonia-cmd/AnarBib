-- ============================================================================
-- 20260524070000_tasks_templates.sql
-- ----------------------------------------------------------------------------
-- Chantier #TASKS — etape 4 : taches-types locales.
-- Dossier d'ouverture : module des taches, v0.1 (23/05/2026).
-- Pre-requis : 20260524040000 (schema), 20260524050000 (regeneration),
--              20260524060000 (cron de securite).
--
-- OBJET
--   Donner a chaque bibliotheque la capacite de definir ses propres
--   modeles de taches, instanciables en un geste. Modeles LOCAUX : chaque
--   bibliotheque souveraine sur ses taches-types (dossier sec. 3.4), pas
--   de referentiel impose.
--
-- CONCEPTION (arbitrages 24/05)
--   - Ecole A : on enrichit painel_recurring_task_rules. La table porte
--     desormais la cadence ET le contenu du modele. Une « regle de
--     recurrence » devient une « tache-type ». Le nom de la table est
--     conserve (renommer en prod = risque pour un gain cosmetique) ; le
--     COMMENT est mis a jour pour lever l'ambiguite.
--   - Cadence nullable : un modele peut etre RECURRENT (interval_count +
--     interval_unit renseignes) ou PONCTUEL (les deux a NULL — un modele
--     instanciable une fois, qui ne se regenere pas). CHECK de coherence :
--     les deux colonnes ensemble, ou aucune.
--   - Instanciation : fn_task_instantiate_template cree une
--     painel_internal_tasks a partir du modele. Modele recurrent -> la
--     tache porte recurrence_rule_id (elle se regenerera). Modele
--     ponctuel -> la tache NE porte PAS recurrence_rule_id (le modele a
--     seulement pre-rempli les champs, une fois).
--   - Blindage de fn_task_update_status : ne regenerer que si la regle a
--     une cadence complete (interval_unit NOT NULL), pour qu'un
--     recurrence_rule_id pointant par erreur vers un modele ponctuel ne
--     declenche aucune regeneration parasite.
-- ============================================================================


-- ─── Volet 1 — enrichir painel_recurring_task_rules ─────────────────────────

-- 1a. Colonnes de contenu du modele.
ALTER TABLE public.painel_recurring_task_rules
  ADD COLUMN IF NOT EXISTS template_title       text,
  ADD COLUMN IF NOT EXISTS template_description text,
  ADD COLUMN IF NOT EXISTS template_priority    text NOT NULL DEFAULT 'media',
  ADD COLUMN IF NOT EXISTS template_tags        text[] NOT NULL DEFAULT '{}'::text[];

-- 1b. Cadence nullable (etape 2 l'avait posee NOT NULL).
ALTER TABLE public.painel_recurring_task_rules
  ALTER COLUMN interval_count DROP NOT NULL,
  ALTER COLUMN interval_unit  DROP NOT NULL;

-- 1c. CHECK de coherence cadence : les deux colonnes ensemble, ou aucune.
--     (Un modele est soit recurrent, soit ponctuel — jamais a moitie.)
ALTER TABLE public.painel_recurring_task_rules
  DROP CONSTRAINT IF EXISTS painel_recurring_task_rules_cadence_coherence_chk;
ALTER TABLE public.painel_recurring_task_rules
  ADD CONSTRAINT painel_recurring_task_rules_cadence_coherence_chk
  CHECK (
    (interval_count IS NULL AND interval_unit IS NULL)
    OR (interval_count IS NOT NULL AND interval_unit IS NOT NULL)
  );

-- 1d. CHECK sur la priorite du modele.
ALTER TABLE public.painel_recurring_task_rules
  DROP CONSTRAINT IF EXISTS painel_recurring_task_rules_template_priority_chk;
ALTER TABLE public.painel_recurring_task_rules
  ADD CONSTRAINT painel_recurring_task_rules_template_priority_chk
  CHECK (template_priority IN ('baixa', 'media', 'alta'));

COMMENT ON TABLE public.painel_recurring_task_rules IS
  'Tache-type locale d''une bibliotheque (#TASKS, etape 4). Porte le contenu '
  'du modele (template_title, template_description, template_priority, '
  'template_tags) ET, optionnellement, sa cadence de recurrence '
  '(interval_count x interval_unit). Cadence renseignee = modele recurrent ; '
  'cadence NULL = modele ponctuel. Le nom historique « recurring_task_rules » '
  'est conserve ; la table couvre desormais aussi les modeles ponctuels.';


-- ─── Volet 2 — blindage de fn_task_update_status ────────────────────────────
-- Ne regenerer que si la regle a une cadence COMPLETE. Sans ce garde-fou, un
-- recurrence_rule_id pointant vers un modele ponctuel (cadence NULL) ferait
-- un CASE sans branche -> v_interval NULL -> occurrence parasite.
CREATE OR REPLACE FUNCTION public.fn_task_update_status(p_task_id uuid, p_new_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_updated painel_internal_tasks%ROWTYPE;
  v_rule    painel_recurring_task_rules%ROWTYPE;
  v_interval interval;
  v_next_due date;
  v_next_id uuid;
  v_regenerated jsonb := NULL;
BEGIN
  IF p_task_id IS NULL OR p_new_status IS NULL OR btrim(p_new_status) = '' THEN
    RAISE EXCEPTION 'fn_task_update_status: p_task_id et p_new_status obligatoires';
  END IF;

  UPDATE painel_internal_tasks
  SET status = btrim(p_new_status)
  WHERE id = p_task_id
  RETURNING * INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_update_status: task id=% introuvable ou accès refusé', p_task_id;
  END IF;

  -- ─── #TASKS : regeneration a l'achevement (etape 3, blindee etape 4) ──────
  IF btrim(p_new_status) = 'concluida'
     AND v_updated.recurrence_rule_id IS NOT NULL THEN

    SELECT * INTO v_rule
    FROM painel_recurring_task_rules
    WHERE id = v_updated.recurrence_rule_id
      AND is_active = true
      -- #TASKS etape 4 : ne regenerer que si la cadence est COMPLETE.
      -- Un modele ponctuel (interval_unit NULL) ne regenere rien.
      AND interval_unit IS NOT NULL
      AND interval_count IS NOT NULL;

    IF FOUND THEN
      v_interval := CASE v_rule.interval_unit
        WHEN 'dia'    THEN make_interval(days   => v_rule.interval_count)
        WHEN 'semana' THEN make_interval(weeks  => v_rule.interval_count)
        WHEN 'mes'    THEN make_interval(months => v_rule.interval_count)
      END;

      v_next_due := (current_date + v_interval)::date;

      INSERT INTO painel_internal_tasks (
        library_id, title, description, priority, status,
        owner, owner_user_id, due_date, tags, recurrence_rule_id
      )
      VALUES (
        v_updated.library_id, v_updated.title, v_updated.description,
        v_updated.priority, 'pendente', v_updated.owner, v_updated.owner_user_id,
        v_next_due, v_updated.tags, v_updated.recurrence_rule_id
      )
      RETURNING id INTO v_next_id;

      v_regenerated := jsonb_build_object(
        'next_task_id', v_next_id,
        'next_due_date', v_next_due,
        'rule_id', v_rule.id
      );
    END IF;
  END IF;

  RETURN to_jsonb(v_updated) || jsonb_build_object('recurrence_regenerated', v_regenerated);
END;
$function$;


-- ─── Volet 3 — fn_task_instantiate_template : instancier un modele ──────────
-- Cree une painel_internal_tasks a partir d'une tache-type. INVOKER, comme
-- fn_task_create : l'INSERT passe par la RLS painel_internal_tasks_insert.
--   - modele recurrent -> la tache porte recurrence_rule_id ;
--   - modele ponctuel  -> recurrence_rule_id NULL (instanciation unique).
-- p_due_date : echeance optionnelle de la premiere occurrence (le module
-- ne deduit pas l'echeance du modele : la cadence ne dit pas QUAND commencer).
CREATE OR REPLACE FUNCTION public.fn_task_instantiate_template(
  p_template_id uuid,
  p_due_date    date DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_tpl  painel_recurring_task_rules%ROWTYPE;
  v_new  painel_internal_tasks%ROWTYPE;
  v_is_recurrent boolean;
BEGIN
  IF p_template_id IS NULL THEN
    RAISE EXCEPTION 'fn_task_instantiate_template: p_template_id obligatoire';
  END IF;

  -- La RLS painel_recurring_task_rules_select filtre l'acces a l'equipe.
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

  -- Cadence complete = modele recurrent. La tache instanciee ne porte un
  -- recurrence_rule_id QUE dans ce cas (sinon elle se regenererait a tort).
  v_is_recurrent := (v_tpl.interval_unit IS NOT NULL AND v_tpl.interval_count IS NOT NULL);

  INSERT INTO painel_internal_tasks (
    library_id, title, description, priority, status,
    due_date, tags, recurrence_rule_id
  )
  VALUES (
    v_tpl.library_id,
    btrim(v_tpl.template_title),
    NULLIF(btrim(COALESCE(v_tpl.template_description, '')), ''),
    COALESCE(v_tpl.template_priority, 'media'),
    'pendente',
    p_due_date,
    COALESCE(v_tpl.template_tags, ARRAY[]::text[]),
    CASE WHEN v_is_recurrent THEN v_tpl.id ELSE NULL END
  )
  RETURNING * INTO v_new;

  RETURN to_jsonb(v_new) || jsonb_build_object(
    'instantiated_from_template', v_tpl.id,
    'template_is_recurrent', v_is_recurrent
  );
END;
$function$;


-- ─── Verification post-migration ────────────────────────────────────────────
DO $verif$
declare
  v_count integer;
begin
  -- (a) Les 4 colonnes de modele existent.
  select count(*) into v_count
  from pg_attribute
  where attrelid = 'public.painel_recurring_task_rules'::regclass
    and attname in ('template_title','template_description','template_priority','template_tags')
    and not attisdropped;
  if v_count <> 4 then
    raise exception 'Verification echouee : % colonnes template_* sur 4 attendues.', v_count;
  end if;

  -- (b) La cadence est devenue nullable.
  if exists (
    select 1 from pg_attribute
    where attrelid = 'public.painel_recurring_task_rules'::regclass
      and attname in ('interval_count','interval_unit')
      and attnotnull = true
  ) then
    raise exception 'Verification echouee : interval_count/interval_unit toujours NOT NULL.';
  end if;

  -- (c) Le CHECK de coherence de cadence existe.
  if not exists (
    select 1 from pg_constraint
    where conname = 'painel_recurring_task_rules_cadence_coherence_chk'
      and conrelid = 'public.painel_recurring_task_rules'::regclass
  ) then
    raise exception 'Verification echouee : CHECK de coherence de cadence absent.';
  end if;

  -- (d) La fonction d'instanciation existe.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='fn_task_instantiate_template'
  ) then
    raise exception 'Verification echouee : fn_task_instantiate_template absente.';
  end if;

  -- (e) fn_task_update_status porte le blindage cadence.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='fn_task_update_status'
      and pg_get_functiondef(p.oid) ilike '%interval_unit IS NOT NULL%'
  ) then
    raise exception 'Verification echouee : fn_task_update_status non blindee (cadence).';
  end if;

  raise notice 'Migration 20260524070000 : verification OK (4 colonnes modele, cadence nullable + CHECK, fn_task_instantiate_template, fn_task_update_status blindee).';
end;
$verif$;