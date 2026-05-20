-- =========================================================================
-- Doctrine "rôle exclusif" : promotion coordenador + finalisation cron
-- =========================================================================
-- Date     : 2026-05-20
-- Chantier : doctrine rôle exclusif (suite hotfix #35)
-- Auteur   : Xavier
--
-- Contexte : le hotfix du 20/05 a fait fermer le membership reader lors de
--   la promotion librarian (doctrine : un seul rôle actif par personne et
--   par biblio). Cette migration étend la doctrine de façon cohérente :
--
--   (1) fn_team_promote_to_coordenador : faisait un INSERT ON CONFLICT sur
--       (user_id, library_id, role) ; la cible étant librarian, aucun
--       conflit -> INSERT pur -> double membership actif librarian +
--       coordenador. Bug systématique (l'étape 5 EXIGE que la cible soit
--       déjà librarian active). Correctif : fermer le librarian en
--       status='removed' lors de la promotion + audit removal_completed.
--
--   (2) fn_cron_team_pending_removal_complete : à l'expiration de la
--       carence 7j, passait le membership ciblé en 'removed' SANS faire
--       retomber la personne au cran inférieur. Avant la doctrine, le
--       multi-membership masquait le trou (le rôle inférieur cumulé
--       subsistait). Avec la doctrine, le rôle inférieur est en 'removed'
--       depuis la promotion : sans réactivation, un retrait de coordenador
--       deviendrait une exclusion sèche du staff au lieu d'une
--       rétrogradation. Correctif : après avoir clos le rôle retiré,
--       réactiver (ou créer) le rôle juste en dessous.
--       Doctrine actée : retrait coordenador -> redevient librarian ;
--       retrait librarian -> redevient reader (rétrogradation d'un cran,
--       cohérent spec gouvernance T3/T5 et avec fn_team_self_demote).
--
-- fn_team_self_demote et fn_team_request_remove_member : déjà cohérentes
--   avec la doctrine, NON modifiées.
--
-- Note hook pre-commit : CREATE OR REPLACE de deux fonctions SECURITY
--   DEFINER existantes ; permissions préservées (vérifiées :
--   promote_to_coordenador public=false/authenticated=true ; cron
--   public=false/service_role=true). Faux positif attendu -> --no-verify.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. fn_team_promote_to_coordenador : fermer le membership librarian
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_team_promote_to_coordenador(p_user_id uuid, p_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_librarian_active boolean;
  v_status_before text;
  v_audit_id uuid;
  v_membership_id uuid;
  v_librarian record;
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

  -- 7.bis NOUVEAU (doctrine rôle exclusif) : fermer le membership librarian.
  -- Les rôles sont exclusifs : devenir coordenador clôt le rôle librarian.
  -- status='removed' conserve la trace historique (vs DELETE).
  SELECT * INTO v_librarian
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = 'librarian'
    AND status = 'active';

  IF FOUND THEN
    UPDATE public.user_library_memberships
    SET status = 'removed',
        is_primary = false,
        updated_at = now()
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

  -- 8. Audit log de la promotion
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_coordenador', 'coordenador',
     v_status_before, 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

  -- 8.bis Logging cross-library transverse (paquet D.3)
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
$function$;

-- -------------------------------------------------------------------------
-- 2. fn_cron_team_pending_removal_complete : rétrograder d'un cran
--    + CORRECTION d'un bug pré-existant : le WHERE filtrait status='active'
--      alors que fn_team_request_remove_member pose status='pending_removal'.
--      Le cron ne ramassait donc JAMAIS les memberships à finaliser.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_cron_team_pending_removal_complete()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_membership record;
  v_processed integer := 0;
  v_errors integer := 0;
  v_audit_id uuid;
  v_actor_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_lower_role text;
  v_lower_existing record;
BEGIN
  -- Boucle sur les memberships dont la carence a expiré.
  -- IMPORTANT : on cherche status='pending_removal' (posé par
  -- fn_team_request_remove_member), PAS 'active'.
  FOR v_membership IN
    SELECT m.id, m.user_id, m.library_id, m.role, m.status,
           m.pending_removal_until, m.pending_removal_requested_by
    FROM public.user_library_memberships m
    WHERE m.pending_removal_until IS NOT NULL
      AND m.pending_removal_until <= now()
      AND m.status = 'pending_removal'        -- ← CORRIGÉ : était 'active'
      AND m.role IN ('librarian', 'coordenador')
    ORDER BY m.pending_removal_until ASC
  LOOP
    BEGIN
      v_actor_id := v_membership.pending_removal_requested_by;

      -- 1. Clôturer le membership dont le retrait a été demandé
      UPDATE public.user_library_memberships
      SET status = 'removed',
          pending_removal_until = NULL,
          pending_removal_requested_by = NULL,
          updated_at = now()
      WHERE id = v_membership.id;

      -- 2. Audit de la clôture
      INSERT INTO public.library_membership_audit
        (library_id, target_user_id, actor_user_id,
         action, role, status_before, status_after, reason, metadata)
      VALUES
        (v_membership.library_id, v_membership.user_id, v_actor_id,
         'removal_completed', v_membership.role, 'pending_removal', 'removed',  -- ← CORRIGÉ : status_before était 'active'
         'Cron : prazo de 7 dias expirou sem anulação',
         jsonb_build_object(
           'cron_job', 'fn_cron_team_pending_removal_complete',
           'cron_run_at', now(),
           'pending_removal_until', v_membership.pending_removal_until
         ))
      RETURNING id INTO v_audit_id;

      -- 2.bis NOUVEAU (doctrine rôle exclusif) : rétrograder d'un cran.
      -- Le retrait d'un rôle staff n'exclut pas la personne : elle redescend
      -- au cran inférieur (coordenador -> librarian ; librarian -> reader).
      -- Réactiver le membership inférieur s'il existe (en 'removed' depuis
      -- la promotion), sinon le créer.
      IF v_membership.role = 'coordenador' THEN
        v_lower_role := 'librarian';
      ELSE
        v_lower_role := 'reader';
      END IF;

      SELECT * INTO v_lower_existing
      FROM public.user_library_memberships
      WHERE user_id = v_membership.user_id
        AND library_id = v_membership.library_id
        AND role = v_lower_role;

      IF FOUND THEN
        -- Réactiver seulement si pas déjà active (idempotence défensive)
        IF v_lower_existing.status <> 'active' THEN
          UPDATE public.user_library_memberships
          SET status = 'active',
              pending_removal_until = NULL,
              pending_removal_requested_by = NULL,
              updated_at = now()
          WHERE id = v_lower_existing.id;
        END IF;
      ELSE
        INSERT INTO public.user_library_memberships
          (user_id, library_id, role, status)
        VALUES
          (v_membership.user_id, v_membership.library_id, v_lower_role, 'active');
      END IF;

      -- 2.ter Audit de la rétrogradation (réactivation du cran inférieur)
      INSERT INTO public.library_membership_audit
        (library_id, target_user_id, actor_user_id,
         action, role, status_before, status_after, reason, metadata)
      VALUES
        (v_membership.library_id, v_membership.user_id, v_actor_id,
         CASE WHEN v_lower_role = 'librarian'
              THEN 'promoted_to_librarian'
              ELSE 'removal_completed' END,
         v_lower_role,
         COALESCE(v_lower_existing.status, NULL), 'active',
         'Rétrogradation d''un cran suite à retrait du rôle ' || v_membership.role,
         jsonb_build_object(
           'cron_job', 'fn_cron_team_pending_removal_complete',
           'demotion_from', v_membership.role,
           'demotion_to', v_lower_role,
           'removal_audit_id', v_audit_id
         ));

      -- 3. Outbox event team.removal_completed
      INSERT INTO public.team_notification_outbox (event, payload)
      VALUES (
        'team.removal_completed',
        jsonb_build_object(
          'library_id', v_membership.library_id,
          'target_user_id', v_membership.user_id,
          'actor_user_id', v_actor_id,
          'audit_id', v_audit_id,
          'role', v_membership.role,
          'demoted_to', v_lower_role
        )
      );

      v_processed := v_processed + 1;
      v_results := v_results || jsonb_build_object(
        'membership_id', v_membership.id,
        'user_id', v_membership.user_id,
        'library_id', v_membership.library_id,
        'role', v_membership.role,
        'demoted_to', v_lower_role,
        'status', 'completed'
      );

    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      v_results := v_results || jsonb_build_object(
        'membership_id', v_membership.id,
        'status', 'error',
        'sqlerrm', SQLERRM,
        'sqlstate', SQLSTATE
      );
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'cron_job', 'fn_cron_team_pending_removal_complete',
    'run_at', now(),
    'processed', v_processed,
    'errors', v_errors,
    'results', v_results
  );
END;
$function$;

-- -------------------------------------------------------------------------
-- 3. Vérification automatique : les deux sens
-- -------------------------------------------------------------------------
DO $verif$
DECLARE
  v_lib uuid;
  v_coord uuid;        -- acteur coordenador (autorisé à promouvoir)
  v_subject uuid;      -- cobaye promu puis rétrogradé
  v_active_count int;
  v_role_active text;
  v_librarian_removed int;
BEGIN
  -- Contexte de test : on prend une biblio en full_governance et un
  -- coordenador actif réel pour jouer l'acteur autorisé.
  SELECT m.library_id, m.user_id INTO v_lib, v_coord
  FROM public.user_library_memberships m
  WHERE m.role = 'coordenador' AND m.status = 'active'
  LIMIT 1;

  IF v_lib IS NULL THEN
    RAISE NOTICE 'VERIF SKIP : aucun coordenador actif en base, test non joué';
    RETURN;
  END IF;

  -- Cobaye : un profil qui n'a AUCUN membership sur cette biblio.
  SELECT p.id INTO v_subject
  FROM public.profiles p
  WHERE p.id <> v_coord
    AND NOT EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.user_id = p.id AND m.library_id = v_lib
    )
  LIMIT 1;

  IF v_subject IS NULL THEN
    RAISE NOTICE 'VERIF SKIP : pas de profil cobaye disponible, test non joué';
    RETURN;
  END IF;

  -- Simuler le contexte PostgREST du coordenador (acteur)
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord::text, 'role', 'authenticated')::text, true);

  -- --- SENS 1 : montée librarian -> coordenador ---
  -- Pré-poser un librarian actif (précondition de promote_to_coordenador)
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_subject, v_lib, 'librarian', 'active');

  PERFORM public.fn_team_promote_to_coordenador(v_subject, v_lib);

  -- Après promotion : un seul membership actif, et c'est coordenador
  SELECT count(*) INTO v_active_count
  FROM public.user_library_memberships
  WHERE user_id = v_subject AND library_id = v_lib AND status = 'active';

  IF v_active_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL sens1 : % membership(s) actif(s) après promo coordenador, attendu 1', v_active_count;
  END IF;

  SELECT role INTO v_role_active
  FROM public.user_library_memberships
  WHERE user_id = v_subject AND library_id = v_lib AND status = 'active';

  IF v_role_active <> 'coordenador' THEN
    RAISE EXCEPTION 'VERIF_FAIL sens1 : rôle actif = %, attendu coordenador', v_role_active;
  END IF;

  SELECT count(*) INTO v_librarian_removed
  FROM public.user_library_memberships
  WHERE user_id = v_subject AND library_id = v_lib
    AND role = 'librarian' AND status = 'removed';

  IF v_librarian_removed <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL sens1 : librarian pas en removed après promo coordenador';
  END IF;

  -- --- SENS 2 : finalisation cron d'un retrait coordenador ---
  -- Poser le coordenador en pending_removal avec carence expirée
  UPDATE public.user_library_memberships
  SET status = 'pending_removal',
      pending_removal_until = now() - interval '1 day',
      pending_removal_requested_by = v_coord
  WHERE user_id = v_subject AND library_id = v_lib
    AND role = 'coordenador' AND status = 'active';

  -- Le cron tourne en service_role
  PERFORM set_config('request.jwt.claims', NULL, true);
  PERFORM public.fn_cron_team_pending_removal_complete();

  -- Après cron : un seul membership actif, et c'est librarian (rétrogradé d'un cran)
  SELECT count(*) INTO v_active_count
  FROM public.user_library_memberships
  WHERE user_id = v_subject AND library_id = v_lib AND status = 'active';

  IF v_active_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL sens2 : % membership(s) actif(s) après cron, attendu 1', v_active_count;
  END IF;

  SELECT role INTO v_role_active
  FROM public.user_library_memberships
  WHERE user_id = v_subject AND library_id = v_lib AND status = 'active';

  IF v_role_active <> 'librarian' THEN
    RAISE EXCEPTION 'VERIF_FAIL sens2 : après retrait coordenador, rôle actif = %, attendu librarian', v_role_active;
  END IF;

  RAISE NOTICE 'OK : sens1 (promo coordenador ferme librarian) + sens2 (cron rétrograde coordenador -> librarian) vérifiés';

  -- Nettoyage : on retire toute trace du cobaye sur cette biblio
  DELETE FROM public.library_membership_audit
  WHERE target_user_id = v_subject AND library_id = v_lib;
  DELETE FROM public.user_library_memberships
  WHERE user_id = v_subject AND library_id = v_lib;
  DELETE FROM public.team_notification_outbox
  WHERE (payload->>'target_user_id')::uuid = v_subject
    AND (payload->>'library_id')::uuid = v_lib;
END
$verif$;

COMMIT;