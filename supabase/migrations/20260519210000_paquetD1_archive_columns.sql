-- ============================================================================
-- Paquet D.1 - Infrastructure archivage : colonnes + CHECK + indexes
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.4 (paquet D)
--
-- Objectif : ajouter le couple (archived_at, archive_reason) sur les 5 tables
-- transactionnelles "vivantes" pour supporter la mise a l'ecart des transactions
-- lors des transitions de profil type 4 (passage en circulation_mode='off').
--
-- 5 tables impactees :
--   - emprestimos_v2
--   - reservas_v2
--   - consultas_locais_v2
--   - interlibrary_loans_v2
--   - membership_payments
--
-- Pour chaque table :
--   - colonne archived_at timestamptz NULL
--   - colonne archive_reason text NULL avec CHECK enum
--   - contrainte (archived_at IS NULL) = (archive_reason IS NULL)
--   - index partiel WHERE archived_at IS NULL pour preserver les perfs
--     des requetes courantes sur les transactions vivantes
--
-- Donnees prod au moment du paquet : aucune transaction vivante (29 emp + 14 res
-- + 28 con tous encerrados, 0 ILL). Le paquet est donc sans risque sur les
-- donnees existantes : archived_at sera NULL partout au start.
--
-- Doctrine : ce paquet est mecanique et faible risque. Pas d'effet metier
-- avant le paquet D.2 qui livre les helpers d'archivage.
-- ============================================================================

BEGIN;

-- ============================================================================
-- A. emprestimos_v2
-- ============================================================================
ALTER TABLE public.emprestimos_v2
  ADD COLUMN archived_at timestamptz NULL,
  ADD COLUMN archive_reason text NULL;

ALTER TABLE public.emprestimos_v2
  ADD CONSTRAINT emprestimos_v2_archive_reason_chk
  CHECK (archive_reason IS NULL OR archive_reason IN ('profile_transition', 'admin_manual', 'system_cleanup'));

ALTER TABLE public.emprestimos_v2
  ADD CONSTRAINT emprestimos_v2_archive_consistency_chk
  CHECK ((archived_at IS NULL) = (archive_reason IS NULL));

CREATE INDEX emprestimos_v2_active_idx
  ON public.emprestimos_v2 (library_id, status_global)
  WHERE archived_at IS NULL;

CREATE INDEX emprestimos_v2_archived_idx
  ON public.emprestimos_v2 (library_id, archived_at, archive_reason)
  WHERE archived_at IS NOT NULL;

-- ============================================================================
-- B. reservas_v2
-- ============================================================================
ALTER TABLE public.reservas_v2
  ADD COLUMN archived_at timestamptz NULL,
  ADD COLUMN archive_reason text NULL;

ALTER TABLE public.reservas_v2
  ADD CONSTRAINT reservas_v2_archive_reason_chk
  CHECK (archive_reason IS NULL OR archive_reason IN ('profile_transition', 'admin_manual', 'system_cleanup'));

ALTER TABLE public.reservas_v2
  ADD CONSTRAINT reservas_v2_archive_consistency_chk
  CHECK ((archived_at IS NULL) = (archive_reason IS NULL));

CREATE INDEX reservas_v2_active_idx
  ON public.reservas_v2 (library_id, status_global)
  WHERE archived_at IS NULL;

CREATE INDEX reservas_v2_archived_idx
  ON public.reservas_v2 (library_id, archived_at, archive_reason)
  WHERE archived_at IS NOT NULL;

-- ============================================================================
-- C. consultas_locais_v2
-- ============================================================================
ALTER TABLE public.consultas_locais_v2
  ADD COLUMN archived_at timestamptz NULL,
  ADD COLUMN archive_reason text NULL;

ALTER TABLE public.consultas_locais_v2
  ADD CONSTRAINT consultas_locais_v2_archive_reason_chk
  CHECK (archive_reason IS NULL OR archive_reason IN ('profile_transition', 'admin_manual', 'system_cleanup'));

ALTER TABLE public.consultas_locais_v2
  ADD CONSTRAINT consultas_locais_v2_archive_consistency_chk
  CHECK ((archived_at IS NULL) = (archive_reason IS NULL));

CREATE INDEX consultas_locais_v2_active_idx
  ON public.consultas_locais_v2 (library_id, status_global)
  WHERE archived_at IS NULL;

CREATE INDEX consultas_locais_v2_archived_idx
  ON public.consultas_locais_v2 (library_id, archived_at, archive_reason)
  WHERE archived_at IS NOT NULL;

-- ============================================================================
-- D. interlibrary_loans_v2
-- ============================================================================
-- Particularite : pas de colonne library_id directe, on a lender_library_id
-- et borrower_library_id. L'index actif inclut les deux pour permettre des
-- recherches par l'une ou l'autre biblio.
ALTER TABLE public.interlibrary_loans_v2
  ADD COLUMN archived_at timestamptz NULL,
  ADD COLUMN archive_reason text NULL;

ALTER TABLE public.interlibrary_loans_v2
  ADD CONSTRAINT interlibrary_loans_v2_archive_reason_chk
  CHECK (archive_reason IS NULL OR archive_reason IN ('profile_transition', 'admin_manual', 'system_cleanup'));

ALTER TABLE public.interlibrary_loans_v2
  ADD CONSTRAINT interlibrary_loans_v2_archive_consistency_chk
  CHECK ((archived_at IS NULL) = (archive_reason IS NULL));

CREATE INDEX interlibrary_loans_v2_lender_active_idx
  ON public.interlibrary_loans_v2 (lender_library_id, status_global)
  WHERE archived_at IS NULL;

CREATE INDEX interlibrary_loans_v2_borrower_active_idx
  ON public.interlibrary_loans_v2 (borrower_library_id, status_global)
  WHERE archived_at IS NULL;

CREATE INDEX interlibrary_loans_v2_archived_idx
  ON public.interlibrary_loans_v2 (archived_at, archive_reason)
  WHERE archived_at IS NOT NULL;

-- ============================================================================
-- E. membership_payments (cotisations)
-- ============================================================================
-- Note doctrinale : on archive uniquement les cotisations EN COURS lors d'une
-- transition full_sigb -> informal (paquet D.2). Les cotisations historiques
-- (valid_until depasse) ne sont pas masquees - elles relevent de la couche
-- masquage (D.4) qui fournit api.library_cotisation_history pour la tracabilite
-- comptable. Le paquet B (transitions) declenche l'archivage via fn_archive_library_cotisations.
ALTER TABLE public.membership_payments
  ADD COLUMN archived_at timestamptz NULL,
  ADD COLUMN archive_reason text NULL;

ALTER TABLE public.membership_payments
  ADD CONSTRAINT membership_payments_archive_reason_chk
  CHECK (archive_reason IS NULL OR archive_reason IN ('profile_transition', 'admin_manual', 'system_cleanup'));

ALTER TABLE public.membership_payments
  ADD CONSTRAINT membership_payments_archive_consistency_chk
  CHECK ((archived_at IS NULL) = (archive_reason IS NULL));

CREATE INDEX membership_payments_active_idx
  ON public.membership_payments (library_id, valid_until)
  WHERE archived_at IS NULL;

CREATE INDEX membership_payments_archived_idx
  ON public.membership_payments (library_id, archived_at, archive_reason)
  WHERE archived_at IS NOT NULL;

-- ============================================================================
-- DO block verification fail-fast
-- ============================================================================
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- 5 tables x 2 colonnes ajoutees = 10 colonnes archive_*
  SELECT count(*) INTO v_count
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND column_name IN ('archived_at', 'archive_reason')
     AND table_name IN ('emprestimos_v2','reservas_v2','consultas_locais_v2','interlibrary_loans_v2','membership_payments');
  IF v_count <> 10 THEN
    RAISE EXCEPTION 'VERIF_FAIL_A : %/10 colonnes archive_* ajoutees', v_count;
  END IF;

  -- 5 tables x 2 contraintes = 10 contraintes archive_*
  SELECT count(*) INTO v_count
    FROM pg_constraint
   WHERE conname LIKE '%_archive_reason_chk'
      OR conname LIKE '%_archive_consistency_chk';
  IF v_count < 10 THEN
    RAISE EXCEPTION 'VERIF_FAIL_B : %/10+ contraintes archive ajoutees', v_count;
  END IF;

  -- Indexes partiels : 2 par table (sauf ill qui en a 3) + 1 archived par table = 2*4 + 3 + 2 = 13
  -- En realite : emp=2, res=2, con=2, ill=3, mp=2 = 11 indexes partiels archive
  SELECT count(*) INTO v_count
    FROM pg_indexes
   WHERE schemaname = 'public'
     AND (indexname LIKE '%_active_idx' OR indexname LIKE '%_archived_idx')
     AND (tablename IN ('emprestimos_v2','reservas_v2','consultas_locais_v2','interlibrary_loans_v2','membership_payments'));
  IF v_count < 11 THEN
    RAISE EXCEPTION 'VERIF_FAIL_C : %/11+ indexes partiels archive crees', v_count;
  END IF;

  -- Sanity check : aucune ligne en prod ne doit avoir archived_at apres ce paquet
  SELECT (
    (SELECT count(*) FROM emprestimos_v2 WHERE archived_at IS NOT NULL)
  + (SELECT count(*) FROM reservas_v2 WHERE archived_at IS NOT NULL)
  + (SELECT count(*) FROM consultas_locais_v2 WHERE archived_at IS NOT NULL)
  + (SELECT count(*) FROM interlibrary_loans_v2 WHERE archived_at IS NOT NULL)
  + (SELECT count(*) FROM membership_payments WHERE archived_at IS NOT NULL)
  ) INTO v_count;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_D : % lignes ont archived_at non-NULL apres ajout colonne (devrait etre 0)', v_count;
  END IF;

  RAISE NOTICE 'Paquet D.1 - Verification OK : 10 colonnes + 10 contraintes + 11 indexes + 0 ligne archivee';
END
$verif$;

COMMIT;
