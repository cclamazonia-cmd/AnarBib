-- =====================================================================
-- AnarBib — Tests d'acceptation : la recherche de capas passe du bouton au lot
-- Date : 2026-09-27 · Migration 20260927180120_capas_la_recherche_passe_du_bouton_au_lot
--
-- CE QUE LA SUITE GARDE.
--   · le lot ne cherche que des « livro » sans capa, titrés, hors bac à
--     sable ; jamais cherchées d'abord, à ISBN en tête ; une recherche vide se
--     refait après 90 jours, une recherche en panne le lendemain ;
--   · le lot range sans écraser : une proposition en attente ou tranchée par
--     une personne reste telle quelle ; les aperçus (data:) n'entrent pas en
--     base ;
--   · l'écran de revue ne montre et ne laisse trancher que le périmètre de la
--     personne (bibliothèque qui possède ou détient la notice ; tout pour
--     l'administration du réseau) ; la provenance posée est celle de la
--     PROPOSITION ; une capa posée entre-temps n'est jamais remplacée ;
--   · rien du lot n'est ouvert au lectorat.
-- Convention maison : la suite se termine par un RAISE EXCEPTION, tout est
-- annulé, même en cas de succès.
--   Bilan OK : 'CAPAS LOT OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib    constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_staff  constant uuid := '11111111-1111-1111-1111-111111111111';   -- coordenador blmf-test
  c_admin  constant uuid := '22222222-2222-2222-2222-222222222222';   -- sans adhésion : admin réseau ici
  c_reader constant uuid := '33333333-3333-3333-3333-333333333333';   -- lectrice blmf-test
  v_autre uuid; v_bac uuid;
  b1 bigint; b2 bigint; b3 bigint; b4 bigint; b5 bigint; b6 bigint; b7 bigint; b8 bigint;
  v_ids bigint[]; v_txt text; v_err text; v_row record; v_j jsonb;
  c_ol    constant text := 'https://covers.openlibrary.org/b/id/951719-L.jpg';
  c_cands jsonb;
  c_ok    constant jsonb := '[{"id":"openlibrary","ok":true,"count":0},{"id":"inventaire","ok":true,"skipped":true,"count":0}]';
BEGIN
  -- ── Un monde à soi : les notices du seed ont une capa, le temps de la suite ──
  UPDATE public.books SET cover_object_path = 'books/seed/front.jpg'
   WHERE nullif(btrim(coalesce(cover_object_path, '')), '') IS NULL;

  INSERT INTO public.libraries (slug, name) VALUES ('capas-autre-test', 'Autre (capas)') RETURNING id INTO v_autre;
  INSERT INTO public.libraries (slug, name) VALUES ('capas-teste', 'Bac à sable (capas)') RETURNING id INTO v_bac;

  INSERT INTO public.books (titulo, bib_ref, tipo_material, isbn, owner_library_id)
  VALUES ('L''anarchisme aujourd''hui', 'CAPAS-T1', 'livro', '978-2-296-03507-2', c_lib) RETURNING id INTO b1;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('A Conquista do Pão', 'CAPAS-T2', 'livro', c_lib) RETURNING id INTO b2;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, cover_object_path)
  VALUES ('Déjà couverte', 'CAPAS-T3', 'livro', c_lib, 'books/CAPAS-T3/front.jpg') RETURNING id INTO b3;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Un périodique', 'CAPAS-T4', 'periodico', c_lib) RETURNING id INTO b4;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Exercice de formation', 'CAPAS-T5', 'livro', v_bac) RETURNING id INTO b5;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Hors du périmètre', 'CAPAS-T6', 'livro', v_autre) RETURNING id INTO b6;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Détenu ici, possédé ailleurs', 'CAPAS T7/é', 'livro', v_autre) RETURNING id INTO b7;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (b7, c_lib, 1, 1);
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('À écarter', 'CAPAS-T8', 'livro', c_lib) RETURNING id INTO b8;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('   ', 'CAPAS-T9', 'livro', c_lib);  -- sans titre : rien à chercher

  c_cands := jsonb_build_array(
    jsonb_build_object('thumbnailUrl', 'https://covers.openlibrary.org/b/id/951719-M.jpg', 'fullUrl', c_ol,
                       'source', 'openlibrary', 'license', null, 'voie', 'isbn',
                       'thumbnailData', 'data:image/jpeg;base64,AAAA',
                       'edition', jsonb_build_object('annee', '2007', 'editeurs', jsonb_build_array('L''Harmattan'))),
    jsonb_build_object('thumbnailUrl', 'http://exemple.org/x.jpg', 'fullUrl', 'http://exemple.org/x.jpg', 'source', 'og_image'));

  -- ── Le lot : quoi chercher ─────────────────────────────────────────
  v_t := 'T1 à chercher : livro sans capa, titré, hors bac à sable ; ISBN en tête';
  SELECT array_agg(book_id) INTO v_ids FROM public.fn_capas_lot_a_chercher(100);
  IF v_ids = ARRAY[b1, b2, b6, b7, b8] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, 'rien')); END IF;

  -- ── Le lot : où ranger ─────────────────────────────────────────────
  v_t := 'T2 candidates trouvées : a_revoir, sans aperçu ni adresse non https';
  v_txt := public.fn_capas_lot_enregistrer(b1, c_cands, c_ok);
  SELECT * INTO v_row FROM public.cover_proposals WHERE book_id = b1;
  IF v_txt = 'a_revoir' AND jsonb_array_length(v_row.candidates) = 1
     AND NOT (v_row.candidates->0 ? 'thumbnailData') AND v_row.candidates->0->>'fullUrl' = c_ol THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt || ' ' || coalesce(v_row.candidates::text, '')); END IF;

  v_t := 'T3 rien trouvé, une source en panne : en_panne';
  v_txt := public.fn_capas_lot_enregistrer(b2, '[]'::jsonb,
    '[{"id":"openlibrary","ok":false,"count":0,"error":"HTTP 503"},{"id":"inventaire","ok":true,"skipped":true,"count":0}]');
  IF v_txt = 'en_panne' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  v_t := 'T4 rien trouvé, sources muettes mais vivantes : sans_resultat';
  v_txt := public.fn_capas_lot_enregistrer(b6, '[]'::jsonb, c_ok);
  IF v_txt = 'sans_resultat' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  v_t := 'T5 une proposition en attente n''est pas écrasée par une nouvelle recherche';
  v_txt := public.fn_capas_lot_enregistrer(b1, '[]'::jsonb, c_ok);
  IF v_txt = 'inchange' AND (SELECT statut FROM public.cover_proposals WHERE book_id = b1) = 'a_revoir' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  PERFORM public.fn_capas_lot_enregistrer(b7, c_cands, c_ok);
  PERFORM public.fn_capas_lot_enregistrer(b8, c_cands, c_ok);

  v_t := 'T6 les délais : en panne le lendemain, sans résultat après 90 jours, en attente jamais';
  SELECT array_agg(book_id) INTO v_ids FROM public.fn_capas_lot_a_chercher(100);
  IF v_ids IS NULL THEN
    UPDATE public.cover_proposals SET cherche_le = now() - interval '2 days' WHERE book_id IN (b1, b2, b6);
    SELECT array_agg(book_id) INTO v_ids FROM public.fn_capas_lot_a_chercher(100);
    IF v_ids = ARRAY[b2] THEN
      UPDATE public.cover_proposals SET cherche_le = now() - interval '91 days' WHERE book_id = b6;
      SELECT array_agg(book_id ORDER BY book_id) INTO v_ids FROM public.fn_capas_lot_a_chercher(100);
      IF v_ids = ARRAY[b2, b6] THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (91 j) : ' || coalesce(v_ids::text, 'rien')); END IF;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (2 j) : ' || coalesce(v_ids::text, 'rien')); END IF;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (tout de suite) : ' || v_ids::text); END IF;
  UPDATE public.cover_proposals SET cherche_le = now() WHERE book_id IN (b2, b6);

  -- ── L'écran de revue : le périmètre ────────────────────────────────
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);

  v_t := 'T7 liste : le périmètre de la coordination (possédé ou détenu), ISBN d''abord';
  -- b6 remis « à revoir » : il ne doit PAS paraître (possédé ailleurs, pas détenu ici)
  UPDATE public.cover_proposals SET statut = 'a_revoir', candidates = c_cands - 1 WHERE book_id = b6;
  SELECT array_agg(book_id ORDER BY book_id) INTO v_ids FROM api.capas_revue_liste(50, 0);
  IF v_ids = ARRAY[b1, b7, b8] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, 'rien')); END IF;

  v_t := 'T8 résumé : trois à revoir dans le périmètre, une en panne';
  v_j := api.capas_revue_resume();
  IF (v_j->>'a_revoir')::int = 3 AND (v_j->>'en_panne')::int = 1 AND (v_j->>'a_chercher')::int = 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_j::text); END IF;

  v_t := 'T9 une lectrice n''atteint pas l''écran de revue';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_reader, 'role', 'authenticated')::text, true);
  v_err := NULL;
  BEGIN PERFORM * FROM api.capas_revue_liste(10, 0); EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE; END;
  IF v_err = '42501' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'liste rendue')); END IF;

  -- ── Accepter ───────────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);

  v_t := 'T10 une adresse absente de la proposition est refusée';
  v_err := NULL;
  BEGIN PERFORM api.capas_revue_accepter(b1, 'https://evil.example/x.jpg', 'books/CAPAS-T1/capa-abc.jpg');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err = 'capa_candidate_inconnue' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'acceptée')); END IF;

  v_t := 'T11 un fichier hors du dossier de la notice est refusé';
  v_err := NULL;
  BEGIN PERFORM api.capas_revue_accepter(b1, c_ol, 'books/CAPAS-T8/capa-abc.jpg');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err = 'capa_chemin_invalide' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'accepté')); END IF;

  v_t := 'T12 accepter pose la capa, avec la provenance de la proposition';
  v_txt := api.capas_revue_accepter(b1, c_ol, 'books/CAPAS-T1/capa-mg3k2x1a.jpg');
  SELECT b.cover_object_path, b.cover_source, b.cover_license, b.updated_by, p.statut, p.retenue->>'fullUrl' AS retenue, p.decided_by
    INTO v_row
    FROM public.books b JOIN public.cover_proposals p ON p.book_id = b.id WHERE b.id = b1;
  IF v_txt = 'acceptee' AND v_row.cover_object_path = 'books/CAPAS-T1/capa-mg3k2x1a.jpg'
     AND v_row.cover_source = 'openlibrary' AND v_row.cover_license IS NULL AND v_row.updated_by = c_staff
     AND v_row.statut = 'acceptee' AND v_row.retenue = c_ol AND v_row.decided_by = c_staff THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '') || ' ' || row_to_json(v_row)::text); END IF;

  v_t := 'T13 une proposition tranchée ne se tranche pas deux fois';
  v_err := NULL;
  BEGIN PERFORM api.capas_revue_accepter(b1, c_ol, 'books/CAPAS-T1/capa-autre.jpg');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err = 'capa_proposition_close' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'acceptée')); END IF;

  v_t := 'T14 hors du périmètre : refusé (42501), rien d''écrit';
  v_err := NULL;
  BEGIN PERFORM api.capas_revue_accepter(b6, c_ol, 'books/CAPAS-T6/capa-abc.jpg');
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err = '42501 capa_hors_perimetre'
     AND (SELECT cover_object_path FROM public.books WHERE id = b6) IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'accepté')); END IF;

  v_t := 'T15 détenue ici (bib_ref à nettoyer) ; une capa posée entre-temps n''est pas remplacée';
  UPDATE public.books SET cover_object_path = 'books/CAPAS_T7__/front.jpg', cover_source = 'manual' WHERE id = b7;
  v_txt := api.capas_revue_accepter(b7, c_ol, 'books/CAPAS_T7__/capa-abc.jpg');
  SELECT b.cover_object_path, b.cover_source, p.statut INTO v_row
    FROM public.books b JOIN public.cover_proposals p ON p.book_id = b.id WHERE b.id = b7;
  IF v_txt = 'perimee' AND v_row.cover_object_path = 'books/CAPAS_T7__/front.jpg'
     AND v_row.cover_source = 'manual' AND v_row.statut = 'perimee' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '') || ' ' || row_to_json(v_row)::text); END IF;

  -- ── Écarter, rouvrir ───────────────────────────────────────────────
  v_t := 'T16 écartée : plus jamais reproposée par le lot, même après 100 jours';
  v_txt := api.capas_revue_ecarter(b8);
  UPDATE public.cover_proposals SET cherche_le = now() - interval '100 days' WHERE book_id = b8;
  IF v_txt = 'ecartee'
     AND NOT EXISTS (SELECT 1 FROM public.fn_capas_lot_a_chercher(100) WHERE book_id = b8)
     AND public.fn_capas_lot_enregistrer(b8, c_cands, c_ok) = 'inchange' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '')); END IF;

  v_t := 'T17 rouvrir défait l''écartement';
  v_txt := api.capas_revue_rouvrir(b8);
  IF v_txt = 'a_revoir' AND (SELECT decided_by FROM public.cover_proposals WHERE book_id = b8) IS NULL THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '')); END IF;

  -- ── L'administration du réseau voit tout ───────────────────────────
  v_t := 'T18 administration du réseau : le hors-périmètre paraît';
  INSERT INTO public.network_administrators (user_id, status) VALUES (c_admin, 'active');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);
  IF EXISTS (SELECT 1 FROM api.capas_revue_liste(50, 0) WHERE book_id = b6) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── Le cron ────────────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claims', '', true);

  v_t := 'T19 le cron range l''obsolète et appelle cover-batch s''il reste à chercher';
  UPDATE public.books SET cover_object_path = 'books/CAPAS-T8/front.jpg' WHERE id = b8;
  UPDATE public.cover_proposals SET cherche_le = now() - interval '2 days' WHERE book_id = b2;  -- à rechercher
  PERFORM public.fn_capas_lot_call();
  IF (SELECT statut FROM public.cover_proposals WHERE book_id = b8) = 'perimee'
     AND EXISTS (SELECT 1 FROM net.http_request_queue q WHERE q.url LIKE '%/functions/v1/cover-batch'
                  AND q.headers ? 'X-Cron-Secret') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── Les droits ─────────────────────────────────────────────────────
  v_t := 'T20 rien du lot ni la table ne sont ouverts au lectorat';
  IF NOT has_function_privilege('authenticated', 'public.fn_capas_lot_a_chercher(integer)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_capas_lot_enregistrer(bigint, jsonb, jsonb)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_capas_lot_call()', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.capas_revue_accepter(bigint, text, text)', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.fn_capas_lot_enregistrer(bigint, jsonb, jsonb)', 'EXECUTE')
     AND NOT has_table_privilege('authenticated', 'public.cover_proposals', 'SELECT')
     AND NOT has_table_privilege('anon', 'public.cover_proposals', 'SELECT') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CAPAS LOT ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CAPAS LOT OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
