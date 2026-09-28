-- =====================================================================
-- AnarBib — Tests d'acceptation : l'import reprend les zones courantes et
-- les responsabilités d'un catalogue PMB (H17, H18, H22 — aller-retour PMB)
-- Date    : 2026-09-27
-- Ref     : migration 20260928111814_h17_h18_l_import_reprend_zones_et_responsabilites
--
-- T1  notice MARC : type, pages, volume, collection, notes, classification,
--     adresse (en note pour un livre), responsabilités structurées.
-- T2  article dépouillé : périodique hôte, fascicule, pages, date.
-- T3  périodique : titre clé ; ressource numérique : adresse dans son champ.
-- T4  CSV / RIS : les noms, en auteur·rice, la première principale.
-- T5  rôle et nature hors vocabulaire : « outro », nature inconnue.
-- T6  publication puis reprise : nature et code d'origine suivent.
-- T7  rattrapage des brouillons importés en cours sans contributeur ;
--     rejoué : rien ; un brouillon pourvu, un publié, intacts.
-- T8  rapprochements proposés en révision, jamais appliqués ; refus à qui
--     n'est pas staff de la bibliothèque du lot ; anon exclu.
-- T9  le format pmb_xml est admis (H22).
-- T10 (revue du 28/09) auteurs en objets (recherche institutionnelle, paquet
--     de fonds) : leur nom, leur rôle AnarBib ; jamais un non-agent, positions
--     renumérotées ; un fascicule garde numéro et date.
-- T11 la recherche par nom en une passe rend ce que la recherche nom par nom
--     rend ; un congrès qualifié trouve son autorité nue ; la limite porte sur
--     les propositions ; le rapport du lot s'ouvre et compte pareil.
-- T12 la reprise d'une notice recopie ce que la publication réécrit (article,
--     thèse, zine…) : republier ne l'efface plus.
-- T13 la scission d'autorité garde la nature de la part et le code d'origine.
-- T14 la fusion de notices aussi (fn_fusion_notices, sous merge_book).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-ZONES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid; v_libBibB uuid;
  v_src bigint; v_run bigint; v_lot bigint; v_res jsonb;
  v_d1 bigint; v_d2 bigint; v_d3 bigint; v_d4 bigint; v_d5 bigint; v_d6 bigint;
  v_book bigint; v_rep bigint; v_aut bigint; v_id bigint; v_id2 bigint; v_id3 bigint;
  v_n int; v_m int; v_ok boolean; v_txt text; v_hint text;
  v_d7 bigint; v_d8 bigint; v_d9 bigint; v_d10 bigint; v_rap jsonb; v_b12 bigint; v_r12 bigint; v_aut2 bigint; v_k int;
  v_contrib jsonb := '[
    {"name":"Černá, Zdeňka","nature":"person","role":"autor","role_code":"070","primary":true,"dates":"1950-....","tag":"700"},
    {"name":"Collectif Brûlot","nature":"collective","role":"autor","role_code":"070","primary":true,"tag":"710"},
    {"name":"Muñoz, Pilar","nature":"person","role":"tradutor","role_code":"730","primary":false,"tag":"702"},
    {"name":"Congrès anarchiste (3 ; 1907 ; Amsterdam)","nature":"congress","role":"autor","role_code":null,"primary":false,"tag":"711"}
  ]'::jsonb;
BEGIN
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-h18-b', 'Essai H18 — B', true, 'private') RETURNING id INTO v_libB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h18-b-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_libBibB;
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_libBibB, 'Essai', 'H18') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_libBibB, v_libB, 'librarian', 'active', true);

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai H18 PMB', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h18.marc', 'h18.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, item_type, authors, subjects, match_status, editorial_decision, normalized_payload)
  VALUES
    (v_run, 1, 'H18-1', 'Des bourses du travail', 'am', '["Černá, Zdeňka","Collectif Brûlot"]'::jsonb, '["Anarchisme -- Histoire"]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb, 'material_type', 'livro', 'extent', '352 p.', 'pages', 352,
       'volume', 'Tome 2 : Les coopératives', 'series', 'Mémoires sociales ; 7', 'notes', E'Résumé\n\nNote générale',
       'classification', '334.7', 'url', 'https://example.org/h18', 'contributors', v_contrib)),
    (v_run, 2, 'H18-2', 'Classer sans dominer', 'aa', '[]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb, 'material_type', 'artigo', 'extent', 'p. 4-9',
       'host', jsonb_build_object('title', 'Le Rat des bibliothèques', 'issn', '2555-0004', 'volume', '3'),
       'issue', jsonb_build_object('number', '12', 'date', '2025-03-01', 'title', 'Printemps 2025'))),
    (v_run, 3, 'H18-3', 'Le Rat des bibliothèques', 'as', '[]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb, 'material_type', 'periodico', 'key_title', 'Rat des bibliothèques (Le)')),
    (v_run, 4, 'H18-4', 'Une ressource en ligne', 'lm', '[]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb, 'material_type', 'recurso_digital', 'url', 'https://example.org/en-ligne')),
    (v_run, 5, 'H18-5', 'Venue d''un CSV', NULL, '["Reclus, Élisée","Kropotkine, Pierre"]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb)),
    (v_run, 6, 'H18-6', 'Rôle inconnu', 'am', '[]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb, 'material_type', 'inventé',
       'contributors', '[{"name":"Anonyme, A.","nature":"extraterrestre","role":"bourreau","role_code":"999"}, {"name":"  "}, "pas un objet"]'::jsonb)),
    -- T10 : recherche institutionnelle (objets {label}) ; paquet de fonds ({name, role}) ;
    -- un non-agent devant un vrai nom ; un fascicule de périodique
    (v_run, 7, 'H18-7', 'Venue de la recherche', NULL, '[{"label":"Kropotkin, Peter","role":"author","authority_ids":{}}]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb)),
    (v_run, 8, 'H18-8', 'Venue d''un paquet', NULL, '[{"name":"Reclus, Élisée","role":"tradutor","ord":2}]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb)),
    (v_run, 9, 'H18-9', 'Collectif et une personne', NULL, '["Collectif","Kropotkine, Piotr"]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb, 'contributors',
       '[{"name":"Collectif","nature":"collective","role":"autor","primary":true},{"name":"Kropotkine, Piotr","nature":"person","role":"autor","primary":false}]'::jsonb)),
    (v_run, 10, 'H18-10', 'Géo', 'as', '[]'::jsonb, '[]'::jsonb, 'new_record', 'accept_new',
     jsonb_build_object('items', '[]'::jsonb, 'material_type', 'periodico', 'key_title', 'Géo', 'volume', '277',
       'issue', jsonb_build_object('number', '277', 'date', '2004-08-04')));

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
  v_lot := (v_res->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d1 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 1;
  SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 2;
  SELECT m.draft_id INTO v_d3 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 3;
  SELECT m.draft_id INTO v_d4 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 4;
  SELECT m.draft_id INTO v_d5 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 5;
  SELECT m.draft_id INTO v_d6 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 6;
  SELECT m.draft_id INTO v_d7 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 7;
  SELECT m.draft_id INTO v_d8 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 8;
  SELECT m.draft_id INTO v_d9 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 9;
  SELECT m.draft_id INTO v_d10 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 10;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 notice MARC : type, pages, volume, collection, notes, classification, adresse en note, responsabilites';
  BEGIN
    SELECT d.tipo_material = 'livro' AND d.paginas = 352 AND d.volume = 'Tome 2 : Les coopératives'
       AND d.colecao = 'Mémoires sociales ; 7' AND d.cdd = '334.7' AND d.digital_native_url IS NULL
       AND d.notas LIKE E'Résumé\n\nNote générale\n\nEndereço eletrônico: https://example.org/h18\n\nAssuntos importados: Anarchisme -- Histoire%'
      INTO v_ok FROM public.book_drafts d WHERE d.id = v_d1;
    SELECT string_agg(c.position || ':' || c.name || '|' || coalesce(c.nature, '∅') || '|' || c.role || '|' || coalesce(c.role_code, '∅') || '|' || c.is_primary, ' ; ' ORDER BY c.position)
      INTO v_txt FROM public.book_draft_contributors c WHERE c.draft_id = v_d1;
    IF coalesce(v_ok, false)
       AND v_txt = '1:Černá, Zdeňka|person|autor|070|true ; 2:Collectif Brûlot|collective|autor|070|false ; '
                || '3:Muñoz, Pilar|person|tradutor|730|false ; 4:Congrès anarchiste (3 ; 1907 ; Amsterdam)|congress|autor|∅|false'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : champs='||coalesce(v_ok::text,'∅')||' contributeurs='||coalesce(v_txt,'∅')
         ||' notas='||coalesce((SELECT left(notas, 200) FROM public.book_drafts WHERE id = v_d1),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 / T3 ─────────────────────────────────────────────────────────
  v_t := 'T2 article : periodique hote, fascicule, pages, date ; T3 periodique : titre cle ; ressource numerique : son adresse';
  BEGIN
    IF (SELECT d.tipo_material = 'artigo' AND d.artigo_source = 'Le Rat des bibliothèques' AND d.artigo_volume = '3'
               AND d.artigo_issue = '12' AND d.artigo_pages = 'p. 4-9' AND d.data_edicao = '2025-03-01' AND d.paginas IS NULL
               AND d.issn = '2555-0004' AND d.colecao IS NULL
          FROM public.book_drafts d WHERE d.id = v_d2)
       AND (SELECT d.tipo_material = 'periodico' AND d.titulo_periodico = 'Rat des bibliothèques (Le)' FROM public.book_drafts d WHERE d.id = v_d3)
       AND (SELECT d.tipo_material = 'recurso_digital' AND d.digital_native_url = 'https://example.org/en-ligne'
                   AND coalesce(d.notas, '') NOT LIKE '%Endereço%' FROM public.book_drafts d WHERE d.id = v_d4)
       AND (SELECT d.artigo_source IS NULL AND d.titulo_periodico IS NULL FROM public.book_drafts d WHERE d.id = v_d1)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||coalesce((SELECT to_jsonb(d) - 'marc_json' FROM public.book_drafts d WHERE d.id = v_d2)::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 / T5 ─────────────────────────────────────────────────────────
  v_t := 'T4 CSV : les noms en auteur·rice ; T5 role et nature hors vocabulaire, entrees vides ignorees';
  BEGIN
    SELECT string_agg(c.position || ':' || c.name || '|' || c.role || '|' || c.is_primary || '|' || coalesce(c.nature, '∅'), ' ; ' ORDER BY c.position)
      INTO v_txt FROM public.book_draft_contributors c WHERE c.draft_id = v_d5;
    IF v_txt = '1:Reclus, Élisée|autor|true|∅ ; 2:Kropotkine, Pierre|autor|false|∅'
       AND (SELECT string_agg(c.name || '|' || c.role || '|' || coalesce(c.nature, '∅') || '|' || coalesce(c.role_code, '∅'), ' ; ')
              FROM public.book_draft_contributors c WHERE c.draft_id = v_d6) = 'Anonyme, A.|outro|∅|999'
       AND (SELECT tipo_material FROM public.book_drafts WHERE id = v_d6) = 'livro'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : csv='||coalesce(v_txt,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 publication puis reprise : nature et code d''origine suivent';
  BEGIN
    UPDATE public.book_drafts SET bib_ref = 'H18-A-' || id WHERE id = v_d1;
    v_res := public.fn_batch_review_request(v_lot);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_book := public.publish_book_draft(v_d1);
    SELECT string_agg(c.name || '|' || coalesce(c.nature, '∅') || '|' || coalesce(c.role_code, '∅'), ' ; ' ORDER BY c.position)
      INTO v_txt FROM public.book_contributors c WHERE c.book_id = v_book;
    v_rep := public.create_book_draft_from_book(v_book, NULL);
    IF v_txt = 'Černá, Zdeňka|person|070 ; Collectif Brûlot|collective|070 ; Muñoz, Pilar|person|730 ; Congrès anarchiste (3 ; 1907 ; Amsterdam)|congress|∅'
       AND (SELECT string_agg(c.name || '|' || coalesce(c.nature, '∅') || '|' || coalesce(c.role_code, '∅'), ' ; ' ORDER BY c.position)
              FROM public.book_draft_contributors c WHERE c.draft_id = v_rep) = v_txt
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : publie='||coalesce(v_txt,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 rattrapage des brouillons importes sans contributeur ; rejoue : rien ; pourvus et publies intacts';
  BEGIN
    -- noms seuls (CSV d'avant H18)
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, marc_json)
    VALUES ('H18 Sans contributeur', 'livro', v_lib, v_coord, 'draft',
            '{"ingest": {"authors": ["Goldman, Emma", " ", "Berkman, Alexander"]}}'::jsonb) RETURNING id INTO v_id;
    -- structurés (MARC)
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, marc_json)
    VALUES ('H18 Structure', 'livro', v_lib, v_coord, 'ready',
            jsonb_build_object('ingest', '{"authors": ["ignoré"]}'::jsonb,
              'contributors', '[{"name":"Lamb, Marie","nature":"person","role":"ilustrador","role_code":"440"}]'::jsonb)) RETURNING id INTO v_id2;
    -- déjà pourvu à la main ; et un publié
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, marc_json)
    VALUES ('H18 Pourvu', 'livro', v_lib, v_coord, 'draft', '{"ingest": {"authors": ["Ne pas créer"]}}'::jsonb) RETURNING id INTO v_id3;
    INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary) VALUES (v_id3, 1, 'Saisi, À la main', 'autor', true);
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, marc_json)
    VALUES ('H18 Publie', 'livro', v_lib, v_coord, 'published', '{"ingest": {"authors": ["Ne pas créer non plus"]}}'::jsonb) RETURNING id INTO v_aut;
    v_n := ingest.fn_h18_contributeurs_des_brouillons_importes();
    v_m := ingest.fn_h18_contributeurs_des_brouillons_importes();
    IF v_n >= 3 AND v_m = 0
       AND (SELECT string_agg(name || '|' || role || '|' || is_primary, ' ; ' ORDER BY position) FROM public.book_draft_contributors WHERE draft_id = v_id)
           = 'Goldman, Emma|autor|true ; Berkman, Alexander|autor|false'
       AND (SELECT string_agg(name || '|' || role || '|' || nature || '|' || role_code, ' ; ') FROM public.book_draft_contributors WHERE draft_id = v_id2)
           = 'Lamb, Marie|ilustrador|person|440'
       AND (SELECT count(*) FROM public.book_draft_contributors WHERE draft_id = v_id3) = 1
       AND NOT EXISTS (SELECT 1 FROM public.book_draft_contributors WHERE draft_id = v_aut)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : crees='||v_n||' rejoue='||v_m); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 rapprochements proposes en revision, jamais appliques ; refus hors bibliotheque ; anon exclu';
  BEGIN
    INSERT INTO public.authors (sort_name, preferred_name, authority_type) VALUES ('Muñoz, Pilar', 'Pilar Muñoz', 'person') RETURNING id INTO v_aut;
    -- un brouillon de reprise n'est pas dans le lot : v_d1 est publié ; on prend v_d5 (CSV, lot importé)
    INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Reclus, Élisée', 'Élisée Reclus') RETURNING id INTO v_id;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    SELECT count(*) FILTER (WHERE f.draft_id = v_d5 AND f.name = 'Reclus, Élisée' AND f.author_id = v_id),
           count(*) FILTER (WHERE f.author_id IS NULL)
      INTO v_n, v_m FROM public.fn_batch_contributor_candidates(v_lot) f;
    -- rien n'a été rattaché
    v_ok := (SELECT author_id FROM public.book_draft_contributors WHERE draft_id = v_d5 AND name = 'Reclus, Élisée') IS NULL;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM * FROM public.fn_batch_contributor_candidates(v_lot);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_n = 1 AND v_m = 0 AND v_ok AND v_hint = 'error.batch.other_libraries'
       AND NOT has_function_privilege('anon', 'public.fn_batch_contributor_candidates(bigint,integer)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'ingest.fn_h18_contributeurs_des_brouillons_importes()', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : candidats='||v_n||' sans fiche='||v_m||' intact='||coalesce(v_ok::text,'∅')||' autre='||coalesce(v_hint,'accepte')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 le format pmb_xml est admis (H22)';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h22.xml', 'h22.xml', 'pmb_xml', 'ready_for_review') RETURNING id INTO v_id;
    v_hint := NULL;
    BEGIN
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/x.bin', 'x.bin', 'format-invente', 'ready_for_review');
    EXCEPTION WHEN check_violation THEN v_hint := 'refuse';
    END;
    IF v_id IS NOT NULL AND v_hint = 'refuse'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'accepte')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 auteurs en objets : leur nom, leur role ; jamais un non-agent, positions renumerotees ; fascicule : numero et date';
  BEGIN
    IF (SELECT string_agg(position || ':' || name || '|' || role || '|' || is_primary, ' ; ' ORDER BY position) FROM public.book_draft_contributors WHERE draft_id = v_d7)
         = '1:Kropotkin, Peter|autor|true'
       AND (SELECT string_agg(position || ':' || name || '|' || role || '|' || is_primary, ' ; ' ORDER BY position) FROM public.book_draft_contributors WHERE draft_id = v_d8)
         = '1:Reclus, Élisée|tradutor|true'
       -- le non-agent est écarté ; la personne passe en 1, mais n'était pas la principale
       AND (SELECT string_agg(position || ':' || name || '|' || is_primary, ' ; ' ORDER BY position) FROM public.book_draft_contributors WHERE draft_id = v_d9)
         = '1:Kropotkine, Piotr|false'
       AND (SELECT d.tipo_material = 'periodico' AND d.titulo_periodico = 'Géo' AND d.numero = '277' AND d.data_edicao = '2004-08-04'
                   AND d.volume = '277' AND d.colecao IS NULL
              FROM public.book_drafts d WHERE d.id = v_d10)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : d7='
         ||coalesce((SELECT string_agg(position || ':' || name || '|' || role, ' ; ') FROM public.book_draft_contributors WHERE draft_id = v_d7),'∅')
         ||' d8='||coalesce((SELECT string_agg(position || ':' || name || '|' || role, ' ; ') FROM public.book_draft_contributors WHERE draft_id = v_d8),'∅')
         ||' d9='||coalesce((SELECT string_agg(position || ':' || name || '|' || is_primary, ' ; ') FROM public.book_draft_contributors WHERE draft_id = v_d9),'∅')
         ||' d10='||coalesce((SELECT to_jsonb(d) - 'marc_json' FROM public.book_drafts d WHERE d.id = v_d10)::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  v_t := 'T11 recherche par nom en une passe = nom par nom ; congres qualifie ; limite sur les propositions ; rapport';
  BEGIN
    -- deux fiches du même nom : celle de formation (plus ancienne) passe après
    INSERT INTO public.authors (sort_name, preferred_name, source_label) VALUES ('Malatesta, Errico', 'Errico Malatesta', 'formacao-e9');
    INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Malatesta, Errico', 'Errico Malatesta') RETURNING id INTO v_aut;
    INSERT INTO public.authors (sort_name, preferred_name, authority_type) VALUES ('Congrès anarchiste', 'Congrès anarchiste', 'congress') RETURNING id INTO v_aut2;
    v_ok := (SELECT bool_and(h.aid IS NOT DISTINCT FROM public.fn_conv_autorite_homonyme(n.x))
               FROM unnest(ARRAY['Malatesta, Errico', 'Errico Malatesta', 'MALATESTA,  errico', '  Reclus, Élisée ', 'Élisée Reclus',
                                 'Muñoz, Pilar', 'Pilar Muñoz', 'Personne, Sans Fiche', 'X, Y, Z', '', 'Congrès anarchiste']) n(x)
               LEFT JOIN public.fn_conv_autorites_homonymes(ARRAY['Malatesta, Errico', 'Errico Malatesta', 'MALATESTA,  errico', '  Reclus, Élisée ',
                         'Élisée Reclus', 'Muñoz, Pilar', 'Pilar Muñoz', 'Personne, Sans Fiche', 'X, Y, Z', '', 'Congrès anarchiste']) h ON h.nom = n.x)
            AND (SELECT aid FROM public.fn_conv_autorites_homonymes(ARRAY['Errico Malatesta'])) = v_aut;
    -- un contributeur sans fiche AVANT (d2) ; un congrès qualifié (d7)
    INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary) VALUES (v_d2, 1, 'Sans Fiche, Personne', 'autor', true);
    INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary, nature)
    VALUES (v_d7, 2, 'Congrès anarchiste (3 ; 1907 ; Amsterdam)', 'autor', false, 'congress');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM public.fn_batch_contributor_candidates(v_lot, 1);
    SELECT count(*) FILTER (WHERE f.draft_id = v_d7 AND f.author_id = v_aut2), count(*) INTO v_m, v_k
      FROM public.fn_batch_contributor_candidates(v_lot) f;
    v_rap := public.fn_batch_review_report(v_lot);
    IF v_ok AND v_n = 1 AND v_m = 1
       AND (v_rap->'authorities'->>'linkable_count')::int
           = (SELECT count(*) FROM public.fn_batch_live_drafts(v_lot) d JOIN public.book_draft_contributors c ON c.draft_id = d.id
               WHERE c.author_id IS NULL AND NOT public.fn_conv_est_non_agent(c.name) AND public.fn_conv_autorite_homonyme(c.name) IS NOT NULL)
       AND (v_rap->'authorities'->>'unlinked_count')::int
           = (SELECT count(*) FROM public.fn_batch_live_drafts(v_lot) d JOIN public.book_draft_contributors c ON c.draft_id = d.id
               WHERE c.author_id IS NULL AND NOT public.fn_conv_est_non_agent(c.name))
       AND (SELECT count(*) FROM jsonb_array_elements(v_rap->'authorities'->'unlinked') u WHERE u->>'suggested_author_id' IS NOT NULL) >= 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : equivalence='||coalesce(v_ok::text,'∅')||' limite1='||v_n
         ||' congres='||v_m||' propositions='||v_k||' rapport='||coalesce((v_rap->'authorities')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 la reprise recopie ce que la publication reecrit : republier n''efface plus article, these, zine';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material, artigo_source, artigo_volume, artigo_issue, artigo_pages,
                              tese_university, zine_format, distribuidora, subjects)
    VALUES ('H18 Article repris', 'H18-R-1', 'artigo', 'Le Rat', '3', '12', 'p. 4-9', 'Université populaire', 'A5', 'Distro', 'grève')
    RETURNING id INTO v_b12;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_b12, v_lib);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_r12 := public.create_book_draft_from_book(v_b12, NULL);
    PERFORM public.publish_book_draft(v_r12);
    IF (SELECT b.artigo_source = 'Le Rat' AND b.artigo_volume = '3' AND b.artigo_issue = '12' AND b.artigo_pages = 'p. 4-9'
               AND b.tese_university = 'Université populaire' AND b.zine_format = 'A5' AND b.distribuidora = 'Distro' AND b.subjects = 'grève'
          FROM public.books b WHERE b.id = v_b12)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||coalesce((SELECT (to_jsonb(b) - 'marc_json')::text FROM public.books b WHERE b.id = v_b12), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 la scission d''autorite garde la nature de la part et le code d''origine';
  BEGIN
    INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Duo ; Groupe', 'Duo ; Groupe') RETURNING id INTO v_id;
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H18 A scinder', 'H18-S-1', 'livro') RETURNING id INTO v_id2;
    INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id, nature, role_code)
    VALUES (v_id2, 1, 'Duo ; Groupe', 'tradutor', true, v_id, 'person', '730');
    PERFORM public.fn_authority_split(v_id, jsonb_build_array(
      jsonb_build_object('preferred_name', 'Duo', 'sort_name', 'Duo', 'authority_type', 'person'),
      jsonb_build_object('preferred_name', 'Groupe', 'sort_name', 'Groupe', 'authority_type', 'collective')), NULL);
    IF (SELECT string_agg(name || '|' || coalesce(nature, '∅') || '|' || coalesce(role_code, '∅'), ' ; ' ORDER BY position)
          FROM public.book_contributors WHERE book_id = v_id2) = 'Duo|person|730 ; Groupe|collective|730'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||coalesce((SELECT string_agg(name || '|' || coalesce(nature, '∅') || '|' || coalesce(role_code, '∅'), ' ; ' ORDER BY position)
                       FROM public.book_contributors WHERE book_id = v_id2), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 ─────────────────────────────────────────────────────────────
  v_t := 'T14 fusion de notices : les contributeurs repris gardent nature et code d''origine';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H18 Gardee', 'H18-F-1', 'livro') RETURNING id INTO v_id;
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H18 Doublon', 'H18-F-2', 'livro') RETURNING id INTO v_id2;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_id, v_lib), (v_id2, v_lib);
    INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, nature, role_code)
    VALUES (v_id2, 1, 'Congrès anarchiste (3 ; 1907 ; Amsterdam)', 'autor', true, 'congress', '070');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.merge_book(v_id, v_id2);
    IF (SELECT string_agg(name || '|' || coalesce(nature, '∅') || '|' || coalesce(role_code, '∅'), ' ; ')
          FROM public.book_contributors WHERE book_id = v_id) = 'Congrès anarchiste (3 ; 1907 ; Amsterdam)|congress|070'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||coalesce((SELECT string_agg(name || '|' || coalesce(nature, '∅') || '|' || coalesce(role_code, '∅'), ' ; ')
                       FROM public.book_contributors WHERE book_id = v_id), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-ZONES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IMPORT-ZONES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
