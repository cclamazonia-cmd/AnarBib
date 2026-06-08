-- ════════════════════════════════════════════════════════════════════════════
-- MULTI — Multi-appartenance lecteur — Phase 1 : modèle de données
-- Auteur  : Claude (Opus)
-- Session : MULTI P1 (modele de donnees)
-- Date    : 2026-06-08 (UTC)
-- Registre: §20 MULTI (spec-multi-appartenance-lecteur v0.3) ; #CL.10
--
-- Fondation du chantier multi-appartenance. Additif et sûr (aucun backfill, aucune
-- ligne existante invalidée). Les RPC (statut par biblio, validation staff, 5
-- conditions de circulation) et le frontend viennent aux phases suivantes.
--
-- Déjà en place (vérifié, non touché) : `is_primary` + index partiel unique
-- `ux_user_library_memberships_one_primary_active` (MULTI-A.2) ; colonnes
-- status/history_enabled/is_restricted/pending_removal_*.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1) Statuts d'appartenance : 4 → 8 (MULTI-STATUS, spec §2) ────────────────
-- Existants conservés ; ajout de suspended / left_with_pending_circulation /
-- terminated / pending_validation. Additif : aucune ligne existante (active,
-- removed…) n'est invalidée.
ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT user_library_memberships_status_check;
ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_status_check
  CHECK (status = ANY (ARRAY[
    'active', 'inactive', 'pending_removal', 'removed',          -- existants
    'suspended', 'left_with_pending_circulation', 'terminated',  -- sortie volontaire (MULTI-A.4)
    'pending_validation'                                          -- auto-inscription (MULTI-β.1, §8)
  ]::text[]));

-- ── 2) Validation physique PAR APPARTENANCE (décision 30/05, spec §11) ──────
-- La validation est attachée au membership X, pas au compte (MULTI-F.1 condition 2).
ALTER TABLE public.user_library_memberships
  ADD COLUMN IF NOT EXISTS physically_validated_at        timestamptz,
  ADD COLUMN IF NOT EXISTS physically_validated_by_user_id uuid REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS physical_validation_note        text,
  -- ── 3) Numéro lectrice LOCAL par appartenance (MULTI-E.2, spec §5) ──────────
  ADD COLUMN IF NOT EXISTS local_reader_number             text;

-- Format libre par biblio ; unique au sein d'une biblio ; NULL multiples tolérés.
CREATE UNIQUE INDEX IF NOT EXISTS ux_ulm_local_reader_number
  ON public.user_library_memberships (library_id, local_reader_number)
  WHERE local_reader_number IS NOT NULL;

-- ── 4) Journal de validation par appartenance (spec §8/§11) ─────────────────
CREATE TABLE public.membership_validation_log (
  id                   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  membership_id        uuid NOT NULL REFERENCES public.user_library_memberships(id) ON DELETE CASCADE,
  user_id              uuid NOT NULL,   -- dénormalisé (lecteur·rice concerné·e)
  library_id           uuid NOT NULL,   -- dénormalisé (biblio)
  action               text NOT NULL CHECK (action IN ('validated', 'revalidated', 'invalidated')),
  performed_by_user_id uuid,            -- staff ayant validé
  local_reader_number  text,            -- numéro attribué à la validation
  note                 text,
  created_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_mvl_membership ON public.membership_validation_log(membership_id);
CREATE INDEX ix_mvl_library    ON public.membership_validation_log(library_id);

ALTER TABLE public.membership_validation_log ENABLE ROW LEVEL SECURITY;

-- Lecture : le·la membre concerné·e, OU le staff actif (librarian/coordenador)
-- de la bibliothèque. Écritures réservées à la RPC de validation staff (P4,
-- SECURITY DEFINER) — aucun grant d'écriture direct.
CREATE POLICY membership_validation_log_select ON public.membership_validation_log
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.library_id = membership_validation_log.library_id
        AND m.user_id = auth.uid()
        AND m.role IN ('librarian', 'coordenador')
        AND m.status = 'active'
    )
  );

REVOKE ALL ON public.membership_validation_log FROM anon, authenticated;
GRANT SELECT ON public.membership_validation_log TO authenticated;
