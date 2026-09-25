-- =====================================================================
-- AnarBib — Tests : une migration appliquée hors de la CI ouvre un incident (I22)
-- Date    : 2026-09-25
-- Réf     : supabase/migrations/20260925082749_i22_une_migration_hors_ci_ouvre_un_incident.sql
--           REGISTRE DOC-DEPLOY-1 (« interdire et contrôler », 25/09)
--
-- CE QUE CETTE SUITE PROUVE.
--   Sans journal des migrations (base neuve du banc), la sonde dit « sans_objet »
--   et reste verte ; avec un journal qui note l'auteur, une version signée et non
--   acquittée la rend rouge et figure au bilan SANS son auteur ; une version de la
--   CI (auteur nul) ne compte pas ; l'acquittement la fait sortir ; un motif trop
--   court est refusé ; les écarts antérieurs sont acquittés nommément ; la table
--   n'est lisible que d'un admin réseau ; la sonde est fermée à anon et
--   authenticated ; la CHECK des incidents admet « deploiement ».
-- CE QU'ELLE NE PROUVE PAS.
--   Que la plateforme remplisse bien created_by pour l'API de gestion : constaté
--   sur la production le 25/09 (voir l'en-tête de la migration), pas simulable ici.
--
-- Convention : bilan « DEPLOIEMENT OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  ok int := 0; total int := 9;
  v_bilan jsonb; v_n int;
  v_admin uuid := '11111111-1111-1111-1111-111111111111';  -- compte du seed, fait admin réseau en T7
  v_autre uuid := gen_random_uuid();
BEGIN
  -- T1 : sans colonne created_by, « sans_objet » et vert (le banc n'a pas de journal ;
  --      en local, le journal de la CLI n'a pas la colonne)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'supabase_migrations' AND table_name = 'schema_migrations'
                    AND column_name = 'created_by') THEN
    v_bilan := public.fn_healthcheck_deploiement();
    IF (v_bilan->>'ok')::boolean AND v_bilan->>'controle' = 'sans_objet' THEN ok := ok + 1;
    ELSE RAISE WARNING 'T1 : bilan sans journal = %', v_bilan; END IF;
  ELSE
    ok := ok + 1;   -- journal de la plateforme déjà là : T2-T4 couvrent le cas actif
  END IF;

  -- Un journal comme celui de la plateforme, le temps de la suite (ROLLBACK)
  CREATE SCHEMA IF NOT EXISTS supabase_migrations;
  CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations (version text PRIMARY KEY, statements text[], name text);
  ALTER TABLE supabase_migrations.schema_migrations ADD COLUMN IF NOT EXISTS created_by text;
  INSERT INTO supabase_migrations.schema_migrations (version, name, created_by) VALUES
    ('29990101000001', 'appliquee_par_mcp', 'quelquun@exemple.test'),
    ('29990101000002', 'appliquee_par_la_ci', NULL);

  -- T2 : une version signée et non acquittée rend la sonde rouge, et elle seule
  v_bilan := public.fn_healthcheck_deploiement();
  IF (v_bilan->>'ok')::boolean = false AND v_bilan->>'controle' = 'actif'
     AND v_bilan->'ecarts_non_acquittes' @> '[{"version":"29990101000001","nom":"appliquee_par_mcp"}]'
     AND NOT v_bilan->'ecarts_non_acquittes' @> '[{"version":"29990101000002"}]' THEN ok := ok + 1;
  ELSE RAISE WARNING 'T2 : bilan = %', v_bilan; END IF;

  -- T3 : le bilan (qui part par courriel) ne porte jamais l'auteur
  IF position('quelquun@exemple.test' in v_bilan::text) = 0 THEN ok := ok + 1;
  ELSE RAISE WARNING 'T3 : l''auteur figure au bilan'; END IF;

  -- T4 : l'acquittement fait sortir la version, la sonde repasse au vert
  INSERT INTO public.deploiement_ecarts_acquittes (version, motif)
  VALUES ('29990101000001', 'Écart de banc, acquitté par la suite deploiement_tests.');
  v_bilan := public.fn_healthcheck_deploiement();
  IF (v_bilan->>'ok')::boolean AND jsonb_array_length(v_bilan->'ecarts_non_acquittes') = 0 THEN ok := ok + 1;
  ELSE RAISE WARNING 'T4 : bilan après acquittement = %', v_bilan; END IF;

  -- T5 : « ok » n'est pas un motif
  BEGIN
    INSERT INTO public.deploiement_ecarts_acquittes (version, motif) VALUES ('29990101000003', 'ok');
    RAISE WARNING 'T5 : motif de deux lettres accepté';
  EXCEPTION WHEN check_violation THEN ok := ok + 1;
  END;

  -- T6 : les écarts antérieurs sont acquittés nommément, les deux relevés le 25/09 compris
  SELECT count(*) INTO v_n FROM public.deploiement_ecarts_acquittes
   WHERE version IN ('20260820012343','20260820012512','20260820022615','20260820145716','20260820163045',
                     '20260820165002','20260831124714','20260831124757','20260831124823','20260904095317',
                     '20260907172508','20260922185953','20260924180538');
  IF v_n = 13 THEN ok := ok + 1; ELSE RAISE WARNING 'T6 : % écart(s) antérieur(s) acquitté(s) sur 13', v_n; END IF;

  -- T7 : la table n'est lisible que d'un admin réseau
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*) INTO v_n FROM public.deploiement_ecarts_acquittes;
  EXECUTE 'RESET ROLE';
  IF v_n = 0 THEN
    INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.deploiement_ecarts_acquittes;
    EXECUTE 'RESET ROLE';
    IF v_n >= 14 THEN ok := ok + 1; ELSE RAISE WARNING 'T7 : l''admin réseau lit % ligne(s)', v_n; END IF;
  ELSE RAISE WARNING 'T7 : un compte ordinaire lit % ligne(s)', v_n; END IF;

  -- T8 : droits — sonde fermée à anon et authenticated, table fermée à anon, pas d'écriture pour personne
  IF NOT has_function_privilege('anon', 'public.fn_healthcheck_deploiement()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_healthcheck_deploiement()', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.fn_healthcheck_deploiement()', 'EXECUTE')
     AND NOT has_table_privilege('anon', 'public.deploiement_ecarts_acquittes', 'SELECT')
     AND NOT has_table_privilege('authenticated', 'public.deploiement_ecarts_acquittes', 'INSERT')
     AND NOT has_table_privilege('service_role', 'public.deploiement_ecarts_acquittes', 'INSERT') THEN ok := ok + 1;
  ELSE RAISE WARNING 'T8 : droits inattendus'; END IF;

  -- T9 : la CHECK des incidents admet « deploiement » (health-probe l'insère)
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_health_incidents_kind_check'
                AND pg_get_constraintdef(oid) LIKE '%''deploiement''%') THEN ok := ok + 1;
  ELSE RAISE WARNING 'T9 : la CHECK ignore deploiement'; END IF;

  IF ok = total THEN
    RAISE NOTICE 'DEPLOIEMENT OK : %/% tests passés — sans journal vert, version signée rouge et sans auteur, CI ignorée, acquittement motivé, antérieurs acquittés, lecture admin, droits, CHECK', ok, total;
  ELSE
    RAISE EXCEPTION 'DEPLOIEMENT ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
