-- =========================================================================
-- Paquet fix — RLS : lecture staff des autorites (avec ou sans livre)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites (bug creation d'auteur invisible)
-- Auteur   : Xavier + Claude
--
-- PROBLEME
-- --------
-- La seule policy SELECT sur public.authors (authors_public_read) n'autorise a
-- voir un auteur que s'il a au moins un livre lie visible. Une autorite neuve
-- (sans livre) est donc invisible de TOUS, y compris du staff catalogacao :
-- impossible de la retrouver apres creation (workflow "autorite d'abord" casse).
--
-- CORRECTIF
-- ---------
-- Ajouter une policy SELECT permissive pour le staff (librarian/coordenador,
-- meme ensemble de roles que author_translations_librarian_write). Les policies
-- permissives se cumulent : le public continue de voir les auteurs avec livres,
-- le staff voit toutes les autorites.
-- =========================================================================

BEGIN;

DROP POLICY IF EXISTS authors_staff_read ON public.authors;

CREATE POLICY authors_staff_read
  ON public.authors
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.user_id = auth.uid()
        AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
    )
  );

COMMENT ON POLICY authors_staff_read ON public.authors IS
  'Le staff (librarian/coordenador) voit toutes les autorites, y compris sans livre. Paquet du 05/06/2026.';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : DROP POLICY IF EXISTS authors_staff_read ON public.authors;
-- =========================================================================
