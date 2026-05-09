-- ============================================================================
-- paquet6_fix_double_mails_optionD_ROLLBACK.sql
-- ============================================================================
-- Date : 2026-05-09
-- Rollback complet de paquet6_fix_double_mails_optionD.sql
--
-- Restaure les 4 fonctions à leur état d'origine (avant refactor Option D).
--
-- À utiliser uniquement si paquet6_fix_double_mails_optionD.sql cause une
-- régression imprévue. Le rollback restaure le bug du doublon de mails ; donc
-- à ne déclencher que si une autre régression critique apparaît.
--
-- IDEMPOTENT : peut être exécuté plusieurs fois sans effet.
-- ATTENTION : la nouvelle signature de fn_v2_set_reserva_linhas_workflow
--   (avec 7 arguments) sera supprimée, mais la version d'origine à 5 arguments
--   sera restaurée — les éventuels callsites qui auraient été écrits entre
--   temps avec 7 arguments échoueront. À éviter en prod active sans coordination.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Suppression de la nouvelle signature à 7 arguments + restauration des 5
-- ----------------------------------------------------------------------------
-- DROP est nécessaire car CREATE OR REPLACE ne peut pas changer la signature
-- d'une fonction (il faut la signature exacte).
DROP FUNCTION IF EXISTS public.fn_v2_set_reserva_linhas_workflow(
  bigint, integer[], text, text, timestamp with time zone, text, boolean
);

CREATE OR REPLACE FUNCTION public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id bigint,
    p_line_nos integer[],
    p_workflow_stage text,
    p_workflow_note text DEFAULT NULL::text,
    p_pickup_scheduled_for timestamp with time zone DEFAULT NULL::timestamp with time zone
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_stage text := trim(coalesce(p_workflow_stage, ''));
  v_updated int := 0;
begin
  if v_uid is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  if v_stage = '' then
    raise exception 'Etapa de workflow obrigatória.';
  end if;

  select r.library_id
    into v_library_id
  from public.reservas_v2 r
  where r.id = p_reserva_id;

  if v_library_id is null then
    raise exception 'Reserva não encontrada.';
  end if;

  if not exists (
    select 1
    from api.my_access a
    where a.user_id = v_uid
      and a.can_access_painel = true
      and a.library_id = v_library_id
  ) then
    raise exception 'Você não pode gerir esta reserva.';
  end if;

  update public.reserva_linhas_v2 rl
     set item_status = case
           when v_stage = 'cancelada_biblioteca' then 'cancelada_biblioteca'
           when v_stage = 'expirada' then 'expirada'
           when v_stage = 'liberada_para_circulacao' then 'liberada_para_circulacao'
           else rl.item_status
         end,
         cancelled_at = case
           when v_stage = 'cancelada_biblioteca' then coalesce(rl.cancelled_at, timezone('utc', now()))
           else rl.cancelled_at
         end,
         expired_at = case
           when v_stage = 'expirada' then coalesce(rl.expired_at, timezone('utc', now()))
           else rl.expired_at
         end,
         updated_at = timezone('utc', now())
   where rl.reserva_id = p_reserva_id
     and rl.line_no = any(p_line_nos)
     and rl.item_status = 'ativa';

  get diagnostics v_updated = row_count;

  insert into public.reserva_item_workflow_v2 (
    reserva_id,
    line_no,
    workflow_stage,
    workflow_note,
    pickup_scheduled_for,
    updated_at,
    updated_by
  )
  select
    rl.reserva_id,
    rl.line_no,
    v_stage,
    nullif(trim(p_workflow_note), ''),
    p_pickup_scheduled_for,
    timezone('utc', now()),
    v_uid
  from public.reserva_linhas_v2 rl
  where rl.reserva_id = p_reserva_id
    and rl.line_no = any(p_line_nos)
  on conflict (reserva_id, line_no)
  do update
     set workflow_stage = excluded.workflow_stage,
         workflow_note = coalesce(excluded.workflow_note, public.reserva_item_workflow_v2.workflow_note),
         pickup_scheduled_for = coalesce(excluded.pickup_scheduled_for, public.reserva_item_workflow_v2.pickup_scheduled_for),
         updated_at = excluded.updated_at,
         updated_by = excluded.updated_by;

  perform public.fn_v2_refresh_reserva_status_global(p_reserva_id);
  perform public.fn_v2_recompute_from_reserva_lines(p_reserva_id, p_line_nos);

  return v_updated;
end;
$function$;


-- ----------------------------------------------------------------------------
-- 2. Restaurer fn_propose_pickup_slot_as_library (avec 2e UPDATE manuel)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_propose_pickup_slot_as_library(
    p_reserva_id bigint,
    p_line_no integer,
    p_pickup_at timestamp with time zone,
    p_note text DEFAULT NULL::text
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_actor_role text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_pickup_at IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = 'p_pickup_at (timestamptz) est obligatoire pour une proposition de créneau';
  END IF;

  IF p_pickup_at < now() THEN
    RAISE EXCEPTION 'pickup_scheduled_for_in_past'
      USING ERRCODE = '22023',
            HINT = 'le créneau proposé doit être dans le futur';
  END IF;

  SELECT r.library_id, riw.workflow_stage
    INTO v_library_id, v_current_stage
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);
  IF v_actor_role IS NULL THEN
    RAISE EXCEPTION 'not_staff_of_this_library' USING ERRCODE = '42501';
  END IF;

  IF v_current_stage NOT IN ('solicitada', 'em_preparacao', 'retirada_a_combinar') THEN
    RAISE EXCEPTION 'pickup_proposal_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. Les propositions de créneau sont valides depuis solicitada, em_preparacao ou retirada_a_combinar.',
              v_current_stage
            );
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_a_combinar', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_a_combinar refusée pour rôle %s',
              v_current_stage, v_actor_role
            );
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_a_combinar', p_note, p_pickup_at
  );

  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = 'biblio',
      pickup_reply_status = NULL,
      pickup_reply_note = NULL,
      pickup_reply_at = NULL
  WHERE reserva_id = p_reserva_id AND line_no = p_line_no;

  RETURN v_n;
END;
$function$;


-- ----------------------------------------------------------------------------
-- 3. Restaurer fn_propose_pickup_slot_as_reader
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_propose_pickup_slot_as_reader(
    p_reserva_id bigint,
    p_line_no integer,
    p_pickup_at timestamp with time zone,
    p_note text DEFAULT NULL::text
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_library_id uuid;
  v_current_stage text;
  v_iteration_count int;
  v_allow_counter boolean;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_pickup_at IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = 'p_pickup_at (timestamptz) est obligatoire pour une contre-proposition';
  END IF;

  IF p_pickup_at < now() THEN
    RAISE EXCEPTION 'pickup_scheduled_for_in_past'
      USING ERRCODE = '22023',
            HINT = 'le créneau proposé doit être dans le futur';
  END IF;

  SELECT
    r.user_id,
    r.library_id,
    riw.workflow_stage,
    riw.negotiation_iteration_count,
    lnp.reservation_allow_reader_counter_proposal
  INTO
    v_owner,
    v_library_id,
    v_current_stage,
    v_iteration_count,
    v_allow_counter
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  LEFT JOIN public.library_notification_policies lnp ON lnp.library_id = r.library_id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  IF v_current_stage <> 'retirada_a_combinar' THEN
    RAISE EXCEPTION 'pickup_counter_proposal_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La contre-proposition n''est valide que pendant la négociation active (retirada_a_combinar).',
              v_current_stage
            );
  END IF;

  IF v_allow_counter IS NOT NULL AND v_allow_counter = false THEN
    RAISE EXCEPTION 'pickup_counter_proposal_disabled_by_library'
      USING ERRCODE = '42501',
            HINT = 'Cette bibliothèque n''accepte pas les contre-propositions de créneau. Tu peux confirmer le créneau proposé ou annuler ta réservation.';
  END IF;

  IF v_iteration_count >= 3 THEN
    RAISE EXCEPTION 'pickup_negotiation_max_iterations_reached'
      USING ERRCODE = '22023',
            HINT = 'La négociation a atteint sa limite de 3 contre-propositions. Pour finaliser, contacte directement la biblio par téléphone, mail ou de visu.';
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_a_combinar', 'lecteur') THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_a_combinar refusée pour lecteur (incohérence helper, à investiguer)',
              v_current_stage
            );
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_a_combinar', p_note, p_pickup_at
  );

  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = 'leitor',
      pickup_reply_status = NULL,
      pickup_reply_note = NULL,
      pickup_reply_at = NULL
  WHERE reserva_id = p_reserva_id AND line_no = p_line_no;

  RETURN v_n;
END;
$function$;


-- ----------------------------------------------------------------------------
-- 4. Restaurer api.advance_reservation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.advance_reservation(
    p_reserva_id bigint,
    p_line_no integer,
    p_target_stage text,
    p_options jsonb DEFAULT '{}'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_actor_role text;
  v_note text;
  v_pickup timestamptz;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_target_stage IN ('retirada_efetivada', 'liberada_para_circulacao', 'expirada') THEN
    RAISE EXCEPTION 'target_stage_has_dedicated_rpc'
      USING ERRCODE = '22023',
            HINT = format(
              'cible %s non autorisée via api.advance_reservation. Utilise api.confirm_pickup_v1 (retirada_efetivada) ; les autres sont automatiques (cron/trigger).',
              p_target_stage
            );
  END IF;

  IF p_target_stage = 'retirada_agendada' THEN
    RAISE EXCEPTION 'target_stage_has_dedicated_rpc'
      USING ERRCODE = '22023',
            HINT = 'cible retirada_agendada non autorisée via advance_reservation. Le seul chemin légitime est la confirmation mutuelle (api.fn_confirm_pickup_slot_as_library ou as_reader) depuis retirada_a_combinar. Utilise api.fn_propose_pickup_slot_as_library pour ouvrir une négociation.';
  END IF;

  IF p_target_stage = 're-retirada_agendada' THEN
    RAISE EXCEPTION 'target_stage_deprecated'
      USING ERRCODE = '22023',
            HINT = 'cible re-retirada_agendada dépréciée par le refactor v3. Utilise retirada_a_combinar pour la négociation symétrique.';
  END IF;

  SELECT r.library_id, riw.workflow_stage
    INTO v_library_id, v_current_stage
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);
  IF v_actor_role IS NULL THEN
    RAISE EXCEPTION 'not_staff_of_this_library' USING ERRCODE = '42501';
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, p_target_stage, v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → %s refusée pour rôle %s',
              v_current_stage, p_target_stage, v_actor_role
            );
  END IF;

  v_note := p_options->>'note';
  v_pickup := CASE
    WHEN p_options ? 'pickup_scheduled_for'
      THEN (p_options->>'pickup_scheduled_for')::timestamptz
    ELSE NULL
  END;

  IF p_target_stage IN ('retirada_a_combinar') AND v_pickup IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = format(
              'cible %s requiert p_options->>''pickup_scheduled_for'' (timestamptz). Même approximatif, indique un créneau initial pour ouvrir la négociation.',
              p_target_stage
            );
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], p_target_stage, v_note, v_pickup
  );

  IF p_target_stage = 'retirada_a_combinar' THEN
    UPDATE public.reserva_item_workflow_v2
    SET pickup_proposed_by   = 'biblio',
        pickup_reply_status  = NULL,
        pickup_reply_note    = NULL,
        pickup_reply_at      = NULL
    WHERE reserva_id = p_reserva_id AND line_no = p_line_no;
  ELSE
    UPDATE public.reserva_item_workflow_v2
    SET pickup_proposed_by   = NULL,
        pickup_reply_status  = NULL,
        pickup_reply_note    = NULL,
        pickup_reply_at      = NULL
    WHERE reserva_id = p_reserva_id AND line_no = p_line_no
      AND pickup_proposed_by IS NOT NULL;
  END IF;

  RETURN v_n;
END;
$function$;


-- ----------------------------------------------------------------------------
-- 5. Restaurer api.fn_confirm_pickup_slot_as_library (avec 2e UPDATE manuel)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_confirm_pickup_slot_as_library(
    p_reserva_id bigint,
    p_line_no integer
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_proposed_by text;
  v_pickup_at timestamptz;
  v_actor_role text;
  v_audit_note text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT
    r.library_id,
    riw.workflow_stage,
    riw.pickup_proposed_by,
    riw.pickup_scheduled_for
  INTO
    v_library_id,
    v_current_stage,
    v_proposed_by,
    v_pickup_at
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);
  IF v_actor_role IS NULL THEN
    RAISE EXCEPTION 'not_staff_of_this_library' USING ERRCODE = '42501';
  END IF;

  IF v_current_stage <> 'retirada_a_combinar' THEN
    RAISE EXCEPTION 'pickup_confirmation_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La confirmation n''est valide que depuis retirada_a_combinar (négociation active).',
              v_current_stage
            );
  END IF;

  IF v_proposed_by IS NULL THEN
    RAISE EXCEPTION 'pickup_no_active_proposal'
      USING ERRCODE = '22023',
            HINT = 'aucune proposition active à confirmer (pickup_proposed_by IS NULL).';
  END IF;

  IF v_proposed_by <> 'leitor' THEN
    RAISE EXCEPTION 'pickup_confirmation_wrong_proposer'
      USING ERRCODE = '22023',
            HINT = format(
              'pickup_proposed_by = %s. La biblio ne peut confirmer que les contre-propositions du lecteur·rice (pickup_proposed_by = ''leitor''). Si tu veux re-proposer un autre créneau, utilise fn_propose_pickup_slot_as_library.',
              v_proposed_by
            );
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_agendada', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_agendada refusée pour rôle %s (incohérence helper, à investiguer)',
              v_current_stage, v_actor_role
            );
  END IF;

  v_audit_note := format(
    '[autoconf-by-library] %s — créneau verrouillé (retirada_agendada) après contre-proposition lecteur·rice (créneau: %s)',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    COALESCE(to_char(v_pickup_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'NULL')
  );

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_agendada', v_audit_note, v_pickup_at
  );

  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = NULL,
      pickup_reply_status = NULL,
      pickup_reply_note = NULL,
      pickup_reply_at = NULL
  WHERE reserva_id = p_reserva_id AND line_no = p_line_no;

  RETURN v_n;
END;
$function$;


-- ----------------------------------------------------------------------------
-- 6. Restaurer api.fn_confirm_pickup_slot_as_reader (avec 2e UPDATE manuel)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_confirm_pickup_slot_as_reader(
    p_reserva_id bigint,
    p_line_no integer
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_current_stage text;
  v_proposed_by text;
  v_pickup_at timestamptz;
  v_audit_note text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT
    r.user_id,
    riw.workflow_stage,
    riw.pickup_proposed_by,
    riw.pickup_scheduled_for
  INTO
    v_owner,
    v_current_stage,
    v_proposed_by,
    v_pickup_at
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  IF v_current_stage <> 'retirada_a_combinar' THEN
    RAISE EXCEPTION 'pickup_confirmation_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s. La confirmation n''est valide que depuis retirada_a_combinar (négociation active).',
              v_current_stage
            );
  END IF;

  IF v_proposed_by IS NULL THEN
    RAISE EXCEPTION 'pickup_no_active_proposal'
      USING ERRCODE = '22023',
            HINT = 'aucune proposition active à confirmer (pickup_proposed_by IS NULL).';
  END IF;

  IF v_proposed_by <> 'biblio' THEN
    RAISE EXCEPTION 'pickup_confirmation_wrong_proposer'
      USING ERRCODE = '22023',
            HINT = format(
              'pickup_proposed_by = %s. Tu ne peux confirmer que les créneaux proposés par la biblio (pickup_proposed_by = ''biblio''). Si tu veux contre-proposer un autre créneau, utilise fn_propose_pickup_slot_as_reader.',
              v_proposed_by
            );
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_agendada', 'lecteur') THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_agendada refusée pour lecteur (incohérence helper, à investiguer)',
              v_current_stage
            );
  END IF;

  v_audit_note := format(
    '[autoconf-by-reader] %s — créneau verrouillé (retirada_agendada) après proposition biblio (créneau: %s)',
    to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    COALESCE(to_char(v_pickup_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'NULL')
  );

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_agendada', v_audit_note, v_pickup_at
  );

  UPDATE public.reserva_item_workflow_v2
  SET pickup_proposed_by = NULL,
      pickup_reply_status = NULL,
      pickup_reply_note = NULL,
      pickup_reply_at = NULL
  WHERE reserva_id = p_reserva_id AND line_no = p_line_no;

  RETURN v_n;
END;
$function$;


COMMIT;
