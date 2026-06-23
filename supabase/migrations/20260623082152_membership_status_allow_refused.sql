-- =========================================================================
-- Hotfix refonte du refus : autoriser status='refused' (contrainte CHECK)
-- =========================================================================
-- Date     : 2026-06-23
-- Chantier : refonte du refus (tâche #10) — correctif
-- Auteur   : Claude (livré en fichier, appliqué par Forgejo / supabase db push)
--
-- Contexte : la migration 20260623074333 (reject_membership → status='refused')
-- a été validée par dry-run mais celui-ci ne faisait que CRÉER les fonctions, pas
-- exécuter l'UPDATE. À l'usage, le refus échouait (toast « Não foi possível
-- recusar a inscrição ») car user_library_memberships a une contrainte CHECK sur
-- status qui n'incluait PAS 'refused' (23514). On l'ajoute. 'pending_validation'
-- (resubmit) y était déjà.
-- Idempotent (DROP puis ADD). Vérif que 'refused' est bien accepté.
-- =========================================================================

BEGIN;

ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT user_library_memberships_status_check;

ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_status_check
  CHECK (status = ANY (ARRAY[
    'active', 'inactive', 'pending_removal', 'removed', 'suspended',
    'left_with_pending_circulation', 'terminated', 'pending_validation', 'refused'
  ]));

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_library_memberships_status_check'
      AND pg_get_constraintdef(oid) ILIKE '%refused%'
  ) THEN
    RAISE EXCEPTION 'Vérif : refused absent de user_library_memberships_status_check.';
  END IF;
  RAISE NOTICE 'status_check accepte désormais refused. OK.';
END $$;

COMMIT;
