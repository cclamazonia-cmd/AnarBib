-- =========================================================================
-- Champ distribuidora (audiovisuel) — colonne + propagation au publish
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC réel)
-- Chantier : catalogação — champs par type (suite CAT-E13)
--
-- OBJET (demande Xavier)
--   Ajouter un champ « distribuidora » propre à l'audiovisuel (le distributeur
--   d'un film ; `editora` est exclu de l'AV — cf. EDITORA_MAT). Colonne dédiée
--   pour ne pas écraser `editora`.
--
--   - Colonne `distribuidora text` sur book_drafts + books.
--   - Propagation brouillon → livre publié à la publication : on ÉTEND le
--     trigger existant fn_propagate_circulation_default_on_publish (déjà câblé
--     AFTER UPDATE OF status) pour éviter de re-toucher la fonction géante
--     publish_book_draft. Il copie désormais aussi distribuidora.
--
-- DOCTRINE : pas de backfill (aucune fiche audiovisual existante — le seul DVD
--   est encore tipo_material='livro'). Le champ frontend n'apparaît que pour
--   l'AV (section material_audiovisual).
-- =========================================================================

BEGIN;

ALTER TABLE public.book_drafts ADD COLUMN IF NOT EXISTS distribuidora text;
ALTER TABLE public.books       ADD COLUMN IF NOT EXISTS distribuidora text;

-- Étend le trigger de propagation des champs « padrão fiche » au publish
-- (circulation_default + loanable, désormais + distribuidora). Même signature,
-- même attachement (AFTER UPDATE OF status on book_drafts).
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
        distribuidora = NEW.distribuidora
    WHERE id = NEW.published_book_id;
  END IF;
  RETURN NULL;
END;
$function$;

-- -------------------------------------------------------------------------
-- Vérification
-- -------------------------------------------------------------------------
DO $verif$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='books' AND column_name='distribuidora') THEN
    RAISE EXCEPTION 'VERIF_FAIL_1 : books.distribuidora absent';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='book_drafts' AND column_name='distribuidora') THEN
    RAISE EXCEPTION 'VERIF_FAIL_2 : book_drafts.distribuidora absent';
  END IF;
  IF position('distribuidora' IN pg_get_functiondef('public.fn_propagate_circulation_default_on_publish()'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_3 : trigger ne propage pas distribuidora';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   ALTER TABLE public.book_drafts DROP COLUMN IF EXISTS distribuidora;
--   ALTER TABLE public.books DROP COLUMN IF EXISTS distribuidora;
--   (restaurer fn_propagate_circulation_default_on_publish sans distribuidora)
-- =========================================================================
