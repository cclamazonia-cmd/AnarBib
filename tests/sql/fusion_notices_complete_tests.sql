-- =====================================================================
-- AnarBib — Tests d'acceptation : la fusion de notices ne perd plus rien,
-- et la référence d'un exemplaire suit son fonds
-- Date : 2026-09-28 · Migration 20260928100501_la_fusion_de_notices_ne_perd_plus_rien
--
-- CE QUE LA SUITE GARDE.
--   · merge_book reprend les champs VIDES de la notice gardée, jamais par-dessus
--     une valeur ; merge_book_with_fields ne reprend que les champs choisis ;
--   · sujets et contributeur·rices du doublon qui manquent sont repris ;
--   · le brouillon OUVERT de la notice gardée reçoit ce qu'elle a reçu (sinon sa
--     publication l'efface) ; celui du doublon est écarté, pas rattaché ;
--   · les exemplaires du doublon suivent, avec la référence de leur fonds ;
--   · le doublon est gardé entier dans merge_log.details ;
--   · l'invariant : renommer une notice, poser une référence locale, créer un
--     exemplaire — la référence de l'exemplaire suit toujours son fonds ;
--   · rien de neuf n'est ouvert au lectorat.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'FUSION COMPLETE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_coord constant uuid := '11111111-1111-1111-1111-111111111111';   -- coordenador blmf-test = arbitre
  v_l2 uuid;
  v_sujet bigint; v_a bigint; v_b bigint;
  v_c bigint; v_d bigint; v_c2 bigint; v_d2 bigint;
  v_hc bigint; v_hd bigint; v_hd2 bigint;
  v_ec bigint; v_ed bigint; v_ed2 bigint; v_enouv bigint;
  v_dc bigint; v_dd bigint;
  v_hd2b bigint; v_ed2b bigint;
  v_res bigint; v_xd bigint; v_setup text;
  c_reader constant uuid := '33333333-3333-3333-3333-333333333333';   -- lectrice blmf-test (seed)
  v_row record; v_j jsonb; v_n int; v_txt text;
BEGIN
  INSERT INTO public.libraries (slug, name) VALUES ('fusion-autre-test', 'Autre (fusion)') RETURNING id INTO v_l2;
  INSERT INTO public.subjects (slug) VALUES ('fusion-sujet-test') RETURNING id INTO v_sujet;
  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Élisée Reclus', 'Reclus, Élisée') RETURNING id INTO v_a;
  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Trad Uctrice', 'Uctrice, Trad') RETURNING id INTO v_b;

  -- La notice gardée : année et ISBN, pas de couverture, pas de note, pas de sujet.
  INSERT INTO public.books (titulo, bib_ref, tipo_material, ano, isbn, owner_library_id)
  VALUES ('Da Escravidão nos Estados Unidos', 'FUS-C', 'livro', '2010', '9788579350085', c_lib) RETURNING id INTO v_c;
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  VALUES (v_c, v_a, 1, 'Reclus, Élisée', 'autor', true);
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_c, c_lib, 1, 1) RETURNING id INTO v_hc;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('FUS-C', 'FUS-EX-C', c_lib, v_hc, 'ambos', 'public') RETURNING id INTO v_ec;

  -- Le doublon : autre année, une couverture, une note, un sujet, une personne de plus.
  INSERT INTO public.books (titulo, bib_ref, tipo_material, ano, owner_library_id, cover_object_path, cover_source, notas)
  VALUES ('Da Escravidão nos Estados Unidos', 'FUS-D', 'livro', '2011', c_lib, 'books/FUS-D/front.jpg', 'manual', 'Note du doublon')
  RETURNING id INTO v_d;
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary) VALUES
    (v_d, v_a, 1, 'Reclus, Élisée', 'autor', true),
    (v_d, v_b, 2, 'Uctrice, Trad', 'tradutor', false);
  INSERT INTO public.book_subjects (book_id, subject_id, ord) VALUES (v_d, v_sujet, 1);
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_d, c_lib, 1, 1) RETURNING id INTO v_hd;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_d, v_l2, 1, 1) RETURNING id INTO v_hd2;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('FUS-D', 'FUS-EX-D', c_lib, v_hd, 'ambos', 'public') RETURNING id INTO v_ed;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('FUS-D', 'FUS-EX-D2', v_l2, v_hd2, 'ambos', 'public') RETURNING id INTO v_ed2;

  -- Un brouillon ouvert sur chacune (celui de la notice gardée : celui qu'on édite).
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, published_book_id, ano, isbn, created_by)
  VALUES ('update', 'draft', 'FUS-C', 'Da Escravidão nos Estados Unidos', 'livro', c_lib, v_c, '2010', '9788579350085', c_coord) RETURNING id INTO v_dc;
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id, published_book_id, ano, created_by)
  VALUES ('update', 'draft', 'FUS-D', 'Da Escravidão nos Estados Unidos', 'livro', c_lib, v_d, '2011', c_coord) RETURNING id INTO v_dd;

  -- Une réservation active sur le fonds du doublon (par sa référence), et un
  -- exemplaire encore à créer qui vise le doublon par sa référence.
  v_setup := NULL;
  BEGIN
    INSERT INTO public.reservas_v2 (user_id, library_id, status_global) VALUES (c_reader, c_lib, 'ativa') RETURNING id INTO v_res;
    INSERT INTO public.reserva_linhas_v2 (reserva_id, line_no, book_id, holding_id, bib_ref, item_status)
    VALUES (v_res, 1, v_d, v_hd, 'FUS-D', 'ativa');
    INSERT INTO public.exemplar_drafts (action, status, target_bib_ref, target_library_id, tombo)
    VALUES ('create', 'draft', 'FUS-D', c_lib, 'FUS-EX-A-CREER') RETURNING id INTO v_xd;
  EXCEPTION WHEN OTHERS THEN v_setup := SQLSTATE || ' ' || SQLERRM;
  END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_coord, 'role', 'authenticated')::text, true);

  v_t := 'T0 la fusion se fait';
  BEGIN
    PERFORM public.merge_book(v_c, v_d);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLSTATE || ' ' || SQLERRM);
  END;

  v_t := 'T1 le doublon est supprimé, et gardé ENTIER dans merge_log';
  SELECT details INTO v_j FROM public.merge_log
   WHERE entity_type = 'book' AND canonical_id = v_c AND duplicate_id = v_d AND merged_by = c_coord;
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = v_d)
     AND v_j ?& ARRAY['duplicate_titulo', 'notice', 'sujets', 'contributeurs', 'fonds', 'exemplaires', 'brouillons',
                      'couverture_proposee', 'champs_repris', 'champs_choisis', 'sujets_repris', 'contributeurs_repris', 'brouillons_ecartes']
     AND v_j->'notice'->>'bib_ref' = 'FUS-D' AND jsonb_array_length(v_j->'exemplaires') = 2
     AND (v_j->>'sujets_repris')::int = 1 AND (v_j->>'contributeurs_repris')::int = 1 AND (v_j->>'brouillons_ecartes')::int = 1 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(left(v_j::text, 200), 'aucune trace')); END IF;

  v_t := 'T2 les champs vides sont repris (couverture, note), jamais par-dessus une valeur (année, ISBN)';
  SELECT * INTO v_row FROM public.books WHERE id = v_c;
  IF v_row.cover_object_path = 'books/FUS-D/front.jpg' AND v_row.cover_source = 'manual' AND v_row.notas = 'Note du doublon'
     AND v_row.ano = '2010' AND v_row.isbn = '9788579350085' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || row_to_json(v_row)::text); END IF;

  v_t := 'T3 le sujet et la personne en plus sont repris, sans doubler la personne commune';
  SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = v_c;
  IF EXISTS (SELECT 1 FROM public.book_subjects WHERE book_id = v_c AND subject_id = v_sujet)
     AND v_n = 2
     AND EXISTS (SELECT 1 FROM public.book_contributors WHERE book_id = v_c AND author_id = v_b AND role = 'tradutor') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : contributeur·rices=' || v_n); END IF;

  v_t := 'T4 les exemplaires suivent, avec la référence de leur fonds';
  IF (SELECT holding_id FROM public.exemplares WHERE id = v_ed) = v_hc
     AND (SELECT bib_ref FROM public.exemplares WHERE id = v_ed) = 'FUS-C'
     AND (SELECT book_id FROM public.book_holdings WHERE id = v_hd2) = v_c
     AND (SELECT bib_ref FROM public.exemplares WHERE id = v_ed2) = 'FUS-C'
     AND NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hd) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : '
    || (SELECT string_agg(tombo || '→' || bib_ref || '@' || coalesce(holding_id::text, '-'), ', ') FROM public.exemplares WHERE id IN (v_ed, v_ed2))); END IF;

  v_t := 'T4b la réservation sur le fonds du doublon suit le fonds gardé, avec sa référence ; l''exemplaire à créer vise la notice gardée';
  IF v_setup IS NOT NULL THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : mise en place impossible — ' || v_setup);
  ELSIF (SELECT holding_id FROM public.reserva_linhas_v2 WHERE reserva_id = v_res AND line_no = 1) = v_hc
     AND (SELECT bib_ref FROM public.reserva_linhas_v2 WHERE reserva_id = v_res AND line_no = 1) = 'FUS-C'
     AND (SELECT book_id FROM public.reserva_linhas_v2 WHERE reserva_id = v_res AND line_no = 1) = v_c
     AND (SELECT target_bib_ref FROM public.exemplar_drafts WHERE id = v_xd) = 'FUS-C' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : '
    || (SELECT row_to_json(x)::text FROM (SELECT holding_id, bib_ref, book_id FROM public.reserva_linhas_v2 WHERE reserva_id = v_res AND line_no = 1) x)
    || ' / ' || coalesce((SELECT target_bib_ref FROM public.exemplar_drafts WHERE id = v_xd), '-')); END IF;

  v_t := 'T5 le brouillon ouvert du doublon est écarté, pas rattaché ouvert';
  SELECT status, published_book_id INTO v_row FROM public.book_drafts WHERE id = v_dd;
  IF v_row.status = 'cancelled' AND v_row.published_book_id = v_c THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || row_to_json(v_row)::text); END IF;

  v_t := 'T6 le brouillon ouvert de la notice gardée reçoit couverture, note, sujet et personne — sa publication ne les effacera pas';
  SELECT cover_object_path, notas, ano INTO v_row FROM public.book_drafts WHERE id = v_dc;
  IF v_row.cover_object_path = 'books/FUS-D/front.jpg' AND v_row.notas = 'Note du doublon' AND v_row.ano = '2010'
     AND EXISTS (SELECT 1 FROM public.book_draft_subjects WHERE book_draft_id = v_dc AND subject_id = v_sujet)
     AND EXISTS (SELECT 1 FROM public.book_draft_contributors WHERE draft_id = v_dc AND author_id = v_b) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || row_to_json(v_row)::text); END IF;

  v_t := 'T7 merge_book_with_fields sans champ choisi : rien de repris d''office, mais le sujet suit';
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id) VALUES ('Paire deux', 'FUS-C2', 'livro', c_lib) RETURNING id INTO v_c2;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, notas) VALUES ('Paire deux', 'FUS-D2', 'livro', c_lib, 'note D2') RETURNING id INTO v_d2;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_c2, c_lib, 0, 0);
  INSERT INTO public.book_subjects (book_id, subject_id, ord) VALUES (v_d2, v_sujet, 1);
  -- Le fonds du doublon, dans la même bibliothèque, porte une référence locale.
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref, notes, exemplares_total, available_count)
  VALUES (v_d2, c_lib, 'LOC-D2', 'note du fonds D2', 1, 1) RETURNING id INTO v_hd2b;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('LOC-D2', 'FUS-EX-D2B', c_lib, v_hd2b, 'ambos', 'public') RETURNING id INTO v_ed2b;
  BEGIN
    PERFORM public.merge_book_with_fields(v_c2, v_d2, '{}'::text[]);
    IF (SELECT notas FROM public.books WHERE id = v_c2) IS NULL
       AND EXISTS (SELECT 1 FROM public.book_subjects WHERE book_id = v_c2 AND subject_id = v_sujet)
       AND NOT EXISTS (SELECT 1 FROM public.books WHERE id = v_d2) THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  v_t := 'T7b deux fonds dans la même bibliothèque : la référence locale et les notes du fonds supprimé passent au fonds gardé, l''exemplaire aussi';
  SELECT h.id, h.local_bib_ref, h.notes INTO v_row FROM public.book_holdings h WHERE h.book_id = v_c2 AND h.library_id = c_lib;
  IF v_row.local_bib_ref = 'LOC-D2' AND v_row.notes = 'note du fonds D2'
     AND NOT EXISTS (SELECT 1 FROM public.book_holdings WHERE id = v_hd2b)
     AND (SELECT holding_id FROM public.exemplares WHERE id = v_ed2b) = v_row.id
     AND (SELECT bib_ref FROM public.exemplares WHERE id = v_ed2b) = 'LOC-D2' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(row_to_json(v_row)::text, 'aucun fonds')
    || ' / ' || coalesce((SELECT bib_ref || '@' || coalesce(holding_id::text, '-') FROM public.exemplares WHERE id = v_ed2b), '-')); END IF;

  PERFORM set_config('request.jwt.claims', '', true);

  v_t := 'T8 renommer la notice : ses exemplaires sans référence locale suivent, et la réservation aussi';
  UPDATE public.books SET bib_ref = 'FUS-C-NOUVELLE' WHERE id = v_c;
  IF (SELECT count(*) FROM public.exemplares WHERE id IN (v_ec, v_ed, v_ed2) AND bib_ref = 'FUS-C-NOUVELLE') = 3
     AND (v_setup IS NOT NULL OR (SELECT bib_ref FROM public.reserva_linhas_v2 WHERE reserva_id = v_res AND line_no = 1) = 'FUS-C-NOUVELLE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : '
    || (SELECT string_agg(tombo || '→' || bib_ref, ', ') FROM public.exemplares WHERE id IN (v_ec, v_ed, v_ed2))
    || ' / réservation ' || coalesce((SELECT bib_ref FROM public.reserva_linhas_v2 WHERE reserva_id = v_res AND line_no = 1), '-')); END IF;

  v_t := 'T9 poser une référence locale sur un fonds : ses exemplaires et sa réservation la prennent, pas les exemplaires des autres fonds';
  UPDATE public.book_holdings SET local_bib_ref = 'LOC-FUS-1' WHERE id = v_hc;
  IF (SELECT count(*) FROM public.exemplares WHERE id IN (v_ec, v_ed) AND bib_ref = 'LOC-FUS-1') = 2
     AND (SELECT bib_ref FROM public.exemplares WHERE id = v_ed2) = 'FUS-C-NOUVELLE'
     AND (v_setup IS NOT NULL OR (SELECT bib_ref FROM public.reserva_linhas_v2 WHERE reserva_id = v_res AND line_no = 1) = 'LOC-FUS-1') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : '
    || (SELECT string_agg(tombo || '→' || bib_ref, ', ') FROM public.exemplares WHERE id IN (v_ec, v_ed, v_ed2))
    || ' / réservation ' || coalesce((SELECT bib_ref FROM public.reserva_linhas_v2 WHERE reserva_id = v_res AND line_no = 1), '-')); END IF;

  v_t := 'T10 un exemplaire créé avec la référence de la notice prend celle de son fonds';
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, circulation_policy, visibility)
  VALUES ('FUS-C-NOUVELLE', 'FUS-EX-NOUVEAU', c_lib, 'ambos', 'public') RETURNING id INTO v_enouv;
  SELECT holding_id, bib_ref INTO v_row FROM public.exemplares WHERE id = v_enouv;
  IF v_row.holding_id = v_hc AND v_row.bib_ref = 'LOC-FUS-1' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || row_to_json(v_row)::text); END IF;

  v_t := 'T11 une référence écrite à la main hors de la règle est ramenée à celle du fonds';
  UPDATE public.exemplares SET bib_ref = 'N-IMPORTE-QUOI' WHERE id = v_ed2;
  IF (SELECT bib_ref FROM public.exemplares WHERE id = v_ed2) = 'FUS-C-NOUVELLE' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || (SELECT bib_ref FROM public.exemplares WHERE id = v_ed2)); END IF;

  v_t := 'T12 rien de neuf n''est ouvert au lectorat ; les deux fusions restent ouvertes au staff';
  IF NOT has_function_privilege('anon', 'public.fn_fusion_notices(bigint, bigint, text[], boolean)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_fusion_notices(bigint, bigint, text[], boolean)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.tg_exemplaire_reference_suit_son_fonds()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.tg_fonds_reference_des_exemplaires()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.tg_notice_renommee_ses_exemplaires_suivent()', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.merge_book(bigint, bigint)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.merge_book(bigint, bigint)', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'FUSION COMPLETE ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'FUSION COMPLETE OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
