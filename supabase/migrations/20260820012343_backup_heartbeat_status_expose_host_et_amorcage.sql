-- Temoin de sauvegarde : exposer l'hote, et cesser de compter les lignes d'amorcage.
--
-- ⚠️ ORDRE DE REJEU — LIRE AVANT DE TOUCHER A CE FICHIER.
-- Ce fichier porte un numero a l'HEURE REELLE (01:23 UTC). La migration qui
-- CREE la table `backup_heartbeats` et definit la fonction pour la premiere
-- fois, 20260820100000_temoin_de_vie_sauvegardes, porte un numero AVANCE A LA
-- MAIN (10:00). Au rejeu depuis le depot, elle s'execute donc APRES ce fichier.
--
-- Deux consequences, toutes deux traitees :
--
--   1. La table n'existe pas encore quand ce fichier passe. Une fonction
--      `language sql` est validee A SA CREATION : referencer une table absente
--      echoue immediatement. D'ou la garde `to_regclass` ci-dessous et le
--      passage par `execute`. Sans elle, toute reconstruction depuis le depot
--      s'arrete ici — constate le 2026-08-20 en rejouant la CI a blanc.
--
--   2. Meme gardee, cette version serait ensuite ECRASEE par 100000. La version
--      definitive a donc ete reportee la-bas : les deux fichiers posent la meme
--      definition, et l'etat final est correct dans les deux ordres possibles.
--
-- En production, ce fichier a bien fait son office : la table existait deja.
--
-- CONSTAT (PLAN_DE_MARCHE §7.1, mesure le 2026-08-20).
-- fn_backup_heartbeat_status() calculait le silence par max(reported_at) PAR
-- FLUX, sans regarder l'hote. Or au 20/08 :
--
--   court   | ACCATTONE            | temoin REEL
--   court   | amorcage-migration   | ligne de semis
--   long    | amorcage-migration   | ligne de semis SEULE
--   storage | amorcage-migration   | ligne de semis SEULE
--
-- `long` et `storage` etaient tenus en VERT par une ligne de semis posee par la
-- migration d'amorcage, alors qu'aucun tir reel n'a jamais rien signale pour
-- eux. L'alarme n'etait pas cassee : elle etait aveugle. Pire, ces deux lignes
-- ont ete RAFRAICHIES le 19/08 a 14:53, remettant le compteur a zero :
-- l'echeance du ~28/08 sur laquelle le plan comptait n'existait plus.
--
-- DEUX CORRECTIONS
--
-- 1. `vu_le` ignore les lignes d'amorcage DES QU'UN TEMOIN REEL existe pour le
--    flux : la purge demandee par le plan, mais automatique et sans perte de
--    donnee. On ne SUPPRIME pas les semis de `long` et `storage` — aucun temoin
--    reel n'existe encore pour eux, et les retirer declencherait une alerte
--    « les sauvegardes sont muettes » FAUSSE : les flux tournent, ils n'ont
--    simplement pas encore parle. Le semis de `court` est supprime : son temoin
--    reel existe.
--
-- 2. Le statut expose `host`, `temoin_amorcage` et `snapshot_id`.
--    `temoin_amorcage` rend l'angle mort VISIBLE sans basculer `ok` — sinon on
--    declencherait une alerte fausse sur deux flux qui fonctionnent. Meme
--    doctrine que fn_healthcheck_notifications. `snapshot_id` est expose parce
--    qu'il est NUL sur les 5 lignes : le temoin prouve que le script est alle au
--    bout, pas qu'un instantane existe dans le depot restic.
--
-- Compatible avec health-probe sans changement : il ne lit que `ok`,
-- `flux[].muet`, `.flow` et `.age_heures`, tous conserves.
do $mig$
begin
  if to_regclass('public.backup_heartbeats') is null then
    raise notice
      'backup_heartbeats absent : correctif du temoin NON applique ici. Attendu au rejeu depuis le depot (la table est creee par 20260820100000, numerote plus tard). Cette migration-la porte la meme definition definitive.';
    return;
  end if;

  execute $ddl$
    create or replace function public.fn_backup_heartbeat_status()
    returns jsonb
    language sql
    stable
    security definer
    set search_path to 'public', 'pg_temp'
    as $fn$
      with seuils(flow, seuil) as (
        values ('court',   interval '36 hours'),
               ('long',    interval '9 days'),
               ('storage', interval '9 days')
      ),
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
    $fn$;
  $ddl$;

  execute $c$
    comment on function public.fn_backup_heartbeat_status() is
      'Etat des trois flux de sauvegarde. Le silence est calcule sur le dernier temoin REEL : une ligne d''amorcage (host = amorcage-migration) cesse de compter des qu''un vrai tir a signale pour ce flux. `temoin_amorcage` signale un flux tenu en vert par un semis — informatif, ne bascule pas `ok`. `snapshot_id` est expose car un temoin prouve que le script est alle au bout, pas qu''un instantane existe dans le depot restic.';
  $c$;

  -- Purge de la ligne d'amorcage de `court` : son temoin reel existe.
  delete from public.backup_heartbeats
   where coalesce(host,'') = 'amorcage-migration'
     and flow = 'court'
     and exists (select 1 from public.backup_heartbeats b2
                  where b2.flow = 'court' and coalesce(b2.host,'') <> 'amorcage-migration');
end
$mig$;
