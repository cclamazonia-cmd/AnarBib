-- =====================================================================
-- AnarBib — Tests d'acceptation : un lot ne d'un import ne se publie
-- qu'apres une revision approuvee par l'administration, sur rapport
-- Date    : 2026-09-05  ·  Session : importations / qui fait entrer quoi
-- Ref     : migration 20260905093000_revision_des_lots_importes
--
-- Pourquoi cette suite existe : la publication est le geste qui fait le
-- catalogue. La doctrine du 04/09 gardait l'ENTREE des fonds tiers dans la
-- file ; ce paquet garde leur SORTIE vers le catalogue, pour tout lot ne
-- d'un import, sur un rapport lisible par la coordination avant la demande.
--
-- T3 est un test de NON-ACTION (le refus ne publie rien). T4 tient l'autre
-- bord : un lot catalogue A LA MAIN n'est pas concerne. T5 et T8 verifient
-- que la cloche sonne chez la bonne personne, et elle seule. T9 ferme le
-- circuit : apres approbation, la garde s'ouvre. Les refus sont confrontes
-- au HINT reel (PG_EXCEPTION_HINT).
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'REVISION-LOTS-IMPORTES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans role (seed) -> admin reseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_src   bigint; v_run bigint; v_row bigint;
  v_lot_imp bigint; v_lot_main bigint;
  v_draft_imp bigint; v_draft_main bigint;
  v_res jsonb; v_rep jsonb; v_hint text; v_n int; v_id bigint; v_status text;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  -- ── Jeu d'essai : un lot ne d'un import (lien run -> brouillon), un lot a la main ──
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai revision', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, run_status)
  VALUES (v_src, v_lib, 'essai/rev.csv', 'rev.csv', 'drafts_created') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
  VALUES (v_run, 1, 'rev-1', 'A CONQUISTA DO PAO', 'new_record', 'accept_new') RETURNING id INTO v_row;

  INSERT INTO public.catalog_batches (name, status) VALUES ('Essai — lot importe', 'open') RETURNING id INTO v_lot_imp;
  INSERT INTO public.catalog_batches (name, status) VALUES ('Essai — lot a la main', 'open') RETURNING id INTO v_lot_main;

  INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, bib_ref, ano)
  VALUES ('A CONQUISTA DO PAO', v_lot_imp, 'draft', 'livro', 'ESSAI-REV-1', '1892') RETURNING id INTO v_draft_imp;
  INSERT INTO public.book_draft_contributors (draft_id, name, role, is_primary)
  VALUES (v_draft_imp, 'PIOTR KROPOTKINE', 'autor', true);
  INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id)
  VALUES (v_row, v_run, v_draft_imp, v_lot_imp);

  INSERT INTO public.book_drafts (titulo, batch_id, status, tipo_material, bib_ref, ano)
  VALUES ('Germinal', v_lot_main, 'draft', 'livro', 'ESSAI-REV-2', '1885') RETURNING id INTO v_draft_main;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 fn_batch_is_imported distingue le lot ne d''un import du lot a la main';
  BEGIN
    IF public.fn_batch_is_imported(v_lot_imp) AND NOT public.fn_batch_is_imported(v_lot_main) THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : imp='||public.fn_batch_is_imported(v_lot_imp)||' main='||public.fn_batch_is_imported(v_lot_main)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la coordination lit le rapport AVANT toute demande : majuscules, forme directe, autorite non liee';
  BEGIN
    v_rep := public.fn_batch_review_report(v_lot_imp);
    IF (v_rep->'batch'->>'imported')::boolean
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(v_rep->'conventions') c WHERE c->>'rule' = 'titulo_caps' AND (c->>'count')::int = 1)
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(v_rep->'conventions') c WHERE c->>'rule' = 'contrib_caps' AND (c->>'count')::int = 1)
       AND EXISTS (SELECT 1 FROM jsonb_array_elements(v_rep->'conventions') c WHERE c->>'rule' = 'contrib_direct_form')
       AND (v_rep->'authorities'->>'unlinked_count')::int = 1
       AND (v_rep->'duplicates'->'import_matching'->>'new_record')::int = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_rep::text, 400)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 publier un brouillon du lot importe est refuse sans revision, et rien n''est publie';
  BEGIN
    BEGIN
      PERFORM public.publish_book_draft(v_draft_imp);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint <> 'error.publish.review_required' THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')||' / '||SQLERRM);
      ELSIF EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'ESSAI-REV-1') THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : une notice a ete publiee malgre le refus');
      ELSE v_passed := v_passed+1; END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 un lot catalogue a la main n''est pas soumis a la garde de revision';
  BEGIN
    BEGIN
      PERFORM public.publish_book_draft(v_draft_main);
      v_passed := v_passed+1;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.publish.review_required' THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : garde appliquee a un lot a la main');
      ELSE v_passed := v_passed+1; END IF;   -- un autre refus (destination, tombo…) n'est pas le sujet
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 la coordination demande la revision : tour 1, rapport fige, les admins reseau sont prevenus';
  BEGIN
    v_res := public.fn_batch_review_request(v_lot_imp, 'Lot pret, merci de relire les auteurs');
    v_id := (v_res->>'review_id')::bigint;
    SELECT count(*) INTO v_n FROM public.user_notifications
     WHERE user_id = v_admin AND link_type = 'batch_review_verdict' AND link_id = v_lot_imp::text
       AND title = 'notif.review.requested.title';
    IF (v_res->>'round')::int = 1
       AND (SELECT status FROM public.catalog_batch_reviews WHERE id = v_id) = 'requested'
       AND (SELECT report IS NOT NULL AND coord_message IS NOT NULL FROM public.catalog_batch_reviews WHERE id = v_id)
       AND v_n = 1
       AND NOT EXISTS (SELECT 1 FROM public.user_notifications WHERE user_id = v_coord AND link_type = 'batch_review_verdict')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res::text,'NULL')||' notifs_admin='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 une seconde demande pendant le tour ouvert est refusee';
  BEGIN
    PERFORM public.fn_batch_review_request(v_lot_imp);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.review.already_requested' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 la coordination ne tranche pas sa propre revision';
  BEGIN
    PERFORM public.fn_batch_review_verdict(v_id, 'approved', 'moi-meme');
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.review.admin_only' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 l''admin demande des retouches : notes obligatoires, la coordination est prevenue';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_batch_review_verdict(v_id, 'changes_requested', '   ');
      RAISE EXCEPTION 'retouches sans note acceptees';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint <> 'error.review.notes_required' THEN RAISE EXCEPTION 'hint = %', coalesce(v_hint, 'NULL'); END IF;
    END;
    v_res := public.fn_batch_review_verdict(v_id, 'changes_requested', 'Inverser les auteurs, casse naturelle');
    SELECT count(*) INTO v_n FROM public.user_notifications
     WHERE user_id = v_coord AND link_type = 'batch_review_result' AND link_id = v_lot_imp::text
       AND title = 'notif.review.changes.title';
    IF (SELECT status FROM public.catalog_batch_reviews WHERE id = v_id) = 'changes_requested'
       AND (SELECT reviewed_by = v_admin AND admin_notes IS NOT NULL FROM public.catalog_batch_reviews WHERE id = v_id)
       AND v_n = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : notifs_coord='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 nouveau tour, approbation, et la garde de publication s''ouvre';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    UPDATE public.book_draft_contributors SET name = 'Kropotkine, Piotr' WHERE draft_id = v_draft_imp;
    v_res := public.fn_batch_review_request(v_lot_imp);
    IF (v_res->>'round')::int <> 2 THEN RAISE EXCEPTION 'round = %', v_res->>'round'; END IF;
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF public.fn_batch_review_status(v_lot_imp) <> 'approved' THEN RAISE EXCEPTION 'statut = %', public.fn_batch_review_status(v_lot_imp); END IF;
    BEGIN
      PERFORM public.publish_book_draft(v_draft_imp);
      v_passed := v_passed+1;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.publish.review_required' THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : garde encore fermee apres approbation');
      ELSE v_passed := v_passed+1; END IF;   -- un refus d'une autre nature n'est pas le sujet
    END;
    -- la demande suivante est refusee : deja approuve
    BEGIN
      PERFORM public.fn_batch_review_request(v_lot_imp);
      RAISE EXCEPTION 'redemande acceptee apres approbation';
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint <> 'error.review.already_approved' THEN RAISE EXCEPTION 'hint = %', coalesce(v_hint, 'NULL'); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 un lot a la main ne se demande pas en revision';
  BEGIN
    PERFORM public.fn_batch_review_request(v_lot_main);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.review.not_imported' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 la liste rend le dernier tour de chaque lot, avec le nom de qui a demande';
  BEGIN
    SELECT l.status INTO v_status FROM public.fn_batch_reviews_list() l WHERE l.batch_id = v_lot_imp;
    SELECT count(*) INTO v_n FROM public.fn_batch_reviews_list() l WHERE l.batch_id = v_lot_imp AND l.round = 2 AND l.imported;
    IF v_status = 'approved' AND v_n = 1
       AND EXISTS (SELECT 1 FROM public.fn_batch_reviews_list() l WHERE l.batch_id = v_lot_main AND l.review_id IS NULL AND NOT l.imported)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : status='||coalesce(v_status,'NULL')||' n='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T12 rien n''est ouvert a anon ni a PUBLIC (fonctions, table), les RPC restent executables';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public'
       AND routine_name IN ('fn_batch_is_imported', 'fn_batch_review_status', 'fn_batch_review_report',
                            'fn_batch_review_request', 'fn_batch_review_verdict', 'fn_batch_reviews_list',
                            'fn_catalog_batch_reviews_notify')
       AND grantee IN ('anon', 'PUBLIC');
    IF v_n <> 0 THEN RAISE EXCEPTION '% droit(s) anon/PUBLIC sur les fonctions', v_n; END IF;
    SELECT count(*) INTO v_n FROM information_schema.table_privileges
     WHERE table_schema = 'public' AND table_name = 'catalog_batch_reviews' AND grantee IN ('anon', 'PUBLIC');
    IF v_n <> 0 THEN RAISE EXCEPTION 'table ouverte a anon/PUBLIC'; END IF;
    SELECT count(DISTINCT routine_name) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public'
       AND routine_name IN ('fn_batch_review_report', 'fn_batch_review_request', 'fn_batch_review_verdict', 'fn_batch_reviews_list')
       AND grantee = 'authenticated' AND privilege_type = 'EXECUTE';
    IF v_n = 4 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/4 RPC executables'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'REVISION-LOTS-IMPORTES OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'REVISION-LOTS-IMPORTES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
