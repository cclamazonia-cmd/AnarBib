-- ============================================================
-- Fix : les lecteurs ne peuvent ni accepter ni contre-proposer un créneau de retrait.
-- Symptôme : « Erro: Você não pode gerir esta reserva. » au clic sur
--   « Aceitar este horário » / « Propor outro horário » (compte lecteur).
-- Cause : api.fn_confirm_pickup_slot_as_reader et api.fn_propose_pickup_slot_as_reader
--   délèguent (refactor « paquet6 fix-up » 2026-05-09) à
--   public.fn_v2_set_reserva_linhas_workflow, qui exige un accès panel
--   (api.my_access.can_access_painel) -> rejet pour tout lecteur (role=reader),
--   auth.uid() restant celui du lecteur même en SECURITY DEFINER.
-- Correctif : extraire le coeur d'écriture (sans garde panel) dans
--   public.fn_v2_set_reserva_linhas_workflow_core (NON exposé à anon/authenticated) ;
--   conserver la garde panel dans le wrapper staff public ; router les wrappers
--   lecteur (passés en SECURITY DEFINER) vers le coeur, après leurs propres
--   contrôles d'autorisation (propriété + précondition + transition lecteur).
--   => pas d'élévation de privilège : appel direct du coeur refusé (REVOKE),
--      appel direct du wrapper staff toujours gardé par le panel.
-- ============================================================

-- 1) Coeur interne : logique d'écriture du workflow, SANS garde d'accès.
CREATE OR REPLACE FUNCTION public.fn_v2_set_reserva_linhas_workflow_core(
  p_reserva_id bigint,
  p_line_nos integer[],
  p_workflow_stage text,
  p_workflow_note text DEFAULT NULL::text,
  p_pickup_scheduled_for timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_pickup_proposed_by text DEFAULT NULL::text,
  p_clear_pickup_reply boolean DEFAULT false
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_stage text := trim(coalesce(p_workflow_stage, ''));
  v_updated int := 0;
  v_pb_resolved text;
  v_pb_should_set boolean := (p_pickup_proposed_by IS NOT NULL);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  IF v_stage = '' THEN
    RAISE EXCEPTION 'Etapa de workflow obrigatória.';
  END IF;

  IF v_pb_should_set THEN
    IF p_pickup_proposed_by NOT IN ('biblio', 'leitor', '__CLEAR__') THEN
      RAISE EXCEPTION 'p_pickup_proposed_by deve ser ''biblio'', ''leitor'' ou ''__CLEAR__'' (recebido: %).', p_pickup_proposed_by
        USING ERRCODE = '22023';
    END IF;
    v_pb_resolved := CASE WHEN p_pickup_proposed_by = '__CLEAR__' THEN NULL ELSE p_pickup_proposed_by END;
  END IF;

  SELECT r.library_id INTO v_library_id
  FROM public.reservas_v2 r
  WHERE r.id = p_reserva_id;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'Reserva não encontrada.';
  END IF;

  -- NB : aucune garde d'accès ici. Le contrôle d'autorisation est porté par les
  -- wrappers appelants (fn_v2_set_reserva_linhas_workflow = staff/panel ;
  -- fn_confirm/propose_pickup_slot_as_reader = propriété + transition lecteur).
  -- Cette fonction n'est PAS exposée à anon/authenticated (REVOKE plus bas).

  UPDATE public.reserva_linhas_v2 rl
     SET item_status = CASE
           WHEN v_stage = 'cancelada_biblioteca' THEN 'cancelada_biblioteca'
           WHEN v_stage = 'expirada' THEN 'expirada'
           WHEN v_stage = 'liberada_para_circulacao' THEN 'liberada_para_circulacao'
           ELSE rl.item_status
         END,
         cancelled_at = CASE
           WHEN v_stage = 'cancelada_biblioteca' THEN coalesce(rl.cancelled_at, timezone('utc', now()))
           ELSE rl.cancelled_at
         END,
         expired_at = CASE
           WHEN v_stage = 'expirada' THEN coalesce(rl.expired_at, timezone('utc', now()))
           ELSE rl.expired_at
         END,
         updated_at = timezone('utc', now())
   WHERE rl.reserva_id = p_reserva_id
     AND rl.line_no = ANY(p_line_nos)
     AND rl.item_status = 'ativa';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  INSERT INTO public.reserva_item_workflow_v2 (
    reserva_id,
    line_no,
    workflow_stage,
    workflow_note,
    pickup_scheduled_for,
    pickup_proposed_by,
    pickup_reply_status,
    pickup_reply_note,
    pickup_reply_at,
    updated_at,
    updated_by
  )
  SELECT
    rl.reserva_id,
    rl.line_no,
    v_stage,
    nullif(trim(p_workflow_note), ''),
    p_pickup_scheduled_for,
    CASE WHEN v_pb_should_set THEN v_pb_resolved ELSE NULL END,
    NULL,
    NULL,
    NULL,
    timezone('utc', now()),
    v_uid
  FROM public.reserva_linhas_v2 rl
  WHERE rl.reserva_id = p_reserva_id
    AND rl.line_no = ANY(p_line_nos)
  ON CONFLICT (reserva_id, line_no)
  DO UPDATE
     SET workflow_stage = excluded.workflow_stage,
         workflow_note = coalesce(excluded.workflow_note, public.reserva_item_workflow_v2.workflow_note),
         pickup_scheduled_for = coalesce(excluded.pickup_scheduled_for, public.reserva_item_workflow_v2.pickup_scheduled_for),
         pickup_proposed_by = CASE
           WHEN v_pb_should_set THEN v_pb_resolved
           ELSE public.reserva_item_workflow_v2.pickup_proposed_by
         END,
         pickup_reply_status = CASE
           WHEN p_clear_pickup_reply THEN NULL
           ELSE public.reserva_item_workflow_v2.pickup_reply_status
         END,
         pickup_reply_note = CASE
           WHEN p_clear_pickup_reply THEN NULL
           ELSE public.reserva_item_workflow_v2.pickup_reply_note
         END,
         pickup_reply_at = CASE
           WHEN p_clear_pickup_reply THEN NULL
           ELSE public.reserva_item_workflow_v2.pickup_reply_at
         END,
         updated_at = excluded.updated_at,
         updated_by = excluded.updated_by;

  PERFORM public.fn_v2_refresh_reserva_status_global(p_reserva_id);
  PERFORM public.fn_v2_recompute_from_reserva_lines(p_reserva_id, p_line_nos);

  RETURN v_updated;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_v2_set_reserva_linhas_workflow_core(bigint, integer[], text, text, timestamptz, text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_v2_set_reserva_linhas_workflow_core(bigint, integer[], text, text, timestamptz, text, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.fn_v2_set_reserva_linhas_workflow_core(bigint, integer[], text, text, timestamptz, text, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_v2_set_reserva_linhas_workflow_core(bigint, integer[], text, text, timestamptz, text, boolean) TO service_role;

-- 2) Wrapper staff public : garde panel conservée, délègue au coeur. Signature/grants inchangés.
CREATE OR REPLACE FUNCTION public.fn_v2_set_reserva_linhas_workflow(
  p_reserva_id bigint,
  p_line_nos integer[],
  p_workflow_stage text,
  p_workflow_note text DEFAULT NULL::text,
  p_pickup_scheduled_for timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_pickup_proposed_by text DEFAULT NULL::text,
  p_clear_pickup_reply boolean DEFAULT false
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  SELECT r.library_id INTO v_library_id
  FROM public.reservas_v2 r
  WHERE r.id = p_reserva_id;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'Reserva não encontrada.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM api.my_access a
    WHERE a.user_id = v_uid
      AND a.can_access_painel = true
      AND a.library_id = v_library_id
  ) THEN
    RAISE EXCEPTION 'Você não pode gerir esta reserva.';
  END IF;

  RETURN public.fn_v2_set_reserva_linhas_workflow_core(
    p_reserva_id,
    p_line_nos,
    p_workflow_stage,
    p_workflow_note,
    p_pickup_scheduled_for,
    p_pickup_proposed_by,
    p_clear_pickup_reply
  );
END;
$function$;

-- 3) Wrapper lecteur « accepter le créneau » : SECURITY DEFINER + appel au coeur.
CREATE OR REPLACE FUNCTION api.fn_confirm_pickup_slot_as_reader(p_reserva_id bigint, p_line_no integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Appel au COEUR (sans garde panel). Les contrôles d'autorisation lecteur
  -- ci-dessus (propriété, précondition, transition) suffisent.
  v_n := public.fn_v2_set_reserva_linhas_workflow_core(
    p_reserva_id,
    ARRAY[p_line_no],
    'retirada_agendada',
    v_audit_note,
    v_pickup_at,
    '__CLEAR__',
    true
  );

  RETURN v_n;
END;
$function$;

-- 4) Wrapper lecteur « contre-proposer un créneau » : SECURITY DEFINER + appel au coeur.
CREATE OR REPLACE FUNCTION api.fn_propose_pickup_slot_as_reader(p_reserva_id bigint, p_line_no integer, p_pickup_at timestamp with time zone, p_note text DEFAULT NULL::text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Appel au COEUR (sans garde panel). Le trigger BEFORE fn_increment_negotiation_counter
  -- incrémente le compteur sur ce seul UPDATE (1 fois).
  v_n := public.fn_v2_set_reserva_linhas_workflow_core(
    p_reserva_id,
    ARRAY[p_line_no],
    'retirada_a_combinar',
    p_note,
    p_pickup_at,
    'leitor',
    true
  );

  RETURN v_n;
END;
$function$;
