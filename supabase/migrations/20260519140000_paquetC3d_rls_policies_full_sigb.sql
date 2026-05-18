-- ============================================================================
-- Paquet C.3d — Patches RLS library_circulation_policy_sets/rules (10 RLS)
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.3
-- Audit prealable : paquetC1_audit_rls.md §6
-- Dependance : paquetC2_helpers_modes_profils.sql (helper fn_library_has_full_sigb)
--
-- Objectif : conditionner les 10 RLS sur les politiques de circulation
-- par fn_library_has_full_sigb(library_id). Les politiques de pret n'ont
-- de sens qu'en mode full_sigb (informal = pas de durees formelles, off = pas
-- de circulation).
--
-- Arbitrage Q3 (redondance defensive, session 19/05/2026) :
--   - 5 RLS sur policy_sets : patche direct sur library_id
--   - 5 RLS sur policy_rules : patche redondant via EXISTS sur policy_sets
--     (l'heritage seul suffirait techniquement, mais redondance = defense en profondeur)
--
-- 10 RLS patchees :
--   Sets : public_read, select, insert, update, delete (5)
--   Rules : public_read, select, insert, update, delete (5)
--
-- Doctrine appliquee : #10 (test PostgREST) + structure DO block fail-fast.
-- Risque : moyen. 10 RLS = surface large mais semantique simple.
-- Validation : test PostgREST simule + non-regression BLMF (1 set + 6 rules).
-- ============================================================================

BEGIN;

-- ===========================================================================
-- A. library_circulation_policy_sets (5 RLS)
-- ===========================================================================

-- A.1 SELECT public_read
DROP POLICY IF EXISTS library_circulation_policy_sets_public_read
  ON public.library_circulation_policy_sets;
CREATE POLICY library_circulation_policy_sets_public_read
  ON public.library_circulation_policy_sets
  FOR SELECT
  TO anon, authenticated
  USING (
    is_active = true
    AND public.fn_library_has_full_sigb(library_id)
  );
COMMENT ON POLICY library_circulation_policy_sets_public_read
  ON public.library_circulation_policy_sets IS
  'Lecture publique OPAC des politiques de pret. Visible uniquement en full_sigb (paquet C.3d).';

-- A.2 SELECT staff
DROP POLICY IF EXISTS library_circulation_policy_sets_select
  ON public.library_circulation_policy_sets;
CREATE POLICY library_circulation_policy_sets_select
  ON public.library_circulation_policy_sets
  FOR SELECT
  TO authenticated
  USING (
    can_manage_library_circulation_policies(library_id)
    AND public.fn_library_has_full_sigb(library_id)
  );
COMMENT ON POLICY library_circulation_policy_sets_select
  ON public.library_circulation_policy_sets IS
  'Lecture staff des politiques. Bloque hors full_sigb (paquet C.3d).';

-- A.3 INSERT
DROP POLICY IF EXISTS library_circulation_policy_sets_insert
  ON public.library_circulation_policy_sets;
CREATE POLICY library_circulation_policy_sets_insert
  ON public.library_circulation_policy_sets
  FOR INSERT
  TO authenticated
  WITH CHECK (
    can_manage_library_circulation_policies(library_id)
    AND public.fn_library_has_full_sigb(library_id)
  );
COMMENT ON POLICY library_circulation_policy_sets_insert
  ON public.library_circulation_policy_sets IS
  'Creation politique de pret. Bloque hors full_sigb (paquet C.3d).';

-- A.4 UPDATE
DROP POLICY IF EXISTS library_circulation_policy_sets_update
  ON public.library_circulation_policy_sets;
CREATE POLICY library_circulation_policy_sets_update
  ON public.library_circulation_policy_sets
  FOR UPDATE
  TO authenticated
  USING (
    can_manage_library_circulation_policies(library_id)
    AND public.fn_library_has_full_sigb(library_id)
  )
  WITH CHECK (
    can_manage_library_circulation_policies(library_id)
    AND public.fn_library_has_full_sigb(library_id)
  );
COMMENT ON POLICY library_circulation_policy_sets_update
  ON public.library_circulation_policy_sets IS
  'Modification politique. Bloque hors full_sigb (paquet C.3d).';

-- A.5 DELETE
DROP POLICY IF EXISTS library_circulation_policy_sets_delete
  ON public.library_circulation_policy_sets;
CREATE POLICY library_circulation_policy_sets_delete
  ON public.library_circulation_policy_sets
  FOR DELETE
  TO authenticated
  USING (
    can_manage_library_circulation_policies(library_id)
    AND public.fn_library_has_full_sigb(library_id)
  );
COMMENT ON POLICY library_circulation_policy_sets_delete
  ON public.library_circulation_policy_sets IS
  'Suppression politique. Bloque hors full_sigb (paquet C.3d).';

-- ===========================================================================
-- B. library_circulation_policy_rules (5 RLS — redondance defensive Q3)
-- ===========================================================================
-- Pattern : EXISTS sur policy_sets pour acceder a library_id, AVEC ajout
-- redondant de fn_library_has_full_sigb dans le EXISTS. Si la RLS parente
-- bloque deja (helper FALSE), le filtre rules redondant ne change rien
-- en mode normal mais fournit defense en profondeur.

-- B.1 SELECT public_read
DROP POLICY IF EXISTS library_circulation_policy_rules_public_read
  ON public.library_circulation_policy_rules;
CREATE POLICY library_circulation_policy_rules_public_read
  ON public.library_circulation_policy_rules
  FOR SELECT
  TO anon, authenticated
  USING (
    is_active = true
    AND EXISTS (
      SELECT 1 FROM public.library_circulation_policy_sets s
       WHERE s.id = library_circulation_policy_rules.policy_set_id
         AND s.is_active = true
         AND public.fn_library_has_full_sigb(s.library_id)
    )
  );
COMMENT ON POLICY library_circulation_policy_rules_public_read
  ON public.library_circulation_policy_rules IS
  'Lecture publique regles de pret. Visible uniquement en full_sigb (paquet C.3d).';

-- B.2 SELECT staff
DROP POLICY IF EXISTS library_circulation_policy_rules_select
  ON public.library_circulation_policy_rules;
CREATE POLICY library_circulation_policy_rules_select
  ON public.library_circulation_policy_rules
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.library_circulation_policy_sets s
       WHERE s.id = library_circulation_policy_rules.policy_set_id
         AND can_manage_library_circulation_policies(s.library_id)
         AND public.fn_library_has_full_sigb(s.library_id)
    )
  );
COMMENT ON POLICY library_circulation_policy_rules_select
  ON public.library_circulation_policy_rules IS
  'Lecture staff regles. Bloque hors full_sigb (paquet C.3d).';

-- B.3 INSERT
DROP POLICY IF EXISTS library_circulation_policy_rules_insert
  ON public.library_circulation_policy_rules;
CREATE POLICY library_circulation_policy_rules_insert
  ON public.library_circulation_policy_rules
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.library_circulation_policy_sets s
       WHERE s.id = library_circulation_policy_rules.policy_set_id
         AND can_manage_library_circulation_policies(s.library_id)
         AND public.fn_library_has_full_sigb(s.library_id)
    )
  );
COMMENT ON POLICY library_circulation_policy_rules_insert
  ON public.library_circulation_policy_rules IS
  'Creation regle de pret. Bloque hors full_sigb (paquet C.3d).';

-- B.4 UPDATE
DROP POLICY IF EXISTS library_circulation_policy_rules_update
  ON public.library_circulation_policy_rules;
CREATE POLICY library_circulation_policy_rules_update
  ON public.library_circulation_policy_rules
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.library_circulation_policy_sets s
       WHERE s.id = library_circulation_policy_rules.policy_set_id
         AND can_manage_library_circulation_policies(s.library_id)
         AND public.fn_library_has_full_sigb(s.library_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.library_circulation_policy_sets s
       WHERE s.id = library_circulation_policy_rules.policy_set_id
         AND can_manage_library_circulation_policies(s.library_id)
         AND public.fn_library_has_full_sigb(s.library_id)
    )
  );
COMMENT ON POLICY library_circulation_policy_rules_update
  ON public.library_circulation_policy_rules IS
  'Modification regle. Bloque hors full_sigb (paquet C.3d).';

-- B.5 DELETE
DROP POLICY IF EXISTS library_circulation_policy_rules_delete
  ON public.library_circulation_policy_rules;
CREATE POLICY library_circulation_policy_rules_delete
  ON public.library_circulation_policy_rules
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.library_circulation_policy_sets s
       WHERE s.id = library_circulation_policy_rules.policy_set_id
         AND can_manage_library_circulation_policies(s.library_id)
         AND public.fn_library_has_full_sigb(s.library_id)
    )
  );
COMMENT ON POLICY library_circulation_policy_rules_delete
  ON public.library_circulation_policy_rules IS
  'Suppression regle. Bloque hors full_sigb (paquet C.3d).';

-- ===========================================================================
-- C. DO block de verification fail-fast
-- ===========================================================================
DO $verif$
DECLARE
  v_blmf_id uuid;
  v_count int;
BEGIN
  -- a. Toutes les 10 policies cibles existent
  SELECT count(*) INTO v_count FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename IN ('library_circulation_policy_sets','library_circulation_policy_rules')
     AND policyname IN (
       'library_circulation_policy_sets_public_read',
       'library_circulation_policy_sets_select',
       'library_circulation_policy_sets_insert',
       'library_circulation_policy_sets_update',
       'library_circulation_policy_sets_delete',
       'library_circulation_policy_rules_public_read',
       'library_circulation_policy_rules_select',
       'library_circulation_policy_rules_insert',
       'library_circulation_policy_rules_update',
       'library_circulation_policy_rules_delete'
     );
  IF v_count <> 10 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : attendu 10 policies, trouve %', v_count;
  END IF;

  -- a.bis : toutes referencent fn_library_has_full_sigb
  SELECT count(*) INTO v_count FROM pg_policies
   WHERE schemaname = 'public'
     AND tablename IN ('library_circulation_policy_sets','library_circulation_policy_rules')
     AND policyname IN (
       'library_circulation_policy_sets_public_read',
       'library_circulation_policy_sets_select',
       'library_circulation_policy_sets_insert',
       'library_circulation_policy_sets_update',
       'library_circulation_policy_sets_delete',
       'library_circulation_policy_rules_public_read',
       'library_circulation_policy_rules_select',
       'library_circulation_policy_rules_insert',
       'library_circulation_policy_rules_update',
       'library_circulation_policy_rules_delete'
     )
     AND (COALESCE(qual,'') || ' ' || COALESCE(with_check,'')) LIKE '%fn_library_has_full_sigb%';
  IF v_count <> 10 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a_bis : %/10 referencent fn_library_has_full_sigb', v_count;
  END IF;

  -- b. BLMF
  SELECT id INTO v_blmf_id FROM public.libraries
   WHERE name = 'Biblioteca Libertária Maxwell Ferreira' LIMIT 1;
  IF v_blmf_id IS NULL THEN RAISE EXCEPTION 'VERIF_FAIL_b : BLMF introuvable'; END IF;

  -- c. BLMF en full_sigb -> helper TRUE
  IF NOT public.fn_library_has_full_sigb(v_blmf_id) THEN
    RAISE EXCEPTION 'VERIF_FAIL_c : BLMF helper FALSE alors qu''elle est en full_sigb';
  END IF;

  -- d. Non regression : 1 policy_set + 6 policy_rules existent toujours pour BLMF
  SELECT count(*) INTO v_count FROM public.library_circulation_policy_sets s
   WHERE s.library_id = v_blmf_id;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_d1 : attendu 1 policy_set BLMF, trouve %', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM public.library_circulation_policy_rules r
    JOIN public.library_circulation_policy_sets s ON s.id = r.policy_set_id
   WHERE s.library_id = v_blmf_id;
  IF v_count <> 6 THEN
    RAISE EXCEPTION 'VERIF_FAIL_d2 : attendu 6 policy_rules BLMF, trouve %', v_count;
  END IF;

  RAISE NOTICE 'Paquet C.3d — Verification OK : 10 RLS policies conditionnees par fn_library_has_full_sigb';
END
$verif$;

COMMIT;
