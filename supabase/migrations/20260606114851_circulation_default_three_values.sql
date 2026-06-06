-- =========================================================================
-- Paquet catalogação §5.6 — circulação local padrão à 3 valeurs (niveau fiche)
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC réel : l'horloge dépasse enfin le max
--            fabriqué du dossier, donc heure exacte conforme à CLAUDE.md)
-- Chantier : catalogação fiche & paliers (spec §5.6) — lève le différé CAT-E6
--
-- OBJET (décision Xavier : implémenter les 3 valeurs, stratégie additive+synchro)
-- ------------------------------------------------------------------------------
--   La spec §5.6 veut une « circulação local padrão » à 3 valeurs au niveau
--   fiche (emprestavel | consulta | ambos), qui pré-remplit la destination de
--   chaque exemplaire. Le champ existant `loanable` (booléen) est load-bearing
--   (disponibilité `session_loanable`, MV catalogue non-migrée, BookPage, seed
--   exemplaire). Pour livrer les 3 valeurs SANS casser cette logique booléenne :
--
--   - Nouvelle colonne `circulation_default` (3 valeurs) sur book_drafts + books,
--     backfillée depuis `loanable` (true→emprestavel, false→consulta).
--   - `loanable` CONSERVÉ et maintenu synchronisé (= circulation_default <>
--     'consulta') : la dispo / la MV / BookPage continuent sur `loanable`,
--     inchangés. Le frontend écrit les deux ; ce trigger garantit la cohérence
--     au livre publié.
--   - UN trigger AFTER UPDATE OF status sur book_drafts propage la valeur du
--     brouillon vers le livre publié (même pattern que la sync contributeurs).
--     On NE touche PAS publish_book_draft (fonction géante) ni
--     create_book_draft_from_book.
--
-- DOCTRINE : trigger SECURITY DEFINER + search_path + REVOKE EXECUTE FROM PUBLIC.
--   Pas de BEFORE trigger (éviterait d'écraser un loanable explicite au publish).
-- =========================================================================

BEGIN;

-- 1) Colonne 3 valeurs sur les deux tables -------------------------------
ALTER TABLE public.book_drafts
  ADD COLUMN IF NOT EXISTS circulation_default text NOT NULL DEFAULT 'emprestavel'
  CONSTRAINT book_drafts_circulation_default_check
  CHECK (circulation_default IN ('emprestavel', 'consulta', 'ambos'));

ALTER TABLE public.books
  ADD COLUMN IF NOT EXISTS circulation_default text NOT NULL DEFAULT 'emprestavel'
  CONSTRAINT books_circulation_default_check
  CHECK (circulation_default IN ('emprestavel', 'consulta', 'ambos'));

-- 2) Backfill depuis loanable (true→emprestavel défaut ; false→consulta) --
UPDATE public.book_drafts SET circulation_default = 'consulta' WHERE loanable IS FALSE;
UPDATE public.books       SET circulation_default = 'consulta' WHERE loanable IS FALSE;

-- 3) Propagation brouillon → livre publié à la publication ---------------
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
        loanable = (NEW.circulation_default IS DISTINCT FROM 'consulta')
    WHERE id = NEW.published_book_id;
  END IF;
  RETURN NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_propagate_circulation_default_on_publish() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_propagate_circulation_default_on_publish ON public.book_drafts;
CREATE TRIGGER trg_propagate_circulation_default_on_publish
  AFTER UPDATE OF status ON public.book_drafts
  FOR EACH ROW
  WHEN (NEW.status = 'published' AND NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION public.fn_propagate_circulation_default_on_publish();

COMMENT ON FUNCTION public.fn_propagate_circulation_default_on_publish() IS
  'Propage book_drafts.circulation_default vers books (+ derive loanable) a la publication. Catalogacao 5.6, 06/06/2026.';

-- -------------------------------------------------------------------------
-- Vérification automatique
-- -------------------------------------------------------------------------
DO $verif$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='book_drafts' AND column_name='circulation_default') THEN
    RAISE EXCEPTION 'VERIF_FAIL_1 : book_drafts.circulation_default absent';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='books' AND column_name='circulation_default') THEN
    RAISE EXCEPTION 'VERIF_FAIL_2 : books.circulation_default absent';
  END IF;
  -- cohérence du backfill : aucun livre consulta avec circulation_default <> consulta
  IF EXISTS (SELECT 1 FROM public.books WHERE loanable IS FALSE AND circulation_default <> 'consulta') THEN
    RAISE EXCEPTION 'VERIF_FAIL_3 : backfill incoherent (books consulta)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_propagate_circulation_default_on_publish') THEN
    RAISE EXCEPTION 'VERIF_FAIL_4 : trigger de propagation absent';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   DROP TRIGGER IF EXISTS trg_propagate_circulation_default_on_publish ON public.book_drafts;
--   DROP FUNCTION IF EXISTS public.fn_propagate_circulation_default_on_publish();
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS circulation_default;
--   ALTER TABLE public.books DROP COLUMN IF EXISTS circulation_default;
-- =========================================================================
