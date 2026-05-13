-- ============================================================================
-- Paquet E.4.c - Vue api.collective_removal_proposals_current_v1
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Ref.  : docs/spec-administrateur-reseau.md v0.3 (retrait collectif D.6)
--
-- Contexte
-- --------
-- Le frontend E.4.c doit afficher la section "Propostas de retirada coletiva
-- em curso" dans AdminsPanel. Cette vue agrege en une lecture :
--   1. la proposition (id, status, motivation, dates, carence)
--   2. l'identite cible (proposed_user_id) via JOIN profiles
--   3. l'identite du proposeur (proposed_by) via JOIN profiles
--   4. l'identite de l'annulateur (cancelled_by) via JOIN profiles si applicable
--   5. le compte de votes (favor, against)
--   6. le denominateur unanimite (admins actifs hors target)
--   7. flags pour le caller (has_voted, is_target, is_proposer)
--
-- Status couverts : 'open' et 'unanimous' (carence en cours).
-- Status exclus : 'cancelled', 'executed', 'expired' (historises hors de
-- cette vue "current_v1", consultables via une vue "history" a creer
-- ulterieurement si besoin).
--
-- Doctrine v0.3 :
--   - SECURITY INVOKER : RLS sous-jacente (rls_crp_select) s'applique
--   - GRANT SELECT TO authenticated
--   - Symetrique de api.cooptation_proposals_current_v1 (E.4.b)
-- ============================================================================

BEGIN;

CREATE OR REPLACE VIEW api.collective_removal_proposals_current_v1 AS
WITH active_admin_count AS (
    SELECT count(*)::int AS total
    FROM public.network_administrators
    WHERE status = 'active'
)
SELECT
    p.id AS proposal_id,
    p.proposed_user_id,
    p.proposed_by,
    p.proposed_at,
    p.expires_at,
    p.motivation,
    p.status,
    p.unanimous_at,
    p.pending_removal_until,
    -- Identite cible
    target_profile.public_id   AS proposed_public_id,
    target_profile.first_name  AS proposed_first_name,
    target_profile.last_name   AS proposed_last_name,
    target_profile.email       AS proposed_email,
    -- Identite proposeur
    proposer_profile.public_id   AS proposer_public_id,
    proposer_profile.first_name  AS proposer_first_name,
    proposer_profile.last_name   AS proposer_last_name,
    proposer_profile.email       AS proposer_email,
    -- Comptes de votes
    (SELECT count(*) FROM public.network_admin_collective_removal_votes v
       WHERE v.proposal_id = p.id AND v.vote = 'favor')::int AS favor_count,
    (SELECT count(*) FROM public.network_admin_collective_removal_votes v
       WHERE v.proposal_id = p.id AND v.vote = 'against')::int AS against_count,
    -- Denominateur unanimite : admins actifs hors target
    -- (le target ne vote pas sur son propre retrait : doctrine v0.3)
    (SELECT total FROM active_admin_count) - (
        CASE WHEN EXISTS (
            SELECT 1 FROM public.network_administrators na
            WHERE na.user_id = p.proposed_user_id AND na.status = 'active'
        ) THEN 1 ELSE 0 END
    ) AS required_votes,
    -- Flags caller
    EXISTS (
        SELECT 1 FROM public.network_admin_collective_removal_votes v
        WHERE v.proposal_id = p.id AND v.voter_user_id = auth.uid()
    ) AS caller_has_voted,
    (p.proposed_user_id = auth.uid()) AS caller_is_target,
    (p.proposed_by = auth.uid()) AS caller_is_proposer
FROM public.network_admin_collective_removal_proposals p
LEFT JOIN public.profiles target_profile ON target_profile.id = p.proposed_user_id
LEFT JOIN public.profiles proposer_profile ON proposer_profile.id = p.proposed_by
WHERE p.status IN ('open', 'unanimous');

ALTER VIEW api.collective_removal_proposals_current_v1 SET (security_invoker = on);

GRANT SELECT ON api.collective_removal_proposals_current_v1 TO authenticated;

COMMENT ON VIEW api.collective_removal_proposals_current_v1 IS
'E.4.c v0.3 - Vue listing propositions de retrait collectif ouvertes (status=''open'' ou ''unanimous'') avec identites resolves, comptes de votes (favor/against), denominateur unanimite, flags caller. SECURITY INVOKER. Frontend : AdminsPanel section "Propostas de retirada coletiva".';

COMMIT;
