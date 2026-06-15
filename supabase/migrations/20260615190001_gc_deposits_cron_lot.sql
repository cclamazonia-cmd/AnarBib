-- =========================================================================
-- Chantier « gestion des fichiers numériques », point 2 — GC des dépôts attachés.
--
-- Après attache, le fichier d'origine reste dans partner-catalog-deposits (l'EF COPIE,
-- ne déplace pas) : redondant une fois l'asset dans le bucket final. Le DELETE storage
-- est interdit en SQL (trigger storage.protect_delete) et la policy partner_deposit_delete
-- est inopérante côté usager (chemin received/<run>/… ≠ library_id). La purge passe donc
-- par l'EF gc-deposits (service_role), déclenchée par un cron quotidien.
--
--   1. ingest.fn_cron_gc_deposits() : appelle l'EF gc-deposits via pg_net (secret vault).
--   2. cron.schedule('gc-fonds-deposits', '30 4 * * *', …).
-- =========================================================================
BEGIN;

CREATE OR REPLACE FUNCTION ingest.fn_cron_gc_deposits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'ingest', 'public'
AS $$
DECLARE
  v_secret text;
  v_base   text := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/';
  v_req    bigint;
BEGIN
  SELECT ds.decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets ds
   WHERE ds.name = 'ANARBIB_PARTNER_IMPORT_SECRET'
   ORDER BY ds.created_at DESC LIMIT 1;
  IF coalesce(v_secret, '') = '' THEN
    RAISE EXCEPTION 'Secret ANARBIB_PARTNER_IMPORT_SECRET introuvable dans vault.decrypted_secrets';
  END IF;

  v_req := net.http_post(
    url := v_base || 'gc-deposits',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-import-secret', v_secret),
    body := jsonb_build_object('age_days', 30),
    timeout_milliseconds := 60000
  );
END;
$$;

REVOKE ALL ON FUNCTION ingest.fn_cron_gc_deposits() FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION ingest.fn_cron_gc_deposits() IS
  'Chantier fichiers numériques (point 2). Déclenche l''EF gc-deposits (pg_net + secret vault) pour '
  'purger les fichiers de dépôt des received_assets attachés depuis > 30 j. Appelé par le cron '
  'gc-fonds-deposits. INTERNE.';

-- Planification quotidienne (04:30 UTC). cron.schedule est idempotent par jobname.
SELECT cron.schedule('gc-fonds-deposits', '30 4 * * *', $cron$ SELECT ingest.fn_cron_gc_deposits(); $cron$);

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                  WHERE n.nspname='ingest' AND p.proname='fn_cron_gc_deposits') THEN
    RAISE EXCEPTION 'verify (pt2): ingest.fn_cron_gc_deposits manquante';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname='gc-fonds-deposits') THEN
    RAISE EXCEPTION 'verify (pt2): cron gc-fonds-deposits non planifié';
  END IF;
  RAISE NOTICE 'point 2 OK : GC des dépôts (cron + EF gc-deposits).';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   SELECT cron.unschedule('gc-fonds-deposits');
--   DROP FUNCTION IF EXISTS ingest.fn_cron_gc_deposits();
-- =========================================================================
