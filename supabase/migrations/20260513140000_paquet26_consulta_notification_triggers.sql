-- =============================================================================
-- Paquet 26 — Phase 3 consultations — Livrable 2 (triggers notifications)
-- Migration : 20260513140000_paquet26_consulta_notification_triggers
--
-- Crée 2 trigger functions + 2 CREATE TRIGGER sur les tables consultations :
--
--   1. trg_notify_consulta_lifecycle  ON consulta_linhas_v2
--      - INSERT                              → consulta_v2_criada
--      - UPDATE item_status ativa→consultada → consulta_v2_realizada
--      - UPDATE item_status ativa→cancelada_leitor    → consulta_v2_cancelada  (payload cancelled_by=leitor)
--      - UPDATE item_status ativa→cancelada_biblioteca → consulta_v2_cancelada (payload cancelled_by=biblioteca)
--      - UPDATE item_status ativa→expirada    → consulta_v2_expirada
--
--   2. trg_notify_consulta_workflow ON consulta_item_workflow_v2
--      - UPDATE workflow_stage →consulta_agendada (incluant transitions
--        em_preparacao→consulta_agendada ET consulta_agendada→consulta_agendada
--        pour re-propositions) → consulta_v2_agendada
--      - UPDATE schedule_reply_status DISTINCT FROM (nouveau confirmado/recusado_leitor)
--                                                  → consulta_v2_resposta_creneau
--
-- Patterns appliqués (calque trg_notify_reserva_workflow_change paquet 5b/6) :
--   - SECURITY DEFINER + SET search_path TO 'public' (calque exact)
--   - Lecture du master switch local_consultation_enabled en premier
--   - Lecture dynamique du flag par event via EXECUTE format(%I) (calque bloc 1)
--   - COALESCE(flag, true) → fail-open si flag NULL
--   - PERFORM fn_dispatch_circulation_notify_event (helper canonique réutilisé)
--   - Payload JSONB riche : line_nos toujours, cancelled_by/schedule_reply_status selon contexte
--   - RETURN NEW à la fin → ne bloque jamais la transition métier
--
-- Référence spec : docs/spec-flux-consultations.md §7.2
-- Source de vérité décalque : trg_notify_reserva_workflow_change (paquet 5b/6)
-- =============================================================================

BEGIN;

-- ============================================================================
-- 1. Trigger function lifecycle (sur consulta_linhas_v2)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_notify_consulta_lifecycle()
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
  v_local_consultation_enabled boolean;
  v_cancelled_by text;
  v_payload jsonb;
BEGIN
  -- ------------------------------------------------------------------------
  -- Mapping (TG_OP, NEW.item_status, OLD.item_status) → (event, flag_column)
  -- ------------------------------------------------------------------------
  v_event := NULL;
  v_flag_column := NULL;
  v_cancelled_by := NULL;

  IF TG_OP = 'INSERT' AND NEW.item_status = 'ativa' THEN
    v_event := 'consulta_v2_criada';
    v_flag_column := 'consulta_mail_criada_enabled';

  ELSIF TG_OP = 'UPDATE'
        AND OLD.item_status IS DISTINCT FROM NEW.item_status
        AND OLD.item_status = 'ativa' THEN

    IF NEW.item_status = 'consultada' THEN
      v_event := 'consulta_v2_realizada';
      v_flag_column := 'consulta_mail_realizada_enabled';

    ELSIF NEW.item_status = 'cancelada_leitor' THEN
      v_event := 'consulta_v2_cancelada';
      v_flag_column := 'consulta_mail_cancelada_enabled';
      v_cancelled_by := 'leitor';

    ELSIF NEW.item_status = 'cancelada_biblioteca' THEN
      v_event := 'consulta_v2_cancelada';
      v_flag_column := 'consulta_mail_cancelada_enabled';
      v_cancelled_by := 'biblioteca';

    ELSIF NEW.item_status = 'expirada' THEN
      v_event := 'consulta_v2_expirada';
      v_flag_column := 'consulta_mail_expirada_enabled';
    END IF;
  END IF;

  -- ------------------------------------------------------------------------
  -- Pas d'event à émettre → sortir
  -- ------------------------------------------------------------------------
  IF v_event IS NULL THEN
    RETURN NEW;
  END IF;

  -- ------------------------------------------------------------------------
  -- Récupérer library_id via consultas_locais_v2 (joint par consulta_id)
  -- ------------------------------------------------------------------------
  SELECT cl.library_id INTO v_library_id
  FROM public.consultas_locais_v2 cl
  WHERE cl.id = NEW.consulta_id;

  -- ------------------------------------------------------------------------
  -- Garde 1 : master switch local_consultation_enabled
  -- (fail-open par défaut si policy absente ou flag NULL)
  -- ------------------------------------------------------------------------
  v_local_consultation_enabled := true;
  IF v_library_id IS NOT NULL THEN
    SELECT local_consultation_enabled INTO v_local_consultation_enabled
    FROM public.library_notification_policies
    WHERE library_id = v_library_id;
    v_local_consultation_enabled := COALESCE(v_local_consultation_enabled, true);
  END IF;

  IF NOT v_local_consultation_enabled THEN
    RETURN NEW;
  END IF;

  -- ------------------------------------------------------------------------
  -- Garde 2 : flag granulaire par event (lecture dynamique calque bloc 1
  -- de trg_notify_reserva_workflow_change)
  -- ------------------------------------------------------------------------
  v_enabled := true;  -- fail-open par défaut
  IF v_library_id IS NOT NULL AND v_flag_column IS NOT NULL THEN
    EXECUTE format(
      'SELECT %I FROM public.library_notification_policies WHERE library_id = $1',
      v_flag_column
    ) INTO v_enabled USING v_library_id;
    v_enabled := COALESCE(v_enabled, true);
  END IF;

  IF NOT v_enabled THEN
    RETURN NEW;
  END IF;

  -- ------------------------------------------------------------------------
  -- Construire le payload (line_nos toujours, cancelled_by si contexte)
  -- ------------------------------------------------------------------------
  v_payload := jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no));
  IF v_cancelled_by IS NOT NULL THEN
    v_payload := v_payload || jsonb_build_object('cancelled_by', v_cancelled_by);
  END IF;

  -- ------------------------------------------------------------------------
  -- Dispatch via helper canonique (réutilise pg_net.http_post centralisé)
  -- ------------------------------------------------------------------------
  PERFORM public.fn_dispatch_circulation_notify_event(
    v_event,
    NEW.consulta_id,
    v_payload
  );

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.trg_notify_consulta_lifecycle() IS
  'Paquet 26 L2 — Trigger function lifecycle consultations. Émet consulta_v2_{criada,realizada,cancelada,expirada} via fn_dispatch_circulation_notify_event. Double garde local_consultation_enabled + consulta_mail_*_enabled. Fail-open sur flag NULL.';

-- ============================================================================
-- 2. Trigger function workflow (sur consulta_item_workflow_v2)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.trg_notify_consulta_workflow()
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
  v_local_consultation_enabled boolean;
  v_payload jsonb;
  v_emit_agendada boolean := false;
  v_emit_resposta boolean := false;
BEGIN
  -- ------------------------------------------------------------------------
  -- Détecter laquelle des 2 transitions a eu lieu (peut être les deux dans
  -- la même UPDATE théoriquement, mais en pratique exclusif)
  -- ------------------------------------------------------------------------

  -- Transition workflow_stage → consulta_agendada
  -- Couvre :
  --   - em_preparacao → consulta_agendada (proposition staff initiale)
  --   - consulta_agendada → consulta_agendada (re-proposition staff)
  --   - solicitada → consulta_agendada (raccourci staff, théorique)
  IF (TG_OP = 'INSERT' AND NEW.workflow_stage = 'consulta_agendada')
     OR (TG_OP = 'UPDATE'
         AND NEW.workflow_stage = 'consulta_agendada'
         AND (OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage
              OR OLD.consultation_starts_at IS DISTINCT FROM NEW.consultation_starts_at
              OR OLD.consultation_ends_at IS DISTINCT FROM NEW.consultation_ends_at))
  THEN
    v_emit_agendada := true;
  END IF;

  -- Transition schedule_reply_status → confirmado_leitor / recusado_leitor
  -- (calque bloc 2 trg_notify_reserva_workflow_change pour pickup_reply_status)
  IF TG_OP = 'UPDATE'
     AND OLD.schedule_reply_status IS DISTINCT FROM NEW.schedule_reply_status
     AND NEW.schedule_reply_status IN ('confirmado_leitor', 'recusado_leitor')
  THEN
    v_emit_resposta := true;
  END IF;

  -- Rien à émettre → sortir tôt
  IF NOT v_emit_agendada AND NOT v_emit_resposta THEN
    RETURN NEW;
  END IF;

  -- ------------------------------------------------------------------------
  -- Récupérer library_id (chemin : consulta_item_workflow_v2.consulta_id
  --                              → consultas_locais_v2.library_id)
  -- ------------------------------------------------------------------------
  SELECT cl.library_id INTO v_library_id
  FROM public.consultas_locais_v2 cl
  WHERE cl.id = NEW.consulta_id;

  -- ------------------------------------------------------------------------
  -- Garde 1 : master switch
  -- ------------------------------------------------------------------------
  v_local_consultation_enabled := true;
  IF v_library_id IS NOT NULL THEN
    SELECT local_consultation_enabled INTO v_local_consultation_enabled
    FROM public.library_notification_policies
    WHERE library_id = v_library_id;
    v_local_consultation_enabled := COALESCE(v_local_consultation_enabled, true);
  END IF;

  IF NOT v_local_consultation_enabled THEN
    RETURN NEW;
  END IF;

  -- ------------------------------------------------------------------------
  -- Émission 1 : consulta_v2_agendada
  -- ------------------------------------------------------------------------
  IF v_emit_agendada THEN
    v_flag_column := 'consulta_mail_agendada_enabled';
    v_event := 'consulta_v2_agendada';

    v_enabled := true;
    IF v_library_id IS NOT NULL THEN
      EXECUTE format(
        'SELECT %I FROM public.library_notification_policies WHERE library_id = $1',
        v_flag_column
      ) INTO v_enabled USING v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;

    IF v_enabled THEN
      -- Payload riche : line_nos + consultation_starts_at + consultation_ends_at
      -- (le handler TS reformatera dans la timezone biblio via formatDateTimeInZone)
      v_payload := jsonb_build_object(
        'line_nos', jsonb_build_array(NEW.line_no),
        'consultation_starts_at', NEW.consultation_starts_at,
        'consultation_ends_at',   NEW.consultation_ends_at
      );

      PERFORM public.fn_dispatch_circulation_notify_event(
        v_event,
        NEW.consulta_id,
        v_payload
      );
    END IF;
  END IF;

  -- ------------------------------------------------------------------------
  -- Émission 2 : consulta_v2_resposta_creneau
  -- ------------------------------------------------------------------------
  IF v_emit_resposta THEN
    v_flag_column := 'consulta_mail_resposta_creneau_enabled';
    v_event := 'consulta_v2_resposta_creneau';

    v_enabled := true;
    IF v_library_id IS NOT NULL THEN
      EXECUTE format(
        'SELECT %I FROM public.library_notification_policies WHERE library_id = $1',
        v_flag_column
      ) INTO v_enabled USING v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;

    IF v_enabled THEN
      -- Payload riche : line_nos + schedule_reply_status (discriminant confirmé/refusé)
      v_payload := jsonb_build_object(
        'line_nos', jsonb_build_array(NEW.line_no),
        'schedule_reply_status', NEW.schedule_reply_status
      );

      PERFORM public.fn_dispatch_circulation_notify_event(
        v_event,
        NEW.consulta_id,
        v_payload
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.trg_notify_consulta_workflow() IS
  'Paquet 26 L2 — Trigger function workflow consultations. Émet consulta_v2_agendada (transition vers consulta_agendada, y compris re-propositions) et consulta_v2_resposta_creneau (réponse lecteur au créneau). Double garde local_consultation_enabled + flag granulaire. Fail-open sur flag NULL.';

-- ============================================================================
-- 3. Déclarations CREATE TRIGGER (calque exact paquet 5b reservas)
-- ============================================================================

-- Drop d'abord (idempotence si la migration est rejouée)
DROP TRIGGER IF EXISTS trg_notify_consulta_lifecycle ON public.consulta_linhas_v2;
DROP TRIGGER IF EXISTS trg_notify_consulta_workflow  ON public.consulta_item_workflow_v2;

-- Lifecycle (calque trg_notify_emprestimo_criado pour le pattern AFTER INSERT/UPDATE)
CREATE TRIGGER trg_notify_consulta_lifecycle
  AFTER INSERT OR UPDATE OF item_status
  ON public.consulta_linhas_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_consulta_lifecycle();

-- Workflow (calque trg_notify_reserva_workflow : AFTER INSERT OR UPDATE OF cols)
CREATE TRIGGER trg_notify_consulta_workflow
  AFTER INSERT OR UPDATE OF workflow_stage, schedule_reply_status,
                            consultation_starts_at, consultation_ends_at
  ON public.consulta_item_workflow_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_notify_consulta_workflow();

-- ============================================================================
-- 4. Sanity check post-migration
-- ============================================================================

DO $$
DECLARE
  v_lifecycle_fn_exists boolean;
  v_workflow_fn_exists boolean;
  v_lifecycle_trg_exists boolean;
  v_workflow_trg_exists boolean;
  v_dispatch_helper_exists boolean;
BEGIN
  -- Vérifier que les 2 fonctions existent
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_lifecycle'
  ) INTO v_lifecycle_fn_exists;

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_workflow'
  ) INTO v_workflow_fn_exists;

  -- Vérifier que les 2 triggers sont en place
  SELECT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'consulta_linhas_v2'
      AND t.tgname = 'trg_notify_consulta_lifecycle'
      AND NOT t.tgisinternal
  ) INTO v_lifecycle_trg_exists;

  SELECT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'consulta_item_workflow_v2'
      AND t.tgname = 'trg_notify_consulta_workflow'
      AND NOT t.tgisinternal
  ) INTO v_workflow_trg_exists;

  -- Vérifier que le helper dispatch existe (dépendance critique)
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_dispatch_circulation_notify_event'
  ) INTO v_dispatch_helper_exists;

  IF NOT v_lifecycle_fn_exists THEN
    RAISE EXCEPTION 'Paquet 26 L2 — Function trg_notify_consulta_lifecycle MANQUANTE';
  END IF;
  IF NOT v_workflow_fn_exists THEN
    RAISE EXCEPTION 'Paquet 26 L2 — Function trg_notify_consulta_workflow MANQUANTE';
  END IF;
  IF NOT v_lifecycle_trg_exists THEN
    RAISE EXCEPTION 'Paquet 26 L2 — Trigger trg_notify_consulta_lifecycle MANQUANT sur consulta_linhas_v2';
  END IF;
  IF NOT v_workflow_trg_exists THEN
    RAISE EXCEPTION 'Paquet 26 L2 — Trigger trg_notify_consulta_workflow MANQUANT sur consulta_item_workflow_v2';
  END IF;
  IF NOT v_dispatch_helper_exists THEN
    RAISE EXCEPTION 'Paquet 26 L2 — DÉPENDANCE MANQUANTE : public.fn_dispatch_circulation_notify_event';
  END IF;

  RAISE NOTICE 'Paquet 26 L2 OK — 2 trigger fns + 2 triggers + dependance fn_dispatch_circulation_notify_event verifiees';
  RAISE NOTICE 'Paquet 26 L2 — Les triggers vont commencer a emettre des events consulta_v2_* MAIS handler TS pas encore en place (L3+L4).';
  RAISE NOTICE 'Paquet 26 L2 — Les events vont arriver dans notify-event qui retournera 200 ignored (cf. dispatch.ts dernier return null).';
  RAISE NOTICE 'Paquet 26 L2 — Aucun mail ne sera envoye tant que L3+L4 ne sont pas poussees. Comportement attendu.';
END;
$$;

COMMIT;
