-- =====================================================================
-- AnarBib — Tests d'acceptation : l'identifiant d'origine d'une notice est
-- gardé PAR bibliothèque (H20, aller-retour PMB)
-- Date    : 2026-09-27
-- Ref     : migration 20260928111812_h20_l_identifiant_d_origine_par_bibliotheque
--
-- T1 une notice importée garde son 001, à la bibliothèque qui la publie
--    (source_record_id, marc_json.ingest.source_id, book_external_ids).
-- T2 sans 001 : aucun identifiant — jamais le numéro de la ligne de staging.
-- T3 un exemplaire rapproché d'une notice d'une AUTRE bibliothèque : le 001
--    est gardé pour la bibliothèque qui importe, la notice partagée intacte.
-- T4 unicité par (bibliothèque, schéma, valeur) ; même numéro dans deux
--    bibliothèques ; réclamé par une autre notice : il reste à la première.
-- T5 lecture : le staff de sa bibliothèque, l'administration ; personne
--    d'autre, ni anon ; aucune écriture par l'API.
-- T6 les faux identifiants (numéro de ligne) des brouillons en cours sont
--    effacés ; un vrai, et un brouillon publié, restent.
-- T7 reprise des notices déjà publiées depuis un import ; rejouée : rien de
--    plus ; un brouillon de reprise d'une autre bibliothèque ne donne rien.
-- T8 fusion de notices (merge_book) : les identifiants du doublon, de chaque
--    bibliothèque, passent à la notice gardée.
-- T9 à l'import, une clé que portent deux lignes du run est effacée des
--    brouillons ; le numéro d'un fascicule (CSV de périodiques) aussi ; le
--    numéro d'un CSV qui n'est pas de périodiques reste.
-- T10 un brouillon importé absorbé par une fiche existante lui laisse son 001.
-- T11 fusion de brouillons : à la publication du survivant, le 001 du perdant
--    est posé aussi ; la source se relit dans le run quand le brouillon ne la
--    porte pas.
-- T12 un run ne se supprime pas tant qu'un exemplaire rapproché l'attend.
-- T13 une clé égale par hasard au numéro de sa ligne de staging, que la ligne
--    porte vraiment, reste un identifiant.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'IDENTIFIANT-ORIGINE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- admin reseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid; v_libBibB uuid;
  v_src bigint; v_run bigint; v_run2 bigint; v_lot bigint; v_lot2 bigint; v_res jsonb;
  v_d1 bigint; v_d2 bigint; v_book1 bigint; v_book2 bigint; v_bookB bigint; v_row bigint;
  v_x bigint; v_id bigint; v_id2 bigint; v_id3 bigint; v_n int; v_m int; v_k int; v_ok boolean; v_txt text;
  v_run3 bigint; v_lot3 bigint; v_r1 bigint; v_r2 bigint; v_r3 bigint; v_r4 bigint; v_r5 bigint; v_r6 bigint;
  v_bookX bigint; v_bookY bigint; v_bookZ bigint; v_book5 bigint; v_book6 bigint; v_run4 bigint; v_row4 bigint; v_x4 bigint;
BEGIN
  -- ── Décor ───────────────────────────────────────────────────────────
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "H20-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-h20-b', 'Essai H20 — B', true, 'private') RETURNING id INTO v_libB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h20-b-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_libBibB;
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_libBibB, 'Essai', 'H20') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_libBibB, v_libB, 'librarian', 'active', true);

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai H20 PMB', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h20.marc', 'h20.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 1, 'PMB-001', 'H20 Avec son 001', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run, 2, NULL, 'H20 Sans 001', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb));

  -- ── T1 / T2 ─────────────────────────────────────────────────────────
  v_t := 'T1 une notice importee garde son 001 a la bibliotheque qui la publie ; T2 sans 001, rien';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot := (v_res->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d1 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 1;
    SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 2;
    UPDATE public.book_drafts SET bib_ref = 'H20-A-' || id, tipo_material = 'livro' WHERE id IN (v_d1, v_d2);
    v_ok := (SELECT source_record_id FROM public.book_drafts WHERE id = v_d1) = 'PMB-001'
            AND (SELECT (marc_json->'ingest'->>'source_id')::bigint FROM public.book_drafts WHERE id = v_d1) = v_src
            AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_d2) IS NULL;
    v_res := public.fn_batch_review_request(v_lot);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_book1 := public.publish_book_draft(v_d1);
    v_book2 := public.publish_book_draft(v_d2);
    IF v_ok
       AND (SELECT count(*) FROM public.book_external_ids e
             WHERE e.book_id = v_book1 AND e.library_id = v_lib AND e.scheme = 'import:' || v_src
               AND e.value = 'PMB-001' AND e.source_id = v_src) = 1
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.book_id = v_book2)
       AND (SELECT source_record_id FROM public.books WHERE id = v_book2) IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : brouillons='||coalesce(v_ok::text,'∅')
         ||' lignes='||(SELECT count(*) FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 un exemplaire rapproche d''une notice d''une autre bibliotheque : le 001 gardé pour qui importe';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, source_record_id)
    VALUES ('H20 Notice de B', 'H20-B-1', 'livro', v_libB, 'ORIGINE-DE-B') RETURNING id INTO v_bookB;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bookB, v_libB);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h20b.marc', 'h20b.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run2;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run2, 1, 'PMB-777', 'H20 Notice de B (doublon)', 'matched_book', 'accept_duplicate', v_bookB,
            jsonb_build_object('items', '[{"source_item_code":"H20-X1","call_number":"A"}]'::jsonb))
    RETURNING id INTO v_row;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := ingest.fn_create_exemplar_drafts_from_import_rows(v_run2, ARRAY[v_row]);
    v_lot2 := (v_res->>'batch_id')::bigint;
    SELECT min(id) INTO v_x FROM public.exemplar_drafts WHERE import_staging_row_id = v_row;
    -- aucun identifiant avant la publication
    v_n := (SELECT count(*) FROM public.book_external_ids WHERE book_id = v_bookB);
    PERFORM public.publish_exemplar_draft(v_x);
    IF v_n = 0
       AND (SELECT count(*) FROM public.book_external_ids e
             WHERE e.book_id = v_bookB AND e.library_id = v_lib AND e.scheme = 'import:' || v_src AND e.value = 'PMB-777') = 1
       AND (SELECT source_record_id FROM public.books WHERE id = v_bookB) = 'ORIGINE-DE-B'
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.book_id = v_bookB AND e.library_id = v_libB)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avant='||v_n||' apres='
         ||(SELECT count(*) FROM public.book_external_ids WHERE book_id = v_bookB)||' origine B='
         ||coalesce((SELECT source_record_id FROM public.books WHERE id = v_bookB),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 unicite par (bibliotheque, schema, valeur) ; deux bibliotheques ; reclame par une autre notice : reste a la premiere';
  BEGIN
    -- le même numéro, pour B : une seconde ligne
    PERFORM ingest.fn_record_book_external_id(v_bookB, v_libB, v_src, 'PMB-001');
    -- le numéro de A réclamé par une autre notice : il ne passe pas d'une
    -- notice à l'autre (revue du 28/09 : la dernière publiée l'emportait)
    PERFORM ingest.fn_record_book_external_id(v_book2, v_lib, v_src, '  PMB-001 ');
    -- sans valeur, sans bibliothèque, sans source : rien
    PERFORM ingest.fn_record_book_external_id(v_book1, v_lib, v_src, '   ');
    PERFORM ingest.fn_record_book_external_id(v_book1, NULL, v_src, 'PMB-X');
    PERFORM ingest.fn_record_book_external_id(v_book1, v_lib, NULL, 'PMB-Y');
    IF (SELECT count(*) FROM public.book_external_ids WHERE scheme = 'import:' || v_src AND value = 'PMB-001') = 2
       AND (SELECT book_id FROM public.book_external_ids WHERE library_id = v_lib AND scheme = 'import:' || v_src AND value = 'PMB-001') = v_book1
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids WHERE value IN ('PMB-X', 'PMB-Y', ''))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||(SELECT string_agg(library_id::text||'/'||value||'->'||book_id, ', ') FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2, v_bookB))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 lecture : staff de sa bibliotheque, administration ; ni les autres, ni anon ; pas d''ecriture par l''API';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) FILTER (WHERE library_id = v_lib), count(*) FILTER (WHERE library_id = v_libB) INTO v_n, v_m
      FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2, v_bookB);
    v_txt := NULL;
    BEGIN
      INSERT INTO public.book_external_ids (book_id, library_id, scheme, value) VALUES (v_book1, v_lib, 'import:1', 'FORGE');
      v_txt := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE;
    END;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) FILTER (WHERE library_id = v_lib) INTO v_k FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2, v_bookB);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_id FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2, v_bookB);
    EXECUTE 'RESET ROLE';
    IF v_n = 2 AND v_m = 0 AND v_k = 0 AND v_id = 3 AND v_txt = '42501'
       AND NOT has_table_privilege('anon', 'public.book_external_ids', 'SELECT')
       AND NOT has_function_privilege('authenticated', 'ingest.fn_record_book_external_id(bigint,uuid,bigint,text)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'ingest.fn_record_book_external_id(bigint,uuid,bigint,text)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA A='||v_n||' B='||v_m||' libB voit A='||v_k||' admin='||v_id||' insert='||coalesce(v_txt,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 faux identifiants (numero de ligne) des brouillons non publies effaces ; un vrai, un publie, restent';
  BEGIN
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Faux', 'livro', v_lib, v_coord, 'draft', '424242', '{"ingest": {"staging_row_id": 424242}}'::jsonb) RETURNING id INTO v_id;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Vrai', 'livro', v_lib, v_coord, 'ready', 'PMB-9', '{"ingest": {"staging_row_id": 424243}}'::jsonb) RETURNING id INTO v_id2;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Faux jete', 'livro', v_lib, v_coord, 'cancelled', '424244', '{"ingest": {"staging_row_id": 424244}}'::jsonb) RETURNING id INTO v_id3;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Faux publie', 'livro', v_lib, v_coord, 'published', '424245', '{"ingest": {"staging_row_id": 424245}}'::jsonb) RETURNING id INTO v_x;
    v_n := ingest.fn_h20_effacer_faux_identifiants();
    IF v_n >= 2
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id3) IS NULL
       -- le miroir de marc_json (anarbib_provenance) aussi, sinon le pont le rend
       AND (SELECT marc_json->'anarbib_provenance'->>'source_record_id' FROM public.book_drafts WHERE id = v_id) IS NULL
       AND (SELECT marc_json->'anarbib_provenance'->>'source_record_id' FROM public.book_drafts WHERE id = v_id2) = 'PMB-9'
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id2) = 'PMB-9'
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_x) = '424245'
       AND ingest.fn_h20_effacer_faux_identifiants() = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : effaces='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 reprise des notices deja publiees depuis un import ; rejouee : rien de plus';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Publiee avant', 'H20-AVANT-1', 'livro') RETURNING id INTO v_id;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, published_book_id, marc_json)
    VALUES ('H20 Publiee avant', 'livro', v_lib, v_coord, 'published', 'PMB-555', v_id,
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'staging_row_id', 999999))) RETURNING id INTO v_id2;
    -- et une publiée dont l'« identifiant » est le numéro de sa ligne : pas reprise
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Publiee faux', 'H20-AVANT-2', 'livro') RETURNING id INTO v_id3;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, published_book_id, marc_json)
    VALUES ('H20 Publiee faux', 'livro', v_lib, v_coord, 'published', '888888', v_id3,
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'staging_row_id', 888888)));
    -- un brouillon de REPRISE publié par une autre bibliothèque recopie le
    -- marc_json et le source_record_id de la notice : il ne donne rien à B
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, action, source_record_id, published_book_id, marc_json)
    VALUES ('H20 Publiee avant (reprise de B)', 'livro', v_libB, v_libBibB, 'published', 'update', 'PMB-555', v_id,
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'staging_row_id', 999999)));
    v_n := ingest.fn_h20_reprise_identifiants();
    v_m := ingest.fn_h20_reprise_identifiants();
    IF v_n >= 1 AND v_m = 0
       AND (SELECT count(*) FROM public.book_external_ids e
             WHERE e.book_id = v_id AND e.library_id = v_lib AND e.scheme = 'import:' || v_src AND e.value = 'PMB-555') = 1
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.book_id = v_id AND e.library_id = v_libB)
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.book_id = v_id3)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : reprise='||v_n||' rejouee='||v_m
         ||' B='||(SELECT count(*) FROM public.book_external_ids e WHERE e.book_id = v_id AND e.library_id = v_libB)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 fusion de notices : les identifiants du doublon, de chaque bibliotheque, passent a la notice gardee';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Gardee', 'H20-X-1', 'livro') RETURNING id INTO v_bookX;
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Doublon', 'H20-Y-1', 'livro') RETURNING id INTO v_bookY;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bookX, v_lib), (v_bookY, v_lib);
    PERFORM ingest.fn_record_book_external_id(v_bookY, v_lib, v_src, 'PMB-Y1');
    PERFORM ingest.fn_record_book_external_id(v_bookY, v_libB, v_src, 'PMB-Y1');
    PERFORM ingest.fn_record_book_external_id(v_bookX, v_lib, v_src, 'PMB-X1');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.merge_book(v_bookX, v_bookY);
    IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = v_bookY)
       AND (SELECT count(*) FROM public.book_external_ids WHERE book_id = v_bookX) = 3
       AND (SELECT count(*) FROM public.book_external_ids WHERE value = 'PMB-Y1' AND book_id = v_bookX) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||coalesce((SELECT string_agg(library_id::text||'/'||value||'->'||book_id, ', ') FROM public.book_external_ids WHERE value LIKE 'PMB-_1'),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Décor de T9 à T13 : un run de six lignes ─────────────────────────
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h20c.marc', 'h20c.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run3, 1, 'N-12', 'H20 Fascicule 12 (a)', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 2, 'N-12', 'H20 Fascicule 12 (b)', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 3, 'PMB-310', 'H20 Absorbee par une fiche', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 4, 'PMB-410', 'H20 Brouillon perdant', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 5, 'PMB-510', 'H20 Brouillon survivant', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 6, NULL, 'H20 Cle egale a sa ligne', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb));
  UPDATE ingest.partner_catalog_staging_rows SET external_key = id::text WHERE run_id = v_run3 AND row_no = 6;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  v_res := public.fn_import_promote(v_run3, ARRAY['new_record'], ARRAY['accept_new']);
  v_lot3 := (v_res->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_r1 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 1;
  SELECT m.draft_id INTO v_r2 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 2;
  SELECT m.draft_id INTO v_r3 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 3;
  SELECT m.draft_id INTO v_r4 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 4;
  SELECT m.draft_id INTO v_r5 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 5;
  SELECT m.draft_id INTO v_r6 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 6;
  UPDATE public.book_drafts SET bib_ref = 'H20-C-' || id, tipo_material = 'livro' WHERE id IN (v_r1, v_r2, v_r3, v_r4, v_r5, v_r6);

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 cle portee par deux lignes du run, numero de fascicule : effaces a l''import ; numero d''un CSV sans periodique : garde';
  BEGIN
    -- le numéro d'un fascicule (CSV de périodiques, lot 63) ; celui d'un CSV
    -- de livres (MLEG, run 3 en production) reste
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Fascicule CSV', 'livro', v_lib, v_coord, 'draft', '7',
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run3, 'staging_row_id', 777001, 'detected_format', 'csv',
              'raw_payload', jsonb_build_object('numero', '7', 'periodico', 'Le Rat des bibliotheques')))) RETURNING id INTO v_id;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Livre CSV', 'livro', v_lib, v_coord, 'draft', '8',
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run3, 'staging_row_id', 777002, 'detected_format', 'csv',
              'raw_payload', jsonb_build_object('numero', '8', 'titulo_livro', 'Un livre')))) RETURNING id INTO v_id2;
    v_n := ingest.fn_h20_effacer_faux_identifiants(v_run3);
    IF (SELECT source_record_id FROM public.book_drafts WHERE id = v_r1) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_r2) IS NULL
       AND (SELECT marc_json->'anarbib_provenance'->>'source_record_id' FROM public.book_drafts WHERE id = v_r2) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_r3) = 'PMB-310'
       AND v_n = 1
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id2) = '8'
       AND ingest.fn_h20_identifiant_d_origine(v_id2) = '8'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lignes 1/2='
         ||coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_r1),'∅')||'/'
         ||coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_r2),'∅')||' effaces='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 un brouillon importe absorbe par une fiche existante lui laisse son 001';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Fiche existante', 'H20-Z-1', 'livro') RETURNING id INTO v_bookZ;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM api.merge_draft_into_book(v_r3, v_bookZ, '{}'::jsonb);
    IF (SELECT status FROM public.book_drafts WHERE id = v_r3) = 'cancelled'
       AND (SELECT count(*) FROM public.book_external_ids e
             WHERE e.book_id = v_bookZ AND e.library_id = v_lib AND e.scheme = 'import:' || v_src AND e.value = 'PMB-310') = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||(SELECT count(*) FROM public.book_external_ids WHERE book_id = v_bookZ)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 / T13 ───────────────────────────────────────────────────────
  v_t := 'T11 fusion de brouillons : le 001 du perdant pose a la publication du survivant, source relue dans le run ; T13 cle egale a sa ligne, que la ligne porte';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM api.merge_book_drafts(v_r5, v_r4, '{}'::jsonb);
    -- un brouillon d'avant H20 : sa source n'est que dans le run
    UPDATE public.book_drafts SET marc_json = marc_json #- '{ingest,source_id}' WHERE id = v_r5;
    v_ok := (SELECT source_record_id FROM public.book_drafts WHERE id = v_r6)
              = (SELECT id::text FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run3 AND row_no = 6)
            AND NOT (SELECT marc_json->'ingest' ? 'source_id' FROM public.book_drafts WHERE id = v_r5);
    v_res := public.fn_batch_review_request(v_lot3);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_book5 := public.publish_book_draft(v_r5);
    v_book6 := public.publish_book_draft(v_r6);
    IF v_ok
       AND (SELECT string_agg(e.value, ',' ORDER BY e.value) FROM public.book_external_ids e
             WHERE e.book_id = v_book5 AND e.library_id = v_lib AND e.scheme = 'import:' || v_src AND e.source_id = v_src) = 'PMB-410,PMB-510'
       AND (SELECT e.value FROM public.book_external_ids e WHERE e.book_id = v_book6)
           = (SELECT id::text FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run3 AND row_no = 6)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : brouillons='||coalesce(v_ok::text,'∅')||' survivant='
         ||coalesce((SELECT string_agg(value, ',') FROM public.book_external_ids WHERE book_id = v_book5),'∅')||' cle-ligne='
         ||coalesce((SELECT string_agg(value, ',') FROM public.book_external_ids WHERE book_id = v_book6),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 un run ne se supprime pas tant qu''un exemplaire rapproche l''attend ; ecarte : il se supprime';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h20d.marc', 'h20d.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run4;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run4, 1, 'PMB-888', 'H20 Notice de B (autre doublon)', 'matched_book', 'accept_duplicate', v_bookB,
            jsonb_build_object('items', '[{"source_item_code":"H20-X8","call_number":"B"}]'::jsonb))
    RETURNING id INTO v_row4;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM ingest.fn_create_exemplar_drafts_from_import_rows(v_run4, ARRAY[v_row4]);
    SELECT min(id) INTO v_x4 FROM public.exemplar_drafts WHERE import_staging_row_id = v_row4;
    v_txt := NULL;
    BEGIN
      PERFORM public.fn_import_delete_run(v_run4);
      v_txt := 'supprime';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT;
    END;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x4;
    v_res := public.fn_import_delete_run(v_run4);
    IF v_x4 IS NOT NULL AND v_txt = 'error.import.run_has_drafts'
       AND coalesce((v_res->>'ok')::boolean, false)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run4)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaire='||coalesce(v_x4::text,'∅')||' refus='||coalesce(v_txt,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IDENTIFIANT-ORIGINE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IDENTIFIANT-ORIGINE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
