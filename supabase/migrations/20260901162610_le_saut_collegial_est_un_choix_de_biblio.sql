-- =====================================================================
-- 20260901162610_le_saut_collegial_est_un_choix_de_biblio.sql
--
-- Objet : GOUV-11/GOUV-12 — le saut collégial reader -> coordenador devient
--         possible, en opt-in PAR BIBLIO (défaut désactivé).
--
-- Doctrine (registre v0.8, cadrage CADRAGE_promotion_directe_reader_
-- coordenador_2026-09-01) :
--   - L'interdiction du saut (« target must be active librarian first »)
--     était un héritage d'implémentation de fn_team_promote_to_coordenador,
--     pas un principe : P2 exige la cooptation, qui est portée par le
--     circuit collégial — lequel reste INTÉGRAL (proposition -> ratification
--     selon quorum -> acceptation). Rien d'autre ne bouge : quorums,
--     consentement, péremption, notifications, traçage transverse.
--   - Opt-in : libraries.allow_direct_coordenador, défaut false. Une biblio
--     qui fonctionne en collectif horizontal (cas BTL) l'active après
--     décision de son collectif ; ailleurs, rien ne change.
--   - Cible : reader status='active' STRICT (GOUV-12) — jamais « pas
--     pending » : un garde-fou de statut qui énumère ce qu'il refuse laisse
--     passer ce qu'il n'a pas prévu. Pas d'entrée depuis l'extérieur.
--   - Rôle exclusif généralisé : à l'acceptation, la ligne active
--     inférieure se ferme QUELLE QU'ELLE SOIT (reader ou librarian), et
--     l'audit dit d'où vient la personne (metadata.from_role).
--
-- Les deux fonctions remplacées reconduisent à l'identique :
--   - le DEFAULT 'librarian' du paramètre p_role (GOUV-6 : 42P13 sinon) ;
--   - la garde admin réseau de 20260826160000 (GOUV-7) ;
--   - le décompte de quorum qui exclut la personne visée (GOUV-3) — pour
--     un·e reader ce filtre est neutre (elle n'est pas staff), le calcul
--     est correct sans modification.
--
-- Idempotente : ADD COLUMN IF NOT EXISTS + CREATE OR REPLACE (ACL
-- conservées). Rollback : _rollback_20260901162610_le_saut_collegial_est_
-- un_choix_de_biblio.sql. Tests : tests/sql/saut_collegial_tests.sql.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Le réglage par biblio
-- ---------------------------------------------------------------------

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS allow_direct_coordenador boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.libraries.allow_direct_coordenador IS
  'GOUV-11 : autorise la proposition collégiale de coordination à viser un·e reader actif·ve de la biblio (saut reader -> coordenador), pour les collectifs horizontaux. Défaut false ; se règle en base sur décision du collectif (précédent : team_admission_mode). Le circuit collégial (quorum, acceptation, péremption) s''applique intégralement. Cf. CADRAGE_promotion_directe_reader_coordenador_2026-09-01.';


-- ---------------------------------------------------------------------
-- 2. Proposition : la précondition s'élargit là où la biblio l'autorise
--    (base : définition 20260826160000, reconduite à l'identique ailleurs)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_team_propose_invitation(
  p_library_id uuid,
  p_invited_public_id text,
  -- Le DEFAULT vient de 20260820210000 et doit être reconduit à l'identique :
  -- CREATE OR REPLACE sait AJOUTER une valeur par défaut, jamais en RETIRER
  -- (42P13, « cannot remove parameter defaults from existing function »).
  -- L'omettre a fait échouer cette migration en production le 26/08/2026.
  p_role text DEFAULT 'librarian'::text
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
  v_allow_direct boolean;
  v_from_role text;
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

  -- Garde 1 — qui a le droit de DÉPOSER une proposition.
  -- L'accueil reste réservé au staff LOCAL ; la promotion à coordenador est
  -- aussi ouverte à l'admin réseau (rattrapage §6.1, cf. 20260826160000 / GOUV-7).
  IF NOT (public.user_can_manage_library_notifications(p_library_id)
          OR (p_role = 'coordenador' AND public.fn_caller_is_network_admin())) THEN
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

    -- Précondition GOUV-11 : librarian actif·ve — ou, si la biblio a activé
    -- le saut collégial, reader actif·ve STRICT (GOUV-12). L'échelle était un
    -- héritage d'implémentation ; la cooptation, elle, est dans le circuit.
    SELECT allow_direct_coordenador INTO v_allow_direct
      FROM public.libraries WHERE id = p_library_id;

    IF EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_invited AND m.library_id = p_library_id
         AND m.role = 'librarian' AND m.status = 'active'
    ) THEN
      v_from_role := 'librarian';
    ELSIF COALESCE(v_allow_direct, false) AND EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_invited AND m.library_id = p_library_id
         AND m.role = 'reader' AND m.status = 'active'
    ) THEN
      v_from_role := 'reader';
    ELSIF COALESCE(v_allow_direct, false) THEN
      RAISE EXCEPTION 'precondition_failed: target must be an active librarian or an active reader of this library';
    ELSE
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
  -- (Pour un·e reader — saut collégial — le filtre est simplement neutre.)
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
        'required_ratifications', v_required,
        'from_role', v_from_role
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
-- 3. Acceptation : revérification élargie + rôle exclusif généralisé
--    (base : définition 20260826120000 §4, reconduite à l'identique ailleurs)
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
  v_allow_direct boolean;
  v_from_role text;
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

  -- =============== promotion collégiale : (librarian|reader) -> coordenador ===============
  ELSIF v_inv.role_proposed = 'coordenador' THEN

    -- La précondition est revérifiée, sous sa forme GOUV-11 : la personne a pu
    -- être retirée de l'équipe — ou la biblio a pu désactiver le saut —
    -- entre la proposition et l'acceptation.
    SELECT allow_direct_coordenador INTO v_allow_direct
      FROM public.libraries WHERE id = v_inv.library_id;

    IF EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_inv.invited_user_id AND m.library_id = v_inv.library_id
         AND m.role = 'librarian' AND m.status = 'active'
    ) THEN
      v_from_role := 'librarian';
    ELSIF COALESCE(v_allow_direct, false) AND EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.user_id = v_inv.invited_user_id AND m.library_id = v_inv.library_id
         AND m.role = 'reader' AND m.status = 'active'
    ) THEN
      v_from_role := 'reader';
    ELSE
      RAISE EXCEPTION 'precondition_failed: no longer an active librarian (nor an eligible active reader)';
    END IF;

    INSERT INTO public.user_library_memberships
      (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
    VALUES
      (v_inv.invited_user_id, v_inv.library_id, 'coordenador', 'active', NULL, NULL)
    ON CONFLICT (user_id, library_id, role) DO UPDATE
      SET status = 'active', pending_removal_until = NULL,
          pending_removal_requested_by = NULL, updated_at = now()
    RETURNING id INTO v_membership_id;

    -- Doctrine du rôle exclusif (Q15), généralisée par GOUV-12 : la ligne
    -- active inférieure se ferme QUELLE QU'ELLE SOIT (librarian ou reader).
    -- Une seule devrait exister ; la boucle est le filet, pas la règle.
    FOR v_lower IN
      SELECT * FROM public.user_library_memberships
       WHERE user_id = v_inv.invited_user_id AND library_id = v_inv.library_id
         AND role IN ('librarian', 'reader') AND status = 'active'
    LOOP
      UPDATE public.user_library_memberships
        SET status = 'removed', is_primary = false, updated_at = now()
       WHERE id = v_lower.id;

      INSERT INTO public.library_membership_audit
        (library_id, target_user_id, actor_user_id, action, role,
         status_before, status_after, reason, metadata)
      VALUES
        (v_inv.library_id, v_inv.invited_user_id, v_actor, 'removal_completed', v_lower.role,
         'active', 'removed',
         'Membership ' || v_lower.role || ' cloturé suite à promotion coordenador',
         jsonb_build_object('superseded_by', 'coordenador',
                            'coordenador_membership_id', v_membership_id));
    END LOOP;

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
                          'required_ratifications', v_inv.required_ratifications,
                          'from_role', v_from_role))
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
-- 4. Vérification : ce que CETTE migration fait, rien de global
--    (DOC-DEPLOY-4)
-- ---------------------------------------------------------------------

DO $do$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'libraries'
       AND column_name = 'allow_direct_coordenador'
  ) THEN
    RAISE EXCEPTION 'verification: colonne libraries.allow_direct_coordenador absente';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_team_propose_invitation'
       AND p.prosrc LIKE '%allow_direct_coordenador%'
  ) THEN
    RAISE EXCEPTION 'verification: fn_team_propose_invitation ne lit pas le réglage';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_team_accept_invitation'
       AND p.prosrc LIKE '%allow_direct_coordenador%'
  ) THEN
    RAISE EXCEPTION 'verification: fn_team_accept_invitation ne lit pas le réglage';
  END IF;
END
$do$;

COMMIT;
