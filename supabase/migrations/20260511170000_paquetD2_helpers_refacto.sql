-- ============================================================================
-- 20260511170000_paquetD2_helpers_refacto.sql
-- ============================================================================
-- Paquet D.2 — Refacto des helpers obsolètes
--
-- Réf spec : docs/spec-administrateur-reseau.md v0.3 §6.3
--
-- Contenu :
-- 1. Réécriture user_can_manage_library en wrapper léger qui délègue à
--    user_can_engage_library (helper du paquet A qui inclut les admins réseau).
--    Sémantique strictement préservée + admins réseau désormais reconnus.
--
-- 2. Ajout de COMMENT sur user_has_library_staff_role pour documenter sa
--    dépréciation et la limite actuelle (non-reconnaissance des admins réseau)
--    SANS toucher au code de la fonction. Décision conservatrice (option C
--    en session 11/05/2026) : les 3 callers (fn_team_list_memberships,
--    fn_resolve_caller_role_for_library, api.resolve_circulation_rule)
--    s'accommodent de la limite actuelle. Refacto reportée au paquet F.
--
-- Bug latent qui motivait ce paquet (avant fix D.2) :
--   Sans cette refacto, un admin réseau pur (sans membership local coord/admin)
--   ne pouvait PAS appeler fn_team_suspend_member, fn_team_request_remove_member
--   ni les RPC promote_to_*, parce que ces RPC vérifient user_can_manage_library
--   à l'étape 2 et user_can_manage_library ne reconnaissait pas les admins réseau.
--   Avec D.2, ce blocage est levé : un admin réseau peut désormais effectuer
--   ces actes de gouvernance sur n'importe quelle biblio.
--
-- Atomicité : transaction unique avec validations.
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : Réécriture user_can_manage_library en wrapper
-- ============================================================================
-- AVANT (helper actuel, obsolète) :
--   SELECT EXISTS (
--     SELECT 1 FROM user_library_memberships m
--     WHERE m.user_id = auth.uid()
--       AND m.library_id = p_library_id
--       AND m.status = 'active'
--       AND m.role IN ('coordenador', 'administrador')
--   );
--
-- APRÈS (wrapper) :
--   SELECT user_can_engage_library(p_library_id);
--
-- user_can_engage_library a été créé au paquet A avec cette sémantique :
--   UNION (admin réseau actif) OR (coordenador ou administrador local actif).
--
-- Donc Xavier qui est coord BLMF + admin réseau verra TRUE pour BLMF et BTL.
-- Patricia coord BTL verra TRUE pour BTL et FALSE pour BLMF.
-- Un admin réseau pur verra TRUE pour toutes les biblios.

CREATE OR REPLACE FUNCTION public.user_can_manage_library(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $$
    -- Délégué à user_can_engage_library (paquet A) qui inclut les admins réseau.
    -- Préserve la sémantique "coord+ local" tout en ajoutant la dimension transverse.
    SELECT public.user_can_engage_library(p_library_id);
$$;

COMMENT ON FUNCTION public.user_can_manage_library(uuid) IS
'Délégué à user_can_engage_library (paquet A). Reconnaît désormais les admins réseau en plus du staff local coordenador/administrador. Réécrit au paquet D.2 (11/05/2026). Wrapper léger : à supprimer au paquet F après migration explicite des appelants vers user_can_engage_library directement.';

-- ============================================================================
-- SECTION 2 : COMMENT de dépréciation sur user_has_library_staff_role
-- ============================================================================
-- Code de la fonction laissé INCHANGÉ. Seul le COMMENT est ajouté pour
-- documenter la dette technique et la limite actuelle.

COMMENT ON FUNCTION public.user_has_library_staff_role(uuid, uuid) IS
'DEPRECATED v0.3 : ne reconnaît PAS les admins réseau (paquet A). Conservé tel quel au paquet D.2 (11/05/2026) car les 3 callers connus s''accommodent de cette limite : fn_team_list_memberships (qui passe d''abord par fn_caller_is_administrador → fn_caller_is_network_admin au paquet D.8), fn_resolve_caller_role_for_library (qui fait fallback vers branche network_admin au paquet B), et api.resolve_circulation_rule (impact marginal : un admin réseau ne peut pas faire d''emprunts au nom d''autres lecteurs sur des biblios externes, cas d''usage rare). Refacto reportée au paquet F. À ce moment, soit le réécrire en wrapper de user_can_act_as_staff_on_library_for(uuid, uuid) (à créer), soit le DROP et migrer les callers vers user_can_act_as_staff_on_library + sous-requête.';

-- ============================================================================
-- SECTION 3 : VALIDATIONS POST-REFACTO
-- ============================================================================

-- 3.1 user_can_manage_library est maintenant un wrapper
DO $$
DECLARE
    v_def text;
BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'user_can_manage_library';
    
    IF v_def IS NULL THEN
        RAISE EXCEPTION 'helper_missing: user_can_manage_library introuvable';
    END IF;
    
    IF v_def NOT LIKE '%user_can_engage_library%' THEN
        RAISE EXCEPTION 'refacto_failed: user_can_manage_library n''appelle pas user_can_engage_library';
    END IF;
    
    IF v_def LIKE '%role IN (''coordenador'', ''administrador'')%' OR v_def LIKE '%role IN (''administrador''%' THEN
        RAISE WARNING 'refacto_partial: ancienne logique role IN encore présente';
    END IF;
    
    RAISE NOTICE 'refacto_ok: user_can_manage_library est maintenant un wrapper de user_can_engage_library';
END;
$$;

-- 3.2 Test fonctionnel : Xavier (admin réseau + coord BLMF) voit TRUE sur BLMF et BTL
-- Note : ce test n'utilise PAS de SET LOCAL ROLE authenticated car la requête
-- est faite dans le contexte de la migration. On vérifie juste que la fonction
-- ne plante pas, pas son comportement réel pour un utilisateur. Le test réel
-- sera dans les vérifications manuelles post-application.
DO $$
DECLARE
    v_result boolean;
BEGIN
    -- Appel sans utilisateur authentifié (auth.uid() retourne NULL)
    -- → user_can_engage_library doit retourner FALSE proprement
    SELECT public.user_can_manage_library('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid) INTO v_result;
    
    IF v_result IS NULL THEN
        RAISE EXCEPTION 'function_returns_null: user_can_manage_library retourne NULL au lieu de FALSE/TRUE';
    END IF;
    
    RAISE NOTICE 'function_smoke_test_ok: user_can_manage_library retourne % sans appelant (attendu : false sans auth)', v_result;
END;
$$;

-- 3.3 Helper user_can_engage_library toujours présent (paquet A)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'user_can_engage_library'
    ) THEN
        RAISE EXCEPTION 'dependency_missing: user_can_engage_library() introuvable (paquet A non appliqué ?)';
    END IF;
    
    RAISE NOTICE 'dependency_ok: user_can_engage_library() présent';
END;
$$;

-- 3.4 user_has_library_staff_role a son COMMENT mis à jour
DO $$
DECLARE
    v_comment text;
BEGIN
    SELECT obj_description(p.oid, 'pg_proc') INTO v_comment
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'user_has_library_staff_role';
    
    IF v_comment IS NULL OR v_comment NOT LIKE '%DEPRECATED%' THEN
        RAISE WARNING 'comment_missing: COMMENT de dépréciation pas appliqué sur user_has_library_staff_role';
    ELSE
        RAISE NOTICE 'comment_ok: user_has_library_staff_role marqué DEPRECATED';
    END IF;
END;
$$;

-- 3.5 Les RPC qui appellent user_can_manage_library bénéficient automatiquement
-- du fix (audit de visibilité) : on liste pour la traçabilité.
DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT count(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'api')
      AND p.prokind = 'f'
      AND p.proname <> 'user_can_manage_library'
      AND pg_get_functiondef(p.oid) LIKE '%user_can_manage_library%';
    
    RAISE NOTICE 'callers_count: % fonctions appellent user_can_manage_library (toutes bénéficient automatiquement du fix admin réseau)', v_count;
END;
$$;

COMMIT;

-- ============================================================================
-- Vérifications manuelles post-application :
-- ============================================================================
-- Toujours penser à SET LOCAL ROLE authenticated dans le SQL Editor !
--
-- Test 1 : voir la nouvelle définition de user_can_manage_library
--    SELECT pg_get_functiondef(p.oid)
--    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--    WHERE n.nspname = 'public' AND p.proname = 'user_can_manage_library';
--    Attendu : SELECT public.user_can_engage_library(p_library_id);
--
-- Test 2 : Xavier (admin réseau + coord BLMF) peut maintenant manager BTL
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "d6710372-e5e5-4608-800b-99a26817c677"}';
--    SELECT 
--      public.user_can_manage_library('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid) AS xavier_manage_blmf,
--      public.user_can_manage_library('b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'::uuid) AS xavier_manage_btl;
--    ROLLBACK;
--    Attendu : les deux à TRUE (BLMF via coord local, BTL via admin réseau)
--
-- Test 3 : Patricia (coord BTL pure) ne peut TOUJOURS PAS manager BLMF
--    BEGIN;
--    SET LOCAL ROLE authenticated;
--    SET LOCAL "request.jwt.claims" = '{"sub": "2a42b6bd-d159-4ee0-b66b-28a03062232b"}';
--    SELECT 
--      public.user_can_manage_library('b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'::uuid) AS patricia_manage_btl,
--      public.user_can_manage_library('1234825f-a0f9-4fbd-a875-6551c30ea4ca'::uuid) AS patricia_manage_blmf;
--    ROLLBACK;
--    Attendu : btl=TRUE, blmf=FALSE
--
-- ============================================================================
-- Fin du fichier.
-- ============================================================================
