-- =====================================================================
-- AnarBib — Accueil dans l'équipe — LOT 4 : notifications (émission des events)
-- Auteur  : coordination AnarBib
-- Session : Invitation-équipe (mise en place)
-- Réf     : 20260619125325_invitation_equipe.sql ; CADRAGE_accueil_equipe.
--
-- Les RPC propose/ratify émettent désormais des events team.* (best-effort, via
-- fn_team_notify_event → team_notification_outbox → EF notify-event) :
--   - team.invitation_proposed : invitation en attente → la coordination (à endosser)
--   - team.invitation_ready    : invitation prête → la personne invitée (à accepter)
-- Payload canonique (library_id, target_user_id=invité·e, actor_user_id=proposeur·euse,
-- invitation_id). L'in-app est déjà couvert par l'UI (TabBiblios / TeamPanel).
-- =====================================================================

-- ── propose : émet ready (→ invité·e) ou proposed (→ coordination) ───
CREATE OR REPLACE FUNCTION public.fn_team_propose_invitation(
  p_library_id uuid, p_invited_public_id text, p_role text DEFAULT 'librarian'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
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
  SELECT id INTO v_invited FROM public.profiles WHERE public_id = upper(btrim(p_invited_public_id));
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

  -- Notification (lot 4, best-effort) : prête → invité·e ; sinon → coordination.
  IF v_status = 'ready' THEN
    PERFORM public.fn_team_notify_event('team.invitation_ready', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited, 'actor_user_id', v_actor, 'invitation_id', v_inv_id));
  ELSE
    PERFORM public.fn_team_notify_event('team.invitation_proposed', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited, 'actor_user_id', v_actor, 'invitation_id', v_inv_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'invitation_id', v_inv_id,
                 'required_ratifications', v_required, 'status', v_status);
END $$;
ALTER FUNCTION public.fn_team_propose_invitation(uuid, text, text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_propose_invitation(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_propose_invitation(uuid, text, text) TO authenticated, service_role;

-- ── ratify : émet ready (→ invité·e) si l'endossement vient de finaliser ──
CREATE OR REPLACE FUNCTION public.fn_team_ratify_invitation(p_invitation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_lib uuid; v_status text; v_is_coord boolean; v_invited uuid; v_proposer uuid;
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

  -- Notification (lot 4, best-effort) : l'endossement vient de rendre l'invitation prête.
  IF v_status = 'ready' THEN
    PERFORM public.fn_team_notify_event('team.invitation_ready', jsonb_build_object(
      'library_id', v_lib, 'target_user_id', v_invited, 'actor_user_id', v_proposer, 'invitation_id', p_invitation_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'status', v_status);
END $$;
ALTER FUNCTION public.fn_team_ratify_invitation(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_ratify_invitation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_ratify_invitation(uuid) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
