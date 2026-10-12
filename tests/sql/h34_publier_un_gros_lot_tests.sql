-- =====================================================================
-- AnarBib — Tests d'acceptation : publier un gros lot importé (H34)
-- Date    : 2026-10-12
-- Ref     : migration 20261012153013_h34_publier_un_gros_lot
--
-- Aucune règle n'est posée ici : la disponibilité d'un fonds (exemplaires
-- publics non retirés, moins prêts, réservations et PEB ouverts), celle d'une
-- notice (le dernier fonds recompté), le numéro d'inventaire (le plus grand
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
--     notice touchée vaut son fonds de BLMF (le dernier recompté, comme
--     avant) ; un fonds et une notice que le lot ne touche pas sont intacts
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
-- T10 une notice à deux fonds notés : recomptés un par un, dans l'ordre du
--     dernier geste ; la notice vaut le dernier (comme le recompte par
--     exemplaire) ; le drapeau tombe.
-- T11 pendant un lot, un exemplaire qui change de fonds fait noter le nouveau
--     puis l'ancien, une suppression le sien ; rien n'est recompté avant la
--     fin ; puis chacun l'est (même choix de fonds que le recompte immédiat).
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
  v_t := 'T01 mesure : publier un lot importé de 25 notices et 560 exemplaires < 8 s';
  BEGIN
    -- (SET et non set_config : la plate-forme n'ouvre ce réglage qu'à la commande SET)
    EXECUTE 'SET LOCAL track_functions = ''all''';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    SELECT coalesce(jsonb_object_agg(schemaname || '.' || funcname, jsonb_build_array(calls, total_time)), '{}') INTO v_f0
      FROM pg_stat_xact_user_functions;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_t0 := clock_timestamp();
    v_res := public.publish_catalog_batch(v_lot);
    v_ms := extract(epoch FROM clock_timestamp() - v_t0) * 1000;
    EXECUTE 'RESET ROLE';
    SELECT coalesce(jsonb_object_agg(schemaname || '.' || funcname, jsonb_build_array(calls, total_time)), '{}') INTO v_f1
      FROM pg_stat_xact_user_functions;
    RAISE NOTICE 'H34-MESURE publier un lot de 25 notices / 560 exemplaires (fond de 2 700) : % ms ; %', round(v_ms), v_res;
    IF (v_res->>'books_published')::int = 25 AND (v_res->>'exemplars_published')::int = 60
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot AND status = 'published') = 560
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lot) = 'published'
       AND v_ms < 8000
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||round(v_ms)||' ms ; '||coalesce(v_res::text, 'NULL')); END IF;
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
    -- chaque notice touchée vaut son fonds de BLMF (le dernier recompté)
    SELECT count(*) INTO v_n
      FROM public.exemplar_drafts x JOIN public.exemplares e ON e.id = x.published_exemplar_id
      JOIN public.book_holdings h ON h.id = e.holding_id JOIN public.books bk ON bk.id = h.book_id
     WHERE x.batch_id = v_lot AND bk.available_count IS DISTINCT FROM h.available_count;
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
  v_t := 'T03 une fois par fonds touché : 560 déclenchements, un seul recompte, sur les 45 fonds touchés';
  BEGIN
    v_e := '';
    IF coalesce((v_f1->'public.fn_recompute_holdings_on_exemplar_change'->>0)::bigint, 0)
       - coalesce((v_f0->'public.fn_recompute_holdings_on_exemplar_change'->>0)::bigint, 0) <> 560 THEN
      v_e := v_e || ' declencheur(' || coalesce((v_f1->'public.fn_recompute_holdings_on_exemplar_change'->>0)::bigint, 0)
                                    - coalesce((v_f0->'public.fn_recompute_holdings_on_exemplar_change'->>0)::bigint, 0) || ')';
    END IF;
    v_n := coalesce((v_f1->'public.fn_v2_recompute_holdings_availability'->>0)::bigint, 0)
         - coalesce((v_f0->'public.fn_v2_recompute_holdings_availability'->>0)::bigint, 0);
    IF v_n <> 1 THEN v_e := v_e || ' recomptes(' || v_n || ')'; END IF;
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
    IF (SELECT available_count FROM public.books WHERE id = v_b) IS DISTINCT FROM (SELECT available_count FROM public.book_holdings WHERE id = v_hB)
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

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H34-PUBLIER-UN-GROS-LOT OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'H34-PUBLIER-UN-GROS-LOT ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
