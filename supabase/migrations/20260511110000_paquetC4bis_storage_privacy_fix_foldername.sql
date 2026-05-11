-- ============================================================================
-- 20260511110000_paquetC4bis_storage_privacy_fix_foldername.sql
-- ============================================================================
-- Paquet C.4bis — Correction du bug de référencement dans les 3 policies 
--                 privacy de storage.objects.
--
-- Contexte du bug :
--   Le paquet C.4 a écrit les policies avec ce pattern :
--       EXISTS ( SELECT 1 FROM libraries l 
--                WHERE l.slug = (storage.foldername(name))[1] 
--                  AND user_can_engage_library(l.id) )
--   
--   La référence non préfixée `name` aurait dû désigner la colonne `name`
--   de storage.objects (la table sur laquelle s'applique la policy, donc le
--   CHEMIN du fichier). Mais PostgreSQL a résolu silencieusement `name` vers
--   `l.name` (la colonne `name` de la table libraries dans la sous-requête,
--   donc le NOM HUMAIN de la bibliothèque, par exemple "Biblioteca Terra Libre").
--   
--   Résultat : storage.foldername('Biblioteca Terra Libre')[1] = NULL
--   (la fonction attend un chemin avec /, le nom n'en a pas).
--   Donc l.slug = NULL est toujours faux, et l'EXISTS retourne toujours false.
--   
--   Conséquence en prod : depuis l'application de C.4, PERSONNE ne peut
--   uploader/modifier/supprimer des fichiers dans le bucket library-privacy-public.
--   (Bug confirmé par requête de diagnostic du 11/05/2026.)
--
-- Le fix : préfixer explicitement `storage.objects.name` (avec qualification
-- complète) pour lever l'ambiguïté et forcer PostgreSQL à utiliser la
-- bonne colonne, à savoir le chemin du fichier.
--
-- AVANT (bug) :
--   WHERE l.slug = (storage.foldername(name))[1]
--                                       ^^^^
--                                       résolu en l.name (BUG)
--
-- APRÈS (fix) :
--   WHERE l.slug = (storage.foldername(storage.objects.name))[1]
--                                       ^^^^^^^^^^^^^^^^^^^
--                                       qualification complète, sans ambiguïté
--
-- Atomicité : transaction unique avec validation.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : Réécriture des 3 policies privacy avec la bonne référence
-- ============================================================================

-- 1.1 DELETE
DROP POLICY IF EXISTS "Coordenadors can delete privacy sections" 
    ON storage.objects;

CREATE POLICY "Coordenadors can delete privacy sections"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'library-privacy-public'::text
        AND EXISTS (
            SELECT 1 
            FROM public.libraries l
            WHERE l.slug = (storage.foldername(storage.objects.name))[1]
              AND user_can_engage_library(l.id)
        )
    );

-- 1.2 UPDATE
DROP POLICY IF EXISTS "Coordenadors can update privacy sections" 
    ON storage.objects;

CREATE POLICY "Coordenadors can update privacy sections"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'library-privacy-public'::text
        AND EXISTS (
            SELECT 1 
            FROM public.libraries l
            WHERE l.slug = (storage.foldername(storage.objects.name))[1]
              AND user_can_engage_library(l.id)
        )
    );

-- 1.3 INSERT
DROP POLICY IF EXISTS "Coordenadors can upload privacy sections" 
    ON storage.objects;

CREATE POLICY "Coordenadors can upload privacy sections"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'library-privacy-public'::text
        AND EXISTS (
            SELECT 1 
            FROM public.libraries l
            WHERE l.slug = (storage.foldername(storage.objects.name))[1]
              AND user_can_engage_library(l.id)
        )
    );

-- ============================================================================
-- SECTION 2 : VALIDATIONS POST-CORRECTION
-- ============================================================================

-- 2.1 Les 3 policies privacy utilisent maintenant storage.objects.name
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname IN (
          'Coordenadors can delete privacy sections',
          'Coordenadors can update privacy sections',
          'Coordenadors can upload privacy sections'
      )
      AND (
          qual LIKE '%storage.objects.name%' 
          OR with_check LIKE '%storage.objects.name%'
          OR qual LIKE '%objects.name%' 
          OR with_check LIKE '%objects.name%'
      );
    
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'fix_count_mismatch: % policies utilisent la bonne référence (attendu : 3)', v_count;
    END IF;
    
    RAISE NOTICE 'fix_ok: 3 policies privacy utilisent maintenant storage.objects.name';
END;
$$;

-- 2.2 Les policies utilisent toujours le helper user_can_engage_library
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname IN (
          'Coordenadors can delete privacy sections',
          'Coordenadors can update privacy sections',
          'Coordenadors can upload privacy sections'
      )
      AND (
          qual LIKE '%user_can_engage_library%' 
          OR with_check LIKE '%user_can_engage_library%'
      );
    
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'helper_count_mismatch: % policies utilisent user_can_engage_library (attendu : 3)', v_count;
    END IF;
    
    RAISE NOTICE 'helper_ok: 3 policies utilisent user_can_engage_library';
END;
$$;

-- 2.3 Validation par simulation : vérifier que la sous-requête ne retourne
-- plus NULL pour un chemin valide. On simule sans agir.
DO $$
DECLARE
    v_extraction text;
BEGIN
    -- Simule l'extraction sur un chemin réaliste
    SELECT (storage.foldername('blmf/regimentos/regulamento.pdf'))[1] 
    INTO v_extraction;
    
    IF v_extraction IS NULL OR v_extraction = '' THEN
        RAISE EXCEPTION 'foldername_test_failed: storage.foldername sur un chemin valide retourne NULL';
    END IF;
    
    IF v_extraction <> 'blmf' THEN
        RAISE WARNING 'foldername_test_unexpected: extraction = %, attendu = blmf', v_extraction;
    ELSE
        RAISE NOTICE 'foldername_test_ok: storage.foldername(''blmf/...'')[1] = ''blmf''';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
--
-- 1. Lister les 3 policies corrigées, attendu : storage.objects.name dans la clause
--    SELECT policyname, cmd,
--           regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') AS clause
--    FROM pg_policies
--    WHERE schemaname = 'storage'
--      AND tablename = 'objects'
--      AND policyname LIKE 'Coordenadors%'
--    ORDER BY policyname;
--
-- 2. Test côté Xavier : il devrait pouvoir voir/uploader sur BLMF et BTL
--    (ce test passe par l'UI uploads de fichiers privacy)
--
-- 3. Test côté Patricia : elle devrait pouvoir uploader sur BTL,
--    mais pas sur BLMF
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
