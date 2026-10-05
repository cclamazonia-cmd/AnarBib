-- =====================================================================
-- AnarBib — Tests d'acceptation : le dépôt numérique part des droits
-- Date    : 2026-10-05
-- Ref     : migration 20261005092916_le_depot_numerique_part_des_droits
-- Session : Retours du catalogage & numérique
--
-- T1 le réglage « lecture publique d'œuvres sous droits » : la coordination
--    de la bibliothèque le change, le reste du staff non. (La branche
--    « administration du réseau » du trigger n'est pas jouée ici : la policy
--    libraries_staff_update décide d'abord si la ligne est modifiable.)
-- T2 cohérence depuis l'écran : espace ↔ accès ; sous droits + public exige
--    le réglage ET une justification ; cession et licence libre exigent une
--    justification ; sous droits réservé, non.
-- T3 une ressource ancienne s'édite (libellé) sans être rejugée.
-- T4 publication sans recréation : même id après republication, nouveau
--    inséré, retiré supprimé, justification et empreinte audio conservées.
-- T5 la reprise pose le lien vers le publié et recopie la justification.
-- T6 un EPUB se dépose côté brouillon.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'DEPOT-NUMERIQUE-DROITS OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coordA uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_libA   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_biblio uuid; v_admin uuid;
  v_book bigint; v_draft bigint; v_r1 bigint; v_r2 bigint; v_p1 bigint; v_p1b bigint; v_n int;
  v_hint text; v_txt text; v_retake bigint; v_ok boolean;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'dn-' || n || '-' || gen_random_uuid() || '@example.invalid', now(), now()
    FROM generate_series(1, 2) n;
  SELECT id INTO v_biblio FROM auth.users WHERE email LIKE 'dn-1-%';
  SELECT id INTO v_admin  FROM auth.users WHERE email LIKE 'dn-2-%';
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT u, 'Essai', 'DN' FROM unnest(ARRAY[v_biblio, v_admin]) u ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_biblio, v_libA, 'librarian', 'active', true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  UPDATE public.libraries SET digital_public_under_rights = false WHERE id = v_libA;

  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('DN publie', 'DN-1', 'livro', v_libA) RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_libA);
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, published_book_id, action)
  VALUES ('DN brouillon', 'livro', v_libA, v_coordA, 'draft', v_book, 'update') RETURNING id INTO v_draft;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 le reglage revient a la coordination';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_biblio, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_hint := NULL;
    BEGIN UPDATE public.libraries SET digital_public_under_rights = true WHERE id = v_libA;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    IF v_hint IS DISTINCT FROM 'error.library.digital_policy_coord_only' THEN v_txt := v_txt || 'bibliothecaire=' || coalesce(v_hint, 'accepte') || ' '; END IF;

    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.libraries SET digital_public_under_rights = true WHERE id = v_libA;
    EXECUTE 'RESET ROLE';
    IF NOT (SELECT digital_public_under_rights FROM public.libraries WHERE id = v_libA) THEN v_txt := v_txt || 'coordination-refusee '; END IF;

    UPDATE public.libraries SET digital_public_under_rights = false WHERE id = v_libA;   -- remis à faux pour T2 (postgres)
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 coherence droits / acces / espace depuis l''ecran';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    -- public dans un espace réservé
    v_hint := NULL;
    BEGIN INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
          VALUES (v_draft, 'pdf_publico', 'leitura_online', 'publico', 'pdf-restrito', 'books/x/a.pdf', 'dominio_publico');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.digital.bucket_scope' THEN v_txt := v_txt || 'espace=' || coalesce(v_hint, 'accepte') || ' '; END IF;
    -- sous droits + public, bibliothèque fermée
    v_hint := NULL;
    BEGIN INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status, rights_justification)
          VALUES (v_draft, 'pdf_publico', 'leitura_online', 'publico', 'anarbib-pdf-public', 'books/x/b.pdf', 'sob_direitos', 'trouvable en ligne');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.digital.public_under_rights_not_allowed' THEN v_txt := v_txt || 'ferme=' || coalesce(v_hint, 'accepte') || ' '; END IF;
    -- cession sans justification
    v_hint := NULL;
    BEGIN INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, source_url, rights_status)
          VALUES (v_draft, 'link_externo', 'link_externo', 'publico', 'https://exemple.invalid/c', 'cessao_autoral');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.digital.justification_required' THEN v_txt := v_txt || 'cession=' || coalesce(v_hint, 'acceptee') || ' '; END IF;
    -- sous droits réservé, sans justification : permis
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
    VALUES (v_draft, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'pdf-restrito', 'books/x/d.pdf', 'sob_direitos');
    EXECUTE 'RESET ROLE';

    -- bibliothèque ouverte : sous droits + public avec justification passe, sans justification non
    UPDATE public.libraries SET digital_public_under_rights = true WHERE id = v_libA;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_hint := NULL;
    BEGIN INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
          VALUES (v_draft, 'pdf_publico', 'leitura_online', 'publico', 'anarbib-pdf-public', 'books/x/e.pdf', 'sob_direitos');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.digital.justification_required' THEN v_txt := v_txt || 'ouvert-sans-justif=' || coalesce(v_hint, 'accepte') || ' '; END IF;
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status, rights_justification)
    VALUES (v_draft, 'pdf_publico', 'leitura_online', 'publico', 'anarbib-pdf-public', 'books/x/f.pdf', 'sob_direitos', 'trouvable sur le site de l''éditeur, choix assumé');
    EXECUTE 'RESET ROLE';
    UPDATE public.libraries SET digital_public_under_rights = false WHERE id = v_libA;
    DELETE FROM public.book_draft_digital_resources WHERE book_draft_id = v_draft;
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 une ressource ancienne s''edite sans etre rejugee';
  BEGIN
    -- posée par le système, incohérente au regard des règles d'aujourd'hui
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
    VALUES (v_draft, 'pdf_publico', 'leitura_online', 'publico', 'anarbib-pdf-public', 'books/x/g.pdf', 'cessao_autoral') RETURNING id INTO v_r1;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_draft_digital_resources SET label = 'Libellé corrigé' WHERE id = v_r1;
    EXECUTE 'RESET ROLE';
    IF (SELECT label FROM public.book_draft_digital_resources WHERE id = v_r1) = 'Libellé corrigé'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : libelle non modifie'); END IF;
    DELETE FROM public.book_draft_digital_resources WHERE book_draft_id = v_draft;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 publication sans recreation';
  BEGIN
    v_txt := '';
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status, rights_justification, label)
    VALUES (v_draft, 'pdf_publico', 'leitura_online', 'publico', 'anarbib-pdf-public', 'books/x/h.pdf', 'licenca_livre', 'CC BY-SA 4.0', 'Premier') RETURNING id INTO v_r1;
    PERFORM public.publish_book_draft_digital_resources(v_draft, v_book);
    SELECT published_resource_id INTO v_p1 FROM public.book_draft_digital_resources WHERE id = v_r1;
    IF v_p1 IS NULL THEN v_txt := v_txt || 'lien-non-pose '; END IF;
    -- empreinte audio posée sur le publié
    UPDATE public.book_digital_resources SET chromaprint_fp = 'empreinte' WHERE id = v_p1;
    -- republication avec un libellé changé et une seconde ressource
    UPDATE public.book_draft_digital_resources SET label = 'Premier, corrigé' WHERE id = v_r1;
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, source_url, label)
    VALUES (v_draft, 'link_externo', 'link_externo', 'publico', 'https://exemple.invalid/i', 'Second') RETURNING id INTO v_r2;
    PERFORM public.publish_book_draft_digital_resources(v_draft, v_book);
    SELECT id INTO v_p1b FROM public.book_digital_resources WHERE book_id = v_book AND label = 'Premier, corrigé';
    IF v_p1b IS DISTINCT FROM v_p1 THEN v_txt := v_txt || 'id-change(' || v_p1 || '->' || coalesce(v_p1b::text, '∅') || ') '; END IF;
    IF (SELECT chromaprint_fp FROM public.book_digital_resources WHERE id = v_p1) IS DISTINCT FROM 'empreinte' THEN v_txt := v_txt || 'empreinte-perdue '; END IF;
    IF (SELECT rights_justification FROM public.book_digital_resources WHERE id = v_p1) IS DISTINCT FROM 'CC BY-SA 4.0' THEN v_txt := v_txt || 'justification-perdue '; END IF;
    IF (SELECT count(*) FROM public.book_digital_resources WHERE book_id = v_book) <> 2 THEN v_txt := v_txt || 'second-absent '; END IF;
    -- le premier retiré du brouillon quitte le publié
    DELETE FROM public.book_draft_digital_resources WHERE id = v_r1;
    PERFORM public.publish_book_draft_digital_resources(v_draft, v_book);
    IF EXISTS (SELECT 1 FROM public.book_digital_resources WHERE id = v_p1) THEN v_txt := v_txt || 'retire-reste '; END IF;
    IF (SELECT count(*) FROM public.book_digital_resources WHERE book_id = v_book) <> 1 THEN v_txt := v_txt || 'compte '; END IF;
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 la reprise pose le lien et recopie la justification';
  BEGIN
    UPDATE public.book_digital_resources SET rights_status = 'licenca_livre', rights_justification = 'CC BY 4.0' WHERE book_id = v_book;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, published_book_id, action)
    VALUES ('DN reprise', 'livro', v_libA, v_coordA, 'draft', v_book, 'update') RETURNING id INTO v_retake;
    PERFORM public.copy_book_digital_resources_to_draft(v_book, v_retake);
    SELECT count(*) INTO v_n FROM public.book_draft_digital_resources d
      JOIN public.book_digital_resources p ON p.id = d.published_resource_id
     WHERE d.book_draft_id = v_retake AND d.rights_justification = 'CC BY 4.0';
    IF v_n = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s) liee(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 un EPUB se depose';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, mime_type, rights_status)
    VALUES (v_draft, 'epub', 'leitura_online', 'publico', 'anarbib-epub-public', 'books/x/j.epub', 'application/epub+zip', 'dominio_publico');
    EXECUTE 'RESET ROLE';
    v_passed := v_passed+1;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'DEPOT-NUMERIQUE-DROITS OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'DEPOT-NUMERIQUE-DROITS ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
