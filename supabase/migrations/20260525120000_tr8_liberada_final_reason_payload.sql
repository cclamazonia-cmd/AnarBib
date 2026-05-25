-- =============================================================================
-- Migration TR-8 — chantier #153.A (corrections post-audit #153)
-- =============================================================================
-- Objet : résorber le doublon de mail subi par le ou la lectrice lors d'une
--         annulation de réservation par la bibliothèque (et, par cohérence,
--         lors d'un no-show).
--
-- Contexte : une annulation biblio fait passer le workflow_stage à
-- 'cancelada_biblioteca'. Le trigger trg_auto_liberate_after_no_show rebascule
-- aussitôt le stage à 'liberada_para_circulacao' (avec final_reason renseigné :
-- 'cancelled_by_library' pour une annulation, 'no_show' pour un non-retrait).
-- Le trigger d'émission trg_notify_reserva_workflow_change émet alors
-- l'événement 'liberada_para_circulacao', et le handler EF
-- handleReservaV2WorkflowEvent envoie un mail lecteur·rice « libérée pour
-- circulation » — un doublon de jargon interne, le lecteur·rice ayant déjà reçu
-- le mail d'annulation (ou de non-retrait).
--
-- Décision D-2 (dossier-cadre post-audit #153) et instruction D-2.a
-- (25/05/2026) : toute bascule causale vers 'liberada_para_circulacao' porte un
-- final_reason non nul. Le mail lecteur·rice de ce stage doit être neutralisé
-- dès que final_reason est non nul (cas 'cancelled_by_library' ET 'no_show' —
-- portée élargie validée le 25/05). Le mail staff, lui, reste émis : la
-- bibliothèque veut savoir que l'exemplaire est revenu en circulation.
--
-- Périmètre de cette migration (SQL uniquement) :
--   Le trigger d'émission trg_notify_reserva_workflow_change joint final_reason
--   au payload (p_extra) du dispatch, lorsque la ligne workflow en porte un.
--   final_reason est une colonne de reserva_item_workflow_v2 — donc de NEW :
--   le trigger y a accès directement, sans rien lire ni deviner.
--
-- Le volet Edge Function (handleReservaV2WorkflowEvent coupe le mail
-- lecteur·rice quand final_reason est présent dans le payload) est livré
-- séparément, hors migration.
--
-- Note (observation portée en dette, hors périmètre de cette migration) :
-- le flag library_notification_policies.reservation_mail_liberada_para_circulacao_enabled
-- a un DEFAULT false. Une fois ce correctif posé, et dans la mesure où toute
-- bascule vers 'liberada_para_circulacao' porte aujourd'hui un final_reason, ce
-- flag pourrait n'activer plus aucun mail lecteur·rice. À instruire séparément
-- (cohérence transverse, chantier #153.E ou note de backlog) — la présente
-- migration ne touche pas ce flag.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Reproduction intégrale de trg_notify_reserva_workflow_change (dump 25/05/2026)
-- -----------------------------------------------------------------------------
-- À l'identique, à une seule exception : dans le Bloc 1, l'appel à
-- fn_dispatch_circulation_notify_event joint final_reason au payload lorsque
-- NEW.final_reason est non nul. Les Blocs 2 et 3 sont inchangés.

CREATE OR REPLACE FUNCTION public.trg_notify_reserva_workflow_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
DECLARE
  v_event text;
  v_flag_column text;
  v_enabled boolean;
  v_library_id uuid;
BEGIN
  -- =============================================================
  -- Bloc 1 : changement de workflow_stage (transitions de stage)
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
        -- TR-8 (#153.A) : on joint final_reason au payload lorsque la ligne
        -- workflow en porte un. Le handler EF s'en sert pour neutraliser le
        -- mail lecteur·rice de 'liberada_para_circulacao' quand la libération
        -- est causale (annulation biblio ou no-show), tout en conservant le
        -- mail staff. final_reason est une colonne de NEW, accès direct.
        PERFORM fn_dispatch_circulation_notify_event(
          v_event, NEW.reserva_id,
          jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no))
          || CASE
               WHEN NEW.final_reason IS NOT NULL
                 THEN jsonb_build_object('final_reason', NEW.final_reason)
               ELSE '{}'::jsonb
             END
        );
      END IF;
    END IF;
  END IF;

  -- =============================================================
  -- Bloc 2 : changement de pickup_reply_status (legacy v2)
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

  -- =============================================================
  -- Bloc 3 : changement intra-stage en négociation v3
  -- (paquet 6 fix-up 2026-05-09)
  -- Déclenche le webhook 'retirada_a_combinar' quand la résa reste
  -- dans le même stage 'retirada_a_combinar' mais avec un changement
  -- de pickup_proposed_by ou pickup_scheduled_for.
  -- Cas couverts :
  --   - Contre-proposition lecteur (proposed_by biblio→leitor)
  --   - Renégo staff après contre-prop lecteur (proposed_by leitor→biblio)
  --   - Modification du créneau sans changer de proposeur
  -- Garde-fou : workflow_stage IDENTIQUE entre OLD et NEW (sinon le
  -- Bloc 1 a déjà géré la transition, on évite ainsi le doublon).
  -- =============================================================
  IF TG_OP = 'UPDATE'
     AND NEW.workflow_stage = 'retirada_a_combinar'
     AND OLD.workflow_stage = NEW.workflow_stage
     AND (OLD.pickup_proposed_by IS DISTINCT FROM NEW.pickup_proposed_by
          OR OLD.pickup_scheduled_for IS DISTINCT FROM NEW.pickup_scheduled_for) THEN
    -- Lire le flag de la lib (réutilise le flag du Bloc 1)
    SELECT r.library_id INTO v_library_id
    FROM public.reservas_v2 r
    WHERE r.id = NEW.reserva_id;

    v_enabled := true;  -- fail-open par défaut

    IF v_library_id IS NOT NULL THEN
      SELECT reservation_mail_retirada_a_combinar_enabled INTO v_enabled
      FROM public.library_notification_policies
      WHERE library_id = v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;

    IF v_enabled THEN
      PERFORM fn_dispatch_circulation_notify_event(
        'retirada_a_combinar', NEW.reserva_id,
        jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no))
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$_$;

-- -----------------------------------------------------------------------------
-- Vérification en fin de transaction
-- -----------------------------------------------------------------------------
-- RAISE EXCEPTION ici => rollback automatique de toute la migration.

DO $verify$
BEGIN
  -- La fonction trigger doit toujours exister.
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'trg_notify_reserva_workflow_change'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'TR-8 : trg_notify_reserva_workflow_change introuvable après migration.';
  END IF;

  -- Le trigger qui l'attache à reserva_item_workflow_v2 doit toujours exister.
  -- Le trigger se nomme 'trg_notify_reserva_workflow' (la fonction, elle, porte
  -- le suffixe '_change' : trg_notify_reserva_workflow_change).
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_notify_reserva_workflow'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'TR-8 : le trigger trg_notify_reserva_workflow n''est plus attaché.';
  END IF;

  RAISE NOTICE 'TR-8 : migration vérifiée — trigger d''émission en place, payload enrichi de final_reason.';
END;
$verify$;
