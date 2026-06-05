-- =========================================================================
-- Paquet capas P2 — colonnes cover_source / cover_license
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Module capas (spec-module-capas v0.2, CAT-C1)
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- Ajoute les colonnes d'attribution de capa sur `books` et `book_drafts` :
--   - cover_source  : provenance de l'illustration (openlibrary, wikimedia,
--                     og_image, manual, ...) — pour la conformite ethique.
--   - cover_license : licence de l'illustration quand connue (CC-BY, PD, ...).
-- La colonne d'ancre `cover_object_path` existe deja sur les deux tables
-- (reservee au Lot 6 / spec-catalogacao-fiche-et-paliers §5.3).
--
-- DOCTRINE
-- --------
-- ADD COLUMN seul sur tables existantes deja sous RLS : pas de fonction
-- SECURITY DEFINER, pas de nouvelle table, pas de vue, pas de policy.
-- Colonnes text nullable, sans CHECK (valeurs libres cote EF cover_lookup).
-- Les GRANT colonne suivent les GRANT table existants (herites).
-- =========================================================================

BEGIN;

ALTER TABLE public.books
  ADD COLUMN IF NOT EXISTS cover_source  text,
  ADD COLUMN IF NOT EXISTS cover_license text;

ALTER TABLE public.book_drafts
  ADD COLUMN IF NOT EXISTS cover_source  text,
  ADD COLUMN IF NOT EXISTS cover_license text;

COMMENT ON COLUMN public.books.cover_source IS
  'Provenance de la capa (openlibrary, wikimedia, og_image, manual). Paquet capas P2 du 05/06/2026.';
COMMENT ON COLUMN public.books.cover_license IS
  'Licence de la capa quand connue (CC-BY, PD, ...). Paquet capas P2 du 05/06/2026.';
COMMENT ON COLUMN public.book_drafts.cover_source IS
  'Provenance de la capa (openlibrary, wikimedia, og_image, manual). Paquet capas P2 du 05/06/2026.';
COMMENT ON COLUMN public.book_drafts.cover_license IS
  'Licence de la capa quand connue (CC-BY, PD, ...). Paquet capas P2 du 05/06/2026.';

COMMIT;

-- =========================================================================
-- Rollback cible en cas de regression post-deploiement :
-- =========================================================================
-- BEGIN;
--   ALTER TABLE public.books       DROP COLUMN IF EXISTS cover_source, DROP COLUMN IF EXISTS cover_license;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS cover_source, DROP COLUMN IF EXISTS cover_license;
-- COMMIT;
-- =========================================================================
