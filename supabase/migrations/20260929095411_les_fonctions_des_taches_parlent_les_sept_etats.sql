-- =========================================================================
-- Les fonctions des tâches internes parlent les sept états
-- =========================================================================
-- Date     : 2026-09-29
-- Chantier : tâches internes — suite de l'item F6 (migration 20260831073104)
--
-- LE CONSTAT. Le 31/08, la colonne `painel_internal_tasks.status` a reçu les
-- sept états du cycle de vie (aberta, a_fazer, em_andamento, bloqueada,
-- concluida, cancelada, arquivada), une CHECK pour les tenir, et `aberta` pour
-- défaut. La table était vide : « aucun écran à migrer, aucun risque ». Mais
-- cinq fonctions écrivaient ou filtraient encore `pendente`, l'ancien défaut :
--
--   fn_task_create                       INSERT … 'pendente'      → 23514
--   fn_task_instantiate_template         INSERT … 'pendente'      → 23514
--   fn_task_update_status                régénération 'pendente'  → 23514
--   fn_notify_fonds_deposit_received     INSERT … 'pendente'      → 23514
--   fn_cron_tasks_detect_stale_recurrence  status IN ('pendente','em_andamento')
--
-- Depuis le 31/08, AUCUNE tâche ne pouvait donc être créée, ni à la main, ni
-- depuis un modèle, ni par l'arrivée d'un lot de fonds ; et une tâche récurrente
-- passée à « terminée » aurait levé au lieu de se régénérer. Personne ne l'a vu
-- pendant quatre semaines : la table était vide, et elle l'est restée. Constat de
-- Xavier à l'écran le 29/09 (« Tâche impossible à créer », 23514).
--
-- CE QUE FAIT CETTE MIGRATION. Elle repart de la définition RÉELLE de chaque
-- fonction (pg_get_functiondef), y remplace le mot par remplacements COMPTÉS,
-- et la recrée — droits, options et corps conservés, rien n'est retapé :
--   · les quatre écritures prennent `aberta`, l'état d'entrée du cycle ;
--   · la sonde des récurrences en souffrance regarde les quatre états VIVANTS
--     (aberta, a_fazer, em_andamento, bloqueada) — une tâche bloquée depuis
--     dix jours est en souffrance, et l'ancien filtre l'aurait ignorée.
-- Un compte inattendu arrête tout : la fonction a changé depuis la lecture.
--
-- DONNÉES : aucune. La table est vide en production (0 ligne au 29/09).
-- =========================================================================

BEGIN;

DO $$
DECLARE
  r record;
  v_def text;
  v_n int;
  v_attendu int;
  v_vieux text;
  v_neuf text;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_task_create', 'fn_task_instantiate_template',
                         'fn_task_update_status', 'fn_notify_fonds_deposit_received',
                         'fn_cron_tasks_detect_stale_recurrence')
     ORDER BY p.proname
  LOOP
    v_def := pg_get_functiondef(r.oid);
    IF r.proname = 'fn_cron_tasks_detect_stale_recurrence' THEN
      v_vieux := $v$('pendente', 'em_andamento')$v$;
      v_neuf  := $v$('aberta', 'a_fazer', 'em_andamento', 'bloqueada')$v$;
      v_attendu := 2;
    ELSE
      v_vieux := $v$'pendente'$v$;
      v_neuf  := $v$'aberta'$v$;
      v_attendu := 1;
    END IF;
    v_n := (length(v_def) - length(replace(v_def, v_vieux, ''))) / length(v_vieux);
    IF v_n <> v_attendu THEN
      RAISE EXCEPTION '% : % occurrence(s) de % au lieu de % — la fonction a change, relire avant de migrer',
        r.proname, v_n, v_vieux, v_attendu;
    END IF;
    v_def := replace(v_def, v_vieux, v_neuf);
    IF position('pendente' in v_def) > 0 THEN
      RAISE EXCEPTION '% : le mot reste dans la definition apres remplacement', r.proname;
    END IF;
    EXECUTE v_def;
  END LOOP;
END $$;

-- -------------------------------------------------------------------------
-- Vérification (doctrine) : les cinq fonctions existent, et plus aucune
-- fonction qui touche la table ne nomme l'ancien état.
-- -------------------------------------------------------------------------
DO $$
DECLARE v_n int; v_liste text;
BEGIN
  SELECT count(*) INTO v_n
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_task_create', 'fn_task_instantiate_template',
                       'fn_task_update_status', 'fn_notify_fonds_deposit_received',
                       'fn_cron_tasks_detect_stale_recurrence');
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'cinq fonctions attendues, % trouvees', v_n;
  END IF;

  SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_liste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('public', 'api', 'ingest', 'private')
     AND p.prosrc ILIKE '%painel_internal_tasks%'
     AND p.prosrc LIKE '%''pendente''%';
  IF v_liste IS NOT NULL THEN
    RAISE EXCEPTION 'l ancien etat reste nomme dans : %', v_liste;
  END IF;
END $$;

COMMIT;
