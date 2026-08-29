-- =============================================================================
-- Une vue n'est pas une cible d'ecriture
-- =============================================================================
-- Date     : 2026-08-30
-- Chantier : hygiene des GRANT herites (fin du releve du 29-30/08)
--
-- CE QU'ON RETIRE. Cinq vues de `public` portaient encore INSERT, UPDATE et
-- DELETE pour `anon` et `authenticated` : v_library_deposits, v_audio_tracklist,
-- v_catalog_books_editable, v_library_notification_context,
-- v_membership_overview_panel. Toutes les cinq sont lues, jamais ecrites — le
-- depot ne contient que des `.select()` sur elles, et aucune requete d'ecriture
-- n'apparait dans les journaux.
--
-- CE QUE CE PAQUET N'EST PAS, ET IL FAUT LE DIRE. Ce n'est pas la fermeture d'un
-- trou. Les cinq vues sont en `security_invoker = true` : les droits ET la RLS de
-- la table de base s'appliquent a qui ecrit a travers elles. Verifie sur le cas
-- le plus sensible — `v_library_deposits`, une projection de `loan_deposits`,
-- donc de l'argent : la table accorde deja les memes droits, ses quatre policies
-- sont toutes `TO authenticated` et conditionnees a
-- `user_can_engage_library(library_id)`, et `anon` n'a AUCUNE policy, donc rien.
-- La vue n'ajoutait aucun pouvoir. On range, on ne colmate pas.
--
-- Ce qui serait vraiment dangereux, et qu'il faut continuer a surveiller, c'est
-- une vue SANS security_invoker : la, les droits du proprietaire s'appliqueraient
-- et la RLS de la table de base serait contournee. C'est pour ce jour-la que
-- l'invariant « une vue n'est jamais une cible d'ecriture » vaut d'etre tenu.
--
-- POURQUOI ON NE PEUT PAS REGLER LA SOURCE, CETTE FOIS. Le paquet 20260829140000
-- avait corrige le defaut du schema pour TRUNCATE/REFERENCES/TRIGGER. Impossible
-- de faire pareil ici : `ALTER DEFAULT PRIVILEGES ... ON TABLES` ne distingue pas
-- les tables des vues, et INSERT/UPDATE/DELETE sur les TABLES sont exactement ce
-- qui fait marcher l'API. Retirer le defaut casserait tout.
--
-- L'invariant ne peut donc etre tenu que par un CONTROLE, pas par un reglage :
-- tests/sql/grants_herites_tests.sql T6. C'est le seul endroit ou il vivra.
-- =============================================================================

begin;

do $revoke$
declare r record; v_n int := 0;
begin
  for r in select viewname from pg_views where schemaname = 'public' order by viewname
  loop
    execute format('revoke insert, update, delete on public.%I from anon, authenticated', r.viewname);
    v_n := v_n + 1;
  end loop;
  raise notice 'droits d''ecriture retires sur % vue(s) de public', v_n;
end
$revoke$;

-- -----------------------------------------------------------------------------
-- Verification
-- -----------------------------------------------------------------------------
do $verif$
declare v_n int; v_txt text; v_lectures int;
begin
  select count(*), coalesce(string_agg(distinct g.table_name, ', ' order by g.table_name), '')
    into v_n, v_txt
    from information_schema.role_table_grants g
   where g.table_schema = 'public'
     and g.grantee in ('anon', 'authenticated')
     and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE')
     and exists (select 1 from pg_views v
                  where v.schemaname = 'public' and v.viewname = g.table_name);
  if v_n <> 0 then
    raise exception '% droit(s) d''ecriture subsistent sur des vues : %', v_n, left(v_txt, 200);
  end if;

  -- Test de NON-ACTION : les LECTURES ne doivent pas avoir bouge. Un revoke trop
  -- large aurait aveugle le catalogue public et les ecrans du panneau.
  select count(*) into v_lectures
    from information_schema.role_table_grants g
   where g.table_schema = 'public' and g.privilege_type = 'SELECT'
     and g.grantee in ('anon', 'authenticated')
     and exists (select 1 from pg_views v
                  where v.schemaname = 'public' and v.viewname = g.table_name);
  if v_lectures < 20 then
    raise exception 'les lectures des vues ont ete rognees (% restantes)', v_lectures;
  end if;

  -- Et les cinq vues du releve doivent rester lisibles, chacune.
  if exists (
    select 1 from unnest(array['v_library_deposits', 'v_audio_tracklist',
                               'v_catalog_books_editable', 'v_library_notification_context',
                               'v_membership_overview_panel']) as v(nom)
     where not exists (select 1 from information_schema.role_table_grants g
                        where g.table_schema = 'public' and g.table_name = v.nom
                          and g.grantee = 'authenticated' and g.privilege_type = 'SELECT')
  ) then
    raise exception 'une des cinq vues du releve n''est plus lisible par authenticated';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select count(*) from information_schema.role_table_grants g
--    where g.table_schema='public' and g.grantee in ('anon','authenticated')
--      and g.privilege_type in ('INSERT','UPDATE','DELETE')
--      and exists (select 1 from pg_views v
--                   where v.schemaname='public' and v.viewname=g.table_name);
--   -- attendu : 0, et ca doit le rester (grants_herites_tests.sql T6)
--
-- Le vrai danger reste ailleurs — une vue sans security_invoker :
--   select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
--    where n.nspname='public' and c.relkind='v'
--      and coalesce((select option_value from pg_options_to_table(c.reloptions)
--                     where option_name='security_invoker'), 'false') <> 'true';
-- =============================================================================
