-- ═══════════════════════════════════════════════════════════════════════════
-- Migration : fn_team_list_memberships() — RPC pour <TeamPanel />
-- Date      : 07/05/2026 (suite immédiate de la migration RLS ulm)
-- Auteur    : Xavier (assist Claude) — Phase B1 follow-up #2
-- ═══════════════════════════════════════════════════════════════════════════
--
-- CONTEXTE
-- --------
-- Suite à la correction des policies RLS sur user_library_memberships, il
-- est apparu que les profils des autres bibliothèques restent invisibles
-- pour l'admin AnarBib (RLS sur profiles via can_manage_profile_from_my_libraries
-- qui ne couvre que les libs où on est coord/admin).
--
-- Plutôt que d'ouvrir les vannes RLS sur profiles (table sensible : adresse,
-- téléphone, raison de restriction…), on opte pour une RPC SECURITY DEFINER
-- qui :
--   1. Valide explicitement les droits du caller selon le scope demandé
--   2. Retourne uniquement les champs nécessaires pour l'UI (pas l'adresse
--      postale, pas le téléphone, pas les détails sensibles)
--   3. Joint ulm + profiles + libraries en une seule requête côté DB
--
-- DÉCISIONS POLITIQUES (validées 07/05/2026)
-- ------------------------------------------
-- - Scope 'library' : un staff (librarian/coord/admin) actif d'une lib voit
--   tous les staff de SA lib. Pas les readers (gérés ailleurs).
-- - Scope 'network' : seul l'administrador AnarBib accède. Voit tous les
--   memberships (staff + readers) de toutes les libs.
--
-- CHAMPS RETOURNÉS
-- ----------------
-- Pour chaque membership : tout ce qu'affiche TeamPanel (id, user_id,
-- library_id, role, status, is_primary, created_at, is_restricted,
-- restricted_reason, pending_removal_until, pending_removal_requested_by)
-- + profile minimal (email, first_name, last_name, public_id)
-- + library minimale (id, name, short_name, slug)
--
-- Champs explicitement EXCLUS (sensibles, non nécessaires à TeamPanel) :
-- - profiles.address
-- - profiles.phone
-- - profiles.gender
-- - profiles.must_change_password
-- - profiles.password_changed_at
-- - profiles.consent_email_at
-- - profiles.preferred_language (pas utile dans TeamPanel)
--
-- ROLLBACK
-- --------
-- DROP FUNCTION IF EXISTS public.fn_team_list_memberships(text, uuid);
--
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_team_list_memberships(
  p_scope      text,
  p_library_id uuid DEFAULT NULL
)
  RETURNS SETOF jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
  v_caller         uuid := auth.uid();
  v_caller_is_admin boolean;
BEGIN
  -- ── 1. Authentification minimale ────────────────────
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required'
      USING HINT = 'Sign in before calling this function.';
  END IF;

  -- ── 2. Validation du scope ──────────────────────────
  IF p_scope NOT IN ('library', 'network') THEN
    RAISE EXCEPTION 'invalid_scope'
      USING HINT = 'p_scope must be ''library'' or ''network''.';
  END IF;

  -- ── 3. Détection admin AnarBib (utilisé pour les 2 scopes) ──
  v_caller_is_admin := public.fn_caller_is_administrador();

  -- ═══ SCOPE = library ═══════════════════════════════
  IF p_scope = 'library' THEN
    IF p_library_id IS NULL THEN
      RAISE EXCEPTION 'library_id_required'
        USING HINT = 'Scope library requires a non-null p_library_id.';
    END IF;

    -- Droit d'accès : staff actif de cette lib OU admin AnarBib
    IF NOT (
      v_caller_is_admin
      OR public.user_has_library_staff_role(v_caller, p_library_id)
    ) THEN
      RAISE EXCEPTION 'forbidden'
        USING HINT = 'Caller is not staff of this library and not an administrador.';
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
    -- Droit d'accès : admin AnarBib uniquement
    IF NOT v_caller_is_admin THEN
      RAISE EXCEPTION 'forbidden'
        USING HINT = 'Network scope is reserved to administrador role.';
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
$$;

COMMENT ON FUNCTION public.fn_team_list_memberships(text, uuid) IS
  'Phase B1 follow-up 07/05/2026 : RPC alimentant <TeamPanel /> en lecture. '
  'SECURITY DEFINER pour permettre à l''admin AnarBib de voir les profils '
  'cross-bibliothèques sans ouvrir les RLS profiles. Valide explicitement '
  'les droits du caller selon le scope (library = staff de la lib OU admin ; '
  'network = admin uniquement). Retourne setof jsonb avec champs UI '
  'minimaux (pas d''adresse postale, téléphone, etc.).';

-- ─── Permissions d'exécution ───────────────────────────
REVOKE ALL ON FUNCTION public.fn_team_list_memberships(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_team_list_memberships(text, uuid) TO authenticated;
