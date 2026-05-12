-- ============================================================================
-- Paquet 24c-bis : qualifier objects.name dans les 3 RLS storage
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

COMMENT ON POLICY "Coordenadors can upload library ui assets" ON storage.objects IS
  'Paquet 24c-bis : objects.name qualifie pour eviter resolution sur libraries.name (bug 12/05/2026).';
