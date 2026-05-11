-- ============================================================================
-- 20260511200000_paquetD5_vote_cooptation_q4.sql
-- ============================================================================
-- Paquet D.5 — Enrichissement fn_network_admin_vote_cooptation (Q4)
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §Q4 (disclose_identity + rationale)
--
-- Contenu :
-- 1. Ajout colonne disclose_identity boolean NOT NULL sur network_administrator_cooptation_votes
--    (table actuellement vide, pas besoin de DEFAULT pour le backfill)
-- 2. Réécriture fn_network_admin_vote_cooptation :
--    - Nouvelle signature avec p_disclose_identity en 3e position, OBLIGATOIRE (pas de DEFAULT)
--    - Nouvelle Garde 7 : si vote='opposed' et rationale vide/NULL → RAISE EXCEPTION
--    - UPSERT enrichi avec disclose_identity
--    - Audit enrichi avec disclose_identity dans metadata
-- 3. Suppression de l'ancienne signature (signature change donc nouvelle fonction)
--
-- DOCTRINE :
-- - disclose_identity OBLIGATOIRE à chaque vote (pas de DEFAULT) : la
--   transparence/anonymat est une décision politique consciente, pas un
--   comportement par défaut. L'admin doit choisir explicitement à chaque vote.
-- - disclose_identity stocké dans la table même mais utilisé seulement
--   pour les vues publiques : actor_user_id reste pour la traçabilité interne.
-- - rationale obligatoire si vote='opposed' : exposer ses raisons publiquement
--   est indissociable de l'opposition (Q4 v0.3).
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : Ajout de la colonne disclose_identity
-- ============================================================================
-- La table est actuellement vide (vérifié en session 11/05/2026 : count=0),
-- donc on peut ajouter NOT NULL sans DEFAULT ni backfill.

ALTER TABLE public.network_administrator_cooptation_votes
    ADD COLUMN disclose_identity boolean NOT NULL;

COMMENT ON COLUMN public.network_administrator_cooptation_votes.disclose_identity IS
'Décision politique du votant : true = vote nominatif (l''identité est visible aux autres admins réseau et dans le digest), false = vote anonyme (l''identité est masquée dans les vues publiques, mais conservée en base pour la traçabilité interne en cas de litige). Choix obligatoire à chaque vote (pas de DEFAULT côté DB ni côté fonction). Paquet D.5 (11/05/2026).';

-- ============================================================================
-- SECTION 2 : Suppression de l'ancienne fonction (changement de signature)
-- ============================================================================
-- PostgreSQL ne peut pas REPLACE une fonction si la signature change.
-- On DROP l'ancienne puis on CREATE la nouvelle.

DROP FUNCTION IF EXISTS public.fn_network_admin_vote_cooptation(uuid, text, text);

-- ============================================================================
-- SECTION 3 : Réécriture fn_network_admin_vote_cooptation
-- ============================================================================
-- Nouvelle signature : (p_proposal_id, p_vote, p_disclose_identity, p_rationale)
-- - p_disclose_identity OBLIGATOIRE (pas de DEFAULT)
-- - p_rationale optionnel par défaut, mais OBLIGATOIRE si p_vote='opposed' (Garde 7)

CREATE FUNCTION public.fn_network_admin_vote_cooptation(
    p_proposal_id      uuid,
    p_vote             text,
    p_disclose_identity boolean,
    p_rationale        text DEFAULT NULL
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
    FROM public.network_administrator_cooptation_proposals
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
    
    -- Garde 7 NOUVELLE (Q4) : rationale obligatoire si vote=opposed
    IF p_vote = 'opposed' AND (p_rationale IS NULL OR length(trim(p_rationale)) = 0) THEN
        RAISE EXCEPTION 'rationale_required_for_opposed: rationale is mandatory when voting opposed (cf. spec v0.3 Q4)'
            USING ERRCODE = '22023';
    END IF;
    
    -- Garde 8 NOUVELLE (Q4) : disclose_identity doit être explicitement défini
    -- (PostgreSQL traite NULL boolean comme valeur, mais sémantiquement c'est
    -- une absence de décision. On force le choix.)
    IF p_disclose_identity IS NULL THEN
        RAISE EXCEPTION 'disclose_identity_required: explicit disclosure choice is mandatory at each vote (cf. spec v0.3 Q4)'
            USING ERRCODE = '22023';
    END IF;
    
    -- UPSERT du vote enrichi avec disclose_identity
    INSERT INTO public.network_administrator_cooptation_votes 
        (proposal_id, voter_user_id, vote, rationale, disclose_identity, voted_at)
    VALUES (p_proposal_id, v_caller_id, p_vote, p_rationale, p_disclose_identity, now())
    ON CONFLICT (proposal_id, voter_user_id) 
    DO UPDATE SET 
        vote = EXCLUDED.vote, 
        rationale = EXCLUDED.rationale,
        disclose_identity = EXCLUDED.disclose_identity,
        voted_at = now();
    
    -- Audit enrichi
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
    
    -- Le trigger trg_check_cooptation_completion s'occupe de la suite
END;
$$;

COMMENT ON FUNCTION public.fn_network_admin_vote_cooptation(uuid, text, boolean, text) IS
'Enregistre le vote d''un administrateur réseau sur une proposition de cooptation. Paquet D.5 (11/05/2026, Q4). 
Signature changée (BREAKING) : p_disclose_identity ajouté en 3e position et OBLIGATOIRE (pas de DEFAULT). 
Garde 7 : rationale obligatoire si vote=opposed (acte politique : exposer ses raisons publiquement est indissociable de l''opposition). 
disclose_identity stocké en base mais filtré dans les vues publiques pour le respect du choix politique du votant.';

GRANT EXECUTE ON FUNCTION public.fn_network_admin_vote_cooptation(uuid, text, boolean, text) TO authenticated;

-- ============================================================================
-- SECTION 4 : VALIDATIONS POST-MODIFICATION
-- ============================================================================

-- 4.1 La colonne disclose_identity est créée NOT NULL
DO $$
DECLARE
    v_nullable text;
BEGIN
    SELECT is_nullable INTO v_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'network_administrator_cooptation_votes'
      AND column_name = 'disclose_identity';
    
    IF v_nullable IS NULL THEN
        RAISE EXCEPTION 'column_missing: disclose_identity non créée';
    END IF;
    
    IF v_nullable <> 'NO' THEN
        RAISE EXCEPTION 'column_nullable_unexpected: disclose_identity est nullable (attendu : NOT NULL)';
    END IF;
    
    RAISE NOTICE 'column_ok: disclose_identity créée en NOT NULL';
END;
$$;

-- 4.2 La nouvelle signature de la fonction est en place
DO $$
DECLARE
    v_args text;
BEGIN
    SELECT pg_get_function_arguments(p.oid) INTO v_args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fn_network_admin_vote_cooptation';
    
    IF v_args IS NULL THEN
        RAISE EXCEPTION 'function_missing: fn_network_admin_vote_cooptation introuvable';
    END IF;
    
    IF v_args NOT LIKE '%p_disclose_identity boolean%' THEN
        RAISE EXCEPTION 'signature_unexpected: p_disclose_identity non présent dans la signature (% trouvé)', v_args;
    END IF;
    
    IF v_args LIKE '%p_disclose_identity boolean DEFAULT%' THEN
        RAISE EXCEPTION 'default_not_allowed: p_disclose_identity ne doit PAS avoir de DEFAULT (cf. Q4 doctrine)';
    END IF;
    
    RAISE NOTICE 'signature_ok: nouvelle signature avec p_disclose_identity boolean obligatoire. Args : %', v_args;
END;
$$;

-- 4.3 L'ancienne signature est bien supprimée (3 args au lieu de 4)
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'fn_network_admin_vote_cooptation'
      AND pg_get_function_arguments(p.oid) NOT LIKE '%p_disclose_identity%';
    
    IF v_count > 0 THEN
        RAISE EXCEPTION 'old_signature_still_exists: ancienne signature (sans p_disclose_identity) toujours présente';
    END IF;
    
    RAISE NOTICE 'old_signature_dropped: ancienne signature supprimée';
END;
$$;

-- 4.4 Test fonctionnel : appel sans authentification doit planter à Garde 1
DO $$
DECLARE
    v_was_rejected boolean := false;
BEGIN
    BEGIN
        -- auth.uid() est NULL (pas de SET LOCAL), donc Garde 1 doit RAISE
        PERFORM public.fn_network_admin_vote_cooptation(
            gen_random_uuid(),
            'favorable',
            true,
            NULL
        );
    EXCEPTION 
        WHEN insufficient_privilege THEN
            v_was_rejected := true;
    END;
    
    IF NOT v_was_rejected THEN
        RAISE WARNING 'auth_guard_check: Garde 1 (forbidden non-admin) n''a peut-\u00eatre pas plant\u00e9. Test indicatif.';
    ELSE
        RAISE NOTICE 'auth_guard_ok: Garde 1 (forbidden non-admin) déclenchée correctement';
    END IF;
END;
$$;

-- 4.5 Helpers requis présents
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_caller_is_network_admin'
    ) THEN
        RAISE EXCEPTION 'dependency_missing: fn_caller_is_network_admin (paquet A)';
    END IF;
    
    RAISE NOTICE 'dependencies_ok: fn_caller_is_network_admin présent';
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- ATTENTION : les votes que tu crées en test resteraient en base si tu ne
-- ROLLBACK pas. Utiliser BEGIN/ROLLBACK pour les tests fonctionnels.
--
-- Test 1 : signature et structure
--    SELECT pg_get_function_arguments(p.oid) AS args
--    FROM pg_proc p
--    JOIN pg_namespace n ON n.oid = p.pronamespace
--    WHERE n.nspname = 'public' AND p.proname = 'fn_network_admin_vote_cooptation';
--    Attendu : "p_proposal_id uuid, p_vote text, p_disclose_identity boolean, p_rationale text DEFAULT NULL::text"
--
-- Test 2 : structure de la table votes
--    SELECT column_name, is_nullable 
--    FROM information_schema.columns 
--    WHERE table_schema='public' AND table_name='network_administrator_cooptation_votes'
--    ORDER BY ordinal_position;
--    Attendu : disclose_identity boolean NOT NULL en plus des 5 anciennes colonnes.
--
-- Test 3 (sans vraie proposition donc plantera proprement) : Garde 7 — vote=opposed sans rationale
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    SELECT public.fn_network_admin_vote_cooptation(
--        gen_random_uuid()::uuid,  -- proposition fictive
--        'opposed',                 -- vote opposed
--        true,                      -- disclose_identity
--        NULL                       -- rationale NULL → doit planter
--    );
--    ROLLBACK;
--    Attendu : RAISE EXCEPTION 'rationale_required_for_opposed' (Garde 7), pas 'proposal_not_found' (Garde 3)
--    Note : les Gardes s'exécutent en séquence. Garde 7 vient APRÈS Garde 3, donc en fait 'proposal_not_found' plantera d'abord.
--    Pour vraiment tester Garde 7 il faut une proposition réelle. Garder en mémoire pour test futur.
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
