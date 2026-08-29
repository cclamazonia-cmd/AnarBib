-- =============================================================================
-- Un lot publie s'archive, il ne se supprime pas — et le dire
-- =============================================================================
-- Date     : 2026-08-30
-- Chantier : catalogage — onglet Lots
--
-- LE SYMPTOME. Le lot « Mutirão de catalogação — BLMF — 2026-08-15 » affichait
-- 9 brouillons dans l'onglet Lots, refusait d'etre supprime pour cette raison,
-- et la file editoriale montrait 0 brouillon pour ce meme lot. Les deux
-- disaient vrai : les 9 sont a l'etat `published`.
--
--   * la file ne montre que le travail EN COURS (`draft`, `ready`) ;
--   * le compte du lot prenait tout ce qui n'est pas `cancelled`, donc y
--     ajoutait les fiches deja versees au catalogue.
--
-- LA REGLE N'ETAIT PAS FAUSSE, SON RECIT L'ETAIT. Bloquer sur les brouillons
-- publies est un choix defendable, et c'est celui qui est retenu (decision du
-- 30/08) : un lot publie garde la memoire d'une seance de catalogage collectif —
-- « ces 9 fiches viennent du mutirão du 15 aout ». Cette trace vaut plus que la
-- place qu'il occupe dans une liste, et « Archiver » existe deja pour le sortir
-- de la vue. Ce qui manquait, c'est de le DIRE : le message parlait de
-- « supprimer les brouillons d'abord », ce qui n'a aucun sens pour des fiches
-- publiees, et un seul nombre melangeait trois choses.
--
-- CE QUE FAIT CE PAQUET.
--   1. la vue distingue EN COURS / PUBLIES / CORBEILLE, au lieu d'un total
--      ambigu. L'ecran peut alors nommer la bonne raison ;
--   2. la regle devient REELLE. Elle ne vivait que dans le JavaScript de
--      deleteBatch — un garde-fou d'ecran, pas une garantie : l'API laissait
--      passer. Un trigger BEFORE DELETE la tient desormais cote base, avec deux
--      motifs distincts selon ce qui reste.
--
-- Le vocabulaire suit celui de la file editoriale, pas l'inverse : c'est elle
-- que les gens lisent tous les jours.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Trois comptes, parce qu'il y a trois choses
-- -----------------------------------------------------------------------------
-- DROP puis CREATE : le jeu de colonnes change, CREATE OR REPLACE ne sait pas le
-- faire. La vue date de ce matin (20260830090000), personne d'autre n'en depend.
drop view if exists public.v_catalog_batch_draft_counts;

create view public.v_catalog_batch_draft_counts
with (security_invoker = true) as
  select b.id as batch_id,
         (select count(*) from public.book_drafts     d where d.batch_id = b.id and d.status in ('draft','ready'))
       + (select count(*) from public.author_drafts   d where d.batch_id = b.id and d.status in ('draft','ready'))
       + (select count(*) from public.exemplar_drafts d where d.batch_id = b.id and d.status in ('draft','ready'))
           as en_cours,
         (select count(*) from public.book_drafts     d where d.batch_id = b.id and d.status = 'published')
       + (select count(*) from public.author_drafts   d where d.batch_id = b.id and d.status = 'published')
       + (select count(*) from public.exemplar_drafts d where d.batch_id = b.id and d.status = 'published')
           as publies,
         (select count(*) from public.book_drafts     d where d.batch_id = b.id and d.status = 'cancelled')
       + (select count(*) from public.author_drafts   d where d.batch_id = b.id and d.status = 'cancelled')
       + (select count(*) from public.exemplar_drafts d where d.batch_id = b.id and d.status = 'cancelled')
           as corbeille
    from public.catalog_batches b;

-- Le defaut du schema redonne anon + ecriture a chaque vue neuve (cf. paquets
-- 20260830090000 et 20260830110000) : on retire, on n'ajoute pas.
revoke all on public.v_catalog_batch_draft_counts from anon, authenticated;
grant select on public.v_catalog_batch_draft_counts to authenticated;

comment on view public.v_catalog_batch_draft_counts is
  'Ce que retient chaque lot, en TROIS comptes distincts : en_cours (draft/ready, '
  'le travail vivant — vocabulaire de la file editoriale), publies (fiches deja '
  'versees au catalogue, qui gardent la memoire de la seance) et corbeille '
  '(cancelled, purgee avec le lot). Un seul total melangeait les trois et faisait '
  'refuser une suppression pour une raison incomprehensible. Une ligne par lot, '
  'lots vides compris. security_invoker=true. Revue le 30/08/2026.';

-- -----------------------------------------------------------------------------
-- 2. La regle, cote base et plus seulement cote ecran
-- -----------------------------------------------------------------------------
create or replace function public.fn_guard_catalog_batch_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $fn$
declare
  v_en_cours bigint;
  v_publies  bigint;
begin
  select en_cours, publies into v_en_cours, v_publies
    from public.v_catalog_batch_draft_counts where batch_id = old.id;

  -- Du travail vivant : il faut le traiter ou le jeter, pas l'effacer par la
  -- bande en supprimant son lot.
  if coalesce(v_en_cours, 0) > 0 then
    raise exception 'Le lot % retient encore % brouillon(s) en cours.', old.id, v_en_cours
      using hint = 'error.batch.has_drafts_in_progress';
  end if;

  -- Des fiches publiees : le lot est la memoire d'une seance de catalogage.
  -- On archive, on ne supprime pas.
  if coalesce(v_publies, 0) > 0 then
    raise exception 'Le lot % porte % fiche(s) publiee(s) : il s''archive, il ne se supprime pas.', old.id, v_publies
      using hint = 'error.batch.published_archive_instead';
  end if;

  return old;
end;
$fn$;

revoke execute on function public.fn_guard_catalog_batch_delete() from public, anon;

comment on function public.fn_guard_catalog_batch_delete() is
  'Trigger BEFORE DELETE de catalog_batches : refuse si le lot retient du travail '
  'EN COURS, ou s''il porte des fiches PUBLIEES (dans ce cas il s''archive). La '
  'corbeille du lot, elle, ne bloque pas — elle part avec lui. Cette regle ne '
  'vivait que dans le JavaScript jusqu''au 30/08/2026 : l''API laissait passer.';

drop trigger if exists trg_catalog_batches_guard_delete on public.catalog_batches;
create trigger trg_catalog_batches_guard_delete
  before delete on public.catalog_batches
  for each row execute function public.fn_guard_catalog_batch_delete();

-- -----------------------------------------------------------------------------
-- Verification — on emprunte les trois chemins
-- -----------------------------------------------------------------------------
do $verif$
declare
  v_lot bigint; v_en_cours bigint; v_publies bigint; v_corbeille bigint; v_msg text;
begin
  insert into public.catalog_batches (name, status)
  values ('__verif_lot_publie__', 'open') returning id into v_lot;

  insert into public.book_drafts (titulo, batch_id, status) values ('a', v_lot, 'draft');
  insert into public.book_drafts (titulo, batch_id, status) values ('b', v_lot, 'published');
  insert into public.book_drafts (titulo, batch_id, status) values ('c', v_lot, 'cancelled');

  select en_cours, publies, corbeille into v_en_cours, v_publies, v_corbeille
    from public.v_catalog_batch_draft_counts where batch_id = v_lot;
  if (v_en_cours, v_publies, v_corbeille) is distinct from (1::bigint, 1::bigint, 1::bigint) then
    raise exception 'comptes attendus 1/1/1, trouves %/%/%', v_en_cours, v_publies, v_corbeille;
  end if;

  -- (a) du travail en cours -> refus, motif « en cours »
  begin
    delete from public.catalog_batches where id = v_lot;
    raise exception 'la suppression aurait du etre refusee (travail en cours)';
  exception when others then
    get stacked diagnostics v_msg = pg_exception_hint;
    if v_msg is distinct from 'error.batch.has_drafts_in_progress' then
      raise exception 'mauvais motif de refus (en cours) : %', coalesce(v_msg, 'aucun');
    end if;
  end;

  -- (b) plus que du publie -> refus, motif « archiver »
  delete from public.book_drafts where batch_id = v_lot and status = 'draft';
  begin
    delete from public.catalog_batches where id = v_lot;
    raise exception 'la suppression aurait du etre refusee (fiches publiees)';
  exception when others then
    get stacked diagnostics v_msg = pg_exception_hint;
    if v_msg is distinct from 'error.batch.published_archive_instead' then
      raise exception 'mauvais motif de refus (publie) : %', coalesce(v_msg, 'aucun');
    end if;
  end;

  -- (c) plus que la corbeille -> la suppression passe
  delete from public.book_drafts where batch_id = v_lot and status = 'published';
  delete from public.book_drafts where batch_id = v_lot and status = 'cancelled';
  delete from public.catalog_batches where id = v_lot;
  if exists (select 1 from public.catalog_batches where id = v_lot) then
    raise exception 'la suppression aurait du passer une fois le lot vide';
  end if;

  delete from public.catalog_audit_log where details->>'batch_id' = v_lot::text;

  if exists (select 1 from information_schema.role_table_grants
              where table_schema = 'public' and table_name = 'v_catalog_batch_draft_counts'
                and grantee not in ('postgres', 'service_role')
                and (grantee in ('anon', 'PUBLIC') or privilege_type in ('INSERT','UPDATE','DELETE'))) then
    raise exception 'la vue a repris des droits de trop';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select b.id, b.name, b.status, c.en_cours, c.publies, c.corbeille
--     from public.catalog_batches b
--     join public.v_catalog_batch_draft_counts c on c.batch_id = b.id
--    order by b.id;
--   -- le lot Mutirão (57) doit sortir 0 en cours / 9 publies / 0 corbeille :
--   -- c'est un lot a ARCHIVER, et l'ecran doit le dire ainsi.
-- =============================================================================
