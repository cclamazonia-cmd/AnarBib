-- ============================================================================
-- Paquet 25.11ter — Aligner le CHECK constraint project_stage sur le frontend
-- ============================================================================
-- CONTEXTE :
--   Le frontend (SolicitarBibliotecaPage.jsx) propose 4 valeurs pour le champ
--   "Situação atual da iniciativa" (project_stage) :
--     - em_funcionamento  (en fonctionnement)
--     - em_montagem       (en montage)
--     - em_planejamento   (en planification)
--     - reativacao        (réactivation)
--
--   La DB n'acceptait que 3 valeurs et toutes differentes :
--     - em_formacao
--     - em_organizacao
--     - em_funcionamento
--
--   Resultat : 3 des 4 choix proposes a l'usager echouaient au moment de la
--   soumission avec une erreur SQL CHECK constraint violation. Bug identifie
--   pendant un test en conditions reelles le 12/05/2026.
--
-- DECISION :
--   Aligner la DB sur le frontend (vocabulaire militant plus precis et nuance),
--   tout en conservant en tolerance les valeurs legacy au cas ou des donnees
--   historiques les utiliseraient (defensif).
--
-- IMPACT :
--   - Pas de changement frontend
--   - Pas de changement RPC fn_submit_library_request / via_claim
--   - Aucune donnee historique a migrer (verifier en pre-flight)
-- ============================================================================

DO $$
DECLARE
  v_legacy_count int;
BEGIN
  SELECT count(*) INTO v_legacy_count
  FROM public.library_requests
  WHERE project_stage IN ('em_formacao', 'em_organizacao');

  IF v_legacy_count > 0 THEN
    RAISE NOTICE 'Paquet 25.11ter : % lignes historiques avec valeurs legacy (em_formacao/em_organizacao) — conservees en tolerance dans le CHECK.', v_legacy_count;
  ELSE
    RAISE NOTICE 'Paquet 25.11ter : aucune donnee historique avec valeurs legacy. Le CHECK sera defini sur les 4 valeurs frontend uniquement.';
  END IF;
END
$$;

ALTER TABLE public.library_requests
  DROP CONSTRAINT IF EXISTS library_requests_project_stage_check;

ALTER TABLE public.library_requests
  ADD CONSTRAINT library_requests_project_stage_check
  CHECK (project_stage = ANY (ARRAY[
    'em_funcionamento'::text,
    'em_montagem'::text,
    'em_planejamento'::text,
    'reativacao'::text,
    'em_formacao'::text,
    'em_organizacao'::text
  ]));

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.library_requests'::regclass
      AND conname = 'library_requests_project_stage_check'
      AND pg_get_constraintdef(oid) ILIKE '%em_montagem%'
      AND pg_get_constraintdef(oid) ILIKE '%em_planejamento%'
      AND pg_get_constraintdef(oid) ILIKE '%reativacao%'
  ) THEN
    RAISE EXCEPTION 'Paquet 25.11ter : le CHECK constraint ne contient pas toutes les valeurs frontend attendues';
  END IF;

  RAISE NOTICE 'Paquet 25.11ter : CHECK constraint project_stage etendu avec succes (4 frontend + 2 legacy).';
END
$$;
