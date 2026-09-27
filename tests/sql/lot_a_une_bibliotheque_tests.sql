-- =====================================================================
-- AnarBib — Tests d'acceptation : un lot de catalogage a une bibliothèque
-- (B30, suite de B29, REGISTRE CAT-E18)
-- Date    : 2026-09-27
-- Ref     : migration 20260927191059_b30_lot_a_une_bibliotheque
--
-- Profils : coordination de A (seed), bibliothécaire de B, staff de A ET de B,
-- lectrice de A, admin réseau sans adhésion, coordination de B qui n'est que
-- bibliothécaire en A, admin réseau aussi bibliothécaire de A, ancienne
-- bibliothécaire de A (adhésion inactive). Écritures par l'API sous le rôle
-- authenticated (politiques, déclencheurs) ; RPC en postgres avec l'identité
-- du jeton.
-- T1  création par l'API : bibliothèque posée (défaut ou choix), hors de ses
--     bibliothèques refusée, figée ensuite ; l'administration crée un lot
--     sans bibliothèque (même quand elle est aussi staff).
-- T2  voir : le staff de la bibliothèque du lot, l'administration.
-- T3  modifier (fermer) : idem ; supprimer : la coordination DE ce lot.
-- T4  ranger : notice, exemplaire saisi, autorité ; refus à la création dit,
--     rangement en masse refusé sans erreur, restauration et changement de
--     bibliothèque sortent du lot (et pas vers l'ancien lot), un exemplaire
--     importé suit sa notice, une bibliothèque seulement matérialisée ne
--     compte pas ; l'administration range tout.
-- T5  réattribution : change la bibliothèque du lot, même vide ; autorités
--     d'une personne qui n'est pas staff de la nouvelle : hors du lot ; la
--     note garde la bibliothèque d'avant.
-- T6  imports : le lot naît avec la bibliothèque du run, ou la destination
--     d'un dépôt ou d'un entrepôt OAI (nulle si inconnue).
-- T7  révision : la coordination DU lot ; cotes d'un lot de l'administration.
-- T7b refus dans l'ordre : autre bibliothèque avant existence ou statut.
-- T8  reprises dans un lot : seulement de SA bibliothèque.
-- T9  rejeu d'un brouillon dont le lot a disparu : hors lot, sans erreur.
-- T10 listes : révisions avec la bibliothèque du lot ; bibliothèques des
--     brouillons en cours.
-- T11 publier : l'administration sans adhésion ; une adhésion inactive, non.
-- T12 reprise des lots existants (fn_b30_lot_bibliotheque_initiale).
-- T13 rapport et rubriques : les brouillons de la bibliothèque du lot.
-- T14 supprimer : ce qui l'empêche, compté sur tout le lot.
-- T15 lot approuvé : l'administration redemande une révision, puis réattribue.
-- T16 une notice importée sans bibliothèque ne se publie pas (ni chez qui publie).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'LOT-A-UNE-BIBLIOTHEQUE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coordA uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin  uuid := '22222222-2222-2222-2222-222222222222';  -- admin reseau, sans adhesion
  v_libA   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid; v_libBibB uuid; v_multi uuid; v_reader uuid; v_coordB uuid; v_adminStaff uuid; v_ancien uuid;
  v_lotA bigint; v_lotB bigint; v_lotAdm bigint; v_lot bigint; v_lot2 bigint; v_lotImpA bigint;
  v_bA bigint; v_bB bigint; v_bA2 bigint; v_bC bigint; v_xA bigint; v_x2 bigint; v_aA bigint; v_id bigint;
  v_id2 bigint; v_id3 bigint; v_id4 bigint; v_id5 bigint; v_x3 bigint; v_x4 bigint;
  v_src bigint; v_run bigint; v_row bigint; v_bookB bigint; v_exA bigint; v_audit bigint;
  v_n int; v_m int; v_k int; v_hint text; v_txt text; v_txt2 text; v_ok boolean; v_uuid uuid;
  v_res jsonb; v_res2 jsonb; v_nomA text;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-b30-b', 'Essai B30 — B', true, 'private') RETURNING id INTO v_libB;
  SELECT name INTO v_nomA FROM public.libraries WHERE id = v_libA;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'b30-' || n || '-' || gen_random_uuid() || '@example.invalid', now(), now()
    FROM generate_series(1, 6) n;
  SELECT id INTO v_libBibB    FROM auth.users WHERE email LIKE 'b30-1-%';
  SELECT id INTO v_multi      FROM auth.users WHERE email LIKE 'b30-2-%';
  SELECT id INTO v_reader     FROM auth.users WHERE email LIKE 'b30-3-%';
  SELECT id INTO v_coordB     FROM auth.users WHERE email LIKE 'b30-4-%';
  SELECT id INTO v_adminStaff FROM auth.users WHERE email LIKE 'b30-5-%';
  SELECT id INTO v_ancien     FROM auth.users WHERE email LIKE 'b30-6-%';
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT u, 'Essai', 'B30' FROM unnest(ARRAY[v_libBibB, v_multi, v_reader, v_coordB, v_adminStaff, v_ancien]) u ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_libBibB, v_libB, 'librarian', 'active', true),
    (v_multi, v_libA, 'librarian', 'active', true),
    (v_multi, v_libB, 'librarian', 'active', false),
    (v_reader, v_libA, 'reader', 'active', true),
    (v_coordB, v_libB, 'coordenador', 'active', true),
    (v_coordB, v_libA, 'librarian', 'active', false),
    (v_adminStaff, v_libA, 'librarian', 'active', true),
    (v_ancien, v_libA, 'librarian', 'inactive', true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_adminStaff, 'active');

  INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 lot A', v_coordA, v_libA) RETURNING id INTO v_lotA;
  INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 lot B', v_libBibB, v_libB) RETURNING id INTO v_lotB;
  INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 lot de l''administration', v_admin, NULL) RETURNING id INTO v_lotAdm;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
  VALUES ('B30 Notice de A', 'livro', v_libA, v_coordA, v_lotA, 'draft') RETURNING id INTO v_bA;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
  VALUES ('B30 Notice de B', 'livro', v_libB, v_libBibB, 'draft') RETURNING id INTO v_bB;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
  VALUES ('B30 Autre notice de A', 'livro', v_libA, v_coordA, 'draft') RETURNING id INTO v_bA2;
  INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by)
  VALUES ('create', 'draft', 'pending', v_libA, v_coordA) RETURNING id INTO v_xA;
  INSERT INTO public.author_drafts (preferred_name, status, created_by) VALUES ('B30 Autorite de A', 'draft', v_coordA) RETURNING id INTO v_aA;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 creation par l''API : bibliotheque posee, hors portee refusee, figee ; lot sans bibliotheque par l''admin';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.catalog_batches (name) VALUES ('B30 lot cree par libB') RETURNING id, library_id INTO v_lot, v_uuid;
    v_hint := NULL;
    BEGIN
      INSERT INTO public.catalog_batches (name, library_id) VALUES ('B30 lot force en A', v_libA);
      v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_hint := SQLSTATE;
    END;
    UPDATE public.catalog_batches SET library_id = v_libA WHERE id = v_lot;
    EXECUTE 'RESET ROLE';
    v_ok := v_uuid = v_libB AND (SELECT library_id FROM public.catalog_batches WHERE id = v_lot) = v_libB;
    -- multi (A et B) choisit B ; puis ne le déplace pas vers A.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.catalog_batches (name, library_id) VALUES ('B30 lot de multi en B', v_libB) RETURNING id INTO v_lot2;
    UPDATE public.catalog_batches SET library_id = v_libA WHERE id = v_lot2;
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND (SELECT library_id FROM public.catalog_batches WHERE id = v_lot2) = v_libB;
    -- l'administration : un lot sans bibliothèque, qu'elle ne change pas non plus par l'API.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.catalog_batches (name) VALUES ('B30 lot cree par l''admin') RETURNING id, library_id INTO v_id, v_uuid;
    UPDATE public.catalog_batches SET library_id = v_libA WHERE id = v_id;
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND v_uuid IS NULL AND (SELECT library_id FROM public.catalog_batches WHERE id = v_id) IS NULL;
    -- une administratrice aussi staff de A : sans choix, un lot de
    -- l'administration ; avec A choisie, un lot de A.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_adminStaff, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.catalog_batches (name) VALUES ('B30 lot reseau d''une admin de A') RETURNING library_id INTO v_uuid;
    v_ok := v_ok AND v_uuid IS NULL;
    INSERT INTO public.catalog_batches (name, library_id) VALUES ('B30 lot de A d''une admin', v_libA) RETURNING library_id INTO v_uuid;
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND v_uuid = v_libA;
    -- la lectrice ne crée pas de lot.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_reader, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_txt := NULL;
    BEGIN
      INSERT INTO public.catalog_batches (name) VALUES ('B30 lot de la lectrice');
      v_txt := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE;
    END;
    EXECUTE 'RESET ROLE';
    IF v_ok AND v_hint = '42501' AND v_txt = '42501'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : bibliotheques='||coalesce(v_ok::text,'∅')||' force en A='||coalesce(v_hint,'∅')||' lectrice='||coalesce(v_txt,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 voir : staff de la bibliotheque du lot, administration';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.catalog_batches WHERE id IN (v_lotA, v_lotB, v_lotAdm);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_m FROM public.catalog_batches WHERE id IN (v_lotA, v_lotB, v_lotAdm);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_k FROM public.catalog_batches WHERE id IN (v_lotA, v_lotB, v_lotAdm);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_reader, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_id FROM public.catalog_batches WHERE id IN (v_lotA, v_lotB, v_lotAdm);
    EXECUTE 'RESET ROLE';
    IF v_n = 1 AND v_m = 2 AND v_k = 3 AND v_id = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA='||v_n||' multi='||v_m||' admin='||v_k||' lectrice='||v_id); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 fermer : staff du lot ; supprimer : coordination DE ce lot';
  BEGIN
    -- libB ne ferme pas le lot de A ; coordA, si (puis on le rouvre).
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.catalog_batches SET status = 'closed' WHERE id = v_lotA;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.catalog_batches SET notes = 'b30' WHERE id = v_lotA;
    GET DIAGNOSTICS v_m = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    -- deux lots vides : un de A, un de B. coordB coordonne B et n'est que
    -- bibliothécaire en A.
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 vide de A', v_coordA, v_libA) RETURNING id INTO v_lot;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 vide de B', v_libBibB, v_libB) RETURNING id INTO v_lot2;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    v_ok := public.fn_caller_coordinates_batch(v_lot2) AND NOT public.fn_caller_coordinates_batch(v_lot)
            AND public.fn_caller_owns_batch(v_lot);
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM public.catalog_batches WHERE id = v_lot;
    GET DIAGNOSTICS v_k = ROW_COUNT;                                          -- 0
    DELETE FROM public.catalog_batches WHERE id = v_lot2;
    GET DIAGNOSTICS v_id = ROW_COUNT;                                         -- 1
    EXECUTE 'RESET ROLE';
    -- libB (bibliothécaire) ne supprime pas un lot vide de B.
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 autre vide de B', v_libBibB, v_libB) RETURNING id INTO v_lot2;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM public.catalog_batches WHERE id = v_lot2;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_m = 1 AND v_ok AND v_k = 0 AND v_id = 1 AND v_n = 0
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lotA) = 'open'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA modifie='||v_m||' predicats coordB='||coalesce(v_ok::text,'∅')||' coordB suppr A='||v_k||' coordB suppr B='||v_id||' libB suppr='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 ranger : seulement dans un lot de SA bibliotheque';
  BEGIN
    -- multi (A et B) : une notice de A dans le lot de A, oui ; une notice de B
    -- dans le lot de A, non (rangement en masse : rien ne bouge, sans erreur) ;
    -- une notice neuve de B créée dans le lot de A : refus dit.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = v_lotA WHERE id IN (v_bA2, v_bB);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_hint := NULL;
    BEGIN
      INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, batch_id) VALUES ('B30 Neuve de B dans A', 'livro', v_libB, v_lotA);
      v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    -- un exemplaire saisi de A dans le lot de A ; dans le lot de B, non.
    UPDATE public.exemplar_drafts SET batch_id = v_lotB WHERE id = v_xA;
    EXECUTE 'RESET ROLE';
    v_ok := (SELECT batch_id FROM public.book_drafts WHERE id = v_bA2) = v_lotA
            AND (SELECT batch_id FROM public.book_drafts WHERE id = v_bB) IS NULL
            AND (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_xA) IS NULL;
    -- coordA : l'autorité dans le lot de A, oui ; dans le lot de B, non.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.author_drafts SET batch_id = v_lotB WHERE id = v_aA;
    v_ok := v_ok AND (SELECT batch_id FROM public.author_drafts WHERE id = v_aA) IS NULL;
    UPDATE public.author_drafts SET batch_id = v_lotA WHERE id = v_aA;
    v_ok := v_ok AND (SELECT batch_id FROM public.author_drafts WHERE id = v_aA) = v_lotA;
    EXECUTE 'RESET ROLE';
    -- multi change la bibliothèque d'une notice rangée dans le lot de A : elle en sort.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET owner_library_id = v_libB WHERE id = v_bA2;
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND (SELECT batch_id FROM public.book_drafts WHERE id = v_bA2) IS NULL;
    -- une notice de B jetée dans le lot de A (héritage) : restaurée par libB, elle en sort.
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Jetee de B dans A', 'livro', v_libB, v_libBibB, v_lotA, 'cancelled') RETURNING id INTO v_id;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_id;
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND (SELECT batch_id FROM public.book_drafts WHERE id = v_id) IS NULL
                 AND (SELECT status FROM public.book_drafts WHERE id = v_id) = 'draft';

    -- Combinaisons d'un même UPDATE, par multi, staff de A ET de B (le lot de
    -- A est donc le sien : c'est la règle « même bibliothèque » qui joue).
    -- (a) une notice de B jetée dans le lot de A, restaurée : hors du lot ;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Jetee de B restauree par multi', 'livro', v_libB, v_multi, v_lotA, 'cancelled') RETURNING id INTO v_id;
    -- (b) une notice de A du lot de A rangée dans le lot de l'administration : refus, elle reste dans A ;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Reste dans A', 'livro', v_libA, v_multi, v_lotA, 'draft') RETURNING id INTO v_bC;
    -- (c) la même, avec un passage à B dans le même UPDATE : hors lot (pas ramenée dans A, qui ne l'accueille plus) ;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Refusee et changee', 'livro', v_libA, v_multi, v_lotA, 'draft') RETURNING id INTO v_id2;
    -- (d) passage à B avec un lot de B : accepté ;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Changee avec son lot', 'livro', v_libA, v_multi, v_lotA, 'draft') RETURNING id INTO v_id3;
    -- (e) une notice importée passée à B (seule owner_library_id dans le SET) :
    --     hors du lot, et son exemplaire importé la suit ;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Notice a exemplaire importe', 'livro', v_libA, v_multi, v_lotA, 'draft') RETURNING id INTO v_id4;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, book_draft_id, batch_id)
    VALUES ('create', 'draft', 'pending', v_libA, v_multi, v_id4, v_lotA) RETURNING id INTO v_x2;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_id;
    UPDATE public.book_drafts SET batch_id = v_lotAdm WHERE id = v_bC;
    UPDATE public.book_drafts SET batch_id = v_lotAdm, owner_library_id = v_libB WHERE id = v_id2;
    UPDATE public.book_drafts SET batch_id = v_lotB, owner_library_id = v_libB WHERE id = v_id3;
    UPDATE public.book_drafts SET owner_library_id = v_libB WHERE id = v_id4;
    EXECUTE 'RESET ROLE';
    -- (f) une notice d'avant B29 (sans bibliothèque), rangée dans le lot de
    --     l'administration, enregistrée par sa créatrice (l'écran renvoie
    --     owner_library_id nul) : la bibliothèque qu'on lui matérialise n'est
    --     pas un changement — elle reste dans le lot ;
    -- (f') la même chose pour un exemplaire saisi sans cible ;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 D''avant B29', 'livro', NULL, v_coordA, v_lotAdm, 'draft') RETURNING id INTO v_id5;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, batch_id)
    VALUES ('create', 'draft', 'pending', NULL, v_coordA, v_lotAdm) RETURNING id INTO v_x3;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET owner_library_id = NULL WHERE id = v_id5;
    UPDATE public.exemplar_drafts SET target_library_id = NULL WHERE id = v_x3;
    EXECUTE 'RESET ROLE';
    -- (g) un exemplaire saisi de A, rangé dans le lot de A, passé à B (seule
    --     target_library_id dans le SET) : hors du lot.
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, batch_id)
    VALUES ('create', 'draft', 'pending', v_libA, v_multi, v_lotA) RETURNING id INTO v_x4;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET target_library_id = v_libB WHERE id = v_x4;
    EXECUTE 'RESET ROLE';
    v_txt2 := concat_ws(' ',
      CASE WHEN (SELECT batch_id FROM public.book_drafts WHERE id = v_id) IS NOT NULL THEN 'a' END,
      CASE WHEN (SELECT batch_id FROM public.book_drafts WHERE id = v_bC) IS DISTINCT FROM v_lotA THEN 'b' END,
      CASE WHEN (SELECT batch_id FROM public.book_drafts WHERE id = v_id2) IS NOT NULL
             OR (SELECT owner_library_id FROM public.book_drafts WHERE id = v_id2) IS DISTINCT FROM v_libB THEN 'c' END,
      CASE WHEN (SELECT batch_id FROM public.book_drafts WHERE id = v_id3) IS DISTINCT FROM v_lotB THEN 'd' END,
      CASE WHEN (SELECT batch_id FROM public.book_drafts WHERE id = v_id4) IS NOT NULL THEN 'e-notice' END,
      CASE WHEN (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_x2) IS NOT NULL THEN 'e-exemplaire' END,
      CASE WHEN (SELECT batch_id FROM public.book_drafts WHERE id = v_id5) IS DISTINCT FROM v_lotAdm
             OR (SELECT owner_library_id FROM public.book_drafts WHERE id = v_id5) IS DISTINCT FROM v_libA THEN 'f' END,
      CASE WHEN (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_x3) IS DISTINCT FROM v_lotAdm THEN 'f''' END,
      CASE WHEN (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_x4) IS NOT NULL
             OR (SELECT target_library_id FROM public.exemplar_drafts WHERE id = v_x4) IS DISTINCT FROM v_libB THEN 'g' END);

    -- l'administration range où elle veut.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = v_lotAdm WHERE id = v_bB;
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND (SELECT batch_id FROM public.book_drafts WHERE id = v_bB) = v_lotAdm;
    IF v_ok AND v_n = 2 AND v_hint = 'error.batch.library_mismatch' AND v_txt2 = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : etats='||coalesce(v_ok::text,'∅')||' lignes='||v_n||' creation='||coalesce(v_hint,'∅')||' combinaisons en echec='||coalesce(nullif(v_txt2, ''),'aucune')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 reattribution : la bibliotheque du lot change, meme vide ; autorites d''ailleurs hors du lot ; trace';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 vide a donner a B', v_admin, NULL) RETURNING id INTO v_lot;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_reassign_library(v_lot, v_libB);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    v_ok := (SELECT library_id FROM public.catalog_batches WHERE id = v_lot) = v_libB
            AND NOT ((v_res->'warnings') ? 'nothing_to_do')
            AND (v_res->>'previous_library_id') IS NULL
            AND public.fn_caller_can_see_batch(v_lot)
            AND (SELECT notes FROM public.catalog_batches WHERE id = v_lot) LIKE '%lote antes : administracao da rede%';
    -- un lot de A donné à B : l'autorité de coordA (pas staff de B) sort du
    -- lot ; celles de multi (staff de B) et de l'administration restent.
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 lot de A donne a B', v_coordA, v_libA) RETURNING id INTO v_lot2;
    INSERT INTO public.author_drafts (preferred_name, status, created_by, batch_id) VALUES ('B30 Aut. de coordA', 'draft', v_coordA, v_lot2) RETURNING id INTO v_id2;
    INSERT INTO public.author_drafts (preferred_name, status, created_by, batch_id) VALUES ('B30 Aut. de multi', 'ready', v_multi, v_lot2) RETURNING id INTO v_id3;
    INSERT INTO public.author_drafts (preferred_name, status, created_by, batch_id) VALUES ('B30 Aut. de l''admin', 'draft', v_admin, v_lot2) RETURNING id INTO v_id4;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_res2 := public.fn_batch_reassign_library(v_lot2, v_libB);
    IF v_ok
       AND (SELECT library_id FROM public.catalog_batches WHERE id = v_lot2) = v_libB
       AND (v_res2->>'authors_detached')::int = 1 AND (v_res2->'warnings') ? 'authors_detached'
       AND (SELECT batch_id FROM public.author_drafts WHERE id = v_id2) IS NULL
       AND (SELECT batch_id FROM public.author_drafts WHERE id = v_id3) = v_lot2
       AND (SELECT batch_id FROM public.author_drafts WHERE id = v_id4) = v_lot2
       AND (v_res2->>'previous_library_id')::uuid = v_libA AND v_res2->>'previous_library_name' = v_nomA
       AND (SELECT notes FROM public.catalog_batches WHERE id = v_lot2) LIKE '%lote antes : ' || v_nomA || '%'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : vide='||coalesce(v_ok::text,'∅')||' '||coalesce(v_res::text,'∅')||' / lot de A='||coalesce(v_res2::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 imports : bibliotheque du run, destination d''un depot ou d''un entrepot OAI, nulle si inconnue';
  BEGIN
    INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
    VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
    -- catalogue propre de A
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('Essai B30 propre', v_libA, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_libA, 'essai/b30.marc', 'b30.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'b30-1', 'B30 Importee propre', 'new_record', 'accept_new') RETURNING id INTO v_row;
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_run, ARRAY[v_row], NULL, NULL, v_coordA);
    v_lotImpA := (v_res->>'batch_id')::bigint;
    v_ok := (SELECT library_id FROM public.catalog_batches WHERE id = v_lotImpA) = v_libA;
    -- dépôt d'une compagne sans destination connue : l'administration
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('Essai B30 depot', v_libA, 'mapeada', 'partner_deposit', true) RETURNING id INTO v_src;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_libA, 'essai/b30d.marc', 'b30d.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'b30-2', 'B30 Importee depot', 'new_record', 'accept_new') RETURNING id INTO v_row;
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_run, ARRAY[v_row], NULL, NULL, v_admin);
    v_ok := v_ok AND (SELECT library_id FROM public.catalog_batches WHERE id = (v_res->>'batch_id')::bigint) IS NULL;
    -- … puis la destination déclarée : B
    UPDATE ingest.partner_catalog_sources SET destination_library_id = v_libB WHERE id = v_src;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 2, 'b30-3', 'B30 Importee depot 2', 'new_record', 'accept_new') RETURNING id INTO v_row;
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_run, ARRAY[v_row], NULL, NULL, v_admin);
    v_ok := v_ok AND (SELECT library_id FROM public.catalog_batches WHERE id = (v_res->>'batch_id')::bigint) = v_libB;
    -- entrepôt OAI sans destination : l'administration ; avec, la destination
    INSERT INTO ingest.partner_catalog_sources
      (partner_name, library_id, relation_status, source_kind, import_enabled, oai_endpoint_url, oai_metadata_prefix)
    VALUES ('Essai B30 entrepot', v_libA, 'mapeada', 'oai_pmh', true, 'https://entrepot-b30.invalid/oai', 'marcxml')
    RETURNING id INTO v_src;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_libA, 'essai/b30o.marc', 'b30o.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'b30-4', 'B30 Moissonnee', 'new_record', 'accept_new') RETURNING id INTO v_row;
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_run, ARRAY[v_row], NULL, NULL, v_admin);
    v_ok := v_ok AND (SELECT library_id FROM public.catalog_batches WHERE id = (v_res->>'batch_id')::bigint) IS NULL;
    UPDATE ingest.partner_catalog_sources SET destination_library_id = v_libB WHERE id = v_src;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 2, 'b30-5', 'B30 Moissonnee 2', 'new_record', 'accept_new') RETURNING id INTO v_row;
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_run, ARRAY[v_row], NULL, NULL, v_admin);
    v_ok := v_ok AND (SELECT library_id FROM public.catalog_batches WHERE id = (v_res->>'batch_id')::bigint) = v_libB;
    IF v_ok
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 revision : la coordination DU lot ; cotes d''un lot de l''administration : sans convention';
  BEGIN
    -- coordB (coordonne B, bibliothécaire en A) ne demande pas la révision d'un lot de A.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM public.fn_batch_review_request(v_lotA, NULL);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    -- lot de l'administration : pas de convention (no_owner).
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_txt := NULL;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Sans cote dans le lot admin', 'livro', v_libA, v_coordA, v_lotAdm, 'draft');
    BEGIN PERFORM public.fn_batch_assign_bib_refs(v_lotAdm, false);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT; END;
    IF v_txt = 'error.bibref.batch.no_owner'
       AND v_hint = 'error.review.coordenador_only'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cotes='||coalesce(v_txt,'acceptees')||' / revision coordB='||coalesce(v_hint,'accepte')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T7b refus dans l''ordre : autre bibliotheque avant existence ou statut';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    v_txt := '';
    BEGIN PERFORM public.publish_catalog_batch(v_lotA);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.publish_catalog_batch(-1);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.fn_batch_review_report(v_lotA);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.fn_batch_review_report(-1);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.fn_batch_assign_bib_refs(v_lotA, false);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.fn_batch_assign_bib_refs(-1, false);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM * FROM public.fn_batch_rubrics(v_lotA);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM * FROM public.fn_batch_rubrics(-1);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint; END;
    IF v_txt = 'error.batch.other_libraries error.batch.other_libraries error.batch.other_libraries error.batch.other_libraries '
               || 'error.bibref.batch.staff_only error.bibref.batch.staff_only error.rubrics.batch.staff_only error.rubrics.batch.staff_only'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 reprises dans un lot : seulement un lot de SA bibliotheque';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('B30 Livre publie de B', 'B30-B-1', 'livro', v_libB) RETURNING id INTO v_bookB;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, circulation_policy) VALUES ('B30-A-1', 'B30-TOMBO-A', v_libA, 'emprestavel') RETURNING id INTO v_exA;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    -- reprise d'une notice de B par coordA : le brouillon est à A → lot de A, oui ; lot de B, non.
    v_id := public.create_book_draft_from_book(v_bookB, v_lotA);
    v_txt := '';
    BEGIN PERFORM public.create_book_draft_from_book(v_bookB, v_lotB); v_txt := v_txt || 'livre-accepte ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.create_exemplar_draft_from_exemplar(v_exA, v_lotB); v_txt := v_txt || 'ex-accepte ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    PERFORM public.create_exemplar_draft_from_exemplar(v_exA, v_lotA);
    IF (SELECT batch_id FROM public.book_drafts WHERE id = v_id) = v_lotA
       AND v_txt = 'error.batch.other_libraries error.batch.other_libraries '
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 rejeu d''un brouillon dont le lot a disparu : hors lot, sans erreur';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 lot qui disparait', v_coordA, v_libA) RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Jetee puis rejouee', 'livro', v_libA, v_coordA, v_lot, 'cancelled') RETURNING id INTO v_id;
    DELETE FROM public.book_drafts WHERE id = v_id;
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_id;
    DELETE FROM public.catalog_batches WHERE id = v_lot;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_res := public.fn_restore_deleted_draft(v_audit);
    IF (v_res->>'ok')::boolean AND (SELECT batch_id FROM public.book_drafts WHERE id = v_id) IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 listes : revisions avec la bibliotheque du lot ; bibliotheques des brouillons en cours';
  BEGIN
    INSERT INTO public.catalog_batch_reviews (batch_id, status, requested_by, report) VALUES (v_lotA, 'requested', v_coordA, '{"b30": "A"}');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    SELECT r.batch_library_id = v_libA AND r.batch_library_name IS NOT NULL AND r.report IS NOT NULL INTO v_ok
      FROM public.fn_batch_reviews_list() r WHERE r.batch_id = v_lotA;
    SELECT count(*) INTO v_n FROM public.fn_batch_reviews_list() r WHERE r.batch_id IN (v_lotB, v_lotAdm);
    SELECT count(*) INTO v_m FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lotA;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_k FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lotA;
    IF coalesce(v_ok, false) AND v_n = 0 AND v_m >= 1 AND v_k = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : revision='||coalesce(v_ok::text,'∅')||' lots d''autrui listes='||v_n||' owners coordA='||v_m||' owners libB='||v_k); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  v_t := 'T11 publier : l''administration sans adhesion publie ; une adhesion inactive ne suffit plus';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 lot de l''administration a publier', v_admin, NULL) RETURNING id INTO v_lot;
    INSERT INTO public.author_drafts (action, status, preferred_name, sort_name, created_by, updated_by, batch_id)
    VALUES ('create', 'ready', 'Ottavia B30 Lotto', 'Lotto, Ottavia B30', v_admin, v_admin, v_lot);
    INSERT INTO public.author_drafts (action, status, preferred_name, sort_name, created_by, updated_by)
    VALUES ('create', 'draft', 'Ottavia B30 Sola', 'Sola, Ottavia B30', v_admin, v_admin) RETURNING id INTO v_id;
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Notice publiee par l''administration', 'B30-ADM-1', 'livro', v_libA, v_admin, v_lot, 'ready');
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('B30 Livre de A', 'B30-ADM-0', 'livro', v_libA);
    -- une série de tombos pour A (l'exemplaire initial de la notice, celui de l'exemplaire saisi)
    UPDATE public.libraries SET tombo_pattern = '{"prefix": "B30-ADM-", "year": false, "pad": 4}'::jsonb WHERE id = v_libA;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, created_by, batch_id)
    VALUES ('create', 'ready', 'pending', v_libA, 'B30-ADM-0', v_admin, v_lot);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_res := public.publish_catalog_batch(v_lot);
    v_id2 := public.publish_author_draft(v_id);
    -- une ancienne bibliothécaire de A (adhésion inactive) : plus de publication.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_ancien, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM public.publish_catalog_batch(v_lotA);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    v_txt := NULL;
    BEGIN PERFORM public.publish_book_draft(v_bA);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT; END;
    IF (SELECT status FROM public.catalog_batches WHERE id = v_lot) = 'published'
       AND (v_res->>'authors_published')::int = 1 AND v_id2 IS NOT NULL
       AND (v_res->>'books_published')::int = 1 AND (v_res->>'exemplars_published')::int = 1
       AND EXISTS (SELECT 1 FROM public.books b JOIN public.book_holdings h ON h.book_id = b.id
                    WHERE b.bib_ref = 'B30-ADM-1' AND h.library_id = v_libA)
       AND v_hint = 'error.catalog.staff_only' AND v_txt = 'error.catalog.staff_only'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot='||coalesce(v_res::text,'∅')||' seule='||coalesce(v_id2::text,'∅')||' inactive lot='||coalesce(v_hint,'acceptee')||' inactive notice='||coalesce(v_txt,'acceptee')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 reprise : bibliotheque d''un lot existant — en cours d''abord, puis publiees, puis createur';
  BEGIN
    v_txt2 := '';
    -- (a) en cours de A, publiée de B (réattribué après une publication partielle) : A
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 reprise a', v_coordA, NULL) RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status) VALUES
      ('B30 ra en cours', 'livro', v_libA, v_coordA, v_lot, 'draft'),
      ('B30 ra publiee', 'livro', v_libB, v_libBibB, v_lot, 'published');
    IF public.fn_b30_lot_bibliotheque_initiale(v_lot) IS DISTINCT FROM v_libA THEN v_txt2 := v_txt2 || 'a '; END IF;
    -- (b) en cours de A et de B : aucune
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 reprise b', v_coordA, NULL) RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status) VALUES
      ('B30 rb de A', 'livro', v_libA, v_coordA, v_lot, 'draft'),
      ('B30 rb de B', 'livro', v_libB, v_libBibB, v_lot, 'ready');
    IF public.fn_b30_lot_bibliotheque_initiale(v_lot) IS NOT NULL THEN v_txt2 := v_txt2 || 'b '; END IF;
    -- (c) publiées de B seulement : B
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 reprise c', v_coordA, NULL) RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status) VALUES
      ('B30 rc publiee', 'livro', v_libB, v_libBibB, v_lot, 'published');
    IF public.fn_b30_lot_bibliotheque_initiale(v_lot) IS DISTINCT FROM v_libB THEN v_txt2 := v_txt2 || 'c '; END IF;
    -- (d) rien que la corbeille, lot créé par coordA : sa bibliothèque de staff
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 reprise d', v_coordA, NULL) RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status) VALUES
      ('B30 rd jetee', 'livro', v_libB, v_libBibB, v_lot, 'cancelled');
    IF public.fn_b30_lot_bibliotheque_initiale(v_lot) IS NULL
       OR public.fn_b30_lot_bibliotheque_initiale(v_lot) IS DISTINCT FROM public.fn_user_staff_library(v_coordA) THEN v_txt2 := v_txt2 || 'd '; END IF;
    -- (e) vide, créé par une administratrice aussi staff : aucune
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 reprise e', v_adminStaff, NULL) RETURNING id INTO v_lot;
    IF public.fn_b30_lot_bibliotheque_initiale(v_lot) IS NOT NULL THEN v_txt2 := v_txt2 || 'e '; END IF;
    -- (f) un exemplaire saisi en cours de B, seul : B
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 reprise f', v_coordA, NULL) RETURNING id INTO v_lot;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, batch_id)
    VALUES ('create', 'draft', 'pending', v_libB, v_libBibB, v_lot);
    IF public.fn_b30_lot_bibliotheque_initiale(v_lot) IS DISTINCT FROM v_libB THEN v_txt2 := v_txt2 || 'f '; END IF;
    -- (g) un brouillon en cours de bibliothèque inconnue (créé par l'administration, sans owner) : aucune
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 reprise g', v_coordA, NULL) RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status) VALUES
      ('B30 rg sans bibliotheque', 'livro', NULL, v_admin, v_lot, 'draft');
    IF public.fn_b30_lot_bibliotheque_initiale(v_lot) IS NOT NULL THEN v_txt2 := v_txt2 || 'g '; END IF;
    -- (h) une seule fiche PUBLIÉE de bibliothèque inconnue : aucune non plus (pas le créateur du lot)
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 reprise h', v_coordA, NULL) RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status) VALUES
      ('B30 rh publiee sans bibliotheque', 'livro', NULL, v_admin, v_lot, 'published');
    IF public.fn_b30_lot_bibliotheque_initiale(v_lot) IS NOT NULL THEN v_txt2 := v_txt2 || 'h '; END IF;
    IF v_txt2 = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cas en echec='||v_txt2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 rapport et rubriques : hors administration, les brouillons de la bibliotheque du lot';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 lot du rapport', v_coordA, v_libA) RETURNING id INTO v_lot;
    -- une notice de B rangée là par l'administration (comme T4 le permet)
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status) VALUES
      ('B30 Rapport de A', 'livro', v_libA, v_coordA, v_lot, 'draft'),
      ('B30 Rapport de B rangee par l''administration', 'livro', v_libB, v_libBibB, v_lot, 'draft'),
      ('B30 Rapport de B jetee', 'livro', v_libB, v_libBibB, v_lot, 'cancelled');
    -- un exemplaire de rapprochement de B (ligne importée de T6), rangé là par l'administration
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, batch_id, import_staging_row_id, source_item_code)
    VALUES ('create', 'draft', 'pending', v_libB, v_admin, v_lot, v_row, 'B30-RAP-B');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_review_report(v_lot);
    SELECT coalesce(sum(r.drafts), 0) INTO v_n FROM public.fn_batch_rubrics(v_lot) r;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_res2 := public.fn_batch_review_report(v_lot);
    SELECT coalesce(sum(r.drafts), 0) INTO v_m FROM public.fn_batch_rubrics(v_lot) r;
    IF (v_res->'batch'->>'drafts_active')::int = 1 AND (v_res2->'batch'->>'drafts_active')::int = 2
       AND (v_res->'batch'->>'drafts_cancelled')::int = 0 AND (v_res2->'batch'->>'drafts_cancelled')::int = 1
       AND (v_res->'items'->>'count')::int = 0 AND (v_res2->'items'->>'count')::int = 1
       AND position('Rapport de B' in v_res::text) = 0 AND position('B30-RAP-B' in v_res::text) = 0
       AND v_n = 1 AND v_m = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA='||coalesce(v_res->'batch'->>'drafts_active','∅')
         ||' (titre de B '||CASE WHEN position('Rapport de B' in coalesce(v_res::text, '')) > 0 THEN 'present' ELSE 'absent' END
         ||') admin='||coalesce(v_res2->'batch'->>'drafts_active','∅')||' rubriques coordA='||v_n||' admin='||v_m
         ||' corbeille coordA='||coalesce(v_res->'batch'->>'drafts_cancelled','∅')||' admin='||coalesce(v_res2->'batch'->>'drafts_cancelled','∅')
         ||' exemplaires coordA='||coalesce(v_res->'items'->>'count','∅')||' admin='||coalesce(v_res2->'items'->>'count','∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 ─────────────────────────────────────────────────────────────
  v_t := 'T14 supprimer un lot : ce qui l''empeche, compte sur tout le lot, pour sa coordination';
  BEGIN
    -- un lot de A avec une fiche publiée de A, donné à B (IMP-20 c : la fiche reste à A)
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B30 lot a supprimer', v_coordA, v_libA) RETURNING id INTO v_lot;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B30 Publiee de A', 'livro', v_libA, v_coordA, v_lot, 'published');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_reassign_library(v_lot, v_libB);
    -- coordB réduite à la coordination de B : elle ne voit pas la fiche de A.
    DELETE FROM public.user_library_memberships WHERE user_id = v_coordB AND library_id = v_libA;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    SELECT b.en_cours, b.publies INTO v_n, v_m FROM public.fn_batch_delete_blockers(v_lot) b;
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT c.publies INTO v_k FROM public.v_catalog_batch_draft_counts c WHERE c.batch_id = v_lot;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_id FROM public.fn_batch_delete_blockers(v_lot);
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES (v_coordB, v_libA, 'librarian', 'active', false);
    IF v_n = 0 AND v_m = 1 AND coalesce(v_k, 0) = 0 AND v_id = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : en cours='||coalesce(v_n::text,'∅')||' publiees='||coalesce(v_m::text,'∅')||' vue='||coalesce(v_k::text,'∅')||' libB lignes='||v_id); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T15 ─────────────────────────────────────────────────────────────
  v_t := 'T15 lot approuve : l''administration redemande une revision, puis change sa bibliotheque';
  BEGIN
    INSERT INTO public.catalog_batch_reviews (batch_id, round, status, requested_by, reviewed_by, reviewed_at)
    VALUES (v_lotImpA, 1, 'approved', v_coordA, v_admin, now());
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_txt := NULL;
    BEGIN PERFORM public.fn_batch_review_request(v_lotImpA, NULL);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM public.fn_batch_reassign_library(v_lotImpA, v_libB);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    v_res := public.fn_batch_review_request(v_lotImpA, 'B30 : nouvelle destination');
    v_res2 := public.fn_batch_reassign_library(v_lotImpA, v_libB);
    IF v_txt = 'error.review.already_approved' AND v_hint = 'error.batch.reassign.review_approved'
       AND (v_res->>'round')::int = 2
       AND (SELECT library_id FROM public.catalog_batches WHERE id = v_lotImpA) = v_libB
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA='||coalesce(v_txt,'acceptee')||' reattribution sous approbation='||coalesce(v_hint,'acceptee')||' nouveau tour='||coalesce(v_res::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  v_t := 'T16 une notice importee sans bibliotheque ne se publie pas, ni chez qui publie';
  BEGIN
    -- dépôt d'une compagne non admise, sans destination : lot et notice sans bibliothèque
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('Essai B30 depot sans destination', v_libA, 'mapeada', 'partner_deposit', true) RETURNING id INTO v_src;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_libA, 'essai/b30n.marc', 'b30n.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'b30-n', 'B30 Notice de compagne', 'new_record', 'accept_new') RETURNING id INTO v_row;
    v_res := ingest.fn_create_book_drafts_from_import_rows(v_run, ARRAY[v_row], NULL, NULL, v_admin);
    v_lot := (v_res->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_id FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id = v_row;
    UPDATE public.book_drafts SET bib_ref = 'B30-DEP-1', tipo_material = 'livro', owner_library_id = NULL WHERE id = v_id;
    INSERT INTO public.catalog_batch_reviews (batch_id, round, status, requested_by, reviewed_by, reviewed_at)
    VALUES (v_lot, 1, 'approved', v_admin, v_admin, now());
    -- une administratrice aussi bibliothécaire de A, puis l'administration sans adhésion
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_adminStaff, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM public.publish_book_draft(v_id);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_txt := NULL;
    BEGIN PERFORM public.publish_catalog_batch(v_lot);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT; END;
    -- supprimée définitivement puis rejouée depuis le journal : le lien d'import
    -- est parti en cascade, la trace marc_json.ingest reste — toujours refusée.
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_id;
    DELETE FROM public.book_drafts WHERE id = v_id;
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_id;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_adminStaff, 'role', 'authenticated')::text, true);
    v_res2 := public.fn_restore_deleted_draft(v_audit);
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_id;
    v_txt2 := NULL;
    BEGIN PERFORM public.publish_book_draft(v_id);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt2 = PG_EXCEPTION_HINT; END;
    IF (SELECT library_id FROM public.catalog_batches WHERE id = v_lot) IS NULL
       AND v_hint = 'error.publish.record_without_library' AND v_txt = 'error.publish.record_without_library'
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.draft_id = v_id)
       AND v_txt2 = 'error.publish.record_without_library'
       AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.bib_ref = 'B30-DEP-1')
       AND (SELECT status FROM public.book_drafts WHERE id = v_id) IN ('draft', 'ready')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : admin staff='||coalesce(v_hint,'publiee')||' admin='||coalesce(v_txt,'publiee')
         ||' rejouee='||coalesce(v_txt2,'publiee')||' restauration='||coalesce(v_res2::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'LOT-A-UNE-BIBLIOTHEQUE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'LOT-A-UNE-BIBLIOTHEQUE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
