-- =============================================================================
-- ROLLBACK : Workflow réservation v2 — Phase 5 paquet 2
-- =============================================================================
-- Inverse la migration 20260508_workflow_reservation_phase5_paquet_2.sql
--
-- Supprime les 2 nouvelles RPC, le trigger, la fonction trigger, le cron job
-- et la fonction cron. Restaure l'état post-paquet-1 (donc avec les colonnes
-- pickup_proposed_by + negotiation_iteration_count toujours présentes mais
-- sans les RPC pour les manipuler).
--
-- ATTENTION : si tu veux rollback paquet 1 + paquet 2 d'un coup, lance
-- d'abord ce rollback PUIS le rollback du paquet 1.
-- =============================================================================

BEGIN;

-- 1. Désinscription du cron job
DO $$
BEGIN
  PERFORM cron.unschedule('anarbib-reservation-expire-negotiation');
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- 2. Suppression de la fonction cron
DROP FUNCTION IF EXISTS public.fn_expire_negotiation_timeout();

-- 3. Suppression du trigger et de sa fonction
DROP TRIGGER IF EXISTS trg_increment_negotiation_counter ON public.reserva_item_workflow_v2;
DROP FUNCTION IF EXISTS public.fn_increment_negotiation_counter();

-- 4. Suppression des 2 RPC
DROP FUNCTION IF EXISTS api.fn_propose_pickup_slot_as_library(bigint, integer, timestamptz, text);
DROP FUNCTION IF EXISTS api.fn_propose_pickup_slot_as_reader(bigint, integer, timestamptz, text);

COMMIT;
