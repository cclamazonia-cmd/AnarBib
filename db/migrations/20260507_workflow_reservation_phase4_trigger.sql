-- =============================================================================
-- Migration : Workflow réservation — Phase 4 trigger avec lecture flags
-- Date      : 2026-05-07
-- Spec      : docs/specs/spec-workflow-reservation.md section 7
-- =============================================================================
-- Réécriture de trg_notify_reserva_workflow_change pour :
--   1. Router em_preparacao (manquant avant — avalé par ELSE RETURN NEW)
--   2. Lire les 12 flags reservation_mail_*_enabled avant de dispatcher
--   3. Skip silencieux si flag false (pas d'appel HTTP inutile vers notify-event)
--
-- Lecture flag : SELECT direct sur library_notification_policies, jointure via
-- reservas_v2.library_id. Si pas de policy (cas improbable), on dispatche par
-- défaut (fail-open : un mail manqué vaut mieux qu'une réservation invisible).
--
-- Note : la signature du trigger reste identique
-- (CREATE TRIGGER trg_notify_reserva_workflow déjà en place sur la table).
-- Cette migration met juste à jour la fonction, pas le trigger lui-même.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.trg_notify_reserva_workflow_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event text;
  v_flag_column text;
  v_enabled boolean;
  v_library_id uuid;
BEGIN
  -- =============================================================
  -- Bloc 1 : changement de workflow_stage
  -- =============================================================
  IF TG_OP = 'INSERT' OR (OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage) THEN
    v_event := NULL;
    v_flag_column := NULL;

    -- Mapping stage → (event, flag_column)
    IF NEW.workflow_stage = 'solicitada' AND TG_OP = 'INSERT' THEN
      v_event := 'reserva_v2_criada';
      v_flag_column := 'reservation_mail_solicitada_enabled';
    ELSIF NEW.workflow_stage = 'em_preparacao' THEN
      v_event := 'em_preparacao';
      v_flag_column := 'reservation_mail_em_preparacao_enabled';
    ELSIF NEW.workflow_stage = 'pronta_para_retirada' THEN
      v_event := 'pronta_para_retirada';
      v_flag_column := 'reservation_mail_pronta_para_retirada_enabled';
    ELSIF NEW.workflow_stage = 'retirada_agendada' THEN
      v_event := 'retirada_agendada';
      v_flag_column := 'reservation_mail_retirada_agendada_enabled';
    ELSIF NEW.workflow_stage = 'retirada_a_combinar' THEN
      v_event := 'retirada_a_combinar';
      v_flag_column := 'reservation_mail_retirada_a_combinar_enabled';
    ELSIF NEW.workflow_stage = 're-retirada_agendada' THEN
      v_event := 'retirada_reagendada';
      v_flag_column := 'reservation_mail_retirada_reagendada_enabled';
    ELSIF NEW.workflow_stage IN ('nao_retirada', 'retirada_no_show') THEN
      v_event := 'reserva_nao_retirada';
      v_flag_column := 'reservation_mail_retirada_no_show_enabled';
    ELSIF NEW.workflow_stage = 'liberada_para_circulacao' THEN
      v_event := 'liberada_para_circulacao';
      v_flag_column := 'reservation_mail_liberada_para_circulacao_enabled';
    ELSIF NEW.workflow_stage = 'cancelada_biblioteca' THEN
      v_event := 'reserva_cancelada_biblioteca';
      v_flag_column := 'reservation_mail_cancelada_biblioteca_enabled';
    ELSIF NEW.workflow_stage = 'cancelada_leitor' THEN
      v_event := 'reserva_cancelada_leitor';
      v_flag_column := 'reservation_mail_cancelada_leitor_enabled';
    ELSIF NEW.workflow_stage = 'expirada' THEN
      v_event := 'reserva_expirada';
      v_flag_column := 'reservation_mail_expirada_enabled';
    ELSIF NEW.workflow_stage = 'retirada_efetivada' THEN
      v_event := 'reserva_convertida_em_emprestimo';
      v_flag_column := 'reservation_mail_retirada_efetivada_enabled';
    END IF;

    IF v_event IS NOT NULL THEN
      -- Lire le flag de la lib
      SELECT r.library_id INTO v_library_id
      FROM public.reservas_v2 r
      WHERE r.id = NEW.reserva_id;

      v_enabled := true;  -- fail-open par défaut

      IF v_library_id IS NOT NULL AND v_flag_column IS NOT NULL THEN
        EXECUTE format(
          'SELECT %I FROM public.library_notification_policies WHERE library_id = $1',
          v_flag_column
        ) INTO v_enabled USING v_library_id;
        v_enabled := COALESCE(v_enabled, true);
      END IF;

      IF v_enabled THEN
        PERFORM fn_dispatch_circulation_notify_event(
          v_event, NEW.reserva_id,
          jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no))
        );
      END IF;
    END IF;
  END IF;

  -- =============================================================
  -- Bloc 2 : changement de pickup_reply_status
  -- (les mails "lecteur confirme/refuse créneau" sont admin-only,
  --  pas concernés par les flags reservation_mail_*_enabled qui
  --  ciblent les notifs lecteur)
  -- =============================================================
  IF TG_OP = 'UPDATE'
     AND OLD.pickup_reply_status IS DISTINCT FROM NEW.pickup_reply_status
     AND NEW.pickup_reply_status IS NOT NULL THEN
    PERFORM fn_dispatch_circulation_notify_event(
      CASE WHEN NEW.pickup_reply_status = 'confirmado_leitor'
           THEN 'retirada_confirmada_leitor'
           ELSE 'retirada_recusada_leitor'
      END,
      NEW.reserva_id,
      jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no))
    );
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_notify_reserva_workflow_change() IS
  'Trigger AFTER INSERT/UPDATE qui dispatche les events vers notify-event Edge Function. Phase 4 (07/05/2026) : ajout du routage em_preparacao + lecture des 12 flags reservation_mail_*_enabled de library_notification_policies pour skip silencieux si flag false. Fail-open en cas de policy manquante.';
