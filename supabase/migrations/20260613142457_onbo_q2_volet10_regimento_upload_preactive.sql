-- ════════════════════════════════════════════════════════════════════════════
-- ONBO-Q2 — Volet 10 : téléversement du regimento depuis l'atelier (biblio pré-active)
-- ════════════════════════════════════════════════════════════════════════════
-- Obliger un collectif à héberger lui-même son règlement (URL externe) est un frein.
-- On veut un upload direct vers le bucket public library-regimentos-public depuis
-- l'atelier. Or les policies storage.objects existantes de ce bucket
-- (library_regimentos_public_librarians_*) gatent sur api.my_access.can_access_catalogacao,
-- qui exige une membership dans une biblio ACTIVE (active_memberships filtre l.is_active=true).
-- → une coordinatrice en constitution (biblio is_active=false) ne peut pas téléverser.
--
-- On ajoute 3 policies PERMISSIVES (INSERT/UPDATE/SELECT) calquées sur le pattern
-- paquet C.4 : scopées au slug présent dans le chemin (regimentos/<slug>/…, donc
-- folder index [2]) et gardées par user_can_engage_library(l.id) — qui reconnaît le
-- coordenador SANS exiger is_active. S'ajoutent (OR) aux policies librarians_*.
-- NB : pas de COMMENT sur storage.objects (pas de privilège owner du schéma storage).
-- ════════════════════════════════════════════════════════════════════════════

-- INSERT (upload)
DROP POLICY IF EXISTS "library_regimentos_public_constitution_insert" ON storage.objects;
CREATE POLICY "library_regimentos_public_constitution_insert"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'library-regimentos-public'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(name))[2]
      AND public.user_can_engage_library(l.id)
  )
);

-- UPDATE (upsert)
DROP POLICY IF EXISTS "library_regimentos_public_constitution_update" ON storage.objects;
CREATE POLICY "library_regimentos_public_constitution_update"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'library-regimentos-public'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(name))[2]
      AND public.user_can_engage_library(l.id)
  )
)
WITH CHECK (
  bucket_id = 'library-regimentos-public'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(name))[2]
      AND public.user_can_engage_library(l.id)
  )
);

-- SELECT (défensif : relecture/list côté client)
DROP POLICY IF EXISTS "library_regimentos_public_constitution_select" ON storage.objects;
CREATE POLICY "library_regimentos_public_constitution_select"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'library-regimentos-public'
  AND EXISTS (
    SELECT 1 FROM public.libraries l
    WHERE l.slug = (storage.foldername(name))[2]
      AND public.user_can_engage_library(l.id)
  )
);

-- Garde-fou : les 3 policies doivent exister.
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM pg_policies
   WHERE schemaname='storage' AND tablename='objects'
     AND policyname IN ('library_regimentos_public_constitution_insert',
                        'library_regimentos_public_constitution_update',
                        'library_regimentos_public_constitution_select');
  IF n <> 3 THEN
    RAISE EXCEPTION 'KO: policies regimento upload pré-actif incomplètes (% / 3)', n;
  END IF;
  RAISE NOTICE 'ONBO-Q2 volet 10 OK : upload regimento pré-actif autorisé (3 policies storage).';
END $$;
