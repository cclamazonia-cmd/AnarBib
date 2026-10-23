-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — la purge de rétention tourne chaque dimanche (23/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- Activation de RET-2/RET-3, décidée par Xavier le 23/10 après l'essai à blanc
-- en production (20 h 11 UTC : 28 courriers sortants de plus de 90 jours et
-- 3 notifications du réseau lues depuis plus de 90 jours, rien d'autre).
--
-- Le job anarbib-rgpd-purge-weekly garde son nom et son horaire (dimanche,
-- 3 h UTC) ; sa commande passe de fn_purge_expired_data à fn_purge_retention,
-- qui couvre tout ce que la première purgeait (toutes les bibliothèques, plus
-- seulement les actives) et les familles de RET-3. fn_purge_expired_data reste
-- en base, appelée par rien : le retour arrière tient dans
-- _rollback_20261023201346_la_purge_de_retention_tourne_chaque_dimanche.sql.
--
-- La liste des crons attendus (private.fn_crons_attendus, I26) suit, par le
-- procédé de 20261003202521 : empreinte relevée en production le 23/10, ancre
-- comptée, une ligne remplacée.
--
-- Tests : tests/sql/retention_plafonds_purge_tests.sql (T14 : le cron appelle
-- la nouvelle purge, plus l'ancienne) ; tests/sql/crons_planifies_tests.sql
-- (nom, horaire, état et fonction appelée).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

DO $cron$
DECLARE v_jobid bigint;
BEGIN
  v_jobid := cron.schedule(
    'anarbib-rgpd-purge-weekly',
    '0 3 * * 0',
    ' SELECT public.fn_purge_retention(p_dry_run := false); '
  );
  RAISE NOTICE 'Job cron anarbib-rgpd-purge-weekly mis à jour (fn_purge_retention), jobid=%.', v_jobid;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Job cron NON mis à jour (cron indisponible ici ?) : %. À vérifier en prod.', SQLERRM;
END;
$cron$;

DO $mig$
DECLARE
  v_def   text;
  v_n     int;
  v_ancre text := $a$    ('anarbib-rgpd-purge-weekly', '0 3 * * 0', $c$ SELECT public.fn_purge_expired_data(p_dry_run := false); $c$, true),$a$;
  v_ligne text := $b$    ('anarbib-rgpd-purge-weekly', '0 3 * * 0', $c$ SELECT public.fn_purge_retention(p_dry_run := false); $c$, true),$b$;
BEGIN
  IF (SELECT md5(replace(prosrc, E'\r', '')) FROM pg_proc
       WHERE oid = 'private.fn_crons_attendus()'::regprocedure)
     <> '250767182dbaec8f0d6648ff2b86be59' THEN
    RAISE EXCEPTION 'Rétention : private.fn_crons_attendus a changé depuis le relevé du 23/10 — relire avant de réécrire';
  END IF;
  v_def := replace(pg_get_functiondef('private.fn_crons_attendus()'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN RAISE EXCEPTION 'Rétention : ancre de fn_crons_attendus trouvée % fois (1 attendue)', v_n; END IF;
  EXECUTE replace(v_def, v_ancre, v_ligne);
END
$mig$;

-- ─── Garde ─────────────────────────────────────────────────────────────────
DO $garde$
BEGIN
  IF (SELECT count(*) FROM private.fn_crons_attendus()) <> 43 THEN
    RAISE EXCEPTION 'Rétention : fn_crons_attendus doit porter 43 jobs';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM private.fn_crons_attendus()
                  WHERE jobname = 'anarbib-rgpd-purge-weekly' AND command ILIKE '%fn_purge_retention(p_dry_run := false)%')
     OR EXISTS (SELECT 1 FROM private.fn_crons_attendus() WHERE command ILIKE '%fn_purge_expired_data%') THEN
    RAISE EXCEPTION 'Rétention : fn_crons_attendus n''appelle pas la nouvelle purge (ou appelle encore l''ancienne)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM cron.job j JOIN private.fn_crons_attendus() a ON a.jobname = j.jobname::text
                  WHERE j.jobname = 'anarbib-rgpd-purge-weekly' AND j.command = a.command
                    AND j.schedule = a.schedule AND j.active) THEN
    RAISE EXCEPTION 'Rétention : le cron anarbib-rgpd-purge-weekly ne correspond pas à fn_crons_attendus';
  END IF;
END;
$garde$;

COMMIT;
