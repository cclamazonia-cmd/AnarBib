-- B9 — le schéma `backup_2026_05_07` disparaît (REGISTRE §BG2, décision BG2-9).
--
-- Six tables copiées le 7 mai 2026 avant la bascule v2 de la circulation :
-- `emprestimos_v2`, `emprestimo_itens_v2`, `reservas_v2`, `reserva_linhas_v2`,
-- `reserva_item_workflow_v2`, `loan_midpoint_message_log`. Relevé du
-- 04/09/2026 en production : zéro ligne et zéro insertion depuis leur création
-- (`pg_stat_user_tables`), sans clé primaire, sans RLS ; aucune fonction
-- (`pg_proc.prosrc`) ni vue (`pg_views.definition`) ne cite le schéma.
--
-- Les homonymes de `public` (`public.emprestimos_v2`, `public.reservas_v2`, …)
-- sont les tables vivantes : elles ne bougent pas, et `deploy/bg2-known-tables.txt`,
-- qui ne classe que `public`, n'a rien à changer.
--
-- Garde : la purge refuse de s'exécuter si l'une des tables porte encore une ligne.
-- Sur une base où le schéma n'existe pas (rejeu en CI), la migration ne fait rien.
--
-- RELEVÉ DÉMENTI (04/09/2026 au soir, run backend 9254851) : cinq des six
-- tables portent 10 lignes chacune — réservations et prêts d'essai du 29/03
-- au 02/04/2026, absents de `public` aujourd'hui. On ne détruit pas ce qu'on
-- n'a pas relu : si une table porte encore une ligne, la purge est DIFFÉRÉE
-- (notice), le schéma reste, la migration passe. Sinon, purge.


do $$
declare
  r record;
  n bigint;
  occupees text := '';
begin
  if to_regnamespace('backup_2026_05_07') is null then
    raise notice 'backup_2026_05_07 : schéma absent, rien à purger';
    return;
  end if;

  for r in
    select c.relname
      from pg_class c
      join pg_namespace ns on ns.oid = c.relnamespace
     where ns.nspname = 'backup_2026_05_07' and c.relkind = 'r'
  loop
    execute format('select count(*) from backup_2026_05_07.%I', r.relname) into n;
    if n > 0 then occupees := occupees || format(' %s=%s', r.relname, n); end if;
  end loop;

  if occupees <> '' then
    raise notice 'backup_2026_05_07 : purge différée, tables non vides :%', occupees;
    return;
  end if;

  execute 'drop schema backup_2026_05_07 cascade';
  raise notice 'backup_2026_05_07 : schéma supprimé';
end
$$;
