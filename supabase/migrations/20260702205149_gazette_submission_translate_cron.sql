-- CHEMIN DÉPÔT : supabase/migrations/<timestamp>_gazette_submission_translate_cron.sql
-- À APPLIQUER APRÈS le déploiement de l'EF translate-gazette-submission + secrets.
-- Traduit automatiquement les brèves en attente, toutes les 10 minutes (par lots).

create or replace function public.fn_gazette_translate_call()
returns void language plpgsql security definer set search_path = public, extensions as $fn$
declare
  v_url    text := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/translate-gazette-submission';
  v_secret text;
  v_pending int;
begin
  -- ne rien faire s'il n'y a aucune brève à traduire (économise les appels)
  select count(*) into v_pending from public.gazette_submissions where i18n_status = 'pending';
  if v_pending = 0 then return; end if;

  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'gazette_cron_secret';
  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type','application/json','X-Cron-Secret', coalesce(v_secret,'')),
    body    := '{}'::jsonb
  );
end;
$fn$;

-- pg_cron absent du sql-tests CI (reconstruction sans cron) -> garde-fou doctrine.
DO $cron$
BEGIN
  PERFORM cron.schedule('anarbib-gazette-translate-submissions', '*/10 * * * *',
    $$select public.fn_gazette_translate_call()$$);
  RAISE NOTICE 'Job cron gazette translate cree/MAJ.';
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Job cron gazette translate NON cree (cron indisponible ici ?) : %. A creer/verifier en prod.', SQLERRM;
END;
$cron$;

-- Pour retirer :
-- select cron.unschedule('anarbib-gazette-translate-submissions');
