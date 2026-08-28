-- =============================================================================
-- Une suppression de brouillon laisse une trace, et cette trace se rejoue
-- =============================================================================
-- Date     : 2026-08-29
-- Chantier : catalogage — portee des gestes destructeurs (levier 2)
--
-- CE QU'ON REPARE. Jeter un brouillon a la corbeille est reversible et, par les
-- RPC `discard_*`, journalise. Le supprimer DEFINITIVEMENT n'etait ni l'un ni
-- l'autre : aucun trigger d'audit sur les trois tables de brouillons, la ligne
-- disparaissait sans laisser de quoi savoir qui, quand, ni quoi. Le 28/08/2026,
-- un vidage de corbeille a efface 259 brouillons de cinq bibliotheques : il n'en
-- reste aujourd'hui aucune trace exploitable.
--
-- LE CHOIX. On ne retire a personne le droit de supprimer — c'est le levier 3,
-- qui appartient a la federation et pas au code. On rend l'accident REPARABLE :
-- la suppression ecrit son propre instantane, et une RPC le rejoue. Une culture
-- de responsabilite plutot que de permission.
--
-- POURQUOI PAS DE TABLE NEUVE. `public.catalog_audit_log` existe depuis le
-- 04/06/2026 et porte deja `action / entity_type / entity_id / label / details`.
-- Son vocabulaire `entity_type` est tenu par une CHECK (`book`,`author`,
-- `exemplar`) — on le REUTILISE tel quel plutot que d'en inventer un quatrieme,
-- et `action` n'a pas de CHECK, donc `delete` et `restore` s'y ajoutent sans
-- elargir quoi que ce soit. Une table de plus aurait aussi impose un classement
-- dans deploy/bg2-known-tables.txt (filet anti-fuite de la sauvegarde) ; ici,
-- rien a classer.
--
-- CE QUE L'INSTANTANE CONTIENT. La ligne entiere (`to_jsonb(old)`) et, pour un
-- brouillon de livre, ses ENFANTS en CASCADE qui disparaitraient avec elle :
-- contributeurs, matieres, contexte de catalogage, ressources numeriques. Sans
-- eux le rejeu rendrait une coquille. Le trigger est BEFORE DELETE, seul moment
-- ou les enfants existent encore. Deux enfants sont volontairement HORS
-- instantane : `book_draft_import_events` (journal d'un journal) et
-- `ingest.partner_catalog_row_to_draft` (il appartient au run d'import, qui peut
-- avoir disparu — cf. paquet 20260829060000).
--
-- LE JOURNAL SE DURCIT AU PASSAGE. `authenticated` y avait INSERT, UPDATE,
-- DELETE et TRUNCATE : la personne qui supprime pouvait effacer la trace de sa
-- suppression, ce qui vide l'exercice de son sens. Elle n'y garde que SELECT.
-- (Portee reelle a relativiser : PostgREST n'expose pas TRUNCATE, il fallait un
-- acces SQL direct. C'est de la defense en profondeur, pas une porte ouverte.
-- 131 des 187 tables de `public` portent le meme TRUNCATE herite des GRANT en
-- bloc — les 130 autres ne sont PAS traitees ici, c'est un chantier a part.)
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Le trigger d'audit
-- -----------------------------------------------------------------------------
create or replace function public.fn_audit_draft_deletion()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $fn$
declare
  v_entity  text;
  v_label   text;
  v_library uuid;
  v_details jsonb;
begin
  v_details := jsonb_build_object('snapshot', to_jsonb(old));

  if tg_table_name = 'book_drafts' then
    v_entity  := 'book';
    v_label   := old.titulo;
    v_library := old.owner_library_id;
    -- Les enfants en CASCADE : sans eux, le rejeu rendrait une coquille.
    v_details := v_details || jsonb_build_object('children', jsonb_build_object(
      'book_draft_contributors', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_contributors c where c.draft_id = old.id), '[]'::jsonb),
      'book_draft_subjects', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_subjects c where c.book_draft_id = old.id), '[]'::jsonb),
      'book_draft_catalog_context', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_catalog_context c where c.book_draft_id = old.id), '[]'::jsonb),
      'book_draft_digital_resources', coalesce(
        (select jsonb_agg(to_jsonb(c)) from public.book_draft_digital_resources c where c.book_draft_id = old.id), '[]'::jsonb)
    ));
  elsif tg_table_name = 'author_drafts' then
    v_entity := 'author';
    v_label  := old.preferred_name;
  else
    v_entity  := 'exemplar';
    v_label   := coalesce(old.tombo, old.target_bib_ref);
    v_library := old.target_library_id;
  end if;

  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (auth.uid(), 'delete', v_entity, old.id, v_library, v_label,
          v_details || jsonb_build_object('batch_id', old.batch_id, 'source_table', tg_table_name));

  return old;
end;
$fn$;

revoke execute on function public.fn_audit_draft_deletion() from public, anon;

comment on function public.fn_audit_draft_deletion() is
  'Trigger BEFORE DELETE des trois tables de brouillons : ecrit dans '
  'catalog_audit_log une ligne action=''delete'' portant l''instantane complet '
  'de la ligne (et ses enfants CASCADE pour un livre), de quoi la rejouer. '
  'Cree le 29/08/2026 (levier 2 de la portee des gestes destructeurs).';

drop trigger if exists trg_book_drafts_audit_delete on public.book_drafts;
create trigger trg_book_drafts_audit_delete
  before delete on public.book_drafts
  for each row execute function public.fn_audit_draft_deletion();

drop trigger if exists trg_author_drafts_audit_delete on public.author_drafts;
create trigger trg_author_drafts_audit_delete
  before delete on public.author_drafts
  for each row execute function public.fn_audit_draft_deletion();

drop trigger if exists trg_exemplar_drafts_audit_delete on public.exemplar_drafts;
create trigger trg_exemplar_drafts_audit_delete
  before delete on public.exemplar_drafts
  for each row execute function public.fn_audit_draft_deletion();

-- -----------------------------------------------------------------------------
-- 2. Le rejeu
-- -----------------------------------------------------------------------------
create or replace function public.fn_restore_deleted_draft(p_audit_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $fn$
declare
  v_log      public.catalog_audit_log%rowtype;
  v_snap     jsonb;
  v_tbl      text;
  v_id       bigint;
  v_exists   boolean;
  v_child    record;
  v_fk       text;
  v_enfants  int := 0;
  v_n        int;
begin
  -- Meme porte que la publication : le staff de catalogage. Restaurer n'est pas
  -- un geste destructeur, il n'a pas a etre plus reserve que catalguer.
  if not exists (select 1 from public.user_library_memberships m
                  where m.user_id = auth.uid() and m.status = 'active'
                    and m.role = any (array['librarian'::text, 'coordenador'::text]))
     and not public.fn_caller_is_network_admin() then
    raise exception 'Acesso restrito ao staff de catalogacao.'
      using hint = 'error.catalog.staff_only';
  end if;

  select * into v_log from public.catalog_audit_log where id = p_audit_id;
  if not found or v_log.action <> 'delete' then
    raise exception 'entree de journal % introuvable ou pas une suppression', p_audit_id
      using hint = 'error.catalog.restore_not_found';
  end if;

  v_snap := v_log.details -> 'snapshot';
  v_tbl  := v_log.details ->> 'source_table';
  if v_snap is null or v_tbl is null then
    raise exception 'instantane absent pour le journal % (purge de retention ?)', p_audit_id
      using hint = 'error.catalog.restore_no_snapshot';
  end if;
  -- La table vient du journal : on la confronte a la liste, on ne la concatene
  -- pas telle quelle dans du SQL.
  if v_tbl not in ('book_drafts', 'author_drafts', 'exemplar_drafts') then
    raise exception 'table inattendue dans le journal % : %', p_audit_id, v_tbl;
  end if;

  v_id := (v_snap ->> 'id')::bigint;
  execute format('select exists (select 1 from public.%I where id = $1)', v_tbl)
    into v_exists using v_id;
  if v_exists then
    raise exception 'le brouillon % existe deja : rien a rejouer', v_id
      using hint = 'error.catalog.restore_already';
  end if;

  execute format(
    'insert into public.%I select * from jsonb_populate_record(null::public.%I, $1)', v_tbl, v_tbl)
    using v_snap;

  if v_tbl = 'book_drafts' then
    for v_child in
      select key as tbl, value as rows
        from jsonb_each(coalesce(v_log.details -> 'children', '{}'::jsonb))
    loop
      if v_child.tbl not in ('book_draft_contributors', 'book_draft_subjects',
                             'book_draft_catalog_context', 'book_draft_digital_resources') then
        continue;
      end if;
      -- L'INSERT du parent a reveille ses propres triggers : celui qui seme les
      -- contributeurs depuis `autor`, celui qui derive le contexte de catalogage
      -- depuis marc_json. Ils viennent de fabriquer des enfants QUI NE SONT PAS
      -- ceux qu'on rejoue — d'ou un conflit de cle primaire sur
      -- book_draft_catalog_context (trouve par les tests, pas par la lecture).
      -- Regle retenue : l'instantane fait foi, il decrit l'etat au moment de la
      -- suppression. On efface ce que les triggers ont pose, puis on rejoue.
      v_fk := case v_child.tbl when 'book_draft_contributors' then 'draft_id'
                               else 'book_draft_id' end;
      execute format('delete from public.%I where %I = $1', v_child.tbl, v_fk) using v_id;
      execute format(
        'insert into public.%I select * from jsonb_populate_recordset(null::public.%I, $1)',
        v_child.tbl, v_child.tbl) using v_child.rows;
      get diagnostics v_n = row_count;
      v_enfants := v_enfants + v_n;
    end loop;
  end if;

  -- Le journal est en ajout seul : on n'annote pas la ligne d'origine, on ecrit
  -- une seconde ligne. Une trace qui se reecrit n'est plus une trace.
  insert into public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  values (auth.uid(), 'restore', v_log.entity_type, v_id, v_log.library_id, v_log.label,
          jsonb_build_object('from_audit_id', p_audit_id, 'source_table', v_tbl,
                             'children_restored', v_enfants));

  return jsonb_build_object('ok', true, 'entity_type', v_log.entity_type,
                            'draft_id', v_id, 'source_table', v_tbl,
                            'children_restored', v_enfants);
end;
$fn$;

revoke execute on function public.fn_restore_deleted_draft(bigint) from public, anon;
grant execute on function public.fn_restore_deleted_draft(bigint) to authenticated;

comment on function public.fn_restore_deleted_draft(bigint) is
  'Rejoue une suppression definitive de brouillon a partir de l''instantane du '
  'journal (catalog_audit_log, action=''delete''), enfants compris. Reserve au '
  'staff de catalogage. Cree le 29/08/2026 (levier 2).';

-- -----------------------------------------------------------------------------
-- 3. Le journal se durcit
-- -----------------------------------------------------------------------------
revoke insert, update, delete, truncate, references, trigger
  on public.catalog_audit_log from authenticated;
revoke all on public.catalog_audit_log from anon;
grant select on public.catalog_audit_log to authenticated;
grant all on public.catalog_audit_log to service_role;

-- -----------------------------------------------------------------------------
-- 4. Retention : la trace reste, l'instantane s'efface
-- -----------------------------------------------------------------------------
-- Garder une copie complete de donnees supprimees indefiniment serait le
-- contraire du geste demande. Au-dela de 90 jours on ne garde que la LIGNE de
-- journal (qui, quand, quoi) et on retire la charge utile.
create or replace function public.fn_purge_audit_draft_snapshots()
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $fn$
declare v_n int;
begin
  update public.catalog_audit_log
     set details = (details - 'snapshot' - 'children') || jsonb_build_object('snapshot_purged', true)
   where action = 'delete'
     and occurred_at < now() - interval '90 days'
     and details ? 'snapshot';
  get diagnostics v_n = row_count;
  return v_n;
end;
$fn$;

revoke execute on function public.fn_purge_audit_draft_snapshots() from public, anon;

do $cron$
begin
  perform cron.schedule('anarbib-catalog-audit-snapshot-purge', '17 4 * * *',
                        $sql$select public.fn_purge_audit_draft_snapshots();$sql$);
exception when others then
  raise notice 'pg_cron absent (rejeu de schema hors production) : purge non planifiee — %', sqlerrm;
end
$cron$;

-- -----------------------------------------------------------------------------
-- Verification — on emprunte le chemin
-- -----------------------------------------------------------------------------
-- Aller-retour complet sur author_drafts (la plus simple des trois : pas
-- d'enfants en cascade, donc le test ne depend d'aucune donnee seedee). Le cas
-- du livre AVEC ses enfants est tenu par tests/sql/catalogage_suppression_tracee_tests.sql.
do $verif$
declare
  v_id bigint; v_audit bigint; v_res jsonb; v_nom text; v_n int;
begin
  insert into public.author_drafts (preferred_name, status)
  values ('__verif_audit_suppression__', 'cancelled') returning id into v_id;

  delete from public.author_drafts where id = v_id;

  select id into v_audit from public.catalog_audit_log
   where action = 'delete' and entity_type = 'author' and entity_id = v_id;
  if v_audit is null then
    raise exception 'la suppression n''a pas ete journalisee';
  end if;

  if (select details -> 'snapshot' ->> 'preferred_name' from public.catalog_audit_log where id = v_audit)
     is distinct from '__verif_audit_suppression__' then
    raise exception 'l''instantane ne porte pas la ligne supprimee';
  end if;

  -- Le rejeu : impossible ici (la RPC exige un JWT de staff), on rejoue donc la
  -- meme insertion depuis l'instantane, ce qui verifie que l'instantane SUFFIT.
  insert into public.author_drafts
  select * from jsonb_populate_record(null::public.author_drafts,
    (select details -> 'snapshot' from public.catalog_audit_log where id = v_audit));

  select preferred_name into v_nom from public.author_drafts where id = v_id;
  if v_nom is distinct from '__verif_audit_suppression__' then
    raise exception 'le rejeu de l''instantane ne rend pas la ligne';
  end if;

  -- Menage : la seconde suppression rejournalise, on retire les deux traces.
  delete from public.author_drafts where id = v_id;
  delete from public.catalog_audit_log where entity_type = 'author' and entity_id = v_id;

  select count(*) into v_n from public.author_drafts where preferred_name = '__verif_audit_suppression__';
  if v_n <> 0 then
    raise exception 'residu de verification : % ligne(s)', v_n;
  end if;

  -- ALTER DEFAULT PRIVILEGES de `public` accorde EXECUTE a anon sur TOUTE
  -- fonction neuve du schema : revoquer PUBLIC ne suffit pas, il faut nommer
  -- anon. Sans ce controle, fn_purge_audit_draft_snapshots — SECURITY DEFINER —
  -- serait appelable par un visiteur non connecte. Trouve par les tests.
  if exists (
    select 1 from information_schema.routine_privileges
     where routine_schema = 'public'
       and routine_name in ('fn_audit_draft_deletion', 'fn_restore_deleted_draft',
                            'fn_purge_audit_draft_snapshots')
       and grantee in ('anon', 'PUBLIC')
  ) then
    raise exception 'une des fonctions du paquet reste executable par anon ou PUBLIC';
  end if;

  -- Le journal ne doit plus etre modifiable par authenticated.
  if exists (select 1 from information_schema.role_table_grants
              where table_schema = 'public' and table_name = 'catalog_audit_log'
                and grantee = 'authenticated'
                and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')) then
    raise exception 'catalog_audit_log reste modifiable par authenticated';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select action, count(*) from public.catalog_audit_log group by 1;
--   -- 'delete' apparait des la premiere suppression definitive
--
--   select id, occurred_at, entity_type, label, details->>'batch_id' as lot,
--          (details ? 'snapshot') as rejouable
--     from public.catalog_audit_log where action = 'delete'
--    order by occurred_at desc limit 20;
--
--   select privilege_type from information_schema.role_table_grants
--    where table_schema='public' and table_name='catalog_audit_log' and grantee='authenticated';
--   -- attendu : SELECT, et rien d'autre
-- =============================================================================
