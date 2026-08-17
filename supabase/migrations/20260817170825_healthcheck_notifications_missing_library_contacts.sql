-- fn_healthcheck_notifications() : signaler les bibliotheques ACTIVES sans
-- courriel de contact.
--
-- Trouve le 2026-08-17 en eprouvant notify-document-permission-request en
-- dry_run : la copie « requester_copy » sortait avec to = null, parce que
-- Biblioteca Terra Livre et CIRA Marseille n'ont aucun contact_email dans
-- library_contact_profiles. safeSendEmail gere proprement (skipped /
-- invalid_email, pas de plantage) — donc la notification disparait EN SILENCE,
-- exactement le motif que cette sonde existe pour rendre visible.
--
-- ATTENTION — cette version rend le constat BLOQUANT (il compte dans `ok`).
-- C'etait une erreur de conception, corrigee immediatement apres par
-- 20260817170941 : la sonde ne peut pas savoir si une bibliotheque a vocation a
-- rester dans le reseau, et `ok` resterait faux indefiniment sur un point que
-- personne ne compte corriger. Migration conservee telle qu'appliquee pour que
-- le depot reflete l'historique reel de la base.
--
-- Seul notify-document-permission-request route via library_contact_profiles ;
-- les autres notifieurs resolvent leurs destinataires via les adhesions du
-- personnel. La consequence est donc nommee explicitement dans la sortie.
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
  v_contacts  jsonb := '[]'::jsonb;
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

  -- 5. Bibliotheques ACTIVES sans courriel de contact.
  begin
    select coalesce(jsonb_agg(jsonb_build_object(
             'bibliotheque', coalesce(l.short_name, l.name),
             'consequence', 'ne recevra jamais les notifications routees via library_contact_profiles (notify-document-permission-request)')
           order by coalesce(l.short_name, l.name)), '[]'::jsonb)
      into v_contacts
    from public.libraries l
    left join public.library_contact_profiles c on c.library_id = l.id
    where l.is_active and coalesce(c.contact_email, '') = '';
  exception
    when undefined_table or undefined_column then v_contacts := '[]'::jsonb;
  end;

  return jsonb_build_object(
    'ok', (jsonb_array_length(v_vifs) = 0
           and jsonb_array_length(v_types) = 0
           and jsonb_array_length(v_files) = 0
           and jsonb_array_length(v_contacts) = 0),
    'verifie_le', now(),
    'secrets_absents_bloquants', v_vifs,
    'secrets_absents_dormants', v_dormants,
    'event_types_refuses_par_la_check', v_types,
    'files_non_traitees', v_files,
    'bibliotheques_actives_sans_contact', v_contacts,
    'crons_inactifs_pour_information', v_crons
  );
end $fn$;

comment on function public.fn_healthcheck_notifications() is
  'Sonde de sante des notifications. `ok` ne reflete que les pannes VIVES : secrets Vault manquants sur un flux actif, event_type refuses par la CHECK, files bloquees, bibliotheques actives sans courriel de contact. Un secret manquant dont les seuls lecteurs sont appeles par un cron inactif est classe dormant (informatif). Lecture seule ; ne renvoie jamais la valeur d''un secret.';

revoke all on function public.fn_healthcheck_notifications() from public, anon, authenticated;
grant execute on function public.fn_healthcheck_notifications() to service_role;
