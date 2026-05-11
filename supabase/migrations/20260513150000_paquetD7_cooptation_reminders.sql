-- ============================================================================
-- Paquet D.7 — Rappels cooptation J+14 et J+25 (spec v0.3 §Q3)
-- ============================================================================
-- Date  : 2026-05-13
-- Auteur: Xavier (AnarBib)
-- Réf.  : docs/spec-administrateur-reseau.md v0.3 §Q3
--
-- Doctrine (5 décisions figées) :
--  1. Compter les jours depuis proposed_at
--  2. Rappels seulement aux admins n'ayant pas voté
--  3. Continue tant que status='open' (même si vote 'against' existe)
--  4. Un seul cron + une fonction (fn_cron_cooptation_send_reminders)
--  5. Idempotence via payload->>'reminder_kind' valant 'j14' ou 'j25'
--
-- Implémentation :
--  - Horaire cron : 25 9 * * * (UTC) = ~11h25 locale Dunkerque été
--  - Event unique : 'network.cooptation_reminder'
--    payload : { proposal_id, proposed_user_id, proposed_by, proposed_at,
--                reminder_kind: 'j14'|'j25', expires_at, pending_voters: [...] }
--  - Détection stricte : proposed_at entre J-15 et J-14 pour j14,
--                         entre J-26 et J-25 pour j25.
--  - Audit dans network_administrator_audit : event_type='cooptation_reminder_sent'
--  - Job cron créé INACTIF (cohérent paquet C et D)
--
-- Effet en prod : aucun. Job inactif, aucune proposition de cooptation
-- actuellement ouverte (0 proposition, 1 seul admin actif).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Fonction d'envoi des rappels (appelée par cron)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_cron_cooptation_send_reminders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
    v_proposal record;
    v_pending_voters jsonb;
    v_outbox_id bigint;
    v_j14_count integer := 0;
    v_j25_count integer := 0;
    v_now timestamptz := now();
BEGIN
    -- =========================================================================
    -- Passe J+14 : propositions créées entre J-15 et J-14
    -- =========================================================================
    FOR v_proposal IN
        SELECT id, proposed_user_id, proposed_by, proposed_at, expires_at
        FROM public.network_administrator_cooptation_proposals
        WHERE status = 'open'
          AND proposed_at >= v_now - interval '15 days'
          AND proposed_at <  v_now - interval '14 days'
    LOOP
        -- Calculer la liste des admins actifs n'ayant pas voté (hors proposé)
        -- C'est cette liste qui sera consommée par l'Edge Function pour le fan-out.
        SELECT COALESCE(jsonb_agg(na.user_id), '[]'::jsonb) INTO v_pending_voters
        FROM public.network_administrators na
        WHERE na.status = 'active'
          AND na.user_id <> v_proposal.proposed_user_id
          AND NOT EXISTS (
              SELECT 1 FROM public.network_administrator_cooptation_votes v
              WHERE v.proposal_id = v_proposal.id
                AND v.voter_user_id = na.user_id
          );

        -- Si la liste est vide (tous ont voté), on saute (la proposition devrait
        -- déjà avoir basculé en autre statut, mais on est prudent)
        IF v_pending_voters = '[]'::jsonb THEN
            CONTINUE;
        END IF;

        -- INSERT outbox : un seul event par proposition, l'Edge Function
        -- résout le fan-out depuis pending_voters[]
        SELECT public.fn_network_notify_event(
            'network.cooptation_reminder',
            jsonb_build_object(
                'proposal_id', v_proposal.id,
                'proposed_user_id', v_proposal.proposed_user_id,
                'proposed_by', v_proposal.proposed_by,
                'proposed_at', v_proposal.proposed_at,
                'expires_at', v_proposal.expires_at,
                'reminder_kind', 'j14',
                'pending_voters', v_pending_voters
            )
        ) INTO v_outbox_id;

        -- Audit
        INSERT INTO public.network_administrator_audit
            (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            v_proposal.proposed_user_id,
            'cooptation_reminder_sent',
            NULL,  -- exécution cron, pas d'actor utilisateur
            v_proposal.proposed_user_id,
            jsonb_build_object(
                'proposal_id', v_proposal.id,
                'reminder_kind', 'j14',
                'pending_voters_count', jsonb_array_length(v_pending_voters),
                'outbox_id', v_outbox_id
            )
        );

        v_j14_count := v_j14_count + 1;
    END LOOP;

    -- =========================================================================
    -- Passe J+25 : propositions créées entre J-26 et J-25
    -- =========================================================================
    FOR v_proposal IN
        SELECT id, proposed_user_id, proposed_by, proposed_at, expires_at
        FROM public.network_administrator_cooptation_proposals
        WHERE status = 'open'
          AND proposed_at >= v_now - interval '26 days'
          AND proposed_at <  v_now - interval '25 days'
    LOOP
        SELECT COALESCE(jsonb_agg(na.user_id), '[]'::jsonb) INTO v_pending_voters
        FROM public.network_administrators na
        WHERE na.status = 'active'
          AND na.user_id <> v_proposal.proposed_user_id
          AND NOT EXISTS (
              SELECT 1 FROM public.network_administrator_cooptation_votes v
              WHERE v.proposal_id = v_proposal.id
                AND v.voter_user_id = na.user_id
          );

        IF v_pending_voters = '[]'::jsonb THEN
            CONTINUE;
        END IF;

        SELECT public.fn_network_notify_event(
            'network.cooptation_reminder',
            jsonb_build_object(
                'proposal_id', v_proposal.id,
                'proposed_user_id', v_proposal.proposed_user_id,
                'proposed_by', v_proposal.proposed_by,
                'proposed_at', v_proposal.proposed_at,
                'expires_at', v_proposal.expires_at,
                'reminder_kind', 'j25',
                'pending_voters', v_pending_voters
            )
        ) INTO v_outbox_id;

        INSERT INTO public.network_administrator_audit
            (user_id, event_type, actor_user_id, target_user_id, metadata)
        VALUES (
            v_proposal.proposed_user_id,
            'cooptation_reminder_sent',
            NULL,
            v_proposal.proposed_user_id,
            jsonb_build_object(
                'proposal_id', v_proposal.id,
                'reminder_kind', 'j25',
                'pending_voters_count', jsonb_array_length(v_pending_voters),
                'outbox_id', v_outbox_id
            )
        );

        v_j25_count := v_j25_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'j14_sent', v_j14_count,
        'j25_sent', v_j25_count,
        'run_at', v_now
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_cron_cooptation_send_reminders() FROM PUBLIC;
-- Pas de GRANT à authenticated : fonction réservée au cron (postgres role)

COMMENT ON FUNCTION public.fn_cron_cooptation_send_reminders() IS 
    'D.7 — Cron quotidien : envoie rappels J+14 et J+25 aux admins n''ayant pas voté sur les propositions de cooptation ouvertes. Détection stricte : fenêtre 24h. Event unique network.cooptation_reminder avec payload->>''reminder_kind''.';


-- ----------------------------------------------------------------------------
-- 2. Job pg_cron : créé INACTIF
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_job_id bigint;
BEGIN
    -- Supprime tout job antérieur du même nom (idempotence)
    PERFORM cron.unschedule(jobid) 
        FROM cron.job 
        WHERE jobname = 'anarbib-cooptation-reminders-daily';
    
    -- Schedule : tous les jours à 09h25 UTC
    SELECT cron.schedule(
        'anarbib-cooptation-reminders-daily',
        '25 9 * * *',
        $cron$SELECT public.fn_cron_cooptation_send_reminders();$cron$
    ) INTO v_job_id;
    
    -- Désactivation immédiate (dormant jusqu'à activation manuelle)
    PERFORM cron.alter_job(v_job_id, active := false);
END;
$$;


COMMIT;

-- ============================================================================
-- Notes post-déploiement
-- ============================================================================
-- 1. Migration enregistrée :
--    SELECT version, name FROM supabase_migrations.schema_migrations
--    ORDER BY version DESC LIMIT 3;
--
-- 2. Fonction créée :
--    SELECT proname FROM pg_proc WHERE proname = 'fn_cron_cooptation_send_reminders';
--
-- 3. Job cron INACTIF (attendu : active = false) :
--    SELECT jobname, schedule, active 
--    FROM cron.job 
--    WHERE jobname = 'anarbib-cooptation-reminders-daily';
--
-- 4. Test fonctionnel manuel (sans activer le cron) :
--    SELECT public.fn_cron_cooptation_send_reminders();
--    -- Attendu si aucune proposition ouverte : {"j14_sent": 0, "j25_sent": 0, "run_at": "..."}
--
-- 5. Activation future :
--    -- a. L'Edge Function notify-event doit savoir traiter network.cooptation_reminder
--    --    (item #78 backlog : ajouter handler)
--    -- b. Activer le cron :
--    --    SELECT cron.alter_job(
--    --        (SELECT jobid FROM cron.job WHERE jobname = 'anarbib-cooptation-reminders-daily'),
--    --        active := true
--    --    );
--
-- 6. Item #80 backlog : passage 7/8 → 8/8 sous-paquets D si D.8 livré.
--    D.7 livré : passage 6/8 → 7/8.
