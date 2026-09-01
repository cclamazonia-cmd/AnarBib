-- =====================================================================
-- ROLLBACK de 20260901220000_statut_vacated_role_quitte.sql
--
-- Reconvertit `vacated` en `inactive`, restaure `fn_team_self_demote` dans
-- son état du socle, et referme le CHECK sur le vocabulaire d'avant.
--
-- ATTENTION : reconvertir REPERD l'information. Les rôles quittés
-- volontairement redeviennent indiscernables des comptes délaissés, et
-- l'écran d'équipe recommencera à annoncer « sans connexion depuis plus de
-- 270 jours » sur des gens qui ont simplement passé la main. C'est le
-- comportement d'avant le 01/09/2026, restauré tel quel.
-- =====================================================================

BEGIN;

UPDATE public.user_library_memberships
   SET status = 'inactive', updated_at = now()
 WHERE status = 'vacated';

CREATE OR REPLACE FUNCTION "public"."fn_team_self_demote"("p_library_id" "uuid", "p_target_role" "text" DEFAULT 'librarian'::"text", "p_confirm_close_governance" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
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
$$;


ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT IF EXISTS user_library_memberships_status_check;

ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_status_check
  CHECK (status = ANY (ARRAY[
    'active'::text, 'inactive'::text, 'pending_removal'::text, 'removed'::text,
    'suspended'::text, 'left_with_pending_circulation'::text, 'terminated'::text,
    'pending_validation'::text, 'refused'::text
  ]));

COMMIT;
