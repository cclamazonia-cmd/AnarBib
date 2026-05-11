-- ============================================================================
-- 20260511030000_paquetA_network_admin_infrastructure.sql
-- ============================================================================
-- Paquet A — Infrastructure de l'administrateur réseau (AnarBib)
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.1 (11/05/2026)
--
-- Pose en parallèle de l'existant les structures nécessaires à la séparation
-- entre staff local et administration réseau, SANS toucher aux RLS, fonctions
-- ou vues existantes. Aucun impact sur la prod.
--
-- Contenu :
--   1. 4 nouvelles tables (network_administrators + audit + proposals + votes)
--   2. 3 helpers SQL centralisés (fn_caller_is_network_admin,
--      user_can_act_as_staff_on_library, user_can_engage_library)
--   3. 4 RPC (propose, vote, self_remove, request_removal)
--   4. 1 trigger de complétion de cooptation
--   5. 2 vues (network_administrators_public_v1, my_network_admin_status)
--   6. RLS sur les nouvelles tables
--   7. GRANTs aux rôles authenticated et anon
--   8. Tests SQL en commentaires désactivés (à décommenter manuellement)
--
-- Niveau de garde-fous : strict (RAISE EXCEPTION sur tout cas d'erreur).
--
-- Atomicité : transaction unique. En cas d'erreur, rien n'est créé.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 network_administrators — table principale
-- ----------------------------------------------------------------------------
CREATE TABLE public.network_administrators (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
    status text NOT NULL DEFAULT 'active' 
        CHECK (status IN ('active', 'pending_removal', 'removed', 'inactive')),
    coopted_at timestamptz NOT NULL DEFAULT now(),
    coopted_by_unanimity_of uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
    removal_requested_at timestamptz,
    removal_reason text,
    removed_at timestamptz,
    last_seen_at timestamptz,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.network_administrators IS 
'Personnes qui animent la coordination du réseau AnarBib. Cooptation à l''unanimité des administrateurs en place. Aucune library_id : leur autorité est transverse au réseau, jamais située dans une biblio particulière. Réf spec-administrateur-reseau.md.';

COMMENT ON COLUMN public.network_administrators.coopted_by_unanimity_of IS 
'Liste des user_id des administrateurs qui ont voté favorablement à la cooptation. Doit être égal à l''ensemble des administrateurs actifs au moment de la cooptation.';

COMMENT ON COLUMN public.network_administrators.last_seen_at IS 
'Dernière activité de l''administrateur. Utilisé pour la détection d''inactivité longue (>6 mois → passage auto à status=inactive).';

CREATE INDEX network_administrators_status_active_idx 
    ON public.network_administrators(user_id) 
    WHERE status = 'active';

-- Trigger updated_at standard
CREATE OR REPLACE FUNCTION public.tg_network_administrators_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_network_administrators_updated_at
    BEFORE UPDATE ON public.network_administrators
    FOR EACH ROW
    EXECUTE FUNCTION public.tg_network_administrators_updated_at();

-- ----------------------------------------------------------------------------
-- 1.2 network_administrator_audit — journal immuable
-- ----------------------------------------------------------------------------
CREATE TABLE public.network_administrator_audit (
    id bigserial PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id),
    event_type text NOT NULL 
        CHECK (event_type IN (
            'cooptation_proposed', 
            'cooptation_voted', 
            'cooptation_completed', 
            'cooptation_rejected',
            'cooptation_expired',
            'self_removal_requested', 
            'removal_requested', 
            'removal_completed', 
            'inactivity_marked',
            'foundational_admin_added'
        )),
    actor_user_id uuid REFERENCES auth.users(id),
    target_user_id uuid REFERENCES auth.users(id),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.network_administrator_audit IS 
'Journal immuable des événements liés aux administrateurs réseau. INSERT only, jamais UPDATE ni DELETE. Garantit la traçabilité politique des cooptations et retraits.';

CREATE INDEX network_administrator_audit_user_id_idx 
    ON public.network_administrator_audit(user_id, created_at DESC);

CREATE INDEX network_administrator_audit_event_type_idx 
    ON public.network_administrator_audit(event_type, created_at DESC);

-- Empêcher tout UPDATE/DELETE sur l'audit (immuabilité)
CREATE OR REPLACE FUNCTION public.tg_network_administrator_audit_immutable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'audit_immutable: network_administrator_audit is append-only, UPDATE and DELETE are forbidden';
END;
$$;

CREATE TRIGGER trg_network_administrator_audit_no_update
    BEFORE UPDATE ON public.network_administrator_audit
    FOR EACH ROW
    EXECUTE FUNCTION public.tg_network_administrator_audit_immutable();

CREATE TRIGGER trg_network_administrator_audit_no_delete
    BEFORE DELETE ON public.network_administrator_audit
    FOR EACH ROW
    EXECUTE FUNCTION public.tg_network_administrator_audit_immutable();

-- ----------------------------------------------------------------------------
-- 1.3 network_administrator_cooptation_proposals — propositions en cours
-- ----------------------------------------------------------------------------
CREATE TABLE public.network_administrator_cooptation_proposals (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    proposed_user_id uuid NOT NULL REFERENCES auth.users(id),
    proposed_by uuid NOT NULL REFERENCES auth.users(id),
    proposed_at timestamptz NOT NULL DEFAULT now(),
    motivation text NOT NULL,
    status text NOT NULL DEFAULT 'open' 
        CHECK (status IN ('open', 'completed', 'rejected', 'cancelled', 'expired')),
    completed_at timestamptz,
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
    CONSTRAINT motivation_not_too_short CHECK (length(trim(motivation)) >= 20)
);

COMMENT ON TABLE public.network_administrator_cooptation_proposals IS 
'Propositions de cooptation en cours. Expiration automatique à 30 jours. La motivation doit faire >=20 caractères (engagement politique du proposeur).';

CREATE INDEX network_administrator_cooptation_proposals_open_idx
    ON public.network_administrator_cooptation_proposals(proposed_user_id)
    WHERE status = 'open';

CREATE INDEX network_administrator_cooptation_proposals_expires_idx
    ON public.network_administrator_cooptation_proposals(expires_at)
    WHERE status = 'open';

-- ----------------------------------------------------------------------------
-- 1.4 network_administrator_cooptation_votes — votes individuels
-- ----------------------------------------------------------------------------
CREATE TABLE public.network_administrator_cooptation_votes (
    proposal_id uuid NOT NULL REFERENCES public.network_administrator_cooptation_proposals(id) ON DELETE CASCADE,
    voter_user_id uuid NOT NULL REFERENCES auth.users(id),
    vote text NOT NULL CHECK (vote IN ('favorable', 'opposed', 'abstain')),
    voted_at timestamptz NOT NULL DEFAULT now(),
    rationale text,
    PRIMARY KEY (proposal_id, voter_user_id)
);

COMMENT ON TABLE public.network_administrator_cooptation_votes IS 
'Votes des administrateurs réseau actifs sur une proposition. Une voix par personne (PK composite). Une seule opposition suffit à bloquer (unanimité requise). Les votes peuvent être modifiés tant que la proposition est ouverte (UPSERT).';

-- ============================================================================
-- SECTION 2 : HELPERS SQL CENTRALISÉS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 fn_caller_is_network_admin() — successeur de fn_caller_is_administrador
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_caller_is_network_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.network_administrators
        WHERE user_id = auth.uid() AND status = 'active'
    );
$$;

COMMENT ON FUNCTION public.fn_caller_is_network_admin() IS 
'Retourne TRUE si l''appelant courant est un administrateur réseau actif. Remplace fn_caller_is_administrador() (qui reste opérationnel pendant la coexistence du paquet B).';

GRANT EXECUTE ON FUNCTION public.fn_caller_is_network_admin() TO authenticated, anon;

-- ----------------------------------------------------------------------------
-- 2.2 user_can_act_as_staff_on_library(uuid) — autorisation transverse staff
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.user_can_act_as_staff_on_library(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT 
        -- Soit administrateur réseau (droit transverse)
        EXISTS (
            SELECT 1 FROM public.network_administrators
            WHERE user_id = auth.uid() AND status = 'active'
        )
        OR
        -- Soit staff local actif sur cette biblio
        EXISTS (
            SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid()
              AND m.library_id = p_library_id
              AND m.status = 'active'
              AND m.role = ANY (ARRAY['librarian', 'coordenador'])
        );
$$;

COMMENT ON FUNCTION public.user_can_act_as_staff_on_library(uuid) IS 
'Retourne TRUE si l''appelant peut agir comme membre du staff sur la biblio donnée. Inclut les administrateurs réseau (droit transverse) et le staff local actif (librarian + coordenador). Utilisé par les RLS catégorie A (15 policies).';

GRANT EXECUTE ON FUNCTION public.user_can_act_as_staff_on_library(uuid) TO authenticated, anon;

-- ----------------------------------------------------------------------------
-- 2.3 user_can_engage_library(uuid) — autorisation d'engagement politique
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.user_can_engage_library(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT 
        -- Soit administrateur réseau
        EXISTS (
            SELECT 1 FROM public.network_administrators
            WHERE user_id = auth.uid() AND status = 'active'
        )
        OR
        -- Soit coordenador local actif (les librarian ne peuvent pas engager politiquement)
        EXISTS (
            SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid()
              AND m.library_id = p_library_id
              AND m.status = 'active'
              AND m.role = 'coordenador'
        );
$$;

COMMENT ON FUNCTION public.user_can_engage_library(uuid) IS 
'Retourne TRUE si l''appelant peut engager politiquement la biblio (modifications structurelles, règlement, politique de circulation). Inclut administrateurs réseau et coordenadores locaux. Utilisé par les RLS catégorie B (4 policies).';

GRANT EXECUTE ON FUNCTION public.user_can_engage_library(uuid) TO authenticated, anon;

-- ============================================================================
-- SECTION 3 : TRIGGER DE COMPLÉTION DE COOPTATION
-- ============================================================================

-- Le trigger s'exécute après chaque INSERT ou UPDATE sur les votes.
-- Il vérifie si la proposition doit être clôturée :
--   - 1+ vote opposed → status='rejected' (veto immédiat)
--   - tous les admins actifs ont voté favorable → status='completed' + INSERT admin
--   - sinon, en attente
CREATE OR REPLACE FUNCTION public.trg_check_cooptation_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_proposal record;
    v_total_admins integer;
    v_favorable_votes integer;
    v_opposed_votes integer;
    v_voter_ids uuid[];
BEGIN
    -- Récupère la proposition
    SELECT * INTO v_proposal 
        FROM network_administrator_cooptation_proposals
        WHERE id = NEW.proposal_id;
    
    IF v_proposal.status <> 'open' THEN
        -- Proposition déjà clôturée, rien à faire
        RETURN NEW;
    END IF;
    
    -- Compte des admins actifs hors proposé (les éligibles à voter)
    SELECT count(*) INTO v_total_admins 
        FROM network_administrators
        WHERE status = 'active' 
          AND user_id <> v_proposal.proposed_user_id;
    
    -- Compte des votes favorables et opposés
    SELECT 
        count(*) FILTER (WHERE vote = 'favorable'),
        count(*) FILTER (WHERE vote = 'opposed'),
        array_agg(voter_user_id) FILTER (WHERE vote = 'favorable')
    INTO v_favorable_votes, v_opposed_votes, v_voter_ids
    FROM network_administrator_cooptation_votes
    WHERE proposal_id = NEW.proposal_id;
    
    -- Cas 1 : un seul vote opposed → veto immédiat
    IF v_opposed_votes > 0 THEN
        UPDATE network_administrator_cooptation_proposals
            SET status = 'rejected', completed_at = now()
            WHERE id = NEW.proposal_id;
        
        INSERT INTO network_administrator_audit 
            (user_id, event_type, target_user_id, metadata)
            VALUES (
                v_proposal.proposed_user_id, 
                'cooptation_rejected', 
                v_proposal.proposed_user_id, 
                jsonb_build_object(
                    'proposal_id', NEW.proposal_id, 
                    'opposed_count', v_opposed_votes,
                    'favorable_count', v_favorable_votes
                )
            );
        
        RETURN NEW;
    END IF;
    
    -- Cas 2 : tous les admins actifs ont voté favorable → cooptation effective
    IF v_total_admins > 0 AND v_favorable_votes >= v_total_admins THEN
        -- Insertion dans network_administrators
        INSERT INTO network_administrators 
            (user_id, status, coopted_at, coopted_by_unanimity_of)
            VALUES (
                v_proposal.proposed_user_id, 
                'active', 
                now(), 
                COALESCE(v_voter_ids, ARRAY[]::uuid[])
            );
        
        -- Clôture de la proposition
        UPDATE network_administrator_cooptation_proposals
            SET status = 'completed', completed_at = now()
            WHERE id = NEW.proposal_id;
        
        INSERT INTO network_administrator_audit 
            (user_id, event_type, target_user_id, metadata)
            VALUES (
                v_proposal.proposed_user_id, 
                'cooptation_completed', 
                v_proposal.proposed_user_id, 
                jsonb_build_object(
                    'proposal_id', NEW.proposal_id, 
                    'voters', COALESCE(v_voter_ids, ARRAY[]::uuid[])
                )
            );
    END IF;
    
    -- Cas 3 : votes encore manquants → on attend
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_check_cooptation_completion() IS 
'Trigger après vote : clôture la proposition si veto (opposed) ou unanimité (favorable). En cas d''unanimité, crée la ligne dans network_administrators automatiquement.';

CREATE TRIGGER trg_check_cooptation_completion_after_vote
    AFTER INSERT OR UPDATE ON public.network_administrator_cooptation_votes
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_check_cooptation_completion();

-- ============================================================================
-- SECTION 4 : RPC DE COOPTATION ET RETRAIT
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 fn_network_admin_propose_cooptation — proposer une nouvelle personne
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_network_admin_propose_cooptation(
    p_user_id uuid,
    p_motivation text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_proposal_id uuid;
    v_caller_id uuid := auth.uid();
BEGIN
    -- Garde 1 : l'appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can propose cooptation'
            USING ERRCODE = '42501';
    END IF;
    
    -- Garde 2 : la personne proposée doit exister dans auth.users
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'user_not_found: target user does not exist'
            USING ERRCODE = 'P0002';
    END IF;
    
    -- Garde 3 : la personne proposée ne doit pas déjà être admin réseau actif
    IF EXISTS (
        SELECT 1 FROM network_administrators 
        WHERE user_id = p_user_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'already_admin: this person is already an active network administrator'
            USING ERRCODE = '23505';
    END IF;
    
    -- Garde 4 : pas de proposition en cours pour cette personne
    IF EXISTS (
        SELECT 1 FROM network_administrator_cooptation_proposals
        WHERE proposed_user_id = p_user_id AND status = 'open'
    ) THEN
        RAISE EXCEPTION 'proposal_exists: an open proposal already exists for this person'
            USING ERRCODE = '23505';
    END IF;
    
    -- Garde 5 : motivation suffisante (>=20 chars trim, déjà CHECK mais on raise tôt)
    IF length(trim(coalesce(p_motivation, ''))) < 20 THEN
        RAISE EXCEPTION 'motivation_too_short: motivation must be at least 20 characters'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 6 : ne pas se proposer soi-même
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'self_proposal_forbidden: you cannot propose yourself'
            USING ERRCODE = '42501';
    END IF;
    
    -- Création de la proposition
    INSERT INTO network_administrator_cooptation_proposals
        (proposed_user_id, proposed_by, motivation)
        VALUES (p_user_id, v_caller_id, p_motivation)
        RETURNING id INTO v_proposal_id;
    
    -- Vote automatique favorable du proposeur (le trigger gérera la complétion
    -- si jamais le proposeur est le seul admin actif)
    INSERT INTO network_administrator_cooptation_votes
        (proposal_id, voter_user_id, vote, rationale)
        VALUES (v_proposal_id, v_caller_id, 'favorable', 'Proposeur, vote implicite');
    
    -- Audit
    INSERT INTO network_administrator_audit 
        (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            p_user_id, 
            'cooptation_proposed', 
            v_caller_id, 
            p_user_id, 
            jsonb_build_object('proposal_id', v_proposal_id, 'motivation', p_motivation)
        );
    
    RETURN v_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.fn_network_admin_propose_cooptation(uuid, text) IS 
'Propose la cooptation d''une personne comme administrateur réseau. Garde-fous stricts. Crée automatiquement le vote favorable du proposeur. Retourne l''ID de la proposition.';

GRANT EXECUTE ON FUNCTION public.fn_network_admin_propose_cooptation(uuid, text) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4.2 fn_network_admin_vote_cooptation — voter sur une proposition
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_network_admin_vote_cooptation(
    p_proposal_id uuid,
    p_vote text,
    p_rationale text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_proposal record;
BEGIN
    -- Garde 1 : l'appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can vote'
            USING ERRCODE = '42501';
    END IF;
    
    -- Garde 2 : le vote doit être valide
    IF p_vote IS NULL OR p_vote NOT IN ('favorable', 'opposed', 'abstain') THEN
        RAISE EXCEPTION 'invalid_vote: vote must be favorable, opposed, or abstain'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 3 : la proposition doit exister
    SELECT * INTO v_proposal 
        FROM network_administrator_cooptation_proposals
        WHERE id = p_proposal_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'proposal_not_found'
            USING ERRCODE = 'P0002';
    END IF;
    
    -- Garde 4 : la proposition doit être ouverte
    IF v_proposal.status <> 'open' THEN
        RAISE EXCEPTION 'proposal_closed: proposal is no longer open (status=%)', v_proposal.status
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 5 : pas expirée
    IF v_proposal.expires_at < now() THEN
        RAISE EXCEPTION 'proposal_expired'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 6 : on ne vote pas sur soi-même
    IF v_proposal.proposed_user_id = v_caller_id THEN
        RAISE EXCEPTION 'self_vote_forbidden: you cannot vote on your own cooptation'
            USING ERRCODE = '42501';
    END IF;
    
    -- UPSERT du vote (on peut changer son vote tant que la proposition est ouverte)
    INSERT INTO network_administrator_cooptation_votes 
        (proposal_id, voter_user_id, vote, rationale, voted_at)
        VALUES (p_proposal_id, v_caller_id, p_vote, p_rationale, now())
    ON CONFLICT (proposal_id, voter_user_id) 
    DO UPDATE SET 
        vote = EXCLUDED.vote, 
        rationale = EXCLUDED.rationale, 
        voted_at = now();
    
    -- Audit
    INSERT INTO network_administrator_audit 
        (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            v_proposal.proposed_user_id, 
            'cooptation_voted', 
            v_caller_id, 
            v_proposal.proposed_user_id, 
            jsonb_build_object('proposal_id', p_proposal_id, 'vote', p_vote)
        );
    
    -- Le trigger trg_check_cooptation_completion s'occupe de la suite
END;
$$;

COMMENT ON FUNCTION public.fn_network_admin_vote_cooptation(uuid, text, text) IS 
'Vote sur une proposition de cooptation. UPSERT : un admin peut changer son vote tant que la proposition est ouverte. Un seul vote "opposed" suffit à rejeter (veto). Trigger de complétion automatique.';

GRANT EXECUTE ON FUNCTION public.fn_network_admin_vote_cooptation(uuid, text, text) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4.3 fn_network_admin_self_remove — auto-retrait unilatéral
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_network_admin_self_remove(
    p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_remaining_admins integer;
BEGIN
    -- Garde 1 : l'appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can self-remove'
            USING ERRCODE = '42501';
    END IF;
    
    -- Compte des autres admins actifs (hors appelant)
    SELECT count(*) INTO v_remaining_admins
        FROM network_administrators
        WHERE status = 'active' AND user_id <> v_caller_id;
    
    -- Garde 2 : si l'appelant est le dernier admin, transition pending_removal
    -- avec carence de 30 jours pour permettre un workflow de récupération
    IF v_remaining_admins = 0 THEN
        UPDATE network_administrators
            SET status = 'pending_removal',
                removal_requested_at = now(),
                removal_reason = COALESCE(p_reason, 'Auto-retrait du dernier administrateur réseau')
            WHERE user_id = v_caller_id;
        
        INSERT INTO network_administrator_audit 
            (user_id, event_type, actor_user_id, target_user_id, metadata)
            VALUES (
                v_caller_id, 
                'self_removal_requested', 
                v_caller_id, 
                v_caller_id, 
                jsonb_build_object(
                    'reason', p_reason, 
                    'last_admin', true,
                    'carence_until', (now() + interval '30 days')
                )
            );
        
        RAISE NOTICE 'last_admin_pending_removal: you are the last network administrator. Status set to pending_removal with 30-day grace period.';
        RETURN;
    END IF;
    
    -- Cas normal : retrait immédiat
    UPDATE network_administrators
        SET status = 'removed',
            removed_at = now(),
            removal_reason = COALESCE(p_reason, 'Auto-retrait')
        WHERE user_id = v_caller_id;
    
    INSERT INTO network_administrator_audit 
        (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            v_caller_id, 
            'removal_completed', 
            v_caller_id, 
            v_caller_id, 
            jsonb_build_object('reason', p_reason, 'self_initiated', true)
        );
END;
$$;

COMMENT ON FUNCTION public.fn_network_admin_self_remove(text) IS 
'Auto-retrait d''un administrateur réseau (acte unilatéral). Si dernier admin actif, passe en pending_removal avec carence de 30 jours pour permettre une récupération du réseau.';

GRANT EXECUTE ON FUNCTION public.fn_network_admin_self_remove(text) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4.4 fn_network_admin_request_removal — proposer le retrait d'un autre
-- ----------------------------------------------------------------------------
-- Note : le retrait collectif à l'unanimité utilisera le même mécanisme de
-- propositions/votes que la cooptation, en miroir. Pour ce paquet A, on pose
-- la RPC d'amorce qui crée une proposition spéciale event_type=removal_*.
-- Le workflow complet (vote miroir) sera implémenté au paquet D.
CREATE OR REPLACE FUNCTION public.fn_network_admin_request_removal(
    p_target_user_id uuid,
    p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
BEGIN
    -- Garde 1 : l'appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can request removal'
            USING ERRCODE = '42501';
    END IF;
    
    -- Garde 2 : la cible doit être admin réseau actif
    IF NOT EXISTS (
        SELECT 1 FROM network_administrators 
        WHERE user_id = p_target_user_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'target_not_admin: target user is not an active network administrator'
            USING ERRCODE = 'P0002';
    END IF;
    
    -- Garde 3 : motivation suffisante
    IF length(trim(coalesce(p_reason, ''))) < 20 THEN
        RAISE EXCEPTION 'reason_too_short: removal reason must be at least 20 characters'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 4 : ne pas demander son propre retrait via cette RPC (utiliser self_remove)
    IF p_target_user_id = v_caller_id THEN
        RAISE EXCEPTION 'use_self_remove: use fn_network_admin_self_remove for self-removal'
            USING ERRCODE = '42501';
    END IF;
    
    -- Marquer la cible en pending_removal (le workflow de vote miroir
    -- sera implémenté au paquet D ; pour l'instant, on trace la demande)
    UPDATE network_administrators
        SET status = 'pending_removal',
            removal_requested_at = now(),
            removal_reason = p_reason
        WHERE user_id = p_target_user_id;
    
    INSERT INTO network_administrator_audit 
        (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            p_target_user_id, 
            'removal_requested', 
            v_caller_id, 
            p_target_user_id, 
            jsonb_build_object(
                'reason', p_reason, 
                'workflow_version', 'paquet_A_stub',
                'note', 'Full unanimity-voting workflow will be implemented in paquet D'
            )
        );
END;
$$;

COMMENT ON FUNCTION public.fn_network_admin_request_removal(uuid, text) IS 
'Demande le retrait d''un autre administrateur réseau. STUB paquet A : marque en pending_removal et trace l''audit. Le workflow complet de vote miroir à l''unanimité sera implémenté au paquet D.';

GRANT EXECUTE ON FUNCTION public.fn_network_admin_request_removal(uuid, text) TO authenticated;

-- ============================================================================
-- SECTION 5 : VUES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 api.network_administrators_public_v1 — liste publique des admins actifs
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW api.network_administrators_public_v1 AS
SELECT 
    na.user_id,
    p.public_id,
    p.first_name,
    p.last_name,
    p.email,
    na.coopted_at,
    na.last_seen_at
FROM public.network_administrators na
LEFT JOIN public.profiles p ON p.id = na.user_id
WHERE na.status = 'active';

COMMENT ON VIEW api.network_administrators_public_v1 IS 
'Liste des administrateurs réseau actifs, exposée à tous les utilisateurs authentifiés. Sert de référence pour /rede onglet Administrateurs et pour les badges NetworkAdminBadge.';

GRANT SELECT ON api.network_administrators_public_v1 TO authenticated;

-- ----------------------------------------------------------------------------
-- 5.2 api.my_network_admin_status — statut admin réseau de l'appelant
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW api.my_network_admin_status AS
SELECT 
    na.user_id,
    na.status,
    na.coopted_at,
    na.coopted_by_unanimity_of,
    na.last_seen_at,
    na.notes,
    (na.status = 'active') AS is_active_admin
FROM public.network_administrators na
WHERE na.user_id = auth.uid();

COMMENT ON VIEW api.my_network_admin_status IS 
'Pour l''appelant courant : statut administrateur réseau (s''il existe). Retourne 0 ligne si l''appelant n''est pas administrateur réseau. Utilisé par LibraryContext frontend pour exposer isNetworkAdmin.';

GRANT SELECT ON api.my_network_admin_status TO authenticated;

-- ============================================================================
-- SECTION 6 : RLS SUR LES NOUVELLES TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6.1 network_administrators
-- ----------------------------------------------------------------------------
ALTER TABLE public.network_administrators ENABLE ROW LEVEL SECURITY;

-- SELECT : visible à tous les authenticated (transparence du réseau)
CREATE POLICY network_administrators_select_all
    ON public.network_administrators
    FOR SELECT
    TO authenticated
    USING (true);

-- INSERT : interdit en direct (uniquement via trigger trg_check_cooptation_completion
-- ou via insertion manuelle de fondateur·rice par un superadmin DB)
-- Pas de policy INSERT pour authenticated : ils ne peuvent pas écrire en direct.
-- Le trigger tourne avec SECURITY DEFINER donc il bypass RLS.

-- UPDATE : uniquement via RPC fn_network_admin_self_remove et fn_network_admin_request_removal
-- (qui tournent SECURITY DEFINER, bypass RLS). Pas de policy UPDATE pour authenticated.

-- DELETE : jamais. Pas de policy.

-- ----------------------------------------------------------------------------
-- 6.2 network_administrator_audit
-- ----------------------------------------------------------------------------
ALTER TABLE public.network_administrator_audit ENABLE ROW LEVEL SECURITY;

-- SELECT : visible à tous les admins réseau actifs (transparence interne)
CREATE POLICY network_administrator_audit_select_admins
    ON public.network_administrator_audit
    FOR SELECT
    TO authenticated
    USING (fn_caller_is_network_admin());

-- INSERT : interdit en direct (uniquement via triggers et RPC SECURITY DEFINER)
-- UPDATE et DELETE : interdits par triggers tg_network_administrator_audit_immutable

-- ----------------------------------------------------------------------------
-- 6.3 network_administrator_cooptation_proposals
-- ----------------------------------------------------------------------------
ALTER TABLE public.network_administrator_cooptation_proposals ENABLE ROW LEVEL SECURITY;

-- SELECT : visible aux admins réseau actifs + à la personne proposée
CREATE POLICY proposals_select_admins_or_proposed
    ON public.network_administrator_cooptation_proposals
    FOR SELECT
    TO authenticated
    USING (
        fn_caller_is_network_admin() 
        OR proposed_user_id = auth.uid()
    );

-- INSERT : uniquement via RPC fn_network_admin_propose_cooptation (SECURITY DEFINER)
-- UPDATE : uniquement via trigger et RPC (SECURITY DEFINER)
-- DELETE : jamais

-- ----------------------------------------------------------------------------
-- 6.4 network_administrator_cooptation_votes
-- ----------------------------------------------------------------------------
ALTER TABLE public.network_administrator_cooptation_votes ENABLE ROW LEVEL SECURITY;

-- SELECT : visible aux admins réseau actifs + au votant lui-même + au proposé
CREATE POLICY votes_select_admins_or_self_or_proposed
    ON public.network_administrator_cooptation_votes
    FOR SELECT
    TO authenticated
    USING (
        fn_caller_is_network_admin() 
        OR voter_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM network_administrator_cooptation_proposals p
            WHERE p.id = network_administrator_cooptation_votes.proposal_id
              AND p.proposed_user_id = auth.uid()
        )
    );

-- INSERT/UPDATE : uniquement via RPC fn_network_admin_vote_cooptation (SECURITY DEFINER)
-- DELETE : jamais (CASCADE depuis proposals si suppression de proposition,
-- mais on ne devrait jamais supprimer une proposition - on change son status)

-- ============================================================================
-- SECTION 7 : COHÉRENCE FINALE
-- ============================================================================

-- Vérification que les helpers retournent FALSE pour le moment (aucun admin réseau)
DO $$
DECLARE
    v_admin_count integer;
BEGIN
    SELECT count(*) INTO v_admin_count FROM public.network_administrators;
    
    IF v_admin_count <> 0 THEN
        RAISE EXCEPTION 'unexpected_initial_state: network_administrators should be empty at creation, found % rows', v_admin_count;
    END IF;
    
    RAISE NOTICE 'paquet_A_ok: infrastructure created, table is empty as expected. Paquet B will migrate existing administrador memberships.';
END;
$$;

COMMIT;

-- ============================================================================
-- TESTS SQL (commentaires désactivés, à décommenter manuellement si besoin)
-- ============================================================================
-- Pour exécuter ces tests :
--   1. Décommenter le bloc concerné
--   2. Lancer la requête dans SQL Editor
--   3. Vérifier la sortie
--   4. ROLLBACK manuellement pour ne pas polluer la base
--
-- ATTENTION : ces tests ne tournent PAS dans la transaction principale.
-- Ils sont là pour validation manuelle après application de la migration.

/*
-- TEST 1 : insertion fondatrice (cas du premier administrateur)
-- ⚠️ Adapte le user_id avec celui de Xavier (cf. requête d'audit du 11/05)
BEGIN;
INSERT INTO public.network_administrators 
    (user_id, status, coopted_at, coopted_by_unanimity_of, notes)
    VALUES (
        'd6710372-e5e5-4608-800b-99a26817c677'::uuid,
        'active',
        now(),
        ARRAY[]::uuid[],
        'Fondateur du réseau AnarBib, cooptation hors workflow (paquet A test)'
    );

INSERT INTO public.network_administrator_audit
    (user_id, event_type, actor_user_id, target_user_id, metadata)
    VALUES (
        'd6710372-e5e5-4608-800b-99a26817c677'::uuid,
        'foundational_admin_added',
        'd6710372-e5e5-4608-800b-99a26817c677'::uuid,
        'd6710372-e5e5-4608-800b-99a26817c677'::uuid,
        jsonb_build_object('foundational', true, 'test', true)
    );

-- Vérif
SELECT * FROM public.network_administrators;
SELECT fn_caller_is_network_admin();  -- doit retourner true si auth.uid() = Xavier
SELECT user_can_act_as_staff_on_library('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid);

ROLLBACK;  -- NE PAS COMMITER, c'est un test
*/

/*
-- TEST 2 : tentative d'INSERT direct sans passer par la RPC (doit échouer pour authenticated)
-- À lancer en tant qu'utilisateur authenticated (pas service_role)
BEGIN;
INSERT INTO public.network_administrators 
    (user_id, status) 
    VALUES (auth.uid(), 'active');
-- Devrait échouer car aucune policy INSERT pour authenticated.
ROLLBACK;
*/

/*
-- TEST 3 : tentative d'UPDATE sur l'audit (doit échouer par trigger)
BEGIN;
INSERT INTO public.network_administrator_audit
    (user_id, event_type, metadata)
    VALUES ('d6710372-e5e5-4608-800b-99a26817c677'::uuid, 'cooptation_proposed', '{}'::jsonb);

UPDATE public.network_administrator_audit 
    SET metadata = '{"hacked": true}'::jsonb 
    WHERE id = (SELECT max(id) FROM public.network_administrator_audit);
-- Devrait échouer : audit_immutable
ROLLBACK;
*/

/*
-- TEST 4 : tentative de cooptation avec motivation trop courte (doit échouer)
-- Pré-requis : être admin réseau actif
SELECT fn_network_admin_propose_cooptation(
    '2a42b6bd-d159-4ee0-b66b-28a03062232b'::uuid,
    'court'
);
-- Devrait échouer : motivation_too_short
*/

/*
-- TEST 5 : workflow complet de cooptation avec 1 seul admin (Xavier)
-- Si Xavier est le seul admin actif, sa proposition + son vote favorable
-- devraient déclencher la complétion automatique.
-- 
-- Pré-requis : avoir exécuté TEST 1 (insertion fondatrice Xavier) avec COMMIT
-- 
-- Pour tester complètement :
--   a) Créer un user de test dans auth.users
--   b) En tant que Xavier, appeler fn_network_admin_propose_cooptation
--   c) Vérifier que le trigger a auto-complété (status='completed') et
--      que le user de test apparaît dans network_administrators
SELECT fn_network_admin_propose_cooptation(
    '<UUID_USER_TEST>'::uuid,
    'Motivation test du workflow de cooptation paquet A (>=20 chars OK).'
);

-- Vérifier
SELECT * FROM public.network_administrator_cooptation_proposals ORDER BY proposed_at DESC LIMIT 1;
SELECT * FROM public.network_administrator_cooptation_votes ORDER BY voted_at DESC LIMIT 5;
SELECT * FROM public.network_administrators ORDER BY coopted_at DESC LIMIT 5;
SELECT * FROM public.network_administrator_audit ORDER BY created_at DESC LIMIT 10;
*/

-- Fin du fichier.
