-- ============================================================================
-- Paquet F.3 - Refacto 3 fonctions Type C politiques + suppression branche A
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Ref.  : docs/spec-administrateur-reseau.md v0.3
--
-- Contexte
-- --------
-- Dernier sous-paquet du chantier admin reseau v0.3. Refacto des 3 fonctions
-- qui contenaient encore de la logique politique liee a 'administrador' :
--
--   1. fn_team_request_remove_member : suppression du garde-fou §6.9
--      ("pas de retrait d'un administrador") devenu mort code apres F.1.
--   2. fn_team_self_demote           : suppression de toute la BRANCHE A
--      (logique "last admin lockdown" avec phrase rituelle JE FERME LA
--      GOUVERNANCE ANARBIB) + variables associees + signature
--      p_confirm_close_governance conservee pour retrocompat (param ignore).
--   3. fn_team_suspend_member        : suppression du garde-fou §6.9
--      ("pas de suspension d'un administrador") devenu mort code.
--
-- Doctrine v0.3
-- -------------
-- Le role local 'administrador' a ete supprime en F.1. Le retrait des admins
-- reseau passe maintenant par les RPC fn_network_admin_*. Les gardes-fous
-- speciaux pour proteger les administrador dans les RPC team_* deviennent
-- obsoletes.
--
-- Pour fn_team_self_demote : la branche A geait l'auto-retrait du dernier
-- admin local avec une phrase rituelle. Cette logique n'a plus d'objet
-- (plus aucun user ne peut etre administrador local). La branche B
-- (logique pre-B2 preservee pour staff librarian/coordenador) reste
-- entierement intacte. Le parametre p_confirm_close_governance est garde
-- avec DEFAULT NULL pour retrocompatibilite frontend (le wrapper React
-- quitAdminFunctions sera supprime en F.3 frontend).
--
-- Effet en prod
-- -------------
-- - Plus aucune logique residuelle d'administrador local en DB.
-- - Les wrappers React quitAdminFunctions/promoteToAdministrador deviennent
--   inutiles (cf F.3 frontend, meme commit).
-- ============================================================================

BEGIN;

-- ============================================================================
-- fn_team_request_remove_member : suppression garde-fou §5 (administrador)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_request_remove_member(
    p_user_id uuid,
    p_library_id uuid,
    p_role text,
    p_reason text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_audit_id uuid;
  v_pending_until timestamptz;
  v_remaining_coords int;
  v_warning text := NULL;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Autorisation : coordenador+ de la biblio cible (depuis D.2, inclut admin reseau)
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can request removal';
  END IF;

  -- 3. Validation du role cible
  IF p_role NOT IN ('librarian', 'coordenador') THEN
    RAISE EXCEPTION 'invalid_argument: p_role must be librarian or coordenador';
  END IF;

  -- 4. Garde-fou §6.7 : pas de retrait de soi-meme
  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'forbidden: cannot request own removal (use fn_team_self_demote instead)';
  END IF;

  -- 5. F.3 v0.3 : SUPPRESSION garde-fou §6.9 ancien "pas de retrait d'un administrador"
  --    Devenu mort code apres F.1 (role 'administrador' supprime du schema).
  --    Le retrait d'un admin reseau passe par fn_network_admin_propose_collective_removal.

  -- 6. Recuperer la membership cible
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: no membership for this user/library/role combination';
  END IF;

  -- 7. Garde-fou §6.6 cas 1 : si deja suspended, refuser
  IF v_existing.status = 'suspended' THEN
    RAISE EXCEPTION 'precondition_failed: cannot request removal of suspended member; unsuspend first (cf. spec §6.6 cas 1)';
  END IF;

  -- 8. Idempotence : si deja pending_removal, ne rien faire
  IF v_existing.status = 'pending_removal' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'no_change', true,
      'reason', 'already_pending_removal',
      'pending_removal_until', v_existing.pending_removal_until,
      'action', 'removal_requested'
    );
  END IF;

  -- 9. Precondition : la membership doit etre active
  IF v_existing.status <> 'active' THEN
    RAISE EXCEPTION 'precondition_failed: only active memberships can be marked for removal (current status: %)', v_existing.status;
  END IF;

  -- 10. Calcul de la date de fin de carence : 7 jours fixes
  v_pending_until := now() + interval '7 days';

  -- 11. UPDATE de la membership
  UPDATE public.user_library_memberships
  SET status = 'pending_removal',
      pending_removal_until = v_pending_until,
      pending_removal_requested_by = v_actor_id,
      updated_at = now()
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  -- 12. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'removal_requested', p_role,
     'active', 'pending_removal', p_reason,
     jsonb_build_object('pending_removal_until', v_pending_until))
  RETURNING id INTO v_audit_id;

  -- 12.bis (paquet D.3) : logging cross-library transverse
  PERFORM public.fn_log_cross_library_action(
    p_library_id        := p_library_id,
    p_action_type       := 'team_request_remove_member',
    p_is_critical       := public.fn_is_critical_action_type('team_request_remove_member'),
    p_target_entity_type := 'user_library_membership',
    p_target_entity_id  := v_existing.id,
    p_payload           := jsonb_build_object(
      'target_user_id', p_user_id,
      'role', p_role,
      'reason', p_reason,
      'pending_removal_until', v_pending_until,
      'audit_id', v_audit_id
    )
  );

  -- 13. Detection §6.1 : si on demande le retrait du dernier coord, signaler
  IF p_role = 'coordenador' THEN
    SELECT count(*) INTO v_remaining_coords
    FROM public.user_library_memberships
    WHERE library_id = p_library_id
      AND role = 'coordenador'
      AND status = 'active';

    IF v_remaining_coords = 0 THEN
      v_warning := 'last_coordinator_pending_removal';
      PERFORM public.fn_team_notify_event(
        'team.last_coordinator_pending_removal',
        jsonb_build_object(
          'library_id', p_library_id,
          'target_user_id', p_user_id,
          'actor_user_id', v_actor_id,
          'pending_removal_until', v_pending_until,
          'audit_id', v_audit_id
        )
      );
    END IF;
  END IF;

  -- 14. Notification mail standard
  PERFORM public.fn_team_notify_event(
    'team.removal_requested',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'role', p_role,
      'reason', p_reason,
      'pending_removal_until', v_pending_until,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'removal_requested',
    'role', p_role,
    'pending_removal_until', v_pending_until,
    'audit_id', v_audit_id,
    'warning', v_warning
  );
END;
$function$;

-- ============================================================================
-- fn_team_self_demote : suppression BRANCHE A complete (last admin lockdown)
-- ============================================================================
-- Le parametre p_confirm_close_governance est conserve avec DEFAULT NULL
-- pour retrocompatibilite frontend. Il est desormais ignore.

CREATE OR REPLACE FUNCTION public.fn_team_self_demote(
    p_library_id uuid,
    p_target_role text DEFAULT 'librarian'::text,
    p_confirm_close_governance text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id           uuid := auth.uid();
  v_higher_role        text;
  v_higher_existing    record;
  v_target_existing    record;
  v_audit_id           uuid;
  v_remaining_coords   int;
  v_warning            text := NULL;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Validation du role cible
  IF p_target_role NOT IN ('librarian', 'reader') THEN
    RAISE EXCEPTION 'invalid_argument: p_target_role must be librarian or reader';
  END IF;

  -- 3. F.3 v0.3 : SUPPRESSION BRANCHE A complete (auto-retrait du dernier
  --    administrador local avec phrase rituelle JE FERME LA GOUVERNANCE
  --    ANARBIB). Devenu mort code apres F.1.
  --    Pour l'auto-retrait d'un admin reseau, utiliser
  --    fn_network_admin_self_remove_unilateral (RPC dediee).
  --    Le parametre p_confirm_close_governance est conserve (DEFAULT NULL)
  --    pour retrocompatibilite avec le frontend, mais ignore.

  -- BRANCHE B uniquement : logique pre-B2 preservee, staff librarian/coordenador

  -- B.1 - Identifier le role superieur actuellement actif a desactiver
  IF p_target_role = 'librarian' THEN
    v_higher_role := 'coordenador';
  ELSE
    v_higher_role := 'librarian';
  END IF;

  -- B.2 - Verifier que l'acteur a bien une membership active dans le role superieur
  SELECT * INTO v_higher_existing
  FROM public.user_library_memberships
  WHERE user_id = v_actor_id
    AND library_id = p_library_id
    AND role = v_higher_role
    AND status = 'active';

  IF NOT FOUND THEN
    -- Cas particulier reader : on cherche aussi coordenador
    IF p_target_role = 'reader' THEN
      SELECT * INTO v_higher_existing
      FROM public.user_library_memberships
      WHERE user_id = v_actor_id
        AND library_id = p_library_id
        AND role = 'coordenador'
        AND status = 'active';
      IF FOUND THEN
        v_higher_role := 'coordenador';
      ELSE
        RAISE EXCEPTION 'precondition_failed: no active staff membership to demote from';
      END IF;
    ELSE
      RAISE EXCEPTION 'precondition_failed: no active % membership to demote from', v_higher_role;
    END IF;
  END IF;

  -- B.3 - Desactiver la membership superieure
  UPDATE public.user_library_memberships
  SET status = 'inactive',
      pending_removal_until = NULL,
      pending_removal_requested_by = NULL,
      updated_at = now()
  WHERE user_id = v_actor_id
    AND library_id = p_library_id
    AND role = v_higher_role;

  -- B.4 - Activer / creer la membership cible
  SELECT * INTO v_target_existing
  FROM public.user_library_memberships
  WHERE user_id = v_actor_id
    AND library_id = p_library_id
    AND role = p_target_role;

  IF FOUND THEN
    UPDATE public.user_library_memberships
    SET status = 'active',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now()
    WHERE user_id = v_actor_id
      AND library_id = p_library_id
      AND role = p_target_role;
  ELSE
    INSERT INTO public.user_library_memberships
      (user_id, library_id, role, status)
    VALUES
      (v_actor_id, p_library_id, p_target_role, 'active');
  END IF;

  -- B.5 - Si on etait coordenador et qu'on se desactive vers reader, gerer aussi librarian
  IF p_target_role = 'reader' AND v_higher_role = 'coordenador' THEN
    UPDATE public.user_library_memberships
    SET status = 'inactive',
        updated_at = now()
    WHERE user_id = v_actor_id
      AND library_id = p_library_id
      AND role = 'librarian'
      AND status = 'active';
  END IF;

  -- B.6 - Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role,
     status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, v_actor_id, v_actor_id, 'self_demoted', v_higher_role,
     'active', 'inactive', NULL,
     jsonb_build_object('target_role', p_target_role))
  RETURNING id INTO v_audit_id;

  -- B.7 - Detection §6.1 : dernier coordenador qui se retrograde
  IF v_higher_role = 'coordenador' THEN
    SELECT count(*) INTO v_remaining_coords
    FROM public.user_library_memberships
    WHERE library_id = p_library_id
      AND role = 'coordenador'
      AND status = 'active';

    IF v_remaining_coords = 0 THEN
      v_warning := 'last_coordinator_left';
      PERFORM public.fn_team_notify_event(
        'team.last_coordinator_left',
        jsonb_build_object(
          'library_id', p_library_id,
          'actor_user_id', v_actor_id,
          'audit_id', v_audit_id,
          'trigger', 'self_demote'
        )
      );
    END IF;
  END IF;

  -- B.8 - Notification mail standard self-demote
  PERFORM public.fn_team_notify_event(
    'team.self_demoted',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', v_actor_id,
      'actor_user_id', v_actor_id,
      'from_role', v_higher_role,
      'to_role', p_target_role,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'self_demoted',
    'from_role', v_higher_role,
    'to_role', p_target_role,
    'audit_id', v_audit_id,
    'warning', v_warning
  );
END;
$function$;

-- ============================================================================
-- fn_team_suspend_member : suppression garde-fou §6 (administrador)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_suspend_member(
    p_user_id uuid,
    p_library_id uuid,
    p_role text,
    p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_audit_id uuid;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Autorisation : coordenador+ de la biblio cible (depuis D.2, inclut admin reseau)
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can suspend';
  END IF;

  -- 3. Validation du role cible
  IF p_role NOT IN ('librarian', 'coordenador') THEN
    RAISE EXCEPTION 'invalid_argument: p_role must be librarian or coordenador';
  END IF;

  -- 4. Garde-fou §6.7 : pas d'auto-suspension
  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'forbidden: cannot self-suspend';
  END IF;

  -- 5. Reason obligatoire (cf. spec §5.7 note : justification obligatoire)
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'invalid_argument: p_reason is mandatory for suspension (cf. spec §5.7)';
  END IF;

  -- 6. F.3 v0.3 : SUPPRESSION garde-fou §6.9 ancien "pas de suspension d'un administrador"
  --    Devenu mort code apres F.1 (role 'administrador' supprime du schema).

  -- 7. Recuperer la membership cible
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: no membership for this user/library/role combination';
  END IF;

  -- 8. Idempotence : si deja suspended, ne rien faire (mais accepter une nouvelle reason)
  IF v_existing.status = 'suspended' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'no_change', true,
      'reason', 'already_suspended',
      'action', 'suspended'
    );
  END IF;

  -- 9. Precondition : status doit etre active ou pending_removal
  IF v_existing.status NOT IN ('active', 'pending_removal') THEN
    RAISE EXCEPTION 'precondition_failed: cannot suspend membership in status % (only active or pending_removal)', v_existing.status;
  END IF;

  -- 10. UPDATE : passage a suspended
  UPDATE public.user_library_memberships
  SET status = 'suspended',
      updated_at = now()
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  -- 11. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'suspended', p_role,
     v_existing.status, 'suspended', p_reason, NULL)
  RETURNING id INTO v_audit_id;

  -- 11.bis (paquet D.3) : logging cross-library transverse
  PERFORM public.fn_log_cross_library_action(
    p_library_id        := p_library_id,
    p_action_type       := 'team_suspend_member',
    p_is_critical       := public.fn_is_critical_action_type('team_suspend_member'),
    p_target_entity_type := 'user_library_membership',
    p_target_entity_id  := v_existing.id,
    p_payload           := jsonb_build_object(
      'target_user_id', p_user_id,
      'role', p_role,
      'reason', p_reason,
      'status_before', v_existing.status,
      'status_after', 'suspended',
      'audit_id', v_audit_id
    )
  );

  -- 12. Notification mail
  PERFORM public.fn_team_notify_event(
    'team.suspended',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'role', p_role,
      'reason', p_reason,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'suspended',
    'role', p_role,
    'audit_id', v_audit_id
  );
END;
$function$;

COMMIT;
