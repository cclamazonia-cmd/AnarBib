-- =====================================================================
-- AnarBib — Tests d'acceptation : une notice importée d'un fichier MARC qui ne
-- lui décrit aucun exemplaire n'en reçoit pas d'automatique (IMP-25)
-- Date    : 2026-09-28
-- Ref     : migration 20260929103533_imp25_une_notice_marc_sans_exemplaire_n_en_recoit_pas
--
-- T1 MARC (zone d'exemplaire lue, aucune) : publiée, détenue par la
--    bibliothèque, AUCUN exemplaire.
-- T2 CSV (le fichier ne décrit jamais d'exemplaire) : l'exemplaire
--    automatique reste.
-- T3 MARC avec exemplaires : exactement les siens (H19 inchangé).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-SANS-EXEMPLAIRE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans rôle (seed) -> admin réseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_src bigint; v_run bigint; v_lot bigint; v_res jsonb;
  v_marc bigint; v_csv bigint; v_avec bigint;
  v_brut_marc jsonb := '{"marc_dialect": "unimarc", "leader": "00000nas0 22000001i 450 ", "item_tag": "995",
                         "fields": [{"tag": "001", "value": "IMP25-1"}, {"tag": "200", "ind1": "1", "ind2": " ", "subfields": [{"code": "a", "value": "Revue sans exemplaire"}]}]}'::jsonb;
  v_items jsonb := '[{"source_item_code": "IMP25-EX-1", "call_number": "P 1", "note": null, "owner": "BDP", "item_type": null, "public": null, "status": null}]'::jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "IMP25-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai IMP-25', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/imp25.iso', 'imp25.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, raw_payload, normalized_payload)
  VALUES (v_run, 1, 'IMP25-1', 'Revue sans exemplaire', 'new_record', 'accept_new', v_brut_marc,
          jsonb_build_object('items', '[]'::jsonb, 'material_type', 'periodico')),
         (v_run, 2, 'IMP25-2', 'Livre venu d''un CSV', 'new_record', 'accept_new', '{"csv": {"titulo": "Livre venu d''un CSV"}}'::jsonb,
          jsonb_build_object('items', '[]'::jsonb)),
         (v_run, 3, 'IMP25-3', 'Livre avec son exemplaire', 'new_record', 'accept_new',
          jsonb_set(jsonb_set(v_brut_marc, '{fields,0,value}', '"IMP25-3"'), '{leader}', '"00000nam0 22000001i 450 "'),
          jsonb_build_object('items', v_items));

  v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
  v_lot := (v_res->>'batch_id')::bigint;
  UPDATE public.book_drafts SET bib_ref = 'IMP25-REF-' || id WHERE batch_id = v_lot AND bib_ref IS NULL;
  v_res := public.fn_batch_review_request(v_lot);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  v_res := public.publish_catalog_batch(v_lot);
  SELECT d.published_book_id INTO v_marc FROM public.book_drafts d JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
    JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 1;
  SELECT d.published_book_id INTO v_csv FROM public.book_drafts d JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
    JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 2;
  SELECT d.published_book_id INTO v_avec FROM public.book_drafts d JOIN ingest.partner_catalog_row_to_draft m ON m.draft_id = d.id
    JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 3;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 MARC sans exemplaire : publiee, detenue, aucun exemplaire';
  BEGIN
    IF v_marc IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = v_marc AND h.library_id = v_lib)
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_marc)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : livre '||coalesce(v_marc::text, '∅')||' / '||left(coalesce(v_res::text, '∅'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 CSV : l''exemplaire automatique reste';
  BEGIN
    IF (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
         WHERE h.book_id = v_csv AND h.library_id = v_lib) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : livre '||coalesce(v_csv::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 MARC avec exemplaires : exactement les siens';
  BEGIN
    IF (SELECT array_agg(e.source_item_code) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
         WHERE h.book_id = v_avec) = ARRAY['IMP25-EX-1']
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : livre '||coalesce(v_avec::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-SANS-EXEMPLAIRE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IMPORT-SANS-EXEMPLAIRE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
