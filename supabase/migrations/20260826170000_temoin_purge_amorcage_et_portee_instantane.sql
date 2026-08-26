-- =============================================================================
-- Temoin de vie : retirer les semis devenus inutiles, et dire ce que
-- `snapshot_id` prouve
-- =============================================================================
-- Date     : 2026-08-26
-- Chantier : chaine de bascule auto-hebergee (#BG2-16, suite)
--
-- ETAT MESURE LE 26/08/2026, en base, avant d'ecrire une ligne :
--
--   flow    | dernier temoin 'ok'      | host      | snapshot_id
--   --------+--------------------------+-----------+------------
--   court   | 26/08 07:36:38 UTC       | ACCATTONE | 4359105d
--   long    | 26/08 07:35:43 UTC       | ACCATTONE | 5740d6a6
--   storage | 26/08 07:48:49 UTC       | ACCATTONE | 3a36373d
--
-- Les DEUX conditions posees le 20/08 pour purger sont donc remplies, et c'est
-- la seule raison pour laquelle cette migration existe maintenant et pas avant :
--
--   1. `host` est expose depuis 20260820012343 -- fait, rien a refaire ici ;
--   2. un temoin REEL, venu d'ACCATTONE, existe desormais pour `long` et pour
--      `storage` (ils n'en avaient aucun le 20/08). Les retirer plus tot aurait
--      declenche une alerte FAUSSE : les flux tournaient, ils n'avaient
--      simplement pas encore parle.
--
-- CE QUE FAIT CETTE MIGRATION
--
-- 1. Elle supprime les lignes d'amorcage des flux qui ont un temoin reel.
--    Le predicat est GENERIQUE (tout flux ayant un 'ok' reel), pas une liste
--    d'identifiants : rejouee sur une base reconstruite ou les temoins reels
--    n'existent pas encore, elle ne supprime rien et ne casse rien. C'est ce
--    qui la rend sure dans les deux ordres de rejeu -- voir l'avertissement
--    d'ordre en tete de 20260820012343.
--
--    Depuis 20260820012343 la fonction IGNORE deja les semis des qu'un temoin
--    reel existe : la suppression ne change donc AUCUN comportement d'alarme.
--    Elle retire une donnee qui ment a la lecture directe de la table -- le
--    genre de ligne qu'on relit un jour de restauration, en croyant qu'un tir
--    a eu lieu le 19/08 a 14:53.
--
-- 2. Elle expose `instantane_atteste`. C'est la reponse a la question laissee
--    ouverte le 20/08 (remplir snapshot_id, ou documenter sa portee ?) : il est
--    REMPLI depuis BG2-15 par `snapshot_id_de()` dans anarbib-bg2.sh, qui relit
--    le depot restic apres le tir. Restait a rendre visible le jour ou il
--    cesserait de l'etre -- un `restic snapshots` muet, un depot injoignable a
--    la relecture -- car la fonction, elle, n'y verrait rien : le temoin
--    partirait quand meme, `ok` resterait vrai, et l'information se perdrait
--    jusqu'au jour de la restauration.
--
--    Informatif, comme `temoin_amorcage` : NE BASCULE PAS `ok`. Un instantane
--    non atteste n'est pas une panne de sauvegarde, c'est un angle mort -- et
--    on n'apprend pas aux gens a ignorer une alarme.
--
-- PORTEE EXACTE DU TEMOIN, puisque c'est ce qu'on documente ici :
--   - il prouve que le script est alle au bout de son flux ;
--   - avec `snapshot_id`, il prouve en plus qu'un instantane portant cette
--     etiquette etait LISTABLE dans le depot restic juste apres le tir ;
--   - il ne prouve PAS que cet instantane est RESTAURABLE. Seul le
--     `restore-test` mensuel le prouve. Ne jamais lire un temoin vert comme
--     une garantie de restauration.
--   - une ligne `phase='started'` porte legitimement `snapshot_id` a NULL :
--     au depart, l'instantane n'existe pas encore.
--
-- Compatible avec health-probe sans changement : il lit `ok`, `flux[].muet`,
-- `.flow`, `.age_heures`, `.raison`, `.interrompu` et `.temoin_amorcage`, tous
-- conserves a l'identique.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Purge des semis dont le flux a parle pour de vrai
-- -----------------------------------------------------------------------------
do $purge$
declare
  v_supprimees int;
begin
  delete from public.backup_heartbeats a
   where coalesce(a.host, '') = 'amorcage-migration'
     and exists (
       select 1
         from public.backup_heartbeats b
        where b.flow = a.flow
          and b.phase = 'ok'
          and coalesce(b.host, '') <> 'amorcage-migration'
     );
  get diagnostics v_supprimees = row_count;
  raise notice 'temoin : % ligne(s) d''amorcage supprimee(s).', v_supprimees;
end
$purge$;

-- -----------------------------------------------------------------------------
-- 2. Le statut expose `instantane_atteste`
-- -----------------------------------------------------------------------------
-- Corps repris a l'IDENTIQUE de 20260821050000_temoin_depart_orphelin, seule la
-- cle `instantane_atteste` s'ajoute. La logique d'orphelin (seule une arrivee
-- referme) et le seuil de 60 min, qui est le DOUBLE du TimeoutStartSec=1800 des
-- unites systemd, sont inchanges : ces deux nombres bougent ensemble ou pas du
-- tout.
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
              -- Informatif, ne bascule pas `ok` : dit si le dernier temoin
              -- d'arrivee retenu porte un identifiant d'instantane restic.
              'instantane_atteste', (j.snapshot_id is not null),
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

comment on function public.fn_backup_heartbeat_status() is
  'Etat des trois flux de sauvegarde. Le silence se calcule sur le dernier temoin REEL '
  '(phase ok, host <> amorcage-migration). `interrompu` signale un depart ORPHELIN de plus '
  'de 60 min : seule une arrivee referme. `temoin_amorcage` et `instantane_atteste` sont '
  'INFORMATIFS et ne basculent pas `ok`. PORTEE : un temoin vert prouve que le script est '
  'alle au bout, et si `snapshot_id` est present qu''un instantane etait listable dans le '
  'depot restic juste apres le tir. Il ne prouve PAS qu''il est restaurable : seul le '
  'restore-test mensuel le prouve.';

-- -----------------------------------------------------------------------------
-- 3. Verification
-- -----------------------------------------------------------------------------
-- On verifie la STRUCTURE et la coherence de la purge, PAS que `ok` vaut true.
-- Une migration qui exige `ok` se retourne contre nous le jour ou on rejoue le
-- depot sur une base restauree depuis un dump ancien : les temoins y sont
-- vieux, `ok` est faux a bon droit, et la reconstruction s'arreterait sur une
-- alarme qui fait exactement son travail. Voir 20260821050000, qui porte cette
-- assertion -- sans danger la ou elle est (elle s'execute apres l'amorcage, sur
-- des temoins frais), mais a ne pas reproduire.
do $verif$
declare
  v jsonb;
  v_reste int;
begin
  v := public.fn_backup_heartbeat_status();

  if v is null or not (v ? 'flux') then
    raise exception 'fn_backup_heartbeat_status ne repond plus';
  end if;
  if not (v -> 'flux' -> 0 ? 'instantane_atteste') then
    raise exception 'le champ instantane_atteste n''est pas expose';
  end if;
  -- Non-regression : les champs dont health-probe depend.
  if not (v -> 'flux' -> 0 ? 'orphelin_depuis')
     or not (v -> 'flux' -> 0 ? 'temoin_amorcage')
     or not (v -> 'flux' -> 0 ? 'host')
     or not (v -> 'flux' -> 0 ? 'muet')
     or not (v -> 'flux' -> 0 ? 'interrompu')
     or not (v -> 'flux' -> 0 ? 'raison') then
    raise exception 'un champ consomme par health-probe a disparu du statut';
  end if;

  -- Aucun semis ne doit survivre sur un flux qui a un temoin reel.
  select count(*) into v_reste
    from public.backup_heartbeats a
   where coalesce(a.host,'') = 'amorcage-migration'
     and exists (select 1 from public.backup_heartbeats b
                  where b.flow = a.flow and b.phase = 'ok'
                    and coalesce(b.host,'') <> 'amorcage-migration');
  if v_reste > 0 then
    raise exception 'purge incomplete : % semis subsistent sur un flux ayant un temoin reel', v_reste;
  end if;
end
$verif$;

commit;

-- =============================================================================
-- CONTROLE APRES DEPLOIEMENT
-- =============================================================================
--   select jsonb_pretty(public.fn_backup_heartbeat_status());
--
-- Attendu : ok = true, trois flux, `temoin_amorcage` = false PARTOUT (c'est le
-- changement visible : plus aucun flux tenu en vert par un semis), et
-- `instantane_atteste` = true partout tant que restic reste relisible.
--
--   select flow, phase, host, snapshot_id, reported_at
--     from public.backup_heartbeats
--    where coalesce(host,'') = 'amorcage-migration';
--   -- doit ne rien rendre.
--
-- EPROUVER `instantane_atteste` sans rien casser -- insertion d'un temoin
-- d'arrivee sans instantane, retiree PAR SON ID (jamais par un etat, cf. la
-- lecon de 20260821050000) :
--
--   insert into public.backup_heartbeats (flow, host, phase)
--   values ('court', 'ACCATTONE', 'ok') returning id;   -- <- NOTER CET ID
--   select public.fn_backup_heartbeat_status();
--   -- 'court' doit passer instantane_atteste = false, ok doit RESTER true.
--   delete from public.backup_heartbeats where id = <l id note>;
-- =============================================================================
