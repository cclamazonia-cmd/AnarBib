-- ============================================================================
-- Paquet 24c-octies : ajouter la policy SELECT manquante pour library-ui-assets
--
-- Cause finale du blocage upload : sans policy SELECT, le SDK Supabase Storage
-- echoue ses checks internes et retourne 42501 RLS sur l'INSERT (message
-- d'erreur trompeur). Diagnostic confirme via MCP : SELECT en role authenticated
-- retournait 0 lignes, ajout de la policy a debloque les INSERTs.
-- ============================================================================

CREATE POLICY IF NOT EXISTS "Authenticated can read library ui assets"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (bucket_id = 'library-ui-assets');