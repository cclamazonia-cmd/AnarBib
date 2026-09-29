-- =====================================================================
-- AnarBib — Tests : les fonctions des tâches internes écrivent un état
--                   que la base accepte
-- Date    : 2026-09-29
-- Réf     : 20260929095411_les_fonctions_des_taches_parlent_les_sept_etats.sql
--           20260831073104 (les sept états et leur CHECK, item F6)
--           src/lib/taskStatus.js (la même liste, côté écran)
--
-- CE QUE CETTE SUITE PROUVE, en EMPRUNTANT les chemins : créer une tâche,
-- instancier un modèle, terminer une tâche récurrente (régénération) passent,
-- et la tâche naît `aberta`. Du 31/08 au 29/09 ces trois gestes levaient 23514
-- — aucune suite ne les exécutait, la table était vide, personne ne l'a vu.
-- Un chemin jamais exécuté n'est pas un chemin qui marche.
--
-- Convention : bilan « TACHES-ETATS OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  ok int := 0; total int := 7;
  v_lib uuid; v_task uuid; v_rule uuid; v_inst uuid; v_next uuid;
  v_status text; v_liste text; v_res jsonb; v_flag timestamptz;
BEGIN
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-taches-etats', 'Essai — tâches', true, 'private')
  RETURNING id INTO v_lib;

  -- T1 : plus aucune fonction qui touche la table ne nomme l'ancien état
  SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_liste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('public', 'api', 'ingest', 'private')
     AND p.prosrc ILIKE '%painel_internal_tasks%'
     AND p.prosrc LIKE '%''pendente''%';
  IF v_liste IS NULL THEN ok := ok + 1; ELSE RAISE WARNING 'T1 ancien etat nomme dans : %', v_liste; END IF;

  -- T2 : créer une tâche passe, et elle naît « aberta »
  BEGIN
    v_res := public.fn_task_create(v_lib, 'Désherbage à l''état', 'Retirer les livres en mauvais état.',
                                   'media', 'Essai', current_date + 2, ARRAY['urgent']);
    v_task := (v_res->>'id')::uuid;
    SELECT status INTO v_status FROM public.painel_internal_tasks WHERE id = v_task;
    IF v_status = 'aberta' THEN ok := ok + 1; ELSE RAISE WARNING 'T2 etat % au lieu de aberta', v_status; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'T2 fn_task_create a leve : % (%)', SQLERRM, SQLSTATE;
  END;

  -- T3 : instancier un modèle récurrent passe, la tâche naît « aberta » et porte sa série
  BEGIN
    INSERT INTO public.painel_recurring_task_rules
      (library_id, template_title, template_priority, interval_count, interval_unit, is_active)
    VALUES (v_lib, 'Rangement des retours', 'media', 1, 'semana', true)
    RETURNING id INTO v_rule;
    v_res := public.fn_task_instantiate_template(v_rule, current_date - 10);
    v_inst := (v_res->>'id')::uuid;
    SELECT status INTO v_status FROM public.painel_internal_tasks
     WHERE id = v_inst AND recurrence_rule_id = v_rule;
    IF v_status = 'aberta' THEN ok := ok + 1; ELSE RAISE WARNING 'T3 etat % au lieu de aberta', v_status; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'T3 fn_task_instantiate_template a leve : % (%)', SQLERRM, SQLSTATE;
  END;

  -- T4 : la sonde des récurrences en souffrance voit une tâche BLOQUÉE en retard
  --      (l'ancien filtre ne connaissait que deux états, dont un qui n'existe plus)
  BEGIN
    PERFORM public.fn_task_update_status(v_inst, 'bloqueada');
    PERFORM * FROM public.fn_cron_tasks_detect_stale_recurrence();
    SELECT recurrence_stale_flagged_at INTO v_flag FROM public.painel_internal_tasks WHERE id = v_inst;
    IF v_flag IS NOT NULL THEN ok := ok + 1; ELSE RAISE WARNING 'T4 tache bloquee en retard non signalee'; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'T4 a leve : % (%)', SQLERRM, SQLSTATE;
  END;

  -- T5 : terminer une tâche récurrente la régénère, et la suivante naît « aberta »
  BEGIN
    v_res := public.fn_task_update_status(v_inst, 'concluida');
    v_next := (v_res->'recurrence_regenerated'->>'next_task_id')::uuid;
    SELECT status INTO v_status FROM public.painel_internal_tasks WHERE id = v_next;
    IF v_next IS NOT NULL AND v_status = 'aberta' THEN ok := ok + 1;
    ELSE RAISE WARNING 'T5 regeneration : id %, etat %', v_next, v_status; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'T5 fn_task_update_status a leve : % (%)', SQLERRM, SQLSTATE;
  END;

  -- T6 : les sept états passent par la fonction de changement d'état
  BEGIN
    FOREACH v_status IN ARRAY ARRAY['a_fazer','em_andamento','bloqueada','cancelada','arquivada','aberta','concluida'] LOOP
      PERFORM public.fn_task_update_status(v_task, v_status);
    END LOOP;
    SELECT status INTO v_status FROM public.painel_internal_tasks WHERE id = v_task;
    IF v_status = 'concluida' THEN ok := ok + 1; ELSE RAISE WARNING 'T6 etat final %', v_status; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'T6 un etat du cycle est refuse : % (%)', SQLERRM, SQLSTATE;
  END;

  -- T7 : l'ancien état reste refusé par la base
  BEGIN
    PERFORM public.fn_task_update_status(v_task, 'pendente');
    RAISE WARNING 'T7 : pendente est passe';
  EXCEPTION WHEN check_violation THEN ok := ok + 1;
  END;

  IF ok = total THEN
    RAISE NOTICE 'TACHES-ETATS OK : %/% tests passés', ok, total;
  ELSE
    RAISE EXCEPTION 'TACHES-ETATS ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
