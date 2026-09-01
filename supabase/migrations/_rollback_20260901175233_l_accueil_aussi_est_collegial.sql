-- =====================================================================
-- _rollback_20260901175233_l_accueil_aussi_est_collegial.sql
--
-- Défait 20260901175233 : restaure la promotion directe reader -> librarian
-- telle qu'elle existait (définition du baseline 20260510000000, hotfix #35
-- inclus — fermeture de la ligne reader). Fichier préfixé « _ » : ignoré
-- par la CLI Supabase.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_librarian(
  p_user_id uuid,
  p_library_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_status_before text;
  v_audit_id uuid;
  v_membership_id uuid;
  v_reader record;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Autorisation : coordenador+ de la biblio cible (depuis D.2, inclut admin réseau)
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can promote to librarian';
  END IF;

  -- 3. Garde-fou : pas d'auto-promotion (cf. spec §6.2)
  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'forbidden: cannot self-promote';
  END IF;

  -- 4. Vérification existence de la cible
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'not_found: target user does not exist';
  END IF;

  -- 5. Idempotence : si déjà librarian active, ne rien faire
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = 'librarian';

  IF FOUND AND v_existing.status = 'active' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'no_change', true,
      'reason', 'already_librarian_active',
      'action', 'promoted_to_librarian'
    );
  END IF;

  v_status_before := v_existing.status;

  -- 6. INSERT ou UPDATE (réactivation d'une membership inactive)
  INSERT INTO public.user_library_memberships
    (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
  VALUES
    (p_user_id, p_library_id, 'librarian', 'active', NULL, NULL)
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now()
  RETURNING id INTO v_membership_id;

  -- 6.bis (hotfix #35) : fermer le membership reader de la meme biblio.
  SELECT * INTO v_reader
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = 'reader'
    AND status = 'active';

  IF FOUND THEN
    UPDATE public.user_library_memberships
    SET status = 'removed',
        is_primary = false,
        updated_at = now()
    WHERE id = v_reader.id;

    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role,
       status_before, status_after, reason, metadata)
    VALUES
      (p_library_id, p_user_id, v_actor_id, 'removal_completed', 'reader',
       'active', 'removed',
       'Membership reader cloturé suite à promotion librarian',
       jsonb_build_object('superseded_by', 'librarian',
                          'librarian_membership_id', v_membership_id));
  END IF;

  -- 7. Audit log de la promotion
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_librarian', 'librarian',
     v_status_before, 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

  -- 7.bis Logging cross-library transverse (paquet D.3)
  PERFORM public.fn_log_cross_library_action(
    p_library_id        := p_library_id,
    p_action_type       := 'team_promote_to_librarian',
    p_is_critical       := public.fn_is_critical_action_type('team_promote_to_librarian'),
    p_target_entity_type := 'user_library_membership',
    p_target_entity_id  := v_membership_id,
    p_payload           := jsonb_build_object(
      'target_user_id', p_user_id,
      'status_before', v_status_before,
      'status_after', 'active',
      'audit_id', v_audit_id
    )
  );

  -- 8. Notification mail
  PERFORM public.fn_team_notify_event(
    'team.promoted_to_librarian',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'promoted_to_librarian',
    'audit_id', v_audit_id
  );
END;
$$;

COMMENT ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid) IS NULL;

COMMIT;
