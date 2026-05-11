-- ============================================================================
-- 20260511160000_paquetD1_helper_is_critical_action_type.sql
-- ============================================================================
-- Paquet D.1 — Helper fn_is_critical_action_type(text)
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3.1
--
-- Centralise la liste limitative des action_types considérés comme critiques.
-- Une action critique déclenche une notification immédiate par mail au staff
-- local de la biblio (cf. C.5c trigger trg_cross_lib_log_critical_notification).
--
-- Les actions non-critiques sont juste loggées et apparaissent dans le digest
-- hebdomadaire (cf. C.5c job pg_cron anarbib-notify-cross-library-digest-weekly).
--
-- ACTIONS CRITIQUES (notification immédiate) :
--   - update_library                       : modification de la fiche biblio (slug, name, identité)
--   - update_library_membership_rules      : règlement d'adhésion
--   - update_library_retention_policies    : politique de rétention RGPD
--   - update_library_service_state         : état de service (ouverture, pause, etc.)
--   - team_suspend_member                  : suspension de staff
--   - team_request_remove_member           : demande de retrait de staff (carence 7j)
--   - team_promote_to_coordenador          : promotion vers coordenador (rôle pivot)
--
-- ACTIONS NON-CRITIQUES (digest hebdomadaire seulement) :
--   - team_promote_to_librarian            : promotion plus basse, moins sensible
--   - Toute action future non listée dans la whitelist critique
--
-- Le helper est utilisé par les RPC du paquet D et par les triggers AFTER UPDATE
-- pour passer la bonne valeur de is_critical à fn_log_cross_library_action.
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : HELPER fn_is_critical_action_type
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_is_critical_action_type(p_action_type text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = pg_temp
AS $$
    SELECT p_action_type = ANY (ARRAY[
        'update_library',
        'update_library_membership_rules',
        'update_library_retention_policies',
        'update_library_service_state',
        'team_suspend_member',
        'team_request_remove_member',
        'team_promote_to_coordenador'
    ]);
$$;

COMMENT ON FUNCTION public.fn_is_critical_action_type(text) IS
'Retourne TRUE si l''action_type passé en paramètre est considéré comme critique au sens de la spec v0.3 §6.3.1 (déclenche notification immédiate au staff local). Liste limitative whitelist : update_library, update_library_membership_rules, update_library_retention_policies, update_library_service_state, team_suspend_member, team_request_remove_member, team_promote_to_coordenador. Toute action non listée est non-critique (digest hebdo seulement). IMMUTABLE car la liste ne dépend d''aucune donnée. Paquet D.1 (11/05/2026).';

GRANT EXECUTE ON FUNCTION public.fn_is_critical_action_type(text) TO authenticated, anon;

-- ============================================================================
-- SECTION 2 : VALIDATIONS POST-CRÉATION
-- ============================================================================

-- 2.1 Helper créé et IMMUTABLE
DO $$
DECLARE
    v_volatility char;
BEGIN
    SELECT p.provolatile INTO v_volatility
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_is_critical_action_type';
    
    IF v_volatility IS NULL THEN
        RAISE EXCEPTION 'helper_missing: fn_is_critical_action_type introuvable';
    END IF;
    
    IF v_volatility <> 'i' THEN
        RAISE WARNING 'helper_volatility_unexpected: fn_is_critical_action_type est % au lieu de IMMUTABLE', v_volatility;
    END IF;
    
    RAISE NOTICE 'helper_ok: fn_is_critical_action_type créé en IMMUTABLE';
END;
$$;

-- 2.2 Test fonctionnel : les 7 actions critiques retournent TRUE
DO $$
DECLARE
    v_action text;
    v_critical_actions text[] := ARRAY[
        'update_library',
        'update_library_membership_rules',
        'update_library_retention_policies',
        'update_library_service_state',
        'team_suspend_member',
        'team_request_remove_member',
        'team_promote_to_coordenador'
    ];
    v_result boolean;
BEGIN
    FOREACH v_action IN ARRAY v_critical_actions LOOP
        SELECT public.fn_is_critical_action_type(v_action) INTO v_result;
        IF NOT v_result THEN
            RAISE EXCEPTION 'critical_check_failed: action % devrait être critique mais retourne FALSE', v_action;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'critical_check_ok: les 7 actions critiques sont reconnues';
END;
$$;

-- 2.3 Test fonctionnel : actions NON-critiques retournent FALSE
DO $$
DECLARE
    v_result boolean;
BEGIN
    SELECT public.fn_is_critical_action_type('team_promote_to_librarian') INTO v_result;
    IF v_result THEN
        RAISE EXCEPTION 'noncritical_check_failed: team_promote_to_librarian devrait être non-critique';
    END IF;
    
    SELECT public.fn_is_critical_action_type('unknown_action_for_future') INTO v_result;
    IF v_result THEN
        RAISE EXCEPTION 'noncritical_check_failed: une action inconnue devrait être non-critique';
    END IF;
    
    SELECT public.fn_is_critical_action_type('') INTO v_result;
    IF v_result THEN
        RAISE EXCEPTION 'noncritical_check_failed: chaîne vide devrait être non-critique';
    END IF;
    
    SELECT public.fn_is_critical_action_type(NULL) INTO v_result;
    IF v_result IS NOT NULL AND v_result THEN
        RAISE EXCEPTION 'null_check_failed: NULL ne devrait pas être critique';
    END IF;
    
    RAISE NOTICE 'noncritical_check_ok: actions inconnues, vides et NULL ne sont pas critiques';
END;
$$;

-- 2.4 Permissions GRANT EXECUTE accordées
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
      AND routine_name = 'fn_is_critical_action_type'
      AND grantee IN ('authenticated', 'anon');
    
    IF v_count < 2 THEN
        RAISE WARNING 'grants_count_low: % GRANTs trouvés (attendu : >=2)', v_count;
    ELSE
        RAISE NOTICE 'grants_ok: GRANT EXECUTE accordé à authenticated et anon';
    END IF;
END;
$$;

COMMIT;

-- ============================================================================
-- Fin du fichier.
-- ============================================================================
