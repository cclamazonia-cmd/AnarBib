-- ============================================================
-- Paquet A1 (hotfix) — Note obligatoire annulation biblio consulta
-- ============================================================
-- Bug B6 detecte en QA manuelle 15/05/2026 :
-- L'annulation d'une consulta par la biblio (api.advance_consulta avec
-- p_target_stage='cancelada_biblioteca') accepte aujourd'hui une note
-- NULL ou triviale, ce qui contredit la spec consultas v2.1 §6.2 et §8.1.
--
-- Fix : ajouter une garde explicite dans api.advance_consulta qui exige
-- une workflow_note >= 5 caracteres pour la transition cancelada_biblioteca.
--
-- Doctrine politique :
-- - 5 chars minimum cote biblio (Option B validee 15/05) : empeche les
--   notes triviales sans alourdir le workflow operationnel
-- - PAS de modification de api.cancel_consulta_as_reader (asymetrie
--   politique : le·la lecteur·rice a un droit d'annulation inalienable
--   sans avoir a se justifier, cf. spec consultas v2.1 §5.3)
--
-- Spec : docs/specs/spec-flux-consultations.md v2.1 §6.2, §8.1
-- Date : 2026-05-15
-- ============================================================

-- ============================================================
-- SECTION 1 — Refacto api.advance_consulta
-- ============================================================
-- On reprend la fonction existante (paquet 25, fichier
-- 20260512130000_consulta_workflow_wrappers.sql) et on ajoute la garde
-- en debut de bloc cancelada_biblioteca.
-- ============================================================

CREATE OR REPLACE FUNCTION api.advance_consulta(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_target_stage text,
  p_workflow_note text DEFAULT NULL,
  p_consultation_starts_at timestamptz DEFAULT NULL,
  p_consultation_ends_at timestamptz DEFAULT NULL,
  p_consultation_timezone text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
  v_current_stage text;
  v_updated int;
  v_trimmed_note text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta % nao encontrada', p_consulta_id USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  -- Recuperer le stage courant (premier line_no pour reference)
  SELECT workflow_stage INTO v_current_stage
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id AND line_no = p_line_nos[1];

  IF NOT public.fn_check_consulta_transition(v_current_stage, p_target_stage, v_actor_role) THEN
    RAISE EXCEPTION 'invalid_stage: transicao % -> % nao permitida para %', 
      v_current_stage, p_target_stage, v_actor_role
      USING ERRCODE = '42501';
  END IF;

  -- ============================================================
  -- B6 (15/05/2026) : note obligatoire pour annulation biblio
  -- ============================================================
  -- Doctrine politique : toute annulation par la biblio doit laisser
  -- une trace ecrite >= 5 chars (compromis pratique vs symbolique).
  -- Voir spec v2.1 §6.2 et §8.1.
  IF p_target_stage = 'cancelada_biblioteca' THEN
    v_trimmed_note := trim(coalesce(p_workflow_note, ''));
    IF length(v_trimmed_note) < 5 THEN
      RAISE EXCEPTION 'cancel_note_required: a note workflow de pelo menos 5 caracteres e obrigatoria para anulacao pela biblioteca'
        USING ERRCODE = 'P0001',
              HINT = 'Indique brevemente o motivo da anulacao (ex: livro indisponivel, doblee com outro pedido, etc.)';
    END IF;
  END IF;

  -- Invariant schedule_missing : starts_at et ends_at obligatoires ENSEMBLE
  IF p_target_stage = 'consulta_agendada' THEN
    IF p_consultation_starts_at IS NULL OR p_consultation_ends_at IS NULL THEN
      RAISE EXCEPTION 'schedule_missing: p_consultation_ends_at obrigatorio com p_consultation_starts_at'
        USING ERRCODE = 'P0001';
    END IF;
    
    v_updated := public.fn_v2_set_consulta_linhas_workflow_slot(
      p_consulta_id, p_line_nos, p_target_stage, p_workflow_note,
      to_char(p_consultation_starts_at, 'YYYY-MM-DD'),
      to_char(p_consultation_starts_at, 'HH24:MI'),
      to_char(p_consultation_ends_at, 'HH24:MI'),
      p_consultation_timezone
    );
  ELSE
    v_updated := public.fn_v2_set_consulta_linhas_workflow(
      p_consulta_id, p_line_nos, p_target_stage, p_workflow_note, NULL
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'updated_count', v_updated);
END;
$$;

COMMENT ON FUNCTION api.advance_consulta IS
  'Wrapper de transition workflow consulta (SECURITY INVOKER). Verifie role, transition autorisee, invariants schedule_missing et cancel_note_required. Cf. spec consultas v2.1 §6.2, §6.4 (R1 invariant schedule_missing), §6.2 et §8.1 (B6 note obligatoire annulation biblio, fix 15/05/2026).';

-- ============================================================
-- SECTION 2 — Verification finale (DO-block)
-- ============================================================

DO $$
DECLARE
  v_function_exists boolean;
  v_function_body text;
BEGIN
  -- Verifier que la fonction existe toujours
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'api' AND p.proname = 'advance_consulta'
  ) INTO v_function_exists;
  
  IF NOT v_function_exists THEN
    RAISE EXCEPTION 'Verification echouee : api.advance_consulta absente apres CREATE OR REPLACE';
  END IF;
  
  -- Verifier que la garde cancel_note_required est bien presente dans le body
  SELECT pg_get_functiondef(p.oid) INTO v_function_body
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'api' AND p.proname = 'advance_consulta';
  
  IF v_function_body NOT LIKE '%cancel_note_required%' THEN
    RAISE EXCEPTION 'Verification echouee : api.advance_consulta n''integre pas la garde cancel_note_required';
  END IF;
  
  RAISE NOTICE 'OK : api.advance_consulta refactoree avec garde cancel_note_required >= 5 chars';
  RAISE NOTICE 'Fix B6 (15/05/2026) applique avec succes';
END $$;
