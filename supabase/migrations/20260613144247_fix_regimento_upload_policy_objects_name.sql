-- ════════════════════════════════════════════════════════════════════════════
-- FIX — Volet 10 upload : qualifier objects.name dans les policies storage
-- ════════════════════════════════════════════════════════════════════════════
-- Bug de la migration 20260613142457 : la sous-requête
--   EXISTS (SELECT 1 FROM public.libraries l WHERE l.slug = (storage.foldername(name))[2] ...)
-- utilisait un `name` NON qualifié. Comme public.libraries possède une colonne `name`,
-- la résolution de colonne a lié `name` à libraries.name (portée interne) au lieu du
-- chemin de l'objet storage → (storage.foldername(libraries.name))[2] = NULL → aucun
-- match → "new row violates row-level security policy" au téléversement.
--
-- Correctif : qualifier explicitement objects.name (le chemin de l'objet storage),
-- comme les policies qui marchent (privacy / ui-assets). Chemin regimentos/<slug>/…
-- → folder index [2] = slug.
-- ════════════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "library_regimentos_public_constitution_insert" ON storage.objects;
CREATE POLICY "library_regimentos_public_constitution_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'library-regimentos-public'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(objects.name))[2]
      AND public.user_can_engage_library(l.id)
  )
);

DROP POLICY IF EXISTS "library_regimentos_public_constitution_update" ON storage.objects;
CREATE POLICY "library_regimentos_public_constitution_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'library-regimentos-public'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(objects.name))[2]
      AND public.user_can_engage_library(l.id)
  )
)
WITH CHECK (
  bucket_id = 'library-regimentos-public'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(objects.name))[2]
      AND public.user_can_engage_library(l.id)
  )
);

DROP POLICY IF EXISTS "library_regimentos_public_constitution_select" ON storage.objects;
CREATE POLICY "library_regimentos_public_constitution_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'library-regimentos-public'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(objects.name))[2]
      AND public.user_can_engage_library(l.id)
  )
);

-- Garde-fou : la policy INSERT doit référencer objects.name, pas libraries.name.
DO $$
DECLARE v_check text;
BEGIN
  SELECT pg_get_expr(polwithcheck, polrelid) INTO v_check
    FROM pg_policy
   WHERE polrelid='storage.objects'::regclass
     AND polname='library_regimentos_public_constitution_insert';
  IF v_check IS NULL OR position('objects.name' in v_check) = 0 THEN
    RAISE EXCEPTION 'KO: policy insert ne référence pas objects.name (=%)', v_check;
  END IF;
  RAISE NOTICE 'FIX OK : upload regimento pré-actif utilise objects.name.';
END $$;
