-- ============================================================
-- Paquet 141.1 — Hardening notifications consultas : propagation
-- workflow_note + 2 events manquants
-- ============================================================
-- Chantier : #141 hardening notifications consultas
-- Spec : docs/specs/spec-flux-consultations.md v2.1 §11.2
-- Date : 2026-05-16
-- ============================================================
-- Bugs résolus par cette migration :
--
-- B3 généralisé : les notes workflow (workflow_note) ne sont jamais
--   propagées dans les payloads des events consulta_v2_*. Conséquence :
--   les mails ne peuvent pas afficher la note (motif refus, motif
--   annulation, etc.). Cf. spec v2.1 §6.2 et §8.1.
--
-- B6 complément : la note d'annulation par la biblio (fix 15/05/2026)
--   est bien enregistrée en DB mais pas dans le mail au lecteur·rice.
--
-- B2 : la transition solicitada → em_preparacao ne déclenche aucun event,
--   donc pas de mail au lecteur·rice. Création de consulta_v2_em_preparacao.
--
-- B5 : la transition vers nao_compareceu ne déclenche aucun event, donc
--   pas de mail au lecteur·rice. Création de consulta_v2_nao_compareceu.
--
-- Doctrine politique : le mail no-show n'est pas une punition, c'est un
-- rappel d'engagement réciproque (la biblio s'est engagée vis-à-vis du
-- lecteur·rice, la réciproque était attendue). Cf. doctrine SIGB R5
-- inversé : on notifie qui a manqué à son engagement.
--
-- DETTE DOCTRINALE CORRIGÉE :
--   Les 2 triggers existants (créés au paquet 26 du 12/05/2026, avant le
--   hook pre-commit AnarBib) avaient GRANT EXECUTE TO PUBLIC non révoqué.
--   Cette migration ajoute REVOKE EXECUTE FROM PUBLIC pour les aligner
--   sur la doctrine sécurité (CHANTIER_doctrine_creation_objets_securises
--   _2026-05-12.md Template 1). Pas de GRANT explicite : les triggers
--   sont invoqués automatiquement par PostgreSQL, aucun rôle applicatif
--   ne les exécute directement.
-- ============================================================

-- ============================================================
-- SECTION 1 — Ajouter 2 colonnes toggle dans library_notification_policies
-- ============================================================

ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS consulta_mail_em_preparacao_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS consulta_mail_nao_compareceu_enabled boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.library_notification_policies.consulta_mail_em_preparacao_enabled IS
  'Toggle granulaire pour le mail consulta_v2_em_preparacao (lecteur·rice prévenu·e que sa demande est en préparation). Cf. spec consultas v2.1 §11.2.';

COMMENT ON COLUMN public.library_notification_policies.consulta_mail_nao_compareceu_enabled IS
  'Toggle granulaire pour le mail consulta_v2_nao_compareceu (lecteur·rice prévenu·e qu''iel est marqué·e absent·e). Doctrine : rappel d''engagement réciproque, pas punition.';

-- ============================================================
-- SECTION 2 — Refacto trg_notify_consulta_lifecycle
-- ============================================================
-- Ajout : récupération de workflow_note via JOIN sur consulta_item_workflow_v2
-- par (consulta_id, line_no) et injection dans le payload si non-NULL non-vide.
-- ============================================================

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
  v_workflow_note text;
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
  -- Garde 2 : flag granulaire par event
  -- ------------------------------------------------------------------------
  v_enabled := true;
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
  -- B3 généralisé (15/05/2026) : récupérer workflow_note via JOIN
  -- ------------------------------------------------------------------------
  -- La table consulta_linhas_v2 (watched) ne contient pas workflow_note.
  -- On lit dans consulta_item_workflow_v2 par (consulta_id, line_no).
  -- ------------------------------------------------------------------------
  SELECT workflow_note INTO v_workflow_note
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = NEW.consulta_id AND line_no = NEW.line_no;

  -- ------------------------------------------------------------------------
  -- Construire le payload
  -- ------------------------------------------------------------------------
  v_payload := jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no));
  IF v_cancelled_by IS NOT NULL THEN
    v_payload := v_payload || jsonb_build_object('cancelled_by', v_cancelled_by);
  END IF;
  -- B3 généralisé : workflow_note propagée si non-NULL et non-vide
  IF v_workflow_note IS NOT NULL AND trim(v_workflow_note) <> '' THEN
    v_payload := v_payload || jsonb_build_object('workflow_note', v_workflow_note);
  END IF;

  -- ------------------------------------------------------------------------
  -- Dispatch via helper canonique
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
  'Trigger émet events lifecycle consulta_v2_* sur changements item_status de consulta_linhas_v2. v2 (15/05/2026) : propagation workflow_note via JOIN sur consulta_item_workflow_v2 (fix B3 généralisé). Cf. spec consultas v2.1 §11.2.';

-- DOCTRINE SÉCURITÉ : SECURITY DEFINER + REVOKE FROM PUBLIC
-- (correction dette doctrinale héritée du paquet 26)
-- Pas de GRANT explicite : fonction trigger appelée par PostgreSQL en interne,
-- aucun rôle applicatif n'a besoin de l'exécuter directement.
REVOKE EXECUTE ON FUNCTION public.trg_notify_consulta_lifecycle() FROM PUBLIC;

-- ============================================================
-- SECTION 3 — Refacto trg_notify_consulta_workflow + ajout 2 events
-- ============================================================
-- Refacto majeure : ajout des 2 events manquants em_preparacao et
-- nao_compareceu, + propagation de workflow_note (directement disponible
-- via NEW puisque la table watched est consulta_item_workflow_v2).
-- ============================================================

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
  v_emit_em_preparacao boolean := false;
  v_emit_agendada boolean := false;
  v_emit_resposta boolean := false;
  v_emit_nao_compareceu boolean := false;
BEGIN
  -- ------------------------------------------------------------------------
  -- Détecter laquelle des 4 transitions a eu lieu
  -- (théoriquement exclusives, mais on les évalue toutes pour robustesse)
  -- ------------------------------------------------------------------------

  -- B2 NOUVEAU : Transition workflow_stage → em_preparacao
  -- Émis quand le·la coordenador·a clique « Preparar » sur une consulta
  IF TG_OP = 'UPDATE'
     AND NEW.workflow_stage = 'em_preparacao'
     AND OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage
  THEN
    v_emit_em_preparacao := true;
  END IF;

  -- Transition workflow_stage → consulta_agendada (existant)
  IF (TG_OP = 'INSERT' AND NEW.workflow_stage = 'consulta_agendada')
     OR (TG_OP = 'UPDATE'
         AND NEW.workflow_stage = 'consulta_agendada'
         AND (OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage
              OR OLD.consultation_starts_at IS DISTINCT FROM NEW.consultation_starts_at
              OR OLD.consultation_ends_at IS DISTINCT FROM NEW.consultation_ends_at))
  THEN
    v_emit_agendada := true;
  END IF;

  -- B5 NOUVEAU : Transition workflow_stage → nao_compareceu
  -- Émis quand la biblio marque le no-show (bouton « Marcar não comparecimento »)
  IF TG_OP = 'UPDATE'
     AND NEW.workflow_stage = 'nao_compareceu'
     AND OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage
  THEN
    v_emit_nao_compareceu := true;
  END IF;

  -- Transition schedule_reply_status → confirmado_leitor / recusado_leitor (existant)
  IF TG_OP = 'UPDATE'
     AND OLD.schedule_reply_status IS DISTINCT FROM NEW.schedule_reply_status
     AND NEW.schedule_reply_status IN ('confirmado_leitor', 'recusado_leitor')
  THEN
    v_emit_resposta := true;
  END IF;

  -- Rien à émettre → sortir tôt
  IF NOT v_emit_em_preparacao AND NOT v_emit_agendada 
     AND NOT v_emit_resposta AND NOT v_emit_nao_compareceu THEN
    RETURN NEW;
  END IF;

  -- ------------------------------------------------------------------------
  -- Récupérer library_id
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
  -- Émission 1 : consulta_v2_em_preparacao (NOUVEAU B2)
  -- ------------------------------------------------------------------------
  IF v_emit_em_preparacao THEN
    v_flag_column := 'consulta_mail_em_preparacao_enabled';
    v_event := 'consulta_v2_em_preparacao';

    v_enabled := true;
    IF v_library_id IS NOT NULL THEN
      EXECUTE format(
        'SELECT %I FROM public.library_notification_policies WHERE library_id = $1',
        v_flag_column
      ) INTO v_enabled USING v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;

    IF v_enabled THEN
      v_payload := jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no));
      IF NEW.workflow_note IS NOT NULL AND trim(NEW.workflow_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('workflow_note', NEW.workflow_note);
      END IF;

      PERFORM public.fn_dispatch_circulation_notify_event(
        v_event,
        NEW.consulta_id,
        v_payload
      );
    END IF;
  END IF;

  -- ------------------------------------------------------------------------
  -- Émission 2 : consulta_v2_agendada (existant + propagation workflow_note)
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
      v_payload := jsonb_build_object(
        'line_nos', jsonb_build_array(NEW.line_no),
        'consultation_starts_at', NEW.consultation_starts_at,
        'consultation_ends_at',   NEW.consultation_ends_at
      );
      IF NEW.workflow_note IS NOT NULL AND trim(NEW.workflow_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('workflow_note', NEW.workflow_note);
      END IF;

      PERFORM public.fn_dispatch_circulation_notify_event(
        v_event,
        NEW.consulta_id,
        v_payload
      );
    END IF;
  END IF;

  -- ------------------------------------------------------------------------
  -- Émission 3 : consulta_v2_nao_compareceu (NOUVEAU B5)
  -- ------------------------------------------------------------------------
  IF v_emit_nao_compareceu THEN
    v_flag_column := 'consulta_mail_nao_compareceu_enabled';
    v_event := 'consulta_v2_nao_compareceu';

    v_enabled := true;
    IF v_library_id IS NOT NULL THEN
      EXECUTE format(
        'SELECT %I FROM public.library_notification_policies WHERE library_id = $1',
        v_flag_column
      ) INTO v_enabled USING v_library_id;
      v_enabled := COALESCE(v_enabled, true);
    END IF;

    IF v_enabled THEN
      v_payload := jsonb_build_object(
        'line_nos', jsonb_build_array(NEW.line_no),
        'consultation_starts_at', NEW.consultation_starts_at
      );
      IF NEW.workflow_note IS NOT NULL AND trim(NEW.workflow_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('workflow_note', NEW.workflow_note);
      END IF;

      PERFORM public.fn_dispatch_circulation_notify_event(
        v_event,
        NEW.consulta_id,
        v_payload
      );
    END IF;
  END IF;

  -- ------------------------------------------------------------------------
  -- Émission 4 : consulta_v2_resposta_creneau (existant + propagation workflow_note)
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
      v_payload := jsonb_build_object(
        'line_nos', jsonb_build_array(NEW.line_no),
        'schedule_reply_status', NEW.schedule_reply_status
      );
      IF NEW.workflow_note IS NOT NULL AND trim(NEW.workflow_note) <> '' THEN
        v_payload := v_payload || jsonb_build_object('workflow_note', NEW.workflow_note);
      END IF;

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
  'Trigger émet events workflow consulta_v2_* sur changements de consulta_item_workflow_v2. v2 (15/05/2026) : ajout events em_preparacao (B2) et nao_compareceu (B5) + propagation workflow_note (B3 généralisé). Cf. spec consultas v2.1 §11.2.';

-- DOCTRINE SÉCURITÉ : SECURITY DEFINER + REVOKE FROM PUBLIC
-- (correction dette doctrinale héritée du paquet 26)
REVOKE EXECUTE ON FUNCTION public.trg_notify_consulta_workflow() FROM PUBLIC;

-- ============================================================
-- SECTION 4 — Vérification finale (DO-block)
-- ============================================================

DO $$
DECLARE
  v_lifecycle_body text;
  v_workflow_body text;
  v_em_preparacao_col_exists boolean;
  v_nao_compareceu_col_exists boolean;
  v_lifecycle_acl_count int;
  v_workflow_acl_count int;
BEGIN
  -- 4.1 Vérifier que les 2 nouvelles colonnes toggle existent
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
      AND table_name = 'library_notification_policies'
      AND column_name = 'consulta_mail_em_preparacao_enabled'
  ) INTO v_em_preparacao_col_exists;
  
  IF NOT v_em_preparacao_col_exists THEN
    RAISE EXCEPTION 'Verification echouee : colonne consulta_mail_em_preparacao_enabled absente';
  END IF;
  
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
      AND table_name = 'library_notification_policies'
      AND column_name = 'consulta_mail_nao_compareceu_enabled'
  ) INTO v_nao_compareceu_col_exists;
  
  IF NOT v_nao_compareceu_col_exists THEN
    RAISE EXCEPTION 'Verification echouee : colonne consulta_mail_nao_compareceu_enabled absente';
  END IF;
  
  RAISE NOTICE 'OK : 2 nouvelles colonnes toggle ajoutees (em_preparacao + nao_compareceu)';
  
  -- 4.2 Vérifier que la propagation workflow_note est présente dans lifecycle
  SELECT pg_get_functiondef(p.oid) INTO v_lifecycle_body
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_lifecycle';
  
  IF v_lifecycle_body NOT LIKE '%workflow_note%' THEN
    RAISE EXCEPTION 'Verification echouee : trg_notify_consulta_lifecycle ne propage pas workflow_note';
  END IF;
  
  RAISE NOTICE 'OK : trg_notify_consulta_lifecycle propage workflow_note';
  
  -- 4.3 Vérifier que les 2 nouveaux events sont présents dans workflow
  SELECT pg_get_functiondef(p.oid) INTO v_workflow_body
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_workflow';
  
  IF v_workflow_body NOT LIKE '%consulta_v2_em_preparacao%' THEN
    RAISE EXCEPTION 'Verification echouee : trg_notify_consulta_workflow ne contient pas consulta_v2_em_preparacao';
  END IF;
  
  IF v_workflow_body NOT LIKE '%consulta_v2_nao_compareceu%' THEN
    RAISE EXCEPTION 'Verification echouee : trg_notify_consulta_workflow ne contient pas consulta_v2_nao_compareceu';
  END IF;
  
  IF v_workflow_body NOT LIKE '%workflow_note%' THEN
    RAISE EXCEPTION 'Verification echouee : trg_notify_consulta_workflow ne propage pas workflow_note';
  END IF;
  
  RAISE NOTICE 'OK : trg_notify_consulta_workflow contient 4 events (em_preparacao, agendada, nao_compareceu, resposta_creneau)';
  RAISE NOTICE 'OK : trg_notify_consulta_workflow propage workflow_note';
  
  -- 4.4 Vérifier que PUBLIC n'a plus EXECUTE sur les 2 triggers
  SELECT count(*) INTO v_lifecycle_acl_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_lifecycle'
    AND pg_catalog.array_to_string(p.proacl, ',') LIKE '%=X/%';
  
  IF v_lifecycle_acl_count > 0 THEN
    RAISE EXCEPTION 'Verification echouee : trg_notify_consulta_lifecycle conserve un GRANT TO PUBLIC';
  END IF;
  
  SELECT count(*) INTO v_workflow_acl_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public' AND p.proname = 'trg_notify_consulta_workflow'
    AND pg_catalog.array_to_string(p.proacl, ',') LIKE '%=X/%';
  
  IF v_workflow_acl_count > 0 THEN
    RAISE EXCEPTION 'Verification echouee : trg_notify_consulta_workflow conserve un GRANT TO PUBLIC';
  END IF;
  
  RAISE NOTICE 'OK : PUBLIC ne peut plus EXECUTE les 2 triggers (dette doctrinale corrigee)';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Paquet 141.1 applique avec succes (15/05/2026)';
  RAISE NOTICE '  - B2 resolu : event consulta_v2_em_preparacao cree';
  RAISE NOTICE '  - B5 resolu : event consulta_v2_nao_compareceu cree';
  RAISE NOTICE '  - B3 generalise + complement B6 : workflow_note propagee';
  RAISE NOTICE '  - Dette doctrinale corrigee : REVOKE FROM PUBLIC sur 2 triggers';
  RAISE NOTICE '========================================';
END $$;
