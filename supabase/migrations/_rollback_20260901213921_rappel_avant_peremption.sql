-- =====================================================================
-- ROLLBACK de 20260901213921_rappel_avant_peremption.sql
--
-- Retire le cron et la fonction de rappel, et rend à
-- `fn_team_expire_invitations` sa version muette du 26/08 (20260826120000
-- §6, telle que corrigée par 20260901234500 — elle n'y touchait pas).
--
-- ATTENTION : après ce rollback, une proposition d'équipe peut à nouveau
-- expirer sans que personne ne l'apprenne. La fermeture reste correcte,
-- c'est son annonce qui disparaît — exactement le silence que GOUV-17b
-- avait relevé.
--
-- Les notifications déjà posées ne sont PAS supprimées : elles disent des
-- faits qui ont eu lieu.
-- =====================================================================

BEGIN;

DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-team-invitations-remind') THEN
    PERFORM cron.unschedule('anarbib-team-invitations-remind');
  END IF;
EXCEPTION
  WHEN undefined_table OR undefined_function OR invalid_schema_name OR insufficient_privilege THEN
    RAISE NOTICE 'pg_cron indisponible ici : desplanifier anarbib-team-invitations-remind manuellement';
END
$do$;

DROP FUNCTION IF EXISTS public.fn_team_invitation_remind();

CREATE OR REPLACE FUNCTION public.fn_team_expire_invitations()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.library_team_invitations
     SET status = 'expired',
         resolved_at = now(),
         updated_at = now(),
         resolution_note = COALESCE(resolution_note, '')
                           || ' [expirée automatiquement]'
   WHERE status IN ('pending_ratification', 'ready')
     AND expires_at IS NOT NULL
     AND expires_at < now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END
$fn$;

ALTER FUNCTION public.fn_team_expire_invitations() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_expire_invitations()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_team_expire_invitations() TO service_role;

COMMIT;
