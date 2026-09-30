-- =========================================================================
-- L'invitation à une tâche crée une invitation
-- =========================================================================
-- Date     : 2026-09-30
-- Chantier : backlog v34, item F16 (relevé par la carte de la chaîne de
--            courriel, F1, docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md)
--
-- LE CONSTAT. Le bouton « Inviter » d'une tâche interne appelle
-- `fn_task_invite(tâche, adresse)`, qui ajoute l'adresse aux marqueurs (`tags`)
-- de la tâche ; le déclencheur `trg_sync_task_invites_from_task` appelle alors
-- `sync_task_invites_from_task`, qui crée l'invitation et la ligne de file
-- d'envoi pour chaque adresse que `task_invite_emails_from_tags` lui donne.
-- Or cette dernière ne retient que les marqueurs `convite:<adresse>`, et
-- `fn_task_invite` posait l'adresse BRUTE : aucune invitation n'a jamais été
-- créée (`painel_internal_task_invites` : 0 ligne ; file d'invitation : jamais
-- une insertion). L'écran annonçait pourtant « invitation envoyée », et
-- l'adresse finissait affichée parmi les marqueurs de la tâche.
--
-- CE QUE FAIT CETTE MIGRATION. Elle repart de la définition RÉELLE de
-- `fn_task_invite` (pg_get_functiondef) et, par remplacements COMPTÉS, lui fait
-- poser `convite:<adresse>` — la forme que la synchronisation attend — et
-- tester l'idempotence sur cette même forme. Rien d'autre n'est retapé. Les
-- écrans et les courriels n'affichent plus les marqueurs `convite:` (même
-- commit).
--
-- DONNÉES : aucune. `painel_internal_tasks` est vide en production (30/09).
-- =========================================================================

BEGIN;

DO $$
DECLARE
  v_def   text;
  v_n     int;
  v_i     int;
  v_vieux text[] := ARRAY[
    'IF v_email_clean = ANY(v_existing_tags) THEN',
    'v_new_tags := v_existing_tags || ARRAY[v_email_clean];'
  ];
  v_neuf  text[] := ARRAY[
    'IF ''convite:'' || v_email_clean = ANY(COALESCE(v_existing_tags, ''{}''::text[])) THEN',
    'v_new_tags := COALESCE(v_existing_tags, ''{}''::text[]) || ARRAY[''convite:'' || v_email_clean];'
  ];
BEGIN
  SELECT pg_get_functiondef('public.fn_task_invite(uuid, text)'::regprocedure) INTO v_def;
  FOR v_i IN 1 .. array_length(v_vieux, 1) LOOP
    v_n := (length(v_def) - length(replace(v_def, v_vieux[v_i], ''))) / length(v_vieux[v_i]);
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'fn_task_invite : ancre « % » trouvée % fois au lieu de 1 — la fonction a changé, relire avant de migrer',
        v_vieux[v_i], v_n;
    END IF;
  END LOOP;
  FOR v_i IN 1 .. array_length(v_vieux, 1) LOOP
    v_def := replace(v_def, v_vieux[v_i], v_neuf[v_i]);
  END LOOP;
  EXECUTE v_def;
END $$;

-- Vérification : la fonction pose désormais le marqueur que la synchronisation lit.
DO $$
BEGIN
  IF (SELECT prosrc FROM pg_proc WHERE oid = 'public.fn_task_invite(uuid, text)'::regprocedure)
       NOT LIKE '%ARRAY[''convite:'' || v_email_clean]%' THEN
    RAISE EXCEPTION 'fn_task_invite ne pose toujours pas le marqueur convite:';
  END IF;
  IF public.task_invite_emails_from_tags(ARRAY['convite:Essai@Exemple.org', 'urgent']) <> ARRAY['essai@exemple.org'] THEN
    RAISE EXCEPTION 'task_invite_emails_from_tags ne lit plus le marqueur convite:';
  END IF;
END $$;

COMMIT;
