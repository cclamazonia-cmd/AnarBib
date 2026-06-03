-- =====================================================================
-- Phase 1 Catalogação — vague mutualisée exemplares + exemplar_drafts
-- PROVENANCE (spec-acquisition-provenance §5.1, ACQ-Q1)
--   + DESTINATION (spec-exemplaires-circulation §4.1, CAT-B1..B3)
-- Une seule transaction sur les deux tables (CAT-B6 / Q9 — jamais deux vagues).
-- Pré-requis SATISFAIT : #MODEL-item-grain cœur livré en prod (CAT-B7).
--
-- DÉPLOIEMENT (DOC-DEPLOY-1) : renommer ce fichier en
--   <UTC>_exemplares_provenance_destination.sql  (timestamp UTC à vérifier),
--   le déposer dans supabase/migrations/, puis  git push  → Woodpecker.
--   Jamais apply_migration MCP, jamais SQL Editor, npm run build avant push.
--
-- DÉFAUTS DE DESIGN APPLIQUÉS (réversibles avant push — cf. §6 du dossier) :
--   [D1] circulation_policy NOT NULL sur exemplares (backfillé) ;
--        nullable sur exemplar_drafts (décidé à l'édition/publish).
--   [D2] validation acquisition_mode par trigger (DEFINER + search_path figé, DOC-OBJ-2).
--   [D3] colonne source_library conservée (origine don/troca ; ≠ library_id).
-- =====================================================================

BEGIN;

-- 1) Couche PROVENANCE (acquisition §5.1) -----------------------------
ALTER TABLE public.exemplares
  ADD COLUMN acquisition_mode text,     -- code logique -> catalog_ref_acquisition_modes.code
  ADD COLUMN acquisition_date date,
  ADD COLUMN provenance_note  text,
  ADD COLUMN source_library   text;     -- [D3] origine (don/troca) ; != library_id (detenteur)

ALTER TABLE public.exemplar_drafts
  ADD COLUMN acquisition_mode text,
  ADD COLUMN acquisition_date date,
  ADD COLUMN provenance_note  text,
  ADD COLUMN source_library   text;

-- 2) Couche DESTINATION (exemplaires §4.1 ; B1 = text + CHECK, pas enum) ---
ALTER TABLE public.exemplares
  ADD COLUMN circulation_policy text,                       -- emprestavel|consulta|ambos (seed padrao)
  ADD COLUMN visibility text NOT NULL DEFAULT 'public';     -- public|staff_only (= arquivo)

ALTER TABLE public.exemplares
  ADD CONSTRAINT exemplares_circulation_policy_chk
    CHECK (circulation_policy IS NULL
           OR circulation_policy = ANY (ARRAY['emprestavel','consulta','ambos'])),
  ADD CONSTRAINT exemplares_visibility_chk
    CHECK (visibility = ANY (ARRAY['public','staff_only']));

ALTER TABLE public.exemplar_drafts
  ADD COLUMN circulation_policy text,
  ADD COLUMN visibility text NOT NULL DEFAULT 'public';

ALTER TABLE public.exemplar_drafts
  ADD CONSTRAINT exemplar_drafts_circulation_policy_chk
    CHECK (circulation_policy IS NULL
           OR circulation_policy = ANY (ARRAY['emprestavel','consulta','ambos'])),
  ADD CONSTRAINT exemplar_drafts_visibility_chk
    CHECK (visibility = ANY (ARRAY['public','staff_only']));

-- 3) BACKFILL exemplares (§4.2 ; ~2461 lignes) ------------------------
--    visibility couvert par DEFAULT 'public' ;
--    circulation_policy derive de books.loanable via le holding.
UPDATE public.exemplares e
SET circulation_policy = CASE WHEN b.loanable THEN 'emprestavel' ELSE 'consulta' END
FROM public.book_holdings h
JOIN public.books b ON b.id = h.book_id
WHERE e.holding_id = h.id
  AND e.circulation_policy IS NULL;

-- exemplaires sans holding (holding_id NULL) -> defaut prudent
UPDATE public.exemplares
SET circulation_policy = 'consulta'
WHERE circulation_policy IS NULL;

-- [D1] NOT NULL sur exemplares.circulation_policy APRES backfill
ALTER TABLE public.exemplares
  ALTER COLUMN circulation_policy SET NOT NULL;

-- 4) [D2] Validation acquisition_mode in referentiel (DOC-OBJ-2) ------
CREATE OR REPLACE FUNCTION public.fn_validate_acquisition_mode()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $fn$
BEGIN
  IF NEW.acquisition_mode IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.catalog_ref_acquisition_modes
       WHERE code = NEW.acquisition_mode AND is_active
     ) THEN
    RAISE EXCEPTION 'acquisition_mode % inconnu ou inactif', NEW.acquisition_mode
      USING errcode = 'P0001';
  END IF;
  RETURN NEW;
END;
$fn$;

-- REVOKE EXECUTE (fonction trigger, jamais appelée directement) — forme attendue
-- par le hook pre-commit (Test 2) ; sur UNE ligne (le regex ne traverse pas les \n).
REVOKE EXECUTE ON FUNCTION public.fn_validate_acquisition_mode() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_validate_acquisition_mode_exemplares
  BEFORE INSERT OR UPDATE OF acquisition_mode ON public.exemplares
  FOR EACH ROW EXECUTE FUNCTION public.fn_validate_acquisition_mode();

CREATE TRIGGER trg_validate_acquisition_mode_exemplar_drafts
  BEFORE INSERT OR UPDATE OF acquisition_mode ON public.exemplar_drafts
  FOR EACH ROW EXECUTE FUNCTION public.fn_validate_acquisition_mode();

-- 5) DO-block de verification (DOC-OBJ-2 ; information_schema ; RAISE = rollback)
DO $do$
DECLARE
  v_missing text;
BEGIN
  SELECT string_agg(t || '.' || c, ', ') INTO v_missing
  FROM (VALUES
    ('exemplares','acquisition_mode'),('exemplares','acquisition_date'),
    ('exemplares','provenance_note'),('exemplares','source_library'),
    ('exemplares','circulation_policy'),('exemplares','visibility'),
    ('exemplar_drafts','acquisition_mode'),('exemplar_drafts','acquisition_date'),
    ('exemplar_drafts','provenance_note'),('exemplar_drafts','source_library'),
    ('exemplar_drafts','circulation_policy'),('exemplar_drafts','visibility')
  ) AS x(t,c)
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = x.t AND column_name = x.c
  );
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'colonnes absentes : %', v_missing;
  END IF;

  IF EXISTS (SELECT 1 FROM public.exemplares WHERE circulation_policy IS NULL) THEN
    RAISE EXCEPTION 'backfill circulation_policy incomplet (exemplares)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.exemplares WHERE visibility IS NULL) THEN
    RAISE EXCEPTION 'visibility NULL (exemplares)';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'exemplares_visibility_chk') THEN
    RAISE EXCEPTION 'CHECK exemplares_visibility_chk absent';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'exemplares_circulation_policy_chk') THEN
    RAISE EXCEPTION 'CHECK exemplares_circulation_policy_chk absent';
  END IF;
END
$do$;

COMMIT;
