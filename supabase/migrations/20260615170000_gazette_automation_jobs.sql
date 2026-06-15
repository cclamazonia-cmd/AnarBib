-- CHEMIN DÉPÔT : supabase/migrations/<timestamp>_gazette_automation_jobs.sql
-- À APPLIQUER APRÈS : déploiement de l'EF gazette-monthly-build + pose des secrets
-- (ANTHROPIC_API_KEY, GAZETTE_CRON_SECRET) + secret Vault pour l'appel cron.
--
-- Orchestration SANS GitHub Actions : pg_cron déclenche l'EF par étapes.
--   • le 15 à 06:00 UTC   → étape "start"
--   • toutes les 5 min     → "tick" (avance le job jusqu'à status='ready')

-- 1) État du build (1 ligne par numéro)
create table if not exists public.gazette_build_jobs (
  issue_number  integer primary key,
  status        text not null default 'curating'
                check (status in ('curating','translating','assembling','finalizing','ready','failed')),
  cursor_locale text,
  sources       jsonb not null default '{}'::jsonb,
  step_error    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create trigger tg_gazette_build_jobs_updated_at
  before update on public.gazette_build_jobs
  for each row execute function public.set_updated_at();

alter table public.gazette_build_jobs enable row level security;
create policy gazette_build_jobs_read_network_staff on public.gazette_build_jobs
  for select to authenticated
  using (exists (select 1 from public.network_staff ns where ns.user_id = auth.uid() and ns.is_active));
-- Écriture : service_role uniquement (l'EF), donc pas de policy d'écriture.

-- 2) Helper d'appel de l'EF via pg_net (calquer sur vos fn_cron_* existantes).
--    ⚠️ Adapter la récupération du secret au mécanisme maison (Vault). Exemple Vault :
--       select decrypted_secret from vault.decrypted_secrets where name = 'gazette_cron_secret'
create or replace function public.fn_gazette_build_call(p_step text, p_issue integer default null)
returns void language plpgsql security definer set search_path = public, extensions as $fn$
declare
  v_url    text := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/gazette-monthly-build';
  v_secret text;
begin
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'gazette_cron_secret';
  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type','application/json','X-Cron-Secret', coalesce(v_secret,'')),
    body    := jsonb_build_object('step', p_step, 'issue_number', p_issue)
  );
end;
$fn$;

-- 3) pg_cron (extension déjà active sur le projet)
-- Démarrage mensuel : 15 du mois à 06:00 UTC
select cron.schedule('anarbib-gazette-monthly-start', '0 6 15 * *', $$select public.fn_gazette_build_call('start')$$);
-- Avance par étapes toutes les 5 minutes (no-op si aucun job en cours)
select cron.schedule('anarbib-gazette-reconcile-tick', '*/5 * * * *', $$select public.fn_gazette_build_call('tick')$$);

-- Pour retirer :
-- select cron.unschedule('anarbib-gazette-monthly-start');
-- select cron.unschedule('anarbib-gazette-reconcile-tick');
