-- ============================================================================
-- Paquet D.6 - Connexion paquet B <-> paquet D : hooks archivage
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.4 (paquet D, point d'orgue)
-- Dependance : paquets B (transitions), D.1 (colonnes), D.2 (helpers).
--
-- Objectif : connecter le paquet B (transitions profil) au paquet D (archivage)
-- en remplacant le refus precoce type 4 de fn_propose_library_profile_change
-- par l'appel effectif des helpers D.2 au moment de l'execution.
--
-- 2 modifications :
--
--   1. fn_propose_library_profile_change
--      Retrait du RAISE EXCEPTION 'PROPOSE_TYPE_4_REQUIRES_PACKAGE_D'.
--      Les transitions type 4 sont maintenant proposables.
--
--   2. fn_execute_library_profile_change
--      Ajout d'un bloc d'archivage entre l'UPDATE libraries (etape 2) et
--      l'UPDATE proposal status=completed (etape 3).
--
--      Cas couverts :
--        - circulation_mode -> 'off' : appel fn_archive_library_circulation
--          (archive emp+res+con+ill vivants)
--        - circulation_mode: 'full_sigb' -> 'informal' : appel
--          fn_archive_library_cotisations (archive cotisations en cours)
--
--      Doctrine #141.2.E : NARRATIVE avant ETAT. L'INSERT history et l'UPDATE
--      libraries gardent leur ordre actuel. L'archivage vient apres car il
--      depend de la nouvelle valeur ; ce n'est pas une narrative au sens du
--      141.2.E mais un effet de bord systeme.
--
-- Doctrine v2 maintenue : SECURITY DEFINER, search_path = public.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. fn_propose_library_profile_change - retrait refus type 4
-- ============================================================================
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
  -- ===== Garde-fou 1 : authentification =====
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'PROPOSE_AUTH_REQUIRED : authentification requise'
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.profile_change.auth_required';
  END IF;

  -- ===== Garde-fou 2 : caller est staff actif de la biblio =====
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

  -- ===== Garde-fou 3 : motivation substantielle =====
  IF p_motivation IS NULL OR length(trim(p_motivation)) < 5 THEN
    RAISE EXCEPTION 'PROPOSE_MOTIVATION_TOO_SHORT : la motivation doit faire au moins 5 caracteres'
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.motivation_too_short';
  END IF;

  -- ===== Garde-fou 4 : pas de proposition open existante sur (library, axis) =====
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

  -- ===== Lecture etat courant et classification =====
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

  -- fn_classify_transition leve check_violation si valeurs identiques ou invalides
  v_classification  := public.fn_classify_transition(p_axis, v_old_value, p_new_value);
  v_transition_type := (v_classification->>'transition_type')::int;
  v_governance      := v_classification->>'governance_required';

  -- ===== D.6 : SUPPRESSION du refus precoce type 4 =====
  -- Le paquet D etant livre, les transitions type 4 sont maintenant supportees.
  -- L'archivage effectif sera realise par fn_execute_library_profile_change
  -- qui appellera fn_archive_library_circulation / fn_archive_library_cotisations
  -- au bon moment.

  -- ===== Garde-fou 5 : quorum minimum staff actif (echelle du risque) =====
  v_active_staff := public.fn_library_active_staff_count(p_library_id);
  v_min_quorum := CASE v_transition_type
    WHEN 1 THEN 1   -- elargissement : 1 staff suffit
    WHEN 2 THEN 2   -- retractation douce : 2 staff (vote significatif)
    WHEN 3 THEN 2   -- retractation politique : 2 staff
    WHEN 4 THEN 3   -- archivage : 3 staff (coherent admin reseau v0.3)
  END;

  IF v_active_staff < v_min_quorum THEN
    RAISE EXCEPTION 'PROPOSE_QUORUM_NOT_MET : type % requiert >= % staff actifs, % presents',
      v_transition_type, v_min_quorum, v_active_staff
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.quorum_not_met';
  END IF;

  -- ===== Calcul des votes requis pour acceptation =====
  v_votes_required := CASE v_governance
    WHEN 'direct'             THEN 0
    WHEN 'majority'           THEN (v_active_staff / 2) + 1
    WHEN 'unanimous'          THEN v_active_staff
    WHEN 'unanimous_extended' THEN v_active_staff
  END;

  -- ===== Calcul expires_at =====
  v_expires_at := CASE
    WHEN v_transition_type = 1 THEN now()
    ELSE now() + interval '30 days'
  END;

  -- ===== INSERT proposal =====
  INSERT INTO public.library_profile_proposals (
    library_id, axis, old_value, new_value, transition_type, governance_required,
    motivation, proposed_by, status, expires_at,
    completed_at
  )
  VALUES (
    p_library_id, p_axis, v_old_value, p_new_value, v_transition_type, v_governance,
    trim(p_motivation), v_caller_id,
    CASE WHEN v_transition_type = 1 THEN 'completed' ELSE 'open' END,
    v_expires_at,
    CASE WHEN v_transition_type = 1 THEN now() ELSE NULL END
  )
  RETURNING id INTO v_proposal_id;

  -- ===== Type 1 : auto-execute dans la transaction (doctrine D6) =====
  IF v_transition_type = 1 THEN
    -- Doctrine #141.2.E : NARRATIVE avant ETAT
    INSERT INTO public.library_profile_history (
      library_id, axis, old_value, new_value, changed_by, changed_at, change_reason
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

    -- Note : type 1 ne touche jamais a circulation_mode -> off (qui est type 4)
    -- ni a full_sigb -> informal (qui est type 4 aussi), donc pas d'archivage ici.

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

-- ============================================================================
-- 2. fn_execute_library_profile_change - ajout hooks archivage
-- ============================================================================
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
  -- ===== Lecture proposal avec lock =====
  SELECT * INTO v_proposal
  FROM public.library_profile_proposals
  WHERE id = p_proposal_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'EXECUTE_PROPOSAL_NOT_FOUND : proposition introuvable (%)', p_proposal_id
      USING ERRCODE = 'no_data_found',
            HINT    = 'error.profile_change.proposal_not_found';
  END IF;

  -- ===== Garde-fou 1 : auth (staff biblio) OU appel cron systeme =====
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

  -- ===== Garde-fou 2 : status acceptable =====
  IF v_proposal.status NOT IN ('accepted_unanimous', 'accepted_majority') THEN
    RAISE EXCEPTION 'EXECUTE_PROPOSAL_NOT_ACCEPTED : proposition pas executable (status=%)', v_proposal.status
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.not_accepted';
  END IF;

  -- ===== Garde-fou 3 : carence echue =====
  IF v_proposal.grace_period_until IS NULL OR v_proposal.grace_period_until > now() THEN
    RAISE EXCEPTION 'EXECUTE_GRACE_PERIOD_ACTIVE : carence active jusqu''a %', v_proposal.grace_period_until
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.grace_period_active';
  END IF;

  -- ===== DOCTRINE #141.2.E : NARRATIVE avant ETAT =====
  -- 1. INSERT library_profile_history (audit narratif AVANT bascule)
  INSERT INTO public.library_profile_history (
    library_id, axis, old_value, new_value, changed_by, changed_at, change_reason
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

  -- 2. UPDATE libraries (l'etat bascule)
  IF    v_proposal.axis = 'catalog_mode'     THEN UPDATE public.libraries SET catalog_mode     = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'circulation_mode' THEN UPDATE public.libraries SET circulation_mode = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'network_mode'     THEN UPDATE public.libraries SET network_mode     = v_proposal.new_value WHERE id = v_proposal.library_id;
  ELSIF v_proposal.axis = 'governance_mode'  THEN UPDATE public.libraries SET governance_mode  = v_proposal.new_value WHERE id = v_proposal.library_id;
  END IF;

  -- ===== D.6 : Hooks archivage selon le type de transition =====
  -- Cas 1 : circulation_mode -> 'off' (depuis 'informal' ou 'full_sigb')
  --         Archivage complet de la circulation vivante.
  IF v_proposal.axis = 'circulation_mode' AND v_proposal.new_value = 'off' THEN
    v_archive_result := public.fn_archive_library_circulation(
      v_proposal.library_id,
      p_proposal_id
    );
  END IF;

  -- Cas 2 : circulation_mode: 'full_sigb' -> 'informal'
  --         Archivage des cotisations en cours uniquement.
  --         (les prets restent en cours, juste les rappels mail sont
  --          desactives ailleurs par effet de circulation_mode change).
  IF v_proposal.axis = 'circulation_mode'
     AND v_proposal.old_value = 'full_sigb'
     AND v_proposal.new_value = 'informal' THEN
    v_archive_result := public.fn_archive_library_cotisations(
      v_proposal.library_id,
      p_proposal_id
    );
  END IF;

  -- 3. UPDATE proposal status='completed'
  UPDATE public.library_profile_proposals
  SET status       = 'completed',
      completed_at = now()
  WHERE id = p_proposal_id;

  -- 4. UPDATE grace_locks released_at
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
    'archive_result',       v_archive_result  -- NULL si pas d'archivage applique
  );
END;
$function$;

-- ============================================================================
-- DO block de verification fail-fast
-- ============================================================================
DO $verif$
DECLARE
  v_def_propose text;
  v_def_execute text;
BEGIN
  -- Verifier que le refus type 4 est bien retire de fn_propose
  SELECT pg_get_functiondef(p.oid) INTO v_def_propose
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_propose_library_profile_change';
  IF v_def_propose ILIKE '%PROPOSE_TYPE_4_REQUIRES_PACKAGE_D%' THEN
    RAISE EXCEPTION 'VERIF_FAIL_A : le refus type 4 est toujours present dans fn_propose_library_profile_change';
  END IF;

  -- Verifier que les hooks archivage sont bien dans fn_execute
  SELECT pg_get_functiondef(p.oid) INTO v_def_execute
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_execute_library_profile_change';
  IF v_def_execute NOT ILIKE '%fn_archive_library_circulation%' THEN
    RAISE EXCEPTION 'VERIF_FAIL_B : hook fn_archive_library_circulation manquant dans fn_execute';
  END IF;
  IF v_def_execute NOT ILIKE '%fn_archive_library_cotisations%' THEN
    RAISE EXCEPTION 'VERIF_FAIL_C : hook fn_archive_library_cotisations manquant dans fn_execute';
  END IF;

  RAISE NOTICE 'Paquet D.6 - Verification OK : refus type 4 retire, hooks archivage en place';
END
$verif$;

COMMIT;
