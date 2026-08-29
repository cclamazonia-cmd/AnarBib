-- =============================================================================
-- Un lot dit ce qu'il contient
-- =============================================================================
-- Date     : 2026-08-30
-- Chantier : catalogage — onglet Lots et file editoriale
--
-- CE QU'ON REPARE. Le 29/08, un lot « qu'on venait de supprimer » etait toujours
-- la. Les journaux HTTP ont tranche : aucun DELETE n'avait ete envoye, seulement
-- un PATCH — c'est-a-dire « Fermer le lot ». Ni la base ni la RLS n'y etaient
-- pour rien : c'est l'ecran qui invitait a la confusion, de trois facons.
--
--   1. un lot OUVERT n'offre pas « Supprimer », seulement « Publier » et
--      « Fermer » ; supprimer demande fermer -> descendre dans « Lots clos » ->
--      supprimer. Fermer RESSEMBLE donc au geste de rangement ;
--   2. le menu « Lot » de la file liste TOUS les lots, y compris un lot clos et
--      VIDE, qui ne peut plus rien filtrer ;
--   3. le nombre de brouillons d'un lot n'est visible NULLE PART : on n'apprend
--      qu'un lot est vide — donc supprimable — qu'en cliquant et en lisant
--      l'alerte de refus.
--
-- Les trois se soignent avec la meme chose : savoir, sans cliquer, ce qu'un lot
-- contient. D'ou cette vue, et rien de plus cote base.
--
-- POURQUOI UNE VUE ET PAS UN COMPTE COTE ECRAN. L'ecran aurait pu compter
-- lui-meme, en trois requetes par lot. Outre le nombre d'allers-retours, ce
-- serait une quatrieme copie de la question « ce lot retient-il du travail ? » —
-- la meme que pose deja `deleteBatch` avant de supprimer. Une seule definition,
-- lue par tout le monde.
--
-- security_invoker=true : les comptes sont ceux que l'appelant a le droit de
-- voir, pas ceux d'un observateur privilegie.
--
-- Le vocabulaire suit celui du 29/08 : est ACTIF ce qui n'est pas a la corbeille
-- (`status <> 'cancelled'`), et c'est l'actif seul qui empeche de supprimer un
-- lot — la corbeille du lot part avec lui.
-- =============================================================================

begin;

create or replace view public.v_catalog_batch_draft_counts
with (security_invoker = true) as
  select b.id as batch_id,
         (select count(*) from public.book_drafts     d where d.batch_id = b.id and d.status <> 'cancelled')
       + (select count(*) from public.author_drafts   d where d.batch_id = b.id and d.status <> 'cancelled')
       + (select count(*) from public.exemplar_drafts d where d.batch_id = b.id and d.status <> 'cancelled')
           as actifs,
         (select count(*) from public.book_drafts     d where d.batch_id = b.id and d.status =  'cancelled')
       + (select count(*) from public.author_drafts   d where d.batch_id = b.id and d.status =  'cancelled')
       + (select count(*) from public.exemplar_drafts d where d.batch_id = b.id and d.status =  'cancelled')
           as corbeille
    from public.catalog_batches b;

-- ATTENTION — le defaut du schema accorde a `anon` ET `authenticated` SELECT,
-- INSERT, UPDATE et DELETE sur toute relation neuve de `public`, VUES COMPRISES.
-- Un `grant select ... to authenticated` ne fait donc qu'ajouter du redondant :
-- ce qu'il faut, c'est RETIRER le reste. Trouve par le bloc de verification de
-- cette migration meme, qui a rougi sur sa propre vue.
--
-- Et ce n'est pas theorique : une vue simple sur UNE table est AUTO-MODIFIABLE
-- (`is_updatable = YES`), donc un DELETE passe a travers elle jusqu'a la table.
-- Ici la RLS de book_drafts rattrape (security_invoker + policies du 29/08), mais
-- une surface d'ecriture qu'on n'a pas voulue n'a pas a exister.
revoke all on public.v_catalog_batch_draft_counts from anon, authenticated;
grant select on public.v_catalog_batch_draft_counts to authenticated;

-- Meme defaut, meme correctif, sur la vue posee la veille par le paquet
-- 20260829160000 : elle porte INSERT/UPDATE/DELETE pour anon et authenticated,
-- et elle est auto-modifiable. On repare ce qu'on a soi-meme laisse passer.
revoke all on public.v_book_draft_destination from anon, authenticated;
grant select on public.v_book_draft_destination to authenticated;

comment on view public.v_catalog_batch_draft_counts is
  'Ce que retient chaque lot : brouillons ACTIFS (qui empechent de le supprimer) '
  'et brouillons a la CORBEILLE (qui partent avec lui). Une ligne par lot, y '
  'compris les lots vides — c''est precisement le cas qu''il faut pouvoir '
  'montrer. Lue par l''onglet Lots et par le filtre de la file editoriale. '
  'security_invoker=true. Creee le 30/08/2026.';

-- -----------------------------------------------------------------------------
-- Verification
-- -----------------------------------------------------------------------------
do $verif$
declare
  v_lot bigint; v_actifs bigint; v_corbeille bigint; v_lignes int;
begin
  insert into public.catalog_batches (name, status)
  values ('__verif_comptes_lot__', 'open') returning id into v_lot;

  -- Un lot VIDE doit apparaitre, a zero. Un lot absent de la vue serait invisible
  -- a l'ecran, donc jamais montre comme supprimable : c'est le cas qui compte.
  select actifs, corbeille into v_actifs, v_corbeille
    from public.v_catalog_batch_draft_counts where batch_id = v_lot;
  if not found or v_actifs <> 0 or v_corbeille <> 0 then
    raise exception 'un lot vide doit apparaitre a 0/0 (trouve %/%)', v_actifs, v_corbeille;
  end if;

  insert into public.book_drafts (titulo, batch_id, status) values ('a', v_lot, 'draft');
  insert into public.book_drafts (titulo, batch_id, status) values ('b', v_lot, 'ready');
  insert into public.book_drafts (titulo, batch_id, status) values ('c', v_lot, 'cancelled');
  insert into public.author_drafts (preferred_name, batch_id, status) values ('d', v_lot, 'draft');

  select actifs, corbeille into v_actifs, v_corbeille
    from public.v_catalog_batch_draft_counts where batch_id = v_lot;
  if v_actifs <> 3 or v_corbeille <> 1 then
    raise exception 'comptes attendus 3 actifs / 1 corbeille, trouves %/%', v_actifs, v_corbeille;
  end if;

  -- Une ligne par lot, ni plus ni moins.
  select count(*) into v_lignes from public.v_catalog_batch_draft_counts;
  if v_lignes <> (select count(*) from public.catalog_batches) then
    raise exception 'la vue ne rend pas une ligne par lot';
  end if;

  delete from public.book_drafts where batch_id = v_lot;
  delete from public.author_drafts where batch_id = v_lot;
  delete from public.catalog_batches where id = v_lot;
  delete from public.catalog_audit_log where details->>'batch_id' = v_lot::text;

  if exists (select 1 from public.catalog_batches where name = '__verif_comptes_lot__') then
    raise exception 'residu de verification';
  end if;

  -- Les deux vues de ce chantier : lecture pour authenticated, rien pour anon,
  -- et surtout aucune ecriture — une vue n'est jamais une cible d'ecriture ici.
  if exists (select 1 from information_schema.role_table_grants
              where table_schema = 'public'
                and table_name in ('v_catalog_batch_draft_counts', 'v_book_draft_destination')
                and (grantee in ('anon', 'PUBLIC')
                     or privilege_type in ('INSERT', 'UPDATE', 'DELETE'))
                and grantee <> 'postgres' and grantee <> 'service_role') then
    raise exception 'une vue du chantier garde des droits de trop (anon, ou ecriture)';
  end if;
  if not exists (select 1 from information_schema.role_table_grants
                  where table_schema = 'public' and table_name = 'v_catalog_batch_draft_counts'
                    and grantee = 'authenticated' and privilege_type = 'SELECT') then
    raise exception 'la vue n''est plus lisible par authenticated';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select b.id, b.name, b.status, c.actifs, c.corbeille
--     from public.catalog_batches b
--     join public.v_catalog_batch_draft_counts c on c.batch_id = b.id
--    order by b.id;
--   -- un lot a 0/0 est supprimable d'un clic depuis l'onglet Lots (coordination)
--
-- A REGARDER, NON TRAITE ICI : quatre AUTRES vues de `public` portent encore des
-- droits d'ecriture herites pour anon/authenticated. Trois sont inertes (non
-- auto-modifiables) ; `v_library_deposits`, elle, est auto-modifiable. Elles ne
-- sont pas de ce chantier : on les signale plutot que d'y toucher a l'aveugle.
--
--   select v.table_name, v.is_updatable,
--          string_agg(distinct g.grantee, ', ') as ecriture_accordee_a
--     from information_schema.views v
--     join information_schema.role_table_grants g
--       on g.table_schema = v.table_schema and g.table_name = v.table_name
--    where v.table_schema = 'public'
--      and g.grantee in ('anon', 'authenticated')
--      and g.privilege_type in ('INSERT', 'UPDATE', 'DELETE')
--    group by 1, 2 order by 1;
-- =============================================================================
