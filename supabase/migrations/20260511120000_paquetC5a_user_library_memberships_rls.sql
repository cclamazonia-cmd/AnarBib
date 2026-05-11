-- ============================================================================
-- 20260511120000_paquetC5a_user_library_memberships_rls.sql
-- ============================================================================
-- Paquet C.5a — Bascule des RLS user_library_memberships sur les nouveaux
--               helpers + renommage de la policy admin.
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §5.4 + §6.3
--
-- 3 policies sur user_library_memberships, traitements différenciés :
--
-- 1. ulm_select_all_for_administrador → RENOMMÉE en ulm_select_all_for_network_admin
--    Pattern actuel : fn_caller_is_administrador()
--    Pattern cible  : fn_caller_is_network_admin()
--    Sémantique : un administrateur réseau voit toute la table user_library_memberships
--    (visibilité totale pour le réseau).
--
-- 2. ulm_select_own_memberships → INTACTE
--    Pattern : auth.uid() = user_id (logique personnelle, hors scope)
--
-- 3. ulm_select_staff_visible_to_staff_same_lib → BASCULÉE
--    Pattern actuel : (role IN (3 staff)) AND user_has_library_staff_role(auth.uid(), library_id)
--    Pattern cible  : (role IN (3 staff)) AND user_can_act_as_staff_on_library(library_id)
--    Sémantique : un membre staff d'une biblio voit les autres memberships staff
--    de cette biblio. Le filtre role IN (...) conserve 'administrador' pendant
--    la coexistence (Q7 : à retirer au paquet F).
--
-- IMPORTANT : cette table est CŒUR du système d'autorisation. Les helpers
-- eux-mêmes (user_can_act_as_staff_on_library, fn_caller_is_network_admin)
-- interrogent network_administrators et user_library_memberships. C'est pour
-- ça que cette bascule est faite EN DERNIER (C.5a) après C.1 à C.4 et leur
-- validation. Tout est solide à ce stade.
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : Renommage et bascule de la policy admin réseau
-- ============================================================================

-- 1.1 DROP l'ancienne policy (par son ancien nom)
DROP POLICY IF EXISTS ulm_select_all_for_administrador 
    ON public.user_library_memberships;

-- 1.2 CREATE la nouvelle policy avec le nouveau nom + nouveau helper
CREATE POLICY ulm_select_all_for_network_admin
    ON public.user_library_memberships
    FOR SELECT
    TO authenticated
    USING (fn_caller_is_network_admin());

COMMENT ON POLICY ulm_select_all_for_network_admin 
    ON public.user_library_memberships IS
'Visibilité totale de user_library_memberships pour les administrateurs réseau. Renommée du nom historique ulm_select_all_for_administrador au paquet C.5a (11/05/2026). Le helper fn_caller_is_network_admin interroge network_administrators uniquement (paquet A).';

-- ============================================================================
-- SECTION 2 : Bascule de la policy staff cross-biblio
-- ============================================================================

DROP POLICY IF EXISTS ulm_select_staff_visible_to_staff_same_lib 
    ON public.user_library_memberships;

CREATE POLICY ulm_select_staff_visible_to_staff_same_lib
    ON public.user_library_memberships
    FOR SELECT
    TO authenticated
    USING (
        role = ANY (ARRAY['librarian'::text, 'coordenador'::text, 'administrador'::text])
        AND user_can_act_as_staff_on_library(library_id)
    );

COMMENT ON POLICY ulm_select_staff_visible_to_staff_same_lib 
    ON public.user_library_memberships IS
'Visibilité des memberships staff de la même biblio pour les autres staff de cette biblio (ou admins réseau). Le filtre role IN conserve administrador pendant la coexistence (Q7 : à retirer au paquet F). Paquet C.5a (11/05/2026).';

-- ============================================================================
-- SECTION 3 : ulm_select_own_memberships INTACTE (hors scope)
-- ============================================================================
-- On ne touche pas à cette policy, elle est conceptuellement personnelle
-- (auth.uid() = user_id) et n'a rien à voir avec les rôles d'autorisation.
-- Le bloc DO §4.3 vérifie qu'elle est restée intacte.

-- ============================================================================
-- SECTION 4 : VALIDATIONS POST-BASCULE
-- ============================================================================

-- 4.1 Les 2 policies basculées existent et utilisent les nouveaux helpers
DO $$
DECLARE
    v_admin_count integer;
    v_staff_count integer;
BEGIN
    -- Policy admin réseau (renommée)
    SELECT count(*) INTO v_admin_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_library_memberships'
      AND policyname = 'ulm_select_all_for_network_admin'
      AND qual LIKE '%fn_caller_is_network_admin%';
    
    IF v_admin_count <> 1 THEN
        RAISE EXCEPTION 'admin_policy_failed: ulm_select_all_for_network_admin pas trouvée ou n''utilise pas fn_caller_is_network_admin (trouvé : %)', v_admin_count;
    END IF;
    
    -- Policy staff (basculée)
    SELECT count(*) INTO v_staff_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_library_memberships'
      AND policyname = 'ulm_select_staff_visible_to_staff_same_lib'
      AND qual LIKE '%user_can_act_as_staff_on_library%';
    
    IF v_staff_count <> 1 THEN
        RAISE EXCEPTION 'staff_policy_failed: ulm_select_staff_visible_to_staff_same_lib pas trouvée ou n''utilise pas user_can_act_as_staff_on_library (trouvé : %)', v_staff_count;
    END IF;
    
    RAISE NOTICE 'bascule_ok: 2 policies basculées (admin réseau via fn_caller_is_network_admin, staff via user_can_act_as_staff_on_library)';
END;
$$;

-- 4.2 L'ancienne policy ulm_select_all_for_administrador n'existe plus
DO $$
DECLARE
    v_old_count integer;
BEGIN
    SELECT count(*) INTO v_old_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_library_memberships'
      AND policyname = 'ulm_select_all_for_administrador';
    
    IF v_old_count > 0 THEN
        RAISE EXCEPTION 'old_policy_still_exists: ulm_select_all_for_administrador n''a pas été supprimée';
    END IF;
    
    RAISE NOTICE 'renommage_ok: ancienne policy ulm_select_all_for_administrador retirée';
END;
$$;

-- 4.3 ulm_select_own_memberships est INTACTE
DO $$
DECLARE
    v_def text;
BEGIN
    SELECT regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') INTO v_def
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_library_memberships'
      AND policyname = 'ulm_select_own_memberships';
    
    IF v_def IS NULL THEN
        RAISE EXCEPTION 'own_policy_missing: ulm_select_own_memberships a disparu';
    END IF;
    
    IF v_def LIKE '%user_can_act_as_staff_on_library%' OR v_def LIKE '%fn_caller_is_network_admin%' THEN
        RAISE EXCEPTION 'own_policy_modified: ulm_select_own_memberships modifiée par erreur';
    END IF;
    
    IF v_def NOT LIKE '%auth.uid()%' OR v_def NOT LIKE '%user_id%' THEN
        RAISE WARNING 'own_policy_unexpected: pattern inattendu pour ulm_select_own_memberships';
    END IF;
    
    RAISE NOTICE 'own_intact_ok: ulm_select_own_memberships préservée (auth.uid() = user_id)';
END;
$$;

-- 4.4 Aucune mention inline de fn_caller_is_administrador dans les policies
-- (déprécation effective de la fonction au paquet D)
DO $$
DECLARE
    v_remaining integer;
BEGIN
    SELECT count(*) INTO v_remaining
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_library_memberships'
      AND (qual LIKE '%fn_caller_is_administrador%' OR with_check LIKE '%fn_caller_is_administrador%');
    
    IF v_remaining > 0 THEN
        RAISE WARNING 'deprecated_helper_still_used: % policies utilisent encore fn_caller_is_administrador()', v_remaining;
    ELSE
        RAISE NOTICE 'cleanup_ok: aucune policy de user_library_memberships n''utilise fn_caller_is_administrador';
    END IF;
END;
$$;

-- 4.5 Helpers présents
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_caller_is_network_admin'
    ) THEN
        RAISE EXCEPTION 'helper_missing: fn_caller_is_network_admin() introuvable';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'user_can_act_as_staff_on_library'
    ) THEN
        RAISE EXCEPTION 'helper_missing: user_can_act_as_staff_on_library() introuvable';
    END IF;
    
    RAISE NOTICE 'helpers_ok: fn_caller_is_network_admin et user_can_act_as_staff_on_library présents';
END;
$$;

-- 4.6 RLS toujours activée sur user_library_memberships
DO $$
DECLARE
    v_rls boolean;
BEGIN
    SELECT rowsecurity INTO v_rls
    FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'user_library_memberships';
    
    IF NOT v_rls THEN
        RAISE EXCEPTION 'rls_disabled: user_library_memberships a RLS désactivée (cas critique)';
    END IF;
    
    RAISE NOTICE 'rls_enabled_ok: RLS toujours activée sur user_library_memberships';
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- Toujours penser à SET LOCAL ROLE authenticated dans le SQL Editor !
--
-- Test 1 : lister les 3 policies finales, attendu : 3 lignes incluant
-- la policy renommée
--    SELECT policyname, cmd,
--           regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') AS clause
--    FROM pg_policies
--    WHERE schemaname = 'public'
--      AND tablename = 'user_library_memberships'
--    ORDER BY policyname;
--
-- Test 2 : Xavier (admin réseau) voit toute la table
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    SELECT count(*) AS xavier_voit FROM public.user_library_memberships;
--    ROLLBACK;
--    Attendu : count = nombre total de memberships en base
--
-- Test 3 : Patricia voit ses propres memberships + staff de BTL (sa biblio)
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "2a42b6bd-d159-4ee0-b66b-28a03062232b"}';
--    SELECT library_id, role, count(*) FROM public.user_library_memberships GROUP BY library_id, role;
--    ROLLBACK;
--    Attendu : seulement les memberships BTL + ses propres memberships (s'ils
--    sont sur une autre biblio, ce qui n'est pas le cas)
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
