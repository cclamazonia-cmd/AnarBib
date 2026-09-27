-- =========================================================================
-- B10, passe 2 — indexer les clés étrangères dont le parent est supprimé
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B10 (hygiène de performance), avis 0001 unindexed_foreign_keys ;
--            liste assumée de B21 (tests/sql/fk_sans_index_garde_tests.sql)
--
-- POURQUOI CES 21 ET PAS LES 38. Une clé étrangère sans index ne coûte qu'au
-- moment où son PARENT est supprimé (ou sa clé modifiée) : PostgreSQL parcourt
-- alors toute la table enfant pour vérifier, mettre à NULL ou supprimer en
-- cascade. La question n'est donc pas « la table est-elle petite » mais « le
-- parent est-il supprimé en exploitation ». Mesuré le 27/09 (compteurs depuis
-- le redémarrage du 02/09, 25 jours) : `works` 146 suppressions (fusions
-- d'œuvres), `authors` 37 (fusions d'autorités), `books` 21, `auth.users` et
-- `profiles` 2 (effacements de comptes) ; et les brouillons, lots et fichiers
-- d'import que la corbeille et « Supprimer le lot » purgent par centaines —
-- chaque brouillon supprimé coûtait DEUX parcours complets de
-- `ingest.partner_catalog_staging_rows` (11 Mo, la plus grosse table
-- d'import), dont les deux colonnes sont en SET NULL.
--
-- Les 17 autres pointent des référentiels qui ne se suppriment pas : les 15
-- tables de codes `catalog_ref_*`, les bibliothèques (une bibliothèque se
-- désactive ; 0 suppression) et les partenaires de catalogue (3 lignes). Elles
-- restent dans la liste assumée de B21, motif réécrit le même jour.
--
-- Même forme que le solde du 02/07 (20260702160920) : btree mono-colonne,
-- noms ix_<table>_<colonne>, IF NOT EXISTS. CREATE INDEX simple : tables de
-- quelques Mo au plus, instantané et transactionnel, pas de CONCURRENTLY.
-- Retour arrière : DROP INDEX IF EXISTS <nom>, et la ligne dans B21.
-- =========================================================================

BEGIN;

-- Parent purgé : brouillons (corbeille, « Supprimer le lot »), notices
-- (fusions), fichiers et lots d'import.
CREATE INDEX IF NOT EXISTS ix_partner_catalog_staging_rows_created_book_draft_id
  ON ingest.partner_catalog_staging_rows (created_book_draft_id);
CREATE INDEX IF NOT EXISTS ix_partner_catalog_staging_rows_proposed_book_draft_id
  ON ingest.partner_catalog_staging_rows (proposed_book_draft_id);
CREATE INDEX IF NOT EXISTS ix_partner_catalog_staging_rows_proposed_book_id
  ON ingest.partner_catalog_staging_rows (proposed_book_id);
CREATE INDEX IF NOT EXISTS ix_partner_catalog_staging_rows_source_file_id
  ON ingest.partner_catalog_staging_rows (source_file_id);
CREATE INDEX IF NOT EXISTS ix_partner_catalog_row_to_draft_batch_id
  ON ingest.partner_catalog_row_to_draft (batch_id);

-- Parent fusionné : œuvres, autorités, notices, revues. Pour les tables de
-- paires (a, b), la clé primaire couvre `a` ; `b` réclame son propre index.
CREATE INDEX IF NOT EXISTS ix_book_drafts_work_id
  ON public.book_drafts (work_id);
CREATE INDEX IF NOT EXISTS ix_author_not_duplicate_author_id_b
  ON public.author_not_duplicate (author_id_b);
CREATE INDEX IF NOT EXISTS ix_authority_duplicate_reports_author_id_b
  ON public.authority_duplicate_reports (author_id_b);
CREATE INDEX IF NOT EXISTS ix_catalog_duplicate_reports_book_id_b
  ON public.catalog_duplicate_reports (book_id_b);
CREATE INDEX IF NOT EXISTS ix_serial_not_duplicate_serial_id_b
  ON public.serial_not_duplicate (serial_id_b);

-- Parent effacé : comptes (auth.users, profiles) — colonnes d'acteur.
CREATE INDEX IF NOT EXISTS ix_author_not_duplicate_created_by
  ON public.author_not_duplicate (created_by);
CREATE INDEX IF NOT EXISTS ix_authority_duplicate_reports_closed_by
  ON public.authority_duplicate_reports (closed_by);
CREATE INDEX IF NOT EXISTS ix_authority_duplicate_reports_reported_by
  ON public.authority_duplicate_reports (reported_by);
CREATE INDEX IF NOT EXISTS ix_book_reading_note_reports_reporter_user_id
  ON public.book_reading_note_reports (reporter_user_id);
CREATE INDEX IF NOT EXISTS ix_book_reading_note_reports_resolved_by
  ON public.book_reading_note_reports (resolved_by);
CREATE INDEX IF NOT EXISTS ix_book_reading_notes_hidden_by
  ON public.book_reading_notes (hidden_by);
CREATE INDEX IF NOT EXISTS ix_catalog_duplicate_reports_closed_by
  ON public.catalog_duplicate_reports (closed_by);
CREATE INDEX IF NOT EXISTS ix_catalog_duplicate_reports_reported_by
  ON public.catalog_duplicate_reports (reported_by);
CREATE INDEX IF NOT EXISTS ix_catalog_review_queue_applique_par
  ON public.catalog_review_queue (applique_par);
CREATE INDEX IF NOT EXISTS ix_catalog_review_queue_decided_by
  ON public.catalog_review_queue (decided_by);
CREATE INDEX IF NOT EXISTS ix_library_request_claims_revoked_by_user_id
  ON public.library_request_claims (revoked_by_user_id);

-- ---------------------------------------------------------------------------
-- Garde : chacune des 21 contraintes a désormais un index dont les premières
-- colonnes sont les siennes (même détection que B21 et que l'avis Supabase).
-- Un IF NOT EXISTS qui sauterait sur un nom déjà pris ailleurs se verrait ici.
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE v_reste text; v_vues int;
BEGIN
  SELECT count(*) FILTER (WHERE true),
         string_agg(n.nspname || '.' || t.relname || ' (' || c.conname || ')', ', ')
           FILTER (WHERE NOT EXISTS (
             SELECT 1 FROM pg_index i
             WHERE i.indrelid = c.conrelid
               AND (i.indkey::int2[])[0:array_length(c.conkey, 1) - 1] = c.conkey))
    INTO v_vues, v_reste
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE c.contype = 'f'
    AND c.conname IN (
      'partner_catalog_staging_rows_created_book_draft_id_fkey',
      'partner_catalog_staging_rows_proposed_book_draft_id_fkey',
      'partner_catalog_staging_rows_proposed_book_id_fkey',
      'partner_catalog_staging_rows_source_file_id_fkey',
      'partner_catalog_row_to_draft_batch_id_fkey',
      'book_drafts_work_id_fkey',
      'author_not_duplicate_author_id_b_fkey',
      'authority_duplicate_reports_author_id_b_fkey',
      'catalog_duplicate_reports_book_id_b_fkey',
      'serial_not_duplicate_serial_id_b_fkey',
      'author_not_duplicate_created_by_fkey',
      'authority_duplicate_reports_closed_by_fkey',
      'authority_duplicate_reports_reported_by_fkey',
      'book_reading_note_reports_reporter_user_id_fkey',
      'book_reading_note_reports_resolved_by_fkey',
      'book_reading_notes_hidden_by_fkey',
      'catalog_duplicate_reports_closed_by_fkey',
      'catalog_duplicate_reports_reported_by_fkey',
      'catalog_review_queue_applique_par_fkey',
      'catalog_review_queue_decided_by_fkey',
      'library_request_claims_revoked_by_user_id_fkey');
  IF v_vues <> 21 THEN
    RAISE EXCEPTION 'B10 passe 2 : % contraintes retrouvées sur 21 attendues (renommée ou disparue ?)', v_vues;
  END IF;
  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'B10 passe 2 : clés étrangères toujours sans index : %', v_reste;
  END IF;
END
$garde$;

COMMIT;
