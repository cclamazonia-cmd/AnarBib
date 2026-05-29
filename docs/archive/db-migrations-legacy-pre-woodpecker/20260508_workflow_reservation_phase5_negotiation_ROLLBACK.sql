-- =============================================================================
-- ROLLBACK : Workflow réservation — Phase 5 (négociation symétrique)
-- =============================================================================
-- Inverse la migration 20260508_workflow_reservation_phase5_negotiation.sql
--
-- À utiliser uniquement si la migration cause un problème en production.
-- Restaure l'état pré-migration : retire les nouvelles colonnes et restaure
-- la fonction fn_check_workflow_transition à sa version v1.
--
-- ATTENTION : ce rollback supprime les colonnes — toute donnée écrite dedans
-- sera perdue. Vérifie avec une requête SELECT avant d'exécuter :
--   SELECT count(*) FROM reserva_item_workflow_v2
--     WHERE pickup_proposed_by IS NOT NULL OR negotiation_iteration_count > 0;
-- =============================================================================

BEGIN;

-- 1. Restaurer fn_check_workflow_transition à sa version v1 (pré-migration)
CREATE OR REPLACE FUNCTION public.fn_check_workflow_transition(
  p_from text,
  p_to text,
  p_actor_role text
) RETURNS boolean
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = public
AS $$
WITH normalized AS (
  SELECT
    CASE WHEN p_from = 'nao_retirada' THEN 'retirada_no_show'
         ELSE p_from END AS f,
    CASE WHEN p_to = 'nao_retirada' THEN 'retirada_no_show'
         ELSE p_to END AS t,
    p_actor_role AS r
)
SELECT CASE
  WHEN f IS NULL OR t IS NULL OR r IS NULL THEN false
  WHEN f IN (
    'retirada_efetivada',
    'cancelada_leitor',
    'cancelada_biblioteca',
    'expirada',
    'liberada_para_circulacao'
  ) THEN false
  WHEN f = 'retirada_no_show' THEN false
  WHEN r = 'lecteur' AND t = 'cancelada_leitor' AND f IN (
    'solicitada',
    'em_preparacao',
    'retirada_agendada',
    'retirada_a_combinar',
    're-retirada_agendada',
    'pronta_para_retirada'
  ) THEN true
  WHEN r = 'lecteur' THEN false
  WHEN r = 'coordenador' AND t = 'cancelada_biblioteca' AND f IN (
    'solicitada',
    'em_preparacao',
    'retirada_agendada',
    'retirada_a_combinar',
    're-retirada_agendada',
    'pronta_para_retirada'
  ) THEN true
  WHEN r = 'system' AND t = 'expirada' AND f = 'solicitada' THEN true
  WHEN r = 'system' AND t = 'retirada_no_show' AND f IN (
    'pronta_para_retirada',
    'retirada_agendada',
    're-retirada_agendada'
  ) THEN true
  WHEN r = 'system' THEN false
  WHEN f = 'solicitada' AND t IN (
    'em_preparacao',
    'retirada_agendada',
    'retirada_a_combinar'
  ) AND r IN ('librarian', 'coordenador') THEN true
  WHEN f = 'em_preparacao' AND t IN (
    'retirada_agendada',
    'retirada_a_combinar'
  ) AND r IN ('librarian', 'coordenador') THEN true
  WHEN f = 'retirada_agendada' AND t IN (
    're-retirada_agendada',
    'pronta_para_retirada'
  ) AND r IN ('librarian', 'coordenador') THEN true
  WHEN f = 'retirada_a_combinar' AND t IN (
    'retirada_agendada',
    're-retirada_agendada',
    'pronta_para_retirada'
  ) AND r IN ('librarian', 'coordenador') THEN true
  WHEN f = 're-retirada_agendada' AND t IN (
    're-retirada_agendada',
    'pronta_para_retirada'
  ) AND r IN ('librarian', 'coordenador') THEN true
  WHEN f = 'pronta_para_retirada' AND t IN (
    'retirada_efetivada',
    'retirada_no_show'
  ) AND r IN ('librarian', 'coordenador') THEN true
  ELSE false
END
FROM normalized;
$$;

-- 2. Supprimer les contraintes ajoutées
ALTER TABLE public.reserva_item_workflow_v2
  DROP CONSTRAINT IF EXISTS chk_pickup_proposed_by;
ALTER TABLE public.reserva_item_workflow_v2
  DROP CONSTRAINT IF EXISTS chk_negotiation_iteration_max;
ALTER TABLE public.library_notification_policies
  DROP CONSTRAINT IF EXISTS chk_negotiation_timeout;

-- 3. Supprimer les colonnes ajoutées
ALTER TABLE public.reserva_item_workflow_v2
  DROP COLUMN IF EXISTS pickup_proposed_by;
ALTER TABLE public.reserva_item_workflow_v2
  DROP COLUMN IF EXISTS negotiation_iteration_count;
ALTER TABLE public.library_notification_policies
  DROP COLUMN IF EXISTS reservation_allow_reader_counter_proposal;
ALTER TABLE public.library_notification_policies
  DROP COLUMN IF EXISTS reservation_negotiation_timeout_days;

COMMIT;
