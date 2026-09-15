-- =====================================================================
-- AnarBib — Tests d'acceptation : un lot importe a une bibliotheque de
-- destination — declaree, tamponnee a la promotion, reattribuable
-- Date    : 2026-09-15  ·  Session : importations / a qui appartient le fonds
-- Ref     : migration 20260915184154_un_lot_importe_a_une_bibliotheque
--
-- Pourquoi cette suite existe : jusqu'ici la creation des brouillons d'un
-- import ne posait jamais owner_library_id, et la publication retombait sur
-- la biblio de qui publie. Le lot Solidaires (1673 brouillons, biblio creee
-- le 14/09) n'avait aucun geste dans l'app pour etre rattache.
--
-- T1-T3 : le TAMPON a la promotion, selon la provenance (propre / compagne
-- sans destination / compagne avec destination). T4-T8 : la REATTRIBUTION
-- (qui, quoi, ce qui ne bouge pas, ce qui refuse). T9 : ce que l'ecran lit.
-- T10 : les droits. Les refus sont confrontes au HINT reel.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'LOT-IMPORTE-BIBLIO-DESTINATION OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed) ; devient admin reseau a T2
  v_other uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans role (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_lib2  uuid;                                            -- biblio compagne, creee ici (inactive, sans tombo)
  v_src_own bigint; v_src_dep bigint; v_src_dep2 bigint;
  v_run bigint; v_row bigint;
  v_lot_own bigint; v_lot_dep bigint; v_lot_dep2 bigint;
  v_draft_pub bigint; v_draft_trash bigint;
  v_res jsonb; v_hint text; v_n int; v_owner uuid; v_notes text; v_txt text;
  v_rev bigint;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-compagne-destination', 'Essai — Biblio compagne', false, 'private')
  RETURNING id INTO v_lib2;

  -- Les brouillons d'un import portent partner_source = 'other_partner', et le
  -- trigger de contexte (book_draft_catalog_context) le confronte a la table de
  -- reference catalog_ref_source_partners. La ligne existe en prod comme DONNEE
  -- (aucune migration ne la pose) : sans elle, la promotion ne se rejoue pas
  -- au banc. Annulee avec le reste.
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;

  -- ── T1 : catalogue propre → la biblio du run est tamponnee ──────────────
  v_t := 'T1 promotion d''un catalogue propre : owner_library_id = la biblio du run';
  BEGIN
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('Essai propre', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src_own;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, run_status)
    VALUES (v_src_own, v_lib, 'essai/propre.csv', 'propre.csv', 'drafts_created') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'own-1', 'Champs, usines et ateliers', 'new_record', 'accept_new') RETURNING id INTO v_row;
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot_own := (v_res->>'batch_id')::bigint;
    SELECT d.owner_library_id INTO v_owner FROM public.book_drafts d WHERE d.batch_id = v_lot_own;
    IF v_owner = v_lib AND (v_res->>'owner_stamped')::int = 1
       AND (SELECT d.owner_library FROM public.book_drafts d WHERE d.batch_id = v_lot_own) = 'BLMF (base de test)'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : owner='||coalesce(v_owner::text,'NULL')||' res='||left(v_res::text,300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- Le meme compte devient admin reseau : un depot de compagne ne se promeut pas autrement.
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_coord, 'active');

  -- ── T2 : depot de compagne SANS destination → rien n'est tamponne ───────
  v_t := 'T2 promotion d''un depot de compagne sans destination : owner_library_id reste nul';
  BEGIN
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('Essai compagne sans destination', v_lib, 'mapeada', 'partner_deposit', true) RETURNING id INTO v_src_dep;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, run_status)
    VALUES (v_src_dep, v_lib, 'essai/dep.csv', 'dep.csv', 'drafts_created') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'dep-1', 'La conquete du pain', 'new_record', 'accept_new') RETURNING id INTO v_row;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 2, 'dep-2', 'L''entraide', 'new_record', 'accept_new');
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot_dep := (v_res->>'batch_id')::bigint;
    SELECT count(*) INTO v_n FROM public.book_drafts d WHERE d.batch_id = v_lot_dep AND d.owner_library_id IS NULL;
    IF v_n = 2 AND (v_res->>'owner_stamped')::int = 0 AND v_res->>'owner_library_id' IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : sans_owner='||v_n||' res='||left(v_res::text,300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 : depot de compagne AVEC destination (declaree a l'enregistrement) ─
  v_t := 'T3 fn_import_register_deposit_source ecrit la destination, et la promotion la tamponne';
  BEGIN
    v_res := public.fn_import_register_deposit_source('Essai compagne admise', NULL, v_lib2);
    v_src_dep2 := (v_res->>'source_id')::bigint;
    IF (SELECT s.destination_library_id FROM ingest.partner_catalog_sources s WHERE s.id = v_src_dep2) IS DISTINCT FROM v_lib2 THEN
      RAISE EXCEPTION 'destination non ecrite a l''enregistrement';
    END IF;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, run_status)
    VALUES (v_src_dep2, v_lib, 'essai/dep2.csv', 'dep2.csv', 'drafts_created') RETURNING id INTO v_run;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run, 1, 'dep2-1', 'Paroles d''un revolte', 'new_record', 'accept_new');
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot_dep2 := (v_res->>'batch_id')::bigint;
    SELECT d.owner_library_id INTO v_owner FROM public.book_drafts d WHERE d.batch_id = v_lot_dep2;
    IF v_owner = v_lib2 AND (v_res->>'owner_stamped')::int = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : owner='||coalesce(v_owner::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3b : la source deja connue recoit la destination donnee plus tard ───
  v_t := 'T3b re-enregistrer une source connue avec une destination la met a jour (created=false)';
  BEGIN
    v_res := public.fn_import_register_deposit_source('Essai compagne sans destination', NULL, v_lib2);
    IF (v_res->>'created')::boolean = false AND (v_res->>'source_id')::bigint = v_src_dep
       AND (SELECT s.destination_library_id FROM ingest.partner_catalog_sources s WHERE s.id = v_src_dep) = v_lib2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text,200)); END IF;
    -- on remet la source sans destination pour T5 (qui doit l'aligner lui-meme)
    UPDATE ingest.partner_catalog_sources SET destination_library_id = NULL WHERE id = v_src_dep;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 : reattribuer n'est pas un geste de coordination ──────────────────
  v_t := 'T4 un compte qui n''est pas admin reseau ne reattribue pas (hint admin_only), et rien ne bouge';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_batch_reassign_library(v_lot_dep, v_lib2);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      SELECT count(*) INTO v_n FROM public.book_drafts d WHERE d.batch_id = v_lot_dep AND d.owner_library_id IS NOT NULL;
      IF v_hint = 'error.batch.reassign.admin_only' AND v_n = 0 THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')||' bouges='||v_n); END IF;
    END;
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 : la reattribution, en entier ─────────────────────────────────────
  v_t := 'T5 l''admin reattribue : les brouillons en cours changent, publie et corbeille non, la source suit, la trace est ecrite, les avertissements sont dits';
  BEGIN
    -- un brouillon deja publie et un a la corbeille dans le meme lot, qui ne doivent pas bouger
    INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, bib_ref, owner_library_id, initial_copies_library_id)
    VALUES ('Deja publie', v_lot_dep, 'published', 'livro', 'ESSAI-DEST-PUB', v_lib, v_lib) RETURNING id INTO v_draft_pub;
    INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, bib_ref, owner_library_id)
    VALUES ('A la corbeille', v_lot_dep, 'cancelled', 'livro', 'ESSAI-DEST-TRASH', v_lib) RETURNING id INTO v_draft_trash;
    -- un override admin pose sur un brouillon en cours : il doit tomber
    UPDATE public.book_drafts SET initial_copies_library_id = v_lib
     WHERE batch_id = v_lot_dep AND status = 'draft' AND titulo = 'La conquete du pain';

    v_res := public.fn_batch_reassign_library(v_lot_dep, v_lib2);

    SELECT count(*) INTO v_n FROM public.book_drafts d
     WHERE d.batch_id = v_lot_dep AND d.status = 'draft'
       AND d.owner_library_id = v_lib2 AND d.owner_library = 'Essai — Biblio compagne'
       AND d.initial_copies_library_id IS NULL;
    SELECT notes INTO v_notes FROM public.catalog_batches WHERE id = v_lot_dep;
    IF v_n = 2
       AND (v_res->>'drafts_updated')::int = 2
       AND (v_res->>'drafts_published_untouched')::int = 1
       AND (v_res->>'sources_aligned')::int = 1
       AND (SELECT d.owner_library_id FROM public.book_drafts d WHERE d.id = v_draft_pub) = v_lib
       AND (SELECT d.initial_copies_library_id FROM public.book_drafts d WHERE d.id = v_draft_pub) = v_lib
       AND (SELECT d.owner_library_id FROM public.book_drafts d WHERE d.id = v_draft_trash) = v_lib
       AND (SELECT s.destination_library_id FROM ingest.partner_catalog_sources s WHERE s.id = v_src_dep) = v_lib2
       AND v_notes LIKE '%Lote reatribuido a biblioteca « Essai — Biblio compagne »%'
       AND v_notes LIKE '%antes : sem biblioteca%'
       AND v_res->'warnings' ? 'library_without_tombo_pattern'
       AND v_res->'warnings' ? 'library_inactive'
       AND NOT (v_res->'warnings' ? 'nothing_to_do')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : n='||v_n||' res='||left(v_res::text,400)||' notes='||left(coalesce(v_notes,'NULL'),200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 : rejouer le meme geste ne fait rien, et le dit ───────────────────
  v_t := 'T6 reattribuer vers la meme biblio : 0 brouillon, avertissement nothing_to_do, pas de refus';
  BEGIN
    v_res := public.fn_batch_reassign_library(v_lot_dep, v_lib2);
    IF (v_res->>'drafts_updated')::int = 0 AND v_res->'warnings' ? 'nothing_to_do' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text,300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 : une revision approuvee ferme la porte ───────────────────────────
  v_t := 'T7 un lot dont la revision est approuvee ne se reattribue pas (hint review_approved) ; un tour en retouches n''empeche rien';
  BEGIN
    INSERT INTO public.catalog_batch_reviews (batch_id, round, status, requested_by, requested_at, reviewed_by, reviewed_at)
    VALUES (v_lot_dep2, 1, 'approved', v_coord, now(), v_coord, now()) RETURNING id INTO v_rev;
    BEGIN
      PERFORM public.fn_batch_reassign_library(v_lot_dep2, v_lib);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint <> 'error.batch.reassign.review_approved' THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL'));
      ELSE
        -- tour 2 en retouches : la porte se rouvre
        INSERT INTO public.catalog_batch_reviews (batch_id, round, status, requested_by, requested_at, reviewed_by, reviewed_at, admin_notes)
        VALUES (v_lot_dep2, 2, 'changes_requested', v_coord, now(), v_coord, now(), 'revoir la destination');
        v_res := public.fn_batch_reassign_library(v_lot_dep2, v_lib);
        IF (v_res->>'drafts_updated')::int = 1 THEN v_passed := v_passed+1;
        ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : apres retouches '||left(v_res::text,200)); END IF;
      END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 : lot ferme, biblio inconnue, lot inconnu ─────────────────────────
  v_t := 'T8 refus : lot ferme (not_open), biblio inconnue (library_not_found), lot inconnu (not_found)';
  BEGIN
    UPDATE public.catalog_batches SET status = 'closed' WHERE id = v_lot_own;
    v_txt := '';
    BEGIN
      PERFORM public.fn_batch_reassign_library(v_lot_own, v_lib2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN
      PERFORM public.fn_batch_reassign_library(v_lot_dep, gen_random_uuid());
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    BEGIN
      PERFORM public.fn_batch_reassign_library(-1, v_lib2);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_txt := v_txt || coalesce(v_hint,'?') || ';'; END;
    IF v_txt = 'error.batch.reassign.not_open;error.batch.reassign.library_not_found;error.batch.reassign.not_found;'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
    UPDATE public.catalog_batches SET status = 'open' WHERE id = v_lot_own;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 : ce que l'ecran lit ──────────────────────────────────────────────
  v_t := 'T9 fn_batch_owner_libraries : par lot, la biblio des brouillons en cours (nulle = sans biblio), sans les publies ni la corbeille';
  BEGIN
    -- v_lot_dep : 2 en cours chez lib2 (publie + corbeille exclus) ; v_lot_own : 1 chez BLMF ; v_lot_dep2 : 1 chez BLMF (T7)
    IF (SELECT count(*) FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lot_dep) = 1
       AND (SELECT o.drafts FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lot_dep) = 2
       AND (SELECT o.library_name FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lot_dep) = 'Essai — Biblio compagne'
       AND (SELECT o.library_id FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lot_own) = v_lib
       AND (SELECT s.destination_library_name FROM public.fn_import_list_sources() s WHERE s.id = v_src_dep) = 'Essai — Biblio compagne'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t); END IF;
    -- un brouillon sans biblio se voit : on en remet un a nul
    UPDATE public.book_drafts SET owner_library_id = NULL, owner_library = NULL WHERE batch_id = v_lot_own AND status = 'draft';
    IF (SELECT o.library_id IS NULL AND o.library_name IS NULL AND o.drafts = 1
          FROM public.fn_batch_owner_libraries() o WHERE o.batch_id = v_lot_own)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : sans biblio non montre'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 : droits ─────────────────────────────────────────────────────────
  v_t := 'T10 aucune fonction du paquet ouverte a anon ; celles de l''ecran executables par authenticated ; une seule signature d''enregistrement';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_import_register_deposit_source';
    IF NOT has_function_privilege('anon', 'public.fn_batch_reassign_library(bigint, uuid)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.fn_batch_owner_libraries()', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.fn_import_register_deposit_source(text, text, uuid)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.fn_import_list_sources()', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_batch_reassign_library(bigint, uuid)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_batch_owner_libraries()', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_import_register_deposit_source(text, text, uuid)', 'EXECUTE')
       AND v_n = 1
       AND to_regclass('ingest.partner_catalog_sources_destination_library_idx') IS NOT NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : signatures='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Bilan (RAISE = tout est annule) ─────────────────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'LOT-IMPORTE-BIBLIO-DESTINATION OK : %/%', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'LOT-IMPORTE-BIBLIO-DESTINATION ECHEC : %/% — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
