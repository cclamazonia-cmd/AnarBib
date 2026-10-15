-- =====================================================================
-- AnarBib — Tests d'acceptation : le lien va à la page de la source (D17)
-- Date    : 2026-10-15
-- Ref     : migration 20261015180042_d17_le_lien_va_a_la_page_de_la_source
-- Session : D17 lien vers la page source
-- Décision: REGISTRE §47 NUMDIF-3 (option (b) du cadrage du 15/10)
--
-- read-digital-asset signe en service_role ce que rend
-- get_accessible_digital_asset_by_id_v2, et cette RPC est elle-même exposée à
-- PostgREST : c'est donc ELLE qui décide quelle adresse sort. La suite
-- l'appelle sous les rôles de session.
--
-- T1 compte membre de la bibliothèque détentrice, ressource restreinte servie
--    depuis le stockage : la page sort, le fichier jamais.
-- T2 anon : rien (ni par la RPC, ni par la table).
-- T3 compte d'une autre bibliothèque : rien (ni par la RPC, ni par la table).
-- T4 le membre ne lit pas non plus le fichier en lisant la table.
-- T5 ressource publique : l'anonyme lit le fichier et la page (inchangé).
-- T6 ressource restreinte SANS fichier stocké : son adresse est son chemin de
--    lecture, elle sort pour le membre (exception assumée, cf. migration).
-- T7 la reprise et la publication font suivre la page.
-- T8 une page qui n'est pas une adresse web est refusée, au publié comme au
--    brouillon.
-- T9 liste fermée : parmi les fonctions qui lisent book_digital_resources,
--    seules deux ouvertes aux rôles de session rendent une colonne source_url,
--    et la seconde ne sert que le public. (get_book_primary_accessible_digital_asset_v2
--    la rend aussi, mais reste fermée aux rôles de session.)
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'D17-PAGE-SOURCE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coordA uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_libA uuid; v_libB uuid;
  v_membre uuid; v_etranger uuid;
  v_bRes bigint; v_bPub bigint; v_bLien bigint;
  v_rRes bigint; v_rPub bigint; v_rLien bigint;
  v_draft bigint; v_n int; v_txt text; v_row record;
  c_fichier constant text := 'https://exemple.invalid/wp-content/uploads/livre.pdf';
  c_page    constant text := 'https://exemple.invalid/article-du-livre/';
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-d17-a', 'Essai D17 détentrice', true, 'public') RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-d17-b', 'Essai D17 autre', true, 'public') RETURNING id INTO v_libB;

  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'd17-' || n || '-' || gen_random_uuid() || '@example.invalid', now(), now()
    FROM generate_series(1, 2) n;
  SELECT id INTO v_membre   FROM auth.users WHERE email LIKE 'd17-1-%';
  SELECT id INTO v_etranger FROM auth.users WHERE email LIKE 'd17-2-%';
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT u, 'Essai', 'D17' FROM unnest(ARRAY[v_membre, v_etranger]) u ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_membre, v_libA, 'reader', 'active', true),
    (v_etranger, v_libB, 'reader', 'active', true);

  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('D17 réservé', 'D17-1', 'livro', v_libA) RETURNING id INTO v_bRes;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('D17 public', 'D17-2', 'livro', v_libA) RETURNING id INTO v_bPub;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('D17 lien', 'D17-3', 'livro', v_libA) RETURNING id INTO v_bLien;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bRes, v_libA), (v_bPub, v_libA), (v_bLien, v_libA);

  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
         storage_bucket, storage_path, mime_type, source_name, source_url, source_page_url, rights_status, bibliographic_match_validated)
  VALUES (v_bRes, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'active', true,
         'pdf-restrito', 'books/d17/r.pdf', 'application/pdf', 'Exemple', c_fichier, c_page, 'sob_direitos', true)
  RETURNING id INTO v_rRes;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
         storage_bucket, storage_path, mime_type, source_name, source_url, source_page_url, rights_status, bibliographic_match_validated)
  VALUES (v_bPub, 'pdf_publico', 'leitura_online', 'publico', 'active', true,
         'anarbib-pdf-public', 'books/d17/p.pdf', 'application/pdf', 'Internet Archive',
         'https://archive.org/download/exemple/exemple.pdf', 'https://archive.org/details/exemple', 'dominio_publico', true)
  RETURNING id INTO v_rPub;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
         source_name, source_url, rights_status, bibliographic_match_validated)
  VALUES (v_bLien, 'link_externo', 'link_externo', 'conta_ativa', 'active', true,
         'Exemple', 'https://exemple.invalid/lecture-en-ligne', 'sob_direitos', true)
  RETURNING id INTO v_rLien;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 membre : la page sort, le fichier jamais';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_membre, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_row FROM public.get_accessible_digital_asset_by_id_v2(v_rRes);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_n = 1 AND v_row.access_granted AND v_row.source_page_url = c_page AND v_row.source_url IS NULL
       AND v_row.source_name = 'Exemple'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lignes='||v_n||' page='||coalesce(v_row.source_page_url,'∅')
      ||' fichier='||coalesce(v_row.source_url,'∅')||' accordé='||coalesce(v_row.access_granted::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 anon : rien';
  BEGIN
    PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT count(*) INTO v_n FROM public.get_accessible_digital_asset_by_id_v2(v_rRes);
    v_txt := 'rpc=' || v_n;
    SELECT count(*) INTO v_n FROM public.book_digital_resources WHERE id = v_rRes;
    v_txt := v_txt || ' table=' || v_n;
    EXECUTE 'RESET ROLE';
    IF v_txt = 'rpc=0 table=0'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 compte d''une autre bibliotheque : rien';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_etranger, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.get_accessible_digital_asset_by_id_v2(v_rRes);
    v_txt := 'rpc=' || v_n;
    SELECT count(*) INTO v_n FROM public.book_digital_resources WHERE id = v_rRes;
    v_txt := v_txt || ' table=' || v_n;
    EXECUTE 'RESET ROLE';
    IF v_txt = 'rpc=0 table=0'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 le membre ne lit pas le fichier par la table';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_membre, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.book_digital_resources WHERE source_url = c_fichier;
    EXECUTE 'RESET ROLE';
    IF v_n = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 public : l''anonyme lit le fichier et la page';
  BEGIN
    PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT * INTO v_row FROM public.get_accessible_digital_asset_by_id_v2(v_rPub);
    EXECUTE 'RESET ROLE';
    IF v_row.source_url = 'https://archive.org/download/exemple/exemple.pdf'
       AND v_row.source_page_url = 'https://archive.org/details/exemple'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fichier='||coalesce(v_row.source_url,'∅')||' page='||coalesce(v_row.source_page_url,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 restreinte sans fichier stocke : son chemin de lecture sort pour le membre seul';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_membre, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_row FROM public.get_accessible_digital_asset_by_id_v2(v_rLien);
    EXECUTE 'RESET ROLE';
    v_txt := 'membre=' || coalesce(v_row.source_url, '∅');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_etranger, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.get_accessible_digital_asset_by_id_v2(v_rLien);
    EXECUTE 'RESET ROLE';
    v_txt := v_txt || ' etranger=' || v_n;
    IF v_txt = 'membre=https://exemple.invalid/lecture-en-ligne etranger=0'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 la reprise et la publication font suivre la page';
  BEGIN
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, published_book_id, action)
    VALUES ('D17 reprise', 'livro', v_libA, v_coordA, 'draft', v_bRes, 'update') RETURNING id INTO v_draft;
    PERFORM public.copy_book_digital_resources_to_draft(v_bRes, v_draft);
    SELECT source_page_url INTO v_txt FROM public.book_draft_digital_resources
     WHERE book_draft_id = v_draft AND published_resource_id = v_rRes;
    v_txt := 'reprise=' || coalesce(v_txt, '∅');
    UPDATE public.book_draft_digital_resources SET source_page_url = 'https://exemple.invalid/autre-page'
     WHERE book_draft_id = v_draft AND published_resource_id = v_rRes;
    PERFORM public.publish_book_draft_digital_resources(v_draft, v_bRes);
    v_txt := v_txt || ' publie=' || coalesce((SELECT source_page_url FROM public.book_digital_resources WHERE id = v_rRes), '∅');
    IF v_txt = 'reprise=' || c_page || ' publie=https://exemple.invalid/autre-page'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 une page qui n''est pas une adresse web est refusee';
  BEGIN
    v_txt := '';
    BEGIN
      UPDATE public.book_digital_resources SET source_page_url = 'javascript:alert(1)' WHERE id = v_rPub;
      v_txt := v_txt || 'publie-accepte ';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN
      UPDATE public.book_draft_digital_resources SET source_page_url = 'archive.org/details/x' WHERE book_draft_id = v_draft;
      v_txt := v_txt || 'brouillon-accepte ';
    EXCEPTION WHEN check_violation THEN NULL; END;
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  -- Une fonction neuve qui rendrait source_url aux rôles de session doit dire
  -- ici pourquoi elle ne livre pas le fichier d'une ressource restreinte.
  v_t := 'T9 liste fermee des fonctions de session qui rendent source_url';
  BEGIN
    SELECT string_agg(n.nspname || '.' || p.proname, ', ' ORDER BY p.proname) INTO v_txt
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('public', 'api')
       AND pg_get_function_result(p.oid) ~ '\msource_url\M'
       AND p.prosrc ~ 'book_digital_resources'
       AND (has_function_privilege('anon', p.oid, 'EXECUTE') OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'get_book_primary_public_digital_asset_v2'
       AND p.prosrc ~ 'access_scope\s*=\s*''publico''';
    IF v_txt = 'public.get_accessible_digital_asset_by_id_v2, public.get_book_primary_public_digital_asset_v2' AND v_n = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'∅')||' ; filtre public='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'D17-PAGE-SOURCE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'D17-PAGE-SOURCE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
