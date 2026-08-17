-- fn_healthcheck_notifications() : distinguer une panne VIVE d'un flux DEBRANCHE,
-- et ne plus planter sur les agregats.
--
-- MOTIF 1 — la sonde criait dans le vide. Elle rapportait
-- WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST comme secret manquant, donc
-- ok = false en permanence. Or son unique lecteur,
-- fn_cron_notify_cross_library_digest, n'est appele que par un job pg_cron
-- INACTIF, et sa cible functions/v1/notify-cross-library-digest N'EXISTE PAS
-- (404 en prod, absente du depot et de config.toml). Ce n'est pas une panne :
-- c'est un vestige d'un chantier jamais termine.
--
-- Creer le secret aurait fait passer la sonde au vert AU-DESSUS D'UN FLUX MORT
-- — un mensonge pire que le bruit. On classe donc le manque au lieu de le taire :
--   * secrets_absents_bloquants -> compte dans `ok` (panne vive) ;
--   * secrets_absents_dormants  -> informatif, ne compte pas dans `ok`.
-- Un manque est DORMANT si tous ses lecteurs ne sont appeles que par des jobs
-- pg_cron inactifs. Des qu'on reactive le job, il redevient bloquant tout seul
-- (verifie : dormant_aujourdhui = true, dormant_si_on_reactive = false).
-- Si cron.job est indisponible (CI), on reste conservateur : tout est bloquant.
--
-- MOTIF 2 — pg_get_functiondef() leve « is an aggregate function » sur un
-- agregat, ce qui pouvait faire planter la sonde avant tout resultat. Meme
-- garde-fou que celui ajoute a
-- tests/sql/notifications_event_types_coherence_tests.sql : prokind = 'f'.
create or replace function public.fn_healthcheck_notifications()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'vault', 'extensions', 'pg_temp'
as $fn$
declare
  v_vifs      jsonb := '[]'::jsonb;
  v_dormants  jsonb := '[]'::jsonb;
  v_types     jsonb := '[]'::jsonb;
  v_files     jsonb := '[]'::jsonb;
  v_crons     jsonb := '[]'::jsonb;
  v_cron_dispo boolean := true;
  r record; f record;
  v_allowed text[]; v_declared text[]; v_missing text[];
  v_n bigint;
begin
  begin
    perform 1 from cron.job limit 1;
  exception
    when undefined_table or invalid_schema_name or insufficient_privilege then
      v_cron_dispo := false;
  end;

  -- 1. Secrets lus dans le Vault par une fonction, mais absents du Vault,
  --    classes selon qu'ils bloquent un flux vivant ou dorment.
  begin
    with refs as (
      select p.proname, m.arr[1] as nom
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral regexp_matches(
        pg_get_functiondef(p.oid),
        '(?:fn_internal_get_vault_secret\(|name\s*=\s*)''([A-Za-z0-9_]+)''', 'g') as m(arr)
      where n.nspname = 'public'
        and p.prokind = 'f'
        and p.proname <> 'fn_healthcheck_notifications'
        and pg_get_functiondef(p.oid) ilike '%vault%'
    ),
    plausibles as (
      select * from refs
      where nom ~ '^[A-Z][A-Z0-9_]{3,}$'
         or nom ~* '(secret|salt|token|key|url)$'
    ),
    manquants as (
      select p.nom, p.proname
      from plausibles p
      where not exists (select 1 from vault.secrets v where v.name = p.nom)
    ),
    classe as (
      select m.nom, m.proname,
             (v_cron_dispo
              and exists (select 1 from cron.job j where j.command like '%' || m.proname || '%')
              and not exists (select 1 from cron.job j
                              where j.command like '%' || m.proname || '%' and j.active)
             ) as dormant
      from manquants m
    ),
    agg as (
      select nom,
             string_agg(distinct proname, ', ') as lecteurs,
             bool_and(dormant) as tout_dormant
      from classe group by nom
    )
    select
      coalesce(jsonb_agg(jsonb_build_object('secret', nom, 'lu_par', lecteurs)
                         order by nom) filter (where not tout_dormant), '[]'::jsonb),
      coalesce(jsonb_agg(jsonb_build_object('secret', nom, 'lu_par', lecteurs,
                                            'raison', 'lecteur(s) appeles uniquement par un cron INACTIF')
                         order by nom) filter (where tout_dormant), '[]'::jsonb)
      into v_vifs, v_dormants
    from agg;
  exception
    when undefined_table or undefined_function or invalid_schema_name then
      v_vifs := jsonb_build_array(jsonb_build_object('erreur', 'Vault indisponible'));
  end;

  -- 2. event_type accepte par une fonction mais refuse par la CHECK de la table.
  for r in
    select t.relname as tbl,
           replace(t.relname, '_notification_events', '') as prefixe,
           pg_get_constraintdef(c.oid) as checkdef
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public' and c.contype = 'c'
      and t.relname like '%\_notification\_events'
      and pg_get_constraintdef(c.oid) like '%event_type%'
  loop
    select array_agg(distinct m.arr[1]) into v_allowed
    from regexp_matches(r.checkdef, '''([^'']+)''::text', 'g') as m(arr);
    continue when coalesce(array_length(v_allowed, 1), 0) = 0;

    for f in
      select p.oid, p.proname from pg_proc p
      join pg_namespace np on np.oid = p.pronamespace
      where np.nspname = 'public'
        and p.prokind = 'f'
        and p.proname <> 'fn_healthcheck_notifications'
        and pg_get_functiondef(p.oid) like '%' || r.tbl || '%'
    loop
      select array_agg(distinct m.arr[1]) into v_declared
      from regexp_matches(pg_get_functiondef(f.oid),
                          '''(' || r.prefixe || '_[a-z_]+)''', 'g') as m(arr)
      where m.arr[1] not like '%notification\_events' and m.arr[1] <> r.tbl;
      continue when coalesce(array_length(v_declared, 1), 0) = 0;

      select array_agg(d) into v_missing
      from unnest(v_declared) as d where d <> all (v_allowed);

      if coalesce(array_length(v_missing, 1), 0) > 0 then
        v_types := v_types || jsonb_build_object(
          'table', r.tbl, 'fonction', f.proname, 'types_refuses_par_la_check', v_missing);
      end if;
    end loop;
  end loop;

  -- 3. Files d'attente : lignes ni envoyees ni ignorees.
  for r in
    select c.relname as tbl
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relname like '%outbox%'
      and exists (select 1 from pg_attribute a
                  where a.attrelid = c.oid and a.attname = 'status' and a.attnum > 0)
    order by c.relname
  loop
    execute format(
      'select count(*) from public.%I where coalesce(status, '''') not in (''sent'', ''skipped'')',
      r.tbl) into v_n;
    if v_n > 0 then
      v_files := v_files || jsonb_build_object('file', r.tbl, 'lignes_non_traitees', v_n);
    end if;
  end loop;

  -- 4. Crons de notification inactifs (informatif).
  if v_cron_dispo then
    select coalesce(jsonb_agg(jsonb_build_object('job', jobname, 'schedule', schedule)
                              order by jobname), '[]'::jsonb)
      into v_crons
    from cron.job
    where not active and (jobname ilike '%notify%' or jobname ilike '%digest%' or jobname ilike '%report%');
  end if;

  return jsonb_build_object(
    'ok', (jsonb_array_length(v_vifs) = 0
           and jsonb_array_length(v_types) = 0
           and jsonb_array_length(v_files) = 0),
    'verifie_le', now(),
    'secrets_absents_bloquants', v_vifs,
    'secrets_absents_dormants', v_dormants,
    'event_types_refuses_par_la_check', v_types,
    'files_non_traitees', v_files,
    'crons_inactifs_pour_information', v_crons
  );
end $fn$;

comment on function public.fn_healthcheck_notifications() is
  'Sonde de sante des notifications. `ok` ne reflete que les pannes VIVES : un secret Vault manquant dont les seuls lecteurs sont appeles par un cron inactif est classe dormant (informatif). Lecture seule ; ne renvoie jamais la valeur d''un secret.';

revoke all on function public.fn_healthcheck_notifications() from public, anon, authenticated;
grant execute on function public.fn_healthcheck_notifications() to service_role;
