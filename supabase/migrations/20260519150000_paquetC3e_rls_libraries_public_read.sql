-- ============================================================================
-- Paquet C.3e — RLS libraries (libraries_public_read + libraries_public_signup_read)
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.3 (Q2 raffinee 19/05)
-- Audit prealable : paquetC1_audit_rls.md §8
-- Dependance : paquetC2_helpers_modes_profils.sql (helper fn_library_visible_to_caller etendu)
--
-- Objectif : conditionner la visibilite publique des biblios par network_mode <> 'isolated'.
--
-- DEUX RLS PATCHEES :
--
--   1. libraries_public_read : refactor pour deleguer a fn_library_visible_to_caller(id)
--      (deja etendu en C.2 pour integrer network_mode <> isolated sur public/network).
--      Benefice : code DRY, coherence avec books_public_read.
--
--   2. libraries_public_signup_read : ajoute filtre network_mode <> 'isolated'.
--      Raffinement de l'arbitrage Q2 initial (audit C.1) suite a la decouverte
--      lors du test PostgREST simule : avec accepts_public_signup=true sans filtre
--      network_mode, une biblio basculee en isolated reste visible a anon via
--      cette policy parallele.
--      Doctrine §2.5 : "isolated = pas vue par le reseau" est inconditionnel.
--      Une biblio isolated qui veut accueillir un nouveau leitora doit
--      passer en observer ou utiliser l'inscription manuelle par le staff.
--
-- Doctrine appliquee : #10 test PostgREST simule.
-- Risque : eleve (RLS publique, surface large) mitige par tests anon+auth.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. libraries_public_read : refactor via fn_library_visible_to_caller(id)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS libraries_public_read ON public.libraries;
CREATE POLICY libraries_public_read
  ON public.libraries
  FOR SELECT
  TO anon, authenticated
  USING (
    public.fn_library_visible_to_caller(id)
  );
COMMENT ON POLICY libraries_public_read ON public.libraries IS
  'Visibilite biblio anon/auth deleguee a fn_library_visible_to_caller (etendu C.2 : network_mode <> isolated sur public/network). Paquet C.3e.';

-- ---------------------------------------------------------------------------
-- 2. libraries_public_signup_read : filtre network_mode <> 'isolated'
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS libraries_public_signup_read ON public.libraries;
CREATE POLICY libraries_public_signup_read
  ON public.libraries
  FOR SELECT
  TO anon, authenticated
  USING (
    is_active = true
    AND accepts_public_signup = true
    AND network_mode <> 'isolated'
  );
COMMENT ON POLICY libraries_public_signup_read ON public.libraries IS
  'Listage publique pour signup. Filtre network_mode <> isolated (coherence doctrine §2.5 isolated, paquet C.3e).';

-- ---------------------------------------------------------------------------
-- DO block de verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_blmf_id uuid;
  v_btl_id uuid;
  v_count int;
BEGIN
  -- a. libraries_public_read utilise fn_library_visible_to_caller
  SELECT count(*) INTO v_count FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'libraries'
     AND policyname = 'libraries_public_read'
     AND COALESCE(qual,'') LIKE '%fn_library_visible_to_caller%';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : libraries_public_read ne reference pas fn_library_visible_to_caller';
  END IF;

  -- b. libraries_public_signup_read filtre network_mode <> isolated
  SELECT count(*) INTO v_count FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename = 'libraries'
     AND policyname = 'libraries_public_signup_read'
     AND COALESCE(qual,'') LIKE '%network_mode%isolated%';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_b : libraries_public_signup_read ne filtre pas network_mode <> isolated';
  END IF;

  -- c. BLMF + BTL existent
  SELECT id INTO v_blmf_id FROM public.libraries
   WHERE name = 'Biblioteca Libertária Maxwell Ferreira' LIMIT 1;
  SELECT id INTO v_btl_id FROM public.libraries
   WHERE name = 'Biblioteca Terra Livre' LIMIT 1;
  IF v_blmf_id IS NULL OR v_btl_id IS NULL THEN
    RAISE EXCEPTION 'VERIF_FAIL_c : BLMF=% BTL=%', v_blmf_id, v_btl_id;
  END IF;

  -- d. Non regression visible_to_caller en role postgres
  IF NOT public.fn_library_visible_to_caller(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_d : helper(BLMF) devrait etre TRUE en profil D';
  END IF;

  -- e. Non regression : BLMF + BTL en network_mode=federated (pas isolated)
  --    => signup_read laisse passer les deux
  SELECT count(*) INTO v_count FROM public.libraries
   WHERE id IN (v_blmf_id, v_btl_id)
     AND is_active = true
     AND accepts_public_signup = true
     AND network_mode <> 'isolated';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'VERIF_FAIL_e : %/2 biblios passent les conditions signup_read', v_count;
  END IF;

  RAISE NOTICE 'Paquet C.3e — Verification OK : 2 RLS patchees (public_read delegue helper, signup_read filtre isolated)';
END
$verif$;

COMMIT;
