-- ============================================================================
-- Paquet C.3b — Patches RLS SELECT prets + consultations + PEB
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.3
-- Audit prealable : paquetC1_audit_rls.md §2, §4, §5
-- Dependance : paquetC2_helpers_modes_profils.sql (20260519100000)
-- Suit : paquetC3a_rls_reservas_circulation.sql (20260519110000)
--
-- Objectif : conditionner 3 RLS SELECT par fn_library_has_circulation()
-- pour empecher la lecture des transactions vivantes en mode off.
--
-- Particularite PEB (arbitrage Q1 doctrine cloture propre) :
--   - SELECT permissif si AU MOINS UNE des deux bibs garde circulation
--   - Permet la cloture des transactions inter-bibs en cours quand une biblio
--     bascule en off (cf. spec §9.3, doctrine workflow PEB).
--
-- 3 policies patchees, 3 tables :
--   1. emprestimos_v2.emprestimos_v2_select_policy        : direct library_id
--   2. consultas_locais_v2.consultas_locais_v2_select_policy : direct library_id
--   3. interlibrary_loans_v2.interlibrary_loans_v2_select : OR lender/borrower (Q1)
--
-- Note INSERT/UPDATE : aucune policy directe sur emprestimos_v2 / consultas_locais_v2.
-- Les ecritures passent par RPC SECURITY DEFINER (fn_create_emprestimo_v2,
-- fn_create_consulta_*) qui bypassent la RLS. Le verrou ecriture se posera
-- en C.4 (RPC). Pour PEB, les INSERT/UPDATE iront en C.3c (condition composite stricte).
--
-- Doctrines appliquees : #10 test PostgREST simule en pre-push, #18 doctrine v2.
-- Risque : eleve. Une RLS mal patchee peut couper toute lecture de la prod.
-- Mitigation : DO block fail-fast verifiant structure + non-regression BLMF.
-- Validation : test PostgREST simule (test_C3b_postgrest_simule.sql) avant push.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. emprestimos_v2_select_policy
-- ---------------------------------------------------------------------------
-- Original : (user_id = auth.uid()) OR (EXISTS staff via my_access)
-- Patche   : original AND fn_library_has_circulation(library_id)
DROP POLICY IF EXISTS emprestimos_v2_select_policy ON public.emprestimos_v2;
CREATE POLICY emprestimos_v2_select_policy
  ON public.emprestimos_v2
  FOR SELECT
  TO authenticated
  USING (
    (
      (user_id = auth.uid())
      OR (
        EXISTS (
          SELECT 1 FROM api.my_access ma
           WHERE ma.user_id = auth.uid()
             AND ma.can_access_painel = true
             AND ma.library_id = emprestimos_v2.library_id
        )
      )
    )
    AND public.fn_library_has_circulation(library_id)
  );
COMMENT ON POLICY emprestimos_v2_select_policy ON public.emprestimos_v2 IS
  'Lecteur voit ses prets, staff voit prets de la biblio. Invisible si circulation_mode=off (paquet C.3b).';

-- ---------------------------------------------------------------------------
-- 2. consultas_locais_v2_select_policy
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS consultas_locais_v2_select_policy ON public.consultas_locais_v2;
CREATE POLICY consultas_locais_v2_select_policy
  ON public.consultas_locais_v2
  FOR SELECT
  TO authenticated
  USING (
    (
      (user_id = auth.uid())
      OR (
        EXISTS (
          SELECT 1 FROM api.my_access ma
           WHERE ma.user_id = auth.uid()
             AND ma.can_access_painel = true
             AND ma.library_id = consultas_locais_v2.library_id
        )
      )
    )
    AND public.fn_library_has_circulation(library_id)
  );
COMMENT ON POLICY consultas_locais_v2_select_policy ON public.consultas_locais_v2 IS
  'Lecteur voit ses consultations, staff voit consultations biblio. Invisible si circulation_mode=off (paquet C.3b).';

-- ---------------------------------------------------------------------------
-- 3. interlibrary_loans_v2_select (PEB)
-- ---------------------------------------------------------------------------
-- Arbitrage Q1 (doctrine cloture propre) : lecture autorisee si AU MOINS UNE
-- des deux bibs garde circulation, pour permettre la finalisation des
-- transactions en cours quand une biblio bascule en off.
-- Aucune lecture si LES DEUX bibs sont en off (transaction definitivement morte).
DROP POLICY IF EXISTS interlibrary_loans_v2_select ON public.interlibrary_loans_v2;
CREATE POLICY interlibrary_loans_v2_select
  ON public.interlibrary_loans_v2
  FOR SELECT
  TO authenticated
  USING (
    (
      user_can_manage_library(lender_library_id)
      OR user_can_manage_library(borrower_library_id)
    )
    AND (
      public.fn_library_has_circulation(lender_library_id)
      OR public.fn_library_has_circulation(borrower_library_id)
    )
  );
COMMENT ON POLICY interlibrary_loans_v2_select ON public.interlibrary_loans_v2 IS
  'Staff PEB voit transactions des bibs qu''il gere. SELECT permissif (Q1 cloture) : visible si UNE des deux bibs garde circulation (paquet C.3b).';

-- ---------------------------------------------------------------------------
-- 4. DO block de verification fail-fast
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_blmf_id uuid;
  v_btl_id uuid;
  v_count int;
BEGIN
  -- a. Verifier que les 3 policies cibles existent
  SELECT count(*) INTO v_count FROM pg_policies
   WHERE schemaname = 'public'
     AND (tablename, policyname) IN (
       ('emprestimos_v2', 'emprestimos_v2_select_policy'),
       ('consultas_locais_v2', 'consultas_locais_v2_select_policy'),
       ('interlibrary_loans_v2', 'interlibrary_loans_v2_select')
     );
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : attendu 3 policies cibles, trouve %', v_count;
  END IF;

  -- a.bis : les 3 policies referencent fn_library_has_circulation
  SELECT count(*) INTO v_count FROM pg_policies
   WHERE schemaname = 'public'
     AND (tablename, policyname) IN (
       ('emprestimos_v2', 'emprestimos_v2_select_policy'),
       ('consultas_locais_v2', 'consultas_locais_v2_select_policy'),
       ('interlibrary_loans_v2', 'interlibrary_loans_v2_select')
     )
     AND COALESCE(qual,'') LIKE '%fn_library_has_circulation%';
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a_bis : seulement %/3 policies referencent fn_library_has_circulation', v_count;
  END IF;

  -- b. BLMF + BTL en profil D
  SELECT id INTO v_blmf_id FROM public.libraries
   WHERE name = 'Biblioteca Libertária Maxwell Ferreira' LIMIT 1;
  SELECT id INTO v_btl_id FROM public.libraries
   WHERE name = 'Biblioteca Terra Livre' LIMIT 1;
  IF v_blmf_id IS NULL OR v_btl_id IS NULL THEN
    RAISE EXCEPTION 'VERIF_FAIL_b : BLMF=% BTL=%', v_blmf_id, v_btl_id;
  END IF;

  -- c. Non regression : helper renvoie TRUE pour les 2 biblios en full_sigb
  IF NOT public.fn_library_has_circulation(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c1 : helper BLMF doit etre TRUE en full_sigb';
  END IF;
  IF NOT public.fn_library_has_circulation(v_btl_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c2 : helper BTL doit etre TRUE en full_sigb';
  END IF;

  -- d. Non regression structure : il existe toujours des donnees dans les 3 tables
  --    pour les baselines connues
  SELECT count(*) INTO v_count FROM public.emprestimos_v2
   WHERE library_id = v_blmf_id;
  IF v_count = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_d1 : 0 emprestimos sur BLMF (devrait y en avoir, baseline=29)';
  END IF;

  SELECT count(*) INTO v_count FROM public.consultas_locais_v2
   WHERE library_id = v_blmf_id;
  IF v_count = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_d2 : 0 consultas sur BLMF (devrait y en avoir, baseline=28)';
  END IF;

  --   Pas de baseline PEB (0 en prod) — on ne verifie pas

  RAISE NOTICE 'Paquet C.3b — Verification OK : 3 RLS SELECT (emprestimos, consultas, PEB) conditionnees par fn_library_has_circulation';
END
$verif$;

COMMIT;
