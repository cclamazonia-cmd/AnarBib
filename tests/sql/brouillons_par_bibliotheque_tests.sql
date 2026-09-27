-- =====================================================================
-- AnarBib — Tests d'acceptation : les brouillons de catalogage appartiennent
-- à leur bibliothèque (B29, REGISTRE CAT-E18)
-- Date    : 2026-09-27
-- Ref     : migration 20260927160000_b29_brouillons_par_bibliotheque
--           + 20260927200627_b29_aides_internes_fermees_aux_comptes (T31)
--
-- Cinq personnes : coordination de A (seed), bibliothécaire de B, staff de A
-- ET de B, lectrice de A, admin réseau sans adhésion ; plus une coordination
-- de B qui n'est que bibliothécaire en A. Les lectures et écritures directes
-- se jouent SOUS le rôle authenticated (politiques), les RPC en postgres avec
-- l'identité du jeton (gardes des fonctions SECURITY DEFINER).
-- T1  lecture des notices par bibliothèque (A, B, les deux, admin, lectrice).
-- T2  notice sans bibliothèque : celle du créateur ; née d'un import : admin.
-- T3  écriture : 0 ligne hors de ses bibliothèques ; déplacer vers B refusé ;
--     created_by posé à l'INSERT et figé à l'UPDATE.
-- T4  tables enfants : suivent la notice.
-- T5  exemplaires : cible, sinon notice (importé) ; rapprochement sans
--     bibliothèque : admin ; cible vers B refusée.
-- T6  autorités : lecture commune, écriture par le créateur ou l'admin.
-- T7  suppression définitive : coordination DE la bibliothèque du brouillon.
-- T8  publication : notice, exemplaire, autorité d'une autre bibliothèque ou
--     personne refusés ; lot mixte refusé (admin : permis).
-- T9  fusions, doublons proposés : pas au-delà de ses bibliothèques.
-- T10 lots : rapport, prédicat d'édition, listes (révisions, bibliothèques).
-- T11 journal : lecture et rejeu par bibliothèque.
-- T12 reprises depuis le catalogue publié.
-- T13 vues invoker : comptes des lots et destinations, par bibliothèque.
-- T14 tours de révision lus en direct : lots entièrement à soi.
-- T15 ranger un brouillon dans un lot (API, reprise) : un lot à soi.
-- T16 les lots eux-mêmes : voir, modifier, supprimer ; created_by figé.
-- T17 bibliothèque fixée à la création : un mutirão révoqué ne l'emporte pas.
-- T18 fusion : cotes réécrites chez soi seulement ; journal par bibliothèque.
-- T19 gardes avant tout contrôle (statut d'un brouillon d'autrui muet).
-- T20 exemplaire sans cible : bibliothèque du brouillon, pas de qui publie.
-- T21 notice d'un compte admin (aussi staff) sans bibliothèque : admin seul.
-- T22 lot d'un dépôt non admis (bibliothèque inconnue) : à l'administration ;
--     réattribué, il passe à la bibliothèque ; sa corbeille reste où elle
--     était (IMP-20 c) sans l'en empêcher.
-- T23 ranger dans le lot vide ou publié d'une autre bibliothèque, le publier :
--     refusé.
-- T24 publier un lot qui porte les autorités d'autrui : refus distinct.
-- T25 l'admin qui enregistre une notice sans bibliothèque ne lui donne pas la
--     sienne ; le rejeu fixe la bibliothèque du journal ; un lot se confie.
-- T26 sortie de corbeille dans un lot qui n'est plus à soi : hors du lot.
-- T27 demander la révision : la coordination DE la bibliothèque du lot.
-- T28 réattribution : un exemplaire saisi d'ailleurs sort du lot.
-- T29 le lot d'un compte admin aussi staff n'est pas celui de ses collègues
--     (l'administration le confie) ; oracles (destination, aides, existence)
--     fermés.
-- T30 résolution d'un exemplaire (notice sans owner : créateur, import, admin) ;
--     rejeu d'une autorité sans créateur refusé ; créateur d'un lot qui n'est
--     plus staff : ne le voit plus.
-- T31 aides internes (appelées par des DEFINER seulement) fermées aux comptes,
--     aides servies ouvertes ; les DEFINER qui les portent, joués sous le rôle
--     authenticated, refusent pour la raison métier (jamais le privilège).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'BROUILLONS-PAR-BIBLIOTHEQUE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coordA uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin  uuid := '22222222-2222-2222-2222-222222222222';  -- admin reseau, sans adhesion
  v_libA   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid; v_libBibB uuid; v_multi uuid; v_reader uuid; v_coordB uuid;
  v_bA bigint; v_bB bigint; v_bOrph bigint; v_bNone bigint; v_bImp bigint; v_bA2 bigint; v_bB2 bigint;
  v_xA bigint; v_xB bigint; v_xImpB bigint; v_xRec bigint;
  v_aA bigint; v_aB bigint;
  v_lotA bigint; v_lotMix bigint;
  v_src bigint; v_run bigint; v_row bigint;
  v_bookB bigint; v_exB bigint; v_audit bigint;
  v_n int; v_m int; v_k int; v_hint text; v_txt text; v_ok boolean; v_id bigint; v_res jsonb;
  v_txt2 text; v_ok2 int; v_lotB bigint; v_lotC bigint; v_xNew bigint; v_adminA uuid;
  v_lotImp bigint; v_lotVideB bigint; v_lotPubB bigint; v_lotAut bigint;
  v_lotX bigint; v_lotX2 bigint; v_lotX3 bigint; v_lotX4 bigint; v_lotX5 bigint;
  v_exA bigint; v_hint2 text; v_k2 int; v_ok3 boolean; v_id2 bigint;
  v_lotX6 bigint; v_id3 bigint; v_x2 bigint; v_x3 bigint; v_ex uuid; v_row2 bigint;
  v_bFusS bigint; v_bFusL bigint; v_xFusA bigint; v_xFusB bigint;
  v_lot31A bigint; v_lot31B bigint; v_b31A bigint; v_b31B bigint; v_a31B bigint; v_x31B bigint; v_f text;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-b29-b', 'Essai B29 — B', true, 'private') RETURNING id INTO v_libB;
  -- Quatre comptes de test.
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'b29-' || n || '-' || gen_random_uuid() || '@example.invalid', now(), now()
    FROM generate_series(1, 4) n;
  SELECT id INTO v_libBibB FROM auth.users WHERE email LIKE 'b29-1-%';
  SELECT id INTO v_multi   FROM auth.users WHERE email LIKE 'b29-2-%';
  SELECT id INTO v_reader  FROM auth.users WHERE email LIKE 'b29-3-%';
  SELECT id INTO v_coordB  FROM auth.users WHERE email LIKE 'b29-4-%';
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT u, 'Essai', 'B29' FROM unnest(ARRAY[v_libBibB, v_multi, v_reader, v_coordB]) u ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_libBibB, v_libB, 'librarian', 'active', true),
    (v_multi, v_libA, 'librarian', 'active', true),
    (v_multi, v_libB, 'librarian', 'active', false),
    (v_reader, v_libA, 'reader', 'active', true),
    (v_coordB, v_libB, 'coordenador', 'active', true),
    (v_coordB, v_libA, 'librarian', 'active', false);

  -- B30 : un lot a une bibliothèque ; le lot mixte (héritage d'avant B30) n'en a
  -- pas : il est à l'administration.
  INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot A', v_coordA, v_libA) RETURNING id INTO v_lotA;
  INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot mixte', v_coordA, NULL) RETURNING id INTO v_lotMix;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
  VALUES ('B29 Notice de A', 'livro', v_libA, v_coordA, v_lotA, 'draft') RETURNING id INTO v_bA;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
  VALUES ('B29 Notice de B', 'livro', v_libB, v_libBibB, 'draft') RETURNING id INTO v_bB;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
  VALUES ('B29 Orpheline creee en A', 'livro', NULL, v_coordA, 'draft') RETURNING id INTO v_bOrph;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
  VALUES ('B29 Sans bibliotheque', 'livro', NULL, v_admin, 'draft') RETURNING id INTO v_bNone;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
  VALUES ('B29 Lot mixte A', 'livro', v_libA, v_coordA, v_lotMix, 'draft') RETURNING id INTO v_bA2;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
  VALUES ('B29 Lot mixte B', 'livro', v_libB, v_libBibB, v_lotMix, 'draft') RETURNING id INTO v_bB2;
  -- Une notice née d'un import, sans bibliothèque (dépôt d'une compagne non admise), promue par l'admin.
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai B29', v_libA, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_libA, 'essai/b29.marc', 'b29.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
  VALUES (v_run, 1, 'b29', 'B29 Importee', 'new_record', 'accept_new') RETURNING id INTO v_row;
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
  VALUES ('B29 Importee sans bibliotheque', 'livro', NULL, v_admin, 'draft') RETURNING id INTO v_bImp;
  INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, created_by) VALUES (v_row, v_run, v_bImp, v_admin);
  INSERT INTO public.book_draft_contributors (draft_id, name) VALUES (v_bA, 'Autrice A'), (v_bB, 'Autrice B');
  INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by) VALUES ('create', 'draft', 'pending', v_libA, v_coordA) RETURNING id INTO v_xA;
  INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by) VALUES ('create', 'draft', 'pending', v_libB, v_libBibB) RETURNING id INTO v_xB;
  INSERT INTO public.exemplar_drafts (action, status, label_status, book_draft_id, created_by) VALUES ('create', 'draft', 'pending', v_bB, v_libBibB) RETURNING id INTO v_xImpB;
  INSERT INTO public.exemplar_drafts (action, status, label_status, import_staging_row_id, created_by) VALUES ('create', 'draft', 'pending', v_row, v_coordA) RETURNING id INTO v_xRec;
  INSERT INTO public.author_drafts (preferred_name, status, created_by) VALUES ('B29 Autorite de A', 'draft', v_coordA) RETURNING id INTO v_aA;
  INSERT INTO public.author_drafts (preferred_name, status, created_by) VALUES ('B29 Autorite de B', 'draft', v_libBibB) RETURNING id INTO v_aB;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 lecture des notices par bibliotheque';
  BEGIN
    v_txt := '';
    -- coordination de A
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT string_agg(titulo, '|' ORDER BY titulo) INTO v_txt FROM public.book_drafts WHERE titulo LIKE 'B29 %';
    EXECUTE 'RESET ROLE';
    IF v_txt IS DISTINCT FROM 'B29 Lot mixte A|B29 Notice de A|B29 Orpheline creee en A' THEN RAISE EXCEPTION 'coordA voit : %', v_txt; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT string_agg(titulo, '|' ORDER BY titulo) INTO v_txt FROM public.book_drafts WHERE titulo LIKE 'B29 %';
    EXECUTE 'RESET ROLE';
    IF v_txt IS DISTINCT FROM 'B29 Lot mixte B|B29 Notice de B' THEN RAISE EXCEPTION 'libB voit : %', v_txt; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.book_drafts WHERE titulo LIKE 'B29 %';
    EXECUTE 'RESET ROLE';
    IF v_n <> 5 THEN RAISE EXCEPTION 'multi voit % notices (5 attendues : A, B, orpheline de A, mixtes)', v_n; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.book_drafts WHERE titulo LIKE 'B29 %';
    EXECUTE 'RESET ROLE';
    IF v_n <> 7 THEN RAISE EXCEPTION 'admin voit % notices (7)', v_n; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_reader, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.book_drafts WHERE titulo LIKE 'B29 %';
    EXECUTE 'RESET ROLE';
    IF v_n <> 0 THEN RAISE EXCEPTION 'la lectrice voit % notices', v_n; END IF;
    v_passed := v_passed+1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 sans bibliotheque : celle du createur ; nee d''un import : admin seul';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.book_drafts WHERE id IN (v_bImp, v_bNone);
    EXECUTE 'RESET ROLE';
    IF v_n = 0
       AND public.fn_book_draft_library(v_bOrph) = v_libA
       AND public.fn_book_draft_library(v_bImp) IS NULL
       AND public.fn_book_draft_library(v_bNone) IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : multi voit '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 ecriture : 0 ligne ailleurs, deplacer vers B refuse, created_by pose et fige';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET notas = 'b29' WHERE id = v_bB;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    UPDATE public.book_drafts SET notas = 'b29', created_by = v_libBibB WHERE id = v_bA;
    GET DIAGNOSTICS v_m = ROW_COUNT;
    v_hint := NULL;
    BEGIN
      UPDATE public.book_drafts SET owner_library_id = v_libB WHERE id = v_bA;
      v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_hint := SQLSTATE;
    END;
    v_txt := NULL;
    BEGIN
      INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id) VALUES ('B29 Forgee pour B', 'livro', v_libB);
      v_txt := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE;
    END;
    INSERT INTO public.book_drafts (titulo, tipo_material, created_by) VALUES ('B29 Neuve de A', 'livro', v_libBibB) RETURNING id INTO v_id;
    EXECUTE 'RESET ROLE';
    IF v_n = 0 AND v_m = 1 AND v_hint = '42501' AND v_txt = '42501'
       AND (SELECT created_by FROM public.book_drafts WHERE id = v_bA) = v_coordA
       AND (SELECT created_by FROM public.book_drafts WHERE id = v_id) = v_coordA
       AND public.fn_book_draft_library(v_id) = v_libA
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ailleurs='||v_n||' ici='||v_m||' deplacer='||coalesce(v_hint,'∅')||' forger='||coalesce(v_txt,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 tables enfants : elles suivent la notice';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT string_agg(name, '|' ORDER BY name) INTO v_txt FROM public.book_draft_contributors WHERE draft_id IN (v_bA, v_bB);
    v_hint := NULL;
    BEGIN
      INSERT INTO public.book_draft_contributors (draft_id, name) VALUES (v_bB, 'Intruse');
      v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_hint := SQLSTATE;
    END;
    EXECUTE 'RESET ROLE';
    IF v_txt = 'Autrice A' AND v_hint = '42501'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'∅')||' / insertion '||coalesce(v_hint,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 exemplaires : cible, sinon notice ; rapprochement sans bibliotheque : admin ; cible vers B refusee';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    -- (v_xRec : rapprochement sans bibliothèque, créé par coordA : visible par son créateur, CAT-E18 1)
    SELECT coalesce(array_agg(id ORDER BY id), '{}') = ARRAY[v_xA, v_xRec] INTO v_ok FROM public.exemplar_drafts WHERE id IN (v_xA, v_xB, v_xImpB, v_xRec);
    v_hint := NULL;
    BEGIN
      UPDATE public.exemplar_drafts SET target_library_id = v_libB WHERE id = v_xA;
      v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_hint := SQLSTATE;
    END;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.exemplar_drafts WHERE id IN (v_xB, v_xImpB, v_xRec);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_m FROM public.exemplar_drafts WHERE id IN (v_xA, v_xB, v_xImpB, v_xRec);
    EXECUTE 'RESET ROLE';
    IF v_ok AND v_hint = '42501' AND v_n = 2 AND v_m = 4
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA='||v_ok||' cible='||coalesce(v_hint,'∅')||' libB='||v_n||' admin='||v_m); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 autorites : lecture commune, ecriture par le createur ou l''admin';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.author_drafts WHERE id IN (v_aA, v_aB);
    UPDATE public.author_drafts SET notes = 'b29' WHERE id = v_aB;
    GET DIAGNOSTICS v_m = ROW_COUNT;
    UPDATE public.author_drafts SET notes = 'b29' WHERE id = v_aA;
    GET DIAGNOSTICS v_id = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.author_drafts SET notes = 'b29 admin' WHERE id = v_aB;
    GET DIAGNOSTICS v_k = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_n = 2 AND v_m = 0 AND v_id = 1 AND v_k = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lus='||v_n||' autrui='||v_m||' sienne='||v_id||' admin='||v_k); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 suppression definitive : coordination DE la bibliotheque du brouillon';
  BEGIN
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_bA2;
    -- coordB coordonne B, et n'est que bibliothécaire en A.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM public.book_drafts WHERE id = v_bA2;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM public.book_drafts WHERE id = v_bA2;
    GET DIAGNOSTICS v_m = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_n = 0 AND v_m = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordB='||v_n||' coordA='||v_m); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;
  -- (la notice v_bA2 du lot mixte est supprimée : on en remet une)
  INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
  VALUES ('B29 Lot mixte A', 'livro', v_libA, v_coordA, v_lotMix, 'draft') RETURNING id INTO v_bA2;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 publication : notice, exemplaire, autorite d''ailleurs refuses ; lot mixte refuse sauf admin';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_txt := '';
    BEGIN PERFORM public.publish_book_draft(v_bB); v_txt := v_txt || 'livre-accepte ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.publish_exemplar_draft(v_xB); v_txt := v_txt || 'ex-accepte ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.publish_author_draft(v_aB); v_txt := v_txt || 'aut-accepte ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM public.publish_catalog_batch(v_lotMix); v_txt := v_txt || 'lot-accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint; END;
    IF v_txt = 'error.publish.other_library error.publish.other_library error.catalog.author_draft_creator_only error.batch.other_libraries'
       AND public.fn_caller_can_edit_batch(v_lotA, true)
       AND NOT public.fn_caller_can_edit_batch(v_lotMix, false)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    IF NOT public.fn_caller_can_edit_batch(v_lotMix, true) THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : l''admin ne peut pas agir sur le lot mixte');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 fusions et doublons proposes : pas au-dela de ses bibliotheques';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('B29 Livre publie de B', 'B29-B-1', 'livro', v_libB) RETURNING id INTO v_bookB;
    -- Deux quasi-doublons du titre de v_bA : un en A, un en B.
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status) VALUES
      ('B29 Notice de A', 'livro', v_libA, v_coordA, 'draft'), ('B29 Notice de A', 'livro', v_libB, v_libBibB, 'draft');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_txt := '';
    BEGIN PERFORM api.merge_book_drafts(v_bA, v_bB, '{}'::jsonb); v_txt := v_txt || 'fusion-acceptee ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM api.merge_draft_into_book(v_bB, v_bookB, '{}'::jsonb); v_txt := v_txt || 'absorption-acceptee ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    SELECT count(*) INTO v_n FROM api.suggest_draft_duplicates(v_bB);
    SELECT count(*) INTO v_m FROM api.suggest_draft_duplicates(v_bA) s
      JOIN public.book_drafts d ON d.id = s.candidate_id AND s.source = 'draft' WHERE d.owner_library_id = v_libB;
    SELECT count(*) INTO v_id FROM api.suggest_draft_duplicates(v_bA) s
      JOIN public.book_drafts d ON d.id = s.candidate_id AND s.source = 'draft' WHERE d.owner_library_id = v_libA;
    -- multi (staff de A et B) : des bibliothèques résolues différentes ne se fusionnent pas.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    BEGIN PERFORM api.merge_book_drafts(v_bA, v_bB, '{}'::jsonb); v_txt := v_txt || 'multi-acceptee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint; END;
    IF v_txt = 'error.catalog.draft_other_library error.catalog.draft_other_library error.merge.cross_library'
       AND v_n = 0 AND v_m = 0 AND v_id >= 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt||' / suggestions B='||v_n||' candidats B='||v_m||' candidats A='||v_id); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 lots : rapport, predicat d''edition, listes';
  BEGIN
    v_txt := NULL;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM public.fn_batch_review_report(v_lotMix);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := SQLERRM; END;
    v_ok := v_hint = 'error.batch.other_libraries'
            AND public.fn_batch_caller_can_edit(v_lotA)
            AND NOT public.fn_batch_caller_can_edit(v_lotMix)
            AND (public.fn_batch_review_report(v_lotA) ? 'batch');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_n FROM public.fn_batch_reviews_list() r WHERE r.batch_id IN (v_lotA, v_lotMix);
    SELECT count(*) INTO v_m FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lotA;
    -- B30 : le lot hérité mixte est à l'administration : libB ne le liste plus.
    v_ok := v_ok AND NOT EXISTS (SELECT 1 FROM public.fn_batch_reviews_list() r WHERE r.batch_id = v_lotMix);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    IF coalesce(v_ok, false) AND v_n = 0 AND v_m = 0 AND NOT public.fn_batch_caller_can_edit(v_lotMix)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ok='||coalesce(v_ok::text,'∅')||' hint='||coalesce(v_hint,'∅')||' err='||coalesce(v_txt,'∅')||' revisions libB='||v_n||' owners lotA='||v_m); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  v_t := 'T11 journal : lecture et rejeu par bibliotheque';
  BEGIN
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
    VALUES ('B29 Supprimee de B', 'livro', v_libB, v_libBibB, 'cancelled') RETURNING id INTO v_id;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    DELETE FROM public.book_drafts WHERE id = v_id;
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_id;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.catalog_audit_log WHERE id = v_audit;
    EXECUTE 'RESET ROLE';
    v_hint := NULL;
    BEGIN PERFORM public.fn_restore_deleted_draft(v_audit);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_m FROM public.catalog_audit_log WHERE id = v_audit;
    EXECUTE 'RESET ROLE';
    v_res := public.fn_restore_deleted_draft(v_audit);
    IF v_n = 0 AND v_m = 1 AND v_hint = 'error.catalog.draft_other_library' AND (v_res->>'ok')::boolean
       AND (SELECT library_id FROM public.catalog_audit_log WHERE id = v_audit) = v_libB
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA lit '||v_n||' libB lit '||v_m||' rejeu coordA '||coalesce(v_hint,'accepte')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 reprises depuis le catalogue publie';
  BEGIN
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, circulation_policy) VALUES ('B29-B-1', 'B29-TOMBO-B', v_libB, 'emprestavel') RETURNING id INTO v_exB;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_id := public.create_book_draft_from_book(v_bookB, NULL);
    v_hint := NULL;
    BEGIN PERFORM public.create_exemplar_draft_from_exemplar(v_exB, NULL);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_reader, 'role', 'authenticated')::text, true);
    v_txt := NULL;
    BEGIN PERFORM public.create_author_draft_from_author((SELECT min(id) FROM public.authors), NULL);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT; END;
    IF (SELECT owner_library_id FROM public.book_drafts WHERE id = v_id) = v_libA
       AND v_hint = 'error.catalog.draft_other_library'
       AND (v_txt = 'error.catalog.staff_only' OR NOT EXISTS (SELECT 1 FROM public.authors))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : owner reprise='||coalesce((SELECT owner_library_id::text FROM public.book_drafts WHERE id = v_id),'∅')||' exemplaire='||coalesce(v_hint,'accepte')||' autorite lectrice='||coalesce(v_txt,'acceptee')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 vues invoker : comptes des lots et destinations, par bibliotheque';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.v_catalog_batch_draft_counts c WHERE c.batch_id = v_lotMix;   -- B30 : 0 (lot de l'administration)
    SELECT count(*) INTO v_m FROM public.v_book_draft_destination v WHERE v.draft_id IN (v_bA, v_bOrph);
    EXECUTE 'RESET ROLE';
    IF v_n = 0 AND v_m = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : en_cours lot mixte='||coalesce(v_n::text,'∅')||' destinations='||v_m); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 ─────────────────────────────────────────────────────────────
  v_t := 'T14 tours de revision lus en direct : lots entierement a soi';
  BEGIN
    INSERT INTO public.catalog_batch_reviews (batch_id, status, requested_by, report)
    VALUES (v_lotA, 'requested', v_coordA, '{"b29": "A"}'), (v_lotMix, 'requested', v_coordA, '{"b29": "mixte"}');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.catalog_batch_reviews WHERE batch_id IN (v_lotA, v_lotMix);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_m FROM public.catalog_batch_reviews WHERE batch_id IN (v_lotA, v_lotMix);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_k FROM public.catalog_batch_reviews WHERE batch_id IN (v_lotA, v_lotMix);
    EXECUTE 'RESET ROLE';
    -- La liste des révisions masque l'instantané d'un lot qu'on ne possède pas.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    -- B30 : un lot qu'on ne voit pas n'est pas listé du tout.
    v_ok := NOT EXISTS (SELECT 1 FROM public.fn_batch_reviews_list() r WHERE r.batch_id IN (v_lotA, v_lotMix));
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    SELECT v_ok AND (r.report IS NOT NULL) INTO v_ok FROM public.fn_batch_reviews_list() r WHERE r.batch_id = v_lotA;
    v_ok := v_ok AND NOT EXISTS (SELECT 1 FROM public.fn_batch_reviews_list() r WHERE r.batch_id = v_lotMix);
    IF v_n = 0 AND v_m = 1 AND v_k = 2 AND coalesce(v_ok, false)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : libB='||v_n||' coordA='||v_m||' admin='||v_k||' masquage liste='||coalesce(v_ok::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T15 ─────────────────────────────────────────────────────────────
  v_t := 'T15 ranger un brouillon dans un lot : seulement un lot a soi';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_hint := NULL;
    BEGIN
      UPDATE public.book_drafts SET batch_id = v_lotMix WHERE id = v_bOrph;
      v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_hint := SQLSTATE;
    END;
    SELECT batch_id IS DISTINCT FROM v_lotMix INTO v_ok FROM public.book_drafts WHERE id = v_bOrph;   -- B30 : resté hors du lot mixte
    UPDATE public.book_drafts SET batch_id = v_lotA WHERE id = v_bOrph;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_txt := NULL;
    BEGIN
      INSERT INTO public.book_drafts (titulo, tipo_material, batch_id) VALUES ('B29 Intruse lot A', 'livro', v_lotA);
      v_txt := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE;
    END;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_res := NULL;
    BEGIN PERFORM public.create_book_draft_from_book(v_bookB, v_lotMix); v_res := '"accepte"';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt2 = PG_EXCEPTION_HINT; END;
    -- B30 : un rangement refusé ne lève plus (gestes de masse) : le brouillon
    -- reste où il était ; la création refusée, elle, lève 42501.
    IF v_hint = 'accepte' AND v_n = 1 AND v_txt = '42501' AND v_res IS NULL AND v_txt2 = 'error.batch.other_libraries'
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_bOrph) = v_lotA AND coalesce(v_ok, false)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : vers mixte='||coalesce(v_hint,'∅')||' reste hors du mixte='||coalesce(v_ok::text,'∅')||' vers A='||v_n||' intruse='||coalesce(v_txt,'∅')||' reprise='||coalesce(v_txt2,'acceptee')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  v_t := 'T16 les lots eux-memes : voir, modifier, supprimer, created_by fige';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.catalog_batches WHERE id IN (v_lotA, v_lotMix);        -- 1 : le mixte
    UPDATE public.catalog_batches SET status = 'closed' WHERE id IN (v_lotA, v_lotMix);
    GET DIAGNOSTICS v_m = ROW_COUNT;                                                             -- 0
    INSERT INTO public.catalog_batches (name, created_by) VALUES ('B29 lot de B', v_coordA)
    RETURNING id, (created_by = v_libBibB) INTO v_lotB, v_ok;
    UPDATE public.catalog_batches SET created_by = v_coordA WHERE id = v_lotB;
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND (SELECT created_by FROM public.catalog_batches WHERE id = v_lotB) = v_libBibB;
    -- B30 : coordA a créé v_lotMix, lot de l'administration : ni le voir, ni le modifier.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_k FROM public.catalog_batches WHERE id = v_lotMix;
    UPDATE public.catalog_batches SET notes = 'b30' WHERE id = v_lotMix;
    GET DIAGNOSTICS v_id2 = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND v_k = 0 AND v_id2 = 0;
    -- Un lot de A qui n'a plus que sa corbeille (le déclencheur existant refuse
    -- la suppression d'un lot au travail vivant). coordB, réduite à la
    -- coordination de B : le lot vide d'une collègue de B se supprime, pas
    -- celui de A.
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot jete de A', v_coordA, v_libA) RETURNING id INTO v_lotC;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Jetee du lot C', 'livro', v_libA, v_coordA, v_lotC, 'cancelled');
    -- coordB, simple bibliothécaire en A : le lot de A n'est pas le sien à
    -- supprimer (la coordination DE ce lot, fn_caller_coordinates_batch).
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM public.catalog_batches WHERE id = v_lotC;
    GET DIAGNOSTICS v_k2 = ROW_COUNT;                                                            -- 0
    EXECUTE 'RESET ROLE';
    DELETE FROM public.user_library_memberships WHERE user_id = v_coordB AND library_id = v_libA;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    v_ok3 := NOT public.fn_caller_owns_batch(v_lotC);    -- « vide » (corbeille) : ni créé par elle, ni collègue
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM public.catalog_batches WHERE id = v_lotC;
    GET DIAGNOSTICS v_k = ROW_COUNT;                                                             -- 0
    DELETE FROM public.catalog_batches WHERE id = v_lotB;
    GET DIAGNOSTICS v_id = ROW_COUNT;                                                            -- 1
    EXECUTE 'RESET ROLE';
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES (v_coordB, v_libA, 'librarian', 'active', false);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_ok2 FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lotA;
    IF v_n = 0 AND v_m = 0 AND v_ok AND v_k2 = 0 AND v_ok3 AND v_k = 0 AND v_id = 1 AND v_ok2 >= 1   -- B30 : v_n = 0
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lotMix) = 'open'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : vus='||v_n||' modifies='||v_m||' createur fige='||coalesce(v_ok::text,'∅')||' suppr lot de A par coordB bib. de A='||v_k2||' owns lot C='||coalesce((NOT v_ok3)::text,'∅')||' suppr lot de A='||v_k||' suppr collegue='||v_id||' owners admin='||v_ok2); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T17 ─────────────────────────────────────────────────────────────
  v_t := 'T17 bibliotheque fixee a la creation (mutirao revoque : elle reste)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    INSERT INTO public.book_drafts (titulo, tipo_material) VALUES ('B29 Fixee multi', 'livro') RETURNING id INTO v_id;
    UPDATE public.book_drafts SET owner_library_id = NULL WHERE id = v_id;
    INSERT INTO public.exemplar_drafts (action, status, label_status) VALUES ('create', 'draft', 'pending') RETURNING id INTO v_xNew;
    EXECUTE 'RESET ROLE';
    DELETE FROM public.user_library_memberships WHERE user_id = v_multi AND library_id = v_libA;
    v_ok := (SELECT owner_library_id FROM public.book_drafts WHERE id = v_id) = v_libA
            AND (SELECT owner_library FROM public.book_drafts WHERE id = v_id) IS NOT NULL
            AND (SELECT target_library_id FROM public.exemplar_drafts WHERE id = v_xNew) = v_libA
            AND public.fn_book_draft_library(v_id) = v_libA;
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES (v_multi, v_libA, 'librarian', 'active', true);
    IF v_ok
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : owner='||coalesce((SELECT owner_library_id::text FROM public.book_drafts WHERE id = v_id),'∅')||' cible='||coalesce((SELECT target_library_id::text FROM public.exemplar_drafts WHERE id = v_xNew),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T18 ─────────────────────────────────────────────────────────────
  v_t := 'T18 fusion : cotes reecrites dans ses bibliotheques seulement ; journal par bibliotheque';
  BEGIN
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, bib_ref)
    VALUES ('B29 Fus S', 'livro', v_libA, v_coordA, 'draft', 'B29-FUS-S') RETURNING id INTO v_bFusS;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, bib_ref)
    VALUES ('B29 Fus L', 'livro', v_libA, v_coordA, 'draft', 'B29-FUS-L') RETURNING id INTO v_bFusL;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, created_by)
    VALUES ('create', 'draft', 'pending', v_libA, 'B29-FUS-L', v_coordA) RETURNING id INTO v_xFusA;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, created_by)
    VALUES ('create', 'draft', 'pending', v_libB, 'B29-FUS-L', v_libBibB) RETURNING id INTO v_xFusB;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    PERFORM api.merge_book_drafts(v_bFusS, v_bFusL, '{}'::jsonb);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_m FROM public.merge_log WHERE entity_type = 'book_draft' AND duplicate_id = v_bFusL;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.merge_log WHERE entity_type = 'book_draft' AND duplicate_id = v_bFusL;
    EXECUTE 'RESET ROLE';
    IF (SELECT target_bib_ref FROM public.exemplar_drafts WHERE id = v_xFusA) = 'B29-FUS-S'
       AND (SELECT target_bib_ref FROM public.exemplar_drafts WHERE id = v_xFusB) = 'B29-FUS-L'
       AND v_m = 1 AND v_n = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ex A='||coalesce((SELECT target_bib_ref FROM public.exemplar_drafts WHERE id = v_xFusA),'∅')||' ex B='||coalesce((SELECT target_bib_ref FROM public.exemplar_drafts WHERE id = v_xFusB),'∅')||' journal coordA='||v_m||' libB='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T19 ─────────────────────────────────────────────────────────────
  v_t := 'T19 gardes avant tout controle : rien ne renseigne sur le brouillon d''autrui';
  BEGIN
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
    VALUES ('B29 Jetee de B', 'livro', v_libB, v_libBibB, 'cancelled') RETURNING id INTO v_id;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_txt := '';
    BEGIN PERFORM public.publish_book_draft(v_id); v_txt := v_txt || 'publiee ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM api.merge_draft_into_book(v_id, v_bookB, '{}'::jsonb); v_txt := v_txt || 'absorbee ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint || ' '; END;
    BEGIN PERFORM api.merge_book_drafts(v_bA, v_id, '{}'::jsonb); v_txt := v_txt || 'fusionnee';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || v_hint; END;
    IF v_txt = 'error.publish.other_library error.catalog.draft_other_library error.catalog.draft_other_library'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T20 ─────────────────────────────────────────────────────────────
  v_t := 'T20 exemplaire sans cible : publie dans la bibliotheque du brouillon, pas celle de qui publie';
  BEGIN
    -- Saisi par libB (fixture sans cible) ; multi (principale : A, staff de B aussi) publie.
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_bib_ref, tombo, created_by)
    VALUES ('create', 'draft', 'pending', 'B29-B-1', 'B29-TOMBO-SC', v_libBibB) RETURNING id INTO v_xNew;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
    v_id := public.publish_exemplar_draft(v_xNew);
    IF (SELECT library_id FROM public.exemplares WHERE id = v_id) = v_libB
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : bibliotheque='||coalesce((SELECT library_id::text FROM public.exemplares WHERE id = v_id),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T21 ─────────────────────────────────────────────────────────────
  v_t := 'T21 notice creee par un compte admin aussi staff, sans bibliotheque : a l''administration';
  BEGIN
    INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
    VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'b29-5-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_adminA;
    INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_adminA, 'Essai', 'B29') ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.network_administrators (user_id, status) VALUES (v_adminA, 'active');
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES (v_adminA, v_libA, 'librarian', 'active', true);
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
    VALUES ('B29 Promue par une admin', 'livro', NULL, v_adminA, 'draft') RETURNING id INTO v_id;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.book_drafts WHERE id = v_id;
    EXECUTE 'RESET ROLE';
    IF v_n = 0 AND public.fn_book_draft_library(v_id) IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA voit '||v_n||', bibliotheque '||coalesce(public.fn_book_draft_library(v_id)::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T22 ─────────────────────────────────────────────────────────────
  v_t := 'T22 lot d''un depot non admis : a l''administration seule ; reattribue, il passe (sa corbeille reste, IMP-20 c, sans l''empecher)';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by) VALUES ('B29 lot du depot', v_admin) RETURNING id INTO v_lotImp;
    UPDATE public.book_drafts SET batch_id = v_lotImp WHERE id = v_bImp;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Jetee du depot', 'livro', NULL, v_admin, v_lotImp, 'cancelled') RETURNING id INTO v_id;
    INSERT INTO public.catalog_batch_reviews (batch_id, status, requested_by, report) VALUES (v_lotImp, 'requested', v_admin, '{"b29": "depot"}');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_ok := NOT public.fn_caller_can_edit_batch(v_lotImp, false) AND NOT public.fn_caller_owns_batch(v_lotImp)
            AND NOT public.fn_batch_caller_can_edit(v_lotImp);
    v_hint := NULL;
    BEGIN PERFORM public.fn_batch_review_report(v_lotImp);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.catalog_batch_reviews WHERE batch_id = v_lotImp;
    v_txt := NULL;
    BEGIN
      UPDATE public.book_drafts SET batch_id = v_lotImp WHERE id = v_bOrph;
      v_txt := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE;
    END;
    EXECUTE 'RESET ROLE';
    -- Un lot qui ne porte qu'un exemplaire de rapprochement d'un dépôt
    -- (bibliothèque inconnue) : pas à coordA non plus (branche exemplaire).
    INSERT INTO public.catalog_batches (name, created_by) VALUES ('B29 lot de rapprochement du depot', v_admin) RETURNING id INTO v_lotX;
    INSERT INTO public.exemplar_drafts (action, status, label_status, import_staging_row_id, created_by, batch_id)
    VALUES ('create', 'draft', 'pending', v_row, v_admin, v_lotX);
    v_ok := v_ok AND NOT public.fn_caller_can_edit_batch(v_lotX, true) AND NOT public.fn_caller_owns_batch(v_lotX)
            AND NOT public.fn_batch_caller_can_edit(v_lotX);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_reassign_library(v_lotImp, v_libA);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    IF v_ok AND v_hint = 'error.batch.other_libraries' AND v_n = 0 AND v_txt = 'accepte'   -- B30 : sans effet, sans erreur
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_bOrph) = v_lotA
       AND (SELECT owner_library_id FROM public.book_drafts WHERE id = v_id) IS NULL
       AND public.fn_caller_owns_batch(v_lotImp)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : predicats faux='||coalesce(v_ok::text,'∅')||' rapport='||coalesce(v_hint,'rendu')||' revisions lues='||v_n||' ranger='||coalesce(v_txt,'∅')||' corbeille='||coalesce((SELECT owner_library_id::text FROM public.book_drafts WHERE id = v_id),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T23 ─────────────────────────────────────────────────────────────
  v_t := 'T23 ranger dans le lot vide ou publie d''une autre bibliotheque : refuse ; le publier aussi';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot vide de B', v_libBibB, v_libB) RETURNING id INTO v_lotVideB;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot publie de B', v_libBibB, v_libB) RETURNING id INTO v_lotPubB;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Publiee de B', 'livro', v_libB, v_libBibB, v_lotPubB, 'published');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_txt := '';
    BEGIN UPDATE public.book_drafts SET batch_id = v_lotVideB WHERE id = v_bA; v_txt := v_txt || 'vide-accepte ';
    EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || ' '; END;
    BEGIN UPDATE public.book_drafts SET batch_id = v_lotPubB WHERE id = v_bA; v_txt := v_txt || 'publie-accepte';
    EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE; END;
    EXECUTE 'RESET ROLE';
    v_hint := NULL;
    BEGIN PERFORM public.publish_catalog_batch(v_lotVideB);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    v_ok := NOT public.fn_batch_caller_can_edit(v_lotVideB) AND NOT public.fn_batch_caller_can_edit(v_lotPubB);
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, circulation_policy)
    VALUES ('B29-A-REPRISE', 'B29-TOMBO-A-REPRISE', v_libA, 'emprestavel') RETURNING id INTO v_exA;
    v_txt2 := '';
    BEGIN PERFORM public.create_book_draft_from_book(v_bookB, v_lotPubB); v_txt2 := v_txt2 || 'livre-accepte ';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; v_txt2 := v_txt2 || v_hint2 || ' '; END;
    BEGIN PERFORM public.create_exemplar_draft_from_exemplar(v_exA, v_lotPubB); v_txt2 := v_txt2 || 'ex-accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint2 = PG_EXCEPTION_HINT; v_txt2 := v_txt2 || v_hint2; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = v_lotVideB WHERE id = v_bB;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    IF v_txt = 'vide-accepte publie-accepte' AND v_hint = 'error.batch.other_libraries' AND v_n = 1 AND v_ok   -- B30 : sans effet, sans erreur
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_bB) = v_lotVideB
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_bA) = v_lotA
       AND v_txt2 = 'error.batch.other_libraries error.batch.other_libraries'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA='||v_txt||' publier='||coalesce(v_hint,'accepte')||' libB range='||v_n||' peut agir='||coalesce((NOT v_ok)::text,'∅')||' reprises='||coalesce(v_txt2,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T24 ─────────────────────────────────────────────────────────────
  v_t := 'T24 publier un lot qui porte les autorites d''une autre personne : refus distinct';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot aux autorites', v_coordA, v_libA) RETURNING id INTO v_lotAut;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Notice du lot aux autorites', 'livro', v_libA, v_coordA, v_lotAut, 'draft');
    INSERT INTO public.author_drafts (preferred_name, status, created_by, batch_id) VALUES ('B29 Autorite de B dans A', 'draft', v_libBibB, v_lotAut);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM public.publish_catalog_batch(v_lotAut);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint = 'error.batch.other_authors'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_hint,'publie')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T25 ─────────────────────────────────────────────────────────────
  v_t := 'T25 admin qui enregistre une notice sans bibliotheque, rejeu fixe la bibliotheque, lot confie';
  BEGIN
    -- (v_adminA : admin réseau ET bibliothécaire de A, T21.) L'écran renvoie
    -- owner_library_id = null à chaque enregistrement : la notice du dépôt ne
    -- devient pas celle de A.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_adminA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET owner_library_id = NULL, notas = 'b29 admin' WHERE id = v_bNone;
    EXECUTE 'RESET ROLE';
    v_ok := (SELECT owner_library_id FROM public.book_drafts WHERE id = v_bNone) IS NULL;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_adminA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET owner_library_id = NULL, notas = 'b29 admin promue' WHERE titulo = 'B29 Promue par une admin';
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND (SELECT owner_library_id FROM public.book_drafts WHERE titulo = 'B29 Promue par une admin') IS NULL;
    -- Rejeu : une notice sans owner, supprimée ; son créateur quitte B ; le
    -- rejeu la rend à B (bibliothèque du journal), pas « à personne ».
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
    VALUES ('B29 Sans owner rejouee', 'livro', NULL, v_libBibB, 'cancelled') RETURNING id INTO v_id;
    DELETE FROM public.book_drafts WHERE id = v_id;
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_id;
    DELETE FROM public.user_library_memberships WHERE user_id = v_libBibB AND library_id = v_libB;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    PERFORM public.fn_restore_deleted_draft(v_audit);
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES (v_libBibB, v_libB, 'librarian', 'active', true);
    v_ok2 := CASE WHEN (SELECT owner_library_id FROM public.book_drafts WHERE id = v_id) = v_libB THEN 1 ELSE 0 END;
    -- Lot confié par l'administration : B30, c'est le réattribuer (son
    -- créateur, lui, reste figé).
    INSERT INTO public.catalog_batches (name, created_by) VALUES ('B29 lot a confier', v_admin) RETURNING id INTO v_lotB;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.catalog_batches SET created_by = v_libBibB WHERE id = v_lotB;
    EXECUTE 'RESET ROLE';
    PERFORM public.fn_batch_reassign_library(v_lotB, v_libB);
    IF v_ok AND v_ok2 = 1 AND (SELECT created_by FROM public.catalog_batches WHERE id = v_lotB) = v_admin
       AND (SELECT library_id FROM public.catalog_batches WHERE id = v_lotB) = v_libB
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : owner du depot='||coalesce((SELECT owner_library_id::text FROM public.book_drafts WHERE id = v_bNone),'∅')||' rejeu='||coalesce((SELECT owner_library_id::text FROM public.book_drafts WHERE id = v_id),'∅')||' lot confie a '||coalesce((SELECT library_id::text FROM public.catalog_batches WHERE id = v_lotB),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T26 ─────────────────────────────────────────────────────────────
  v_t := 'T26 sortie de corbeille dans un lot qui n''est plus a soi : le brouillon revient, hors du lot';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot reattribue a A', v_admin, v_libA) RETURNING id INTO v_lotX2;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Notice de A du lot reattribue', 'livro', v_libA, v_coordA, v_lotX2, 'draft');
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Jetee de B du lot reattribue', 'livro', v_libB, v_libBibB, v_lotX2, 'cancelled') RETURNING id INTO v_id;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Jetee de A du lot reattribue', 'livro', v_libA, v_coordA, v_lotX2, 'cancelled') RETURNING id INTO v_id2;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_id;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_id2;
    EXECUTE 'RESET ROLE';
    -- Un lot ENTIÈREMENT publié par A (plus rien en cours), la corbeille de B
    -- dedans : B la restaure → hors du lot ; B n'y range rien ; exemplaire saisi
    -- de B jeté dans le lot de A : même chose.
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot publie par A', v_admin, v_libA) RETURNING id INTO v_lotX6;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Publiee par A', 'livro', v_libA, v_coordA, v_lotX6, 'published');
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Jetee de B dans le lot publie de A', 'livro', v_libB, v_libBibB, v_lotX6, 'cancelled') RETURNING id INTO v_id3;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, batch_id)
    VALUES ('create', 'cancelled', 'pending', v_libB, v_libBibB, v_lotX6) RETURNING id INTO v_x2;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    v_ok3 := NOT public.fn_caller_owns_batch(v_lotX6);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_id3;
    UPDATE public.exemplar_drafts SET status = 'draft' WHERE id = v_x2;
    v_hint2 := NULL;
    BEGIN UPDATE public.book_drafts SET batch_id = v_lotX6 WHERE id = v_bB; v_hint2 := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_hint2 := SQLSTATE; END;
    EXECUTE 'RESET ROLE';
    v_ok3 := v_ok3 AND v_hint2 = 'accepte'   -- B30 : sans effet, sans erreur
             AND (SELECT batch_id FROM public.book_drafts WHERE id = v_bB) = v_lotVideB
             AND (SELECT batch_id FROM public.book_drafts WHERE id = v_id3) IS NULL
             AND (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_x2) IS NULL;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_ok3 := v_ok3 AND public.fn_caller_owns_batch(v_lotX6);
    IF v_ok3 AND v_n = 1
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_id) IS NULL
       AND (SELECT status FROM public.book_drafts WHERE id = v_id) = 'draft'
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_id2) = v_lotX2
       AND public.fn_caller_owns_batch(v_lotX2) AND public.fn_caller_can_edit_batch(v_lotX2, false)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot publie de A='||coalesce(v_ok3::text,'∅')||' ranger='||coalesce(v_hint2,'∅')||' restaure='||v_n||' lot du brouillon de B='||coalesce((SELECT batch_id::text FROM public.book_drafts WHERE id = v_id),'∅')||' lot du brouillon de A='||coalesce((SELECT batch_id::text FROM public.book_drafts WHERE id = v_id2),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T27 ─────────────────────────────────────────────────────────────
  v_t := 'T27 demander la revision d''un lot importe : la coordination DE sa bibliotheque';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot importe de A', v_coordA, v_libA) RETURNING id INTO v_lotX3;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status, partner_source)
    VALUES ('B29 Importee de A', 'livro', v_libA, v_coordA, v_lotX3, 'draft', 'other_partner');
    -- coordB coordonne B et n'est que bibliothécaire en A.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM public.fn_batch_review_request(v_lotX3, NULL);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    v_ok := NOT public.fn_caller_coordinates_batch(v_lotX3);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_request(v_lotX3, NULL);
    IF v_hint = 'error.review.coordenador_only' AND v_ok
       AND EXISTS (SELECT 1 FROM public.catalog_batch_reviews r WHERE r.batch_id = v_lotX3)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordB='||coalesce(v_hint,'accepte')||' coordonne='||coalesce((NOT v_ok)::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T28 ─────────────────────────────────────────────────────────────
  v_t := 'T28 reattribution : un exemplaire saisi d''une autre bibliotheque sort du lot, qui reste gerable';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 lot a reattribuer a B', v_admin, v_libA) RETURNING id INTO v_lotX4;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, batch_id, status)
    VALUES ('B29 Notice du lot a reattribuer', 'livro', v_libA, v_coordA, v_lotX4, 'draft');
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, batch_id)
    VALUES ('create', 'draft', 'pending', v_libA, v_coordA, v_lotX4) RETURNING id INTO v_xNew;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, batch_id)
    VALUES ('create', 'published', 'pending', v_libA, v_coordA, v_lotX4) RETURNING id INTO v_x2;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by, batch_id)
    VALUES ('create', 'cancelled', 'pending', v_libA, v_coordA, v_lotX4) RETURNING id INTO v_x3;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_reassign_library(v_lotX4, v_libB);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    IF (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_xNew) IS NULL
       AND (SELECT target_library_id FROM public.exemplar_drafts WHERE id = v_xNew) = v_libA
       AND (v_res->>'items_detached')::int = 1 AND (v_res->'warnings') ? 'items_detached'
       AND (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_x2) = v_lotX4
       AND (SELECT batch_id FROM public.exemplar_drafts WHERE id = v_x3) = v_lotX4
       AND public.fn_caller_owns_batch(v_lotX4) AND public.fn_caller_can_edit_batch(v_lotX4, true)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res::text,'∅')||' lot de l''exemplaire='||coalesce((SELECT batch_id::text FROM public.exemplar_drafts WHERE id = v_xNew),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T29 ─────────────────────────────────────────────────────────────
  v_t := 'T29 lot d''un compte admin aussi staff : pas celui des collegues (il se confie) ; oracles fermes';
  BEGIN
    INSERT INTO public.catalog_batches (name, created_by) VALUES ('B29 lot vide d''une admin de A', v_adminA) RETURNING id INTO v_lotX5;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_ok := NOT public.fn_caller_can_see_batch(v_lotX5) AND NOT public.fn_caller_coordinates_batch(v_lotX5);
    v_ok2 := CASE WHEN public.fn_book_draft_destination_library(v_bB) IS NULL
                   AND public.fn_book_draft_destination_library(v_bA) = v_libA THEN 1 ELSE 0 END;
    v_ok3 := NOT has_function_privilege('authenticated', 'public.fn_user_staff_library(uuid)', 'EXECUTE')
             AND NOT has_function_privilege('authenticated', 'public.fn_book_draft_library(bigint)', 'EXECUTE')
             AND has_function_privilege('authenticated', 'public.fn_caller_staff_library()', 'EXECUTE')
             AND public.fn_caller_can_edit_book_draft(-1) = false
             AND public.fn_caller_can_edit_exemplar_draft(-1) = false
             AND public.fn_caller_can_edit_author_draft(-1) = false;
    IF v_ok AND v_ok2 = 1 AND v_ok3
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot visible='||coalesce(v_ok::text,'∅')||' destination='||v_ok2||' oracles fermes='||coalesce(v_ok3::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T30 ─────────────────────────────────────────────────────────────
  v_t := 'T30 resolution d''un exemplaire, rejeu d''une autorite sans createur, createur d''un lot qui n''est plus staff';
  BEGIN
    -- Résolution aplatie : notice sans owner créée par coordA → A ; créée par
    -- un admin → aucune ; née d'un import → aucune.
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 2, 'b29-2', 'B29 Importee 2', 'new_record', 'accept_new') RETURNING id INTO v_row2;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
    VALUES ('B29 Importee par coordA', 'livro', NULL, v_coordA, 'draft') RETURNING id INTO v_id3;
    INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, created_by) VALUES (v_row2, v_run, v_id3, v_coordA);
    v_ok := public.fn_exemplar_draft_fallback_library(v_bOrph, NULL, NULL) = v_libA
            AND public.fn_exemplar_draft_fallback_library(v_bNone, NULL, NULL) IS NULL
            AND public.fn_exemplar_draft_fallback_library(v_id3, NULL, NULL) IS NULL
            AND public.fn_exemplar_draft_fallback_library(NULL, NULL, v_coordA) = v_libA
            AND public.fn_exemplar_draft_fallback_library(NULL, NULL, v_adminA) IS NULL;
    -- Rejeu d'une autorité sans créateur : refusé à qui n'est pas admin.
    INSERT INTO public.author_drafts (preferred_name, status, created_by) VALUES ('B29 Autorite sans createur', 'cancelled', NULL) RETURNING id INTO v_id2;
    DELETE FROM public.author_drafts WHERE id = v_id2;
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l WHERE l.action = 'delete' AND l.entity_type = 'author' AND l.entity_id = v_id2;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN PERFORM public.fn_restore_deleted_draft(v_audit);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    -- Créateur d'un lot qui n'est plus staff : ne le voit plus.
    INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
    VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'b29-6-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_ex;
    INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_ex, 'Essai', 'B29') ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.catalog_batches (name, created_by) VALUES ('B29 lot d''une ancienne', v_ex) RETURNING id INTO v_lotX6;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_ex, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.catalog_batches WHERE id = v_lotX6;
    EXECUTE 'RESET ROLE';
    IF v_ok AND v_hint = 'error.catalog.author_draft_creator_only' AND v_n = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : resolution='||coalesce(v_ok::text,'∅')||' rejeu='||coalesce(v_hint,'accepte')||' lot vu par son ancienne creatrice='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T31 ─────────────────────────────────────────────────────────────
  -- 20260927200627 : cinq aides ne servaient que des fonctions DEFINER ; elles
  -- sont fermées aux comptes. Le risque d'une fermeture, c'est un appelant qui
  -- s'exécute sous authenticated : on joue donc aussi, SOUS ce rôle, les
  -- fonctions DEFINER qui les portent, et l'on attend leur refus métier —
  -- jamais un 42501 de privilège.
  v_t := 'T31 aides internes fermees aux comptes ; aides servies ouvertes ; les DEFINER qui les portent repondent sous authenticated';
  BEGIN
    v_txt := '';
    -- (a) les deux camps, chaque fonction nommée
    FOREACH v_f IN ARRAY ARRAY[
      'public.fn_caller_can_edit_draft_library(uuid, uuid)', 'public.fn_caller_can_edit_exemplar_draft(bigint)',
      'public.fn_caller_can_edit_author_draft(bigint)', 'public.fn_caller_can_edit_batch(bigint, boolean)',
      'public.fn_caller_can_see_batch(bigint)'] LOOP
      IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE') THEN
        v_txt := v_txt || 'ouverte:' || v_f || ' ';
      END IF;
    END LOOP;
    FOREACH v_f IN ARRAY ARRAY[
      'public.fn_caller_staff_library_ids()', 'public.fn_caller_coordinator_library_ids()', 'public.fn_caller_staff_library()',
      'public.fn_book_draft_creator_library(bigint, uuid)', 'public.fn_exemplar_draft_fallback_library(bigint, bigint, uuid)',
      'public.fn_caller_can_edit_book_draft(bigint)', 'public.fn_caller_owns_batch(bigint)',
      'public.fn_caller_coordinates_batch(bigint)', 'public.fn_caller_batch_library(bigint)',
      'public.fn_caller_batch_library_sans_attente(bigint)', 'public.fn_batch_delete_blockers(bigint)'] LOOP
      IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') THEN v_txt := v_txt || 'fermee:' || v_f || ' '; END IF;
      IF has_function_privilege('anon', v_f, 'EXECUTE') THEN v_txt := v_txt || 'anon:' || v_f || ' '; END IF;
    END LOOP;
    -- décor propre (postgres : les déclencheurs de B29 le laissent passer)
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 T31 lot de A', v_coordA, v_libA) RETURNING id INTO v_lot31A;
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('B29 T31 lot de B', v_libBibB, v_libB) RETURNING id INTO v_lot31B;
    INSERT INTO public.author_drafts (preferred_name, status, created_by, batch_id) VALUES ('B29 T31 Autorite de multi dans A', 'draft', v_multi, v_lot31A);
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
    VALUES ('B29 T31 Notice de A', 'livro', v_libA, v_coordA, 'draft') RETURNING id INTO v_b31A;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status)
    VALUES ('B29 T31 Notice de B', 'livro', v_libB, v_libBibB, 'draft') RETURNING id INTO v_b31B;
    INSERT INTO public.author_drafts (preferred_name, status, created_by) VALUES ('B29 T31 Autorite de B', 'draft', v_libBibB) RETURNING id INTO v_a31B;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, created_by)
    VALUES ('create', 'draft', 'pending', v_libB, v_libBibB) RETURNING id INTO v_x31B;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    -- (b) appelée en direct, une aide fermée est refusée par le privilège
    BEGIN PERFORM public.fn_caller_can_see_batch(v_lot31A); v_txt := v_txt || 'direct:can_see_batch ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN PERFORM public.fn_caller_can_edit_batch(v_lot31A, true); v_txt := v_txt || 'direct:can_edit_batch ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN PERFORM public.fn_caller_can_edit_draft_library(v_libA, v_coordA); v_txt := v_txt || 'direct:can_edit_draft_library ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN PERFORM public.fn_caller_can_edit_exemplar_draft(v_x31B); v_txt := v_txt || 'direct:can_edit_exemplar_draft ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN PERFORM public.fn_caller_can_edit_author_draft(v_a31B); v_txt := v_txt || 'direct:can_edit_author_draft ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    -- (c) les prédicats servis qui les appellent répondent juste
    BEGIN
      IF NOT public.fn_caller_owns_batch(v_lot31A) OR public.fn_caller_owns_batch(v_lot31B) THEN v_txt := v_txt || 'owns_batch '; END IF;
      IF public.fn_batch_caller_can_edit(v_lot31B) THEN v_txt := v_txt || 'batch_caller_can_edit '; END IF;
      IF NOT public.fn_caller_can_edit_book_draft(v_b31A) OR public.fn_caller_can_edit_book_draft(v_b31B) THEN v_txt := v_txt || 'can_edit_book_draft '; END IF;
    EXCEPTION WHEN OTHERS THEN v_txt := v_txt || 'predicats:' || SQLSTATE || ' ';
    END;
    -- (d) les publications refusent pour la raison métier
    v_hint := NULL;
    BEGIN PERFORM public.publish_catalog_batch(v_lot31B); v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(nullif(v_hint, ''), SQLSTATE); END;
    IF v_hint IS DISTINCT FROM 'error.batch.other_libraries' THEN v_txt := v_txt || 'lot-de-B:' || v_hint || ' '; END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_catalog_batch(v_lot31A); v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(nullif(v_hint, ''), SQLSTATE); END;
    IF v_hint IS DISTINCT FROM 'error.batch.other_authors' THEN v_txt := v_txt || 'lot-aux-autorites:' || v_hint || ' '; END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_author_draft(v_a31B); v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(nullif(v_hint, ''), SQLSTATE); END;
    IF v_hint IS DISTINCT FROM 'error.catalog.author_draft_creator_only' THEN v_txt := v_txt || 'autorite-de-B:' || v_hint || ' '; END IF;
    v_hint := NULL;
    BEGIN PERFORM public.publish_exemplar_draft(v_x31B); v_hint := 'publie';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_hint := coalesce(nullif(v_hint, ''), SQLSTATE); END;
    IF v_hint IS DISTINCT FROM 'error.publish.other_library' THEN v_txt := v_txt || 'exemplaire-de-B:' || v_hint || ' '; END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'BROUILLONS-PAR-BIBLIOTHEQUE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'BROUILLONS-PAR-BIBLIOTHEQUE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
