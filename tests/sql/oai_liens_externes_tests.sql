-- =====================================================================
-- AnarBib — Tests d'acceptation : le lien de lecture d'une notice
-- moissonnée devient un lien externe du brouillon, puis de la notice ;
-- et dc:contributor arrive en « autre responsabilité », pas en auteur
-- Date    : 2026-10-19
-- Ref     : migration 20261018221318_le_lien_de_lecture_moissonne_devient_un_lien_externe
--           (étape 4 du cadrage fédéralisme ASB ↔ AnarBib, 18/10/2026)
--
-- Décor : BLMF (seed), sa coordination (seed), l'administration du réseau
-- (compte seed sans rôle, promu ici). Une source OAI-PMH dont BLMF est la
-- destination, un run de moisson, trois lignes telles que harvest-oai-pmh
-- les écrit pour du Dublin Core (normalized_payload.external_links et
-- normalized_payload.contributors). Promotion par la coordination de BLMF,
-- faite aussi administratrice du réseau (moisson = geste de réseau, et
-- promouvoir exige d'être bibliothécaire), révision demandée par elle,
-- approuvée par l'autre compte d'administration, lot publié par elle — le
-- chemin de l'écran.
--
-- T1  L1 : deux liens externes au brouillon (http et https gardés, doublon,
--     javascript: et adresse à espace écartés), forme exacte de l'écran
--     (link_externo, publico, text/html, draft), attribués à la source
--     (source_name = attribution_text = nom de la source), droits vides.
-- T2  L2 sans external_links : aucune ressource (rien ne change pour un
--     import ordinaire).
-- T3  L3, sept adresses : cinq gardées, les cinq premières, dans l'ordre.
-- T4  L1 : responsabilités du brouillon — le créateur « autor » principal,
--     la contributrice « outro », non principale, code « dc:contributor ».
-- T5  Après publication : la notice de L1 porte deux ressources
--     link_externo actives et publiques, mêmes adresses, même attribution ;
--     ses contributeurs gardent les rôles (book_contributors).
-- T6  La fonction réécrite reste SECURITY DEFINER, fermée à anon et à
--     authenticated.
-- T7  Ce que voit le PUBLIC (rôle anon, bibliothèque publique) : le badge du
--     catalogue (catalog_digital_access_v1) annonce le lien externe, et le
--     bouton de la notice (get_book_primary_public_digital_asset_v2) le rend.
--     Le lien naît validé (20261019…_le_lien_moissonne_nait_valide) : sans
--     cela, il était publié mais invisible — T1-T5 lisaient les tables et ne
--     le voyaient pas.
--
-- Bilan OK : 'OAI-LIENS OK : N/N'
-- (T7 : migration 20261019115107_le_lien_moissonne_nait_valide)
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans role (seed) -> admin reseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_src bigint; v_run bigint; v_l1 bigint; v_l2 bigint; v_l3 bigint;
  v_d1 bigint; v_d2 bigint; v_d3 bigint; v_b1 bigint; v_batch bigint; v_rev bigint;
  v_res jsonb; v_txt text; v_n int; v_urls text[]; v_usages text[];
  c_source constant text := 'LEX Entrepot de textes';
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, destination_library_id, relation_status, source_kind,
                                              import_enabled, oai_endpoint_url, oai_metadata_prefix)
  VALUES (c_source, v_lib, v_lib, 'mapeada', 'oai_pmh', true, 'https://lex.invalid/oai.php', 'oai_dc') RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'oai/lex/2026-10-19', 'moisson-oai-lex', 'oai_pmh', 'ready_for_review') RETURNING id INTO v_run;

  -- Les lignes, telles que harvest-oai-pmh les écrit pour du Dublin Core.
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, match_status, editorial_decision, raw_payload, normalized_payload)
  VALUES (v_run, 1, 'oai:lex.invalid:texte:1', 'LEX Entre paysans', '["LEX Createur"]'::jsonb, 'new_record', 'pending',
          '{"oai": {"identifier": "oai:lex.invalid:texte:1"}}'::jsonb,
          jsonb_build_object(
            'external_links', jsonb_build_array(
              'https://lex.invalid/lire/entre-paysans', 'javascript:alert(1)',
              'https://lex.invalid/lire/entre-paysans', 'http://lex.invalid/a b', 'HTTP://miroir.invalid/entre-paysans'),
            'contributors', jsonb_build_array(
              jsonb_build_object('name', 'LEX Createur', 'nature', NULL, 'role', 'autor', 'role_code', 'dc:creator', 'primary', true),
              jsonb_build_object('name', 'LEX Contributrice', 'nature', NULL, 'role', 'outro', 'role_code', 'dc:contributor', 'primary', false))))
  RETURNING id INTO v_l1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, raw_payload, normalized_payload)
  VALUES (v_run, 2, 'oai:lex.invalid:texte:2', 'LEX Sans adresse', 'new_record', 'pending', '{}'::jsonb, '{}'::jsonb)
  RETURNING id INTO v_l2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, raw_payload, normalized_payload)
  VALUES (v_run, 3, 'oai:lex.invalid:texte:3', 'LEX Sept adresses', 'new_record', 'pending', '{}'::jsonb,
          jsonb_build_object('external_links', (SELECT jsonb_agg('https://lex.invalid/l/' || g ORDER BY g) FROM generate_series(1, 7) g)))
  RETURNING id INTO v_l3;

  -- Promotion : moisson OAI = geste de réseau (04/09/2026), et promouvoir exige
  -- aussi d'être bibliothécaire de la bibliothèque du run. Comme
  -- import_moisson_oai_admin_tests T4 : la coordination de BLMF est aussi
  -- administratrice du réseau ici. Le verdict de révision reste à un autre compte.
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_coord, 'active') ON CONFLICT DO NOTHING;
  PERFORM public.fn_import_set_editorial(v_run, ARRAY[v_l1, v_l2, v_l3], 'accept_new');
  v_res := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_l1, v_l2, v_l3]);
  v_batch := (v_res->>'batch_id')::bigint;
  SELECT created_book_draft_id INTO v_d1 FROM ingest.partner_catalog_staging_rows WHERE id = v_l1;
  SELECT created_book_draft_id INTO v_d2 FROM ingest.partner_catalog_staging_rows WHERE id = v_l2;
  SELECT created_book_draft_id INTO v_d3 FROM ingest.partner_catalog_staging_rows WHERE id = v_l3;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 L1 : deux liens externes au brouillon, forme de l''ecran, attribues a la source';
  BEGIN
    SELECT array_agg(r.source_url ORDER BY r.id) INTO v_urls FROM public.book_draft_digital_resources r WHERE r.book_draft_id = v_d1;
    SELECT count(*) INTO v_n FROM public.book_draft_digital_resources r
     WHERE r.book_draft_id = v_d1
       AND r.resource_type = 'link_externo' AND r.usage_type = 'link_externo' AND r.access_scope = 'publico'
       AND r.status = 'draft' AND r.is_active AND r.mime_type = 'text/html'
       AND r.source_name = c_source AND r.attribution_text = c_source AND r.label = c_source
       AND r.rights_status IS NULL AND r.storage_bucket IS NULL AND r.storage_path IS NULL
       AND r.metadata->>'staging_row_id' = v_l1::text;
    IF v_d1 IS NOT NULL AND v_n = 2
       AND v_urls = ARRAY['https://lex.invalid/lire/entre-paysans', 'HTTP://miroir.invalid/entre-paysans']
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : draft='||coalesce(v_d1::text,'NULL')||' conformes='||v_n||' urls='||coalesce(v_urls::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 L2 sans external_links : aucune ressource';
  BEGIN
    SELECT count(*) INTO v_n FROM public.book_draft_digital_resources WHERE book_draft_id = v_d2;
    IF v_d2 IS NOT NULL AND v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : draft='||coalesce(v_d2::text,'NULL')||' ressources='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 L3, sept adresses : les cinq premieres, dans l''ordre';
  BEGIN
    SELECT array_agg(r.source_url ORDER BY r.id) INTO v_urls FROM public.book_draft_digital_resources r WHERE r.book_draft_id = v_d3;
    IF v_urls = ARRAY['https://lex.invalid/l/1', 'https://lex.invalid/l/2', 'https://lex.invalid/l/3',
                      'https://lex.invalid/l/4', 'https://lex.invalid/l/5']
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : urls='||coalesce(v_urls::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 L1 : createur autor principal, contributrice outro non principale (dc:contributor)';
  BEGIN
    SELECT string_agg(c.name||'/'||c.role||'/'||c.is_primary||'/'||coalesce(c.role_code, '-'), ' ; ' ORDER BY c.position)
      INTO v_txt FROM public.book_draft_contributors c WHERE c.draft_id = v_d1;
    IF v_txt = 'LEX Createur/autor/true/dc:creator ; LEX Contributrice/outro/false/dc:contributor'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt, 'aucun contributeur')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 publication : deux liens externes actifs et publics sur la notice, roles gardes';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    UPDATE public.book_drafts SET bib_ref = 'LEX-REF-' || id WHERE batch_id = v_batch AND bib_ref IS NULL;
    v_res := public.fn_batch_review_request(v_batch, 'liens externes : essai');
    v_rev := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.publish_catalog_batch(v_batch);
    SELECT published_book_id INTO v_b1 FROM public.book_drafts WHERE id = v_d1;

    SELECT array_agg(r.source_url ORDER BY r.id) INTO v_urls FROM public.book_digital_resources r
     WHERE r.book_id = v_b1 AND r.resource_type = 'link_externo' AND r.usage_type = 'link_externo'
       AND r.access_scope = 'publico' AND r.status = 'active' AND r.is_active
       AND r.attribution_text = c_source AND r.source_name = c_source;
    SELECT string_agg(c.name||'/'||c.role, ' ; ' ORDER BY c.position) INTO v_txt
      FROM public.book_contributors c WHERE c.book_id = v_b1;
    IF v_b1 IS NOT NULL
       AND v_urls = ARRAY['https://lex.invalid/lire/entre-paysans', 'HTTP://miroir.invalid/entre-paysans']
       AND v_txt = 'LEX Createur/autor ; LEX Contributrice/outro'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : book='||coalesce(v_b1::text,'NULL')||' urls='||coalesce(v_urls::text,'NULL')||' contributeurs='||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 fn_create_book_drafts_from_import_rows : SECURITY DEFINER, fermee a anon et authenticated';
  BEGIN
    IF (SELECT prosecdef FROM pg_proc WHERE oid = 'ingest.fn_create_book_drafts_from_import_rows(bigint,bigint[],text,text,uuid)'::regprocedure)
       AND NOT has_function_privilege('anon', 'ingest.fn_create_book_drafts_from_import_rows(bigint,bigint[],text,text,uuid)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'ingest.fn_create_book_drafts_from_import_rows(bigint,bigint[],text,text,uuid)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : droits ou enveloppe changes'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 le public voit le lien : badge du catalogue et bouton de la notice, sous le role anon';
  BEGIN
    UPDATE public.libraries SET visibility_level = 'public', network_mode = 'federated', is_active = true WHERE id = v_lib;
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT a.public_usages INTO v_usages FROM public.catalog_digital_access_v1(ARRAY[v_b1]) a WHERE a.book_id = v_b1;
    SELECT p.source_url INTO v_txt FROM public.get_book_primary_public_digital_asset_v2(v_b1) p;
    EXECUTE 'RESET ROLE';
    IF 'link_externo' = ANY (coalesce(v_usages, '{}'::text[]))
       AND v_txt IN ('https://lex.invalid/lire/entre-paysans', 'HTTP://miroir.invalid/entre-paysans')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : usages='||coalesce(v_usages::text,'NULL')||' bouton='||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'OAI-LIENS OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'OAI-LIENS ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
