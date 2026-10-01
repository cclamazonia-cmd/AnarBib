-- =====================================================================
-- AnarBib — Tests d'acceptation : une ligne « Accepté (rattaché) »
-- (accept_duplicate) ne devient jamais une notice ; « Rapprocher » reste
-- son seul chemin (H21 lot 0 ; REGISTRE IMP-26 h, décision du 29/09)
-- Date    : 2026-09-29
-- Ref     : migration 20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe
--           (section 3 : éligibilité de bulk et de create, défauts de
--           promote et de bulk, fn_import_set_editorial ; section 4 :
--           déclencheur trg_book_drafts_ecarte_ligne_importee)
--
-- R1  « Promouvoir » (défauts) : seule la nouveauté acceptée part en
--     création ; les lignes rattachées (matched_book, possible_duplicate,
--     manual_decision, matched_draft) restent sans brouillon ni lien.
-- R2  filtre explicite sur les lignes rattachées : rien, aucun lot, pas
--     d'erreur.
-- R2b « Promouvoir la sélection » (p_row_ids) : une ligne rattachée choisie
--     n'est pas promue ; choisie seule, même avec le filtre accept_duplicate,
--     rien n'est créé.
-- R3  ingest.fn_create_book_drafts_from_import_rows, dernière garde :
--     (a) une liste de lignes rattachées est refusée ; (b) sans liste, une
--     ligne rattachée approuvée et sélectionnée est refusée ; (c) dans une
--     sélection mêlée, seule la nouveauté devient un brouillon.
-- R4  « Rapprocher » : un exemplaire sur la notice existante ; le
--     « Promouvoir » suivant ne touche pas la ligne.
-- R5  dernier exemplaire rapproché annulé : la ligne revient en attente,
--     jamais promue ; accept_new lui reste refusé (incompatible).
-- R6  signatures FINALES (promote 6 paramètres, bulk 7) sans défaut
--     « rattaché » ; droits inchangés (écran : authenticated ; internes :
--     ni authenticated ni anon).
-- R7  une ligne rattachée promue avant IMP-26 (brouillon présent) n'est ni
--     repromue ni rapprochée.
-- R7b son brouillon supprimé définitivement : la ligne est écartée
--     (reject, IMP-27 e) — ni promue ni rapprochable ensuite.
-- R8  fn_import_set_editorial refuse accept_duplicate (HINT
--     error.import.rattacher_par_rapprocher), casse et espaces compris ; la
--     ligne ne change pas.
-- R8b accept_new et reject restent acceptés.
-- R9  « Rapprocher » pose toujours accept_duplicate lui-même (matched_book
--     refusé en R8, possible_duplicate, manual_decision).
--
-- Contre-épreuves jouées le 29/09 (définitions d'avant le lot 0, ou lot 0
-- appliqué en partie, rejouées avant la suite dans la transaction annulée) :
--   promote + bulk d'avant                    -> R1 (5 lignes choisies), R2,
--                                                R2b (pas de p_row_ids), R6
--   create d'avant                            -> R3 (a : brouillon créé)
--   promote + bulk + create d'avant           -> R1 (5 brouillons), R2, R2b, R3, R6
--   bulk du lot 0 sans la règle IMP-26        -> R2, R2b
--   create : règle dans les comptes seulement -> R3 (c : 2 brouillons)
--   create : règle dans la boucle seulement   -> R3 (a : « Aucun rascunho »)
--   fn_import_set_editorial d'avant           -> R8
--   garde de set_editorial sans lower/btrim   -> R8 (« Accept_Duplicate »)
--   sans le déclencheur d'écartement (e)      -> R7b
-- Chaque contre-épreuve est jouée seule : bulk et create gardent chacune,
-- et chacune a son test. R4, R5, R7, R8b et R9 sont des tests de
-- NON-RÉGRESSION : aucune contre-épreuve ne les fait tomber.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-RATTACHEE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_src bigint; v_book bigint; v_run bigint; v_res jsonb; v_res2 jsonb;
  v_txt text; v_hint text; v_hint2 text; v_n int; v_k int; v_oid oid;
  v_new bigint; v_dup bigint; v_d bigint;
  v_run4 bigint; v_r4 bigint; v_x4 bigint;
  v_run7 bigint; v_r7 bigint; v_d7 bigint;
  v_run8 bigint; v_r81 bigint; v_r82 bigint; v_r83 bigint; v_r84 bigint; v_r85 bigint;
BEGIN
  -- ── Décor ───────────────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  -- La notice déjà au catalogue à laquelle les lignes rattachées renvoient.
  INSERT INTO public.books (titulo, bib_ref, tipo_material)
  VALUES ('H21C Notice existante', 'H21C-RATT-1', 'livro') RETURNING id INTO v_book;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai H21C rattachee', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;

  -- R4/R5 : une ligne matched_book en attente, avec un exemplaire codé.
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21c-ratt-4.marc', 'h21c-ratt-4.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run4;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
  VALUES (v_run4, 1, 'H21C-RATT-R4', 'H21C a rapprocher', 'matched_book', 'pending', 'pending', false, v_book,
          '{"items": [{"source_item_code": "H21C-RATT-R4-1", "call_number": "A"}]}'::jsonb)
  RETURNING id INTO v_r4;

  -- R7/R7b : une ligne rattachée PROMUE avant IMP-26 (brouillon et lien posés).
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21c-ratt-7.marc', 'h21c-ratt-7.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run7;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
  VALUES ('H21C promue avant IMP-26', 'livro', v_lib, v_coord, 'draft') RETURNING id INTO v_d7;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, created_book_draft_id, normalized_payload)
  VALUES (v_run7, 1, 'H21C-RATT-R7', 'H21C promue avant', 'matched_book', 'accept_duplicate', 'draft_created', false, v_book, v_d7,
          '{"items": [{"source_item_code": "H21C-RATT-R7-1"}]}'::jsonb)
  RETURNING id INTO v_r7;
  INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)
  VALUES (v_r7, v_run7, v_d7, NULL, v_coord);

  -- R8/R8b/R9 : des lignes en attente, une par cas.
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21c-ratt-8.marc', 'h21c-ratt-8.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run8;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
  VALUES (v_run8, 1, 'H21C-RATT-R81', 'H21C matched_book en attente', 'matched_book', 'pending', 'pending', false, v_book,
          '{"items": [{"source_item_code": "H21C-RATT-R9-1"}]}'::jsonb)
  RETURNING id INTO v_r81;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
  VALUES (v_run8, 2, 'H21C-RATT-R82', 'H21C nouveaute en attente', 'new_record', 'pending', 'pending', false, NULL, '{"items": []}'::jsonb)
  RETURNING id INTO v_r82;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
  VALUES (v_run8, 3, 'H21C-RATT-R83', 'H21C doublon possible a rejeter', 'possible_duplicate', 'pending', 'pending', false, v_book, '{"items": []}'::jsonb)
  RETURNING id INTO v_r83;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
  VALUES (v_run8, 4, 'H21C-RATT-R84', 'H21C doublon possible a rapprocher', 'possible_duplicate', 'pending', 'pending', false, v_book,
          '{"items": [{"source_item_code": "H21C-RATT-R9-2"}]}'::jsonb)
  RETURNING id INTO v_r84;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
  VALUES (v_run8, 5, 'H21C-RATT-R85', 'H21C decision manuelle a rapprocher', 'manual_decision', 'pending', 'pending', false, v_book,
          '{"items": [{"source_item_code": "H21C-RATT-R9-3"}]}'::jsonb)
  RETURNING id INTO v_r85;

  -- ── R1 ──────────────────────────────────────────────────────────────
  v_t := 'R1 Promouvoir (defauts) : seule la nouveaute acceptee part en creation, les rattachees restent sans brouillon ni lien';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21c-ratt-1.marc', 'h21c-ratt-1.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
    VALUES (v_run, 1, 'H21C-RATT-R1-1', 'H21C nouveaute', 'new_record', 'accept_new', 'approved', true, NULL, '{"items": []}'::jsonb)
    RETURNING id INTO v_new;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
    VALUES (v_run, 2, 'H21C-RATT-R1-2', 'H21C matched_book', 'matched_book', 'accept_duplicate', 'approved', true, v_book, '{"items": []}'::jsonb),
           (v_run, 3, 'H21C-RATT-R1-3', 'H21C possible_duplicate', 'possible_duplicate', 'accept_duplicate', 'approved', true, v_book, '{"items": []}'::jsonb),
           (v_run, 4, 'H21C-RATT-R1-4', 'H21C manual_decision', 'manual_decision', 'accept_duplicate', 'approved', true, v_book, '{"items": []}'::jsonb),
           (v_run, 5, 'H21C-RATT-R1-5', 'H21C matched_draft', 'matched_draft', 'accept_duplicate', 'approved', true, NULL, '{"items": []}'::jsonb);
    v_res := public.fn_import_promote(v_run);
    IF coalesce((v_res->>'created_drafts')::int, -1) = 1
       AND coalesce((v_res->>'selected_count')::int, -1) = 1
       AND v_res->'selected_row_ids' = jsonb_build_array(v_new)
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = (v_res->>'batch_id')::bigint) = 1
       AND (SELECT created_book_draft_id IS NOT NULL FROM ingest.partner_catalog_staging_rows WHERE id = v_new)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows
                        WHERE run_id = v_run AND id <> v_new
                          AND (created_book_draft_id IS NOT NULL OR review_status = 'draft_created'))
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run AND staging_row_id <> v_new)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce((v_res - 'run')::text, 'NULL'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R2 ──────────────────────────────────────────────────────────────
  v_t := 'R2 filtre explicite sur les lignes rattachees : rien, aucun lot, aucune erreur';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21c-ratt-2.marc', 'h21c-ratt-2.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
    VALUES (v_run, 1, 'H21C-RATT-R2-1', 'H21C rattachee', 'matched_book', 'accept_duplicate', 'approved', true, v_book, '{"items": []}'::jsonb)
    RETURNING id INTO v_dup;
    SELECT count(*) INTO v_n FROM public.catalog_batches;
    v_res := public.fn_import_promote(v_run, ARRAY['matched_book'], ARRAY['accept_duplicate']);
    IF coalesce((v_res->>'selected_count')::int, -1) = 0
       AND v_res->>'batch_id' IS NULL
       AND (SELECT count(*) FROM public.catalog_batches) = v_n
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run)
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_dup) IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce((v_res - 'run')::text, 'NULL'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R2b ─────────────────────────────────────────────────────────────
  v_t := 'R2b Promouvoir la selection (p_row_ids) : la ligne rattachee choisie n''est pas promue ; choisie seule, meme avec le filtre accept_duplicate, rien';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21c-ratt-2b.marc', 'h21c-ratt-2b.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
    VALUES (v_run, 1, 'H21C-RATT-R2b-1', 'H21C nouveaute choisie', 'new_record', 'accept_new', 'approved', true, NULL, '{"items": []}'::jsonb)
    RETURNING id INTO v_new;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
    VALUES (v_run, 2, 'H21C-RATT-R2b-2', 'H21C rattachee choisie', 'matched_book', 'accept_duplicate', 'approved', true, v_book, '{"items": []}'::jsonb)
    RETURNING id INTO v_dup;
    -- Le chemin de l'écran : la sélection, les défauts.
    v_res := public.fn_import_promote(v_run, p_row_ids => ARRAY[v_new, v_dup]);
    SELECT count(*) INTO v_n FROM public.catalog_batches;
    -- Choisie seule, et demandée par le filtre : c'est l'éligibilité qui la
    -- retient, pas le défaut {accept_new}.
    v_res2 := public.fn_import_promote(v_run, p_editorial_decisions => ARRAY['accept_new', 'accept_duplicate'],
                                       p_row_ids => ARRAY[v_dup]);
    IF coalesce((v_res->>'selected_count')::int, -1) = 1
       AND v_res->'selected_row_ids' = jsonb_build_array(v_new)
       AND coalesce((v_res->>'created_drafts')::int, -1) = 1
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_dup) IS NULL
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_dup)
       AND coalesce((v_res2->>'selected_count')::int, -1) = 0
       AND v_res2->>'batch_id' IS NULL
       AND (SELECT count(*) FROM public.catalog_batches) = v_n
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce((v_res - 'run')::text, 'NULL'), 200)
         ||' / seule : '||left(coalesce((v_res2 - 'run')::text, 'NULL'), 150)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R3 ──────────────────────────────────────────────────────────────
  v_t := 'R3 fn_create_book_drafts_from_import_rows : liste rattachee refusee ; sans liste refusee ; selection melee : la nouveaute seule';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21c-ratt-3.marc', 'h21c-ratt-3.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
    VALUES (v_run, 1, 'H21C-RATT-R3-1', 'H21C rattachee', 'matched_book', 'accept_duplicate', 'approved', true, v_book, '{"items": []}'::jsonb)
    RETURNING id INTO v_dup;
    v_txt := NULL;
    BEGIN
      PERFORM ingest.fn_create_book_drafts_from_import_rows(v_run, ARRAY[v_dup], NULL, NULL, v_coord);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL OR v_txt NOT LIKE 'Aucune ligne autoris%' THEN
      RAISE EXCEPTION '(a) liste rattachee : %', coalesce(v_txt, 'brouillon cree');
    END IF;
    v_txt := NULL;
    BEGIN
      PERFORM ingest.fn_create_book_drafts_from_import_rows(v_run, NULL, NULL, NULL, v_coord);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt IS NULL OR v_txt NOT LIKE 'Aucune ligne autoris%' THEN
      RAISE EXCEPTION '(b) sans liste : %', coalesce(v_txt, 'brouillon cree');
    END IF;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, normalized_payload)
    VALUES (v_run, 2, 'H21C-RATT-R3-2', 'H21C nouveaute', 'new_record', 'accept_new', 'approved', true, '{"items": []}'::jsonb)
    RETURNING id INTO v_new;
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_run, ARRAY[v_new, v_dup], NULL, NULL, v_coord);
    IF (v_res->>'requested_rows')::int = 1 AND (v_res->>'created_drafts')::int = 1
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_new) IS NOT NULL
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_dup) IS NULL
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_dup)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : (c) '||left(coalesce((v_res - 'run')::text, 'NULL'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R4 ──────────────────────────────────────────────────────────────
  v_t := 'R4 Rapprocher : exemplaire sur la notice existante ; Promouvoir ensuite ne touche pas la ligne';
  BEGIN
    v_res := public.fn_import_reconcile_duplicates(v_run4, ARRAY[v_r4]);
    SELECT created_exemplar_draft_id INTO v_x4 FROM ingest.partner_catalog_staging_rows WHERE id = v_r4;
    v_res2 := public.fn_import_promote(v_run4);
    IF v_x4 IS NOT NULL
       AND (SELECT editorial_decision = 'accept_duplicate' AND created_book_draft_id IS NULL
              FROM ingest.partner_catalog_staging_rows WHERE id = v_r4)
       AND (SELECT x.book_draft_id IS NULL AND x.target_bib_ref = 'H21C-RATT-1' AND x.source_item_code = 'H21C-RATT-R4-1'
              FROM public.exemplar_drafts x WHERE x.id = v_x4)
       AND coalesce((v_res2->>'selected_count')::int, -1) = 0
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run4)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaire='||coalesce(v_x4::text,'∅')
         ||' '||left(coalesce((v_res2 - 'run')::text, 'NULL'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R5 (décor de R4) ────────────────────────────────────────────────
  v_t := 'R5 dernier exemplaire rapproche annule : ligne en attente, jamais promue ; accept_new lui reste refuse';
  BEGIN
    IF v_x4 IS NULL THEN RAISE EXCEPTION 'decor de R4 absent'; END IF;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE import_staging_row_id = v_r4;
    v_res := public.fn_import_promote(v_run4);
    v_txt := NULL;
    BEGIN
      PERFORM public.fn_import_set_editorial(v_run4, ARRAY[v_r4], 'accept_new', NULL);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF (SELECT editorial_decision = 'pending' AND created_exemplar_draft_id IS NULL AND created_book_draft_id IS NULL
               AND review_status = 'pending' AND selected_for_draft = false
          FROM ingest.partner_catalog_staging_rows WHERE id = v_r4)
       AND coalesce((v_res->>'selected_count')::int, -1) = 0
       AND v_txt LIKE '%incompatible%'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'accept_new admis')
         ||' / '||left(coalesce((v_res - 'run')::text, 'NULL'), 150)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R6 ──────────────────────────────────────────────────────────────
  v_t := 'R6 signatures finales sans defaut rattache ; droits inchanges';
  BEGIN
    -- fn_import_promote : une seule signature, 6 paramètres, le dernier p_row_ids.
    SELECT count(*), min(p.oid) INTO v_n, v_oid FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_import_promote';
    SELECT p.pronargs, pg_get_function_arguments(p.oid) INTO v_k, v_txt FROM pg_proc p WHERE p.oid = v_oid;
    IF v_n <> 1 OR v_k <> 6 OR position('accept_duplicate' IN v_txt) > 0
       OR position('p_editorial_decisions text[] DEFAULT ARRAY[''accept_new''::text]' IN v_txt) = 0
       OR v_txt NOT LIKE '%, p_row_ids bigint[] DEFAULT NULL::bigint[]' THEN
      RAISE EXCEPTION 'promote (% signature(s), % parametres) : %', v_n, v_k, v_txt;
    END IF;
    IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') OR has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'droits de promote';
    END IF;
    -- ingest.fn_bulk_create_book_drafts_from_run : une seule signature, 7 paramètres.
    SELECT count(*), min(p.oid) INTO v_n, v_oid FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'ingest' AND p.proname = 'fn_bulk_create_book_drafts_from_run';
    SELECT p.pronargs, pg_get_function_arguments(p.oid) INTO v_k, v_txt FROM pg_proc p WHERE p.oid = v_oid;
    IF v_n <> 1 OR v_k <> 7 OR position('accept_duplicate' IN v_txt) > 0
       OR position('p_editorial_decisions text[] DEFAULT ARRAY[''accept_new''::text]' IN v_txt) = 0
       OR v_txt NOT LIKE '%, p_row_ids bigint[] DEFAULT NULL::bigint[]' THEN
      RAISE EXCEPTION 'bulk (% signature(s), % parametres) : %', v_n, v_k, v_txt;
    END IF;
    IF has_function_privilege('authenticated', v_oid, 'EXECUTE') OR has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'droits de bulk';
    END IF;
    -- create : interne ; set_editorial et reconcile : l'écran (authenticated), jamais anon.
    IF has_function_privilege('authenticated', 'ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'public.fn_import_set_editorial(bigint, bigint[], text, text)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.fn_import_set_editorial(bigint, bigint[], text, text)', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'public.fn_import_reconcile_duplicates(bigint, bigint[])', 'EXECUTE')
       OR has_function_privilege('anon', 'public.fn_import_reconcile_duplicates(bigint, bigint[])', 'EXECUTE') THEN
      RAISE EXCEPTION 'droits de create, set_editorial ou reconcile';
    END IF;
    v_passed := v_passed+1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R7 ──────────────────────────────────────────────────────────────
  v_t := 'R7 ligne rattachee promue avant IMP-26 (brouillon present) : ni repromue, ni rapprochee';
  BEGIN
    v_res := public.fn_import_promote(v_run7);
    v_txt := NULL;
    BEGIN
      PERFORM ingest.fn_create_exemplar_drafts_from_import_rows(v_run7, ARRAY[v_r7]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF coalesce((v_res->>'selected_count')::int, -1) = 0
       AND v_res->>'batch_id' IS NULL
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_r7) = v_d7
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run7) = 1
       AND v_txt LIKE 'Aucune ligne eligible%'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rapprochement='||coalesce(v_txt,'accepte')
         ||' / '||left(coalesce((v_res - 'run')::text, 'NULL'), 150)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R7b (décor de R7) ───────────────────────────────────────────────
  v_t := 'R7b son brouillon supprime definitivement : la ligne est ecartee (reject), ni promue ni rapprochable';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_d7) THEN RAISE EXCEPTION 'decor de R7 absent'; END IF;
    -- « Vider la corbeille » : à la corbeille, puis supprimé.
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d7;
    DELETE FROM public.book_drafts WHERE id = v_d7;
    v_res := public.fn_import_promote(v_run7);
    v_txt := NULL;
    BEGIN
      PERFORM ingest.fn_create_exemplar_drafts_from_import_rows(v_run7, ARRAY[v_r7]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF (SELECT editorial_decision = 'reject' AND review_status = 'rejected' AND selected_for_draft = false
               AND created_book_draft_id IS NULL AND created_exemplar_draft_id IS NULL
               AND editorial_note LIKE '%IMP-27 e%'
          FROM ingest.partner_catalog_staging_rows WHERE id = v_r7)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run7)
       AND coalesce((v_res->>'selected_count')::int, -1) = 0
       AND v_txt LIKE 'Aucune ligne eligible%'
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE import_staging_row_id = v_r7)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ligne='||coalesce((
           SELECT editorial_decision || '/' || review_status || ' livre=' || coalesce(created_book_draft_id::text, '∅')
             FROM ingest.partner_catalog_staging_rows WHERE id = v_r7), '∅')
         ||' rapprochement='||coalesce(v_txt, 'accepte')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R8 ──────────────────────────────────────────────────────────────
  v_t := 'R8 fn_import_set_editorial refuse accept_duplicate (HINT), casse et espaces compris ; la ligne ne change pas';
  BEGIN
    v_hint := NULL;
    BEGIN
      PERFORM public.fn_import_set_editorial(v_run8, ARRAY[v_r81], 'accept_duplicate', 'H21C essai');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    v_hint2 := NULL;
    BEGIN
      PERFORM public.fn_import_set_editorial(v_run8, ARRAY[v_r81], '  Accept_Duplicate ', NULL);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.import.rattacher_par_rapprocher'
       AND v_hint2 = 'error.import.rattacher_par_rapprocher'
       AND (SELECT editorial_decision = 'pending' AND review_status = 'pending' AND selected_for_draft = false
                   AND editorial_note IS NULL AND editorial_decided_at IS NULL AND editorial_decided_by IS NULL
                   AND created_exemplar_draft_id IS NULL AND created_book_draft_id IS NULL
              FROM ingest.partner_catalog_staging_rows WHERE id = v_r81)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'aucun refus')
         ||' / casse='||coalesce(v_hint2,'aucun refus')||' / ligne='||coalesce((
           SELECT editorial_decision || '/' || review_status || '/' || selected_for_draft
             FROM ingest.partner_catalog_staging_rows WHERE id = v_r81), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R8b ─────────────────────────────────────────────────────────────
  v_t := 'R8b fn_import_set_editorial : accept_new et reject restent acceptes';
  BEGIN
    v_res := public.fn_import_set_editorial(v_run8, ARRAY[v_r82], 'accept_new', NULL);
    v_res2 := public.fn_import_set_editorial(v_run8, ARRAY[v_r83], 'reject', 'H21C pas pour nous');
    IF (v_res->>'updated_rows')::int = 1 AND (v_res2->>'updated_rows')::int = 1
       AND (SELECT editorial_decision = 'accept_new' AND review_status = 'approved' AND selected_for_draft
                   AND editorial_decided_by = v_coord
              FROM ingest.partner_catalog_staging_rows WHERE id = v_r82)
       AND (SELECT editorial_decision = 'reject' AND review_status = 'rejected' AND NOT selected_for_draft
                   AND editorial_note = 'H21C pas pour nous'
              FROM ingest.partner_catalog_staging_rows WHERE id = v_r83)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce((v_res - 'run')::text, 'NULL'), 150)
         ||' / '||left(coalesce((v_res2 - 'run')::text, 'NULL'), 150)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── R9 (décor de R8) ────────────────────────────────────────────────
  v_t := 'R9 Rapprocher pose toujours accept_duplicate lui-meme (matched_book refusee en R8, possible_duplicate, manual_decision)';
  BEGIN
    v_res := public.fn_import_reconcile_duplicates(v_run8, ARRAY[v_r81, v_r84, v_r85]);
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_staging_rows
     WHERE id IN (v_r81, v_r84, v_r85)
       AND editorial_decision = 'accept_duplicate'
       AND editorial_note = 'page import: rapprochement (exemplar)'
       AND editorial_decided_by = v_coord
       AND review_status = 'draft_created' AND selected_for_draft = false
       AND created_exemplar_draft_id IS NOT NULL AND created_book_draft_id IS NULL;
    SELECT count(*) INTO v_k FROM public.exemplar_drafts x
     WHERE x.import_staging_row_id IN (v_r81, v_r84, v_r85)
       AND x.book_draft_id IS NULL AND x.target_bib_ref = 'H21C-RATT-1'
       AND x.batch_id = (v_res->>'batch_id')::bigint
       AND x.source_item_code IN ('H21C-RATT-R9-1', 'H21C-RATT-R9-2', 'H21C-RATT-R9-3');
    IF v_n = 3 AND v_k = 3
       AND (v_res->>'created_exemplar_drafts')::int = 3 AND (v_res->>'created_items')::int = 3
       -- la ligne rejetée en R8b n'est pas touchée
       AND (SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = v_r83) = 'reject'
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run8)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lignes='||v_n||'/3 exemplaires='||v_k||'/3 '
         ||left(coalesce((v_res - 'run')::text, 'NULL'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-RATTACHEE OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'IMPORT-RATTACHEE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
