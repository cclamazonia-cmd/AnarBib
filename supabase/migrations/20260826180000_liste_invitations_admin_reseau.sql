-- =====================================================================
-- 20260826180000_liste_invitations_admin_reseau.sql
--
-- Objet : rendre visible à l'administration réseau la proposition de
--         coordination qu'elle vient elle-même de déposer.
--
-- Constat : 20260826160000 a rouvert `fn_team_propose_invitation` aux admins
--   réseau pour `p_role = 'coordenador'`. Mais `fn_team_list_invitations`,
--   qui alimente la liste des invitations de l'écran d'équipe, filtre
--   toujours sur le seul `user_can_manage_library_notifications` — lequel
--   exige un membership LOCAL. Un·e admin réseau proposant sur une biblio
--   dont iel n'est pas membre recevait donc le message de succès, puis une
--   liste vide : ni relecture de sa proposition, ni constat de l'endossement.
--
-- Portée : une seule clause, dans une seule fonction. L'ouverture se fait au
--   niveau LIGNE (`i.role_proposed = 'coordenador'`), pas au niveau de la
--   fonction : les invitations d'accueil restent invisibles à qui ne peut pas
--   les proposer. Un·e admin réseau qui est AUSSI staff local passe par la
--   première branche et voit tout, comme avant.
--
-- Ce que ça ne fait pas : aucun droit d'ÉCRITURE n'est ajouté. Ratifier et
--   accepter gardent leurs propres gardes, inchangées.
--
-- Idempotente : CREATE OR REPLACE, signature inchangée.
-- Rollback : réappliquer la définition de 20260826120000 §7.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_team_list_invitations(p_library_id uuid)
RETURNS SETOF jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
  SELECT jsonb_build_object(
    'id', i.id,
    'library_id', i.library_id,
    'status', i.status,
    'role_proposed', i.role_proposed,
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
    AND (
      -- Le staff LOCAL voit tout ce qui concerne son équipe : inchangé.
      public.user_can_manage_library_notifications(p_library_id)
      -- Depuis 20260826160000, un·e admin réseau peut PROPOSER un passage à la
      -- coordination sur une biblio où iel n'a pas de membership. Mais cette
      -- liste-ci lui restait fermée : iel obtenait le message de succès, puis un
      -- écran vide — impossible de relire sa propre proposition, ni de constater
      -- qu'elle a été endossée. Proposer sans pouvoir relire n'est pas une demi-
      -- mesure prudente, c'est une action à l'aveugle.
      --
      -- L'ouverture est volontairement ÉTROITE, au niveau LIGNE et non de la
      -- fonction : seules les propositions de coordination deviennent visibles.
      -- L'accueil (role_proposed = 'librarian') reste l'affaire du staff local —
      -- un·e admin réseau ne peut pas le proposer, iel n'a pas à le lire.
      OR (i.role_proposed = 'coordenador' AND public.fn_caller_is_network_admin())
    )
  ORDER BY i.created_at DESC;
$fn$;

COMMIT;
