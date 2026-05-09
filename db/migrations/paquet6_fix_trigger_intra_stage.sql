-- ═══════════════════════════════════════════════════════════
-- Paquet 6 fix-up — trigger workflow déclenchement intra-stage v3
-- ═══════════════════════════════════════════════════════════
-- Bug constaté (2026-05-09 session de tests à chaud) :
--
-- Quand le lecteur fait une contre-proposition de créneau (RPC
-- fn_propose_pickup_slot_as_reader), la résa reste dans le même
-- workflow_stage 'retirada_a_combinar' mais avec :
--   - pickup_proposed_by qui passe de 'biblio' à 'leitor'
--   - pickup_scheduled_for qui change vers le nouveau créneau
--   - negotiation_iteration_count qui s'incrémente
--
-- La trigger trg_notify_reserva_workflow_change ne se déclenchait
-- que sur changement de workflow_stage (Bloc 1) ou de pickup_reply_status
-- (Bloc 2 legacy). Aucun bloc ne couvrait le changement intra-stage,
-- donc aucun webhook n'était envoyé pour les contre-propositions ni
-- pour les renégos staff (= toute la sémantique v3 négociation).
--
-- Diagnostic confirmé en DB : résa #10 avec pickup_proposed_by='leitor',
-- iter=1, stage='retirada_a_combinar', mais aucun POST notify-event après
-- la contre-prop.
--
-- Fix : ajouter un Bloc 3 qui détecte le changement intra-stage
-- (workflow_stage=retirada_a_combinar inchangé) lié à un changement
-- de pickup_proposed_by ou pickup_scheduled_for. Réutilise le flag
-- reservation_mail_retirada_a_combinar_enabled pour cohérence.
--
-- Garde-fou : le bloc 3 ne se déclenche que si workflow_stage est
-- IDENTIQUE entre OLD et NEW (vrai changement intra-stage), ce qui
-- évite tout doublon avec le Bloc 1 lors d'une vraie transition.
-- ═══════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.trg_notify_reserva_workflow_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        PERFORM fn_dispatch_circulation_notify_event(
          v_event, NEW.reserva_id,
          jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no))
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
$function$;

COMMENT ON FUNCTION public.trg_notify_reserva_workflow_change() IS
  'Trigger AFTER INSERT/UPDATE sur reserva_item_workflow_v2.
   Bloc 1 : transitions de workflow_stage (notifications lecteur+biblio).
   Bloc 2 : changement de pickup_reply_status (legacy v2 admin-only).
   Bloc 3 : changement intra-stage en négociation v3 (contre-prop, renégo).
   Paquet 6 fix-up 2026-05-09 : ajout du Bloc 3 pour couvrir les
   transitions intra-stage qui existent depuis la sémantique v3.';

-- ═══════════════════════════════════════════════════════════
-- Requête d'acceptation à lancer après application
-- ═══════════════════════════════════════════════════════════
-- Q1 : la fonction est bien remplacée
-- SELECT pg_get_functiondef('public.trg_notify_reserva_workflow_change'::regproc);
-- Attendu : le code contient bien "Bloc 3" et la condition NEW.pickup_proposed_by.
--
-- Q2 : test à chaud — sur la résa #10 actuellement à proposed_by='leitor',
-- iter=1, modifier pickup_scheduled_for via une nouvelle contre-prop staff
-- depuis le painel (ce qui changera proposed_by à 'biblio' et iter à 2).
-- Vérifier que :
--   - 1 webhook POST notify-event est déclenché (logs Supabase)
--   - 2 mails arrivent : lecteur en français (libraryCounterProposed),
--     biblio en pt-BR (staffCounterProposed)
-- ═══════════════════════════════════════════════════════════
