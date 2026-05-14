-- ============================================================
-- Patch #114.B Q1 : enrichir payload network.cooptation_rejected
-- pour permettre la diffusion conditionnelle du rationale opposé
-- selon doctrine 4.2 (disclose_identity=true → rationale visible)
-- ============================================================

CREATE OR REPLACE FUNCTION public.trg_check_cooptation_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_proposal record;
    v_total_admins integer;
    v_favorable_votes integer;
    v_opposed_votes integer;
    v_voter_ids uuid[];
BEGIN
    SELECT * INTO v_proposal 
        FROM network_administrator_cooptation_proposals
        WHERE id = NEW.proposal_id;
    
    IF v_proposal.status <> 'open' THEN
        RETURN NEW;
    END IF;
    
    SELECT count(*) INTO v_total_admins 
        FROM network_administrators
        WHERE status = 'active' 
          AND user_id <> v_proposal.proposed_user_id;
    
    SELECT 
        count(*) FILTER (WHERE vote = 'favorable'),
        count(*) FILTER (WHERE vote = 'opposed'),
        array_agg(voter_user_id) FILTER (WHERE vote = 'favorable')
    INTO v_favorable_votes, v_opposed_votes, v_voter_ids
    FROM network_administrator_cooptation_votes
    WHERE proposal_id = NEW.proposal_id;
    
    -- Cas 1 : un seul vote opposed -> veto immediat
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
                    'favorable_count', v_favorable_votes,
                    'rejecting_voter_user_id', NEW.voter_user_id
                )
            );
        
        -- #114.B : payload enrichi pour diffusion conditionnelle du rationale
        -- selon doctrine 4.2 (rationale visible uniquement si disclose=true)
        PERFORM public.fn_network_notify_event(
            'network.cooptation_rejected',
            jsonb_build_object(
                'proposal_id', NEW.proposal_id,
                'proposed_user_id', v_proposal.proposed_user_id,
                'proposed_by', v_proposal.proposed_by,
                'opposed_count', v_opposed_votes,
                'favorable_count', v_favorable_votes,
                'opposed_voter_user_id', NEW.voter_user_id,
                'disclose_identity', NEW.disclose_identity,
                'rationale', NEW.rationale
            )
        );
        
        RETURN NEW;
    END IF;
    
    -- Cas 2 : tous les admins actifs ont vote favorable -> cooptation effective
    IF v_total_admins > 0 AND v_favorable_votes >= v_total_admins THEN
        INSERT INTO network_administrators 
            (user_id, status, coopted_at, coopted_by_unanimity_of)
            VALUES (
                v_proposal.proposed_user_id, 
                'active', 
                now(), 
                COALESCE(v_voter_ids, ARRAY[]::uuid[])
            );
        
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
        
        PERFORM public.fn_network_notify_event(
            'network.cooptation_completed',
            jsonb_build_object(
                'proposal_id', NEW.proposal_id,
                'proposed_user_id', v_proposal.proposed_user_id,
                'proposed_by', v_proposal.proposed_by,
                'voters', COALESCE(v_voter_ids, ARRAY[]::uuid[])
            )
        );
    END IF;
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_check_cooptation_completion() IS
  '#114.B 2026-05-14: payload network.cooptation_rejected enrichi avec opposed_voter_user_id, disclose_identity, rationale pour diffusion conditionnelle selon doctrine 4.2.';