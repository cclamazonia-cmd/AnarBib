-- =============================================================================
-- Temoin de vie des sauvegardes (#BG2-16)
-- =============================================================================
-- PROBLEME. RUNBOOK_restauration_BG2 §7.5 le nomme sans le resoudre : la chaine
-- `OnFailure=` de systemd detecte les ERREURS, pas les SILENCES. Les trois
-- timers ne tirent que quand le poste de travail est allume. Si la machine
-- reste eteinte trois semaines, ou si WSL ne demarre pas, rien n'echoue —
-- il ne se passe simplement rien, et personne ne l'apprend.
--
-- « Detecter "ca n'a jamais tourne" exige un observateur EXTERNE. »
--
-- SOLUTION. L'observateur est ici, en base. Le poste de travail PRODUIT les
-- sauvegardes ; Supabase CONSTATE leur absence. Aucun service tiers, rien qui
-- sorte du reseau, et le jour ou tout bascule sur une VM c'est le meme
-- mecanisme qui suit.
--
-- Le script anarbib-bg2.sh a deja un acces base par ~/.pgpass : il signale
-- lui-meme chaque flux reussi. Pas de nouveau secret, pas de nouvel appel HTTP.
--
-- LIMITE ASSUMEE, dans la meme veine que celle de health-probe : si Supabase
-- tombe entierement, l'observateur tombe avec. Il couvre le silence des
-- sauvegardes, ce qui est le risque reel et documente.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. La table des temoins
-- -----------------------------------------------------------------------------
create table if not exists public.backup_heartbeats (
  id          bigint generated always as identity primary key,
  flow        text        not null check (flow in ('court', 'long', 'storage')),
  reported_at timestamptz not null default now(),
  snapshot_id text,
  host        text
);

comment on table public.backup_heartbeats is
  'Signal de vie emis par anarbib-bg2.sh a la fin de chaque flux restic reussi. '
  'Sert a detecter le SILENCE des sauvegardes (cf. RUNBOOK_restauration_BG2 §7.5).';

create index if not exists backup_heartbeats_flow_date_idx
  on public.backup_heartbeats (flow, reported_at desc);

-- RLS : lecture reservee aux admins reseau. Personne n'ecrit directement —
-- seule fn_record_backup_heartbeat() insere, en SECURITY DEFINER.
alter table public.backup_heartbeats enable row level security;

drop policy if exists backup_heartbeats_select_network_admin on public.backup_heartbeats;
create policy backup_heartbeats_select_network_admin
  on public.backup_heartbeats
  for select
  to authenticated
  using (public.fn_caller_is_network_admin());

revoke all on table public.backup_heartbeats from public, anon;
grant select on table public.backup_heartbeats to authenticated;
grant select, insert, delete on table public.backup_heartbeats to service_role;

-- Amorcage : une ligne par flux, datee de maintenant. Sans elle, le controle
-- crierait au silence des la premiere execution, avant meme que le script ait
-- eu l'occasion de signaler quoi que ce soit.
insert into public.backup_heartbeats (flow, host)
select f, 'amorcage-migration'
from (values ('court'), ('long'), ('storage')) as v(f)
where not exists (select 1 from public.backup_heartbeats b where b.flow = v.f);

-- -----------------------------------------------------------------------------
-- 2. L'enregistrement, appele par le script
-- -----------------------------------------------------------------------------
create or replace function public.fn_record_backup_heartbeat(
  p_flow        text,
  p_snapshot_id text default null,
  p_host        text default null
) returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  if p_flow not in ('court', 'long', 'storage') then
    raise exception 'flux inconnu : % (attendu court, long ou storage)', p_flow
      using errcode = '22023';
  end if;
  insert into public.backup_heartbeats (flow, snapshot_id, host)
  values (p_flow, nullif(btrim(coalesce(p_snapshot_id, '')), ''),
                  nullif(btrim(coalesce(p_host, '')), ''));

  -- Purge : on ne garde qu'un an d'historique par flux.
  delete from public.backup_heartbeats
   where reported_at < now() - interval '1 year';
end;
$$;

comment on function public.fn_record_backup_heartbeat(text, text, text) is
  'Appelee par anarbib-bg2.sh apres chaque restic backup reussi. '
  'Le proprietaire (postgres) conserve EXECUTE ; personne d''autre.';

revoke execute on function public.fn_record_backup_heartbeat(text, text, text)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Le controle, appele par health-probe
-- -----------------------------------------------------------------------------
-- Seuils : ils laissent de la marge sur la cadence reelle.
--   court   : quotidien   -> alerte au-dela de 36 h
--   long    : hebdomadaire -> alerte au-dela de 9 jours
--   storage : hebdomadaire -> alerte au-dela de 9 jours
create or replace function public.fn_backup_heartbeat_status()
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  with seuils(flow, seuil) as (
    values ('court',   interval '36 hours'),
           ('long',    interval '9 days'),
           ('storage', interval '9 days')
  ),
  -- AMENDE LE 2026-08-20 (voir migration 20260820012343). Cette version-ci est
  -- la definitive : la migration 012343 porte le meme correctif mais s'execute
  -- AVANT ce fichier au rejeu (numerotation a l'heure reelle contre numerotation
  -- avancee a la main). Sans cet alignement, une reconstruction depuis le depot
  -- restaurerait ici l'ancienne version et defairait le correctif en silence.
  --
  -- Le silence se calcule sur le dernier temoin REEL : une ligne d'amorcage
  -- (host = 'amorcage-migration') cesse de compter des qu'un vrai tir a signale
  -- pour ce flux. `temoin_amorcage` rend visible un flux tenu en vert par un
  -- semis, sans basculer `ok` — sinon on declencherait une alerte fausse sur des
  -- flux qui fonctionnent mais n'ont pas encore parle.
  reel as (
    select s.flow,
           (select b.reported_at from public.backup_heartbeats b
             where b.flow = s.flow and coalesce(b.host,'') <> 'amorcage-migration'
             order by b.reported_at desc limit 1) as vu_le,
           (select b.host from public.backup_heartbeats b
             where b.flow = s.flow and coalesce(b.host,'') <> 'amorcage-migration'
             order by b.reported_at desc limit 1) as host,
           (select b.snapshot_id from public.backup_heartbeats b
             where b.flow = s.flow and coalesce(b.host,'') <> 'amorcage-migration'
             order by b.reported_at desc limit 1) as snapshot_id
      from seuils s
  ),
  tous as (
    select s.flow,
           (select b.reported_at from public.backup_heartbeats b
             where b.flow = s.flow order by b.reported_at desc limit 1) as vu_le,
           (select b.host from public.backup_heartbeats b
             where b.flow = s.flow order by b.reported_at desc limit 1) as host,
           (select b.snapshot_id from public.backup_heartbeats b
             where b.flow = s.flow order by b.reported_at desc limit 1) as snapshot_id
      from seuils s
  ),
  dernier as (
    select s.flow, s.seuil,
           coalesce(r.vu_le, t.vu_le)             as vu_le,
           coalesce(r.host,  t.host)              as host,
           coalesce(r.snapshot_id, t.snapshot_id) as snapshot_id,
           (r.vu_le is null)                      as temoin_amorcage
      from seuils s
      join reel r on r.flow = s.flow
      join tous t on t.flow = s.flow
  )
  select jsonb_build_object(
    'ok', not exists (select 1 from dernier d
                       where d.vu_le is null or now() - d.vu_le > d.seuil),
    'flux', coalesce(jsonb_agg(jsonb_build_object(
              'flow',            d.flow,
              'vu_le',           d.vu_le,
              'host',            d.host,
              'age_heures',      round(extract(epoch from (now() - d.vu_le)) / 3600.0, 1),
              'seuil_heures',    round(extract(epoch from d.seuil) / 3600.0, 1),
              'muet',            (d.vu_le is null or now() - d.vu_le > d.seuil),
              'temoin_amorcage', d.temoin_amorcage,
              'snapshot_id',     d.snapshot_id
            ) order by d.flow), '[]'::jsonb)
  )
  from dernier d;
$$;

comment on function public.fn_backup_heartbeat_status() is
  'Etat des trois flux de sauvegarde. Consommee par l''Edge Function health-probe, '
  'qui ouvre un incident kind=''backup'' quand un flux devient muet.';

revoke execute on function public.fn_backup_heartbeat_status() from public, anon;
grant execute on function public.fn_backup_heartbeat_status() to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Separer les incidents de service et les incidents de sauvegarde
-- -----------------------------------------------------------------------------
-- ⚠️ INDISPENSABLE. health-probe ferme « le dernier incident ouvert », sans
-- regarder son origine : sans cette colonne, le premier tour vert du service
-- public refermerait un incident de sauvegarde et enverrait un courriel
-- « service retabli » qui ne voudrait rien dire.
-- Le correctif correspondant est dans supabase/functions/health-probe/index.ts,
-- meme commit : les deux requetes d'incident y filtrent desormais sur kind.
alter table public.service_health_incidents
  add column if not exists kind text not null default 'service';

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'service_health_incidents_kind_check'
  ) then
    alter table public.service_health_incidents
      add constraint service_health_incidents_kind_check
      check (kind in ('service', 'backup'));
  end if;
end $$;

create index if not exists service_health_incidents_kind_open_idx
  on public.service_health_incidents (kind, closed_at, opened_at desc);

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select public.fn_backup_heartbeat_status();
--
-- Attendu juste apres la migration : ok = true, trois flux, ages proches de
-- zero (les lignes d'amorcage).
--
-- Puis, une fois les trois lignes ajoutees a anarbib-bg2.sh, un tir manuel :
--   ./anarbib-bg2.sh backup long
-- doit faire passer 'long' a un age de quelques secondes, avec un host reel
-- au lieu de 'amorcage-migration'.
--
-- EPROUVER L'ALARME, dans l'esprit du force_fail de health-probe — une alarme
-- jamais declenchee n'est pas une alarme :
--   update public.backup_heartbeats
--      set reported_at = now() - interval '10 days'
--    where flow = 'long';
-- puis attendre deux tours de sonde (10 minutes) : un incident kind='backup'
-- doit s'ouvrir et un courriel partir. Relancer ensuite un vrai tir pour
-- refermer.
