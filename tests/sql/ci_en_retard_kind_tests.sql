-- =====================================================================
-- AnarBib — Tests : le kind « ci_en_retard » est admis par la base (A3)
-- Date    : 2026-09-28
-- Réf     : 20260928095045_a3_la_ci_en_retard_ouvre_un_incident.sql
--           supabase/functions/_shared/ci/forgejo-tasks.ts (la règle)
--           src/tests/health-probe-kinds-check.test.js (lit le texte de la migration)
--
-- CE QUE CETTE SUITE PROUVE, contre la base et non contre un fichier : une
-- insertion sous ce kind passe, et un kind inconnu est refusé. La garde vitest
-- lit la dernière CHECK dans les migrations ; ici on l'exerce.
--
-- Convention : bilan « CI-EN-RETARD OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

DO $$
DECLARE ok int := 0; total int := 3; v_id bigint;
BEGIN
  -- 1. le kind est admis
  INSERT INTO public.service_health_incidents (kind, reason)
  VALUES ('ci_en_retard', 'essai : une tâche en attente depuis plus de 120 min')
  RETURNING id INTO v_id;
  IF v_id IS NOT NULL THEN ok := ok + 1; ELSE RAISE WARNING 'T1 insertion sans id'; END IF;

  -- 2. un kind inconnu est refusé par la CHECK
  BEGIN
    INSERT INTO public.service_health_incidents (kind, reason) VALUES ('ci_inconnu', 'essai');
    RAISE WARNING 'T2 : un kind inconnu est passé';
  EXCEPTION WHEN check_violation THEN ok := ok + 1;
  END;

  -- 3. la CHECK garde les kinds antérieurs (deploiement, capas_sources)
  IF (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'service_health_incidents_kind_check')
     LIKE '%deploiement%' THEN ok := ok + 1; ELSE RAISE WARNING 'T3 : deploiement absent de la CHECK'; END IF;

  IF ok = total THEN
    RAISE NOTICE 'CI-EN-RETARD OK : %/% tests passés', ok, total;
  ELSE
    RAISE EXCEPTION 'CI-EN-RETARD ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
