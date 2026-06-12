-- =========================================================================
-- Paquet FED-1b — Durcissement : REVOKE EXECUTE FROM anon sur les helpers cercle
-- =========================================================================
-- Date     : 2026-06-12
-- Chantier : face fédération / cercles (suite paquet FED-1, migration 20260612075752)
-- Auteur   : Xavier (AnarBib)
-- Session  : Cercles fédéraux — fondations
--
-- Contexte : l'advisor sécurité Supabase signale
-- `anon_security_definer_function_executable` sur les 4 helpers SECURITY DEFINER
-- créés en public par FED-1. En cause : le default privilege Supabase de `public`
-- accorde EXECUTE à `anon` à la création, que `REVOKE EXECUTE … FROM PUBLIC`
-- (fait en FED-1) ne retire pas. Conséquence : `anon` pouvait appeler ces
-- fonctions via PostgREST RPC — inoffensif pour les 3 helpers de garde (auth.uid()
-- NULL → false), mais `fn_circle_member_count` exposait un compteur de membres.
-- Aucune de ces fonctions n'est nécessaire à `anon` (les objets cercle sont
-- réservés à `authenticated` : tables REVOKE ALL FROM anon, vues GRANT authenticated).
--
-- Correctif : REVOKE EXECUTE FROM anon (conforme DOC-OBJ-2 : révoquer anon en plus
-- de PUBLIC). `authenticated` conserve EXECUTE (usage par les vues/RLS) — le warning
-- `authenticated_security_definer_function_executable` reste, c'est le pattern maison
-- RPC-first assumé. Les 6 RPC api.fn_circle_* sont déjà anon=false (schéma api).
-- =========================================================================

BEGIN;

REVOKE EXECUTE ON FUNCTION public.fn_caller_attached_member()      FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_caller_in_circle(uuid)        FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_caller_attached_library(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_circle_member_count(uuid)     FROM anon;

DO $verify$
DECLARE v_anon int; v_auth int;
BEGIN
    SELECT
        count(*) FILTER (WHERE has_function_privilege('anon', sig, 'EXECUTE')),
        count(*) FILTER (WHERE has_function_privilege('authenticated', sig, 'EXECUTE'))
    INTO v_anon, v_auth
    FROM (VALUES
        ('public.fn_caller_attached_member()'),
        ('public.fn_caller_in_circle(uuid)'),
        ('public.fn_caller_attached_library(uuid)'),
        ('public.fn_circle_member_count(uuid)')
    ) f(sig);

    IF v_anon <> 0 THEN
        RAISE EXCEPTION 'verify FED-1b: anon peut encore exécuter % helper(s) cercle', v_anon;
    END IF;
    IF v_auth <> 4 THEN
        RAISE EXCEPTION 'verify FED-1b: authenticated devrait garder EXECUTE sur les 4 helpers (trouvé %)', v_auth;
    END IF;
    RAISE NOTICE 'FED-1b OK : anon révoqué sur les 4 helpers cercle ; authenticated conservé.';
END;
$verify$;

COMMIT;

-- Rollback (si besoin) :
-- BEGIN;
--   GRANT EXECUTE ON FUNCTION public.fn_caller_attached_member(), public.fn_caller_in_circle(uuid),
--     public.fn_caller_attached_library(uuid), public.fn_circle_member_count(uuid) TO anon;
-- COMMIT;
