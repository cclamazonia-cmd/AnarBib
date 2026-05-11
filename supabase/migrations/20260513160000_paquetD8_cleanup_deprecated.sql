-- ============================================================================
-- Paquet D.8 — Cleanup deprecated (v0.3)
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Réf.  : docs/spec-administrateur-reseau.md v0.3
--
-- Contenu :
--  1. Refacto fn_team_list_memberships : remplacer fn_caller_is_administrador
--     par fn_caller_is_network_admin (interprétation A, doctrine v0.3)
--  2. Déprécation fn_caller_is_administrador
--  3. Déprécation fn_team_promote_to_administrador
--
-- Audit préalable confirmé :
--  - fn_team_promote_to_administrador : aucun caller dans public/api
--  - fn_caller_is_administrador : seul caller restant = fn_team_list_memberships
--    (refacto dans cette même migration)
--  - 1 seul utilisateur avec role='administrador' actif : Xavier (BLMF), aussi
--    admin réseau actif → garde son accès via fn_caller_is_network_admin
--
-- Effet en prod :
--  - fn_team_list_memberships : Xavier ne perd pas l'accès (admin réseau)
--    Aucun autre utilisateur n'a role='administrador' actif → personne d'autre
--    n'est impacté
--  - fn_caller_is_administrador : tout appel lèvera désormais une exception
--    (déprécation totale)
--  - fn_team_promote_to_administrador : idem (déprécation totale)
--
-- Boucle paquet D : 8/8 sous-paquets livrés.
-- Reste à venir : paquet E (UI admin réseau), paquet F (finalisation).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Refacto fn_team_list_memberships
-- ----------------------------------------------------------------------------
-- Remplace l'appel à fn_caller_is_administrador (rôle local résiduel)
-- par fn_caller_is_network_admin (doctrine v0.3).
-- Le filtrage SELECT (role IN librarian/coordenador/administrador) et
-- l'ORDER BY sont conservés : on continue d'afficher d'éventuels
-- memberships 'administrador' encore existants (sera nettoyé au paquet F).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_list_memberships(
    p_scope text,
    p_library_id uuid DEFAULT NULL::uuid
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_caller            uuid := auth.uid();
    v_caller_is_netadmin boolean;
BEGIN
    -- 1. Authentification minimale
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'auth_required'
            USING HINT = 'Sign in before calling this function.';
    END IF;

    -- 2. Validation du scope
    IF p_scope NOT IN ('library', 'network') THEN
        RAISE EXCEPTION 'invalid_scope'
            USING HINT = 'p_scope must be ''library'' or ''network''.';
    END IF;

    -- 3. Détection admin réseau (doctrine v0.3, remplace fn_caller_is_administrador)
    v_caller_is_netadmin := public.fn_caller_is_network_admin();

    -- ═══ SCOPE = library ═══════════════════════════════
    IF p_scope = 'library' THEN
        IF p_library_id IS NULL THEN
            RAISE EXCEPTION 'library_id_required'
                USING HINT = 'Scope library requires a non-null p_library_id.';
        END IF;

        -- Droit d'accès : staff actif de cette lib OU admin réseau
        IF NOT (
            v_caller_is_netadmin
            OR public.user_has_library_staff_role(v_caller, p_library_id)
        ) THEN
            RAISE EXCEPTION 'forbidden'
                USING HINT = 'Caller is not staff of this library and not a network administrator.';
        END IF;

        RETURN QUERY
            SELECT jsonb_build_object(
                'id',                          ulm.id,
                'user_id',                     ulm.user_id,
                'library_id',                  ulm.library_id,
                'role',                        ulm.role,
                'status',                      ulm.status,
                'is_primary',                  ulm.is_primary,
                'created_at',                  ulm.created_at,
                'updated_at',                  ulm.updated_at,
                'is_restricted',               ulm.is_restricted,
                'restricted_reason',           ulm.restricted_reason,
                'pending_removal_until',       ulm.pending_removal_until,
                'pending_removal_requested_by', ulm.pending_removal_requested_by,
                'profiles', jsonb_build_object(
                    'email',      p.email,
                    'first_name', p.first_name,
                    'last_name',  p.last_name,
                    'public_id',  p.public_id
                ),
                'libraries', jsonb_build_object(
                    'id',         l.id,
                    'name',       l.name,
                    'short_name', l.short_name,
                    'slug',       l.slug
                )
            )
            FROM public.user_library_memberships ulm
            LEFT JOIN public.profiles p  ON p.id = ulm.user_id
            LEFT JOIN public.libraries l ON l.id = ulm.library_id
            WHERE ulm.library_id = p_library_id
              AND ulm.role IN ('librarian', 'coordenador', 'administrador')
            ORDER BY
                CASE ulm.role
                    WHEN 'administrador' THEN 1
                    WHEN 'coordenador'   THEN 2
                    WHEN 'librarian'     THEN 3
                    ELSE 99
                END,
                p.last_name,
                p.first_name,
                ulm.created_at;

        RETURN;
    END IF;

    -- ═══ SCOPE = network ═══════════════════════════════
    IF p_scope = 'network' THEN
        -- Droit d'accès : admin réseau uniquement (doctrine v0.3)
        IF NOT v_caller_is_netadmin THEN
            RAISE EXCEPTION 'forbidden'
                USING HINT = 'Network scope is reserved to network administrators.';
        END IF;

        RETURN QUERY
            SELECT jsonb_build_object(
                'id',                          ulm.id,
                'user_id',                     ulm.user_id,
                'library_id',                  ulm.library_id,
                'role',                        ulm.role,
                'status',                      ulm.status,
                'is_primary',                  ulm.is_primary,
                'created_at',                  ulm.created_at,
                'updated_at',                  ulm.updated_at,
                'is_restricted',               ulm.is_restricted,
                'restricted_reason',           ulm.restricted_reason,
                'pending_removal_until',       ulm.pending_removal_until,
                'pending_removal_requested_by', ulm.pending_removal_requested_by,
                'profiles', jsonb_build_object(
                    'email',      p.email,
                    'first_name', p.first_name,
                    'last_name',  p.last_name,
                    'public_id',  p.public_id
                ),
                'libraries', jsonb_build_object(
                    'id',         l.id,
                    'name',       l.name,
                    'short_name', l.short_name,
                    'slug',       l.slug
                )
            )
            FROM public.user_library_memberships ulm
            LEFT JOIN public.profiles p  ON p.id = ulm.user_id
            LEFT JOIN public.libraries l ON l.id = ulm.library_id
            WHERE ulm.role IN ('librarian', 'coordenador', 'administrador')
            ORDER BY
                l.short_name NULLS LAST,
                CASE ulm.role
                    WHEN 'administrador' THEN 1
                    WHEN 'coordenador'   THEN 2
                    WHEN 'librarian'     THEN 3
                    ELSE 99
                END,
                p.last_name,
                p.first_name,
                ulm.created_at;

        RETURN;
    END IF;
END;
$function$;

COMMENT ON FUNCTION public.fn_team_list_memberships(text, uuid) IS 
    'D.8 — Refactorisée pour utiliser fn_caller_is_network_admin (doctrine v0.3) au lieu de fn_caller_is_administrador (deprecated).';


-- ----------------------------------------------------------------------------
-- 2. Déprécation fn_caller_is_administrador
-- ----------------------------------------------------------------------------
-- Tout appel lèvera désormais une exception.
-- Signal explicite à tout caller futur d'utiliser fn_caller_is_network_admin.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_caller_is_administrador()
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
    RAISE EXCEPTION 'deprecated: fn_caller_is_administrador is deprecated. Use fn_caller_is_network_admin (v0.3) for network admin checks, or query user_library_memberships directly for local administrador role checks.'
        USING ERRCODE = '0A000';  -- feature_not_supported
END;
$function$;

COMMENT ON FUNCTION public.fn_caller_is_administrador() IS 
    'D.8 — DEPRECATED v0.3. Remplacée par fn_caller_is_network_admin pour la doctrine admin réseau. Le rôle local administrador dans user_library_memberships sera supprimé au paquet F.';


-- ----------------------------------------------------------------------------
-- 3. Déprécation fn_team_promote_to_administrador
-- ----------------------------------------------------------------------------
-- Tout appel lèvera désormais une exception.
-- La promotion vers admin réseau passe par fn_network_admin_propose_cooptation
-- (workflow unanimité).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_administrador(
    p_user_id uuid,
    p_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RAISE EXCEPTION 'deprecated: fn_team_promote_to_administrador is deprecated. The local administrador role is replaced by the network administrator role (v0.3). Use fn_network_admin_propose_cooptation to propose a network admin (unanimity workflow).'
        USING ERRCODE = '0A000';  -- feature_not_supported
END;
$function$;

COMMENT ON FUNCTION public.fn_team_promote_to_administrador(uuid, uuid) IS 
    'D.8 — DEPRECATED v0.3. La promotion d''un administrador local n''a plus de sens : utiliser le workflow de cooptation admin réseau via fn_network_admin_propose_cooptation.';


COMMIT;

-- ============================================================================
-- Notes post-déploiement
-- ============================================================================
-- 1. Migration enregistrée :
--    SELECT version, name FROM supabase_migrations.schema_migrations
--    ORDER BY version DESC LIMIT 3;
--
-- 2. Vérification refacto fn_team_list_memberships :
--    SELECT pg_get_functiondef(p.oid)
--    FROM pg_proc p WHERE p.proname = 'fn_team_list_memberships';
--    -- Doit contenir : fn_caller_is_network_admin (non plus fn_caller_is_administrador)
--
-- 3. Vérification déprécations :
--    SELECT pg_get_functiondef(p.oid)
--    FROM pg_proc p WHERE p.proname IN 
--      ('fn_caller_is_administrador', 'fn_team_promote_to_administrador');
--    -- Les deux doivent contenir : RAISE EXCEPTION 'deprecated...'
--
-- 4. Test fonctionnel : appeler fn_team_list_memberships('network') en tant
--    que Xavier (admin réseau actif) doit retourner les memberships réseau.
--    SELECT public.fn_team_list_memberships('network');
--    -- Attendu : liste jsonb des memberships staff actifs (toutes biblios)
--
-- 5. Test des déprécations :
--    SELECT public.fn_caller_is_administrador();
--    -- Attendu : ERROR 0A000 'deprecated: ...'
--    SELECT public.fn_team_promote_to_administrador(
--      gen_random_uuid(), gen_random_uuid()
--    );
--    -- Attendu : ERROR 0A000 'deprecated: ...'
--
-- 6. Backlog item #80 : passage 7/8 → 8/8 sous-paquets D livrés.
--    PAQUET D BOUCLÉ. Reste paquet E (UI admin réseau) et paquet F (finalisation).
