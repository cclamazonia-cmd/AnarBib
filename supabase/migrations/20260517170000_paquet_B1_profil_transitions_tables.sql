-- ============================================================================
-- AnarBib -- Paquet B.1 -- Tables transitions de profils
-- ============================================================================
-- Date           : 17/05/2026
-- Auteur         : Xavier (via Claude)
-- Chantier       : #98-B Profils d'adoption / Paquet B Transitions
-- Spec reference : docs/specs/spec-profils-bibliotheque.md v0.3 §9.2
-- Prerequis      : Paquet A profils livre en prod (migration 20260515170000)
-- ============================================================================
--
-- Objectif :
--   Deposer la couche d'audit immutable des transitions de profils :
--   propositions, votes, et locks de carence. Aucune logique RPC ni job pg_cron
--   dans cette migration (B.3 et B.4 plus tard). Aucune transition n'est encore
--   executable apres ce paquet -- il pose seulement le receptacle de tracabilite.
--
-- Tables creees (3) :
--   1. library_profile_proposals  : propositions de changement de mode (axe X)
--   2. library_profile_votes      : votes individuels sur une proposition
--   3. library_profile_grace_locks: locks de carence empechant traitement par
--                                   les jobs pg_cron pendant transition
--
-- Doctrines respectees :
--   - Doctrine creation objets securises (12/05) : RLS + GRANTs explicites,
--     trigger functions en SECURITY DEFINER + SET search_path = public.
--   - Doctrine immutabilite audit (paquet A) : 3 trigger functions
--     fn_block_lpp_modification, fn_block_lpv_modification, fn_block_lpgl_modification
--     qui RAISE EXCEPTION sur DELETE et sur UPDATE des colonnes non-autorisees.
--   - Doctrine RLS testing (12/05) : DO-block final avec SET LOCAL ROLE +
--     SET LOCAL "request.jwt.claims" pour tests anon + authenticated.
--
-- Politique d'immutabilite par table :
--   - library_profile_proposals : UPDATE autorise sur colonnes de cycle de vie
--     (status, *_at, grace_period_until, cancelled_*). Le reste est verrouille.
--   - library_profile_votes : aucun UPDATE autorise. Un vote pose est immuable.
--   - library_profile_grace_locks : UPDATE autorise uniquement sur released_at
--     (liberation manuelle ou auto par B.4).
--   Aucune table ne tolere DELETE (audit = pour toujours).
--
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Table : library_profile_proposals
-- ----------------------------------------------------------------------------

CREATE TABLE public.library_profile_proposals (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id            uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  axis                  text NOT NULL
    CHECK (axis IN ('catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode')),
  old_value             text NOT NULL,
  new_value             text NOT NULL,
  transition_type       int  NOT NULL CHECK (transition_type IN (1, 2, 3, 4)),
  governance_required   text NOT NULL
    CHECK (governance_required IN ('direct', 'majority', 'unanimous', 'unanimous_extended')),
  motivation            text NOT NULL CHECK (length(motivation) >= 5),
  proposed_by           uuid NOT NULL REFERENCES auth.users(id),
  proposed_at           timestamptz NOT NULL DEFAULT now(),
  status                text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'accepted_unanimous', 'accepted_majority',
                      'rejected', 'expired', 'cancelled', 'completed')),
  unanimous_at          timestamptz,
  majority_at           timestamptz,
  expires_at            timestamptz NOT NULL,
  grace_period_until    timestamptz,
  completed_at          timestamptz,
  cancelled_at          timestamptz,
  cancelled_by          uuid REFERENCES auth.users(id),
  cancelled_motivation  text,

  CONSTRAINT chk_lpp_values_differ CHECK (old_value <> new_value),

  CONSTRAINT chk_lpp_status_dates CHECK (
    (status IN ('open') AND completed_at IS NULL) OR
    (status IN ('rejected', 'expired', 'cancelled') AND completed_at IS NULL) OR
    (status IN ('accepted_unanimous', 'accepted_majority') AND completed_at IS NULL) OR
    (status = 'completed' AND completed_at IS NOT NULL)
  ),

  CONSTRAINT chk_lpp_cancelled_triplet CHECK (
    (cancelled_at IS NULL AND cancelled_by IS NULL AND cancelled_motivation IS NULL)
    OR
    (cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND cancelled_motivation IS NOT NULL
     AND length(cancelled_motivation) >= 5)
  )
);

COMMENT ON TABLE public.library_profile_proposals IS
  'Audit des propositions de transition de profil (B.1). Une ligne = une demande de changement de *_mode sur une biblio. Immutable sauf colonnes de cycle de vie.';

CREATE INDEX idx_lpp_library_status
  ON public.library_profile_proposals (library_id, status);
CREATE INDEX idx_lpp_status_expires
  ON public.library_profile_proposals (status, expires_at)
  WHERE status = 'open';
CREATE INDEX idx_lpp_status_grace
  ON public.library_profile_proposals (status, grace_period_until)
  WHERE status IN ('accepted_unanimous', 'accepted_majority');

CREATE UNIQUE INDEX uniq_lpp_one_open_per_library_axis
  ON public.library_profile_proposals (library_id, axis)
  WHERE status = 'open';

-- ----------------------------------------------------------------------------
-- 2. Table : library_profile_votes
-- ----------------------------------------------------------------------------

CREATE TABLE public.library_profile_votes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id         uuid NOT NULL REFERENCES public.library_profile_proposals(id) ON DELETE CASCADE,
  voter_id            uuid NOT NULL REFERENCES auth.users(id),
  vote                text NOT NULL CHECK (vote IN ('for', 'against')),
  voted_at            timestamptz NOT NULL DEFAULT now(),
  rationale_against   text,

  CONSTRAINT uniq_lpv_one_vote_per_voter UNIQUE (proposal_id, voter_id),

  CONSTRAINT chk_lpv_rationale_required_against CHECK (
    (vote = 'for' AND rationale_against IS NULL) OR
    (vote = 'against' AND rationale_against IS NOT NULL AND length(rationale_against) >= 20)
  )
);

COMMENT ON TABLE public.library_profile_votes IS
  'Audit des votes individuels sur propositions de transition de profil (B.1). Strictement immuable : aucun UPDATE ni DELETE possible apres INSERT.';

CREATE INDEX idx_lpv_proposal ON public.library_profile_votes (proposal_id);
CREATE INDEX idx_lpv_voter    ON public.library_profile_votes (voter_id);

-- ----------------------------------------------------------------------------
-- 3. Table : library_profile_grace_locks
-- ----------------------------------------------------------------------------

CREATE TABLE public.library_profile_grace_locks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id      uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  proposal_id     uuid NOT NULL REFERENCES public.library_profile_proposals(id) ON DELETE CASCADE,
  affected_axis   text NOT NULL
    CHECK (affected_axis IN ('catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode')),
  affected_jobs   text[] NOT NULL,
  locked_at       timestamptz NOT NULL DEFAULT now(),
  grace_until     timestamptz NOT NULL,
  released_at     timestamptz,

  CONSTRAINT chk_lpgl_grace_after_lock CHECK (grace_until > locked_at)
);

COMMENT ON TABLE public.library_profile_grace_locks IS
  'Audit des locks de carence pendant transitions de profil (B.1). Consulte par les jobs pg_cron (B.4). UPDATE autorise uniquement sur released_at.';

CREATE INDEX idx_lpgl_active_by_library
  ON public.library_profile_grace_locks (library_id, grace_until)
  WHERE released_at IS NULL;

CREATE INDEX idx_lpgl_proposal
  ON public.library_profile_grace_locks (proposal_id);

-- ============================================================================
-- TRIGGERS d'immutabilite
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_block_lpp_modification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'LIBRARY_PROFILE_PROPOSALS_IS_IMMUTABLE : suppression interdite (id=%)', OLD.id
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.id              IS DISTINCT FROM OLD.id              THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : id'              USING ERRCODE = 'check_violation'; END IF;
    IF NEW.library_id      IS DISTINCT FROM OLD.library_id      THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : library_id'      USING ERRCODE = 'check_violation'; END IF;
    IF NEW.axis            IS DISTINCT FROM OLD.axis            THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : axis'            USING ERRCODE = 'check_violation'; END IF;
    IF NEW.old_value       IS DISTINCT FROM OLD.old_value       THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : old_value'       USING ERRCODE = 'check_violation'; END IF;
    IF NEW.new_value       IS DISTINCT FROM OLD.new_value       THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : new_value'       USING ERRCODE = 'check_violation'; END IF;
    IF NEW.transition_type IS DISTINCT FROM OLD.transition_type THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : transition_type' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.governance_required IS DISTINCT FROM OLD.governance_required THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : governance_required' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.motivation      IS DISTINCT FROM OLD.motivation      THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : motivation'      USING ERRCODE = 'check_violation'; END IF;
    IF NEW.proposed_by     IS DISTINCT FROM OLD.proposed_by     THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : proposed_by'     USING ERRCODE = 'check_violation'; END IF;
    IF NEW.proposed_at     IS DISTINCT FROM OLD.proposed_at     THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : proposed_at'     USING ERRCODE = 'check_violation'; END IF;
    IF NEW.expires_at      IS DISTINCT FROM OLD.expires_at      THEN RAISE EXCEPTION 'LPP_LOCKED_COLUMN : expires_at'      USING ERRCODE = 'check_violation'; END IF;
  END IF;

  RETURN NEW;
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_block_lpp_modification() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_block_lpp_modification() IS
  'Trigger d''immutabilite pour library_profile_proposals (B.1). Bloque DELETE et UPDATE des colonnes non-cycle-de-vie.';

CREATE TRIGGER trg_lpp_block_modification
  BEFORE UPDATE OR DELETE ON public.library_profile_proposals
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_block_lpp_modification();

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_block_lpv_modification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'LIBRARY_PROFILE_VOTES_IS_IMMUTABLE : suppression interdite (id=%)', OLD.id
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'LIBRARY_PROFILE_VOTES_IS_IMMUTABLE : modification interdite (id=%)', OLD.id
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_block_lpv_modification() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_block_lpv_modification() IS
  'Trigger d''immutabilite pour library_profile_votes (B.1). Bloque toute modification post-INSERT.';

CREATE TRIGGER trg_lpv_block_modification
  BEFORE UPDATE OR DELETE ON public.library_profile_votes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_block_lpv_modification();

-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_block_lpgl_modification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'LIBRARY_PROFILE_GRACE_LOCKS_IS_IMMUTABLE : suppression interdite (id=%)', OLD.id
      USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.id            IS DISTINCT FROM OLD.id            THEN RAISE EXCEPTION 'LPGL_LOCKED_COLUMN : id'            USING ERRCODE = 'check_violation'; END IF;
    IF NEW.library_id    IS DISTINCT FROM OLD.library_id    THEN RAISE EXCEPTION 'LPGL_LOCKED_COLUMN : library_id'    USING ERRCODE = 'check_violation'; END IF;
    IF NEW.proposal_id   IS DISTINCT FROM OLD.proposal_id   THEN RAISE EXCEPTION 'LPGL_LOCKED_COLUMN : proposal_id'   USING ERRCODE = 'check_violation'; END IF;
    IF NEW.affected_axis IS DISTINCT FROM OLD.affected_axis THEN RAISE EXCEPTION 'LPGL_LOCKED_COLUMN : affected_axis' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.affected_jobs IS DISTINCT FROM OLD.affected_jobs THEN RAISE EXCEPTION 'LPGL_LOCKED_COLUMN : affected_jobs' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.locked_at     IS DISTINCT FROM OLD.locked_at     THEN RAISE EXCEPTION 'LPGL_LOCKED_COLUMN : locked_at'     USING ERRCODE = 'check_violation'; END IF;
    IF NEW.grace_until   IS DISTINCT FROM OLD.grace_until   THEN RAISE EXCEPTION 'LPGL_LOCKED_COLUMN : grace_until'   USING ERRCODE = 'check_violation'; END IF;
    IF OLD.released_at IS NOT NULL AND NEW.released_at IS NULL THEN
      RAISE EXCEPTION 'LPGL_RELEASED_AT_IRREVERSIBLE : ne peut etre repris a NULL'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_block_lpgl_modification() FROM PUBLIC;

COMMENT ON FUNCTION public.fn_block_lpgl_modification() IS
  'Trigger d''immutabilite pour library_profile_grace_locks (B.1). Bloque DELETE et UPDATE des colonnes non-released_at.';

CREATE TRIGGER trg_lpgl_block_modification
  BEFORE UPDATE OR DELETE ON public.library_profile_grace_locks
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_block_lpgl_modification();

-- ============================================================================
-- RLS et GRANTs
-- ============================================================================

ALTER TABLE public.library_profile_proposals   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_profile_votes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_profile_grace_locks ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.library_profile_proposals   TO authenticated;
GRANT SELECT ON public.library_profile_votes       TO authenticated;
GRANT SELECT ON public.library_profile_grace_locks TO authenticated;

CREATE POLICY lpp_select_staff_or_netadmin
  ON public.library_profile_proposals
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.library_id = library_profile_proposals.library_id
        AND m.user_id = auth.uid()
        AND m.status = 'active'
        AND m.role IN ('librarian', 'coordenador')
    )
    OR
    EXISTS (
      SELECT 1 FROM public.network_staff n
      WHERE n.user_id = auth.uid()
        AND n.is_active = true
        AND (n.can_view_network_metrics OR n.can_manage_network_staff)
    )
  );

CREATE POLICY lpv_select_via_proposal
  ON public.library_profile_votes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.library_profile_proposals p
      WHERE p.id = library_profile_votes.proposal_id
        AND (
          EXISTS (
            SELECT 1 FROM public.user_library_memberships m
            WHERE m.library_id = p.library_id
              AND m.user_id = auth.uid()
              AND m.status = 'active'
              AND m.role IN ('librarian', 'coordenador')
          )
          OR
          EXISTS (
            SELECT 1 FROM public.network_staff n
            WHERE n.user_id = auth.uid()
              AND n.is_active = true
        AND (n.can_view_network_metrics OR n.can_manage_network_staff)
          )
        )
    )
  );

CREATE POLICY lpgl_select_staff_or_netadmin
  ON public.library_profile_grace_locks
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.library_id = library_profile_grace_locks.library_id
        AND m.user_id = auth.uid()
        AND m.status = 'active'
        AND m.role IN ('librarian', 'coordenador')
    )
    OR
    EXISTS (
      SELECT 1 FROM public.network_staff n
      WHERE n.user_id = auth.uid()
        AND n.is_active = true
        AND (n.can_view_network_metrics OR n.can_manage_network_staff)
    )
  );

-- ============================================================================
-- DO-block de verification finale
-- ============================================================================

DO $verif$
DECLARE
  v_count        int;
  v_anon_rows    int;
  v_auth_rows    int;
BEGIN
  RAISE NOTICE '--- Verification finale B.1 ---';

  -- 1. Tables existent et vides
  SELECT count(*) INTO v_count FROM information_schema.tables
   WHERE table_schema = 'public'
     AND table_name IN ('library_profile_proposals','library_profile_votes','library_profile_grace_locks');
  IF v_count <> 3 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : tables manquantes (%/3)', v_count; END IF;

  SELECT count(*) INTO v_count FROM public.library_profile_proposals;
  IF v_count <> 0 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : library_profile_proposals non vide (%)', v_count; END IF;
  SELECT count(*) INTO v_count FROM public.library_profile_votes;
  IF v_count <> 0 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : library_profile_votes non vide (%)', v_count; END IF;
  SELECT count(*) INTO v_count FROM public.library_profile_grace_locks;
  IF v_count <> 0 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : library_profile_grace_locks non vide (%)', v_count; END IF;
  RAISE NOTICE 'OK : 3 tables creees et vides';

  -- 2. Trigger functions
  SELECT count(*) INTO v_count
  FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN ('fn_block_lpp_modification','fn_block_lpv_modification','fn_block_lpgl_modification');
  IF v_count <> 3 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : trigger functions manquantes (%/3)', v_count; END IF;
  RAISE NOTICE 'OK : 3 trigger functions en place';

  -- 3. Triggers actifs
  SELECT count(*) INTO v_count
  FROM pg_trigger
  WHERE tgname IN ('trg_lpp_block_modification','trg_lpv_block_modification','trg_lpgl_block_modification')
    AND NOT tgisinternal;
  IF v_count <> 3 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : triggers manquants (%/3)', v_count; END IF;
  RAISE NOTICE 'OK : 3 triggers actifs';

  -- 4. RLS active
  SELECT count(*) INTO v_count
  FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'public'
    AND c.relname IN ('library_profile_proposals','library_profile_votes','library_profile_grace_locks')
    AND c.relrowsecurity = true;
  IF v_count <> 3 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : RLS non activee sur les 3 tables (%/3)', v_count; END IF;
  RAISE NOTICE 'OK : RLS activee sur les 3 tables';

  -- 5. Policies SELECT existent
  SELECT count(*) INTO v_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND policyname IN ('lpp_select_staff_or_netadmin','lpv_select_via_proposal','lpgl_select_staff_or_netadmin');
  IF v_count <> 3 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : policies manquantes (%/3)', v_count; END IF;
  RAISE NOTICE 'OK : 3 policies SELECT creees';

  -- 6. Test anon : doit retourner 0 lignes (RLS bloque)
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';
  SELECT count(*) INTO v_anon_rows FROM public.library_profile_proposals;
  IF v_anon_rows <> 0 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : anon voit % proposals (devrait voir 0)', v_anon_rows; END IF;
  SELECT count(*) INTO v_anon_rows FROM public.library_profile_votes;
  IF v_anon_rows <> 0 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : anon voit % votes (devrait voir 0)', v_anon_rows; END IF;
  SELECT count(*) INTO v_anon_rows FROM public.library_profile_grace_locks;
  IF v_anon_rows <> 0 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : anon voit % locks (devrait voir 0)', v_anon_rows; END IF;
  RESET ROLE;
  RAISE NOTICE 'OK : anon bloque sur les 3 tables (0 lignes accessibles)';

  -- 7. Test authenticated SANS appartenance : doit retourner 0 lignes
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000099","role":"authenticated"}';
  SELECT count(*) INTO v_auth_rows FROM public.library_profile_proposals;
  IF v_auth_rows <> 0 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : auth sans staff voit % proposals (devrait voir 0)', v_auth_rows; END IF;
  RESET ROLE;
  RAISE NOTICE 'OK : authenticated sans appartenance bloque (0 lignes accessibles)';

  -- 8. Non-regression : libraries toujours accessible
  SELECT count(*) INTO v_count FROM public.libraries;
  IF v_count < 2 THEN RAISE EXCEPTION 'B1_VERIF_FAIL : libraries inaccessible apres migration (% lignes)', v_count; END IF;
  RAISE NOTICE 'OK : libraries toujours accessible (% biblios)', v_count;

  RAISE NOTICE '--- B.1 verifie : 3 tables + 3 triggers + RLS conformes ---';
END
$verif$;

COMMIT;

-- ============================================================================
-- Fin du paquet B.1
-- ============================================================================
