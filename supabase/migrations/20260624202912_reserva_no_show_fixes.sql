-- =========================================================================
-- Paquet RESERVA-NOSHOW-FIX — garde anti-retrait-passé + note no-show i18n
-- =========================================================================
-- Date     : 2026-06-24
-- Chantier : réservations / no-show (suite signalement Xavier 24/06)
--
-- Deux corrections :
--  1) api.advance_reservation : refuse un pickup_scheduled_for dans le passé
--     (sinon fn_detect_no_show_reservations marque no-show instantanément).
--     Nouvelle erreur codée : 'pickup_scheduled_for_in_past'.
--  2) fn_detect_no_show_reservations : écrit la sentinelle système
--     '@@note:systemNote.noShowAuto' (traduite dans la langue du destinataire
--     par decodeSystemNote) au lieu d'une note FRANÇAISE codée en dur qui
--     fuitait telle quelle dans le mail (« Observação »).
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.advance_reservation(p_reserva_id bigint, p_line_no integer, p_target_stage text, p_options jsonb DEFAULT '{}'::jsonb)
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
  v_proposed_by_arg text;
  v_clear_reply boolean;
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

  -- GARDE (fix 2026-06-24) : un retrait ne peut pas être planifié dans le passé,
  -- sinon fn_detect_no_show_reservations le marque no-show dès le run suivant.
  IF v_pickup IS NOT NULL AND v_pickup < now() THEN
    RAISE EXCEPTION 'pickup_scheduled_for_in_past'
      USING ERRCODE = '22023',
            HINT = format(
              'pickup_scheduled_for (%s) est dans le passé ; planifie le retrait dans le futur.',
              v_pickup::text
            );
  END IF;

  IF p_target_stage IN ('retirada_a_combinar') AND v_pickup IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = format(
              'cible %s requiert p_options->>''pickup_scheduled_for'' (timestamptz). Même approximatif, indique un créneau initial pour ouvrir la négociation.',
              p_target_stage
            );
  END IF;

  IF p_target_stage = 'retirada_a_combinar' THEN
    v_proposed_by_arg := 'biblio';
    v_clear_reply := true;
  ELSE
    v_proposed_by_arg := '__CLEAR__';
    v_clear_reply := true;
  END IF;

  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id,
    ARRAY[p_line_no],
    p_target_stage,
    v_note,
    v_pickup,
    v_proposed_by_arg,
    v_clear_reply
  );

  RETURN v_n;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_detect_no_show_reservations()
 RETURNS TABLE(processed_count integer, error_count integer, details jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_row record;
  v_processed integer := 0;
  v_errors integer := 0;
  v_errors_details jsonb := '[]'::jsonb;
BEGIN
  FOR v_row IN
    SELECT
      riw.id,
      riw.reserva_id,
      riw.line_no,
      riw.workflow_stage,
      riw.pickup_scheduled_for,
      r.library_id,
      lnp.reservation_no_show_timeout_hours AS timeout_hours
    FROM public.reserva_item_workflow_v2 riw
    JOIN public.reservas_v2 r ON r.id = riw.reserva_id
    JOIN public.library_notification_policies lnp ON lnp.library_id = r.library_id
    WHERE riw.workflow_stage IN ('pronta_para_retirada', 'retirada_agendada', 're-retirada_agendada')
      AND riw.pickup_scheduled_for IS NOT NULL
      AND riw.pickup_scheduled_for < now() - make_interval(hours => lnp.reservation_no_show_timeout_hours)
  LOOP
    BEGIN
      IF NOT public.fn_check_workflow_transition(v_row.workflow_stage, 'retirada_no_show', 'system') THEN
        RAISE EXCEPTION 'helper_refused_transition';
      END IF;

      UPDATE public.reserva_item_workflow_v2
      SET workflow_stage = 'retirada_no_show',
          -- Sentinelle système : traduite dans la langue du destinataire par
          -- decodeSystemNote (mail) / systemNotes.js (front). Voir clé
          -- systemNote.noShowAuto. (Remplace une note FR codée en dur.)
          workflow_note = '@@note:systemNote.noShowAuto',
          updated_at = now()
      WHERE id = v_row.id;

      v_processed := v_processed + 1;
    EXCEPTION
      WHEN OTHERS THEN
        v_errors := v_errors + 1;
        v_errors_details := v_errors_details || jsonb_build_object(
          'reserva_id', v_row.reserva_id,
          'line_no', v_row.line_no,
          'sqlstate', SQLSTATE,
          'message', SQLERRM
        );
    END;
  END LOOP;

  processed_count := v_processed;
  error_count := v_errors;
  details := jsonb_build_object(
    'run_at', now(),
    'errors', v_errors_details
  );
  RETURN NEXT;
END;
$function$;

-- Vérification
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_detect_no_show_reservations'
      AND pg_get_functiondef(p.oid) LIKE '%@@note:systemNote.noShowAuto%'
  ) THEN
    RAISE EXCEPTION 'RESERVA-NOSHOW-FIX : sentinelle systemNote.noShowAuto absente du cron';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = 'advance_reservation'
      AND pg_get_functiondef(p.oid) LIKE '%pickup_scheduled_for_in_past%'
  ) THEN
    RAISE EXCEPTION 'RESERVA-NOSHOW-FIX : garde pickup_scheduled_for_in_past absente';
  END IF;
  RAISE NOTICE 'RESERVA-NOSHOW-FIX OK.';
END $$;

COMMIT;
