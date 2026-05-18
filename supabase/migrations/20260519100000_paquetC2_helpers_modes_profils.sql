-- ============================================================================
-- Paquet C.2 — Helpers de lecture des modes profils
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §3.3, §9.3
-- Audit prealable : paquetC1_audit_rls.md
-- Doctrine appliquee : creation objets backend v2 (CHANTIER_doctrine_..._v2_2026-05-18.md)
--   - SECURITY DEFINER + SET search_path = public, pg_temp
--   - REVOKE EXECUTE FROM PUBLIC, anon, authenticated, service_role (forme obligatoire)
--   - GRANT EXECUTE TO authenticated (rôle légitime pour appel via RLS authenticated)
--   - DO block fail-fast en fin de migration testant les valeurs attendues
--
-- Arbitrages (session 19/05/2026) :
--   Q1 PEB : SELECT autorise pendant transition off (cloture propre), bloc en INSERT/UPDATE en C.3
--   Q2 signup public : reste possible meme en isolated (libraries_public_signup_read non patchee)
--   Q3 policy_rules : redondance defensive (les 5 RLS rules patchees en plus en C.3)
--   Q4 fn_library_visible_to_caller : etendu ici (couvre books + libraries + vues C.5)
--   Q5 fn_library_is_federated : stricte (= federated seul)
--   Q6 governance : strict + nouveau fn_library_has_staff_roles
--
-- Periode d'execution : 19/05/2026 10h
-- Aucun risque de regression (les 5 helpers existants n'ont aucun usage detecte
-- via pg_proc/pg_views/pg_policies au 18/05 23h59)
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. fn_library_has_circulation — circulation_mode <> 'off'
-- ---------------------------------------------------------------------------
-- Vrai si la biblio a une circulation active (informal ou full_sigb).
-- Faux si circulation_mode = 'off' ou si la biblio n'existe pas/est inactive.
-- Note : retourne FALSE (pas NULL) pour les UUID inconnus, par securite RLS.
CREATE OR REPLACE FUNCTION public.fn_library_has_circulation(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
  SELECT COALESCE(
    (SELECT circulation_mode <> 'off'
       FROM public.libraries
      WHERE id = p_library_id
        AND is_active = true),
    false
  );
$func$;

COMMENT ON FUNCTION public.fn_library_has_circulation(uuid) IS
  'Vrai si circulation_mode IN (informal, full_sigb). Helper RLS/RPC paquet C profils.';

REVOKE EXECUTE ON FUNCTION public.fn_library_has_circulation(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.fn_library_has_circulation(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. fn_library_has_full_sigb — circulation_mode = 'full_sigb'
-- ---------------------------------------------------------------------------
-- Vrai uniquement pour le SIGB complet (politiques de pret, cotisations, rappels).
CREATE OR REPLACE FUNCTION public.fn_library_has_full_sigb(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
  SELECT COALESCE(
    (SELECT circulation_mode = 'full_sigb'
       FROM public.libraries
      WHERE id = p_library_id
        AND is_active = true),
    false
  );
$func$;

COMMENT ON FUNCTION public.fn_library_has_full_sigb(uuid) IS
  'Vrai si circulation_mode = full_sigb (politiques de pret, rappels, cotisations).';

REVOKE EXECUTE ON FUNCTION public.fn_library_has_full_sigb(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.fn_library_has_full_sigb(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. fn_library_publishes_catalog — catalog_mode = 'network_published'
-- ---------------------------------------------------------------------------
-- Vrai si le catalogue est publie dans la MV reseau et les autorites federees.
CREATE OR REPLACE FUNCTION public.fn_library_publishes_catalog(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
  SELECT COALESCE(
    (SELECT catalog_mode = 'network_published'
       FROM public.libraries
      WHERE id = p_library_id
        AND is_active = true),
    false
  );
$func$;

COMMENT ON FUNCTION public.fn_library_publishes_catalog(uuid) IS
  'Vrai si catalog_mode = network_published (notice visible reseau, autorite federee).';

REVOKE EXECUTE ON FUNCTION public.fn_library_publishes_catalog(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.fn_library_publishes_catalog(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. fn_library_is_federated — network_mode = 'federated' (STRICT, arbitrage Q5)
-- ---------------------------------------------------------------------------
-- Vrai uniquement en federation pleine (visible reseau + participe inter-bibs).
-- Une biblio en mode observer voit le reseau mais N'EST PAS visible : pas couverte.
-- Note : pas de helper symetrique fn_library_observes_network a ce stade (Q5).
CREATE OR REPLACE FUNCTION public.fn_library_is_federated(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
  SELECT COALESCE(
    (SELECT network_mode = 'federated'
       FROM public.libraries
      WHERE id = p_library_id
        AND is_active = true),
    false
  );
$func$;

COMMENT ON FUNCTION public.fn_library_is_federated(uuid) IS
  'Vrai si network_mode = federated (STRICT, arbitrage Q5 paquet C). Observer non couvert.';

REVOKE EXECUTE ON FUNCTION public.fn_library_is_federated(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.fn_library_is_federated(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 5. fn_library_uses_governance — governance_mode = 'full_governance' (STRICT, Q6)
-- ---------------------------------------------------------------------------
-- Vrai uniquement pour le workflow complet : cooptation unanime, votes, carence.
-- Une biblio en mode staff_roles a des roles differencies SANS workflow formel.
CREATE OR REPLACE FUNCTION public.fn_library_uses_governance(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
  SELECT COALESCE(
    (SELECT governance_mode = 'full_governance'
       FROM public.libraries
      WHERE id = p_library_id
        AND is_active = true),
    false
  );
$func$;

COMMENT ON FUNCTION public.fn_library_uses_governance(uuid) IS
  'Vrai si governance_mode = full_governance (STRICT). Workflow cooptation/votes/audit/carence active.';

REVOKE EXECUTE ON FUNCTION public.fn_library_uses_governance(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.fn_library_uses_governance(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. fn_library_has_staff_roles — governance_mode <> 'informal' (NEW, Q6)
-- ---------------------------------------------------------------------------
-- Vrai si la biblio a des roles differencies (librarian, coordenador, administrador).
-- Couvre staff_roles ET full_governance.
-- Justification : la contrainte de spec §2.8 dit que full_sigb exige staff_roles minimum.
-- C'est ce predicat qui controle les RLS policy_sets/rules (C.3).
CREATE OR REPLACE FUNCTION public.fn_library_has_staff_roles(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
  SELECT COALESCE(
    (SELECT governance_mode <> 'informal'
       FROM public.libraries
      WHERE id = p_library_id
        AND is_active = true),
    false
  );
$func$;

COMMENT ON FUNCTION public.fn_library_has_staff_roles(uuid) IS
  'Vrai si governance_mode IN (staff_roles, full_governance). Helper roles differencies (paquet C).';

REVOKE EXECUTE ON FUNCTION public.fn_library_has_staff_roles(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.fn_library_has_staff_roles(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 7. EXTENSION fn_library_visible_to_caller (arbitrage Q4)
-- ---------------------------------------------------------------------------
-- Anciennement : visibilite basee uniquement sur visibility_level + appartenance.
-- Maintenant : intersecte avec network_mode pour les branches publique et reseau.
-- Branche `private` (membres) : INCHANGEE. Un membre voit toujours sa biblio,
-- quel que soit network_mode. Coherent : isolated = invisible de l'exterieur,
-- pas invisible aux membres.
--
-- IMPACT : la policy `libraries.libraries_public_read` (anon + auth) et la policy
-- `books.books_public_read` (qui utilise ce helper) sont automatiquement
-- conditionnees par network_mode. Aucune modification RLS necessaire pour
-- ces deux policies — l'effet vient gratuitement par l'extension du helper.
--
-- Note : ne touche PAS a `libraries_public_signup_read` (arbitrage Q2 : signup
-- public reste possible meme en isolated, par lien direct).
CREATE OR REPLACE FUNCTION public.fn_library_visible_to_caller(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
  SELECT EXISTS (
    SELECT 1
      FROM public.libraries l
     WHERE l.id = p_library_id
       AND l.is_active = true
       AND (
         -- Branche public : visible anon + auth, MAIS pas si isolated
         (l.visibility_level = 'public'
          AND l.network_mode <> 'isolated')
         OR
         -- Branche network : visible aux auth membres du reseau, MAIS pas si isolated
         (l.visibility_level = 'network'
          AND auth.uid() IS NOT NULL
          AND public.fn_current_user_is_in_network()
          AND l.network_mode <> 'isolated')
         OR
         -- Branche private : INCHANGEE — un membre voit sa biblio meme si isolated
         (l.visibility_level = 'private'
          AND auth.uid() IS NOT NULL
          AND public.fn_current_user_is_member_of(p_library_id))
       )
  );
$func$;

COMMENT ON FUNCTION public.fn_library_visible_to_caller(uuid) IS
  'Visibilite biblio pour caller (anon/auth/membre). Etendue paquet C.2 : network_mode <> isolated sur branches public/network. Branche private inchangee.';

-- Les GRANT existants sur fn_library_visible_to_caller restent inchanges.
-- (helper deja en place depuis longtemps, ne pas casser les permissions actuelles)

-- ---------------------------------------------------------------------------
-- 8. DO block de verification fail-fast
-- ---------------------------------------------------------------------------
-- Doctrine v2 : verifications fonctionnelles obligatoires AVANT COMMIT.
-- En cas d'echec d'un test, RAISE EXCEPTION = auto-rollback de toute la migration.
--
-- Tests :
--   a. Les 6 helpers existent avec la bonne signature
--   b. Les 6 helpers sont en SECURITY DEFINER avec search_path correct
--   c. Sur BLMF et BTL (profil D = tout active), tous les helpers retournent true
--      sauf fn_library_has_full_sigb qui depend du mode exact
--   d. fn_library_visible_to_caller retourne TRUE pour BLMF/BTL en contexte anon
--      (visibility_level=public AND network_mode<>isolated)
--   e. fn_library_visible_to_caller retourne FALSE pour un UUID inconnu
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_blmf_id uuid;
  v_btl_id uuid;
  v_fake_id uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_count int;
  v_search_path text;
BEGIN
  -- a. Verifier la presence des 6 helpers avec la bonne signature
  SELECT count(*) INTO v_count
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN (
       'fn_library_has_circulation',
       'fn_library_has_full_sigb',
       'fn_library_publishes_catalog',
       'fn_library_is_federated',
       'fn_library_uses_governance',
       'fn_library_has_staff_roles'
     )
     AND pg_get_function_identity_arguments(p.oid) = 'p_library_id uuid';

  IF v_count <> 6 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : attendu 6 helpers avec signature (uuid), trouve %', v_count;
  END IF;

  -- b. Verifier search_path correct sur les 6 helpers (doctrine v2)
  FOR v_search_path IN
    SELECT array_to_string(p.proconfig, ',')
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN (
         'fn_library_has_circulation',
         'fn_library_has_full_sigb',
         'fn_library_publishes_catalog',
         'fn_library_is_federated',
         'fn_library_uses_governance',
         'fn_library_has_staff_roles'
       )
  LOOP
    IF v_search_path IS NULL OR v_search_path NOT LIKE '%public%pg_temp%' THEN
      RAISE EXCEPTION 'VERIF_FAIL_b : search_path doctrine v2 manquant ou incorrect : %', v_search_path;
    END IF;
  END LOOP;

  -- c. Recuperer les UUID des 2 biblios prod (toutes deux en profil D)
  SELECT id INTO v_blmf_id FROM public.libraries
   WHERE name = 'Biblioteca Libertária Maxwell Ferreira' LIMIT 1;
  SELECT id INTO v_btl_id FROM public.libraries
   WHERE name = 'Biblioteca Terra Livre' LIMIT 1;

  IF v_blmf_id IS NULL OR v_btl_id IS NULL THEN
    RAISE EXCEPTION 'VERIF_FAIL_c0 : BLMF ou BTL introuvable (BLMF=%, BTL=%)', v_blmf_id, v_btl_id;
  END IF;

  -- c.1 BLMF en profil D : tous les helpers (sauf comparaisons exactes) renvoient true
  IF NOT public.fn_library_has_circulation(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c1a : fn_library_has_circulation(BLMF) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_has_full_sigb(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c1b : fn_library_has_full_sigb(BLMF) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_publishes_catalog(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c1c : fn_library_publishes_catalog(BLMF) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_is_federated(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c1d : fn_library_is_federated(BLMF) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_uses_governance(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c1e : fn_library_uses_governance(BLMF) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_has_staff_roles(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c1f : fn_library_has_staff_roles(BLMF) doit etre TRUE en profil D';
  END IF;

  -- c.2 Idem BTL
  IF NOT public.fn_library_has_circulation(v_btl_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c2a : fn_library_has_circulation(BTL) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_has_full_sigb(v_btl_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c2b : fn_library_has_full_sigb(BTL) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_publishes_catalog(v_btl_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c2c : fn_library_publishes_catalog(BTL) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_is_federated(v_btl_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c2d : fn_library_is_federated(BTL) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_uses_governance(v_btl_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c2e : fn_library_uses_governance(BTL) doit etre TRUE en profil D';
  END IF;
  IF NOT public.fn_library_has_staff_roles(v_btl_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c2f : fn_library_has_staff_roles(BTL) doit etre TRUE en profil D';
  END IF;

  -- d. UUID inconnu : tous les helpers retournent FALSE (pas NULL — securite RLS)
  IF public.fn_library_has_circulation(v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_d1 : fn_library_has_circulation(<inconnu>) doit etre FALSE (pas NULL)';
  END IF;
  IF public.fn_library_has_full_sigb(v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_d2 : fn_library_has_full_sigb(<inconnu>) doit etre FALSE';
  END IF;
  IF public.fn_library_publishes_catalog(v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_d3 : fn_library_publishes_catalog(<inconnu>) doit etre FALSE';
  END IF;
  IF public.fn_library_is_federated(v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_d4 : fn_library_is_federated(<inconnu>) doit etre FALSE';
  END IF;
  IF public.fn_library_uses_governance(v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_d5 : fn_library_uses_governance(<inconnu>) doit etre FALSE';
  END IF;
  IF public.fn_library_has_staff_roles(v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_d6 : fn_library_has_staff_roles(<inconnu>) doit etre FALSE';
  END IF;

  -- e. fn_library_visible_to_caller : test de coherence des preconditions
  --    Etat prod constate au 19/05/2026 :
  --      BLMF : visibility_level=public, network_mode=federated → branche publique
  --      BTL  : visibility_level=network, network_mode=federated → branche reseau
  --    Les deux ne sont pas isolated, donc fn_library_visible_to_caller doit
  --    pouvoir les retourner TRUE dans leur contexte respectif (anon pour BLMF,
  --    auth-membre-reseau pour BTL).
  --    Test minimal : aucune des 2 n'est isolated (precondition commune des deux branches).
  SELECT count(*) INTO v_count
    FROM public.libraries
   WHERE id IN (v_blmf_id, v_btl_id)
     AND is_active = true
     AND network_mode <> 'isolated'
     AND visibility_level IN ('public','network');

  IF v_count <> 2 THEN
    RAISE EXCEPTION 'VERIF_FAIL_e : BLMF et BTL doivent etre is_active + network_mode<>isolated + visibility_level IN (public,network), trouve %/2', v_count;
  END IF;

  -- e2. UUID inconnu doit retourner FALSE (securite RLS)
  IF public.fn_library_visible_to_caller(v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_e2 : fn_library_visible_to_caller(<inconnu>) doit etre FALSE';
  END IF;

  RAISE NOTICE 'Paquet C.2 — Verification fail-fast OK : 6 helpers crees/modernises + extension fn_library_visible_to_caller pour BLMF (%) et BTL (%)', v_blmf_id, v_btl_id;
END
$verif$;

COMMIT;
