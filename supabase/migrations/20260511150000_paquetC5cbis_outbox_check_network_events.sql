-- ============================================================================
-- 20260511150000_paquetC5cbis_outbox_check_network_events.sql
-- ============================================================================
-- Paquet C.5c-bis — Élargissement du CHECK constraint event_check pour
--                   accepter les events 'network.%' (en plus de 'team.%').
--
-- Contexte du fix :
--   Le paquet C.5c a installé le trigger trg_cross_lib_log_critical_notification
--   qui insère un event 'network.cross_library_critical_action' dans
--   public.team_notification_outbox. Mais la contrainte CHECK existante
--   sur cette table n'autorisait que les events préfixés 'team.%'.
--   
--   Le trigger fonctionne, mais l'INSERT dans l'outbox plante avec :
--   ERROR: 23514: new row for relation "team_notification_outbox" violates
--   check constraint "team_notification_outbox_event_check"
--   
-- Le fix : élargir le CHECK pour accepter (event LIKE 'team.%' OR LIKE 'network.%').
--
-- Décision architecturale (session 11/05/2026) :
--   On n'a pas voulu renommer le préfixe en team.network.* ni utiliser team.*
--   tout court parce que les events 'network.*' reflètent une dimension
--   architecturale réelle (Q2 + Q6 de la spec : actions transverses des
--   admins réseau). Le préfixe est porteur de sens.
--
--   La table reste nommée team_notification_outbox même si elle accueille
--   désormais des events network.*. Renommer la table serait un changement
--   plus radical hors scope du paquet C.
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : Réécriture du CHECK constraint
-- ============================================================================

ALTER TABLE public.team_notification_outbox
    DROP CONSTRAINT team_notification_outbox_event_check;

ALTER TABLE public.team_notification_outbox
    ADD CONSTRAINT team_notification_outbox_event_check
    CHECK (event ~~ 'team.%' OR event ~~ 'network.%');

COMMENT ON CONSTRAINT team_notification_outbox_event_check 
    ON public.team_notification_outbox IS
'Whitelist des préfixes d''events autorisés dans cette file outbox : team.* (notifications de gestion du staff) ou network.* (notifications d''actions transverses des admins réseau). Élargi au paquet C.5c-bis (11/05/2026).';

-- ============================================================================
-- SECTION 2 : VALIDATIONS POST-MODIFICATION
-- ============================================================================

-- 2.1 Le nouveau CHECK est en place avec les deux préfixes
DO $$
DECLARE
    v_def text;
BEGIN
    SELECT pg_get_constraintdef(c.oid) INTO v_def
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'team_notification_outbox'
      AND c.conname = 'team_notification_outbox_event_check';
    
    IF v_def IS NULL THEN
        RAISE EXCEPTION 'check_missing: team_notification_outbox_event_check pas trouvé';
    END IF;
    
    IF v_def NOT LIKE '%team.%' OR v_def NOT LIKE '%network.%' THEN
        RAISE EXCEPTION 'check_unexpected: CHECK ne mentionne pas team.* ET network.* (% trouvé)', v_def;
    END IF;
    
    RAISE NOTICE 'check_ok: CHECK élargi avec succès. Définition : %', v_def;
END;
$$;

-- 2.2 Test fonctionnel : un event network.* peut maintenant être inséré
-- (avec ROLLBACK pour ne pas polluer l'outbox)
DO $$
DECLARE
    v_test_id bigint;
BEGIN
    INSERT INTO public.team_notification_outbox (event, payload)
    VALUES (
        'network.test_check_validation',
        '{"validation": "C.5c-bis paquet"}'::jsonb
    ) RETURNING id INTO v_test_id;
    
    IF v_test_id IS NULL THEN
        RAISE EXCEPTION 'insert_network_failed: l''INSERT d''un event network.* a échoué silencieusement';
    END IF;
    
    RAISE NOTICE 'insert_network_ok: event network.* peut être inséré (id=%)', v_test_id;
    
    -- Nettoyer la ligne de test
    DELETE FROM public.team_notification_outbox WHERE id = v_test_id;
    
    RAISE NOTICE 'cleanup_ok: ligne de test retirée';
END;
$$;

-- 2.3 Test fonctionnel : un event team.* reste autorisé (régression non introduite)
DO $$
DECLARE
    v_test_id bigint;
BEGIN
    INSERT INTO public.team_notification_outbox (event, payload)
    VALUES (
        'team.test_check_regression',
        '{"validation": "C.5c-bis no regression"}'::jsonb
    ) RETURNING id INTO v_test_id;
    
    IF v_test_id IS NULL THEN
        RAISE EXCEPTION 'insert_team_failed: l''INSERT d''un event team.* a échoué (régression !)';
    END IF;
    
    RAISE NOTICE 'insert_team_ok: event team.* toujours autorisé (id=%)', v_test_id;
    
    -- Nettoyer la ligne de test
    DELETE FROM public.team_notification_outbox WHERE id = v_test_id;
    
    RAISE NOTICE 'cleanup_ok: ligne de test retirée';
END;
$$;

-- 2.4 Test fonctionnel : un event d'un autre préfixe est toujours rejeté
DO $$
DECLARE
    v_was_rejected boolean := false;
BEGIN
    BEGIN
        INSERT INTO public.team_notification_outbox (event, payload)
        VALUES (
            'unauthorized.fake_event',
            '{}'::jsonb
        );
    EXCEPTION 
        WHEN check_violation THEN
            v_was_rejected := true;
    END;
    
    IF NOT v_was_rejected THEN
        RAISE EXCEPTION 'check_too_permissive: un event d''un préfixe inconnu n''a pas été rejeté';
    END IF;
    
    RAISE NOTICE 'check_protects_ok: events d''autres préfixes toujours rejetés (CHECK actif)';
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
--
-- 1. Vérifier la nouvelle définition du CHECK :
--    SELECT conname, pg_get_constraintdef(c.oid) AS definition
--    FROM pg_constraint c
--    JOIN pg_class t ON t.oid = c.conrelid
--    WHERE t.relname = 'team_notification_outbox' AND c.contype = 'c';
--
-- 2. Refaire le test du trigger C.5c (qui plantait avant le fix) :
--    BEGIN;
--    INSERT INTO public.network_admin_cross_library_actions_log
--      (actor_user_id, library_id, action_type, is_critical, payload)
--    VALUES (
--      'd6710372-e5e5-4608-800b-99a26817c677',
--      'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a',
--      'test_trigger_critical_post_fix', true,
--      '{"manual_validation": "C.5c-bis"}'::jsonb
--    );
--    SELECT id, event, payload->>'action_type' AS action_type
--    FROM public.team_notification_outbox
--    WHERE event = 'network.cross_library_critical_action'
--    ORDER BY id DESC LIMIT 1;
--    ROLLBACK;
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
