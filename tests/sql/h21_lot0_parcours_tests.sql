-- =====================================================================
-- AnarBib — Tests d'acceptation : le PARCOURS d'une bibliothèque qui
-- importe son catalogue, de bout en bout (H21 lot 0, REGISTRE IMP-26 et
-- IMP-27, décisions de Xavier du 29/09/2026)
-- Date    : 2026-09-29
-- Ref     : migration 20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe
--
-- Pourquoi cette suite existe : chaque correctif du lot 0 a sa suite, qui le
-- prouve seul. Aucune ne suit la chaîne entière — import → promotion d'une
-- sélection → révision → publication → rapprochement → annulation →
-- suppression → restauration → re-promotion — où les correctifs se croisent
-- (un brouillon rangé après l'approbation, puis supprimé, puis restauré ;
-- une sélection qui rejoint un lot en retouches…). Ici, UNE bibliothèque
-- (BLMF), UN fichier MARC, et l'état du catalogue à la fin.
--
-- Décor : une notice N0 déjà au catalogue de BLMF ; un run MARC de 9 lignes :
--   L1 nouvelle 'H21P-1' (1 exemplaire)   L2 nouvelle 'H21P-2' (sans exemplaire)
--   L3 nouvelle 'H21P-R'                  L4 rejetée, MÊME clé 'H21P-R'
--   L5 doublon de N0 'H21P-5' (1 ex.)     L6 doublon possible de N0, « Accepté
--   L7 doublon de N0 'H21P-7' (1 ex.)        (rattaché) » posé par l'API, sans ex.
--   L8 nouvelle 'H21P-8' (1 ex.)          L9 nouvelle 'H21P-9' (1 ex.)
--
-- E1  IMP-26 (h) + sélection : « Accepté (rattaché) » ne se pose plus par
--     fn_import_set_editorial (HINT réel) ; « Promouvoir la sélection » [L1]
--     ne promeut que L1 : un brouillon, un lot T1, son exemplaire.
-- E2  (a) la garde suit le brouillon : l'exemplaire de L1 perdu (supprimé) ;
--     dans T1, review_required ; sorti du lot par l'API (« Sans lot »),
--     imported_needs_batch ; le run ne se supprime pas tant que ce brouillon
--     lié vit hors de son lot (run_has_linked_drafts). Remis dans T1.
-- E3  (d) une seconde sélection [L8] rejoint T1 (ouvert, sans révision) ; les
--     exemplaires créés sont ceux de L8 SEULS — celui de L1, supprimé entre
--     les deux sélections, ne revient pas.
-- E4  révision de T1 : liste figée {d1, d8} ; approbation ; publication du
--     lot ; les clés 'H21P-1' et 'H21P-8' enregistrées une fois, sur leurs notices.
-- E5  (d) une sélection [L3] ne rejoint pas un lot publié : lot neuf T2 ;
--     identifiant jugé par la ligne : 'H21P-R' (portée aussi par L4) effacé
--     du brouillon ; T2 révisé et approuvé (sans publier).
-- E6  (b) [L2] ne rejoint pas T2 approuvé (lot neuf T3) ; rangé ensuite dans
--     T2 par l'API : added_after_review (notice seule ET lot entier, tout ou
--     rien) ; la liste des lots le dit (after_review = 1) ; la COORDINATION
--     redemande un tour : tour 2 = {d2, d3}.
-- E7  (d) T3 vide supprimé ; l'administration demande des retouches sur T2
--     (« L2 est un doublon ») ; une sélection [L9] rejoint T2 en retouches.
-- E8  (e) L2 à la corbeille puis supprimé DÉFINITIVEMENT : sa ligne est
--     écartée (reject/rejected, note IMP-27 e) ; « Promouvoir » (tout le run)
--     ne la reprend pas ; rejoué depuis le journal : la ligne revient à CE
--     brouillon (seconde passe : accept_new/draft_created, created_book_draft_id,
--     lien row_to_draft rétabli) ; UN brouillon pour L2, jamais deux — ni par
--     « Promouvoir », ni par une réacceptation de L2 par l'API suivie de
--     « Promouvoir la sélection » (constats 10 et 16 de la revue : que la
--     décision ignore la ligne ou la refuse, rien ne naît) ; il ne se publie
--     pas sans révision ; remis à la corbeille, la ligne reste la sienne.
-- E9  (b) tour 3 = {d3, d9} (la corbeille n'en est pas) ; approuvé ; T2
--     publié ; 'H21P-9' enregistrée ; 'H21P-R' jamais.
-- E10 (c) « Rapprocher » [L5] : lot R5 importé ; l'exemplaire rapproché ne se
--     publie pas avant révision (seul ni par le lot) ; un exemplaire fait à
--     la main rangé dans R5 après l'approbation attend (contagion) ; la
--     coordination redemande ; tour 2 approuvé ; R5 publié ; 'H21P-5' sur N0.
-- E11 IMP-26 (h) : [L5, L6] — même avec un filtre explicite « accept_duplicate »,
--     même « tout le run » — aucune notice.
-- E12 rapprochement annulé : L7 revient en attente ; « Promouvoir » ne la
--     prend pas ; un nouveau rapprochement la reprend sans doublon, et son
--     lot attend sa révision (c).
-- E13 le run ne se supprime pas : son travail vit (refus dit, run intact) —
--     brouillons de ses lots, brouillon lié hors lot, ou exemplaire rapproché
--     à la corbeille (seconde passe : run_has_trashed_items).
-- E14 invariants finaux : au plus une notice par clé d'origine (et les clés
--     attendues, exactement) ; aucune notice née d'une ligne rattachée ou
--     rapprochée (L5, L6, L7) ; chaque notice publiée du run et chaque
--     exemplaire publié hors notice de ses lots vient d'un lot dont le
--     DERNIER tour est approuvé et le couvre.
--
-- Un appel qui DOIT être refusé et qui passe est annulé (sous-transaction)
-- et noté : l'étape tombe, la suite du parcours garde son décor — une
-- contre-épreuve fait tomber l'étape du correctif, pas tout le parcours.
--
-- Contre-épreuves (définition d'avant le lot 0 rejouée avant la suite ;
-- jouées le 29/09, 14/14 avec la migration) :
--   ancien-publish_book_draft                 : 12/14 — E2 (publiée « Sans lot »),
--       E6 (notice rangée après l'approbation publiée, seule et par le lot).
--   ancien-promote-bulk-items                 :  2/14 — E1 tombe : « Promouvoir la
--       sélection » n'existe pas (fn_import_promote sans p_row_ids) ; E2-E9, E11,
--       E12, E14 en cascade (rien n'est promu) ; E10, E13 tiennent.
--   ancien-fn_create_book_drafts_from_import_rows : 9/14 — E3 et E7 (lot neuf au
--       lieu du lot ouvert du run) ; E4, E9, E14 en cascade (notices hors de T1/T2).
--   ancien-publish_exemplar_draft             : 12/14 — E10 (exemplaire rapproché
--       et exemplaire fait à la main publiés sans révision), E12 (idem, second
--       rapprochement).
--   ancien-declencheur-ecartement             : 11/14 — E8 (la ligne de L2 reste
--       accept_new, « Promouvoir » la reprend) ; E11, E12 en cascade (même
--       re-promotion de L2 par « tout le run »).
--   et, en complément :
--   ancien-fn_import_delete_run               : 13/14 — E2 (le run se supprime sous
--       le brouillon lié sorti de son lot).
--   ancien-fn_batch_review_request            :  5/14 — E4 (liste non figée), E6 (la
--       coordination ne redemande pas : already_approved) ; E7-E12, E14 en cascade.
--   ancien-fn_batch_is_imported               : 11/14 — E10 (lot de rapprochement
--       « pas importé » : révision refusée), E12 (publié sans révision) ; E14.
--   ancien-fn_h20_identifiant_d_origine       : 11/14 — E5, E9 ('H21P-R' gardée puis
--       enregistrée) ; E14.
--   ancien-fn_import_set_editorial            : 13/14 — E1 (« rattaché » posé par l'API).
--   mutants de la définition vivante (agent F, scratchpad h21-lot0-agents) :
--   ancien-F-bulk-sans-selection  :  4/14 — E1 (5 brouillons pour une sélection
--       d'une ligne) ; E2-E9, E14 en cascade.
--   ancien-F-items-tout-le-lot    : 12/14 — E3 (l'exemplaire supprimé de L1 recréé
--       dans le lot repris) ; E4 en cascade.
--   ancien-F-rattachee-eligible   : 13/14 — E11 (L6 « rattachée » promue par le
--       filtre explicite accept_duplicate).
--   seconde passe (revue du 29/09 ; mutants ciblés de la définition vivante,
--   scratchpad h21-lot0-agents/E-seconde ; toutes les contre-épreuves
--   ci-dessus rejouées le 30/09 avec les mêmes résultats) :
--   E-restaurer-sans-reprise      : 13/14 — E8 (au rejeu, la ligne de L2 reste
--       écartée ; réacceptée par l'API puis promue, elle donne un second
--       brouillon — noté puis annulé).
--   E-decision-sans-ignorer       : 14/14 — E8 tient : la décision de la première
--       passe REFUSE la ligne reprise (verrouillée) au lieu de l'ignorer ; rien
--       ne naît. Ce que l'écran en montre est l'affaire d'import_promotion_selection.
--   E13 ne tombe avec aucune : non-régression (sous ancien-promote-bulk-items,
--   rien n'est promu : seul l'exemplaire rapproché de L7, à la corbeille,
--   retient le run — run_has_trashed_items).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'H21-LOT0-PARCOURS OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans role (seed) -> admin reseau ici
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_src bigint; v_run bigint; v_n0 bigint;
  v_l1 bigint; v_l2 bigint; v_l3 bigint; v_l4 bigint; v_l5 bigint; v_l6 bigint; v_l7 bigint; v_l8 bigint; v_l9 bigint;
  v_t1 bigint; v_t2 bigint; v_t3 bigint; v_r5 bigint; v_r7 bigint; v_r7b bigint;
  v_d1 bigint; v_d2 bigint; v_d3 bigint; v_d8 bigint; v_d9 bigint;
  v_b1 bigint; v_b3 bigint; v_b8 bigint; v_b9 bigint;
  v_x5 bigint; v_xm bigint; v_x7 bigint; v_x7b bigint;
  v_rev bigint; v_audit bigint;
  v_res jsonb; v_res2 jsonb;
  v_h1 text; v_h2 text; v_h3 text; v_h4 text; v_msg text; v_txt text;
  v_n int; v_m int; v_k int; v_ok boolean; v_ok2 boolean; v_res3 jsonb;
  v_scheme text;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  -- Les tombos de la bibliothèque (publication des notices et des exemplaires).
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "H21P-T-", "year": false, "pad": 4}'::jsonb WHERE id = v_lib;

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H21P parcours', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  v_scheme := 'import:' || v_src;

  -- N0 : une notice déjà au catalogue de BLMF, que le fichier redécrit.
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('H21P Notice deja au catalogue', 'H21P-N0', 'livro', v_lib) RETURNING id INTO v_n0;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_n0, v_lib);

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h21p.marc', 'h21p.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 1, 'H21P-1', 'H21P Premiere selection', 'new_record', 'pending',
          jsonb_build_object('items', '[{"source_item_code":"H21P-C1","call_number":"H21P 1"}]'::jsonb)) RETURNING id INTO v_l1;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 2, 'H21P-2', 'H21P Notice rangee apres l''approbation', 'new_record', 'pending',
          jsonb_build_object('items', '[]'::jsonb)) RETURNING id INTO v_l2;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 3, 'H21P-R', 'H21P Notice a cle repetee', 'new_record', 'pending', '{}'::jsonb) RETURNING id INTO v_l3;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, normalized_payload)
  VALUES (v_run, 4, 'H21P-R', 'H21P Ligne rejetee, meme cle', 'new_record', 'reject', 'rejected', '{}'::jsonb) RETURNING id INTO v_l4;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
  VALUES (v_run, 5, 'H21P-5', 'H21P Doublon rapproche', 'matched_book', 'pending', v_n0,
          jsonb_build_object('items', '[{"source_item_code":"H21P-C5","call_number":"H21P 5"}]'::jsonb)) RETURNING id INTO v_l5;
  -- L6 : l'état que l'API produisait avant IMP-26 (h) — « rattaché » sans rapprochement.
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, review_status, selected_for_draft, proposed_book_id, normalized_payload)
  VALUES (v_run, 6, 'H21P-6', 'H21P Doublon rattache sans exemplaire', 'possible_duplicate', 'accept_duplicate', 'approved', true, v_n0,
          jsonb_build_object('items', '[]'::jsonb)) RETURNING id INTO v_l6;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id, normalized_payload)
  VALUES (v_run, 7, 'H21P-7', 'H21P Doublon rapproche puis annule', 'matched_book', 'pending', v_n0,
          jsonb_build_object('items', '[{"source_item_code":"H21P-C7"}]'::jsonb)) RETURNING id INTO v_l7;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 8, 'H21P-8', 'H21P Seconde selection', 'new_record', 'pending',
          jsonb_build_object('items', '[{"source_item_code":"H21P-C8","call_number":"H21P 8"}]'::jsonb)) RETURNING id INTO v_l8;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, normalized_payload)
  VALUES (v_run, 9, 'H21P-9', 'H21P Selection pendant les retouches', 'new_record', 'pending',
          jsonb_build_object('items', '[{"source_item_code":"H21P-C9"}]'::jsonb)) RETURNING id INTO v_l9;

  -- ── E1 ──────────────────────────────────────────────────────────────
  v_t := 'E1 IMP-26 h + selection : rattache refuse a l''API ; Promouvoir [L1] ne promeut que L1';
  BEGIN
    PERFORM public.fn_import_set_editorial(v_run, ARRAY[v_l1, v_l2, v_l3, v_l8, v_l9], 'accept_new');
    v_h1 := NULL;
    BEGIN
      PERFORM public.fn_import_set_editorial(v_run, ARRAY[v_l7], 'accept_duplicate');
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT;
    END;
    v_res := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_l1]);
    v_t1 := (v_res->>'batch_id')::bigint;
    SELECT created_book_draft_id INTO v_d1 FROM ingest.partner_catalog_staging_rows WHERE id = v_l1;
    UPDATE public.book_drafts SET bib_ref = 'H21P-REF-' || id
     WHERE marc_json->'ingest'->>'run_id' = v_run::text AND bib_ref IS NULL;
    IF v_h1 = 'error.import.rattacher_par_rapprocher'
       AND (SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = v_l7) = 'pending'
       AND v_t1 IS NOT NULL AND v_d1 IS NOT NULL
       AND (v_res->>'created_drafts')::int = 1 AND (v_res->>'items_created')::int = 1
       AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = v_run) = 1
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_d1) = v_t1
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows sr
                        WHERE sr.run_id = v_run AND sr.id <> v_l1 AND sr.created_book_draft_id IS NOT NULL)
       AND (SELECT count(*) FROM public.exemplar_drafts x
             WHERE x.book_draft_id = v_d1 AND x.batch_id = v_t1 AND x.source_item_code = 'H21P-C1') = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : rattache='||coalesce(v_h1,'NULL')
           ||' promotion='||left(coalesce(v_res::text,'NULL'), 250)
           ||' brouillons='||(SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = v_run)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E2 ──────────────────────────────────────────────────────────────
  v_t := 'E2 (a) la garde suit le brouillon importe : dans son lot, hors lot ; le run ne part pas sous lui';
  BEGIN
    -- L'exemplaire du fichier de L1 est perdu : supprimé. (Vivant, il
    -- retiendrait le run à lui seul — garde H20 de fn_import_delete_run —
    -- et cacherait celle du lot 0 sur le brouillon lié.)
    DELETE FROM public.exemplar_drafts WHERE book_draft_id = v_d1;
    v_h1 := NULL; v_h2 := NULL; v_h3 := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d1);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT;
    END;
    -- « Sans lot », par l'API.
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_d1;
    EXECUTE 'RESET ROLE';
    BEGIN
      PERFORM public.publish_book_draft(v_d1);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT;
    END;
    -- Le lot d'origine est vide : seul le brouillon lié, hors de son lot,
    -- retient le run.
    BEGIN
      PERFORM public.fn_import_delete_run(v_run);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h3 = PG_EXCEPTION_HINT;
    END;
    -- Remis dans son lot, par l'API.
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = v_t1 WHERE id = v_d1;
    EXECUTE 'RESET ROLE';
    IF v_h1 = 'error.publish.review_required'
       AND v_h2 = 'error.publish.imported_needs_batch'
       AND v_h3 = 'error.import.run_has_linked_drafts'
       AND (SELECT status FROM public.book_drafts WHERE id = v_d1) = 'draft'
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_d1) = v_t1
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d1)
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
       AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.bib_ref = 'H21P-REF-' || v_d1)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : dans le lot='||coalesce(v_h1,'NULL')
           ||' hors lot='||coalesce(v_h2,'NULL')||' suppression du run='||coalesce(v_h3,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E3 ──────────────────────────────────────────────────────────────
  v_t := 'E3 (d) la selection suivante [L8] rejoint T1 ouvert ; seuls les exemplaires de L8 sont crees';
  BEGIN
    -- d1 n'a plus d'exemplaire (supprimé en E2) : la promotion de L8 dans le
    -- même lot ne doit pas le lui recréer.
    v_res := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_l8]);
    SELECT created_book_draft_id INTO v_d8 FROM ingest.partner_catalog_staging_rows WHERE id = v_l8;
    UPDATE public.book_drafts SET bib_ref = 'H21P-REF-' || id
     WHERE marc_json->'ingest'->>'run_id' = v_run::text AND bib_ref IS NULL;
    IF (v_res->>'batch_id')::bigint = v_t1
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_d8) = v_t1
       AND (v_res->>'created_drafts')::int = 1 AND (v_res->>'items_created')::int = 1
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d1)
       AND (SELECT count(*) FROM public.exemplar_drafts x
             WHERE x.book_draft_id = v_d8 AND x.batch_id = v_t1 AND x.source_item_code = 'H21P-C8') = 1
       AND (SELECT count(DISTINCT m.batch_id) FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = v_run) = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot='||coalesce(v_res->>'batch_id','NULL')||' (T1='||v_t1
           ||') exemplaires='||coalesce(v_res->>'items_created','NULL')
           ||' exemplaire de L1 recree='||(SELECT count(*) FROM public.exemplar_drafts x WHERE x.book_draft_id = v_d1)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E4 ──────────────────────────────────────────────────────────────
  v_t := 'E4 revision de T1 (liste figee), approbation, publication ; cles H21P-1 et H21P-8 une fois';
  BEGIN
    v_res := public.fn_batch_review_request(v_t1, 'H21P : premier lot');
    v_rev := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.publish_catalog_batch(v_t1);
    SELECT published_book_id INTO v_b1 FROM public.book_drafts WHERE id = v_d1;
    SELECT published_book_id INTO v_b8 FROM public.book_drafts WHERE id = v_d8;
    IF (SELECT draft_ids FROM public.catalog_batch_reviews WHERE id = v_rev)
         = (SELECT array_agg(x ORDER BY x) FROM unnest(ARRAY[v_d1, v_d8]) x)
       AND (v_res->>'books_published')::int = 2
       AND (SELECT status FROM public.catalog_batches WHERE id = v_t1) = 'published'
       AND v_b1 IS NOT NULL AND v_b8 IS NOT NULL
       AND (SELECT count(*) FROM public.book_external_ids e WHERE e.scheme = v_scheme AND e.value = 'H21P-1') = 1
       AND (SELECT e.book_id FROM public.book_external_ids e WHERE e.library_id = v_lib AND e.scheme = v_scheme AND e.value = 'H21P-1') = v_b1
       AND (SELECT count(*) FROM public.book_external_ids e WHERE e.scheme = v_scheme AND e.value = 'H21P-8') = 1
       AND (SELECT e.book_id FROM public.book_external_ids e WHERE e.library_id = v_lib AND e.scheme = v_scheme AND e.value = 'H21P-8') = v_b8
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
             WHERE h.book_id = v_b8 AND e.library_id = v_lib AND e.source_item_code = 'H21P-C8') = 1
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.source_item_code = 'H21P-C1')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : liste='||coalesce((SELECT draft_ids::text FROM public.catalog_batch_reviews WHERE id = v_rev),'NULL')
           ||' d1/d8='||v_d1||'/'||v_d8||' publication='||left(coalesce(v_res::text,'NULL'), 200)
           ||' cles='||coalesce((SELECT string_agg(e.value||'->'||e.book_id, ',') FROM public.book_external_ids e WHERE e.scheme = v_scheme), 'aucune')); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E5 ──────────────────────────────────────────────────────────────
  v_t := 'E5 (d) [L3] ne rejoint pas un lot publie : lot neuf T2 ; H21P-R (portee par L4 aussi) effacee ; T2 approuve';
  BEGIN
    v_res := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_l3]);
    v_t2 := (v_res->>'batch_id')::bigint;
    SELECT created_book_draft_id INTO v_d3 FROM ingest.partner_catalog_staging_rows WHERE id = v_l3;
    UPDATE public.book_drafts SET bib_ref = 'H21P-REF-' || id
     WHERE marc_json->'ingest'->>'run_id' = v_run::text AND bib_ref IS NULL;
    v_res2 := public.fn_batch_review_request(v_t2, 'H21P : second lot');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict((v_res2->>'review_id')::bigint, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_t2 IS NOT NULL AND v_t2 <> v_t1 AND v_d3 IS NOT NULL
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_d3) = v_t2
       AND (SELECT source_record_id FROM public.book_drafts WHERE id = v_d3) IS NULL
       AND ingest.fn_h20_identifiant_d_origine(v_d3) IS NULL
       AND ingest.fn_h20_identifiant_d_origine(v_d1) = 'H21P-1'
       AND public.fn_batch_review_status(v_t2) = 'approved'
       AND (SELECT status FROM public.catalog_batches WHERE id = v_t2) = 'open'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot='||coalesce(v_t2::text,'NULL')||' (T1='||v_t1
           ||') cle du brouillon='||coalesce((SELECT source_record_id FROM public.book_drafts WHERE id = v_d3),'NULL')
           ||' juge='||coalesce(ingest.fn_h20_identifiant_d_origine(v_d3),'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E6 ──────────────────────────────────────────────────────────────
  v_t := 'E6 (b) [L2] range dans T2 apres l''approbation : added_after_review ; la coordination redemande un tour';
  BEGIN
    v_res := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_l2]);
    v_t3 := (v_res->>'batch_id')::bigint;
    SELECT created_book_draft_id INTO v_d2 FROM ingest.partner_catalog_staging_rows WHERE id = v_l2;
    UPDATE public.book_drafts SET bib_ref = 'H21P-REF-' || id
     WHERE marc_json->'ingest'->>'run_id' = v_run::text AND bib_ref IS NULL;
    -- Rangée dans le lot approuvé, par l'API : le contournement que (b) ferme.
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.book_drafts SET batch_id = v_t2 WHERE id = v_d2;
    EXECUTE 'RESET ROLE';
    v_h1 := NULL; v_h2 := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d2);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT;
    END;
    BEGIN
      PERFORM public.publish_catalog_batch(v_t2);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT;
    END;
    SELECT l.after_review INTO v_n FROM public.fn_batch_reviews_list() l WHERE l.batch_id = v_t2;
    -- La coordination (pas l'administration) redemande : il y a un ajout.
    v_res2 := public.fn_batch_review_request(v_t2, 'H21P : une notice rangee apres l''approbation');
    v_rev := (v_res2->>'review_id')::bigint;
    IF v_t3 IS NOT NULL AND v_t3 NOT IN (v_t1, v_t2)
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_d2) = v_t2
       AND v_h1 = 'error.publish.added_after_review'
       AND v_h2 = 'error.publish.added_after_review'
       AND (SELECT count(*) FROM public.book_drafts WHERE id IN (v_d2, v_d3) AND status = 'draft') = 2
       AND v_n = 1
       AND (v_res2->>'round')::int = 2
       AND (SELECT draft_ids FROM public.catalog_batch_reviews WHERE id = v_rev)
             = (SELECT array_agg(x ORDER BY x) FROM unnest(ARRAY[v_d2, v_d3]) x)
       AND public.fn_batch_review_status(v_t2) = 'requested'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lot de L2='||coalesce(v_t3::text,'NULL')
           ||' notice seule='||coalesce(v_h1,'NULL')||' lot entier='||coalesce(v_h2,'NULL')
           ||' after_review='||coalesce(v_n::text,'NULL')||' demande='||left(coalesce(v_res2::text,'NULL'), 120)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E7 ──────────────────────────────────────────────────────────────
  v_t := 'E7 (d) retouches demandees sur T2 : la selection [L9] rejoint T2 en retouches';
  BEGIN
    -- T3, vidé par le rangement de E6, est supprimé par la coordination (API).
    EXECUTE 'SET LOCAL ROLE authenticated';
    DELETE FROM public.catalog_batches WHERE id = v_t3;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev, 'changes_requested', 'H21P : L2 est un doublon, a ecarter');
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_l9]);
    SELECT created_book_draft_id INTO v_d9 FROM ingest.partner_catalog_staging_rows WHERE id = v_l9;
    UPDATE public.book_drafts SET bib_ref = 'H21P-REF-' || id
     WHERE marc_json->'ingest'->>'run_id' = v_run::text AND bib_ref IS NULL;
    IF NOT EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = v_t3)
       AND public.fn_batch_review_status(v_t2) = 'changes_requested'
       AND (v_res->>'batch_id')::bigint = v_t2
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_d9) = v_t2
       AND (v_res->>'items_created')::int = 1
       AND (SELECT count(*) FROM public.exemplar_drafts x
             WHERE x.book_draft_id = v_d9 AND x.batch_id = v_t2 AND x.source_item_code = 'H21P-C9') = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : T3 supprime='||(NOT EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = v_t3))
           ||' statut T2='||coalesce(public.fn_batch_review_status(v_t2),'NULL')
           ||' lot de L9='||coalesce(v_res->>'batch_id','NULL')||' (T2='||v_t2||')'); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E8 ──────────────────────────────────────────────────────────────
  v_t := 'E8 (e) L2 supprime definitivement : ligne ecartee, pas re-promue ; rejouee : la ligne lui revient, un seul brouillon meme reacceptee, garde tenue';
  BEGIN
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d2;   -- à la corbeille
    DELETE FROM public.book_drafts WHERE id = v_d2;                      -- « Vider la corbeille »
    v_ok := (SELECT editorial_decision = 'reject' AND review_status = 'rejected'
                    AND created_book_draft_id IS NULL AND NOT selected_for_draft
                    AND editorial_note LIKE '%IMP-27 e%'
               FROM ingest.partner_catalog_staging_rows WHERE id = v_l2);
    -- « Promouvoir » tout le run : rien d'éligible (une promotion inattendue
    -- est notée puis annulée).
    v_txt := NULL;
    BEGIN
      v_res := public.fn_import_promote(v_run);
      IF v_res->>'batch_id' IS NOT NULL THEN
        v_txt := 'promotion inattendue des lignes '||coalesce(v_res->>'selected_row_ids','?');
        RAISE EXCEPTION 'h21p-annule';
      END IF;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'h21p-annule' THEN v_txt := coalesce(v_txt, '')||SQLERRM; END IF;
    END;
    -- Restauration depuis le journal : la création rejouée reprend la ligne que
    -- SA suppression avait écartée (seconde passe, revue du 29/09) — décision
    -- reverrouillée (accept_new / draft_created), lien rétabli.
    SELECT max(l.id) INTO v_audit FROM public.catalog_audit_log l
     WHERE l.action = 'delete' AND l.entity_type = 'book' AND l.entity_id = v_d2;
    v_res := public.fn_restore_deleted_draft(v_audit);
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_d2;       -- sortie de corbeille
    SELECT count(*) INTO v_n FROM public.book_drafts d
     WHERE d.marc_json->'ingest'->>'staging_row_id' = v_l2::text;
    v_ok2 := (SELECT sr.created_book_draft_id = v_d2 AND sr.editorial_decision = 'accept_new'
                     AND sr.review_status = 'draft_created' AND NOT sr.selected_for_draft
                FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = v_l2)
             AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m
                          WHERE m.staging_row_id = v_l2 AND m.draft_id = v_d2 AND m.run_id = v_run);
    v_h1 := NULL;
    BEGIN
      PERFORM public.publish_book_draft(v_d2);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT;
    END;
    -- Après la restauration non plus, « Promouvoir » ne fait pas un second brouillon.
    BEGIN
      v_res2 := public.fn_import_promote(v_run);
      IF v_res2->>'batch_id' IS NOT NULL THEN
        v_txt := coalesce(v_txt, '')||' / apres restauration : promotion des lignes '||coalesce(v_res2->>'selected_row_ids','?');
        RAISE EXCEPTION 'h21p-annule';
      END IF;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'h21p-annule' THEN v_txt := coalesce(v_txt, '')||SQLERRM; END IF;
    END;
    -- … ni la réacceptation de L2 par l'API suivie de « Promouvoir la
    -- sélection » (revue du 29/09, constats 10 et 16 : l'ordre rejeu puis
    -- réacceptation). Que la décision ignore la ligne reprise ou la refuse,
    -- aucun brouillon neuf ; un brouillon neuf est noté puis annulé.
    v_msg := NULL;
    BEGIN
      BEGIN
        v_res3 := public.fn_import_set_editorial(v_run, ARRAY[v_l2], 'accept_new');
        v_msg := 'decision posee sur '||coalesce(v_res3->>'updated_rows', '?')||' ligne(s)';
      EXCEPTION WHEN OTHERS THEN v_msg := 'decision refusee : '||SQLERRM;
      END;
      v_res3 := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_l2]);
      IF v_res3->>'batch_id' IS NOT NULL THEN
        v_txt := coalesce(v_txt, '')||' / reacceptee ('||v_msg||') puis promue : lignes '||coalesce(v_res3->>'selected_row_ids','?');
        RAISE EXCEPTION 'h21p-annule';
      END IF;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'h21p-annule' THEN v_txt := coalesce(v_txt, '')||' / reacceptation : '||SQLERRM; END IF;
    END;
    SELECT count(*) INTO v_m FROM public.book_drafts d
     WHERE d.marc_json->'ingest'->>'staging_row_id' = v_l2::text;
    -- L'administration a demandé de l'écarter : retour à la corbeille. La
    -- ligne reste la sienne (un nouveau « Vider la corbeille » l'écartera).
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_d2;
    IF coalesce(v_ok, false)
       AND v_txt IS NULL
       AND (v_res->>'draft_id')::bigint = v_d2
       AND v_n = 1 AND v_m = 1
       AND coalesce(v_ok2, false)
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_d2) = v_t2
       AND v_h1 = 'error.publish.review_required'
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_l2) = v_d2
       AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.marc_json->'ingest'->>'staging_row_id' = v_l2::text)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ligne ecartee='||coalesce(v_ok::text,'NULL')
           ||' ligne reprise au rejeu='||coalesce(v_ok2::text,'NULL')
           ||' ('||coalesce((SELECT editorial_decision||'/'||review_status||'/'||coalesce(created_book_draft_id::text,'-')
                               FROM ingest.partner_catalog_staging_rows WHERE id = v_l2),'?')
           ||') re-promotion='||coalesce(v_txt,'aucune')||' brouillons de L2='||coalesce(v_n::text,'NULL')||'/'||coalesce(v_m::text,'NULL')
           ||' reacceptation='||coalesce(v_msg,'NULL')
           ||' publication restauree='||coalesce(v_h1,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E9 ──────────────────────────────────────────────────────────────
  v_t := 'E9 (b) tour 3 = {d3, d9}, approuve ; T2 publie ; H21P-9 enregistree, H21P-R jamais';
  BEGIN
    v_res := public.fn_batch_review_request(v_t2, 'H21P : doublon ecarte');
    v_rev := (v_res->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res2 := public.publish_catalog_batch(v_t2);
    SELECT published_book_id INTO v_b3 FROM public.book_drafts WHERE id = v_d3;
    SELECT published_book_id INTO v_b9 FROM public.book_drafts WHERE id = v_d9;
    IF (v_res->>'round')::int = 3
       AND (SELECT draft_ids FROM public.catalog_batch_reviews WHERE id = v_rev)
             = (SELECT array_agg(x ORDER BY x) FROM unnest(ARRAY[v_d3, v_d9]) x)
       AND (v_res2->>'books_published')::int = 2
       AND v_b3 IS NOT NULL AND v_b9 IS NOT NULL
       AND (SELECT status FROM public.book_drafts WHERE id = v_d2) = 'cancelled'
       AND (SELECT e.book_id FROM public.book_external_ids e WHERE e.library_id = v_lib AND e.scheme = v_scheme AND e.value = 'H21P-9') = v_b9
       AND NOT EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.value = 'H21P-R' OR e.book_id = v_b3)
       AND (SELECT source_record_id FROM public.books WHERE id = v_b3) IS NULL
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
             WHERE h.book_id = v_b9 AND e.library_id = v_lib AND e.source_item_code = 'H21P-C9') = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : tour='||coalesce(v_res::text,'NULL')
           ||' liste='||coalesce((SELECT draft_ids::text FROM public.catalog_batch_reviews WHERE id = v_rev),'NULL')
           ||' d3/d9='||v_d3||'/'||coalesce(v_d9::text,'NULL')||' publication='||left(coalesce(v_res2::text,'NULL'), 150)
           ||' cles='||coalesce((SELECT string_agg(e.value||'->'||e.book_id, ',') FROM public.book_external_ids e WHERE e.scheme = v_scheme), 'aucune')); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E10 ─────────────────────────────────────────────────────────────
  v_t := 'E10 (c) le lot de rapprochement passe par la revision ; contagion d''un exemplaire fait a la main ; H21P-5 sur N0';
  BEGIN
    v_res := public.fn_import_reconcile_duplicates(v_run, ARRAY[v_l5]);
    v_r5 := (v_res->>'batch_id')::bigint;
    SELECT x.id INTO v_x5 FROM public.exemplar_drafts x
     WHERE x.import_staging_row_id = v_l5 AND x.book_draft_id IS NULL AND x.source_item_code = 'H21P-C5';
    v_ok := public.fn_batch_is_imported(v_r5);
    -- (1) avant toute révision : ni l'exemplaire seul, ni le lot.
    v_h1 := NULL; v_h2 := NULL; v_h3 := NULL; v_h4 := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_x5);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT;
    END;
    BEGIN
      PERFORM public.publish_catalog_batch(v_r5);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT;
    END;
    -- (2) tour 1, approuvé.
    v_res2 := public.fn_batch_review_request(v_r5, 'H21P : exemplaires rapproches');
    v_rev := (v_res2->>'review_id')::bigint;
    v_msg := (SELECT exemplar_draft_ids::text FROM public.catalog_batch_reviews WHERE id = v_rev);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- (3) un exemplaire fait à la main, rangé dans R5 après l'approbation (API).
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, target_bib_ref, shelf_location, created_by)
    VALUES ('create', 'draft', 'pending', v_lib, 'H21P-N0', 'H21P M', v_coord) RETURNING id INTO v_xm;
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.exemplar_drafts SET batch_id = v_r5 WHERE id = v_xm;
    EXECUTE 'RESET ROLE';
    BEGIN
      PERFORM public.publish_exemplar_draft(v_xm);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h3 = PG_EXCEPTION_HINT;
    END;
    v_k := public.fn_batch_ajouts_apres_revision(v_r5);
    -- (4) la coordination redemande ; tour 2 approuvé ; le lot se publie.
    v_res2 := public.fn_batch_review_request(v_r5, 'H21P : un exemplaire ajoute');
    v_rev := (v_res2->>'review_id')::bigint;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM public.fn_batch_review_verdict(v_rev, 'approved', NULL);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_res2 := public.publish_catalog_batch(v_r5);
    IF v_r5 IS NOT NULL AND v_x5 IS NOT NULL AND v_ok
       AND v_h1 = 'error.publish.review_required'
       AND v_h2 = 'error.publish.review_required'
       AND v_msg = ('{' || v_x5 || '}')
       AND v_h3 = 'error.publish.added_after_review'
       AND v_k = 1
       AND (SELECT exemplar_draft_ids FROM public.catalog_batch_reviews WHERE id = v_rev)
             = (SELECT array_agg(x ORDER BY x) FROM unnest(ARRAY[v_x5, v_xm]) x)
       AND (v_res2->>'exemplars_published')::int = 2
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
             WHERE h.book_id = v_n0 AND e.library_id = v_lib AND e.source_item_code = 'H21P-C5' AND e.shelf_location = 'H21P 5') = 1
       AND (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
             WHERE h.book_id = v_n0 AND e.library_id = v_lib AND e.shelf_location = 'H21P M') = 1
       AND (SELECT e.book_id FROM public.book_external_ids e WHERE e.library_id = v_lib AND e.scheme = v_scheme AND e.value = 'H21P-5') = v_n0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : importe='||coalesce(v_ok::text,'NULL')
           ||' seul='||coalesce(v_h1,'NULL')||' lot='||coalesce(v_h2,'NULL')||' liste 1='||coalesce(v_msg,'NULL')
           ||' fait main='||coalesce(v_h3,'NULL')||' ajouts='||coalesce(v_k::text,'NULL')
           ||' publication='||left(coalesce(v_res2::text,'NULL'), 150)); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E11 ─────────────────────────────────────────────────────────────
  v_t := 'E11 IMP-26 h : [L5, L6] rattachees ou rapprochees, filtre explicite, tout le run : aucune notice';
  BEGIN
    v_txt := NULL;
    BEGIN
      v_res := public.fn_import_promote(v_run, p_row_ids := ARRAY[v_l5, v_l6]);
      IF v_res->>'batch_id' IS NOT NULL THEN
        v_txt := 'selection : '||coalesce(v_res->>'selected_row_ids','?'); RAISE EXCEPTION 'h21p-annule';
      END IF;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'h21p-annule' THEN v_txt := coalesce(v_txt, '')||' selection : '||SQLERRM; END IF;
    END;
    BEGIN
      v_res := public.fn_import_promote(v_run, ARRAY['matched_book', 'possible_duplicate'], ARRAY['accept_duplicate'],
                                        p_row_ids := ARRAY[v_l5, v_l6]);
      IF v_res->>'batch_id' IS NOT NULL THEN
        v_txt := coalesce(v_txt, '')||' filtre : '||coalesce(v_res->>'selected_row_ids','?'); RAISE EXCEPTION 'h21p-annule';
      END IF;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'h21p-annule' THEN v_txt := coalesce(v_txt, '')||' filtre : '||SQLERRM; END IF;
    END;
    BEGIN
      v_res := public.fn_import_promote(v_run);
      IF v_res->>'batch_id' IS NOT NULL THEN
        v_txt := coalesce(v_txt, '')||' tout le run : '||coalesce(v_res->>'selected_row_ids','?'); RAISE EXCEPTION 'h21p-annule';
      END IF;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'h21p-annule' THEN v_txt := coalesce(v_txt, '')||' tout le run : '||SQLERRM; END IF;
    END;
    IF v_txt IS NULL
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id IN (v_l5, v_l6))
       AND (SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = v_l6) = 'accept_duplicate'
       AND (SELECT created_book_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_l6) IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'liens presents')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E12 ─────────────────────────────────────────────────────────────
  v_t := 'E12 rapprochement annule : L7 en attente, pas promue ; nouveau rapprochement sans doublon, revise (c)';
  BEGIN
    v_res := public.fn_import_reconcile_duplicates(v_run, ARRAY[v_l7]);
    v_r7 := (v_res->>'batch_id')::bigint;
    SELECT x.id INTO v_x7 FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_l7 AND x.batch_id = v_r7;
    UPDATE public.exemplar_drafts SET status = 'cancelled' WHERE id = v_x7;
    v_ok := (SELECT editorial_decision = 'pending' AND created_exemplar_draft_id IS NULL
               FROM ingest.partner_catalog_staging_rows WHERE id = v_l7);
    v_txt := NULL;
    BEGIN
      v_res := public.fn_import_promote(v_run);
      IF v_res->>'batch_id' IS NOT NULL THEN
        v_txt := 'promotion de '||coalesce(v_res->>'selected_row_ids','?'); RAISE EXCEPTION 'h21p-annule';
      END IF;
    EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'h21p-annule' THEN v_txt := coalesce(v_txt, '')||SQLERRM; END IF;
    END;
    v_res := public.fn_import_reconcile_duplicates(v_run, ARRAY[v_l7]);
    v_r7b := (v_res->>'batch_id')::bigint;
    SELECT x.id INTO v_x7b FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_l7 AND x.batch_id = v_r7b;
    v_h1 := NULL;
    BEGIN
      PERFORM public.publish_exemplar_draft(v_x7b);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT;
    END;
    IF coalesce(v_ok, false) AND v_txt IS NULL
       AND v_r7b IS NOT NULL AND v_r7b <> v_r7
       AND (SELECT count(*) FROM public.exemplar_drafts x
             WHERE x.import_staging_row_id = v_l7 AND x.status IN ('draft', 'ready', 'published')) = 1
       AND (SELECT created_exemplar_draft_id FROM ingest.partner_catalog_staging_rows WHERE id = v_l7) = v_x7b
       AND (SELECT status FROM public.exemplar_drafts WHERE id = v_x7) = 'cancelled'
       AND v_h1 = 'error.publish.review_required'
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.source_item_code = 'H21P-C7')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : en attente='||coalesce(v_ok::text,'NULL')
           ||' promotion='||coalesce(v_txt,'aucune')||' vivants='||(SELECT count(*) FROM public.exemplar_drafts x
             WHERE x.import_staging_row_id = v_l7 AND x.status IN ('draft', 'ready', 'published'))
           ||' publication avant revision='||coalesce(v_h1,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E13 ─────────────────────────────────────────────────────────────
  v_t := 'E13 le run ne se supprime pas sous son travail : refus dit, run et lignes intacts';
  BEGIN
    v_h1 := NULL;
    BEGIN
      PERFORM public.fn_import_delete_run(v_run);
      RAISE EXCEPTION 'H21P accepte a tort' USING HINT = 'h21p.accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT;
    END;
    -- Le premier refus rencontré : brouillons des lots du run, brouillon lié
    -- hors de son lot, ou (seconde passe, revue du 29/09) exemplaire rapproché
    -- à la corbeille — celui de L7 (E12), seul à retenir le run quand rien
    -- n'a été promu.
    IF v_h1 IN ('error.import.run_has_drafts', 'error.import.run_has_linked_drafts', 'error.import.run_has_trashed_items')
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run)
       AND (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run) = 9
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── E14 ─────────────────────────────────────────────────────────────
  v_t := 'E14 invariants : une notice par cle ; rien ne nait d''une ligne rattachee ; tout publie l''est sous un tour approuve qui le couvre';
  BEGIN
    v_txt := NULL;
    -- (i) au plus une notice par clé d'origine ; les clés attendues, exactement.
    IF EXISTS (SELECT 1 FROM public.book_external_ids e WHERE e.scheme = v_scheme
                GROUP BY e.value HAVING count(DISTINCT e.book_id) > 1) THEN
      v_txt := concat_ws(' ; ', v_txt, 'une cle pour deux notices');
    END IF;
    IF (SELECT string_agg(e.value || '=' || CASE e.book_id WHEN v_b1 THEN 'b1' WHEN v_b8 THEN 'b8' WHEN v_b9 THEN 'b9'
                                                        WHEN v_n0 THEN 'N0' ELSE e.book_id::text END, ',' ORDER BY e.value)
          FROM public.book_external_ids e WHERE e.scheme = v_scheme AND e.library_id = v_lib)
       IS DISTINCT FROM 'H21P-1=b1,H21P-5=N0,H21P-8=b8,H21P-9=b9' THEN
      v_txt := concat_ws(' ; ', v_txt, 'cles : ' || coalesce((SELECT string_agg(e.value || '->' || e.book_id, ',' ORDER BY e.value)
                                                               FROM public.book_external_ids e WHERE e.scheme = v_scheme), 'aucune'));
    END IF;
    IF EXISTS (SELECT 1 FROM public.books b WHERE b.marc_json->'ingest'->>'run_id' = v_run::text
                GROUP BY b.marc_json->'ingest'->>'staging_row_id' HAVING count(*) > 1)
       OR EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'run_id' = v_run::text
                   AND d.status <> 'cancelled'
                   GROUP BY d.marc_json->'ingest'->>'staging_row_id' HAVING count(*) > 1) THEN
      v_txt := concat_ws(' ; ', v_txt, 'deux notices pour une ligne');
    END IF;
    IF (SELECT count(*) FROM public.books b WHERE b.marc_json->'ingest'->>'run_id' = v_run::text) <> 4 THEN
      v_txt := concat_ws(' ; ', v_txt, 'notices du run : ' || (SELECT count(*) FROM public.books b WHERE b.marc_json->'ingest'->>'run_id' = v_run::text));
    END IF;
    -- (ii) aucune notice née d'une ligne rattachée ou rapprochée.
    IF EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.marc_json->'ingest'->>'staging_row_id' IN (v_l5::text, v_l6::text, v_l7::text))
       OR EXISTS (SELECT 1 FROM public.books b WHERE b.marc_json->'ingest'->>'staging_row_id' IN (v_l5::text, v_l6::text, v_l7::text))
       OR EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft m WHERE m.staging_row_id IN (v_l5, v_l6, v_l7))
       OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows sr WHERE sr.id IN (v_l5, v_l6, v_l7) AND sr.created_book_draft_id IS NOT NULL) THEN
      v_txt := concat_ws(' ; ', v_txt, 'une notice nee d''une ligne rattachee');
    END IF;
    -- (iii) tout ce qui est publié l'est sous le DERNIER tour de son lot,
    -- approuvé, qui le couvre.
    SELECT count(*) FILTER (WHERE NOT coalesce(r.ok, false)), count(*) INTO v_n, v_m
      FROM public.book_drafts d
      LEFT JOIN LATERAL (
        SELECT x.status = 'approved' AND (x.draft_ids IS NULL OR d.id = ANY (x.draft_ids)) AS ok
          FROM public.catalog_batch_reviews x WHERE x.batch_id = d.batch_id ORDER BY x.round DESC LIMIT 1) r ON true
     WHERE d.marc_json->'ingest'->>'run_id' = v_run::text AND d.status = 'published';
    IF v_n <> 0 OR v_m <> 4 THEN
      v_txt := concat_ws(' ; ', v_txt, 'notices publiees hors tour couvrant : ' || v_n || '/' || v_m);
    END IF;
    SELECT count(*) FILTER (WHERE NOT coalesce(r.ok, false)), count(*) INTO v_n, v_m
      FROM public.exemplar_drafts xd
      LEFT JOIN LATERAL (
        SELECT x.status = 'approved' AND (x.exemplar_draft_ids IS NULL OR xd.id = ANY (x.exemplar_draft_ids)) AS ok
          FROM public.catalog_batch_reviews x WHERE x.batch_id = xd.batch_id ORDER BY x.round DESC LIMIT 1) r ON true
     WHERE xd.book_draft_id IS NULL AND xd.status = 'published'
       AND (xd.import_staging_row_id IN (SELECT sr.id FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = v_run)
            OR xd.batch_id IN (v_r5, v_r7, v_r7b));
    IF v_n <> 0 OR v_m <> 2 THEN
      v_txt := concat_ws(' ; ', v_txt, 'exemplaires publies hors tour couvrant : ' || v_n || '/' || v_m);
    END IF;
    IF v_txt IS NULL
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H21-LOT0-PARCOURS OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'H21-LOT0-PARCOURS ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
