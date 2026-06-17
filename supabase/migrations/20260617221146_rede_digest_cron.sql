-- =========================================================================
-- Digest hebdomadaire « actus réseau » — déclencheur pg_cron (créé INACTIF)
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Feeding « avis & notifications » — digest e-mail (lecteur·rice passif·ve)
-- Auteur   : Claude (assistant·e)
-- Session  : Avis & notifications — feeding réseau (digest EF)
-- Branche  : rede-digest-ef (hors worktree partagé)
--
-- Accompagne l'Edge Function `notify-rede-digest` : un e-mail hebdomadaire qui
-- surface les nouveautés réseau (Gazette + nouveaux cercles) aux abonné·es de la
-- Lettre (consentement RÉUTILISÉ : profiles.consent_lettre ; désabonnement = celui
-- de la Lettre). Ne part QUE s'il y a du neuf. La Lettre garde son propre e-mail.
--
-- Déclenchement : pg_cron → fn_rede_digest_call() → net.http_post vers l'EF,
-- authentifié par le secret webhook (vault `rede_digest_webhook_secret`, reflété
-- dans l'env EF `WEBHOOK_SECRET_NOTIFY_REDE_DIGEST`).
--
-- ⚠️ Le job cron est créé **INACTIF** (doctrine paquet C.5c) : AUCUN e-mail ne part
-- tant que l'activation manuelle n'est pas faite. Checklist d'activation EN BAS.
-- =========================================================================

BEGIN;

-- Helper d'appel de l'EF (calqué sur fn_gazette_build_call).
CREATE OR REPLACE FUNCTION public.fn_rede_digest_call()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $fn$
DECLARE
  v_url    text := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/notify-rede-digest';
  v_secret text;
  v_until  timestamptz := now();
  v_since  timestamptz := now() - interval '7 days';
BEGIN
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'rede_digest_webhook_secret';
  PERFORM net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-webhook-secret', coalesce(v_secret, '')
               ),
    -- timestamptz -> chaîne ISO 8601 en JSON, parsée par new Date() côté EF.
    body    := jsonb_build_object('since', v_since, 'until', v_until, 'source', 'pg_cron')
  );
END;
$fn$;

-- Job hebdomadaire (lundi 09:00 UTC) créé puis DÉSACTIVÉ via cron.alter_job.
-- ⚠️ PAS d'UPDATE direct sur cron.job : cette table exige des privilèges NON
-- accordés au rôle qui exécute la migration (db push) ; cron.alter_job, elle,
-- fonctionne avec les permissions du propriétaire du job (cf. paquet C.5c).
-- cron.schedule UPSERTE par nom -> migration ré-exécutable (idempotente).
DO $$
DECLARE
  v_job_id bigint;
BEGIN
  v_job_id := cron.schedule(
    job_name := 'anarbib-rede-digest-weekly',
    schedule := '0 9 * * 1',
    command  := 'SELECT public.fn_rede_digest_call();'
  );
  PERFORM cron.alter_job(job_id := v_job_id, active := false);
END;
$$;

COMMIT;

-- =========================================================================
-- CHECKLIST D'ACTIVATION (manuelle, à faire APRÈS déploiement de l'EF) :
--   1) Déployer l'EF notify-rede-digest (fait par la CI au push).
--   2) Poser le secret webhook côté EF :
--        supabase secrets set WEBHOOK_SECRET_NOTIFY_REDE_DIGEST=<valeur-forte>
--   3) Refléter la MÊME valeur dans le vault pour le caller :
--        select vault.create_secret('<valeur-forte>', 'rede_digest_webhook_secret');
--   4) Test à blanc (fenêtre sans nouveauté -> skipped, ou avec un secret valide) :
--        select public.fn_rede_digest_call();
--   5) Activer le cron (via cron.alter_job, pas UPDATE direct) :
--        select cron.alter_job(
--          job_id := (select jobid from cron.job where jobname = 'anarbib-rede-digest-weekly'),
--          active := true);
-- Pour retirer :  select cron.unschedule('anarbib-rede-digest-weekly');
-- =========================================================================
