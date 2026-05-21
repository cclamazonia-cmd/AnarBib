-- =====================================================================
-- Paquet 1 — Spec criar-conta v0.3 §4.1
-- Champs signup_intent sur public.profiles + RPC d'effacement du nom de
-- bibliotheque mentionne par une lectrice orpheline.
--
-- Chantier : restructuration onboarding /criar-conta (cas Karina).
-- Doctrine : creation d'objets securises v2 (REVOKE + search_path + DO).
-- Teste en sandbox (BEGIN/ROLLBACK) avant ecriture : DDL + 5 tests
-- comportementaux OK.
-- =====================================================================

-- ---- 1. Les 3 colonnes -------------------------------------------------
-- Idempotent : ADD COLUMN IF NOT EXISTS. signup_intent_metadata est
-- NOT NULL DEFAULT '{}' pour eviter les COALESCE cote EF et frontend.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS signup_intent          text,
  ADD COLUMN IF NOT EXISTS signup_intent_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS signup_intent_set_at   timestamptz;

-- ---- 2. Contrainte CHECK sur les valeurs autorisees --------------------
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_signup_intent_chk;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_signup_intent_chk
  CHECK (signup_intent IS NULL OR signup_intent IN (
    'reader_pending',
    'reader_orphan',
    'collective_candidate'
  ));

-- ---- 3. Commentaires : tracer la doctrine RLS (decision v0.3) ----------
-- RLS de profiles = par ligne, pas par colonne. Un·e librarian voyant
-- deja le profil de ses lecteur·rices verra aussi signup_intent. Juge
-- acceptable en v0.3 (signup_intent peu sensible, deductible du contexte ;
-- une orpheline n'a pas de membership donc pas de profil expose a un·e
-- librarian). Pas de mecanisme de masquage colonne ajoute.
COMMENT ON COLUMN public.profiles.signup_intent IS
  'Intention d''inscription, marqueur historique pose par l''EF register. '
  'Spec criar-conta v0.3 paragraphe 4.1. NULL pour les comptes anterieurs '
  'a la spec. Visibilite : RLS par ligne, un·e librarian voit ce champ '
  'pour les lecteur·rices de SA bibliotheque (decision v0.3 : acceptable).';
COMMENT ON COLUMN public.profiles.signup_intent_metadata IS
  'Metadonnees liees a signup_intent (jsonb, NOT NULL defaut {}). '
  'reader_orphan : {library_name_mentioned}. reader_pending : '
  '{library_id, library_slug}. collective_candidate : {claim_id}. '
  'Spec criar-conta v0.3 paragraphe 4.1.';
COMMENT ON COLUMN public.profiles.signup_intent_set_at IS
  'Horodatage de pose de signup_intent par l''EF register. Ne change plus '
  'ensuite (marqueur historique). Spec criar-conta v0.3 paragraphe 4.1.';

-- ---- 4. RPC : la personne efface le nom de biblio qu'elle a mentionne --
-- Scope strict a auth.uid() : la personne agit uniquement sur sa ligne.
-- Idempotent : si la cle n'existe pas, l'operation reussit sans effet.
CREATE OR REPLACE FUNCTION api.fn_clear_my_signup_metadata_field()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, api, auth, pg_temp
AS $fn$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Non authentifie';
  END IF;

  UPDATE public.profiles
     SET signup_intent_metadata =
           signup_intent_metadata - 'library_name_mentioned'
   WHERE id = auth.uid();
END;
$fn$;

-- ---- 5. ACL : doctrine objets securises, Template 1 -------------------
-- Fonction exposee au frontend (bouton "effacer" de /conta, paquet 7) :
-- REVOKE EXECUTE FROM PUBLIC, puis GRANT explicite. service_role recoit
-- aussi EXECUTE : c'est la norme des RPC api.* du projet (les 8 RPC api.*
-- SECURITY DEFINER existantes ont toutes service_role=X nominatif) et la
-- doctrine confirme "service_role conserve TOUJOURS l'acces". Necessaire
-- pour que l'Edge Function register (paquet 2) puisse appeler la RPC.
REVOKE EXECUTE ON FUNCTION api.fn_clear_my_signup_metadata_field() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_clear_my_signup_metadata_field() TO authenticated;
GRANT EXECUTE ON FUNCTION api.fn_clear_my_signup_metadata_field() TO service_role;

-- ---- 6. Verification automatique (auto-rollback si echec) --------------
DO $chk$
DECLARE
  n_cols  int;
  has_chk boolean;
  has_fn  boolean;
BEGIN
  SELECT count(*) INTO n_cols
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles'
    AND column_name IN ('signup_intent','signup_intent_metadata','signup_intent_set_at');
  IF n_cols <> 3 THEN
    RAISE EXCEPTION 'Echec migration : % colonnes signup_intent (attendu 3)', n_cols;
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_signup_intent_chk'
      AND conrelid = 'public.profiles'::regclass
  ) INTO has_chk;
  IF NOT has_chk THEN
    RAISE EXCEPTION 'Echec migration : contrainte profiles_signup_intent_chk absente';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = 'fn_clear_my_signup_metadata_field'
  ) INTO has_fn;
  IF NOT has_fn THEN
    RAISE EXCEPTION 'Echec migration : RPC api.fn_clear_my_signup_metadata_field absente';
  END IF;

  RAISE NOTICE 'Migration signup_intent : verification OK (3 colonnes, CHECK, RPC).';
END $chk$;
