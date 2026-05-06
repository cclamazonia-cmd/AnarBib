-- ============================================================================
-- Lot 5 — Phase 1bis : Alignement de fn_team_self_demote sur le format
-- canonique du payload pour fn_team_notify_event
-- ============================================================================
-- Date : 2026-05-06
-- Auteur : Xavier VAN WELDEN
-- Spec : docs/spec-gouvernance-roles.md §11.4
-- ============================================================================
--
-- Contexte du patch :
--   La RPC fn_team_self_demote (créée dans 2026_05_06_lot2_3_rpc_team_governance.sql)
--   émet 2 events team.* :
--     - team.self_demoted (notification de la personne qui s'est rétrogradée)
--     - team.last_coordinator_left (escalade aux administrateur·rices AnarBib)
--
--   L'audit du 06/05/2026 préparant le handler domain/team.ts a révélé que
--   le payload de team.self_demoted ne contenait PAS le champ target_user_id,
--   alors que le format canonique du payload (cf. spec §11.4 et architecture
--   commune avec les autres events team.*) le requiert.
--
--   Pour l'auto-rétrogradation, la cible EST l'acteur·rice. Le handler aurait
--   pu inférer cela (target_user_id = actor_user_id si absent), mais il est
--   plus propre de respecter le format canonique strict.
--
--   Cas non corrigé : team.last_coordinator_left N'envoie PAS target_user_id,
--   et c'est correct architecturalement : pour les escalades AnarBib, la cible
--   est la liste des administrateur·rices, résolue côté handler.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_self_demote(
  p_library_id uuid,
  p_target_role text DEFAULT 'librarian'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_higher_role text;
  v_higher_existing record;
  v_target_existing record;
  v_audit_id uuid;
  v_remaining_coords int;
  v_warning text := NULL;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Validation du rôle cible
  IF p_target_role NOT IN ('librarian', 'reader') THEN
    RAISE EXCEPTION 'invalid_argument: p_target_role must be librarian or reader';
  END IF;

  -- 3. Garde-fou §6.9 : un administrador ne peut pas utiliser cette RPC
  -- (la rotation administrador est hors-spec, §13)
  IF EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = v_actor_id
      AND role = 'administrador'
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'forbidden: administrador cannot self-demote via this RPC (cf. spec §6.9, §13)';
  END IF;

  -- 4. Identifier le rôle "supérieur" actuellement actif à désactiver
  -- Si target = librarian → désactiver coordenador
  -- Si target = reader → désactiver librarian (ET coordenador si présent)
  IF p_target_role = 'librarian' THEN
    v_higher_role := 'coordenador';
  ELSE  -- p_target_role = 'reader'
    v_higher_role := 'librarian';
  END IF;

  -- 5. Vérifier que l'acteur·rice a bien une membership active dans le rôle supérieur
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

  -- 6. Désactiver la membership supérieure
  UPDATE public.user_library_memberships
  SET status = 'inactive',
      pending_removal_until = NULL,
      pending_removal_requested_by = NULL,
      updated_at = now()
  WHERE user_id = v_actor_id
    AND library_id = p_library_id
    AND role = v_higher_role;

  -- 7. Activer / créer la membership cible
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

  -- 8. Si on était coordenador et qu'on se désactive vers reader, gérer aussi librarian
  IF p_target_role = 'reader' AND v_higher_role = 'coordenador' THEN
    UPDATE public.user_library_memberships
    SET status = 'inactive',
        updated_at = now()
    WHERE user_id = v_actor_id
      AND library_id = p_library_id
      AND role = 'librarian'
      AND status = 'active';
  END IF;

  -- 9. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, v_actor_id, v_actor_id, 'self_demoted', v_higher_role,
     'active', 'inactive', NULL,
     jsonb_build_object('target_role', p_target_role))
  RETURNING id INTO v_audit_id;

  -- 10. Détection §6.1 : dernier coordenador qui se rétrograde
  IF v_higher_role = 'coordenador' THEN
    SELECT count(*) INTO v_remaining_coords
    FROM public.user_library_memberships
    WHERE library_id = p_library_id
      AND role = 'coordenador'
      AND status = 'active';

    IF v_remaining_coords = 0 THEN
      v_warning := 'last_coordinator_left';
      -- Escalade aux administradores AnarBib
      -- target_user_id absent volontairement : la cible est la liste des admins,
      -- résolue côté handler domain/team.ts (cf. spec §11.4)
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

  -- 11. Notification mail standard self-demote
  -- AJOUT 06/05/2026 : target_user_id := v_actor_id pour cohérence avec le
  -- format canonique du payload (la cible IS l'acteur·rice pour une auto-rétrogradation).
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

-- Vérification post-création
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'fn_team_self_demote'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'Échec : fn_team_self_demote manquante après CREATE OR REPLACE';
  END IF;

  RAISE NOTICE 'Phase 1bis appliquée : fn_team_self_demote alignée sur le format canonique.';
END $$;
