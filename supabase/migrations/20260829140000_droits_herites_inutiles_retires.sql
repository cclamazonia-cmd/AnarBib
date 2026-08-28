-- =============================================================================
-- Les droits que l'API n'utilise jamais ne restent pas accordes
-- =============================================================================
-- Date     : 2026-08-29
-- Chantier : hygiene des GRANT herites (suite de l'examen de portee)
--
-- CE QU'ON RETIRE. `anon` et `authenticated` portaient TRUNCATE sur 130 tables
-- de `public`, TRIGGER sur 131, REFERENCES sur 131 — heritage des GRANT en bloc
-- de la mise en place. Aucun des trois n'est expose par PostgREST : il faudrait
-- une connexion SQL directe avec le mot de passe du role pour s'en servir, et
-- une personne connectee a l'application n'a qu'un JWT.
--
-- CE N'EST DONC PAS UN TROU, ET LE DIRE COMPTE. La classe reellement dangereuse
-- — une table ecrivable par anon/authenticated SANS RLS — est VIDE (mesure :
-- 0 sur 187, et 0 table de `public` sans RLS). Ce paquet ne bouche rien : il
-- retire une classe de bruit, pour que le prochain signalement veuille dire
-- quelque chose. C'est le meme raisonnement que l'epinglage de search_path du
-- 29/08 : ramener un compteur a zero pour rendre le prochain 1 significatif.
--
-- Aucune fonction du depot n'utilise TRUNCATE (verifie : 0 sur les schemas
-- public, ingest, api, private), et INSERT/UPDATE/DELETE ne sont PAS touches —
-- la, c'est la RLS qui garde, et elle est partout.
--
-- POURQUOI UN REVOKE SEUL NE TIENDRAIT PAS. `ALTER DEFAULT PRIVILEGES` de
-- `public` accorde `arwdDxtm` — tout, TRUNCATE compris — sur CHAQUE table neuve.
-- Nettoyer sans traiter la source, c'est se donner rendez-vous au prochain
-- CREATE TABLE. On change donc aussi le defaut pose par `postgres`, sous lequel
-- tournent les migrations. Le defaut pose par `supabase_admin` n'est pas
-- modifiable ici : c'est la suite CI qui rattrape ce cas-la.
--
-- Ce qui garde vraiment la reparation n'est pas ce fichier mais
-- tests/sql/grants_herites_tests.sql : une liste qui se verifie, pas une
-- intention. Meme role que deploy/bg2-known-tables.txt pour la sauvegarde.
-- =============================================================================

begin;

revoke truncate, references, trigger on all tables in schema public from anon, authenticated;

alter default privileges in schema public
  revoke truncate, references, trigger on tables from anon, authenticated;

-- -----------------------------------------------------------------------------
-- Verification
-- -----------------------------------------------------------------------------
do $verif$
declare
  v_reste int;
  v_ecrivables_sans_rls int;
  v_lecture_perdue int;
begin
  select count(*) into v_reste
    from information_schema.role_table_grants
   where table_schema = 'public'
     and grantee in ('anon', 'authenticated')
     and privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER');
  if v_reste <> 0 then
    raise exception 'il reste % droit(s) TRUNCATE/REFERENCES/TRIGGER sur public', v_reste;
  end if;

  -- Ce qui compte VRAIMENT doit rester vide.
  select count(*) into v_ecrivables_sans_rls
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
     and exists (select 1 from information_schema.role_table_grants g
                  where g.table_schema = 'public' and g.table_name = c.relname
                    and g.grantee in ('anon', 'authenticated')
                    and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE'));
  if v_ecrivables_sans_rls <> 0 then
    raise exception '% table(s) ecrivable(s) par anon/authenticated sans RLS', v_ecrivables_sans_rls;
  end if;

  -- Et surtout : on n'a RIEN casse. Le catalogue public doit rester lisible par
  -- anon, et les tables metier ecrivables par authenticated. Un REVOKE trop
  -- large se verrait ici.
  select count(*) into v_lecture_perdue
    from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'authenticated'
     and table_name in ('book_drafts', 'author_drafts', 'exemplar_drafts', 'catalog_batches')
     and privilege_type in ('SELECT', 'INSERT', 'UPDATE', 'DELETE');
  if v_lecture_perdue < 16 then
    raise exception 'les droits metier des tables de catalogage ont ete rognes (% sur 16)', v_lecture_perdue;
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select count(*) from information_schema.role_table_grants
--    where table_schema='public' and grantee in ('anon','authenticated')
--      and privilege_type in ('TRUNCATE','REFERENCES','TRIGGER');
--   -- attendu : 0, et ca doit le rester (suite CI grants_herites_tests.sql)
--
--   select defaclobjtype, defaclacl::text from pg_default_acl d
--     join pg_namespace n on n.oid = d.defaclnamespace where n.nspname='public';
--   -- l'entree 'r' posee par postgres ne doit plus porter D (TRUNCATE),
--   -- x (REFERENCES) ni t (TRIGGER) pour anon/authenticated.
-- =============================================================================
