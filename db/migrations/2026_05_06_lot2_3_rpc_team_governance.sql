-- ============================================================================
-- Lot 2 + 3 — RPCs de gouvernance des rôles dans AnarBib
-- ============================================================================
-- Date : 2026-05-06
-- Auteur : Xavier VAN WELDEN
-- Spec de référence : docs/spec-gouvernance-roles.md §11
-- Lot précédent : db/migrations/2026_05_05_lot1_governance_db_infrastructure.sql
-- ============================================================================
--
-- Ce fichier crée :
--   1. Le helper fn_team_notify_event (Option A : pg_net.http_post direct
--      vers notify-event Edge Function, secret lu depuis supabase_vault)
--   2. Les 2 RPCs de cooptation (Lot 2) :
--        - fn_team_promote_to_librarian
--        - fn_team_promote_to_coordenador
--   3. Les 5 RPCs de retraits/suspensions (Lot 3) :
--        - fn_team_self_demote
--        - fn_team_request_remove_member
--        - fn_team_cancel_remove_member
--        - fn_team_suspend_member
--        - fn_team_unsuspend_member
--
-- Conventions communes (cf. spec §11.1) :
--   - Préfixe fn_team_*
--   - LANGUAGE plpgsql SECURITY DEFINER
--   - SET search_path = public, pg_temp
--   - Vérifications d'autorisation explicites en début de fonction
--   - Retour jsonb structuré : {ok, action, no_change?, warnings?, errors?}
--   - Audit log dans library_membership_audit
--   - Notification mail via fn_team_notify_event
--   - GRANT EXECUTE à authenticated uniquement
--
-- Garde-fous transverses (cf. spec §6) :
--   - 6.2 : Auto-promotion impossible (vérifié par toutes les RPCs de promote)
--   - 6.3 : Pas de promotion vers administrador (aucune RPC ne le permet)
--   - 6.7 : Tentative de retrait de soi-même refusée (utiliser self_demote)
--   - 6.9 : Tentative de modifier un administrador refusée
--
-- Note d'implémentation pour fn_team_notify_event :
--   La spec §11.4 propose Option A (pg_net direct) ou Option B
--   (notification_outbox + cron). On retient l'Option A pour cette première
--   version : plus simple, suffisante pour la BLMF en mode test grandeur réelle.
--   Si une panne momentanée fait rater un mail, c'est visible dans les logs
--   Supabase et réémettable manuellement. La bascule vers Option B se fera
--   quand l'infrastructure notification_outbox sera implémentée (chantier
--   futur, hors session).
-- ============================================================================

-- ─── Section 0 : Garde-fou de pré-requis ────────────────────────────────────
-- Vérifie que les fonctions du Lot 1 et l'infrastructure du Lot 1 existent
-- avant de créer les RPCs qui en dépendent.

DO $$
BEGIN
  -- Vérif fonctions Lot 1
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'user_can_manage_library' AND pronamespace = 'public'::regnamespace) THEN
    RAISE EXCEPTION 'Pré-requis manquant : public.user_can_manage_library() doit exister (Lot 1)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'user_has_library_staff_role' AND pronamespace = 'public'::regnamespace) THEN
    RAISE EXCEPTION 'Pré-requis manquant : public.user_has_library_staff_role() doit exister (Lot 1)';
  END IF;
  -- Vérif table d'audit
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'library_membership_audit' AND relnamespace = 'public'::regnamespace) THEN
    RAISE EXCEPTION 'Pré-requis manquant : table public.library_membership_audit doit exister (Lot 1)';
  END IF;
  -- Vérif extension pg_net
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE EXCEPTION 'Pré-requis manquant : extension pg_net doit être installée';
  END IF;
  -- Vérif extension supabase_vault
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'supabase_vault') THEN
    RAISE EXCEPTION 'Pré-requis manquant : extension supabase_vault doit être installée';
  END IF;
  -- Vérif présence du secret webhook
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'webhook_secret_notify_event') THEN
    RAISE EXCEPTION 'Pré-requis manquant : vault.secrets.webhook_secret_notify_event doit être défini';
  END IF;
  RAISE NOTICE 'Tous les pré-requis Lot 1 + vault secret sont en place. Création des RPCs en cours.';
END $$;


-- ============================================================================
-- HELPER : fn_team_notify_event
-- ============================================================================
-- Centralise l'envoi des events team.* vers l'Edge Function notify-event.
-- Lit le secret webhook depuis supabase_vault et fait un pg_net.http_post.
--
-- Usage : SELECT public.fn_team_notify_event('team.promoted_to_librarian', payload);
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_notify_event(
  p_event text,
  p_payload jsonb
)
RETURNS bigint  -- request_id de pg_net (utile pour debug / monitoring)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_url text;
  v_secret text;
  v_request_id bigint;
  v_full_payload jsonb;
BEGIN
  -- URL de l'Edge Function notify-event
  v_url := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/notify-event';

  -- Lecture du secret depuis vault (déchiffrement à la volée)
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'webhook_secret_notify_event';

  IF v_secret IS NULL OR v_secret = '' THEN
    RAISE WARNING 'fn_team_notify_event: webhook_secret_notify_event vide ou introuvable dans vault. Notification non envoyée pour event=%', p_event;
    RETURN NULL;
  END IF;

  -- Construction du payload final (event + données)
  v_full_payload := jsonb_build_object(
    'event_type', p_event,
    'data', p_payload
  );

  -- Envoi du POST asynchrone via pg_net
  -- (la requête est mise en file ; le retour est le request_id, pas la réponse)
  SELECT net.http_post(
    url := v_url,
    body := v_full_payload,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-webhook-secret', v_secret
    )
  ) INTO v_request_id;

  RETURN v_request_id;

EXCEPTION
  WHEN OTHERS THEN
    -- Une erreur d'envoi de mail ne doit JAMAIS faire échouer la RPC métier.
    -- On logue juste l'erreur et on retourne NULL.
    RAISE WARNING 'fn_team_notify_event échec pour event=% : %', p_event, SQLERRM;
    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.fn_team_notify_event(text, jsonb) IS
  'Helper interne : envoie un event team.* vers notify-event Edge Function via pg_net.http_post. Secret lu depuis vault.secrets.webhook_secret_notify_event. Cf. spec-gouvernance-roles.md §11.4 (Option A).';

-- Pas de GRANT EXECUTE : cette fonction est interne, appelée uniquement par les RPCs fn_team_*.
REVOKE ALL ON FUNCTION public.fn_team_notify_event(text, jsonb) FROM PUBLIC;


-- ============================================================================
-- LOT 2.1 — fn_team_promote_to_librarian
-- ============================================================================
-- Cooptation reader → librarian (T1 dans la spec §5.2).
-- Référence : spec §5.2 + §11.3 (pattern type)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_librarian(
  p_user_id uuid,
  p_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_status_before text;
  v_audit_id uuid;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Autorisation : coordenador+ de la biblio cible (cf. spec §5.2)
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

  -- 5. Idempotence : si déjà librarian active, ne rien faire (cf. spec §6.8)
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

  v_status_before := v_existing.status;  -- NULL si pas de ligne existante

  -- 6. INSERT ou UPDATE (réactivation d'une membership inactive)
  INSERT INTO public.user_library_memberships
    (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
  VALUES
    (p_user_id, p_library_id, 'librarian', 'active', NULL, NULL)
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now();

  -- 7. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_librarian', 'librarian',
     v_status_before, 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

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

GRANT EXECUTE ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid) IS
  'Coopte un reader au rôle librarian dans une biblio. Réservé à coordenador+ de la biblio cible. Cf. spec-gouvernance-roles.md §5.2.';


-- ============================================================================
-- LOT 2.2 — fn_team_promote_to_coordenador
-- ============================================================================
-- Cooptation librarian → coordenador (T2 dans la spec §5.3).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_coordenador(
  p_user_id uuid,
  p_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_librarian_active boolean;
  v_status_before text;
  v_audit_id uuid;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Autorisation : coordenador+ de la biblio cible
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

  v_status_before := v_existing.status;  -- NULL si pas de ligne existante

  -- 7. INSERT ou UPDATE de la membership coordenador
  -- (la membership librarian est conservée intacte, multi-membership cf. spec §5.3)
  INSERT INTO public.user_library_memberships
    (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
  VALUES
    (p_user_id, p_library_id, 'coordenador', 'active', NULL, NULL)
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now();

  -- 8. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_coordenador', 'coordenador',
     v_status_before, 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

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

GRANT EXECUTE ON FUNCTION public.fn_team_promote_to_coordenador(uuid, uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_team_promote_to_coordenador(uuid, uuid) IS
  'Coopte un librarian actif au rôle coordenador dans une biblio. Réservé à coordenador+ de la biblio cible. Cf. spec-gouvernance-roles.md §5.3.';


-- ============================================================================
-- LOT 3.1 — fn_team_self_demote
-- ============================================================================
-- Auto-rétrogradation : la personne se rétrograde elle-même.
--   - coordenador → librarian (T3 spec §5.4)
--   - librarian → reader (T4 spec §5.5)
--
-- Multi-membership : la membership ciblée par p_target_role est activée
-- (créée si nécessaire), et la membership actuelle plus haute est inactivée.
--
-- Garde-fou §6.9 : un administrador ne peut pas utiliser cette RPC pour
-- se rétrograder. Cf. cadrage politique du 06/05/2026.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_self_demote(
  p_library_id uuid,
  p_target_role text DEFAULT 'librarian'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

  -- 8. Si on était coordenador et qu'on se désactive, gérer aussi librarian
  -- (cas T3 → reader : il faut aussi désactiver librarian s'il est actif)
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
  PERFORM public.fn_team_notify_event(
    'team.self_demoted',
    jsonb_build_object(
      'library_id', p_library_id,
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

GRANT EXECUTE ON FUNCTION public.fn_team_self_demote(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_team_self_demote(uuid, text) IS
  'Auto-rétrogradation : la personne se rétrograde elle-même (T3 ou T4). p_target_role = librarian ou reader. Cf. spec-gouvernance-roles.md §5.4 et §5.5. Garde-fou §6.9 : refusée pour administrador.';


-- ============================================================================
-- LOT 3.2 — fn_team_request_remove_member
-- ============================================================================
-- Demande de retrait d'un·e membre par un·e coord (T5 spec §5.6).
-- Met la membership en pending_removal avec carence 7j.
-- Garde-fou §6.7 : refus si la cible est l'acteur·rice (utiliser self_demote).
-- Garde-fou §6.6 cas 1 : refus si la membership est déjà suspended.
-- Garde-fou §6.9 : refus si la cible est administrador.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_request_remove_member(
  p_user_id uuid,
  p_library_id uuid,
  p_role text,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

  -- 2. Autorisation : coordenador+ de la biblio cible
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

  -- 7. Garde-fou §6.6 cas 1 : si déjà suspended, refuser (double étape volontaire)
  IF v_existing.status = 'suspended' THEN
    RAISE EXCEPTION 'precondition_failed: cannot request removal of suspended member; unsuspend first (cf. spec §6.6 cas 1)';
  END IF;

  -- 8. Idempotence : si déjà pending_removal, ne rien faire
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

  -- 10. Calcul de la date de fin de carence : 7 jours fixes (cf. spec §5.6, §6.6 cas 2)
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

  -- 13. Détection §6.1 : si on demande le retrait du dernier coord, signaler
  -- (la situation devient critique si l'annulation n'a pas lieu et qu'on
  -- atteint J+7 sans autre coord coopté entre-temps)
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

GRANT EXECUTE ON FUNCTION public.fn_team_request_remove_member(uuid, uuid, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_team_request_remove_member(uuid, uuid, text, text) IS
  'Demande le retrait d''un·e membre staff (librarian ou coordenador) via une carence de 7 jours. La cible passe à pending_removal. Le cron de complétion (cf. Lot 4) finalisera à J+7. Réservé à coordenador+. Cf. spec-gouvernance-roles.md §5.6.';


-- ============================================================================
-- LOT 3.3 — fn_team_cancel_remove_member
-- ============================================================================
-- Annulation d'une demande de retrait (T8 spec §5.9).
-- Tout coord+ peut annuler, y compris la cible elle-même (auto-protection
-- collégiale, cadrage du 06/05/2026).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_cancel_remove_member(
  p_user_id uuid,
  p_library_id uuid,
  p_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_audit_id uuid;
  v_actor_is_target boolean;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Validation du rôle cible
  IF p_role NOT IN ('librarian', 'coordenador') THEN
    RAISE EXCEPTION 'invalid_argument: p_role must be librarian or coordenador';
  END IF;

  -- 3. Autorisation : coordenador+ OU la cible elle-même
  v_actor_is_target := (v_actor_id = p_user_id);

  IF NOT v_actor_is_target AND NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ or the target themselves can cancel removal';
  END IF;

  -- 4. Récupérer la membership cible
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: no membership for this user/library/role combination';
  END IF;

  -- 5. Précondition : la membership doit être en pending_removal
  IF v_existing.status <> 'pending_removal' THEN
    RAISE EXCEPTION 'precondition_failed: membership is not in pending_removal (current status: %)', v_existing.status;
  END IF;

  -- 6. UPDATE : retour à active, nettoyage des champs pending_removal
  UPDATE public.user_library_memberships
  SET status = 'active',
      pending_removal_until = NULL,
      pending_removal_requested_by = NULL,
      updated_at = now()
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  -- 7. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'removal_cancelled', p_role,
     'pending_removal', 'active', NULL,
     jsonb_build_object(
       'cancelled_by_target', v_actor_is_target,
       'original_pending_until', v_existing.pending_removal_until,
       'original_requested_by', v_existing.pending_removal_requested_by
     ))
  RETURNING id INTO v_audit_id;

  -- 8. Notification mail
  PERFORM public.fn_team_notify_event(
    'team.removal_cancelled',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'role', p_role,
      'cancelled_by_target', v_actor_is_target,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'removal_cancelled',
    'role', p_role,
    'cancelled_by_target', v_actor_is_target,
    'audit_id', v_audit_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_team_cancel_remove_member(uuid, uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_team_cancel_remove_member(uuid, uuid, text) IS
  'Annule une demande de retrait en cours (pending_removal → active). Tout coordenador+ peut annuler, ainsi que la cible elle-même (auto-protection collégiale). Cf. spec-gouvernance-roles.md §5.9.';


-- ============================================================================
-- LOT 3.4 — fn_team_suspend_member
-- ============================================================================
-- Suspension immédiate (T6 spec §5.7).
-- Mesure conservatoire avec reason obligatoire. Pas de carence.
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
SET search_path = public, pg_temp
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

  -- 2. Autorisation : coordenador+ de la biblio cible
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
  IF v_existing.status = 'suspended' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'no_change', true,
      'reason', 'already_suspended',
      'action', 'suspended'
    );
  END IF;

  -- 9. Précondition : status doit être active ou pending_removal
  -- (si pending_removal, on suspend en parallèle ; le cron J+7 ne touchera
  -- pas une ligne suspended, à vérifier dans le Lot 4)
  IF v_existing.status NOT IN ('active', 'pending_removal') THEN
    RAISE EXCEPTION 'precondition_failed: cannot suspend membership in status % (only active or pending_removal)', v_existing.status;
  END IF;

  -- 10. UPDATE : passage à suspended (on conserve pending_removal_* si présents pour
  -- pouvoir restaurer en cas d'unsuspend ; cf. cas-limite §6.6)
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

GRANT EXECUTE ON FUNCTION public.fn_team_suspend_member(uuid, uuid, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_team_suspend_member(uuid, uuid, text, text) IS
  'Suspension immédiate d''un·e membre staff. Mesure conservatoire avec reason obligatoire. Réservé à coordenador+. Cf. spec-gouvernance-roles.md §5.7.';


-- ============================================================================
-- LOT 3.5 — fn_team_unsuspend_member
-- ============================================================================
-- Levée de suspension (T7 spec §5.8).
-- Tout coord+ peut lever (pas obligatoirement celui·celle qui a suspendu).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_team_unsuspend_member(
  p_user_id uuid,
  p_library_id uuid,
  p_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

  -- 2. Autorisation : coordenador+ de la biblio cible
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can unsuspend';
  END IF;

  -- 3. Validation du rôle cible
  IF p_role NOT IN ('librarian', 'coordenador') THEN
    RAISE EXCEPTION 'invalid_argument: p_role must be librarian or coordenador';
  END IF;

  -- 4. Récupérer la membership cible
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: no membership for this user/library/role combination';
  END IF;

  -- 5. Précondition : la membership doit être suspended
  IF v_existing.status <> 'suspended' THEN
    RAISE EXCEPTION 'precondition_failed: membership is not suspended (current status: %)', v_existing.status;
  END IF;

  -- 6. UPDATE : retour à active
  -- Note : si pending_removal_until était posé avant la suspension, on le conserve.
  -- Si c'était NULL avant suspension, on le laisse à NULL.
  UPDATE public.user_library_memberships
  SET status = 'active',
      updated_at = now()
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = p_role;

  -- 7. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'unsuspended', p_role,
     'suspended', 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

  -- 8. Notification mail
  PERFORM public.fn_team_notify_event(
    'team.unsuspended',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'role', p_role,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'unsuspended',
    'role', p_role,
    'audit_id', v_audit_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_team_unsuspend_member(uuid, uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_team_unsuspend_member(uuid, uuid, text) IS
  'Lève une suspension (suspended → active). Tout coordenador+ peut lever, pas obligatoirement celui·celle qui a suspendu. Cf. spec-gouvernance-roles.md §5.8.';


-- ============================================================================
-- FIN DE LA MIGRATION LOT 2 + 3
-- ============================================================================
-- Récap des fonctions créées :
--   1. fn_team_notify_event (helper interne)
--   2. fn_team_promote_to_librarian (Lot 2.1, T1)
--   3. fn_team_promote_to_coordenador (Lot 2.2, T2)
--   4. fn_team_self_demote (Lot 3.1, T3 + T4)
--   5. fn_team_request_remove_member (Lot 3.2, T5)
--   6. fn_team_cancel_remove_member (Lot 3.3, T8)
--   7. fn_team_suspend_member (Lot 3.4, T6)
--   8. fn_team_unsuspend_member (Lot 3.5, T7)
--
-- Reste à faire (sessions futures) :
--   - Lot 4 : crons (cron_team_pending_removal_complete + cron_team_inactive_cleanup)
--   - Lot 5 : notifications mail (i18n × 6 locales, adaptation notify-event)
--   - Lot 6 : UI enrichissement onglet team
--   - Lot 7 : workflow d'invitation
-- ============================================================================


-- ============================================================================
-- POST-CRÉATION : RÉVOCATION DES PERMISSIONS ANON ET PUBLIC
-- ============================================================================
-- Sur Supabase, toute fonction nouvellement créée dans le schéma public
-- reçoit automatiquement un GRANT EXECUTE pour les rôles `anon` et `authenticated`.
-- Le simple GRANT EXECUTE ... TO authenticated dans les CREATE FUNCTION ci-dessus
-- AJOUTE le grant explicite mais ne RÉVOQUE PAS le grant anon automatique.
--
-- Ces REVOKE sont indispensables pour respecter la spec §11.1 :
-- "GRANT EXECUTE accordé à `authenticated` uniquement (pas à `anon`)"
--
-- Defense in depth : même si chaque RPC vérifie auth.uid() en début de fonction,
-- on bloque l'accès à anon au niveau permissions pour ne pas dépendre uniquement
-- de cette vérification interne.
-- ============================================================================

-- Révocation anon
REVOKE EXECUTE ON FUNCTION public.fn_team_cancel_remove_member(uuid, uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_coordenador(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_request_remove_member(uuid, uuid, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_self_demote(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_suspend_member(uuid, uuid, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_unsuspend_member(uuid, uuid, text) FROM anon;

-- Révocation PUBLIC (defense in depth supplémentaire)
REVOKE EXECUTE ON FUNCTION public.fn_team_cancel_remove_member(uuid, uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_coordenador(uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_team_request_remove_member(uuid, uuid, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_team_self_demote(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_team_suspend_member(uuid, uuid, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_team_unsuspend_member(uuid, uuid, text) FROM PUBLIC;

-- Et pour le helper interne fn_team_notify_event : double-check
-- (le REVOKE FROM PUBLIC initial dans la création n'avait pas suffi pour des
-- raisons identiques - voir §11.1 commentaire ci-dessus)
REVOKE EXECUTE ON FUNCTION public.fn_team_notify_event(text, jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_team_notify_event(text, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_notify_event(text, jsonb) FROM PUBLIC;


-- ============================================================================
-- POST-DÉCOUVERTE : DROP DU TRIGGER LEGACY sync_primary_membership_role
-- ============================================================================
-- Lors du test fonctionnel du Lot 2 (RPC fn_team_promote_to_librarian) en
-- prod le 06/05/2026, un bug bloquant a été détecté :
--
--   ERROR: 23505 duplicate key value violates unique constraint
--   "user_library_memberships_user_id_library_id_role_key"
--   CONTEXT: PL/pgSQL function sync_primary_membership_role_from_profile_flag()
--
-- Cause racine : un trigger legacy sync_primary_membership_role_from_profile_flag
-- sur public.profiles essayait de RENOMMER la membership "is_primary=true" du
-- user dès que profiles.is_librarian changeait. Cette logique mono-rôle est
-- incompatible avec le multi-membership prévu par la spec gouvernance §5.2
-- (cooptation reader → librarian = nouvelle membership librarian, pas
-- renommage de l'ancienne).
--
-- Solution adoptée :
--   - DROP du trigger trg_sync_primary_membership_role_from_profile_flag
--   - Conservation du trigger trg_sync_profile_is_librarian_from_memberships
--     (il alimente profiles.is_librarian utilisé par notify-internal-task)
--   - La fonction sync_primary_membership_role_from_profile_flag() reste
--     dans pg_proc comme code historique consultable
--
-- Vérifications préalables effectuées le 06/05/2026 :
--   - Aucune RLS policy n'utilise profiles.is_librarian
--   - Aucune fonction PL/pgSQL custom (autre que les sync_*) ne le modifie
--   - Aucun frontend ni Edge Function ne le modifie
--   - Une seule lecture côté EF : notify-internal-task (handlers/internal-task.ts:478)
--
-- Tests fonctionnels du 06/05/2026 (post-DROP) : 5 scénarios passés sur la BLMF
-- avec un compte de test, puis cleanup complet.
--
-- Référence : docs/decisions/REFACTOR_TRIGGERS_MEMBERSHIPS_2026-05-06.md
-- ============================================================================

-- Garde-fou : si le trigger n'existe pas (rejeu sur base déjà migrée), on ne plante pas
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'trg_sync_primary_membership_role_from_profile_flag'
      AND tgrelid = 'public.profiles'::regclass
  ) THEN
    DROP TRIGGER trg_sync_primary_membership_role_from_profile_flag ON public.profiles;
    RAISE NOTICE 'Trigger trg_sync_primary_membership_role_from_profile_flag supprimé.';
  ELSE
    RAISE NOTICE 'Trigger trg_sync_primary_membership_role_from_profile_flag déjà absent — rien à faire.';
  END IF;
END $$;
