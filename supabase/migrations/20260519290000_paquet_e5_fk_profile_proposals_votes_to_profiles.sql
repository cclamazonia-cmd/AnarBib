-- ============================================================================
-- Paquet E.5 hotfix (20/05/2026) : FK manquantes vers profiles
-- ============================================================================
-- 
-- Contexte : PostgREST (utilise par supabase-js cote frontend) ne peut faire
-- un JOIN automatique 'profiles:proposed_by(first_name, last_name)' que si une
-- FK declarée existe. Sans cette FK, l'erreur retournee est :
--   "Could not find a relationship between 'library_profile_proposals' and
--    'proposed_by' in the schema cache"
--
-- Cette migration ajoute :
--   - library_profile_proposals.proposed_by -> profiles.id (ON DELETE SET NULL)
--   - library_profile_proposals.cancelled_by -> profiles.id (ON DELETE SET NULL)
--   - library_profile_votes.voter_id -> profiles.id (ON DELETE CASCADE)
--   - library_profile_history.changed_by -> profiles.id (ON DELETE SET NULL)
--
-- Doctrine ON DELETE :
--   - SET NULL pour proposed_by / cancelled_by / changed_by : on garde la trace
--     historique (motivation, dates, transitions) meme si le profile est supprime
--   - CASCADE pour voter_id : si le profile est supprime, ses votes le sont aussi
--     (un vote anonymise n'a pas de sens pour calculer le quorum)
--
-- Note : applique en prod via MCP apply_migration le 19/05/2026 21:23,
-- timestamp realigne de 20260519192310 vers 20260519290000.
-- ============================================================================

BEGIN;

ALTER TABLE public.library_profile_proposals
  DROP CONSTRAINT IF EXISTS library_profile_proposals_proposed_by_fkey;
ALTER TABLE public.library_profile_proposals
  ADD CONSTRAINT library_profile_proposals_proposed_by_fkey
  FOREIGN KEY (proposed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.library_profile_proposals
  DROP CONSTRAINT IF EXISTS library_profile_proposals_cancelled_by_fkey;
ALTER TABLE public.library_profile_proposals
  ADD CONSTRAINT library_profile_proposals_cancelled_by_fkey
  FOREIGN KEY (cancelled_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.library_profile_votes
  DROP CONSTRAINT IF EXISTS library_profile_votes_voter_id_fkey;
ALTER TABLE public.library_profile_votes
  ADD CONSTRAINT library_profile_votes_voter_id_fkey
  FOREIGN KEY (voter_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.library_profile_history
  DROP CONSTRAINT IF EXISTS library_profile_history_changed_by_fkey;
ALTER TABLE public.library_profile_history
  ADD CONSTRAINT library_profile_history_changed_by_fkey
  FOREIGN KEY (changed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

DO $verify$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'library_profile_proposals_proposed_by_fkey') THEN
    RAISE EXCEPTION 'VERIF FAIL : FK proposed_by manquante';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'library_profile_votes_voter_id_fkey') THEN
    RAISE EXCEPTION 'VERIF FAIL : FK voter_id manquante';
  END IF;
  RAISE NOTICE 'Paquet E.5 hotfix FK : verification OK';
END
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;
