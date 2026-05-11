-- ============================================================================
-- 20260511190000_paquetD4_table_triggers_logging.sql
-- ============================================================================
-- Paquet D.4 — Triggers AFTER UPDATE pour logging cross-library automatique
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3 + §6.3.1
--
-- Contenu : 4 triggers AFTER UPDATE sur les tables sensibles aux modifications
-- structurelles de gouvernance. Permet de tracer automatiquement les UPDATE
-- directs (par le frontend, RLS contrôle déjà l'autorisation) sans modifier
-- les routes d'écriture.
--
-- Stratégie :
-- - Trigger AFTER UPDATE FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*)
--   pour skipper les UPDATE non-significatifs (recursion silencieuse, etc.)
-- - Liste explicite des colonnes politiques par table (decision session 11/05)
-- - Calcul du delta OLD vs NEW colonne par colonne en jsonb
-- - Si au moins 1 colonne politique a changé, appel fn_log_cross_library_action
-- - Sinon NOOP silencieux (changement non politique)
--
-- Le helper fn_log_cross_library_action (paquet C.5b) fait lui-même le tri :
-- NOOP si l'appelant n'est pas en action transverse. Donc les UPDATE par
-- le staff local d'une biblio ne sont PAS loggés.
--
-- 4 tables couvertes :
--   - libraries                 → action_type='update_library', is_critical=true
--   - library_membership_rules  → action_type='update_library_membership_rules', is_critical=true
--   - library_retention_policies → action_type='update_library_retention_policies', is_critical=true
--   - library_service_state     → action_type='update_library_service_state', is_critical=true
--
-- Colonnes ignorées systématiquement : updated_at, created_at, id, library_id.
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : Trigger sur libraries
-- ============================================================================
-- 21 colonnes politiques tracées, 4 colonnes ignorées (id, created_at, updated_at, et
-- la regimento_draft_updated_at qui suit automatiquement les modifs draft).

CREATE OR REPLACE FUNCTION public.tg_libraries_log_cross_library_action()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_delta jsonb := '{}'::jsonb;
BEGIN
    -- Identité
    IF OLD.slug IS DISTINCT FROM NEW.slug THEN
        v_delta := v_delta || jsonb_build_object('slug', jsonb_build_object('old', OLD.slug, 'new', NEW.slug));
    END IF;
    IF OLD.name IS DISTINCT FROM NEW.name THEN
        v_delta := v_delta || jsonb_build_object('name', jsonb_build_object('old', OLD.name, 'new', NEW.name));
    END IF;
    IF OLD.short_name IS DISTINCT FROM NEW.short_name THEN
        v_delta := v_delta || jsonb_build_object('short_name', jsonb_build_object('old', OLD.short_name, 'new', NEW.short_name));
    END IF;
    -- Géographie
    IF OLD.city IS DISTINCT FROM NEW.city THEN
        v_delta := v_delta || jsonb_build_object('city', jsonb_build_object('old', OLD.city, 'new', NEW.city));
    END IF;
    IF OLD.state IS DISTINCT FROM NEW.state THEN
        v_delta := v_delta || jsonb_build_object('state', jsonb_build_object('old', OLD.state, 'new', NEW.state));
    END IF;
    IF OLD.country IS DISTINCT FROM NEW.country THEN
        v_delta := v_delta || jsonb_build_object('country', jsonb_build_object('old', OLD.country, 'new', NEW.country));
    END IF;
    -- Statut opérationnel
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
        v_delta := v_delta || jsonb_build_object('is_active', jsonb_build_object('old', OLD.is_active, 'new', NEW.is_active));
    END IF;
    IF OLD.is_default IS DISTINCT FROM NEW.is_default THEN
        v_delta := v_delta || jsonb_build_object('is_default', jsonb_build_object('old', OLD.is_default, 'new', NEW.is_default));
    END IF;
    -- Politique de visibilité et d'adhésion
    IF OLD.visibility_level IS DISTINCT FROM NEW.visibility_level THEN
        v_delta := v_delta || jsonb_build_object('visibility_level', jsonb_build_object('old', OLD.visibility_level, 'new', NEW.visibility_level));
    END IF;
    IF OLD.membership_enabled IS DISTINCT FROM NEW.membership_enabled THEN
        v_delta := v_delta || jsonb_build_object('membership_enabled', jsonb_build_object('old', OLD.membership_enabled, 'new', NEW.membership_enabled));
    END IF;
    IF OLD.default_locale IS DISTINCT FROM NEW.default_locale THEN
        v_delta := v_delta || jsonb_build_object('default_locale', jsonb_build_object('old', OLD.default_locale, 'new', NEW.default_locale));
    END IF;
    IF OLD.document_governance_config IS DISTINCT FROM NEW.document_governance_config THEN
        v_delta := v_delta || jsonb_build_object('document_governance_config_changed', true);
    END IF;
    IF OLD.admin_notes IS DISTINCT FROM NEW.admin_notes THEN
        v_delta := v_delta || jsonb_build_object('admin_notes_changed', true);
    END IF;
    -- Règlement brouillon
    IF OLD.regimento_draft_object_path IS DISTINCT FROM NEW.regimento_draft_object_path THEN
        v_delta := v_delta || jsonb_build_object('regimento_draft_object_path_changed', true);
    END IF;
    IF OLD.regimento_draft_filename IS DISTINCT FROM NEW.regimento_draft_filename THEN
        v_delta := v_delta || jsonb_build_object('regimento_draft_filename', jsonb_build_object('old', OLD.regimento_draft_filename, 'new', NEW.regimento_draft_filename));
    END IF;
    IF OLD.regimento_draft_version IS DISTINCT FROM NEW.regimento_draft_version THEN
        v_delta := v_delta || jsonb_build_object('regimento_draft_version', jsonb_build_object('old', OLD.regimento_draft_version, 'new', NEW.regimento_draft_version));
    END IF;
    -- Règlement publié (le plus politique)
    IF OLD.regimento_published_object_path IS DISTINCT FROM NEW.regimento_published_object_path THEN
        v_delta := v_delta || jsonb_build_object('regimento_published_object_path_changed', true);
    END IF;
    IF OLD.regimento_published_url IS DISTINCT FROM NEW.regimento_published_url THEN
        v_delta := v_delta || jsonb_build_object('regimento_published_url', jsonb_build_object('old', OLD.regimento_published_url, 'new', NEW.regimento_published_url));
    END IF;
    IF OLD.regimento_published_filename IS DISTINCT FROM NEW.regimento_published_filename THEN
        v_delta := v_delta || jsonb_build_object('regimento_published_filename', jsonb_build_object('old', OLD.regimento_published_filename, 'new', NEW.regimento_published_filename));
    END IF;
    IF OLD.regimento_published_version IS DISTINCT FROM NEW.regimento_published_version THEN
        v_delta := v_delta || jsonb_build_object('regimento_published_version', jsonb_build_object('old', OLD.regimento_published_version, 'new', NEW.regimento_published_version));
    END IF;
    IF OLD.regimento_published_at IS DISTINCT FROM NEW.regimento_published_at THEN
        v_delta := v_delta || jsonb_build_object('regimento_published_at', jsonb_build_object('old', OLD.regimento_published_at, 'new', NEW.regimento_published_at));
    END IF;
    
    -- Si aucune colonne politique n'a changé, NOOP
    IF v_delta = '{}'::jsonb THEN
        RETURN NEW;
    END IF;
    
    -- Logging (NOOP si l'appelant n'est pas en action transverse)
    PERFORM public.fn_log_cross_library_action(
        p_library_id        := NEW.id,
        p_action_type       := 'update_library',
        p_is_critical       := public.fn_is_critical_action_type('update_library'),
        p_target_entity_type := 'library',
        p_target_entity_id  := NEW.id,
        p_payload           := jsonb_build_object('delta', v_delta)
    );
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.tg_libraries_log_cross_library_action() IS
'Trigger AFTER UPDATE sur libraries : si au moins une colonne politique a changé (21 colonnes tracées hors id/created_at/updated_at), appelle fn_log_cross_library_action avec le delta complet. Paquet D.4 (11/05/2026).';

CREATE TRIGGER trg_libraries_log_cross_library_action
    AFTER UPDATE ON public.libraries
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION public.tg_libraries_log_cross_library_action();

-- ============================================================================
-- SECTION 2 : Trigger sur library_membership_rules
-- ============================================================================

CREATE OR REPLACE FUNCTION public.tg_lmr_log_cross_library_action()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_delta jsonb := '{}'::jsonb;
BEGIN
    IF OLD.name IS DISTINCT FROM NEW.name THEN
        v_delta := v_delta || jsonb_build_object('name', jsonb_build_object('old', OLD.name, 'new', NEW.name));
    END IF;
    IF OLD.description IS DISTINCT FROM NEW.description THEN
        v_delta := v_delta || jsonb_build_object('description_changed', true);
    END IF;
    IF OLD.amount_min IS DISTINCT FROM NEW.amount_min THEN
        v_delta := v_delta || jsonb_build_object('amount_min', jsonb_build_object('old', OLD.amount_min, 'new', NEW.amount_min));
    END IF;
    IF OLD.amount_suggested IS DISTINCT FROM NEW.amount_suggested THEN
        v_delta := v_delta || jsonb_build_object('amount_suggested', jsonb_build_object('old', OLD.amount_suggested, 'new', NEW.amount_suggested));
    END IF;
    IF OLD.currency IS DISTINCT FROM NEW.currency THEN
        v_delta := v_delta || jsonb_build_object('currency', jsonb_build_object('old', OLD.currency, 'new', NEW.currency));
    END IF;
    IF OLD.period_type IS DISTINCT FROM NEW.period_type THEN
        v_delta := v_delta || jsonb_build_object('period_type', jsonb_build_object('old', OLD.period_type::text, 'new', NEW.period_type::text));
    END IF;
    IF OLD.period_anchor IS DISTINCT FROM NEW.period_anchor THEN
        v_delta := v_delta || jsonb_build_object('period_anchor', jsonb_build_object('old', OLD.period_anchor::text, 'new', NEW.period_anchor::text));
    END IF;
    IF OLD.is_required IS DISTINCT FROM NEW.is_required THEN
        v_delta := v_delta || jsonb_build_object('is_required', jsonb_build_object('old', OLD.is_required, 'new', NEW.is_required));
    END IF;
    IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
        v_delta := v_delta || jsonb_build_object('is_active', jsonb_build_object('old', OLD.is_active, 'new', NEW.is_active));
    END IF;
    IF OLD.display_order IS DISTINCT FROM NEW.display_order THEN
        v_delta := v_delta || jsonb_build_object('display_order', jsonb_build_object('old', OLD.display_order, 'new', NEW.display_order));
    END IF;
    
    IF v_delta = '{}'::jsonb THEN
        RETURN NEW;
    END IF;
    
    PERFORM public.fn_log_cross_library_action(
        p_library_id        := NEW.library_id,
        p_action_type       := 'update_library_membership_rules',
        p_is_critical       := public.fn_is_critical_action_type('update_library_membership_rules'),
        p_target_entity_type := 'library_membership_rule',
        p_target_entity_id  := NEW.id,
        p_payload           := jsonb_build_object('rule_name', NEW.name, 'delta', v_delta)
    );
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.tg_lmr_log_cross_library_action() IS
'Trigger AFTER UPDATE sur library_membership_rules : trace les modifications de règles d''adhésion par un admin réseau non-staff local. Paquet D.4 (11/05/2026).';

CREATE TRIGGER trg_lmr_log_cross_library_action
    AFTER UPDATE ON public.library_membership_rules
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION public.tg_lmr_log_cross_library_action();

-- ============================================================================
-- SECTION 3 : Trigger sur library_retention_policies
-- ============================================================================

CREATE OR REPLACE FUNCTION public.tg_lrp_log_cross_library_action()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_delta jsonb := '{}'::jsonb;
BEGIN
    IF OLD.retention_loans_days IS DISTINCT FROM NEW.retention_loans_days THEN
        v_delta := v_delta || jsonb_build_object('retention_loans_days', jsonb_build_object('old', OLD.retention_loans_days, 'new', NEW.retention_loans_days));
    END IF;
    IF OLD.retention_reservations_days IS DISTINCT FROM NEW.retention_reservations_days THEN
        v_delta := v_delta || jsonb_build_object('retention_reservations_days', jsonb_build_object('old', OLD.retention_reservations_days, 'new', NEW.retention_reservations_days));
    END IF;
    IF OLD.retention_consultations_days IS DISTINCT FROM NEW.retention_consultations_days THEN
        v_delta := v_delta || jsonb_build_object('retention_consultations_days', jsonb_build_object('old', OLD.retention_consultations_days, 'new', NEW.retention_consultations_days));
    END IF;
    IF OLD.retention_notifications_days IS DISTINCT FROM NEW.retention_notifications_days THEN
        v_delta := v_delta || jsonb_build_object('retention_notifications_days', jsonb_build_object('old', OLD.retention_notifications_days, 'new', NEW.retention_notifications_days));
    END IF;
    IF OLD.notes IS DISTINCT FROM NEW.notes THEN
        v_delta := v_delta || jsonb_build_object('notes_changed', true);
    END IF;
    
    IF v_delta = '{}'::jsonb THEN
        RETURN NEW;
    END IF;
    
    PERFORM public.fn_log_cross_library_action(
        p_library_id        := NEW.library_id,
        p_action_type       := 'update_library_retention_policies',
        p_is_critical       := public.fn_is_critical_action_type('update_library_retention_policies'),
        p_target_entity_type := 'library_retention_policy',
        p_target_entity_id  := NEW.library_id,  -- pas d'id distinct, on prend library_id
        p_payload           := jsonb_build_object('delta', v_delta)
    );
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.tg_lrp_log_cross_library_action() IS
'Trigger AFTER UPDATE sur library_retention_policies : trace les modifications de politique de rétention RGPD par un admin réseau non-staff local. Paquet D.4 (11/05/2026).';

CREATE TRIGGER trg_lrp_log_cross_library_action
    AFTER UPDATE ON public.library_retention_policies
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION public.tg_lrp_log_cross_library_action();

-- ============================================================================
-- SECTION 4 : Trigger sur library_service_state
-- ============================================================================

CREATE OR REPLACE FUNCTION public.tg_lss_log_cross_library_action()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_delta jsonb := '{}'::jsonb;
BEGIN
    IF OLD.service_mode IS DISTINCT FROM NEW.service_mode THEN
        v_delta := v_delta || jsonb_build_object('service_mode', jsonb_build_object('old', OLD.service_mode, 'new', NEW.service_mode));
    END IF;
    IF OLD.public_message IS DISTINCT FROM NEW.public_message THEN
        v_delta := v_delta || jsonb_build_object('public_message_changed', true);
    END IF;
    IF OLD.allows_new_reservations IS DISTINCT FROM NEW.allows_new_reservations THEN
        v_delta := v_delta || jsonb_build_object('allows_new_reservations', jsonb_build_object('old', OLD.allows_new_reservations, 'new', NEW.allows_new_reservations));
    END IF;
    IF OLD.allows_new_loans IS DISTINCT FROM NEW.allows_new_loans THEN
        v_delta := v_delta || jsonb_build_object('allows_new_loans', jsonb_build_object('old', OLD.allows_new_loans, 'new', NEW.allows_new_loans));
    END IF;
    IF OLD.consultation_timezone IS DISTINCT FROM NEW.consultation_timezone THEN
        v_delta := v_delta || jsonb_build_object('consultation_timezone', jsonb_build_object('old', OLD.consultation_timezone, 'new', NEW.consultation_timezone));
    END IF;
    IF OLD.max_simultaneous_consultations IS DISTINCT FROM NEW.max_simultaneous_consultations THEN
        v_delta := v_delta || jsonb_build_object('max_simultaneous_consultations', jsonb_build_object('old', OLD.max_simultaneous_consultations, 'new', NEW.max_simultaneous_consultations));
    END IF;
    IF OLD.consultation_schedule_struct IS DISTINCT FROM NEW.consultation_schedule_struct THEN
        v_delta := v_delta || jsonb_build_object('consultation_schedule_struct_changed', true);
    END IF;
    IF OLD.service_schedule_text IS DISTINCT FROM NEW.service_schedule_text THEN
        v_delta := v_delta || jsonb_build_object('service_schedule_text_changed', true);
    END IF;
    
    IF v_delta = '{}'::jsonb THEN
        RETURN NEW;
    END IF;
    
    PERFORM public.fn_log_cross_library_action(
        p_library_id        := NEW.library_id,
        p_action_type       := 'update_library_service_state',
        p_is_critical       := public.fn_is_critical_action_type('update_library_service_state'),
        p_target_entity_type := 'library_service_state',
        p_target_entity_id  := NEW.library_id,
        p_payload           := jsonb_build_object('delta', v_delta)
    );
    
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.tg_lss_log_cross_library_action() IS
'Trigger AFTER UPDATE sur library_service_state : trace les modifications d''état de service par un admin réseau non-staff local. Paquet D.4 (11/05/2026).';

CREATE TRIGGER trg_lss_log_cross_library_action
    AFTER UPDATE ON public.library_service_state
    FOR EACH ROW
    WHEN (OLD.* IS DISTINCT FROM NEW.*)
    EXECUTE FUNCTION public.tg_lss_log_cross_library_action();

-- ============================================================================
-- SECTION 5 : VALIDATIONS POST-CRÉATION
-- ============================================================================

-- 5.1 Les 4 triggers sont installés
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND t.tgname IN (
          'trg_libraries_log_cross_library_action',
          'trg_lmr_log_cross_library_action',
          'trg_lrp_log_cross_library_action',
          'trg_lss_log_cross_library_action'
      );
    
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'triggers_count_mismatch: % triggers installés (attendu : 4)', v_count;
    END IF;
    
    RAISE NOTICE 'triggers_ok: 4 triggers AFTER UPDATE installés';
END;
$$;

-- 5.2 Les 4 fonctions trigger sont présentes
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
          'tg_libraries_log_cross_library_action',
          'tg_lmr_log_cross_library_action',
          'tg_lrp_log_cross_library_action',
          'tg_lss_log_cross_library_action'
      );
    
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'tg_functions_count_mismatch: % fonctions trigger (attendu : 4)', v_count;
    END IF;
    
    RAISE NOTICE 'tg_functions_ok: 4 fonctions trigger créées';
END;
$$;

-- 5.3 Dépendances présentes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_log_cross_library_action'
    ) THEN
        RAISE EXCEPTION 'dependency_missing: fn_log_cross_library_action (paquet C.5b)';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_is_critical_action_type'
    ) THEN
        RAISE EXCEPTION 'dependency_missing: fn_is_critical_action_type (paquet D.1)';
    END IF;
    
    RAISE NOTICE 'dependencies_ok: helpers fn_log_cross_library_action + fn_is_critical_action_type présents';
END;
$$;

-- 5.4 Les triggers utilisent WHEN (OLD.* IS DISTINCT FROM NEW.*) pour optimisation
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname IN ('libraries', 'library_membership_rules', 'library_retention_policies', 'library_service_state')
      AND t.tgname LIKE 'trg_%_log_cross_library_action'
      AND t.tgqual IS NOT NULL;
    
    IF v_count <> 4 THEN
        RAISE WARNING 'when_clause_missing: % triggers ont WHEN clause (attendu : 4)', v_count;
    ELSE
        RAISE NOTICE 'when_clause_ok: les 4 triggers utilisent WHEN (OLD.* IS DISTINCT FROM NEW.*)';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- ATTENTION : tout test fonctionnel qui modifie une biblio doit être fait
-- avec BEGIN/ROLLBACK pour ne pas polluer la prod.
--
-- Test 1 : voir les triggers installés
--    SELECT c.relname AS table_name, t.tgname AS trigger_name, t.tgenabled
--    FROM pg_trigger t
--    JOIN pg_class c ON c.oid = t.tgrelid
--    WHERE t.tgname LIKE 'trg_%_log_cross_library_action'
--    ORDER BY c.relname;
--    Attendu : 4 triggers, tgenabled='O' (Origin)
--
-- Test 2 : Xavier (admin réseau) modifie le nom de BTL → trace dans le log
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    
--    SELECT count(*) AS log_before
--    FROM public.network_admin_cross_library_actions_log
--    WHERE action_type = 'update_library';
--    
--    -- Modification fictive : on inverse short_name puis on l'écrit pareil
--    UPDATE public.libraries 
--    SET short_name = short_name || '_test'
--    WHERE id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a';
--    
--    SELECT count(*) AS log_after, payload
--    FROM public.network_admin_cross_library_actions_log
--    WHERE action_type = 'update_library'
--    ORDER BY id DESC LIMIT 1;
--    
--    ROLLBACK;  -- IMPORTANT : annule tout
--    Attendu : log_after = log_before + 1, le payload contient delta.short_name
--
-- Test 3 : Patricia (coord BTL) modifie BTL → PAS de trace
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "2a42b6bd-d159-4ee0-b66b-28a03062232b"}';
--    
--    UPDATE public.libraries 
--    SET short_name = short_name || '_test'
--    WHERE id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a';
--    
--    SELECT count(*) AS recent_logs
--    FROM public.network_admin_cross_library_actions_log
--    WHERE action_type = 'update_library'
--      AND created_at > now() - interval '1 minute';
--    
--    ROLLBACK;
--    Attendu : recent_logs = 0 (action locale légitime, pas tracée)
--
-- Test 4 : Xavier modifie BLMF (sa biblio) → PAS de trace transverse
--    (le helper fn_log_cross_library_action filtre : Xavier est staff local de BLMF)
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
