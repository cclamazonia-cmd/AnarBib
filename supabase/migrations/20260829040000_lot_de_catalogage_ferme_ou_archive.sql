-- =============================================================================
-- Un lot de catalogage peut etre ferme ou archive
-- =============================================================================
-- Date     : 2026-08-29
-- Chantier : catalogage — onglet « Lots »
--
-- SYMPTOME. Dans /catalogacao#batchesPanel, « Fermer le lot » repond « Une
-- erreur technique est survenue (23514) ». 23514 = check_violation. Et comme
-- « Supprimer » n'existe que dans les sections « Lots clos » et « Lots
-- archives », un lot qui ne peut pas etre ferme ne peut jamais etre supprime :
-- le bouton qui echoue est le seul chemin vers la suppression.
--
-- CAUSE. Deux vocabulaires ont derive l'un de l'autre.
--   * la table :  open | published | cancelled          (CHECK d'origine)
--   * l'ecran  :  open -> published | closed -> archived
-- « closed » et « archived » n'ont jamais existe cote base. Aucun lot n'est
-- donc jamais sorti de « open » autrement qu'en etant publie : au 28/08/2026
-- les 5 lots de production sont tous « open », et la table n'a jamais porte
-- une seule ligne dans un autre etat. Le chemin n'etait pas casse, il n'avait
-- jamais ete emprunte.
--
-- POURQUOI ELARGIR PLUTOT QUE RENOMMER COTE ECRAN. Les trois etats ne sont pas
-- des synonymes : « fermer » ne prend plus de brouillons mais les garde
-- accessibles (c'est ce que promet la confirmation affichee), « archiver »
-- retire de la vue courante, « publier » verse au catalogue. Les replier sur le
-- seul « cancelled » existant perdrait la distinction — et « archived »
-- n'aurait de toute facon toujours pas d'equivalent.
--
-- « cancelled » reste dans la liste bien qu'inutilise (0 ligne) : le retirer ne
-- gagne rien et casserait tout appelant vivant hors de ce depot.
--
-- Rien d'autre ne depend du vocabulaire exact : les fonctions serveur qui
-- lisent le statut testent « = 'open' » ou « <> 'open' »
-- (create_drafts_from_import_run, publish_catalog_batch), donc un lot ferme ou
-- archive se comporte deja comme un lot non ouvert — il refuse les nouveaux
-- rascunhos et la publication.
-- =============================================================================

begin;

alter table public.catalog_batches
  drop constraint if exists catalog_batches_status_check;

alter table public.catalog_batches
  add constraint catalog_batches_status_check
  check (status = any (array['open', 'published', 'closed', 'cancelled', 'archived']));

comment on constraint catalog_batches_status_check on public.catalog_batches is
  'Etats d''un lot : open -> published (verse au catalogue) ou closed (ne prend '
  'plus de brouillons), puis archived (retire de la vue). « cancelled » est '
  'historique et inutilise. Elargi le 29/08/2026 (paquet lots fermables).';

-- -----------------------------------------------------------------------------
-- Verification — on emprunte le chemin, on ne le decrit pas
-- -----------------------------------------------------------------------------
-- La ligne d'essai est creee et supprimee dans la meme transaction : la
-- verification tient donc aussi en CI, ou le schema est reconstruit sans seed.
do $verif$
declare
  v_id bigint;
begin
  insert into public.catalog_batches (name, notes, status)
  values ('__verif_statuts_lot__', 'ligne temporaire de migration', 'open')
  returning id into v_id;

  update public.catalog_batches set status = 'closed'    where id = v_id;
  update public.catalog_batches set status = 'archived'  where id = v_id;
  update public.catalog_batches set status = 'published' where id = v_id;
  update public.catalog_batches set status = 'cancelled' where id = v_id;

  delete from public.catalog_batches where id = v_id;

  -- ... et un etat hors vocabulaire doit toujours etre refuse.
  begin
    insert into public.catalog_batches (name, status)
    values ('__verif_statuts_lot_invalide__', 'nawak');
    raise exception 'la contrainte accepte un statut hors vocabulaire';
  exception
    when check_violation then null;
  end;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select pg_get_constraintdef(oid) from pg_constraint
--    where conrelid = 'public.catalog_batches'::regclass
--      and conname  = 'catalog_batches_status_check';
--   -- attendu : CHECK (status = ANY (ARRAY['open', 'published', 'closed',
--   --                                      'cancelled', 'archived']))
--
--   select status, count(*) from public.catalog_batches group by 1;
--   -- aucune ligne '__verif_statuts_lot__' ne doit subsister
-- =============================================================================
