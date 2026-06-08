-- =========================================================================
-- Fix RLS Storage : assets de theme (library-ui-assets / themes/{slug}/)
-- =========================================================================
-- Date     : 2026-06-08 (horodatage UTC reel)
-- Chantier : Identite visuelle des bibliotheques (upload manifest/logo/bg...)
-- Auteur   : Xavier + Claude
-- Session  : QR codes etiquettes module mobile
--
-- BUG
-- ---
-- Les 4 policies du bucket 'library-ui-assets' scopant le dossier themes/
-- comparaient le slug de la biblio au 2e segment de... storage.foldername(
-- l.name) -- le NOM de la bibliotheque -- au lieu de storage.foldername(name),
-- le CHEMIN de l'objet uploade. Resultat : l'EXISTS etait toujours faux,
-- l'upload/list/update/delete des assets de theme etait refuse pour TOUT LE
-- MONDE (meme un coordenador), avec "new row violates row-level security
-- policy". Cote UI, le list() echouait aussi -> "Arquivo ausente".
--
-- CORRECTIF
-- ---------
-- Reference correcte au chemin de l'objet : (storage.foldername(
-- storage.objects.name))[2]. A l'interieur du sous-EXISTS, 'name' seul est
-- ambigu (la table libraries a aussi une colonne name) : on qualifie donc
-- explicitement storage.objects.name pour viser la ligne objet.
--
-- Le perimetre d'autorisation est INCHANGE : user_can_engage_library()
-- (= admin reseau OU coordenador actif de la biblio cible). On corrige
-- seulement la cible de la comparaison de slug.
--
-- DROP IF EXISTS + CREATE : idempotent, et rejoue le correctif sur une base
-- fraiche (les policies d'origine avaient ete creees hors migration).
-- =========================================================================

BEGIN;

-- INSERT ---------------------------------------------------------------------
DROP POLICY IF EXISTS "ui assets: scoped insert" ON storage.objects;
CREATE POLICY "ui assets: scoped insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'library-ui-assets'
    AND (
      (storage.foldername(name))[1] IS DISTINCT FROM 'themes'
      OR EXISTS (
        SELECT 1 FROM public.libraries l
        WHERE l.slug = (storage.foldername(storage.objects.name))[2]
          AND public.user_can_engage_library(l.id)
      )
    )
  );

-- UPDATE ---------------------------------------------------------------------
DROP POLICY IF EXISTS "ui assets: scoped update" ON storage.objects;
CREATE POLICY "ui assets: scoped update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (
      (storage.foldername(name))[1] IS DISTINCT FROM 'themes'
      OR EXISTS (
        SELECT 1 FROM public.libraries l
        WHERE l.slug = (storage.foldername(storage.objects.name))[2]
          AND public.user_can_engage_library(l.id)
      )
    )
  )
  WITH CHECK (
    bucket_id = 'library-ui-assets'
    AND (
      (storage.foldername(name))[1] IS DISTINCT FROM 'themes'
      OR EXISTS (
        SELECT 1 FROM public.libraries l
        WHERE l.slug = (storage.foldername(storage.objects.name))[2]
          AND public.user_can_engage_library(l.id)
      )
    )
  );

-- DELETE ---------------------------------------------------------------------
DROP POLICY IF EXISTS "ui assets: scoped delete" ON storage.objects;
CREATE POLICY "ui assets: scoped delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (
      (storage.foldername(name))[1] IS DISTINCT FROM 'themes'
      OR EXISTS (
        SELECT 1 FROM public.libraries l
        WHERE l.slug = (storage.foldername(storage.objects.name))[2]
          AND public.user_can_engage_library(l.id)
      )
    )
  );

-- SELECT (list own theme folder) --------------------------------------------
DROP POLICY IF EXISTS "ui assets: staff list own theme folder" ON storage.objects;
CREATE POLICY "ui assets: staff list own theme folder" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(storage.objects.name))[2]
        AND public.user_can_engage_library(l.id)
    )
  );

COMMIT;

-- =========================================================================
-- Rollback : restaurer l'ancienne expression (buggee) n'a pas de sens ;
-- en cas de besoin, recreer les policies avec le perimetre voulu.
-- =========================================================================
