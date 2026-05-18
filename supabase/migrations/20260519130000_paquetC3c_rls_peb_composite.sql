-- ============================================================================
-- Paquet C.3c — Helper fn_peb_authorized + patches RLS PEB INSERT/UPDATE
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.3
-- Audit prealable : paquetC1_audit_rls.md §5
-- Dependance : paquetC2_helpers_modes_profils.sql (20260519100000)
-- Suit : paquetC3b_rls_select_circulation.sql (20260519120000)
--
-- Arbitrage doctrinal (Q1+Q5 spec §2.5) :
--   PEB INSERT/UPDATE exige COMPOSITE STRICT :
--     - circulation des deux bibs (les deux <> off)
--     - federation des deux bibs (les deux = federated)
--   Une biblio observer ne peut PAS faire de PEB (spec §2.5 explicite :
--   federated exige les fonctions inter-bibs ; observer ne participe pas).
--
-- Option implementation : helper compose fn_peb_authorized(lender, borrower)
--   - Encapsule la logique politique dans une fonction unique testable
--   - Reduit la surface RLS (2 conditions au lieu de 4)
--   - Reutilisable en C.5 pour les vues PEB
--
-- 2 RLS patchees :
--   1. interlibrary_loans_v2_insert (INSERT)
--   2. interlibrary_loans_v2_update (UPDATE)
--
-- Items v2 (3 RLS) : NON patchees directement, l'heritage via EXISTS sur
-- interlibrary_loans_v2 suffit (RLS de la parente filtre la sous-requete).
--
-- Doctrine appliquee : v2 sur fn_peb_authorized + DO block fail-fast.
-- Validation : test PostgREST simule (test_C3c_postgrest_simule.sql).
-- Note : 0 PEB en prod => tests fonctionnels structurels (helper teste isolement).
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Helper fn_peb_authorized — encapsule la logique composite PEB
-- ---------------------------------------------------------------------------
-- Vrai si lender ET borrower satisfont tous les criteres pour creer/avancer un PEB :
--   - has_circulation des deux cotes (circulation_mode <> off)
--   - is_federated des deux cotes (network_mode = federated)
-- Coherent avec spec §2.5 PEB = fonction inter-bibs federees.
CREATE OR REPLACE FUNCTION public.fn_peb_authorized(
  p_lender_library_id uuid,
  p_borrower_library_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
  SELECT
    public.fn_library_has_circulation(p_lender_library_id)
    AND public.fn_library_has_circulation(p_borrower_library_id)
    AND public.fn_library_is_federated(p_lender_library_id)
    AND public.fn_library_is_federated(p_borrower_library_id);
$func$;

COMMENT ON FUNCTION public.fn_peb_authorized(uuid, uuid) IS
  'Vrai si les 2 bibs peuvent participer a un PEB (circulation actif + federated des deux cotes). Helper composite paquet C.3c.';

REVOKE EXECUTE ON FUNCTION public.fn_peb_authorized(uuid, uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.fn_peb_authorized(uuid, uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. RLS interlibrary_loans_v2_insert — INSERT
-- ---------------------------------------------------------------------------
-- Original : WITH CHECK (user_can_manage_library(lender_library_id)
--                        OR user_can_manage_library(borrower_library_id))
-- Patche   : original AND fn_peb_authorized(lender, borrower)
DROP POLICY IF EXISTS interlibrary_loans_v2_insert ON public.interlibrary_loans_v2;
CREATE POLICY interlibrary_loans_v2_insert
  ON public.interlibrary_loans_v2
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (user_can_manage_library(lender_library_id)
     OR user_can_manage_library(borrower_library_id))
    AND public.fn_peb_authorized(lender_library_id, borrower_library_id)
  );
COMMENT ON POLICY interlibrary_loans_v2_insert ON public.interlibrary_loans_v2 IS
  'Creation PEB autorisee si les 2 bibs ont circulation+federation (paquet C.3c, composite strict).';

-- ---------------------------------------------------------------------------
-- 3. RLS interlibrary_loans_v2_update — UPDATE
-- ---------------------------------------------------------------------------
-- Original USING / WITH CHECK : user_can_manage_library(lender_library_id)
--                                OR user_can_manage_library(borrower_library_id)
-- Patche : original AND fn_peb_authorized(lender, borrower) sur les deux clauses
DROP POLICY IF EXISTS interlibrary_loans_v2_update ON public.interlibrary_loans_v2;
CREATE POLICY interlibrary_loans_v2_update
  ON public.interlibrary_loans_v2
  FOR UPDATE
  TO authenticated
  USING (
    (user_can_manage_library(lender_library_id)
     OR user_can_manage_library(borrower_library_id))
    AND public.fn_peb_authorized(lender_library_id, borrower_library_id)
  )
  WITH CHECK (
    (user_can_manage_library(lender_library_id)
     OR user_can_manage_library(borrower_library_id))
    AND public.fn_peb_authorized(lender_library_id, borrower_library_id)
  );
COMMENT ON POLICY interlibrary_loans_v2_update ON public.interlibrary_loans_v2 IS
  'Progression workflow PEB autorisee si les 2 bibs ont circulation+federation (paquet C.3c).';

-- ---------------------------------------------------------------------------
-- 4. DO block de verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_blmf_id uuid;
  v_btl_id uuid;
  v_fake_id uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_count int;
  v_search_path text;
BEGIN
  -- a. Helper fn_peb_authorized cree avec bonne signature
  SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_peb_authorized'
     AND pg_get_function_identity_arguments(p.oid) = 'p_lender_library_id uuid, p_borrower_library_id uuid';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : helper fn_peb_authorized absent ou signature incorrecte';
  END IF;

  -- b. search_path doctrine v2
  SELECT array_to_string(p.proconfig, ',') INTO v_search_path
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_peb_authorized';
  IF v_search_path IS NULL OR v_search_path NOT LIKE '%public%pg_temp%' THEN
    RAISE EXCEPTION 'VERIF_FAIL_b : search_path doctrine v2 incorrect : %', v_search_path;
  END IF;

  -- c. 2 RLS PEB cibles existent et referencent fn_peb_authorized
  SELECT count(*) INTO v_count FROM pg_policies
   WHERE schemaname = 'public'
     AND (tablename, policyname) IN (
       ('interlibrary_loans_v2', 'interlibrary_loans_v2_insert'),
       ('interlibrary_loans_v2', 'interlibrary_loans_v2_update')
     )
     AND (COALESCE(qual,'') || ' ' || COALESCE(with_check,'')) LIKE '%fn_peb_authorized%';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'VERIF_FAIL_c : %/2 RLS PEB referencent fn_peb_authorized', v_count;
  END IF;

  -- d. BLMF + BTL profil D
  SELECT id INTO v_blmf_id FROM public.libraries
   WHERE name = 'Biblioteca Libertária Maxwell Ferreira' LIMIT 1;
  SELECT id INTO v_btl_id FROM public.libraries
   WHERE name = 'Biblioteca Terra Livre' LIMIT 1;
  IF v_blmf_id IS NULL OR v_btl_id IS NULL THEN
    RAISE EXCEPTION 'VERIF_FAIL_d : BLMF=% BTL=%', v_blmf_id, v_btl_id;
  END IF;

  -- e. Tests semantiques du helper (sans simulation off — testee hors transaction)
  -- e.1 BLMF (full_sigb, federated) <-> BTL (full_sigb, federated) : TRUE
  IF NOT public.fn_peb_authorized(v_blmf_id, v_btl_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_e1 : fn_peb_authorized(BLMF, BTL) doit etre TRUE (profil D x profil D)';
  END IF;

  -- e.2 BLMF <-> BLMF (meme biblio) : TRUE (cas degenere mais coherent)
  IF NOT public.fn_peb_authorized(v_blmf_id, v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_e2 : fn_peb_authorized(BLMF, BLMF) doit etre TRUE';
  END IF;

  -- e.3 UUID inconnu <-> BLMF : FALSE (les sous-helpers retournent FALSE sur UUID inconnu)
  IF public.fn_peb_authorized(v_fake_id, v_blmf_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_e3 : fn_peb_authorized(<inconnu>, BLMF) doit etre FALSE';
  END IF;

  -- e.4 BLMF <-> UUID inconnu : FALSE
  IF public.fn_peb_authorized(v_blmf_id, v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_e4 : fn_peb_authorized(BLMF, <inconnu>) doit etre FALSE';
  END IF;

  -- e.5 UUID inconnu x 2 : FALSE
  IF public.fn_peb_authorized(v_fake_id, v_fake_id) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'VERIF_FAIL_e5 : fn_peb_authorized(<inconnu>, <inconnu>) doit etre FALSE';
  END IF;

  RAISE NOTICE 'Paquet C.3c — Verification OK : fn_peb_authorized cree, 2 RLS PEB conditionnees, semantique helper validee';
END
$verif$;

COMMIT;
