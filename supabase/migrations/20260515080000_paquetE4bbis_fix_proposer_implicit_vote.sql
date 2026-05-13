-- ============================================================================
-- Paquet E.4.b.bis - Fix vote implicite proposeur (disclose_identity NOT NULL)
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Ref.  : docs/spec-administrateur-reseau.md v0.3 (cooptation D.5)
--
-- Contexte
-- --------
-- Bug dormant detecte au premier appel reel de fn_network_admin_propose_
-- cooptation (test fonctionnel E.4.b, proposition Xavier -> Patricia) :
--
--   ERROR: null value in column "disclose_identity" of relation
--   "network_administrator_cooptation_votes" violates not-null constraint
--
-- Origine : depuis D.5, la fonction fn_network_admin_propose_cooptation
-- inserait un vote favorable implicite pour le proposeur SANS fournir
-- disclose_identity, alors que cette colonne est NOT NULL en table.
-- La transaction etait rollback atomiquement (rien a nettoyer cote DB).
--
-- Doctrine v0.3 pour ce cas
-- -------------------------
-- "disclose_identity choix explicite obligatoire pour chaque vote, pas de
-- DEFAULT" -- c'est valide pour les votes utilisateur via RPC vote.
-- Le vote favorable du proposeur n'est cependant pas un vote utilisateur :
-- c'est une consequence mecanique de la proposition. Le proposeur est de
-- toute facon visible (champ proposed_by sur la proposition).
--
-- => disclose_identity = TRUE pour le vote implicite du proposeur
--    (le proposeur est deja identifie de fait, garder cette coherence)
--
-- Modification chirurgicale
-- -------------------------
-- CREATE OR REPLACE FUNCTION fn_network_admin_propose_cooptation avec :
--   INSERT INTO network_administrator_cooptation_votes
--       (proposal_id, voter_user_id, vote, rationale, disclose_identity)
--       VALUES (v_proposal_id, v_caller_id, 'favorable',
--               'Proposeur, vote implicite', TRUE);
--
-- Tout le reste de la fonction est strictement inchange (gardes 1-6,
-- audit, notification outbox via fn_network_notify_event).
-- ============================================================================

BEGIN;

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
    -- E.4.b.bis : ajout disclose_identity=TRUE (colonne NOT NULL).
    -- Le proposeur est de toute facon visible via le champ proposed_by
    -- de la proposition : garder identite disclosee est coherent.
    INSERT INTO network_administrator_cooptation_votes
        (proposal_id, voter_user_id, vote, rationale, disclose_identity)
        VALUES (v_proposal_id, v_caller_id, 'favorable',
                'Proposeur, vote implicite', TRUE);
    
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
    
    -- Notification outbox (E.1bis : 1 INSERT par event, fan-out cote EF)
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

COMMIT;

-- ============================================================================
-- Notes post-deploiement
-- ============================================================================
-- 1. Migration enregistree :
--    SELECT version, name FROM supabase_migrations.schema_migrations
--    ORDER BY version DESC LIMIT 3;
--
-- 2. Test bout-en-bout : refaire le test E.4.b (Xavier propose Patricia)
--    via UI ou via SQL :
--    -- (en mode authenticated Xavier - SET LOCAL ROLE + JWT)
--    SELECT fn_network_admin_propose_cooptation(
--        '2a42b6bd-d159-4ee0-b66b-28a03062232b'::uuid,
--        'Patricia coordonne BLMF depuis 2024 et porte la doctrine federative.'
--    );
--    -- Attendu : retourne un UUID, pas d'erreur disclose_identity
--
-- 3. Verifier que le vote implicite est bien insere avec disclose_identity=TRUE :
--    SELECT v.proposal_id, v.voter_user_id, v.vote, v.rationale, v.disclose_identity
--    FROM network_administrator_cooptation_votes v
--    JOIN network_administrator_cooptation_proposals p ON p.id = v.proposal_id
--    WHERE p.proposed_user_id = '2a42b6bd-d159-4ee0-b66b-28a03062232b';
--    -- Attendu : 1 ligne, disclose_identity=true
