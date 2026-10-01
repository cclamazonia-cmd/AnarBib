-- =====================================================================
-- AnarBib — Tests d'acceptation : une notice importée DÉJÀ publiée se
-- republie hors lot (H21 lot 0, sixième passe ; REGISTRE IMP-27 a et b)
-- Date    : 2026-10-01
-- Ref     : migration 20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe
--           (bloc $h21_publier_notice$ : la garde « sans lot » épargne un
--           brouillon au statut « publié », que seule la publication pose —
--           déclencheur book_drafts_statut_publie_reserve)
--
-- Décor : une ligne promue par la coordination de BLMF (fn_import_promote),
-- lot demandé en révision, approuvé par l'administration du réseau, notice
-- publiée par publish_book_draft sous authenticated. Chaque geste ensuite
-- est joué dans une sous-transaction annulée, par l'API (SET LOCAL ROLE
-- authenticated), tel que BookDraftForm l'écrit.
--
-- RH1 témoin : retouche dans son lot, republiée — même notice au catalogue.
-- RH2 « Sans lot » puis Publier : republiée, même notice, titre retouché.
-- RH3 autre bibliothèque propriétaire (le lot de BLMF n'est pas de la cible,
--     l'écran vide batch_id — B30), par une coordination des deux
--     bibliothèques : republiée.
-- RH4 la porte tient pour une PREMIÈRE publication : un brouillon importé
--     jamais publié, sorti de son lot par l'API, est refusé
--     (error.publish.imported_needs_batch) ; et la publication remise en
--     « draft » par l'API puis sortie du lot l'est aussi.
-- RH5 le statut « publié » ne se pose pas par l'API
--     (error.publish.status_reserved) : l'exemption ne s'achète pas.
-- RH6 « publié » mais notice retirée du catalogue (published_book_id vide) :
--     la republication hors lot en créerait une neuve — refusée.
--
-- Contre-épreuve (01/10/2026) : publish_book_draft de la cinquième passe
-- (sans exemption) → RH2 et RH3 tombent (error.publish.imported_needs_batch,
-- constat du sceptique P6/S2, sonde p2.sql) ; exemption sur le seul statut
-- (sans « published_book_id is not null », constat du sceptique suivant) →
-- RH6 tombe ; garde « sans lot » retirée → RH4 et RH6 tombent.
-- =====================================================================
DO $$
DECLARE
  v_coord uuid := '11111111-1111-1111-1111-111111111111';
  v_admin uuid := '22222222-2222-2222-2222-222222222222';
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_lib3 uuid; v_multi uuid; v_src bigint; v_run bigint; v_res jsonb; v_lot bigint;
  v_d bigint; v_d2 bigint; v_book bigint; v_book_apres bigint;
  v_t text; v_h text; v_titre text; v_owner uuid; v_st text;
  v_passed int := 0; v_failed int := 0; v_failures text[] := '{}';
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level, tombo_pattern)
  VALUES (gen_random_uuid(), 'h21-rh-cible', 'H21 RH cible', true, 'private', '{"prefix": "H21RHC-", "year": false, "pad": 4}'::jsonb)
  RETURNING id INTO v_lib3;
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'h21-rh-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id INTO v_multi;
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_multi, 'H21', 'RH') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_multi, v_lib, 'coordenador', 'active', true), (v_multi, v_lib3, 'coordenador', 'active', false);
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H21 RH', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'h21/rh.marc', 'rh.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 1, 'h21rh-1', 'H21 RH notice publiee', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run, 2, 'h21rh-2', 'H21 RH notice jamais publiee', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb));
  v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
  v_lot := (v_res->>'batch_id')::bigint;
  SELECT m.draft_id INTO v_d FROM ingest.partner_catalog_row_to_draft m
    JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 1;
  SELECT m.draft_id INTO v_d2 FROM ingest.partner_catalog_row_to_draft m
    JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 2;
  UPDATE public.book_drafts SET bib_ref = 'H21RH-REF-' || id WHERE id IN (v_d, v_d2);
  v_res := public.fn_batch_review_request(v_lot);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.publish_book_draft(v_d);
  EXECUTE 'RESET ROLE';
  SELECT published_book_id INTO v_book FROM public.book_drafts WHERE id = v_d;
  IF v_book IS NULL OR (SELECT status FROM public.book_drafts WHERE id = v_d) <> 'published'
     OR (SELECT status FROM public.book_drafts WHERE id = v_d2) = 'published' THEN
    RAISE EXCEPTION 'H21-REPUBLIER-HORS-LOT ECHEC : décor (notice non publiée)';
  END IF;

  -- RH1 témoin : retouche dans son lot
  v_t := 'RH1 retouche dans son lot republiee, meme notice';
  BEGIN
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET titulo = 'H21 RH retouche 1' WHERE id = v_d;
      PERFORM public.publish_book_draft(v_d);
      EXECUTE 'RESET ROLE';
      SELECT published_book_id INTO v_book_apres FROM public.book_drafts WHERE id = v_d;
      SELECT titulo INTO v_titre FROM public.books WHERE id = v_book;
      v_h := 'ok';
      RAISE EXCEPTION 'annuler';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'annuler' THEN GET STACKED DIAGNOSTICS v_h = PG_EXCEPTION_HINT; v_h := coalesce(nullif(v_h, ''), SQLERRM); END IF;
    END;
    IF v_h = 'ok' AND v_book_apres = v_book AND v_titre = 'H21 RH retouche 1' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h, 'NULL')||' titre='||coalesce(v_titre, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- RH2 « Sans lot » puis Publier
  v_t := 'RH2 Sans lot puis Publier : republiee hors lot, meme notice';
  v_h := NULL; v_titre := NULL; v_book_apres := NULL;
  BEGIN
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET titulo = 'H21 RH retouche 2', batch_id = NULL WHERE id = v_d;
      PERFORM public.publish_book_draft(v_d);
      EXECUTE 'RESET ROLE';
      SELECT published_book_id INTO v_book_apres FROM public.book_drafts WHERE id = v_d;
      SELECT titulo INTO v_titre FROM public.books WHERE id = v_book;
      v_h := 'ok';
      RAISE EXCEPTION 'annuler';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'annuler' THEN GET STACKED DIAGNOSTICS v_h = PG_EXCEPTION_HINT; v_h := coalesce(nullif(v_h, ''), SQLERRM); END IF;
    END;
    IF v_h = 'ok' AND v_book_apres = v_book AND v_titre = 'H21 RH retouche 2' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h, 'NULL')||' titre='||coalesce(v_titre, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- RH3 autre bibliothèque propriétaire (sort du lot)
  v_t := 'RH3 autre bibliotheque proprietaire : republiee hors lot';
  v_h := NULL; v_owner := NULL; v_book_apres := NULL;
  BEGIN
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_multi, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET owner_library_id = v_lib3, holder_library_id = v_lib3, batch_id = NULL WHERE id = v_d;
      PERFORM public.publish_book_draft(v_d);
      EXECUTE 'RESET ROLE';
      SELECT published_book_id, owner_library_id INTO v_book_apres, v_owner FROM public.book_drafts WHERE id = v_d;
      v_h := 'ok';
      RAISE EXCEPTION 'annuler';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'annuler' THEN GET STACKED DIAGNOSTICS v_h = PG_EXCEPTION_HINT; v_h := coalesce(nullif(v_h, ''), SQLERRM); END IF;
    END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_h = 'ok' AND v_book_apres = v_book AND v_owner = v_lib3 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- RH4 la porte tient pour une première publication
  v_t := 'RH4 premiere publication hors lot refusee (jamais publiee ; publiee remise en draft)';
  DECLARE v_h1 text; v_h2 text;
  BEGIN
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_d2;
      PERFORM public.publish_book_draft(v_d2);
      v_h1 := 'accepte';
      EXECUTE 'RESET ROLE';
      RAISE EXCEPTION 'annuler';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'annuler' THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END IF;
    END;
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d;
      UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_d;
      PERFORM public.publish_book_draft(v_d);
      v_h2 := 'accepte';
      EXECUTE 'RESET ROLE';
      RAISE EXCEPTION 'annuler';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'annuler' THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END IF;
    END;
    IF v_h1 = 'error.publish.imported_needs_batch' AND v_h2 = 'error.publish.imported_needs_batch'
       AND (SELECT status FROM public.book_drafts WHERE id = v_d2) <> 'published' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : jamais publiee='||coalesce(v_h1, 'NULL')||' remise en draft='||coalesce(v_h2, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- RH5 l'exemption ne s'achète pas : « publié » refusé à l'API
  v_t := 'RH5 statut published pose par l API refuse';
  v_h := NULL;
  BEGIN
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET status = 'published', batch_id = NULL WHERE id = v_d2;
      v_h := 'accepte';
      EXECUTE 'RESET ROLE';
      RAISE EXCEPTION 'annuler';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'annuler' THEN GET STACKED DIAGNOSTICS v_h = PG_EXCEPTION_HINT; v_h := coalesce(nullif(v_h, ''), SQLERRM); END IF;
    END;
    SELECT status INTO v_st FROM public.book_drafts WHERE id = v_d2;
    IF v_h = 'error.publish.status_reserved' AND v_st <> 'published' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h, 'NULL')||' statut='||coalesce(v_st, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- RH6 « publié » sans notice au catalogue (notice retirée : published_book_id
  -- vidé ; ici par l'API, que le déclencheur de trace laisse faire) : la
  -- republication hors lot créerait une notice NEUVE — refusée.
  v_t := 'RH6 publie sans notice au catalogue, hors lot : refuse';
  v_h := NULL;
  BEGIN
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET published_book_id = NULL, batch_id = NULL,
                                    bib_ref = 'H21RH-REF-NEUF-' || id WHERE id = v_d;
      PERFORM public.publish_book_draft(v_d);
      v_h := 'accepte';
      EXECUTE 'RESET ROLE';
      RAISE EXCEPTION 'annuler';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'annuler' THEN GET STACKED DIAGNOSTICS v_h = PG_EXCEPTION_HINT; v_h := coalesce(nullif(v_h, ''), SQLERRM); END IF;
    END;
    IF v_h = 'error.publish.imported_needs_batch' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H21-REPUBLIER-HORS-LOT OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'H21-REPUBLIER-HORS-LOT ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
