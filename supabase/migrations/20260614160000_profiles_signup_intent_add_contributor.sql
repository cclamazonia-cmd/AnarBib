-- =====================================================================
-- FIX — autoriser signup_intent = 'contributor' (atelier autorités)
-- =====================================================================
-- Bug : la migration 20260613170000 a ajouté le trigger
-- trg_create_network_contributor (qui crée une ligne network_contributors
-- quand profiles.signup_intent devient 'contributor') et l'EF register écrit
-- bien 'contributor', MAIS la contrainte CHECK profiles_signup_intent_chk
-- (posée par 20260521120000) n'a jamais été étendue à 'contributor'.
-- Conséquence : tout UPDATE signup_intent='contributor' est rejeté
-- (check_violation), le trigger ne fire jamais, network_contributors reste
-- vide → AUCUN compte contributeur ne peut être créé proprement.
--
-- Fix : recréer la contrainte avec 'contributor'. Purement additif (aucune
-- ligne existante ne porte 'contributor', la valeur étant jusqu'ici interdite).
-- =====================================================================

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_signup_intent_chk;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_signup_intent_chk
  CHECK (signup_intent IS NULL OR signup_intent IN (
    'reader_pending',
    'reader_orphan',
    'collective_candidate',
    'contributor'
  ));

-- Vérification automatique (auto-rollback si échec) : 'contributor' accepté.
DO $chk$
DECLARE ok boolean;
BEGIN
  SELECT pg_get_constraintdef(oid) LIKE '%contributor%'
    INTO ok
    FROM pg_constraint
   WHERE conname = 'profiles_signup_intent_chk'
     AND conrelid = 'public.profiles'::regclass;
  IF NOT COALESCE(ok, false) THEN
    RAISE EXCEPTION 'Echec : profiles_signup_intent_chk ne contient pas contributor';
  END IF;
  RAISE NOTICE 'Migration : signup_intent contributor autorise (verification OK).';
END $chk$;
