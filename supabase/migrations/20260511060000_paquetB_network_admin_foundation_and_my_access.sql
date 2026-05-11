-- ============================================================================
-- 20260511060000_paquetB_network_admin_foundation_and_my_access.sql
-- ============================================================================
-- Paquet B — Cooptation fondatrice de Xavier + réécriture api.my_access
--           + création api.network_overview + adaptation fn_resolve_caller_role_for_library
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 (11/05/2026)
--           - §4.3 Premier administrateur
--           - §5.3 Spécification api.network_overview
--           - §6.2 Paquet B
--           - Q7 + Q8 : séquence conservatrice, on NE TOUCHE PAS à la
--             ligne administrador BLMF de Xavier (reportée au paquet F)
--
-- Choix de conception (tranchés au §point-1/2/3 de la session 11/05) :
--   - my_access : 1-ligne-par-user, can_access_painel calculé sur UNION
--     (au moins un membership staff local OR admin réseau actif)
--   - library_id peut être NULL pour un admin réseau sans membership local
--   - fn_resolve_caller_role_for_library : rôle local prime, network_admin
--     retourné seulement s'il n'y a pas de rôle local sur la biblio
--
-- Atomicité : transaction unique. En cas d'erreur, rien n'est appliqué.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : COOPTATION FONDATRICE DE XAVIER
-- ============================================================================
-- Cas particulier décrit dans la spec §4.3 : le premier administrateur réseau
-- ne peut pas être coopté par le workflow normal (personne pour voter). On
-- l'insère manuellement avec coopted_by_unanimity_of vide, et on trace
-- l'événement dans l'audit avec event_type='foundational_admin_added'.

-- Garde-fou : on ne fait rien si Xavier est déjà admin réseau actif
-- (cas où la migration serait rejouée par erreur)
DO $$
DECLARE
    v_xavier_id uuid := 'd6710372-e5e5-4608-800b-99a26817c677';
    v_already_admin integer;
BEGIN
    SELECT count(*) INTO v_already_admin
    FROM public.network_administrators
    WHERE user_id = v_xavier_id AND status = 'active';
    
    IF v_already_admin > 0 THEN
        RAISE NOTICE 'foundational_skip: Xavier est déjà admin réseau actif, INSERT sauté';
        RETURN;
    END IF;
    
    -- Vérifier que Xavier existe bien dans auth.users
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_xavier_id) THEN
        RAISE EXCEPTION 'xavier_not_found: user d6710372-e5e5-4608-800b-99a26817c677 absent de auth.users';
    END IF;
    
    -- Vérifier qu'il existe au moins une autre trace de Xavier dans le système
    -- (au minimum sa ligne administrador BLMF du 24/03 doit toujours être là)
    IF NOT EXISTS (
        SELECT 1 FROM public.user_library_memberships
        WHERE user_id = v_xavier_id 
          AND role = 'administrador' 
          AND status = 'active'
    ) THEN
        RAISE WARNING 'foundational_warning: Xavier n''a pas de membership administrador actif (attendu : la ligne BLMF du 24/03). Cas anormal mais on continue.';
    END IF;
    
    -- Insertion fondatrice
    INSERT INTO public.network_administrators (
        user_id, 
        status, 
        coopted_at, 
        coopted_by_unanimity_of, 
        notes
    ) VALUES (
        v_xavier_id,
        'active',
        now(),
        ARRAY[]::uuid[],
        'Fondateur du réseau AnarBib. Cooptation hors workflow standard (premier admin réseau, personne pour voter). Réf : spec-administrateur-reseau.md v0.3 §4.3 + paquet B (11/05/2026).'
    );
    
    -- Trace dans l'audit
    INSERT INTO public.network_administrator_audit (
        user_id, 
        event_type, 
        actor_user_id, 
        target_user_id, 
        metadata
    ) VALUES (
        v_xavier_id,
        'foundational_admin_added',
        v_xavier_id,  -- l'acteur est Xavier lui-même (auto-installation)
        v_xavier_id,
        jsonb_build_object(
            'foundational', true,
            'paquet', 'B',
            'spec_version', 'v0.3',
            'rationale', 'Premier admin réseau du système, cooptation impossible par workflow standard'
        )
    );
    
    RAISE NOTICE 'foundational_ok: Xavier inscrit comme administrateur réseau fondateur';
END;
$$;

-- ============================================================================
-- SECTION 2 : RÉÉCRITURE DE api.my_access
-- ============================================================================
-- Architecture : 1-ligne-par-user, can_access_painel et can_access_catalogacao
-- calculés sur l'UNION : staff local actif (n'importe quelle biblio) OR
-- admin réseau actif.
--
-- Changement par rapport à l'existant :
--   AVANT : can_access_painel = (effective_membership.role IN staff_array)
--           → bug latent : seulement le membership primaire compte
--   APRÈS : can_access_painel = (au moins un membership staff actif)
--                            OR (admin réseau actif)
--
-- Structure des autres colonnes (id, email, library_id, library_slug, etc.)
-- INCHANGÉE pour compatibilité avec le frontend et avec api.my_session_context.

CREATE OR REPLACE VIEW api.my_access AS
WITH base AS (
    SELECT 
        sc.user_id,
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
),
active_memberships AS (
    SELECT 
        m.user_id,
        l.id AS library_id,
        l.slug AS library_slug,
        l.name AS library_name,
        m.role,
        m.status,
        m.is_primary,
        m.created_at
    FROM public.user_library_memberships m
    JOIN public.libraries l ON l.id = m.library_id
    WHERE m.status = 'active' 
      AND l.is_active = true 
      AND m.user_id = auth.uid()
),
effective_membership AS (
    -- On garde la logique "primaire d'abord, puis le plus ancien" pour
    -- déterminer la biblio par défaut affichée. Cette logique reste
    -- INCHANGÉE par rapport à l'existant.
    SELECT *
    FROM active_memberships
    ORDER BY is_primary DESC, created_at, library_slug
    LIMIT 1
),
network_admin_status AS (
    -- Paquet B : nouveau CTE qui calcule si l'appelant est admin réseau actif
    SELECT EXISTS (
        SELECT 1 
        FROM public.network_administrators
        WHERE user_id = auth.uid() 
          AND status = 'active'
    ) AS is_network_admin
),
has_any_staff_membership AS (
    -- Paquet B : nouveau CTE qui dit si l'appelant a au moins UN membership
    -- staff actif (peu importe la biblio). Corrige le bug latent où seul
    -- le membership primaire était considéré.
    SELECT EXISTS (
        SELECT 1
        FROM active_memberships am
        WHERE am.role = ANY (ARRAY['librarian', 'coordenador', 'administrador'])
    ) AS has_staff
)
SELECT 
    b.user_id AS id,
    b.email,
    b.is_librarian,
    COALESCE(p.is_restricted, false) AS is_restricted,
    b.default_library_id,
    b.default_library_slug,
    b.default_library_name,
    b.can_access_conta,
    
    -- can_access_painel : UNION (staff local actif n'importe où) OR (admin réseau)
    -- Si is_restricted=true, accès refusé quoi qu'il arrive
    ((has_staff.has_staff OR na.is_network_admin) 
        AND COALESCE(p.is_restricted, false) = false) 
        AS can_access_painel,
    
    -- can_access_catalogacao : même règle (paquet B n'introduit pas de
    -- distinction sémantique entre painel et catalogacao côté droits)
    ((has_staff.has_staff OR na.is_network_admin) 
        AND COALESCE(p.is_restricted, false) = false) 
        AS can_access_catalogacao,
    
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
LEFT JOIN public.profiles p ON p.id = b.user_id
LEFT JOIN effective_membership em ON em.user_id = b.user_id
CROSS JOIN network_admin_status na
CROSS JOIN has_any_staff_membership has_staff;

COMMENT ON VIEW api.my_access IS
'Droits effectifs de l''appelant courant. Une seule ligne retournée. '
'Paquet B (11/05/2026) : can_access_painel et can_access_catalogacao '
'calculés sur l''UNION (au moins un membership staff local actif) OR '
'(admin réseau actif). Fix le bug latent où seul le membership primaire '
'était considéré. library_id peut être NULL pour un admin réseau sans '
'membership local. Réf : spec-administrateur-reseau.md v0.3 §6.2.';

GRANT SELECT ON api.my_access TO authenticated;

-- ============================================================================
-- SECTION 3 : MODIFICATION DE fn_resolve_caller_role_for_library
-- ============================================================================
-- Choix de conception : rôle local prime. 'network_admin' n'est retourné que
-- s'il n'y a aucun rôle local sur la biblio passée en paramètre.
--
-- Conséquence pour Xavier (admin réseau + coordenador BLMF) :
--   - fn_resolve_caller_role_for_library('BLMF') → 'coordenador' (rôle local prime)
--   - fn_resolve_caller_role_for_library('BTL')  → 'network_admin' (pas de rôle local)
--
-- Pour Patricia (coord BTL, pas admin réseau) :
--   - fn_resolve_caller_role_for_library('BTL')  → 'coordenador' (inchangé)
--   - fn_resolve_caller_role_for_library('BLMF') → NULL (inchangé)

CREATE OR REPLACE FUNCTION public.fn_resolve_caller_role_for_library(p_library_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- 1. Rôle local prime : coordenador OU administrador
    -- (user_can_manage_library couvre les deux, comportement INCHANGÉ)
    IF user_can_manage_library(p_library_id) THEN
        RETURN 'coordenador';
    END IF;
    
    -- 2. Rôle local : librarian
    IF user_has_library_staff_role(v_uid, p_library_id) THEN
        RETURN 'librarian';
    END IF;
    
    -- 3. Rôle local : leitor (lecteur actif sur cette biblio)
    -- Paquet 20 v2 (11/05/2026, fix critique) : reconnaitre le role lecteur
    -- pour les users ayant une membership active sur la library.
    IF EXISTS (
        SELECT 1 
        FROM public.user_library_memberships
        WHERE user_id = v_uid
          AND library_id = p_library_id
          AND role = 'reader'
          AND status = 'active'
    ) THEN
        RETURN 'leitor';
    END IF;
    
    -- 4. Paquet B (11/05/2026) : si pas de rôle local, vérifier admin réseau.
    -- Permet à un admin réseau visitant une biblio dont il n'est pas membre
    -- d'avoir un rôle reconnu (au lieu de retourner NULL et d'être traité
    -- comme un visiteur anonyme par les RPC qui appellent cette fonction).
    IF fn_caller_is_network_admin() THEN
        RETURN 'network_admin';
    END IF;
    
    -- 5. Aucun rôle local, pas admin réseau
    RETURN NULL;
END;
$function$;

COMMENT ON FUNCTION public.fn_resolve_caller_role_for_library(uuid) IS
'Retourne le rôle de l''appelant dans la biblio donnée. Rôle local prime '
'sur le statut admin réseau. Si pas de rôle local mais admin réseau, '
'retourne ''network_admin''. Sinon NULL. Modifié au paquet B (11/05/2026, '
'spec v0.3).';

-- ============================================================================
-- SECTION 4 : CRÉATION DE api.network_overview
-- ============================================================================
-- Vue agrégée pour le bandeau /rede onglet "Vue d'ensemble du réseau".
-- Une seule ligne retournée. Pas de calcul croisé personnes×biblios
-- (sémantique v0.2/v0.3 "page = périmètre").
--
-- Réf : spec-administrateur-reseau.md v0.3 §5.3

CREATE OR REPLACE VIEW api.network_overview AS
SELECT
    (SELECT count(*) 
     FROM public.network_administrators 
     WHERE status = 'active') 
        AS network_admins_active,
    
    (SELECT count(*) 
     FROM public.network_administrator_cooptation_proposals 
     WHERE status = 'open') 
        AS open_cooptation_proposals,
    
    (SELECT count(*) 
     FROM public.libraries 
     WHERE is_active = true) 
        AS libraries_active,
    
    (SELECT count(*) FROM public.books) 
        AS books_total,
    
    (SELECT count(*) FROM public.authors) 
        AS authors_total,
    
    (SELECT count(*) FROM public.exemplares) 
        AS exemplars_total,
    
    -- Sommes circulatoires (réutilise library_circulation_stats déjà existante)
    (SELECT coalesce(sum(loans_open), 0) 
     FROM api.library_circulation_stats) 
        AS loans_open_total,
    
    (SELECT coalesce(sum(loans_overdue), 0) 
     FROM api.library_circulation_stats) 
        AS loans_overdue_total,
    
    (SELECT coalesce(sum(reservations_active), 0) 
     FROM api.library_circulation_stats) 
        AS reservations_active_total;

COMMENT ON VIEW api.network_overview IS
'Indicateurs globaux du réseau AnarBib. Une seule ligne retournée. '
'Volontairement minimaliste : pas de compteur "équipe réseau" au sens '
'"personnes engagées quelque part", concept inexistant dans la doctrine '
'v0.3 (sémantique "page = périmètre, sans calcul croisé"). '
'Réf : spec-administrateur-reseau.md v0.3 §5.3.';

GRANT SELECT ON api.network_overview TO authenticated;

-- ============================================================================
-- SECTION 5 : VALIDATIONS POST-APPLICATION
-- ============================================================================

-- 5.1 Xavier doit être admin réseau actif
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM public.network_administrators
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND status = 'active';
    
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'validation_xavier_admin_failed: Xavier devrait être 1 fois admin réseau actif, trouvé % lignes', v_count;
    END IF;
    
    RAISE NOTICE 'validation_xavier_admin_ok: Xavier est admin réseau actif';
END;
$$;

-- 5.2 La trace audit existe
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM public.network_administrator_audit
    WHERE user_id = 'd6710372-e5e5-4608-800b-99a26817c677'
      AND event_type = 'foundational_admin_added';
    
    IF v_count = 0 THEN
        RAISE WARNING 'validation_audit_warning: aucune trace foundational_admin_added pour Xavier. Migration rejouée ?';
    ELSE
        RAISE NOTICE 'validation_audit_ok: % trace(s) foundational_admin_added pour Xavier', v_count;
    END IF;
END;
$$;

-- 5.3 La ligne administrador BLMF de Xavier doit toujours être active
-- (Q7 : on ne touche pas à cette ligne au paquet B, reportée au paquet F)
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
        RAISE EXCEPTION 'q7_violation: la ligne administrador BLMF de Xavier devrait toujours être active (Q7 : reportée au paquet F), trouvé % lignes', v_count;
    END IF;
    
    RAISE NOTICE 'q7_ok: ligne administrador BLMF de Xavier intacte (double filet de sécurité)';
END;
$$;

-- 5.4 fn_caller_is_network_admin() devrait retourner true si on est Xavier
-- (on ne peut pas vraiment tester ça dans la migration car auth.uid() est
-- typiquement NULL en contexte service_role, mais on vérifie au moins que
-- la fonction n'a pas été cassée par un effet de bord)
DO $$
DECLARE
    v_signature_ok boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_caller_is_network_admin'
    ) INTO v_signature_ok;
    
    IF NOT v_signature_ok THEN
        RAISE EXCEPTION 'helper_missing: fn_caller_is_network_admin() introuvable, le paquet A devrait l''avoir créée';
    END IF;
    
    RAISE NOTICE 'helper_ok: fn_caller_is_network_admin() présente';
END;
$$;

-- 5.5 api.network_overview retourne 1 ligne avec network_admins_active=1
DO $$
DECLARE
    v_admins integer;
    v_libs integer;
BEGIN
    SELECT network_admins_active, libraries_active 
    INTO v_admins, v_libs
    FROM api.network_overview;
    
    RAISE NOTICE 'network_overview: admins_active=% libraries_active=%', v_admins, v_libs;
    
    IF v_admins <> 1 THEN
        RAISE WARNING 'validation_overview_warning: network_admins_active=% (attendu : 1, Xavier seul fondateur)', v_admins;
    END IF;
    
    IF v_libs < 2 THEN
        RAISE WARNING 'validation_overview_warning: libraries_active=% (attendu : >=2 pour BLMF et BTL)', v_libs;
    END IF;
END;
$$;

-- 5.6 fn_resolve_caller_role_for_library a bien été modifiée
DO $$
DECLARE
    v_definition text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' 
      AND p.proname = 'fn_resolve_caller_role_for_library';
    
    IF v_definition NOT LIKE '%fn_caller_is_network_admin%' THEN
        RAISE EXCEPTION 'fn_resolve_caller_role_for_library_not_updated: la fonction ne référence pas fn_caller_is_network_admin()';
    END IF;
    
    RAISE NOTICE 'fn_resolve_caller_role_for_library_ok: fonction mise à jour pour network_admin';
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
--
-- 1. Vérifier que Xavier voit ses droits enrichis :
--    En tant qu'utilisateur authentifié (pas service_role), exécuter :
--      SELECT can_access_painel, can_access_catalogacao FROM api.my_access;
--    Attendu : (true, true)
--
-- 2. Vérifier la vue network_overview :
--    SELECT * FROM api.network_overview;
--    Attendu : 1 ligne, network_admins_active=1, libraries_active=2
--
-- 3. Vérifier fn_resolve_caller_role_for_library pour Xavier :
--    SELECT fn_resolve_caller_role_for_library('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid); -- BLMF
--    Attendu : 'coordenador' (rôle local prime sur admin réseau)
--    
--    SELECT fn_resolve_caller_role_for_library('b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'::uuid); -- BTL
--    Attendu : 'network_admin' (pas de rôle local sur BTL, mais admin réseau)
--
-- 4. Recharger /painel, /rede, /catalogacao dans le navigateur (Ctrl+Shift+R)
--    Vérifier qu'aucun accès n'est perdu (RLS qui dépendent de my_access).
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
