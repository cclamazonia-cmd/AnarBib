-- ============================================================================
-- 20260511130000_paquetC5b_cross_library_actions_log_infrastructure.sql
-- ============================================================================
-- Paquet C.5b — Infrastructure d'audit des actions transverses des admins
--               réseau sur les biblios dont ils ne sont pas staff local.
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3.1
--           (Q2 + Q6 tranchées : traçabilité maximale + digest hebdomadaire
--           + notifications immédiates pour actions critiques)
--
-- Contenu (minimal selon décision C.5b option A) :
--   1. Table network_admin_cross_library_actions_log
--   2. Index optimisés
--   3. RLS (admins réseau voient tout + staff local voit le log de sa biblio)
--   4. Helpers SQL appelés explicitement par les RPC (à intégrer au paquet D)
--   5. Trigger d'immutabilité (INSERT only, comme network_administrator_audit)
--
-- NON inclus dans C.5b (reporté à C.5c et paquet D) :
--   - Mécanisme de notification (event immédiat + cron digest hebdo) → C.5c
--   - Modification des RPC existantes pour appeler les helpers → paquet D
--
-- Le journal est INSERT ONLY (immutable) : audit politique infalsifiable.
-- 
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : TABLE network_admin_cross_library_actions_log
-- ============================================================================

CREATE TABLE public.network_admin_cross_library_actions_log (
    id bigserial PRIMARY KEY,
    actor_user_id uuid NOT NULL REFERENCES auth.users(id),
    library_id uuid NOT NULL REFERENCES public.libraries(id),
    action_type text NOT NULL,
    is_critical boolean NOT NULL DEFAULT false,
    target_entity_type text,
    target_entity_id uuid,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.network_admin_cross_library_actions_log IS 
'Journal des actions effectuées par un administrateur réseau sur une bibliothèque dont il n''est pas staff local. Garantit la transparence politique des interventions transverses (réf : spec-administrateur-reseau.md v0.3 §6.3.1, Q2 + Q6). INSERT only, immutable (triggers BEFORE UPDATE/DELETE qui RAISE).';

COMMENT ON COLUMN public.network_admin_cross_library_actions_log.is_critical IS 
'Si true, l''action déclenche un mail immédiat au staff local de la biblio. Liste limitative définie dans la spec v0.3 §6.3.1 : modifications de règlement, retention, suspensions, promotions, modifications de libraries (slug/name/identité).';

COMMENT ON COLUMN public.network_admin_cross_library_actions_log.action_type IS 
'Type d''action loggée. Valeurs attendues : update_library, update_library_membership_rules, update_library_retention_policies, update_library_service_state, team_suspend_member, team_request_remove_member, team_promote_to_*, update_library_circulation_policies, et autres actions transverses non-critiques. Pas de CHECK contraignant pour permettre l''ajout futur de types sans migration.';

-- ============================================================================
-- SECTION 2 : INDEX
-- ============================================================================

-- Index principal : recherche par biblio + temporel (digest hebdomadaire)
CREATE INDEX network_admin_cross_lib_log_library_idx 
    ON public.network_admin_cross_library_actions_log(library_id, created_at DESC);

-- Index partiel pour actions critiques (recherche rapide pour notifications immédiates)
CREATE INDEX network_admin_cross_lib_log_critical_idx 
    ON public.network_admin_cross_library_actions_log(is_critical, library_id, created_at DESC)
    WHERE is_critical = true;

-- Index sur l'auteur (recherche par actor : "qu'est-ce que Xavier a fait sur d'autres biblios ?")
CREATE INDEX network_admin_cross_lib_log_actor_idx 
    ON public.network_admin_cross_library_actions_log(actor_user_id, created_at DESC);

-- ============================================================================
-- SECTION 3 : IMMUTABILITÉ (triggers BEFORE UPDATE/DELETE)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.tg_cross_lib_log_immutable()
RETURNS trigger 
LANGUAGE plpgsql 
AS $$
BEGIN
    RAISE EXCEPTION 'cross_library_log_immutable: network_admin_cross_library_actions_log is append-only, UPDATE and DELETE are forbidden';
END;
$$;

CREATE TRIGGER trg_cross_lib_log_no_update
    BEFORE UPDATE ON public.network_admin_cross_library_actions_log
    FOR EACH ROW
    EXECUTE FUNCTION public.tg_cross_lib_log_immutable();

CREATE TRIGGER trg_cross_lib_log_no_delete
    BEFORE DELETE ON public.network_admin_cross_library_actions_log
    FOR EACH ROW
    EXECUTE FUNCTION public.tg_cross_lib_log_immutable();

-- ============================================================================
-- SECTION 4 : ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.network_admin_cross_library_actions_log 
    ENABLE ROW LEVEL SECURITY;

-- Policy A : admins réseau voient tout le log (transparence interne)
CREATE POLICY cross_lib_log_select_network_admins
    ON public.network_admin_cross_library_actions_log
    FOR SELECT
    TO authenticated
    USING (fn_caller_is_network_admin());

COMMENT ON POLICY cross_lib_log_select_network_admins 
    ON public.network_admin_cross_library_actions_log IS
'Les admins réseau voient toutes les lignes du log. Transparence interne au collectif des admins. Paquet C.5b (11/05/2026).';

-- Policy B : staff local d'une biblio voit le log des actions sur sa biblio
-- (transparence locale : Patricia coord BTL voit ce que d'autres admins
-- réseau ont fait sur BTL)
-- Note : user_can_act_as_staff_on_library retourne aussi true pour les admins
-- réseau, donc cette policy est redondante pour eux avec la policy A (OR
-- combiné par PostgreSQL). Acceptable.
CREATE POLICY cross_lib_log_select_local_staff
    ON public.network_admin_cross_library_actions_log
    FOR SELECT
    TO authenticated
    USING (user_can_act_as_staff_on_library(library_id));

COMMENT ON POLICY cross_lib_log_select_local_staff 
    ON public.network_admin_cross_library_actions_log IS
'Le staff local d''une biblio voit les actions transverses des admins réseau sur sa biblio. Transparence locale. Paquet C.5b (11/05/2026).';

-- Pas de policy INSERT pour authenticated : seuls les helpers SECURITY DEFINER
-- du paquet C.5b (§5) peuvent insérer. Les RPC futures appelleront ces helpers.

-- Pas de policy UPDATE ni DELETE : table append-only, immutabilité garantie
-- par triggers (§3).

-- ============================================================================
-- SECTION 5 : HELPERS SQL DE LOGGING
-- ============================================================================
-- Forme 1 : appels explicites par les RPC.
-- Les helpers tournent en SECURITY DEFINER pour bypass les RLS d'écriture
-- (qui n'existent pas pour authenticated, mais à plus forte raison pour
-- garantir l'INSERT depuis n'importe quel contexte d'appel).

-- 5.1 Helper principal : log d'une action transverse
-- Vérifie automatiquement si l'appelant est admin réseau ET non-staff local.
-- Si oui, INSERT. Sinon, NOOP silencieux (l'action n'est pas transverse).
CREATE OR REPLACE FUNCTION public.fn_log_cross_library_action(
    p_library_id uuid,
    p_action_type text,
    p_is_critical boolean DEFAULT false,
    p_target_entity_type text DEFAULT NULL,
    p_target_entity_id uuid DEFAULT NULL,
    p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_is_network_admin boolean;
    v_is_local_staff boolean;
    v_log_id bigint;
BEGIN
    -- Sans appelant authentifié, rien à logger
    IF v_caller_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- L'appelant est-il admin réseau actif ?
    SELECT EXISTS (
        SELECT 1 FROM public.network_administrators
        WHERE user_id = v_caller_id AND status = 'active'
    ) INTO v_is_network_admin;
    
    -- Si pas admin réseau, c'est pas une action transverse, on ne logge pas
    IF NOT v_is_network_admin THEN
        RETURN NULL;
    END IF;
    
    -- L'appelant est-il aussi staff local de cette biblio ?
    SELECT EXISTS (
        SELECT 1 FROM public.user_library_memberships m
        WHERE m.user_id = v_caller_id
          AND m.library_id = p_library_id
          AND m.status = 'active'
          AND m.role = ANY (ARRAY['librarian', 'coordenador'])
    ) INTO v_is_local_staff;
    
    -- Si l'admin réseau est aussi staff local, l'action est légitimement
    -- locale, pas transverse. On ne logge pas.
    IF v_is_local_staff THEN
        RETURN NULL;
    END IF;
    
    -- C'est une action transverse : on log
    INSERT INTO public.network_admin_cross_library_actions_log
        (actor_user_id, library_id, action_type, is_critical, 
         target_entity_type, target_entity_id, payload)
    VALUES 
        (v_caller_id, p_library_id, p_action_type, p_is_critical,
         p_target_entity_type, p_target_entity_id, p_payload)
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;

COMMENT ON FUNCTION public.fn_log_cross_library_action(uuid, text, boolean, text, uuid, jsonb) IS
'Helper d''audit : logge une action si l''appelant est admin réseau ET n''est pas staff local de la biblio cible. NOOP silencieux dans les autres cas (rien à logger). Retourne l''id du log ou NULL. À appeler depuis les RPC concernées. SECURITY DEFINER pour bypass les RLS d''écriture (la table n''accepte pas d''INSERT direct depuis authenticated). Paquet C.5b (11/05/2026).';

GRANT EXECUTE ON FUNCTION public.fn_log_cross_library_action(uuid, text, boolean, text, uuid, jsonb) 
    TO authenticated;

-- 5.2 Helper utilitaire pour les RPC qui veulent juste tester sans logger
-- ("suis-je en train de faire une action transverse en ce moment ?")
CREATE OR REPLACE FUNCTION public.fn_is_cross_library_action(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
    SELECT 
        EXISTS (
            SELECT 1 FROM public.network_administrators
            WHERE user_id = auth.uid() AND status = 'active'
        )
        AND NOT EXISTS (
            SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid()
              AND m.library_id = p_library_id
              AND m.status = 'active'
              AND m.role = ANY (ARRAY['librarian', 'coordenador'])
        );
$$;

COMMENT ON FUNCTION public.fn_is_cross_library_action(uuid) IS
'Retourne TRUE si l''appelant est admin réseau actif ET n''est pas staff local de la biblio passée en paramètre. Utile pour les RPC qui veulent déclencher un comportement différent en cas d''action transverse (par exemple, notifier le staff local). Paquet C.5b (11/05/2026).';

GRANT EXECUTE ON FUNCTION public.fn_is_cross_library_action(uuid) TO authenticated;

-- ============================================================================
-- SECTION 6 : VALIDATIONS POST-CRÉATION
-- ============================================================================

-- 6.1 Table créée avec les bonnes colonnes
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'network_admin_cross_library_actions_log'
      AND column_name IN ('id', 'actor_user_id', 'library_id', 'action_type', 
                           'is_critical', 'target_entity_type', 'target_entity_id',
                           'payload', 'created_at');
    
    IF v_count <> 9 THEN
        RAISE EXCEPTION 'table_columns_mismatch: % colonnes trouvées (attendu : 9)', v_count;
    END IF;
    
    RAISE NOTICE 'table_ok: network_admin_cross_library_actions_log créée avec les 9 colonnes attendues';
END;
$$;

-- 6.2 Index présents
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'network_admin_cross_library_actions_log'
      AND indexname IN (
          'network_admin_cross_lib_log_library_idx',
          'network_admin_cross_lib_log_critical_idx',
          'network_admin_cross_lib_log_actor_idx'
      );
    
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'index_count_mismatch: % index trouvés (attendu : 3)', v_count;
    END IF;
    
    RAISE NOTICE 'index_ok: 3 index créés';
END;
$$;

-- 6.3 RLS activée et 2 policies SELECT créées
DO $$
DECLARE
    v_rls boolean;
    v_policies integer;
BEGIN
    SELECT rowsecurity INTO v_rls
    FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'network_admin_cross_library_actions_log';
    
    IF NOT v_rls THEN
        RAISE EXCEPTION 'rls_disabled: RLS pas activée sur la nouvelle table';
    END IF;
    
    SELECT count(*) INTO v_policies
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'network_admin_cross_library_actions_log';
    
    IF v_policies <> 2 THEN
        RAISE EXCEPTION 'policies_count_mismatch: % policies créées (attendu : 2)', v_policies;
    END IF;
    
    RAISE NOTICE 'rls_ok: RLS activée + 2 policies SELECT créées';
END;
$$;

-- 6.4 Helpers présents
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_log_cross_library_action'
    ) THEN
        RAISE EXCEPTION 'helper_missing: fn_log_cross_library_action introuvable';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'fn_is_cross_library_action'
    ) THEN
        RAISE EXCEPTION 'helper_missing: fn_is_cross_library_action introuvable';
    END IF;
    
    RAISE NOTICE 'helpers_ok: fn_log_cross_library_action et fn_is_cross_library_action créés';
END;
$$;

-- 6.5 Triggers d'immutabilité présents
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    WHERE c.relname = 'network_admin_cross_library_actions_log'
      AND t.tgname IN ('trg_cross_lib_log_no_update', 'trg_cross_lib_log_no_delete');
    
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'trigger_count_mismatch: % triggers d''immutabilité (attendu : 2)', v_count;
    END IF;
    
    RAISE NOTICE 'immutability_ok: triggers BEFORE UPDATE et BEFORE DELETE installés';
END;
$$;

-- 6.6 Initial state : table vide
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count FROM public.network_admin_cross_library_actions_log;
    
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'initial_state_unexpected: % lignes dans une table fraîchement créée', v_count;
    END IF;
    
    RAISE NOTICE 'initial_state_ok: table vide, prête à accueillir le premier log';
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
--
-- 1. Lister les RLS de la nouvelle table :
--    SELECT policyname, cmd, regexp_replace(coalesce(qual, with_check), E'\\s+', ' ', 'g') AS clause
--    FROM pg_policies
--    WHERE schemaname = 'public' AND tablename = 'network_admin_cross_library_actions_log'
--    ORDER BY policyname;
--    Attendu : 2 policies (cross_lib_log_select_network_admins et _local_staff)
--
-- 2. Tester fn_is_cross_library_action :
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    SELECT 
--      'Xavier sur BLMF (coord local)' AS scenario,
--      fn_is_cross_library_action('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid) AS is_transverse;
--    SELECT 
--      'Xavier sur BTL (pas membre)' AS scenario,
--      fn_is_cross_library_action('b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'::uuid) AS is_transverse;
--    ROLLBACK;
--    Attendu : Xavier sur BLMF = false (staff local), Xavier sur BTL = true (transverse)
--
-- 3. Tester fn_log_cross_library_action (simulation) :
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    SELECT fn_log_cross_library_action(
--      'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'::uuid,
--      'test_log_creation',
--      false,
--      NULL, NULL,
--      '{"test": "C.5b validation"}'::jsonb
--    ) AS log_id;
--    SELECT * FROM public.network_admin_cross_library_actions_log;
--    ROLLBACK; -- annule le test pour ne pas polluer
--    Attendu : 1 ligne créée avec actor_user_id=Xavier, library_id=BTL,
--    action_type='test_log_creation', is_critical=false
--
-- 4. Tester l'immutabilité :
--    BEGIN;
--    INSERT INTO public.network_admin_cross_library_actions_log
--      (actor_user_id, library_id, action_type)
--      VALUES (
--        'd6710372-e5e5-4608-800b-99a26817c677',
--        'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a',
--        'test_immutable'
--      );
--    UPDATE public.network_admin_cross_library_actions_log SET action_type = 'hacked' 
--      WHERE action_type = 'test_immutable';
--    -- Devrait planter avec cross_library_log_immutable
--    ROLLBACK;
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
