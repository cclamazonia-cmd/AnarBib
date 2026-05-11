-- ============================================================================
-- 20260511070000_paquetC1_painel_internal_tasks_rls.sql
-- ============================================================================
-- Paquet C.1 — Bascule des RLS painel_internal_tasks (+ outbox) sur les
--              nouveaux helpers d'autorisation.
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3 (Plan paquet C)
--
-- 7 policies à basculer :
--   - painel_internal_tasks_delete_same_library_team   (DELETE)
--   - painel_internal_tasks_insert_same_library_team   (INSERT)
--   - painel_internal_tasks_select_same_library_team   (SELECT)
--   - painel_internal_tasks_update_same_library_team   (UPDATE)
--   - painel_internal_task_invites_select_same_library_team (SELECT)
--   - painel_internal_task_invitation_outbox_select_same_library_team (SELECT)
--   - painel_internal_task_notification_outbox_select_same_library_te (SELECT, nom tronqué à 63 chars)
--
-- AVANT (pattern catégorie A) :
--   USING (EXISTS ( SELECT 1
--      FROM user_library_memberships m
--     WHERE m.user_id = auth.uid() 
--       AND m.library_id = <table>.library_id 
--       AND m.role = ANY (ARRAY['librarian','coordenador','administrador'])
--       AND m.status = 'active'))
--
-- APRÈS :
--   USING (user_can_act_as_staff_on_library(<table>.library_id))
--
-- Le helper user_can_act_as_staff_on_library inclut :
--   - librarian, coordenador (staff local actif)
--   - admin réseau actif (network_administrators avec status='active')
-- 
-- Il N'INCLUT PAS 'administrador' du rôle local : c'est volontaire (paquet F
-- supprimera ce rôle de user_library_memberships). Pendant la coexistence :
--   - Xavier garde l'accès via son coordenador BLMF (rôle local)
--   - Xavier garde l'accès cross-biblios via son admin réseau (Q7 double filet)
--   - Sa ligne administrador BLMF du 24/03 devient inactive POUR CETTE RLS
--     (mais reste en base, paquet F la supprimera)
--
-- Atomicité : transaction unique. Validation post-bascule via blocs DO.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : painel_internal_tasks (4 policies)
-- ============================================================================

-- 1.1 SELECT policy
DROP POLICY IF EXISTS painel_internal_tasks_select_same_library_team 
    ON public.painel_internal_tasks;

CREATE POLICY painel_internal_tasks_select_same_library_team
    ON public.painel_internal_tasks
    FOR SELECT
    TO public
    USING (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY painel_internal_tasks_select_same_library_team 
    ON public.painel_internal_tasks IS
'Lecture des tâches internes : staff local ou admin réseau. Paquet C.1 (11/05/2026).';

-- 1.2 INSERT policy
DROP POLICY IF EXISTS painel_internal_tasks_insert_same_library_team 
    ON public.painel_internal_tasks;

CREATE POLICY painel_internal_tasks_insert_same_library_team
    ON public.painel_internal_tasks
    FOR INSERT
    TO public
    WITH CHECK (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY painel_internal_tasks_insert_same_library_team 
    ON public.painel_internal_tasks IS
'Création de tâches internes : staff local ou admin réseau. Paquet C.1 (11/05/2026).';

-- 1.3 UPDATE policy
DROP POLICY IF EXISTS painel_internal_tasks_update_same_library_team 
    ON public.painel_internal_tasks;

CREATE POLICY painel_internal_tasks_update_same_library_team
    ON public.painel_internal_tasks
    FOR UPDATE
    TO public
    USING (user_can_act_as_staff_on_library(library_id))
    WITH CHECK (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY painel_internal_tasks_update_same_library_team 
    ON public.painel_internal_tasks IS
'Modification de tâches internes : staff local ou admin réseau. Paquet C.1 (11/05/2026).';

-- 1.4 DELETE policy
DROP POLICY IF EXISTS painel_internal_tasks_delete_same_library_team 
    ON public.painel_internal_tasks;

CREATE POLICY painel_internal_tasks_delete_same_library_team
    ON public.painel_internal_tasks
    FOR DELETE
    TO public
    USING (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY painel_internal_tasks_delete_same_library_team 
    ON public.painel_internal_tasks IS
'Suppression de tâches internes : staff local ou admin réseau. Paquet C.1 (11/05/2026).';

-- ============================================================================
-- SECTION 2 : painel_internal_task_invites (1 policy)
-- ============================================================================

DROP POLICY IF EXISTS painel_internal_task_invites_select_same_library_team 
    ON public.painel_internal_task_invites;

CREATE POLICY painel_internal_task_invites_select_same_library_team
    ON public.painel_internal_task_invites
    FOR SELECT
    TO public
    USING (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY painel_internal_task_invites_select_same_library_team 
    ON public.painel_internal_task_invites IS
'Lecture des invitations sur tâches internes : staff local ou admin réseau. Paquet C.1.';

-- ============================================================================
-- SECTION 3 : painel_internal_task_invitation_outbox (1 policy)
-- ============================================================================

DROP POLICY IF EXISTS painel_internal_task_invitation_outbox_select_same_library_team 
    ON public.painel_internal_task_invitation_outbox;

CREATE POLICY painel_internal_task_invitation_outbox_select_same_library_team
    ON public.painel_internal_task_invitation_outbox
    FOR SELECT
    TO public
    USING (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY painel_internal_task_invitation_outbox_select_same_library_team 
    ON public.painel_internal_task_invitation_outbox IS
'Lecture outbox invitations tâches : staff local ou admin réseau. Paquet C.1.';

-- ============================================================================
-- SECTION 4 : painel_internal_task_notification_outbox (1 policy)
-- ============================================================================
-- Note : le nom de policy est tronqué à 63 chars par PostgreSQL
-- (painel_internal_task_notification_outbox_select_same_library_te)

DROP POLICY IF EXISTS painel_internal_task_notification_outbox_select_same_library_te 
    ON public.painel_internal_task_notification_outbox;

CREATE POLICY painel_internal_task_notification_outbox_select_same_library_te
    ON public.painel_internal_task_notification_outbox
    FOR SELECT
    TO public
    USING (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY painel_internal_task_notification_outbox_select_same_library_te 
    ON public.painel_internal_task_notification_outbox IS
'Lecture outbox notifications tâches : staff local ou admin réseau. Paquet C.1.';

-- ============================================================================
-- SECTION 5 : VALIDATIONS POST-BASCULE
-- ============================================================================

-- 5.1 Vérification : les 7 policies existent bien et utilisent le nouveau helper
DO $$
DECLARE
    v_count integer;
    v_expected integer := 7;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
          'painel_internal_tasks',
          'painel_internal_task_invites',
          'painel_internal_task_invitation_outbox',
          'painel_internal_task_notification_outbox'
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

-- 5.2 Vérification : aucune policy de ces tables ne mentionne plus 'administrador' 
--     dans une sous-requête inline (signe que la bascule est complète)
DO $$
DECLARE
    v_remaining integer;
BEGIN
    SELECT count(*) INTO v_remaining
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
          'painel_internal_tasks',
          'painel_internal_task_invites',
          'painel_internal_task_invitation_outbox',
          'painel_internal_task_notification_outbox'
      )
      AND (
          qual LIKE '%administrador%' 
          OR with_check LIKE '%administrador%'
      );
    
    IF v_remaining > 0 THEN
        RAISE WARNING 'remaining_administrador: % policies mentionnent encore administrador en inline (cas non prévu)', v_remaining;
    ELSE
        RAISE NOTICE 'cleanup_ok: aucune mention inline de administrador dans les RLS basculées';
    END IF;
END;
$$;

-- 5.3 Vérification : le helper user_can_act_as_staff_on_library est bien là
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' 
          AND p.proname = 'user_can_act_as_staff_on_library'
    ) THEN
        RAISE EXCEPTION 'helper_missing: user_can_act_as_staff_on_library() introuvable (paquet A pas appliqué ?)';
    END IF;
    
    RAISE NOTICE 'helper_ok: user_can_act_as_staff_on_library() présente';
END;
$$;

-- 5.4 Smoke test : count(*) sur painel_internal_tasks
-- (en service_role, donc bypass RLS, juste pour confirmer que la table existe et est intacte)
DO $$
DECLARE
    v_tasks_count integer;
BEGIN
    SELECT count(*) INTO v_tasks_count FROM public.painel_internal_tasks;
    RAISE NOTICE 'data_integrity_ok: painel_internal_tasks contient % lignes (avant et après bascule, ne devrait pas avoir changé)', v_tasks_count;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
--
-- 1. Lister les policies basculées (devrait montrer les 7 utilisant le helper) :
--    SELECT tablename, policyname, cmd,
--           regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') AS clause
--    FROM pg_policies
--    WHERE schemaname = 'public'
--      AND tablename LIKE 'painel_internal_task%'
--    ORDER BY tablename, policyname;
--    Attendu : 7 lignes, toutes avec user_can_act_as_staff_on_library
--
-- 2. Test côté Xavier en simulant son auth :
--    BEGIN;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    SELECT count(*) FROM public.painel_internal_tasks 
--      WHERE library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'; -- BLMF
--    SELECT count(*) FROM public.painel_internal_tasks 
--      WHERE library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'; -- BTL
--    ROLLBACK;
--    Attendu : pas d'erreur, count >= 0 sur les deux biblios
--    (Xavier voit BLMF via son coord, voit BTL via son admin réseau)
--
-- 3. Test côté Patricia en simulant son auth :
--    BEGIN;
--    SET LOCAL "request.jwt.claims" = '{"sub": "2a42b6bd-d159-4ee0-b66b-28a03062232b"}';
--    SELECT count(*) FROM public.painel_internal_tasks 
--      WHERE library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'; -- BTL
--    SELECT count(*) FROM public.painel_internal_tasks 
--      WHERE library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'; -- BLMF
--    ROLLBACK;
--    Attendu : count >= 0 sur BTL, mais SELECT bloqué (0 lignes) sur BLMF
--    (Patricia est coord BTL uniquement, pas admin réseau, pas accès BLMF)
--
-- 4. Recharger /painel onglet tâches dans le navigateur (Ctrl+Shift+R)
--    En tant que Xavier : doit voir les tâches BLMF (et BTL si tâches existantes)
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
