-- ============================================================================
-- Paquet 24c-sexies : helper SECURITY DEFINER dedie pour les RLS Storage
--
-- Diagnostic : la policy actuelle echoue meme avec un path canonique correct
-- (verifie via Network DevTools : POST library-ui-assets/themes/blmf/bg.webp).
-- Le test SQL Editor avec auth simulee passe (policy_full = true), donc le
-- contexte Storage REST evalue auth.uid() differemment du contexte REST.
--
-- Approche conservatrice : ne pas modifier user_can_engage_library (utilise
-- par 22 RLS du paquet C). Creer un helper dedie en SECURITY DEFINER qui
-- isole le contexte d'execution et garantit que auth.uid() est resolu via
-- la session PostgreSQL plutot que via le contexte d'appel Storage.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_can_engage_library_for_storage(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT
        EXISTS (
            SELECT 1 FROM public.network_administrators
            WHERE user_id = auth.uid() AND status = 'active'
        )
        OR
        EXISTS (
            SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid()
              AND m.library_id = p_library_id
              AND m.status = 'active'
              AND m.role = 'coordenador'
        );
$$;

GRANT EXECUTE ON FUNCTION public.fn_can_engage_library_for_storage(uuid)
  TO authenticated;

DROP POLICY IF EXISTS "Coordenadors can upload library ui assets" ON storage.objects;
DROP POLICY IF EXISTS "Coordenadors can update library ui assets" ON storage.objects;
DROP POLICY IF EXISTS "Coordenadors can delete library ui assets" ON storage.objects;

CREATE POLICY "Coordenadors can upload library ui assets"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(storage.objects.name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(storage.objects.name))[2]
        AND fn_can_engage_library_for_storage(l.id)
    )
  );

CREATE POLICY "Coordenadors can update library ui assets"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(storage.objects.name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(storage.objects.name))[2]
        AND fn_can_engage_library_for_storage(l.id)
    )
  );

CREATE POLICY "Coordenadors can delete library ui assets"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'library-ui-assets'
    AND (storage.foldername(storage.objects.name))[1] = 'themes'
    AND EXISTS (
      SELECT 1 FROM public.libraries l
      WHERE l.slug = (storage.foldername(storage.objects.name))[2]
        AND fn_can_engage_library_for_storage(l.id)
    )
  );