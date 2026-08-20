-- =============================================================================
-- Temoin de vie, palier 2/2 : reconnaitre un tir interrompu
-- =============================================================================
-- Suite de `20260820163045_temoin_phase_depart`, qui a pose la colonne `phase`
-- et immunise la sonde. Ici, on lui apprend a s'en servir.
--
-- LE PROBLEME, rappele en une phrase. Jusqu'ici, pour la sonde, une machine
-- eteinte toute la journee et un tir mort en plein repack etaient le MEME
-- evenement : dans les deux cas, rien n'arrivait en base. D'ou 37 heures
-- d'aveuglement sur le cas du 20/08, alors que l'information « ce tir a
-- commence et n'a pas fini » existait des la premiere minute.
--
-- LA REGLE AJOUTEE. Un temoin de DEPART plus recent que le dernier temoin
-- d'ARRIVEE, et vieux de plus d'une heure -> le tir est mort en route.
--
-- POURQUOI UNE HEURE, et pas moins :
--   * les trois unites systemd portent TimeoutStartSec=1800 — systemd tue
--     lui-meme un tir au-dela de 30 minutes ;
--   * les durees reelles mesurees du flux court sont de 5 a 7 minutes
--     (17/08 : 6 min 40 ; 18/08 : 5 min 37 ; 19/08 : 5 min 08).
-- Une heure laisse donc le double de la borne systemd. Cette marge absorbe le
-- seul faux positif imaginable : une machine mise en veille quelques minutes
-- pendant le tir, qui reprendrait ensuite.
--
-- CE QUE CETTE REGLE N'EST PAS. Ce n'est pas un resserrement du seuil de
-- silence, qui reste a 36 h. Resserrer ce seuil-la serait une faute : la
-- chaine tourne sur un poste qu'on eteint la nuit, et l'alarme sonnerait
-- legitimement mais sans cesse, jusqu'a ce qu'on apprenne a l'ignorer. Les
-- 36 h achetent le droit d'eteindre son ordinateur.
--
-- Ici, aucun faux positif de ce genre n'est possible : un temoin 'started'
-- PROUVE qu'un tir a commence. On ne devine plus, on constate.
--
-- Detection ramenee de ~37 h a ~1 h.
--
-- COTE SONDE, rien a redeployer pour que l'incident s'ouvre : health-probe
-- filtre deja sur `muet`, qui devient vrai dans les deux cas. Le champ
-- `raison` est ajoute pour que le courriel cesse de dire « muet depuis 1.2 h »
-- quand le seuil de silence est de 36 h — health-probe l'utilisera des sa
-- prochaine mise a jour, et retombe sinon sur son libelle actuel.
-- =============================================================================

create or replace function public.fn_backup_heartbeat_status()
 returns jsonb
 language sql
 stable security definer
 set search_path to 'public', 'pg_temp'
as $function$
  with seuils(flow, seuil) as (
    values ('court',   interval '36 hours'),
           ('long',    interval '9 days'),
           ('storage', interval '9 days')
  ),
  -- Dernier temoin d'ARRIVEE reel (hors amorcage), et tous hotes confondus.
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
  -- Dernier temoin de DEPART, tous hotes confondus.
  depart as (
    select s.flow,
           (select b.reported_at from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'started'
             order by b.reported_at desc limit 1) as parti_le,
           (select b.host from public.backup_heartbeats b
             where b.flow = s.flow and b.phase = 'started'
             order by b.reported_at desc limit 1) as host
      from seuils s
  ),
  dernier as (
    select s.flow,
           s.seuil,
           coalesce(r.vu_le, t.vu_le)             as vu_le,
           coalesce(r.host,  t.host)              as host,
           coalesce(r.snapshot_id, t.snapshot_id) as snapshot_id,
           (r.vu_le is null)                      as temoin_amorcage,
           d.parti_le,
           d.host                                 as host_depart
      from seuils s
      join reel r   on r.flow = s.flow
      join tous t   on t.flow = s.flow
      join depart d on d.flow = s.flow
  ),
  juge as (
    select d.*,
           (d.parti_le is not null
             and (d.vu_le is null or d.parti_le > d.vu_le)
             and now() - d.parti_le > interval '60 minutes')          as interrompu,
           (d.vu_le is null or now() - d.vu_le > d.seuil)             as silencieux
      from dernier d
  )
  select jsonb_build_object(
    'ok', not exists (select 1 from juge j where j.silencieux or j.interrompu),
    'flux', coalesce(jsonb_agg(jsonb_build_object(
              'flow',            j.flow,
              'vu_le',           j.vu_le,
              'host',            j.host,
              'age_heures',      round(extract(epoch from (now() - j.vu_le)) / 3600.0, 1),
              'seuil_heures',    round(extract(epoch from j.seuil) / 3600.0, 1),
              'muet',            (j.silencieux or j.interrompu),
              'silencieux',      j.silencieux,
              'interrompu',      j.interrompu,
              'parti_le',        j.parti_le,
              'temoin_amorcage', j.temoin_amorcage,
              'snapshot_id',     j.snapshot_id,
              'raison',
                case
                  when j.interrompu then
                    j.flow || ' : tir commence il y a '
                      || round(extract(epoch from (now() - j.parti_le)) / 3600.0, 1)
                      || ' h et JAMAIS TERMINE (tue en route)'
                  when j.silencieux then
                    j.flow || ' muet depuis '
                      || round(extract(epoch from (now() - j.vu_le)) / 3600.0, 1) || ' h'
                  else null
                end
            ) order by j.flow), '[]'::jsonb)
  )
  from juge j;
$function$;

revoke execute on function public.fn_backup_heartbeat_status() from public, anon;
grant execute on function public.fn_backup_heartbeat_status() to authenticated;

do $$
declare v jsonb;
begin
  v := public.fn_backup_heartbeat_status();
  if v is null or not (v ? 'flux') then
    raise exception 'fn_backup_heartbeat_status ne repond plus';
  end if;
  if (v->>'ok')::boolean is not true then
    raise exception 'le statut passe a non-ok alors quaucun started nexiste : regression';
  end if;
end $$;

-- =============================================================================
-- EPROUVER L'ALARME — une alarme jamais declenchee n'est pas une alarme
-- =============================================================================
-- Une fois anarbib-bg2.sh modifie pour signaler son depart :
--
--   select public.fn_record_backup_heartbeat('court', null, 'ACCATTONE', 'started');
--   update public.backup_heartbeats
--      set reported_at = now() - interval '2 hours'
--    where phase = 'started' and flow = 'court';
--
-- Deux tours de sonde (10 min) plus tard, un incident kind='backup' doit
-- s'ouvrir avec « tir commence il y a 2 h et JAMAIS TERMINE », SANS attendre
-- les 36 h. Refermer ensuite par un tir reel.
-- =============================================================================
