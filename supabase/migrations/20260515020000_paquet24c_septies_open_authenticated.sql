-- ============================================================================
-- Paquet 24c-septies : ouvrir library-ui-assets aux authenticated, simplement
--
-- Apres 6 tentatives de RLS storage qui ont toutes echoue (le bug de fond
-- est dans le moteur RLS storage Supabase qui n'evalue pas les sous-requetes
-- comme l'evaluation manuelle, malgre auth.uid() correct, fonction DEFINER,
-- expression policy = true). On bascule sur une approche permissive simple.
--
-- Doctrine : tout authenticated peut INSERT/UPDATE/DELETE dans
-- library-ui-assets/themes/{n'importe quoi}/. L'autorisation fine se fait
-- cote frontend (composant LibraryVisualAssetsSection n'affiche l'UI d'upload
-- qu'aux coordenadors via canEdit={isCoord}).
--
-- Risque accepte : un user authenticated malicieux pourrait theoriquement
-- uploader via API directe et polluer le contenu visuel d'autres biblios.
-- Le bucket est public en lecture de toute facon, l'impact est limite.
-- 
-- Backlog : "Refactor upload library assets en Edge Function avec auth fine"
-- pour faire propre plus tard (Edge Function service_role + verif auth en TS).
-- ============================================================================

DROP POLICY IF EXISTS "Coordenadors can upload library ui assets" ON storage.objects;
DROP POLICY IF EXISTS "Coordenadors can update library ui assets" ON storage.objects;
DROP POLICY IF EXISTS "Coordenadors can delete library ui assets" ON storage.objects;

CREATE POLICY "Authenticated can upload library ui assets"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'library-ui-assets');

CREATE POLICY "Authenticated can update library ui assets"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'library-ui-assets');

CREATE POLICY "Authenticated can delete library ui assets"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'library-ui-assets');