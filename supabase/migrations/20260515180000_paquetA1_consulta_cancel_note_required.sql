-- ============================================================
-- Paquet A1 (hotfix v2) — Note obligatoire annulation biblio consulta
-- ============================================================
-- v2 (15/05/2026 soir) : la v1 plantait avec "function name not unique"
-- parce que :
-- 1. Elle avait 7 parametres au lieu des 8 reels en prod (le parametre
--    legacy p_consultation_scheduled_for avait ete retire par erreur)
-- 2. Postgres aurait cree une 2e surcharge au lieu de remplacer
-- 3. Le COMMENT ON FUNCTION sans signature ne pouvait pas resoudre
--
-- v2 : on part de la fonction reellement deployee en prod (recuperee via
-- pg_get_functiondef) et on ajoute UNIQUEMENT la garde cancel_note_required
-- au bon endroit. Tout le reste (verifications NULL, heterogeneite, timezone,
-- legacy p_consultation_scheduled_for) est preserve.
--
-- Spec : docs/specs/spec-flux-consultations.md v2.1 §6.2, §8.1
-- Date : 2026-05-15
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
  v_effective_tz text;
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
  -- Doctrine politique : toute annulation par la biblio doit laisser
  -- une trace ecrite >= 5 chars (compromis pratique vs symbolique).
  -- Voir spec v2.1 §6.2 et §8.1.
  -- 
  -- Place ici (debut de bloc) pour fail-fast : avant tout SELECT cher
  -- (fn_get_consulta_context, etc.), on rejette les appels invalides.
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

  -- F.2 v0.3 : la resolution du role retourne 'leitor' / 'librarian' /
  -- 'coordenador' / NULL (le role 'administrador' a ete supprime en F.1).
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
    v_effective_tz := COALESCE(
      p_consultation_timezone,
      (SELECT consultation_timezone FROM public.library_service_state
        WHERE library_id = v_ctx.library_id),
      'UTC'
    );

    IF p_consultation_ends_at IS NULL THEN
      RAISE EXCEPTION 'schedule_missing: p_consultation_ends_at obrigatorio com p_consultation_starts_at'
        USING ERRCODE = 'P0001';
    END IF;

    v_updated := public.fn_v2_set_consulta_linhas_workflow_slot(
      p_consulta_id,
      p_line_nos,
      p_target_stage,
      p_workflow_note,
      to_char(p_consultation_starts_at AT TIME ZONE v_effective_tz, 'YYYY-MM-DD'),
      to_char(p_consultation_starts_at AT TIME ZONE v_effective_tz, 'HH24:MI'),
      to_char(p_consultation_ends_at   AT TIME ZONE v_effective_tz, 'HH24:MI'),
      v_effective_tz
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

-- ============================================================
-- COMMENT avec signature complete (8 parametres)
-- ============================================================
-- Sans la signature complete, Postgres ne sait pas quelle surcharge
-- commenter et leve "function name is not unique". On specifie donc
-- les 8 types de parametres explicitement.

COMMENT ON FUNCTION api.advance_consulta(
  bigint, integer[], text, text, 
  timestamp with time zone, 
  timestamp with time zone, 
  timestamp with time zone, 
  text
) IS
  'Wrapper de transition workflow consulta (SECURITY INVOKER). Verifie role, transition autorisee, invariants schedule_missing et cancel_note_required. Cf. spec consultas v2.1 §6.2, §6.4 (R1 invariant schedule_missing), §6.2 et §8.1 (B6 note obligatoire annulation biblio, fix 15/05/2026).';

-- ============================================================
-- Verification finale (DO-block)
-- ============================================================

DO $$
DECLARE
  v_function_body text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_function_body
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'api' AND p.proname = 'advance_consulta';
  
  IF v_function_body IS NULL THEN
    RAISE EXCEPTION 'Verification echouee : api.advance_consulta absente';
  END IF;
  
  IF v_function_body NOT LIKE '%cancel_note_required%' THEN
    RAISE EXCEPTION 'Verification echouee : garde cancel_note_required absente';
  END IF;
  
  IF v_function_body NOT LIKE '%v_trimmed_note%' THEN
    RAISE EXCEPTION 'Verification echouee : variable v_trimmed_note absente';
  END IF;
  
  RAISE NOTICE 'OK : api.advance_consulta refactoree avec garde cancel_note_required >= 5 chars';
  RAISE NOTICE 'Fix B6 v2 (15/05/2026) applique avec succes';
END $$;
