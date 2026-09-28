-- =====================================================================
-- AnarBib — Tests d'acceptation : l'export d'une bibliothèque contient tout
-- ce qu'elle a catalogué, et rien d'une autre (H24, aller-retour PMB)
-- Date    : 2026-09-28
-- Ref     : migration 20260928111816_h24_l_export_contient_tout_ce_que_la_bibliotheque_a_catalogue
--
-- T1 les notices qu'elle détient, pas les autres ; la bibliothèque (nom,
--    pays, langue) accompagne l'export.
-- T2 responsabilités depuis book_contributors, dans l'ordre : nom, nature (la
--    sienne, sinon celle de la fiche), rôle, code d'origine, principale,
--    autorité, dates de la fiche.
-- T3 sujets du thésaurus dans la langue de la bibliothèque ; texte libre en
--    mots-clés.
-- T4 identifiant d'origine et identifiants de SA bibliothèque seulement.
-- T5 exemplaires de cette bibliothèque seulement.
-- T6 l'enregistrement MARC d'origine : pour la bibliothèque qui l'a importé
--    (sans ses exemplaires), pas pour une autre.
-- T7 article (hôte, fascicule, pages), œuvre, périodique.
-- T9 par pages (H26) : total, suite, rien de perdu ni de double.
-- T10 chaque colonne sous sa clé (aucune interversion).
-- T8 garde : ni le staff sans coordination, ni la coordination d'une autre
--    bibliothèque, ni anon ; l'administration du réseau, oui.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'EXPORT-CATALOGUE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid; v_coordB uuid; v_bibA uuid;
  v_src bigint; v_srcB bigint; v_run bigint;
  v_bk1 bigint; v_bk2 bigint; v_bk3 bigint; v_hA bigint; v_hB bigint; v_h3 bigint;
  v_aut1 bigint; v_aut2 bigint; v_sub bigint; v_work bigint; v_serial bigint; v_bk4 bigint;
  v_res jsonb; v_resB jsonb; v_r jsonb; v_txt text; v_ok boolean;
  v_srcDep bigint; v_runDep bigint; v_bk8 bigint; v_bk9 bigint;
BEGIN
  -- ── Décor ───────────────────────────────────────────────────────────
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  UPDATE public.libraries SET default_locale = 'fr', country = 'Brasil' WHERE id = v_lib;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level, default_locale)
  VALUES (gen_random_uuid(), 'essai-h24-b', 'Essai H24 — B', true, 'private', 'pt-BR') RETURNING id INTO v_libB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h24-b-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_coordB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h24-a-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_bibA;
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_coordB, 'Essai', 'H24 B'), (v_bibA, 'Essai', 'H24 A') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_coordB, v_libB, 'coordenador', 'active', true), (v_bibA, v_lib, 'librarian', 'active', true);

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('PMB essai H24', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Autre source B', v_libB, 'mapeada', 'own_catalog', true) RETURNING id INTO v_srcB;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h24.iso', 'h24.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;

  INSERT INTO public.authors (sort_name, preferred_name, authority_type, birth_year)
  VALUES ('Černá, Zdeňka', 'Zdeňka Černá', 'person', 1950) RETURNING id INTO v_aut1;
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, birth_year, death_year)
  VALUES ('Collectif Brûlot', 'Collectif Brûlot', 'collective', 1971, 1989) RETURNING id INTO v_aut2;
  INSERT INTO public.subjects (slug, label_i18n, status)
  VALUES ('h24-syndicalisme', '{"fr": "Syndicalisme", "pt-BR": "Sindicalismo"}'::jsonb, 'ativo') RETURNING id INTO v_sub;
  INSERT INTO public.works (uniform_title) VALUES ('Des bourses du travail (œuvre)') RETURNING id INTO v_work;
  INSERT INTO public.serials (slug, uniform_title, issn) VALUES ('h24-le-rat', 'Le Rat des bibliothèques', '2555-0004') RETURNING id INTO v_serial;

  -- bk1 : détenue par A et par B ; importée par A (MARC d'origine)
  INSERT INTO public.books (titulo, subtitulo, autor, bib_ref, tipo_material, paginas, colecao, notas, subjects, assuntos, work_id, marc_json)
  VALUES ('H24 Des bourses du travail', 'histoire', 'Zdeňka Černá', 'H24-1', 'livro', 352, 'Mémoires sociales ; 7', 'Note.',
          'autogestion | Bakunin, Mikhail, 1814-1876; autogestion', 'coopératives; entraide', v_work,
          jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'source_id', v_src, 'raw_payload', jsonb_build_object(
            'marc_dialect', 'unimarc', 'leader', '00000nam0 22000001i 450 ', 'item_tag', '952', 'fields', jsonb_build_array(
              jsonb_build_object('tag', '952', 'ind1', ' ', 'ind2', ' ', 'subfields', '[{"code":"p","value":"PROFIL"}]'::jsonb),
              jsonb_build_object('tag', '001', 'value', '61'),
              jsonb_build_object('tag', '319', 'ind1', ' ', 'ind2', ' ', 'subfields', '[{"code":"a","value":"droits"}]'::jsonb),
              jsonb_build_object('tag', '995', 'ind1', ' ', 'ind2', ' ', 'subfields', '[{"code":"f","value":"CDF1"}]'::jsonb))))))
  RETURNING id INTO v_bk1;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref) VALUES (v_bk1, v_lib, 'BLMF-LOC-1') RETURNING id INTO v_hA;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk1, v_libB) RETURNING id INTO v_hB;
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id, nature, role_code) VALUES
    (v_bk1, 1, 'Černá, Zdeňka', 'autor', true, v_aut1, 'person', '070'),
    (v_bk1, 2, 'Collectif Brûlot', 'autor', false, v_aut2, NULL, NULL),
    (v_bk1, 3, 'Muñoz, Pilar', 'tradutor', false, NULL, 'person', '730'),
    (v_bk1, 4, 'Coletivo sem ficha', 'organizacao', false, NULL, NULL, NULL);
  INSERT INTO public.book_subjects (book_id, subject_id, ord) VALUES (v_bk1, v_sub, 1);
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility, shelf_location, source_item_code, notes)
  VALUES ('H24-1', 'H24-A-0001', v_lib, v_hA, 'emprestavel', 'public', '334.7 CER', 'CDF0000000009', 'Dédicacé'),
         ('H24-1', 'H24-B-0001', v_libB, v_hB, 'emprestavel', 'public', 'B 334', 'B-CODE', NULL);
  PERFORM ingest.fn_record_book_external_id(v_bk1, v_lib, v_src, 'PMB-61');
  PERFORM ingest.fn_record_book_external_id(v_bk1, v_libB, v_srcB, 'B-99');

  -- bk2 : détenue par B seulement
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H24 Seulement chez B', 'H24-2', 'livro') RETURNING id INTO v_bk2;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk2, v_libB);

  -- bk3 : un article dépouillé ; bk4 : un fascicule de périodique
  INSERT INTO public.books (titulo, bib_ref, tipo_material, artigo_source, artigo_volume, artigo_issue, artigo_pages, data_edicao)
  VALUES ('H24 Classer sans dominer', 'H24-3', 'artigo', 'Le Rat des bibliothèques', '3', '12', 'p. 4-9', '2025-03-01') RETURNING id INTO v_bk3;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk3, v_lib) RETURNING id INTO v_h3;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, serial_id, numero, data_edicao) VALUES ('H24 Le Rat nº 12', 'H24-4', 'periodico', v_serial, '12', '2025-03-01') RETURNING id INTO v_bk4;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk4, v_lib);

  -- bk9 : chaque colonne une valeur distincte (un champ interverti se voit)
  INSERT INTO public.books (titulo, subtitulo, autor, volume, edicao, local_publicacao, editora, ano, isbn, issn, idioma, cdd,
                            notas, digital_native_url, titulo_periodico, colecao, bib_ref, tipo_material, paginas)
  VALUES ('T9-titre', 'T9-sous', 'T9-mention', 'T9-vol', 'T9-ed', 'T9-lieu', 'T9-editeur', '1999', '978-0-00-000000-9', '1234-567X', 'es', '335.8',
          'T9-note', 'https://ex.org/t9', 'T9-cle', 'T9-coll', 'H24-9', 'recurso_digital', 99) RETURNING id INTO v_bk9;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk9, v_lib);

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, destination_library_id, relation_status, source_kind, import_enabled)
  VALUES ('Depot de B', v_lib, v_libB, 'mapeada', 'partner_deposit', true) RETURNING id INTO v_srcDep;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_srcDep, v_lib, 'essai/dep.iso', 'dep.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runDep;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, marc_json)
  VALUES ('H24 Depot de B', 'H24-8', 'livro', jsonb_build_object('ingest', jsonb_build_object('run_id', v_runDep, 'source_id', v_srcDep,
          'raw_payload', jsonb_build_object('marc_dialect', 'unimarc', 'fields', jsonb_build_array(jsonb_build_object('tag', '001', 'value', 'D-8'))))))
  RETURNING id INTO v_bk8;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk8, v_lib), (v_bk8, v_libB);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  v_res := public.fn_export_catalog_lote(v_lib);
  SELECT r INTO v_r FROM jsonb_array_elements(v_res->'records') r WHERE (r->>'id')::bigint = v_bk1;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 les notices detenues, pas les autres ; la bibliotheque accompagne l''export';
  BEGIN
    IF (SELECT array_agg((r->>'id')::bigint ORDER BY (r->>'id')::bigint) FROM jsonb_array_elements(v_res->'records') r
         WHERE (r->>'id')::bigint IN (v_bk1, v_bk2, v_bk3, v_bk4, v_bk8, v_bk9)) = ARRAY[v_bk1, v_bk3, v_bk4, v_bk9, v_bk8]
       AND v_res->'library'->>'short_name' IS NOT DISTINCT FROM (SELECT short_name FROM public.libraries WHERE id = v_lib)
       AND v_res->'library'->>'default_locale' = 'fr' AND v_res->'library'->>'country' = 'Brasil'
       AND (v_res->>'count')::int = jsonb_array_length(v_res->'records')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(left(v_res::text, 300),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 responsabilites : nom, nature (sienne ou de la fiche), role, code, principale, autorite, dates';
  BEGIN
    IF v_r->'contributors' = jsonb_build_array(
         jsonb_build_object('name', 'Černá, Zdeňka', 'nature', 'person', 'role', 'autor', 'roleCode', '070', 'primary', true, 'authorId', v_aut1, 'dates', '1950-....'),
         jsonb_build_object('name', 'Collectif Brûlot', 'nature', 'collective', 'role', 'autor', 'primary', false, 'authorId', v_aut2, 'dates', '1971-1989'),
         jsonb_build_object('name', 'Muñoz, Pilar', 'nature', 'person', 'role', 'tradutor', 'roleCode', '730', 'primary', false),
         jsonb_build_object('name', 'Coletivo sem ficha', 'nature', 'collective', 'role', 'organizacao', 'primary', false))
       AND v_r->'authors'->0->>'name' = 'Černá, Zdeňka'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((v_r->'contributors')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 sujets du thesaurus dans la langue de la bibliotheque ; texte libre en mots-cles';
  BEGIN
    IF v_r->'subjects' = jsonb_build_array(jsonb_build_object('id', v_sub, 'label', 'Syndicalisme'))
       AND v_r->'keywords' = '["autogestion", "Bakunin, Mikhail, 1814-1876", "coopératives", "entraide"]'::jsonb
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((v_r->'subjects')::text,'∅')||' '||coalesce((v_r->'keywords')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 identifiant d''origine et identifiants de SA bibliotheque seulement';
  BEGIN
    IF v_r->>'originId' = 'PMB-61'
       AND v_r->'externalIds' = jsonb_build_array(jsonb_build_object('scheme', 'import:' || v_src, 'value', 'PMB-61', 'label', 'PMB essai H24'))
       AND v_r->>'bibRef' = 'BLMF-LOC-1'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((v_r->'externalIds')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 exemplaires de cette bibliotheque seulement';
  BEGIN
    IF jsonb_array_length(v_r->'items') = 1
       AND (v_r->'items'->0) - 'id' = '{"tombo": "H24-A-0001", "code": "CDF0000000009", "callNumber": "334.7 CER", "note": "Dédicacé", "circulationPolicy": "emprestavel", "visibility": "public"}'::jsonb
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((v_r->'items')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 enregistrement d''origine pour la bibliotheque qui l''a importe (sans exemplaires), pas pour une autre';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    v_resB := public.fn_export_catalog_lote(v_libB);
    IF v_r->'source'->>'dialect' = 'unimarc'
       AND (SELECT array_agg(f->>'tag') FROM jsonb_array_elements(v_r->'source'->'fields') f) = ARRAY['001', '319']
       AND v_r->'source'->>'leader' = '00000nam0 22000001i 450 ' AND v_r->'source'->>'itemTag' = '952'
       -- un dépôt compagnon : l'origine va à la bibliothèque d'où vient la notice (B), pas à qui l'a importé
       AND (SELECT r ? 'source' FROM jsonb_array_elements(v_res->'records') r WHERE (r->>'id')::bigint = v_bk8) = false
       AND (SELECT r->'source'->'fields'->0->>'value' FROM jsonb_array_elements(v_resB->'records') r WHERE (r->>'id')::bigint = v_bk8) = 'D-8'
       AND (SELECT r ? 'source' FROM jsonb_array_elements(v_resB->'records') r WHERE (r->>'id')::bigint = v_bk1) = false
       AND (SELECT r->>'originId' FROM jsonb_array_elements(v_resB->'records') r WHERE (r->>'id')::bigint = v_bk1) = 'B-99'
       AND (SELECT r->'items'->0->>'tombo' FROM jsonb_array_elements(v_resB->'records') r WHERE (r->>'id')::bigint = v_bk1) = 'H24-B-0001'
       AND (SELECT count(*) FROM jsonb_array_elements(v_resB->'records') r WHERE (r->>'id')::bigint IN (v_bk3, v_bk4)) = 0
       AND (SELECT r->>'bibRef' FROM jsonb_array_elements(v_resB->'records') r WHERE (r->>'id')::bigint = v_bk1) = 'H24-1'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : A='||coalesce((v_r->'source')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 article (hote, fascicule, pages), oeuvre, periodique';
  BEGIN
    IF (SELECT r->'host' = '{"title": "Le Rat des bibliothèques", "volume": "3"}'::jsonb
               AND r->'issue' = '{"number": "12", "date": "2025-03-01"}'::jsonb
               AND r->>'articlePages' = 'p. 4-9' AND r->>'materialType' = 'artigo'
          FROM jsonb_array_elements(v_res->'records') r WHERE (r->>'id')::bigint = v_bk3)
       AND v_r->'work'->>'title' = 'Des bourses du travail (œuvre)'
       AND (SELECT (r->'serial') - 'id' FROM jsonb_array_elements(v_res->'records') r WHERE (r->>'id')::bigint = v_bk4)
           = '{"title": "Le Rat des bibliothèques", "issn": "2555-0004"}'::jsonb
       AND (SELECT r->'issue' FROM jsonb_array_elements(v_res->'records') r WHERE (r->>'id')::bigint = v_bk4)
           = '{"number": "12", "date": "2025-03-01"}'::jsonb
       AND v_r->>'pages' = '352' AND v_r->>'collection' = 'Mémoires sociales ; 7'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 garde : ni le staff sans coordination, ni la coordination d''une autre bibliotheque, ni anon ; l''administration oui';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_bibA, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_export_catalog_lote(v_lib); v_txt := v_txt || 'staff-accepte ';
    EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_export_catalog_lote(v_lib); v_txt := v_txt || 'coordB-accepte ';
    EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_ok := (public.fn_export_catalog_lote(v_lib)->>'ok')::boolean;
    IF v_txt = '' AND v_ok
       AND NOT has_function_privilege('anon', 'public.fn_export_catalog_lote(uuid,bigint,integer)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_export_catalog_lote(uuid,bigint,integer)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 par pages : total a la premiere, suite tant que la page est pleine, rien de perdu ni de double';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_resB := public.fn_export_catalog_lote(v_lib, NULL, 2);
    v_txt := (SELECT string_agg(r->>'id', ',' ORDER BY (r->>'id')::bigint) FROM jsonb_array_elements(v_resB->'records') r);
    v_ok := (v_resB->>'count')::int = 2 AND (v_resB->>'total')::int = (v_res->>'count')::int
            AND (v_resB->>'next')::bigint = (SELECT max((r->>'id')::bigint) FROM jsonb_array_elements(v_resB->'records') r);
    -- toutes les pages, bout à bout
    WHILE v_resB->>'next' IS NOT NULL LOOP
      v_resB := public.fn_export_catalog_lote(v_lib, (v_resB->>'next')::bigint, 2);
      v_ok := v_ok AND v_resB->>'total' IS NULL;
      v_txt := v_txt || coalesce(',' || (SELECT string_agg(r->>'id', ',' ORDER BY (r->>'id')::bigint) FROM jsonb_array_elements(v_resB->'records') r), '');
    END LOOP;
    IF v_ok AND v_txt = (SELECT string_agg(r->>'id', ',' ORDER BY (r->>'id')::bigint) FROM jsonb_array_elements(v_res->'records') r)
       AND v_res->>'next' IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : pages='||coalesce(v_txt,'∅')||' ok='||coalesce(v_ok::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 chaque colonne a sa cle (aucune interversion)';
  BEGIN
    IF (SELECT r->>'title' = b.titulo AND r->>'subtitle' = b.subtitulo AND r->>'responsibility' = b.autor AND r->>'volume' = b.volume
               AND r->>'edition' = b.edicao AND r->>'place' = b.local_publicacao AND r->>'publisher' = b.editora AND r->>'year' = b.ano
               AND r->>'isbn' = b.isbn AND r->>'issn' = b.issn AND r->>'language' = b.idioma AND r->>'cdd' = b.cdd
               AND r->>'notes' = b.notas AND r->>'url' = b.digital_native_url AND r->>'keyTitle' = b.titulo_periodico
               AND r->>'collection' = b.colecao AND r->>'materialType' = b.tipo_material AND (r->>'pages')::int = b.paginas
          FROM jsonb_array_elements(v_res->'records') r JOIN public.books b ON b.id = (r->>'id')::bigint WHERE b.id = v_bk9)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||coalesce((SELECT r::text FROM jsonb_array_elements(v_res->'records') r WHERE (r->>'id')::bigint = v_bk9), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'EXPORT-CATALOGUE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'EXPORT-CATALOGUE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
