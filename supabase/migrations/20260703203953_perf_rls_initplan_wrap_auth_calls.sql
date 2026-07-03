-- Perf : advisor 0003 auth_rls_initplan. Emballe les appels auth.*() des policies
-- RLS de `public` en (select auth.*()) pour qu'ils soient évalués UNE fois par requête
-- au lieu d'une fois par ligne. Transformation sémantiquement neutre (auth.uid() est
-- STABLE dans une requête). Idempotent (dé-emballe puis ré-emballe) et atomique.
-- Faithful round-trip : pg_get_expr est appelé sous le MÊME search_path que l'ALTER,
-- donc les parties non-auth de l'expression se re-parsent à l'identique.
-- Vérifié post-application : 0 appel non-emballé restant, 0 double-emballage.
do $$
declare
  r record;
  v_newqual text;
  v_newcheck text;
  v_sql text;
  n int := 0;
begin
  perform set_config('search_path', 'public, api, extensions, ingest', true);

  for r in
    select pol.polname as polname,
           pol.polrelid::regclass::text as tbl,
           pg_get_expr(pol.polqual, pol.polrelid) as qual,
           pg_get_expr(pol.polwithcheck, pol.polrelid) as with_check
    from pg_policy pol
    join pg_class c on c.oid = pol.polrelid
    join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public'
  loop
    v_newqual := regexp_replace(regexp_replace(coalesce(r.qual,''),
        '\(\s*SELECT\s+(auth\.(uid|role|jwt|email)\(\))\s+AS\s+\w+\s*\)', '\1', 'gi'),
        'auth\.(uid|role|jwt|email)\(\)', '(select auth.\1())', 'g');
    v_newcheck := regexp_replace(regexp_replace(coalesce(r.with_check,''),
        '\(\s*SELECT\s+(auth\.(uid|role|jwt|email)\(\))\s+AS\s+\w+\s*\)', '\1', 'gi'),
        'auth\.(uid|role|jwt|email)\(\)', '(select auth.\1())', 'g');

    if (r.qual is not null and v_newqual is distinct from r.qual)
       or (r.with_check is not null and v_newcheck is distinct from r.with_check) then
      v_sql := format('ALTER POLICY %I ON %s', r.polname, r.tbl);
      if r.qual is not null then
        v_sql := v_sql || format(' USING (%s)', v_newqual);
      end if;
      if r.with_check is not null then
        v_sql := v_sql || format(' WITH CHECK (%s)', v_newcheck);
      end if;
      execute v_sql;
      n := n + 1;
    end if;
  end loop;

  raise notice 'initplan wrap: % policies modifiées', n;
end $$;
