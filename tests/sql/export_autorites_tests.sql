-- =====================================================================
-- AnarBib — Tests d'acceptation : l'export des autorités d'une bibliothèque
-- (H25, aller-retour PMB)
-- Date    : 2026-09-28
-- Ref     : migration 20260928170908_h25_exporter_les_autorites_d_une_bibliotheque
--
-- T1 les fiches liées aux notices qu'elle détient, et elles seules ; type,
--    formes rejetées (tableau de fusions ou objet par langue), identifiants.
-- T2 les sujets de ses notices et TOUS leurs ancêtres, libellés dans sa langue
--    (et les replis : pt-BR, puis la première langue) ; renvois génériques et
--    associés.
-- T3 garde : ni le staff sans coordination, ni la coordination d'une autre
--    bibliothèque, ni une coordination qui n'est plus active, ni anon ;
--    l'administration du réseau, oui.
-- Revue contradictoire du 28/09 :
-- T4 une fiche a UN type, le même dans les deux exports : non typée, celui que
--    lui donnent ses responsabilités ; typée, le sien, quelle que soit la nature
--    notée sur la responsabilité ; ISNI, Wikidata, IdRef, LCCN.
-- T5 l'invariant de H25 : chaque $3 de l'export des notices (authorId, id de
--    sujet) a sa fiche dans l'export des autorités de la même bibliothèque.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'EXPORT-AUTORITES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid; v_coordB uuid; v_bibA uuid; v_coordV uuid;
  v_bk1 bigint; v_bk2 bigint; v_bk3 bigint; v_bk4 bigint; v_a1 bigint; v_a2 bigint; v_a3 bigint; v_a4 bigint; v_a5 bigint;
  v_s0 bigint; v_s1 bigint; v_s2 bigint; v_s3 bigint; v_s4 bigint; v_s5 bigint;
  v_res jsonb; v_cat jsonb; v_x jsonb; v_txt text; v_ok boolean; v_manque text[];
BEGIN
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  UPDATE public.libraries SET default_locale = 'fr' WHERE id = v_lib;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-h25-b', 'Essai H25 — B', true, 'private') RETURNING id INTO v_libB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h25-b-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_coordB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h25-a-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_bibA;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h25-v-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_coordV;
  INSERT INTO public.profiles (id, first_name, last_name)
  VALUES (v_coordB, 'Essai', 'H25 B'), (v_bibA, 'Essai', 'H25 A'), (v_coordV, 'Essai', 'H25 V') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_coordB, v_libB, 'coordenador', 'active', true), (v_bibA, v_lib, 'librarian', 'active', true),
         (v_coordV, v_lib, 'coordenador', 'vacated', false);

  INSERT INTO public.authors (sort_name, preferred_name, authority_type, birth_year, viaf_id, variant_forms)
  VALUES ('Reclus, Élisée', 'Élisée Reclus', 'person', 1830, '12345',
          '[{"form": "Reclus, Elisée", "source": "fusion"}, {"form": "Élisée Reclus", "source": "doublon"}]'::jsonb) RETURNING id INTO v_a1;
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, variant_forms)
  VALUES ('Collectif Brûlot', 'Collectif Brûlot', 'collective', '{"fr": ["Brûlot"], "es": ["Colectivo Brûlot"]}'::jsonb) RETURNING id INTO v_a2;
  INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Seulement chez B', 'Seulement chez B') RETURNING id INTO v_a3;
  -- une fiche NON typée, avec tous ses identifiants (808 fiches sur 1 509 ne sont pas typées en prod)
  INSERT INTO public.authors (sort_name, preferred_name, isni, wikidata_id, external_ids)
  VALUES ('Coletivo sem tipo', 'Coletivo sem tipo', '0000000121032683', 'Q4115189',
          '{"idref": "027000001", "lccn": "n79021164"}'::jsonb) RETURNING id INTO v_a4;
  -- une fiche typée « collective », notée « person » sur la responsabilité
  INSERT INTO public.authors (sort_name, preferred_name, authority_type) VALUES ('Ateneu Libertário', 'Ateneu Libertário', 'collective') RETURNING id INTO v_a5;

  INSERT INTO public.subjects (slug, label_i18n, status) VALUES ('h25-classes', '{"fr": "Classes sociales"}'::jsonb, 'ativo') RETURNING id INTO v_s0;
  INSERT INTO public.subjects (slug, label_i18n, status, parent_id) VALUES ('h25-mouvement', '{"fr": "Mouvement ouvrier", "pt-BR": "Movimento operário"}'::jsonb, 'ativo', v_s0) RETURNING id INTO v_s1;
  INSERT INTO public.subjects (slug, label_i18n, status, parent_id, alt_i18n) VALUES ('h25-synd', '{"fr": "Syndicalisme"}'::jsonb, 'ativo', v_s1, '{"fr": ["Syndicats"]}'::jsonb) RETURNING id INTO v_s2;
  INSERT INTO public.subjects (slug, label_i18n, status) VALUES ('h25-coop', '{"pt-BR": "Cooperativas"}'::jsonb, 'ativo') RETURNING id INTO v_s3;
  INSERT INTO public.subjects (slug, label_i18n, status) VALUES ('h25-b', '{"fr": "Seulement chez B"}'::jsonb, 'ativo') RETURNING id INTO v_s4;
  INSERT INTO public.subjects (slug, label_i18n, status) VALUES ('h25-es', '{"es": "Anarquismo"}'::jsonb, 'ativo') RETURNING id INTO v_s5;
  INSERT INTO public.subject_relations (subject_id, related_subject_id) VALUES (v_s2, v_s3);

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H25 A', 'H25-1', 'livro') RETURNING id INTO v_bk1;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H25 B', 'H25-2', 'livro') RETURNING id INTO v_bk2;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk1, v_lib), (v_bk2, v_libB);
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id, nature) VALUES
    (v_bk1, 1, 'Reclus, Élisée', 'autor', true, v_a1, NULL), (v_bk1, 2, 'Collectif Brûlot', 'autor', false, v_a2, NULL),
    (v_bk2, 1, 'Seulement chez B', 'autor', true, v_a3, NULL),
    (v_bk1, 3, 'Coletivo sem tipo', 'autor', false, v_a4, 'collective'),
    (v_bk1, 4, 'Ateneu Libertário', 'autor', false, v_a5, 'person');
  -- La fiche non typée v_a4 a des responsabilités de natures MÊLÉES (2 « collective »,
  -- 1 « person ») : un calcul ligne par ligne sortirait une 700 vers une fiche 210.
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H25 C', 'H25-3', 'livro') RETURNING id INTO v_bk3;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H25 D', 'H25-4', 'livro') RETURNING id INTO v_bk4;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk3, v_lib), (v_bk4, v_lib);
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id, nature) VALUES
    (v_bk3, 1, 'Coletivo sem tipo', 'autor', true, v_a4, 'person'),
    (v_bk4, 1, 'Coletivo sem tipo', 'autor', true, v_a4, 'collective');
  INSERT INTO public.book_subjects (book_id, subject_id, ord) VALUES (v_bk1, v_s2, 1), (v_bk1, v_s3, 2), (v_bk2, v_s4, 1), (v_bk1, v_s5, 3);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  v_res := public.fn_export_authorities_lote(v_lib);
  v_cat := public.fn_export_catalog_lote(v_lib);

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 les fiches liees a ses notices, et elles seules ; type, formes rejetees, identifiants';
  BEGIN
    SELECT x INTO v_x FROM jsonb_array_elements(v_res->'authors') x WHERE (x->>'id')::bigint = v_a1;
    IF (SELECT array_agg((x->>'id')::bigint ORDER BY (x->>'id')::bigint) FROM jsonb_array_elements(v_res->'authors') x
          WHERE (x->>'id')::bigint IN (v_a1, v_a2, v_a3, v_a4, v_a5)) = ARRAY[v_a1, v_a2, v_a4, v_a5]
       AND v_x->>'type' = 'person' AND v_x->>'sortName' = 'Reclus, Élisée' AND (v_x->>'birthYear')::int = 1830 AND v_x->>'viaf' = '12345'
       AND v_x->'variants' = '["Reclus, Elisée"]'::jsonb
       AND (SELECT x->'variants' FROM jsonb_array_elements(v_res->'authors') x WHERE (x->>'id')::bigint = v_a2)
           = '["Brûlot", "Colectivo Brûlot"]'::jsonb
       AND (SELECT x->>'type' FROM jsonb_array_elements(v_res->'authors') x WHERE (x->>'id')::bigint = v_a2) = 'collective'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((v_res->'authors')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 sujets de ses notices et tous leurs ancetres, dans sa langue (et ses replis) ; renvois';
  BEGIN
    IF (SELECT array_agg((x->>'id')::bigint ORDER BY (x->>'id')::bigint) FROM jsonb_array_elements(v_res->'subjects') x
          WHERE (x->>'id')::bigint IN (v_s0, v_s1, v_s2, v_s3, v_s4, v_s5)) = ARRAY[v_s0, v_s1, v_s2, v_s3, v_s5]
       AND (SELECT x->>'label' FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s1) = 'Mouvement ouvrier'
       AND (SELECT x->>'label' FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s3) = 'Cooperativas'
       AND (SELECT x->>'label' FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s5) = 'Anarquismo'
       AND (SELECT (x->>'broader')::bigint = v_s0 FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s1)
       AND (SELECT (x->>'broader')::bigint = v_s1 AND x->'alt' = '["Syndicats"]'::jsonb AND x->'related' = to_jsonb(ARRAY[v_s3])
              FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s2)
       AND (SELECT x->'related' = to_jsonb(ARRAY[v_s2]) FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s3)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((v_res->'subjects')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 garde : ni le staff, ni la coordination d''une autre bibliotheque, ni une coordination inactive, ni anon ; l''administration oui';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_bibA, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_export_authorities_lote(v_lib); v_txt := v_txt || 'staff-accepte ';
    EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_export_authorities_lote(v_lib); v_txt := v_txt || 'coordB-accepte ';
    EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordV, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_export_authorities_lote(v_lib); v_txt := v_txt || 'coordV-accepte ';
    EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_ok := (public.fn_export_authorities_lote(v_lib)->>'ok')::boolean;
    IF v_txt = '' AND v_ok
       AND NOT has_function_privilege('anon', 'public.fn_export_authorities_lote(uuid)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_export_authorities_lote(uuid)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'private.fn_nature_autorite(bigint)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 une fiche a un type, le meme dans les deux exports ; ISNI, Wikidata, IdRef, LCCN';
  BEGIN
    SELECT x INTO v_x FROM jsonb_array_elements(v_res->'authors') x WHERE (x->>'id')::bigint = v_a4;
    IF v_x->>'type' = 'collective'
       AND v_x->>'isni' = '0000000121032683' AND v_x->>'wikidata' = 'Q4115189'
       AND v_x->>'idref' = '027000001' AND v_x->>'lccn' = 'n79021164'
       AND (SELECT x->>'type' FROM jsonb_array_elements(v_res->'authors') x WHERE (x->>'id')::bigint = v_a5) = 'collective'
       -- l'export des notices dit la même nature pour ces deux $3, à CHAQUE
       -- occurrence (v_a4 figure trois fois, dont une notée « person »)
       AND (SELECT bool_and(c->>'nature' IS NOT DISTINCT FROM 'collective')
              FROM jsonb_array_elements(v_cat->'records') r CROSS JOIN LATERAL jsonb_array_elements(r->'contributors') c
             WHERE (c->>'authorId')::bigint IN (v_a4, v_a5))
       AND (SELECT count(*) FROM jsonb_array_elements(v_cat->'records') r CROSS JOIN LATERAL jsonb_array_elements(r->'contributors') c
             WHERE (c->>'authorId')::bigint = v_a4) = 3
       AND (SELECT count(*) FROM jsonb_array_elements(v_cat->'records') r CROSS JOIN LATERAL jsonb_array_elements(r->'contributors') c
             WHERE (c->>'authorId')::bigint = v_a5) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_x::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 chaque $3 de l''export des notices a sa fiche dans l''export des autorites, meme nature';
  BEGIN
    SELECT array_agg(DISTINCT m) INTO v_manque FROM (
      SELECT 'nom ' || (c->>'authorId') AS m
        FROM jsonb_array_elements(v_cat->'records') r CROSS JOIN LATERAL jsonb_array_elements(r->'contributors') c
       WHERE c ? 'authorId'
         AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_res->'authors') a
                          WHERE a->>'id' = c->>'authorId' AND a->>'type' = c->>'nature')
      UNION ALL
      SELECT 'sujet ' || (s->>'id')
        FROM jsonb_array_elements(v_cat->'records') r CROSS JOIN LATERAL jsonb_array_elements(r->'subjects') s
       WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_res->'subjects') a WHERE a->>'id' = s->>'id')
    ) q;
    IF v_manque IS NULL
       AND (SELECT count(*) FROM jsonb_array_elements(v_cat->'records') r CROSS JOIN LATERAL jsonb_array_elements(r->'contributors') c
             WHERE c ? 'authorId') >= 4
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(array_to_string(v_manque[1:10], ', '), 'trop peu de $3')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'EXPORT-AUTORITES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'EXPORT-AUTORITES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
