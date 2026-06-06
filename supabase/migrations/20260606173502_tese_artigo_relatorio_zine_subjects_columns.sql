-- =========================================================================
-- Colonnes tese / artigo / relatorio / zine / subjects + propagation publish
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC reel)
-- Chantier : catalogacao — champs par type (spec §5.4, chips spawnees)
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- Le formulaire de catalogacao affiche deja les champs tese/artigo/relatorio/
-- zine/subjects (EMPTY_FORM + fieldRegistry) mais les colonnes correspondantes
-- n'existent dans aucune table : handleSave ecrit dans book_drafts -> Supabase
-- ignore les clefs inconnues -> les champs sont perdus a la sauvegarde.
--
-- Ce script :
--   1. Ajoute 14 colonnes a book_drafts ET books (13 type-specifiques + subjects).
--   2. Etend fn_propagate_circulation_default_on_publish pour propager
--      les 14 nouvelles colonnes (+ distribuidora, deja present) du brouillon
--      vers le livre publie. Meme trigger (AFTER UPDATE OF status), meme
--      signature — seul le corps change.
--
-- NOTE : publish_book_draft n'est PAS touche. La propagation passe par le
-- trigger, qui s'execute juste apres le SET status='published'. C'est le
-- pattern pose par la migration distribuidora (20260606130227).
-- =========================================================================

BEGIN;

-- ─── 1. Ajout colonnes ──────────────────────────────────────────────────

-- Tese
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS tese_university text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS tese_advisor text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS tese_university text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS tese_advisor text;

-- Artigo
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS artigo_source text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS artigo_volume text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS artigo_issue text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS artigo_pages text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS artigo_source text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS artigo_volume text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS artigo_issue text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS artigo_pages text;

-- Relatorio
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS relatorio_org text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS relatorio_recipient text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS relatorio_internal_notes text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS relatorio_org text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS relatorio_recipient text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS relatorio_internal_notes text;

-- Zine
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS zine_print_run text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS zine_technique text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS zine_format text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS zine_print_run text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS zine_technique text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS zine_format text;

-- Subjects (assuntos / mots-cles, transversal)
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS subjects text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS subjects text;

-- ─── 2. Trigger de propagation etendu ───────────────────────────────────
-- Origine : fn_propagate_circulation_default_on_publish (migration
-- 20260606130227 distribuidora). On ajoute les 14 nouvelles colonnes.
-- Le trigger existant (AFTER UPDATE OF status ON book_drafts, WHEN
-- NEW.status='published') reste inchange — seul le corps de la fonction
-- est remplace.

CREATE OR REPLACE FUNCTION public.fn_propagate_circulation_default_on_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.published_book_id IS NOT NULL THEN
    UPDATE public.books
    SET circulation_default = NEW.circulation_default,
        loanable = (NEW.circulation_default IS DISTINCT FROM 'consulta'),
        distribuidora = NEW.distribuidora,
        -- Tese
        tese_university = NEW.tese_university,
        tese_advisor = NEW.tese_advisor,
        -- Artigo
        artigo_source = NEW.artigo_source,
        artigo_volume = NEW.artigo_volume,
        artigo_issue = NEW.artigo_issue,
        artigo_pages = NEW.artigo_pages,
        -- Relatorio
        relatorio_org = NEW.relatorio_org,
        relatorio_recipient = NEW.relatorio_recipient,
        relatorio_internal_notes = NEW.relatorio_internal_notes,
        -- Zine
        zine_print_run = NEW.zine_print_run,
        zine_technique = NEW.zine_technique,
        zine_format = NEW.zine_format,
        -- Subjects
        subjects = NEW.subjects
    WHERE id = NEW.published_book_id;
  END IF;
  RETURN NULL;
END;
$function$;

-- ─── 3. Verification ───────────────────────────────────────────────────

DO $verif$
DECLARE
  v_cols text[] := ARRAY[
    'tese_university','tese_advisor',
    'artigo_source','artigo_volume','artigo_issue','artigo_pages',
    'relatorio_org','relatorio_recipient','relatorio_internal_notes',
    'zine_print_run','zine_technique','zine_format',
    'subjects'
  ];
  v_col text;
BEGIN
  FOREACH v_col IN ARRAY v_cols LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='book_drafts' AND column_name=v_col) THEN
      RAISE EXCEPTION 'VERIF_FAIL: book_drafts.% absent', v_col;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='books' AND column_name=v_col) THEN
      RAISE EXCEPTION 'VERIF_FAIL: books.% absent', v_col;
    END IF;
  END LOOP;

  -- Verifie que le trigger propage les nouvelles colonnes
  IF position('tese_university' IN pg_get_functiondef(
      'public.fn_propagate_circulation_default_on_publish()'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL: trigger ne propage pas tese_university';
  END IF;
  IF position('subjects' IN pg_get_functiondef(
      'public.fn_propagate_circulation_default_on_publish()'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL: trigger ne propage pas subjects';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS tese_university;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS tese_advisor;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS artigo_source;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS artigo_volume;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS artigo_issue;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS artigo_pages;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS relatorio_org;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS relatorio_recipient;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS relatorio_internal_notes;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS zine_print_run;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS zine_technique;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS zine_format;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS subjects;
--   ALTER TABLE public.books DROP COLUMN IF EXISTS tese_university;
--   ...idem books...
--   (restaurer fn_propagate_circulation_default_on_publish sans ces colonnes)
-- =========================================================================
