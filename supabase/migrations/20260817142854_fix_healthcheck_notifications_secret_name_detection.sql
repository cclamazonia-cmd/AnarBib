-- Correctif de fn_healthcheck_notifications() : detection des noms de secrets.
--
-- La premiere version (20260817142747) extrayait tout littéral suivant
-- « name = '…' », ce qui capturait des faux positifs venant de requetes sur le
-- catalogue systeme — y compris depuis SON PROPRE corps : nspname = 'public' et
-- attname = 'status' etaient rapportes comme « secrets absents du Vault ».
--
-- Deux garde-fous ajoutes :
--   1. la fonction s'exclut elle-meme du balayage (elle contient, par nature,
--      le motif d'extraction en clair) ;
--   2. un nom n'est retenu que s'il RESSEMBLE a un secret du projet :
--      soit ALL_CAPS (WEBHOOK_SECRET_…), soit terminant par secret/salt/token/
--      key/url (gazette_cron_secret, rede_digest_webhook_secret, pseudonym_salt).
--      'public' et 'status' echouent aux deux tests.
--
-- Apres correctif, la sonde ne remonte plus qu'une seule anomalie reelle en
-- prod : WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST, lu par
-- fn_cron_notify_cross_library_digest dont le cron est INACTIF (mine dormante).
create or replace function public.fn_healthcheck_notifications()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'vault', 'extensions', 'pg_temp'
as $fn$
declare
  v_secrets   jsonb := '[]'::jsonb;
  v_types     jsonb := '[]'::jsonb;
  v_files     jsonb := '[]'::jsonb;
  v_crons     jsonb := '[]'::jsonb;
  r record; f record;
  v_allowed text[]; v_declared text[]; v_missing text[];
  v_n bigint;
begin
  -- 1. Secrets lus dans le Vault par une fonction, mais absents du Vault.
  begin
    with refs as (
      select p.proname, m.arr[1] as nom
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral regexp_matches(
        pg_get_functiondef(p.oid),
        '(?:fn_internal_get_vault_secret\(|name\s*=\s*)''([A-Za-z0-9_]+)''', 'g') as m(arr)
      where n.nspname = 'public'
        and p.proname <> 'fn_healthcheck_notifications'   -- garde-fou 1
        and pg_get_functiondef(p.oid) ilike '%vault%'
    ),
    plausibles as (
      select * from refs
      where nom ~ '^[A-Z][A-Z0-9_]{3,}$'                  -- garde-fou 2
         or nom ~* '(secret|salt|token|key|url)$'
    )
    select coalesce(jsonb_agg(jsonb_build_object(
             'secret', x.nom, 'lu_par', x.lecteurs) order by x.nom), '[]'::jsonb)
      into v_secrets
    from (
      select r2.nom, string_agg(distinct r2.proname, ', ') as lecteurs
      from plausibles r2
      where not exists (select 1 from vault.secrets v where v.name = r2.nom)
      group by r2.nom
    ) x;
  exception
    when undefined_table or undefined_function or invalid_schema_name then
      v_secrets := jsonb_build_array(jsonb_build_object('erreur', 'Vault indisponible'));
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

  -- 4. Crons de notification inactifs (informatif : une mine dormante y sommeille
  --    souvent, cf. WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST).
  begin
    select coalesce(jsonb_agg(jsonb_build_object('job', jobname, 'schedule', schedule)
                              order by jobname), '[]'::jsonb)
      into v_crons
    from cron.job
    where not active and (jobname ilike '%notify%' or jobname ilike '%digest%' or jobname ilike '%report%');
  exception
    when undefined_table or invalid_schema_name then v_crons := '[]'::jsonb;
  end;

  return jsonb_build_object(
    'ok', (jsonb_array_length(v_secrets) = 0
           and jsonb_array_length(v_types) = 0
           and jsonb_array_length(v_files) = 0),
    'verifie_le', now(),
    'secrets_absents_du_vault', v_secrets,
    'event_types_refuses_par_la_check', v_types,
    'files_non_traitees', v_files,
    'crons_inactifs_pour_information', v_crons
  );
end $fn$;

comment on function public.fn_healthcheck_notifications() is
  'Sonde de sante des notifications : secrets Vault manquants, event_type refuses par la CHECK, files bloquees, crons inactifs. Lecture seule ; ne renvoie jamais la valeur d''un secret.';

revoke all on function public.fn_healthcheck_notifications() from public, anon, authenticated;
grant execute on function public.fn_healthcheck_notifications() to service_role;
