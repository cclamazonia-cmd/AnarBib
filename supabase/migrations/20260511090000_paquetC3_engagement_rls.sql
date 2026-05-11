-- ============================================================================
-- 20260511090000_paquetC3_engagement_rls.sql
-- ============================================================================
-- Paquet C.3 — Bascule des RLS d'engagement politique sur les nouveaux helpers
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3
--
-- 7 policies sur 3 tables, traitées différemment selon leur sémantique :
--
-- 4 policies basculées vers user_can_engage_library (catégorie B) :
--   - lmr_modify              (ALL  sur library_membership_rules)
--   - lrp_modify_management   (ALL  sur library_retention_policies)
--   - mp_modify_staff         (ALL  sur membership_payments)
--   - mp_select_staff         (SELECT sur membership_payments)
--
-- 1 policy basculée vers user_can_act_as_staff_on_library (catégorie A) :
--   - lrp_select_staff        (SELECT sur library_retention_policies)
--
-- 1 policy au pattern inline préservé (lecteurs inclus, hors catégorie) :
--   - lmr_select              (SELECT sur library_membership_rules)
--     Sémantique : tout membre actif (y compris lecteur) peut lire les
--     règles d'adhésion de la biblio dont il est membre. Pas couvert par
--     les helpers actuels car les lecteurs ne sont pas du staff ni admin
--     réseau. Pattern inline préservé tel quel pour ne pas créer un
--     helper monobjet.
--
-- 1 policy laissée intacte (logique personnelle non liée aux rôles) :
--   - mp_select_own           (SELECT sur membership_payments)
--     Sémantique : chacun voit ses propres paiements (user_id = auth.uid()).
--     Hors scope du paquet C.
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : library_membership_rules (2 policies, traitements différents)
-- ============================================================================

-- 1.1 lmr_modify (ALL) → user_can_engage_library (catégorie B)
DROP POLICY IF EXISTS lmr_modify 
    ON public.library_membership_rules;

CREATE POLICY lmr_modify
    ON public.library_membership_rules
    FOR ALL
    TO authenticated
    USING (user_can_engage_library(library_id))
    WITH CHECK (user_can_engage_library(library_id));

COMMENT ON POLICY lmr_modify 
    ON public.library_membership_rules IS
'Modification des règles d''adhésion : engagement politique de la biblio (coordenador ou admin réseau). Paquet C.3 (11/05/2026).';

-- 1.2 lmr_select (SELECT) → pattern inline préservé (lecteurs inclus)
-- Sémantique : tout membre actif voit les règles d'adhésion.
-- NON couverte par les helpers du paquet A car inclut les lecteurs.
-- On préserve le pattern d'origine sans modification.
DROP POLICY IF EXISTS lmr_select 
    ON public.library_membership_rules;

CREATE POLICY lmr_select
    ON public.library_membership_rules
    FOR SELECT
    TO authenticated
    USING (EXISTS (
        SELECT 1 
        FROM public.user_library_memberships m 
        WHERE m.user_id = auth.uid() 
          AND m.library_id = library_membership_rules.library_id 
          AND m.status = 'active'
    ));

COMMENT ON POLICY lmr_select 
    ON public.library_membership_rules IS
'Lecture des règles d''adhésion : tout membre actif (lecteur, staff, admin réseau via membership local). Pattern inline préservé car les lecteurs ne sont pas couverts par les helpers du paquet A. Paquet C.3 (11/05/2026).';

-- ============================================================================
-- SECTION 2 : library_retention_policies (2 policies)
-- ============================================================================

-- 2.1 lrp_select_staff (SELECT) → user_can_act_as_staff_on_library (catégorie A)
-- Sémantique : tout le staff peut lire la politique de rétention, y compris
-- librarian. Pas seulement l'engagement (coordenador), mais aussi
-- l'opérationnel (librarian).
DROP POLICY IF EXISTS lrp_select_staff 
    ON public.library_retention_policies;

CREATE POLICY lrp_select_staff
    ON public.library_retention_policies
    FOR SELECT
    TO authenticated
    USING (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY lrp_select_staff 
    ON public.library_retention_policies IS
'Lecture de la politique de rétention : staff local ou admin réseau. Paquet C.3 (11/05/2026).';

-- 2.2 lrp_modify_management (ALL) → user_can_engage_library (catégorie B)
-- Sémantique : seul l'engagement politique peut modifier la rétention.
DROP POLICY IF EXISTS lrp_modify_management 
    ON public.library_retention_policies;

CREATE POLICY lrp_modify_management
    ON public.library_retention_policies
    FOR ALL
    TO authenticated
    USING (user_can_engage_library(library_id))
    WITH CHECK (user_can_engage_library(library_id));

COMMENT ON POLICY lrp_modify_management 
    ON public.library_retention_policies IS
'Modification de la politique de rétention : engagement politique de la biblio (coordenador ou admin réseau). Paquet C.3 (11/05/2026).';

-- ============================================================================
-- SECTION 3 : membership_payments (3 policies, dont 1 intacte)
-- ============================================================================

-- 3.1 mp_select_staff (SELECT) → user_can_engage_library (catégorie B)
DROP POLICY IF EXISTS mp_select_staff 
    ON public.membership_payments;

CREATE POLICY mp_select_staff
    ON public.membership_payments
    FOR SELECT
    TO authenticated
    USING (user_can_engage_library(library_id));

COMMENT ON POLICY mp_select_staff 
    ON public.membership_payments IS
'Lecture des paiements d''adhésion : engagement politique de la biblio (coordenador ou admin réseau). Paquet C.3 (11/05/2026).';

-- 3.2 mp_modify_staff (ALL) → user_can_engage_library (catégorie B)
DROP POLICY IF EXISTS mp_modify_staff 
    ON public.membership_payments;

CREATE POLICY mp_modify_staff
    ON public.membership_payments
    FOR ALL
    TO authenticated
    USING (user_can_engage_library(library_id))
    WITH CHECK (user_can_engage_library(library_id));

COMMENT ON POLICY mp_modify_staff 
    ON public.membership_payments IS
'Modification des paiements d''adhésion : engagement politique de la biblio (coordenador ou admin réseau). Paquet C.3 (11/05/2026).';

-- 3.3 mp_select_own : INTACTE (lecture de ses propres paiements)
-- On ne touche pas à cette policy, elle est conceptuellement hors scope
-- du paquet C (logique personnelle, pas liée aux rôles).
-- Le bloc DO de validation §5.2 vérifie qu'elle est restée intacte.

-- ============================================================================
-- SECTION 4 : VALIDATIONS POST-BASCULE
-- ============================================================================

-- 4.1 Les 5 policies basculées utilisent un helper
DO $$
DECLARE
    v_engage_count integer;
    v_staff_count integer;
BEGIN
    SELECT count(*) INTO v_engage_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname IN ('lmr_modify', 'lrp_modify_management', 'mp_modify_staff', 'mp_select_staff')
      AND (
          qual LIKE '%user_can_engage_library%' 
          OR with_check LIKE '%user_can_engage_library%'
      );
    
    IF v_engage_count <> 4 THEN
        RAISE EXCEPTION 'engage_count_mismatch: % policies basculées sur user_can_engage_library (attendu : 4)', v_engage_count;
    END IF;
    
    SELECT count(*) INTO v_staff_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname = 'lrp_select_staff'
      AND qual LIKE '%user_can_act_as_staff_on_library%';
    
    IF v_staff_count <> 1 THEN
        RAISE EXCEPTION 'staff_count_mismatch: lrp_select_staff pas basculée sur user_can_act_as_staff_on_library';
    END IF;
    
    RAISE NOTICE 'rls_bascule_ok: 4 policies sur user_can_engage_library + 1 policy sur user_can_act_as_staff_on_library';
END;
$$;

-- 4.2 mp_select_own est intacte (pattern original préservé)
DO $$
DECLARE
    v_def text;
BEGIN
    SELECT regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') INTO v_def
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'membership_payments'
      AND policyname = 'mp_select_own';
    
    IF v_def IS NULL THEN
        RAISE EXCEPTION 'mp_select_own_missing: la policy mp_select_own a disparu';
    END IF;
    
    IF v_def NOT LIKE '%user_id = auth.uid()%' THEN
        RAISE EXCEPTION 'mp_select_own_modified: la policy a été modifiée (clause attendue : user_id = auth.uid())';
    END IF;
    
    RAISE NOTICE 'mp_select_own_intact: policy de lecture personnelle inchangée';
END;
$$;

-- 4.3 lmr_select préserve le pattern inline (lecteurs inclus)
DO $$
DECLARE
    v_def text;
BEGIN
    SELECT regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') INTO v_def
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'library_membership_rules'
      AND policyname = 'lmr_select';
    
    IF v_def IS NULL THEN
        RAISE EXCEPTION 'lmr_select_missing: la policy lmr_select a disparu';
    END IF;
    
    IF v_def LIKE '%user_can_act_as_staff_on_library%' OR v_def LIKE '%user_can_engage_library%' THEN
        RAISE EXCEPTION 'lmr_select_helper_misuse: lmr_select utilise un helper, ce qui restreindrait l''accès aux non-staff (perte des lecteurs)';
    END IF;
    
    IF v_def NOT LIKE '%user_library_memberships%' OR v_def NOT LIKE '%status = ''active''%' THEN
        RAISE WARNING 'lmr_select_pattern_unexpected: pattern inline modifié de manière inattendue';
    END IF;
    
    RAISE NOTICE 'lmr_select_pattern_ok: pattern inline préservé, lecteurs toujours inclus';
END;
$$;

-- 4.4 Aucune mention inline de 'administrador' dans les 5 policies basculées
DO $$
DECLARE
    v_remaining integer;
BEGIN
    SELECT count(*) INTO v_remaining
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname IN ('lmr_modify', 'lrp_modify_management', 'mp_modify_staff', 'mp_select_staff', 'lrp_select_staff')
      AND (
          qual LIKE '%administrador%' 
          OR with_check LIKE '%administrador%'
      );
    
    IF v_remaining > 0 THEN
        RAISE WARNING 'remaining_administrador: % policies mentionnent encore administrador en inline', v_remaining;
    ELSE
        RAISE NOTICE 'cleanup_ok: aucune mention inline de administrador dans les 5 policies basculées';
    END IF;
END;
$$;

-- 4.5 Helpers présents (paquet A appliqué)
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
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' 
          AND p.proname = 'user_can_act_as_staff_on_library'
    ) THEN
        RAISE EXCEPTION 'helper_missing: user_can_act_as_staff_on_library() introuvable';
    END IF;
    
    RAISE NOTICE 'helpers_ok: user_can_engage_library() et user_can_act_as_staff_on_library() présentes';
END;
$$;

-- 4.6 RLS activée sur les 3 tables
DO $$
DECLARE
    v_disabled integer;
BEGIN
    SELECT count(*) INTO v_disabled
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename IN ('library_retention_policies', 'library_membership_rules', 'membership_payments')
      AND rowsecurity = false;
    
    IF v_disabled > 0 THEN
        RAISE WARNING 'rls_disabled: % table(s) ont RLS désactivée', v_disabled;
    ELSE
        RAISE NOTICE 'rls_enabled_ok: RLS activée sur les 3 tables';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- Toujours penser à SET LOCAL ROLE authenticated dans le SQL Editor !
--
-- Test 1 : lister les policies finales (attendu : 7 policies au total)
--    SELECT tablename, policyname, cmd,
--           regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') AS clause
--    FROM pg_policies
--    WHERE schemaname = 'public'
--      AND tablename IN ('library_retention_policies', 'library_membership_rules', 'membership_payments')
--    ORDER BY tablename, policyname;
--
-- Test 2 : Xavier (coord BLMF + admin réseau) — peut tout faire
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    SELECT
--      (SELECT count(*) FROM public.library_membership_rules) AS lmr_count,
--      (SELECT count(*) FROM public.library_retention_policies) AS lrp_count,
--      (SELECT count(*) FROM public.membership_payments) AS mp_count;
--    ROLLBACK;
--    Attendu : counts >= 0 sans erreur (Xavier accède à tout via coord BLMF + admin réseau)
--
-- Test 3 : Patricia (coord BTL pure) — accès à BTL uniquement
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "2a42b6bd-d159-4ee0-b66b-28a03062232b"}';
--    SELECT
--      (SELECT count(*) FROM public.library_membership_rules WHERE library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca') AS lmr_blmf,
--      (SELECT count(*) FROM public.library_membership_rules WHERE library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a') AS lmr_btl;
--    ROLLBACK;
--    Attendu : lmr_blmf = 0 (Patricia n'est pas membre BLMF), lmr_btl >= 0
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
