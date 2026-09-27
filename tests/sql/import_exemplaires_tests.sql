-- =====================================================================
-- AnarBib — Tests d'acceptation : les exemplaires d'un catalogue importe
-- deviennent des exemplaires (H19, REGISTRE IMP-21)
-- Date    : 2026-09-26  ·  Session : aller-retour PMB (G15, H14)
-- Ref     : migration 20260927113000_h19_exemplaires_importes
--
-- Le parcours entier, avec les formes que l'EF ecrit (normalized_payload.items) :
-- T1  promotion : un brouillon d'exemplaire par exemplaire, rattache a SA
--     notice, sans tombo, avec code d'origine, cote, note, proprietaire ;
--     type/public/statut dans la provenance.
-- T2  rapport de revision : `items` compte, aucun probleme.
-- T3  un exemplaire importe ne se publie pas avant sa notice (HINT reel).
-- T4  publication du lot (revision approuvee) : EXACTEMENT les exemplaires du
--     fichier (pas d'exemplaire automatique en plus), tombos du schema de la
--     bibliotheque, codes d'origine gardes ; une notice sans exemplaire garde
--     son exemplaire automatique ; les exemplaires d'une notice ecartee ne
--     font pas echouer le lot.
-- T5  code d'origine deja pris dans la bibliotheque : dit au rapport, refuse a
--     la publication (HINT reel).
-- T6  lot sans bibliotheque (depot compagnon sans destination) : dit au
--     rapport ; la notice qui porte des exemplaires ne se publie pas (HINT).
-- T7  reattribution du lot : les exemplaires suivent.
-- T8  rapprochement vers une notice existante : un brouillon par exemplaire ;
--     annuler l'un ne defait pas la decision tant qu'un autre vit.
-- T9  profil : correspondance des exemplaires posee, relue ; cle inconnue refusee.
-- T10 unicite du code d'origine PAR bibliotheque (pas globale).
-- T11 droits : anon n'execute ni la creation de profil ni la publication ;
--     authenticated n'execute pas la fonction ingest.
-- Revue contradictoire du 26-27/09 : un test par defaut corrige.
-- T12 republier un exemplaire importe deja publie garde son tombo (aucun
--     numero brule) ; le tombo pose revient au brouillon.
-- T13 publier un exemplaire exige d'etre staff de la bibliotheque visee (et de
--     celle qui detient l'exemplaire) : un tombo fourni ne contourne plus rien.
-- T14 book_draft_id / import_staging_row_id ne s'ecrivent pas par l'API.
-- T15 l'exemplaire suit sa notice : corbeille, restauration, changement de lot.
-- T16 rapport : doublons en un passage, 40 problemes au plus, bibliotheque
--     differente de la notice, code attendu par un autre lot, « code pris »
--     tu a qui n'est pas staff de la bibliotheque.
-- T17 rapprochement d'un depot compagnon : administration du reseau seule,
--     exemplaires verses a la destination de la source.
-- T18 rapprochement : code deja dans la bibliotheque non recree ; ligne
--     rapprochee non promue, ligne promue non rapprochee.
-- T19 declencheur : repointage limite au meme rapprochement.
-- T20 le code d'origine n'entre dans aucune note de provenance (IMP-21 b).
-- Seconde revue du 27/09 :
-- T21 fusion de doublons : exemplaires du perdant au survivant ; d'un brouillon absorbe, sur la fiche.
-- T22 journal : une notice supprimee revient avec ses exemplaires importes.
-- T23 un run rapproche ne se retraite plus.
-- T24 par l'API, l'exemplaire importe suit sa notice (restaure seul, deplace seul, published_exemplar_id).
-- T25 reattribution : code deja dans la destination = refus dit.
-- T26 rapport : « sans numerotation » seulement sans tombo.
-- T27 repli sans bibliotheque cible : adhesion de staff.
-- Troisieme passe du 27/09 :
-- T28 exemplaire ecarte seul, restaure apres la publication de sa notice : publie sur la fiche.
-- T29 journal : pas d'entree a part pour un exemplaire supprime avec sa notice ; rejeu isole refuse proprement.
-- T30 profil supprime depuis l'import : refuse des l'envoi.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-EXEMPLAIRES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans role (seed) -> admin reseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_lib2  uuid;
  v_src bigint; v_src_dep bigint; v_run bigint; v_run2 bigint; v_run3 bigint; v_run4 bigint;
  v_lot bigint; v_lot2 bigint; v_lot3 bigint; v_lot4 bigint;
  v_res jsonb; v_rep jsonb; v_hint text; v_n int; v_id bigint; v_txt text;
  v_d_trois bigint; v_d_un bigint; v_d_zero bigint; v_d_ecarte bigint; v_d_dep bigint;
  v_book_trois bigint; v_book_zero bigint; v_row bigint; v_x1 bigint; v_x2 bigint;
  v_other uuid; v_run5 bigint; v_run6 bigint; v_run7 bigint; v_run8 bigint;
  v_lot5 bigint; v_lot6 bigint; v_lot7 bigint; v_d5 bigint; v_d_mis bigint;
  v_r1 bigint; v_r2 bigint; v_txt2 text; v_ok boolean;
  v_items3 jsonb := '[{"source_item_code":"CDF0000000010","call_number":"027.6 GAR","note":null,"owner":"BDP","item_type":"uu","public":"u","status":null},
                      {"source_item_code":"CDF0000000011","call_number":"027.6 GAR","note":"Exemplaire de consultation","owner":"BDP","item_type":"uu","public":"u","status":null},
                      {"source_item_code":"CDF0000000012","call_number":"ARCH GAR 1","note":"Exemplaire dédicacé","owner":"Fonds propre","item_type":"uu","public":"u","status":null}]'::jsonb;
  v_items1 jsonb := '[{"source_item_code":"CDF0000000001","call_number":"ZINE BRU","note":"Photocopie agrafée, fragile","owner":"BDP","item_type":"uu","public":"u","status":null}]'::jsonb;
  v_items_e jsonb := '[{"source_item_code":"CDF0000000099","call_number":"X","note":null,"owner":"BDP","item_type":null,"public":null,"status":null}]'::jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  -- Un schema de numerotation pour la biblio de test (IMP-21 a : le tombo en vient).
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "ESSAI-H19-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai exemplaires', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/pmb.marc', 'pmb.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 1, '71', 'Petite histoire des bibliothèques ouvrières', 'new_record', 'accept_new', jsonb_build_object('items', v_items3)),
         (v_run, 2, '61', 'Brûler les frontières', 'new_record', 'accept_new', jsonb_build_object('items', v_items1)),
         (v_run, 3, '99', 'Sans exemplaire', 'new_record', 'accept_new', jsonb_build_object('items', '[]'::jsonb)),
         (v_run, 4, '98', 'Notice écartée', 'new_record', 'accept_new', jsonb_build_object('items', v_items_e));

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 promotion : un brouillon d''exemplaire par exemplaire, rattache a sa notice, sans tombo';
  BEGIN
    v_res := public.fn_import_promote(v_run, ARRAY['new_record'], ARRAY['accept_new']);
    v_lot := (v_res->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d_trois FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 1;
    SELECT m.draft_id INTO v_d_un    FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 2;
    SELECT m.draft_id INTO v_d_zero  FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 3;
    SELECT m.draft_id INTO v_d_ecarte FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run AND s.row_no = 4;
    IF (v_res->>'items_created')::int = 5
       AND (SELECT count(*) FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_trois) = 3
       AND (SELECT count(*) FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_zero) = 0
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.batch_id = v_lot AND (x.tombo IS NOT NULL OR x.target_library_id IS DISTINCT FROM v_lib OR x.import_staging_row_id IS NULL))
       AND EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_trois AND x.source_item_code = 'CDF0000000012'
                    AND x.shelf_location = 'ARCH GAR 1' AND x.notes = 'Exemplaire dédicacé' AND x.source_library = 'Fonds propre'
                    AND x.provenance_note LIKE '%Tipo: uu.%Publico: u.%'
                    AND x.provenance_note NOT LIKE '%CDF0000000012%')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : res='||left(coalesce(v_res::text,'NULL'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- Les bib_ref, comme fn_batch_assign_bib_refs les poserait.
  UPDATE public.book_drafts SET bib_ref = 'ESSAI-H19-REF-' || id WHERE batch_id = v_lot;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 rapport de revision : items compte les 5 exemplaires, aucun probleme';
  BEGIN
    v_rep := public.fn_batch_review_report(v_lot);
    IF (v_rep->'items'->>'count')::int = 5 AND (v_rep->'items'->>'with_code')::int = 5
       AND v_rep->'items'->'problems' = '[]'::jsonb
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_rep->'items','null'::jsonb)::text, 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 un exemplaire importe ne se publie pas avant sa notice';
  BEGIN
    SELECT min(x.id) INTO v_id FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_un;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_id);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.publish.item_before_record'
         AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.source_item_code = 'CDF0000000001')
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')||' / '||SQLERRM); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 publication du lot : exactement les exemplaires du fichier, tombos du schema, codes gardes';
  BEGIN
    -- La notice 4 est ecartee (corbeille) : ses exemplaires ne doivent rien casser.
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d_ecarte;
    v_res := public.fn_batch_review_request(v_lot);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.publish_catalog_batch(v_lot);
    SELECT published_book_id INTO v_book_trois FROM public.book_drafts WHERE id = v_d_trois;
    SELECT published_book_id INTO v_book_zero FROM public.book_drafts WHERE id = v_d_zero;
    SELECT string_agg(e.tombo || '=' || e.source_item_code, ',' ORDER BY e.source_item_code) INTO v_txt
      FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_book_trois;
    IF (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_book_trois) = 3
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_book_trois
             AND e.tombo ~ '^ESSAI-H19-[0-9]{4}$' AND e.library_id = v_lib AND e.source_item_code LIKE 'CDF00000000%') = 3
       AND (SELECT e.shelf_location FROM public.exemplares e WHERE e.source_item_code = 'CDF0000000012' AND e.library_id = v_lib) = 'ARCH GAR 1'
       AND (SELECT count(*) FROM public.exemplares e WHERE e.source_item_code = 'CDF0000000001' AND e.library_id = v_lib) = 1
       -- La notice sans exemplaire importe garde son exemplaire automatique.
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_book_zero) = 1
       -- Tous les brouillons d'exemplaires des notices publiees sont publies ;
       -- ceux de la notice ecartee l'ont suivie a la corbeille (T15).
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id IN (v_d_trois, v_d_un) AND x.status <> 'published')
       AND (SELECT count(*) FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_ecarte AND x.status = 'cancelled') = 1
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lot) = 'published'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')||' res='||left(coalesce(v_res::text,'NULL'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 code d''origine deja pris dans la bibliotheque : dit au rapport, refuse a la publication';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/pmb2.marc', 'pmb2.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run2;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run2, 1, '61b', 'Brûler les frontières (réimport)', 'new_record', 'accept_new', jsonb_build_object('items', v_items1));
    v_lot2 := (public.fn_import_promote(v_run2, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    UPDATE public.book_drafts SET bib_ref = 'ESSAI-H19-REF-' || id WHERE batch_id = v_lot2;
    v_rep := public.fn_batch_review_report(v_lot2);
    v_res := public.fn_batch_review_request(v_lot2);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.publish_catalog_batch(v_lot2);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.publish.source_item_code_taken'
         AND (v_rep->'items'->>'code_taken')::int = 1
         AND v_rep->'items'->'problems' @> '[{"reason": "code_taken", "source_item_code": "CDF0000000001"}]'::jsonb
         AND (SELECT count(*) FROM public.exemplares e WHERE e.source_item_code = 'CDF0000000001') = 1
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')||' / '||SQLERRM||' / '||left(coalesce(v_rep->'items','null'::jsonb)::text, 200)); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 lot sans bibliotheque : dit au rapport, la notice a exemplaires ne se publie pas';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    -- L'admin reseau est aussi membre coordenador de la biblio de test (publication = staff).
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
    VALUES (v_admin, v_lib, 'coordenador', 'active', true) ON CONFLICT DO NOTHING;
    v_res := public.fn_import_register_deposit_source('Essai compagne sans destination H19', NULL, NULL);
    v_src_dep := (v_res->>'source_id')::bigint;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src_dep, v_lib, 'essai/dep.marc', 'dep.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run3;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run3, 1, 'dep-1', 'Fonds de compagne', 'new_record', 'accept_new', jsonb_build_object('items', v_items_e));
    v_lot3 := (public.fn_import_promote(v_run3, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    UPDATE public.book_drafts SET bib_ref = 'ESSAI-H19-DEP-' || id WHERE batch_id = v_lot3 RETURNING id INTO v_d_dep;
    v_rep := public.fn_batch_review_report(v_lot3);
    v_res := public.fn_batch_review_request(v_lot3);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', 'essai');
    BEGIN
      PERFORM public.publish_book_draft(v_d_dep);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      -- Le repli de publish_book_draft aurait choisi la biblio principale de
      -- l'admin (v_lib) : la garde porte sur la biblio DONNÉE aux exemplaires.
      IF v_hint = 'error.publish.items_without_library'
         AND (v_rep->'items'->>'without_library')::int = 1
         AND (SELECT status FROM public.book_drafts WHERE id = v_d_dep) = 'draft'
         AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.source_item_code = 'CDF0000000099')
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')||' / '||SQLERRM||' / '||left(coalesce(v_rep->'items','null'::jsonb)::text, 200)); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T7 ──────────────────────────────────────────────────────────────
  v_t := 'T7 reattribution du lot : les exemplaires suivent';
  BEGIN
    -- (identite : admin reseau, depuis T6) Une revision approuvee bloque la
    -- reattribution : on demande un nouveau tour d'abord.
    UPDATE public.catalog_batch_reviews SET status = 'changes_requested', admin_notes = 'essai H19' WHERE batch_id = v_lot3;
    INSERT INTO public.libraries (id, slug, name, is_active, visibility_level, tombo_pattern)
    VALUES (gen_random_uuid(), 'essai-h19-destination', 'Essai — destination H19', true, 'private', '{"prefix": "ESSAI-H19-D-", "pad": 3}'::jsonb)
    RETURNING id INTO v_lib2;
    v_res := public.fn_batch_reassign_library(v_lot3, v_lib2);
    IF (v_res->>'items_updated')::int = 1
       AND (SELECT x.target_library_id FROM public.exemplar_drafts x WHERE x.batch_id = v_lot3) = v_lib2
       AND (public.fn_batch_review_report(v_lot3)->'items'->>'without_library')::int = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_res::text,'NULL'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T8 ──────────────────────────────────────────────────────────────
  v_t := 'T8 rapprochement : un brouillon par exemplaire ; annuler l''un ne defait pas la decision';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/rappr.marc', 'rappr.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run4;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run4, 1, '71r', 'Petite histoire (doublon)', 'matched_book', 'accept_duplicate', v_book_trois,
            jsonb_build_object('items', '[{"source_item_code":"RAP-1","call_number":"A"},{"source_item_code":"RAP-2","call_number":"B"}]'::jsonb))
    RETURNING id INTO v_row;
    v_res := ingest.fn_create_exemplar_drafts_from_import_rows(v_run4, ARRAY[v_row]);
    SELECT min(id), max(id) INTO v_x1, v_x2 FROM public.exemplar_drafts WHERE import_staging_row_id = v_row;
    IF (v_res->>'created_items')::int <> 2 OR v_x1 = v_x2
       OR (SELECT created_exemplar_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_row) <> v_x1 THEN
      RAISE EXCEPTION 'creation : % / % %', v_res, v_x1, v_x2;
    END IF;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x1;
    IF (SELECT created_exemplar_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_row) IS DISTINCT FROM v_x2
       OR (SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = v_row) <> 'accept_duplicate' THEN
      RAISE EXCEPTION 'annuler le premier a defait la decision';
    END IF;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x2;
    IF (SELECT created_exemplar_draft_id IS NULL AND editorial_decision = 'pending' FROM ingest.partner_catalog_staging_rows WHERE id = v_row)
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE import_staging_row_id = v_row AND source_item_code IN ('RAP-1', 'RAP-2')) = 2
       -- B30 : le lot d'un rapprochement du catalogue propre est à la bibliothèque du run.
       AND (SELECT b.library_id FROM public.catalog_batches b JOIN public.exemplar_drafts x ON x.batch_id = b.id WHERE x.id = v_x2) = v_lib
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : le dernier annule n''a pas remis la ligne en attente'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T9 ──────────────────────────────────────────────────────────────
  v_t := 'T9 profil : correspondance des exemplaires posee et relue ; cle inconnue refusee (HINT)';
  BEGIN
    v_res := public.fn_import_profile_create(v_lib, 'PMB DIRA (essai)', '{}'::jsonb, '{}'::jsonb, '{"code": "b", "call_number": "kd", "owner": ""}'::jsonb);
    IF NOT EXISTS (SELECT 1 FROM public.fn_import_profiles_list(v_lib) p
                    WHERE p.id = (v_res->>'id')::bigint AND p.items_mapping = '{"code": "b", "call_number": "kd", "owner": ""}'::jsonb) THEN
      RAISE EXCEPTION 'profil non relu : %', v_res;
    END IF;
    BEGIN
      PERFORM public.fn_import_profile_create(v_lib, 'Mauvais', '{}'::jsonb, '{}'::jsonb, '{"barcode": "f"}'::jsonb);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cle inconnue acceptee');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.import.items_mapping_invalid' THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')||' / '||SQLERRM); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 le code d''origine est unique PAR bibliotheque, pas sur toute la base';
  BEGIN
    -- Meme code que l'exemplaire publie en T4 dans v_lib, mais dans v_lib2 : admis.
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, source_item_code, circulation_policy) VALUES ('X', 'ESSAI-H19-U1', v_lib2, 'CDF0000000001', 'emprestavel');
    BEGIN
      INSERT INTO public.exemplares (bib_ref, tombo, library_id, source_item_code, circulation_policy) VALUES ('X', 'ESSAI-H19-U2', v_lib2, 'CDF0000000001', 'emprestavel');
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : doublon accepte dans la meme bibliotheque');
    EXCEPTION WHEN unique_violation THEN v_passed := v_passed+1;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  v_t := 'T11 droits : anon n''execute ni profil ni publication ; authenticated n''execute pas la fonction ingest';
  BEGIN
    IF NOT has_function_privilege('anon', 'public.fn_import_profile_create(uuid,text,jsonb,jsonb,jsonb)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_import_profile_create(uuid,text,jsonb,jsonb,jsonb)', 'EXECUTE')
       AND to_regprocedure('public.fn_import_profile_create(uuid,text,jsonb,jsonb)') IS NULL
       AND NOT has_function_privilege('anon', 'public.publish_book_draft(bigint)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.publish_exemplar_draft(bigint)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'ingest.fn_create_item_drafts_for_batch(bigint,uuid)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : droits inattendus'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 republier un exemplaire importe garde son tombo ; le tombo pose revient au brouillon';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF EXISTS (SELECT 1 FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id
                WHERE x.book_draft_id = v_d_trois AND x.tombo IS DISTINCT FROM e.tombo) THEN
      RAISE EXCEPTION 'tombo non reecrit au brouillon a la publication';
    END IF;
    SELECT string_agg(e.tombo, ',' ORDER BY e.id) INTO v_txt
      FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_book_trois;
    v_txt2 := public.fn_next_tombo(v_lib);
    -- La file « tout selectionner → publier » repasse sur les brouillons deja publies.
    FOR v_id IN SELECT x.id FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_trois LOOP
      PERFORM public.publish_exemplar_draft(v_id);
    END LOOP;
    -- Un brouillon au tombo vide (le formulaire, un brouillon d'avant le correctif).
    SELECT min(x.id) INTO v_id FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_trois;
    UPDATE public.exemplar_drafts SET tombo = NULL WHERE id = v_id;
    PERFORM public.publish_exemplar_draft(v_id);
    IF public.fn_next_tombo(v_lib) = v_txt2
       AND (SELECT string_agg(e.tombo, ',' ORDER BY e.id) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = v_book_trois) = v_txt
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id
                        WHERE x.book_draft_id = v_d_trois AND x.tombo IS DISTINCT FROM e.tombo)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avant '||coalesce(v_txt,'NULL')||' / '||coalesce(v_txt2,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 publier exige d''etre staff de la bibliotheque visee, un tombo fourni ne contourne rien';
  BEGIN
    INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
    VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
            'authenticated', 'authenticated', 'h19-' || gen_random_uuid() || '@example.invalid', now(), now())
    RETURNING id INTO v_other;
    INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_other, 'Essai', 'H19') ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
    VALUES (v_other, v_lib2, 'librarian', 'active', true);
    -- (a) creation dans v_lib, tombo fourni, code d'origine « squatte ».
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, tombo, source_item_code)
    VALUES ('create', 'draft', 'pending', v_lib, (SELECT bib_ref FROM public.books WHERE id = v_book_trois), 'ESSAI-H19-INTRUS', 'SQUAT-1')
    RETURNING id INTO v_x1;
    -- (b) deplacement d'un exemplaire de v_lib vers v_lib2 (dont v_other est staff).
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, tombo, published_exemplar_id)
    SELECT 'update', 'draft', 'pending', v_lib2, e.bib_ref, 'ESSAI-H19-INTRUS2', e.id
      FROM public.exemplares e WHERE e.source_item_code = 'CDF0000000010' AND e.library_id = v_lib
    RETURNING id INTO v_x2;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
    v_n := 0;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_x1);
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.publish.other_library' THEN v_n := v_n + 1; END IF;
    END;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_x2);
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.publish.other_library' THEN v_n := v_n + 1; END IF;
    END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_n = 2
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.source_item_code = 'SQUAT-1' OR e.tombo LIKE 'ESSAI-H19-INTRUS%')
       AND (SELECT e.library_id FROM public.exemplares e WHERE e.source_item_code = 'CDF0000000010' AND e.library_id = v_lib) = v_lib
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||v_n); END IF;
    DELETE FROM public.exemplar_drafts WHERE id IN (v_x1, v_x2);
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 ─────────────────────────────────────────────────────────────
  v_t := 'T14 book_draft_id / import_staging_row_id ne s''ecrivent pas par l''API (role authenticated)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    SELECT min(x.id) INTO v_id FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_trois;
    v_n := 0;
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, book_draft_id)
      VALUES ('create', 'draft', 'pending', v_lib, v_d_zero);
      EXECUTE 'RESET ROLE';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM LIKE 'Vinculo de importacao%' THEN v_n := v_n + 1; END IF;
    END;
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.exemplar_drafts SET book_draft_id = v_d_zero WHERE id = v_id;
      EXECUTE 'RESET ROLE';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM LIKE 'Vinculo de importacao%' THEN v_n := v_n + 1; END IF;
    END;
    -- Le reste d'un brouillon importe s'edite normalement (formulaire).
    v_ok := false;
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.exemplar_drafts SET notes = 'note editee (T14)' WHERE id = v_id;
      EXECUTE 'RESET ROLE';
      v_ok := true;
    EXCEPTION WHEN OTHERS THEN v_failures := v_failures||(v_t||' : edition ordinaire refusee : '||SQLERRM);
    END;
    EXECUTE 'RESET ROLE';
    IF v_n = 2 AND v_ok
       AND (SELECT book_draft_id = v_d_trois AND notes = 'note editee (T14)' FROM public.exemplar_drafts WHERE id = v_id)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||v_n||' ok='||v_ok); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T15 ─────────────────────────────────────────────────────────────
  v_t := 'T15 l''exemplaire suit sa notice : corbeille, restauration, changement de lot';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/corb.marc', 'corb.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run5;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run5, 1, 'corb', 'Notice qui va et vient', 'new_record', 'accept_new',
            jsonb_build_object('items', '[{"source_item_code":"CORB-1"},{"source_item_code":"CORB-2"}]'::jsonb));
    v_lot5 := (public.fn_import_promote(v_run5, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT id INTO v_d5 FROM public.book_drafts WHERE batch_id = v_lot5;
    -- CORB-2 est ecarte seul d'abord (perdu, pilonne) : il ne doit pas ressusciter.
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE book_draft_id = v_d5 AND source_item_code = 'CORB-2';
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d5;
    IF (SELECT count(*) FROM public.exemplar_drafts WHERE book_draft_id = v_d5 AND status = 'cancelled') <> 2
       OR (SELECT count(*) FROM public.exemplar_drafts WHERE book_draft_id = v_d5 AND cancelled_with_record) <> 1 THEN
      RAISE EXCEPTION 'corbeille : les exemplaires ne suivent pas';
    END IF;
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d5;
    IF (SELECT string_agg(source_item_code || '=' || status, ',' ORDER BY source_item_code) FROM public.exemplar_drafts WHERE book_draft_id = v_d5)
       IS DISTINCT FROM 'CORB-1=draft,CORB-2=cancelled' THEN
      RAISE EXCEPTION 'restauration : % ', (SELECT string_agg(source_item_code || '=' || status, ',' ORDER BY source_item_code) FROM public.exemplar_drafts WHERE book_draft_id = v_d5);
    END IF;
    -- Restauree seule, la notice etant vivante : permis.
    UPDATE public.exemplar_drafts SET status = 'draft' WHERE book_draft_id = v_d5 AND source_item_code = 'CORB-2';
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('Essai H19 lot cible', v_coord, v_lib) RETURNING id INTO v_lot6;   -- B30
    UPDATE public.book_drafts SET batch_id = v_lot6 WHERE id = v_d5;
    IF (SELECT count(*) FROM public.exemplar_drafts WHERE book_draft_id = v_d5 AND batch_id = v_lot6) = 2
       AND (public.fn_batch_review_report(v_lot6)->'items'->>'count')::int = 2
       AND coalesce((public.fn_batch_review_report(v_lot5)->'items'->>'count')::int, 0) = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : changement de lot non suivi'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  v_t := 'T16 rapport : un passage, 40 problemes au plus, bibliotheque differente, code attendu ailleurs, « code pris » tu hors staff';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/gros.marc', 'gros.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run6;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run6, 1, 'gros', 'Quarante-cinq fois le meme code', 'new_record', 'accept_new',
            jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', 'DUP-X', 'call_number', 'C' || g)) FROM generate_series(1, 45) g))),
           (v_run6, 2, 'mis', 'Notice attribuee ailleurs', 'new_record', 'accept_new', jsonb_build_object('items', '[{"source_item_code":"MIS-1"}]'::jsonb)),
           (v_run6, 3, 'corb2', 'Code attendu par un autre lot', 'new_record', 'accept_new', jsonb_build_object('items', '[{"source_item_code":"CORB-1"}]'::jsonb)),
           (v_run6, 4, 'pris', 'Code deja dans la bibliotheque', 'new_record', 'accept_new', jsonb_build_object('items', '[{"source_item_code":"CDF0000000001"}]'::jsonb));
    v_lot7 := (public.fn_import_promote(v_run6, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT m.draft_id INTO v_d_mis FROM ingest.partner_catalog_row_to_draft m JOIN ingest.partner_catalog_staging_rows s ON s.id = m.staging_row_id WHERE s.run_id = v_run6 AND s.row_no = 2;
    -- B29 : une notice donnée à une autre bibliothèque rendrait le lot mixte (rapport
    -- refusé à la coordination) ; le décalage se fabrique donc sur l'exemplaire.
    UPDATE public.exemplar_drafts SET target_library_id = v_lib2 WHERE book_draft_id = v_d_mis;
    v_rep := public.fn_batch_review_report(v_lot7);
    -- B29 (CAT-E18) : hors staff de la bibliothèque du lot, le rapport entier est refusé
    -- (avant : lu, avec « code pris » tu).
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN
      v_res := public.fn_batch_review_report(v_lot7);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF (v_rep->'items'->>'count')::int = 48
       AND (v_rep->'items'->>'code_twice')::int = 45
       AND (v_rep->'items'->>'library_mismatch')::int = 1
       AND (v_rep->'items'->>'code_pending_elsewhere')::int = 1
       AND (v_rep->'items'->>'code_taken')::int = 1
       AND jsonb_array_length(v_rep->'items'->'problems') = 40
       -- Hors staff de la bibliotheque : pas de rapport du tout (B29).
       AND v_hint = 'error.batch.other_libraries'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce((v_rep->'items') - 'problems','null'::jsonb)::text, 300)||' / hors staff '||coalesce(v_hint,'rapport rendu')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T17 ─────────────────────────────────────────────────────────────
  v_t := 'T17 rapprochement d''un depot compagnon : administration seule, exemplaires a la destination de la source';
  BEGIN
    -- v_src_dep (T6) a recu la destination v_lib2 a la reattribution (T7) ; ses runs sont sous v_lib.
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src_dep, v_lib, 'essai/dep2.marc', 'dep2.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run7;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run7, 1, 'dep-r', 'Fonds de compagne (doublon)', 'matched_book', 'accept_duplicate', v_book_trois,
            jsonb_build_object('items', '[{"source_item_code":"DEP-1"},{"source_item_code":"DEP-2"}]'::jsonb))
    RETURNING id INTO v_row;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_hint := NULL;
    BEGIN
      PERFORM ingest.fn_create_exemplar_drafts_from_import_rows(v_run7, ARRAY[v_row]);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    v_res := ingest.fn_create_exemplar_drafts_from_import_rows(v_run7, ARRAY[v_row]);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_hint = 'error.import.deposit_admin_only'
       AND (v_res->>'created_items')::int = 2
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row AND x.target_library_id IS DISTINCT FROM v_lib2)
       -- B30 : le lot d'un dépôt compagnon est à la destination de la source.
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x JOIN public.catalog_batches b ON b.id = x.batch_id
                        WHERE x.import_staging_row_id = v_row AND b.library_id IS DISTINCT FROM v_lib2)
       AND EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_row AND x.batch_id IS NOT NULL)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')||' res='||left(coalesce(v_res::text,'NULL'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T18 ─────────────────────────────────────────────────────────────
  v_t := 'T18 rapprochement : code deja la non recree ; rapprochee non promue ; promue non rapprochee';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/reexport.marc', 'reexport.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run8;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run8, 1, '71x', 'Petite histoire (reexport)', 'matched_book', 'accept_duplicate', v_book_trois,
            jsonb_build_object('items', '[{"source_item_code":"CDF0000000010"},{"source_item_code":"NEW-1"}]'::jsonb))
    RETURNING id INTO v_r1;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run8, 2, '71y', 'Petite histoire (tout y est)', 'matched_book', 'accept_duplicate', v_book_trois,
            jsonb_build_object('items', '[{"source_item_code":"CDF0000000011"}]'::jsonb))
    RETURNING id INTO v_r2;
    v_res := ingest.fn_create_exemplar_drafts_from_import_rows(v_run8, ARRAY[v_r1, v_r2]);
    IF (v_res->>'created_items')::int <> 1 OR (v_res->>'items_skipped_code_taken')::int <> 2
       OR (v_res->>'rows_already_held')::int <> 1
       OR (SELECT created_exemplar_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_r2) IS NOT NULL
       -- La ligne entierement detenue est rejetee, avec sa raison (plus de doublon a la promotion).
       OR (SELECT editorial_decision || '/' || review_status FROM ingest.partner_catalog_staging_rows WHERE id = v_r2) <> 'reject/rejected' THEN
      RAISE EXCEPTION 'code deja la : %', v_res;
    END IF;
    -- Toute la selection deja detenue : dit, pas une erreur.
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run8, 4, '71w', 'Petite histoire (encore)', 'matched_book', 'accept_duplicate', v_book_trois,
            jsonb_build_object('items', '[{"source_item_code":"CDF0000000012"}]'::jsonb))
    RETURNING id INTO v_id;
    v_res := ingest.fn_create_exemplar_drafts_from_import_rows(v_run8, ARRAY[v_id]);
    IF v_res->>'batch_id' IS NOT NULL OR (v_res->>'rows_already_held')::int <> 1 THEN
      RAISE EXCEPTION 'selection deja detenue : %', v_res;
    END IF;
    -- Une ligne neuve, non rapprochee, est promue ; les rapprochees ou rejetees non.
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
    VALUES (v_run8, 3, '71z', 'Petite histoire (a promouvoir)', 'matched_book', 'accept_duplicate', v_book_trois,
            jsonb_build_object('items', '[{"source_item_code":"PRO-1"}]'::jsonb))
    RETURNING id INTO v_x2;
    PERFORM public.fn_import_promote(v_run8, ARRAY['matched_book'], ARRAY['accept_duplicate']);
    IF (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_r1) IS NOT NULL
       OR (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_r2) IS NOT NULL
       OR (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_x2) IS NULL THEN
      RAISE EXCEPTION 'promotion d''une ligne rapprochee ou rejetee, ou ligne neuve oubliee';
    END IF;
    -- et la ligne promue ne se rapproche plus.
    v_txt := NULL;
    BEGIN
      PERFORM ingest.fn_create_exemplar_drafts_from_import_rows(v_run8, ARRAY[v_x2]);
    EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
    END;
    IF v_txt LIKE 'Aucune ligne eligible%'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rapprochement d''une ligne promue : '||coalesce(v_txt,'accepte')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T19 ─────────────────────────────────────────────────────────────
  v_t := 'T19 declencheur : repointage limite au meme rapprochement';
  BEGIN
    SELECT created_exemplar_draft_id INTO v_x1 FROM ingest.partner_catalog_staging_rows WHERE id = v_r1;
    -- Un brouillon d'un autre lot qui pretend venir de la meme ligne.
    INSERT INTO public.exemplar_drafts (batch_id, action, status, label_status, target_library_id, import_staging_row_id)
    VALUES (v_lot6, 'create', 'draft', 'pending', v_lib, v_r1) RETURNING id INTO v_x2;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x1;
    IF (SELECT created_exemplar_draft_id IS NULL AND editorial_decision = 'pending' FROM ingest.partner_catalog_staging_rows WHERE id = v_r1)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ligne repointee sur un brouillon etranger'); END IF;
    DELETE FROM public.exemplar_drafts WHERE id = v_x2;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T20 ─────────────────────────────────────────────────────────────
  v_t := 'T20 le code d''origine n''entre dans aucune note de provenance (IMP-21 b)';
  BEGIN
    IF (SELECT count(*) FROM public.exemplar_drafts x WHERE x.source_item_code IS NOT NULL) >= 60
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x
                        WHERE x.source_item_code IS NOT NULL AND x.provenance_note LIKE '%' || x.source_item_code || '%')
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e
                        WHERE e.source_item_code IS NOT NULL AND e.provenance_note LIKE '%' || e.source_item_code || '%')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : code retrouve dans une note : '||coalesce((
           SELECT string_agg(x.id || ' ' || x.source_item_code || ' [' || left(x.provenance_note, 160) || ']', ' ; ')
             FROM public.exemplar_drafts x
            WHERE x.source_item_code IS NOT NULL AND x.provenance_note LIKE '%' || x.source_item_code || '%'), 'aucun brouillon')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T21 ─────────────────────────────────────────────────────────────
  v_t := 'T21 fusion de doublons : les exemplaires importes du perdant passent au survivant, ceux d''un brouillon absorbe vont sur la fiche';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/fusion.marc', 'fusion.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run5;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run5, 1, 'fa', 'Doublon A', 'new_record', 'accept_new', jsonb_build_object('items', '[{"source_item_code":"FUS-A"}]'::jsonb)),
           (v_run5, 2, 'fb', 'Doublon B', 'new_record', 'accept_new', jsonb_build_object('items', '[{"source_item_code":"FUS-B"}]'::jsonb));
    v_lot5 := (public.fn_import_promote(v_run5, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT min(id), max(id) INTO v_x1, v_x2 FROM public.book_drafts WHERE batch_id = v_lot5;
    PERFORM api.merge_book_drafts(v_x1, v_x2, '{}'::jsonb);
    IF (SELECT count(*) FROM public.exemplar_drafts WHERE book_draft_id = v_x1 AND status = 'draft') <> 2
       OR EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE book_draft_id = v_x2) THEN
      RAISE EXCEPTION 'fusion brouillon-brouillon : exemplaires non repointes';
    END IF;
    PERFORM api.merge_draft_into_book(v_x1, v_book_trois, '{}'::jsonb);
    IF (SELECT count(*) FROM public.exemplar_drafts x
         WHERE x.source_item_code IN ('FUS-A', 'FUS-B') AND x.status = 'draft' AND x.book_draft_id IS NULL
           AND x.target_bib_ref = (SELECT bib_ref FROM public.books WHERE id = v_book_trois)
           AND x.import_staging_row_id IS NOT NULL AND x.target_library_id = v_lib) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaires perdus a la fusion dans une fiche'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T22 ─────────────────────────────────────────────────────────────
  v_t := 'T22 journal : une notice supprimee revient AVEC ses exemplaires importes';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/journal.marc', 'journal.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run6;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run6, 1, 'jr', 'Notice supprimee puis rejouee', 'new_record', 'accept_new',
            jsonb_build_object('items', '[{"source_item_code":"JRN-1","call_number":"J 1"},{"source_item_code":"JRN-2"}]'::jsonb));
    v_lot7 := (public.fn_import_promote(v_run6, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    SELECT id INTO v_id FROM public.book_drafts WHERE batch_id = v_lot7;
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_id;
    DELETE FROM public.book_drafts WHERE id = v_id;   -- « Vider la corbeille »
    IF EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE source_item_code LIKE 'JRN-%') THEN
      RAISE EXCEPTION 'CASCADE absente ?';
    END IF;
    SELECT max(l.id) INTO v_x1 FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_id;
    v_res := public.fn_restore_deleted_draft(v_x1);
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_id;   -- sortie de corbeille
    IF (SELECT count(*) FROM public.exemplar_drafts x
         WHERE x.book_draft_id = v_id AND x.status = 'draft' AND x.source_item_code IN ('JRN-1', 'JRN-2')) = 2
       AND (SELECT shelf_location FROM public.exemplar_drafts WHERE source_item_code = 'JRN-1') = 'J 1'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_res::text,'NULL'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T23 ─────────────────────────────────────────────────────────────
  v_t := 'T23 un run rapproche ne se retraite plus (ses brouillons perdraient leur import)';
  BEGIN
    -- v_run7 (T17) n'a ete que rapproche : aucune notice promue, deux exemplaires vivants.
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = v_run7) THEN
      RAISE EXCEPTION 'decor : v_run7 a ete promu';
    END IF;
    v_hint := NULL;
    BEGIN
      PERFORM public.fn_import_dispatch(v_run7, true);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.import.reparse_after_promotion'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T24 ─────────────────────────────────────────────────────────────
  v_t := 'T24 par l''API, un exemplaire importe suit sa notice : restaure seul, deplace seul, published_exemplar_id';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_ok := false;
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d5;
      -- restaurer les exemplaires seuls : ils attendent leur notice
      UPDATE public.exemplar_drafts SET status = 'draft' WHERE book_draft_id = v_d5;
      IF EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE book_draft_id = v_d5 AND (status <> 'cancelled' OR NOT cancelled_with_record)) THEN
        RAISE EXCEPTION 'restaures sous une notice ecartee';
      END IF;
      UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d5;
      -- deplaces seuls vers un autre lot, publies vers un exemplaire etranger : rien ne bouge
      UPDATE public.exemplar_drafts SET batch_id = v_lot5 WHERE book_draft_id = v_d5;
      UPDATE public.exemplar_drafts SET published_exemplar_id = (SELECT min(id) FROM public.exemplares) WHERE book_draft_id = v_d5;
      EXECUTE 'RESET ROLE';
      v_ok := true;
    EXCEPTION WHEN OTHERS THEN v_failures := v_failures||(v_t||' : '||SQLERRM);
    END;
    EXECUTE 'RESET ROLE';
    IF v_ok
       AND (SELECT count(*) FROM public.exemplar_drafts
             WHERE book_draft_id = v_d5 AND status = 'draft' AND batch_id = v_lot6 AND published_exemplar_id IS NULL) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce((SELECT string_agg(status||'/'||batch_id||'/'||coalesce(published_exemplar_id::text,'-'), ',') FROM public.exemplar_drafts WHERE book_draft_id = v_d5), 'rien')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T25 ─────────────────────────────────────────────────────────────
  v_t := 'T25 reattribuer un exemplaire importe dont le code existe dans la destination : refus dit, pas un 23505 brut';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, source_item_code, circulation_policy)
    VALUES ('X', 'ESSAI-H19-U3', v_lib2, 'CDF0000000011', 'emprestavel');
    SELECT x.id INTO v_id FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d_trois AND x.source_item_code = 'CDF0000000011';
    -- comme #cross-lib-reassign : autre bibliotheque, detention et tombo vides ; brouillon sans code.
    UPDATE public.exemplar_drafts SET target_library_id = v_lib2, target_holding_id = NULL, tombo = NULL, source_item_code = NULL WHERE id = v_id;
    v_hint := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_id);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_hint = 'error.publish.source_item_code_taken'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T26 ─────────────────────────────────────────────────────────────
  v_t := 'T26 rapport : « sans numerotation » seulement pour un exemplaire qui n''a pas deja son tombo';
  BEGIN
    INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
    VALUES (gen_random_uuid(), 'essai-h19-sans-schema', 'Essai — sans schema H19', true, 'private') RETURNING id INTO v_other;
    -- B30 : le lot est à la bibliothèque de ses exemplaires (le rapport ne
    -- montre, hors administration, que ceux de la bibliothèque du lot).
    INSERT INTO public.catalog_batches (name, created_by, library_id) VALUES ('Essai H19 T26', v_coord, v_other) RETURNING id INTO v_lot5;
    INSERT INTO public.exemplar_drafts (batch_id, action, status, label_status, target_library_id, import_staging_row_id, tombo, target_bib_ref)
    VALUES (v_lot5, 'create', 'draft', 'pending', v_other, v_r1, 'T26-1', 'X'),
           (v_lot5, 'create', 'draft', 'pending', v_other, v_r1, NULL, 'X');
    -- B29 (CAT-E18) : le rapport d'un lot est à qui en possède tous les
    -- brouillons ; la coordination est aussi staff de la bibliothèque visée.
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
    VALUES (v_coord, v_other, 'librarian', 'active', false);
    v_rep := public.fn_batch_review_report(v_lot5);
    DELETE FROM public.user_library_memberships WHERE user_id = v_coord AND library_id = v_other;
    IF (v_rep->'items'->>'count')::int = 2 AND (v_rep->'items'->>'library_without_numbering')::int = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce((v_rep->'items') - 'problems','null'::jsonb)::text, 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T27 ─────────────────────────────────────────────────────────────
  v_t := 'T27 repli sans bibliotheque cible : une adhesion de STAFF, pas l''adhesion principale de lectrice';
  BEGIN
    SELECT u.id INTO v_other FROM auth.users u WHERE u.email LIKE 'h19-%@example.invalid' LIMIT 1;
    UPDATE public.user_library_memberships SET is_primary = false WHERE user_id = v_other;
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
    VALUES (v_other, v_lib, 'reader', 'active', true);
    -- B29 : le brouillon est à la bibliothèque de qui l'a créé (sans cible).
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_bib_ref, tombo, created_by)
    VALUES ('create', 'draft', 'pending', (SELECT bib_ref FROM public.books WHERE id = v_book_zero), 'ESSAI-H19-T27', v_other)
    RETURNING id INTO v_id;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
    PERFORM public.publish_exemplar_draft(v_id);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF (SELECT e.library_id FROM public.exemplares e WHERE e.tombo = 'ESSAI-H19-T27') = v_lib2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaire ailleurs que dans la bibliotheque de staff'); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T28 ─────────────────────────────────────────────────────────────
  v_t := 'T28 un exemplaire ecarte seul, restaure APRES la publication de sa notice, se publie sur la fiche';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/tard.marc', 'tard.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run5;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
    VALUES (v_run5, 1, 'tard', 'Exemplaire revenu tard', 'new_record', 'accept_new',
            jsonb_build_object('items', '[{"source_item_code":"TARD-1"},{"source_item_code":"TARD-2"}]'::jsonb));
    v_lot5 := (public.fn_import_promote(v_run5, ARRAY['new_record'], ARRAY['accept_new'])->>'batch_id')::bigint;
    UPDATE public.book_drafts SET bib_ref = 'ESSAI-H19-TARD-' || id WHERE batch_id = v_lot5 RETURNING id INTO v_id;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE book_draft_id = v_id AND source_item_code = 'TARD-2';
    v_res := public.fn_batch_review_request(v_lot5);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    PERFORM public.publish_book_draft(v_id);
    SELECT x.id INTO v_x1 FROM public.exemplar_drafts x WHERE x.book_draft_id = v_id AND x.source_item_code = 'TARD-2';
    UPDATE public.exemplar_drafts SET status = 'draft' WHERE id = v_x1;
    PERFORM public.publish_exemplar_draft(v_x1);
    IF (SELECT e.bib_ref FROM public.exemplares e WHERE e.source_item_code = 'TARD-2' AND e.library_id = v_lib) = 'ESSAI-H19-TARD-' || v_id
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
             JOIN public.book_drafts bd ON bd.published_book_id = h.book_id
            WHERE bd.id = v_id AND e.library_id = v_lib) = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : exemplaire absent ou hors de la fiche'); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T29 ─────────────────────────────────────────────────────────────
  v_t := 'T29 journal : pas d''entree a part pour un exemplaire supprime avec sa notice ; rejeu isole refuse proprement';
  BEGIN
    SELECT id INTO v_id FROM public.book_drafts WHERE titulo = 'Notice supprimee puis rejouee';
    IF v_id IS NULL THEN RAISE EXCEPTION 'decor : notice de T22 absente'; END IF;
    IF EXISTS (SELECT 1 FROM public.catalog_audit_log l
                WHERE l.action = 'delete' AND l.entity_type = 'exemplar'
                  AND l.details->'snapshot'->>'source_item_code' IN ('JRN-1', 'JRN-2')) THEN
      RAISE EXCEPTION 'exemplaires journalises en double de l''instantane de leur notice (T22)';
    END IF;
    -- JRN-2 supprime seul (sa notice existe) : journalise ; puis la notice part.
    DELETE FROM public.exemplar_drafts WHERE book_draft_id = v_id AND source_item_code = 'JRN-2';
    SELECT max(l.id) INTO v_x1 FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'exemplar' AND l.details->'snapshot'->>'source_item_code' = 'JRN-2';
    DELETE FROM public.book_drafts WHERE id = v_id;
    v_hint := NULL;
    BEGIN
      PERFORM public.fn_restore_deleted_draft(v_x1);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_x1 IS NOT NULL AND v_hint = 'error.catalog.restore_record_first'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : entree='||coalesce(v_x1::text,'NULL')||' hint='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T30 ─────────────────────────────────────────────────────────────
  v_t := 'T30 profil supprime depuis l''import : refuse des l''envoi, message a l''ecran';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_import_profile_create(v_lib, 'Profil ephemere (T30)', '{}'::jsonb, '{}'::jsonb, '{"code": "b"}'::jsonb);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, adapter_overrides)
    VALUES (v_src, v_lib, 'essai/profil.marc', 'profil.marc', 'marc_iso2709', 'uploaded', jsonb_build_object('profile_id', (v_res->>'id')::bigint))
    RETURNING id INTO v_run6;
    DELETE FROM ingest.import_profiles WHERE id = (v_res->>'id')::bigint;
    v_hint := NULL;
    BEGIN
      PERFORM public.fn_import_dispatch(v_run6, false);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    END;
    IF v_hint = 'error.import.profile_missing'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-EXEMPLAIRES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IMPORT-EXEMPLAIRES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
