-- Supervision minimale du service public.
--
-- Constat du test de charge (17/08) : AUCUNE alerte n'existait, et la premiere
-- mesure de latence du projet a ete faite ce jour-la. En cas de degradation
-- pendant une rencontre, on l'apprendrait par les personnes presentes.
--
-- Principe : un cron toutes les 5 min appelle l'Edge Function `health-probe`,
-- qui interroge les points d'entree PUBLICS (comme un visiteur), enregistre
-- code HTTP et latence, et alerte par e-mail les administrateurs reseau quand
-- deux tours consecutifs sont mauvais. Un e-mail de retablissement est envoye
-- a la fermeture de l'incident, pour ne pas laisser croire a une panne qui dure.
--
-- Limite ASSUMEE : la sonde vit dans Supabase, donc une panne TOTALE de
-- Supabase l'emporte avec le service. Elle couvre la degradation (lenteurs,
-- 500 sous charge), qui est le risque reellement identifie.
--
-- A ne pas confondre avec fn_healthcheck_notifications() (autre session, meme
-- journee) : celle-la verifie la COHERENCE DE CONFIGURATION du systeme de
-- notifications (secrets presents dans le Vault, types d'evenements declares,
-- crons planifies). Ici on mesure la DISPONIBILITE du service public.

create table if not exists public.service_health_probes (
  id           bigserial primary key,
  checked_at   timestamptz not null default now(),
  endpoint     text        not null,
  ok           boolean     not null,
  status_code  integer,
  latency_ms   integer,
  error        text
);

create index if not exists idx_shp_checked_at on public.service_health_probes (checked_at desc);
create index if not exists idx_shp_endpoint   on public.service_health_probes (endpoint, checked_at desc);

comment on table public.service_health_probes is
  'Historique des sondes de disponibilite du service public (1 ligne par point d''entree et par tour). Purge automatique au-dela de 30 jours par l''Edge Function health-probe.';

create table if not exists public.service_health_incidents (
  id          bigserial primary key,
  opened_at   timestamptz not null default now(),
  closed_at   timestamptz,
  reason      text        not null,
  notified_at timestamptz
);

create index if not exists idx_shi_ouverts on public.service_health_incidents (opened_at desc) where closed_at is null;

comment on table public.service_health_incidents is
  'Incidents de disponibilite ouverts par health-probe. Sert d''anti-repetition : une seule alerte par incident, plus un e-mail de retablissement a la fermeture.';

-- Lecture reservee aux administrateurs reseau. Aucune politique pour anon :
-- RLS active => zero ligne (les droits de table restent larges, comme partout
-- ailleurs dans ce schema, c'est la politique qui fait le verrou).
alter table public.service_health_probes    enable row level security;
alter table public.service_health_incidents enable row level security;

drop policy if exists service_health_probes_read_admin on public.service_health_probes;
create policy service_health_probes_read_admin on public.service_health_probes
  for select to authenticated using (fn_caller_is_network_admin());

drop policy if exists service_health_incidents_read_admin on public.service_health_incidents;
create policy service_health_incidents_read_admin on public.service_health_incidents
  for select to authenticated using (fn_caller_is_network_admin());

-- Secret d'appel. Meme garde-fou CI que pour notify-security-notice : le stub
-- vault du job sql-tests ne fournit ni vault.secrets ni vault.create_secret().
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'WEBHOOK_SECRET_HEALTH_PROBE') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'WEBHOOK_SECRET_HEALTH_PROBE',
      'Secret d''appel de l''Edge Function health-probe (supervision).');
  end if;
exception
  when undefined_table or undefined_function or invalid_schema_name then
    raise notice 'Vault indisponible (CI) : creation du secret health-probe ignoree.';
end $$;

create or replace function public.fn_check_health_probe_secret(p_secret text)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public', 'vault', 'pg_temp'
as $$
declare v_expected text;
begin
  if p_secret is null or length(btrim(p_secret)) = 0 then return false; end if;
  select decrypted_secret into v_expected
    from vault.decrypted_secrets where name = 'WEBHOOK_SECRET_HEALTH_PROBE';
  if v_expected is null or length(v_expected) = 0 then return false; end if;
  return btrim(p_secret) = v_expected;
end $$;

revoke all on function public.fn_check_health_probe_secret(text) from public, anon, authenticated;
grant execute on function public.fn_check_health_probe_secret(text) to service_role;

-- Cron : un tour toutes les 5 minutes. Bloc garde (schema cron absent en CI).
do $cron$
begin
  perform cron.schedule(
    'anarbib-health-probe',
    '*/5 * * * *',
    $job$
      select net.http_post(
        url := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/health-probe',
        headers := jsonb_build_object(
          'content-type', 'application/json',
          'x-webhook-secret', (select decrypted_secret from vault.decrypted_secrets
                                where name = 'WEBHOOK_SECRET_HEALTH_PROBE')),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000);
    $job$);
exception when others then
  raise warning 'Job cron health-probe NON cree (cron indisponible ici ?) : %.', sqlerrm;
end
$cron$;
