-- ============================================================================
-- 20260524040000_tasks_recurrence_schema.sql
-- ----------------------------------------------------------------------------
-- Chantier #TASKS — etape 2 : schema de la recurrence.
-- Dossier d'ouverture : module des taches, v0.1 (23/05/2026).
--
-- OBJET (etape 2 STRICTE — schema seul)
--   Le module des taches ne gere aujourd'hui que des taches ponctuelles.
--   Cette migration pose la STRUCTURE permettant de decrire une tache
--   cyclique. La LOGIQUE (regeneration a l'achevement, cron de securite)
--   est l'etape 3, dans une migration ulterieure.
--
-- CONCEPTION (etape 1, arbitrages actes 24/05)
--   - Recurrence par intervalle fixe : « tous les N dia/semana/mes ».
--   - Ecole 2 : la regle de recurrence vit dans une TABLE DEDIEE, pas en
--     colonnes sur painel_internal_tasks. Une regle existe une fois ; les
--     occurrences (lignes painel_internal_tasks) y pointent. Changer
--     l'intervalle d'une serie = un seul UPDATE. Cette table sera aussi le
--     socle des taches-types locales (etape 4).
--   - painel_internal_tasks recoit une FK nullable recurrence_rule_id :
--     NULL = tache ponctuelle (tout l'existant, inchange) ; renseigne =
--     occurrence d'une serie recurrente.
--
-- SECURITE
--   RLS symetrique a painel_internal_tasks : acces reserve a l'equipe de
--   la bibliotheque (user_can_act_as_staff_on_library). GRANT explicites
--   (doctrine Template 2).
-- ============================================================================


-- ─── Table de la regle de recurrence ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.painel_recurring_task_rules (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id     uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  interval_count integer NOT NULL,
  interval_unit  text NOT NULL,
  label          text,
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  created_by     uuid DEFAULT auth.uid(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  updated_by     uuid DEFAULT auth.uid(),
  CONSTRAINT painel_recurring_task_rules_interval_count_chk
    CHECK (interval_count > 0),
  CONSTRAINT painel_recurring_task_rules_interval_unit_chk
    CHECK (interval_unit IN ('dia', 'semana', 'mes'))
);

COMMENT ON TABLE public.painel_recurring_task_rules IS
  'Regle de recurrence d''une serie de taches internes (#TASKS, etape 2). '
  'Intervalle fixe : interval_count x interval_unit. Une regle est partagee '
  'par toutes les occurrences de la serie ; les lignes painel_internal_tasks '
  'y pointent via recurrence_rule_id.';

-- RLS symetrique a painel_internal_tasks : acces reserve a l'equipe.
ALTER TABLE public.painel_recurring_task_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS painel_recurring_task_rules_select_same_library_team
  ON public.painel_recurring_task_rules;
CREATE POLICY painel_recurring_task_rules_select_same_library_team
  ON public.painel_recurring_task_rules
  FOR SELECT USING (user_can_act_as_staff_on_library(library_id));

DROP POLICY IF EXISTS painel_recurring_task_rules_insert_same_library_team
  ON public.painel_recurring_task_rules;
CREATE POLICY painel_recurring_task_rules_insert_same_library_team
  ON public.painel_recurring_task_rules
  FOR INSERT WITH CHECK (user_can_act_as_staff_on_library(library_id));

DROP POLICY IF EXISTS painel_recurring_task_rules_update_same_library_team
  ON public.painel_recurring_task_rules;
CREATE POLICY painel_recurring_task_rules_update_same_library_team
  ON public.painel_recurring_task_rules
  FOR UPDATE USING (user_can_act_as_staff_on_library(library_id))
             WITH CHECK (user_can_act_as_staff_on_library(library_id));

DROP POLICY IF EXISTS painel_recurring_task_rules_delete_same_library_team
  ON public.painel_recurring_task_rules;
CREATE POLICY painel_recurring_task_rules_delete_same_library_team
  ON public.painel_recurring_task_rules
  FOR DELETE USING (user_can_act_as_staff_on_library(library_id));

-- GRANT explicites (doctrine Template 2), calques sur painel_internal_tasks :
-- authenticated a les privileges de donnees (l'acces reel est filtre par la
-- RLS ci-dessus) ; aucun privilege de donnees pour anon.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.painel_recurring_task_rules TO authenticated, service_role;


-- ─── FK sur painel_internal_tasks : rattachement d'une occurrence ───────────
-- NULL = tache ponctuelle (tout l'existant). Renseigne = occurrence d'une
-- serie. ON DELETE SET NULL : supprimer la regle ne detruit pas les
-- occurrences deja creees — elles redeviennent de simples taches ponctuelles.
ALTER TABLE public.painel_internal_tasks
  ADD COLUMN IF NOT EXISTS recurrence_rule_id uuid;

ALTER TABLE public.painel_internal_tasks
  DROP CONSTRAINT IF EXISTS painel_internal_tasks_recurrence_rule_id_fkey;
ALTER TABLE public.painel_internal_tasks
  ADD CONSTRAINT painel_internal_tasks_recurrence_rule_id_fkey
  FOREIGN KEY (recurrence_rule_id)
  REFERENCES public.painel_recurring_task_rules(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.painel_internal_tasks.recurrence_rule_id IS
  'Rattache la tache a une serie recurrente (#TASKS, etape 2). NULL = tache '
  'ponctuelle. Renseigne = occurrence d''une serie ; voir '
  'painel_recurring_task_rules.';

-- Index : le cron de securite (etape 3) et les vues par echeance (etape 6)
-- filtreront les taches recurrentes.
CREATE INDEX IF NOT EXISTS idx_painel_internal_tasks_recurrence_rule_id
  ON public.painel_internal_tasks (recurrence_rule_id)
  WHERE recurrence_rule_id IS NOT NULL;


-- ─── Verification post-migration ────────────────────────────────────────────
DO $verif$
declare
  v_ok boolean;
begin
  -- (a) La table de regles existe et a la RLS activee.
  select relrowsecurity into v_ok
  from pg_class where oid = 'public.painel_recurring_task_rules'::regclass;
  if not coalesce(v_ok, false) then
    raise exception 'Verification echouee : RLS non activee sur painel_recurring_task_rules.';
  end if;

  -- (b) Les 4 policies sont posees.
  if (select count(*) from pg_policy
      where polrelid = 'public.painel_recurring_task_rules'::regclass) <> 4 then
    raise exception 'Verification echouee : painel_recurring_task_rules doit avoir 4 policies RLS.';
  end if;

  -- (c) La colonne recurrence_rule_id existe sur painel_internal_tasks.
  if not exists (
    select 1 from pg_attribute
    where attrelid = 'public.painel_internal_tasks'::regclass
      and attname = 'recurrence_rule_id' and not attisdropped
  ) then
    raise exception 'Verification echouee : colonne recurrence_rule_id absente.';
  end if;

  -- (d) La FK existe.
  if not exists (
    select 1 from pg_constraint
    where conname = 'painel_internal_tasks_recurrence_rule_id_fkey'
      and conrelid = 'public.painel_internal_tasks'::regclass
  ) then
    raise exception 'Verification echouee : FK recurrence_rule_id absente.';
  end if;

  raise notice 'Migration 20260524040000 : verification OK (table painel_recurring_task_rules + RLS 4 policies, colonne + FK recurrence_rule_id).';
end;
$verif$;
