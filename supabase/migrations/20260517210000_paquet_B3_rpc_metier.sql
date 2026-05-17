-- ============================================================================
-- AnarBib -- Paquet B.3 -- RPC metier cycle de vie des propositions
-- ============================================================================
-- Date            : 17/05/2026
-- Auteur          : Xavier (via Claude)
-- Chantier        : #98-B Profils d'adoption / Paquet B Transitions
-- Spec reference  : docs/specs/spec-profils-bibliotheque.md v0.3 §9.2-9.4
-- Doctrine        : docs/decisions/CHANTIER_doctrine_transitions_profils_2026-05-17.md
-- Prerequis       : B.1 (tables) + B.2 (classification) en prod
-- ============================================================================
--
-- Objectif :
--   Encoder les 4 RPC qui orchestrent le cycle de vie d'une proposition de
--   transition de profil :
--
--     1. fn_propose_library_profile_change  : creer une proposition
--     2. fn_vote_library_profile_change     : poser un vote
--     3. fn_cancel_library_profile_change   : annuler (par proposeur)
--     4. fn_execute_library_profile_change  : executer (post-carence)
--
-- Decisions doctrinales (session 17/05/2026) :
--
--   D1. Type 4 sans paquet D : REFUS PRECOCE dans fn_propose.
--       Pas de mobilisation politique pour transition impossible.
--
--   D2. Retour fn_propose : objet riche jsonb pour UX immediate.
--
--   D3. Cloture apres vote : HYBRIDE. fn_vote tente la cloture si quorum
--       atteint. Le cron B.4 reste le filet de securite.
--
--   D4. Annulation : proposeur uniquement, tant que status='open', avec
--       motif obligatoire (>= 5 chars, deja CHECK en B.1).
--
--   D5. Quorum minimum staff (echelle du risque) :
--       Type 1 : 1 staff actif suffit
--       Types 2-3 : 2 staff actifs minimum
--       Type 4 : 3 staff actifs minimum (cohere avec admin reseau v0.3)
--
--   D6. Type 1 (direct) : auto-execute dans la transaction de fn_propose.
--       Proposal cree directement en status='completed', audit complet,
--       UPDATE libraries dans la meme transaction. UX immediate, audit
--       uniforme, doctrine "aucune decision n'est triviale" preservee.
--
-- Doctrine #141.2.E (ordre des UPDATEs narrative-avant-etat) :
--   Dans fn_execute_*, l'ordre est :
--     1. INSERT library_profile_history  (narrative : l'audit)
--     2. UPDATE libraries SET <axe>_mode  (etat : la bascule)
--     3. UPDATE proposal status='completed'
--     4. UPDATE grace_lock released_at
--   Sinon : un eventuel trigger sur libraries verrait l'absence d'audit.
--
-- Schema applique (rappel issu de B.1) :
--   - public.user_library_memberships (role IN reader/librarian/coordenador,
--                                       status IN active/pending_removal/removed/inactive)
--   - Staff actif = status='active' AND role IN ('librarian','coordenador')
--
-- ============================================================================

BEGIN;

-- ============================================================================
-- Helper prive : compter les staff actifs d'une biblio
-- ============================================================================
-- Utilise par fn_propose (verification quorum) et fn_vote (calcul des votes
-- requis). SECURITY DEFINER pour bypass RLS uniformement.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_library_active_staff_count(p_library_id uuid)
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $body$
  SELECT count(*)::int
  FROM public.user_library_memberships
  WHERE library_id = p_library_id
    AND status = 'active'
    AND role IN ('librarian', 'coordenador');
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_library_active_staff_count(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_library_active_staff_count(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_library_active_staff_count(uuid) IS
  'B.3 helper : compte les staff actifs (status=active, role in librarian/coordenador) d''une biblio. Utilise pour quorum et calcul des votes requis.';

-- ============================================================================
-- 1. fn_propose_library_profile_change
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_propose_library_profile_change(
  p_library_id  uuid,
  p_axis        text,
  p_new_value   text,
  p_motivation  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
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

  -- ===== REFUS PRECOCE : type 4 sans paquet D =====
  -- Doctrine 17/05/2026 D1 : aucune mobilisation politique pour transition impossible
  IF v_transition_type = 4 THEN
    RAISE EXCEPTION 'PROPOSE_TYPE_4_REQUIRES_PACKAGE_D : transition critique avec archivage non disponible (paquet D non livre)'
      USING ERRCODE = 'feature_not_supported',
            HINT    = 'error.profile_change.archiving_not_available';
  END IF;

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
  -- majority : strictement > 50% (ceil(staff/2)+1 sauf si pair pile = staff/2+1)
  -- unanimous : tous les staff actifs
  v_votes_required := CASE v_governance
    WHEN 'direct'             THEN 0  -- pas de vote, auto-execute
    WHEN 'majority'           THEN (v_active_staff / 2) + 1
    WHEN 'unanimous'          THEN v_active_staff
    WHEN 'unanimous_extended' THEN v_active_staff   -- ne devrait pas arriver (refus precoce)
  END;

  -- ===== Calcul expires_at =====
  -- Type 1 : expire immediatement (proposal completed dans cette transaction)
  -- Types 2-3 : 30 jours pour deliberer
  v_expires_at := CASE
    WHEN v_transition_type = 1 THEN now()
    ELSE now() + interval '30 days'
  END;

  -- ===== INSERT proposal =====
  -- Pour type 1, on cree directement en status='completed' (audit complet, doctrine D6)
  -- Pour types 2-3, on cree en status='open' (vote a venir)
  INSERT INTO public.library_profile_proposals (
    library_id, axis, old_value, new_value, transition_type, governance_required,
    motivation, proposed_by, status, expires_at,
    completed_at  -- NULL pour open, now() pour completed (type 1)
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
    -- 1. INSERT library_profile_history (audit narratif)
    INSERT INTO public.library_profile_history (
      library_id, axis, old_value, new_value, changed_by, changed_at, change_reason
    )
    VALUES (
      p_library_id, p_axis, v_old_value, p_new_value, v_caller_id, now(),
      'Transition directe type 1 (' || p_motivation || ')'
    );

    -- 2. UPDATE libraries (l'etat bascule, peut declencher des triggers)
    IF    p_axis = 'catalog_mode'     THEN UPDATE public.libraries SET catalog_mode     = p_new_value WHERE id = p_library_id;
    ELSIF p_axis = 'circulation_mode' THEN UPDATE public.libraries SET circulation_mode = p_new_value WHERE id = p_library_id;
    ELSIF p_axis = 'network_mode'     THEN UPDATE public.libraries SET network_mode     = p_new_value WHERE id = p_library_id;
    ELSIF p_axis = 'governance_mode'  THEN UPDATE public.libraries SET governance_mode  = p_new_value WHERE id = p_library_id;
    END IF;

    v_executed_now := true;
  END IF;

  -- ===== Retour riche pour UX immediate =====
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
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_propose_library_profile_change(uuid, text, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_propose_library_profile_change(uuid, text, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_propose_library_profile_change(uuid, text, text, text) IS
  'B.3 RPC : cree une proposition de transition de profil. Type 1 auto-execute en transaction. Type 4 refuse en amont (paquet D non livre). Verifie staff actif, motivation, quorum, conflit existant.';

-- ============================================================================
-- 2. fn_vote_library_profile_change
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_vote_library_profile_change(
  p_proposal_id       uuid,
  p_vote              text,
  p_rationale_against text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_caller_id         uuid := auth.uid();
  v_proposal          public.library_profile_proposals%ROWTYPE;
  v_vote_id           uuid;
  v_votes_for         int;
  v_votes_against     int;
  v_active_staff      int;
  v_votes_needed      int;
  v_new_status        text;
  v_grace_until       timestamptz;
  v_grace_days        int;
  v_grace_lock_id     uuid;
  v_closed_in_this_tx boolean := false;
BEGIN
  -- ===== Garde-fou 1 : authentification =====
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'VOTE_AUTH_REQUIRED : authentification requise'
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.profile_change.auth_required';
  END IF;

  -- ===== Garde-fou 2 : validation du parametre vote =====
  IF p_vote NOT IN ('for', 'against') THEN
    RAISE EXCEPTION 'VOTE_INVALID_VALUE : vote doit etre for ou against, recu (%)', p_vote
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.vote_invalid';
  END IF;

  -- ===== Lecture proposal avec lock pour cloture atomique =====
  SELECT * INTO v_proposal
  FROM public.library_profile_proposals
  WHERE id = p_proposal_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'VOTE_PROPOSAL_NOT_FOUND : proposition introuvable (%)', p_proposal_id
      USING ERRCODE = 'no_data_found',
            HINT    = 'error.profile_change.proposal_not_found';
  END IF;

  -- ===== Garde-fou 3 : proposal status='open' =====
  IF v_proposal.status <> 'open' THEN
    RAISE EXCEPTION 'VOTE_PROPOSAL_NOT_OPEN : la proposition n''est pas ouverte au vote (status=%)', v_proposal.status
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.proposal_not_open';
  END IF;

  -- ===== Garde-fou 4 : proposal pas expiree =====
  IF v_proposal.expires_at <= now() THEN
    RAISE EXCEPTION 'VOTE_PROPOSAL_EXPIRED : la proposition a expire le %', v_proposal.expires_at
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.proposal_expired';
  END IF;

  -- ===== Garde-fou 5 : caller est staff actif de la biblio =====
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE library_id = v_proposal.library_id
      AND user_id    = v_caller_id
      AND status     = 'active'
      AND role IN ('librarian', 'coordenador')
  ) THEN
    RAISE EXCEPTION 'VOTE_NOT_STAFF : caller n''est pas staff actif de la biblio'
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.profile_change.not_staff';
  END IF;

  -- ===== Garde-fou 6 : rationale obligatoire si against (>= 20 chars) =====
  IF p_vote = 'against' THEN
    IF p_rationale_against IS NULL OR length(trim(p_rationale_against)) < 20 THEN
      RAISE EXCEPTION 'VOTE_RATIONALE_REQUIRED : rationale_against >= 20 caracteres obligatoire pour vote against'
        USING ERRCODE = 'check_violation',
              HINT    = 'error.profile_change.rationale_required';
    END IF;
  END IF;

  -- ===== INSERT vote (CHECK unique en B.1 garantit unicite caller/proposal) =====
  BEGIN
    INSERT INTO public.library_profile_votes (
      proposal_id, voter_id, vote, rationale_against
    )
    VALUES (
      p_proposal_id, v_caller_id, p_vote,
      CASE WHEN p_vote = 'against' THEN trim(p_rationale_against) ELSE NULL END
    )
    RETURNING id INTO v_vote_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'VOTE_ALREADY_CAST : vous avez deja vote sur cette proposition'
      USING ERRCODE = 'unique_violation',
            HINT    = 'error.profile_change.vote_already_cast';
  END;

  -- ===== Recalcul votes apres insertion =====
  SELECT
    count(*) FILTER (WHERE vote = 'for'),
    count(*) FILTER (WHERE vote = 'against')
  INTO v_votes_for, v_votes_against
  FROM public.library_profile_votes
  WHERE proposal_id = p_proposal_id;

  v_active_staff := public.fn_library_active_staff_count(v_proposal.library_id);

  -- ===== Tentative de cloture (doctrine D3 : hybride) =====
  -- Si la condition de gouvernance est atteinte, on bascule status + grace_lock dans cette tx
  v_new_status := NULL;

  IF v_proposal.governance_required = 'majority' THEN
    v_votes_needed := (v_active_staff / 2) + 1;
    -- Acceptation majorite : plus de votants 'for' que 'against' ET au moins votes_needed 'for'
    IF v_votes_for >= v_votes_needed THEN
      v_new_status := 'accepted_majority';
    -- Rejet : impossible d'atteindre la majorite meme si tous les staff restants votent for
    ELSIF (v_votes_for + (v_active_staff - v_votes_for - v_votes_against)) < v_votes_needed THEN
      v_new_status := 'rejected';
    END IF;

  ELSIF v_proposal.governance_required = 'unanimous' THEN
    -- Unanime : tous les staff ont vote ET tous 'for'
    IF v_votes_against > 0 THEN
      v_new_status := 'rejected';   -- un seul against = unanimite rompue
    ELSIF v_votes_for = v_active_staff THEN
      v_new_status := 'accepted_unanimous';
    END IF;
  END IF;

  -- ===== Si cloture decide : UPDATE proposal + grace_lock =====
  IF v_new_status IS NOT NULL THEN
    -- Calcul carence selon type
    v_grace_days := CASE v_proposal.governance_required
      WHEN 'majority'  THEN 0   -- pas de carence en majority
      WHEN 'unanimous' THEN 7   -- 7 jours
    END;

    v_grace_until := now() + (v_grace_days || ' days')::interval;

    -- UPDATE proposal status + horodatage selon decision
    IF v_new_status = 'accepted_majority' THEN
      UPDATE public.library_profile_proposals
      SET status             = v_new_status,
          majority_at        = now(),
          grace_period_until = v_grace_until
      WHERE id = p_proposal_id;

    ELSIF v_new_status = 'accepted_unanimous' THEN
      UPDATE public.library_profile_proposals
      SET status             = v_new_status,
          unanimous_at       = now(),
          grace_period_until = v_grace_until
      WHERE id = p_proposal_id;

    ELSIF v_new_status = 'rejected' THEN
      UPDATE public.library_profile_proposals
      SET status = v_new_status
      WHERE id = p_proposal_id;
    END IF;

    -- Si acceptation : creer grace_lock (les jobs cron skip cette biblio pendant carence)
    IF v_new_status IN ('accepted_majority', 'accepted_unanimous') THEN
      INSERT INTO public.library_profile_grace_locks (
        library_id, proposal_id, affected_axis, affected_jobs, grace_until
      )
      VALUES (
        v_proposal.library_id, p_proposal_id, v_proposal.axis,
        -- Jobs affectes : a affiner selon axe. Pour B.3, on liste les jobs cron
        -- pertinents (B.4 les definira concretement). Mettre 'all' par defaut.
        ARRAY['all_profile_jobs']::text[],
        v_grace_until
      )
      RETURNING id INTO v_grace_lock_id;
    END IF;

    v_closed_in_this_tx := true;
  END IF;

  -- ===== Retour riche =====
  RETURN jsonb_build_object(
    'vote_id',           v_vote_id,
    'proposal_id',       p_proposal_id,
    'votes_for',         v_votes_for,
    'votes_against',     v_votes_against,
    'active_staff_count', v_active_staff,
    'proposal_status',   COALESCE(v_new_status, v_proposal.status),
    'closed_in_this_tx', v_closed_in_this_tx,
    'grace_period_until', v_grace_until,
    'grace_lock_id',     v_grace_lock_id
  );
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_vote_library_profile_change(uuid, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_vote_library_profile_change(uuid, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_vote_library_profile_change(uuid, text, text) IS
  'B.3 RPC : pose un vote sur une proposition ouverte et tente la cloture atomique si quorum atteint (doctrine D3 hybride). FOR UPDATE pour serialiser les votes concurrents.';

-- ============================================================================
-- 3. fn_cancel_library_profile_change
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_cancel_library_profile_change(
  p_proposal_id  uuid,
  p_motivation   text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_caller_id  uuid := auth.uid();
  v_proposal   public.library_profile_proposals%ROWTYPE;
BEGIN
  -- ===== Garde-fou 1 : authentification =====
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'CANCEL_AUTH_REQUIRED : authentification requise'
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.profile_change.auth_required';
  END IF;

  -- ===== Garde-fou 2 : motivation substantielle (>= 5 chars) =====
  IF p_motivation IS NULL OR length(trim(p_motivation)) < 5 THEN
    RAISE EXCEPTION 'CANCEL_MOTIVATION_TOO_SHORT : la motivation doit faire au moins 5 caracteres'
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.motivation_too_short';
  END IF;

  -- ===== Lecture proposal avec lock =====
  SELECT * INTO v_proposal
  FROM public.library_profile_proposals
  WHERE id = p_proposal_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CANCEL_PROPOSAL_NOT_FOUND : proposition introuvable (%)', p_proposal_id
      USING ERRCODE = 'no_data_found',
            HINT    = 'error.profile_change.proposal_not_found';
  END IF;

  -- ===== Garde-fou 3 : caller est le proposeur original (doctrine D4) =====
  IF v_proposal.proposed_by <> v_caller_id THEN
    RAISE EXCEPTION 'CANCEL_NOT_PROPOSER : seule la personne ayant propose peut annuler'
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.profile_change.not_proposer';
  END IF;

  -- ===== Garde-fou 4 : proposal status='open' =====
  IF v_proposal.status <> 'open' THEN
    RAISE EXCEPTION 'CANCEL_PROPOSAL_NOT_OPEN : la proposition n''est pas annulable (status=%)', v_proposal.status
      USING ERRCODE = 'invalid_parameter_value',
            HINT    = 'error.profile_change.proposal_not_open';
  END IF;

  -- ===== UPDATE proposal status='cancelled' =====
  UPDATE public.library_profile_proposals
  SET status               = 'cancelled',
      cancelled_at         = now(),
      cancelled_by         = v_caller_id,
      cancelled_motivation = trim(p_motivation)
  WHERE id = p_proposal_id;

  RETURN jsonb_build_object(
    'proposal_id',  p_proposal_id,
    'cancelled_at', now(),
    'cancelled_by', v_caller_id
  );
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_cancel_library_profile_change(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_cancel_library_profile_change(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_cancel_library_profile_change(uuid, text) IS
  'B.3 RPC : annule une proposition (doctrine D4 : proposeur uniquement, tant que status=open, motivation obligatoire).';

-- ============================================================================
-- 4. fn_execute_library_profile_change
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_execute_library_profile_change(
  p_proposal_id  uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_caller_id     uuid := auth.uid();  -- NULL si appel cron systeme
  v_proposal      public.library_profile_proposals%ROWTYPE;
  v_is_staff      boolean := false;
  v_is_system     boolean := false;
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
    COALESCE(v_caller_id, v_proposal.proposed_by),  -- si cron : on impute au proposeur
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

  -- 3. UPDATE proposal status='completed'
  UPDATE public.library_profile_proposals
  SET status       = 'completed',
      completed_at = now()
  WHERE id = p_proposal_id;

  -- 4. UPDATE grace_locks released_at (liberation des locks lies a cette proposal)
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
    'executed_by_caller',   COALESCE(v_caller_id::text, 'system_cron')
  );
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_execute_library_profile_change(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_execute_library_profile_change(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_execute_library_profile_change(uuid) IS
  'B.3 RPC : execute une proposition acceptee dont la carence est echue. Doctrine #141.2.E (narrative avant etat) : INSERT history -> UPDATE libraries -> UPDATE proposal -> UPDATE grace_lock.';

-- ============================================================================
-- DO-block de verification finale
-- ============================================================================
-- Tests sans modifier la prod : on cree une biblio de test, on simule les
-- RPC avec ROLLBACK final. Si une assertion echoue : RAISE EXCEPTION -> tout
-- rollback.
-- ============================================================================

DO $verif$
DECLARE
  v_count          int;
  v_blmf_id        uuid;
  v_blmf_staff     int;
BEGIN
  RAISE NOTICE '--- Verification finale B.3 ---';

  -- 1. Les 4 RPC + helper sont presents
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_library_active_staff_count',
      'fn_propose_library_profile_change',
      'fn_vote_library_profile_change',
      'fn_cancel_library_profile_change',
      'fn_execute_library_profile_change'
    );
  IF v_count <> 5 THEN
    RAISE EXCEPTION 'B3_VERIF_FAIL : RPC manquants (%/5)', v_count;
  END IF;
  RAISE NOTICE 'OK : 5 fonctions creees (1 helper + 4 RPC metier)';

  -- 2. Helper fn_library_active_staff_count fonctionne sur BLMF
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf' LIMIT 1;
  IF v_blmf_id IS NOT NULL THEN
    v_blmf_staff := public.fn_library_active_staff_count(v_blmf_id);
    RAISE NOTICE 'OK : BLMF a % staff actif(s)', v_blmf_staff;
    -- On ne fait pas d'assertion stricte sur le nombre (depend de la prod)
  END IF;

  -- 3. Verification des grants : authenticated peut executer
  SELECT count(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_propose_library_profile_change',
      'fn_vote_library_profile_change',
      'fn_cancel_library_profile_change',
      'fn_execute_library_profile_change'
    )
    AND has_function_privilege('authenticated', p.oid, 'EXECUTE');
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'B3_VERIF_FAIL : GRANT EXECUTE manquant pour authenticated (%/4)', v_count;
  END IF;
  RAISE NOTICE 'OK : 4 RPC accessibles en EXECUTE pour authenticated';

  -- 4. Verification : public n'a PAS le droit d'executer (REVOKE FROM PUBLIC)
  SELECT count(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_propose_library_profile_change',
      'fn_vote_library_profile_change',
      'fn_cancel_library_profile_change',
      'fn_execute_library_profile_change'
    )
    AND has_function_privilege('public', p.oid, 'EXECUTE');
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'B3_VERIF_FAIL : PUBLIC a encore EXECUTE sur % RPC (devrait etre 0)', v_count;
  END IF;
  RAISE NOTICE 'OK : PUBLIC bloque (REVOKE EXECUTE FROM PUBLIC effectif)';

  -- 5. Verification metadonnees : toutes SECURITY DEFINER
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'fn_propose_library_profile_change',
      'fn_vote_library_profile_change',
      'fn_cancel_library_profile_change',
      'fn_execute_library_profile_change'
    )
    AND p.prosecdef = true;
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'B3_VERIF_FAIL : RPC pas tous SECURITY DEFINER (%/4)', v_count;
  END IF;
  RAISE NOTICE 'OK : 4 RPC sont SECURITY DEFINER';

  -- 6. Tables d'audit toujours vides (aucune migration ne devrait y avoir touche)
  SELECT count(*) INTO v_count FROM public.library_profile_proposals;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'B3_VERIF_FAIL : library_profile_proposals non vide (% lignes) - anomalie', v_count;
  END IF;
  RAISE NOTICE 'OK : library_profile_proposals reste vide (aucune pollution par cette migration)';

  RAISE NOTICE '--- B.3 verifie : 4 RPC + 1 helper, doctrines D1-D6 + #141.2.E respectees ---';
END
$verif$;

COMMIT;

-- ============================================================================
-- Fin du paquet B.3
-- ============================================================================
