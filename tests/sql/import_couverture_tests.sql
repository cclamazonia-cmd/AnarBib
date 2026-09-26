-- =====================================================================
-- AnarBib — Tests d'acceptation : le rapport de revision d'un lot importe
-- dit ce que l'import a repris (H16)
-- Date    : 2026-09-26  ·  Session : aller-retour PMB (G15, H14)
-- Ref     : migration 20260926194500_h16_couverture_au_rapport_de_revision
--
-- T1 : un lot issu d'un import MARC -> une entree `coverage`, avec les
--      comptes du summary et SEULEMENT les zones non reprises.
-- T2 : un lot issu d'un import CSV -> les colonnes non reprises (brut ET
--      indice), aucune reprise.
-- T3 : un lot sans import -> coverage = [].
-- T4 : un run dont le summary n'a pas de couverture (anterieur a H16) ->
--      entree presente, not_taken = [] (le rapport ne casse pas).
-- T5 : droits : anon non, authenticated oui.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-COUVERTURE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_src bigint; v_run bigint; v_run_csv bigint; v_run_old bigint;
  v_res jsonb; v_lot bigint; v_lot_csv bigint; v_lot_old bigint; v_lot_man bigint;
  v_rep jsonb; v_cov jsonb;
  v_marc_summary jsonb := '{
    "coverage": {"kind": "marc", "records": 2, "truncated": false, "zones": [
      {"dialect": "unimarc", "tag": "001", "code": "",  "status": "repris", "occurrences": 2, "records": 2, "surplus": 0, "example": "61"},
      {"dialect": "unimarc", "tag": "200", "code": "a", "status": "repris", "occurrences": 2, "records": 2, "surplus": 0, "example": "Brûler les frontières"},
      {"dialect": "unimarc", "tag": "215", "code": "a", "status": "brut",   "occurrences": 2, "records": 2, "surplus": 0, "example": "32 p."},
      {"dialect": "unimarc", "tag": "995", "code": "f", "status": "brut",   "occurrences": 3, "records": 2, "surplus": 0, "example": "CDF0000000001"}
    ]},
    "coverage_counts": {"repris": 2, "indice": 0, "brut": 2, "total": 4},
    "encoding": {"used": "utf-8", "forced": null, "fallback": false, "declared_unimarc": ["50"]},
    "skipped_rows": 0}'::jsonb;
  v_csv_summary jsonb := '{
    "coverage": {"kind": "csv", "records": 3, "columns": [
      {"header": "titulo", "status": "repris", "field": "title", "occurrences": 3, "example": "O Estado"},
      {"header": "cote",   "status": "indice", "field": "cote",  "occurrences": 3, "example": "320 BAK"},
      {"header": "tipo_material", "status": "brut", "field": null, "occurrences": 3, "example": "livro"}
    ]},
    "coverage_counts": {"repris": 1, "indice": 1, "brut": 1, "total": 3},
    "skipped_rows": 1}'::jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai couverture', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;

  -- Un import MARC, un import CSV, un import d'avant H16 : chacun son lot.
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, summary)
  VALUES (v_src, v_lib, 'essai/pmb.marc', 'pmb.marc', 'marc_iso2709', 'ready_for_review', v_marc_summary) RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
  VALUES (v_run, 1, 'cov-1', 'Brûler les frontières', 'new_record', 'accept_new');
  v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
  v_lot := (v_res->>'batch_id')::bigint;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, summary)
  VALUES (v_src, v_lib, 'essai/cat.csv', 'cat.csv', 'csv', 'ready_for_review', v_csv_summary) RETURNING id INTO v_run_csv;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
  VALUES (v_run_csv, 1, 'cov-2', 'O Estado', 'new_record', 'accept_new');
  v_res := public.fn_import_promote(v_run_csv, ARRAY['new_record'], ARRAY['accept_new']);
  v_lot_csv := (v_res->>'batch_id')::bigint;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, summary)
  VALUES (v_src, v_lib, 'essai/ancien.csv', 'ancien.csv', 'csv', 'ready_for_review', '{"parser": "csv_v1"}'::jsonb) RETURNING id INTO v_run_old;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
  VALUES (v_run_old, 1, 'cov-3', 'Ancien import', 'new_record', 'accept_new');
  v_res := public.fn_import_promote(v_run_old, ARRAY['new_record'], ARRAY['accept_new']);
  v_lot_old := (v_res->>'batch_id')::bigint;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 lot issu d''un import MARC : comptes du summary, seules les zones non reprises';
  BEGIN
    v_rep := public.fn_batch_review_report(v_lot);
    v_cov := v_rep->'coverage';
    IF jsonb_array_length(v_cov) = 1
       AND (v_cov->0->>'run_id')::bigint = v_run
       AND v_cov->0->'counts' = '{"repris": 2, "indice": 0, "brut": 2, "total": 4}'::jsonb
       AND v_cov->0->>'kind' = 'marc'
       AND v_cov->0->'encoding'->>'used' = 'utf-8'
       AND jsonb_array_length(v_cov->0->'not_taken') = 2
       AND NOT (v_cov->0->'not_taken' @> '[{"status": "repris"}]'::jsonb)
       AND v_cov->0->'not_taken' @> '[{"tag": "995", "code": "f", "status": "brut"}]'::jsonb
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_cov::text,'NULL'), 400)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 lot issu d''un import CSV : colonnes brut ET indice, aucune reprise, lignes ecartees';
  BEGIN
    v_cov := public.fn_batch_review_report(v_lot_csv)->'coverage';
    IF jsonb_array_length(v_cov) = 1
       AND v_cov->0->>'kind' = 'csv'
       AND jsonb_array_length(v_cov->0->'not_taken') = 2
       AND v_cov->0->'not_taken' @> '[{"header": "cote", "status": "indice"}, {"header": "tipo_material", "status": "brut"}]'::jsonb
       AND (v_cov->0->>'skipped_rows')::int = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_cov::text,'NULL'), 400)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 lot sans import : coverage vide';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by) VALUES ('Lot manuel couverture', v_coord) RETURNING id INTO v_lot_man;
    v_cov := public.fn_batch_review_report(v_lot_man)->'coverage';
    IF v_cov = '[]'::jsonb THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_cov::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 import d''avant H16 (summary sans couverture) : entree presente, not_taken vide';
  BEGIN
    v_cov := public.fn_batch_review_report(v_lot_old)->'coverage';
    IF jsonb_array_length(v_cov) = 1 AND v_cov->0->'not_taken' = '[]'::jsonb AND v_cov->0->'counts' = 'null'::jsonb
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_cov::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 droits : anon non, authenticated oui';
  BEGIN
    IF NOT has_function_privilege('anon', 'public.fn_batch_review_report(bigint)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_batch_review_report(bigint)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : droits inattendus'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-COUVERTURE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IMPORT-COUVERTURE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
