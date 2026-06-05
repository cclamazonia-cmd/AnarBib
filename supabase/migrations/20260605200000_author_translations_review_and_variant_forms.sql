-- =========================================================================
-- Paquet Ateliers/Track D — revue des bios multilingues + variant_forms
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites multilingues (spec-autorites-notes-bio-multilingues v0.2)
-- Auteur   : Xavier + Claude
--
-- OBJET (migration mutualisee, decision Q5)
-- -----------------------------------------
-- 1. author_translations : workflow de revue (status draft/reviewed +
--    reviewed_by/reviewed_at) et CHECK de parite sur `lang` (10 locales).
-- 2. authors / author_drafts : ancre Track D `variant_forms` (jsonb) pour les
--    formes variantes de nom (controle d'autorite multilingue).
--
-- DOCTRINE
-- --------
-- ADD COLUMN / ADD CONSTRAINT sur tables existantes deja sous RLS. Pas de
-- fonction SECURITY DEFINER, pas de nouvelle table, pas de vue. L'ecriture du
-- statut de revue passe par la policy RLS existante author_translations_librarian_write
-- (cmd ALL, gated librarian/coordenador) : pas de nouvelle policy en v1.
-- Donnees existantes (48 pt-BR + 6 fr) : compatibles avec le CHECK ; status
-- defaut 'reviewed' (saisies staff considerees validees).
-- =========================================================================

BEGIN;

-- 1a. Colonnes de revue sur author_translations
ALTER TABLE public.author_translations
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'reviewed'
    CHECK (status IN ('draft','reviewed')),
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;

-- 1b. CHECK de parite sur lang (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.author_translations'::regclass
      AND conname = 'author_translations_lang_check'
  ) THEN
    ALTER TABLE public.author_translations
      ADD CONSTRAINT author_translations_lang_check
      CHECK (lang IN ('pt-BR','fr','es','en','it','de','ca','eo','nl','el'));
  END IF;
END $$;

-- 2. Ancre Track D : formes variantes de nom (autorite multilingue)
ALTER TABLE public.authors
  ADD COLUMN IF NOT EXISTS variant_forms jsonb;
ALTER TABLE public.author_drafts
  ADD COLUMN IF NOT EXISTS variant_forms jsonb;

COMMENT ON COLUMN public.author_translations.status IS
  'Workflow Ateliers : draft (contribution en cours) / reviewed (validee). Paquet du 05/06/2026.';
COMMENT ON COLUMN public.authors.variant_forms IS
  'Formes variantes de nom (controle d''autorite multilingue, Track D). Paquet du 05/06/2026.';
COMMENT ON COLUMN public.author_drafts.variant_forms IS
  'Formes variantes de nom (controle d''autorite multilingue, Track D). Paquet du 05/06/2026.';

-- Verification
DO $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT
    EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema='public' AND table_name='author_translations' AND column_name='status')
    AND EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema='public' AND table_name='authors' AND column_name='variant_forms')
    AND EXISTS (SELECT 1 FROM pg_constraint
              WHERE conrelid='public.author_translations'::regclass AND conname='author_translations_lang_check')
  INTO v_ok;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'Migration incomplete (colonnes/contrainte manquantes). Rollback.';
  END IF;
  RAISE NOTICE 'author_translations revue + variant_forms : OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback cible (si regression) :
-- =========================================================================
-- BEGIN;
--   ALTER TABLE public.author_translations
--     DROP CONSTRAINT IF EXISTS author_translations_lang_check,
--     DROP COLUMN IF EXISTS status,
--     DROP COLUMN IF EXISTS reviewed_by,
--     DROP COLUMN IF EXISTS reviewed_at;
--   ALTER TABLE public.authors       DROP COLUMN IF EXISTS variant_forms;
--   ALTER TABLE public.author_drafts DROP COLUMN IF EXISTS variant_forms;
-- COMMIT;
-- =========================================================================
