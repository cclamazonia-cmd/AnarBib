-- ============================================================================
-- 20260511050000_paquet23bis_blmf_coord_realign.sql
-- ============================================================================
-- Paquet 23bis — Réalignement du membership BLMF de Xavier sur la réalité
--                politique.
--
-- Contexte :
--   Le paquet 23 a passé en status='removed' la ligne coordenador BLMF créée
--   le 07/05/2026 par effet de bord des tests Phase B. Sauf que ce passage
--   en 'removed' raconte une histoire fausse : Xavier n'a jamais été
--   "retiré" politiquement de la coordination BLMF, cette ligne n'aurait
--   jamais dû exister avec ce statut. L'affichage de profil affichait donc
--   "Coordenador(a/e) Retirad·o" alors qu'il s'agissait d'un déchet technique.
--
--   Par ailleurs, Xavier *anime vraiment* BLMF au quotidien et y exerce
--   politiquement un rôle de coordination. Il faut donc inscrire ce rôle
--   en base de manière authentique.
--
-- Contenu :
--   1. DELETE de la ligne fantôme coordenador BLMF du 7/05 (status=removed)
--      → ne raconte plus une histoire de retrait fictif.
--   2. INSERT d'une nouvelle ligne coordenador BLMF datée d'aujourd'hui
--      → reflète l'engagement politique réel de Xavier dans BLMF.
--      is_primary=false : l'administrador BLMF du 24/03 reste primaire.
--      Cette décision sera révisée au paquet B (migration vers
--      network_administrators), moment où l'administrador local
--      disparaîtra de user_library_memberships.
--
-- Atomicité : transaction unique avec garde-fous stricts.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : DELETE de la ligne fantôme
-- ============================================================================

WITH deleted AS (
    DELETE FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'  -- Xavier
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'  -- BLMF
      AND role = 'coordenador'
      AND status = 'removed'
      AND created_at >= '2026-05-07 00:00:00+00'
      AND created_at <  '2026-05-08 00:00:00+00'
    RETURNING id, role, status, created_at, updated_at
)
SELECT 'deleted_phantom_row' AS info, * FROM deleted;

-- Validation : exactement 1 ligne supprimée
DO $$
DECLARE
    v_remaining integer;
BEGIN
    SELECT count(*) INTO v_remaining
    FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND role = 'coordenador'
      AND status = 'removed'
      AND created_at >= '2026-05-07 00:00:00+00'
      AND created_at <  '2026-05-08 00:00:00+00';
    
    IF v_remaining > 0 THEN
        RAISE EXCEPTION 'delete_failed: % phantom rows still exist after DELETE', v_remaining;
    END IF;
    
    RAISE NOTICE 'delete_ok: ligne fantôme coordenador BLMF du 7/05 supprimée';
END;
$$;

-- Safety check : l'admin BLMF du 24/03 doit toujours être actif
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND role = 'administrador'
      AND status = 'active';
    
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'admin_safety_check_failed: administrador BLMF de Xavier devrait toujours être actif, trouvé % lignes', v_count;
    END IF;
    
    RAISE NOTICE 'admin_safety_check_ok: administrador BLMF intact';
END;
$$;

-- ============================================================================
-- SECTION 2 : INSERT du nouveau coordenador BLMF
-- ============================================================================

-- Validation préalable : pas de coordenador actif déjà existant
-- (la ligne du 7/05 vient d'être supprimée, donc rien ne devrait exister)
DO $$
DECLARE
    v_existing integer;
BEGIN
    SELECT count(*) INTO v_existing
    FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND role = 'coordenador'
      AND status = 'active';
    
    IF v_existing > 0 THEN
        RAISE EXCEPTION 'pre_insert_failed: % coordenador BLMF actif(s) existent déjà pour Xavier (attendu : 0)', v_existing;
    END IF;
    
    RAISE NOTICE 'pre_insert_ok: pas de coordenador BLMF actif, libre pour INSERT';
END;
$$;

-- Insertion
WITH inserted AS (
    INSERT INTO public.user_library_memberships
        (user_id, library_id, role, status, is_primary, history_enabled)
    VALUES (
        'd6710372-e5e5-4608-800b-99a26817c677',  -- Xavier
        '1234825f-a0f9-4fbd-a875-6551c30ea4ca',  -- BLMF
        'coordenador',
        'active',
        false,   -- l'administrador du 24/03 reste primaire
        true
    )
    RETURNING id, user_id, library_id, role, status, is_primary, created_at
)
SELECT 'inserted_coord_row' AS info, * FROM inserted;

-- Validation : exactement 1 ligne créée
DO $$
DECLARE
    v_count integer;
    v_new_id uuid;
BEGIN
    -- Compte
    SELECT count(*) INTO v_count
    FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND role = 'coordenador'
      AND status = 'active'
      AND created_at >= (now() - interval '1 minute');
    
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'insert_validation_failed: % coordenador BLMF actif(s) (attendu : 1)', v_count;
    END IF;
    
    -- Récup de l'id (séparée, via ORDER BY au lieu de max() qui n'existe pas pour uuid)
    SELECT id INTO v_new_id
    FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND role = 'coordenador'
      AND status = 'active'
    ORDER BY created_at DESC
    LIMIT 1;
    
    RAISE NOTICE 'insert_ok: nouveau coordenador BLMF créé (id=%)', v_new_id;
END;
$$;

-- ============================================================================
-- SECTION 3 : VALIDATION FINALE GLOBALE
-- ============================================================================
-- Après le 23bis, Xavier doit avoir EXACTEMENT 2 memberships actifs sur BLMF :
--   - administrador (du 24/03, is_primary=true)
--   - coordenador (créé maintenant, is_primary=false)

DO $$
DECLARE
    v_admin_count integer;
    v_coord_count integer;
    v_total_active integer;
BEGIN
    SELECT 
        count(*) FILTER (WHERE role = 'administrador'),
        count(*) FILTER (WHERE role = 'coordenador'),
        count(*)
    INTO v_admin_count, v_coord_count, v_total_active
    FROM public.user_library_memberships
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
      AND status = 'active';
    
    RAISE NOTICE 'final_state: Xavier BLMF active memberships = % administrador + % coordenador = % total',
        v_admin_count, v_coord_count, v_total_active;
    
    IF v_admin_count <> 1 OR v_coord_count <> 1 OR v_total_active <> 2 THEN
        RAISE EXCEPTION 'final_state_wrong: attendu (1, 1, 2), obtenu (%, %, %)', 
            v_admin_count, v_coord_count, v_total_active;
    END IF;
    
    RAISE NOTICE 'final_state_ok: Xavier est bien administrador + coordenador BLMF';
END;
$$;

-- Validation côté vue circulation_stats : grâce au COUNT(DISTINCT user_id)
-- du paquet 23, BLMF doit toujours afficher librarians_active=1 (1 personne
-- distincte avec un rôle staff, même si elle a 2 memberships).
DO $$
DECLARE
    v_blmf_librarians integer;
BEGIN
    SELECT librarians_active INTO v_blmf_librarians
    FROM api.library_circulation_stats
    WHERE slug = 'blmf';
    
    RAISE NOTICE 'view_state: BLMF librarians_active=% (attendu : 1, grâce au COUNT DISTINCT du paquet 23)', v_blmf_librarians;
    
    IF v_blmf_librarians <> 1 THEN
        RAISE WARNING 'view_state_warning: BLMF librarians_active=% inattendu (attendu : 1). Le COUNT(DISTINCT user_id) du paquet 23 devrait neutraliser le double membership.', v_blmf_librarians;
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
--
-- 1. Memberships BLMF de Xavier :
--    SELECT role, status, is_primary, created_at, updated_at
--    FROM user_library_memberships
--    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
--      AND library_id = '1234825f-a0f9-4fbd-a875-6551c30ea4ca'
--    ORDER BY created_at;
--    Attendu : 2 lignes, toutes deux status='active'
--      - administrador (is_primary=true, 24/03/2026)
--      - coordenador (is_primary=false, today)
--
-- 2. Plus aucune ligne 'removed' parasite :
--    SELECT count(*) FROM user_library_memberships WHERE status = 'removed';
--    Attendu : 0
--
-- 3. Bandeau /rede après reload : EQUIPE = 2 (toi BLMF + Patricia BTL)
--    Carte BLMF : Equipe = 1 (grâce au DISTINCT du paquet 23)
--    Page /biblioteca BLMF profil : affiche bien tes deux rôles actifs,
--    pas de "Retirad·o" fantôme.
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
