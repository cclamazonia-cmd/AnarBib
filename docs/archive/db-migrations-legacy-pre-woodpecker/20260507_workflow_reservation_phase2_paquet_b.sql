-- =============================================================================
-- Migration : Workflow réservation — Phase 2 paquet B (2 wrappers sensibles)
-- Date      : 2026-05-07
-- Spec      : docs/specs/spec-workflow-reservation.md section 6
-- =============================================================================
-- Wrappers api.* SECURITY INVOKER pour les transitions sensibles :
--   - api.confirm_pickup_v1     : conversion atomique reserva → emprunt
--   - api.cancel_reservation_as_library : annulation par biblio (coordenador)
--
-- Décisions de design tranchées :
--   - confirm_pickup_v1 : strict workflow_stage = 'pronta_para_retirada'
--                         retourne loan_id (bigint) du nouvel emprunt
--                         due_at optionnel (calcule via fn_v2 si NULL)
--   - cancel_reservation_as_library : exclusif coordenador (pas librarian)
--                                     raison obligatoire ≥ 5 chars si stage
--                                     ∈ retirada_agendada / re-retirada_agendada
--                                     / retirada_a_combinar / pronta_para_retirada
--
-- Validé par 7 tests de rejet (T_B_1..7) — cf. SESSION_2026-05-07.md
-- =============================================================================

-- =============================================================================
-- 6. api.confirm_pickup_v1(p_reserva_id, p_line_no, p_loan_options) → loan_id
-- =============================================================================

CREATE OR REPLACE FUNCTION api.confirm_pickup_v1(
  p_reserva_id bigint,
  p_line_no integer,
  p_loan_options jsonb DEFAULT '{}'::jsonb
) RETURNS bigint
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_actor_role text;
  v_due_at date;
  v_note text;
  v_loan_id bigint;
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

  IF v_current_stage <> 'pronta_para_retirada' THEN
    RAISE EXCEPTION 'pickup_only_from_pronta_para_retirada'
      USING ERRCODE = '22023',
            HINT = format(
              'stage actuel = %s, attendu pronta_para_retirada. Utilise api.advance_reservation pour les transitions intermédiaires.',
              v_current_stage
            );
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'retirada_efetivada', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'transition %s → retirada_efetivada refusée pour rôle %s (incohérence helper, à investiguer)',
              v_current_stage, v_actor_role
            );
  END IF;

  v_due_at := CASE
    WHEN p_loan_options ? 'due_at'
      THEN (p_loan_options->>'due_at')::date
    ELSE NULL
  END;
  v_note := p_loan_options->>'note';

  v_loan_id := public.fn_v2_convert_reserva_linhas_to_emprestimo(
    p_reserva_id, ARRAY[p_line_no], v_due_at, v_note
  );

  RETURN v_loan_id;
END;
$$;

REVOKE ALL ON FUNCTION api.confirm_pickup_v1(bigint, integer, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.confirm_pickup_v1(bigint, integer, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION api.confirm_pickup_v1(bigint, integer, jsonb) TO authenticated;

COMMENT ON FUNCTION api.confirm_pickup_v1(bigint, integer, jsonb) IS
  'Convertit atomiquement une ligne de réservation en emprunt (transition pronta_para_retirada → retirada_efetivada). Réservé au staff de la biblio. Restriction stricte : seul le stage pronta_para_retirada autorise cette opération. La fonction sous-jacente vérifie automatiquement le statut de cotisation et calcule due_at via la politique de circulation de la biblio (sauf si fourni dans p_loan_options). Retourne le loan_id (bigint) du nouvel emprunt. p_loan_options : {"due_at": "YYYY-MM-DD", "note": "..."}.';

-- =============================================================================
-- 7. api.cancel_reservation_as_library(p_reserva_id, p_line_no, p_reason)
-- =============================================================================

CREATE OR REPLACE FUNCTION api.cancel_reservation_as_library(
  p_reserva_id bigint,
  p_line_no integer,
  p_reason text DEFAULT NULL
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
  v_reason_required boolean;
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

  -- Exclusion explicite des librarians (message clair plutôt que transition_not_allowed)
  IF v_actor_role = 'librarian' THEN
    RAISE EXCEPTION 'coordenador_required'
      USING ERRCODE = '42501',
            HINT = 'L''annulation d''une réservation par la biblio est une décision politique réservée aux coordenadores et administradores.';
  END IF;

  -- Raison conditionnelle : obligatoire si la biblio s'est déjà engagée
  v_reason_required := v_current_stage IN (
    'retirada_agendada',
    're-retirada_agendada',
    'retirada_a_combinar',
    'pronta_para_retirada'
  );

  IF v_reason_required AND (p_reason IS NULL OR length(btrim(p_reason)) < 5) THEN
    RAISE EXCEPTION 'reason_required_min_5_chars'
      USING ERRCODE = '22023',
            HINT = format(
              'À ce stade (%s), un retrait a été planifié avec le lecteur·rice. Une raison d''au moins 5 caractères est requise par respect.',
              v_current_stage
            );
  END IF;

  IF NOT public.fn_check_workflow_transition(v_current_stage, 'cancelada_biblioteca', v_actor_role) THEN
    RAISE EXCEPTION 'transition_not_allowed'
      USING ERRCODE = '22023',
            HINT = format(
              'cancelada_biblioteca refusée depuis %s pour rôle %s',
              v_current_stage, v_actor_role
            );
  END IF;

  v_n := public.fn_v2_cancel_reserva_linhas_as_biblioteca(
    p_reserva_id, ARRAY[p_line_no], CASE WHEN p_reason IS NOT NULL THEN btrim(p_reason) ELSE NULL END
  );

  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.cancel_reservation_as_library(bigint, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.cancel_reservation_as_library(bigint, integer, text) FROM anon;
GRANT EXECUTE ON FUNCTION api.cancel_reservation_as_library(bigint, integer, text) TO authenticated;

COMMENT ON FUNCTION api.cancel_reservation_as_library(bigint, integer, text) IS
  'Annule une ligne de réservation au nom de la bibliothèque (transition vers cancelada_biblioteca). Réservé aux coordenadores/administradores (pas aux librarians). Raison obligatoire ≥ 5 caractères si la biblio s''est déjà engagée avec le lecteur (stages retirada_agendada/re-retirada_agendada/retirada_a_combinar/pronta_para_retirada). Optionnelle pour solicitada/em_preparacao. Le trigger trg_auto_liberate_after_no_show déclenchera ensuite la bascule automatique vers liberada_para_circulacao avec final_reason=cancelled_by_library.';
