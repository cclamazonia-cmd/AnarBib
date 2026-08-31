-- =====================================================================
-- AnarBib -- Les rappels d'echeance existent enfin
-- Date    : 2026-08-31  ·  Item F4  ·  doctrines DOC-RAPPEL-1, DOC-SILENCE-1
-- Ref     : spec-flux-emprunts §2.4 et §10.2 (amendes le meme jour)
--           supabase/functions/notify-loan-cycle/
--
-- CE QUE LE RELEVE A MONTRE.
--
-- `library_notification_policies` portait `loan_reminders_enabled` et
-- `loan_overdue_enabled`, exposes dans `v_library_notification_context` -- la
-- vue que lit la pile courriel. Les trois bibliotheques dotees d'une politique
-- les avaient a `true`. Elles ne les avaient pas actives : ils NAISSENT
-- actives. Et aucun envoi correspondant n'existait : les trente-six crons ont
-- ete relus un par un, aucun ne concerne le pret aux lectrices.
--
-- Trois bibliotheques se croyaient donc couvertes par un dispositif absent.
-- C'est le cas (a) de DOC-SILENCE-1, et la meme mecanique que le privilege
-- `anon` retourne le meme jour : un defaut herite qui passe pour une decision.
--
-- TROIS MOMENTS, PAS SIX (DOC-RAPPEL-1). La spec en annoncait six -- J-5, J-3,
-- jour J, J+1, J+7, J+30. On en garde trois : J-3, le jour de l'echeance, J+7.
-- Un signal qui se repete cesse d'etre lu (OPS-8), et une lectrice emoussee ne
-- referme pas un ticket : elle cesse d'emprunter.
--
-- UN QUATRIEME ENVOI, QUI EN REMPLACE UN AUTRE. A mi-parcours, l'ancienne
-- fonction `notify-mid-loan-reading` demandait « Como vai a leitura? » -- une
-- question a laquelle un courriel ne permet pas de repondre -- et le faisait EN
-- PORTUGAIS EN DUR, quelle que soit la langue de la lectrice. On propose
-- desormais un geste qui laisse quelque chose au reseau : ecrire une note de
-- lecture, sous pseudonyme, dans le catalogue. `book_reading_notes` est
-- construite, deployee, et n'a jamais recu une seule ligne ; l'ecran d'ecriture
-- existe deja sur la page de l'oeuvre. Le cron de l'ancienne fonction est
-- desactive ci-dessous : garder les deux, ce serait deux courriels a mi-parcours.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. L'interrupteur qui manquait -- et qui commande quelque chose
-- ---------------------------------------------------------------------
-- Les deux autres existaient deja et ne commandaient rien. Celui-ci nait en
-- meme temps que l'envoi qu'il gouverne : c'est la seule facon de ne pas
-- reproduire ce que cet item corrige.
ALTER TABLE public.library_notification_policies
  ADD COLUMN IF NOT EXISTS reading_notes_invite_enabled boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.library_notification_policies.reading_notes_invite_enabled IS
  'Invitation, a mi-parcours du pret, a deposer une note de lecture sous pseudonyme '
  'dans le catalogue du reseau. Remplace l''ancien courriel « Como vai a leitura? ». '
  'Item F4, doctrine DOC-RAPPEL-1.';

-- ---------------------------------------------------------------------
-- 2. Au plus une fois par item et par moment
-- ---------------------------------------------------------------------
-- Sans cette trace, un cron rejoue deux fois dans la journee enverrait deux
-- fois le meme rappel : exactement le defaut que DOC-RAPPEL-1 evite. C'est
-- l'invariant 4 du §11.1 de la spec, applique aux rappels.
CREATE TABLE IF NOT EXISTS public.loan_cycle_notifications (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  emprestimo_item_id   bigint      NOT NULL REFERENCES public.emprestimo_itens_v2(id) ON DELETE CASCADE,
  moment               text        NOT NULL CHECK (moment IN ('d3','d0','overdue7','note_invite')),
  library_id           uuid        NULL,
  user_id              uuid        NULL,
  sent_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT loan_cycle_notifications_unicite UNIQUE (emprestimo_item_id, moment)
);

COMMENT ON TABLE public.loan_cycle_notifications IS
  'Trace des courriels du cycle d''emprunt reellement partis (F4). L''unicite '
  '(item, moment) garantit qu''un rappel ne part qu''une fois. La ligne n''est '
  'ecrite QUE si l''envoi a reussi : un envoi manque doit pouvoir etre rejoue.';

CREATE INDEX IF NOT EXISTS loan_cycle_notifications_item_idx
  ON public.loan_cycle_notifications (emprestimo_item_id);

-- RLS : cette table ne regarde personne d'autre que le service. Aucune policy
-- n'est creee -- RLS active sans policy = ferme a tous les roles de session,
-- `service_role` la contourne. C'est la forme la plus fermee, et elle est
-- volontaire (cf. B1, meme raisonnement pour le schema `ingest`).
ALTER TABLE public.loan_cycle_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.loan_cycle_notifications FROM anon, authenticated;

-- Et le droit dit POSITIVEMENT qui agit, au lieu de se deduire des refus.
-- `service_role` est le seul acteur : la fonction Edge lit ce qui est deja
-- parti, ecrit ce qui vient de partir, et efface une ligne quand l'item
-- disparait. Pas d'UPDATE : une trace d'envoi ne se modifie pas.
-- (Cinquieme regle du hook pre-commit -- elle a bloque ce fichier au premier
-- essai, et elle avait raison : fermer sans dire qui a le droit laisse la
-- prochaine lecture deviner.)
GRANT SELECT, INSERT, DELETE ON TABLE public.loan_cycle_notifications TO service_role;

-- ---------------------------------------------------------------------
-- 3. Le declencheur quotidien
-- ---------------------------------------------------------------------
-- Le secret est celui de l'ancienne fonction, REUTILISE DELIBEREMENT : cette
-- fonction la remplace, le secret existe deja dans le vault et y est renseigne.
-- En creer un neuf, c'etait risquer d'en ajouter un quatorzieme a vide (F7).
CREATE OR REPLACE FUNCTION public.fn_cron_notify_loan_cycle()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $fn$
DECLARE
  v_url    text;
  v_secret text;
BEGIN
  v_url := regexp_replace(public.fn_internal_get_vault_secret('SUPABASE_URL'), '/+$', '')
           || '/functions/v1/notify-loan-cycle';
  v_secret := public.fn_internal_get_vault_secret('WEBHOOK_SECRET_NOTIFY_MID_LOAN');

  IF coalesce(v_secret, '') = '' THEN
    RAISE EXCEPTION 'WEBHOOK_SECRET_NOTIFY_MID_LOAN absent du vault : le tir echouerait en silence';
  END IF;

  RETURN net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', v_secret),
    body    := jsonb_build_object('source', 'pg_cron', 'job', 'anarbib-notify-loan-cycle-daily',
                                  'scheduled_at', now()),
    timeout_milliseconds := 60000
  );
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_cron_notify_loan_cycle() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  -- Le nouveau cron, 9h15 UTC -- apres les crons de resolution de 3h et avant
  -- le reste de la journee.
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-notify-loan-cycle-daily') THEN
    PERFORM cron.unschedule('anarbib-notify-loan-cycle-daily');
  END IF;
  PERFORM cron.schedule('anarbib-notify-loan-cycle-daily', '15 9 * * *',
                        'select public.fn_cron_notify_loan_cycle();');

  -- L'ancien mi-parcours est remplace, pas double.
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-notify-mid-loan-reading-daily') THEN
    PERFORM cron.unschedule('anarbib-notify-mid-loan-reading-daily');
    RAISE NOTICE 'anarbib-notify-mid-loan-reading-daily desactive : remplace par le moment note_invite.';
  END IF;
END $$;

-- ---------------------------------------------------------------------
-- Verification -- annule tout si l'etat vise n'est pas atteint
-- ---------------------------------------------------------------------
DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM information_schema.columns
   WHERE table_schema='public' AND table_name='library_notification_policies'
     AND column_name='reading_notes_invite_enabled';
  IF v_n <> 1 THEN RAISE EXCEPTION 'ECHEC : interrupteur absent'; END IF;

  SELECT count(*) INTO v_n FROM pg_constraint
   WHERE conname = 'loan_cycle_notifications_unicite';
  IF v_n <> 1 THEN RAISE EXCEPTION 'ECHEC : sans unicite (item, moment), un rappel peut partir deux fois'; END IF;

  IF NOT has_table_privilege('service_role', 'public.loan_cycle_notifications', 'INSERT')
     OR has_table_privilege('anon', 'public.loan_cycle_notifications', 'SELECT')
     OR has_table_privilege('authenticated', 'public.loan_cycle_notifications', 'SELECT') THEN
    RAISE EXCEPTION 'ECHEC : les droits de la trace ne sont pas ceux voulus';
  END IF;

  SELECT count(*) INTO v_n FROM cron.job WHERE jobname = 'anarbib-notify-loan-cycle-daily';
  IF v_n <> 1 THEN RAISE EXCEPTION 'ECHEC : le cron quotidien n''est pas planifie'; END IF;

  SELECT count(*) INTO v_n FROM cron.job WHERE jobname = 'anarbib-notify-mid-loan-reading-daily';
  IF v_n <> 0 THEN RAISE EXCEPTION 'ECHEC : l''ancien mi-parcours tourne encore -- deux courriels partiraient'; END IF;

  RAISE NOTICE 'OK : trois rappels et une invitation, un seul cron, au plus un envoi par item et par moment.';
END $$;

COMMIT;
