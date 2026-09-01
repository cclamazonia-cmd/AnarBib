-- =====================================================================
-- _rollback_20260901162610_le_saut_collegial_est_un_choix_de_biblio.sql
--
-- Défait 20260901162610 :
--   1. fn_team_propose_invitation : retour à la définition 20260826160000
--      (garde admin réseau conservée, précondition « librarian first » stricte).
--   2. fn_team_accept_invitation : retour à la définition 20260826120000 §4.
--   3. suppression du réglage libraries.allow_direct_coordenador.
-- Ordre : fonctions d'abord (elles cessent de référencer la colonne),
-- colonne ensuite. Fichier préfixé « _ » : ignoré par la CLI Supabase.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_team_propose_invitation(
  p_library_id uuid,
  p_invited_public_id text,
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

  IF NOT (public.user_can_manage_library_notifications(p_library_id)
          OR (p_role = 'coordenador' AND public.fn_caller_is_network_admin())) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can propose an invitation';
  END IF;

  IF p_role = 'coordenador' AND NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can propose a promotion to coordenador';
  END IF;

  SELECT id INTO v_invited
    FROM public.profiles
   WHERE upper(btrim(public_id)) = upper(btrim(p_invited_public_id));

  IF v_invited IS NULL THEN
    RAISE EXCEPTION 'not_found: no profile with that public_id';
  END IF;

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


CREATE OR REPLACE FUNCTION public.fn_team_accept_invitation(
  p_invitation_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_actor uuid := auth.uid();
  v_inv record;
  v_membership_id uuid;
  v_lower record;
  v_audit_id uuid;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  SELECT * INTO v_inv FROM public.library_team_invitations WHERE id = p_invitation_id;
  IF v_inv.id IS NULL THEN
    RAISE EXCEPTION 'not_found: invitation';
  END IF;

  IF v_inv.invited_user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'forbidden: only the invited person can accept';
  END IF;

  IF v_inv.status IS DISTINCT FROM 'ready' THEN
    RAISE EXCEPTION 'conflict: invitation not ready (%)', v_inv.status;
  END IF;

  IF v_inv.expires_at IS NOT NULL AND v_inv.expires_at < now() THEN
    RAISE EXCEPTION 'conflict: invitation expired';
  END IF;

  IF v_inv.role_proposed = 'librarian' THEN

    INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
    VALUES (v_inv.invited_user_id, v_inv.library_id, 'librarian', 'active')
    ON CONFLICT (user_id, library_id, role) DO UPDATE
      SET status = 'active', pending_removal_until = NULL,
          pending_removal_requested_by = NULL, updated_at = now()
    RETURNING id INTO v_membership_id;

    SELECT * INTO v_lower FROM public.user_library_memberships
      WHERE user_id = v_inv.invited_user_id AND library_id = v_inv.library_id
        AND role = 'reader' AND status = 'active';

    IF FOUND THEN
      UPDATE public.user_library_memberships
        SET status = 'removed', is_primary = false, updated_at = now()
       WHERE id = v_lower.id;

      INSERT INTO public.library_membership_audit
        (library_id, target_user_id, actor_user_id, action, role,
         status_before, status_after, reason, metadata)
      VALUES
        (v_inv.library_id, v_inv.invited_user_id, v_actor, 'removal_completed', 'reader',
         'active', 'removed',
         'Membership reader cloturé suite à accueil dans l''équipe',
         jsonb_build_object('superseded_by', 'librarian',
                            'librarian_membership_id', v_membership_id));
    END IF;

    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role,
       status_before, status_after, reason, metadata)
    VALUES
      (v_inv.library_id, v_inv.invited_user_id, v_actor, 'promoted_to_librarian', 'librarian',
       NULL, 'active',
       'Accueil dans l''équipe (invitation acceptée)',
       jsonb_build_object('via', 'team_invitation_accepted',
                          'invitation_id', v_inv.id,
                          'proposed_by', v_inv.proposed_by))
    RETURNING id INTO v_audit_id;

  ELSIF v_inv.role_proposed = 'coordenador' THEN

    IF NOT EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_inv.invited_user_id AND m.library_id = v_inv.library_id
         AND m.role = 'librarian' AND m.status = 'active'
    ) THEN
      RAISE EXCEPTION 'precondition_failed: no longer an active librarian';
    END IF;

    INSERT INTO public.user_library_memberships
      (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
    VALUES
      (v_inv.invited_user_id, v_inv.library_id, 'coordenador', 'active', NULL, NULL)
    ON CONFLICT (user_id, library_id, role) DO UPDATE
      SET status = 'active', pending_removal_until = NULL,
          pending_removal_requested_by = NULL, updated_at = now()
    RETURNING id INTO v_membership_id;

    SELECT * INTO v_lower FROM public.user_library_memberships
      WHERE user_id = v_inv.invited_user_id AND library_id = v_inv.library_id
        AND role = 'librarian' AND status = 'active';

    IF FOUND THEN
      UPDATE public.user_library_memberships
        SET status = 'removed', is_primary = false, updated_at = now()
       WHERE id = v_lower.id;

      INSERT INTO public.library_membership_audit
        (library_id, target_user_id, actor_user_id, action, role,
         status_before, status_after, reason, metadata)
      VALUES
        (v_inv.library_id, v_inv.invited_user_id, v_actor, 'removal_completed', 'librarian',
         'active', 'removed',
         'Membership librarian cloturé suite à promotion coordenador',
         jsonb_build_object('superseded_by', 'coordenador',
                            'coordenador_membership_id', v_membership_id));
    END IF;

    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role,
       status_before, status_after, reason, metadata)
    VALUES
      (v_inv.library_id, v_inv.invited_user_id, v_actor, 'promoted_to_coordenador', 'coordenador',
       NULL, 'active',
       'Promotion collégiale acceptée',
       jsonb_build_object('via', 'team_invitation_accepted',
                          'invitation_id', v_inv.id,
                          'proposed_by', v_inv.proposed_by,
                          'required_ratifications', v_inv.required_ratifications))
    RETURNING id INTO v_audit_id;

    PERFORM public.fn_team_notify_event('team.promoted_to_coordenador', jsonb_build_object(
      'library_id', v_inv.library_id,
      'target_user_id', v_inv.invited_user_id,
      'actor_user_id', v_inv.proposed_by,
      'audit_id', v_audit_id));

  ELSE
    RAISE EXCEPTION 'conflict: unsupported role_proposed (%)', v_inv.role_proposed;
  END IF;

  UPDATE public.library_team_invitations
     SET status = 'accepted', resolved_at = now(), updated_at = now()
   WHERE id = p_invitation_id;

  RETURN jsonb_build_object(
    'ok', true,
    'library_id', v_inv.library_id,
    'role', v_inv.role_proposed,
    'membership_id', v_membership_id,
    'audit_id', v_audit_id
  );
END
$fn$;

ALTER TABLE public.libraries DROP COLUMN IF EXISTS allow_direct_coordenador;

COMMIT;
