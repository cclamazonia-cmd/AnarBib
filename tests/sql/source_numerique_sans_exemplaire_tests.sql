-- =====================================================================
-- AnarBib — Tests d'acceptation : une source d'import « numérique, sans
-- exemplaire » ne reçoit pas d'exemplaire automatique à la publication
-- (décision de Xavier du 15/10/2026 ; premier cas : Anarchief.org)
-- Date    : 2026-10-15
-- Ref     : migration 20261015192644_source_numerique_sans_exemplaire
--
-- Décor : BLMF (seed), sa coordination (seed), l'administration du réseau
-- (compte seed sans rôle, promu ici). Deux sources de catalogue propre, un
-- fichier CSV chacune (aucune zone d'exemplaire, aucun brouillon d'exemplaire
-- lié) : S1 porte meta.sans_exemplaire = true, S2 ne porte rien. Un run par
-- source, une ligne par run, promue, révisée, approuvée, publiée.
--
-- T1  ingest.fn_source_sans_exemplaire : vrai pour S1 par source_id, vrai
--     par le run seul (source_id NULL), faux pour S2, faux pour un run et une
--     source inconnus, faux quand le drapeau dit 'false'.
-- T2  Publication d'une notice née de S1 : la notice est créée, BLMF la
--     DÉTIENT (book_holdings), et ZÉRO exemplaire n'est créé — aucun tombo
--     consommé dans la série de BLMF.
-- T3  Publication d'une notice née de S2 (même fichier, même chemin) : UN
--     exemplaire automatique, comme avant (IMP-25 : « un CSV ne décrit jamais
--     d'exemplaire, l'automatique reste »).
-- T4  Les exemplaires importés (H19) passent avant : une ligne de S1 qui
--     porte un exemplaire dans son fichier le publie quand même (la source
--     « sans exemplaire » ne jette pas ce que le fichier décrit).
-- T5  La fonction d'aide n'est pas exécutable par anon ni authenticated.
--
-- Bilan OK : 'SANS-EXEMPLAIRE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans role (seed) -> admin reseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_s1 bigint; v_s2 bigint; v_run1 bigint; v_run2 bigint; v_run3 bigint;
  v_l1 bigint; v_l2 bigint; v_l3 bigint;
  v_t1 bigint; v_t2 bigint; v_t3 bigint;
  v_d1 bigint; v_d2 bigint; v_d3 bigint;
  v_b1 bigint; v_b2 bigint; v_b3 bigint;
  v_rev bigint; v_res jsonb; v_txt text; v_n int; v_m int;
BEGIN
  -- Aide de session : promeut la ligne, demande la révision, l'administration
  -- approuve, publie le lot — même chemin que l'écran (fn_import_promote ->
  -- fn_batch_review_request -> fn_batch_review_verdict -> publish_catalog_batch).
  EXECUTE $f$CREATE FUNCTION pg_temp.sxe_publier(p_run bigint, p_row bigint, p_coord uuid, p_admin uuid)
    RETURNS TABLE (o_batch bigint, o_draft bigint, o_book bigint) LANGUAGE plpgsql AS $b$
  DECLARE v_res jsonb; v_rev bigint;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_coord, 'role', 'authenticated')::text, true);
    PERFORM public.fn_import_set_editorial(p_run, ARRAY[p_row], 'accept_new');
    v_res := public.fn_import_promote(p_run, p_row_ids := ARRAY[p_row]);
    o_batch := (v_res->>'batch_id')::bigint;
    SELECT created_book_draft_id INTO o_draft FROM ingest.partner_catalog_staging_rows WHERE id = p_row;
    -- la cote, comme « Cotes manquantes » à l'écran (fn_batch_assign_bib_refs) ou h21_lot0
    UPDATE public.book_drafts SET bib_ref = 'SXE-REF-' || id WHERE id = o_draft AND bib_ref IS NULL;
    v_res := public.fn_batch_review_request(o_batch, 'sans exemplaire : essai');
    v_rev := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_coord, 'role', 'authenticated')::text, true);
    PERFORM public.publish_catalog_batch(o_batch);
    SELECT published_book_id INTO o_book FROM public.book_drafts WHERE id = o_draft;
    RETURN NEXT;
  END $b$;$f$;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "SXE-T-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled, meta)
  VALUES ('SXE archive numerique', v_lib, 'mapeada', 'own_catalog', true, '{"sans_exemplaire": true}'::jsonb) RETURNING id INTO v_s1;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('SXE catalogue ordinaire', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_s2;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_s1, v_lib, 'essai/sxe1.csv', 'sxe1.csv', 'csv', 'ready_for_review') RETURNING id INTO v_run1;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_s2, v_lib, 'essai/sxe2.csv', 'sxe2.csv', 'csv', 'ready_for_review') RETURNING id INTO v_run2;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_s1, v_lib, 'essai/sxe3.csv', 'sxe3.csv', 'csv', 'ready_for_review') RETURNING id INTO v_run3;

  -- une ligne CSV : raw_payload sans item_tag, normalized_payload sans items
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, item_type, match_status, editorial_decision, raw_payload, normalized_payload)
  VALUES (v_run1, 1, 'SXE-1', 'SXE Notice numerique sans exemplaire', 'livro', 'new_record', 'pending',
          '{"cle": "SXE-1", "titre": "SXE Notice numerique sans exemplaire"}'::jsonb, '{}'::jsonb) RETURNING id INTO v_l1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, item_type, match_status, editorial_decision, raw_payload, normalized_payload)
  VALUES (v_run2, 1, 'SXE-2', 'SXE Notice ordinaire avec exemplaire automatique', 'livro', 'new_record', 'pending',
          '{"cle": "SXE-2", "titre": "SXE Notice ordinaire"}'::jsonb, '{}'::jsonb) RETURNING id INTO v_l2;
  -- T4 : une ligne de S1 dont le fichier décrit un exemplaire (H19)
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, item_type, match_status, editorial_decision, raw_payload, normalized_payload)
  VALUES (v_run3, 1, 'SXE-3', 'SXE Notice numerique avec un exemplaire decrit', 'livro', 'new_record', 'pending',
          '{"cle": "SXE-3"}'::jsonb,
          jsonb_build_object('items', '[{"source_item_code":"SXE-C3","call_number":"SXE 3"}]'::jsonb)) RETURNING id INTO v_l3;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 fn_source_sans_exemplaire : S1 vrai (source, run seul), S2 faux, inconnus faux, false explicite faux';
  BEGIN
    v_txt := NULL;
    IF NOT ingest.fn_source_sans_exemplaire(v_run1, v_s1) THEN v_txt := concat_ws(' ; ', v_txt, 'S1 par source_id'); END IF;
    IF NOT ingest.fn_source_sans_exemplaire(v_run1, NULL) THEN v_txt := concat_ws(' ; ', v_txt, 'S1 par le run seul'); END IF;
    IF ingest.fn_source_sans_exemplaire(v_run2, v_s2) THEN v_txt := concat_ws(' ; ', v_txt, 'S2 devrait etre faux'); END IF;
    IF ingest.fn_source_sans_exemplaire(NULL, NULL) THEN v_txt := concat_ws(' ; ', v_txt, 'NULL/NULL devrait etre faux'); END IF;
    IF ingest.fn_source_sans_exemplaire(-1, -1) THEN v_txt := concat_ws(' ; ', v_txt, 'inconnus devraient etre faux'); END IF;
    UPDATE ingest.partner_catalog_sources SET meta = '{"sans_exemplaire": "false"}'::jsonb WHERE id = v_s2;
    IF ingest.fn_source_sans_exemplaire(v_run2, v_s2) THEN v_txt := concat_ws(' ; ', v_txt, 'false explicite devrait etre faux'); END IF;
    UPDATE ingest.partner_catalog_sources SET meta = '{}'::jsonb WHERE id = v_s2;
    IF v_txt IS NULL THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 source sans exemplaire : notice creee, detenue par BLMF, zero exemplaire, aucun tombo consomme';
  BEGIN
    SELECT o_batch, o_draft, o_book INTO v_t1, v_d1, v_b1 FROM pg_temp.sxe_publier(v_run1, v_l1, v_coord, v_admin);
    SELECT count(*) INTO v_n FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_b1;
    SELECT count(*) INTO v_m FROM public.book_holdings h WHERE h.book_id = v_b1 AND h.library_id = v_lib;
    IF v_b1 IS NOT NULL AND v_m = 1 AND v_n = 0
       AND (SELECT status FROM public.book_drafts WHERE id = v_d1) = 'published'
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.bib_ref = (SELECT bib_ref FROM public.books WHERE id = v_b1))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : book='||coalesce(v_b1::text,'NULL')||' holdings='||v_m||' exemplaires='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 source ordinaire, meme chemin : un exemplaire automatique (IMP-25 inchange pour un CSV)';
  BEGIN
    SELECT o_batch, o_draft, o_book INTO v_t2, v_d2, v_b2 FROM pg_temp.sxe_publier(v_run2, v_l2, v_coord, v_admin);
    SELECT count(*) INTO v_n FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_b2 AND e.library_id = v_lib;
    IF v_b2 IS NOT NULL AND v_n = 1
       AND (SELECT e.tombo FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_b2 LIMIT 1) LIKE 'SXE-T-%'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : book='||coalesce(v_b2::text,'NULL')||' exemplaires='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 source sans exemplaire, mais le fichier en decrit un (H19) : il est publie, et lui seul';
  BEGIN
    SELECT o_batch, o_draft, o_book INTO v_t3, v_d3, v_b3 FROM pg_temp.sxe_publier(v_run3, v_l3, v_coord, v_admin);
    SELECT count(*) INTO v_n FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_b3;
    IF v_b3 IS NOT NULL AND v_n = 1
       AND EXISTS (SELECT 1 FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
                    WHERE h.book_id = v_b3 AND e.source_item_code = 'SXE-C3')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : book='||coalesce(v_b3::text,'NULL')||' exemplaires='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 fn_source_sans_exemplaire : ni anon ni authenticated ne peuvent l''executer';
  BEGIN
    IF NOT has_function_privilege('anon', 'ingest.fn_source_sans_exemplaire(bigint, bigint)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'ingest.fn_source_sans_exemplaire(bigint, bigint)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : privilege accorde'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'SANS-EXEMPLAIRE OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'SANS-EXEMPLAIRE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
