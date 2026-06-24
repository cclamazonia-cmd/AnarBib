-- ============================================================
-- Fix : planification de consultation locale en heure de la BIBLIOTHÈQUE.
-- Symptôme : « O horário escolhido fica fora da janela estruturada da biblioteca. »
--   (masqué par le front en « Não foi possível atualizar a etapa da consulta »)
--   quand le·la bibliothécaire planifie depuis un autre fuseau que la biblio.
-- Cause : le front (PanelPage.handleScheduleSubmit) encode l'heure saisie dans
--   le fuseau du NAVIGATEUR (new Date('YYYY-MM-DDTHH:MM')) et envoie ce fuseau
--   (Intl resolved tz). advance_consulta reconstruit alors le mur d'horloge dans le
--   fuseau navigateur et le passe tel quel au slot, MAIS
--   fn_validate_consulta_schedule_window raisonne en fuseau de la BIBLIO
--   (library_service_state.consultation_timezone). Un·e bibliothécaire à Paris
--   (UTC+2) saisissant 14:00 vise en réalité 09:00 à Belém (UTC-3) → souvent hors
--   fenêtre 09:00-18:00.
-- Correctif : une consultation sur place se planifie en heure de la biblio. On
--   récupère l'heure saisie via le fuseau navigateur (p_consultation_timezone),
--   puis on l'INTERPRÈTE dans le fuseau de la biblio (passé au slot), cohérent avec
--   la validation et le stockage. No-op si navigateur == fuseau biblio ; corrige le
--   cas inter-fuseaux. Vérifié : 14:00 Paris -> stocké 14:00 Belém ; 10:00 Paris
--   (qui échouait) -> stocké 10:00 Belém, OK.
-- Suites front (non couvertes ici, à déployer séparément) :
--   (1) surfacer le message backend précis au lieu du toast générique ;
--   (2) corriger le hint du modal qui annonce le fuseau navigateur (devrait afficher
--       le fuseau de la biblio).
-- ============================================================
CREATE OR REPLACE FUNCTION api.advance_consulta(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_target_stage text,
  p_workflow_note text DEFAULT NULL::text,
  p_consultation_scheduled_for timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_consultation_starts_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_consultation_ends_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_consultation_timezone text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
  v_current_stage text;
  v_heterogeneous_count int;
  v_input_tz text;     -- fuseau ayant servi à ENCODER l'instant côté front (navigateur)
  v_library_tz text;   -- fuseau de la bibliothèque (référence de validation/stockage)
  v_updated int;
  v_trimmed_note text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_consulta_id IS NULL THEN
    RAISE EXCEPTION 'not_found: p_consulta_id manquant' USING ERRCODE = 'P0001';
  END IF;

  IF p_line_nos IS NULL OR cardinality(p_line_nos) = 0 THEN
    RAISE EXCEPTION 'not_found: p_line_nos vide' USING ERRCODE = 'P0001';
  END IF;

  IF p_target_stage IS NULL OR p_target_stage = '' THEN
    RAISE EXCEPTION 'invalid_stage: p_target_stage manquant' USING ERRCODE = '42501';
  END IF;

  -- ============================================================
  -- B6 (15/05/2026) : note obligatoire pour annulation biblio
  -- ============================================================
  IF p_target_stage = 'cancelada_biblioteca' THEN
    v_trimmed_note := trim(coalesce(p_workflow_note, ''));
    IF length(v_trimmed_note) < 5 THEN
      RAISE EXCEPTION 'cancel_note_required: a note workflow de pelo menos 5 caracteres e obrigatoria para anulacao pela biblioteca'
        USING ERRCODE = 'P0001',
              HINT = 'Indique brevemente o motivo da anulacao (ex: livro indisponivel, doublee com outro pedido, etc.)';
    END IF;
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta % nao encontrada', p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  SELECT workflow_stage
    INTO v_current_stage
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id
    AND line_no = p_line_nos[1];

  IF v_current_stage IS NULL THEN
    RAISE EXCEPTION 'not_found: linha % da consulta % nao encontrada',
      p_line_nos[1], p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*)
    INTO v_heterogeneous_count
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id
    AND line_no = ANY(p_line_nos)
    AND workflow_stage IS DISTINCT FROM v_current_stage;

  IF v_heterogeneous_count > 0 THEN
    RAISE EXCEPTION 'invalid_stage: linhas com etapas heterogeneas (esperado %, % linhas diferentes)',
      v_current_stage, v_heterogeneous_count
      USING ERRCODE = '42501';
  END IF;

  IF NOT public.fn_check_consulta_transition(v_current_stage, p_target_stage, v_actor_role) THEN
    RAISE EXCEPTION 'invalid_stage: transicao % -> % nao permitida para %',
      v_current_stage, p_target_stage, COALESCE(v_actor_role, '(null)')
      USING ERRCODE = '42501';
  END IF;

  IF p_target_stage = 'consulta_agendada' AND p_consultation_starts_at IS NOT NULL THEN
    -- Fuseau de la biblio = référence (validation + stockage cohérents).
    v_library_tz := COALESCE(
      (SELECT consultation_timezone FROM public.library_service_state
        WHERE library_id = v_ctx.library_id),
      'UTC'
    );
    -- Fuseau ayant encodé l'instant côté front (= fuseau navigateur transmis).
    v_input_tz := COALESCE(p_consultation_timezone, v_library_tz, 'UTC');

    IF p_consultation_ends_at IS NULL THEN
      RAISE EXCEPTION 'schedule_missing: p_consultation_ends_at obrigatorio com p_consultation_starts_at'
        USING ERRCODE = 'P0001';
    END IF;

    -- On récupère le mur d'horloge SAISI via v_input_tz (p.ex. « 14:00 »), puis on
    -- l'interprète dans le fuseau de la biblio v_library_tz (dernier argument).
    v_updated := public.fn_v2_set_consulta_linhas_workflow_slot(
      p_consulta_id,
      p_line_nos,
      p_target_stage,
      p_workflow_note,
      to_char(p_consultation_starts_at AT TIME ZONE v_input_tz, 'YYYY-MM-DD'),
      to_char(p_consultation_starts_at AT TIME ZONE v_input_tz, 'HH24:MI'),
      to_char(p_consultation_ends_at   AT TIME ZONE v_input_tz, 'HH24:MI'),
      v_library_tz
    );

  ELSIF p_target_stage = 'consulta_agendada' AND p_consultation_scheduled_for IS NULL THEN
    RAISE EXCEPTION 'schedule_missing: p_consultation_scheduled_for ou p_consultation_starts_at obrigatorio'
      USING ERRCODE = 'P0001';

  ELSE
    v_updated := public.fn_v2_set_consulta_linhas_workflow(
      p_consulta_id,
      p_line_nos,
      p_target_stage,
      p_workflow_note,
      p_consultation_scheduled_for
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'updated_count', v_updated);
END;
$function$;
