-- ============================================================================
-- 20260511180000_paquetD3_team_rpcs_logging.sql
-- ============================================================================
-- Paquet D.3 — Ajout du logging cross-library dans les 4 RPC team
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3 + §6.3.1
--
-- Refacto chirurgical : on ajoute UN seul bloc `PERFORM fn_log_cross_library_action(...)`
-- dans chaque RPC, placé après l'INSERT dans library_membership_audit (qui
-- a déjà créé v_audit_id) et avant la notification fn_team_notify_event.
--
-- Aucun autre changement de logique métier. Toutes les validations, garde-fous,
-- préconditions, idempotences, audits internes et notifications sont préservés
-- EXACTEMENT à l'identique.
--
-- 4 RPC réécrites complètement en CREATE OR REPLACE FUNCTION pour clarté :
--   - fn_team_suspend_member         → action_type='team_suspend_member', is_critical=true
--   - fn_team_request_remove_member  → action_type='team_request_remove_member', is_critical=true
--   - fn_team_promote_to_librarian   → action_type='team_promote_to_librarian', is_critical=false
--   - fn_team_promote_to_coordenador → action_type='team_promote_to_coordenador', is_critical=true
--
-- La valeur de is_critical est calculée dynamiquement via fn_is_critical_action_type
-- (paquet D.1) pour centraliser la liste limitative et éviter la duplication.
--
-- Logique fn_log_cross_library_action (paquet C.5b) :
--   - NOOP silencieux si l'appelant n'est pas admin réseau actif
--   - NOOP silencieux si l'appelant est admin réseau MAIS aussi staff local
--     de la biblio cible (action légitimement locale, pas transverse)
--   - INSERT dans network_admin_cross_library_actions_log sinon
--   - Si is_critical=true, le trigger AFTER INSERT (paquet C.5c) déclenche
--     un event 'network.cross_library_critical_action' dans team_notification_outbox
--     pour notification immédiate au staff local de la biblio
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : fn_team_suspend_member
-- ============================================================================
-- Ajout du logging entre étape 11 (audit log) et étape 12 (notification mail).
-- action_type = 'team_suspend_member', is_critical = true (whitelist D.1).

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
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_audit_id uuid;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Autorisation : coordenador+ de la biblio cible (depuis D.2, inclut admin réseau)
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can suspend';
  END IF;

  -- 3. Validation du rôle cible
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

  -- 6. Garde-fou §6.9 : pas de suspension d'un administrador
  IF EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = p_user_id
      AND role = 'administrador'
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'forbidden: cannot suspend administrador via this RPC (cf. spec §6.9, §13)';
  END IF;

  -- 7. Récupérer la membership cible
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: no membership for this user/library/role combination';
  END IF;

  -- 8. Idempotence : si déjà suspended, ne rien faire (mais accepter une nouvelle reason)
  -- NOTE: pas de logging transverse car aucune action effective
  IF v_existing.status = 'suspended' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'no_change', true,
      'reason', 'already_suspended',
      'action', 'suspended'
    );
  END IF;

  -- 9. Précondition : status doit être active ou pending_removal
  IF v_existing.status NOT IN ('active', 'pending_removal') THEN
    RAISE EXCEPTION 'precondition_failed: cannot suspend membership in status % (only active or pending_removal)', v_existing.status;
  END IF;

  -- 10. UPDATE : passage à suspended
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

  -- 11.bis NOUVEAU (paquet D.3) : logging cross-library transverse
  -- NOOP silencieux si l'appelant n'est pas en action transverse.
  -- Si is_critical=true (whitelist D.1), déclenche notif immédiate au staff local.
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
$$;

-- ============================================================================
-- SECTION 2 : fn_team_request_remove_member
-- ============================================================================
-- Ajout du logging entre étape 12 (audit log) et étape 13 (détection §6.1).
-- action_type = 'team_request_remove_member', is_critical = true.

CREATE OR REPLACE FUNCTION public.fn_team_request_remove_member(
    p_user_id uuid, 
    p_library_id uuid, 
    p_role text, 
    p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
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

  -- 2. Autorisation : coordenador+ de la biblio cible (depuis D.2, inclut admin réseau)
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can request removal';
  END IF;

  -- 3. Validation du rôle cible
  IF p_role NOT IN ('librarian', 'coordenador') THEN
    RAISE EXCEPTION 'invalid_argument: p_role must be librarian or coordenador';
  END IF;

  -- 4. Garde-fou §6.7 : pas de retrait de soi-même
  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'forbidden: cannot request own removal (use fn_team_self_demote instead)';
  END IF;

  -- 5. Garde-fou §6.9 : pas de retrait d'un administrador
  IF EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = p_user_id
      AND role = 'administrador'
      AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'forbidden: cannot remove administrador via this RPC (cf. spec §6.9, §13)';
  END IF;

  -- 6. Récupérer la membership cible
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: no membership for this user/library/role combination';
  END IF;

  -- 7. Garde-fou §6.6 cas 1 : si déjà suspended, refuser
  IF v_existing.status = 'suspended' THEN
    RAISE EXCEPTION 'precondition_failed: cannot request removal of suspended member; unsuspend first (cf. spec §6.6 cas 1)';
  END IF;

  -- 8. Idempotence : si déjà pending_removal, ne rien faire
  -- NOTE: pas de logging transverse car aucune action effective
  IF v_existing.status = 'pending_removal' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'no_change', true,
      'reason', 'already_pending_removal',
      'pending_removal_until', v_existing.pending_removal_until,
      'action', 'removal_requested'
    );
  END IF;

  -- 9. Précondition : la membership doit être active
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

  -- 12.bis NOUVEAU (paquet D.3) : logging cross-library transverse
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

  -- 13. Détection §6.1 : si on demande le retrait du dernier coord, signaler
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
$$;

-- ============================================================================
-- SECTION 3 : fn_team_promote_to_librarian
-- ============================================================================
-- Ajout du logging entre étape 7 (audit log) et étape 8 (notification mail).
-- action_type = 'team_promote_to_librarian', is_critical = FALSE (digest seulement).

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_librarian(
    p_user_id uuid, 
    p_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_status_before text;
  v_audit_id uuid;
  v_membership_id uuid;
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
  -- NOTE: pas de logging transverse car aucune action effective
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

  -- 7. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_librarian', 'librarian',
     v_status_before, 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

  -- 7.bis NOUVEAU (paquet D.3) : logging cross-library transverse
  -- is_critical=FALSE (non listé dans la whitelist D.1) → digest hebdo seulement
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

-- ============================================================================
-- SECTION 4 : fn_team_promote_to_coordenador
-- ============================================================================
-- Ajout du logging entre étape 8 (audit log) et étape 9 (notification mail).
-- action_type = 'team_promote_to_coordenador', is_critical = TRUE (rôle pivot).

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_coordenador(
    p_user_id uuid, 
    p_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_librarian_active boolean;
  v_status_before text;
  v_audit_id uuid;
  v_membership_id uuid;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Autorisation : coordenador+ de la biblio cible (depuis D.2, inclut admin réseau)
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can promote to coordenador';
  END IF;

  -- 3. Garde-fou : pas d'auto-promotion
  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'forbidden: cannot self-promote';
  END IF;

  -- 4. Vérification existence de la cible
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'not_found: target user does not exist';
  END IF;

  -- 5. Précondition spec §5.3 : la cible doit déjà avoir une membership librarian active
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = p_user_id
      AND library_id = p_library_id
      AND role = 'librarian'
      AND status = 'active'
  ) INTO v_librarian_active;

  IF NOT v_librarian_active THEN
    RAISE EXCEPTION 'precondition_failed: target must be active librarian first (use fn_team_promote_to_librarian)';
  END IF;

  -- 6. Idempotence : si déjà coordenador actif, ne rien faire
  -- NOTE: pas de logging transverse car aucune action effective
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = 'coordenador';

  IF FOUND AND v_existing.status = 'active' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'no_change', true,
      'reason', 'already_coordenador_active',
      'action', 'promoted_to_coordenador'
    );
  END IF;

  v_status_before := v_existing.status;

  -- 7. INSERT ou UPDATE de la membership coordenador
  INSERT INTO public.user_library_memberships
    (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
  VALUES
    (p_user_id, p_library_id, 'coordenador', 'active', NULL, NULL)
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now()
  RETURNING id INTO v_membership_id;

  -- 8. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_coordenador', 'coordenador',
     v_status_before, 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

  -- 8.bis NOUVEAU (paquet D.3) : logging cross-library transverse
  -- is_critical=TRUE (rôle pivot, déclenche notif immédiate au staff local)
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

  -- 9. Notification mail
  PERFORM public.fn_team_notify_event(
    'team.promoted_to_coordenador',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'promoted_to_coordenador',
    'audit_id', v_audit_id
  );
END;
$$;

-- ============================================================================
-- SECTION 5 : VALIDATIONS POST-REFACTO
-- ============================================================================

-- 5.1 Les 4 RPC sont présentes
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
          'fn_team_suspend_member',
          'fn_team_request_remove_member',
          'fn_team_promote_to_librarian',
          'fn_team_promote_to_coordenador'
      );
    
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'rpc_count_mismatch: % RPC trouvées (attendu : 4)', v_count;
    END IF;
    
    RAISE NOTICE 'rpc_count_ok: 4 RPC team présentes';
END;
$$;

-- 5.2 Les 4 RPC contiennent maintenant un appel à fn_log_cross_library_action
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
          'fn_team_suspend_member',
          'fn_team_request_remove_member',
          'fn_team_promote_to_librarian',
          'fn_team_promote_to_coordenador'
      )
      AND pg_get_functiondef(p.oid) LIKE '%fn_log_cross_library_action%';
    
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'logging_count_mismatch: % RPC appellent fn_log_cross_library_action (attendu : 4)', v_count;
    END IF;
    
    RAISE NOTICE 'logging_ok: 4 RPC team intègrent maintenant fn_log_cross_library_action';
END;
$$;

-- 5.3 Les 4 RPC utilisent fn_is_critical_action_type (pas de hardcoding)
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
          'fn_team_suspend_member',
          'fn_team_request_remove_member',
          'fn_team_promote_to_librarian',
          'fn_team_promote_to_coordenador'
      )
      AND pg_get_functiondef(p.oid) LIKE '%fn_is_critical_action_type%';
    
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'centralization_failed: % RPC utilisent fn_is_critical_action_type (attendu : 4, pas de hardcoding)', v_count;
    END IF;
    
    RAISE NOTICE 'centralization_ok: les 4 RPC utilisent le helper central fn_is_critical_action_type';
END;
$$;

-- 5.4 Helpers requis présents
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_log_cross_library_action'
    ) THEN
        RAISE EXCEPTION 'dependency_missing: fn_log_cross_library_action (paquet C.5b)';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_is_critical_action_type'
    ) THEN
        RAISE EXCEPTION 'dependency_missing: fn_is_critical_action_type (paquet D.1)';
    END IF;
    
    RAISE NOTICE 'dependencies_ok: fn_log_cross_library_action + fn_is_critical_action_type présents';
END;
$$;

-- 5.5 Sémantique préservée : les 4 RPC contiennent toujours fn_team_notify_event
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
          'fn_team_suspend_member',
          'fn_team_request_remove_member',
          'fn_team_promote_to_librarian',
          'fn_team_promote_to_coordenador'
      )
      AND pg_get_functiondef(p.oid) LIKE '%fn_team_notify_event%';
    
    IF v_count <> 4 THEN
        RAISE WARNING 'notifications_count_low: % RPC contiennent fn_team_notify_event (attendu : 4)', v_count;
    ELSE
        RAISE NOTICE 'notifications_preserved_ok: les 4 RPC conservent fn_team_notify_event (notifications mail locales intactes)';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- ATTENTION : la table network_admin_cross_library_actions_log est IMMUTABLE.
-- Tout test fonctionnel d'INSERT doit être fait avec BEGIN/ROLLBACK pour ne
-- pas polluer la table.
--
-- Test 1 : Xavier (admin réseau) suspend une membership BTL → trace dans le log
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    
--    -- Compter le log avant
--    SELECT count(*) AS log_before
--    FROM public.network_admin_cross_library_actions_log
--    WHERE action_type = 'team_suspend_member';
--    
--    -- (Faut une membership BTL active à suspendre — on simule par un INSERT pour le test)
--    -- ... ce test fonctionnel est délicat car il modifie de vraies memberships.
--    -- Plus simple : tester via l'UI avec un compte de test.
--    
--    ROLLBACK;
--
-- Test 2 : Patricia (coord BTL pur) suspend dans BTL → PAS de log transverse
--    Action légitimement locale, donc fn_log_cross_library_action retourne NULL.
--    L'audit interne library_membership_audit fonctionne quand même.
--
-- Test 3 : voir les définitions actualisées
--    SELECT proname, length(pg_get_functiondef(p.oid)) AS def_length
--    FROM pg_proc p
--    JOIN pg_namespace n ON n.oid = p.pronamespace
--    WHERE n.nspname = 'public'
--      AND p.proname IN (
--        'fn_team_suspend_member',
--        'fn_team_request_remove_member',
--        'fn_team_promote_to_librarian',
--        'fn_team_promote_to_coordenador'
--      );
--    Attendu : 4 lignes, chaque définition plus longue qu'avant D.3 (+15-20 lignes pour le bloc PERFORM).
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
