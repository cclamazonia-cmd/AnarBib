-- =============================================================================
-- Temoin de vie : l'alarme ne doit plus s'eteindre sur un simple DEMARRAGE
-- =============================================================================
-- CORRIGE `20260820165002_temoin_tir_interrompu`, dont la detection etait
-- silenciable par ce qu'elle est censee detecter.
--
-- CE QUI S'EST PASSE, mesure pendant l'epreuve du 20/08 au soir :
--
--   id=9   ok       19:30:25   (a809ef0c)
--   id=10  started  19:30:30   (ligne injectee pour le test)
--   id=11  started  20:40:24   (depart du tir de fermeture)
--   id=12  ok       20:46:22   (b4d37058)
--
--   incident #3 : ouvert 20:35:01, ferme 20:45:01
--
-- L'incident s'est ferme QUATRE-VINGT-UNE SECONDES AVANT que la sauvegarde
-- reussisse. Le courriel « Sauvegardes retablies » est parti a 20:45:01, le
-- temoin de reussite est arrive a 20:46:22. La fermeture n'a donc pas ete
-- causee par un tir reussi, mais par un tir qui COMMENCAIT.
--
-- POURQUOI. L'ancienne detection ne regardait que le DERNIER depart :
--
--     parti_le > vu_le  and  now() - parti_le > 60 min
--
-- Le depart de 20:40:24 a remplace celui de 19:30:30 dans le calcul ; il
-- n'avait que 4,6 minutes ; `interrompu` est retombe a faux.
--
-- CONSEQUENCE, et c'est elle qui rend la correction urgente : un simple
-- DEMARRAGE eteignait l'alarme pour une heure. Une machine qui demarre un tir
-- et meurt, en boucle, l'aurait gardee fermee indefiniment, rearmee a chaque
-- tentative — c'est-a-dire le scenario meme du 20/08, en repetition.
--
-- LA CORRECTION. Ne plus raisonner sur LE DERNIER depart, mais sur l'existence
-- d'un depart ORPHELIN : un `started` qu'aucun `ok` ne suit. Un nouveau depart
-- n'efface alors plus rien ; SEULE UNE ARRIVEE referme.
--
-- On expose `orphelin_depuis` = le PLUS ANCIEN depart orphelin, et non le plus
-- recent : en cas de demarrages repetes qui meurent, c'est lui qui dit depuis
-- combien de temps on est aveugle. Le plus recent minimiserait la panne.
--
-- Un tir EN COURS produit legitimement un orphelin ; il ne declenche rien tant
-- qu'il a moins d'une heure.
--
-- ⚠️ POURQUOI UNE HEURE, ET PAS UN AUTRE NOMBRE — A LIRE AVANT DE TOUCHER A
--    L'UN OU A L'AUTRE. Le seuil de 60 min est le DOUBLE du `TimeoutStartSec`
--    de 1800 s porte par les trois unites systemd. Cette relation n'est pas un
--    hasard, c'est tout le raisonnement :
--
--      un tir legitime NE PEUT PAS depasser 30 minutes — systemd le tue avant.
--      Donc un depart vieux d'une heure signifie forcement un tir mort SANS QUE
--      SYSTEMD AIT PU LE SIGNALER : session demontee, machine eteinte, WSL
--      arrete. C'est-a-dire exactement le trou que `OnFailure=` ne couvre pas.
--
--    Il n'y a donc aucun faux positif possible tant que seuil > TimeoutStartSec.
--    **Si quelqu'un releve un jour le TimeoutStartSec sans relever ce seuil,
--    l'alarme redevient fausse EN SILENCE** : un tir long mais legitime sera
--    signale comme mort. Les deux nombres bougent ensemble ou pas du tout.
--
--    Durees reelles mesurees le 20/08, pour situer la marge :
--      court    ~6 min
--      long     ~6 min
--      storage  21 s a 11 min 18 s (430 Mo de buckets, 792 Mo de memoire)
--
-- ⚠️ RISQUE A HORIZON PROCHE, sur `storage`. Ces 11 min 18 s valent pour 430 Mo.
--    Le profil de numerisation vise 11 a 27 Go. A cette echelle le flux
--    depassera les 30 minutes, systemd le tuera, et l'alarme se declenchera —
--    CORRECTEMENT, mais toutes les semaines. Ce n'est pas un defaut de cette
--    detection : c'est un dimensionnement a revoir AVEC le chantier de
--    numerisation, et non apres la premiere panne. A porter au plan de marche.
--
-- NON-REGRESSION, deja verifiee en base par la session qui a mene l'epreuve :
-- le predicat orphelin rend `false` partout sur l'etat actuel, et `court =
-- TRUE` s'il est rejoue a l'instant de la fermeture. Il attrape donc le cas
-- manque sans rouvrir d'incident a tort.
-- =============================================================================

begin;

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
  -- LE CHANGEMENT : le plus ancien depart QU'AUCUNE ARRIVEE NE SUIT.
  -- Un depart plus recent n'efface pas un orphelin plus ancien.
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
  -- Dernier depart, tous statuts confondus : purement informatif.
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
           coalesce(r.vu_le, t.vu_le)             as vu_le,
           coalesce(r.host,  t.host)              as host,
           coalesce(r.snapshot_id, t.snapshot_id) as snapshot_id,
           (r.vu_le is null)                      as temoin_amorcage,
           d.parti_le,
           o.depuis                               as orphelin_depuis,
           (o.depuis is not null
             and now() - o.depuis > interval '60 minutes')            as interrompu,
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
              'muet',            (j.silencieux or j.interrompu),
              'silencieux',      j.silencieux,
              'interrompu',      j.interrompu,
              'parti_le',        j.parti_le,
              'orphelin_depuis', j.orphelin_depuis,
              'temoin_amorcage', j.temoin_amorcage,
              'snapshot_id',     j.snapshot_id,
              'raison',
                case
                  when j.interrompu then
                    j.flow || ' : tir commence il y a '
                      || round(extract(epoch from (now() - j.orphelin_depuis)) / 3600.0, 1)
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

-- -----------------------------------------------------------------------------
-- Verification
-- -----------------------------------------------------------------------------
do $$
declare v jsonb;
begin
  v := public.fn_backup_heartbeat_status();
  if v is null or not (v ? 'flux') then
    raise exception 'fn_backup_heartbeat_status ne repond plus';
  end if;
  if not (v -> 'flux' -> 0 ? 'orphelin_depuis') then
    raise exception 'le champ orphelin_depuis nest pas expose';
  end if;
  -- L'etat courant ne doit PAS declencher : tous les departs ont une arrivee.
  if (v->>'ok')::boolean is not true then
    raise exception 'le statut passe a non-ok sur letat courant : reouverture a tort';
  end if;
end $$;

commit;

-- =============================================================================
-- EPROUVER — la recette, corrigee elle aussi
-- =============================================================================
-- L'ancienne recette (migration 20260820165002) etait fausse PAR CONSTRUCTION,
-- pas par obsolescence : elle visait sa cible par un ETAT,
--
--     update ... where phase = 'started' and flow = 'court'
--
-- ce qui ne designait qu'une ligne tant qu'aucun tir reel n'en avait produit
-- d'autre. Des qu'il y en a eu une, la meme commande rétrodatait le temoin d'un
-- vrai tir. Et le rétrodatage plaçait le depart AVANT le dernier `ok`, donc la
-- detection ne se declenchait pas : une recette destructrice ET incapable de
-- reussir. TOUJOURS designer une ligne de test par son `id`.
--
-- LA BONNE RECETTE : injecter un depart ORPHELIN, deja vieux d'une heure, et
-- noter son id.
--
--   insert into public.backup_heartbeats (flow, host, phase, reported_at)
--   values ('court', 'ACCATTONE', 'started', now() - interval '61 minutes')
--   returning id;    -- <- NOTER CET ID
--
-- Deux tours de sonde (10 min) plus tard : incident kind='backup' ouvert, avec
-- « tir commence il y a 1.0 h et JAMAIS TERMINE ». Refermer par un tir REEL :
--
--   systemctl --user start anarbib-backup-court.service
--
-- PUIS CONTROLER CE QUI A MANQUE LE 20/08 — comparer la fermeture au temoin de
-- reussite, et pas seulement constater que l'incident s'est ferme :
--
--   select i.closed_at,
--          (select max(b.reported_at) from public.backup_heartbeats b
--            where b.flow='court' and b.phase='ok') as temoin_reussite,
--          i.closed_at >= (select max(b.reported_at) from public.backup_heartbeats b
--                           where b.flow='court' and b.phase='ok') as ferme_apres_le_succes
--     from public.service_health_incidents i
--    where i.kind='backup' order by i.opened_at desc limit 1;
--
-- `ferme_apres_le_succes` doit valoir TRUE. Avec l'ancienne logique il valait
-- false, et personne ne l'avait regarde.
--
-- ⚠️ LE NETTOYAGE N'EST PAS OPTIONNEL — c'est la moitie de la recette.
--
--    Un depart orphelin injecte et jamais suivi d'un tir REEL epingle l'alarme
--    en position ouverte : par construction, SEULE UNE ARRIVEE referme, et une
--    arrivee ne viendra jamais pour un depart fabrique. L'incident restera donc
--    ouvert indefiniment — et tant qu'un incident `backup` est ouvert, la sonde
--    n'en cree AUCUN autre. Autrement dit : oublier de nettoyer ne laisse pas
--    une ligne en trop, ca REND L'ALARME AVEUGLE aux pannes suivantes.
--
--    C'est le meme piege que l'issue de CI restee ouverte le 20/08 au matin, qui
--    empechait toute nouvelle issue d'etre creee : un dispositif muet ressemble
--    a un dispositif calme.
--
--    Donc, dans cet ordre et sans en sauter :
--      1. refermer par un tir REEL (ci-dessus) ;
--      2. verifier `ferme_apres_le_succes` = TRUE ;
--      3. supprimer la ligne de test PAR SON ID :
--           delete from public.backup_heartbeats where id = <l id note>;
--      4. verifier qu'aucun incident `backup` ne reste ouvert :
--           select id, opened_at from public.service_health_incidents
--            where kind='backup' and closed_at is null;
--         -- doit ne rien rendre.
-- =============================================================================
