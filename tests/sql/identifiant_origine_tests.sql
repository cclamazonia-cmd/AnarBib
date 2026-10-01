-- =====================================================================
-- AnarBib — Tests d'acceptation : l'identifiant d'origine d'une notice est
-- gardé PAR bibliothèque (H20, aller-retour PMB)
-- Date    : 2026-09-27 ; T3 adapté et T14-T19 le 2026-09-29 (H21 lot 0) ;
--           T19 revu le 2026-09-29 après l'amendement de la migration (le tour
--           fige TOUS les exemplaires du lot, rattachés compris) ; T12 adapté
--           et T20 le 2026-09-30 (seconde passe du lot 0 : constats #0 et #11)
-- Ref     : migration 20260928111812_h20_l_identifiant_d_origine_par_bibliotheque
--           migration 20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe
--           (juge de la LIGNE ingest.fn_h20_cle_de_la_ligne ; IMP-27 c : un lot
--           de rapprochement passe par la révision)
--
-- T1 une notice importée garde son 001, à la bibliothèque qui la publie
--    (source_record_id, marc_json.ingest.source_id, book_external_ids).
-- T2 sans 001 : aucun identifiant — jamais le numéro de la ligne de staging.
-- T3 un exemplaire rapproché d'une notice d'une AUTRE bibliothèque : le 001
--    est gardé pour la bibliothèque qui importe, la notice partagée intacte.
--    Depuis H21 lot 0 (IMP-27 c), l'exemplaire rapproché ne se publie
--    qu'après la révision de son lot : la coordination la demande,
--    l'administration l'approuve, puis la publication (T4, T5, T12 s'appuient
--    sur la notice de B et la clé que T3 pose).
-- T4 unicité par (bibliothèque, schéma, valeur) ; même numéro dans deux
--    bibliothèques ; réclamé par une autre notice : il reste à la première.
-- T5 lecture : le staff de sa bibliothèque, l'administration ; personne
--    d'autre, ni anon ; aucune écriture par l'API.
-- T6 les faux identifiants (numéro de ligne) des brouillons en cours sont
--    effacés ; un vrai, et un brouillon publié, restent.
-- T7 reprise des notices déjà publiées depuis un import ; rejouée : rien de
--    plus ; un brouillon de reprise d'une autre bibliothèque ne donne rien.
-- T8 fusion de notices (merge_book) : les identifiants du doublon, de chaque
--    bibliothèque, passent à la notice gardée.
-- T9 à l'import, une clé que portent deux lignes du run est effacée des
--    brouillons ; le numéro d'un fascicule (CSV de périodiques) aussi ; le
--    numéro d'un CSV qui n'est pas de périodiques reste.
-- T10 un brouillon importé absorbé par une fiche existante lui laisse son 001.
-- T11 fusion de brouillons : à la publication du survivant, le 001 du perdant
--    est posé aussi ; la source se relit dans le run quand le brouillon ne la
--    porte pas.
-- T12 un run ne se supprime pas tant qu'un exemplaire rapproché l'attend ;
--     depuis la seconde passe du lot 0 (IMP-27 c, constat #0), mis à la
--     corbeille il le retient encore (HINT error.import.run_has_trashed_items :
--     restauré sans sa ligne, il se publierait comme un exemplaire fait à la
--     main) ; purgé, il le libère et le run se supprime.
-- T13 une clé égale par hasard au numéro de sa ligne de staging, que la ligne
--    porte vraiment, reste un identifiant.
--
-- H21 lot 0 — l'identifiant d'origine se juge sur la LIGNE d'import
-- (tout exemplaire rapproché est publié après la révision de son lot) :
-- T14 exemplaire rapproché : une clé que deux lignes du fichier portent
--     (l'autre rejetée) n'est pas enregistrée ; une clé unique l'est.
-- T15 exemplaire rapproché depuis un CSV de périodiques : pas le numéro du
--     fascicule ; le numéro d'un CSV de livres, oui.
-- T16 le juge de la ligne lui-même : vide, répétée (espaces, décision
--     indifférente), fascicule d'un CSV : rien ; clé unique, même clé dans un
--     AUTRE run de la source (le réimport), numéro d'un CSV de livres,
--     « numero » d'un run MARC, clé égale à sa ligne : la clé ; DEFINER,
--     STABLE, fermé à l'API.
-- T17 brouillon né d'une ligne dont la clé est portée par une ligne REJETÉE
--     du fichier : clé effacée à la promotion, aucun identifiant.
-- T18 un brouillon né d'une ligne se juge sur SA ligne (row_to_draft) :
--     source_record_id et marc_json.ingest.staging_row_id retouchés ne
--     changent pas la clé enregistrée à la publication.
-- T19 brouillon absorbé par une fiche que la bibliothèque détient, son
--     exemplaire détaché publié : une clé répétée dans le fichier n'est
--     enregistrée ni par l'absorption ni par l'exemplaire. Révision demandée
--     et approuvée AVANT l'absorption ; l'exemplaire, encore rattaché à sa
--     notice à la demande, figure parmi ce que le tour soumet
--     (exemplar_draft_ids, IMP-27 b) : détaché ensuite par l'absorption, sans
--     avoir été rangé après la demande, il reste couvert et se publie SANS
--     second tour — rien n'attend un nouveau tour
--     (fn_batch_ajouts_apres_revision = 0), la coordination ne peut pas en
--     redemander un (HINT error.review.already_approved), le lot n'a qu'un tour.
-- T18 reprend le lot et le brouillon L de T17.
--
-- Seconde passe du lot 0 (30/09) :
-- T20 (constat #11) un identifiant d'origine saisi à la main (UPDATE en
--     postgres, comme le formulaire l'enregistre) sur un brouillon LIÉ dont la
--     ligne n'a pas de clé valide — clé répétée dans le fichier, ou vide —
--     n'est pas effacé par la sélection suivante du même run
--     (fn_import_promote, p_row_ids = d'AUTRES lignes), ni la colonne ni son
--     miroir marc_json.anarbib_provenance ; publiée ensuite, la notice le
--     porte (books.source_record_id), sans en faire un identifiant d'import
--     (book_external_ids : rien). La clé venue du fichier, elle, reste effacée
--     comme avant sur un brouillon qui la porte encore : à la première
--     promotion ; sur la ligne promue par la sélection suivante, dont la clé
--     est entourée d'espaces dans le fichier (la promotion la rogne, la
--     comparaison la rogne aussi) ; ressaisie telle quelle sur un brouillon
--     déjà promu. Une clé unique reste.
--
-- Contre-épreuves (29/09, définition d'avant le lot 0 rejouée avant la suite) :
--   fn_h20_identifiant_d_origine d'avant : T17, T18, T19 tombent ;
--   publish_exemplar_draft d'avant (clé brute, sans la porte c) : T14, T15,
--     T19 tombent sur la CLÉ enregistrée brute (la révision y est sans effet) ;
--   les deux, et fn_h20_cle_de_la_ligne retirée : T14 à T19 tombent, T1 à
--     T13 passent ;
--   fn_batch_is_imported d'avant : T3, T14, T15 tombent (lot de rapprochement
--     « pas importé », révision refusée ; T4, T5, T12 en cascade) ;
--   fn_batch_review_request d'avant (aucune liste figée) : T19 tombe
--     (l'exemplaire n'est pas dans la liste du tour) ;
--   fn_batch_review_request d'avant l'amendement (liste figée sans les
--     exemplaires rattachés) : T19 tombe (l'exemplaire détaché compte comme
--     ajouté, un second tour est accepté et la publication attend :
--     error.publish.review_required).
-- Contre-épreuves de la seconde passe (30/09, définition rejouée avant la suite) :
--   fn_h20_effacer_faux_identifiants d'avant (migration 20260928111812,
--     inchangée au commit WIP) : T20 seul tombe (les deux saisies effacées par
--     la sélection suivante, la notice publiée sans elles) ;
--   mutant « un brouillon lié n'est jamais effacé » : T9, T17, T20 tombent
--     (la clé répétée venue du fichier reste) ;
--   mutant « clé de la ligne comparée sans btrim » : T20 seul tombe (la clé
--     entourée d'espaces dans le fichier reste au brouillon de la sélection
--     suivante ; aucune autre suite ne le voit) ;
--   fn_import_delete_run du commit WIP (la corbeille ne retient pas le run) :
--     T12 seul tombe (le run se supprime sous l'exemplaire à la corbeille).
-- Mutants du juge de la ligne : clé brute (T9, T14-T17, T19) ; répétition
-- sur toute la source (T16) ; lignes rejetées ignorées (T14, T16, T17, T19) ;
-- sans btrim (T16) ; fascicule sans « periodico » (T15, T16) ; fascicule en
-- tout format (T16) ; ouvert à authenticated (T16).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'IDENTIFIANT-ORIGINE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- admin reseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB uuid; v_libBibB uuid;
  v_src bigint; v_run bigint; v_run2 bigint; v_lot bigint; v_lot2 bigint; v_res jsonb;
  v_d1 bigint; v_d2 bigint; v_book1 bigint; v_book2 bigint; v_bookB bigint; v_row bigint;
  v_x bigint; v_id bigint; v_id2 bigint; v_id3 bigint; v_n int; v_m int; v_k int; v_ok boolean; v_txt text;
  v_run3 bigint; v_lot3 bigint; v_r1 bigint; v_r2 bigint; v_r3 bigint; v_r4 bigint; v_r5 bigint; v_r6 bigint;
  v_bookX bigint; v_bookY bigint; v_bookZ bigint; v_book5 bigint; v_book6 bigint; v_run4 bigint; v_row4 bigint; v_x4 bigint;
  -- H21 lot 0 (T14-T19)
  v_run5 bigint; v_run6 bigint; v_run7 bigint; v_run8 bigint; v_run9 bigint; v_run10 bigint; v_run11 bigint;
  v_lotR bigint; v_lotC bigint; v_lot4 bigint; v_lot5 bigint;
  v_bD1 bigint; v_bD2 bigint; v_bD3 bigint; v_bD4 bigint; v_bZ2 bigint; v_bL bigint;
  v_dR bigint; v_dL bigint; v_dA bigint; v_xA bigint;
  v_l1 bigint; v_l2 bigint; v_l3 bigint; v_l4 bigint; v_l5 bigint; v_l6 bigint; v_l7 bigint; v_l8 bigint;
  v_c1 bigint; v_c2 bigint; v_c3 bigint; v_aj int; v_pub text;
  -- seconde passe du lot 0 (T12, T20)
  v_corb text; v_run12 bigint; v_s1 bigint; v_s3 bigint; v_s4 bigint; v_s6 bigint; v_s8 bigint;
  v_dS1 bigint; v_dS3 bigint; v_dS4 bigint; v_dS6 bigint; v_dS8 bigint; v_lotS bigint; v_bS1 bigint;
  v_avant text; v_apres text; v_miroir text;
BEGIN
  -- ── Décor ───────────────────────────────────────────────────────────
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "H20-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-h20-b', 'Essai H20 — B', true, 'private') RETURNING id INTO v_libB;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h20-b-' || gen_random_uuid() || '@example.invalid', now(), now()) RETURNING id INTO v_libBibB;
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_libBibB, 'Essai', 'H20') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_libBibB, v_libB, 'librarian', 'active', true);

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai H20 PMB', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h20.marc', 'h20.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 1, 'PMB-001', 'H20 Avec son 001', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run, 2, NULL, 'H20 Sans 001', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb));

  -- ── T1 / T2 ─────────────────────────────────────────────────────────
  v_t := 'T1 une notice importee garde son 001 a la bibliotheque qui la publie ; T2 sans 001, rien';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot := (v_res->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d1 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 1;
    SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 2;
    UPDATE public.book_drafts SET bib_ref = 'H20-A-' || id, tipo_material = 'livro' WHERE id IN (v_d1, v_d2);
    v_ok := (SELECT source_record_id FROM public.book_drafts WHERE id = v_d1) = 'PMB-001'
            AND (SELECT (marc_json->'ingest'->>'source_id')::bigint FROM public.book_drafts WHERE id = v_d1) = v_src
            AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_d2) IS NULL;
    v_res := public.fn_batch_review_request(v_lot);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_book1 := public.publish_book_draft(v_d1);
    v_book2 := public.publish_book_draft(v_d2);
    IF v_ok
       AND (SELECT count(*) FROM public.book_external_ids e
             WHERE e.book_id = v_book1 AND e.library_id = v_lib AND e.scheme = 'import:' || v_src
               AND e.value = 'PMB-001' AND e.source_id = v_src) = 1
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.book_id = v_book2)
       AND (SELECT source_record_id FROM public.books WHERE id = v_book2) IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : brouillons='||coalesce(v_ok::text,'∅')
         ||' lignes='||(SELECT count(*) FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 un exemplaire rapproche d''une notice d''une autre bibliotheque : le 001 gardé pour qui importe';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, source_record_id)
    VALUES ('H20 Notice de B', 'H20-B-1', 'livro', v_libB, 'ORIGINE-DE-B') RETURNING id INTO v_bookB;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bookB, v_libB);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h20b.marc', 'h20b.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run2;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run2, 1, 'PMB-777', 'H20 Notice de B (doublon)', 'matched_book', 'accept_duplicate', v_bookB,
            jsonb_build_object('items', '[{"source_item_code":"H20-X1","call_number":"A"}]'::jsonb))
    RETURNING id INTO v_row;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := ingest.fn_create_exemplar_drafts_from_import_rows(v_run2, ARRAY[v_row]);
    v_lot2 := (v_res->>'batch_id')::bigint;
    SELECT min(id) INTO v_x FROM public.exemplar_drafts WHERE import_staging_row_id = v_row;
    -- aucun identifiant avant la publication
    v_n := (SELECT count(*) FROM public.book_external_ids WHERE book_id = v_bookB);
    -- H21 lot 0 (IMP-27 c) : un lot de rapprochement passe par la révision ;
    -- la coordination la demande, l'administration l'approuve.
    v_res := public.fn_batch_review_request(v_lot2);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.publish_exemplar_draft(v_x);
    IF v_n = 0
       AND (SELECT count(*) FROM public.book_external_ids e
             WHERE e.book_id = v_bookB AND e.library_id = v_lib AND e.scheme = 'import:' || v_src AND e.value = 'PMB-777') = 1
       AND (SELECT source_record_id FROM public.books WHERE id = v_bookB) = 'ORIGINE-DE-B'
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.book_id = v_bookB AND e.library_id = v_libB)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avant='||v_n||' apres='
         ||(SELECT count(*) FROM public.book_external_ids WHERE book_id = v_bookB)||' origine B='
         ||coalesce((SELECT source_record_id FROM public.books WHERE id = v_bookB),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 unicite par (bibliotheque, schema, valeur) ; deux bibliotheques ; reclame par une autre notice : reste a la premiere';
  BEGIN
    -- le même numéro, pour B : une seconde ligne
    PERFORM ingest.fn_record_book_external_id(v_bookB, v_libB, v_src, 'PMB-001');
    -- le numéro de A réclamé par une autre notice : il ne passe pas d'une
    -- notice à l'autre (revue du 28/09 : la dernière publiée l'emportait)
    PERFORM ingest.fn_record_book_external_id(v_book2, v_lib, v_src, '  PMB-001 ');
    -- sans valeur, sans bibliothèque, sans source : rien
    PERFORM ingest.fn_record_book_external_id(v_book1, v_lib, v_src, '   ');
    PERFORM ingest.fn_record_book_external_id(v_book1, NULL, v_src, 'PMB-X');
    PERFORM ingest.fn_record_book_external_id(v_book1, v_lib, NULL, 'PMB-Y');
    IF (SELECT count(*) FROM public.book_external_ids WHERE scheme = 'import:' || v_src AND value = 'PMB-001') = 2
       AND (SELECT book_id FROM public.book_external_ids WHERE library_id = v_lib AND scheme = 'import:' || v_src AND value = 'PMB-001') = v_book1
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids WHERE value IN ('PMB-X', 'PMB-Y', ''))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||(SELECT string_agg(library_id::text||'/'||value||'->'||book_id, ', ') FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2, v_bookB))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 lecture : staff de sa bibliotheque, administration ; ni les autres, ni anon ; pas d''ecriture par l''API';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) FILTER (WHERE library_id = v_lib), count(*) FILTER (WHERE library_id = v_libB) INTO v_n, v_m
      FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2, v_bookB);
    v_txt := NULL;
    BEGIN
      INSERT INTO public.book_external_ids (book_id, library_id, scheme, value) VALUES (v_book1, v_lib, 'import:1', 'FORGE');
      v_txt := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE;
    END;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libBibB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) FILTER (WHERE library_id = v_lib) INTO v_k FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2, v_bookB);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_id FROM public.book_external_ids WHERE book_id IN (v_book1, v_book2, v_bookB);
    EXECUTE 'RESET ROLE';
    IF v_n = 2 AND v_m = 0 AND v_k = 0 AND v_id = 3 AND v_txt = '42501'
       AND NOT has_table_privilege('anon', 'public.book_external_ids', 'SELECT')
       AND NOT has_function_privilege('authenticated', 'ingest.fn_record_book_external_id(bigint,uuid,bigint,text)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'ingest.fn_record_book_external_id(bigint,uuid,bigint,text)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : coordA A='||v_n||' B='||v_m||' libB voit A='||v_k||' admin='||v_id||' insert='||coalesce(v_txt,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 faux identifiants (numero de ligne) des brouillons non publies effaces ; un vrai, un publie, restent';
  BEGIN
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Faux', 'livro', v_lib, v_coord, 'draft', '424242', '{"ingest": {"staging_row_id": 424242}}'::jsonb) RETURNING id INTO v_id;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Vrai', 'livro', v_lib, v_coord, 'ready', 'PMB-9', '{"ingest": {"staging_row_id": 424243}}'::jsonb) RETURNING id INTO v_id2;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Faux jete', 'livro', v_lib, v_coord, 'cancelled', '424244', '{"ingest": {"staging_row_id": 424244}}'::jsonb) RETURNING id INTO v_id3;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Faux publie', 'livro', v_lib, v_coord, 'published', '424245', '{"ingest": {"staging_row_id": 424245}}'::jsonb) RETURNING id INTO v_x;
    v_n := ingest.fn_h20_effacer_faux_identifiants();
    IF v_n >= 2
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id3) IS NULL
       -- le miroir de marc_json (anarbib_provenance) aussi, sinon le pont le rend
       AND (SELECT marc_json->'anarbib_provenance'->>'source_record_id' FROM public.book_drafts WHERE id = v_id) IS NULL
       AND (SELECT marc_json->'anarbib_provenance'->>'source_record_id' FROM public.book_drafts WHERE id = v_id2) = 'PMB-9'
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id2) = 'PMB-9'
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_x) = '424245'
       AND ingest.fn_h20_effacer_faux_identifiants() = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : effaces='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 reprise des notices deja publiees depuis un import ; rejouee : rien de plus';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Publiee avant', 'H20-AVANT-1', 'livro') RETURNING id INTO v_id;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, published_book_id, marc_json)
    VALUES ('H20 Publiee avant', 'livro', v_lib, v_coord, 'published', 'PMB-555', v_id,
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'staging_row_id', 999999))) RETURNING id INTO v_id2;
    -- et une publiée dont l'« identifiant » est le numéro de sa ligne : pas reprise
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Publiee faux', 'H20-AVANT-2', 'livro') RETURNING id INTO v_id3;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, published_book_id, marc_json)
    VALUES ('H20 Publiee faux', 'livro', v_lib, v_coord, 'published', '888888', v_id3,
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'staging_row_id', 888888)));
    -- un brouillon de REPRISE publié par une autre bibliothèque recopie le
    -- marc_json et le source_record_id de la notice : il ne donne rien à B
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, action, source_record_id, published_book_id, marc_json)
    VALUES ('H20 Publiee avant (reprise de B)', 'livro', v_libB, v_libBibB, 'published', 'update', 'PMB-555', v_id,
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run, 'staging_row_id', 999999)));
    v_n := ingest.fn_h20_reprise_identifiants();
    v_m := ingest.fn_h20_reprise_identifiants();
    IF v_n >= 1 AND v_m = 0
       AND (SELECT count(*) FROM public.book_external_ids e
             WHERE e.book_id = v_id AND e.library_id = v_lib AND e.scheme = 'import:' || v_src AND e.value = 'PMB-555') = 1
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.book_id = v_id AND e.library_id = v_libB)
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.book_id = v_id3)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : reprise='||v_n||' rejouee='||v_m
         ||' B='||(SELECT count(*) FROM public.book_external_ids e WHERE e.book_id = v_id AND e.library_id = v_libB)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 fusion de notices : les identifiants du doublon, de chaque bibliotheque, passent a la notice gardee';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Gardee', 'H20-X-1', 'livro') RETURNING id INTO v_bookX;
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Doublon', 'H20-Y-1', 'livro') RETURNING id INTO v_bookY;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bookX, v_lib), (v_bookY, v_lib);
    PERFORM ingest.fn_record_book_external_id(v_bookY, v_lib, v_src, 'PMB-Y1');
    PERFORM ingest.fn_record_book_external_id(v_bookY, v_libB, v_src, 'PMB-Y1');
    PERFORM ingest.fn_record_book_external_id(v_bookX, v_lib, v_src, 'PMB-X1');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.merge_book(v_bookX, v_bookY);
    IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = v_bookY)
       AND (SELECT count(*) FROM public.book_external_ids WHERE book_id = v_bookX) = 3
       AND (SELECT count(*) FROM public.book_external_ids WHERE value = 'PMB-Y1' AND book_id = v_bookX) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||coalesce((SELECT string_agg(library_id::text||'/'||value||'->'||book_id, ', ') FROM public.book_external_ids WHERE value LIKE 'PMB-_1'),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Décor de T9 à T13 : un run de six lignes ─────────────────────────
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h20c.marc', 'h20c.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run3, 1, 'N-12', 'H20 Fascicule 12 (a)', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 2, 'N-12', 'H20 Fascicule 12 (b)', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 3, 'PMB-310', 'H20 Absorbee par une fiche', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 4, 'PMB-410', 'H20 Brouillon perdant', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 5, 'PMB-510', 'H20 Brouillon survivant', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run3, 6, NULL, 'H20 Cle egale a sa ligne', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb));
  UPDATE ingest.partner_catalog_staging_rows SET external_key = id::text WHERE run_id = v_run3 AND row_no = 6;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  v_res := public.fn_import_promote(v_run3, ARRAY['new_record'], ARRAY['accept_new']);
  v_lot3 := (v_res->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_r1 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 1;
  SELECT m.draft_id INTO v_r2 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 2;
  SELECT m.draft_id INTO v_r3 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 3;
  SELECT m.draft_id INTO v_r4 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 4;
  SELECT m.draft_id INTO v_r5 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 5;
  SELECT m.draft_id INTO v_r6 FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run3 AND s.row_no = 6;
  UPDATE public.book_drafts SET bib_ref = 'H20-C-' || id, tipo_material = 'livro' WHERE id IN (v_r1, v_r2, v_r3, v_r4, v_r5, v_r6);

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 cle portee par deux lignes du run, numero de fascicule : effaces a l''import ; numero d''un CSV sans periodique : garde';
  BEGIN
    -- le numéro d'un fascicule (CSV de périodiques, lot 63) ; celui d'un CSV
    -- de livres (MLEG, run 3 en production) reste
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Fascicule CSV', 'livro', v_lib, v_coord, 'draft', '7',
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run3, 'staging_row_id', 777001, 'detected_format', 'csv',
              'raw_payload', jsonb_build_object('numero', '7', 'periodico', 'Le Rat des bibliotheques')))) RETURNING id INTO v_id;
    INSERT INTO public.book_drafts (titulo, tipo_material, owner_library_id, created_by, status, source_record_id, marc_json)
    VALUES ('H20 Livre CSV', 'livro', v_lib, v_coord, 'draft', '8',
            jsonb_build_object('ingest', jsonb_build_object('run_id', v_run3, 'staging_row_id', 777002, 'detected_format', 'csv',
              'raw_payload', jsonb_build_object('numero', '8', 'titulo_livro', 'Un livre')))) RETURNING id INTO v_id2;
    v_n := ingest.fn_h20_effacer_faux_identifiants(v_run3);
    IF (SELECT source_record_id FROM public.book_drafts WHERE id = v_r1) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_r2) IS NULL
       AND (SELECT marc_json->'anarbib_provenance'->>'source_record_id' FROM public.book_drafts WHERE id = v_r2) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_r3) = 'PMB-310'
       AND v_n = 1
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_id2) = '8'
       AND ingest.fn_h20_identifiant_d_origine(v_id2) = '8'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lignes 1/2='
         ||coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_r1),'∅')||'/'
         ||coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_r2),'∅')||' effaces='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 un brouillon importe absorbe par une fiche existante lui laisse son 001';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H20 Fiche existante', 'H20-Z-1', 'livro') RETURNING id INTO v_bookZ;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM api.merge_draft_into_book(v_r3, v_bookZ, '{}'::jsonb);
    IF (SELECT status FROM public.book_drafts WHERE id = v_r3) = 'cancelled'
       AND (SELECT count(*) FROM public.book_external_ids e
             WHERE e.book_id = v_bookZ AND e.library_id = v_lib AND e.scheme = 'import:' || v_src AND e.value = 'PMB-310') = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '
         ||(SELECT count(*) FROM public.book_external_ids WHERE book_id = v_bookZ)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 / T13 ───────────────────────────────────────────────────────
  v_t := 'T11 fusion de brouillons : le 001 du perdant pose a la publication du survivant, source relue dans le run ; T13 cle egale a sa ligne, que la ligne porte';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM api.merge_book_drafts(v_r5, v_r4, '{}'::jsonb);
    -- un brouillon d'avant H20 : sa source n'est que dans le run
    UPDATE public.book_drafts SET marc_json = marc_json #- '{ingest,source_id}' WHERE id = v_r5;
    v_ok := (SELECT source_record_id FROM public.book_drafts WHERE id = v_r6)
              = (SELECT id::text FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run3 AND row_no = 6)
            AND NOT (SELECT marc_json->'ingest' ? 'source_id' FROM public.book_drafts WHERE id = v_r5);
    v_res := public.fn_batch_review_request(v_lot3);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_book5 := public.publish_book_draft(v_r5);
    v_book6 := public.publish_book_draft(v_r6);
    IF v_ok
       AND (SELECT string_agg(e.value, ',' ORDER BY e.value) FROM public.book_external_ids e
             WHERE e.book_id = v_book5 AND e.library_id = v_lib AND e.scheme = 'import:' || v_src AND e.source_id = v_src) = 'PMB-410,PMB-510'
       AND (SELECT e.value FROM public.book_external_ids e WHERE e.book_id = v_book6)
           = (SELECT id::text FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run3 AND row_no = 6)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : brouillons='||coalesce(v_ok::text,'∅')||' survivant='
         ||coalesce((SELECT string_agg(value, ',') FROM public.book_external_ids WHERE book_id = v_book5),'∅')||' cle-ligne='
         ||coalesce((SELECT string_agg(value, ',') FROM public.book_external_ids WHERE book_id = v_book6),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 un run ne se supprime pas tant qu''un exemplaire rapproche l''attend, ni tant qu''il est a la corbeille ; purge : il se supprime';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h20d.marc', 'h20d.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run4;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run4, 1, 'PMB-888', 'H20 Notice de B (autre doublon)', 'matched_book', 'accept_duplicate', v_bookB,
            jsonb_build_object('items', '[{"source_item_code":"H20-X8","call_number":"B"}]'::jsonb))
    RETURNING id INTO v_row4;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM ingest.fn_create_exemplar_drafts_from_import_rows(v_run4, ARRAY[v_row4]);
    SELECT min(id) INTO v_x4 FROM public.exemplar_drafts WHERE import_staging_row_id = v_row4;
    v_txt := NULL;
    BEGIN
      PERFORM public.fn_import_delete_run(v_run4);
      v_txt := 'supprime';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT;
    END;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x4;
    -- H21 lot 0, seconde passe (IMP-27 c, constat #0) : à la corbeille, il
    -- retient encore le run ; sans sa ligne (FK SET NULL), restauré, il se
    -- publierait comme un exemplaire fait à la main, sans révision.
    v_corb := NULL;
    BEGIN
      PERFORM public.fn_import_delete_run(v_run4);
      v_corb := 'supprime';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_corb = PG_EXCEPTION_HINT;
    END;
    -- purgé (« Vider la corbeille ») : il ne retient plus le run
    DELETE FROM public.exemplar_drafts WHERE id = v_x4;
    IF v_corb IS DISTINCT FROM 'supprime' THEN
      v_res := public.fn_import_delete_run(v_run4);
    END IF;
    IF v_x4 IS NOT NULL AND v_txt = 'error.import.run_has_drafts'
       AND v_corb = 'error.import.run_has_trashed_items'
       AND coalesce((v_res->>'ok')::boolean, false)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run4)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaire='||coalesce(v_x4::text,'∅')||' refus='||coalesce(v_txt,'∅')
         ||' corbeille='||coalesce(v_corb,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ══ H21 lot 0 : l'identifiant d'origine se juge sur la LIGNE d'import ══
  -- ── T14 ─────────────────────────────────────────────────────────────
  v_t := 'T14 exemplaire rapproche : une cle que deux lignes du fichier portent (l''autre rejetee) n''est pas enregistree ; une cle unique l''est';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H21D Notice 1', 'H21D-B-1', 'livro') RETURNING id INTO v_bD1;
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H21D Notice 2', 'H21D-B-2', 'livro') RETURNING id INTO v_bD2;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bD1, v_lib), (v_bD2, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21d-a.marc', 'h21d-a.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run5;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run5, 1, 'H21D-DUP', 'H21D Rapprochee (cle repetee)', 'matched_book', 'accept_duplicate', v_bD1,
            jsonb_build_object('items', '[{"source_item_code":"H21D-X1"}]'::jsonb)),
           (v_run5, 2, 'H21D-DUP', 'H21D Rejetee (meme cle)', 'new_record', 'reject', NULL, jsonb_build_object('items', '[]'::jsonb)),
           (v_run5, 3, 'H21D-901', 'H21D Rapprochee (cle unique)', 'matched_book', 'accept_duplicate', v_bD2,
            jsonb_build_object('items', '[{"source_item_code":"H21D-X2"}]'::jsonb));
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := ingest.fn_create_exemplar_drafts_from_import_rows(v_run5);
    v_lotR := (v_res->>'batch_id')::bigint;
    -- IMP-27 (c) : le lot de rapprochement est révisé avant toute publication
    v_res := public.fn_batch_review_request(v_lotR);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    FOR v_x IN SELECT x.id FROM public.exemplar_drafts x WHERE x.batch_id = v_lotR ORDER BY x.id LOOP
      PERFORM public.publish_exemplar_draft(v_x);
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM public.book_external_ids WHERE value = 'H21D-DUP')
       AND (SELECT count(*) FROM public.book_external_ids e WHERE e.book_id = v_bD2 AND e.library_id = v_lib
             AND e.scheme = 'import:' || v_src AND e.value = 'H21D-901') = 1
       AND (SELECT count(*) FROM public.exemplares WHERE library_id = v_lib AND source_item_code IN ('H21D-X1', 'H21D-X2')) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cles='
         ||coalesce((SELECT string_agg(value||'->'||book_id, ', ') FROM public.book_external_ids WHERE book_id IN (v_bD1, v_bD2)),'∅')
         ||' exemplaires='||(SELECT count(*) FROM public.exemplares WHERE library_id = v_lib AND source_item_code IN ('H21D-X1', 'H21D-X2'))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T15 ─────────────────────────────────────────────────────────────
  v_t := 'T15 exemplaire rapproche depuis un CSV de periodiques : pas le numero du fascicule ; le numero d''un CSV de livres, oui';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H21D Fascicule CSV', 'H21D-B-3', 'livro') RETURNING id INTO v_bD3;
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H21D Livre CSV', 'H21D-B-4', 'livro') RETURNING id INTO v_bD4;
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bD3, v_lib), (v_bD4, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21d-b.csv', 'h21d-b.csv', 'csv', 'ready_for_review') RETURNING id INTO v_run6;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, raw_payload, normalized_payload)
    VALUES (v_run6, 1, '12', 'H21D Fascicule 12', 'matched_book', 'accept_duplicate', v_bD3,
            jsonb_build_object('numero', '12', 'periodico', 'Le Rat des bibliotheques'), jsonb_build_object('items', '[]'::jsonb)),
           (v_run6, 2, '8', 'H21D Livre 8', 'matched_book', 'accept_duplicate', v_bD4,
            jsonb_build_object('numero', '8', 'titulo_livro', 'Un livre'), jsonb_build_object('items', '[]'::jsonb));
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := ingest.fn_create_exemplar_drafts_from_import_rows(v_run6);
    v_lotC := (v_res->>'batch_id')::bigint;
    v_res := public.fn_batch_review_request(v_lotC);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_n := 0;
    FOR v_x IN SELECT x.id FROM public.exemplar_drafts x WHERE x.batch_id = v_lotC ORDER BY x.id LOOP
      PERFORM public.publish_exemplar_draft(v_x);
      v_n := v_n + 1;
    END LOOP;
    IF v_n = 2
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids WHERE book_id = v_bD3)
       AND (SELECT count(*) FROM public.book_external_ids e WHERE e.book_id = v_bD4 AND e.library_id = v_lib
             AND e.scheme = 'import:' || v_src AND e.value = '8') = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : publies='||v_n||' cles='
         ||coalesce((SELECT string_agg(value||'->'||book_id, ', ') FROM public.book_external_ids WHERE book_id IN (v_bD3, v_bD4)),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  v_t := 'T16 juge de la ligne : vide, repetee (espaces, decision indifferente), fascicule CSV : rien ; cle unique, meme cle dans un autre run, numero d''un CSV de livres, numero d''un run MARC, cle egale a sa ligne : la cle ; DEFINER, STABLE, ferme a l''API';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21d-c.marc', 'h21d-c.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run7;
    -- le même fichier, réimporté : un AUTRE run de la même source
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21d-c-bis.marc', 'h21d-c-bis.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run8;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21d-c.csv', 'h21d-c.csv', 'csv', 'ready_for_review') RETURNING id INTO v_run11;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title) VALUES (v_run7, 1, 'H21D-K-REP', 'H21D L1') RETURNING id INTO v_l1;
    -- la même clé, entourée d'espaces, sur une ligne REJETÉE : elle compte
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, editorial_decision)
    VALUES (v_run7, 2, ' H21D-K-REP ', 'H21D L2', 'reject') RETURNING id INTO v_l2;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title) VALUES (v_run7, 3, NULL, 'H21D L3') RETURNING id INTO v_l3;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title) VALUES (v_run7, 4, '   ', 'H21D L4') RETURNING id INTO v_l4;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title) VALUES (v_run7, 5, 'H21D-K-OK', 'H21D L5') RETURNING id INTO v_l5;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title) VALUES (v_run7, 6, NULL, 'H21D L6') RETURNING id INTO v_l6;
    UPDATE ingest.partner_catalog_staging_rows SET external_key = id::text WHERE id = v_l6;
    -- un run MARC dont le raw_payload a « numero » et « periodico » : la règle
    -- du fascicule ne vaut que pour un CSV
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload)
    VALUES (v_run7, 7, '13', 'H21D L7', jsonb_build_object('numero', '13', 'periodico', 'Y')) RETURNING id INTO v_l7;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title) VALUES (v_run8, 1, 'H21D-K-OK', 'H21D L5 reimportee') RETURNING id INTO v_l8;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload)
    VALUES (v_run11, 1, '12', 'H21D C1', jsonb_build_object('numero', '12', 'periodico', 'Le Rat des bibliotheques')) RETURNING id INTO v_c1;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload)
    VALUES (v_run11, 2, '8', 'H21D C2', jsonb_build_object('numero', '8', 'titulo_livro', 'Un livre')) RETURNING id INTO v_c2;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, raw_payload)
    VALUES (v_run11, 3, 'H21D-EXT-1', 'H21D C3', jsonb_build_object('numero', '1', 'periodico', 'X')) RETURNING id INTO v_c3;
    IF ingest.fn_h20_cle_de_la_ligne(v_l1) IS NULL AND ingest.fn_h20_cle_de_la_ligne(v_l2) IS NULL
       AND ingest.fn_h20_cle_de_la_ligne(v_l3) IS NULL AND ingest.fn_h20_cle_de_la_ligne(v_l4) IS NULL
       AND ingest.fn_h20_cle_de_la_ligne(v_l5) = 'H21D-K-OK' AND ingest.fn_h20_cle_de_la_ligne(v_l8) = 'H21D-K-OK'
       AND ingest.fn_h20_cle_de_la_ligne(v_l6) = v_l6::text
       AND ingest.fn_h20_cle_de_la_ligne(v_l7) = '13'
       AND ingest.fn_h20_cle_de_la_ligne(v_c1) IS NULL AND ingest.fn_h20_cle_de_la_ligne(v_c2) = '8'
       AND ingest.fn_h20_cle_de_la_ligne(v_c3) = 'H21D-EXT-1'
       AND ingest.fn_h20_cle_de_la_ligne(-1) IS NULL
       AND (SELECT p.prosecdef AND p.provolatile = 's'
                   AND p.proowner = (SELECT c.relowner FROM pg_class c WHERE c.oid = 'ingest.partner_catalog_staging_rows'::regclass)
              FROM pg_proc p WHERE p.oid = 'ingest.fn_h20_cle_de_la_ligne(bigint)'::regprocedure)
       AND NOT has_function_privilege('authenticated', 'ingest.fn_h20_cle_de_la_ligne(bigint)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'ingest.fn_h20_cle_de_la_ligne(bigint)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : l1..l8/c1..c3='||concat_ws('/',
         coalesce(ingest.fn_h20_cle_de_la_ligne(v_l1),'∅'), coalesce(ingest.fn_h20_cle_de_la_ligne(v_l2),'∅'),
         coalesce(ingest.fn_h20_cle_de_la_ligne(v_l3),'∅'), coalesce(ingest.fn_h20_cle_de_la_ligne(v_l4),'∅'),
         coalesce(ingest.fn_h20_cle_de_la_ligne(v_l5),'∅'), coalesce(ingest.fn_h20_cle_de_la_ligne(v_l6),'∅'),
         coalesce(ingest.fn_h20_cle_de_la_ligne(v_l7),'∅'), coalesce(ingest.fn_h20_cle_de_la_ligne(v_l8),'∅'),
         coalesce(ingest.fn_h20_cle_de_la_ligne(v_c1),'∅'), coalesce(ingest.fn_h20_cle_de_la_ligne(v_c2),'∅'),
         coalesce(ingest.fn_h20_cle_de_la_ligne(v_c3),'∅'))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T17 ─────────────────────────────────────────────────────────────
  v_t := 'T17 brouillon ne d''une ligne dont la cle est portee par une ligne REJETEE du meme fichier : cle effacee a la promotion, aucun identifiant ; l''autre garde la sienne';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21d-d.marc', 'h21d-d.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run9;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run9, 1, 'H21D-R', 'H21D Promue (cle repetee)', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
           (v_run9, 2, 'H21D-R', 'H21D Rejetee (meme cle)', 'new_record', 'reject', jsonb_build_object('items', '[]'::jsonb)),
           (v_run9, 3, 'H21D-L', 'H21D Promue (cle propre)', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb));
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_import_promote(v_run9, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot4 := (v_res->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_dR FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run9 AND s.row_no = 1;
    SELECT m.draft_id INTO v_dL FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run9 AND s.row_no = 3;
    IF v_dR IS NOT NULL AND v_dL IS NOT NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_dR) IS NULL
       AND ingest.fn_h20_identifiant_d_origine(v_dR) IS NULL
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_dL) = 'H21D-L'
       AND ingest.fn_h20_identifiant_d_origine(v_dL) = 'H21D-L'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : R='||coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dR),'∅')
         ||'/'||coalesce(ingest.fn_h20_identifiant_d_origine(v_dR),'∅')||' L='||coalesce(ingest.fn_h20_identifiant_d_origine(v_dL),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T18 ─────────────────────────────────────────────────────────────
  v_t := 'T18 un brouillon ne d''une ligne est juge sur SA ligne (row_to_draft) : source_record_id et marc_json.ingest.staging_row_id retouches ne changent pas la cle enregistree';
  BEGIN
    -- le formulaire (source_record_id) et l'API (marc_json) réécrivent ce
    -- que la promotion avait posé ; row_to_draft, seule la promotion l'écrit
    UPDATE public.book_drafts
       SET source_record_id = 'H21D-FORGE-1',
           marc_json = jsonb_set(marc_json, '{ingest,staging_row_id}',
                         to_jsonb((SELECT id FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run9 AND row_no = 2))),
           bib_ref = 'H21D-L-' || id, tipo_material = 'livro'
     WHERE id = v_dL;
    v_txt := ingest.fn_h20_identifiant_d_origine(v_dL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_batch_review_request(v_lot4);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_bL := public.publish_book_draft(v_dL);
    IF v_txt = 'H21D-L'
       AND (SELECT count(*) FROM public.book_external_ids e WHERE e.book_id = v_bL AND e.library_id = v_lib
             AND e.scheme = 'import:' || v_src AND e.value = 'H21D-L') = 1
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids WHERE value IN ('H21D-FORGE-1', 'H21D-R'))
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : juge='||coalesce(v_txt,'∅')||' cles='
         ||coalesce((SELECT string_agg(value, ',') FROM public.book_external_ids WHERE book_id = v_bL),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T19 ─────────────────────────────────────────────────────────────
  v_t := 'T19 brouillon absorbe par une fiche detenue, puis son exemplaire detache publie sans second tour : une cle repetee dans le fichier n''est enregistree ni par l''absorption ni par l''exemplaire';
  BEGIN
    INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('H21D Fiche absorbante', 'H21D-Z-2', 'livro') RETURNING id INTO v_bZ2;
    -- IMP-26 (a) : on n'absorbe que dans une notice que sa bibliothèque détient
    INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bZ2, v_lib);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21d-e.marc', 'h21d-e.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run10;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run10, 1, 'H21D-A2', 'H21D Absorbee (cle repetee)', 'new_record', 'accept_new',
            jsonb_build_object('items', '[{"source_item_code":"H21D-XA","call_number":"Z"}]'::jsonb)),
           (v_run10, 2, 'H21D-A2', 'H21D Rejetee (meme cle)', 'new_record', 'reject', jsonb_build_object('items', '[]'::jsonb));
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_import_promote(v_run10, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot5 := (v_res->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_dA FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run10 AND s.row_no = 1;
    UPDATE public.book_drafts SET bib_ref = 'H21D-A-' || id, tipo_material = 'livro' WHERE id = v_dA;
    SELECT min(x.id) INTO v_xA FROM public.exemplar_drafts x WHERE x.book_draft_id = v_dA;
    -- révision demandée et approuvée AVANT l'absorption : l'exemplaire, encore
    -- rattaché à sa notice, figure parmi ce que le tour soumet (IMP-27 b)
    v_res := public.fn_batch_review_request(v_lot5);
    v_ok := EXISTS (SELECT 1 FROM public.catalog_batch_reviews r
                     WHERE r.id = (v_res->>'review_id')::bigint AND v_xA = ANY (r.exemplar_draft_ids));
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM api.merge_draft_into_book(v_dA, v_bZ2, '{}'::jsonb);
    -- détaché de sa notice APRÈS la demande, sans avoir été rangé ensuite : le
    -- tour le couvre toujours. Rien n'attend un nouveau tour, la coordination
    -- ne peut pas en redemander un (et n'a pas à le faire) ; il se publie tel.
    v_aj := public.fn_batch_ajouts_apres_revision(v_lot5);
    v_txt := NULL;
    BEGIN
      PERFORM public.fn_batch_review_request(v_lot5);
      v_txt := 'second tour accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_txt = PG_EXCEPTION_HINT;
    END;
    v_pub := 'publie';
    BEGIN
      PERFORM public.publish_exemplar_draft(v_xA);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_pub = PG_EXCEPTION_HINT;
    END;
    IF v_xA IS NOT NULL AND v_ok AND v_aj = 0
       AND v_txt = 'error.review.already_approved' AND v_pub = 'publie'
       AND (SELECT count(*) FROM public.catalog_batch_reviews WHERE batch_id = v_lot5) = 1
       AND (SELECT status FROM public.book_drafts WHERE id = v_dA) = 'cancelled'
       AND (SELECT book_draft_id FROM public.exemplar_drafts WHERE id = v_xA) IS NULL
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_xA) = 'published'
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids WHERE value = 'H21D-A2')
       AND EXISTS (SELECT 1 FROM public.exemplares WHERE library_id = v_lib AND source_item_code = 'H21D-XA')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaire='||coalesce(v_xA::text,'∅')
         ||' couvert='||coalesce(v_ok::text,'∅')||' ajouts='||coalesce(v_aj::text,'∅')
         ||' second tour='||coalesce(v_txt,'∅')
         ||' tours='||(SELECT count(*) FROM public.catalog_batch_reviews WHERE batch_id = v_lot5)
         ||' publication='||coalesce(v_pub,'∅')
         ||' statut='||coalesce((SELECT status FROM public.exemplar_drafts WHERE id = v_xA),'∅')
         ||' cles Z2='||coalesce((SELECT string_agg(value, ',') FROM public.book_external_ids WHERE book_id = v_bZ2),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T20 ─────────────────────────────────────────────────────────────
  v_t := 'T20 identifiant d''origine saisi a la main sur un brouillon lie sans cle valide (repetee, vide) : la selection suivante du run ne l''efface pas ; la cle venue du fichier, portee encore, reste effacee';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h21s.marc', 'h21s.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run12;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run12, 1, 'H21S-DUP',  'H21S Saisie (cle repetee)',            'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
           (v_run12, 2, 'H21S-DUP',  'H21S Rejetee (meme cle)',              'new_record', 'reject',     jsonb_build_object('items', '[]'::jsonb)),
           (v_run12, 3, NULL,        'H21S Saisie (sans cle)',               'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
           (v_run12, 4, 'H21S-DUP4', 'H21S Cle du fichier ressaisie',        'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
           (v_run12, 5, 'H21S-DUP4', 'H21S Rejetee (meme cle 4)',            'new_record', 'reject',     jsonb_build_object('items', '[]'::jsonb)),
           -- la clé du fichier entourée d'espaces : la promotion la rogne, l'effaceur
           -- la reconnaît (btrim des deux côtés)
           (v_run12, 6, ' H21S-DUP6 ', 'H21S Selection suivante (repetee)',  'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
           (v_run12, 7, 'H21S-DUP6', 'H21S Rejetee (meme cle 6)',            'new_record', 'reject',     jsonb_build_object('items', '[]'::jsonb)),
           (v_run12, 8, 'H21S-OK',   'H21S Selection suivante (cle unique)', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb));
    SELECT id INTO v_s1 FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run12 AND row_no = 1;
    SELECT id INTO v_s3 FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run12 AND row_no = 3;
    SELECT id INTO v_s4 FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run12 AND row_no = 4;
    SELECT id INTO v_s6 FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run12 AND row_no = 6;
    SELECT id INTO v_s8 FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run12 AND row_no = 8;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- première sélection : la clé répétée venue du fichier est effacée à la
    -- promotion, comme avant ; une ligne sans clé n'en donne aucune
    v_res := public.fn_import_promote(v_run12, ARRAY['new_record'], ARRAY['accept_new'], p_row_ids := ARRAY[v_s1, v_s3, v_s4]);
    SELECT draft_id INTO v_dS1 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_s1;
    SELECT draft_id INTO v_dS3 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_s3;
    SELECT draft_id INTO v_dS4 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_s4;
    v_avant := concat_ws('/',
                 coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dS1), '∅'),
                 coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dS3), '∅'),
                 coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dS4), '∅'));
    -- la coordination saisit l'identifiant d'origine au formulaire (champ
    -- source_record_id) ; sur dS4, elle ressaisit la clé du fichier telle quelle
    UPDATE public.book_drafts SET source_record_id = 'PMB-SAISI-1', bib_ref = 'H21S-' || id, tipo_material = 'livro' WHERE id = v_dS1;
    UPDATE public.book_drafts SET source_record_id = 'PMB-SAISI-3' WHERE id = v_dS3;
    UPDATE public.book_drafts SET source_record_id = 'H21S-DUP4' WHERE id = v_dS4;
    -- la sélection suivante du même run, d'AUTRES lignes (IMP-27 d : elle
    -- rejoint le lot) ; elle passe l'effaceur sur tout le run
    v_res := public.fn_import_promote(v_run12, ARRAY['new_record'], ARRAY['accept_new'], p_row_ids := ARRAY[v_s6, v_s8]);
    SELECT draft_id INTO v_dS6 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_s6;
    SELECT draft_id INTO v_dS8 FROM ingest.partner_catalog_row_to_draft WHERE staging_row_id = v_s8;
    v_apres := concat_ws('/',
                 coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dS1), '∅'),
                 coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dS3), '∅'),
                 coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dS4), '∅'),
                 coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dS6), '∅'),
                 coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_dS8), '∅'));
    v_miroir := concat_ws('/',
                  coalesce((SELECT marc_json->'anarbib_provenance'->>'source_record_id' FROM public.book_drafts WHERE id = v_dS1), '∅'),
                  coalesce((SELECT marc_json->'anarbib_provenance'->>'source_record_id' FROM public.book_drafts WHERE id = v_dS4), '∅'));
    -- publiée APRÈS la sélection suivante, la saisie arrive à la notice
    v_lotS := (SELECT batch_id FROM public.book_drafts WHERE id = v_dS1);
    v_res := public.fn_batch_review_request(v_lotS);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_bS1 := public.publish_book_draft(v_dS1);
    IF v_dS1 IS NOT NULL AND v_dS3 IS NOT NULL AND v_dS4 IS NOT NULL AND v_dS6 IS NOT NULL AND v_dS8 IS NOT NULL
       AND v_avant = '∅/∅/∅'
       AND v_apres = 'PMB-SAISI-1/PMB-SAISI-3/∅/∅/H21S-OK'
       AND v_miroir = 'PMB-SAISI-1/∅'
       AND (SELECT source_record_id FROM public.books WHERE id = v_bS1) = 'PMB-SAISI-1'
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids WHERE book_id = v_bS1)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : promotion 1/3/4='||coalesce(v_avant,'∅')
         ||' apres la selection suivante 1/3/4/6/8='||coalesce(v_apres,'∅')||' miroir 1/4='||coalesce(v_miroir,'∅')
         ||' notice='||coalesce((SELECT source_record_id FROM public.books WHERE id = v_bS1),'∅')
         ||' cles='||coalesce((SELECT string_agg(value, ',') FROM public.book_external_ids WHERE book_id = v_bS1),'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IDENTIFIANT-ORIGINE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IDENTIFIANT-ORIGINE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
