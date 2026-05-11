-- ============================================================================
-- Paquet D.6bis — Helper fn_network_notify_event + correction INSERT outbox
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Réf.  : Régression dormante détectée lors de l'audit pré-D.7
--
-- Contexte
-- --------
-- Les 4 RPC du paquet D.6 (propose, vote, cancel, cron_execute) inséraient
-- dans team_notification_outbox avec :
--   INSERT INTO ... (event, recipient_user_id, payload, status) VALUES ...
-- Or la table n'a pas de colonne recipient_user_id : le fan-out par
-- destinataire est résolu par l'Edge Function notify-event à partir du
-- payload jsonb.
--
-- En outre, fn_team_notify_event rejette explicitement les events ne
-- commençant pas par 'team.', alors que le CHECK constraint de la table
-- accepte aussi 'network.%' et que le trigger dispatch route tous les
-- events sans filtre.
--
-- La régression est dormante : la Garde 5 (quorum ≥ 3 admins) bloque tous
-- les appels D.6 tant qu'il n'y a qu'un seul admin réseau actif. Aucune
-- ligne network.collective_removal_* n'a été insérée à ce jour (vérifié
-- 13/05/2026).
--
-- Décisions
-- ---------
-- 1. Création d'un helper symétrique fn_network_notify_event(text, jsonb),
--    pattern aligné sur fn_team_notify_event.
-- 2. Réécriture des 4 RPC D.6 : un seul INSERT par event (pas par
--    destinataire), via le nouveau helper. L'Edge Function résoudra le
--    fan-out.
-- 3. Le payload jsonb porte le contexte minimal (proposal_id,
--    proposed_user_id, proposed_by, etc.) ; pas de recipient_user_id.
--
-- Effet en prod : aucun. Les RPC restent bloquées par la Garde 5.
-- L'infrastructure est posée correctement pour l'activation future.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Helper fn_network_notify_event
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_network_notify_event(
    p_event text,
    p_payload jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_outbox_id bigint;
BEGIN
    -- Validation du préfixe : ce helper ne traite que les events 'network.%'.
    -- Pour les events 'team.%', utiliser fn_team_notify_event (symétrie).
    IF p_event IS NULL OR p_event NOT LIKE 'network.%' THEN
        RAISE WARNING 'fn_network_notify_event: event name invalid (must start with "network."): %', p_event;
        RETURN NULL;
    END IF;

    -- Insertion dans la outbox.
    -- Le trigger trg_team_outbox_dispatch déclenchera le POST vers
    -- l'Edge Function notify-event, qui résoudra le fan-out depuis le payload.
    INSERT INTO public.team_notification_outbox (event, payload)
    VALUES (p_event, COALESCE(p_payload, '{}'::jsonb))
    RETURNING id INTO v_outbox_id;

    RETURN v_outbox_id;

EXCEPTION
    WHEN OTHERS THEN
        -- Une erreur d'enregistrement notification ne doit JAMAIS faire
        -- échouer la RPC métier qui appelle ce helper.
        RAISE WARNING 'fn_network_notify_event échec INSERT outbox pour event=% : %', p_event, SQLERRM;
        RETURN NULL;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_network_notify_event(text, jsonb) FROM PUBLIC;
-- Pas de GRANT à authenticated : helper interne appelé par d'autres SECURITY DEFINER

COMMENT ON FUNCTION public.fn_network_notify_event(text, jsonb) IS 
    'D.6bis — Helper d''insertion outbox pour events network.%. Pendant symétrique de fn_team_notify_event. Un seul INSERT par event, fan-out résolu côté Edge Function.';


-- ----------------------------------------------------------------------------
-- 2. Réécriture fn_network_admin_propose_collective_removal
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

    -- Garde 3 : appelant ≠ target
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

    -- Notification : 1 seul INSERT outbox, fan-out résolu côté Edge Function
    PERFORM public.fn_network_notify_event(
        'network.collective_removal_proposed',
        jsonb_build_object(
            'proposal_id', v_proposal_id,
            'proposed_user_id', p_proposed_user_id,
            'proposed_by', v_caller_id,
            'motivation_preview', left(trim(p_motivation), 200),
            'expires_at', (now() + interval '60 days')
        )
    );

    RETURN v_proposal_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_network_admin_propose_collective_removal(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_network_admin_propose_collective_removal(uuid, text) TO authenticated;


-- ----------------------------------------------------------------------------
-- 3. Réécriture fn_network_admin_vote_collective_removal
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
    v_unanimous_now boolean := false;
BEGIN
    -- Garde 1 : appelant admin réseau actif
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

    -- Garde 4 : proposition ouverte
    IF v_proposal.status <> 'open' THEN
        RAISE EXCEPTION 'proposal_not_open: proposal status is %', v_proposal.status
            USING ERRCODE = '22023';
    END IF;

    -- Garde 5 : appelant ≠ target
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

    -- Garde 7 : rationale ≥ 20 caractères si against
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

    -- Notification : 1 seul INSERT outbox pour le vote
    PERFORM public.fn_network_notify_event(
        'network.collective_removal_vote_cast',
        jsonb_build_object(
            'proposal_id', p_proposal_id,
            'proposed_user_id', v_proposal.proposed_user_id,
            'vote', p_vote,
            'voter_user_id', CASE WHEN p_disclose_identity THEN v_caller_id ELSE NULL END,
            'disclose_identity', p_disclose_identity
        )
    );

    -- Détection unanimité
    SELECT count(*) INTO v_active_others_count
        FROM public.network_administrators
        WHERE status = 'active'
          AND user_id <> v_proposal.proposed_user_id;
    
    SELECT EXISTS (
        SELECT 1 FROM public.network_admin_collective_removal_votes
        WHERE proposal_id = p_proposal_id AND vote = 'against'
    ) INTO v_against_exists;
    
    SELECT count(*) INTO v_favor_count
        FROM public.network_admin_collective_removal_votes
        WHERE proposal_id = p_proposal_id AND vote = 'favor';

    IF NOT v_against_exists 
       AND v_favor_count = v_active_others_count
       AND v_active_others_count >= 2
    THEN
        v_unanimous_now := true;
        
        UPDATE public.network_admin_collective_removal_proposals
            SET status = 'unanimous',
                unanimous_at = now(),
                pending_removal_until = now() + interval '7 days'
            WHERE id = p_proposal_id;
        
        UPDATE public.network_administrators
            SET status = 'pending_removal',
                removal_requested_at = now(),
                removal_reason = 'Collective removal proposal ' || p_proposal_id::text
            WHERE user_id = v_proposal.proposed_user_id;
        
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
        
        -- 1 seul INSERT outbox pour signaler l'unanimité
        -- L'Edge Function notifiera target ET autres admins
        PERFORM public.fn_network_notify_event(
            'network.collective_removal_unanimous',
            jsonb_build_object(
                'proposal_id', p_proposal_id,
                'proposed_user_id', v_proposal.proposed_user_id,
                'proposed_by', v_proposal.proposed_by,
                'pending_removal_until', (now() + interval '7 days')
            )
        );
    END IF;

    RETURN CASE WHEN v_unanimous_now THEN 'unanimous_carence_started' ELSE 'vote_recorded' END;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_network_admin_vote_collective_removal(uuid, text, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_network_admin_vote_collective_removal(uuid, text, boolean, text) TO authenticated;


-- ----------------------------------------------------------------------------
-- 4. Réécriture fn_network_admin_cancel_collective_removal
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
BEGIN
    -- Garde 1 : appelant admin réseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can cancel'
            USING ERRCODE = '42501';
    END IF;

    -- Garde 2 : raison ≥ 20 caractères
    IF length(trim(coalesce(p_reason, ''))) < 20 THEN
        RAISE EXCEPTION 'reason_too_short: cancellation reason must be at least 20 characters'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_proposal
        FROM public.network_admin_collective_removal_proposals
        WHERE id = p_proposal_id
        FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'proposal_not_found' USING ERRCODE = 'P0002';
    END IF;

    IF v_proposal.status NOT IN ('open', 'unanimous') THEN
        RAISE EXCEPTION 'proposal_not_cancellable: proposal status is %', v_proposal.status
            USING ERRCODE = '22023';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.network_admin_collective_removal_votes
        WHERE proposal_id = p_proposal_id AND voter_user_id = v_caller_id
    ) INTO v_caller_voted;
    
    IF v_caller_id <> v_proposal.proposed_by AND NOT v_caller_voted THEN
        RAISE EXCEPTION 'only_voters_can_cancel: only the proposer or admins who voted can cancel this proposal'
            USING ERRCODE = '42501';
    END IF;

    UPDATE public.network_admin_collective_removal_proposals
        SET status = 'cancelled',
            cancelled_at = now(),
            cancelled_by = v_caller_id,
            cancellation_reason = trim(p_reason),
            pending_removal_until = NULL
        WHERE id = p_proposal_id;

    -- Si proposition unanimous, restaurer target en active
    IF v_proposal.status = 'unanimous' THEN
        UPDATE public.network_administrators
            SET status = 'active',
                removal_requested_at = NULL,
                removal_reason = NULL
            WHERE user_id = v_proposal.proposed_user_id
              AND status = 'pending_removal';
    END IF;

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

    -- 1 seul INSERT outbox. L'Edge Function décidera de notifier le target
    -- (uniquement si v_proposal.status était 'unanimous', donc déjà notifié)
    -- via le flag 'was_unanimous' dans le payload.
    PERFORM public.fn_network_notify_event(
        'network.collective_removal_cancelled',
        jsonb_build_object(
            'proposal_id', p_proposal_id,
            'proposed_user_id', v_proposal.proposed_user_id,
            'cancelled_by', v_caller_id,
            'was_unanimous', (v_proposal.status = 'unanimous'),
            'cancellation_reason', trim(p_reason)
        )
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_network_admin_cancel_collective_removal(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_network_admin_cancel_collective_removal(uuid, text) TO authenticated;


-- ----------------------------------------------------------------------------
-- 5. Réécriture fn_cron_collective_removal_execute
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
BEGIN
    FOR v_proposal IN
        SELECT id, proposed_user_id, proposed_by
        FROM public.network_admin_collective_removal_proposals
        WHERE status = 'unanimous'
          AND pending_removal_until IS NOT NULL
          AND pending_removal_until <= now()
        FOR UPDATE
    LOOP
        UPDATE public.network_administrators
            SET status = 'removed',
                removed_at = now()
            WHERE user_id = v_proposal.proposed_user_id;
        
        UPDATE public.network_admin_collective_removal_proposals
            SET status = 'executed',
                executed_at = now()
            WHERE id = v_proposal.id;
        
        INSERT INTO public.network_administrator_audit
            (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            v_proposal.proposed_user_id,
            'collective_removal_executed',
            NULL,
            v_proposal.proposed_user_id,
            jsonb_build_object(
                'proposal_id', v_proposal.id,
                'executed_by', 'cron'
            )
        );
        
        -- 1 seul INSERT outbox
        PERFORM public.fn_network_notify_event(
            'network.collective_removal_executed',
            jsonb_build_object(
                'proposal_id', v_proposal.id,
                'proposed_user_id', v_proposal.proposed_user_id,
                'proposed_by', v_proposal.proposed_by
            )
        );
        
        v_executed_count := v_executed_count + 1;
    END LOOP;

    -- Expirer les propositions ouvertes au-delà de expires_at
    UPDATE public.network_admin_collective_removal_proposals
        SET status = 'expired'
        WHERE status = 'open'
          AND expires_at <= now();

    RETURN v_executed_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_cron_collective_removal_execute() FROM PUBLIC;


COMMIT;

-- ============================================================================
-- Notes post-déploiement
-- ============================================================================
-- 1. Vérifier le helper :
--    SELECT proname FROM pg_proc WHERE proname = 'fn_network_notify_event';
-- 2. Vérifier que les RPC D.6 n'ont plus de référence à recipient_user_id :
--    SELECT proname FROM pg_proc 
--    WHERE proname LIKE 'fn_%collective_removal%'
--      AND pg_get_functiondef(oid) LIKE '%recipient_user_id%';
--    -- Attendu : 0 ligne
-- 3. Test smoke (à faire APRÈS l'Edge Function notify-event compatible network.%) :
--    SELECT public.fn_network_notify_event(
--        'network.test_smoke',
--        jsonb_build_object('hello', 'world')
--    );
--    -- Vérifier qu'une ligne apparaît dans team_notification_outbox avec event='network.test_smoke'
--    -- et que le trigger l'a dispatched (status devrait passer à 'sent' ou 'failed' selon Edge Function)
-- 4. Item #78 du backlog (Edge Function notify-cross-library-digest) doit être mis à jour :
--    ajouter le traitement des events network.collective_removal_*
