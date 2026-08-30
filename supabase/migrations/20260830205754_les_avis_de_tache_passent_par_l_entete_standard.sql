-- =========================================================================
-- Paquet F6 (temps 2) — les avis de tâche passent par l'en-tête standard
-- =========================================================================
-- Date     : 2026-08-30
-- Chantier : réunification de la pile courriel de notify-internal-task
-- Ref       : backlog v34 item F6
--
-- POURQUOI, ET POURQUOI SEUL
--
-- `notify-internal-task` tourne sur une copie privée de la pile courriel. Son
-- `authorizeWebhook` accepte DEUX en-têtes — `x-task-invite-secret` ou
-- `x-webhook-secret` — là où le module canonique n'accepte que le second. Les
-- deux expéditeurs SQL (`dispatch_task_notification_outbox` et
-- `dispatch_task_invitation_outbox`) envoient le premier, jamais l'autre :
-- brancher la fonction sur le canonique sans rien d'autre rendrait 401 sur
-- chaque avis.
--
-- Ce paquet aligne donc les expéditeurs AVANT, et rien d'autre. Il est sans
-- effet aujourd'hui : la fonction déployée accepte encore les deux en-têtes.
-- C'est la condition pour que la réunification, au paquet suivant, n'ouvre
-- aucune fenêtre — dans ci.yml les edge functions partent avant `db push`,
-- donc l'ordre inverse serait dangereux.
--
-- Le secret, lui, est déjà le bon : l'empreinte SHA-256 du vault
-- (`ANARBIB_TASK_INVITE_SECRET`) et celle de l'env de la fonction
-- (`WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK`) sont identiques — vérifié le
-- 30/08/2026, sans qu'aucune des deux valeurs n'ait eu à être lue.
--
-- COMMENT : PAR RÉÉCRITURE, PAS PAR RECOPIE
--
-- Les deux fonctions font ~150 lignes chacune. Les retranscrire pour changer
-- une chaîne, c'est se donner deux occasions de faute de frappe — et ce soir
-- une vérification faite sur une transcription plutôt que sur l'artefact a
-- déjà coûté un `db push` à moitié appliqué. On reconstruit donc chaque
-- définition depuis `pg_get_functiondef`, on n'y remplace que le littéral, et
-- on la rejoue. Aucune autre ligne ne peut bouger.
-- =========================================================================

BEGIN;

DO $$
DECLARE
  v_nom text;
  v_def text;
  v_nouvelle text;
BEGIN
  FOREACH v_nom IN ARRAY ARRAY['dispatch_task_notification_outbox',
                               'dispatch_task_invitation_outbox']
  LOOP
    SELECT pg_get_functiondef(p.oid) INTO v_def
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_nom;

    IF v_def IS NULL THEN
      RAISE EXCEPTION 'fonction % introuvable', v_nom;
    END IF;

    v_nouvelle := replace(v_def, 'x-task-invite-secret', 'x-webhook-secret');

    -- Rejouer une definition inchangee serait inutile mais pas faux ; on le
    -- signale plutot que de le taire, pour qu'une reprise de migration se lise.
    IF v_nouvelle = v_def THEN
      RAISE NOTICE 'ancien en-tete deja absent de % — redefinition sans changement', v_nom;
    END IF;

    EXECUTE v_nouvelle;
  END LOOP;
END $$;

-- -------------------------------------------------------------------------
-- Vérification (doctrine)
-- -------------------------------------------------------------------------
DO $$
DECLARE v_noms text;
BEGIN
  SELECT string_agg(n.nspname||'.'||p.proname, ', ' ORDER BY p.proname) INTO v_noms
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE p.prosrc LIKE '%x-task-invite-secret%';
  IF v_noms IS NOT NULL THEN
    RAISE EXCEPTION 'des fonctions envoient encore l''ancien en-tete : %', v_noms;
  END IF;

  SELECT string_agg(n.nspname||'.'||p.proname, ', ' ORDER BY p.proname) INTO v_noms
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('dispatch_task_notification_outbox', 'dispatch_task_invitation_outbox')
     AND p.prosrc NOT LIKE '%x-webhook-secret%';
  IF v_noms IS NOT NULL THEN
    RAISE EXCEPTION 'ces expediteurs n''envoient aucun en-tete standard : %', v_noms;
  END IF;
END $$;

COMMIT;
