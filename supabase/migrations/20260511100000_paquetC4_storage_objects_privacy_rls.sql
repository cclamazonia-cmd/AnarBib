-- ============================================================================
-- 20260511100000_paquetC4_storage_objects_privacy_rls.sql
-- ============================================================================
-- Paquet C.4 — Bascule des RLS storage.objects sur les nouveaux helpers
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3
--
-- AUDIT du 11/05/2026 : 28 policies sur storage.objects, réparties ainsi :
--
-- A) 24 policies catalogacao (6 buckets × 4 actions) DÉJÀ CONFORMES :
--      anarbib-pdf-public, authors, covers, library-regimentos-private,
--      library-regimentos-public, pdf-restrito
--    Pattern : EXISTS api.my_access WHERE can_access_catalogacao = true
--    → Ces policies sont DÉJÀ basculées de fait, depuis le paquet B qui a
--      réécrit api.my_access pour que can_access_catalogacao soit calculé
--      sur l'UNION (staff local OR admin réseau).
--    → AUCUNE MODIFICATION NÉCESSAIRE pour ces 24 policies.
--
-- B) 1 policy de lecture publique INTACTE :
--      "Privacy sections are publicly readable" (SELECT, TO public)
--      Sémantique : tout le monde peut lire library-privacy-public.
--      Hors scope du paquet C (visibilité publique, comme libraries_public_read).
--
-- C) 3 policies privacy à BASCULER :
--      "Coordenadors can delete privacy sections"
--      "Coordenadors can update privacy sections"
--      "Coordenadors can upload privacy sections"
--    Pattern : extrait le slug du premier dossier du chemin, puis vérifie
--    que l'appelant a un rôle staff (coord/admin) sur la biblio correspondante.
--    Catégorie B (engagement politique : seul coord ou admin réseau peut
--    modifier les sections privacy publiques de leur biblio).
--
-- Bascule : pattern (EXISTS membership WHERE role IN (coord, administrador))
--   →     EXISTS libraries WHERE slug = folder[1] AND user_can_engage_library(id)
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : Bascule des 3 policies privacy
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
            WHERE l.slug = (storage.foldername(name))[1]
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
            WHERE l.slug = (storage.foldername(name))[1]
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
            WHERE l.slug = (storage.foldername(name))[1]
              AND user_can_engage_library(l.id)
        )
    );

-- ============================================================================
-- SECTION 2 : DOCUMENTATION DES POLICIES NON TOUCHÉES
-- ============================================================================
-- Pour mémoire d'audit, on ne peut pas mettre de COMMENT sur les policies
-- de storage.objects sans privilège owner du schéma storage. Mais on trace
-- l'analyse dans le RAISE NOTICE pour qu'elle apparaisse dans les logs
-- Woodpecker, et donc dans l'historique de déploiement.

DO $$
BEGIN
    RAISE NOTICE '=== Policies storage.objects NON TOUCHÉES par C.4 ===';
    RAISE NOTICE '24 policies catalogacao (anarbib-pdf-public, authors, covers, library-regimentos-*, pdf-restrito) déjà conformes via api.my_access.can_access_catalogacao (paquet B).';
    RAISE NOTICE '1 policy de lecture publique "Privacy sections are publicly readable" intacte (hors scope C).';
END;
$$;

-- ============================================================================
-- SECTION 3 : VALIDATIONS POST-BASCULE
-- ============================================================================

-- 3.1 Les 3 policies privacy basculées utilisent user_can_engage_library
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
        RAISE EXCEPTION 'privacy_count_mismatch: % policies basculées sur user_can_engage_library (attendu : 3)', v_count;
    END IF;
    
    RAISE NOTICE 'privacy_bascule_ok: 3 policies privacy basculées sur user_can_engage_library';
END;
$$;

-- 3.2 La policy de lecture publique est intacte
DO $$
DECLARE
    v_def text;
BEGIN
    SELECT regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') INTO v_def
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'Privacy sections are publicly readable';
    
    IF v_def IS NULL THEN
        RAISE EXCEPTION 'public_read_missing: la policy "Privacy sections are publicly readable" a disparu';
    END IF;
    
    IF v_def LIKE '%user_can_engage_library%' OR v_def LIKE '%user_can_act_as_staff%' THEN
        RAISE EXCEPTION 'public_read_modified: policy modifiée par erreur, sémantique de lecture publique perdue';
    END IF;
    
    IF v_def NOT LIKE '%library-privacy-public%' THEN
        RAISE WARNING 'public_read_unexpected: pattern de la policy modifié de manière inattendue';
    END IF;
    
    RAISE NOTICE 'public_read_intact: policy de lecture publique inchangée';
END;
$$;

-- 3.3 Les 24 policies catalogacao sont toujours présentes et utilisent my_access
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND (qual LIKE '%my_access%' OR with_check LIKE '%my_access%');
    
    IF v_count < 24 THEN
        RAISE WARNING 'catalogacao_count_low: % policies catalogacao trouvées (attendu : 24, peut-être affectées par erreur)', v_count;
    ELSE
        RAISE NOTICE 'catalogacao_intact_ok: % policies catalogacao toujours via api.my_access', v_count;
    END IF;
END;
$$;

-- 3.4 Helper user_can_engage_library présent
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' 
          AND p.proname = 'user_can_engage_library'
    ) THEN
        RAISE EXCEPTION 'helper_missing: user_can_engage_library() introuvable';
    END IF;
    
    RAISE NOTICE 'helper_ok: user_can_engage_library() présente';
END;
$$;

-- 3.5 RLS activée sur storage.objects
DO $$
DECLARE
    v_rls boolean;
BEGIN
    SELECT rowsecurity INTO v_rls
    FROM pg_tables
    WHERE schemaname = 'storage' AND tablename = 'objects';
    
    IF NOT v_rls THEN
        RAISE WARNING 'rls_disabled: storage.objects a RLS désactivée';
    ELSE
        RAISE NOTICE 'rls_enabled_ok: RLS activée sur storage.objects';
    END IF;
END;
$$;

-- 3.6 Aucune mention inline de 'administrador' dans les 3 policies basculées
DO $$
DECLARE
    v_remaining integer;
BEGIN
    SELECT count(*) INTO v_remaining
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname IN (
          'Coordenadors can delete privacy sections',
          'Coordenadors can update privacy sections',
          'Coordenadors can upload privacy sections'
      )
      AND (qual LIKE '%administrador%' OR with_check LIKE '%administrador%');
    
    IF v_remaining > 0 THEN
        RAISE WARNING 'remaining_administrador: % policies mentionnent encore administrador en inline', v_remaining;
    ELSE
        RAISE NOTICE 'cleanup_ok: aucune mention inline de administrador dans les 3 policies basculées';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- Pattern pour tester les RLS storage : il faut SET LOCAL ROLE authenticated
-- + JWT claims pour simuler un utilisateur.
--
-- Test 1 : lister les 3 policies privacy basculées (attendu : 3 lignes avec
-- user_can_engage_library dans la clause)
--    SELECT policyname, cmd,
--           regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') AS clause
--    FROM pg_policies
--    WHERE schemaname = 'storage'
--      AND tablename = 'objects'
--      AND policyname LIKE 'Coordenadors%'
--    ORDER BY policyname;
--
-- Test 2 : vérifier que les 24 policies catalogacao sont toujours là et
-- pointent toujours sur my_access (attendu : 24 lignes)
--    SELECT policyname, cmd
--    FROM pg_policies
--    WHERE schemaname = 'storage'
--      AND tablename = 'objects'
--      AND (qual LIKE '%my_access%' OR with_check LIKE '%my_access%')
--    ORDER BY policyname;
--
-- Test 3 (frontend) : Xavier peut uploader/modifier des sections privacy
-- de BLMF (il est coord BLMF), et également sur BTL (admin réseau).
-- Patricia peut le faire sur BTL (coord BTL) mais pas sur BLMF.
-- À tester via l'UI de gestion privacy.
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
