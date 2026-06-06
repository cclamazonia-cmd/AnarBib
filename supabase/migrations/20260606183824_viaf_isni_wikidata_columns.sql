-- =========================================================================
-- Colonnes identifiants d'autorite : viaf, isni, wikidata
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC reel)
-- Chantier : catalogacao — spec §5.2, decision D6
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- La spec §5.2 prevoit 3 identifiants d'autorite en tier 3 (Completo) :
--   - VIAF (Virtual International Authority File)
--   - ISNI (International Standard Name Identifier)
--   - Wikidata QID
-- Ces champs etaient marques PLANNED dans fieldRegistry.js (D6) car absents
-- des tables. Ce script ajoute les colonnes + etend le trigger de propagation.
-- =========================================================================

BEGIN;

-- ─── 1. Colonnes ────────────────────────────────────────────────────────

ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS viaf text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS isni text;
ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS wikidata text;

ALTER TABLE public.books ADD COLUMN IF NOT EXISTS viaf text;
ALTER TABLE public.books ADD COLUMN IF NOT EXISTS isni text;
ALTER TABLE public.books ADD COLUMN IF NOT EXISTS wikidata text;

-- ─── 2. Trigger de propagation etendu ───────────────────────────────────
-- Ajoute viaf/isni/wikidata au trigger existant (qui propage deja
-- circulation_default, loanable, distribuidora, tese/artigo/relatorio/zine,
-- subjects). Meme signature, meme attachement.

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
        subjects = NEW.subjects,
        -- Identifiants d'autorite (§5.2)
        viaf = NEW.viaf,
        isni = NEW.isni,
        wikidata = NEW.wikidata
    WHERE id = NEW.published_book_id;
  END IF;
  RETURN NULL;
END;
$function$;

-- ─── 3. Verification ───────────────────────────────────────────────────

DO $verif$
DECLARE
  v_cols text[] := ARRAY['viaf','isni','wikidata'];
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

  IF position('wikidata' IN pg_get_functiondef(
      'public.fn_propagate_circulation_default_on_publish()'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL: trigger ne propage pas wikidata';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS viaf;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS isni;
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS wikidata;
--   ALTER TABLE public.books DROP COLUMN IF EXISTS viaf;
--   ALTER TABLE public.books DROP COLUMN IF EXISTS isni;
--   ALTER TABLE public.books DROP COLUMN IF EXISTS wikidata;
--   (restaurer fn_propagate_circulation_default_on_publish sans viaf/isni/wikidata)
-- =========================================================================
