-- ============================================================================
-- Paquet E.4.b - Vue api.cooptation_proposals_current_v1
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Ref.  : docs/spec-administrateur-reseau.md v0.3 (cooptation D.5)
--
-- Contexte
-- --------
-- Le frontend E.4.b doit afficher la section "Propostas em curso" dans
-- AdminsPanel, listant les propositions de cooptation ouvertes (status='open').
-- Cette vue agrege en une seule lecture :
--   1. la proposition elle-meme (id, status, motivation, dates)
--   2. l'identite de la personne proposee (proposed_user_id) via JOIN profiles
--   3. l'identite du proposeur (proposed_by) via JOIN profiles
--   4. le compte de votes (favorable, opposed, abstain)
--   5. le compte d'admins reseau actifs (denominateur unanimite, hors target)
--   6. si l'appelant a deja vote
--
-- Doctrine v0.3 :
--   - SECURITY INVOKER : la vue respecte la RLS de la table sous-jacente
--     (proposals_select_admins_or_proposed : admins reseau actifs + target)
--   - GRANT SELECT TO authenticated (filtrage assure par la RLS de la table)
--   - Ne montre QUE les propositions status='open' (les autres sont historisees
--     mais hors de cette vue "current_v1")
--   - Pas d'expose direct des UUIDs internes : utilise public_id quand
--     possible. Mais user_id reste necessaire pour l'identification du
--     callsite (vote, equality checks)
--
-- Effet en prod : aucun. Aucune proposition de cooptation actuellement
-- ouverte en DB. La vue retournera 0 lignes tant que personne ne propose.
-- ============================================================================

BEGIN;

CREATE OR REPLACE VIEW api.cooptation_proposals_current_v1 AS
WITH active_admin_count AS (
    -- Compte des admins actifs (denominateur de l'unanimite)
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
    -- Identites resolues
    target_profile.public_id   AS proposed_public_id,
    target_profile.first_name  AS proposed_first_name,
    target_profile.last_name   AS proposed_last_name,
    target_profile.email       AS proposed_email,
    proposer_profile.public_id   AS proposer_public_id,
    proposer_profile.first_name  AS proposer_first_name,
    proposer_profile.last_name   AS proposer_last_name,
    proposer_profile.email       AS proposer_email,
    -- Comptes de votes (sur cette proposition)
    (SELECT count(*) FROM public.network_administrator_cooptation_votes v
       WHERE v.proposal_id = p.id AND v.vote = 'favorable')::int AS favorable_count,
    (SELECT count(*) FROM public.network_administrator_cooptation_votes v
       WHERE v.proposal_id = p.id AND v.vote = 'opposed')::int AS opposed_count,
    (SELECT count(*) FROM public.network_administrator_cooptation_votes v
       WHERE v.proposal_id = p.id AND v.vote = 'abstain')::int AS abstain_count,
    -- Denominateur unanimite : admins actifs hors target
    -- (le target ne vote pas sur sa propre cooptation : doctrine v0.3)
    (SELECT total FROM active_admin_count) - (
        CASE WHEN EXISTS (
            SELECT 1 FROM public.network_administrators na
            WHERE na.user_id = p.proposed_user_id AND na.status = 'active'
        ) THEN 1 ELSE 0 END
    ) AS required_votes,
    -- Le caller a-t-il deja vote ?
    EXISTS (
        SELECT 1 FROM public.network_administrator_cooptation_votes v
        WHERE v.proposal_id = p.id AND v.voter_user_id = auth.uid()
    ) AS caller_has_voted,
    -- Le caller est-il la personne proposee ?
    (p.proposed_user_id = auth.uid()) AS caller_is_target,
    -- Le caller est-il le proposeur ?
    (p.proposed_by = auth.uid()) AS caller_is_proposer
FROM public.network_administrator_cooptation_proposals p
LEFT JOIN public.profiles target_profile ON target_profile.id = p.proposed_user_id
LEFT JOIN public.profiles proposer_profile ON proposer_profile.id = p.proposed_by
WHERE p.status = 'open';

-- SECURITY INVOKER : la vue respecte la RLS de la table sous-jacente
-- (proposals_select_admins_or_proposed : admins reseau actifs + target)
ALTER VIEW api.cooptation_proposals_current_v1 SET (security_invoker = on);

GRANT SELECT ON api.cooptation_proposals_current_v1 TO authenticated;

COMMENT ON VIEW api.cooptation_proposals_current_v1 IS
'E.4.b v0.3 - Vue listing propositions de cooptation ouvertes (status=''open'') avec identites resolves, comptes de votes, denominateur unanimite calcule (admins actifs hors target), et flags pour le caller (has_voted, is_target, is_proposer). SECURITY INVOKER : respecte RLS sous-jacente. Frontend : AdminsPanel section "Propostas em curso".';

COMMIT;

-- ============================================================================
-- Notes post-deploiement
-- ============================================================================
-- 1. Migration enregistree :
--    SELECT version, name FROM supabase_migrations.schema_migrations
--    ORDER BY version DESC LIMIT 3;
--
-- 2. Vue creee :
--    SELECT pg_get_viewdef('api.cooptation_proposals_current_v1'::regclass, true);
--
-- 3. Test fonctionnel (devrait retourner 0 lignes - aucune prop active) :
--    SELECT proposal_id, proposed_public_id, status, favorable_count,
--           opposed_count, required_votes, caller_has_voted, caller_is_target
--    FROM api.cooptation_proposals_current_v1;
--
-- 4. La vue ne couvre PAS les retraits collectifs. Une vue
--    api.collective_removal_proposals_current_v1 symetrique sera creee
--    en E.4.c (paquet suivant).
