-- =====================================================================
-- AnarBib — Accueil dans l'équipe — LOT 3.0 : RPC de liste (pour l'UI)
-- Auteur  : coordination AnarBib
-- Session : Invitation-équipe (mise en place)
-- Réf     : 20260619125325_invitation_equipe.sql ; CADRAGE_accueil_equipe.
--
-- Deux SECDEF de lecture qui alimentent le front (la RLS sur profiles interdit
-- au staff de lire les profils d'autrui — même raison que fn_team_list_memberships) :
--  - fn_team_list_invitations(library_id) : invitations vivantes d'une biblio,
--    pour le staff (avec nom/public_id de l'invité·e + compteur d'endossements).
--  - fn_team_my_invitations() : les invitations de la personne courante
--    (pour l'onglet « mes invitations » : accepter/décliner).
-- =====================================================================

-- ── 1. Liste staff : invitations vivantes d'une biblio ───────────────
CREATE OR REPLACE FUNCTION public.fn_team_list_invitations(p_library_id uuid)
RETURNS SETOF jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
  SELECT jsonb_build_object(
    'id', i.id,
    'library_id', i.library_id,
    'status', i.status,
    'required_ratifications', i.required_ratifications,
    'ratifications_count', (SELECT count(*) FROM public.library_team_invitation_ratifications r WHERE r.invitation_id = i.id),
    'has_coordenador', COALESCE((SELECT bool_or(r.is_coordenador) FROM public.library_team_invitation_ratifications r WHERE r.invitation_id = i.id), false),
    'caller_has_ratified', EXISTS (SELECT 1 FROM public.library_team_invitation_ratifications r WHERE r.invitation_id = i.id AND r.ratifier_user_id = auth.uid()),
    'invited_public_id', ip.public_id,
    'invited_name', NULLIF(btrim(COALESCE(ip.first_name,'') || ' ' || COALESCE(ip.last_name,'')), ''),
    'invited_email', ip.email,
    'proposed_by_name', NULLIF(btrim(COALESCE(pp.first_name,'') || ' ' || COALESCE(pp.last_name,'')), ''),
    'created_at', i.created_at,
    'expires_at', i.expires_at
  )
  FROM public.library_team_invitations i
  JOIN public.profiles ip ON ip.id = i.invited_user_id
  LEFT JOIN public.profiles pp ON pp.id = i.proposed_by
  WHERE i.library_id = p_library_id
    AND i.status IN ('pending_ratification','ready')
    AND public.user_can_manage_library_notifications(p_library_id)
  ORDER BY i.created_at DESC;
$$;
ALTER FUNCTION public.fn_team_list_invitations(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_list_invitations(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_list_invitations(uuid) TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_team_list_invitations(uuid) IS
  'Invitations vivantes (pending/ready) d''une biblio pour son staff. SECDEF (lit profiles, gardé user_can_manage_library_notifications dans le WHERE : 0 ligne si non-staff). Alimente la section « invitations en attente » de TeamPanel.';

-- ── 2. Liste de la personne invitée : ses invitations ────────────────
CREATE OR REPLACE FUNCTION public.fn_team_my_invitations()
RETURNS SETOF jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
  SELECT jsonb_build_object(
    'id', i.id,
    'library_id', i.library_id,
    'library_name', l.name,
    'status', i.status,
    'role_proposed', i.role_proposed,
    'proposed_by_name', NULLIF(btrim(COALESCE(pp.first_name,'') || ' ' || COALESCE(pp.last_name,'')), ''),
    'created_at', i.created_at,
    'expires_at', i.expires_at
  )
  FROM public.library_team_invitations i
  JOIN public.libraries l ON l.id = i.library_id
  LEFT JOIN public.profiles pp ON pp.id = i.proposed_by
  WHERE i.invited_user_id = auth.uid()
    AND i.status IN ('pending_ratification','ready')
  ORDER BY i.created_at DESC;
$$;
ALTER FUNCTION public.fn_team_my_invitations() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_my_invitations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_my_invitations() TO authenticated, service_role;
COMMENT ON FUNCTION public.fn_team_my_invitations() IS
  'Invitations vivantes adressées à la personne courante (auth.uid()). SECDEF (lit libraries + proposeur). Alimente l''onglet « mes invitations » (accepter/décliner ; accept exige status=ready).';

NOTIFY pgrst, 'reload schema';
