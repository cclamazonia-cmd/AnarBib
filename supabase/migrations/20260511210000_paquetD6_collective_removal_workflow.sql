-- ============================================================================
-- Paquet D.6 — Workflow retrait collectif administrateur réseau (Q5 v0.3)
-- ============================================================================
-- Date  : 2026-05-11
-- Auteur: Xavier (AnarBib)
-- Réf.  : docs/spec-administrateur-reseau.md v0.3 §Q5
--
-- Doctrine (12 décisions figées) :
--  1. Tables dédiées proposals + votes (symétrie cooptation)
--  2. Carence absolue 7 jours fixes depuis unanimous_at
--  3. Notifications individuelles aux autres admins à chaque vote ;
--     target notifié seulement à l'unanimité
--  4. Pas de recours formalisé du target
--  5. Un seul admin propose, unanimité des autres actifs requise
--  6. Garde quorum minimal : 3 admins réseau actifs
--  7. Nommage proposed_user_id (symétrie cooptation)
--  8. Ship complet dormant en prod jusqu'au quorum
--  9. Expiration proposition : 60 jours
-- 10. Motivation ≥ 50 caractères
-- 11. Un seul paquet, un commit
-- 12. Déprécation fn_network_admin_request_removal incluse
--
-- Effet en prod immédiat : aucun. 1 seul admin réseau actif (Xavier),
-- la Garde quorum minimal (≥ 3 actifs) bloque toute proposition.
-- L'infrastructure est posée pour activation future.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- D.6.a — Tables
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.network_admin_collective_removal_proposals (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    proposed_user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    proposed_by              uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    motivation               text NOT NULL,
    status                   text NOT NULL DEFAULT 'open',
    proposed_at              timestamptz NOT NULL DEFAULT now(),
    expires_at               timestamptz NOT NULL DEFAULT (now() + interval '60 days'),
    unanimous_at             timestamptz,
    pending_removal_until    timestamptz,
    cancelled_at             timestamptz,
    cancelled_by             uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    cancellation_reason      text,
    executed_at              timestamptz,
    CONSTRAINT crp_status_check CHECK (
        status = ANY (ARRAY[
            'open',
            'unanimous',
            'cancelled',
            'executed',
            'expired'
        ])
    ),
    CONSTRAINT crp_motivation_length CHECK (
        length(trim(motivation)) >= 50
    ),
    CONSTRAINT crp_no_self_target CHECK (
        proposed_user_id <> proposed_by
    ),
    CONSTRAINT crp_pending_implies_unanimous CHECK (
        (pending_removal_until IS NULL) OR (unanimous_at IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_crp_status_open 
    ON public.network_admin_collective_removal_proposals (status, expires_at)
    WHERE status = 'open';

CREATE INDEX IF NOT EXISTS idx_crp_pending_removal_until 
    ON public.network_admin_collective_removal_proposals (pending_removal_until)
    WHERE status = 'unanimous';

CREATE INDEX IF NOT EXISTS idx_crp_proposed_user 
    ON public.network_admin_collective_removal_proposals (proposed_user_id);

COMMENT ON TABLE public.network_admin_collective_removal_proposals IS 
    'Propositions de retrait collectif admin réseau (Q5 v0.3). Workflow : open → unanimous (carence 7j) → executed | cancelled | expired.';

COMMENT ON COLUMN public.network_admin_collective_removal_proposals.unanimous_at IS 
    'Moment où le dernier vote favorable requis a été recueilli. Déclenche la carence de 7 jours.';

COMMENT ON COLUMN public.network_admin_collective_removal_proposals.pending_removal_until IS 
    'unanimous_at + 7 jours. Au-delà, le cron exécute le retrait (status active → removed).';


CREATE TABLE IF NOT EXISTS public.network_admin_collective_removal_votes (
    proposal_id        uuid NOT NULL REFERENCES public.network_admin_collective_removal_proposals(id) ON DELETE CASCADE,
    voter_user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    vote               text NOT NULL,
    rationale          text,
    disclose_identity  boolean NOT NULL,
    voted_at           timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (proposal_id, voter_user_id),
    CONSTRAINT crv_vote_check CHECK (
        vote = ANY (ARRAY['favor', 'against'])
    ),
    CONSTRAINT crv_rationale_if_against CHECK (
        vote = 'favor' OR (vote = 'against' AND length(trim(coalesce(rationale, ''))) >= 20)
    )
);

CREATE INDEX IF NOT EXISTS idx_crv_voter ON public.network_admin_collective_removal_votes (voter_user_id);

COMMENT ON TABLE public.network_admin_collective_removal_votes IS 
    'Votes sur propositions de retrait collectif. Garde 7 : rationale ≥ 20 chars obligatoire si vote = against.';

COMMENT ON COLUMN public.network_admin_collective_removal_votes.disclose_identity IS 
    'Obligatoire (doctrine D.5). Si false, votant anonyme pour le target. Toujours visible pour les autres admins.';


-- ----------------------------------------------------------------------------
-- D.6.a (suite) — RLS
-- ----------------------------------------------------------------------------

ALTER TABLE public.network_admin_collective_removal_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.network_admin_collective_removal_votes ENABLE ROW LEVEL SECURITY;

-- Lecture proposals : admins réseau actifs + le target
DROP POLICY IF EXISTS rls_crp_select ON public.network_admin_collective_removal_proposals;
CREATE POLICY rls_crp_select 
    ON public.network_admin_collective_removal_proposals
    FOR SELECT
    USING (
        fn_caller_is_network_admin()
        OR proposed_user_id = auth.uid()
    );

-- Lecture votes : admins réseau actifs (le target voit la proposition mais pas le détail des votes)
DROP POLICY IF EXISTS rls_crv_select ON public.network_admin_collective_removal_votes;
CREATE POLICY rls_crv_select 
    ON public.network_admin_collective_removal_votes
    FOR SELECT
    USING (
        fn_caller_is_network_admin()
    );

-- INSERT/UPDATE/DELETE bloqués pour tout le monde : tout passe par les RPC SECURITY DEFINER
DROP POLICY IF EXISTS rls_crp_no_direct_write ON public.network_admin_collective_removal_proposals;
CREATE POLICY rls_crp_no_direct_write 
    ON public.network_admin_collective_removal_proposals
    FOR ALL
    USING (false)
    WITH CHECK (false);

DROP POLICY IF EXISTS rls_crv_no_direct_write ON public.network_admin_collective_removal_votes;
CREATE POLICY rls_crv_no_direct_write 
    ON public.network_admin_collective_removal_votes
    FOR ALL
    USING (false)
    WITH CHECK (false);


-- ----------------------------------------------------------------------------
-- D.6.b — RPC propose_collective_removal
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_network_admin_propose_collective_removal(
    p_proposed_user_id uuid,
    p_motivation text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_active_count integer;
    v_proposal_id uuid;
    v_existing_open uuid;
    v_other_admin record;
BEGIN
    -- Garde 1 : appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can propose collective removal'
            USING ERRCODE = '42501';
    END IF;

    -- Garde 2 : target doit être admin réseau actif
    IF NOT EXISTS (
        SELECT 1 FROM public.network_administrators
        WHERE user_id = p_proposed_user_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'target_not_active_admin: target user is not an active network administrator'
            USING ERRCODE = 'P0002';
    END IF;

    -- Garde 3 : appelant ≠ target (l'auto-retrait passe par fn_network_admin_self_remove)
    IF p_proposed_user_id = v_caller_id THEN
        RAISE EXCEPTION 'use_self_remove: use fn_network_admin_self_remove for self-removal'
            USING ERRCODE = '42501';
    END IF;

    -- Garde 4 : motivation ≥ 50 caractères
    IF length(trim(coalesce(p_motivation, ''))) < 50 THEN
        RAISE EXCEPTION 'motivation_too_short: motivation must be at least 50 characters'
            USING ERRCODE = '22023';
    END IF;

    -- Garde 5 : quorum minimal ≥ 3 admins réseau actifs
    -- (doctrine v0.3 : minimum 2 votants après exclusion du target)
    SELECT count(*) INTO v_active_count
        FROM public.network_administrators
        WHERE status = 'active';
    
    IF v_active_count < 3 THEN
        RAISE EXCEPTION 'quorum_too_small: at least 3 active network administrators required for collective removal (currently %)' , v_active_count
            USING ERRCODE = 'P0002';
    END IF;

    -- Garde 6 : pas de proposition déjà ouverte ou unanimous pour ce target
    SELECT id INTO v_existing_open
        FROM public.network_admin_collective_removal_proposals
        WHERE proposed_user_id = p_proposed_user_id
          AND status IN ('open', 'unanimous')
        LIMIT 1;
    
    IF v_existing_open IS NOT NULL THEN
        RAISE EXCEPTION 'proposal_already_open: an active proposal % already exists for this target', v_existing_open
            USING ERRCODE = '23505';
    END IF;

    -- Insertion proposition
    INSERT INTO public.network_admin_collective_removal_proposals
        (proposed_user_id, proposed_by, motivation)
    VALUES
        (p_proposed_user_id, v_caller_id, trim(p_motivation))
    RETURNING id INTO v_proposal_id;

    -- Audit
    INSERT INTO public.network_administrator_audit
        (user_id, event_type, actor_user_id, target_user_id, metadata)
    VALUES (
        p_proposed_user_id,
        'collective_removal_proposed',
        v_caller_id,
        p_proposed_user_id,
        jsonb_build_object(
            'proposal_id', v_proposal_id,
            'motivation_length', length(trim(p_motivation))
        )
    );

    -- Notifications individuelles aux autres admins actifs (hors caller, hors target)
    -- L'appelant compte pour lui-même comme premier vote implicite ? NON.
    -- Doctrine : le proposeur doit voter explicitement pour acter sa position.
    FOR v_other_admin IN
        SELECT user_id 
        FROM public.network_administrators
        WHERE status = 'active'
          AND user_id <> v_caller_id
          AND user_id <> p_proposed_user_id
    LOOP
        INSERT INTO public.team_notification_outbox 
            (event, recipient_user_id, payload, status)
        VALUES (
            'network.collective_removal_proposed',
            v_other_admin.user_id,
            jsonb_build_object(
                'proposal_id', v_proposal_id,
                'proposed_by', v_caller_id,
                'proposed_user_id', p_proposed_user_id,
                'motivation_preview', left(trim(p_motivation), 200)
            ),
            'pending'
        );
    END LOOP;

    RETURN v_proposal_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_network_admin_propose_collective_removal(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_network_admin_propose_collective_removal(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_network_admin_propose_collective_removal(uuid, text) IS 
    'D.6.b — Ouvre une proposition de retrait collectif. Gardes 1-6 (admin réseau actif, target admin actif, pas auto-target, motivation ≥ 50 chars, quorum ≥ 3 actifs, pas de proposition concurrente).';


-- ----------------------------------------------------------------------------
-- D.6.b (suite) — RPC vote_collective_removal
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_network_admin_vote_collective_removal(
    p_proposal_id uuid,
    p_vote text,
    p_disclose_identity boolean,
    p_rationale text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_proposal record;
    v_active_others_count integer;
    v_favor_count integer;
    v_against_exists boolean;
    v_other_admin record;
    v_unanimous_now boolean := false;
BEGIN
    -- Garde 1 : appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can vote'
            USING ERRCODE = '42501';
    END IF;

    -- Garde 2 : vote ∈ {favor, against}
    IF p_vote NOT IN ('favor', 'against') THEN
        RAISE EXCEPTION 'invalid_vote: vote must be favor or against'
            USING ERRCODE = '22023';
    END IF;

    -- Garde 3 : disclose_identity OBLIGATOIRE (doctrine D.5)
    IF p_disclose_identity IS NULL THEN
        RAISE EXCEPTION 'disclose_identity_required: must explicitly declare whether identity is disclosed to target'
            USING ERRCODE = '22023';
    END IF;

    -- Récup proposition
    SELECT * INTO v_proposal
        FROM public.network_admin_collective_removal_proposals
        WHERE id = p_proposal_id
        FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'proposal_not_found' USING ERRCODE = 'P0002';
    END IF;

    -- Garde 4 : proposition doit être ouverte
    IF v_proposal.status <> 'open' THEN
        RAISE EXCEPTION 'proposal_not_open: proposal status is %', v_proposal.status
            USING ERRCODE = '22023';
    END IF;

    -- Garde 5 : appelant ne peut pas être le target
    IF v_caller_id = v_proposal.proposed_user_id THEN
        RAISE EXCEPTION 'target_cannot_vote: the target of a removal proposal cannot vote on it'
            USING ERRCODE = '42501';
    END IF;

    -- Garde 6 : pas déjà voté
    IF EXISTS (
        SELECT 1 FROM public.network_admin_collective_removal_votes
        WHERE proposal_id = p_proposal_id AND voter_user_id = v_caller_id
    ) THEN
        RAISE EXCEPTION 'already_voted: caller has already voted on this proposal'
            USING ERRCODE = '23505';
    END IF;

    -- Garde 7 : rationale ≥ 20 caractères si vote = against (CHECK en table mais on remonte une erreur lisible)
    IF p_vote = 'against' AND length(trim(coalesce(p_rationale, ''))) < 20 THEN
        RAISE EXCEPTION 'rationale_required: rationale of at least 20 characters required when voting against'
            USING ERRCODE = '22023';
    END IF;

    -- Insertion vote
    INSERT INTO public.network_admin_collective_removal_votes
        (proposal_id, voter_user_id, vote, rationale, disclose_identity)
    VALUES
        (p_proposal_id, v_caller_id, p_vote, nullif(trim(coalesce(p_rationale, '')), ''), p_disclose_identity);

    -- Audit
    INSERT INTO public.network_administrator_audit
        (user_id, event_type, actor_user_id, target_user_id, metadata)
    VALUES (
        v_proposal.proposed_user_id,
        'collective_removal_voted',
        v_caller_id,
        v_proposal.proposed_user_id,
        jsonb_build_object(
            'proposal_id', p_proposal_id,
            'vote', p_vote,
            'disclose_identity', p_disclose_identity
        )
    );

    -- Notifications individuelles aux autres admins actifs (hors votant, hors target)
    FOR v_other_admin IN
        SELECT user_id 
        FROM public.network_administrators
        WHERE status = 'active'
          AND user_id <> v_caller_id
          AND user_id <> v_proposal.proposed_user_id
    LOOP
        INSERT INTO public.team_notification_outbox 
            (event, recipient_user_id, payload, status)
        VALUES (
            'network.collective_removal_vote_cast',
            v_other_admin.user_id,
            jsonb_build_object(
                'proposal_id', p_proposal_id,
                'vote', p_vote,
                'voter_user_id', CASE WHEN p_disclose_identity THEN v_caller_id ELSE NULL END,
                'proposed_user_id', v_proposal.proposed_user_id
            ),
            'pending'
        );
    END LOOP;

    -- Détection unanimité
    -- Compte des admins actifs autres que le target (votants potentiels)
    SELECT count(*) INTO v_active_others_count
        FROM public.network_administrators
        WHERE status = 'active'
          AND user_id <> v_proposal.proposed_user_id;
    
    -- Y a-t-il un vote against quelque part ?
    SELECT EXISTS (
        SELECT 1 FROM public.network_admin_collective_removal_votes
        WHERE proposal_id = p_proposal_id AND vote = 'against'
    ) INTO v_against_exists;
    
    -- Compte des votes favor
    SELECT count(*) INTO v_favor_count
        FROM public.network_admin_collective_removal_votes
        WHERE proposal_id = p_proposal_id AND vote = 'favor';

    -- Unanimité = tous les votants potentiels ont voté favor, aucun against
    IF NOT v_against_exists 
       AND v_favor_count = v_active_others_count
       AND v_active_others_count >= 2  -- minimum 2 votants effectifs après exclusion target
    THEN
        v_unanimous_now := true;
        
        UPDATE public.network_admin_collective_removal_proposals
            SET status = 'unanimous',
                unanimous_at = now(),
                pending_removal_until = now() + interval '7 days'
            WHERE id = p_proposal_id;
        
        -- Marquer le target en pending_removal sur la table principale
        UPDATE public.network_administrators
            SET status = 'pending_removal',
                removal_requested_at = now(),
                removal_reason = 'Collective removal proposal ' || p_proposal_id::text
            WHERE user_id = v_proposal.proposed_user_id;
        
        -- Audit unanimité
        INSERT INTO public.network_administrator_audit
            (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            v_proposal.proposed_user_id,
            'collective_removal_unanimous',
            v_caller_id,
            v_proposal.proposed_user_id,
            jsonb_build_object(
                'proposal_id', p_proposal_id,
                'pending_removal_until', (now() + interval '7 days')
            )
        );
        
        -- Notification target
        INSERT INTO public.team_notification_outbox 
            (event, recipient_user_id, payload, status)
        VALUES (
            'network.collective_removal_unanimous',
            v_proposal.proposed_user_id,
            jsonb_build_object(
                'proposal_id', p_proposal_id,
                'pending_removal_until', (now() + interval '7 days')
            ),
            'pending'
        );
        
        -- Notification autres admins (signaler que la carence démarre)
        FOR v_other_admin IN
            SELECT user_id 
            FROM public.network_administrators
            WHERE status = 'active'
              AND user_id <> v_proposal.proposed_user_id
        LOOP
            INSERT INTO public.team_notification_outbox 
                (event, recipient_user_id, payload, status)
            VALUES (
                'network.collective_removal_unanimous',
                v_other_admin.user_id,
                jsonb_build_object(
                    'proposal_id', p_proposal_id,
                    'proposed_user_id', v_proposal.proposed_user_id,
                    'pending_removal_until', (now() + interval '7 days')
                ),
                'pending'
            );
        END LOOP;
    END IF;

    RETURN CASE WHEN v_unanimous_now THEN 'unanimous_carence_started' ELSE 'vote_recorded' END;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_network_admin_vote_collective_removal(uuid, text, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_network_admin_vote_collective_removal(uuid, text, boolean, text) TO authenticated;

COMMENT ON FUNCTION public.fn_network_admin_vote_collective_removal(uuid, text, boolean, text) IS 
    'D.6.b — Vote sur une proposition de retrait collectif. disclose_identity obligatoire (D.5). rationale ≥ 20 chars si against (Garde 7). Détecte l''unanimité, déclenche la carence 7j et notifications.';


-- ----------------------------------------------------------------------------
-- D.6.b (suite) — RPC cancel_collective_removal
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_network_admin_cancel_collective_removal(
    p_proposal_id uuid,
    p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_proposal record;
    v_caller_voted boolean;
    v_other_admin record;
BEGIN
    -- Garde 1 : appelant doit être admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can cancel'
            USING ERRCODE = '42501';
    END IF;

    -- Garde 2 : raison ≥ 20 caractères
    IF length(trim(coalesce(p_reason, ''))) < 20 THEN
        RAISE EXCEPTION 'reason_too_short: cancellation reason must be at least 20 characters'
            USING ERRCODE = '22023';
    END IF;

    -- Récup proposition
    SELECT * INTO v_proposal
        FROM public.network_admin_collective_removal_proposals
        WHERE id = p_proposal_id
        FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'proposal_not_found' USING ERRCODE = 'P0002';
    END IF;

    -- Garde 3 : proposition doit être annulable (open ou unanimous, pas executed/expired/cancelled)
    IF v_proposal.status NOT IN ('open', 'unanimous') THEN
        RAISE EXCEPTION 'proposal_not_cancellable: proposal status is %', v_proposal.status
            USING ERRCODE = '22023';
    END IF;

    -- Garde 4 : seuls les votants peuvent annuler (cohérence : le proposeur a "voté" implicitement)
    --   - Soit l'appelant est le proposeur
    --   - Soit l'appelant a voté sur la proposition
    SELECT EXISTS (
        SELECT 1 FROM public.network_admin_collective_removal_votes
        WHERE proposal_id = p_proposal_id AND voter_user_id = v_caller_id
    ) INTO v_caller_voted;
    
    IF v_caller_id <> v_proposal.proposed_by AND NOT v_caller_voted THEN
        RAISE EXCEPTION 'only_voters_can_cancel: only the proposer or admins who voted can cancel this proposal'
            USING ERRCODE = '42501';
    END IF;

    -- Update proposition
    UPDATE public.network_admin_collective_removal_proposals
        SET status = 'cancelled',
            cancelled_at = now(),
            cancelled_by = v_caller_id,
            cancellation_reason = trim(p_reason),
            pending_removal_until = NULL
        WHERE id = p_proposal_id;

    -- Si la proposition était unanimous, le target était en pending_removal sur la table
    -- principale : on doit le repasser en active
    IF v_proposal.status = 'unanimous' THEN
        UPDATE public.network_administrators
            SET status = 'active',
                removal_requested_at = NULL,
                removal_reason = NULL
            WHERE user_id = v_proposal.proposed_user_id
              AND status = 'pending_removal';
    END IF;

    -- Audit
    INSERT INTO public.network_administrator_audit
        (user_id, event_type, actor_user_id, target_user_id, metadata)
    VALUES (
        v_proposal.proposed_user_id,
        'collective_removal_cancelled',
        v_caller_id,
        v_proposal.proposed_user_id,
        jsonb_build_object(
            'proposal_id', p_proposal_id,
            'previous_status', v_proposal.status,
            'cancellation_reason', trim(p_reason)
        )
    );

    -- Notification target (sauf si la proposition était encore en 'open' et que le target
    -- n'avait jamais été notifié — règle doctrinale : target informé seulement après unanimité)
    IF v_proposal.status = 'unanimous' THEN
        INSERT INTO public.team_notification_outbox 
            (event, recipient_user_id, payload, status)
        VALUES (
            'network.collective_removal_cancelled',
            v_proposal.proposed_user_id,
            jsonb_build_object(
                'proposal_id', p_proposal_id,
                'cancelled_by', v_caller_id
            ),
            'pending'
        );
    END IF;

    -- Notification autres admins (toujours)
    FOR v_other_admin IN
        SELECT user_id 
        FROM public.network_administrators
        WHERE status = 'active'
          AND user_id <> v_caller_id
          AND user_id <> v_proposal.proposed_user_id
    LOOP
        INSERT INTO public.team_notification_outbox 
            (event, recipient_user_id, payload, status)
        VALUES (
            'network.collective_removal_cancelled',
            v_other_admin.user_id,
            jsonb_build_object(
                'proposal_id', p_proposal_id,
                'cancelled_by', v_caller_id,
                'proposed_user_id', v_proposal.proposed_user_id,
                'previous_status', v_proposal.status
            ),
            'pending'
        );
    END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_network_admin_cancel_collective_removal(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_network_admin_cancel_collective_removal(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.fn_network_admin_cancel_collective_removal(uuid, text) IS 
    'D.6.b — Annule une proposition de retrait collectif (open ou unanimous). Annulation possible par le proposeur ou tout votant. Si proposition était unanimous, restaure target à status=active.';


-- ----------------------------------------------------------------------------
-- D.6.c — Cron d'exécution
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_collective_removal_execute()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_executed_count integer := 0;
    v_proposal record;
    v_other_admin record;
BEGIN
    FOR v_proposal IN
        SELECT id, proposed_user_id, proposed_by
        FROM public.network_admin_collective_removal_proposals
        WHERE status = 'unanimous'
          AND pending_removal_until IS NOT NULL
          AND pending_removal_until <= now()
        FOR UPDATE
    LOOP
        -- Exécuter le retrait
        UPDATE public.network_administrators
            SET status = 'removed',
                removed_at = now()
            WHERE user_id = v_proposal.proposed_user_id;
        
        UPDATE public.network_admin_collective_removal_proposals
            SET status = 'executed',
                executed_at = now()
            WHERE id = v_proposal.id;
        
        -- Audit
        INSERT INTO public.network_administrator_audit
            (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            v_proposal.proposed_user_id,
            'collective_removal_executed',
            NULL,  -- exécution par cron, pas d'actor utilisateur
            v_proposal.proposed_user_id,
            jsonb_build_object(
                'proposal_id', v_proposal.id,
                'executed_by', 'cron'
            )
        );
        
        -- Notification target
        INSERT INTO public.team_notification_outbox 
            (event, recipient_user_id, payload, status)
        VALUES (
            'network.collective_removal_executed',
            v_proposal.proposed_user_id,
            jsonb_build_object('proposal_id', v_proposal.id),
            'pending'
        );
        
        -- Notification autres admins (encore actifs)
        FOR v_other_admin IN
            SELECT user_id 
            FROM public.network_administrators
            WHERE status = 'active'
              AND user_id <> v_proposal.proposed_user_id
        LOOP
            INSERT INTO public.team_notification_outbox 
                (event, recipient_user_id, payload, status)
            VALUES (
                'network.collective_removal_executed',
                v_other_admin.user_id,
                jsonb_build_object(
                    'proposal_id', v_proposal.id,
                    'proposed_user_id', v_proposal.proposed_user_id
                ),
                'pending'
            );
        END LOOP;
        
        v_executed_count := v_executed_count + 1;
    END LOOP;

    -- Pendant qu'on y est : expirer les propositions ouvertes au-delà de expires_at
    UPDATE public.network_admin_collective_removal_proposals
        SET status = 'expired'
        WHERE status = 'open'
          AND expires_at <= now();

    RETURN v_executed_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_cron_collective_removal_execute() FROM PUBLIC;
-- Pas de GRANT à authenticated : fonction réservée au cron (postgres role)

COMMENT ON FUNCTION public.fn_cron_collective_removal_execute() IS 
    'D.6.c — Cron quotidien : exécute les retraits dont la carence 7j est expirée, expire les propositions au-delà des 60j.';


-- Job pg_cron : créé INACTIF (cohérent avec pratique paquet C)
-- Activation manuelle quand un Edge Function de digest existera et que le quorum sera atteint
DO $$
DECLARE
    v_job_id bigint;
BEGIN
    -- Supprime tout job antérieur du même nom (idempotence)
    PERFORM cron.unschedule(jobid) 
        FROM cron.job 
        WHERE jobname = 'anarbib-collective-removal-execute-daily';
    
    -- Schedule : tous les jours à 03:15 UTC
    SELECT cron.schedule(
        'anarbib-collective-removal-execute-daily',
        '15 3 * * *',
        $cron$SELECT public.fn_cron_collective_removal_execute();$cron$
    ) INTO v_job_id;
    
    -- Désactivation immédiate (dormant jusqu'à activation manuelle)
    PERFORM cron.alter_job(v_job_id, active := false);
END;
$$;


-- ----------------------------------------------------------------------------
-- D.6.d — Déprécation fn_network_admin_request_removal
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_network_admin_request_removal(
    p_target_user_id uuid, 
    p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
    RAISE EXCEPTION 'deprecated: fn_network_admin_request_removal is deprecated. Use fn_network_admin_propose_collective_removal (D.6) for collective removal with unanimity voting.'
        USING ERRCODE = '0A000';  -- feature_not_supported
END;
$function$;

COMMENT ON FUNCTION public.fn_network_admin_request_removal(uuid, text) IS 
    'D.6.d — DEPRECATED. Remplacée par fn_network_admin_propose_collective_removal (workflow unanimité v0.3 Q5).';


COMMIT;

-- ============================================================================
-- Notes post-déploiement
-- ============================================================================
-- 1. Vérifier la migration : SELECT * FROM supabase_migrations.schema_migrations 
--    ORDER BY version DESC LIMIT 5;
-- 2. Vérifier les RPC : 
--    SELECT proname FROM pg_proc WHERE proname LIKE 'fn_%collective_removal%';
-- 3. Vérifier le job cron (doit être inactif) :
--    SELECT jobname, schedule, active FROM cron.job 
--    WHERE jobname = 'anarbib-collective-removal-execute-daily';
--    → active doit être false
-- 4. Test fonctionnel impossible en l'état (1 seul admin actif, Garde 5 bloque).
--    Le workflow s'active automatiquement dès qu'il y aura 3 admins réseau actifs
--    et qu'on activera le cron via cron.alter_job(..., active := true).
-- 5. notification events à ajouter dans i18n mail-strings (sera traité au paquet E ou
--    juste avant activation cron) :
--    - network.collective_removal_proposed
--    - network.collective_removal_vote_cast
--    - network.collective_removal_unanimous
--    - network.collective_removal_cancelled
--    - network.collective_removal_executed
