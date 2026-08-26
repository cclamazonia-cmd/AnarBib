-- =====================================================================
-- 20260826160000_garde_propose_invitation_admin_reseau.sql
--
-- Objet : rendre à l'administration réseau le droit de PROPOSER un passage à
--         la coordination, que 20260826120000 lui a retiré sans le vouloir.
--
-- Constat : `fn_team_propose_invitation` s'ouvre sur
--   `user_can_manage_library_notifications(p_library_id)`, qui exige un
--   membership LOCAL actif (librarian ou coordenador) et ne connaît pas les
--   admins réseau. C'était sans effet tant que le circuit ne servait qu'à
--   l'accueil — un·e admin réseau n'a pas à accueillir dans une équipe dont
--   iel n'est pas membre, et cette moitié de la règle est conservée ici.
--   Mais T2 (librarian -> coordenador) est passée sur ce même circuit le
--   26/08/2026, alors que l'ancienne `fn_team_promote_to_coordenador` était,
--   elle, ouverte aux admins réseau via `user_can_engage_library`.
--
-- Conséquence corrigée : une bibliothèque sans aucun coordenador actif ne
--   pouvait plus en retrouver un. Les librarians locaux franchissent la
--   garde 1 mais pas la garde 2 ; l'admin réseau était arrêté à la garde 1.
--   Le rattrapage décrit au §6.1 de spec-gouvernance-roles était mort.
--
-- Portée : une seule condition, dans une seule fonction. Aucune autre RPC,
--   aucune table, aucun droit modifiés. L'accueil (p_role = 'librarian')
--   garde exactement la garde qu'il avait avant le 26/08.
--
-- Idempotente : CREATE OR REPLACE, signature inchangée — défaut
--   `p_role text DEFAULT 'librarian'::text` reconduit (cf. GOUV-6 : le
--   retirer lèverait 42P13).
--
-- Rollback : réappliquer la définition de 20260826120000 §2. Aucun rollback
--   dédié — cette migration ne fait que restaurer un droit préexistant.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_team_propose_invitation(
  p_library_id uuid,
  p_invited_public_id text,
  -- Le DEFAULT vient de 20260820210000 et doit être reconduit à l'identique :
  -- CREATE OR REPLACE sait AJOUTER une valeur par défaut, jamais en RETIRER
  -- (42P13, « cannot remove parameter defaults from existing function »).
  -- L'omettre a fait échouer cette migration en production le 26/08/2026.
  p_role text DEFAULT 'librarian'::text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_actor uuid := auth.uid();
  v_invited uuid;
  v_staff_count int;
  v_required int;
  v_mode text;
  v_actor_is_coord boolean;
  v_inv_id uuid;
  v_status text;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF p_role IS NULL OR p_role NOT IN ('librarian', 'coordenador') THEN
    RAISE EXCEPTION 'forbidden: role must be librarian or coordenador';
  END IF;

  -- Garde 1 — qui a le droit de DÉPOSER une proposition.
  --
  -- L'accueil (p_role = 'librarian') reste réservé au staff LOCAL, comme depuis
  -- l'origine du circuit : un·e admin réseau n'a pas à faire entrer quelqu'un dans
  -- une équipe dont iel n'est pas membre. Cette moitié-là ne change pas.
  --
  -- La promotion à coordenador, elle, était accessible à l'admin réseau jusqu'au
  -- 26/08/2026 : fn_team_promote_to_coordenador passait par user_can_manage_library,
  -- donc user_can_engage_library, qui l'inclut explicitement. En basculant T2 sur ce
  -- circuit sans reconduire ce droit, 20260826120000 l'a supprimé sans le dire.
  --
  -- Ce que ça cassait, au-delà du confort : une biblio qui a perdu tou·tes ses
  -- coordenadores ne pouvait plus en retrouver. Les librarians locaux passent cette
  -- garde mais échouent à la suivante (proposer un coordenador exige coordenador+) ;
  -- l'admin réseau, lui, était arrêté ici même. Plus personne ne pouvait rendre sa
  -- coordination à la biblio — précisément le cas que §6.1 de spec-gouvernance-roles
  -- confie aux admins réseau.
  --
  -- Que ce soit un oubli et non un choix, la fonction le dit elle-même : elle appelle
  -- plus bas fn_log_cross_library_action(stage := 'proposed'), un traçage qui n'existe
  -- que pour les actes transverses d'admin réseau. Ce code était inatteignable.
  IF NOT (public.user_can_manage_library_notifications(p_library_id)
          OR (p_role = 'coordenador' AND public.fn_caller_is_network_admin())) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can propose an invitation';
  END IF;

  -- Proposer une promotion à coordenador reste un acte de coordination.
  -- (user_can_manage_library couvre coordenador local ET admin réseau.)
  IF p_role = 'coordenador' AND NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can propose a promotion to coordenador';
  END IF;

  SELECT id INTO v_invited
    FROM public.profiles
   WHERE upper(btrim(public_id)) = upper(btrim(p_invited_public_id));

  IF v_invited IS NULL THEN
    RAISE EXCEPTION 'not_found: no profile with that public_id';
  END IF;

  -- Couvre aussi le garde-fou historique « pas d'auto-promotion ».
  IF v_invited = v_actor THEN
    RAISE EXCEPTION 'forbidden: cannot invite or promote yourself';
  END IF;

  IF p_role = 'librarian' THEN
    IF EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_invited AND m.library_id = p_library_id
         AND m.role IN ('librarian', 'coordenador') AND m.status = 'active'
    ) THEN
      RAISE EXCEPTION 'conflict: already an active team member';
    END IF;
  ELSE
    IF EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_invited AND m.library_id = p_library_id
         AND m.role = 'coordenador' AND m.status = 'active'
    ) THEN
      RAISE EXCEPTION 'conflict: already an active coordenador';
    END IF;

    -- Précondition héritée de fn_team_promote_to_coordenador §5 :
    -- on ne saute pas de reader à coordenador.
    IF NOT EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_invited AND m.library_id = p_library_id
         AND m.role = 'librarian' AND m.status = 'active'
    ) THEN
      RAISE EXCEPTION 'precondition_failed: target must be active librarian first';
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.library_team_invitations
     WHERE library_id = p_library_id AND invited_user_id = v_invited
       AND status IN ('pending_ratification', 'ready')
  ) THEN
    RAISE EXCEPTION 'conflict: an active invitation already exists for this person';
  END IF;

  SELECT team_admission_mode INTO v_mode
    FROM public.libraries WHERE id = p_library_id;

  -- La personne visée est exclue du décompte : sur une promotion à coordenador
  -- elle est elle-même staff, et l'inclure produirait un quorum impossible à
  -- atteindre dans une équipe de deux (elle accepte, elle ne ratifie pas).
  SELECT count(*) INTO v_staff_count
    FROM public.user_library_memberships
   WHERE library_id = p_library_id
     AND role IN ('librarian', 'coordenador')
     AND status = 'active'
     AND user_id <> v_invited;

  v_required := CASE
    WHEN v_mode = 'coordenador_seul' THEN 1
    WHEN v_staff_count < 2 THEN 1
    ELSE 2
  END;

  v_actor_is_coord := public.fn_team_caller_is_coordenador(p_library_id);

  INSERT INTO public.library_team_invitations
    (library_id, invited_user_id, role_proposed, proposed_by, status,
     required_ratifications, expires_at)
  VALUES
    (p_library_id, v_invited, p_role, v_actor, 'pending_ratification',
     v_required, now() + interval '30 days')
  RETURNING id INTO v_inv_id;

  INSERT INTO public.library_team_invitation_ratifications
    (invitation_id, ratifier_user_id, is_coordenador)
  VALUES (v_inv_id, v_actor, v_actor_is_coord);

  PERFORM public.fn_team_invitation_recompute(v_inv_id);
  SELECT status INTO v_status
    FROM public.library_team_invitations WHERE id = v_inv_id;

  -- Traçage transverse : c'est ici que l'acte de coordination a lieu,
  -- pas à l'acceptation (qui est le fait de la personne visée).
  IF p_role = 'coordenador' THEN
    PERFORM public.fn_log_cross_library_action(
      p_library_id         := p_library_id,
      p_action_type        := 'team_promote_to_coordenador',
      p_is_critical        := public.fn_is_critical_action_type('team_promote_to_coordenador'),
      p_target_entity_type := 'library_team_invitation',
      p_target_entity_id   := v_inv_id,
      p_payload            := jsonb_build_object(
        'target_user_id', v_invited,
        'stage', 'proposed',
        'required_ratifications', v_required
      )
    );
  END IF;

  IF v_status = 'ready' THEN
    PERFORM public.fn_team_notify_event('team.invitation_ready', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited,
      'actor_user_id', v_actor, 'invitation_id', v_inv_id,
      'role_proposed', p_role));
  ELSE
    PERFORM public.fn_team_notify_event('team.invitation_proposed', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited,
      'actor_user_id', v_actor, 'invitation_id', v_inv_id,
      'role_proposed', p_role));
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'invitation_id', v_inv_id,
    'role_proposed', p_role,
    'required_ratifications', v_required,
    'status', v_status
  );
END
$fn$;

COMMIT;
