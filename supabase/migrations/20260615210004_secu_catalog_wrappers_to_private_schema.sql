-- =========================================================================
-- Paquet SECU-MV-FIX2 — Wrappers catalogue dans un schéma NON exposé (private)
-- =========================================================================
-- Date     : 2026-06-15
-- Chantier : Nettoyage des security advisors Supabase (fermeture complète)
-- Auteur   : AnarBib
-- Session  : Perf UX + nettoyage advisors sécurité
--
-- POURQUOI (défaut résiduel des paquets SECU-MV / SECU-MV-FIX)
--   Les wrappers `fn_catalog_public_rows` / `fn_catalog_network_rows` ont été
--   créés dans `public`, schéma EXPOSÉ par PostgREST. Tant qu'ils y sont,
--   `authenticated` (qui doit pouvoir les EXÉCUTER pour que la vue invoker
--   catalog_list_session_v1 fonctionne) peut AUSSI les appeler directement via
--   POST /rest/v1/rpc/fn_catalog_network_rows et obtenir la MV réseau NON
--   filtrée → le filtre d'appartenance de la vue est de nouveau contournable.
--   Wrapper exposé == GRANT direct sur la MV : on n'avait fait que déplacer la
--   fuite.
--
-- CORRECTIF DÉFINITIF
--   Déplacer les 2 wrappers dans le schéma `private` (NON exposé par PostgREST).
--   PostgREST ne les sert plus en RPC → aucun chemin direct (ni anon ni
--   authenticated). Seules les vues `api.*` (security_invoker, schéma exposé)
--   les appellent en cross-schema : l'appelant a besoin de USAGE sur `private`
--   (accordé) + EXECUTE (préservé par SET SCHEMA). Le filtre de la vue session
--   devient le SEUL point d'accès au catalogue réseau pour un compte connecté.
--   Bonus : les wrappers sortent des advisors 0028/0029 (schéma non exposé).
--   Les MV restent dans `public` (lues en tant que postgres par search_catalog_v1
--   et le refresh, SECDEF) → OPAC et refresh inchangés.
--
--   Précédent de relocalisation de schéma : paquet L7 (pg_trgm -> extensions).
--   Les vues référencent les fonctions par OID → elles suivent automatiquement
--   le changement de schéma (vérifié par le bloc de contrôle ci-dessous).
-- =========================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS private;
COMMENT ON SCHEMA private IS
  'Objets internes NON exposes par PostgREST (wrappers SECDEF du catalogue, '
  'etc.). Cree paquet SECU-MV-FIX2 du 15/06/2026.';

GRANT USAGE ON SCHEMA private TO anon, authenticated, service_role;

ALTER FUNCTION public.fn_catalog_public_rows()  SET SCHEMA private;
ALTER FUNCTION public.fn_catalog_network_rows() SET SCHEMA private;

-- -------------------------------------------------------------------------
-- Vérification : fonctions bien dans private, vues toujours fonctionnelles
-- (preuve que le suivi par OID a opéré), filtre membre/non-membre préservé.
-- -------------------------------------------------------------------------
DO $verify$
DECLARE
  v_in_private    int;
  v_in_public     int;
  v_member        uuid;
  v_anon_rows     int;
  v_member_rows   int;
  v_nonmember_rows int;
BEGIN
  -- (a) les 2 wrappers sont dans private, plus dans public
  SELECT count(*) INTO v_in_private
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'private'
     AND p.proname IN ('fn_catalog_public_rows', 'fn_catalog_network_rows');
  SELECT count(*) INTO v_in_public
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_catalog_public_rows', 'fn_catalog_network_rows');
  IF v_in_private <> 2 OR v_in_public <> 0 THEN
    RAISE EXCEPTION 'Verif echouee : wrappers private=% public=% (attendu 2/0). Rollback.', v_in_private, v_in_public;
  END IF;

  -- (b) la vue anon fonctionne (appel cross-schema private via USAGE+EXECUTE)
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{"role":"anon"}';
  SELECT count(*) INTO v_anon_rows FROM api.catalog_list_anon_v1;
  RESET ROLE;
  IF v_anon_rows < 1 THEN
    RAISE EXCEPTION 'Verif echouee : catalog_list_anon_v1 vide en anon apres deplacement (% lignes). Rollback.', v_anon_rows;
  END IF;

  -- (c) membre voit tout, (d) non-membre seulement le sous-ensemble public
  SELECT user_id INTO v_member FROM public.user_library_memberships WHERE status = 'active' LIMIT 1;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_member, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_member_rows FROM api.catalog_list_session_v1;
  RESET ROLE;

  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  SELECT count(*) INTO v_nonmember_rows FROM api.catalog_list_session_v1;
  RESET ROLE;

  IF v_member_rows < 1 THEN
    RAISE EXCEPTION 'Verif echouee : catalog_list_session_v1 vide pour un membre apres deplacement. Rollback.';
  END IF;
  IF v_nonmember_rows >= v_member_rows THEN
    RAISE EXCEPTION 'Verif echouee : filtre reseau perdu (nonmembre=% >= membre=%). Rollback.', v_nonmember_rows, v_member_rows;
  END IF;

  RAISE NOTICE 'SECU-MV-FIX2 OK : wrappers dans private, anon=% membre=% nonmembre=% (aucun chemin RPC direct vers la MV reseau).',
    v_anon_rows, v_member_rows, v_nonmember_rows;
END
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback (si besoin) : ALTER FUNCTION private.fn_catalog_*_rows() SET SCHEMA public;
-- =========================================================================
