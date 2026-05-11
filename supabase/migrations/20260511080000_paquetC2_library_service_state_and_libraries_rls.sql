-- ============================================================================
-- 20260511080000_paquetC2_library_service_state_and_libraries_rls.sql
-- ============================================================================
-- Paquet C.2 — Bascule des RLS library_service_state (3 policies) + 
--              libraries_staff_update (1 policy) sur les nouveaux helpers.
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3
--
-- 4 policies à basculer (catégorie A : staff local + admin réseau) :
--
--   - library_service_state_select_team    (SELECT)
--   - library_service_state_insert_team    (INSERT)
--   - library_service_state_update_team    (UPDATE)
--   - libraries_staff_update               (UPDATE) — avec is_restricted check préservé
--
-- POLICY NON TOUCHÉE : libraries_public_read (logique de visibilité publique
-- via fn_current_user_is_in_network + fn_current_user_is_member_of,
-- conceptuellement différente, hors scope du paquet C).
--
-- AVANT (catégorie A standard) :
--   USING (EXISTS ( SELECT 1 FROM user_library_memberships m
--      WHERE m.user_id = auth.uid() 
--        AND m.library_id = <table>.library_id 
--        AND m.role = ANY (ARRAY['librarian','coordenador','administrador'])
--        AND m.status = 'active'))
--
-- APRÈS :
--   USING (user_can_act_as_staff_on_library(<table>.library_id))
--
-- Cas particulier libraries_staff_update : préservation du garde-fou
-- is_restricted (utilisateur en mise en pause administrative ne peut
-- pas modifier les biblios même s'il a un rôle staff). Inline pour
-- ne pas modifier la sémantique du helper.
--
--   USING (user_can_act_as_staff_on_library(id) 
--          AND NOT COALESCE((SELECT is_restricted FROM profiles 
--                             WHERE id = auth.uid()), false))
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : library_service_state (3 policies)
-- ============================================================================

-- 1.1 SELECT policy
DROP POLICY IF EXISTS library_service_state_select_team 
    ON public.library_service_state;

CREATE POLICY library_service_state_select_team
    ON public.library_service_state
    FOR SELECT
    TO authenticated
    USING (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY library_service_state_select_team 
    ON public.library_service_state IS
'Lecture de l''état de service : staff local ou admin réseau. Paquet C.2 (11/05/2026).';

-- 1.2 INSERT policy
DROP POLICY IF EXISTS library_service_state_insert_team 
    ON public.library_service_state;

CREATE POLICY library_service_state_insert_team
    ON public.library_service_state
    FOR INSERT
    TO authenticated
    WITH CHECK (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY library_service_state_insert_team 
    ON public.library_service_state IS
'Création d''état de service : staff local ou admin réseau. Paquet C.2 (11/05/2026).';

-- 1.3 UPDATE policy
DROP POLICY IF EXISTS library_service_state_update_team 
    ON public.library_service_state;

CREATE POLICY library_service_state_update_team
    ON public.library_service_state
    FOR UPDATE
    TO authenticated
    USING (user_can_act_as_staff_on_library(library_id))
    WITH CHECK (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY library_service_state_update_team 
    ON public.library_service_state IS
'Modification d''état de service : staff local ou admin réseau. Paquet C.2 (11/05/2026).';

-- ============================================================================
-- SECTION 2 : libraries_staff_update (1 policy, avec is_restricted)
-- ============================================================================

DROP POLICY IF EXISTS libraries_staff_update 
    ON public.libraries;

CREATE POLICY libraries_staff_update
    ON public.libraries
    FOR UPDATE
    TO authenticated
    USING (
        user_can_act_as_staff_on_library(id)
        AND NOT COALESCE(
            (SELECT is_restricted FROM public.profiles WHERE id = auth.uid()), 
            false
        )
    );

COMMENT ON POLICY libraries_staff_update ON public.libraries IS
'Modification d''une biblio : staff local ou admin réseau, sauf si is_restricted=true. Paquet C.2 (11/05/2026). Le garde-fou is_restricted est préservé inline car il ne concerne pas toutes les RLS catégorie A.';

-- ============================================================================
-- SECTION 3 : VALIDATIONS POST-BASCULE
-- ============================================================================

-- 3.1 Les 4 policies basculées existent et utilisent le nouveau helper
DO $$
DECLARE
    v_count integer;
    v_expected integer := 4;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname IN (
          'library_service_state_select_team',
          'library_service_state_insert_team',
          'library_service_state_update_team',
          'libraries_staff_update'
      )
      AND (
          qual LIKE '%user_can_act_as_staff_on_library%' 
          OR with_check LIKE '%user_can_act_as_staff_on_library%'
      );
    
    IF v_count <> v_expected THEN
        RAISE EXCEPTION 'rls_count_mismatch: % policies basculées (attendu : %)', v_count, v_expected;
    END IF;
    
    RAISE NOTICE 'rls_bascule_ok: % policies basculées sur user_can_act_as_staff_on_library', v_count;
END;
$$;

-- 3.2 libraries_public_read est toujours en place et inchangée
DO $$
DECLARE
    v_def text;
BEGIN
    SELECT regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') INTO v_def
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'libraries'
      AND policyname = 'libraries_public_read';
    
    IF v_def IS NULL THEN
        RAISE EXCEPTION 'libraries_public_read_missing: la policy de lecture publique a disparu';
    END IF;
    
    IF v_def LIKE '%user_can_act_as_staff_on_library%' THEN
        RAISE EXCEPTION 'libraries_public_read_modified: la policy aurait été modifiée par erreur';
    END IF;
    
    RAISE NOTICE 'libraries_public_read_intact: policy de lecture publique inchangée';
END;
$$;

-- 3.3 Aucune mention inline de 'administrador' dans les 4 policies basculées
DO $$
DECLARE
    v_remaining integer;
BEGIN
    SELECT count(*) INTO v_remaining
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname IN (
          'library_service_state_select_team',
          'library_service_state_insert_team',
          'library_service_state_update_team',
          'libraries_staff_update'
      )
      AND (
          qual LIKE '%administrador%' 
          OR with_check LIKE '%administrador%'
      );
    
    IF v_remaining > 0 THEN
        RAISE WARNING 'remaining_administrador: % policies mentionnent encore administrador en inline', v_remaining;
    ELSE
        RAISE NOTICE 'cleanup_ok: aucune mention inline de administrador dans les 4 policies basculées';
    END IF;
END;
$$;

-- 3.4 Helper toujours présent
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' 
          AND p.proname = 'user_can_act_as_staff_on_library'
    ) THEN
        RAISE EXCEPTION 'helper_missing: user_can_act_as_staff_on_library() introuvable';
    END IF;
    
    RAISE NOTICE 'helper_ok: user_can_act_as_staff_on_library() présente';
END;
$$;

-- 3.5 RLS activée sur les 2 tables
DO $$
DECLARE
    v_disabled_count integer;
BEGIN
    SELECT count(*) INTO v_disabled_count
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename IN ('library_service_state', 'libraries')
      AND rowsecurity = false;
    
    IF v_disabled_count > 0 THEN
        RAISE WARNING 'rls_disabled: % table(s) ont RLS désactivée', v_disabled_count;
    ELSE
        RAISE NOTICE 'rls_enabled_ok: RLS activée sur library_service_state et libraries';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- Lancer ces tests dans SQL Editor en pensant à SET LOCAL ROLE authenticated
-- (sinon les RLS sont bypass en service_role).
--
-- Test 1 : lister les 5 policies sur les 2 tables, attendu : 5 lignes
--    SELECT tablename, policyname, cmd,
--           regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') AS clause
--    FROM pg_policies
--    WHERE schemaname = 'public'
--      AND tablename IN ('library_service_state', 'libraries')
--    ORDER BY tablename, policyname;
--
-- Test 2 : Xavier peut SELECT library_service_state sur BLMF et BTL :
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    SELECT count(*) AS xavier_voit_states FROM public.library_service_state;
--    ROLLBACK;
--    Attendu : count >= 0, accès aux 2 biblios (BLMF via coord, BTL via admin réseau)
--
-- Test 3 : Patricia voit BTL mais pas BLMF dans library_service_state :
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "2a42b6bd-d159-4ee0-b66b-28a03062232b"}';
--    SELECT library_id, count(*) FROM public.library_service_state GROUP BY library_id;
--    ROLLBACK;
--    Attendu : Patricia ne voit que les lignes BTL
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
