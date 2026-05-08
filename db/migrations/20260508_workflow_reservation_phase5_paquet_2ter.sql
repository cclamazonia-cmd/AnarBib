-- =============================================================================
-- Migration : Workflow réservation v2 — Phase 5 paquet 2 ter
--             (advance_reservation set pickup_proposed_by automatiquement)
-- Date      : 2026-05-08
-- Spec      : docs/spec-workflow-reservation-v2-negotiation.md
-- Paquet    : 2 ter (complète paquet 2 et paquet 2 bis du même jour)
-- Préreq    : 20260508_workflow_reservation_phase5_negotiation.sql
--             20260508_workflow_reservation_phase5_paquet_2.sql
--             20260508_workflow_reservation_phase5_paquet_2bis.sql
-- =============================================================================
-- Patch sur api.advance_reservation (paquet phase 2 paquet A) pour qu'elle
-- enclenche correctement la négociation symétrique quand le staff fait passer
-- une réservation à un stage de retrait via la toolbar « Aplicar etapa ».
--
-- Avant cette migration :
--   advance_reservation set workflow_stage + pickup_scheduled_for + note,
--   mais ne touche PAS à pickup_proposed_by ni au compteur de négociation.
--   → Conséquence : les nouvelles résas en retirada_agendada / re-retirada_agendada
--     sortent avec pickup_proposed_by = NULL, ce qui court-circuite toute la
--     négociation symétrique (paquets 1, 2, 2 bis et UI 3B).
--
-- Après cette migration :
--   Quand p_target_stage IN (retirada_agendada, re-retirada_agendada) :
--     - workflow_stage et pickup_scheduled_for sont set comme avant
--     - pickup_proposed_by = 'biblio' (= la biblio vient de proposer)
--     - les champs legacy pickup_reply_status/note/at sont resetés
--   Comportement identique à fn_propose_pickup_slot_as_library (paquet 2),
--   mais via le chemin générique advance_reservation pour cohérence avec la
--   toolbar staff existante.
--
-- Pour les autres cibles (em_preparacao, retirada_a_combinar, etc.) :
--   pickup_proposed_by est explicitement reset à NULL (la négociation est
--   close ou n'a pas lieu d'être à ce stade).
--
-- Pour les transitions « no-show » (cible retirada_no_show) :
--   non concernées, car ce stage n'est jamais une cible directe via
--   advance_reservation (raccourci api.mark_no_show dédié, cf. paquet 2A).
--
-- Note de design : le compteur negotiation_iteration_count n'est PAS
-- incrémenté ici, car semantique B (validée CCLA) : seules les contre-propositions
-- LECTEUR comptent. La biblio peut proposer/relancer autant qu'elle veut sans
-- consommer le quota.
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. CREATE OR REPLACE api.advance_reservation
-- =============================================================================
-- Identique à la version paquet 2 phase A (20260507) sauf l'ajout d'un UPDATE
-- complémentaire sur pickup_proposed_by + reset legacy après la délégation au
-- helper standard.
-- =============================================================================

CREATE OR REPLACE FUNCTION api.advance_reservation(
  p_reserva_id bigint,
  p_line_no integer,
  p_target_stage text,
  p_options jsonb DEFAULT '{}'::jsonb
) RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_library_id uuid;
  v_current_stage text;
  v_actor_role text;
  v_note text;
  v_pickup timestamptz;
  v_n integer;
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

  IF p_target_stage IN ('retirada_agendada', 're-retirada_agendada', 'retirada_a_combinar')
     AND v_pickup IS NULL THEN
    RAISE EXCEPTION 'pickup_scheduled_for_required'
      USING ERRCODE = '22023',
            HINT = format(
              'cible %s requiert p_options->>''pickup_scheduled_for'' (timestamptz)',
              p_target_stage
            );
  END IF;

  -- Délégation au helper standard pour le stage + pickup_scheduled_for + note
  v_n := public.fn_v2_set_reserva_linhas_workflow(
    p_reserva_id, ARRAY[p_line_no], p_target_stage, v_note, v_pickup
  );

  -- ===========================================================================
  -- PATCH paquet 2 ter (2026-05-08) : enclenchement de la négociation symétrique
  -- ===========================================================================
  -- Selon la cible, on positionne pickup_proposed_by + reset legacy pickup_reply_*.
  -- Le compteur negotiation_iteration_count N'EST PAS touché (sémantique B :
  -- seules les contre-propositions lecteur·rice comptent).
  IF p_target_stage IN ('retirada_agendada', 're-retirada_agendada') THEN
    -- La biblio propose un créneau (ou re-propose après refus/contre-proposition)
    UPDATE public.reserva_item_workflow_v2
    SET pickup_proposed_by   = 'biblio',
        pickup_reply_status  = NULL,
        pickup_reply_note    = NULL,
        pickup_reply_at      = NULL
    WHERE reserva_id = p_reserva_id AND line_no = p_line_no;
  ELSE
    -- Toute autre cible (em_preparacao, retirada_a_combinar, cancelada_*, etc.) :
    -- la négociation est close ou non applicable, on remet à NULL pour cohérence.
    -- Note : retirada_a_combinar est un cas mou (créneau à fixer plus tard, pas
    -- de proposition formelle), donc proposed_by = NULL est correct.
    UPDATE public.reserva_item_workflow_v2
    SET pickup_proposed_by   = NULL,
        pickup_reply_status  = NULL,
        pickup_reply_note    = NULL,
        pickup_reply_at      = NULL
    WHERE reserva_id = p_reserva_id AND line_no = p_line_no
      AND pickup_proposed_by IS NOT NULL;  -- évite des UPDATE inutiles
  END IF;
  -- ===========================================================================

  RETURN v_n;
END;
$$;

REVOKE ALL ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) TO authenticated;

COMMENT ON FUNCTION api.advance_reservation(bigint, integer, text, jsonb) IS
  'Fait progresser une ligne de réservation vers un stage cible. Réservé au staff (librarian/coordenador) de la biblio. Valide la matrice de transitions via fn_check_workflow_transition. Cibles exclues : retirada_efetivada (api.confirm_pickup_v1), liberada_para_circulacao (trigger auto), expirada (cron). p_options jsonb : {"note": "...", "pickup_scheduled_for": "ISO8601"}. Paquet 2 ter (2026-05-08) : set automatiquement pickup_proposed_by = ''biblio'' quand cible IN (retirada_agendada, re-retirada_agendada), reset legacy pickup_reply_* dans tous les cas.';

COMMIT;

-- =============================================================================
-- Validation post-migration
-- =============================================================================
--
-- Q1. La fonction existe toujours dans api avec security_type INVOKER
-- SELECT routine_name, routine_type, security_type
--   FROM information_schema.routines
--   WHERE routine_schema = 'api' AND routine_name = 'advance_reservation';
-- Attendu : 1 ligne, security_type = 'INVOKER'
--
-- Q2. Le COMMENT a bien été mis à jour (mention "Paquet 2 ter")
-- SELECT obj_description('api.advance_reservation(bigint,integer,text,jsonb)'::regprocedure);
-- Attendu : description contenant "Paquet 2 ter (2026-05-08)"
--
-- Q3. Permissions inchangées
-- SELECT routine_name, grantee, privilege_type
--   FROM information_schema.routine_privileges
--   WHERE routine_schema = 'api' AND routine_name = 'advance_reservation'
--     AND grantee IN ('authenticated', 'anon', 'PUBLIC')
--   ORDER BY grantee;
-- Attendu : 1 seule ligne (authenticated, EXECUTE)
--
-- Q4. Idempotence : on peut rejouer la migration sans erreur
-- (Re-lance le fichier entier dans une nouvelle session SQL Editor)
--
-- =============================================================================
-- Migration de données ponctuelle (à lancer SÉPARÉMENT après la migration)
-- =============================================================================
-- Pour rétro-fitter les résas existantes qui sont actuellement en stage de
-- retrait avec pickup_proposed_by = NULL (parce qu'elles ont été créées avant
-- ce paquet 2 ter). Sans ce patch, ces résas restent invisibles à la négo
-- symétrique côté UI : pas de badge, pas de boutons d'action.
--
-- ⚠️ NE PAS METTRE DANS LA TRANSACTION CI-DESSUS : c'est un patch ponctuel sur
-- les données, pas une modification de schéma. À lancer manuellement après
-- avoir vérifié les Q1-Q4 ci-dessus.
--
-- À ce jour (2026-05-08), une seule résa concernée selon le diagnostic
-- effectué pendant la session : reserva_id = 2, line_no = 1.
--
-- UPDATE public.reserva_item_workflow_v2
-- SET pickup_proposed_by = 'biblio'
-- WHERE reserva_id = 2 AND line_no = 1
--   AND pickup_proposed_by IS NULL
--   AND workflow_stage IN ('retirada_agendada', 're-retirada_agendada');
--
-- Vérification post-UPDATE :
-- SELECT reserva_id, line_no, workflow_stage, pickup_proposed_by,
--        negotiation_iteration_count, pickup_scheduled_for
-- FROM public.reserva_item_workflow_v2
-- WHERE reserva_id = 2 AND line_no = 1;
-- Attendu : pickup_proposed_by = 'biblio'
-- =============================================================================
