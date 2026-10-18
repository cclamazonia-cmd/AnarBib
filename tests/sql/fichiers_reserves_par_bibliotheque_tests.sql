-- =====================================================================
-- AnarBib — Tests d'acceptation : fichiers réservés, chaque bibliothèque
-- gère les siens
-- Date    : 2026-10-17
-- Ref     : migration 20261018211310_fichiers_reserves_par_bibliotheque
-- Session : Modele de menace
--
-- T1 objets et droits : les deux aides sont DEFINER, search_path figé,
--    fermées à anon, ouvertes à authenticated ; les politiques versionnées
--    existent et les anciennes ont disparu (si storage.objects a des
--    politiques — le stub CI n'en a pas, on lit pg_policies) ;
--    book_digital_resources n'est plus inscriptible par authenticated.
-- T2 private.fn_objet_reserve_gerable, sous authenticated : l'équipe de A
--    gère le fichier d'un brouillon de A et celui d'un livre que A détient ;
--    l'équipe de B, un lecteur de A, non ; ce qu'on a versé soi-même, oui ;
--    l'administration du réseau partout.
-- T3 private.fn_dossier_reserve_versable : books/<brouillon de A>/ pour A,
--    pas pour B ; un chemin sans fichier, avec « .. » ou hors books/, non.
-- T4 trigger de cohérence : une ressource de brouillon réservée ne désigne
--    que books/<son brouillon>/ ou un fichier déjà rattaché au livre repris.
-- T5 fn_attach_received_asset_record : un chemin qui n'est pas
--    attached/<livre>/<reçu>_… est refusé sur les seuls arguments ; un objet
--    absent n'est constaté qu'après les gardes (pas d'oracle d'existence).
-- T6 fn_revoke_digital_asset_record : seul un fichier d'attache du livre
--    que plus rien ne désigne est déclaré orphelin.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'FICHIERS-RESERVES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_libA uuid; v_libB uuid;
  v_staffA uuid := gen_random_uuid(); v_coordA uuid := gen_random_uuid();
  v_staffB uuid := gen_random_uuid(); v_lectA uuid := gen_random_uuid();
  v_admin uuid := gen_random_uuid();
  v_book bigint; v_dA bigint; v_dB bigint; v_retake bigint;
  v_pA text; v_pB text; v_pLivre text; v_pAttache text;
  v_u uuid; v_txt text; v_b boolean; v_msg text; v_hint text; v_res jsonb; v_asset bigint;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('fr-a-' || v_suf, 'Fichiers A (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('fr-b-' || v_suf, 'Fichiers B (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libB;
  FOREACH v_u IN ARRAY ARRAY[v_staffA, v_coordA, v_staffB, v_lectA, v_admin] LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, created_at, updated_at)
    VALUES ('00000000-0000-0000-0000-000000000000', v_u, 'authenticated', 'authenticated', 'fr-' || v_u || '@example.invalid', now(), now());
    INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_u, 'Essai', 'FR') ON CONFLICT (id) DO NOTHING;
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_staffA, v_libA, 'librarian', 'active', true),
    (v_coordA, v_libA, 'coordenador', 'active', true),
    (v_staffB, v_libB, 'librarian', 'active', true),
    (v_lectA, v_libA, 'reader', 'active', true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('FR livre', 'FR-' || v_suf, 'livro', v_libA) RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_libA);
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, action)
  VALUES ('FR brouillon A', 'livro', v_libA, v_staffA, 'draft', 'create') RETURNING id INTO v_dA;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, action)
  VALUES ('FR brouillon B', 'livro', v_libB, v_staffB, 'draft', 'create') RETURNING id INTO v_dB;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, published_book_id, action)
  VALUES ('FR reprise A', 'livro', v_libA, v_staffA, 'draft', v_book, 'update') RETURNING id INTO v_retake;

  v_pA := 'books/' || v_dA || '/a.pdf';
  v_pB := 'books/' || v_dB || '/b.pdf';
  v_pLivre := 'books/999999' || v_suf || '/livre.pdf';
  v_pAttache := 'attached/' || v_book || '/7_recu.pdf';
  INSERT INTO storage.objects (bucket_id, name, owner_id) VALUES
    ('pdf-restrito', v_pA, NULL), ('pdf-restrito', v_pB, v_staffB::text),
    ('pdf-restrito', v_pLivre, NULL), ('pdf-restrito', v_pAttache, NULL)
  ON CONFLICT (bucket_id, name) DO NOTHING;
  INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
  VALUES (v_dA, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'pdf-restrito', v_pA, 'sob_direitos');
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, storage_bucket, storage_path)
  VALUES (v_book, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'active', true, 'pdf-restrito', v_pLivre);

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 objets et droits';
  BEGIN
    v_txt := '';
    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'private.fn_objet_reserve_gerable(text,text,text)'::regprocedure) THEN v_txt := v_txt || 'gerable-non-definer '; END IF;
    IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'private.fn_dossier_reserve_versable(text,text)'::regprocedure) THEN v_txt := v_txt || 'versable-non-definer '; END IF;
    IF has_function_privilege('anon', 'private.fn_objet_reserve_gerable(text,text,text)', 'EXECUTE') THEN v_txt := v_txt || 'gerable-anon '; END IF;
    IF has_function_privilege('anon', 'private.fn_dossier_reserve_versable(text,text)', 'EXECUTE') THEN v_txt := v_txt || 'versable-anon '; END IF;
    IF NOT has_function_privilege('authenticated', 'private.fn_objet_reserve_gerable(text,text,text)', 'EXECUTE') THEN v_txt := v_txt || 'gerable-ferme '; END IF;
    IF has_table_privilege('authenticated', 'public.book_digital_resources', 'INSERT')
       OR has_table_privilege('authenticated', 'public.book_digital_resources', 'UPDATE')
       OR has_table_privilege('authenticated', 'public.book_digital_resources', 'DELETE') THEN v_txt := v_txt || 'bdr-inscriptible '; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND policyname = 'pdf_restrito_select') THEN v_txt := v_txt || 'politique-absente '; END IF;
    IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND policyname = 'pdf_restrito_librarians_select') THEN v_txt := v_txt || 'ancienne-politique '; END IF;
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 qui gere un fichier reserve';
  BEGIN
    v_txt := '';
    -- équipe de A : brouillon de A, livre détenu par A
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staffA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    IF NOT private.fn_objet_reserve_gerable('pdf-restrito', v_pA, NULL) THEN v_txt := v_txt || 'A-brouillon-refuse '; END IF;
    IF NOT private.fn_objet_reserve_gerable('pdf-restrito', v_pLivre, NULL) THEN v_txt := v_txt || 'A-livre-refuse '; END IF;
    IF private.fn_objet_reserve_gerable('pdf-restrito', v_pB, v_staffB::text) THEN v_txt := v_txt || 'A-lit-B '; END IF;
    EXECUTE 'RESET ROLE';
    -- équipe de B : rien de A, mais ce qu'elle a versé
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staffB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    IF private.fn_objet_reserve_gerable('pdf-restrito', v_pA, NULL) THEN v_txt := v_txt || 'B-lit-brouillon-A '; END IF;
    IF private.fn_objet_reserve_gerable('pdf-restrito', v_pLivre, NULL) THEN v_txt := v_txt || 'B-lit-livre-A '; END IF;
    IF NOT private.fn_objet_reserve_gerable('pdf-restrito', v_pB, v_staffB::text) THEN v_txt := v_txt || 'B-perd-le-sien '; END IF;
    EXECUTE 'RESET ROLE';
    -- lecteur de A : rien
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lectA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    IF private.fn_objet_reserve_gerable('pdf-restrito', v_pLivre, NULL) THEN v_txt := v_txt || 'lecteur-gere '; END IF;
    IF private.fn_objet_reserve_gerable('pdf-restrito', v_pA, v_lectA::text) THEN v_txt := v_txt || 'lecteur-proprietaire-gere '; END IF;
    EXECUTE 'RESET ROLE';
    -- administration du réseau : partout
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    IF NOT private.fn_objet_reserve_gerable('pdf-restrito', v_pB, NULL) THEN v_txt := v_txt || 'admin-refuse '; END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 ou verser un fichier reserve';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staffA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    IF NOT private.fn_dossier_reserve_versable('pdf-restrito', 'books/' || v_dA || '/neuf.pdf') THEN v_txt := v_txt || 'A-son-brouillon-refuse '; END IF;
    IF private.fn_dossier_reserve_versable('pdf-restrito', 'books/' || v_dB || '/neuf.pdf') THEN v_txt := v_txt || 'A-chez-B '; END IF;
    IF private.fn_dossier_reserve_versable('pdf-restrito', 'books/' || v_dA || '/') THEN v_txt := v_txt || 'sans-fichier '; END IF;
    IF private.fn_dossier_reserve_versable('pdf-restrito', 'books/' || v_dA || '/../x.pdf') THEN v_txt := v_txt || 'point-point '; END IF;
    IF private.fn_dossier_reserve_versable('pdf-restrito', 'attached/' || v_book || '/1_x.pdf') THEN v_txt := v_txt || 'hors-books '; END IF;
    -- changement d'espace : le chemin d'une ressource de son brouillon
    IF NOT private.fn_dossier_reserve_versable('pdf-restrito', v_pA) THEN v_txt := v_txt || 'deplacement-refuse '; END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 une ressource reservee reste dans sa notice';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staffB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    -- B désigne le fichier du brouillon de A : refus
    v_hint := NULL;
    BEGIN INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
          VALUES (v_dB, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'pdf-restrito', v_pA, 'sob_direitos');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.digital.file_not_in_bucket' THEN v_txt := v_txt || 'B-vers-A=' || coalesce(v_hint, 'accepte') || ' '; END IF;
    -- B désigne son propre fichier : permis
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
    VALUES (v_dB, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'pdf-restrito', v_pB, 'sob_direitos');
    EXECUTE 'RESET ROLE';
    -- A, dans la reprise du livre : le fichier déjà rattaché au livre, permis
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staffA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
    VALUES (v_retake, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'pdf-restrito', v_pLivre, 'sob_direitos');
    -- mais pas le fichier d'attache non rattaché au livre
    v_hint := NULL;
    BEGIN INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
          VALUES (v_retake, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'pdf-restrito', v_pAttache, 'sob_direitos');
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.digital.file_not_in_bucket' THEN v_txt := v_txt || 'reprise-hors-livre=' || coalesce(v_hint, 'accepte') || ' '; END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 l''attache n''enregistre que son propre chemin';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    -- hors préfixe (fichier d'un brouillon) : refus avant toute lecture
    v_msg := NULL;
    BEGIN PERFORM public.fn_attach_received_asset_record(7, v_book, 'pdf-restrito', v_pA, 'both');
    EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
    IF v_msg IS DISTINCT FROM 'Caminho de destino inválido.' THEN v_txt := v_txt || 'hors-prefixe=' || coalesce(v_msg, 'accepte') || ' '; END IF;
    -- bon préfixe, objet absent : l'existence n'est lue qu'APRÈS les gardes
    -- (pas d'oracle) — ici la garde parle d'abord (reçu inconnu)
    v_msg := NULL;
    BEGIN PERFORM public.fn_attach_received_asset_record(7, v_book, 'pdf-restrito', 'attached/' || v_book || '/7_absent.pdf', 'both');
    EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
    IF v_msg IS DISTINCT FROM 'Recurso recebido introuvável.' THEN v_txt := v_txt || 'absent=' || coalesce(v_msg, 'accepte') || ' '; END IF;
    -- autre reçu, autre livre : refus
    v_msg := NULL;
    BEGIN PERFORM public.fn_attach_received_asset_record(8, v_book, 'pdf-restrito', v_pAttache, 'both');
    EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
    IF v_msg IS DISTINCT FROM 'Caminho de destino inválido.' THEN v_txt := v_txt || 'autre-recu=' || coalesce(v_msg, 'accepte') || ' '; END IF;
    -- bon chemin, objet présent : la garde suivante parle (reçu inconnu)
    v_msg := NULL;
    BEGIN PERFORM public.fn_attach_received_asset_record(7, v_book, 'pdf-restrito', v_pAttache, 'both');
    EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM; END;
    IF v_msg IS DISTINCT FROM 'Recurso recebido introuvável.' THEN v_txt := v_txt || 'bon-chemin=' || coalesce(v_msg, 'accepte') || ' '; END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 n''est orphelin que le fichier d''attache du livre';
  BEGIN
    v_txt := '';
    -- un asset qui désigne le fichier d'un livre (hors attached/) : jamais orphelin
    INSERT INTO public.digital_assets (asset_kind, title, book_id, source_name, review_state, bucket_name, object_path, is_public, mime_type)
    VALUES ('pdf', 'FR asset', v_book, 'AnarBib', 'to_review', 'pdf-restrito', v_pB, false, 'application/pdf') RETURNING id INTO v_asset;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_revoke_digital_asset_record(v_asset);
    EXECUTE 'RESET ROLE';
    IF (v_res->>'file_orphaned')::boolean THEN v_txt := v_txt || 'hors-attache-orphelin '; END IF;
    -- un fichier d'attache du livre que plus rien ne désigne : orphelin
    INSERT INTO public.digital_assets (asset_kind, title, book_id, source_name, review_state, bucket_name, object_path, is_public, mime_type)
    VALUES ('pdf', 'FR asset 2', v_book, 'AnarBib', 'to_review', 'pdf-restrito', v_pAttache, false, 'application/pdf') RETURNING id INTO v_asset;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_revoke_digital_asset_record(v_asset);
    EXECUTE 'RESET ROLE';
    IF NOT coalesce((v_res->>'file_orphaned')::boolean, false) THEN v_txt := v_txt || 'attache-non-orphelin '; END IF;
    -- le même, encore désigné par un brouillon : pas orphelin
    INSERT INTO public.digital_assets (asset_kind, title, book_id, source_name, review_state, bucket_name, object_path, is_public, mime_type)
    VALUES ('pdf', 'FR asset 3', v_book, 'AnarBib', 'to_review', 'pdf-restrito', v_pAttache, false, 'application/pdf') RETURNING id INTO v_asset;
    INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, usage_type, access_scope, storage_bucket, storage_path, rights_status)
    VALUES (v_retake, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'pdf-restrito', v_pAttache, 'sob_direitos');   -- postgres : trigger non joué
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_revoke_digital_asset_record(v_asset);
    EXECUTE 'RESET ROLE';
    IF (v_res->>'file_orphaned')::boolean THEN v_txt := v_txt || 'brouillon-ignore '; END IF;
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Bilan ───────────────────────────────────────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'FICHIERS-RESERVES OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'FICHIERS-RESERVES ECHEC : %/% — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
