-- =====================================================================
-- AnarBib — Tests d'acceptation : l'export des autorités d'une bibliothèque
-- (H25, aller-retour PMB)
-- Date    : 2026-09-28
-- Ref     : migration 20260928135815_h25_exporter_les_autorites_d_une_bibliotheque
--
-- T1 les fiches liées aux notices qu'elle détient, et elles seules ; type,
--    formes rejetées (tableau de fusions ou objet par langue), identifiants.
-- T2 les sujets de ses notices et leurs ancêtres, libellés dans sa langue ;
--    renvois génériques et associés.
-- T3 garde : ni le staff sans coordination, ni la coordination d'une autre
--    bibliothèque, ni anon ; l'administration du réseau, oui.
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
  v_libB uuid; v_coordB uuid; v_bibA uuid;
  v_bk1 bigint; v_bk2 bigint; v_a1 bigint; v_a2 bigint; v_a3 bigint;
  v_s1 bigint; v_s2 bigint; v_s3 bigint; v_s4 bigint;
  v_res jsonb; v_x jsonb; v_txt text; v_ok boolean;
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
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_coordB, 'Essai', 'H25 B'), (v_bibA, 'Essai', 'H25 A') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_coordB, v_libB, 'coordenador', 'active', true), (v_bibA, v_lib, 'librarian', 'active', true);

  INSERT INTO public.authors (sort_name, preferred_name, authority_type, birth_year, viaf_id, variant_forms)
  VALUES ('Reclus, Élisée', 'Élisée Reclus', 'person', 1830, '12345',
          '[{"form": "Reclus, Elisée", "source": "fusion"}, {"form": "Élisée Reclus", "source": "doublon"}]'::jsonb) RETURNING id INTO v_a1;
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, variant_forms)
  VALUES ('Collectif Brûlot', 'Collectif Brûlot', 'collective', '{"fr": ["Brûlot"], "es": ["Colectivo Brûlot"]}'::jsonb) RETURNING id INTO v_a2;
  INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Seulement chez B', 'Seulement chez B') RETURNING id INTO v_a3;

  INSERT INTO public.subjects (slug, label_i18n, status) VALUES ('h25-mouvement', '{"fr": "Mouvement ouvrier", "pt-BR": "Movimento operário"}'::jsonb, 'ativo') RETURNING id INTO v_s1;
  INSERT INTO public.subjects (slug, label_i18n, status, parent_id, alt_i18n) VALUES ('h25-synd', '{"fr": "Syndicalisme"}'::jsonb, 'ativo', v_s1, '{"fr": ["Syndicats"]}'::jsonb) RETURNING id INTO v_s2;
  INSERT INTO public.subjects (slug, label_i18n, status) VALUES ('h25-coop', '{"pt-BR": "Cooperativas"}'::jsonb, 'ativo') RETURNING id INTO v_s3;
  INSERT INTO public.subjects (slug, label_i18n, status) VALUES ('h25-b', '{"fr": "Seulement chez B"}'::jsonb, 'ativo') RETURNING id INTO v_s4;
  INSERT INTO public.subject_relations (subject_id, related_subject_id) VALUES (v_s2, v_s3);

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H25 A', 'H25-1', 'livro') RETURNING id INTO v_bk1;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H25 B', 'H25-2', 'livro') RETURNING id INTO v_bk2;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bk1, v_lib), (v_bk2, v_libB);
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id) VALUES
    (v_bk1, 1, 'Reclus, Élisée', 'autor', true, v_a1), (v_bk1, 2, 'Collectif Brûlot', 'autor', false, v_a2),
    (v_bk2, 1, 'Seulement chez B', 'autor', true, v_a3);
  INSERT INTO public.book_subjects (book_id, subject_id, ord) VALUES (v_bk1, v_s2, 1), (v_bk1, v_s3, 2), (v_bk2, v_s4, 1);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  v_res := public.fn_export_authorities_lote(v_lib);

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 les fiches liees a ses notices, et elles seules ; type, formes rejetees, identifiants';
  BEGIN
    SELECT x INTO v_x FROM jsonb_array_elements(v_res->'authors') x WHERE (x->>'id')::bigint = v_a1;
    IF (SELECT array_agg((x->>'id')::bigint ORDER BY (x->>'id')::bigint) FROM jsonb_array_elements(v_res->'authors') x
          WHERE (x->>'id')::bigint IN (v_a1, v_a2, v_a3)) = ARRAY[v_a1, v_a2]
       AND v_x->>'type' = 'person' AND v_x->>'sortName' = 'Reclus, Élisée' AND (v_x->>'birthYear')::int = 1830 AND v_x->>'viaf' = '12345'
       AND v_x->'variants' = '["Reclus, Elisée"]'::jsonb
       AND (SELECT x->'variants' FROM jsonb_array_elements(v_res->'authors') x WHERE (x->>'id')::bigint = v_a2)
           = '["Brûlot", "Colectivo Brûlot"]'::jsonb
       AND (SELECT x->>'type' FROM jsonb_array_elements(v_res->'authors') x WHERE (x->>'id')::bigint = v_a2) = 'collective'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((v_res->'authors')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 sujets de ses notices et leurs ancetres, dans sa langue ; renvois';
  BEGIN
    IF (SELECT array_agg((x->>'id')::bigint ORDER BY (x->>'id')::bigint) FROM jsonb_array_elements(v_res->'subjects') x
          WHERE (x->>'id')::bigint IN (v_s1, v_s2, v_s3, v_s4)) = ARRAY[v_s1, v_s2, v_s3]
       AND (SELECT x->>'label' FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s1) = 'Mouvement ouvrier'
       AND (SELECT x->>'label' FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s3) = 'Cooperativas'
       AND (SELECT (x->>'broader')::bigint = v_s1 AND x->'alt' = '["Syndicats"]'::jsonb AND x->'related' = to_jsonb(ARRAY[v_s3])
              FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s2)
       AND (SELECT x->'related' = to_jsonb(ARRAY[v_s2]) FROM jsonb_array_elements(v_res->'subjects') x WHERE (x->>'id')::bigint = v_s3)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((v_res->'subjects')::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 garde : ni le staff sans coordination, ni la coordination d''une autre bibliotheque, ni anon ; l''administration oui';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_bibA, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_export_authorities_lote(v_lib); v_txt := v_txt || 'staff-accepte ';
    EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.fn_export_authorities_lote(v_lib); v_txt := v_txt || 'coordB-accepte ';
    EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_ok := (public.fn_export_authorities_lote(v_lib)->>'ok')::boolean;
    IF v_txt = '' AND v_ok
       AND NOT has_function_privilege('anon', 'public.fn_export_authorities_lote(uuid)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_export_authorities_lote(uuid)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'EXPORT-AUTORITES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'EXPORT-AUTORITES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
