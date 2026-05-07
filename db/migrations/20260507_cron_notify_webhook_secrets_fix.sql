-- =============================================================================
-- Migration : 20260507_cron_notify_webhook_secrets_fix
-- Auteur    : Xavier (AnarBib) — 07/05/2026
-- Contexte  : Audit Chantier 1 du 07/05/2026
-- =============================================================================
--
-- PROBLÈME DIAGNOSTIQUÉ
-- ---------------------
-- Trois cron jobs `pg_cron` appelaient des Edge Functions `notify-*` sans
-- envoyer le header `x-webhook-secret` exigé par les EFs côté Deno
-- (`mustEnv("WEBHOOK_SECRET_NOTIFY_*")`). Conséquence : 401 silencieux.
--
-- En plus du secret manquant, deux des trois EFs exigent un payload structuré
-- (`week_start`, `week_end`, voire `library_id`) que les crons n'envoyaient
-- pas non plus :
--
--   1. anarbib-notify-mid-loan-reading-daily       → secret manquant
--   2. anarbib-notify-weekly-report-weekly         → secret + library_id +
--                                                     week_start/end manquants
--   3. anarbib-notify-network-weekly-report-weekly → secret + week_start/end
--                                                     manquants
--
-- PRÉ-REQUIS AVANT D'APPLIQUER CETTE MIGRATION
-- --------------------------------------------
-- Les 3 secrets webhook DOIVENT exister dans `vault.decrypted_secrets` :
--
--   - WEBHOOK_SECRET_NOTIFY_MID_LOAN
--   - WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT
--   - WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT
--
-- Ainsi que SUPABASE_URL (déjà présent au 07/05/2026).
--
-- Pour les copier depuis l'env Edge Functions vers le vault :
--   Dashboard Supabase → Project Settings → Vault → New Secret
--   (récupérer la valeur depuis Edge Functions → <function> → Settings → Secrets)
--
-- Le bloc "Pré-vérification" en tête de migration AVORTE l'application si les
-- secrets manquent, donc aucun risque de casser l'état actuel.
--
-- IDEMPOTENCE
-- -----------
-- Cette migration est entièrement idempotente. On peut la rouler 1, 2 ou N
-- fois sans effet de bord :
--   - CREATE OR REPLACE FUNCTION pour les fonctions
--   - cron.unschedule + cron.schedule pour les jobs
--   - Aucune création de table
--
-- ROLLBACK
-- --------
-- Voir le bloc commenté en queue de fichier (section "ROLLBACK").
-- En clair : restaurer les 3 anciens jobs cron tels qu'ils étaient avant
-- cette migration. Les fonctions PL/pgSQL créées peuvent rester (elles ne
-- sont plus appelées).
--
-- =============================================================================

begin;

-- =============================================================================
-- 0. PRÉ-VÉRIFICATION DES SECRETS REQUIS
-- =============================================================================
-- Si l'un des secrets manque, on AVORTE proprement avant de toucher à
-- quoi que ce soit. Pas de modification partielle, pas d'état hybride.
-- =============================================================================

do $$
declare
  v_missing text[] := array[]::text[];
  v_required text[] := array[
    'SUPABASE_URL',
    'WEBHOOK_SECRET_NOTIFY_MID_LOAN',
    'WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT',
    'WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT'
  ];
  v_secret text;
begin
  foreach v_secret in array v_required loop
    if not exists (
      select 1
      from vault.decrypted_secrets ds
      where ds.name = v_secret
        and coalesce(btrim(ds.decrypted_secret), '') <> ''
    ) then
      v_missing := array_append(v_missing, v_secret);
    end if;
  end loop;

  if array_length(v_missing, 1) > 0 then
    raise exception
      'Migration avortée : secrets manquants dans vault.decrypted_secrets : %. '
      'Ajoutez-les via Dashboard → Project Settings → Vault avant de réessayer.',
      array_to_string(v_missing, ', ');
  end if;
end$$;


-- =============================================================================
-- 1. HELPER : récupération d'un secret du vault
-- =============================================================================
-- Pattern hérité de fn_enqueue_document_permission_request_notification.
-- On factorise pour limiter la duplication dans les 3 nouvelles fonctions
-- de dispatch.
-- =============================================================================

create or replace function public.fn_internal_get_vault_secret(p_name text)
returns text
language plpgsql
security definer
set search_path to 'public', 'vault', 'extensions', 'pg_temp'
as $function$
declare
  v_value text;
begin
  select ds.decrypted_secret
    into v_value
  from vault.decrypted_secrets ds
  where ds.name = p_name
  order by ds.created_at desc
  limit 1;

  if coalesce(btrim(v_value), '') = '' then
    raise exception 'Secret % introuvable ou vide dans vault.decrypted_secrets.', p_name;
  end if;

  return btrim(v_value);
end;
$function$;

revoke all on function public.fn_internal_get_vault_secret(text) from public, anon, authenticated;
comment on function public.fn_internal_get_vault_secret(text) is
'Helper interne : lit la version la plus récente d''un secret du vault. SECURITY DEFINER, jamais exposé via API.';


-- =============================================================================
-- 2. HELPER : calcul de la semaine ISO précédente (lundi → dimanche, UTC)
-- =============================================================================
-- Les rapports hebdo couvrent la semaine *écoulée*, pas la semaine en cours.
-- Comme les crons tournent le lundi matin, on veut :
--   week_start = lundi précédent (J-7)
--   week_end   = dimanche précédent (J-1)
--
-- Note : on travaille en UTC partout (les EFs reformatent ensuite selon le tz
-- envoyé en payload).
-- =============================================================================

create or replace function public.fn_internal_previous_iso_week(p_today date default null)
returns table(week_start date, week_end date)
language plpgsql
immutable
as $function$
declare
  v_today date := coalesce(p_today, (now() at time zone 'utc')::date);
  v_dow   int;  -- 1=lundi … 7=dimanche (extract dow donne 0=dim … 6=sam)
begin
  v_dow := extract(isodow from v_today)::int;
  -- v_dow=1 (lundi) → week_start = today - 7
  -- v_dow=2 (mardi) → week_start = today - 8 (lundi de la semaine d'avant)
  -- etc.
  week_start := v_today - (v_dow - 1) - 7;
  week_end   := week_start + 6;
  return next;
end;
$function$;

comment on function public.fn_internal_previous_iso_week(date) is
'Renvoie (lundi, dimanche) de la semaine ISO précédant la date donnée. Défaut : aujourd''hui UTC.';


-- =============================================================================
-- 3. DISPATCH : notify-mid-loan-reading
-- =============================================================================
-- L'EF gère déjà tout côté métier (calcul de targetDate, itération sur les
-- bibliothèques, anti-doublon via loan_midpoint_message_log, opt-in par
-- contexte et par user). Le cron a juste besoin de l'appeler une fois par
-- jour avec le bon webhook secret. Aucun payload spécifique requis.
-- =============================================================================

create or replace function public.fn_cron_notify_mid_loan_reading()
returns bigint
language plpgsql
security definer
set search_path to 'public', 'vault', 'extensions', 'pg_temp'
as $function$
declare
  v_url    text;
  v_secret text;
  v_req_id bigint;
begin
  v_url := regexp_replace(
    public.fn_internal_get_vault_secret('SUPABASE_URL'),
    '/+$', ''
  ) || '/functions/v1/notify-mid-loan-reading';

  v_secret := public.fn_internal_get_vault_secret('WEBHOOK_SECRET_NOTIFY_MID_LOAN');

  v_req_id := net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'source', 'pg_cron',
      'job', 'anarbib-notify-mid-loan-reading-daily',
      'scheduled_at', now()
    ),
    timeout_milliseconds := 60000
  );

  return v_req_id;
end;
$function$;

revoke all on function public.fn_cron_notify_mid_loan_reading() from public, anon, authenticated;
comment on function public.fn_cron_notify_mid_loan_reading() is
'Wrapper cron pour notify-mid-loan-reading : ajoute le webhook secret. L''EF calcule elle-même la fenêtre temporelle.';


-- =============================================================================
-- 4. DISPATCH : notify-network-weekly-report
-- =============================================================================
-- L'EF orchestre l'itération sur les bibliothèques en interne mais exige
-- week_start + week_end en payload. On les calcule à partir de la date
-- d'exécution du cron (lundi N → semaine du lundi N-7 au dimanche N-1).
-- =============================================================================

create or replace function public.fn_cron_notify_network_weekly_report()
returns bigint
language plpgsql
security definer
set search_path to 'public', 'vault', 'extensions', 'pg_temp'
as $function$
declare
  v_url     text;
  v_secret  text;
  v_req_id  bigint;
  v_week    record;
begin
  v_url := regexp_replace(
    public.fn_internal_get_vault_secret('SUPABASE_URL'),
    '/+$', ''
  ) || '/functions/v1/notify-network-weekly-report';

  v_secret := public.fn_internal_get_vault_secret('WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT');

  select * into v_week from public.fn_internal_previous_iso_week();

  v_req_id := net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'source', 'pg_cron',
      'job', 'anarbib-notify-network-weekly-report-weekly',
      'scheduled_at', now(),
      'week_start', to_char(v_week.week_start, 'YYYY-MM-DD'),
      'week_end',   to_char(v_week.week_end,   'YYYY-MM-DD'),
      'tz', 'UTC'
    ),
    timeout_milliseconds := 60000
  );

  return v_req_id;
end;
$function$;

revoke all on function public.fn_cron_notify_network_weekly_report() from public, anon, authenticated;
comment on function public.fn_cron_notify_network_weekly_report() is
'Wrapper cron pour notify-network-weekly-report : ajoute webhook secret + week_start/end de la semaine ISO précédente.';


-- =============================================================================
-- 5. DISPATCH : notify-weekly-report (par bibliothèque)
-- =============================================================================
-- L'EF attend UN library_id par appel. On itère donc sur toutes les
-- bibliothèques actives et on enfile un appel par bibliothèque.
--
-- Note : pas de `loanable channels` filter ici. C'est l'EF qui décide
-- d'envoyer ou pas (via `weekly_library_summary_enabled` + `channelActive`).
-- Si une lib a son canal désactivé, l'EF retourne 200 ok+skipped et on
-- n'envoie rien. C'est le comportement attendu — la décision est dans le
-- contexte bibliothèque, pas au niveau du cron.
-- =============================================================================

create or replace function public.fn_cron_notify_weekly_report_per_library()
returns table(library_id uuid, request_id bigint)
language plpgsql
security definer
set search_path to 'public', 'vault', 'extensions', 'pg_temp'
as $function$
declare
  v_url    text;
  v_secret text;
  v_week   record;
  v_lib    record;
  v_req_id bigint;
begin
  v_url := regexp_replace(
    public.fn_internal_get_vault_secret('SUPABASE_URL'),
    '/+$', ''
  ) || '/functions/v1/notify-weekly-report';

  v_secret := public.fn_internal_get_vault_secret('WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT');

  select * into v_week from public.fn_internal_previous_iso_week();

  for v_lib in
    select l.id
    from public.libraries l
    where l.is_active = true
    order by l.name
  loop
    v_req_id := net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', v_secret
      ),
      body := jsonb_build_object(
        'source', 'pg_cron',
        'job', 'anarbib-notify-weekly-report-weekly',
        'scheduled_at', now(),
        'library_id', v_lib.id::text,
        'week_start', to_char(v_week.week_start, 'YYYY-MM-DD'),
        'week_end',   to_char(v_week.week_end,   'YYYY-MM-DD'),
        'tz', 'UTC'
      ),
      timeout_milliseconds := 60000
    );

    library_id := v_lib.id;
    request_id := v_req_id;
    return next;
  end loop;

  return;
end;
$function$;

revoke all on function public.fn_cron_notify_weekly_report_per_library() from public, anon, authenticated;
comment on function public.fn_cron_notify_weekly_report_per_library() is
'Wrapper cron pour notify-weekly-report : itère sur toutes les bibliothèques actives, un appel par lib avec library_id + week_start/end.';


-- =============================================================================
-- 6. RECONFIGURATION DES 3 CRON JOBS
-- =============================================================================
-- Pattern : on désinscrit l'ancien job (s'il existe), puis on en crée un
-- nouveau avec exactement le même nom mais qui appelle la fonction wrapper.
--
-- cron.unschedule est tolérant aux jobs absents si on lui passe le nom
-- (il renvoie false sans erreur). On l'enrobe quand même dans un do block
-- pour que la migration reste idempotente même sur un projet où un des
-- jobs aurait déjà été supprimé manuellement.
-- =============================================================================

do $$
declare
  v_job_names text[] := array[
    'anarbib-notify-mid-loan-reading-daily',
    'anarbib-notify-network-weekly-report-weekly',
    'anarbib-notify-weekly-report-weekly'
  ];
  v_job text;
begin
  foreach v_job in array v_job_names loop
    if exists (select 1 from cron.job where jobname = v_job) then
      perform cron.unschedule(v_job);
    end if;
  end loop;
end$$;

-- 6.1 mid-loan-reading : tous les jours à 9h05 UTC
select cron.schedule(
  'anarbib-notify-mid-loan-reading-daily',
  '5 9 * * *',
  $cron$ select public.fn_cron_notify_mid_loan_reading(); $cron$
);

-- 6.2 network-weekly-report : lundis à 8h15 UTC
select cron.schedule(
  'anarbib-notify-network-weekly-report-weekly',
  '15 8 * * 1',
  $cron$ select public.fn_cron_notify_network_weekly_report(); $cron$
);

-- 6.3 weekly-report (par lib) : lundis à 8h00 UTC
select cron.schedule(
  'anarbib-notify-weekly-report-weekly',
  '0 8 * * 1',
  $cron$ select * from public.fn_cron_notify_weekly_report_per_library(); $cron$
);


-- =============================================================================
-- 7. VÉRIFICATION POST-MIGRATION
-- =============================================================================
-- On affiche les 3 jobs reconfigurés pour confirmation visuelle.
-- (NOTICE seulement, pas de modification.)
-- =============================================================================

do $$
declare
  v_job record;
begin
  raise notice '─── Cron jobs notify-* après migration ───';
  for v_job in
    select jobname, schedule, active, command
    from cron.job
    where jobname in (
      'anarbib-notify-mid-loan-reading-daily',
      'anarbib-notify-network-weekly-report-weekly',
      'anarbib-notify-weekly-report-weekly'
    )
    order by jobname
  loop
    raise notice '  ✓ % — schedule="%s" — active=% — command=%',
      v_job.jobname, v_job.schedule, v_job.active, btrim(v_job.command);
  end loop;
end$$;

commit;


-- =============================================================================
-- ROLLBACK (à exécuter manuellement si besoin)
-- =============================================================================
-- begin;
--
-- -- 1. Désinscription des 3 jobs migrés
-- select cron.unschedule('anarbib-notify-mid-loan-reading-daily');
-- select cron.unschedule('anarbib-notify-network-weekly-report-weekly');
-- select cron.unschedule('anarbib-notify-weekly-report-weekly');
--
-- -- 2. Réinscription des anciens jobs (état pré-migration)
-- select cron.schedule(
--   'anarbib-notify-mid-loan-reading-daily',
--   '5 9 * * *',
--   $cron$
--     select net.http_post(
--       url:='https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/notify-mid-loan-reading',
--       headers:=jsonb_build_object(
--         'Content-Type', 'application/json',
--         'Authorization', 'Bearer ' || (
--           select decrypted_secret
--           from vault.decrypted_secrets
--           where name = 'anarbib_staging_anon_key'
--         )
--       ),
--       body:=jsonb_build_object(
--         'source', 'pg_cron',
--         'job', 'anarbib-notify-mid-loan-reading-daily',
--         'scheduled_at', now()
--       ),
--       timeout_milliseconds:=10000
--     );
--   $cron$
-- );
-- -- (idem pour network-weekly et weekly avec leur ancien command original)
--
-- -- 3. Drop des fonctions wrapper (optionnel, elles ne nuisent pas si laissées)
-- drop function if exists public.fn_cron_notify_mid_loan_reading();
-- drop function if exists public.fn_cron_notify_network_weekly_report();
-- drop function if exists public.fn_cron_notify_weekly_report_per_library();
-- drop function if exists public.fn_internal_previous_iso_week(date);
-- drop function if exists public.fn_internal_get_vault_secret(text);
--
-- commit;
-- =============================================================================
