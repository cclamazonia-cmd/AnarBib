-- =====================================================================
-- ROLLBACK de 20260826120000_team_coordenador_collegial_promotion.sql
--
-- Restaure les quatre fonctions dans leur état du 26/08/2026 avant migration,
-- et referme la contrainte de rôle sur 'librarian'.
--
-- ATTENTION : la contrainte ne peut être refermée que si aucune invitation
-- ne porte role_proposed = 'coordenador'. Les invitations coordenador encore
-- ouvertes sont donc révoquées (status = 'revoked'), puis les lignes résolues
-- sont réécrites en 'librarian' — ce qui est faux historiquement, mais
-- l'alternative serait de les détruire. Les promotions déjà ACCEPTÉES ne sont
-- pas défaites : les memberships et l'audit restent intacts.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 0. Neutraliser les invitations coordenador avant de refermer la contrainte
-- ---------------------------------------------------------------------

UPDATE public.library_team_invitations
   SET status = 'revoked',
       resolved_at = COALESCE(resolved_at, now()),
       resolution_note = COALESCE(resolution_note, '')
                         || ' [rollback 20260826120000: invitation coordenador neutralisée]',
       updated_at = now()
 WHERE role_proposed = 'coordenador'
   AND status IN ('pending_ratification', 'ready');

UPDATE public.library_team_invitations
   SET role_proposed = 'librarian',
       resolution_note = COALESCE(resolution_note, '')
                         || ' [rollback 20260826120000: role_proposed reecrit, valeur reelle = coordenador]',
       updated_at = now()
 WHERE role_proposed = 'coordenador';

ALTER TABLE public.library_team_invitations
  DROP CONSTRAINT IF EXISTS library_team_invitations_role_proposed_check;

ALTER TABLE public.library_team_invitations
  ADD CONSTRAINT library_team_invitations_role_proposed_check
  CHECK (role_proposed = 'librarian'::text);


-- ---------------------------------------------------------------------
-- 1. fn_team_propose_invitation — état antérieur
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_propose_invitation(
  p_library_id uuid,
  p_invited_public_id text,
  -- Même contrainte qu'à l'aller (42P13) : le DEFAULT de 20260820210000 est
  -- reconduit tel quel, sans quoi ce rollback échouerait au moment précis
  -- où on en aurait besoin.
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
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  IF p_role IS DISTINCT FROM 'librarian' THEN
    RAISE EXCEPTION 'forbidden: only librarian can be invited (coordenador via promotion/transfer)';
  END IF;
  IF NOT public.user_can_manage_library_notifications(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can propose an invitation';
  END IF;

  SELECT id INTO v_invited FROM public.profiles
   WHERE upper(btrim(public_id)) = upper(btrim(p_invited_public_id));

  IF v_invited IS NULL THEN RAISE EXCEPTION 'not_found: no profile with that public_id'; END IF;
  IF v_invited = v_actor THEN RAISE EXCEPTION 'forbidden: cannot invite yourself'; END IF;
  IF EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = v_invited AND m.library_id = p_library_id
               AND m.role IN ('librarian','coordenador') AND m.status = 'active') THEN
    RAISE EXCEPTION 'conflict: already an active team member';
  END IF;
  IF EXISTS (SELECT 1 FROM public.library_team_invitations
             WHERE library_id = p_library_id AND invited_user_id = v_invited
               AND status IN ('pending_ratification','ready')) THEN
    RAISE EXCEPTION 'conflict: an active invitation already exists for this person';
  END IF;
  SELECT team_admission_mode INTO v_mode FROM public.libraries WHERE id = p_library_id;
  SELECT count(*) INTO v_staff_count FROM public.user_library_memberships
    WHERE library_id = p_library_id AND role IN ('librarian','coordenador') AND status = 'active';
  v_required := CASE
    WHEN v_mode = 'coordenador_seul' THEN 1
    WHEN v_staff_count < 2 THEN 1
    ELSE 2
  END;
  v_actor_is_coord := public.fn_team_caller_is_coordenador(p_library_id);

  INSERT INTO public.library_team_invitations
    (library_id, invited_user_id, role_proposed, proposed_by, status, required_ratifications, expires_at)
  VALUES
    (p_library_id, v_invited, 'librarian', v_actor, 'pending_ratification', v_required, now() + interval '30 days')
  RETURNING id INTO v_inv_id;

  INSERT INTO public.library_team_invitation_ratifications (invitation_id, ratifier_user_id, is_coordenador)
  VALUES (v_inv_id, v_actor, v_actor_is_coord);

  PERFORM public.fn_team_invitation_recompute(v_inv_id);
  SELECT status INTO v_status FROM public.library_team_invitations WHERE id = v_inv_id;

  IF v_status = 'ready' THEN
    PERFORM public.fn_team_notify_event('team.invitation_ready', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited, 'actor_user_id', v_actor, 'invitation_id', v_inv_id));
  ELSE
    PERFORM public.fn_team_notify_event('team.invitation_proposed', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited, 'actor_user_id', v_actor, 'invitation_id', v_inv_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'invitation_id', v_inv_id,
                 'required_ratifications', v_required, 'status', v_status);
END
$fn$;


-- ---------------------------------------------------------------------
-- 2. fn_team_ratify_invitation — état antérieur
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_ratify_invitation(
  p_invitation_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_actor uuid := auth.uid();
  v_lib uuid;
  v_status text;
  v_is_coord boolean;
  v_invited uuid;
  v_proposer uuid;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  SELECT library_id, status, invited_user_id, proposed_by INTO v_lib, v_status, v_invited, v_proposer
    FROM public.library_team_invitations WHERE id = p_invitation_id;
  IF v_lib IS NULL THEN RAISE EXCEPTION 'not_found: invitation'; END IF;
  IF v_status IS DISTINCT FROM 'pending_ratification' THEN
    RAISE EXCEPTION 'conflict: invitation not pending (%)', v_status;
  END IF;
  IF NOT public.user_can_manage_library_notifications(v_lib) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can ratify';
  END IF;
  v_is_coord := public.fn_team_caller_is_coordenador(v_lib);
  INSERT INTO public.library_team_invitation_ratifications (invitation_id, ratifier_user_id, is_coordenador)
  VALUES (p_invitation_id, v_actor, v_is_coord)
  ON CONFLICT (invitation_id, ratifier_user_id) DO UPDATE SET is_coordenador = EXCLUDED.is_coordenador;
  PERFORM public.fn_team_invitation_recompute(p_invitation_id);
  SELECT status INTO v_status FROM public.library_team_invitations WHERE id = p_invitation_id;

  IF v_status = 'ready' THEN
    PERFORM public.fn_team_notify_event('team.invitation_ready', jsonb_build_object(
      'library_id', v_lib, 'target_user_id', v_invited, 'actor_user_id', v_proposer, 'invitation_id', p_invitation_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'status', v_status);
END
$fn$;


-- ---------------------------------------------------------------------
-- 3. fn_team_accept_invitation — état antérieur
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_accept_invitation(
  p_invitation_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_actor uuid := auth.uid(); v_inv record; v_membership_id uuid; v_reader record;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  SELECT * INTO v_inv FROM public.library_team_invitations WHERE id = p_invitation_id;
  IF v_inv.id IS NULL THEN RAISE EXCEPTION 'not_found: invitation'; END IF;
  IF v_inv.invited_user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'forbidden: only the invited person can accept';
  END IF;
  IF v_inv.status IS DISTINCT FROM 'ready' THEN
    RAISE EXCEPTION 'conflict: invitation not ready (%)', v_inv.status;
  END IF;

  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_inv.invited_user_id, v_inv.library_id, 'librarian', 'active')
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active', pending_removal_until = NULL,
        pending_removal_requested_by = NULL, updated_at = now()
  RETURNING id INTO v_membership_id;

  SELECT * INTO v_reader FROM public.user_library_memberships
    WHERE user_id = v_inv.invited_user_id AND library_id = v_inv.library_id
      AND role = 'reader' AND status = 'active';
  IF FOUND THEN
    UPDATE public.user_library_memberships
      SET status = 'removed', is_primary = false, updated_at = now() WHERE id = v_reader.id;
    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
    VALUES
      (v_inv.library_id, v_inv.invited_user_id, v_actor, 'removal_completed', 'reader', 'active', 'removed',
       'Membership reader cloturé suite à accueil dans l''équipe',
       jsonb_build_object('superseded_by', 'librarian', 'librarian_membership_id', v_membership_id));
  END IF;

  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (v_inv.library_id, v_inv.invited_user_id, v_actor, 'promoted_to_librarian', 'librarian', NULL, 'active',
     'Accueil dans l''équipe (invitation acceptée)',
     jsonb_build_object('via', 'team_invitation_accepted', 'invitation_id', v_inv.id, 'proposed_by', v_inv.proposed_by));

  UPDATE public.library_team_invitations
    SET status = 'accepted', resolved_at = now(), updated_at = now() WHERE id = p_invitation_id;

  RETURN jsonb_build_object('ok', true, 'library_id', v_inv.library_id, 'role', 'librarian', 'membership_id', v_membership_id);
END
$fn$;


-- ---------------------------------------------------------------------
-- 4. fn_team_promote_to_coordenador — état antérieur (promotion directe)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_coordenador(
  p_user_id uuid,
  p_library_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_librarian_active boolean;
  v_status_before text;
  v_audit_id uuid;
  v_membership_id uuid;
  v_librarian record;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can promote to coordenador';
  END IF;

  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'forbidden: cannot self-promote';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'not_found: target user does not exist';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = p_user_id AND library_id = p_library_id
      AND role = 'librarian' AND status = 'active'
  ) INTO v_librarian_active;

  IF NOT v_librarian_active THEN
    RAISE EXCEPTION 'precondition_failed: target must be active librarian first (use fn_team_promote_to_librarian)';
  END IF;

  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id AND library_id = p_library_id AND role = 'coordenador';

  IF FOUND AND v_existing.status = 'active' THEN
    RETURN jsonb_build_object('ok', true, 'no_change', true,
      'reason', 'already_coordenador_active', 'action', 'promoted_to_coordenador');
  END IF;

  v_status_before := v_existing.status;

  INSERT INTO public.user_library_memberships
    (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
  VALUES
    (p_user_id, p_library_id, 'coordenador', 'active', NULL, NULL)
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active', pending_removal_until = NULL,
        pending_removal_requested_by = NULL, updated_at = now()
  RETURNING id INTO v_membership_id;

  SELECT * INTO v_librarian
  FROM public.user_library_memberships
  WHERE user_id = p_user_id AND library_id = p_library_id
    AND role = 'librarian' AND status = 'active';

  IF FOUND THEN
    UPDATE public.user_library_memberships
    SET status = 'removed', is_primary = false, updated_at = now()
    WHERE id = v_librarian.id;

    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role,
       status_before, status_after, reason, metadata)
    VALUES
      (p_library_id, p_user_id, v_actor_id, 'removal_completed', 'librarian',
       'active', 'removed',
       'Membership librarian cloturé suite à promotion coordenador',
       jsonb_build_object('superseded_by', 'coordenador',
                          'coordenador_membership_id', v_membership_id));
  END IF;

  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_coordenador', 'coordenador',
     v_status_before, 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

  PERFORM public.fn_log_cross_library_action(
    p_library_id        := p_library_id,
    p_action_type       := 'team_promote_to_coordenador',
    p_is_critical       := public.fn_is_critical_action_type('team_promote_to_coordenador'),
    p_target_entity_type := 'user_library_membership',
    p_target_entity_id  := v_membership_id,
    p_payload           := jsonb_build_object(
      'target_user_id', p_user_id,
      'status_before', v_status_before,
      'status_after', 'active',
      'audit_id', v_audit_id
    )
  );

  PERFORM public.fn_team_notify_event(
    'team.promoted_to_coordenador',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object('ok', true, 'action', 'promoted_to_coordenador', 'audit_id', v_audit_id);
END
$fn$;


-- ---------------------------------------------------------------------
-- 5. Retirer la péremption automatique des invitations
-- ---------------------------------------------------------------------

DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-team-invitations-expire') THEN
    PERFORM cron.unschedule('anarbib-team-invitations-expire');
  END IF;
EXCEPTION
  WHEN undefined_table OR undefined_function OR invalid_schema_name OR insufficient_privilege THEN
    RAISE NOTICE 'pg_cron indisponible ici : desplanifier anarbib-team-invitations-expire manuellement';
END
$do$;

DROP FUNCTION IF EXISTS public.fn_team_expire_invitations();

COMMIT;
