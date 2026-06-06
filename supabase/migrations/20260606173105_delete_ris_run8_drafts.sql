-- =========================================================================
-- Paquet fix — suppression des brouillons de l'import RIS v1 - run 8
-- =========================================================================
-- Date     : 2026-06-06 (horodatage UTC reel)
-- Chantier : Nettoyage donnees / import RIS
-- Auteur   : Xavier + Claude
--
-- CONTEXTE
-- --------
-- Le lot (catalog_batch) id=9 « Import partenaire — RIS v1 — run 8 » [open]
-- contient 5 brouillons de livre (book_drafts), tous status='draft', jamais
-- publies (published_book_id NULL, bib_ref NULL) : rien n'a atteint le catalogue.
-- Demande utilisateur : enlever ces brouillons. Les tables enfants de book_drafts
-- (book_draft_contributors, book_draft_import_events, book_draft_catalog_context,
-- book_draft_digital_resources, ingest.partner_catalog_row_to_draft) sont en
-- ON DELETE CASCADE ; book_catalog_context / partner_catalog_staging_rows en
-- SET NULL -> nettoyage automatique. Verifie : 0 contributeur, 0 import_event,
-- 0 exemplar_draft sur ce lot.
--
-- Le lot 9 lui-meme est CLOS (status='cancelled') plutot que hard-delete
-- (multiples FK vers catalog_batches) : il sort des lots ouverts.
-- =========================================================================

BEGIN;

DO $cleanup$
DECLARE
  v_ids bigint[];
  n int;
BEGIN
  -- Garde : le lot 9 est bien le run RIS attendu
  IF NOT EXISTS (
    SELECT 1 FROM public.catalog_batches
    WHERE id = 9 AND name ILIKE '%RIS%' AND name ILIKE '%run 8%'
  ) THEN
    RAISE EXCEPTION 'abort : le lot 9 n''est pas le run RIS v1 - run 8 attendu';
  END IF;

  SELECT array_agg(id ORDER BY id) INTO v_ids FROM public.book_drafts WHERE batch_id = 9;
  IF COALESCE(array_length(v_ids, 1), 0) <> 5 THEN
    RAISE EXCEPTION 'abort : % brouillon(s) dans le lot 9 au lieu de 5', COALESCE(array_length(v_ids, 1), 0);
  END IF;

  -- Garde : aucun n'est publie (ne supprime pas une fiche en catalogue)
  IF EXISTS (SELECT 1 FROM public.book_drafts WHERE batch_id = 9 AND published_book_id IS NOT NULL) THEN
    RAISE EXCEPTION 'abort : un brouillon du lot 9 est publie';
  END IF;

  DELETE FROM public.book_drafts WHERE batch_id = 9;   -- cascade enfants
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 5 THEN RAISE EXCEPTION 'suppression : % au lieu de 5', n; END IF;

  -- Clore le lot vide
  UPDATE public.catalog_batches
     SET status = 'cancelled', updated_at = now()
   WHERE id = 9;

  -- Bonus (demande utilisateur) : brouillon de TEST annule hors RIS, a la corbeille
  -- (579 « TEST DVD audiovisuel (repro bug) », status cancelled, non publie).
  DELETE FROM public.book_drafts
   WHERE id = 579 AND status = 'cancelled' AND published_book_id IS NULL
     AND titulo ILIKE 'TEST %';

  RAISE NOTICE 'cleanup OK — 5 brouillons RIS run 8 + brouillon test 579 supprimes, lot 9 cloture (%)', v_ids;
END
$cleanup$;

COMMIT;

-- =========================================================================
-- Rollback : non automatique (brouillons de test supprimes volontairement).
-- Pour rouvrir le lot : UPDATE catalog_batches SET status='open' WHERE id=9;
-- =========================================================================
