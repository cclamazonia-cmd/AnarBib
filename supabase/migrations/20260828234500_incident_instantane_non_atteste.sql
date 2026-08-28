-- =============================================================================
-- Un genre d'incident pour l'instantane non atteste
-- =============================================================================
-- Date     : 2026-08-28
-- Chantier : temoin de vie des sauvegardes (#BG2, suite)
--
-- CE QUE 20260826170000 A LAISSE OUVERT.
--
-- Cette migration a ajoute `instantane_atteste` au statut des sauvegardes, avec
-- une raison explicite : rendre visible le jour ou `restic` cesserait d'etre
-- relisible — un depot injoignable a la relecture, un `restic snapshots` muet.
-- Elle a pose, tout aussi explicitement, que le champ est INFORMATIF et ne
-- bascule pas `ok` : un instantane non atteste n'est pas une panne, c'est un
-- angle mort, et on n'apprend pas aux gens a ignorer une alarme.
--
-- Les deux decisions sont justes. Leur combinaison ne l'etait pas. Ne pas
-- basculer `ok` veut dire qu'aucune alerte ne part ; et RIEN ne lisait le champ
-- — verifie le 28/08/2026 : le seul consommateur de fn_backup_heartbeat_status
-- dans tout le depot est l'edge function health-probe, et elle ne regardait pas
-- `instantane_atteste`. Il n'existe aucun tableau de bord ailleurs.
--
-- Le champ etait donc mort, et l'angle mort qu'il devait eclairer restait noir :
-- exactement la panne muette que le dispositif #BG2 existe pour empecher,
-- reproduite sur l'instrument cense la detecter.
--
-- CE QUE FAIT CETTE MIGRATION.
--
-- Rien qu'une chose : elargir le vocabulaire de `service_health_incidents.kind`
-- a 'backup_snapshot'. Le travail est cote health-probe, qui ouvre desormais un
-- incident de ce genre pour un flux qui tire bien mais sans identifiant
-- d'instantane.
--
-- POURQUOI UN GENRE DISTINCT, ET PAS `backup`.
--
-- L'index unique des incidents ouverts porte sur (kind, coalesce(subject,'')).
-- Sous le meme genre, un flux muet et un flux sans instantane se disputeraient
-- la meme ligne : le second empecherait le premier de s'ouvrir, ou le refermerait
-- — et c'est le premier qui compte. Deux natures de probleme, deux genres.
--
-- CE QUE CELA NE FAIT TOUJOURS PAS.
--
-- `ok` ne bascule pas, et c'est maintenu : la sauvegarde n'a pas echoue. Ce
-- signal dit « ce vert ne prouve pas ce que vous croyez », pas « au feu ». Il ne
-- prouve pas davantage qu'une restauration est possible — cela ne s'obtient que
-- par une restauration d'essai, et aucun champ n'en tiendra jamais lieu.
-- =============================================================================

begin;

alter table public.service_health_incidents
  drop constraint if exists service_health_incidents_kind_check;

alter table public.service_health_incidents
  add constraint service_health_incidents_kind_check
  check (kind = any (array[
    'service'::text,
    'backup'::text,
    'notifications'::text,
    'ressources_numeriques'::text,
    'backup_snapshot'::text
  ]));

comment on column public.service_health_incidents.kind is
  'Nature de l''incident. `backup` = un flux de sauvegarde est muet ou son tir a ete '
  'interrompu (bascule `ok`). `backup_snapshot` = le flux tire bien mais son temoin ne '
  'porte pas d''identifiant d''instantane restic : INFORMATIF, ne bascule pas `ok`, dit '
  'seulement que le vert ne prouve pas ce qu''on croit. Les deux genres sont distincts '
  'parce que l''unicite des incidents ouverts porte sur (kind, subject) : melanges, ils '
  'se refermeraient l''un l''autre.';

-- -----------------------------------------------------------------------------
-- Verification STRUCTURELLE
-- -----------------------------------------------------------------------------
-- Structure seulement : en CI les migrations tournent avant le seed.
do $verif$
declare
  v_def text;
begin
  select pg_get_constraintdef(c.oid) into v_def
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
   where n.nspname = 'public'
     and r.relname = 'service_health_incidents'
     and c.conname = 'service_health_incidents_kind_check';

  if v_def is null then
    raise exception 'la CHECK sur kind a disparu';
  end if;

  -- Les quatre genres preexistants doivent survivre a l'elargissement : c'est le
  -- risque propre a un DROP puis ADD de contrainte.
  if v_def not like '%backup_snapshot%'
     or v_def not like '%ressources_numeriques%'
     or v_def not like '%notifications%'
     or v_def not like '%''backup''%'
     or v_def not like '%service%' then
    raise exception 'la CHECK sur kind a perdu un genre : %', v_def;
  end if;

  -- L'unicite par (kind, subject) est ce qui rend le genre distinct utile.
  if not exists (
    select 1 from pg_indexes
     where schemaname = 'public'
       and tablename = 'service_health_incidents'
       and indexname = 'service_health_incidents_ouvert_par_sujet'
  ) then
    raise exception 'l''index d''unicite par (kind, subject) a disparu';
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select jsonb_pretty(public.fn_backup_heartbeat_status());
--   -- `instantane_atteste` doit valoir true sur les trois flux. Tant qu'il l'est,
--   -- AUCUN incident 'backup_snapshot' ne doit exister :
--
--   select kind, subject, opened_at, closed_at, reason
--     from public.service_health_incidents
--    where kind = 'backup_snapshot' order by opened_at desc;
--   -- doit ne rien rendre aujourd'hui.
--
-- EPROUVER le signal sans casser quoi que ce soit — un temoin d'arrivee SANS
-- instantane, retire PAR SON ID (jamais par un etat, cf. 20260821050000) :
--
--   insert into public.backup_heartbeats (flow, host, phase)
--   values ('court', 'ACCATTONE', 'ok') returning id;   -- <- NOTER CET ID
--   -- au prochain tour de health-probe : un incident 'backup_snapshot' sur
--   -- 'court', un courriel, et `ok` qui RESTE true.
--   delete from public.backup_heartbeats where id = <l id note>;
--   -- au tour suivant : l'incident se referme tout seul.
-- =============================================================================
