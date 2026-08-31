-- B5 : neuf policies écrites depuis le 03/07 réévaluent auth.*() par ligne.
--
-- La migration 20260703203953 avait emballé les appels auth.*() de TOUTES les
-- policies de `public` en (select auth.*()) — évalué une fois par requête au
-- lieu d'une fois par ligne (advisor auth_rls_initplan). Mais une migration ne
-- traite que le présent : les policies écrites APRÈS (notes de lecture,
-- signalements de doublons — relevé du 31/08/2026 : book_reading_notes ×4,
-- book_reading_note_reports ×2, catalog_duplicate_reports,
-- authority_duplicate_reports, author_not_duplicate) ont copié l'exemple NU du
-- _TEMPLATE.sql, corrigé en même temps que ce fichier. Le rejeu ci-dessous est
-- le MÊME bloc idempotent : il dé-emballe puis ré-emballe, ne touche que ce
-- qui diffère, et reste sémantiquement neutre (auth.uid() est STABLE).
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

  raise notice 'initplan wrap (rejeu B5) : % policies modifiées', n;
end $$;
