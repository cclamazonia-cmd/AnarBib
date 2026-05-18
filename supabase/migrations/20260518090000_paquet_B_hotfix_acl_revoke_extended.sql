-- ============================================================================
-- Migration : 20260518090000_paquet_B_hotfix_acl_revoke_extended.sql
-- Chantier  : #98-B Paquet B Transitions de profils — hotfix ACL
-- Date      : 18 mai 2026
-- Contexte  : reprise session B.5+B.6, vérifications préalables (18/05 matin)
-- ============================================================================
--
-- PROBLÈME DIAGNOSTIQUÉ (vérif #3 [B-functions-acl]) :
--   Les 7 fonctions non-cron du paquet B (B.2 helpers + B.3 RPC) ont
--   has_function_privilege('anon', ...) = true et idem pour 'service_role'.
--
-- CAUSE : doctrine mémoire #19. À la création d'une fonction dans `public`,
--   ALTER DEFAULT PRIVILEGES (configuré par Supabase au niveau projet) accorde
--   automatiquement EXECUTE à anon/authenticated/service_role. Un REVOKE FROM
--   PUBLIC seul NE SUFFIT PAS — il faut REVOKE FROM PUBLIC, anon, service_role
--   explicitement, puis GRANT TO authenticated uniquement.
--
--   Les fonctions cron (fn_expire_overdue_*, fn_execute_due_*) ont déjà été
--   corrigées lors du hotfix B.4 v2 (commit 13bcb… amend). Cette migration
--   applique le même fix aux 7 fonctions oubliées.
--
-- IMPACT FONCTIONNEL : aucun.
--   - Les RPC métier (propose/vote/cancel/execute) levaient déjà une exception
--     `auth_required` quand auth.uid() IS NULL (défense en profondeur métier).
--   - Cette migration ajoute la défense en profondeur ACL : un anon ne peut
--     même plus invoquer la fonction (erreur permission denied avant le RAISE).
--   - authenticated conserve EXECUTE (RPC + helpers callés depuis frontend OK).
--
-- DOCTRINES APPLIQUÉES :
--   - Mémoire #19 (REVOKE étendu PUBLIC + anon + service_role)
--   - docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
--   - DO block de vérification final (fail-fast en transaction)
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Helpers de classification (B.2)
-- ----------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_classify_transition(
  p_axis text, p_old_value text, p_new_value text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.fn_classify_transition(
  p_axis text, p_old_value text, p_new_value text
) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.fn_required_governance_for_transition(
  p_library_id uuid, p_axis text, p_new_value text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.fn_required_governance_for_transition(
  p_library_id uuid, p_axis text, p_new_value text
) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.fn_library_active_staff_count(
  p_library_id uuid
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.fn_library_active_staff_count(
  p_library_id uuid
) TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. RPC métier (B.3)
-- ----------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_propose_library_profile_change(
  p_library_id uuid, p_axis text, p_new_value text, p_motivation text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.fn_propose_library_profile_change(
  p_library_id uuid, p_axis text, p_new_value text, p_motivation text
) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.fn_vote_library_profile_change(
  p_proposal_id uuid, p_vote text, p_rationale_against text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.fn_vote_library_profile_change(
  p_proposal_id uuid, p_vote text, p_rationale_against text
) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.fn_cancel_library_profile_change(
  p_proposal_id uuid, p_motivation text
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.fn_cancel_library_profile_change(
  p_proposal_id uuid, p_motivation text
) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.fn_execute_library_profile_change(
  p_proposal_id uuid
) FROM PUBLIC, anon, service_role;

GRANT EXECUTE ON FUNCTION public.fn_execute_library_profile_change(
  p_proposal_id uuid
) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. DO block de vérification (fail-fast)
--
-- Doctrine : toute migration touchant permissions/policies/search_path doit
-- inclure un bloc de vérif en simulé anon/authenticated qui RAISE EXCEPTION
-- en cas d'écart. RAISE EXCEPTION = auto-rollback de la transaction.
-- ----------------------------------------------------------------------------

DO $verif$
DECLARE
  v_fn record;
  v_anon_can boolean;
  v_authd_can boolean;
  v_svc_can boolean;
  v_total_violations int := 0;
BEGIN
  FOR v_fn IN
    SELECT p.proname, p.oid
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'fn_classify_transition',
        'fn_required_governance_for_transition',
        'fn_library_active_staff_count',
        'fn_propose_library_profile_change',
        'fn_vote_library_profile_change',
        'fn_cancel_library_profile_change',
        'fn_execute_library_profile_change'
      )
  LOOP
    v_anon_can  := has_function_privilege('anon',          v_fn.oid, 'EXECUTE');
    v_authd_can := has_function_privilege('authenticated', v_fn.oid, 'EXECUTE');
    v_svc_can   := has_function_privilege('service_role',  v_fn.oid, 'EXECUTE');

    IF v_anon_can THEN
      RAISE WARNING 'VIOLATION : % accessible à anon', v_fn.proname;
      v_total_violations := v_total_violations + 1;
    END IF;

    IF v_svc_can THEN
      RAISE WARNING 'VIOLATION : % accessible à service_role', v_fn.proname;
      v_total_violations := v_total_violations + 1;
    END IF;

    IF NOT v_authd_can THEN
      RAISE WARNING 'VIOLATION : % NON accessible à authenticated (devrait l''être)', v_fn.proname;
      v_total_violations := v_total_violations + 1;
    END IF;
  END LOOP;

  IF v_total_violations > 0 THEN
    RAISE EXCEPTION 'Hotfix ACL paquet B : % violations détectées, rollback', v_total_violations;
  END IF;

  RAISE NOTICE 'Hotfix ACL paquet B : 7 fonctions vérifiées, 0 violation. OK.';
END
$verif$;

COMMIT;
