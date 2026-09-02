-- Garde des clés étrangères sans index de support — item B21 (02/09/2026).
--
-- Doctrine v17, précision 3 (et DOC-ACTIF-1 pour l'esprit) : « un chantier de
-- dette structurelle n'est clos que quand un garde automatique empêche sa
-- réouverture. Une migration remet un compteur à zéro ; elle ne tient pas la
-- ligne. » Prouvé expérimentalement : 136 index déployés le 02/07 (151 → 15),
-- 38 clés sans index au 01/09 — remontée par le fonctionnement normal du
-- projet, sans qu'aucune faute soit commise.
--
-- Ce garde remplace la prochaine campagne : toute FK nouvelle a deux issues —
-- son index, ou son entrée motivée dans la liste ci-dessous. Sinon, rouge en
-- CI au moment où la migration s'écrit, pas huit semaines après.
--
-- LA REQUÊTE, ET SON ANGLE MORT (DOC-RECENS-1 : un recensement porte comment
-- il a été fait et ce qu'il ne peut pas voir). Une FK est « couverte » si un
-- index existe dont les PREMIÈRES colonnes, dans l'ordre, sont exactement
-- celles de la contrainte (préfixe de `pg_index.indkey`). Ne sont PAS vus :
-- les index d'expression (indkey porte 0), les index partiels (couverture
-- conditionnelle comptée comme pleine), et les FK des schémas hors
-- public/ingest. Même méthode que l'advisor Supabase, résultats identiques
-- à l'unité au 02/09 (38).

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
BEGIN
  -- ───────────────────────────────────────────────────────────────────
  -- LA LISTE ASSUMÉE — 38 entrées au 02/09/2026, trois familles motivées.
  -- Ajouter une entrée ici doit être un acte (commit qui dit pourquoi),
  -- jamais un réflexe pour faire taire le rouge.
  --
  -- (a) 15 FK vers les tables de codes `catalog_ref_*` : référentiels de
  --     quelques dizaines de lignes, jamais parcourus en sens inverse —
  --     les résiduelles voulues du solde du 02/07, intactes depuis.
  -- (b) 17 colonnes d'acteur des tables de qualité catalographique (qui a
  --     signalé, décidé, appliqué → comptes) + rattachements de brouillon :
  --     volumétrie minuscule, aucune jointure inverse en requête chaude.
  --     Indexer se décidera à l'usage (B10), pas par principe.
  -- (c) 6 FK du schéma `ingest` : transit d'import, tables de staging
  --     purgées par lot, jamais interrogées par les écrans.
  -- ───────────────────────────────────────────────────────────────────
  CREATE TEMP TABLE _fk_assumees(tbl text, conname text) ON COMMIT DROP;
  INSERT INTO _fk_assumees VALUES
    -- (a) tables de codes
    ('public.audio_tracks','audio_tracks_recording_type_fkey'),
    ('public.book_catalog_context','book_catalog_context_acquisition_mode_code_fkey'),
    ('public.book_catalog_context','book_catalog_context_confidence_level_code_fkey'),
    ('public.book_catalog_context','book_catalog_context_import_method_code_fkey'),
    ('public.book_catalog_context','book_catalog_context_review_status_code_fkey'),
    ('public.book_catalog_context','book_catalog_context_source_format_code_fkey'),
    ('public.book_draft_catalog_context','book_draft_catalog_context_acquisition_mode_code_fkey'),
    ('public.book_draft_catalog_context','book_draft_catalog_context_confidence_level_code_fkey'),
    ('public.book_draft_catalog_context','book_draft_catalog_context_import_method_code_fkey'),
    ('public.book_draft_catalog_context','book_draft_catalog_context_review_status_code_fkey'),
    ('public.book_draft_catalog_context','book_draft_catalog_context_source_format_code_fkey'),
    ('public.book_draft_import_events','book_draft_import_events_confidence_level_code_fkey'),
    ('public.book_draft_import_events','book_draft_import_events_import_method_code_fkey'),
    ('public.book_draft_import_events','book_draft_import_events_review_status_code_fkey'),
    ('public.book_draft_import_events','book_draft_import_events_source_format_code_fkey'),
    -- (b) colonnes d'acteur et rattachements
    ('public.author_not_duplicate','author_not_duplicate_author_id_b_fkey'),
    ('public.author_not_duplicate','author_not_duplicate_created_by_fkey'),
    ('public.authority_duplicate_reports','authority_duplicate_reports_author_id_b_fkey'),
    ('public.authority_duplicate_reports','authority_duplicate_reports_closed_by_fkey'),
    ('public.authority_duplicate_reports','authority_duplicate_reports_reported_by_fkey'),
    ('public.book_drafts','book_drafts_initial_copies_library_id_fkey'),
    ('public.book_drafts','book_drafts_work_id_fkey'),
    ('public.book_reading_note_reports','book_reading_note_reports_reporter_user_id_fkey'),
    ('public.book_reading_note_reports','book_reading_note_reports_resolved_by_fkey'),
    ('public.book_reading_notes','book_reading_notes_hidden_by_fkey'),
    ('public.catalog_duplicate_reports','catalog_duplicate_reports_book_id_b_fkey'),
    ('public.catalog_duplicate_reports','catalog_duplicate_reports_closed_by_fkey'),
    ('public.catalog_duplicate_reports','catalog_duplicate_reports_reported_by_fkey'),
    ('public.catalog_review_queue','catalog_review_queue_applique_par_fkey'),
    ('public.catalog_review_queue','catalog_review_queue_decided_by_fkey'),
    ('public.library_request_claims','library_request_claims_revoked_by_user_id_fkey'),
    ('public.serial_not_duplicate','serial_not_duplicate_serial_id_b_fkey'),
    -- (c) transit d'import (ingest)
    ('ingest.partner_catalog_row_to_draft','partner_catalog_row_to_draft_batch_id_fkey'),
    ('ingest.partner_catalog_sources','partner_catalog_sources_catalog_partner_id_fkey'),
    ('ingest.partner_catalog_staging_rows','partner_catalog_staging_rows_created_book_draft_id_fkey'),
    ('ingest.partner_catalog_staging_rows','partner_catalog_staging_rows_proposed_book_draft_id_fkey'),
    ('ingest.partner_catalog_staging_rows','partner_catalog_staging_rows_proposed_book_id_fkey'),
    ('ingest.partner_catalog_staging_rows','partner_catalog_staging_rows_source_file_id_fkey');

  CREATE TEMP TABLE _fk_sans_index ON COMMIT DROP AS
  SELECT n.nspname||'.'||t.relname AS tbl, c.conname
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE c.contype = 'f' AND n.nspname IN ('public','ingest')
    AND NOT EXISTS (
      SELECT 1 FROM pg_index i
      WHERE i.indrelid = c.conrelid
        AND (i.indkey::int2[])[0:array_length(c.conkey,1)-1] = c.conkey);

  -- T1 : aucune FK sans index hors de la liste assumée — la dette n'entre
  --      plus sans un acte.
  v_test_name := 'T1 aucune FK sans index hors liste';
  SELECT string_agg(s.tbl||' ('||s.conname||')', ', ') INTO v_liste
  FROM _fk_sans_index s
  WHERE NOT EXISTS (SELECT 1 FROM _fk_assumees a WHERE a.tbl = s.tbl AND a.conname = s.conname);
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || v_liste
    || ' — son index, ou son entrée motivée dans tests/sql/fk_sans_index_garde_tests.sql'); END IF;

  -- T2 : aucune entrée périmée — la liste ne rétrécit que consciemment
  --      (contrainte disparue ou désormais indexée = entrée à retirer).
  v_test_name := 'T2 aucune entrée périmée dans la liste';
  SELECT string_agg(a.tbl||' ('||a.conname||')', ', ') INTO v_liste
  FROM _fk_assumees a
  WHERE NOT EXISTS (SELECT 1 FROM _fk_sans_index s WHERE s.tbl = a.tbl AND s.conname = a.conname);
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || v_liste
    || ' — indexée ou disparue : retirer l''entrée, la liste ne peut que rétrécir consciemment'); END IF;

  -- T3 : le garde mord — une FK neuve sans index, créée ici même, est vue
  --      par le détecteur. Fixture en tables TEMPORAIRES : pg_constraint et
  --      pg_index les décrivent comme les autres, et rien n'entre dans
  --      `public` (le hook pre-commit exige à raison RLS+GRANT de toute
  --      table qui y naît, même une éphémère de test).
  v_test_name := 'T3 le garde mord sur une FK neuve';
  CREATE TEMP TABLE _b21_epreuve_parent(id bigint PRIMARY KEY) ON COMMIT DROP;
  CREATE TEMP TABLE _b21_epreuve_enfant(id bigint PRIMARY KEY,
    parent_id bigint REFERENCES _b21_epreuve_parent(id)) ON COMMIT DROP;
  IF EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = '_b21_epreuve_enfant' AND c.contype = 'f'
      AND NOT EXISTS (
        SELECT 1 FROM pg_index i
        WHERE i.indrelid = c.conrelid
          AND (i.indkey::int2[])[0:array_length(c.conkey,1)-1] = c.conkey)
  ) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : le détecteur ne voit pas une FK notoirement sans index'); END IF;
  DROP TABLE _b21_epreuve_enfant;
  DROP TABLE _b21_epreuve_parent;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'FK_SANS_INDEX_GARDE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'FK_SANS_INDEX_GARDE OK : %/% tests passés (38 entrées assumées)', v_passed, v_passed;
END $$;
