-- ═══════════════════════════════════════════════════════════════════════════
-- Migration : Phase B2 — Gouvernance des administradores
-- Date      : 07/05/2026 (suite Phase B1 avec hotfixes)
-- Auteur    : Xavier (assist Claude) — Phase B2 spec
-- ═══════════════════════════════════════════════════════════════════════════
--
-- CONTEXTE POLITIQUE
-- ------------------
-- Décision du 07/05/2026 (cf. session marathon) : la gouvernance d'admins
-- doit être gérable depuis l'UI pour permettre à la communauté de continuer
-- à fonctionner même sans dev compétent disponible.
--
-- Cas d'usage typique : Xavier, seul admin actuel, doit pouvoir promouvoir
-- d'autres admins après Bologna 09/2026 (1 technique + 1 politique). Dans
-- l'absolu, un admin doit aussi pouvoir partir si sa situation l'exige
-- (santé, projet abandonné, dissolution politique).
--
-- TROIS CHANGEMENTS DB
-- --------------------
--
-- 1. NOUVELLE RPC fn_team_promote_to_administrador(p_user_id, p_library_id)
--    Permet à un admin existant de promouvoir un staff existant en admin.
--    La cible doit déjà avoir au moins un membership staff (librarian/
--    coord/admin) actif quelque part dans le réseau (pas de promotion
--    ex-nihilo). Le membership admin créé est ancré sur la lib choisie
--    par l'admin promoteur (préfléchage côté UI sur les libs où la cible
--    est déjà staff, mais le choix est libre).
--
-- 2. MODIFICATION de fn_team_self_demote pour permettre admin → librarian
--    Lève le garde-fou §6.9 actuel (admin interdit) sous condition stricte :
--    refuser si l'acteur·rice est le DERNIER admin actif du réseau.
--    Le bypass est possible via un paramètre p_confirm_close_governance
--    qui exige une phrase de confirmation côté UI ('JE FERME LA
--    GOUVERNANCE ANARBIB'). La RPC valide la phrase exacte.
--
-- 3. EXTENSION de la contrainte CHECK sur library_membership_audit.action
--    Ajout de 'promoted_to_administrador' aux valeurs autorisées.
--
-- ROLLBACK
-- --------
-- DROP FUNCTION IF EXISTS public.fn_team_promote_to_administrador(uuid, uuid);
-- (la modification de fn_team_self_demote nécessite de réinstaller la
--  version pré-B2 — voir backup_phaseB1 dans /db/migrations/)
-- (la contrainte CHECK doit être recréée sans 'promoted_to_administrador')
--
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── 1. Étendre la contrainte CHECK sur library_membership_audit.action ──

ALTER TABLE public.library_membership_audit
  DROP CONSTRAINT IF EXISTS library_membership_audit_action_check;

ALTER TABLE public.library_membership_audit
  ADD CONSTRAINT library_membership_audit_action_check
  CHECK (action = ANY (ARRAY[
    'promoted_to_librarian'::text,
    'promoted_to_coordenador'::text,
    'promoted_to_administrador'::text,    -- NOUVEAU Phase B2
    'self_demoted'::text,
    'removal_requested'::text,
    'removal_cancelled'::text,
    'removal_completed'::text,
    'suspended'::text,
    'unsuspended'::text,
    'inactive_warning_30d'::text,
    'inactive_warning_7d'::text,
    'inactive_auto'::text
  ]));

-- ─── 2. fn_team_promote_to_administrador ─────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_administrador(
  p_user_id    uuid,
  p_library_id uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor_id          uuid := auth.uid();
  v_actor_is_admin    boolean;
  v_target_has_staff  boolean;
  v_existing          record;
  v_audit_id          uuid;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. L'acteur·rice doit être administrador actif (au moins une lib)
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = v_actor_id
      AND role = 'administrador'
      AND status = 'active'
  ) INTO v_actor_is_admin;

  IF NOT v_actor_is_admin THEN
    RAISE EXCEPTION 'forbidden: only administrador can promote to administrador';
  END IF;

  -- 3. La cible doit déjà avoir un membership staff actif quelque part
  --    dans le réseau (pas de création ex-nihilo)
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = p_user_id
      AND role IN ('librarian', 'coordenador', 'administrador')
      AND status = 'active'
  ) INTO v_target_has_staff;

  IF NOT v_target_has_staff THEN
    RAISE EXCEPTION 'precondition_failed: target has no active staff membership in the network';
  END IF;

  -- 4. Vérifier que la lib cible existe
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = p_library_id) THEN
    RAISE EXCEPTION 'not_found: library does not exist';
  END IF;

  -- 5. Si la cible est déjà admin actif sur cette lib : no-op (idempotent)
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = 'administrador';

  IF FOUND AND v_existing.status = 'active' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'action', 'noop',
      'reason', 'already_administrador_in_this_library'
    );
  END IF;

  -- 6. Activer ou créer le membership admin sur la lib indiquée
  IF FOUND THEN
    -- Existe en status non-active (inactive, removed, etc.) → réactiver
    UPDATE public.user_library_memberships
    SET status = 'active',
        is_restricted = false,
        restricted_reason = NULL,
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now()
    WHERE id = v_existing.id;
  ELSE
    -- N'existe pas → créer
    INSERT INTO public.user_library_memberships
      (user_id, library_id, role, status)
    VALUES
      (p_user_id, p_library_id, 'administrador', 'active');
  END IF;

  -- 7. Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role,
     status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_administrador',
     'administrador', COALESCE(v_existing.status, 'absent'), 'active', NULL,
     jsonb_build_object('note', 'Phase B2 — promotion administrador via UI'))
  RETURNING id INTO v_audit_id;

  -- 8. Notification mail (event team.promoted_to_administrador)
  PERFORM public.fn_team_notify_event(
    'team.promoted_to_administrador',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'promoted_to_administrador',
    'target_user_id', p_user_id,
    'library_id', p_library_id,
    'audit_id', v_audit_id
  );
END;
$$;

COMMENT ON FUNCTION public.fn_team_promote_to_administrador(uuid, uuid) IS
  'Phase B2 (07/05/2026) : permet à un administrador actif de promouvoir '
  'un user (ayant déjà un membership staff actif dans le réseau) au rôle '
  'administrador, ancré sur p_library_id. Le choix de la lib est libre côté '
  'admin promoteur, avec préfléchage UX sur les libs où la cible est déjà '
  'staff. Idempotent : si la cible est déjà admin sur cette lib, no-op.';

REVOKE ALL ON FUNCTION public.fn_team_promote_to_administrador(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_team_promote_to_administrador(uuid, uuid) TO authenticated;

-- ─── 3. Modification de fn_team_self_demote ──────────────────────────────
--
-- Changement : permettre admin → librarian/reader sous condition stricte.
-- Si on est dernier admin actif, exiger p_confirm_close_governance =
-- 'JE FERME LA GOUVERNANCE ANARBIB' (saisie exacte côté UI).
--
-- Nouvelle signature : on ajoute un 3ème paramètre optionnel
--   p_confirm_close_governance text DEFAULT NULL
--
-- Comportement :
--   - Admin avec d'autres admins actifs en place → demote autorisé sans confirm
--   - Admin dernier actif sans confirm → exception 'last_admin_lockdown'
--   - Admin dernier actif avec confirm correct → demote autorisé + warning
--   - Admin dernier actif avec confirm incorrect → exception 'invalid_confirm'

CREATE OR REPLACE FUNCTION public.fn_team_self_demote(
  p_library_id uuid,
  p_target_role text DEFAULT 'librarian',
  p_confirm_close_governance text DEFAULT NULL
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor_id           uuid := auth.uid();
  v_actor_is_admin     boolean;
  v_other_admins_count int;
  v_higher_role        text;
  v_higher_existing    record;
  v_target_existing    record;
  v_audit_id           uuid;
  v_remaining_coords   int;
  v_warning            text := NULL;
  v_confirm_phrase     constant text := 'JE FERME LA GOUVERNANCE ANARBIB';
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Validation du rôle cible
  IF p_target_role NOT IN ('librarian', 'reader') THEN
    RAISE EXCEPTION 'invalid_argument: p_target_role must be librarian or reader';
  END IF;

  -- 3. Détection : l'acteur·rice est-iel admin AnarBib ?
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = v_actor_id
      AND role = 'administrador'
      AND status = 'active'
  ) INTO v_actor_is_admin;

  -- ═══ BRANCHE A : acteur·rice EST administrador ═══════════════════════
  IF v_actor_is_admin THEN
    -- A.1 — Détecter si on est le dernier admin actif du réseau
    SELECT count(DISTINCT user_id) INTO v_other_admins_count
    FROM public.user_library_memberships
    WHERE role = 'administrador'
      AND status = 'active'
      AND user_id <> v_actor_id;

    -- A.2 — Si dernier admin et pas de confirm → bloquer
    IF v_other_admins_count = 0 THEN
      IF p_confirm_close_governance IS NULL
         OR p_confirm_close_governance <> v_confirm_phrase THEN
        RAISE EXCEPTION
          'last_admin_lockdown: you are the last administrador. '
          'To proceed, pass p_confirm_close_governance with exact phrase. '
          'Expected = ''%''', v_confirm_phrase;
      END IF;
      v_warning := 'last_administrador_left';
    END IF;

    -- A.3 — Désactiver TOUS les memberships admin de l'acteur·rice
    -- (un admin peut être ancré sur plusieurs libs ; on les désactive tous
    -- d'un coup pour cohérence — sinon on aurait une situation hybride)
    UPDATE public.user_library_memberships
    SET status = 'inactive',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now()
    WHERE user_id = v_actor_id
      AND role = 'administrador'
      AND status = 'active';

    -- A.4 — Activer / créer le membership cible sur la lib indiquée
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
      WHERE id = v_target_existing.id;
    ELSE
      INSERT INTO public.user_library_memberships
        (user_id, library_id, role, status)
      VALUES
        (v_actor_id, p_library_id, p_target_role, 'active');
    END IF;

    -- A.5 — Audit log
    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role,
       status_before, status_after, reason, metadata)
    VALUES
      (p_library_id, v_actor_id, v_actor_id, 'self_demoted', 'administrador',
       'active', 'inactive', NULL,
       jsonb_build_object(
         'target_role', p_target_role,
         'from_admin', true,
         'last_administrador', (v_other_admins_count = 0),
         'governance_close_confirmed', (v_warning = 'last_administrador_left')
       ))
    RETURNING id INTO v_audit_id;

    -- A.6 — Notification mail standard
    PERFORM public.fn_team_notify_event(
      'team.self_demoted',
      jsonb_build_object(
        'library_id', p_library_id,
        'target_user_id', v_actor_id,
        'actor_user_id', v_actor_id,
        'from_role', 'administrador',
        'to_role', p_target_role,
        'audit_id', v_audit_id
      )
    );

    -- A.7 — Si dernier admin → escalade dédiée
    IF v_warning = 'last_administrador_left' THEN
      PERFORM public.fn_team_notify_event(
        'team.last_administrador_left',
        jsonb_build_object(
          'library_id', p_library_id,
          'actor_user_id', v_actor_id,
          'audit_id', v_audit_id,
          'trigger', 'self_demote_admin'
        )
      );
    END IF;

    RETURN jsonb_build_object(
      'ok', true,
      'action', 'self_demoted',
      'from_role', 'administrador',
      'to_role', p_target_role,
      'audit_id', v_audit_id,
      'warning', v_warning
    );
  END IF;

  -- ═══ BRANCHE B : acteur·rice n'est pas admin (logique pré-B2 préservée) ══

  -- B.1 — Identifier le rôle "supérieur" actuellement actif à désactiver
  IF p_target_role = 'librarian' THEN
    v_higher_role := 'coordenador';
  ELSE  -- p_target_role = 'reader'
    v_higher_role := 'librarian';
  END IF;

  -- B.2 — Vérifier que l'acteur·rice a bien une membership active dans le rôle supérieur
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

  -- B.3 — Désactiver la membership supérieure
  UPDATE public.user_library_memberships
  SET status = 'inactive',
      pending_removal_until = NULL,
      pending_removal_requested_by = NULL,
      updated_at = now()
  WHERE user_id = v_actor_id
    AND library_id = p_library_id
    AND role = v_higher_role;

  -- B.4 — Activer / créer la membership cible
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

  -- B.5 — Si on était coordenador et qu'on se désactive vers reader, gérer aussi librarian
  IF p_target_role = 'reader' AND v_higher_role = 'coordenador' THEN
    UPDATE public.user_library_memberships
    SET status = 'inactive',
        updated_at = now()
    WHERE user_id = v_actor_id
      AND library_id = p_library_id
      AND role = 'librarian'
      AND status = 'active';
  END IF;

  -- B.6 — Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role,
     status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, v_actor_id, v_actor_id, 'self_demoted', v_higher_role,
     'active', 'inactive', NULL,
     jsonb_build_object('target_role', p_target_role))
  RETURNING id INTO v_audit_id;

  -- B.7 — Détection §6.1 : dernier coordenador qui se rétrograde
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

  -- B.8 — Notification mail standard self-demote
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

COMMENT ON FUNCTION public.fn_team_self_demote(uuid, text, text) IS
  'Phase B2 modif (07/05/2026) : permet aussi admin → librarian/reader '
  'sous garde-fou last admin (refus si dernier admin sauf saisie exacte de '
  '''JE FERME LA GOUVERNANCE ANARBIB''). Logique non-admin inchangée. '
  'Évent team.last_administrador_left envoyé en cas de fermeture confirmée.';

REVOKE ALL ON FUNCTION public.fn_team_self_demote(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_team_self_demote(uuid, text, text) TO authenticated;
