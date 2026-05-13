-- ============================================================================
-- Paquet E.1bis - Notifications cooptation (4 events)
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Ref.  : docs/spec-administrateur-reseau.md v0.3 (cooptation)
--
-- Contexte
-- --------
-- Decouvert lors de l'audit E.1 : les RPC cooptation existantes
-- (fn_network_admin_propose_cooptation, fn_network_admin_vote_cooptation)
-- ne notifient personne. Le trigger trg_check_cooptation_completion non plus.
-- Cooptation totalement silencieuse cote communication.
--
-- Doctrine v0.3 (3 decisions figees) :
--   Q1 transparence vote intermediaire : notifier autres admins (hors votant, hors target)
--   Q3 rejected : target + proposeur + autres admins
--   Q4 completed : target + proposeur + autres admins, avec variante target_intro
--
-- 3 modifications DB :
--   1. fn_network_admin_propose_cooptation -> PERFORM fn_network_notify_event
--      avec event 'network.cooptation_proposed'
--   2. fn_network_admin_vote_cooptation -> PERFORM fn_network_notify_event
--      avec event 'network.cooptation_voted' (un INSERT par vote intermediaire)
--   3. trg_check_cooptation_completion -> PERFORM pour events
--      'network.cooptation_rejected' (1 vote opposed = veto) et
--      'network.cooptation_completed' (unanimite atteinte)
--
-- Pattern : un seul INSERT outbox par event, fan-out resolu cote Edge Function.
-- L'Edge Function lira le payload jsonb (proposed_user_id, proposed_by, etc.)
-- et resoudra les destinataires (target / proposeur / autres admins).
--
-- Effet en prod : aucun. Aucune proposition de cooptation actuellement ouverte.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Patch fn_network_admin_propose_cooptation
-- ----------------------------------------------------------------------------
-- Ajout PERFORM fn_network_notify_event apres INSERT proposal + audit.
-- Tout le reste de la fonction est conserve a l'identique.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_network_admin_propose_cooptation(
    p_user_id uuid,
    p_motivation text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_proposal_id uuid;
    v_caller_id uuid := auth.uid();
    v_expires_at timestamptz;
BEGIN
    -- Garde 1 : l'appelant doit etre admin reseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can propose cooptation'
            USING ERRCODE = '42501';
    END IF;
    
    -- Garde 2 : la personne proposee doit exister dans auth.users
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'user_not_found: target user does not exist'
            USING ERRCODE = 'P0002';
    END IF;
    
    -- Garde 3 : la personne proposee ne doit pas deja etre admin reseau actif
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
    
    -- Garde 5 : motivation suffisante
    IF length(trim(coalesce(p_motivation, ''))) < 20 THEN
        RAISE EXCEPTION 'motivation_too_short: motivation must be at least 20 characters'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 6 : ne pas se proposer soi-meme
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'self_proposal_forbidden: you cannot propose yourself'
            USING ERRCODE = '42501';
    END IF;
    
    -- Creation de la proposition
    INSERT INTO network_administrator_cooptation_proposals
        (proposed_user_id, proposed_by, motivation)
        VALUES (p_user_id, v_caller_id, p_motivation)
        RETURNING id, expires_at INTO v_proposal_id, v_expires_at;
    
    -- Vote automatique favorable du proposeur
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
    
    -- E.1bis : notification outbox (1 seul INSERT, fan-out cote Edge Function)
    PERFORM public.fn_network_notify_event(
        'network.cooptation_proposed',
        jsonb_build_object(
            'proposal_id', v_proposal_id,
            'proposed_user_id', p_user_id,
            'proposed_by', v_caller_id,
            'motivation_preview', left(trim(p_motivation), 200),
            'expires_at', v_expires_at
        )
    );
    
    RETURN v_proposal_id;
END;
$function$;


-- ----------------------------------------------------------------------------
-- 2. Patch fn_network_admin_vote_cooptation
-- ----------------------------------------------------------------------------
-- Ajout PERFORM fn_network_notify_event apres UPSERT vote + audit.
-- Note : ce PERFORM emet 'network.cooptation_voted' meme si le vote est decisif
-- (opposed = veto, ou dernier favorable = unanimite). Le trigger
-- trg_check_cooptation_completion ajoutera son propre event rejected/completed
-- en post-processing. Donc pour une cooptation qui se conclut, 2 events outbox
-- sont emis : voted (par la RPC) puis rejected ou completed (par le trigger).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_network_admin_vote_cooptation(
    p_proposal_id uuid,
    p_vote text,
    p_disclose_identity boolean,
    p_rationale text DEFAULT NULL::text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_proposal record;
BEGIN
    -- Garde 1 : l'appelant doit etre admin reseau actif
    IF NOT fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only active network administrators can vote'
            USING ERRCODE = '42501';
    END IF;
    
    -- Garde 2 : le vote doit etre valide
    IF p_vote IS NULL OR p_vote NOT IN ('favorable', 'opposed', 'abstain') THEN
        RAISE EXCEPTION 'invalid_vote: vote must be favorable, opposed, or abstain'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 3 : la proposition doit exister
    SELECT * INTO v_proposal 
    FROM public.network_administrator_cooptation_proposals
    WHERE id = p_proposal_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'proposal_not_found'
            USING ERRCODE = 'P0002';
    END IF;
    
    -- Garde 4 : la proposition doit etre ouverte
    IF v_proposal.status <> 'open' THEN
        RAISE EXCEPTION 'proposal_closed: proposal is no longer open (status=%)', v_proposal.status
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 5 : pas expiree
    IF v_proposal.expires_at < now() THEN
        RAISE EXCEPTION 'proposal_expired'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 6 : on ne vote pas sur soi-meme
    IF v_proposal.proposed_user_id = v_caller_id THEN
        RAISE EXCEPTION 'self_vote_forbidden: you cannot vote on your own cooptation'
            USING ERRCODE = '42501';
    END IF;
    
    -- Garde 7 (Q4) : rationale obligatoire si vote=opposed
    IF p_vote = 'opposed' AND (p_rationale IS NULL OR length(trim(p_rationale)) = 0) THEN
        RAISE EXCEPTION 'rationale_required_for_opposed: rationale is mandatory when voting opposed (cf. spec v0.3 Q4)'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 8 (Q4) : disclose_identity doit etre explicitement defini
    IF p_disclose_identity IS NULL THEN
        RAISE EXCEPTION 'disclose_identity_required: explicit disclosure choice is mandatory at each vote (cf. spec v0.3 Q4)'
            USING ERRCODE = '22023';
    END IF;
    
    -- UPSERT du vote
    INSERT INTO public.network_administrator_cooptation_votes 
        (proposal_id, voter_user_id, vote, rationale, disclose_identity, voted_at)
    VALUES (p_proposal_id, v_caller_id, p_vote, p_rationale, p_disclose_identity, now())
    ON CONFLICT (proposal_id, voter_user_id) 
    DO UPDATE SET 
        vote = EXCLUDED.vote, 
        rationale = EXCLUDED.rationale,
        disclose_identity = EXCLUDED.disclose_identity,
        voted_at = now();
    
    -- Audit
    INSERT INTO public.network_administrator_audit 
        (user_id, event_type, actor_user_id, target_user_id, metadata)
    VALUES (
        v_proposal.proposed_user_id, 
        'cooptation_voted', 
        v_caller_id, 
        v_proposal.proposed_user_id, 
        jsonb_build_object(
            'proposal_id', p_proposal_id, 
            'vote', p_vote,
            'disclose_identity', p_disclose_identity,
            'has_rationale', (p_rationale IS NOT NULL AND length(trim(p_rationale)) > 0)
        )
    );
    
    -- E.1bis : notification outbox du vote intermediaire (Q1 transparence)
    -- Le trigger trg_check_cooptation_completion ajoutera son propre event
    -- rejected/completed en post-processing s'il y a lieu.
    PERFORM public.fn_network_notify_event(
        'network.cooptation_voted',
        jsonb_build_object(
            'proposal_id', p_proposal_id,
            'proposed_user_id', v_proposal.proposed_user_id,
            'proposed_by', v_proposal.proposed_by,
            'vote', p_vote,
            'voter_user_id', CASE WHEN p_disclose_identity THEN v_caller_id ELSE NULL END,
            'disclose_identity', p_disclose_identity
        )
    );
    
    -- Le trigger trg_check_cooptation_completion s'occupe de la suite
END;
$function$;


-- ----------------------------------------------------------------------------
-- 3. Patch trg_check_cooptation_completion
-- ----------------------------------------------------------------------------
-- Ajout PERFORM pour les events 'network.cooptation_rejected' (cas 1)
-- et 'network.cooptation_completed' (cas 2).
-- Tout le reste de la fonction trigger est conserve a l'identique.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_check_cooptation_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_proposal record;
    v_total_admins integer;
    v_favorable_votes integer;
    v_opposed_votes integer;
    v_voter_ids uuid[];
BEGIN
    -- Recupere la proposition
    SELECT * INTO v_proposal 
        FROM network_administrator_cooptation_proposals
        WHERE id = NEW.proposal_id;
    
    IF v_proposal.status <> 'open' THEN
        -- Proposition deja cloturee, rien a faire
        RETURN NEW;
    END IF;
    
    -- Compte des admins actifs hors propose
    SELECT count(*) INTO v_total_admins 
        FROM network_administrators
        WHERE status = 'active' 
          AND user_id <> v_proposal.proposed_user_id;
    
    -- Compte des votes
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
                    'favorable_count', v_favorable_votes
                )
            );
        
        -- E.1bis : notification outbox rejected
        -- Q3 : target + proposeur + autres admins
        PERFORM public.fn_network_notify_event(
            'network.cooptation_rejected',
            jsonb_build_object(
                'proposal_id', NEW.proposal_id,
                'proposed_user_id', v_proposal.proposed_user_id,
                'proposed_by', v_proposal.proposed_by,
                'opposed_count', v_opposed_votes,
                'favorable_count', v_favorable_votes
            )
        );
        
        RETURN NEW;
    END IF;
    
    -- Cas 2 : tous les admins actifs ont vote favorable -> cooptation effective
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
        
        -- Cloture de la proposition
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
        
        -- E.1bis : notification outbox completed
        -- Q4 : target + proposeur + autres admins (avec variante target_intro
        -- cote i18n / Edge Function pour le nouvel admin)
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
    
    -- Cas 3 : votes encore manquants -> on attend
    RETURN NEW;
END;
$function$;


COMMIT;

-- ============================================================================
-- Notes post-deploiement
-- ============================================================================
-- 1. Migration enregistree :
--    SELECT version, name FROM supabase_migrations.schema_migrations
--    ORDER BY version DESC LIMIT 3;
--
-- 2. Verifier que les 3 fonctions emettent bien les events :
--    SELECT proname FROM pg_proc 
--    WHERE proname IN (
--      'fn_network_admin_propose_cooptation',
--      'fn_network_admin_vote_cooptation',
--      'trg_check_cooptation_completion'
--    ) AND pg_get_functiondef(oid) LIKE '%fn_network_notify_event%';
--    -- Attendu : 3 lignes
--
-- 3. Verifier qu'aucun event cooptation n'est encore en outbox (pas de prop ouverte) :
--    SELECT count(*) FROM team_notification_outbox 
--    WHERE event LIKE 'network.cooptation_%';
--    -- Attendu : 0 (aucune cooptation en cours actuellement)
--
-- 4. Le i18n de ces events est livre dans le meme commit (bloc insere dans
--    supabase/functions/_shared/i18n/mail-strings.ts).
--
-- 5. L'Edge Function notify-event doit savoir traiter ces 4 events pour faire
--    le fan-out vers les destinataires (target / proposeur / autres admins).
--    C'est l'item #78 du backlog.
