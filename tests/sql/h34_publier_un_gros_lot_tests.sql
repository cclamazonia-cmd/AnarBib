-- =====================================================================
-- AnarBib — Tests d'acceptation : publier un gros lot importé (H34)
-- Date    : 2026-10-12
-- Ref     : migration 20261012153013_h34_publier_un_gros_lot
--
-- Aucune règle n'est posée ici : la disponibilité d'un fonds (exemplaires
-- publics non retirés, moins prêts, réservations et PEB ouverts), celle d'une
-- notice (le dernier fonds recompté ; depuis B41, 20/10/2026, la somme de
-- tous ses fonds), le numéro d'inventaire (le plus grand
-- jamais attribué sous le préfixe, plus un — C17, CAT-E21) et les gardes de
-- la publication d'un lot sont ceux d'avant ; la suite prouve que la
-- publication les rend tels quels, puis mesure.
--
-- Fixture (bibliothèque BLMF du seed, coordination 1111…, administration
-- 2222…, préfixe H34T- sur 5 chiffres) : un fond aux volumes de la
-- production (2 700 notices, fonds et exemplaires H34T-00001 à H34T-02700 ;
-- production le 12/10 : 2 567 notices, 2 659 fonds, 2 762 exemplaires) ;
-- H34T-02700 a été donné puis supprimé (il reste au registre) ; prêts,
-- réservations et PEB ouverts sur les notices 1 à 12 ; les notices 1 à 20
-- détenues aussi par une bibliothèque B ; le fonds 21 au compte périmé (99),
-- que le lot ne touche pas. Un run : 25 lignes nouvelles x 20 exemplaires
-- (promues) et 20 lignes rapprochées x 3 exemplaires sur les notices 1 à 20,
-- dans le même lot, dont un exemplaire sur sept « staff_only » ; revue
-- demandée, approuvée.
--
-- T01 mesure : publish_catalog_batch du lot (25 notices, 560 exemplaires),
--     sous le jeton de la coordination, < 8 s (NOTICE H34-MESURE ; au banc,
--     12/10, fond identique : 500 exemplaires 10,0 s avant H34, 1,7 s après ;
--     5 000 exemplaires 132 s avant, 18,5 s après — voir le rapport H34).
-- T02 disponibilité : chaque fonds du réseau égale, colonne par colonne,
--     le compte de la définition d'avant (exemplaires publics non retirés,
--     prêts, réservations, PEB — copiée ici, sur tout le réseau) ; chaque
--     notice touchée vaut la somme de tous ses fonds (B41, 20/10/2026 ;
--     avant, le dernier recompté) ; un fonds et une notice que le lot ne touche pas sont intacts
--     (le fonds 21 garde son 99 : pas de recompte du réseau).
-- T03 une fois par fonds touché : pendant la publication, le déclencheur de
--     l'exemplaire tire 560 fois et ne recompte rien ; la disponibilité est
--     recomptée par UN appel, sur les 45 fonds touchés.
-- T04 la circulation garde son recompte immédiat : après la publication (le
--     drapeau est tombé), un exemplaire passé « staff_only », un prêt ouvert,
--     un exemplaire supprimé recomptent leur fonds tout de suite ; hors
--     publication, private.fn_h34_noter_fonds rend false.
-- T05 numéros : uniques, croissants dans l'ordre des exemplaires, de
--     H34T-02701 à H34T-03260 sans trou — H34T-02700, donné puis supprimé,
--     n'est pas redonné ; tous au registre.
-- T06 fn_next_tombo par index rend ce que rend la lecture d'avant (copiée
--     ici) sur 12 séries : largeurs mêlées, suffixes non numériques, préfixe
--     voisin, numéro au registre seul, préfixe vide, préfixe finissant par un
--     chiffre (repli), préfixe à « _ » ou « % » (repli).
-- T07 mesure : fn_next_tombo pendant la publication < 1 ms par numéro en
--     moyenne (avant H34 : ~5,5 ms à ces volumes, la série relue à chaque
--     numéro ; après, ~0,1 ms).
-- T08 gardes : publier le lot d'une autre bibliothèque, ou sans rôle de
--     catalogage, est refusé (error.catalog.staff_only) ; fn_next_tombo hors
--     du personnel de la bibliothèque : 42501 ; sans schéma : P0001 ; le
--     verrou d'avis par préfixe est pris (pg_locks).
-- T09 aides fermées : private.fn_h34_noter_fonds et
--     private.fn_h34_recompter_fonds_notes refusées à authenticated et anon.
-- T10 une notice à deux fonds notés : recomptés (depuis B41, d'un seul appel) ;
--     la notice vaut la somme des deux (B41, 20/10/2026 ; avant, le dernier
--     recompté) ; le drapeau tombe.
-- T11 pendant un lot, un exemplaire qui change de fonds fait noter le nouveau
--     puis l'ancien, une suppression le sien ; rien n'est recompté avant la
--     fin ; puis chacun l'est (même choix de fonds que le recompte immédiat).
-- H34 lot 2 (12/10/2026, REGISTRE IMP-36, migration
-- 20261012173204_h34_lot2_publier_par_pages) : un lot approuvé se publie par
-- pages (au plus 60 notices et 400 exemplaires par appel ; une notice et ses
-- exemplaires rattachés dans la même page). T01 publie désormais son lot en
-- deux pages (chacune < 8 s) et T03 compte un recompte par page.
-- T12 un gros lot (200 notices x 10 exemplaires, 30 lignes rapprochées x 2,
--     3 mises à jour de notices du fond, 1 exemplaire fait à la main) en
--     6 pages, chacune < 8 s sous le jeton de la coordination : « publishing »
--     jusqu'à la dernière, aucune notice publiée sans tous ses exemplaires
--     rattachés à la fin de sa page, chaque brouillon publié une fois, aucun
--     sauté (NOTICE H34-MESURE ; au banc, 12/10 : ~2,4 à 2,8 s par page pleine).
-- T13 le même lot publié d'un bloc (borne levée le temps d'un sous-bloc annulé)
--     et par pages : base identique — fonds, notices, exemplaires (numéros
--     compris), brouillons, lot — colonne par colonne, par clés naturelles.
-- T14 une page coupée en route (sous-bloc annulé) puis une page refusée (un
--     exemplaire posé entre-temps porte le code d'un rapproché :
--     error.publish.source_item_code_taken) : ni l'une ni l'autre n'écrit,
--     la page d'avant reste, le lot reste « publishing ».
-- T15 pendant « publishing », sous la coordination puis l'administration :
--     retoucher une notice ou un exemplaire, sortir un brouillon du lot, en
--     ajouter un, en supprimer un, changer l'état du lot, poser les cotes,
--     publier un brouillon seul — refusés (error.batch.publishing_locked ou le
--     refus d'un lot non ouvert) ; « publishing » ne se pose ni ne se lève à la
--     main, même hors API.
-- T16 un nouveau tour de révision (administration) rouvre le lot : retouche
--     permise, publication refusée (error.publish.review_required) jusqu'à
--     l'approbation, pages publiées intactes.
-- T17 la reprise, la cause du refus levée : la page refusée se publie, le lot
--     est publié, chaque brouillon une fois, la retouche d'après réouverture
--     publiée.
-- T18 droits sur un lot « publishing » (sans rôle : error.catalog.staff_only),
--     aides fermées.
-- T19 un petit lot (une page) : publié d'un appel, jamais « publishing »,
--     réponse aux trois comptes d'avant (plus done, remaining, page).
-- Deux appels concurrents sur le même lot (verrou FOR UPDATE NOWAIT, second
-- appel refusé : error.batch.publication_busy) ne se testent pas dans une
-- session : banc de deux sessions, scratchpad h34/l2/concurrence2.sh.
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'H34-PUBLIER-UN-GROS-LOT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin uuid := '22222222-2222-2222-2222-222222222222';  -- administration du réseau (posée ici)
  v_lect  uuid := '33333333-3333-3333-3333-333333333333';  -- lectrice BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB  uuid := gen_random_uuid();
  v_src bigint; v_run bigint; v_ids bigint[]; v_idk bigint[]; v_lot bigint; v_rev jsonb; v_res jsonb;
  v_emp bigint; v_resv bigint; v_ill bigint;
  v_t0 timestamptz; v_ms numeric; v_f0 jsonb; v_f1 jsonb;
  v_e text; v_n int; v_x text; v_h bigint; v_b bigint;
BEGIN
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "H34T-", "year": false, "pad": 5}'::jsonb,
         bib_ref_auto = true, bib_ref_prefix = 'H34T-REF-', bib_ref_pad = 5 WHERE id = v_lib;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level, tombo_pattern)
  VALUES (v_libB, 'h34-tests-b', 'H34 Biblio B', true, 'public', '{"prefix": "H34B-", "year": false, "pad": 4}'::jsonb);

  -- le fond
  CREATE TEMP TABLE h34_b ON COMMIT DROP AS
  WITH b AS (INSERT INTO public.books (titulo, bib_ref)
             SELECT 'H34 fond ' || i, 'H34T-FREF-' || i FROM generate_series(1, 2700) i RETURNING id, bib_ref)
  SELECT b.*, row_number() OVER (ORDER BY id) AS k FROM b;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) SELECT id, v_lib, true FROM h34_b;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) SELECT id, v_libB, true FROM h34_b WHERE k <= 20;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy)
  SELECT b.bib_ref, 'H34T-' || lpad(b.k::text, 5, '0'), v_lib, h.id, 'ambos'
    FROM h34_b b JOIN public.book_holdings h ON h.book_id = b.id AND h.library_id = v_lib;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy)
  SELECT b.bib_ref, 'H34B-' || b.k, v_libB, h.id, 'ambos'
    FROM h34_b b JOIN public.book_holdings h ON h.book_id = b.id AND h.library_id = v_libB;
  DELETE FROM public.exemplares WHERE tombo = 'H34T-02700';   -- donné, puis retiré par erreur : il reste pris
  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
  VALUES (v_lect, v_lib, 'aberto', current_date + 30) RETURNING id INTO v_emp;
  INSERT INTO public.emprestimo_itens_v2 (emprestimo_id, line_no, sub_id, book_id, item_id, holding_id, bib_ref, due_at)
  SELECT v_emp, b.k, v_emp || '.' || b.k, h.book_id, e.id, e.holding_id, e.bib_ref, current_date + 30
    FROM h34_b b JOIN public.book_holdings h ON h.book_id = b.id AND h.library_id = v_lib
    JOIN public.exemplares e ON e.holding_id = h.id WHERE b.k <= 4;
  INSERT INTO public.reservas_v2 (user_id, library_id, status_global) VALUES (v_lect, v_lib, 'ativa') RETURNING id INTO v_resv;
  INSERT INTO public.reserva_linhas_v2 (reserva_id, line_no, book_id, item_id, holding_id, bib_ref)
  SELECT v_resv, b.k, h.book_id, NULL, h.id, b.bib_ref
    FROM h34_b b JOIN public.book_holdings h ON h.book_id = b.id AND h.library_id = v_lib WHERE b.k BETWEEN 5 AND 8;
  INSERT INTO public.interlibrary_loans_v2 (lender_library_id, borrower_library_id, initiated_by_library_id, status_global)
  VALUES (v_lib, v_libB, v_lib, 'preparacao') RETURNING id INTO v_ill;
  INSERT INTO public.interlibrary_loan_items_v2 (interlibrary_loan_id, line_no, book_id, holding_id, item_id, bib_ref, item_status)
  SELECT v_ill, b.k, h.book_id, e.holding_id, e.id, e.bib_ref, 'reservado_para_saida'
    FROM h34_b b JOIN public.book_holdings h ON h.book_id = b.id AND h.library_id = v_lib
    JOIN public.exemplares e ON e.holding_id = h.id WHERE b.k BETWEEN 9 AND 12;
  UPDATE public.book_holdings h SET exemplares_total = 99, available_count = 99
    FROM h34_b b WHERE b.id = h.book_id AND b.k = 21 AND h.library_id = v_lib;

  -- le run et son lot
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H34 S', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h34t.iso', 'h34t.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  WITH ins AS (
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, publisher, publication_year,
                                                     normalized_payload, raw_payload, match_status, editorial_decision)
    SELECT v_run, r, 'H34N-' || r, 'H34 nouvelle ' || r, jsonb_build_array('Autrice H34 ' || r), 'Editions H34', '2001',
           jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', 'H34N-' || r || '-' || j,
                                                                          'source_item_id', 'n' || r || '-' || j, 'call_number', 'C ' || j))
                                          FROM generate_series(1, 20) j)),
           '{"item_tag":"995"}'::jsonb, 'new_record', 'pending'
      FROM generate_series(1, 25) r RETURNING id)
  SELECT array_agg(id ORDER BY id) INTO v_ids FROM ins;
  WITH ins AS (
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, normalized_payload, raw_payload,
                                                     match_status, editorial_decision, proposed_book_id)
    SELECT v_run, 100 + b.k, 'H34K-' || b.k, 'H34 rapprochée ' || b.k,
           jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', 'H34K-' || b.k || '-' || j,
                                                                          'source_item_id', 'k' || b.k || '-' || j, 'call_number', 'K ' || j))
                                          FROM generate_series(1, 3) j)),
           '{"item_tag":"995"}'::jsonb, 'known_record', 'pending', b.id
      FROM h34_b b WHERE b.k <= 20 RETURNING id)
  SELECT array_agg(id ORDER BY id) INTO v_idk FROM ins;
  ANALYZE public.books; ANALYZE public.book_holdings; ANALYZE public.exemplares; ANALYZE public.tombos_attribues;
  ANALYZE ingest.partner_catalog_staging_rows;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.fn_import_set_editorial(v_run, v_ids, 'accept_new', 'page import: validation individuelle');
  v_res := public.fn_import_promote(v_run, p_row_ids := v_ids);
  v_lot := (v_res->>'batch_id')::bigint;
  PERFORM public.fn_import_reconcile_duplicates(v_run, v_idk);
  EXECUTE 'RESET ROLE';
  UPDATE public.exemplar_drafts SET visibility = 'staff_only' WHERE batch_id = v_lot AND id % 7 = 0;
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.fn_batch_assign_bib_refs(v_lot, true);
  v_rev := public.fn_batch_review_request(v_lot, NULL);
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.fn_batch_review_verdict((v_rev->>'review_id')::bigint, 'approved', NULL);
  EXECUTE 'RESET ROLE';
  ANALYZE public.exemplar_drafts; ANALYZE public.book_drafts;

  -- l'état d'avant, pour ce que le lot ne touche pas
  CREATE TEMP TABLE h34_h0 ON COMMIT DROP AS SELECT id, book_id, library_id, exemplares_total, available_count, updated_at FROM public.book_holdings;
  CREATE TEMP TABLE h34_b0 ON COMMIT DROP AS SELECT id, available_count, updated_at FROM public.books;

  -- ── T01 ─────────────────────────────────────────────────────────────
  v_t := 'T01 mesure : publier un lot importé de 25 notices et 560 exemplaires, chaque page < 8 s';
  DECLARE v_pages int := 0; v_max numeric := 0; v_b int := 0; v_x int := 0; v_d text := '';
  BEGIN
    -- (SET et non set_config : la plate-forme n'ouvre ce réglage qu'à la commande SET)
    EXECUTE 'SET LOCAL track_functions = ''all''';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    SELECT coalesce(jsonb_object_agg(schemaname || '.' || funcname, jsonb_build_array(calls, total_time)), '{}') INTO v_f0
      FROM pg_stat_xact_user_functions;
    -- H34 lot 2 : par pages (400 exemplaires au plus : 20 notices et leurs
    -- 400 exemplaires, puis 5 notices, leurs 100 exemplaires et les 60 rapprochés)
    v_t0 := clock_timestamp();
    LOOP
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_ms := extract(epoch FROM clock_timestamp()) * 1000;
      v_res := public.publish_catalog_batch(v_lot);
      v_ms := extract(epoch FROM clock_timestamp()) * 1000 - v_ms;
      EXECUTE 'RESET ROLE';
      v_pages := v_pages + 1; v_max := greatest(v_max, v_ms);
      v_b := v_b + (v_res->>'books_published')::int; v_x := v_x + (v_res->>'exemplars_published')::int;
      v_d := v_d || ' ' || round(v_ms);
      EXIT WHEN (v_res->>'done')::boolean OR v_pages >= 10;
    END LOOP;
    v_ms := extract(epoch FROM clock_timestamp() - v_t0) * 1000;
    SELECT coalesce(jsonb_object_agg(schemaname || '.' || funcname, jsonb_build_array(calls, total_time)), '{}') INTO v_f1
      FROM pg_stat_xact_user_functions;
    RAISE NOTICE 'H34-MESURE publier un lot de 25 notices / 560 exemplaires (fond de 2 700) : % ms en % page(s) (% ms) ; dernière %',
      round(v_ms), v_pages, trim(v_d), v_res;
    IF v_b = 25 AND v_x = 60 AND v_pages = 2
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot AND status = 'published') = 560
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lot) = 'published'
       AND v_max < coalesce(nullif(current_setting('anarbib.budget_ms', true), '')::int, 8000)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_pages||' page(s), '||trim(v_d)||' ms ; '||coalesce(v_res::text, 'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T02 ─────────────────────────────────────────────────────────────
  v_t := 'T02 disponibilité : chaque fonds égale le compte d''avant ; une notice vaut son fonds ; le non-touché est intact';
  BEGIN
    v_e := '';
    -- la définition d'avant, sur TOUT le réseau (fn_v2_recompute_holdings_availability,
    -- md5 c33cfe1c…, agrégats sans filtre), pour chaque fonds
    WITH exemplar_counts AS (
      SELECT e.holding_id, count(*)::int AS n FROM public.exemplares e
       WHERE e.holding_id IS NOT NULL AND e.visibility = 'public' AND e.retire_at IS NULL GROUP BY e.holding_id),
    open_loans AS (
      SELECT e.holding_id, count(*)::int AS n FROM public.emprestimo_itens_v2 i JOIN public.exemplares e ON e.id = i.item_id
       WHERE i.item_status = 'aberto' AND e.holding_id IS NOT NULL AND e.visibility = 'public' AND e.retire_at IS NULL GROUP BY e.holding_id),
    active_reservas AS (
      SELECT rl.holding_id, count(*)::int AS n FROM public.reserva_linhas_v2 rl
       WHERE rl.item_status = 'ativa' AND rl.holding_id IS NOT NULL GROUP BY rl.holding_id),
    open_ill AS (
      SELECT coalesce(e.holding_id, il.holding_id) AS holding_id, count(*)::int AS n
        FROM public.interlibrary_loan_items_v2 il JOIN public.interlibrary_loans_v2 l ON l.id = il.interlibrary_loan_id
        LEFT JOIN public.exemplares e ON e.id = il.item_id
       WHERE il.item_status IN ('reservado_para_saida', 'emprestado') AND l.status_global NOT IN ('devolvido', 'cancelado')
         AND coalesce(e.holding_id, il.holding_id) IS NOT NULL GROUP BY 1),
    attendu AS (
      SELECT h.id, coalesce(ec.n, 0) AS total,
             greatest(coalesce(ec.n, 0) - coalesce(ol.n, 0) - coalesce(ar.n, 0) - coalesce(oi.n, 0), 0) AS dispo
        FROM public.book_holdings h
        LEFT JOIN exemplar_counts ec ON ec.holding_id = h.id LEFT JOIN open_loans ol ON ol.holding_id = h.id
        LEFT JOIN active_reservas ar ON ar.holding_id = h.id LEFT JOIN open_ill oi ON oi.holding_id = h.id)
    -- les fonds touchés par le lot (45), et ceux du fond posés avant lui (2 700 + 20 de B)
    SELECT count(*) FILTER (WHERE (h.exemplares_total, h.available_count) IS DISTINCT FROM (a.total, a.dispo)),
           count(*) FILTER (WHERE EXISTS (SELECT 1 FROM public.exemplares e JOIN public.exemplar_drafts x ON x.published_exemplar_id = e.id
                                           WHERE x.batch_id = v_lot AND e.holding_id = h.id))
      INTO v_n, v_h
      FROM public.book_holdings h JOIN attendu a ON a.id = h.id
      LEFT JOIN h34_b b ON b.id = h.book_id
     WHERE (b.id IS NOT NULL OR EXISTS (SELECT 1 FROM public.exemplares e JOIN public.exemplar_drafts x ON x.published_exemplar_id = e.id
                                         WHERE x.batch_id = v_lot AND e.holding_id = h.id))
       AND NOT coalesce(b.k = 21 AND h.library_id = v_lib, false);   -- le fonds périmé, non touché (plus bas)
    IF v_n <> 0 OR v_h <> 45 THEN v_e := v_e || ' fonds-ecart(' || v_n || ' sur ' || v_h || ' touchés)'; END IF;
    -- les fonds touchés : comptes attendus, à la main
    SELECT h.exemplares_total || '/' || h.available_count INTO v_x
      FROM public.book_holdings h JOIN h34_b b ON b.id = h.book_id WHERE b.k = 1 AND h.library_id = v_lib;
    IF v_x IS DISTINCT FROM (SELECT (1 + count(*) FILTER (WHERE x.visibility = 'public')) || '/' || (count(*) FILTER (WHERE x.visibility = 'public'))
                               FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id
                               JOIN public.book_holdings h ON h.id = e.holding_id JOIN h34_b b ON b.id = h.book_id
                              WHERE x.batch_id = v_lot AND b.k = 1) THEN
      v_e := v_e || ' fonds-1(' || coalesce(v_x, '∅') || ')';
    END IF;
    -- chaque notice touchée vaut la somme de TOUS ses fonds (B41, 20/10/2026 :
    -- avant, le dernier recompté seulement — les notices 1 à 20 perdaient B)
    SELECT count(*) INTO v_n
      FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id
      JOIN public.book_holdings h ON h.id = e.holding_id JOIN public.books bk ON bk.id = h.book_id
     WHERE x.batch_id = v_lot
       AND bk.available_count IS DISTINCT FROM (SELECT sum(t.available_count) FROM public.book_holdings t WHERE t.book_id = bk.id);
    IF v_n <> 0 THEN v_e := v_e || ' notices-ecart(' || v_n || ')'; END IF;
    -- le non-touché : fonds 21 (99), fonds de B, notices 21..2700, intacts (updated_at compris)
    IF (SELECT h.exemplares_total || '/' || h.available_count FROM public.book_holdings h JOIN h34_b b ON b.id = h.book_id
         WHERE b.k = 21 AND h.library_id = v_lib) <> '99/99' THEN v_e := v_e || ' perime-recompte'; END IF;
    SELECT count(*) INTO v_n FROM public.book_holdings h JOIN h34_h0 o ON o.id = h.id
     WHERE NOT EXISTS (SELECT 1 FROM public.exemplares e JOIN public.exemplar_drafts x ON x.published_exemplar_id = e.id
                        WHERE x.batch_id = v_lot AND e.holding_id = h.id)
       AND (h.exemplares_total, h.available_count, h.updated_at) IS DISTINCT FROM (o.exemplares_total, o.available_count, o.updated_at);
    IF v_n <> 0 THEN v_e := v_e || ' fonds-non-touches-changes(' || v_n || ')'; END IF;
    SELECT count(*) INTO v_n FROM public.books bk JOIN h34_b0 o ON o.id = bk.id JOIN h34_b b ON b.id = bk.id
     WHERE b.k > 20 AND (bk.available_count, bk.updated_at) IS DISTINCT FROM (o.available_count, o.updated_at);
    IF v_n <> 0 THEN v_e := v_e || ' notices-non-touchees-changees(' || v_n || ')'; END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T03 ─────────────────────────────────────────────────────────────
  v_t := 'T03 une fois par fonds touché : 560 déclenchements, un recompte par page (2), sur les 45 fonds touchés';
  BEGIN
    v_e := '';
    IF coalesce((v_f1->'public.fn_recompute_holdings_on_exemplar_change'->>0)::bigint, 0)
       - coalesce((v_f0->'public.fn_recompute_holdings_on_exemplar_change'->>0)::bigint, 0) <> 560 THEN
      v_e := v_e || ' declencheur(' || coalesce((v_f1->'public.fn_recompute_holdings_on_exemplar_change'->>0)::bigint, 0)
                                    - coalesce((v_f0->'public.fn_recompute_holdings_on_exemplar_change'->>0)::bigint, 0) || ')';
    END IF;
    v_n := coalesce((v_f1->'public.fn_v2_recompute_holdings_availability'->>0)::bigint, 0)
         - coalesce((v_f0->'public.fn_v2_recompute_holdings_availability'->>0)::bigint, 0);
    IF v_n <> 2 THEN v_e := v_e || ' recomptes(' || v_n || ')'; END IF;   -- H34 lot 2 : un par page
    IF (SELECT count(DISTINCT e.holding_id) FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id
         WHERE x.batch_id = v_lot) <> 45 THEN v_e := v_e || ' fonds-touches'; END IF;
    IF coalesce(current_setting('anarbib.h34_disponibilite_differee', true), '') <> ''
       OR coalesce(current_setting('anarbib.h34_fonds_notes', true), '') <> '' THEN
      v_e := v_e || ' drapeau-reste';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T04 ─────────────────────────────────────────────────────────────
  v_t := 'T04 la circulation garde son recompte immédiat';
  DECLARE v_ex bigint; v_ex2 bigint; v_av text; v_ap text;
  BEGIN
    v_e := '';
    SELECT e.id, e.holding_id INTO v_ex, v_h
      FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id
     WHERE x.batch_id = v_lot AND x.book_draft_id IS NOT NULL AND e.visibility = 'public' ORDER BY e.id LIMIT 1;
    SELECT e.id INTO v_ex2 FROM public.exemplares e WHERE e.holding_id = v_h AND e.visibility = 'public' AND e.id <> v_ex ORDER BY e.id LIMIT 1;
    SELECT exemplares_total || '/' || available_count INTO v_av FROM public.book_holdings WHERE id = v_h;
    UPDATE public.exemplares SET visibility = 'staff_only' WHERE id = v_ex;
    SELECT exemplares_total || '/' || available_count INTO v_ap FROM public.book_holdings WHERE id = v_h;
    IF v_ap IS DISTINCT FROM ((split_part(v_av, '/', 1)::int - 1) || '/' || (split_part(v_av, '/', 2)::int - 1)) THEN
      v_e := v_e || ' visibilite(' || v_av || '->' || coalesce(v_ap, '∅') || ')';
    END IF;
    INSERT INTO public.emprestimo_itens_v2 (emprestimo_id, line_no, sub_id, book_id, item_id, holding_id, bib_ref, due_at)
    SELECT v_emp, 9001, v_emp || '.9001', h.book_id, e.id, e.holding_id, e.bib_ref, current_date + 30
      FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE e.id = v_ex2;
    -- le prêt est compté au prochain recompte de son fonds (comme avant : la circulation
    -- l'appelle) ; un exemplaire supprimé recompte tout de suite
    PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_h]);
    SELECT exemplares_total || '/' || available_count INTO v_av FROM public.book_holdings WHERE id = v_h;
    IF v_av IS DISTINCT FROM (split_part(v_ap, '/', 1) || '/' || (split_part(v_ap, '/', 2)::int - 1)) THEN
      v_e := v_e || ' pret(' || v_ap || '->' || coalesce(v_av, '∅') || ')';
    END IF;
    DELETE FROM public.emprestimo_itens_v2 WHERE emprestimo_id = v_emp AND line_no = 9001;
    -- un exemplaire du fond supprimé : son fonds passe de 1/1 à 0/0 tout de suite
    SELECT h.id INTO v_h FROM public.book_holdings h JOIN h34_b b ON b.id = h.book_id WHERE b.k = 2000 AND h.library_id = v_lib;
    DELETE FROM public.exemplares WHERE holding_id = v_h;
    SELECT exemplares_total || '/' || available_count INTO v_ap FROM public.book_holdings WHERE id = v_h;
    IF v_ap IS DISTINCT FROM '0/0' THEN v_e := v_e || ' suppression(1/1->' || coalesce(v_ap, '∅') || ')'; END IF;
    IF private.fn_h34_noter_fonds(ARRAY[v_h]) THEN v_e := v_e || ' noter-hors-lot'; END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T05 ─────────────────────────────────────────────────────────────
  v_t := 'T05 numéros : uniques, croissants, de H34T-02701 à H34T-03260, jamais redonnés, au registre';
  BEGIN
    v_e := '';
    WITH t AS (
      SELECT e.id, e.tombo, (substring(e.tombo FROM 6))::int AS n
        FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id WHERE x.batch_id = v_lot)
    SELECT CASE WHEN count(*) <> 560 THEN ' nombre(' || count(*) || ')' ELSE '' END
        || CASE WHEN count(DISTINCT tombo) <> count(*) THEN ' doublons' ELSE '' END
        || CASE WHEN bool_or(tombo !~ '^H34T-[0-9]{5}$') THEN ' forme' ELSE '' END
        || CASE WHEN min(n) <> 2701 THEN ' debut(' || min(n) || ')' ELSE '' END
        || CASE WHEN max(n) <> 3260 THEN ' fin(' || max(n) || ')' ELSE '' END   -- 560 numéros de 2701 à 3260 : sans trou
      INTO v_x FROM t;
    v_e := v_e || coalesce(v_x, ' aucun');
    -- croissants dans l'ordre des exemplaires (identifiants)
    IF EXISTS (SELECT 1 FROM (SELECT (substring(e.tombo FROM 6))::int AS n, lag((substring(e.tombo FROM 6))::int) OVER (ORDER BY e.id) AS p
                                FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id
                               WHERE x.batch_id = v_lot) s WHERE s.n <= s.p) THEN
      v_e := v_e || ' non-croissants';
    END IF;
    IF EXISTS (SELECT 1 FROM public.exemplares WHERE tombo = 'H34T-02700') THEN v_e := v_e || ' redonne'; END IF;
    IF EXISTS (SELECT 1 FROM public.exemplares e WHERE e.tombo LIKE 'H34T-%'
                 AND NOT EXISTS (SELECT 1 FROM public.tombos_attribues t WHERE t.tombo = e.tombo)) THEN
      v_e := v_e || ' hors-registre';
    END IF;
    IF (SELECT count(*) FROM public.tombos_attribues WHERE tombo BETWEEN 'H34T-02700' AND 'H34T-03260') <> 561 THEN
      v_e := v_e || ' registre-incomplet';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T06 ─────────────────────────────────────────────────────────────
  v_t := 'T06 fn_next_tombo par index = la lecture d''avant, sur 12 séries';
  DECLARE v_libT uuid := gen_random_uuid(); v_pat jsonb; v_pref text; v_new text; v_old text; v_max bigint; v_det text := '';
          v_an text := to_char(current_date, 'YYYY');
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);   -- sans jeton : la numérotation seule
    INSERT INTO public.libraries (id, slug, name, is_active, visibility_level) VALUES (v_libT, 'h34-tests-t', 'H34 T', true, 'public');
    INSERT INTO public.book_holdings (book_id, library_id) SELECT id, v_libT FROM h34_b WHERE k = 30 RETURNING id INTO v_h;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy)
    SELECT 'H34T-FREF-30', t, v_libT, v_h, 'ambos'
      FROM unnest(ARRAY['ZQ-7', 'ZQ-0009', 'ZQ-12', 'ZQ-12A', 'ZQ-99B', 'ZQX-500', 'ZQ-X40', 'Y2026150', 'Y202699',
                        'V' || v_an || '15', 'V' || v_an || '7', 'V' || v_an || '-90',
                        '00042', '7', 'A_B-3', 'AXB-900', 'P%Q-5', 'PXQ-800', 'W.1.', 'W.2', 'W.03']) t;
    INSERT INTO public.tombos_attribues (tombo, exemplar_id, library_id, source) VALUES
      ('ZQ-20', NULL, v_libT, 'journal'), ('W.10', NULL, v_libT, 'journal'), ('000077', NULL, v_libT, 'journal'), ('Y2026300', NULL, v_libT, 'journal');
    v_n := 0;
    -- ZQ- (largeurs mêlées, suffixes non numériques, numéro au registre seul), préfixe voisin, W. (point
    -- final), préfixe vide, préfixes finissant par un chiffre (V + année, Y2026 : repli), à « _ » ou
    -- « % » (repli : LIKE y voit un joker, comme avant), série neuve, année avec séparateur
    FOREACH v_pat IN ARRAY ARRAY[
      '{"prefix": "ZQ-", "pad": 4}', '{"prefix": "ZQ-"}', '{"prefix": "ZQX-", "pad": 3}', '{"prefix": "ZQ-X"}',
      '{"prefix": "W.", "pad": 2}', '{"prefix": "", "pad": 3}', '{"prefix": "V", "year": true}', '{"prefix": "Y2026"}',
      '{"prefix": "A_B-"}', '{"prefix": "P%Q-"}', '{"prefix": "NEUF-", "pad": 5}', '{"prefix": "ZQ", "year": true, "sep": "-"}']::jsonb[] LOOP
      UPDATE public.libraries SET tombo_pattern = v_pat WHERE id = v_libT;
      v_new := public.fn_next_tombo(v_libT);
      -- la lecture d'avant (fn_next_tombo md5 145929f8…), copiée
      v_pref := coalesce(v_pat->>'prefix', '') || CASE WHEN coalesce((v_pat->>'year')::boolean, false)
                                                      THEN to_char(current_date, 'YYYY') || coalesce(v_pat->>'sep', '') ELSE '' END;
      SELECT coalesce(max(n), 0) INTO v_max FROM (
        SELECT (substring(e.tombo FROM char_length(v_pref) + 1))::bigint AS n FROM public.exemplares e
         WHERE e.tombo LIKE v_pref || '%' AND substring(e.tombo FROM char_length(v_pref) + 1) ~ '^[0-9]+$'
        UNION ALL
        SELECT (substring(t.tombo FROM char_length(v_pref) + 1))::bigint FROM public.tombos_attribues t
         WHERE t.tombo LIKE v_pref || '%' AND substring(t.tombo FROM char_length(v_pref) + 1) ~ '^[0-9]+$') s;
      v_old := v_pref || CASE WHEN coalesce((v_pat->>'pad')::int, 0) > 0 THEN lpad((v_max + 1)::text, (v_pat->>'pad')::int, '0')
                              ELSE (v_max + 1)::text END;
      v_det := v_det || ' ' || v_new;
      IF v_new IS DISTINCT FROM v_old THEN v_n := v_n + 1; v_e := coalesce(v_e, '') || format(' [%s : %s au lieu de %s]', v_pat, v_new, v_old); END IF;
    END LOOP;
    RAISE NOTICE 'H34-TOMBOS%', v_det;
    -- les séries attendues, à la main (les cas qui distinguent)
    IF v_n = 0 AND v_det = ' ZQ-0021 ZQ-21 ZQX-501 ZQ-X41 W.11 078 V' || v_an || '16 Y2026301 A_B-901 P%Q-801 NEUF-00001 ZQ' || v_an || '-1' THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||coalesce(v_e, '')||' | rendu'||v_det); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T07 ─────────────────────────────────────────────────────────────
  v_t := 'T07 mesure : fn_next_tombo < 1 ms par numéro pendant la publication';
  BEGIN
    v_n := coalesce((v_f1->'public.fn_next_tombo'->>0)::bigint, 0) - coalesce((v_f0->'public.fn_next_tombo'->>0)::bigint, 0);
    v_ms := coalesce((v_f1->'public.fn_next_tombo'->>1)::numeric, 0) - coalesce((v_f0->'public.fn_next_tombo'->>1)::numeric, 0);
    RAISE NOTICE 'H34-MESURE fn_next_tombo : % appels, % ms (% ms par numéro)', v_n, round(v_ms), round(v_ms / greatest(v_n, 1), 3);
    IF v_n = 560 AND v_ms / v_n < 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' appels, '||round(v_ms)||' ms'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T08 ─────────────────────────────────────────────────────────────
  v_t := 'T08 gardes : lot d''une autre bibliothèque, sans rôle, numéro hors du personnel, sans schéma, verrou par préfixe';
  DECLARE v_lotB bigint; v_hint text; v_state text; v_out uuid := gen_random_uuid();
  BEGIN
    v_e := '';
    INSERT INTO public.catalog_batches (name, library_id) VALUES ('H34 lot de B', v_libB) RETURNING id INTO v_lotB;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.publish_catalog_batch(v_lotB); v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    IF v_hint IS DISTINCT FROM 'error.batch.other_libraries' THEN v_e := v_e || ' autre-biblio(' || coalesce(v_hint, '∅') || ')'; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_out, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.publish_catalog_batch(v_lot); v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    BEGIN PERFORM public.fn_next_tombo(v_lib); v_state := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; END;
    EXECUTE 'RESET ROLE';
    IF v_hint IS DISTINCT FROM 'error.catalog.staff_only' THEN v_e := v_e || ' sans-role(' || coalesce(v_hint, '∅') || ')'; END IF;
    IF v_state IS DISTINCT FROM '42501' THEN v_e := v_e || ' tombo-hors-personnel(' || v_state || ')'; END IF;
    PERFORM set_config('request.jwt.claims', '', true);
    BEGIN PERFORM public.fn_next_tombo(v_libB); v_state := 'accepte';   -- B a un schéma : rendu, sans jeton
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; END;
    IF v_state <> 'accepte' THEN v_e := v_e || ' tombo-b(' || v_state || ')'; END IF;
    UPDATE public.libraries SET tombo_pattern = NULL WHERE id = v_libB;
    BEGIN PERFORM public.fn_next_tombo(v_libB); v_state := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE || ':' || SQLERRM; END;
    IF v_state IS DISTINCT FROM 'P0001:tombo_pattern_not_configured' THEN v_e := v_e || ' sans-schema(' || v_state || ')'; END IF;
    PERFORM public.fn_next_tombo(v_lib);
    IF NOT EXISTS (SELECT 1 FROM pg_locks l
                    WHERE l.locktype = 'advisory' AND l.pid = pg_backend_pid() AND l.granted
                      AND l.objid = (hashtext('tombo:H34T-')::bigint & 4294967295)::oid) THEN
      v_e := v_e || ' verrou-prefixe';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T09 ─────────────────────────────────────────────────────────────
  v_t := 'T09 aides fermées à l''API';
  BEGIN
    IF NOT has_function_privilege('authenticated', 'private.fn_h34_noter_fonds(bigint[])', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'private.fn_h34_noter_fonds(bigint[])', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'private.fn_h34_recompter_fonds_notes()', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'private.fn_h34_recompter_fonds_notes()', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.publish_catalog_batch(bigint)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_v2_recompute_holdings_availability(bigint[], bigint[])', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : droits'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 une notice à deux fonds notés : un recompte par fonds, dans l''ordre du dernier geste';
  DECLARE v_hA bigint; v_hB bigint; v_r int;
  BEGIN
    v_e := '';
    SELECT h.id, b.id INTO v_hA, v_b FROM public.book_holdings h JOIN h34_b b ON b.id = h.book_id WHERE b.k = 15 AND h.library_id = v_lib;
    SELECT h.id INTO v_hB FROM public.book_holdings h WHERE h.book_id = v_b AND h.library_id = v_libB;
    UPDATE public.book_holdings SET exemplares_total = 50, available_count = 50 WHERE id IN (v_hA, v_hB);
    PERFORM set_config('anarbib.h34_fonds_notes', '', true);
    PERFORM set_config('anarbib.h34_disponibilite_differee', 'on', true);
    IF NOT private.fn_h34_noter_fonds(ARRAY[v_hB]) THEN v_e := v_e || ' noter'; END IF;
    PERFORM private.fn_h34_noter_fonds(ARRAY[v_hA, NULL]);
    PERFORM private.fn_h34_noter_fonds(ARRAY[v_hB]);          -- B redevient le dernier geste
    IF current_setting('anarbib.h34_fonds_notes') <> ',' || v_hA || ',' || v_hB || ',' THEN
      v_e := v_e || ' liste(' || current_setting('anarbib.h34_fonds_notes') || ')';
    END IF;
    v_r := private.fn_h34_recompter_fonds_notes();
    IF v_r <> 2 THEN v_e := v_e || ' rendu(' || v_r || ')'; END IF;
    -- B41 (20/10/2026) : la notice vaut la somme de ses deux fonds
    IF (SELECT available_count FROM public.books WHERE id = v_b) IS DISTINCT FROM (SELECT sum(available_count) FROM public.book_holdings WHERE id IN (v_hA, v_hB))
       OR (SELECT exemplares_total FROM public.book_holdings WHERE id = v_hA) = 50
       OR (SELECT exemplares_total FROM public.book_holdings WHERE id = v_hB) <> 1 THEN
      v_e := v_e || ' comptes';
    END IF;
    IF coalesce(current_setting('anarbib.h34_disponibilite_differee', true), '') <> '' THEN v_e := v_e || ' drapeau'; END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  v_t := 'T11 pendant un lot, un exemplaire qui change de fonds fait noter les deux fonds (et une suppression le sien)';
  DECLARE v_hX bigint; v_hY bigint; v_hZ bigint; v_ex bigint; v_r int;
  BEGIN
    v_e := '';
    SELECT h.id INTO v_hX FROM public.book_holdings h JOIN h34_b b ON b.id = h.book_id WHERE b.k = 2100 AND h.library_id = v_lib;
    SELECT h.id INTO v_hY FROM public.book_holdings h JOIN h34_b b ON b.id = h.book_id WHERE b.k = 2101 AND h.library_id = v_lib;
    SELECT h.id INTO v_hZ FROM public.book_holdings h JOIN h34_b b ON b.id = h.book_id WHERE b.k = 2102 AND h.library_id = v_lib;
    SELECT id INTO v_ex FROM public.exemplares WHERE holding_id = v_hX;
    PERFORM set_config('anarbib.h34_fonds_notes', '', true);
    PERFORM set_config('anarbib.h34_disponibilite_differee', 'on', true);
    UPDATE public.exemplares SET holding_id = v_hY, bib_ref = 'H34T-FREF-2101' WHERE id = v_ex;
    DELETE FROM public.exemplares WHERE holding_id = v_hZ;
    -- différé : rien n'a bougé encore
    IF (SELECT string_agg(exemplares_total::text, ',' ORDER BY id) FROM public.book_holdings WHERE id IN (v_hX, v_hY, v_hZ)) <> '1,1,1' THEN
      v_e := v_e || ' pas-differe';
    END IF;
    IF current_setting('anarbib.h34_fonds_notes') <> ',' || v_hY || ',' || v_hX || ',' || v_hZ || ',' THEN
      v_e := v_e || ' liste(' || current_setting('anarbib.h34_fonds_notes') || ')';
    END IF;
    v_r := private.fn_h34_recompter_fonds_notes();
    IF (SELECT string_agg(exemplares_total || '/' || available_count, ',' ORDER BY id) FROM public.book_holdings WHERE id IN (v_hX, v_hY, v_hZ)) <> '0/0,2/2,0/0' THEN
      v_e := v_e || ' comptes(' || (SELECT string_agg(exemplares_total || '/' || available_count, ',' ORDER BY id) FROM public.book_holdings WHERE id IN (v_hX, v_hY, v_hZ)) || ')';
    END IF;
    IF v_e = '' AND v_r = 3 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e||' rendu '||v_r); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ═════════════════════════════════════════════════════════════════════
  -- H34 lot 2 (IMP-36) : un lot approuvé se publie par pages
  -- ═════════════════════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims', '', true);
  -- un lot importé : nr notices nouvelles x ne exemplaires, et des lignes
  -- rapprochées (2 exemplaires) sur les notices du fond k_min..k_max ; promu,
  -- rapproché, cotes posées — la revue reste à demander (pg_temp.h34_approuver)
  CREATE FUNCTION pg_temp.h34_lot(p_src bigint, p_tag text, p_nr int, p_ne int, p_kmin int, p_kmax int)
  RETURNS bigint LANGUAGE plpgsql AS $f$
  DECLARE v_run bigint; v_ids bigint[]; v_idk bigint[]; v_res jsonb; v_lot bigint; v_pg int;
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (p_src, '1234825f-a0f9-4fbd-a875-6551c30ea4ca', 'essai/' || p_tag || '.iso', p_tag || '.iso', 'marc_iso2709', 'ready_for_review')
    RETURNING id INTO v_run;
    WITH ins AS (
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, publisher, publication_year,
                                                       normalized_payload, raw_payload, match_status, editorial_decision)
      SELECT v_run, r, p_tag || '-N-' || r, p_tag || ' notice ' || r, jsonb_build_array('Autrice ' || p_tag || ' ' || r), 'Editions H34', '2002',
             jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', p_tag || '-N-' || r || '-' || j,
                                                                            'source_item_id', p_tag || 'n' || r || '-' || j))
                                            FROM generate_series(1, p_ne) j)),
             '{"item_tag":"995"}'::jsonb, 'new_record', 'pending'
        FROM generate_series(1, p_nr) r RETURNING id)
    SELECT array_agg(id ORDER BY id) INTO v_ids FROM ins;
    WITH ins AS (
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, normalized_payload, raw_payload,
                                                       match_status, editorial_decision, proposed_book_id)
      SELECT v_run, 10000 + b.k, p_tag || '-K-' || b.k, p_tag || ' rapprochée ' || b.k,
             jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', p_tag || '-K-' || b.k || '-' || j,
                                                                            'source_item_id', p_tag || 'k' || b.k || '-' || j))
                                            FROM generate_series(1, 2) j)),
             '{"item_tag":"995"}'::jsonb, 'known_record', 'pending', b.id
        FROM h34_b b WHERE b.k BETWEEN p_kmin AND p_kmax RETURNING id)
    SELECT array_agg(id ORDER BY id) INTO v_idk FROM ins;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_import_set_editorial(v_run, v_ids, 'accept_new', 'page import: validation individuelle');
    -- la promotion va par pages de 100 lignes, comme l'écran (pagesDePromotion,
    -- H33 suite, 14/10 ; 200 avant) : la base refuse au-delà
    FOR v_pg IN 0..((p_nr - 1) / 100) LOOP
      v_res := public.fn_import_promote(v_run, p_row_ids := v_ids[v_pg * 100 + 1 : least(p_nr, v_pg * 100 + 100)]);
      v_lot := coalesce(v_lot, (v_res->>'batch_id')::bigint);
    END LOOP;
    IF v_idk IS NOT NULL THEN PERFORM public.fn_import_reconcile_duplicates(v_run, v_idk); END IF;
    PERFORM public.fn_batch_assign_bib_refs(v_lot, true);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
    RETURN v_lot;
  END $f$;
  CREATE FUNCTION pg_temp.h34_approuver(p_lot bigint) RETURNS void LANGUAGE plpgsql AS $f$
  DECLARE v_rev jsonb;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_rev := public.fn_batch_review_request(p_lot, NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_batch_review_verdict((v_rev->>'review_id')::bigint, 'approved', NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
  END $f$;
  -- une page, sous le jeton de la coordination ; rend la réponse et la durée
  CREATE FUNCTION pg_temp.h34_page(p_lot bigint) RETURNS jsonb LANGUAGE plpgsql AS $f$
  DECLARE v_t0 timestamptz := clock_timestamp(); v_r jsonb;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_r := public.publish_catalog_batch(p_lot);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
    RETURN v_r || jsonb_build_object('ms', round(extract(epoch FROM clock_timestamp() - v_t0) * 1000));
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
    RAISE;
  END $f$;
  -- l'état de la base, par clés naturelles (les identifiants dépendent des séquences)
  CREATE FUNCTION pg_temp.h34_etat(p_lot bigint) RETURNS jsonb LANGUAGE sql AS $f$
    SELECT jsonb_build_object(
      'fonds', (SELECT jsonb_agg(to_jsonb(h) - 'id' - 'book_id' || jsonb_build_object('notice', b.bib_ref) ORDER BY b.bib_ref, h.library_id)
                  FROM public.book_holdings h JOIN public.books b ON b.id = h.book_id),
      'notices', (SELECT jsonb_agg(to_jsonb(b) - 'id' - 'work_id' - 'expression_id' - 'search_vector' ORDER BY b.bib_ref) FROM public.books b),
      'exemplaires', (SELECT jsonb_agg(to_jsonb(e) - 'id' - 'holding_id' || jsonb_build_object('notice', b.bib_ref) ORDER BY e.tombo)
                        FROM public.exemplares e LEFT JOIN public.book_holdings h ON h.id = e.holding_id LEFT JOIN public.books b ON b.id = h.book_id),
      'brouillons', (SELECT jsonb_agg(jsonb_build_object('bib_ref', d.bib_ref, 'status', d.status, 'publie', b.bib_ref) ORDER BY d.bib_ref, d.titulo)
                       FROM public.book_drafts d LEFT JOIN public.books b ON b.id = d.published_book_id WHERE d.batch_id = p_lot),
      'brouillons_ex', (SELECT jsonb_agg(jsonb_build_object('code', x.source_item_code, 'status', x.status, 'tombo', x.tombo, 'publie', e.tombo)
                                         ORDER BY x.source_item_code)
                          FROM public.exemplar_drafts x LEFT JOIN public.exemplares e ON e.id = x.published_exemplar_id WHERE x.batch_id = p_lot),
      'lot', (SELECT jsonb_build_object('status', c.status, 'published_at', c.published_at, 'published_by', c.published_by)
                FROM public.catalog_batches c WHERE c.id = p_lot))
  $f$;

  -- ── T12 / T13 ──────────────────────────────────────────────────────
  v_t := 'T12 un gros lot en plusieurs pages : chacune < 8 s, une notice et ses exemplaires dans la même page, rien publié deux fois ni sauté';
  DECLARE
    v_lot2 bigint; v_bloc jsonb; v_par jsonb; v_r jsonb; v_pages int := 0; v_d text := ''; v_max numeric := 0;
    v_books int := 0; v_ex int := 0; v_upd bigint[]; v_sep int := 0; v_etats text := '';
  BEGIN
    v_e := '';
    v_lot2 := pg_temp.h34_lot(v_src, 'H34G', 200, 10, 101, 130);
    -- trois mises à jour de notices du fond et un exemplaire fait à la main, dans le lot
    WITH u AS (
      INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, status, published_book_id, owner_library_id, batch_id)
      SELECT 'H34 fond ' || b.k || ' (revu)', b.bib_ref, 'livro', 'ready', b.id, v_lib, v_lot2 FROM h34_b b WHERE b.k BETWEEN 201 AND 203
      RETURNING id)
    SELECT array_agg(id) INTO v_upd FROM u;
    INSERT INTO public.exemplar_drafts (batch_id, action, status, label_status, target_library_id, target_bib_ref, source_item_code)
    SELECT v_lot2, 'create', 'ready', 'pending', v_lib, b.bib_ref, 'H34G-MAIN-1' FROM h34_b b WHERE b.k = 204;
    PERFORM pg_temp.h34_approuver(v_lot2);
    ANALYZE public.book_drafts; ANALYZE public.exemplar_drafts;
    -- T13 (référence) : le même lot publié d'un bloc, puis tout annulé
    BEGIN
      CREATE OR REPLACE FUNCTION private.fn_h34_page_de_publication() RETURNS jsonb LANGUAGE sql IMMUTABLE
        SET search_path TO 'pg_catalog' AS $g$ SELECT '{"notices": 100000, "exemplaires": 1000000}'::jsonb $g$;
      v_r := pg_temp.h34_page(v_lot2);
      IF NOT (v_r->>'done')::boolean THEN v_e := v_e || ' bloc-pas-fini'; END IF;
      v_bloc := pg_temp.h34_etat(v_lot2);
      RAISE NOTICE 'H34-MESURE lot 2 : le même lot d''un bloc (référence) : % ms', v_r->>'ms';
      RAISE EXCEPTION 'h34-sentinelle';
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM <> 'h34-sentinelle' THEN RAISE; END IF;
    END;
    IF (private.fn_h34_page_de_publication()->>'notices')::int <> 60 THEN v_e := v_e || ' borne-pas-restauree'; END IF;
    -- par pages
    LOOP
      v_r := pg_temp.h34_page(v_lot2);
      v_pages := v_pages + 1;
      v_max := greatest(v_max, (v_r->>'ms')::numeric);
      v_d := v_d || ' ' || (v_r->>'ms');
      v_books := v_books + (v_r->>'books_published')::int;
      v_ex := v_ex + (v_r->'page'->>'exemplaires')::int;
      v_etats := v_etats || ' ' || (SELECT status FROM public.catalog_batches WHERE id = v_lot2);
      -- une notice publiée n'a plus aucun exemplaire rattaché en brouillon : ils sont partis avec elle
      SELECT count(*) INTO v_n FROM public.exemplar_drafts x JOIN public.book_drafts d ON d.id = x.book_draft_id
       WHERE d.batch_id = v_lot2 AND d.status = 'published' AND x.status IN ('draft', 'ready');
      v_sep := v_sep + v_n;
      IF (v_r->'page'->>'notices')::int > 60 OR ((v_r->'page'->>'exemplaires')::int > 400 AND (v_r->'page'->>'notices')::int > 1) THEN
        v_e := v_e || ' page-trop-grande(' || (v_r->'page')::text || ')';
      END IF;
      EXIT WHEN (v_r->>'done')::boolean OR v_pages >= 20;
    END LOOP;
    RAISE NOTICE 'H34-MESURE lot 2 : 203 notices / 2 061 exemplaires en % pages : % ms (la plus longue % ms) ; états :%',
      v_pages, trim(v_d), v_max, v_etats;
    IF v_pages <> 6 THEN v_e := v_e || ' pages(' || v_pages || ')'; END IF;
    IF v_max >= coalesce(nullif(current_setting('anarbib.budget_ms', true), '')::int, 8000) THEN v_e := v_e || ' page-lente(' || v_max || ')'; END IF;
    IF v_etats <> ' publishing publishing publishing publishing publishing published' THEN v_e := v_e || ' etats(' || v_etats || ')'; END IF;
    IF v_sep <> 0 THEN v_e := v_e || ' notice-separee(' || v_sep || ')'; END IF;
    IF v_books <> 203 OR v_ex <> 2061 THEN v_e := v_e || ' comptes(' || v_books || '/' || v_ex || ')'; END IF;
    -- rien publié deux fois, rien sauté
    IF (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot2 AND status <> 'published') <> 0
       OR (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot2 AND status <> 'published') <> 0 THEN
      v_e := v_e || ' saute';
    END IF;
    IF (SELECT count(DISTINCT published_exemplar_id) FROM public.exemplar_drafts WHERE batch_id = v_lot2) <> 2061
       OR (SELECT count(*) FROM public.exemplares e WHERE e.id IN (SELECT published_exemplar_id FROM public.exemplar_drafts WHERE batch_id = v_lot2)) <> 2061
       OR (SELECT count(*) FROM public.exemplares e WHERE e.source_item_code LIKE 'H34G-%') <> 2061
       OR (SELECT count(DISTINCT published_book_id) FROM public.book_drafts WHERE batch_id = v_lot2) <> 203
       OR (SELECT count(*) FROM public.books WHERE titulo LIKE 'H34G notice %') <> 200
       OR (SELECT count(*) FROM public.books WHERE titulo LIKE 'H34 fond % (revu)') <> 3 THEN
      v_e := v_e || ' deux-fois';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e||' | pages'||v_d); END IF;

    v_t := 'T13 publié par pages = publié d''un bloc (fonds, notices, exemplaires, brouillons, lot ; colonne par colonne)';
    v_par := pg_temp.h34_etat(v_lot2);
    IF v_par = v_bloc THEN v_passed := v_passed+1;
    ELSE
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||(SELECT string_agg(k || '(' || jsonb_array_length(coalesce(v_bloc->k, '[]')) || '/' || jsonb_array_length(coalesce(v_par->k, '[]')) || ')', ' ')
                                                FROM unnest(ARRAY['fonds', 'notices', 'exemplaires', 'brouillons', 'brouillons_ex']) k
                                               WHERE v_bloc->k IS DISTINCT FROM v_par->k)
                                            || CASE WHEN v_bloc->'lot' IS DISTINCT FROM v_par->'lot' THEN ' lot' ELSE '' END);
    END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 à T17 : un lot interrompu, refusé, figé, rouvert, repris ────
  DECLARE
    v_lot3 bigint; v_r jsonb; v_hint text; v_av jsonb; v_code text; v_ex bigint; v_bd bigint; v_xd bigint; v_out uuid := gen_random_uuid();
  BEGIN
    v_t := 'T14 une page interrompue, puis une page refusée : rien d''écrit par elles, les pages d''avant restent, l''état reste « publishing »';
    v_e := '';
    v_lot3 := pg_temp.h34_lot(v_src, 'H34R', 70, 4, 131, 135);   -- 70 notices x 4 + 5 x 2 rapprochés : 2 pages (60, puis 10 et les rapprochés)
    PERFORM pg_temp.h34_approuver(v_lot3);
    v_r := pg_temp.h34_page(v_lot3);
    IF (v_r->>'done')::boolean OR (v_r->>'books_published')::int <> 60 THEN v_e := v_e || ' page1(' || v_r::text || ')'; END IF;
    v_av := pg_temp.h34_etat(v_lot3);
    -- (a) la page 2 coupée en route (un délai dépassé, une coupure) : annulée en entier
    BEGIN
      v_r := pg_temp.h34_page(v_lot3);
      RAISE EXCEPTION 'h34-coupure';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'h34-coupure' THEN RAISE; END IF; END;
    IF pg_temp.h34_etat(v_lot3) IS DISTINCT FROM v_av THEN v_e := v_e || ' coupure-a-ecrit'; END IF;
    -- (b) la page 2 refusée : un exemplaire posé entre-temps porte le code d'un rapproché
    SELECT x.source_item_code INTO v_code FROM public.exemplar_drafts x
     WHERE x.batch_id = v_lot3 AND x.book_draft_id IS NULL ORDER BY x.id DESC LIMIT 1;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, circulation_policy)
    SELECT b.bib_ref, 'H34T-CONFLIT', v_lib, h.id, v_code, 'ambos'
      FROM h34_b b JOIN public.book_holdings h ON h.book_id = b.id AND h.library_id = v_lib WHERE b.k = 2500
    RETURNING id INTO v_ex;
    v_av := pg_temp.h34_etat(v_lot3);
    BEGIN PERFORM pg_temp.h34_page(v_lot3); v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.publish.source_item_code_taken' THEN v_e := v_e || ' refus(' || coalesce(v_hint, '∅') || ')'; END IF;
    IF pg_temp.h34_etat(v_lot3) IS DISTINCT FROM v_av THEN v_e := v_e || ' refus-a-ecrit'; END IF;
    IF (SELECT status FROM public.catalog_batches WHERE id = v_lot3) <> 'publishing'
       OR (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot3 AND status = 'published') <> 60 THEN
      v_e := v_e || ' etat-apres-refus';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;

    v_t := 'T15 « publishing » : rien ne s''ajoute, ne se retouche, ne sort ni ne se supprime ; l''état ne se change qu''à la publication';
    v_e := '';
    SELECT id INTO v_bd FROM public.book_drafts WHERE batch_id = v_lot3 AND status IN ('draft', 'ready') ORDER BY id LIMIT 1;
    SELECT id INTO v_xd FROM public.exemplar_drafts WHERE batch_id = v_lot3 AND book_draft_id IS NULL AND status IN ('draft', 'ready') ORDER BY id LIMIT 1;
    FOR v_x IN SELECT unnest(ARRAY['coord', 'admin']) LOOP
      PERFORM set_config('request.jwt.claims', json_build_object('sub', CASE v_x WHEN 'coord' THEN v_coord ELSE v_admin END, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN UPDATE public.book_drafts SET titulo = titulo || ' (retouche)' WHERE id = v_bd; v_hint := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
      IF v_hint IS DISTINCT FROM 'error.batch.publishing_locked' THEN v_e := v_e || ' ' || v_x || '-retouche(' || coalesce(v_hint, '∅') || ')'; END IF;
      BEGIN UPDATE public.exemplar_drafts SET shelf_location = 'Z' WHERE id = v_xd; v_hint := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
      IF v_hint IS DISTINCT FROM 'error.batch.publishing_locked' THEN v_e := v_e || ' ' || v_x || '-retouche-ex(' || coalesce(v_hint, '∅') || ')'; END IF;
      BEGIN UPDATE public.book_drafts SET batch_id = NULL WHERE id = v_bd; v_hint := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
      IF v_hint IS DISTINCT FROM 'error.batch.publishing_locked' THEN v_e := v_e || ' ' || v_x || '-sortie(' || coalesce(v_hint, '∅') || ')'; END IF;
      BEGIN INSERT INTO public.book_drafts (titulo, owner_library_id, status, batch_id) VALUES ('H34 ajout', v_lib, 'draft', v_lot3); v_hint := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
      IF v_hint IS DISTINCT FROM 'error.batch.publishing_locked' THEN v_e := v_e || ' ' || v_x || '-ajout(' || coalesce(v_hint, '∅') || ')'; END IF;
      BEGIN DELETE FROM public.exemplar_drafts WHERE id = v_xd; v_hint := CASE WHEN FOUND THEN 'accepte' ELSE 'rien' END;
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
      IF v_hint NOT IN ('error.batch.publishing_locked', 'rien') THEN v_e := v_e || ' ' || v_x || '-suppression(' || coalesce(v_hint, '∅') || ')'; END IF;
      BEGIN UPDATE public.catalog_batches SET status = 'open' WHERE id = v_lot3; v_hint := CASE WHEN FOUND THEN 'accepte' ELSE 'rien' END;
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
      IF v_hint NOT IN ('error.batch.publishing_locked', 'rien') THEN v_e := v_e || ' ' || v_x || '-etat(' || coalesce(v_hint, '∅') || ')'; END IF;
      BEGIN PERFORM public.fn_batch_assign_bib_refs(v_lot3, true); v_hint := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
      IF v_hint = 'accepte' THEN v_e := v_e || ' ' || v_x || '-cotes'; END IF;
      BEGIN PERFORM public.publish_book_draft(v_bd); v_hint := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
      IF v_hint IS DISTINCT FROM 'error.batch.publishing_locked' THEN v_e := v_e || ' ' || v_x || '-publier-seul(' || coalesce(v_hint, '∅') || ')'; END IF;
      EXECUTE 'RESET ROLE';
    END LOOP;
    PERFORM set_config('request.jwt.claims', '', true);
    -- le statut « publishing » ne se pose ni ne se lève à la main, même hors API
    BEGIN UPDATE public.catalog_batches SET status = 'closed' WHERE id = v_lot3; v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.batch.publishing_locked' THEN v_e := v_e || ' etat-postgres(' || coalesce(v_hint, '∅') || ')'; END IF;
    BEGIN INSERT INTO public.catalog_batches (name, library_id, status) VALUES ('H34 faux', v_lib, 'publishing'); v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.batch.publishing_locked' THEN v_e := v_e || ' insert-publishing(' || coalesce(v_hint, '∅') || ')'; END IF;
    IF (SELECT titulo FROM public.book_drafts WHERE id = v_bd) LIKE '%(retouche)%'
       OR NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE id = v_xd AND shelf_location IS DISTINCT FROM 'Z')
       OR (SELECT status FROM public.catalog_batches WHERE id = v_lot3) <> 'publishing' THEN
      v_e := v_e || ' a-change';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;

    v_t := 'T16 un nouveau tour rouvre le lot (« open ») : retouche permise, publication refusée jusqu''à l''approbation, pages publiées intactes';
    v_e := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_r := public.fn_batch_review_request(v_lot3, 'H34 : corriger avant la page suivante');
    EXECUTE 'RESET ROLE';
    IF (SELECT status FROM public.catalog_batches WHERE id = v_lot3) <> 'open' THEN v_e := v_e || ' pas-rouvert'; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN UPDATE public.book_drafts SET notas = 'H34 retouchée après réouverture' WHERE id = v_bd; v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    IF v_hint <> 'accepte' THEN v_e := v_e || ' retouche(' || coalesce(v_hint, '∅') || ')'; END IF;
    BEGIN PERFORM pg_temp.h34_page(v_lot3); v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    IF v_hint IS DISTINCT FROM 'error.publish.review_required' THEN v_e := v_e || ' publier-sans-revue(' || coalesce(v_hint, '∅') || ')'; END IF;
    IF (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot3 AND status = 'published') <> 60 THEN v_e := v_e || ' pages-touchees'; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_batch_review_verdict((v_r->>'review_id')::bigint, 'approved', NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_e = '' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;

    v_t := 'T17 la reprise : la page refusée, une fois la cause levée, se publie ; tout publié une fois, rien sauté';
    v_e := '';
    DELETE FROM public.exemplares WHERE id = v_ex;             -- la cause du refus, levée (geste d'administration)
    v_r := pg_temp.h34_page(v_lot3);
    IF NOT (v_r->>'done')::boolean OR (v_r->>'books_published')::int <> 10 OR (v_r->>'exemplars_published')::int <> 10 THEN
      v_e := v_e || ' reprise(' || v_r::text || ')';
    END IF;
    IF (SELECT status FROM public.catalog_batches WHERE id = v_lot3) <> 'published'
       OR (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot3 AND status <> 'published') <> 0
       OR (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot3 AND status <> 'published') <> 0
       OR (SELECT count(*) FROM public.exemplares WHERE source_item_code LIKE 'H34R-%') <> 290
       OR (SELECT count(DISTINCT published_exemplar_id) FROM public.exemplar_drafts WHERE batch_id = v_lot3) <> 290
       OR (SELECT count(*) FROM public.books WHERE titulo LIKE 'H34R notice %') <> 70
       OR (SELECT b.notas FROM public.books b JOIN public.book_drafts d ON d.published_book_id = b.id WHERE d.id = v_bd) IS DISTINCT FROM 'H34 retouchée après réouverture' THEN
      v_e := v_e || ' fin';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;

    v_t := 'T18 droits sur un lot « publishing » ; aides fermées';
    v_e := '';
    -- un lot en cours de publication (on en refait un, deux pages)
    v_lot3 := pg_temp.h34_lot(v_src, 'H34D', 61, 1, 0, -1);
    PERFORM pg_temp.h34_approuver(v_lot3);
    v_r := pg_temp.h34_page(v_lot3);
    IF (SELECT status FROM public.catalog_batches WHERE id = v_lot3) <> 'publishing' THEN v_e := v_e || ' pas-publishing'; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_out, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.publish_catalog_batch(v_lot3); v_hint := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
    EXECUTE 'RESET ROLE';
    IF v_hint IS DISTINCT FROM 'error.catalog.staff_only' THEN v_e := v_e || ' sans-role(' || coalesce(v_hint, '∅') || ')'; END IF;
    PERFORM set_config('request.jwt.claims', '', true);
    IF has_function_privilege('authenticated', 'private.fn_h34_page_de_publication()', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.tg_h34_lot_en_publication()', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.tg_h34_statut_publication()', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'public.publish_catalog_batch(bigint)', 'EXECUTE') THEN
      v_e := v_e || ' droits';
    END IF;
    v_r := pg_temp.h34_page(v_lot3);
    IF NOT (v_r->>'done')::boolean OR (v_r->>'books_published')::int <> 1 THEN v_e := v_e || ' fin(' || v_r::text || ')'; END IF;
    IF v_e = '' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T19 ─────────────────────────────────────────────────────────────
  v_t := 'T19 un petit lot (une page) : comme avant — publié d''un appel, jamais « publishing », mêmes comptes';
  DECLARE v_lot4 bigint; v_r jsonb;
  BEGIN
    v_e := '';
    v_lot4 := pg_temp.h34_lot(v_src, 'H34P', 3, 2, 140, 140);
    PERFORM pg_temp.h34_approuver(v_lot4);
    v_r := pg_temp.h34_page(v_lot4);
    IF NOT (v_r->>'done')::boolean OR (v_r->>'books_published')::int <> 3 OR (v_r->>'authors_published')::int <> 0
       OR (v_r->>'exemplars_published')::int <> 2
       OR (v_r->'remaining') <> '{"books": 0, "authors": 0, "exemplars": 0}'::jsonb
       OR (v_r->'page'->>'notices')::int <> 3 OR (v_r->'page'->>'exemplaires')::int <> 8 THEN
      v_e := v_e || ' reponse(' || v_r::text || ')';
    END IF;
    IF (SELECT status FROM public.catalog_batches WHERE id = v_lot4) <> 'published'
       OR (SELECT published_at FROM public.catalog_batches WHERE id = v_lot4) IS NULL THEN
      v_e := v_e || ' etat';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H34-PUBLIER-UN-GROS-LOT OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'H34-PUBLIER-UN-GROS-LOT ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
