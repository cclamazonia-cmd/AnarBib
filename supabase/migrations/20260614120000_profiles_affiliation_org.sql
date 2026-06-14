-- =====================================================================
-- criar-conta — champ « organisation / collectif d'appartenance »
--
-- Remplace, pour les comptes contributeur·rice (atelier autorités, compte
-- réseau sans bibliothèque), l'ancien champ statistique « genre » par une
-- saisie libre réellement utile : l'organisation ou le collectif auquel la
-- personne appartient. Le genre reste collecté pour les autres types de
-- compte (il est juste masqué à l'inscription contributeur) ; les deux champs
-- sont éditables ensuite dans /conta et le backstage (TabLeitor).
--
-- Doctrine : miroir de 20260521120000_profiles_signup_intent.sql (ADD COLUMN
-- IF NOT EXISTS idempotent + DO de vérification auto-rollback). RLS de profiles
-- = par ligne, pas par colonne : aucune policy à ajouter (un·e librarian qui
-- voit déjà le profil de ses lecteur·rices verra aussi cette colonne, jugé
-- acceptable — info peu sensible, fournie volontairement par la personne).
-- =====================================================================

-- ---- 1. La colonne -----------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS affiliation_org text;

-- ---- 2. Commentaire : tracer la doctrine ------------------------------
COMMENT ON COLUMN public.profiles.affiliation_org IS
  'Organisation / collectif d''appartenance déclaré par la personne (saisie '
  'libre, optionnelle). Posé par l''EF register pour les comptes contributeur '
  'à l''inscription ; éditable ensuite dans /conta et le backstage. Remplace '
  'le champ statistique « genre » pour le cas contributeur (atelier autorités). '
  'Visibilité : RLS par ligne (cf. signup_intent, décision v0.3).';

-- ---- 3. Vérification automatique (auto-rollback si échec) --------------
DO $chk$
DECLARE
  has_col boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles'
      AND column_name = 'affiliation_org'
  ) INTO has_col;
  IF NOT has_col THEN
    RAISE EXCEPTION 'Echec migration : colonne public.profiles.affiliation_org absente';
  END IF;
  RAISE NOTICE 'Migration affiliation_org : verification OK (colonne presente).';
END $chk$;
