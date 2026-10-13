-- =====================================================================
-- AnarBib — Tests d'acceptation : « Rapprocher » et « Promouvoir » un gros
-- fichier sous le plafond de 8 s des appels de l'API (H33)
-- Date    : 2026-10-12
-- Ref     : migration 20261012123726_h33_rapprocher_un_gros_fichier
--
-- Aucune règle n'est posée ici : les verdicts du constat (IMP-33, IMP-35),
-- le rejet d'office, le signal, le lot ouvert du run (IMP-27 d) et le fonds
-- du brouillon sont ceux des lots H19 et H21 ; la suite prouve que la passe
-- unique les rend tels que la boucle d'avant les rendait — l'ordre compris
-- (un exemplaire du fichier que le précédent vient de faire naître est
-- « déjà en brouillon ») — puis mesure.
--
-- Fixture (bibliothèque BLMF du seed, coordination 1111…, sa source S) :
-- exemplaires déjà là (C-DL), déplacé (C-DEP, sur une autre notice),
-- réétiqueté (expl_id x-re sous un autre code), code repris (C-CR, autre
-- expl_id), réattribué (C-RA chez une bibliothèque B) ; brouillons vivants
-- d'avant l'appel : C-PD1 (bibliothèque, par le code), x-pd2 (bibliothèque,
-- par l'expl_id de S), C-PD3 (sans bibliothèque, d'une notice en brouillon de
-- BLMF), C-CAN (à la corbeille : ne compte pas), C-OL (autre bibliothèque :
-- ne compte pas), zz1 (expl_id SANS source : ne compte pas).
--
-- T01 « Rapprocher » lignes 1-5 : chaque verdict, le brouillon créé (cote,
--     note, propriétaire, provenance, fonds de la notice), les lignes (créée,
--     signalées, rejetée d'office), la réponse.
-- T02 « Rapprocher » lignes 6-12, qui rejoint le lot de T01 : « déjà en
--     brouillon » pour un exemplaire qu'un précédent de l'appel vient de créer
--     (par le code, par l'expl_id de même source, dans la même ligne, d'une
--     ligne à l'autre), le bras « bibliothèque » de l'appel avant le bras
--     « notice en brouillon » d'avant l'appel ; sans code, réattribué,
--     implicite, ligne sans exemplaire, cote locale du fonds.
-- T03 le fonds posé par la passe est celui de
--     public.sync_exemplar_draft_holdings_bridge : la rappeler ne change rien.
-- T04 les identifiants croissent dans l'ordre des exemplaires ; la ligne
--     pointe son premier brouillon.
-- T05 la promotion (fn_import_promote) : mêmes règles, la notice étant neuve.
-- T06 le jugement en liste (ingest.fn_h33_juger_exemplaires) rend, pour des
--     exemplaires indépendants, le verdict de ingest.fn_h21_constat_exemplaire.
-- T07 mesure : « Rapprocher » 200 lignes x 25 exemplaires neufs, sous le jeton
--     de la coordination, puis la page suivante (200 x 25 encore, plans de la
--     session bâtis sur la table d'avant) : chacun < 8 s (NOTICE H33-MESURE ;
--     au banc, 12/10 : avant H33 19 à 26 s, puis 48 s pour la page suivante ;
--     après, 1,4 s et 1,4 s).
-- T08 mesure : « Promouvoir » une page pleine < 8 s — 100 lignes nouvelles
--     x 25 exemplaires depuis le 14/10 (200 x 25 avant : 10 à 21 s avant H33,
--     49 s après les deux pages de T07 ; après H33, 2,6 à 3,0 s au calme, mais
--     8,1 s le 13/10 sous la charge d'un second job : la page a été réduite,
--     le seuil jamais — c'est la coupure des appels de l'API).
-- T09 la borne d'une page d'appel : « Rapprocher » (200 lignes, 5 000
--     exemplaires du fichier, comme « Préparer la mise à jour ») refuse 201
--     lignes ou une ligne de 5 001 exemplaires ; « Promouvoir » (100 lignes,
--     2 500 exemplaires depuis le 14/10) refuse 101 lignes ou une ligne de
--     2 501 exemplaires — chacun avec son HINT, sans rien écrire ; 100 lignes
--     passent.
-- T10 garde de l'accord entre les deux textes de l'étape « brouillons
--     vivants » (le constat scalaire, l'EXECUTE de la liste) : tirage
--     déterministe (graine fixe, 80 tirages de 4 à 17 exemplaires — bibliothèque
--     absente, autre source, sans source, cible autre ou nulle, notice en
--     brouillon de la bibliothèque ou d'une autre, codes à espaces, implicites),
--     la liste contre la boucle d'avant (constat puis INSERT, un par un) ; un
--     changement d'un seul côté le fait tomber (repris du banc du sceptique,
--     12/10/2026).
-- T11 (H33 bis, 12/10/2026) mesure : le recalcul de la comparaison et le
--     constat des retraits, à 5 000 exemplaires (5 000 retirés réapparus),
--     chacun < 8 s ; leurs constats passent par la liste
--     (ingest.fn_h33_constater_exemplaires). T10 compare aussi cette liste
--     sans naissance au constat scalaire (et se joue avant T07).
-- T12 (H33 bis) plus aucune fonction n'appelle le constat scalaire, sauf lui ;
--     la garde C17 bis lit le registre des tombos par sa clé
--     (enable_seqscan = off, preuve par le compteur de parcours de l'index) ;
--     la comparaison des notices est calculée une fois (MATERIALIZED).
-- T13 (H33 bis) la levée, à la publication, constate en liste : celle d'un
--     retiré réétiqueté se publie ; celle d'un retiré qui n'est plus « déjà
--     là » ni réétiqueté est refusée, même quand sa ligne porte un autre
--     exemplaire « déjà là ».
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'H33-RAPPROCHER-GROS-FICHIER OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB  uuid := gen_random_uuid();
  v_src bigint; v_run bigint; v_runp bigint; v_lot bigint; v_lot0 bigint; v_bd bigint;
  v_b bigint[]; v_h bigint[]; v_ids bigint[]; v_idp bigint[];
  v_d1 bigint; v_d2 bigint; v_d3 bigint; v_hB bigint;
  v_r1 jsonb; v_r2 jsonb; v_r3 jsonb; v_x jsonb; v_e text; v_n int; i int;
  v_t0 timestamptz; v_ms numeric; v_ms2 numeric;
BEGIN
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "H33T-", "year": false, "pad": 5}'::jsonb,
         bib_ref_auto = true, bib_ref_prefix = 'H33T-REF-', bib_ref_pad = 5 WHERE id = v_lib;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level, tombo_pattern)
  VALUES (v_libB, 'h33-tests-b', 'H33 Biblio B', true, 'public', '{"prefix": "H33B-", "year": false, "pad": 4}'::jsonb);
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H33 S', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  FOR i IN 1..6 LOOP
    INSERT INTO public.books (titulo, bib_ref) VALUES ('H33 livre ' || i, 'H33T-REF-' || i) RETURNING id INTO v_bd;
    v_b := v_b || v_bd;
  END LOOP;
  -- fonds BLMF des livres 1, 2, 3, 4, 6 (6 avec une cote locale) ; le 5 seulement chez B
  FOR i IN 1..6 LOOP
    IF i <> 5 THEN
      INSERT INTO public.book_holdings (book_id, library_id, loanable, local_bib_ref)
      VALUES (v_b[i], v_lib, true, CASE WHEN i = 6 THEN 'LOC-6' END) RETURNING id INTO v_bd;
      v_h := v_h || v_bd;
    ELSE
      v_h := v_h || NULL::bigint;
    END IF;
  END LOOP;
  INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (v_b[5], v_libB, true) RETURNING id INTO v_hB;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy) VALUES
    ('H33T-REF-1', 'H33T-E1', v_lib, v_h[1], 'C-DL', 'x-dl', v_src, 'ambos'),
    ('H33T-REF-2', 'H33T-E2', v_lib, v_h[2], 'C-DEP', 'x-dep', v_src, 'ambos'),
    ('H33T-REF-1', 'H33T-E3', v_lib, v_h[1], 'C-OLD', 'x-re', v_src, 'ambos'),
    ('H33T-REF-1', 'H33T-E4', v_lib, v_h[1], 'C-CR', 'x-cr1', v_src, 'ambos'),
    ('H33T-REF-5', 'H33T-E5', v_libB, v_hB, 'C-RA', 'x-ra', v_src, 'ambos');
  INSERT INTO public.catalog_batches (name, library_id) VALUES ('H33 lot ancien', v_lib) RETURNING id INTO v_lot0;
  INSERT INTO public.exemplar_drafts (batch_id, action, status, label_status, target_library_id, target_bib_ref, source_item_code, source_item_id, import_source_id)
  VALUES (v_lot0, 'create', 'draft', 'pending', v_lib, 'H33T-REF-3', 'C-PD1', 'zz1', NULL) RETURNING id INTO v_d1;
  INSERT INTO public.exemplar_drafts (batch_id, action, status, label_status, target_library_id, target_bib_ref, source_item_code, source_item_id, import_source_id)
  VALUES (v_lot0, 'create', 'ready', 'pending', v_lib, 'H33T-REF-3', 'C-ZZ2', 'x-pd2', v_src) RETURNING id INTO v_d2;
  INSERT INTO public.exemplar_drafts (batch_id, action, status, label_status, target_library_id, target_bib_ref, source_item_code, source_item_id, import_source_id)
  VALUES (v_lot0, 'create', 'cancelled', 'pending', v_lib, 'H33T-REF-3', 'C-CAN', 'x-can0', v_src);
  INSERT INTO public.exemplar_drafts (batch_id, action, status, label_status, target_library_id, target_bib_ref, source_item_code)
  VALUES (NULL, 'create', 'draft', 'pending', v_libB, 'X', 'C-OL');
  INSERT INTO public.book_drafts (titulo, owner_library_id, status, batch_id) VALUES ('H33 notice en brouillon', v_lib, 'draft', v_lot0) RETURNING id INTO v_bd;
  INSERT INTO public.exemplar_drafts (batch_id, action, status, label_status, book_draft_id, target_library_id, source_item_code)
  VALUES (v_lot0, 'create', 'draft', 'pending', v_bd, NULL, 'C-PD3') RETURNING id INTO v_d3;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h33t.iso', 'h33t.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, normalized_payload, raw_payload, match_status, editorial_decision, proposed_book_id)
  SELECT v_run, x.r, 'H33T-' || x.r, 'H33 ligne ' || x.r, x.np, x.rp, 'known_record', 'pending', v_b[x.bk]
    FROM (VALUES
      (1, 1, '{"items":[{"source_item_code":"C-DL","source_item_id":"x-dl"},{"source_item_code":"C-N1","source_item_id":"x-n1","call_number":" K1 ","owner":"Prop","item_type":"L","public":"P","status":"ok","note":"nt"}]}'::jsonb, '{"item_tag":"995"}'::jsonb),
      (2, 1, '{"items":[{"source_item_code":"C-DEP","source_item_id":"x-dep"}]}', '{"item_tag":"995"}'),
      (3, 1, '{"items":[{"source_item_code":"C-NEWRE","source_item_id":"x-re"},{"source_item_code":"C-CR","source_item_id":"x-cr2"}]}', '{"item_tag":"995"}'),
      (4, 3, '{"items":[{"source_item_code":"C-PD1","source_item_id":"x-q1"},{"source_item_code":"C-Q2","source_item_id":"x-pd2"}]}', '{"item_tag":"995"}'),
      (5, 3, '{"items":[{"source_item_code":"C-PD3","source_item_id":"x-q3"},{"source_item_code":"C-CAN","source_item_id":"x-can"},{"source_item_code":"C-OL","source_item_id":"x-ol"}]}', '{"item_tag":"995"}'),
      (6, 4, '{"items":[{"source_item_code":"C-DUP","source_item_id":"x-d1"},{"source_item_code":"C-E","source_item_id":"x-e"},{"source_item_code":"C-H","source_item_id":"x-h"},{"source_item_code":"C-J","source_item_id":"x-j"}]}', '{"item_tag":"995"}'),
      (7, 4, '{"items":[{"source_item_code":"C-DUP","source_item_id":"x-d2"},{"source_item_code":"C-F","source_item_id":"x-e"},{"source_item_code":"C-G","source_item_id":"x-g"},{"source_item_code":"C-H2","source_item_id":"x-h"},{"source_item_code":" C-H2 ","source_item_id":"x-h3"},{"source_item_code":"C-PD3","source_item_id":"x-j"},{"source_item_code":"  ","source_item_id":"x-sc"},{"source_item_code":"C-NOID"}]}', '{"item_tag":"995"}'),
      (8, 5, '{"items":[{"source_item_code":"C-RA","source_item_id":"x-ra"}]}', '{"item_tag":"995"}'),
      (9, 5, '{}', '{}'),
      (10, 6, '{"items":[]}', '{"item_tag":"995"}'),
      (11, 6, '{"items":[{"source_item_code":"C-L6","source_item_id":"x-l6"},{"source_item_code":"C-NOID"},{"source_item_code":"C-OS","source_item_id":"zz1"}]}', '{"item_tag":"995"}'),
      (12, 3, '{"items":[{"source_item_code":"C-SAME","source_item_id":"x-s1"},{"source_item_code":"C-SAME","source_item_id":"x-s2"},{"source_item_code":"C-S3","source_item_id":"x-s1"}]}', '{"item_tag":"995"}')
    ) x(r, bk, np, rp);
  SELECT array_agg(id ORDER BY row_no) INTO v_ids FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/h33p.iso', 'h33p.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runp;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, publisher, publication_year, normalized_payload, raw_payload, match_status, editorial_decision)
  SELECT v_runp, x.r, 'H33P-' || x.r, 'H33 promo ' || x.r, jsonb_build_array('Autrice ' || x.r), 'Ed', '2001', x.np, '{"item_tag":"995"}', 'new_record', 'pending'
    FROM (VALUES
      (1, '{"items":[{"source_item_code":"P-A","source_item_id":"pa"},{"source_item_code":"P-B","source_item_id":"pb","call_number":"KB"},{"source_item_code":"C-DL","source_item_id":"x-dl"}]}'::jsonb),
      (2, '{"items":[{"source_item_code":"P-A","source_item_id":"pa2"},{"source_item_code":"P-C","source_item_id":"pb"},{"source_item_code":"C-PD1","source_item_id":"q"},{"source_item_code":"P-D","source_item_id":"pd","owner":"O","item_type":"T"}]}'),
      (3, '{"items":[{"source_item_code":"C-RA","source_item_id":"x-ra"},{"source_item_code":"","source_item_id":"psc"}]}')
    ) x(r, np);
  SELECT array_agg(id ORDER BY row_no) INTO v_idp FROM ingest.partner_catalog_staging_rows WHERE run_id = v_runp;

  -- le constat posé sur la ligne : l'exemplaire n de la ligne r du run
  CREATE OR REPLACE FUNCTION pg_temp.h33_v(p_run bigint, p_row int, p_n int) RETURNS jsonb LANGUAGE sql AS $f$
    SELECT it FROM ingest.partner_catalog_staging_rows sr, jsonb_array_elements(sr.exemplaires_constat->'items') it
     WHERE sr.run_id = p_run AND sr.row_no = p_row AND (it->>'n')::int = p_n $f$;
  CREATE OR REPLACE FUNCTION pg_temp.h33_cree(p_run bigint, p_row int, p_n int) RETURNS bigint LANGUAGE sql AS $f$
    SELECT (pg_temp.h33_v(p_run, p_row, p_n)->>'brouillon_cree')::bigint $f$;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ── T01 ─────────────────────────────────────────────────────────────
  v_t := 'T01 Rapprocher lignes 1-5 : verdicts, brouillon, lignes, reponse';
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_r1 := public.fn_import_reconcile_duplicates(v_run, v_ids[1:5]);
    EXECUTE 'RESET ROLE';
    v_lot := (v_r1->>'batch_id')::bigint;
    v_e := '';
    IF v_r1->'verdicts' <> '{"deja_la": 1, "deplace": 1, "nouveau": 3, "sans_code": 0, "reattribue": 0, "reetiquete": 1, "code_repris": 1, "deja_en_brouillon": 3}'::jsonb
       OR (v_r1->>'created_items')::int <> 3 OR (v_r1->>'created_exemplar_drafts')::int <> 2 OR (v_r1->>'rows_signalled')::int <> 2
       OR (v_r1->>'rows_already_held')::int <> 1 OR (v_r1->>'items_skipped_code_taken')::int <> 1 OR (v_r1->>'requested_rows')::int <> 5
       OR (v_r1->>'batch_joined')::boolean OR v_lot IS NULL THEN
      v_e := v_e || ' reponse=' || (v_r1 - 'run')::text;
    END IF;
    IF pg_temp.h33_v(v_run, 1, 1)->>'verdict' <> 'deja_la' OR pg_temp.h33_v(v_run, 2, 1)->>'verdict' <> 'deplace'
       OR pg_temp.h33_v(v_run, 3, 1)->>'verdict' <> 'reetiquete' OR pg_temp.h33_v(v_run, 3, 2)->>'verdict' <> 'code_repris'
       OR (pg_temp.h33_v(v_run, 4, 1)->>'draft_id')::bigint IS DISTINCT FROM v_d1
       OR (pg_temp.h33_v(v_run, 4, 2)->>'draft_id')::bigint IS DISTINCT FROM v_d2
       OR (pg_temp.h33_v(v_run, 5, 1)->>'draft_id')::bigint IS DISTINCT FROM v_d3
       OR pg_temp.h33_v(v_run, 5, 2)->>'verdict' <> 'nouveau' OR pg_temp.h33_v(v_run, 5, 3)->>'verdict' <> 'nouveau' THEN
      v_e := v_e || ' verdicts';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.exemplar_drafts d
                    WHERE d.id = pg_temp.h33_cree(v_run, 1, 2) AND d.batch_id = v_lot AND d.status = 'draft'
                      AND d.source_item_code = 'C-N1' AND d.source_item_id = 'x-n1' AND d.import_source_id = v_src
                      AND d.import_run_id = v_run AND d.shelf_location = 'K1' AND d.notes = 'nt' AND d.source_library = 'Prop'
                      AND d.target_library_id = v_lib AND d.target_holding_id = v_h[1] AND d.target_bib_ref = 'H33T-REF-1'
                      AND d.import_staging_row_id = v_ids[1] AND d.created_by = v_coord
                      AND d.provenance_note = 'Exemplar criado a partir de catalogo parceiro "H33 S" (h33t.iso, run ' || v_run
                                              || ', linha 1): biblioteca importadora declara possuir um exemplar de "H33 livre 1". Tipo: L. Publico: P. Situacao: ok.') THEN
      v_e := v_e || ' brouillon';
    END IF;
    IF (SELECT count(*) FROM public.exemplar_drafts WHERE import_run_id = v_run) <> 3
       OR (SELECT library_id FROM public.catalog_batches WHERE id = v_lot) IS DISTINCT FROM v_lib THEN
      v_e := v_e || ' comptes';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_ids[1] AND review_status = 'draft_created'
                     AND created_exemplar_draft_id = pg_temp.h33_cree(v_run, 1, 2) AND NOT selected_for_draft
                     AND (exemplaires_constat->>'batch_id')::bigint = v_lot AND exemplaires_constat->>'via' = 'rapprochement')
       OR NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_ids[2] AND editorial_decision = 'accept_duplicate'
                        AND created_exemplar_draft_id IS NULL AND NOT selected_for_draft AND review_status = 'approved'
                        AND (exemplaires_constat->>'batch_id')::bigint = v_lot)
       OR NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_ids[4] AND editorial_decision = 'reject'
                        AND review_status = 'rejected' AND editorial_decided_by = v_coord
                        AND editorial_note = 'Todos os exemplares desta linha ja estao na biblioteca (mesmo codigo de origem): nada a aproximar.') THEN
      v_e := v_e || ' lignes';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T02 ─────────────────────────────────────────────────────────────
  v_t := 'T02 Rapprocher lignes 6-12 : deja en brouillon par un precedent de l''appel, bras dans l''ordre, cas de bord';
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_r2 := public.fn_import_reconcile_duplicates(v_run, v_ids[6:12]);
    EXECUTE 'RESET ROLE';
    v_e := '';
    IF v_r2->'verdicts' <> '{"deja_la": 0, "deplace": 0, "nouveau": 11, "sans_code": 1, "reattribue": 1, "reetiquete": 0, "code_repris": 0, "deja_en_brouillon": 7}'::jsonb
       OR NOT (v_r2->>'batch_joined')::boolean OR (v_r2->>'batch_id')::bigint IS DISTINCT FROM v_lot
       OR (v_r2->>'created_items')::int <> 11 OR (v_r2->>'created_exemplar_drafts')::int <> 5
       OR (v_r2->>'rows_already_held')::int <> 2 OR (v_r2->>'rows_signalled')::int <> 0 THEN
      v_e := v_e || ' reponse=' || (v_r2 - 'run')::text;
    END IF;
    -- par le code, d'une ligne à l'autre ; par l'expl_id de même source
    IF (pg_temp.h33_v(v_run, 7, 1)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_run, 6, 1)
       OR (pg_temp.h33_v(v_run, 7, 2)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_run, 6, 2)
       OR (pg_temp.h33_v(v_run, 7, 4)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_run, 6, 3)
       -- même code qu'un exemplaire qui n'est PAS né (déjà en brouillon) : nouveau
       OR pg_temp.h33_v(v_run, 7, 5)->>'verdict' <> 'nouveau' OR pg_temp.h33_v(v_run, 7, 3)->>'verdict' <> 'nouveau'
       -- bras « bibliothèque » de l'appel (expl_id x-j) avant le bras « notice en brouillon » (C-PD3)
       OR (pg_temp.h33_v(v_run, 7, 6)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_run, 6, 4)
       OR pg_temp.h33_v(v_run, 7, 7)->>'verdict' <> 'sans_code'
       OR pg_temp.h33_v(v_run, 7, 8)->>'verdict' <> 'nouveau'
       OR (pg_temp.h33_v(v_run, 11, 2)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_run, 7, 8)
       -- un expl_id sans source ne compte pas
       OR pg_temp.h33_v(v_run, 11, 3)->>'verdict' <> 'nouveau'
       -- dans la même ligne, par le code puis par l'expl_id
       OR (pg_temp.h33_v(v_run, 12, 2)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_run, 12, 1)
       OR (pg_temp.h33_v(v_run, 12, 3)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_run, 12, 1)
       OR pg_temp.h33_v(v_run, 8, 1)->>'verdict' <> 'reattribue'
       OR pg_temp.h33_v(v_run, 9, 1) <> jsonb_build_object('n', 1, 'code', NULL, 'expl_id', NULL, 'cote', NULL, 'verdict', 'nouveau',
                                                            'implicite', true, 'brouillon_cree', pg_temp.h33_cree(v_run, 9, 1)) THEN
      v_e := v_e || ' verdicts';
    END IF;
    IF (SELECT count(*) FROM public.exemplar_drafts WHERE import_run_id = v_run) <> 14
       OR (SELECT count(DISTINCT batch_id) FROM public.exemplar_drafts WHERE import_run_id = v_run) <> 1
       OR NOT EXISTS (SELECT 1 FROM public.exemplar_drafts d WHERE d.id = pg_temp.h33_cree(v_run, 11, 1)
                       AND d.target_holding_id = v_h[6] AND d.target_bib_ref = 'LOC-6')
       OR NOT EXISTS (SELECT 1 FROM public.exemplar_drafts d WHERE d.id = pg_temp.h33_cree(v_run, 9, 1)
                       AND d.target_holding_id IS NULL AND d.target_bib_ref = 'H33T-REF-5' AND d.source_item_code IS NULL
                       AND d.source_library = 'H33 S') THEN
      v_e := v_e || ' brouillons';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_ids[8] AND editorial_decision = 'reject'
                     AND editorial_note = 'Todos os exemplares desta linha ja estao na biblioteca ou foram reatribuidos a outra biblioteca (mesma origem): nada a aproximar.')
       OR NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE id = v_ids[10] AND editorial_decision = 'reject'
                        AND (exemplaires_constat->>'sans_exemplaire_decrit')::boolean
                        AND editorial_note = 'Todos os exemplares desta linha ja estao na biblioteca (o arquivo nao descreve nenhum exemplar desta linha): nada a aproximar.')
       OR (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run AND (exemplaires_constat->>'batch_id')::bigint = v_lot) <> 12 THEN
      v_e := v_e || ' lignes';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T03 ─────────────────────────────────────────────────────────────
  v_t := 'T03 le fonds pose par la passe = celui de sync_exemplar_draft_holdings_bridge';
  BEGIN
    SELECT jsonb_agg(jsonb_build_array(id, target_library_id, target_holding_id, target_bib_ref) ORDER BY id) INTO v_x
      FROM public.exemplar_drafts WHERE import_run_id = v_run;
    PERFORM public.sync_exemplar_draft_holdings_bridge(id) FROM public.exemplar_drafts WHERE import_run_id = v_run;
    IF v_x = (SELECT jsonb_agg(jsonb_build_array(id, target_library_id, target_holding_id, target_bib_ref) ORDER BY id)
                FROM public.exemplar_drafts WHERE import_run_id = v_run)
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE import_run_id = v_run AND target_holding_id IS NOT NULL) = 13
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_x::text, 300)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T04 ─────────────────────────────────────────────────────────────
  v_t := 'T04 identifiants croissants dans l''ordre des exemplaires ; la ligne pointe le premier';
  BEGIN
    IF NOT EXISTS (
         SELECT 1 FROM ingest.partner_catalog_staging_rows sr
          WHERE sr.run_id = v_run AND sr.created_exemplar_draft_id IS DISTINCT FROM
                (SELECT min((it->>'brouillon_cree')::bigint) FROM jsonb_array_elements(sr.exemplaires_constat->'items') it))
       AND NOT EXISTS (
         SELECT 1 FROM (SELECT (it->>'brouillon_cree')::bigint AS id,
                               lag((it->>'brouillon_cree')::bigint) OVER (ORDER BY sr.row_no, (it->>'n')::int) AS avant
                          FROM ingest.partner_catalog_staging_rows sr, jsonb_array_elements(sr.exemplaires_constat->'items') it
                         WHERE sr.run_id = v_run AND sr.row_no >= 6 AND it ? 'brouillon_cree') s
          WHERE s.avant IS NOT NULL AND s.id <= s.avant)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ordre ou premier'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T05 ─────────────────────────────────────────────────────────────
  v_t := 'T05 Promouvoir : memes regles, la notice etant neuve';
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_import_set_editorial(v_runp, v_idp, 'accept_new', 'page import: validation individuelle');
    v_r3 := public.fn_import_promote(v_runp, p_row_ids := v_idp);
    EXECUTE 'RESET ROLE';
    v_e := '';
    IF (v_r3->>'items_created')::int <> 3 THEN v_e := v_e || ' items=' || coalesce(v_r3->>'items_created', '∅'); END IF;
    IF pg_temp.h33_v(v_runp, 1, 3)->>'verdict' <> 'deplace'
       OR (pg_temp.h33_v(v_runp, 2, 1)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_runp, 1, 1)
       OR (pg_temp.h33_v(v_runp, 2, 2)->>'draft_id')::bigint IS DISTINCT FROM pg_temp.h33_cree(v_runp, 1, 2)
       OR (pg_temp.h33_v(v_runp, 2, 3)->>'draft_id')::bigint IS DISTINCT FROM v_d1
       OR pg_temp.h33_v(v_runp, 2, 4)->>'verdict' <> 'nouveau'
       OR pg_temp.h33_v(v_runp, 3, 1)->>'verdict' <> 'reattribue' OR pg_temp.h33_v(v_runp, 3, 2)->>'verdict' <> 'sans_code' THEN
      v_e := v_e || ' verdicts';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.exemplar_drafts d
                     JOIN ingest.partner_catalog_staging_rows sr ON sr.id = d.import_staging_row_id
                    WHERE d.id = pg_temp.h33_cree(v_runp, 2, 4) AND sr.row_no = 2 AND d.book_draft_id IS NOT NULL
                      AND d.target_library_id = v_lib AND d.source_library = 'O' AND d.source_item_id = 'pd'
                      AND d.import_source_id = v_src AND d.import_run_id = v_runp AND d.batch_id = (v_r3->>'batch_id')::bigint
                      AND d.provenance_note = 'Exemplar importado de "H33 S" (h33p.iso, run ' || v_runp || ', linha 2). Tipo: T.')
       OR EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows WHERE run_id = v_runp
                   AND (exemplaires_constat->>'via' IS DISTINCT FROM 'promotion'
                        OR (exemplaires_constat->>'batch_id')::bigint IS DISTINCT FROM (v_r3->>'batch_id')::bigint)) THEN
      v_e := v_e || ' brouillon-ou-lignes';
    END IF;
    IF v_e = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_e); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T06 ─────────────────────────────────────────────────────────────
  v_t := 'T06 le jugement en liste rend le verdict de fn_h21_constat_exemplaire';
  BEGIN
    WITH l AS (
      SELECT row_number() OVER () AS k, x.code, x.item
        FROM (VALUES ('C-DL', 'x-dl'), ('C-DEP', 'x-dep'), ('C-NEWRE', 'x-re'), ('C-CR', 'x-cr2'), ('C-RA', 'x-ra'),
                     ('C-PD1', 'q'), ('C-QQ', 'x-pd2'), ('C-PD3', NULL), ('C-CAN', NULL), ('C-OL', NULL), ('C-OS', 'zz1'),
                     ('C-N1', 'x-n1'), (' ', 'x'), (NULL, NULL), ('C-NEUF', 'x-neuf')) x(code, item)
    ), j AS (
      SELECT ingest.fn_h33_juger_exemplaires((SELECT jsonb_agg(jsonb_build_object('lib', v_lib, 'src', v_src, 'book', v_b[1],
                                                      'code', l.code, 'item_id', l.item, 'implicite', false, 'tgt', v_lib) ORDER BY l.k)
                                                FROM l)) AS r
    )
    SELECT count(*) FILTER (WHERE (j.r->(l.k::int - 1))->'c' IS DISTINCT FROM ingest.fn_h21_constat_exemplaire(v_lib, v_src, v_b[1], l.code, l.item)),
           string_agg(l.code || '=' || ((j.r->(l.k::int - 1))->'c')::text, ' ')
      INTO v_n, v_e
      FROM l, j;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ecart(s) | '||left(v_e, 600)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  -- (H33 bis : joué avant les mesures, sur une table de brouillons encore
  -- petite — le constat scalaire, sa référence, n'est plus d'aucun chemin
  -- de l'écran et garde ses plans d'une table vide.)
  -- L'étape « brouillons vivants » est écrite deux fois : dans le constat
  -- (ingest.fn_h21_constat_exemplaire, un exemplaire) et dans l'EXECUTE de
  -- ingest.fn_h33_juger_exemplaires (une liste). Ce tirage les tient d'accord :
  -- la liste contre la boucle d'avant (le constat scalaire, puis l'INSERT de
  -- chaque « nouveau » avant l'exemplaire suivant), annulée à chaque tirage.
  v_t := 'T10 tirage deterministe : la liste rend ce que rendaient le constat et l''INSERT, un par un (bras 2 ne dans l''appel compris)';
  DECLARE
    w_L2 uuid := gen_random_uuid();
    w_S bigint; w_S2 bigint; w_BK bigint; w_BK2 bigint; w_H bigint; w_BD bigint; w_BD2 bigint; w_BDx bigint;
    w_codes text[] := ARRAY['A', 'B', 'C', ' C ', 'D', 'PA', 'PB', 'PC', 'XL', 'XR', NULL, '  '];
    w_ids text[] := ARRAY['i1', 'i2', 'i3', 'pa', 'pb', 'xl', 'xr', NULL, ''];
    w_it int; w_n int; w_k int; w_items jsonb; w_o jsonb; w_old jsonb[]; w_rang jsonb; w_j jsonb;
    w_c jsonb; w_id bigint; w_eo jsonb; w_en jsonb;
    w_ecarts int := 0; w_total int := 0; w_par int := 0; w_avant int := 0; w_bras2 int := 0; w_detail text := '';
    w_lib uuid; w_src bigint; w_tgt uuid; w_bdc bigint; w_code text; w_iid text; w_impl boolean;
    w_cst jsonb; w_total2 int := 0; w_ecarts2 int := 0;   -- H33 bis : la liste sans naissance
  BEGIN
    PERFORM setseed(0.4242);
    v_t0 := clock_timestamp();
    INSERT INTO public.libraries (id, slug, name, is_active, visibility_level) VALUES (w_L2, 'h33-t10-b', 'H33 T10 B', true, 'public');
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('H33 T10 S', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO w_S;
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('H33 T10 S2', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO w_S2;
    INSERT INTO public.books (titulo, bib_ref) VALUES ('H33 T10 1', 'H33T10-1') RETURNING id INTO w_BK;
    INSERT INTO public.books (titulo, bib_ref) VALUES ('H33 T10 2', 'H33T10-2') RETURNING id INTO w_BK2;
    INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (w_BK, v_lib, true) RETURNING id INTO w_H;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy)
    VALUES ('H33T10-1', 'H33T10-E1', v_lib, w_H, 'XL', 'xl', w_S, 'ambos');
    INSERT INTO public.book_drafts (titulo, owner_library_id, status) VALUES ('H33 T10 notice', v_lib, 'draft') RETURNING id INTO w_BD;
    INSERT INTO public.book_drafts (titulo, owner_library_id, status) VALUES ('H33 T10 notice bis', v_lib, 'draft') RETURNING id INTO w_BD2;
    INSERT INTO public.book_drafts (titulo, owner_library_id, status) VALUES ('H33 T10 notice B', w_L2, 'draft') RETURNING id INTO w_BDx;
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, source_item_code, source_item_id, import_source_id)
    VALUES ('create', 'draft', 'pending', v_lib, 'PA', 'zz', NULL), ('create', 'cancelled', 'pending', v_lib, 'PC', 'pc', w_S),
           ('create', 'draft', 'pending', w_L2, 'B', 'i2', w_S);
    INSERT INTO public.exemplar_drafts (action, status, label_status, book_draft_id, target_library_id, source_item_code, source_item_id, import_source_id)
    VALUES ('create', 'ready', 'pending', w_BD, NULL, 'PB', 'pb', w_S), ('create', 'draft', 'pending', w_BDx, NULL, 'D', 'i3', w_S);

    FOR w_it IN 1..80 LOOP
      w_n := 4 + floor(random() * 14)::int;
      w_items := '[]'::jsonb;
      FOR w_k IN 1..w_n LOOP
        w_lib := CASE WHEN random() < 0.08 THEN NULL ELSE v_lib END;
        w_src := CASE WHEN random() < 0.15 THEN NULL WHEN random() < 0.1 THEN w_S2 ELSE w_S END;
        w_tgt := CASE WHEN random() < 0.55 THEN v_lib WHEN random() < 0.8 THEN NULL ELSE w_L2 END;
        w_bdc := CASE WHEN random() < 0.5 THEN NULL WHEN random() < 0.6 THEN w_BD WHEN random() < 0.5 THEN w_BD2 ELSE w_BDx END;
        w_code := w_codes[1 + floor(random() * array_length(w_codes, 1))::int];
        w_iid := w_ids[1 + floor(random() * array_length(w_ids, 1))::int];
        w_impl := random() < 0.05;
        w_items := w_items || jsonb_build_array(jsonb_build_object('lib', w_lib, 'src', w_src,
                     'book', CASE WHEN random() < 0.5 THEN w_BK ELSE w_BK2 END,
                     'code', CASE WHEN w_impl THEN NULL ELSE w_code END, 'item_id', CASE WHEN w_impl THEN NULL ELSE w_iid END,
                     'implicite', w_impl, 'tgt', w_tgt, 'bd', w_bdc));
      END LOOP;
      -- H33 bis : le constat de la liste SANS naissance
      -- (ingest.fn_h33_constater_exemplaires) rend, pour chacun, le constat
      -- scalaire au même instant (rien d'inséré entre-temps)
      w_cst := ingest.fn_h33_constater_exemplaires(w_items);
      FOR w_k IN 1..w_n LOOP
        w_total2 := w_total2 + 1;
        w_c := CASE WHEN (w_items->(w_k - 1)->>'implicite')::boolean
                    THEN jsonb_build_object('verdict', 'nouveau', 'implicite', true)
                    ELSE ingest.fn_h21_constat_exemplaire((w_items->(w_k - 1)->>'lib')::uuid, (w_items->(w_k - 1)->>'src')::bigint,
                           (w_items->(w_k - 1)->>'book')::bigint, w_items->(w_k - 1)->>'code', w_items->(w_k - 1)->>'item_id') END;
        IF (w_cst->(w_k - 1)->>'k')::int <> w_k OR (w_cst->(w_k - 1)->'c') IS DISTINCT FROM w_c THEN
          w_ecarts2 := w_ecarts2 + 1;
          IF w_ecarts2 <= 2 THEN w_detail := w_detail || format(' [liste sans naissance, tirage %s, rang %s : scalaire %s | liste %s]', w_it, w_k, w_c, w_cst->(w_k - 1)->'c'); END IF;
        END IF;
      END LOOP;
      -- la boucle d'avant : constat, puis INSERT de chaque « nouveau », annulés ensuite
      w_old := '{}'; w_rang := '{}';
      BEGIN
        w_k := 0;
        FOR w_o IN SELECT x FROM jsonb_array_elements(w_items) x LOOP
          w_k := w_k + 1;
          IF (w_o->>'implicite')::boolean THEN
            w_c := jsonb_build_object('verdict', 'nouveau', 'implicite', true);
          ELSE
            w_c := ingest.fn_h21_constat_exemplaire((w_o->>'lib')::uuid, (w_o->>'src')::bigint, (w_o->>'book')::bigint,
                                                    w_o->>'code', w_o->>'item_id');
          END IF;
          IF w_c->>'verdict' = 'nouveau' THEN
            INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, book_draft_id,
                                                source_item_code, source_item_id, import_source_id)
            VALUES ('create', 'draft', 'pending', (w_o->>'tgt')::uuid, (w_o->>'bd')::bigint,
                    nullif(btrim(w_o->>'code'), ''), nullif(btrim(w_o->>'item_id'), ''), (w_o->>'src')::bigint)
            RETURNING id INTO w_id;
            w_rang := w_rang || jsonb_build_object(w_id::text, w_k);
          END IF;
          w_old := w_old || w_c;
        END LOOP;
        RAISE EXCEPTION 'h33_t10_annuler';
      EXCEPTION WHEN raise_exception THEN
        IF SQLERRM <> 'h33_t10_annuler' THEN RAISE; END IF;
      END;
      -- la liste
      w_j := ingest.fn_h33_juger_exemplaires(w_items);
      FOR w_k IN 1..w_n LOOP
        w_total := w_total + 1;
        w_eo := w_old[w_k];
        IF w_eo ? 'draft_id' AND w_rang ? (w_eo->>'draft_id') THEN
          -- brouillon né dans l'appel : son rang dans la liste
          w_eo := (w_eo - 'draft_id') || jsonb_build_object('par', (w_rang->>(w_eo->>'draft_id'))::int);
          IF (w_items->(w_k - 1)->>'tgt') IS DISTINCT FROM (w_items->(w_k - 1)->>'lib') THEN w_bras2 := w_bras2 + 1; END IF;
        ELSIF w_eo ? 'draft_id' THEN
          w_avant := w_avant + 1;
        END IF;
        w_en := w_j->(w_k - 1)->'c';
        IF w_j->(w_k - 1) ? 'par' THEN
          w_en := w_en || jsonb_build_object('par', (w_j->(w_k - 1)->>'par')::int);
          w_par := w_par + 1;
        END IF;
        IF (w_j->(w_k - 1)->>'k')::int <> w_k OR w_en IS DISTINCT FROM w_eo THEN
          w_ecarts := w_ecarts + 1;
          IF w_ecarts <= 2 THEN w_detail := w_detail || format(' [tirage %s, rang %s : avant %s | liste %s]', w_it, w_k, w_eo, w_en); END IF;
        END IF;
      END LOOP;
    END LOOP;
    v_ms := extract(epoch FROM clock_timestamp() - v_t0) * 1000;
    RAISE NOTICE 'H33-TIRAGE % exemplaires jugés, % écart(s) ; % « déjà en brouillon » nés dans l''appel (dont % par le bras 2), % d''avant l''appel ; liste sans naissance : % écart(s) sur % : % ms',
      w_total, w_ecarts, w_par, w_bras2, w_avant, w_ecarts2, w_total2, round(v_ms);
    -- le tirage doit avoir exercé les trois cas, sinon il ne prouve rien
    IF w_ecarts = 0 AND w_ecarts2 = 0 AND w_total2 = w_total
       AND w_total > 500 AND w_par > 20 AND w_bras2 > 5 AND w_avant > 20
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||w_ecarts||' ecart(s) sur '||w_total
                                              ||', liste sans naissance '||w_ecarts2||' sur '||w_total2
                                              ||' (par '||w_par||', bras 2 '||w_bras2||', avant '||w_avant||')'||w_detail); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T07 ─────────────────────────────────────────────────────────────
  v_t := 'T07 mesure : Rapprocher 200 lignes x 25 exemplaires neufs, puis la page suivante, chacun < 8 s';
  DECLARE v_runm bigint; v_bm bigint[]; v_rows bigint[]; v_res jsonb; v_res2 jsonb; p int;
  BEGIN
    WITH ins AS (INSERT INTO public.books (titulo, bib_ref)
                 SELECT 'H33 mesure ' || g, 'H33T-M-' || g FROM generate_series(1, 200) g RETURNING id)
    SELECT array_agg(id ORDER BY id) INTO v_bm FROM ins;
    INSERT INTO public.book_holdings (book_id, library_id, loanable) SELECT unnest(v_bm), v_lib, true;
    -- Les notices et les fonds sont des tables stables, aux statistiques à
    -- jour en production (relevé du 12/10/2026 : 2 567 notices, 2 696 fonds) ;
    -- le banc n'en a que 3 lignes de statistiques, et les 200 de chaque naissent
    -- ici dans la transaction. Sans cet ANALYZE, la résolution du fonds
    -- (public.resolve_library_holding_bridge, inchangée : comparaison sur
    -- trim(), sans index) passe à 3,5 s pour 200 appels, contre 44 ms après —
    -- c'est le prochain goulot pour une très grosse bibliothèque.
    -- exemplar_drafts et les lignes du run, eux, restent SANS statistiques
    -- fraîches : c'est le cas que H33 corrige.
    ANALYZE public.books, public.book_holdings;
    v_ms := NULL;
    FOR p IN 1..2 LOOP
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h33m' || p || '.iso', 'h33m.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runm;
      WITH ins AS (
        INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, normalized_payload, raw_payload, match_status, editorial_decision, proposed_book_id)
        SELECT v_runm, r, 'H33M-' || p || '-' || r, 'H33 mesure ' || r,
               jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', 'H33M-' || p || '-' || r || '-' || j,
                                                                              'source_item_id', 'm' || p || '-' || r || '-' || j,
                                                                              'call_number', 'C ' || j)) FROM generate_series(1, 25) j)),
               '{"item_tag":"995"}'::jsonb, 'known_record', 'pending', v_bm[r]
          FROM generate_series(1, 200) r RETURNING id)
      SELECT array_agg(id) INTO v_rows FROM ins;
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_t0 := clock_timestamp();
      v_res := public.fn_import_reconcile_duplicates(v_runm, v_rows);
      IF p = 1 THEN v_ms := extract(epoch FROM clock_timestamp() - v_t0) * 1000; v_res2 := v_res;
      ELSE v_ms2 := extract(epoch FROM clock_timestamp() - v_t0) * 1000; END IF;
      EXECUTE 'RESET ROLE';
    END LOOP;
    RAISE NOTICE 'H33-MESURE Rapprocher 200 lignes x 25 exemplaires neufs : % ms ; page suivante : % ms', round(v_ms), round(v_ms2);
    IF (v_res2->>'created_items')::int = 5000 AND (v_res->>'created_items')::int = 5000
       AND (v_res->>'created_exemplar_drafts')::int = 200 AND (v_res->'verdicts'->>'nouveau')::int = 5000
       AND v_ms < 8000 AND v_ms2 < 8000
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||round(v_ms)||' ms puis '||round(v_ms2)||' ms ; '
                                              ||left(coalesce((v_res - 'run')::text, 'NULL'), 200)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T08 ─────────────────────────────────────────────────────────────
  v_t := 'T08 mesure : Promouvoir une page pleine (100 lignes nouvelles x 25 exemplaires) < 8 s';
  DECLARE v_runm bigint; v_rows bigint[]; v_res jsonb;
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h33mp.iso', 'h33mp.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runm;
    WITH ins AS (
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, publisher, publication_year,
                                                       normalized_payload, raw_payload, match_status, editorial_decision)
      SELECT v_runm, r, 'H33MP-' || r, 'H33 mesure promo ' || r, jsonb_build_array('Autrice H33 ' || r), 'Ed', '2001',
             jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', 'H33MP-' || r || '-' || j,
                                                                            'source_item_id', 'mp' || r || '-' || j,
                                                                            'call_number', 'C ' || j)) FROM generate_series(1, 25) j)),
             '{"item_tag":"995"}'::jsonb, 'new_record', 'pending'
        FROM generate_series(1, 100) r RETURNING id)
    SELECT array_agg(id ORDER BY id) INTO v_rows FROM ins;
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_import_set_editorial(v_runm, v_rows, 'accept_new', 'page import: validation individuelle');
    v_t0 := clock_timestamp();
    v_res := public.fn_import_promote(v_runm, p_row_ids := v_rows);
    v_ms := extract(epoch FROM clock_timestamp() - v_t0) * 1000;
    EXECUTE 'RESET ROLE';
    RAISE NOTICE 'H33-MESURE Promouvoir 100 lignes nouvelles x 25 exemplaires (une page pleine) : % ms', round(v_ms);
    IF (v_res->>'items_created')::int = 2500 AND v_ms < 8000
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||round(v_ms)||' ms ; items='||coalesce(v_res->>'items_created', '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T11 ─────────────────────────────────────────────────────────────
  -- H33 bis (12/10/2026) : les lecteurs du constat passent par la liste
  -- (ingest.fn_h33_constater_exemplaires). Un run neuf de la source (le
  -- fichier actuel : les retraits ne se constatent que sur lui), 200 lignes
  -- reconnues x 25 exemplaires, tous dans la bibliothèque et RETIRÉS ;
  -- exemplar_drafts porte les 10 000 brouillons de T07. Le recalcul de la
  -- comparaison (5 000 constats « déjà là ») et le constat des retraits
  -- (5 000 retirés réapparus).
  v_t := 'T11 mesure : recalcul et constat des retraits a 5 000 exemplaires (5 000 retires reapparus) < 8 s chacun';
  DECLARE v_runm bigint; v_rows bigint[]; v_res jsonb; v_res2 jsonb; v_ms2 numeric; v_nrec int;
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h33r.iso', 'h33r.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runm;
    WITH ins AS (
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, normalized_payload, raw_payload, match_status, editorial_decision, proposed_book_id)
      SELECT v_runm, r, 'H33R-' || r, 'H33 retraits ' || r,
             jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', 'H33R-' || r || '-' || j,
                                                                            'source_item_id', 'r' || r || '-' || j,
                                                                            'call_number', 'R ' || j)) FROM generate_series(1, 25) j)),
             '{"item_tag":"995"}'::jsonb, 'known_record', 'pending', b.id
        FROM generate_series(1, 200) r
        JOIN public.books b ON b.bib_ref = 'H33T-M-' || r
      RETURNING id)
    SELECT array_agg(id ORDER BY id) INTO v_rows FROM ins;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy)
    SELECT b.bib_ref, 'H33R-E-' || r || '-' || j, v_lib, h.id, 'H33R-' || r || '-' || j, 'r' || r || '-' || j, v_src, 'ambos'
      FROM generate_series(1, 200) r
      CROSS JOIN generate_series(1, 25) j
      JOIN public.books b ON b.bib_ref = 'H33T-M-' || r
      JOIN public.book_holdings h ON h.book_id = b.id AND h.library_id = v_lib;
    PERFORM set_config('anarbib.h21_marqueur_retrait', 'on', true);
    UPDATE public.exemplares SET retire_at = now(), retire_run_id = v_runm WHERE tombo LIKE 'H33R-E-%';
    PERFORM set_config('anarbib.h21_marqueur_retrait', '', true);
    -- exemplares est une table stable, aux statistiques à jour en production
    -- (2 762 exemplaires au 12/10/2026) ; ici, 5 000 viennent de naître dans la
    -- transaction : sans cet ANALYZE, chaque constat au catalogue parcourt la
    -- table (3,5 ms au lieu de 0,07 ms). exemplar_drafts aussi : au banc, les
    -- suites annulées le laissent souvent à « 0 ligne sur N pages » (jamais en
    -- production, où les brouillons publiés restent) ; les sous-requêtes
    -- « ORDER BY id LIMIT 1 » par exemplaire de ingest.fn_h21_exemplaires_maj
    -- et de ingest.fn_h21_retraits_constat y parcourent alors toute la clé
    -- primaire (27 s et 21 s mesurés). Le cas « brouillons sans statistiques
    -- fraîches » de H33 est celui de T07.
    ANALYZE public.exemplares, public.exemplar_drafts;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_t0 := clock_timestamp();
    v_res := public.fn_import_recomparer(v_runm, v_rows);
    v_ms := extract(epoch FROM clock_timestamp() - v_t0) * 1000;
    v_t0 := clock_timestamp();
    v_res2 := public.fn_import_retraits(v_runm, 200, 0);
    v_ms2 := extract(epoch FROM clock_timestamp() - v_t0) * 1000;
    EXECUTE 'RESET ROLE';
    v_nrec := (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_runm
                 AND (exemplaires_comparaison->>'deja_la')::int = 25);
    RAISE NOTICE 'H33-MESURE recalcul 200 lignes x 25 (5 000 constats) : % ms ; constat des retraits (5 000 retires reapparus) : % ms', round(v_ms), round(v_ms2);
    IF v_nrec = 200 AND (v_res2->'counts'->>'retire_reapparu')::int = 5000 AND v_ms < 8000 AND v_ms2 < 8000
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||round(v_ms)||' ms / '||round(v_ms2)||' ms ; deja_la x25 '||v_nrec
                                              ||' ; '||left(coalesce((v_res2 - 'items')::text, 'NULL'), 300)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T09 ─────────────────────────────────────────────────────────────
  v_t := 'T09 la borne d''une page d''appel : Rapprocher 201 lignes ou 5 001 exemplaires, Promouvoir 101 lignes ou 2 501 exemplaires refuses (HINT), rien d''ecrit';
  DECLARE v_runm bigint; v_runq bigint; v_runx bigint; v_rows bigint[]; v_one bigint[]; v_rowsq bigint[]; v_rowx bigint[]; v_av bigint; v_hints text := '';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h33b.iso', 'h33b.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runm;
    WITH ins AS (
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, normalized_payload, raw_payload, match_status, editorial_decision, proposed_book_id)
      SELECT v_runm, r, 'H33B-' || r, 'H33 borne ' || r,
             CASE WHEN r = 300 THEN jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', 'H33B-X-' || j)) FROM generate_series(1, 5001) j))
                  ELSE jsonb_build_object('items', jsonb_build_array(jsonb_build_object('source_item_code', 'H33B-' || r))) END,
             '{"item_tag":"995"}'::jsonb, 'known_record', 'pending', v_b[4]
        FROM generate_series(1, 300) r RETURNING id, row_no)
    SELECT array_agg(id ORDER BY row_no) FILTER (WHERE row_no <= 201), array_agg(id) FILTER (WHERE row_no = 300)
      INTO v_rows, v_one FROM ins;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h33bp.iso', 'h33bp.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runq;
    WITH ins AS (
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, normalized_payload, raw_payload, match_status, editorial_decision)
      SELECT v_runq, r, 'H33BP-' || r, 'H33 borne promo ' || r, jsonb_build_array('Autrice ' || r),
             jsonb_build_object('items', jsonb_build_array(jsonb_build_object('source_item_code', 'H33BP-' || r))),
             '{"item_tag":"995"}'::jsonb, 'new_record', 'pending'
        FROM generate_series(1, 101) r RETURNING id)
    SELECT array_agg(id ORDER BY id) INTO v_rowsq FROM ins;
    -- 14/10 : une ligne nouvelle de 2 501 exemplaires, au-delà de la page de promotion
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/h33bx.iso', 'h33bx.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_runx;
    WITH ins AS (
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, authors, normalized_payload, raw_payload, match_status, editorial_decision)
      VALUES (v_runx, 1, 'H33BX-1', 'H33 borne promo exemplaires', jsonb_build_array('Autrice X'),
              jsonb_build_object('items', (SELECT jsonb_agg(jsonb_build_object('source_item_code', 'H33BX-' || j)) FROM generate_series(1, 2501) j)),
              '{"item_tag":"995"}'::jsonb, 'new_record', 'pending')
      RETURNING id)
    SELECT array_agg(id) INTO v_rowx FROM ins;
    v_av := (SELECT count(*) FROM public.exemplar_drafts) + (SELECT count(*) FROM public.book_drafts);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      PERFORM public.fn_import_reconcile_duplicates(v_runm, v_rows);
      v_hints := v_hints || ' 201-lignes-accepte';
    EXCEPTION WHEN OTHERS THEN
      DECLARE h text; BEGIN GET STACKED DIAGNOSTICS h = PG_EXCEPTION_HINT; v_hints := v_hints || ' ' || coalesce(h, '∅'); END;
    END;
    BEGIN
      PERFORM public.fn_import_reconcile_duplicates(v_runm, v_one);
      v_hints := v_hints || ' 5001-accepte';
    EXCEPTION WHEN OTHERS THEN
      DECLARE h text; BEGIN GET STACKED DIAGNOSTICS h = PG_EXCEPTION_HINT; v_hints := v_hints || ' ' || coalesce(h, '∅'); END;
    END;
    PERFORM public.fn_import_set_editorial(v_runq, v_rowsq, 'accept_new', 'page import: validation individuelle');
    BEGIN
      PERFORM public.fn_import_promote(v_runq, p_row_ids := v_rowsq);
      v_hints := v_hints || ' promo-101-acceptee';
    EXCEPTION WHEN OTHERS THEN
      DECLARE h text; BEGIN GET STACKED DIAGNOSTICS h = PG_EXCEPTION_HINT; v_hints := v_hints || ' ' || coalesce(h, '∅'); END;
    END;
    PERFORM public.fn_import_set_editorial(v_runx, v_rowx, 'accept_new', 'page import: validation individuelle');
    BEGIN
      PERFORM public.fn_import_promote(v_runx, p_row_ids := v_rowx);
      v_hints := v_hints || ' promo-2501-acceptee';
    EXCEPTION WHEN OTHERS THEN
      DECLARE h text; BEGIN GET STACKED DIAGNOSTICS h = PG_EXCEPTION_HINT; v_hints := v_hints || ' ' || coalesce(h, '∅'); END;
    END;
    -- 100 lignes passent (une notice et un exemplaire chacune)
    PERFORM public.fn_import_promote(v_runq, p_row_ids := v_rowsq[1:100]);
    EXECUTE 'RESET ROLE';
    IF v_hints = ' error.import.page_too_large error.import.update_page_too_many_items'
                 ' error.import.promotion_page_too_large error.import.promotion_page_too_many_items'
       AND (SELECT count(*) FROM public.book_drafts) + (SELECT count(*) FROM public.exemplar_drafts) = v_av + 200
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE import_run_id = v_runm)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_hints); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 H33 bis : plus aucun constat scalaire hors de lui-meme ; registre des tombos lu par sa cle ; comparaison calculee une fois';
  DECLARE v_scal text; v_avant bigint; v_apres bigint; v_cfg text[];
  BEGIN
    SELECT string_agg(n.nspname || '.' || p.proname, ', ') INTO v_scal
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE p.prosrc ~ 'fn_h21_constat_exemplaire\('
       AND p.oid <> 'ingest.fn_h21_constat_exemplaire(uuid, bigint, bigint, text, text)'::regprocedure;
    SELECT p.proconfig INTO v_cfg FROM pg_proc p WHERE p.oid = 'public.tg_exemplar_draft_tombo_refuse()'::regprocedure;
    -- la garde C17 bis passe par la clé du registre, quelles que soient ses
    -- statistiques (le registre a grossi de 5 000 numéros en T11)
    v_avant := pg_stat_get_xact_numscans('public.tombos_attribues_pkey'::regclass);
    INSERT INTO public.exemplar_drafts (action, status, label_status, target_library_id, tombo)
    VALUES ('create', 'draft', 'pending', v_lib, 'H33-T12-NEUF');
    v_apres := pg_stat_get_xact_numscans('public.tombos_attribues_pkey'::regclass);
    IF v_scal IS NULL AND v_cfg @> ARRAY['enable_seqscan=off'] AND v_apres > v_avant
       AND position('with calc as materialized (' IN pg_get_functiondef('ingest.fn_h21_stocker_comparaisons(bigint, bigint[])'::regprocedure)) > 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : scalaire='||coalesce(v_scal, '∅')||' ; config='||coalesce(v_cfg::text, '∅')
                                              ||' ; parcours de la cle '||v_avant||' -> '||v_apres); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 H33 bis : la levee d''un retire reetiquete se publie ; refusee quand son exemplaire n''est plus deja la ni reetiquete, meme a cote d''un autre qui l''est';
  DECLARE w_S bigint; w_bk bigint; w_h bigint; w_x bigint; w_y bigint; w_z bigint; w_run bigint; w_p jsonb; w_lot bigint;
          w_dx bigint; w_dy bigint; w_rev jsonb; w_hy text; w_px bigint;
  BEGIN
    INSERT INTO public.network_administrators (user_id, status) VALUES ('22222222-2222-2222-2222-222222222222', 'active') ON CONFLICT DO NOTHING;
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('H33 T13 S', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO w_S;
    INSERT INTO public.books (titulo, bib_ref) VALUES ('H33 T13', 'H33T13-1') RETURNING id INTO w_bk;
    INSERT INTO public.book_holdings (book_id, library_id, loanable) VALUES (w_bk, v_lib, true) RETURNING id INTO w_h;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy)
    VALUES ('H33T13-1', 'H33T13-X', v_lib, w_h, 'C13-X', 'x13', w_S, 'ambos') RETURNING id INTO w_x;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy)
    VALUES ('H33T13-1', 'H33T13-Y', v_lib, w_h, 'C13-Y', 'y13', w_S, 'ambos') RETURNING id INTO w_y;
    INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy)
    VALUES ('H33T13-1', 'H33T13-Z', v_lib, w_h, 'C13-Z', 'z13', w_S, 'ambos') RETURNING id INTO w_z;
    PERFORM set_config('anarbib.h21_marqueur_retrait', 'on', true);
    UPDATE public.exemplares SET retire_at = now() - interval '1 day' WHERE id IN (w_x, w_y);
    PERFORM set_config('anarbib.h21_marqueur_retrait', '', true);
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (w_S, v_lib, 'essai/h33t13.iso', 'h33t13.iso', 'marc_iso2709', 'ready_for_review') RETURNING id INTO w_run;
    -- X réapparaît réétiqueté (même expl_id, autre code) ; Y déjà là, à côté de Z
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, normalized_payload, raw_payload, match_status, editorial_decision, proposed_book_id)
    VALUES (w_run, 1, 'H33T13-1', 'H33 T13 1', '{"items":[{"source_item_code":"C13-NEWX","source_item_id":"x13"}]}', '{"item_tag":"995"}', 'known_record', 'pending', w_bk),
           (w_run, 2, 'H33T13-2', 'H33 T13 2', '{"items":[{"source_item_code":"C13-Y","source_item_id":"y13"},{"source_item_code":"C13-Z","source_item_id":"z13"}]}',
            '{"item_tag":"995"}', 'known_record', 'pending', w_bk);
    EXECUTE 'SET LOCAL ROLE authenticated';
    w_p := public.fn_import_proposer_retraits(w_run);
    w_lot := (w_p->>'batch_id')::bigint;
    w_rev := public.fn_batch_review_request(w_lot, NULL);
    EXECUTE 'RESET ROLE';
    SELECT max(id) FILTER (WHERE published_exemplar_id = w_x), max(id) FILTER (WHERE published_exemplar_id = w_y)
      INTO w_dx, w_dy FROM public.exemplar_drafts WHERE import_retrait->>'nature' = 'levee';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_batch_review_verdict((w_rev->>'review_id')::bigint, 'approved', NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    -- Y n'est plus « déjà là » (son code, avec un autre expl_id de la même
    -- source : code repris) ; Z, dans la même ligne, l'est toujours
    UPDATE ingest.partner_catalog_staging_rows
       SET normalized_payload = '{"items":[{"source_item_code":"C13-Y","source_item_id":"y-autre"},{"source_item_code":"C13-Z","source_item_id":"z13"}]}'
     WHERE run_id = w_run AND row_no = 2;
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.publish_exemplar_draft(w_dy); w_hy := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS w_hy = PG_EXCEPTION_HINT; END;
    w_px := public.publish_exemplar_draft(w_dx);
    EXECUTE 'RESET ROLE';
    IF (w_p->>'levees')::int = 2 AND w_dx IS NOT NULL AND w_dy IS NOT NULL
       AND w_hy = 'error.publish.item_levee_gone_from_file' AND w_px = w_x
       AND (SELECT retire_at IS NULL FROM public.exemplares WHERE id = w_x)
       AND (SELECT retire_at IS NOT NULL FROM public.exemplares WHERE id = w_y)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(w_p::text, 'NULL')||' / Y '||coalesce(w_hy, '∅')
                                              ||' / X '||coalesce(w_px::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H33-RAPPROCHER-GROS-FICHIER OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'H33-RAPPROCHER-GROS-FICHIER ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
