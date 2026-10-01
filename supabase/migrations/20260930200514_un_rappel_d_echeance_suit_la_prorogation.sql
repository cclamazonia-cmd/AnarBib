-- =========================================================================
-- Un rappel d'échéance suit la prorogation
-- =========================================================================
-- Date     : 2026-09-30
-- Chantier : backlog v34, item F17 (relevé par la carte de la chaîne de
--            courriel, F1, docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md)
--
-- LE CONSTAT. Proroger un exemplaire (`fn_v2_extend_core`) écrit la nouvelle
-- date dans `emprestimo_itens_v2.extended_until` et laisse `due_at`. Les rappels
-- du cycle d'emprunt (`notify-loan-cycle`, F4) ne lisaient que `due_at` : pour
-- un exemplaire prorogé, « c'est aujourd'hui » à l'ancienne date, « 7 jours de
-- retard » alors qu'il n'est pas en retard, rien avant la vraie échéance. Et la
-- trace `loan_cycle_notifications` ne tolérait qu'un rappel par (exemplaire,
-- moment) : le J-3 parti avant une prorogation aurait bloqué celui de la
-- nouvelle échéance. Latent : aucune prorogation depuis F4 (3 traces en base,
-- aucune sur un exemplaire prorogé, relevé du 30/09).
--
-- CE QUE FAIT CETTE MIGRATION.
--   · La trace porte l'échéance pour laquelle le rappel est parti (`echeance`),
--     reprise sur l'existant (la date de l'exemplaire, `due_at` : aucune trace
--     n'est sur un exemplaire prorogé).
--   · L'unicité devient (exemplaire, moment, échéance) : un rappel ne part
--     qu'une fois POUR UNE ÉCHÉANCE, et une prorogation ouvre droit au rappel
--     de la nouvelle date.
--   · Un déclencheur remplit `echeance` quand l'écrivain ne la donne pas — avec
--     l'échéance courante de l'exemplaire, `coalesce(extended_until, due_at)`,
--     la convention du dépôt. Ainsi l'ancienne version de la fonction (celle qui
--     tourne tant que la nouvelle n'est pas déployée) écrit encore une trace
--     valide : aucun ordre de déploiement ne peut faire repartir un rappel.
--   La fonction `notify-loan-cycle` (même commit) calcule ses fenêtres, le
--   mi-parcours et la date affichée sur l'échéance courante.
-- =========================================================================

BEGIN;

ALTER TABLE public.loan_cycle_notifications ADD COLUMN IF NOT EXISTS echeance date;

UPDATE public.loan_cycle_notifications n
   SET echeance = i.due_at
  FROM public.emprestimo_itens_v2 i
 WHERE i.id = n.emprestimo_item_id AND n.echeance IS NULL;

CREATE OR REPLACE FUNCTION public.tg_loan_cycle_notification_echeance()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.echeance IS NULL THEN
    SELECT coalesce(i.extended_until, i.due_at) INTO NEW.echeance
      FROM public.emprestimo_itens_v2 i
     WHERE i.id = NEW.emprestimo_item_id;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.tg_loan_cycle_notification_echeance() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.tg_loan_cycle_notification_echeance() IS
  'F17 (30/09/2026) : remplit loan_cycle_notifications.echeance, quand l''ecrivain ne la '
  'donne pas, avec l''echeance courante de l''exemplaire (coalesce(extended_until, due_at)).';

DROP TRIGGER IF EXISTS loan_cycle_notifications_echeance ON public.loan_cycle_notifications;
CREATE TRIGGER loan_cycle_notifications_echeance
  BEFORE INSERT ON public.loan_cycle_notifications
  FOR EACH ROW EXECUTE FUNCTION public.tg_loan_cycle_notification_echeance();

ALTER TABLE public.loan_cycle_notifications ALTER COLUMN echeance SET NOT NULL;

ALTER TABLE public.loan_cycle_notifications DROP CONSTRAINT IF EXISTS loan_cycle_notifications_unicite;
ALTER TABLE public.loan_cycle_notifications
  ADD CONSTRAINT loan_cycle_notifications_unicite UNIQUE (emprestimo_item_id, moment, echeance);

COMMENT ON COLUMN public.loan_cycle_notifications.echeance IS
  'Echeance pour laquelle le rappel est parti (F17, 30/09/2026) : coalesce(extended_until, due_at) '
  'de l''exemplaire au moment de l''envoi. L''unicite (exemplaire, moment, echeance) laisse une '
  'prorogation ouvrir droit au rappel de la nouvelle date.';
COMMENT ON TABLE public.loan_cycle_notifications IS
  'Trace des courriels du cycle d''emprunt reellement partis (F4). L''unicite '
  '(item, moment, echeance) garantit qu''un rappel ne part qu''une fois pour une echeance (F17). '
  'La ligne n''est ecrite QUE si l''envoi a reussi : un envoi manque doit pouvoir etre rejoue.';

-- Vérification.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.loan_cycle_notifications WHERE echeance IS NULL) THEN
    RAISE EXCEPTION 'une trace sans echeance subsiste';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conname = 'loan_cycle_notifications_unicite'
                    AND pg_get_constraintdef(oid) LIKE '%emprestimo_item_id, moment, echeance%') THEN
    RAISE EXCEPTION 'l''unicite (exemplaire, moment, echeance) n''est pas posee';
  END IF;
END $$;

COMMIT;
