-- ============================================================================
-- 20260511140000_paquetC5c_cross_library_actions_notifications.sql
-- ============================================================================
-- Paquet C.5c — Mécanisme de notification des actions transverses
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3.1 (Q6)
--
-- Deux mécanismes complémentaires (décidés en session 11/05/2026) :
--
-- 1. NOTIFICATION IMMÉDIATE pour actions critiques (is_critical=true)
--    Trigger AFTER INSERT sur network_admin_cross_library_actions_log
--    qui insère un event 'network.cross_library_critical_action' dans
--    team_notification_outbox.
--    Le traitement de l'outbox (HTTP vers notify-event) est déjà en place
--    pour les events team.*, le pattern se généralise.
--
-- 2. DIGEST HEBDOMADAIRE pour TOUTES les actions transverses
--    Job pg_cron lundi 8h30 (après les deux rapports existants).
--    Pattern HTTP direct via net.http_post vers une Edge Function dédiée
--    notify-cross-library-digest (à créer dans un paquet de code séparé).
--    Le digest inclut TOUTES les actions transverses de la semaine passée,
--    avec un marqueur pour celles déjà notifiées immédiatement (Q6).
--
-- IMPORTANT : le job pg_cron est créé en active=FALSE car l'Edge Function
-- cible n'existe pas encore. À activer manuellement après son déploiement :
--   UPDATE cron.job SET active = true 
--   WHERE jobname = 'anarbib-notify-cross-library-digest-weekly';
--
-- NON inclus dans C.5c :
--   - Edge Function notify-cross-library-digest (à créer séparément)
--   - Modification des RPC existantes pour appeler fn_log_cross_library_action
--     (paquet D : refactorisation RPC + workflow retrait complet)
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : TRIGGER POUR NOTIFICATION IMMÉDIATE DES ACTIONS CRITIQUES
-- ============================================================================

-- Trigger qui s'active après chaque INSERT dans cross_library_actions_log.
-- Si is_critical=true, insère un event dans team_notification_outbox.
-- Le système d'envoi mail existant traitera l'event de manière asynchrone.
CREATE OR REPLACE FUNCTION public.tg_cross_lib_log_critical_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_library_slug text;
    v_library_name text;
    v_actor_email text;
    v_actor_full_name text;
BEGIN
    -- On n'agit que sur les actions marquées critiques
    IF NOT NEW.is_critical THEN
        RETURN NEW;
    END IF;
    
    -- Récupérer les infos contextuelles pour le payload de l'event
    -- (l'Edge Function notify-event aura besoin de tout ça pour composer le mail)
    SELECT l.slug, l.name 
    INTO v_library_slug, v_library_name
    FROM public.libraries l
    WHERE l.id = NEW.library_id;
    
    SELECT 
        p.email,
        coalesce(
            nullif(trim(p.first_name || ' ' || coalesce(p.last_name, '')), ''),
            p.email
        )
    INTO v_actor_email, v_actor_full_name
    FROM public.profiles p
    WHERE p.id = NEW.actor_user_id;
    
    -- Insérer l'event dans la file outbox
    -- Le payload contient toutes les infos nécessaires à l'Edge Function
    -- pour composer un mail i18n aux coordenadores actifs de la biblio
    INSERT INTO public.team_notification_outbox (event, payload)
    VALUES (
        'network.cross_library_critical_action',
        jsonb_build_object(
            'log_id', NEW.id,
            'library_id', NEW.library_id,
            'library_slug', v_library_slug,
            'library_name', v_library_name,
            'actor_user_id', NEW.actor_user_id,
            'actor_email', v_actor_email,
            'actor_full_name', v_actor_full_name,
            'action_type', NEW.action_type,
            'target_entity_type', NEW.target_entity_type,
            'target_entity_id', NEW.target_entity_id,
            'action_payload', NEW.payload,
            'occurred_at', NEW.created_at
        )
    );
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.tg_cross_lib_log_critical_notification() IS
'Trigger AFTER INSERT sur network_admin_cross_library_actions_log : si l''action est marquée critique (is_critical=true), insère un event ''network.cross_library_critical_action'' dans team_notification_outbox pour notification immédiate aux coordenadores actifs de la biblio. Paquet C.5c (11/05/2026).';

CREATE TRIGGER trg_cross_lib_log_critical_notification
    AFTER INSERT ON public.network_admin_cross_library_actions_log
    FOR EACH ROW
    EXECUTE FUNCTION public.tg_cross_lib_log_critical_notification();

-- ============================================================================
-- SECTION 2 : FONCTION DU CRON HEBDOMADAIRE (DIGEST)
-- ============================================================================
-- Suit strictement le pattern de fn_cron_notify_network_weekly_report :
--   1. Récupère URL Supabase + secret webhook depuis le vault
--   2. Calcule la semaine ISO précédente
--   3. Émet un net.http_post vers l'Edge Function notify-cross-library-digest
--   4. Retourne l'ID de la requête

CREATE OR REPLACE FUNCTION public.fn_cron_notify_cross_library_digest()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'vault', 'extensions', 'pg_temp'
AS $$
DECLARE
    v_url     text;
    v_secret  text;
    v_req_id  bigint;
    v_week    record;
BEGIN
    -- URL de l'Edge Function cible
    v_url := regexp_replace(
        public.fn_internal_get_vault_secret('SUPABASE_URL'),
        '/+$', ''
    ) || '/functions/v1/notify-cross-library-digest';
    
    -- Secret pour authentifier le webhook côté Edge Function
    -- Le secret doit être créé dans le vault avec le nom 
    -- WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST avant activation du cron.
    v_secret := public.fn_internal_get_vault_secret('WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST');
    
    -- Semaine ISO précédente (pour le digest hebdo)
    SELECT * INTO v_week FROM public.fn_internal_previous_iso_week();
    
    -- HTTP POST vers l'Edge Function
    v_req_id := net.http_post(
        url := v_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-webhook-secret', v_secret
        ),
        body := jsonb_build_object(
            'source', 'pg_cron',
            'job', 'anarbib-notify-cross-library-digest-weekly',
            'scheduled_at', now(),
            'week_start', to_char(v_week.week_start, 'YYYY-MM-DD'),
            'week_end',   to_char(v_week.week_end,   'YYYY-MM-DD'),
            'tz', 'UTC'
        ),
        timeout_milliseconds := 60000
    );
    
    RETURN v_req_id;
END;
$$;

COMMENT ON FUNCTION public.fn_cron_notify_cross_library_digest() IS
'Trigger un net.http_post vers l''Edge Function notify-cross-library-digest. Appelée par le job pg_cron anarbib-notify-cross-library-digest-weekly chaque lundi à 8h30. L''Edge Function lira la table network_admin_cross_library_actions_log pour la semaine ISO précédente et enverra un digest mail aux coordenadores actifs de chaque biblio concernée, avec marqueur pour les actions déjà notifiées immédiatement (Q6). Paquet C.5c (11/05/2026).';

-- ============================================================================
-- SECTION 3 : JOB pg_cron (CRÉÉ EN INACTIF)
-- ============================================================================
-- Le job est créé en active=false car l'Edge Function notify-cross-library-digest
-- n'existe pas encore. Activation manuelle après son déploiement :
--   UPDATE cron.job SET active = true 
--   WHERE jobname = 'anarbib-notify-cross-library-digest-weekly';

DO $$
DECLARE
    v_job_id bigint;
BEGIN
    -- cron.schedule retourne l'ID du job créé
    -- Pattern '30 8 * * 1' = lundi 8h30 UTC
    v_job_id := cron.schedule(
        job_name := 'anarbib-notify-cross-library-digest-weekly',
        schedule := '30 8 * * 1',
        command := 'SELECT public.fn_cron_notify_cross_library_digest();'
    );
    
    -- Désactiver le job immédiatement (Edge Function pas encore créée).
    -- On utilise cron.alter_job() plutôt qu'UPDATE direct sur cron.job
    -- parce que la table cron.job nécessite des privilèges qui ne sont pas
    -- accordés au rôle exécutant la migration (postgres CI), alors que
    -- cron.alter_job est conçue pour fonctionner avec les permissions du
    -- propriétaire du job.
    PERFORM cron.alter_job(job_id := v_job_id, active := false);
    
    RAISE NOTICE 'cron_job_ok: job anarbib-notify-cross-library-digest-weekly créé (id=%) et désactivé. À activer après déploiement de l''Edge Function notify-cross-library-digest et création du secret WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST dans le vault.', v_job_id;
END;
$$;

-- ============================================================================
-- SECTION 4 : VALIDATIONS POST-CRÉATION
-- ============================================================================

-- 4.1 Trigger d'event immédiat installé
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'network_admin_cross_library_actions_log'
      AND t.tgname = 'trg_cross_lib_log_critical_notification';
    
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'trigger_missing: trg_cross_lib_log_critical_notification pas créé';
    END IF;
    
    RAISE NOTICE 'trigger_ok: trg_cross_lib_log_critical_notification installé';
END;
$$;

-- 4.2 Fonction du cron créée
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' 
          AND p.proname = 'fn_cron_notify_cross_library_digest'
    ) THEN
        RAISE EXCEPTION 'fn_missing: fn_cron_notify_cross_library_digest introuvable';
    END IF;
    
    RAISE NOTICE 'fn_ok: fn_cron_notify_cross_library_digest créée';
END;
$$;

-- 4.3 Job pg_cron créé et désactivé
DO $$
DECLARE
    v_job_active boolean;
BEGIN
    SELECT active INTO v_job_active
    FROM cron.job
    WHERE jobname = 'anarbib-notify-cross-library-digest-weekly';
    
    IF v_job_active IS NULL THEN
        RAISE EXCEPTION 'job_missing: anarbib-notify-cross-library-digest-weekly pas trouvé dans cron.job';
    END IF;
    
    IF v_job_active = true THEN
        RAISE WARNING 'job_active_unexpected: le job est actif alors qu''il devrait être inactif (Edge Function pas encore créée)';
    ELSE
        RAISE NOTICE 'job_ok: anarbib-notify-cross-library-digest-weekly créé en inactif (cohérent)';
    END IF;
END;
$$;

-- 4.4 (Pas de test simulé d'INSERT dans la migration : la table est
-- immutable, donc tout INSERT de test resterait pour toujours dans le log.
-- Le test fonctionnel est dans les commentaires de fin de fichier, à lancer
-- manuellement avec BEGIN/ROLLBACK dans le SQL Editor.)
DO $$
BEGIN
    RAISE NOTICE 'note: test fonctionnel du trigger à lancer manuellement (cf. commentaires de fin de fichier) avec BEGIN/ROLLBACK pour ne pas polluer la table immutable.';
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
--
-- 1. Vérifier que le job pg_cron est créé en inactif :
--    SELECT jobid, jobname, schedule, active 
--    FROM cron.job 
--    WHERE jobname = 'anarbib-notify-cross-library-digest-weekly';
--    Attendu : active = false
--
-- 2. TEST FONCTIONNEL DU TRIGGER (avec BEGIN/ROLLBACK manuel pour ne pas
--    polluer la table immutable) :
--
--    BEGIN;
--    -- Compte avant
--    SELECT count(*) AS outbox_before
--    FROM public.team_notification_outbox
--    WHERE event = 'network.cross_library_critical_action';
--    
--    -- INSERT d'une action critique fictive
--    INSERT INTO public.network_admin_cross_library_actions_log
--      (actor_user_id, library_id, action_type, is_critical, payload)
--    VALUES (
--      'd6710372-e5e5-4608-800b-99a26817c677',
--      'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a',
--      'test_trigger_critical', true,
--      '{"manual_validation": true}'::jsonb
--    );
--    
--    -- Compte après : doit avoir augmenté de 1
--    SELECT count(*) AS outbox_after
--    FROM public.team_notification_outbox
--    WHERE event = 'network.cross_library_critical_action';
--    
--    -- Voir l'event créé (devrait contenir tous les champs enrichis)
--    SELECT id, event, payload
--    FROM public.team_notification_outbox
--    WHERE event = 'network.cross_library_critical_action'
--    ORDER BY id DESC LIMIT 1;
--    
--    ROLLBACK;  -- IMPORTANT : annule tout, sinon la ligne reste pour toujours
--
-- 3. TEST FONCTIONNEL : action NON critique → pas d'event
--    BEGIN;
--    INSERT INTO public.network_admin_cross_library_actions_log
--      (actor_user_id, library_id, action_type, is_critical, payload)
--    VALUES (
--      'd6710372-e5e5-4608-800b-99a26817c677',
--      'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a',
--      'test_trigger_routine', false,
--      '{}'::jsonb
--    );
--    SELECT count(*) AS outbox_count
--    FROM public.team_notification_outbox
--    WHERE event = 'network.cross_library_critical_action'
--      AND created_at > now() - interval '1 minute';
--    -- Attendu : aucun nouvel event (l'action n'était pas critique)
--    ROLLBACK;
--
-- 4. Pour activer le job une fois l'Edge Function créée :
--    UPDATE cron.job SET active = true 
--    WHERE jobname = 'anarbib-notify-cross-library-digest-weekly';
--
-- 5. Pour créer le secret dans le vault (à faire avant activation du cron) :
--    SELECT vault.create_secret(
--      'votre_secret_aléatoire_64_chars',
--      'WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST',
--      'Webhook secret pour notify-cross-library-digest Edge Function'
--    );
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
