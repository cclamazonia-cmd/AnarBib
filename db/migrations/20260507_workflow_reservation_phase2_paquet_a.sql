-- =============================================================================
-- Migration : Workflow réservation — Phase 2 paquet A (5 wrappers + helper rôle)
-- Date      : 2026-05-07
-- Spec      : docs/specs/spec-workflow-reservation.md section 6
-- =============================================================================
-- Wrappers api.* SECURITY INVOKER appelant les fn_v2_* SECURITY DEFINER
-- existantes après validation de la matrice de transitions et des rôles.
--
-- Pattern commun :
--   1. Auth : auth.uid() requis
--   2. Contexte : lire reserva_item_workflow_v2 + reservas_v2 pour résoudre
--      current_stage, library_id, leitor_user_id
--   3. Validation : rôle + helper de matrice + paramètres
--   4. Délégation : fn_v2_* avec line_nos = ARRAY[p_line_no]
--
-- Décisions de design tranchées :
--   - cancel_my_reservation : tout-ou-rien sur multi-ligne (option B)
--   - refuse_pickup_slot : raison obligatoire ≥ 5 caractères
--   - advance_reservation : exclusion explicite des cibles
--     (retirada_efetivada, liberada_para_circulacao, expirada)
--   - mark_no_show : raccourci de advance_reservation('retirada_no_show')
--
-- Validé par 8 tests de rejet (T_AUTH_1, T_REJECT_1..8) — cf. SESSION_2026-05-07.md
-- =============================================================================

-- =============================================================================
-- 0. Helper de résolution de rôle pour une bibliothèque donnée
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_resolve_caller_role_for_library(
  p_library_id uuid
) RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN NULL;
  END IF;

  IF user_can_manage_library(p_library_id) THEN
    RETURN 'coordenador';
  END IF;

  IF user_has_library_staff_role(v_uid, p_library_id) THEN
    RETURN 'librarian';
  END IF;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_resolve_caller_role_for_library(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_resolve_caller_role_for_library(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_resolve_caller_role_for_library(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_resolve_caller_role_for_library(uuid) IS
  'Détermine le actor_role du caller pour une bibliothèque donnée. Retourne ''coordenador'' (couvre admin + coord), ''librarian'', ou NULL si caller non staff. Utilisé par les wrappers api.* du workflow réservation.';

-- =============================================================================
-- 1. api.cancel_my_reservation(p_reserva_id) — annulation lecteur (toutes lignes)
-- =============================================================================

CREATE OR REPLACE FUNCTION api.cancel_my_reservation(
  p_reserva_id bigint
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_lines record;
  v_eligible_lines integer[];
  v_total_lines integer;
  v_blocked_count integer;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT user_id INTO v_owner
  FROM public.reservas_v2
  WHERE id = p_reserva_id;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'reserva_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  v_total_lines := 0;
  v_blocked_count := 0;
  v_eligible_lines := ARRAY[]::integer[];

  FOR v_lines IN
    SELECT line_no, workflow_stage
    FROM public.reserva_item_workflow_v2
    WHERE reserva_id = p_reserva_id
  LOOP
    v_total_lines := v_total_lines + 1;
    IF public.fn_check_workflow_transition(
      v_lines.workflow_stage, 'cancelada_leitor', 'lecteur'
    ) THEN
      v_eligible_lines := array_append(v_eligible_lines, v_lines.line_no);
    ELSE
      v_blocked_count := v_blocked_count + 1;
    END IF;
  END LOOP;

  IF v_total_lines = 0 THEN
    RAISE EXCEPTION 'reserva_has_no_lines' USING ERRCODE = '02000';
  END IF;

  IF v_blocked_count > 0 THEN
    RAISE EXCEPTION 'cancel_blocked_by_stage'
      USING ERRCODE = '22023',
            HINT = format(
              'reserva %s : %s ligne(s) sur %s ne peuvent plus être annulées (état trop avancé)',
              p_reserva_id, v_blocked_count, v_total_lines
            );
  END IF;

  v_n := public.fn_v2_cancel_reserva_linhas_as_leitor(
    p_reserva_id, v_eligible_lines, NULL
  );
  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.cancel_my_reservation(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.cancel_my_reservation(bigint) FROM anon;
GRANT EXECUTE ON FUNCTION api.cancel_my_reservation(bigint) TO authenticated;

COMMENT ON FUNCTION api.cancel_my_reservation(bigint) IS
  'Annule toutes les lignes d''une réservation par son auteur·rice. Tout-ou-rien : si une seule ligne ne peut plus être annulée (stage trop avancé), l''opération échoue entièrement. Retourne le nombre de lignes annulées.';

-- =============================================================================
-- 2. api.confirm_pickup_slot(p_reserva_id, p_line_no)
-- =============================================================================

CREATE OR REPLACE FUNCTION api.confirm_pickup_slot(
  p_reserva_id bigint,
  p_line_no integer
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_current_stage text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT r.user_id, riw.workflow_stage
    INTO v_owner, v_current_stage
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  IF v_current_stage NOT IN ('retirada_agendada', 're-retirada_agendada', 'retirada_a_combinar') THEN
    RAISE EXCEPTION 'pickup_reply_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format('stage actuel = %s, attendu retirada_agendada|re-retirada_agendada|retirada_a_combinar', v_current_stage);
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_pickup_reply(
    p_reserva_id, ARRAY[p_line_no], 'confirmado_leitor', NULL
  );
  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.confirm_pickup_slot(bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.confirm_pickup_slot(bigint, integer) FROM anon;
GRANT EXECUTE ON FUNCTION api.confirm_pickup_slot(bigint, integer) TO authenticated;

COMMENT ON FUNCTION api.confirm_pickup_slot(bigint, integer) IS
  'Confirme le créneau de retrait proposé par la biblio (pickup_reply_status = confirmado_leitor). Réservé au lecteur·rice propriétaire. Valide uniquement si workflow_stage IN (retirada_agendada, re-retirada_agendada, retirada_a_combinar).';

-- =============================================================================
-- 3. api.refuse_pickup_slot(p_reserva_id, p_line_no, p_reason)
-- =============================================================================

CREATE OR REPLACE FUNCTION api.refuse_pickup_slot(
  p_reserva_id bigint,
  p_line_no integer,
  p_reason text
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_current_stage text;
  v_n integer;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason_required_min_5_chars'
      USING ERRCODE = '22023',
            HINT = 'Pour refuser un créneau, indique une raison d''au moins 5 caractères (ex : indisponibilité, autre lieu préféré, etc.)';
  END IF;

  SELECT r.user_id, riw.workflow_stage
    INTO v_owner, v_current_stage
  FROM public.reservas_v2 r
  JOIN public.reserva_item_workflow_v2 riw ON riw.reserva_id = r.id
  WHERE r.id = p_reserva_id AND riw.line_no = p_line_no;

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'reserva_line_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_owner <> v_uid THEN
    RAISE EXCEPTION 'not_your_reserva' USING ERRCODE = '42501';
  END IF;

  IF v_current_stage NOT IN ('retirada_agendada', 're-retirada_agendada', 'retirada_a_combinar') THEN
    RAISE EXCEPTION 'pickup_reply_not_applicable_in_stage'
      USING ERRCODE = '22023',
            HINT = format('stage actuel = %s, attendu retirada_agendada|re-retirada_agendada|retirada_a_combinar', v_current_stage);
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_pickup_reply(
    p_reserva_id, ARRAY[p_line_no], 'recusado_leitor', btrim(p_reason)
  );
  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.refuse_pickup_slot(bigint, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.refuse_pickup_slot(bigint, integer, text) FROM anon;
GRANT EXECUTE ON FUNCTION api.refuse_pickup_slot(bigint, integer, text) TO authenticated;

COMMENT ON FUNCTION api.refuse_pickup_slot(bigint, integer, text) IS
  'Refuse le créneau de retrait proposé par la biblio (pickup_reply_status = recusado_leitor). Raison obligatoire ≥ 5 caractères. Réservé au lecteur·rice propriétaire. Valide uniquement si workflow_stage IN (retirada_agendada, re-retirada_agendada, retirada_a_combinar).';

-- =============================================================================
-- 4. api.advance_reservation(p_reserva_id, p_line_no, p_target_stage, p_options)
-- =============================================================================

CREATE OR REPLACE FUNCTION api.advance_reservation(
  p_reserva_id bigint,
  p_line_no integer,
  p_target_stage text,
  p_options jsonb DEFAULT '{}'::jsonb
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
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

  IF p_target_stage IN ('retirada_agendada', 're-retirada_agendada', 'retirada_a_combinar')
     AND v_pickup IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = format(
              'cible %s requiert p_options->>''pickup_scheduled_for'' (timestamptz)',
              p_target_stage
            );
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], p_target_stage, v_note, v_pickup
  );
  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) TO authenticated;

COMMENT ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) IS
  'Fait progresser une ligne de réservation vers un stage cible. Réservé au staff (librarian/coordenador) de la biblio. Valide la matrice de transitions via fn_check_workflow_transition. Cibles exclues : retirada_efetivada (api.confirm_pickup_v1), liberada_para_circulacao (trigger auto), expirada (cron). p_options jsonb : {"note": "...", "pickup_scheduled_for": "ISO8601"}.';

-- =============================================================================
-- 5. api.mark_no_show(p_reserva_id, p_line_no) — raccourci staff
-- =============================================================================

CREATE OR REPLACE FUNCTION api.mark_no_show(
  p_reserva_id bigint,
  p_line_no integer
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
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

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_no_show', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'no-show non autorisé depuis %s pour rôle %s',
              v_current_stage, v_actor_role
            );
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], 'retirada_no_show', NULL, NULL
  );
  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.mark_no_show(bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.mark_no_show(bigint, integer) FROM anon;
GRANT EXECUTE ON FUNCTION api.mark_no_show(bigint, integer) TO authenticated;

COMMENT ON FUNCTION api.mark_no_show(bigint, integer) IS
  'Marque manuellement une ligne de réservation comme no-show (lecteur·rice non venu·e). Réservé au staff. Le trigger trg_auto_liberate_after_no_show déclenchera ensuite automatiquement la bascule vers liberada_para_circulacao avec final_reason=no_show. Raccourci de api.advance_reservation(..., target=retirada_no_show).';
