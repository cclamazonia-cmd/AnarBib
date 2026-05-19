-- ============================================================================
-- Hotfix D.6 v2 - Correction colonne library_profile_history
-- ============================================================================
-- Bug introduit dans la migration 20260519260000_paquetD6_propose_execute_archivage_hook :
-- les INSERT dans library_profile_history utilisent un nom de colonne errone.
-- Le nom correct dans le schema est `motivation`.
--
-- Detecte par le test fume du 19 mai 2026 matin.
-- Aucun impact prod : aucune transition de profil n'a ete executee depuis
-- le deploiement de D.6 (verifie : 0 lignes dans library_profile_history).
--
-- v2 : DO block de verification refactore pour tester via INSERT reel plutot
-- que par grep sur pg_get_functiondef (qui matchait les commentaires et
-- causait un faux positif lors du hotfix v1).
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_propose_library_profile_change(p_library_id uuid, p_axis text, p_new_value text, p_motivation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id        uuid := auth.uid();
  v_old_value        text;
  v_classification   jsonb;
  v_transition_type  int;
  v_governance       text;
  v_active_staff     int;
  v_min_quorum       int;
  v_proposal_id      uuid;
  v_expires_at       timestamptz;
  v_votes_required   int;
  v_executed_now     boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'PROPOSE_AUTH_REQUIRED : authentification requise'
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.profile_change.auth_required';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE library_id = p_library_id
      AND user_id    = v_caller_id
      AND status     = 'active'
      AND role IN ('librarian', 'coordenador')
  ) THEN
    RAISE EXCEPTION 'PROPOSE_NOT_STAFF : caller n''est pas staff actif de la biblio (%)' , p_library_id
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.profile_change.not_staff';
  END IF;

  IF p_motivation IS NULL OR length(trim(p_motivation)) < 5 THEN
    RAISE EXCEPTION 'PROPOSE_MOTIVATION_TOO_SHORT : la motivation doit faire au moins 5 caracteres'
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.motivation_too_short';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.library_profile_proposals
    WHERE library_id = p_library_id
      AND axis       = p_axis
      AND status     = 'open'
  ) THEN
    RAISE EXCEPTION 'PROPOSE_AXIS_LOCKED : une proposition est deja ouverte sur cet axe pour cette biblio'
      USING ERRCODE = 'unique_violation',
            HINT    = 'error.profile_change.axis_already_open';
  END IF;

  IF    p_axis = 'catalog_mode'     THEN v_old_value := public.fn_library_catalog_mode(p_library_id);
  ELSIF p_axis = 'circulation_mode' THEN v_old_value := public.fn_library_circulation_mode(p_library_id);
  ELSIF p_axis = 'network_mode'     THEN v_old_value := public.fn_library_network_mode(p_library_id);
  ELSIF p_axis = 'governance_mode'  THEN v_old_value := public.fn_library_governance_mode(p_library_id);
  ELSE
    RAISE EXCEPTION 'PROPOSE_UNKNOWN_AXIS : axe inconnu (%)', p_axis
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.unknown_axis';
  END IF;

  IF v_old_value IS NULL THEN
    RAISE EXCEPTION 'PROPOSE_LIBRARY_NOT_FOUND : biblio invisible ou inexistante (%)', p_library_id
      USING ERRCODE = 'no_data_found',
            HINT    = 'error.profile_change.library_not_found';
  END IF;

  v_classification  := public.fn_classify_transition(p_axis, v_old_value, p_new_value);
  v_transition_type := (v_classification->>'transition_type')::int;
  v_governance      := v_classification->>'governance_required';

  v_active_staff := public.fn_library_active_staff_count(p_library_id);
  v_min_quorum := CASE v_transition_type
    WHEN 1 THEN 1
    WHEN 2 THEN 2
    WHEN 3 THEN 2
    WHEN 4 THEN 3
  END;

  IF v_active_staff < v_min_quorum THEN
    RAISE EXCEPTION 'PROPOSE_QUORUM_NOT_MET : type % requiert >= % staff actifs, % presents',
      v_transition_type, v_min_quorum, v_active_staff
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.quorum_not_met';
  END IF;

  v_votes_required := CASE v_governance
    WHEN 'direct'             THEN 0
    WHEN 'majority'           THEN (v_active_staff / 2) + 1
    WHEN 'unanimous'          THEN v_active_staff
    WHEN 'unanimous_extended' THEN v_active_staff
  END;

  v_expires_at := CASE
    WHEN v_transition_type = 1 THEN now()
    ELSE now() + interval '30 days'
  END;

  INSERT INTO public.library_profile_proposals (
    library_id, axis, old_value, new_value, transition_type, governance_required,
    motivation, proposed_by, status, expires_at, completed_at
  )
  VALUES (
    p_library_id, p_axis, v_old_value, p_new_value, v_transition_type, v_governance,
    trim(p_motivation), v_caller_id,
    CASE WHEN v_transition_type = 1 THEN 'completed' ELSE 'open' END,
    v_expires_at,
    CASE WHEN v_transition_type = 1 THEN now() ELSE NULL END
  )
  RETURNING id INTO v_proposal_id;

  IF v_transition_type = 1 THEN
    INSERT INTO public.library_profile_history (
      library_id, axis, old_value, new_value, changed_by, changed_at, motivation
    )
    VALUES (
      p_library_id, p_axis, v_old_value, p_new_value, v_caller_id, now(),
      'Transition directe type 1 (' || p_motivation || ')'
    );

    IF    p_axis = 'catalog_mode'     THEN UPDATE public.libraries SET catalog_mode     = p_new_value WHERE id = p_library_id;
    ELSIF p_axis = 'circulation_mode' THEN UPDATE public.libraries SET circulation_mode = p_new_value WHERE id = p_library_id;
    ELSIF p_axis = 'network_mode'     THEN UPDATE public.libraries SET network_mode     = p_new_value WHERE id = p_library_id;
    ELSIF p_axis = 'governance_mode'  THEN UPDATE public.libraries SET governance_mode  = p_new_value WHERE id = p_library_id;
    END IF;

    v_executed_now := true;
  END IF;

  RETURN jsonb_build_object(
    'proposal_id',          v_proposal_id,
    'library_id',           p_library_id,
    'axis',                 p_axis,
    'old_value',            v_old_value,
    'new_value',            p_new_value,
    'transition_type',      v_transition_type,
    'governance_required',  v_governance,
    'expires_at',           v_expires_at,
    'active_staff_count',   v_active_staff,
    'votes_required',       v_votes_required,
    'status',               CASE WHEN v_executed_now THEN 'completed' ELSE 'open' END,
    'executed_immediately', v_executed_now
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_execute_library_profile_change(p_proposal_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id     uuid := auth.uid();
  v_proposal      public.library_profile_proposals%ROWTYPE;
  v_is_staff      boolean := false;
  v_is_system     boolean := false;
  v_archive_result jsonb := NULL;
BEGIN
  SELECT * INTO v_proposal
  FROM public.library_profile_proposals
  WHERE id = p_proposal_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EXECUTE_PROPOSAL_NOT_FOUND : proposition introuvable (%)', p_proposal_id
      USING ERRCODE = 'no_data_found',
            HINT    = 'error.profile_change.proposal_not_found';
  END IF;

  v_is_system := (v_caller_id IS NULL);

  IF NOT v_is_system THEN
    v_is_staff := EXISTS (
      SELECT 1 FROM public.user_library_memberships
      WHERE library_id = v_proposal.library_id
        AND user_id    = v_caller_id
        AND status     = 'active'
        AND role IN ('librarian', 'coordenador')
    );

    IF NOT v_is_staff THEN
      RAISE EXCEPTION 'EXECUTE_NOT_AUTHORIZED : caller n''est ni staff de la biblio ni systeme cron'
        USING ERRCODE = 'insufficient_privilege',
              HINT    = 'error.profile_change.not_authorized';
    END IF;
  END IF;

  IF v_proposal.status NOT IN ('accepted_unanimous', 'accepted_majority') THEN
    RAISE EXCEPTION 'EXECUTE_PROPOSAL_NOT_ACCEPTED : proposition pas executable (status=%)', v_proposal.status
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.not_accepted';
  END IF;

  IF v_proposal.grace_period_until IS NULL OR v_proposal.grace_period_until > now() THEN
    RAISE EXCEPTION 'EXECUTE_GRACE_PERIOD_ACTIVE : carence active jusqu''a %', v_proposal.grace_period_until
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.grace_period_active';
  END IF;

  INSERT INTO public.library_profile_history (
    library_id, axis, old_value, new_value, changed_by, changed_at, motivation
  )
  VALUES (
    v_proposal.library_id,
    v_proposal.axis,
    v_proposal.old_value,
    v_proposal.new_value,
    COALESCE(v_caller_id, v_proposal.proposed_by),
    now(),
    'Transition type ' || v_proposal.transition_type ||
    ' (' || v_proposal.governance_required || ') : ' || v_proposal.motivation
  );

  IF    v_proposal.axis = 'catalog_mode'     THEN UPDATE public.libraries SET catalog_mode     = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'circulation_mode' THEN UPDATE public.libraries SET circulation_mode = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'network_mode'     THEN UPDATE public.libraries SET network_mode     = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'governance_mode'  THEN UPDATE public.libraries SET governance_mode  = v_proposal.new_value WHERE id = v_proposal.library_id;
  END IF;

  IF v_proposal.axis = 'circulation_mode' AND v_proposal.new_value = 'off' THEN
    v_archive_result := public.fn_archive_library_circulation(
      v_proposal.library_id, p_proposal_id
    );
  END IF;

  IF v_proposal.axis = 'circulation_mode'
     AND v_proposal.old_value = 'full_sigb'
     AND v_proposal.new_value = 'informal' THEN
    v_archive_result := public.fn_archive_library_cotisations(
      v_proposal.library_id, p_proposal_id
    );
  END IF;

  UPDATE public.library_profile_proposals
  SET status       = 'completed',
      completed_at = now()
  WHERE id = p_proposal_id;

  UPDATE public.library_profile_grace_locks
  SET released_at = now()
  WHERE proposal_id = p_proposal_id
    AND released_at IS NULL;

  RETURN jsonb_build_object(
    'proposal_id',          p_proposal_id,
    'library_id',           v_proposal.library_id,
    'axis',                 v_proposal.axis,
    'old_value',            v_proposal.old_value,
    'new_value',            v_proposal.new_value,
    'completed_at',         now(),
    'executed_by_caller',   COALESCE(v_caller_id::text, 'system_cron'),
    'archive_result',       v_archive_result
  );
END;
$function$;

-- ============================================================================
-- Verification fail-fast : la colonne motivation existe-t-elle ?
-- ============================================================================
-- Approche robuste : SELECT LIMIT 0 qui reference explicitement la colonne.
-- Si elle n'existe pas, le parseur SQL leve une exception immediate.
-- Si elle existe, retourne 0 lignes sans rien faire.
-- Pas de pollution audit (immutabilite respectee).
DO $verif$
DECLARE
  v_colonne_existe boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'library_profile_history'
       AND column_name = 'motivation'
  ) INTO v_colonne_existe;

  IF NOT v_colonne_existe THEN
    RAISE EXCEPTION 'VERIF_FAIL : la colonne library_profile_history.motivation n''existe pas en BDD';
  END IF;

  RAISE NOTICE 'Hotfix D.6 v2 - Verification OK : colonne motivation existe dans library_profile_history';
END
$verif$;

COMMIT;
