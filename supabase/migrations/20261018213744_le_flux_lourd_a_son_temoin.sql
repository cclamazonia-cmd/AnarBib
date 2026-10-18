-- =========================================================================
-- Temoin de vie : un quatrieme flux, `lourd`, et une borne de tir par flux
-- =========================================================================
-- Date     : 2026-10-18
-- Chantier : #BG2 sauvegardes (suite de BG2-16, temoin de vie)
-- Auteur   : AnarBib (Claude Code)
-- Session  : Flux storage BG2 : sync incrémentale au lieu du resync
--
-- CE QUI S'EST PASSE. Le 18/10 a 21:01 Paris, le tir `storage` a ete tue par
-- sa borne systemd d'une heure : il retelechargeait TOUS les buckets a chaque
-- fois, et anarbib-pdf-public etait passe de presque rien a 16 Go en une
-- semaine (versement des PDF, D13-D16). La sonde a ouvert l'incident « tir
-- interrompu » — a juste titre.
--
-- CE QUI CHANGE COTE POSTE (deploy/ops/anarbib-bg2.sh, meme commit) :
--   * synchronisation INCREMENTALE des buckets (seul le neuf est telecharge) ;
--   * les buckets LOURDS (PDF, EPUB, fond de carte map-tiles) quittent le flux
--     storage pour un flux `lourd`, sauvegarde dans un depot restic LOCAL, sur
--     un disque du poste : le depot SFTP des Herbes Folles n'a que 14 Go libres
--     sur un /data partage, et ces buckets en pesent ~52. Decision de Xavier,
--     en attendant une place hors site suffisante.
--
-- CE QUE FAIT CETTE MIGRATION
--
-- 1. Elle admet `lourd` dans la contrainte de backup_heartbeats et dans
--    fn_record_backup_heartbeat. Sans cela le temoin du nouveau flux serait
--    refuse — en silence cote poste, ou le temoin est volontairement non
--    bloquant.
--
-- 2. Elle donne a chaque flux SA borne de tir. La regle `interrompu` (un
--    depart sans arrivee depuis plus de 60 min, migration 20260820165002)
--    valait pour tous ; elle etait couplee a TimeoutStartSec=3600 des services.
--    Le flux lourd porte une borne de 3 h (une grosse fournee de PDF se
--    telecharge a ~5 Mo/s) : avec 60 min, la sonde crierait au tir mort
--    pendant qu'il travaille. Sa borne `interrompu` est de 4 h — au-dessus de
--    son TimeoutStartSec, comme les 60 min des autres flux le sont de leur
--    heure : systemd tue un tir trop long AVANT que la sonde ne le juge mort.
--    RELEVER L'UN, C'EST RELEVER L'AUTRE (deploy/ops/systemd/anarbib-backup-lourd.service).
--    Les trois flux existants gardent exactement leurs 60 min.
--
-- 3. Elle seme une ligne d'amorcage pour `lourd`, comme 20260820100000 l'avait
--    fait pour les trois premiers. Sans elle, la sonde verrait un flux sans
--    aucun temoin des son prochain tour — donc « muet » — et enverrait une
--    alerte fausse avant meme le premier tir. La fonction l'ignore des qu'un
--    temoin reel existe, et le courriel la nomme pour ce qu'elle est (« ligne
--    d'amorcage de migration, pas un tir reel ») ; la purge generique de
--    20260826170000 la retirera quand on la rejouera.
--
-- Les seuils de silence sont inchanges ; celui de lourd est hebdomadaire,
-- 9 jours, comme storage. ALIGNE sur deploy/ops/anarbib-bg2-fraicheur.sh
-- (SEUIL_lourd=216) : les deux gardes doivent porter le meme jugement.
--
-- Corps repris de la definition EN PRODUCTION le 18/10 (pg_get_functiondef),
-- qui a evolue depuis 20260820165002 (orphelin, instantane_atteste) : seules
-- les lignes de `lourd` et de la borne par flux different.
-- =========================================================================

-- 1. La contrainte -----------------------------------------------------------
alter table public.backup_heartbeats
  drop constraint if exists backup_heartbeats_flow_check;
alter table public.backup_heartbeats
  add constraint backup_heartbeats_flow_check
  check (flow in ('court', 'long', 'storage', 'lourd'));

-- 2. L'ecriture du temoin ----------------------------------------------------
create or replace function public.fn_record_backup_heartbeat(
  p_flow text,
  p_snapshot_id text default null,
  p_host text default null,
  p_phase text default 'ok')
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
begin
  if p_flow not in ('court', 'long', 'storage', 'lourd') then
    raise exception 'flux inconnu : % (attendu court, long, storage ou lourd)', p_flow
      using errcode = '22023';
  end if;
  if p_phase not in ('started', 'ok') then
    raise exception 'phase inconnue : % (attendu started ou ok)', p_phase
      using errcode = '22023';
  end if;

  insert into public.backup_heartbeats (flow, snapshot_id, host, phase)
  values (p_flow, nullif(btrim(coalesce(p_snapshot_id, '')), ''),
                  nullif(btrim(coalesce(p_host, '')), ''),
                  p_phase);

  delete from public.backup_heartbeats
   where reported_at < now() - interval '1 year';
end;
$function$;

revoke execute on function public.fn_record_backup_heartbeat(text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.fn_record_backup_heartbeat(text, text, text, text)
  to service_role;

-- 3. Le jugement -------------------------------------------------------------
create or replace function public.fn_backup_heartbeat_status()
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public', 'pg_temp'
as $function$
  -- seuil : silence admis entre deux tirs reussis.
  -- borne : duree au-dela de laquelle un tir parti sans revenir est MORT.
  --         Couplee au TimeoutStartSec de chaque service (cf. en-tete).
  with seuils(flow, seuil, borne) as (
    values ('court',   interval '36 hours', interval '60 minutes'),
           ('long',    interval '9 days',   interval '60 minutes'),
           ('storage', interval '9 days',   interval '60 minutes'),
           ('lourd',   interval '9 days',   interval '4 hours')
  ),
  reel as (
    select s.flow,
           (select b.reported_at from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'ok'
               and coalesce(b.host,'') <> 'amorcage-migration'
             order by b.reported_at desc limit 1) as vu_le,
           (select b.host from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'ok'
               and coalesce(b.host,'') <> 'amorcage-migration'
             order by b.reported_at desc limit 1) as host,
           (select b.snapshot_id from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'ok'
               and coalesce(b.host,'') <> 'amorcage-migration'
             order by b.reported_at desc limit 1) as snapshot_id
      from seuils s
  ),
  tous as (
    select s.flow,
           (select b.reported_at from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'ok'
             order by b.reported_at desc limit 1) as vu_le,
           (select b.host from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'ok'
             order by b.reported_at desc limit 1) as host,
           (select b.snapshot_id from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'ok'
             order by b.reported_at desc limit 1) as snapshot_id
      from seuils s
  ),
  orphelin as (
    select s.flow,
           (select min(d.reported_at)
              from public.backup_heartbeats d
             where d.flow = s.flow
               and d.phase = 'started'
               and not exists (select 1
                                 from public.backup_heartbeats o
                                where o.flow = d.flow
                                  and o.phase = 'ok'
                                  and o.reported_at > d.reported_at)
           ) as depuis
      from seuils s
  ),
  depart as (
    select s.flow,
           (select b.reported_at from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'started'
             order by b.reported_at desc limit 1) as parti_le
      from seuils s
  ),
  juge as (
    select s.flow,
           s.seuil,
           s.borne,
           coalesce(r.vu_le, t.vu_le)             as vu_le,
           coalesce(r.host,  t.host)              as host,
           coalesce(r.snapshot_id, t.snapshot_id) as snapshot_id,
           (r.vu_le is null)                      as temoin_amorcage,
           d.parti_le,
           o.depuis                               as orphelin_depuis,
           (o.depuis is not null
             and now() - o.depuis > s.borne)                          as interrompu,
           (coalesce(r.vu_le, t.vu_le) is null
             or now() - coalesce(r.vu_le, t.vu_le) > s.seuil)         as silencieux
      from seuils s
      join reel r     on r.flow = s.flow
      join tous t     on t.flow = s.flow
      join depart d   on d.flow = s.flow
      join orphelin o on o.flow = s.flow
  )
  select jsonb_build_object(
    'ok', not exists (select 1 from juge j where j.silencieux or j.interrompu),
    'flux', coalesce(jsonb_agg(jsonb_build_object(
              'flow',            j.flow,
              'vu_le',           j.vu_le,
              'host',            j.host,
              'age_heures',      round(extract(epoch from (now() - j.vu_le)) / 3600.0, 1),
              'seuil_heures',    round(extract(epoch from j.seuil) / 3600.0, 1),
              'borne_tir_heures', round(extract(epoch from j.borne) / 3600.0, 1),
              'muet',            (j.silencieux or j.interrompu),
              'silencieux',      j.silencieux,
              'interrompu',      j.interrompu,
              'parti_le',        j.parti_le,
              'orphelin_depuis', j.orphelin_depuis,
              'temoin_amorcage', j.temoin_amorcage,
              'snapshot_id',     j.snapshot_id,
              -- Informatif, ne bascule pas `ok` : dit si le dernier temoin
              -- d'arrivee retenu porte un identifiant d'instantane restic.
              'instantane_atteste', (j.snapshot_id is not null),
              'raison',
                case
                  when j.interrompu then
                    j.flow || ' : tir commence il y a '
                      || round(extract(epoch from (now() - j.orphelin_depuis)) / 3600.0, 1)
                      || ' h et JAMAIS TERMINE (tue en route, ou arrete par sa borne de '
                      || round(extract(epoch from j.borne) / 3600.0, 1) || ' h)'
                  when j.silencieux then
                    j.flow || ' muet depuis '
                      || round(extract(epoch from (now() - j.vu_le)) / 3600.0, 1) || ' h'
                  else null
                end
            ) order by j.flow), '[]'::jsonb)
  )
  from juge j;
$function$;

revoke execute on function public.fn_backup_heartbeat_status()
  from public, anon, authenticated;
grant execute on function public.fn_backup_heartbeat_status()
  to service_role;

comment on function public.fn_backup_heartbeat_status() is
  'Etat des quatre flux de sauvegarde (court, long, storage, lourd). Le silence se '
  'calcule sur le dernier temoin REEL ; un depart sans arrivee au-dela de la borne '
  'du flux (60 min, 4 h pour lourd) est un tir interrompu. Consommee par health-probe.';

-- 4. L'amorcage du nouveau flux ----------------------------------------------
insert into public.backup_heartbeats (flow, host, phase)
select 'lourd', 'amorcage-migration', 'ok'
 where not exists (select 1 from public.backup_heartbeats where flow = 'lourd');

-- 5. Garde -------------------------------------------------------------------
do $$
declare v jsonb; f jsonb;
begin
  if has_function_privilege('anon', 'public.fn_backup_heartbeat_status()', 'execute')
     or has_function_privilege('authenticated', 'public.fn_backup_heartbeat_status()', 'execute')
     or has_function_privilege('anon', 'public.fn_record_backup_heartbeat(text, text, text, text)', 'execute')
     or has_function_privilege('authenticated', 'public.fn_record_backup_heartbeat(text, text, text, text)', 'execute') then
    raise exception 'fonctions du temoin ouvertes a anon ou authenticated';
  end if;

  v := public.fn_backup_heartbeat_status();
  if v is null or jsonb_array_length(v->'flux') <> 4 then
    raise exception 'fn_backup_heartbeat_status ne rend pas quatre flux : %', v;
  end if;
  -- `ok` global n'est PAS exige : il depend de l'etat reel des trois autres
  -- flux au moment du deploiement (le 18/10, storage etait en defaut). Seul
  -- le nouveau flux doit naitre vert, grace a son amorcage.
  select x into f from jsonb_array_elements(v->'flux') x where x->>'flow' = 'lourd';
  if f is null or (f->>'muet')::boolean then
    raise exception 'le flux lourd nait muet : amorcage manquant ? %', f;
  end if;
end $$;
