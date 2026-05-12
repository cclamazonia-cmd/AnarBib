-- ============================================================================
-- Paquet 24c-bis : qualifier objects.name dans les 3 RLS storage
--
-- Bug : 'new row violates row-level security policy' lors d'un upload dans
-- library-ui-assets/themes/{slug}/. Cause : name non qualifie dans la
-- sous-requete FROM libraries l etait resolu en libraries.name au lieu de
-- storage.objects.name.
--
-- Fix : qualifier en (storage.foldername(objects.name))[N], comme le fait
-- deja la policy 'Coordenadors can upload privacy sections'.
--
-- Note : pas de COMMENT ON POLICY car les objets de storage.objects
-- appartiennent a supabase_storage_admin, pas a postgres. Le commentaire
-- de tracabilite reste ici en tete du fichier de migration.
-- ============================================================================

DROP POLICY IF EXISTS "Coordenadors can upload library ui assets" ON storage.objects;
DROP POLICY IF EXISTS "Coordenadors can update library ui assets" ON storage.objects;
DROP POLICY IF EXISTS "Coordenadors can delete library ui assets" ON storage.objects;

CREATE POLICY "Coordenadors can upload library ui assets"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(objects.name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(objects.name))[2]
        AND user_can_engage_library(l.id)
    )
  );

CREATE POLICY "Coordenadors can update library ui assets"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(objects.name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(objects.name))[2]
        AND user_can_engage_library(l.id)
    )
  );

CREATE POLICY "Coordenadors can delete library ui assets"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(objects.name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(objects.name))[2]
        AND user_can_engage_library(l.id)
    )
  );
