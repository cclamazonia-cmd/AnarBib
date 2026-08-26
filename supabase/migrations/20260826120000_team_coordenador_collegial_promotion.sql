-- =====================================================================
-- 20260826120000_team_coordenador_collegial_promotion.sql
--
-- Objet : appliquer le principe P2 (cooptation collégiale) à la promotion
--         librarian -> coordenador, qui s'en dispensait jusqu'ici.
--
-- Constat à l'origine (cf. claude/ECART_cosignature_promotion_coordenador_2026-08-26.md) :
--   - `fn_team_propose_invitation` est la seule fonction du schéma qui lise
--     `libraries.team_admission_mode`, et elle refusait explicitement le rôle
--     `coordenador` (« only librarian can be invited »).
--   - `fn_team_promote_to_coordenador` promouvait immédiatement, sur la seule
--     autorisation `user_can_manage_library()`, sans ratification ni consentement.
--   - `library_team_invitations` n'avait jamais servi : 0 ligne.
--
-- Décisions appliquées ici :
--   1. Mécanisme : ratification PRÉALABLE, en réutilisant le workflow d'invitation
--      existant plutôt qu'en créant un second appareil.
--   2. Quorum : règle existante conservée — `coordenador_seul` => 1 ;
--      moins de 2 membres de staff (hors personne visée) => 1 ; sinon 2.
--   3. Consentement : la personne promue doit accepter, symétriquement à P3
--      (« passer la main est un droit »).
--
-- Idempotente : CREATE OR REPLACE + DROP CONSTRAINT IF EXISTS.
-- Rollback : _rollback_20260826120000_team_coordenador_collegial_promotion.sql
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Le rôle proposé peut désormais être coordenador
-- ---------------------------------------------------------------------

ALTER TABLE public.library_team_invitations
  DROP CONSTRAINT IF EXISTS library_team_invitations_role_proposed_check;

ALTER TABLE public.library_team_invitations
  ADD CONSTRAINT library_team_invitations_role_proposed_check
  CHECK (role_proposed = ANY (ARRAY['librarian'::text, 'coordenador'::text]));


-- ---------------------------------------------------------------------
-- 2. Proposition : accepte les deux rôles
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_propose_invitation(
  p_library_id uuid,
  p_invited_public_id text,
  p_role text
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
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  IF p_role IS NULL OR p_role NOT IN ('librarian', 'coordenador') THEN
    RAISE EXCEPTION 'forbidden: role must be librarian or coordenador';
  END IF;

  IF NOT public.user_can_manage_library_notifications(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can propose an invitation';
  END IF;

  -- Proposer une promotion à coordenador reste un acte de coordination.
  -- (user_can_manage_library couvre coordenador local ET admin réseau.)
  IF p_role = 'coordenador' AND NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can propose a promotion to coordenador';
  END IF;

  SELECT id INTO v_invited
    FROM public.profiles
   WHERE upper(btrim(public_id)) = upper(btrim(p_invited_public_id));

  IF v_invited IS NULL THEN
    RAISE EXCEPTION 'not_found: no profile with that public_id';
  END IF;

  -- Couvre aussi le garde-fou historique « pas d'auto-promotion ».
  IF v_invited = v_actor THEN
    RAISE EXCEPTION 'forbidden: cannot invite or promote yourself';
  END IF;

  IF p_role = 'librarian' THEN
    IF EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_invited AND m.library_id = p_library_id
         AND m.role IN ('librarian', 'coordenador') AND m.status = 'active'
    ) THEN
      RAISE EXCEPTION 'conflict: already an active team member';
    END IF;
  ELSE
    IF EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_invited AND m.library_id = p_library_id
         AND m.role = 'coordenador' AND m.status = 'active'
    ) THEN
      RAISE EXCEPTION 'conflict: already an active coordenador';
    END IF;

    -- Précondition héritée de fn_team_promote_to_coordenador §5 :
    -- on ne saute pas de reader à coordenador.
    IF NOT EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_invited AND m.library_id = p_library_id
         AND m.role = 'librarian' AND m.status = 'active'
    ) THEN
      RAISE EXCEPTION 'precondition_failed: target must be active librarian first';
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.library_team_invitations
     WHERE library_id = p_library_id AND invited_user_id = v_invited
       AND status IN ('pending_ratification', 'ready')
  ) THEN
    RAISE EXCEPTION 'conflict: an active invitation already exists for this person';
  END IF;

  SELECT team_admission_mode INTO v_mode
    FROM public.libraries WHERE id = p_library_id;

  -- La personne visée est exclue du décompte : sur une promotion à coordenador
  -- elle est elle-même staff, et l'inclure produirait un quorum impossible à
  -- atteindre dans une équipe de deux (elle accepte, elle ne ratifie pas).
  SELECT count(*) INTO v_staff_count
    FROM public.user_library_memberships
   WHERE library_id = p_library_id
     AND role IN ('librarian', 'coordenador')
     AND status = 'active'
     AND user_id <> v_invited;

  v_required := CASE
    WHEN v_mode = 'coordenador_seul' THEN 1
    WHEN v_staff_count < 2 THEN 1
    ELSE 2
  END;

  v_actor_is_coord := public.fn_team_caller_is_coordenador(p_library_id);

  INSERT INTO public.library_team_invitations
    (library_id, invited_user_id, role_proposed, proposed_by, status,
     required_ratifications, expires_at)
  VALUES
    (p_library_id, v_invited, p_role, v_actor, 'pending_ratification',
     v_required, now() + interval '30 days')
  RETURNING id INTO v_inv_id;

  INSERT INTO public.library_team_invitation_ratifications
    (invitation_id, ratifier_user_id, is_coordenador)
  VALUES (v_inv_id, v_actor, v_actor_is_coord);

  PERFORM public.fn_team_invitation_recompute(v_inv_id);
  SELECT status INTO v_status
    FROM public.library_team_invitations WHERE id = v_inv_id;

  -- Traçage transverse : c'est ici que l'acte de coordination a lieu,
  -- pas à l'acceptation (qui est le fait de la personne visée).
  IF p_role = 'coordenador' THEN
    PERFORM public.fn_log_cross_library_action(
      p_library_id         := p_library_id,
      p_action_type        := 'team_promote_to_coordenador',
      p_is_critical        := public.fn_is_critical_action_type('team_promote_to_coordenador'),
      p_target_entity_type := 'library_team_invitation',
      p_target_entity_id   := v_inv_id,
      p_payload            := jsonb_build_object(
        'target_user_id', v_invited,
        'stage', 'proposed',
        'required_ratifications', v_required
      )
    );
  END IF;

  IF v_status = 'ready' THEN
    PERFORM public.fn_team_notify_event('team.invitation_ready', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited,
      'actor_user_id', v_actor, 'invitation_id', v_inv_id,
      'role_proposed', p_role));
  ELSE
    PERFORM public.fn_team_notify_event('team.invitation_proposed', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited,
      'actor_user_id', v_actor, 'invitation_id', v_inv_id,
      'role_proposed', p_role));
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'invitation_id', v_inv_id,
    'role_proposed', p_role,
    'required_ratifications', v_required,
    'status', v_status
  );
END
$fn$;


-- ---------------------------------------------------------------------
-- 3. Ratification : transmet le rôle proposé au gabarit de mail,
--    et refuse une invitation périmée
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
  v_role text;
  v_expires timestamptz;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  SELECT library_id, status, invited_user_id, proposed_by, role_proposed, expires_at
    INTO v_lib, v_status, v_invited, v_proposer, v_role, v_expires
    FROM public.library_team_invitations WHERE id = p_invitation_id;

  IF v_lib IS NULL THEN
    RAISE EXCEPTION 'not_found: invitation';
  END IF;

  IF v_status IS DISTINCT FROM 'pending_ratification' THEN
    RAISE EXCEPTION 'conflict: invitation not pending (%)', v_status;
  END IF;

  -- Une invitation périmée est refusée. Le marquage en base est le travail
  -- de fn_team_expire_invitations() : le faire ici serait annulé par le RAISE,
  -- qui défait la transaction de la fonction.
  IF v_expires IS NOT NULL AND v_expires < now() THEN
    RAISE EXCEPTION 'conflict: invitation expired';
  END IF;

  IF NOT public.user_can_manage_library_notifications(v_lib) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can ratify';
  END IF;

  -- La personne visée ne ratifie pas sa propre promotion : elle l'accepte.
  IF v_actor = v_invited THEN
    RAISE EXCEPTION 'forbidden: the invited person cannot ratify their own invitation';
  END IF;

  v_is_coord := public.fn_team_caller_is_coordenador(v_lib);

  INSERT INTO public.library_team_invitation_ratifications
    (invitation_id, ratifier_user_id, is_coordenador)
  VALUES (p_invitation_id, v_actor, v_is_coord)
  ON CONFLICT (invitation_id, ratifier_user_id)
  DO UPDATE SET is_coordenador = EXCLUDED.is_coordenador;

  PERFORM public.fn_team_invitation_recompute(p_invitation_id);
  SELECT status INTO v_status
    FROM public.library_team_invitations WHERE id = p_invitation_id;

  IF v_status = 'ready' THEN
    PERFORM public.fn_team_notify_event('team.invitation_ready', jsonb_build_object(
      'library_id', v_lib, 'target_user_id', v_invited,
      'actor_user_id', v_proposer, 'invitation_id', p_invitation_id,
      'role_proposed', v_role));
  END IF;

  RETURN jsonb_build_object('ok', true, 'status', v_status, 'role_proposed', v_role);
END
$fn$;


-- ---------------------------------------------------------------------
-- 4. Acceptation : branche selon le rôle proposé
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_accept_invitation(
  p_invitation_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_actor uuid := auth.uid();
  v_inv record;
  v_membership_id uuid;
  v_lower record;
  v_audit_id uuid;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  SELECT * INTO v_inv FROM public.library_team_invitations WHERE id = p_invitation_id;
  IF v_inv.id IS NULL THEN
    RAISE EXCEPTION 'not_found: invitation';
  END IF;

  IF v_inv.invited_user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'forbidden: only the invited person can accept';
  END IF;

  IF v_inv.status IS DISTINCT FROM 'ready' THEN
    RAISE EXCEPTION 'conflict: invitation not ready (%)', v_inv.status;
  END IF;

  IF v_inv.expires_at IS NOT NULL AND v_inv.expires_at < now() THEN
    RAISE EXCEPTION 'conflict: invitation expired';
  END IF;

  -- =============== accueil dans l'équipe : reader -> librarian ===============
  IF v_inv.role_proposed = 'librarian' THEN

    INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
    VALUES (v_inv.invited_user_id, v_inv.library_id, 'librarian', 'active')
    ON CONFLICT (user_id, library_id, role) DO UPDATE
      SET status = 'active', pending_removal_until = NULL,
          pending_removal_requested_by = NULL, updated_at = now()
    RETURNING id INTO v_membership_id;

    SELECT * INTO v_lower FROM public.user_library_memberships
      WHERE user_id = v_inv.invited_user_id AND library_id = v_inv.library_id
        AND role = 'reader' AND status = 'active';

    IF FOUND THEN
      UPDATE public.user_library_memberships
        SET status = 'removed', is_primary = false, updated_at = now()
       WHERE id = v_lower.id;

      INSERT INTO public.library_membership_audit
        (library_id, target_user_id, actor_user_id, action, role,
         status_before, status_after, reason, metadata)
      VALUES
        (v_inv.library_id, v_inv.invited_user_id, v_actor, 'removal_completed', 'reader',
         'active', 'removed',
         'Membership reader cloturé suite à accueil dans l''équipe',
         jsonb_build_object('superseded_by', 'librarian',
                            'librarian_membership_id', v_membership_id));
    END IF;

    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role,
       status_before, status_after, reason, metadata)
    VALUES
      (v_inv.library_id, v_inv.invited_user_id, v_actor, 'promoted_to_librarian', 'librarian',
       NULL, 'active',
       'Accueil dans l''équipe (invitation acceptée)',
       jsonb_build_object('via', 'team_invitation_accepted',
                          'invitation_id', v_inv.id,
                          'proposed_by', v_inv.proposed_by))
    RETURNING id INTO v_audit_id;

  -- =============== promotion collégiale : librarian -> coordenador ===============
  ELSIF v_inv.role_proposed = 'coordenador' THEN

    -- La précondition est revérifiée : la personne a pu être retirée de
    -- l'équipe entre la proposition et l'acceptation.
    IF NOT EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_inv.invited_user_id AND m.library_id = v_inv.library_id
         AND m.role = 'librarian' AND m.status = 'active'
    ) THEN
      RAISE EXCEPTION 'precondition_failed: no longer an active librarian';
    END IF;

    INSERT INTO public.user_library_memberships
      (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
    VALUES
      (v_inv.invited_user_id, v_inv.library_id, 'coordenador', 'active', NULL, NULL)
    ON CONFLICT (user_id, library_id, role) DO UPDATE
      SET status = 'active', pending_removal_until = NULL,
          pending_removal_requested_by = NULL, updated_at = now()
    RETURNING id INTO v_membership_id;

    -- Doctrine du rôle exclusif (Q15) : la ligne librarian se ferme.
    SELECT * INTO v_lower FROM public.user_library_memberships
      WHERE user_id = v_inv.invited_user_id AND library_id = v_inv.library_id
        AND role = 'librarian' AND status = 'active';

    IF FOUND THEN
      UPDATE public.user_library_memberships
        SET status = 'removed', is_primary = false, updated_at = now()
       WHERE id = v_lower.id;

      INSERT INTO public.library_membership_audit
        (library_id, target_user_id, actor_user_id, action, role,
         status_before, status_after, reason, metadata)
      VALUES
        (v_inv.library_id, v_inv.invited_user_id, v_actor, 'removal_completed', 'librarian',
         'active', 'removed',
         'Membership librarian cloturé suite à promotion coordenador',
         jsonb_build_object('superseded_by', 'coordenador',
                            'coordenador_membership_id', v_membership_id));
    END IF;

    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role,
       status_before, status_after, reason, metadata)
    VALUES
      (v_inv.library_id, v_inv.invited_user_id, v_actor, 'promoted_to_coordenador', 'coordenador',
       NULL, 'active',
       'Promotion collégiale acceptée',
       jsonb_build_object('via', 'team_invitation_accepted',
                          'invitation_id', v_inv.id,
                          'proposed_by', v_inv.proposed_by,
                          'required_ratifications', v_inv.required_ratifications))
    RETURNING id INTO v_audit_id;

    PERFORM public.fn_team_notify_event('team.promoted_to_coordenador', jsonb_build_object(
      'library_id', v_inv.library_id,
      'target_user_id', v_inv.invited_user_id,
      'actor_user_id', v_inv.proposed_by,
      'audit_id', v_audit_id));

  ELSE
    RAISE EXCEPTION 'conflict: unsupported role_proposed (%)', v_inv.role_proposed;
  END IF;

  UPDATE public.library_team_invitations
     SET status = 'accepted', resolved_at = now(), updated_at = now()
   WHERE id = p_invitation_id;

  RETURN jsonb_build_object(
    'ok', true,
    'library_id', v_inv.library_id,
    'role', v_inv.role_proposed,
    'membership_id', v_membership_id,
    'audit_id', v_audit_id
  );
END
$fn$;


-- ---------------------------------------------------------------------
-- 5. La promotion directe n'est plus un chemin praticable
--
-- La fonction est conservée (signature, droits, références) mais refuse,
-- en désignant explicitement le chemin collégial. Un échec bruyant vaut
-- mieux qu'un succès qui ne promeut plus rien.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_promote_to_coordenador(
  p_user_id uuid,
  p_library_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  RAISE EXCEPTION 'collegiality_required: direct promotion to coordenador is disabled'
    USING ERRCODE = '0A000',
          HINT = 'Use fn_team_propose_invitation(p_library_id, <public_id>, ''coordenador''), '
                 'then fn_team_ratify_invitation() by another staff member, '
                 'then fn_team_accept_invitation() by the person concerned.';
END
$fn$;

-- ---------------------------------------------------------------------
-- 6. Péremption des invitations
--
-- Lacune préexistante : `expires_at` était renseigné depuis l'origine, mais
-- aucune tâche ne le faisait respecter. Les invitations restaient
-- indéfiniment 'pending_ratification'. Comme le chemin collégial devient
-- obligatoire pour les promotions, ce balayage cesse d'être facultatif.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_expire_invitations()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.library_team_invitations
     SET status = 'expired',
         resolved_at = now(),
         updated_at = now(),
         resolution_note = COALESCE(resolution_note, '')
                           || ' [expirée automatiquement]'
   WHERE status IN ('pending_ratification', 'ready')
     AND expires_at IS NOT NULL
     AND expires_at < now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END
$fn$;

ALTER FUNCTION public.fn_team_expire_invitations() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_expire_invitations() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_team_expire_invitations() TO service_role;
COMMENT ON FUNCTION public.fn_team_expire_invitations() IS
  'Périme les invitations d''équipe dont expires_at est dépassé. Appelée par le cron anarbib-team-invitations-expire. Cf. migration 20260826120000.';

DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-team-invitations-expire') THEN
    PERFORM cron.unschedule('anarbib-team-invitations-expire');
  END IF;
  PERFORM cron.schedule(
    'anarbib-team-invitations-expire',
    '20 3 * * *',
    $job$SELECT public.fn_team_expire_invitations()$job$
  );
EXCEPTION
  WHEN undefined_table OR undefined_function OR invalid_schema_name OR insufficient_privilege THEN
    RAISE NOTICE 'pg_cron indisponible ici : planifier anarbib-team-invitations-expire manuellement';
END
$do$;

-- ---------------------------------------------------------------------
-- 7. Exposer le rôle proposé à l'écran d'équipe
--
-- `fn_team_list_invitations` n'exposait pas `role_proposed` : tant que seul
-- 'librarian' était possible, c'était superflu. Ça ne l'est plus — la liste
-- doit dire si l'invitation est un accueil ou un passage à la coordination.
-- (`fn_team_my_invitations` l'exposait déjà.)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_list_invitations(p_library_id uuid)
RETURNS SETOF jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $fn$
  SELECT jsonb_build_object(
    'id', i.id,
    'library_id', i.library_id,
    'status', i.status,
    'role_proposed', i.role_proposed,
    'required_ratifications', i.required_ratifications,
    'ratifications_count', (SELECT count(*) FROM public.library_team_invitation_ratifications r WHERE r.invitation_id = i.id),
    'has_coordenador', COALESCE((SELECT bool_or(r.is_coordenador) FROM public.library_team_invitation_ratifications r WHERE r.invitation_id = i.id), false),
    'caller_has_ratified', EXISTS (SELECT 1 FROM public.library_team_invitation_ratifications r WHERE r.invitation_id = i.id AND r.ratifier_user_id = auth.uid()),
    'invited_public_id', ip.public_id,
    'invited_name', NULLIF(btrim(COALESCE(ip.first_name,'') || ' ' || COALESCE(ip.last_name,'')), ''),
    'invited_email', ip.email,
    'proposed_by_name', NULLIF(btrim(COALESCE(pp.first_name,'') || ' ' || COALESCE(pp.last_name,'')), ''),
    'created_at', i.created_at,
    'expires_at', i.expires_at
  )
  FROM public.library_team_invitations i
  JOIN public.profiles ip ON ip.id = i.invited_user_id
  LEFT JOIN public.profiles pp ON pp.id = i.proposed_by
  WHERE i.library_id = p_library_id
    AND i.status IN ('pending_ratification','ready')
    AND public.user_can_manage_library_notifications(p_library_id)
  ORDER BY i.created_at DESC;
$fn$;

ALTER FUNCTION public.fn_team_list_invitations(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_list_invitations(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_list_invitations(uuid) TO authenticated, service_role;

COMMIT;
