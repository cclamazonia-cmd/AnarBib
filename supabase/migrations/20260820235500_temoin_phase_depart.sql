-- =============================================================================
-- Temoin de vie : distinguer « rien n'a tourne » de « un tir est mort en route »
-- =============================================================================
-- PROBLEME, constate le 20/08/2026 (cf. NOTE_angle-mort_tir-interrompu).
-- Le tir `court` de 11 h 30 a passe le filet, lance restic, et a ete TUE en
-- plein repack par un demontage de session (veille ou extinction de WSL).
--
-- Trois instruments locaux ont dit « ca va » :
--   - `systemctl show -p Result` repond success, la ou le journal dit
--     « Failed with result 'signal' » ;
--   - le drapeau ~/anarbib-ops/.last-failure est absent, l'ExecStartPre l'ayant
--     efface au demarrage sans que rien ne le repose ;
--   - `OnFailure=` n'a pas pu tirer : « Transaction is destructive », systemd
--     refusant d'enfiler une tache neuve pendant qu'il demonte la session.
--     Le dispositif d'alerte partage donc le sort de ce qu'il surveille.
--
-- Restait la base, seule a dire vrai. Mais elle ne le dit que TARD, et c'est
-- l'objet de cette migration : heartbeat() n'est appele qu'A LA FIN d'un tir
-- reussi. Un tir qui commence et meurt n'ecrit RIEN — ni succes, ni echec.
-- Pour la sonde, une machine eteinte toute la journee et un tir mort en plein
-- repack sont le MEME evenement. Cout mesure sur le cas du jour : 37 heures
-- d'aveuglement, alors que l'information existait des 11 h 31.
--
-- CE QU'ON NE FAIT PAS. Resserrer le seuil de 36 h. La chaine tourne sur un
-- poste qu'on eteint la nuit ; un seuil serre sonnerait chaque fois que la
-- machine dort, donc legitimement, et on apprendrait a ignorer l'alarme — pire
-- que pas d'alarme. Les 36 h achetent le droit d'eteindre son ordinateur.
--
-- CE QU'ON FAIT. Separer les deux evenements. « Un tir a commence et n'a pas
-- fini » est SANS AMBIGUITE : aucun faux positif possible, et actionnable dans
-- l'heure. Le script signalera son depart en plus de son arrivee.
--
-- PALIER 1 SUR 2 — cette migration ne change RIEN au comportement actuel.
-- Elle pose la colonne, ouvre la fonction a un quatrieme parametre, et
-- IMMUNISE la sonde : le statut ne compte desormais que les temoins 'ok'.
-- Cette immunisation n'est pas cosmetique, c'est ce qui rend l'etape suivante
-- sure. Sans elle, le jour ou le script enverrait un 'started', le statut y
-- verrait un temoin frais et MASQUERAIT le silence — l'alarme deviendrait
-- moins bonne qu'avant.
--
-- PALIER 2, plus tard, quand un 'started' aura ete vu arriver pour de vrai :
-- apprendre a la sonde la regle « derniere ligne = 'started' et vieille de
-- quelques heures -> tir interrompu, incident immediat ».
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. La phase du temoin
-- -----------------------------------------------------------------------------
-- Defaut 'ok' : les lignes existantes gardent exactement leur sens, et un
-- appel qui ignore le parametre continue de signaler une reussite.
alter table public.backup_heartbeats
  add column if not exists phase text not null default 'ok';

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'backup_heartbeats_phase_check'
  ) then
    alter table public.backup_heartbeats
      add constraint backup_heartbeats_phase_check
      check (phase in ('started', 'ok'));
  end if;
end $$;

comment on column public.backup_heartbeats.phase is
  '''started'' = le tir a commence ; ''ok'' = il est alle au bout. '
  'Une ligne ''started'' restee seule signale un tir interrompu (tue en route), '
  'ce qu''un simple silence ne permet pas de distinguer d''une machine eteinte.';

-- L'index de lecture sert au statut, qui filtre desormais sur la phase.
create index if not exists backup_heartbeats_flow_phase_date_idx
  on public.backup_heartbeats (flow, phase, reported_at desc);

-- -----------------------------------------------------------------------------
-- 2. La fonction d'enregistrement gagne un quatrieme parametre
-- -----------------------------------------------------------------------------
-- On DROP l'ancienne signature au lieu de la laisser cohabiter : deux surcharges
-- dont l'une a un parametre par defaut rendent l'appel a trois arguments
-- ambigu. Le script appelle a trois arguments — il continuera de fonctionner
-- tel quel, resolu vers la nouvelle fonction, avec phase = 'ok'.
drop function if exists public.fn_record_backup_heartbeat(text, text, text);

create or replace function public.fn_record_backup_heartbeat(
  p_flow        text,
  p_snapshot_id text default null,
  p_host        text default null,
  p_phase       text default 'ok'
) returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  if p_flow not in ('court', 'long', 'storage') then
    raise exception 'flux inconnu : % (attendu court, long ou storage)', p_flow
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

  -- Purge : on ne garde qu'un an d'historique par flux.
  delete from public.backup_heartbeats
   where reported_at < now() - interval '1 year';
end;
$function$;

comment on function public.fn_record_backup_heartbeat(text, text, text, text) is
  'Appelee par anarbib-bg2.sh : une fois au depart (phase ''started''), une fois '
  'a l''arrivee (phase ''ok''). Le proprietaire (postgres) conserve EXECUTE ; '
  'personne d''autre.';

revoke execute on function public.fn_record_backup_heartbeat(text, text, text, text)
  from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3. Le statut ne compte que les temoins d'arrivee
-- -----------------------------------------------------------------------------
-- Seul changement de comportement, et il est neutre aujourd'hui puisque toutes
-- les lignes existantes valent 'ok'. Il garantit qu'un temoin de DEPART ne
-- pourra jamais etre pris pour la preuve d'une sauvegarde faite.
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
  -- Dernier temoin REEL (hors amorcage) et dernier temoin tous hotes confondus.
  -- Dans les deux cas : phase = 'ok' seulement.
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
  dernier as (
    select s.flow,
           s.seuil,
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
$function$;

revoke execute on function public.fn_backup_heartbeat_status() from public, anon;
grant execute on function public.fn_backup_heartbeat_status() to authenticated;

-- -----------------------------------------------------------------------------
-- 4. Verification, dans la migration meme
-- -----------------------------------------------------------------------------
do $$
declare
  v_avant jsonb;
begin
  -- La colonne existe et sa contrainte tient.
  if not exists (select 1 from information_schema.columns
                  where table_schema='public' and table_name='backup_heartbeats'
                    and column_name='phase') then
    raise exception 'colonne phase absente apres migration';
  end if;

  -- Une seule signature : pas de surcharge ambigue laissee derriere.
  if (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname='fn_record_backup_heartbeat') <> 1 then
    raise exception 'fn_record_backup_heartbeat : surcharge multiple, appel a 3 arguments ambigu';
  end if;

  -- Le statut repond toujours, et toutes les lignes existantes valent 'ok' :
  -- le comportement est donc inchange.
  v_avant := public.fn_backup_heartbeat_status();
  if v_avant is null or not (v_avant ? 'flux') then
    raise exception 'fn_backup_heartbeat_status ne repond plus correctement';
  end if;
  if exists (select 1 from public.backup_heartbeats where phase <> 'ok') then
    raise exception 'une ligne non-ok existe deja : le palier 1 nest plus neutre';
  end if;
end $$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select public.fn_backup_heartbeat_status();
-- Attendu : identique a avant la migration (memes ages, memes hotes, meme ok).
--
-- Puis, quand le palier 2 sera pose et le script modifie, la preuve se fait
-- ainsi — dans l'esprit du force_fail de health-probe, une alarme jamais
-- declenchee n'etant pas une alarme :
--   select public.fn_record_backup_heartbeat('court', null, 'ACCATTONE', 'started');
-- sans 'ok' derriere. La sonde doit ouvrir un incident « tir interrompu »
-- SANS attendre les 36 h. Refermer ensuite par un tir reel.
-- =============================================================================
