-- =====================================================================
-- AnarBib — Tests d'acceptation : une instance restaurée retrouve ses crons
-- Date    : 2026-09-21  ·  Backlog v34 I26
-- Ref     : migration 20260921193147_une_instance_restauree_retrouve_ses_crons
--
-- Pourquoi cette suite existe : `supabase db dump` n'emporte pas `cron.job`.
-- Une instance restaurée portait zéro job et rien ne le disait.
-- `private.fn_crons_replanifier()` les remet ; `restore.sh` l'appelle. Cette
-- suite la met dans la situation d'une restauration — table des jobs VIDE —
-- et dans les situations voisines. Sur le banc, `cron` est un stub : on
-- éprouve la logique, pas l'exécution des jobs (DOC-SILENCE-1 : le bilan le dit).
--
--   T1 tout en place           → rien n'est replanifié (c'est le cas de la production)
--   T2 table des jobs vidée    → les 38 reviennent, mêmes horaires, mêmes commandes
--   T3 second appel            → rien : la fonction est idempotente
--   T4 un horaire décalé, une commande retouchée, un job désactivé
--                              → ces trois-là seulement sont remis, les 35 autres intouchés
--   T5 un job inattendu        → signalé dans le bilan, PAS supprimé
--   T6 ni anon ni authenticated n'exécutent la fonction ni ne lisent la liste
--   T7 la liste ne porte ni secret littéral ni URL en dur (elle vit au dépôt)
--
--   Bilan OK : 'CRONS-REPLANIFIER OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed   int := 0;
  v_failed   int := 0;
  v_failures text[] := '{}';
  v_t        text;
  v          jsonb;
  v_n        int;
  v_att      int;
  v_ids_avant bigint[];
  v_stub     text;
BEGIN
  SELECT count(*) INTO v_att FROM private.fn_crons_attendus();

  v_t := 'T1 tout en place → rien à faire';
  v := private.fn_crons_replanifier();
  IF (v->>'ok')::boolean AND jsonb_array_length(v->'planifies') = 0
     AND (v->>'deja_en_place')::int = v_att THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T2 table vidée (= restauration) → tout revient à l''identique';
  DELETE FROM cron.job;
  v := private.fn_crons_replanifier();
  SELECT count(*) INTO v_n
    FROM private.fn_crons_attendus() a JOIN cron.job j ON j.jobname::text = a.jobname
   WHERE j.schedule = a.schedule AND j.command = a.command AND j.active IS NOT DISTINCT FROM a.active;
  IF jsonb_array_length(v->'planifies') = v_att AND v_n = v_att
     AND (SELECT count(*) FROM cron.job) = v_att THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/' || v_att || ' conformes — ' || (v - 'planifies')::text); END IF;

  v_t := 'T3 second appel → idempotente';
  v := private.fn_crons_replanifier();
  IF jsonb_array_length(v->'planifies') = 0 AND (v->>'deja_en_place')::int = v_att THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T4 trois jobs abîmés → ces trois-là seulement';
  SELECT array_agg(jobid ORDER BY jobname) INTO v_ids_avant FROM cron.job;
  UPDATE cron.job SET schedule = '1 1 1 1 *'      WHERE jobname = 'anarbib-health-probe';
  UPDATE cron.job SET command  = command || ' -- retouche' WHERE jobname = 'anarbib-rgpd-purge-weekly';
  UPDATE cron.job SET active   = false             WHERE jobname = 'anarbib-notify-loan-cycle-daily';
  v := private.fn_crons_replanifier();
  SELECT count(*) INTO v_n
    FROM private.fn_crons_attendus() a JOIN cron.job j ON j.jobname::text = a.jobname
   WHERE j.schedule = a.schedule AND j.command = a.command AND j.active IS NOT DISTINCT FROM a.active;
  IF jsonb_array_length(v->'planifies') = 3 AND v_n = v_att
     AND (v->'planifies') @> '["anarbib-health-probe","anarbib-rgpd-purge-weekly","anarbib-notify-loan-cycle-daily"]'::jsonb
     -- replanifier un nom existant ne change pas son jobid : l'historique des exécutions reste rattaché
     AND v_ids_avant = (SELECT array_agg(jobid ORDER BY jobname) FROM cron.job)
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/' || v_att || ' — ' || v::text); END IF;

  v_t := 'T5 un job inattendu est signalé, pas supprimé';
  PERFORM cron.schedule('job-que-personne-n-attend', '0 0 1 1 *', 'select 1');
  v := private.fn_crons_replanifier();
  IF (v->'inattendus_laisses_en_place') @> '["job-que-personne-n-attend"]'::jsonb
     AND EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'job-que-personne-n-attend')
     AND jsonb_array_length(v->'planifies') = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T6 fermée à anon et authenticated';
  IF NOT has_function_privilege('anon', 'private.fn_crons_replanifier()', 'execute')
     AND NOT has_function_privilege('authenticated', 'private.fn_crons_replanifier()', 'execute')
     AND NOT has_function_privilege('anon', 'private.fn_crons_attendus()', 'execute')
     AND NOT has_function_privilege('authenticated', 'private.fn_crons_attendus()', 'execute')
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  v_t := 'T7 ni secret littéral ni URL en dur dans la liste';
  SELECT count(*) INTO v_n FROM private.fn_crons_attendus()
   WHERE command ~* '(bearer |sb_secret|eyJ[A-Za-z0-9_-]{10,}|apikey|password|https?://)';
  IF v_n = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' commande(s) suspecte(s)'); END IF;

  v_stub := CASE WHEN to_regprocedure('cron.is_ci_stub()') IS NOT NULL
                 THEN 'interface STUB : la logique est éprouvée, aucun job n''est exécuté'
                 ELSE 'pg_cron réel' END;
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'CRONS-REPLANIFIER OK : %/% tests passés — % jobs attendus ; %', v_passed, v_passed, v_att, v_stub;
  ELSE
    RAISE EXCEPTION 'CRONS-REPLANIFIER ECHEC : % échec(s) sur % — % ; %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | '), v_stub;
  END IF;
END $$;
