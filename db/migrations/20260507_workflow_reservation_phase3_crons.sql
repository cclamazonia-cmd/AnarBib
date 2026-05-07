-- =============================================================================
-- Migration : Workflow réservation — Phase 3 (jobs pg_cron)
-- Date      : 2026-05-07
-- Spec      : docs/specs/spec-workflow-reservation.md section 6
-- =============================================================================
-- 2 fonctions cron + 2 jobs pg_cron pour automatiser :
--   - Expiration des solicitada non traitées (timeout en jours par lib)
--   - Détection no-show des pickups dépassés (timeout en heures par lib)
--
-- Architecture :
--   - Fonctions SECURITY DEFINER (auth.uid() = NULL en contexte cron)
--   - Sanity check via fn_check_workflow_transition(..., 'system')
--   - Écriture directe dans reserva_item_workflow_v2 (pas via api.*)
--   - Try/catch par ligne pour résilience
--   - Note de workflow remplie automatiquement
--   - Retour : (processed_count, error_count, details jsonb)
-- =============================================================================

-- =============================================================================
-- 1. fn_expire_solicitada_reservations
-- =============================================================================
-- Bascule en 'expirada' les réservations en stage 'solicitada' dont l'âge
-- (depuis reservas_v2.created_at) dépasse library_notification_policies
-- .reservation_solicitada_timeout_days (default 14, range 7-60).

CREATE OR REPLACE FUNCTION public.fn_expire_solicitada_reservations()
RETURNS TABLE(
  processed_count integer,
  error_count integer,
  details jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
      r.created_at AS reserva_created_at,
      r.library_id,
      lnp.reservation_solicitada_timeout_days AS timeout_days,
      now() - r.created_at AS age
    FROM public.reserva_item_workflow_v2 riw
    JOIN public.reservas_v2 r ON r.id = riw.reserva_id
    JOIN public.library_notification_policies lnp ON lnp.library_id = r.library_id
    WHERE riw.workflow_stage = 'solicitada'
      AND r.created_at < now() - make_interval(days => lnp.reservation_solicitada_timeout_days)
  LOOP
    BEGIN
      IF NOT public.fn_check_workflow_transition('solicitada', 'expirada', 'system') THEN
        RAISE EXCEPTION 'helper_refused_transition';
      END IF;

      UPDATE public.reserva_item_workflow_v2
      SET workflow_stage = 'expirada',
          workflow_note = format(
            'Expirée automatiquement par cron (timeout: %s jours, âge: %s)',
            v_row.timeout_days, v_row.age::text
          ),
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
$$;

REVOKE ALL ON FUNCTION public.fn_expire_solicitada_reservations() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_expire_solicitada_reservations() FROM anon;
REVOKE ALL ON FUNCTION public.fn_expire_solicitada_reservations() FROM authenticated;

COMMENT ON FUNCTION public.fn_expire_solicitada_reservations() IS
  'Job cron : expire les réservations en stage solicitada dont l''âge dépasse library_notification_policies.reservation_solicitada_timeout_days. Tourne en SECURITY DEFINER avec sanity check via fn_check_workflow_transition(actor=''system''). Try/catch par ligne pour résilience. Retourne (processed_count, error_count, details jsonb).';

-- =============================================================================
-- 2. fn_detect_no_show_reservations
-- =============================================================================
-- Bascule en 'retirada_no_show' les réservations en stage de retrait
-- (pronta_para_retirada, retirada_agendada, re-retirada_agendada) dont
-- pickup_scheduled_for + reservation_no_show_timeout_hours est dépassé
-- (default 24h, range 12-168).
-- Le trigger trg_auto_liberate_after_no_show cascade ensuite vers
-- liberada_para_circulacao avec final_reason='no_show'.

CREATE OR REPLACE FUNCTION public.fn_detect_no_show_reservations()
RETURNS TABLE(
  processed_count integer,
  error_count integer,
  details jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
          workflow_note = format(
            'No-show automatique par cron (pickup prévu: %s, timeout: %sh)',
            v_row.pickup_scheduled_for::text, v_row.timeout_hours
          ),
          updated_at = now()
      WHERE id = v_row.id;

      -- Le trigger trg_auto_liberate_after_no_show déclenche ensuite la bascule
      -- automatique vers liberada_para_circulacao avec final_reason='no_show'.

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
$$;

REVOKE ALL ON FUNCTION public.fn_detect_no_show_reservations() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_detect_no_show_reservations() FROM anon;
REVOKE ALL ON FUNCTION public.fn_detect_no_show_reservations() FROM authenticated;

COMMENT ON FUNCTION public.fn_detect_no_show_reservations() IS
  'Job cron : marque retirada_no_show les réservations en stage pronta_para_retirada/retirada_agendada/re-retirada_agendada dont pickup_scheduled_for + reservation_no_show_timeout_hours est dépassé. Le trigger trg_auto_liberate_after_no_show cascade ensuite vers liberada_para_circulacao avec final_reason=no_show. Retourne (processed_count, error_count, details jsonb).';

-- =============================================================================
-- 3. Déclaration des cron jobs (1h de granularité, démarrage décalé de 10 min)
-- =============================================================================

-- Expire solicitada : toutes les heures à xh:05
SELECT cron.schedule(
  'anarbib-reservation-expire-solicitada',
  '5 * * * *',
  $cron$ SELECT public.fn_expire_solicitada_reservations(); $cron$
);

-- Détect no-show : toutes les heures à xh:15
SELECT cron.schedule(
  'anarbib-reservation-detect-no-show',
  '15 * * * *',
  $cron$ SELECT public.fn_detect_no_show_reservations(); $cron$
);
