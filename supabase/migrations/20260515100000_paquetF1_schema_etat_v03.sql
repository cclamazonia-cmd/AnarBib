-- ============================================================================
-- Paquet F.1 - Schema + etat doctrinal v0.3
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Ref.  : docs/spec-administrateur-reseau.md v0.3
--
-- Contexte
-- --------
-- Finalisation chantier admin reseau v0.3 : suppression definitive du role
-- local 'administrador' dans user_library_memberships et dans tout le
-- schema (CHECK, vue api.my_access, policies RLS).
--
-- L'audit pre-F.1 a identifie :
--   - 1 ligne ulm role='administrador' status='active' (Xavier a BLMF, en
--     doublon avec sa ligne coordenador active)
--   - 0 ligne historique (status != active)
--   - 1 vue : api.my_access (CTE has_any_staff_membership)
--   - 2 policies RLS :
--       * public.ulm_select_staff_visible_to_staff_same_lib
--       * public.author_translations_librarian_write
--   - 17 fonctions a refacturer en F.2 et F.3 (paquets suivants)
--
-- Doctrine v0.3
-- -------------
-- Le role 'administrador' local est entierement remplace par le concept
-- d'administrateur reseau (table network_administrators, transverse).
-- Les actions de gouvernance (cooptation, retrait) se font via les RPC
-- fn_network_admin_*. Plus aucun ulm n'aura role='administrador'.
--
-- Effet en prod
-- -------------
-- - Xavier reste coordenador a BLMF (sa ligne coordenador active subsiste).
-- - Xavier reste admin reseau (via network_administrators, hors ulm).
-- - api.my_access continuera de fonctionner pour Xavier (il a staff role
--   coordenador donc has_staff_membership=true).
-- - Plus aucun row ne peut avoir role='administrador' (CHECK refuse).
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Cleanup ulm : retirer la ligne administrador de Xavier
-- ============================================================================

-- Confirmation avant DELETE : 1 et 1 seule ligne attendue
DO $$
DECLARE
    v_count int;
BEGIN
    SELECT count(*) INTO v_count
    FROM public.user_library_memberships
    WHERE role = 'administrador';
    
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'unexpected count of administrador memberships: % (attendu : 1)', v_count;
    END IF;
END $$;

DELETE FROM public.user_library_memberships
WHERE role = 'administrador';

-- Verification : doit etre a 0
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.user_library_memberships WHERE role = 'administrador') THEN
        RAISE EXCEPTION 'DELETE administrador a echoue';
    END IF;
END $$;

-- ============================================================================
-- 2. ALTER CHECK constraint role : retirer 'administrador' des valeurs autorisees
-- ============================================================================

ALTER TABLE public.user_library_memberships
    DROP CONSTRAINT IF EXISTS user_library_memberships_role_check;

ALTER TABLE public.user_library_memberships
    ADD CONSTRAINT user_library_memberships_role_check
    CHECK (role IN ('reader', 'librarian', 'coordenador'));

-- ============================================================================
-- 3. ALTER vue api.my_access : retirer 'administrador' de la CTE has_any_staff_membership
-- ============================================================================

CREATE OR REPLACE VIEW api.my_access AS
 WITH base AS (
         SELECT sc.user_id,
            sc.email,
            sc.first_name,
            sc.last_name,
            sc.full_name,
            sc.is_authenticated,
            sc.is_librarian,
            sc.default_library_id,
            sc.default_library_slug,
            sc.default_library_name,
            sc.can_access_conta
           FROM api.my_session_context sc
        ), active_memberships AS (
         SELECT m.user_id,
            l.id AS library_id,
            l.slug AS library_slug,
            l.name AS library_name,
            m.role,
            m.status,
            m.is_primary,
            m.created_at
           FROM user_library_memberships m
             JOIN libraries l ON l.id = m.library_id
          WHERE m.status = 'active'::text AND l.is_active = true AND m.user_id = auth.uid()
        ), effective_membership AS (
         SELECT active_memberships.user_id,
            active_memberships.library_id,
            active_memberships.library_slug,
            active_memberships.library_name,
            active_memberships.role,
            active_memberships.status,
            active_memberships.is_primary,
            active_memberships.created_at
           FROM active_memberships
          ORDER BY active_memberships.is_primary DESC, active_memberships.created_at, active_memberships.library_slug
         LIMIT 1
        ), network_admin_status AS (
         SELECT (EXISTS ( SELECT 1
                   FROM network_administrators
                  WHERE network_administrators.user_id = auth.uid() AND network_administrators.status = 'active'::text)) AS is_network_admin
        ), has_any_staff_membership AS (
         -- F.1 v0.3 : retrait 'administrador' (role local supprime)
         SELECT (EXISTS ( SELECT 1
                   FROM active_memberships am
                  WHERE am.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))) AS has_staff
        )
 SELECT b.user_id AS id,
    b.email,
    b.is_librarian,
    COALESCE(p.is_restricted, false) AS is_restricted,
    b.default_library_id,
    b.default_library_slug,
    b.default_library_name,
    b.can_access_conta,
    (has_staff.has_staff OR na.is_network_admin) AND COALESCE(p.is_restricted, false) = false AS can_access_painel,
    (has_staff.has_staff OR na.is_network_admin) AND COALESCE(p.is_restricted, false) = false AS can_access_catalogacao,
    b.user_id,
    p.public_id,
    p.first_name,
    p.last_name,
    em.library_id,
    em.library_slug,
    em.library_name,
    em.role,
    em.status,
    em.is_primary
   FROM base b
     LEFT JOIN profiles p ON p.id = b.user_id
     LEFT JOIN effective_membership em ON em.user_id = b.user_id
     CROSS JOIN network_admin_status na
     CROSS JOIN has_any_staff_membership has_staff;

-- ============================================================================
-- 4. ALTER policies RLS : retirer 'administrador' des arrays de roles staff
-- ============================================================================

-- 4a. policy sur user_library_memberships
DROP POLICY IF EXISTS ulm_select_staff_visible_to_staff_same_lib
    ON public.user_library_memberships;

CREATE POLICY ulm_select_staff_visible_to_staff_same_lib
    ON public.user_library_memberships
    FOR SELECT
    USING (
        (role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))
        AND user_can_act_as_staff_on_library(library_id)
    );

-- 4b. policy sur author_translations
DROP POLICY IF EXISTS author_translations_librarian_write
    ON public.author_translations;

CREATE POLICY author_translations_librarian_write
    ON public.author_translations
    FOR ALL
    USING (
        (auth.uid() IS NOT NULL)
        AND (EXISTS (
            SELECT 1
            FROM user_library_memberships m
            WHERE m.user_id = auth.uid()
              AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
        ))
    );

-- ============================================================================
-- Verifications finales
-- ============================================================================

DO $$
DECLARE
    v_ulm_admin_count int;
    v_constraint_def text;
BEGIN
    -- Pas de ulm administrador
    SELECT count(*) INTO v_ulm_admin_count
    FROM public.user_library_memberships
    WHERE role = 'administrador';
    IF v_ulm_admin_count <> 0 THEN
        RAISE EXCEPTION 'F.1: ulm administrador subsistant: %', v_ulm_admin_count;
    END IF;
    
    -- CHECK constraint mis a jour
    SELECT pg_get_constraintdef(con.oid) INTO v_constraint_def
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE nsp.nspname = 'public'
      AND rel.relname = 'user_library_memberships'
      AND con.conname = 'user_library_memberships_role_check';
    
    IF v_constraint_def LIKE '%administrador%' THEN
        RAISE EXCEPTION 'F.1: CHECK constraint contient encore administrador';
    END IF;
END $$;

COMMIT;

-- ============================================================================
-- Notes post-deploiement
-- ============================================================================
-- 1. Migration enregistree :
--    SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 1;
--
-- 2. Verifier que les 17 fonctions identifiees en audit pre-F.1 continuent
--    de retourner correctement malgre la suppression de 'administrador' :
--    (effet attendu : les fonctions tournent toujours, mais leurs branches
--    'administrador' deviennent inertes parce qu'aucun row ne le porte plus.
--    F.2 et F.3 viendront nettoyer le code de ces fonctions.)
--
-- 3. Verifier que Xavier voit toujours bien tout (admin reseau + coordenador
--    BLMF actif) :
--    SELECT * FROM api.my_access;
