-- =============================================================================
-- La suppression definitive passe par la coordination
-- =============================================================================
-- Date     : 2026-08-29
-- Chantier : catalogage — levier 3, cran demande apres l'examen de portee
--
-- CE QUI EST DECIDE. Une seule porte ouvrait tout le catalogage :
-- `can_access_catalogacao` (= adhesion active `librarian` ou `coordenador` dans
-- N'IMPORTE QUELLE bibliotheque, ou admin reseau). Derriere elle : creer,
-- editer, publier, jeter a la corbeille, ET supprimer definitivement.
--
-- L'ecran d'IMPORT, lui, reserve deja a `coordenador` (+ admin reseau) la
-- suppression d'un run, l'enregistrement d'une source, l'ingestion d'un
-- candidat. La bizarrerie n'etait pas qu'il soit strict : c'est que le geste
-- LE PLUS destructeur du catalogage etait le MOINS garde des deux ecrans.
-- Ce paquet aligne le catalogage sur l'import. Rien d'autre ne bouge : creer,
-- editer, publier et jeter a la corbeille restent ouverts au meme monde.
--
-- COMMENT, ET POURQUOI COMME CA. Une policy RESTRICTIVE ajoutee, plutot que la
-- policy ALL existante decoupee en quatre. Une restrictive s'AJOUTE en ET aux
-- permissives : on ne touche a aucun chemin existant, donc on ne risque pas
-- d'en perdre un en le recopiant. Et elle ne porte que sur DELETE.
--
-- La condition reutilise `public.fn_is_catalog_coordinator()`, qui existe deja
-- et sert au panneau de gouvernance des periodiques : adhesion active
-- `coordenador`/`administrador` n'importe ou, ou admin reseau actif. On ne
-- fabrique pas un second vocabulaire de la meme idee.
--
-- `(select ...)` autour de l'appel : la condition devient un InitPlan evalue UNE
-- fois par instruction au lieu d'une fois par ligne — le motif de
-- 20260704000600. Un vidage de corbeille traverse des centaines de lignes.
--
-- CE QUE CA NE FAIT PAS. `service_role` porte BYPASSRLS : les traitements
-- serveur et les migrations ne sont pas concernes. Et cote ecran, une policy qui
-- refuse un DELETE ne leve PAS d'erreur — PostgREST supprime zero ligne et
-- repond 204. Sans garde cote client, une bibliothecaire verrait « supprimes »
-- sans que rien ne bouge : les boutons sont donc masques dans le meme paquet
-- (QueuePanel, BatchesPanel), et le compte annonce vient deja de la base.
-- =============================================================================

begin;

drop policy if exists book_drafts_suppression_definitive_coordination on public.book_drafts;
create policy book_drafts_suppression_definitive_coordination
  on public.book_drafts as restrictive for delete to authenticated
  using ((select public.fn_is_catalog_coordinator()));

drop policy if exists author_drafts_suppression_definitive_coordination on public.author_drafts;
create policy author_drafts_suppression_definitive_coordination
  on public.author_drafts as restrictive for delete to authenticated
  using ((select public.fn_is_catalog_coordinator()));

drop policy if exists exemplar_drafts_suppression_definitive_coordination on public.exemplar_drafts;
create policy exemplar_drafts_suppression_definitive_coordination
  on public.exemplar_drafts as restrictive for delete to authenticated
  using ((select public.fn_is_catalog_coordinator()));

-- Supprimer un lot emporte sa corbeille : meme geste, meme porte.
drop policy if exists catalog_batches_suppression_definitive_coordination on public.catalog_batches;
create policy catalog_batches_suppression_definitive_coordination
  on public.catalog_batches as restrictive for delete to authenticated
  using ((select public.fn_is_catalog_coordinator()));

-- -----------------------------------------------------------------------------
-- Verification structurelle
-- -----------------------------------------------------------------------------
-- Le comportement (une bibliothecaire ne supprime plus, une coordinatrice si)
-- est tenu par tests/sql/suppression_definitive_coordination_tests.sql.
do $verif$
declare v_n int;
begin
  select count(*) into v_n from pg_policies
   where schemaname = 'public'
     and policyname like '%_suppression_definitive_coordination'
     and cmd = 'DELETE' and permissive = 'RESTRICTIVE';
  if v_n <> 4 then
    raise exception 'attendu 4 policies restrictives de suppression, trouve %', v_n;
  end if;

  -- Les policies permissives d'origine doivent etre INTACTES : la restrictive
  -- s'ajoute, elle ne remplace pas.
  if not exists (select 1 from pg_policies
                  where schemaname='public' and tablename='book_drafts'
                    and policyname='book_drafts_catalogacao_librarian_all') then
    raise exception 'la policy permissive d''origine de book_drafts a disparu';
  end if;

  -- Le helper doit rester ferme a anon/PUBLIC : il decide desormais d'un geste
  -- destructeur.
  if exists (select 1 from information_schema.routine_privileges
              where routine_schema='public' and routine_name='fn_is_catalog_coordinator'
                and grantee in ('anon','PUBLIC')) then
    raise exception 'fn_is_catalog_coordinator est ouverte a anon ou PUBLIC';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select tablename, policyname, permissive, cmd
--     from pg_policies
--    where schemaname='public' and policyname like '%suppression_definitive%'
--    order by tablename;
--   -- attendu : 4 lignes, RESTRICTIVE / DELETE
--
-- Rollback cible si la federation revient sur la decision :
--   begin;
--     drop policy book_drafts_suppression_definitive_coordination on public.book_drafts;
--     drop policy author_drafts_suppression_definitive_coordination on public.author_drafts;
--     drop policy exemplar_drafts_suppression_definitive_coordination on public.exemplar_drafts;
--     drop policy catalog_batches_suppression_definitive_coordination on public.catalog_batches;
--   commit;
--   (et remettre les boutons cote ecran : isCoord dans QueuePanel/BatchesPanel)
-- =============================================================================
