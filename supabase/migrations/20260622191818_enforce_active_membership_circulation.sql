-- =========================================================================
-- Enforcement de la validation d'inscription — réservations & consultations
-- =========================================================================
-- Date     : 2026-06-22
-- Chantier : validation présentielle/remote des lecteur·ices (BLMF)
-- Auteur   : Claude (MCP Supabase) — appliquée d'abord sur staging, réintégrée au repo
--
-- Contexte : le mode reader_validation_mode ('presential'/'remote') exige qu'un
-- lecteur soit validé par le staff avant d'accéder aux fonctionnalités lecteur.
-- Or AUCUN contrôle ne l'imposait : les policies de circulation ne filtrent que
-- auth.uid()+circulation, et la création passe par des fonctions SECURITY DEFINER
-- (fn_v2_create_reserva_by_holdings / fn_v2_create_consulta_local_by_holdings)
-- qui CONTOURNENT la RLS. Un membre 'pending_validation' pouvait donc tout faire.
--
-- Choix : garde posée en trigger BEFORE INSERT sur reservas_v2 et
-- consultas_locais_v2 plutôt que réécrire ces deux fonctions volumineuses
-- (moins de surface de régression). La garde ne s'applique qu'au self-service
-- (NEW.user_id = auth.uid()) : les inserts service_role (auth.uid() NULL) et
-- staff-pour-lecteur (user_id <> caller) ne sont pas affectés. Keyée sur
-- status='active' via fn_current_user_is_member_of — jamais sur
-- physically_validated_at (des membres de plein droit sont active sans horodatage).
-- Idempotent. Aucun membre pending_validation au moment de l'application.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_trg_require_active_membership()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  -- Self-service uniquement : un lecteur qui crée pour lui-même doit être
  -- un membre 'active' de la biblio ciblée. Staff / service_role non concernés.
  IF auth.uid() IS NOT NULL
     AND NEW.user_id = auth.uid()
     AND NOT public.fn_current_user_is_member_of(NEW.library_id) THEN
    RAISE EXCEPTION 'Votre inscription à cette bibliothèque doit encore être validée.'
      USING errcode = 'P0001', hint = 'error.membership.not_active';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_trg_require_active_membership() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_trg_require_active_membership() IS
  'Garde validation inscription : bloque la création self-service de réservation/consultation par un membre non encore validé (status<>active). Chantier validation présentielle, 22/06/2026.';

DROP TRIGGER IF EXISTS trg_require_active_membership ON public.reservas_v2;
CREATE TRIGGER trg_require_active_membership
  BEFORE INSERT ON public.reservas_v2
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_require_active_membership();

DROP TRIGGER IF EXISTS trg_require_active_membership ON public.consultas_locais_v2;
CREATE TRIGGER trg_require_active_membership
  BEFORE INSERT ON public.consultas_locais_v2
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_require_active_membership();

-- register (service_role) poste membership_validation_requested via PostgREST.
-- request_membership l'appelle en interne (definer) ; ce droit n'a jamais été
-- exercé pour service_role en appel direct.
GRANT EXECUTE ON FUNCTION public.fn_dispatch_notify_event(text, bigint, jsonb) TO service_role;

-- -------------------------------------------------------------------------
-- Vérification : les deux triggers doivent exister (sinon rollback).
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_trigger
  WHERE tgname = 'trg_require_active_membership'
    AND tgrelid IN ('public.reservas_v2'::regclass, 'public.consultas_locais_v2'::regclass)
    AND NOT tgisinternal;

  IF v_count <> 2 THEN
    RAISE EXCEPTION 'Vérification échouée : % trigger(s) posé(s), attendu 2. Rollback.', v_count;
  END IF;

  RAISE NOTICE 'Enforcement validation : 2 triggers en place. OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé en cas de régression post-déploiement :
-- =========================================================================
-- BEGIN;
--   DROP TRIGGER IF EXISTS trg_require_active_membership ON public.consultas_locais_v2;
--   DROP TRIGGER IF EXISTS trg_require_active_membership ON public.reservas_v2;
--   DROP FUNCTION IF EXISTS public.fn_trg_require_active_membership();
-- COMMIT;
-- =========================================================================
