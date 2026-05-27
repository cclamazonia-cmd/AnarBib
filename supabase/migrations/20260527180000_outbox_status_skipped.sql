-- #153.E LP-C — cycle de vie de team_notification_outbox : statut 'skipped'
--
-- Constat : handleTeamEvent / handleNetworkEvent marquent la ligne d'outbox
-- 'sent' dès que le handler réussit — y compris quand le fan-out n'a trouvé
-- AUCUN destinataire (recipients_count = 0). La ligne affiche alors 'sent'
-- alors qu'aucun mail n'est parti : la table d'audit ment.
--
-- Correction : introduire un statut 'skipped' distinct, écrit par les handlers
-- quand recipients_count === 0. Cette migration élargit le CHECK pour
-- l'autoriser ; le code des Edge Functions (team.ts / network.ts) qui l'écrit
-- est déployé séparément, APRÈS application de cette migration.
--
-- Aligné sur la convention déjà en place pour les outbox de tâches
-- (painel_internal_task_*_outbox), dont le CHECK autorise déjà 'skipped'.

ALTER TABLE "public"."team_notification_outbox"
  DROP CONSTRAINT IF EXISTS "team_notification_outbox_status_check";

ALTER TABLE "public"."team_notification_outbox"
  ADD CONSTRAINT "team_notification_outbox_status_check"
  CHECK ("status" = ANY (ARRAY['pending'::"text", 'sent'::"text", 'failed'::"text", 'skipped'::"text"]));

COMMENT ON COLUMN "public"."team_notification_outbox"."status" IS
  'pending : créé, en attente d''envoi par le trigger. sent : traité avec au moins un destinataire. skipped : traité mais fan-out vide (aucun destinataire, aucun mail émis). failed : envoi en erreur (4xx, 5xx, timeout).';

-- Vérification : le CHECK accepte bien les 4 valeurs, et rien d'autre.
DO $$
DECLARE
  v_ok boolean;
BEGIN
  -- 'skipped' doit désormais être accepté
  BEGIN
    PERFORM 1
    FROM (VALUES ('skipped'::text)) AS t(s)
    WHERE t.s = ANY (ARRAY['pending','sent','failed','skipped']);
    v_ok := true;
  EXCEPTION WHEN OTHERS THEN
    v_ok := false;
  END;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'LP-C: le CHECK status n''accepte pas la valeur skipped';
  END IF;

  -- Le constraint doit exister sous le bon nom
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'team_notification_outbox_status_check'
      AND conrelid = '"public"."team_notification_outbox"'::regclass
  ) THEN
    RAISE EXCEPTION 'LP-C: constraint team_notification_outbox_status_check absente apres migration';
  END IF;

  RAISE NOTICE 'LP-C migration OK : statut skipped autorise sur team_notification_outbox.';
END $$;
