-- ============================================================================
-- 20260524050000_tasks_recurrence_regeneration.sql
-- ----------------------------------------------------------------------------
-- Chantier #TASKS — etape 3 : logique de recurrence (regeneration).
-- Dossier d'ouverture : module des taches, v0.1 (23/05/2026).
-- Pre-requis : migration 20260524040000 (table painel_recurring_task_rules,
--              colonne painel_internal_tasks.recurrence_rule_id).
--
-- OBJET
--   Quand une occurrence d'une tache recurrente est achevee, regenerer
--   automatiquement l'occurrence suivante. Greffe dans fn_task_update_status,
--   point d'entree unique du changement de statut.
--
-- CONCEPTION (arbitrages actes a l'etape 1 et au cadrage de l'etape 3)
--   - Declencheur : passage au statut 'concluida' (orthographe exacte du
--     code applicatif, sans accent).
--   - Cible : seules les taches portant un recurrence_rule_id non NULL et
--     une regle active. Une tache ponctuelle (recurrence_rule_id NULL) ne
--     regenere rien — comportement actuel strictement inchange.
--   - Calcul de la nouvelle echeance (option 1) : date d'achevement reelle
--     (current_date) + intervalle de la regle. Le cycle suit le rythme reel
--     du collectif, coherent avec « regeneration A L'ACHEVEMENT ».
--   - La nouvelle occurrence recopie titre / description / priorite / tags /
--     owner / recurrence_rule_id de l'occurrence achevee, statut 'pendente'.
--   - L'assignation (owner / owner_user_id) est recopiee : la personne qui
--     s'etait portee volontaire sur la serie le reste sur l'occurrence
--     suivante, sauf a s'en retirer (assignation volontaire, etape 1).
--
-- HORS PERIMETRE (etape posterieure)
--   Le cron de securite signalant les chaines de recurrence interrompues
--   (occurrence jamais achevee) est decale a une etape ulterieure : il
--   suppose un nouvel event_kind dans la chaine de notification, hors
--   perimetre de cette etape.
--
-- fn_task_update_status reste en mode INVOKER (droits de l'appelant) :
-- l'INSERT de la nouvelle occurrence passe par la RLS
-- painel_internal_tasks_insert_same_library_team (la personne qui acheve
-- une tache de sa bibliotheque a le droit d'y inserer la suivante).
-- ============================================================================

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

  -- La RLS painel_internal_tasks_update verifie automatiquement
  -- user_can_act_as_staff_on_library.
  UPDATE painel_internal_tasks
  SET status = btrim(p_new_status)
  WHERE id = p_task_id
  RETURNING * INTO v_updated;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_update_status: task id=% introuvable ou accès refusé', p_task_id;
  END IF;

  -- ─── #TASKS etape 3 : regeneration a l'achevement ─────────────────────────
  -- Si la tache vient d'etre achevee ET qu'elle est une occurrence d'une
  -- serie recurrente, on genere la prochaine occurrence.
  IF btrim(p_new_status) = 'concluida'
     AND v_updated.recurrence_rule_id IS NOT NULL THEN

    -- Regle de recurrence rattachee ; seulement si elle est active.
    SELECT * INTO v_rule
    FROM painel_recurring_task_rules
    WHERE id = v_updated.recurrence_rule_id
      AND is_active = true;

    IF FOUND THEN
      -- Intervalle -> type interval Postgres, selon l'unite.
      v_interval := CASE v_rule.interval_unit
        WHEN 'dia'    THEN make_interval(days   => v_rule.interval_count)
        WHEN 'semana' THEN make_interval(weeks  => v_rule.interval_count)
        WHEN 'mes'    THEN make_interval(months => v_rule.interval_count)
      END;

      -- Option 1 : echeance = date d'achevement reelle + intervalle.
      v_next_due := (current_date + v_interval)::date;

      -- Nouvelle occurrence : recopie des attributs de la serie,
      -- statut 'pendente', nouvelle echeance.
      INSERT INTO painel_internal_tasks (
        library_id,
        title,
        description,
        priority,
        status,
        owner,
        owner_user_id,
        due_date,
        tags,
        recurrence_rule_id
      )
      VALUES (
        v_updated.library_id,
        v_updated.title,
        v_updated.description,
        v_updated.priority,
        'pendente',
        v_updated.owner,
        v_updated.owner_user_id,
        v_next_due,
        v_updated.tags,
        v_updated.recurrence_rule_id
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


-- ─── Verification post-migration ────────────────────────────────────────────
DO $verif$
begin
  -- fn_task_update_status reference bien la regeneration recurrente.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='fn_task_update_status'
      and pg_get_functiondef(p.oid) ilike '%recurrence_rule_id%'
      and pg_get_functiondef(p.oid) ilike '%concluida%'
  ) then
    raise exception 'Verification echouee : fn_task_update_status ne porte pas la regeneration recurrente.';
  end if;

  -- La fonction est restee SECURITY INVOKER (pas DEFINER).
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='fn_task_update_status' and p.prosecdef = true
  ) then
    raise exception 'Verification echouee : fn_task_update_status ne doit pas etre en mode definisseur (prosecdef).';
  end if;

  raise notice 'Migration 20260524050000 : verification OK (regeneration a l''achevement dans fn_task_update_status, INVOKER).';
end;
$verif$;
