-- =====================================================================
-- AnarBib — Tests d'acceptation : la photo de couverture prise en rayon
-- Date : 2026-09-27 · Migration 20260927182008_capas_la_photo_prise_en_rayon
--
-- CE QUE LA SUITE GARDE.
--   · la liste de campagne : les notices DÉTENUES par la bibliothèque, sans
--     couverture, hors ressources numériques, dans l'ordre des tombos ;
--   · la recherche trouve ce que la personne a en main : l'étiquette QR d'un
--     exemplaire (…?ex=), un ISBN écrit avec ses tirets, les seuls chiffres
--     d'un tombo, un titre — et montre alors aussi les notices couvertes ;
--   · poser : provenance « photo », fichier dans le dossier de la notice ; une
--     couverture présente n'est remplacée que sur demande explicite ; une
--     proposition du lot en attente devient sans objet ;
--   · le staff de la bibliothèque seulement ; rien pour anon.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'CAPAS PHOTO OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib    constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_staff  constant uuid := '11111111-1111-1111-1111-111111111111';   -- coordenador blmf-test
  c_autre_personne constant uuid := '22222222-2222-2222-2222-222222222222';
  c_reader constant uuid := '33333333-3333-3333-3333-333333333333';
  v_autre uuid;
  b1 bigint; b2 bigint; b3 bigint; b4 bigint; b5 bigint;
  h1 bigint; h2 bigint; h3 bigint; e2 bigint;
  v_ids bigint[]; v_txt text; v_err text; v_j jsonb; v_row record;
BEGIN
  -- Un monde à soi : les notices du seed ont une couverture le temps de la suite.
  UPDATE public.books SET cover_object_path = 'books/seed/front.jpg'
   WHERE nullif(btrim(coalesce(cover_object_path, '')), '') IS NULL;
  INSERT INTO public.libraries (slug, name) VALUES ('capas-photo-autre', 'Autre (photo)') RETURNING id INTO v_autre;

  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('A Conquista do Pão', 'TEST-PHOTO-1', 'livro', c_lib) RETURNING id INTO b1;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, isbn, owner_library_id)
  VALUES ('Anarquismo e educação', 'TEST PHOTO/2', 'livro', '9788577150724', c_lib) RETURNING id INTO b2;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, cover_object_path, cover_source)
  VALUES ('Anarquismo já coberto', 'TEST-PHOTO-3', 'livro', c_lib, 'books/TEST-PHOTO-3/front.jpg', 'openlibrary') RETURNING id INTO b3;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Anarquismo em PDF', 'TEST-PHOTO-4', 'recurso_digital', c_lib) RETURNING id INTO b4;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Anarquismo alheio', 'TEST-PHOTO-5', 'livro', v_autre) RETURNING id INTO b5;

  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (b1, c_lib, 1, 1) RETURNING id INTO h1;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (b2, c_lib, 1, 1) RETURNING id INTO h2;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (b3, c_lib, 1, 1) RETURNING id INTO h3;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (b4, c_lib, 1, 1);
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (b5, v_autre, 1, 1);
  -- b2 a le PREMIER tombo : l'ordre de campagne est celui des tombos, pas des notices.
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('TEST-PHOTO-1', 'TESTE-PHOTO-000447', c_lib, h1, 'ambos', 'public');
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('TEST PHOTO/2', 'TESTE-PHOTO-000120', c_lib, h2, 'ambos', 'public') RETURNING id INTO e2;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('TEST-PHOTO-3', 'TESTE-PHOTO-000900', c_lib, h3, 'ambos', 'public');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);

  v_t := 'T1 compte : deux sans couverture (ni le numérique, ni l''autre bibliothèque)';
  BEGIN v_j := api.capas_photo_resume(c_lib); EXCEPTION WHEN OTHERS THEN v_j := jsonb_build_object('erreur', SQLERRM); END;
  IF (v_j->>'sans_capa')::int = 2 AND (v_j->>'photographiees')::int = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_j::text); END IF;

  v_t := 'T2 liste de campagne : les deux sans couverture, dans l''ordre des tombos';
  v_ids := NULL; v_err := NULL;
  BEGIN SELECT array_agg(book_id) INTO v_ids FROM api.capas_photo_liste(c_lib, NULL, 20, 0);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ids = ARRAY[b2, b1] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, v_err, 'rien')); END IF;

  v_t := 'T3 les seuls chiffres d''un tombo : « 447 »';
  v_ids := NULL; v_err := NULL;
  BEGIN SELECT array_agg(book_id) INTO v_ids FROM api.capas_photo_liste(c_lib, '447', 20, 0);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ids = ARRAY[b1] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, v_err, 'rien')); END IF;

  v_t := 'T4 un ISBN écrit avec ses tirets';
  v_ids := NULL; v_err := NULL;
  BEGIN SELECT array_agg(book_id) INTO v_ids FROM api.capas_photo_liste(c_lib, '978-85-7715-072-4', 20, 0);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ids = ARRAY[b2] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, v_err, 'rien')); END IF;

  v_t := 'T5 l''étiquette QR d''un exemplaire (…?ex=)';
  v_ids := NULL; v_err := NULL;
  BEGIN SELECT array_agg(book_id) INTO v_ids FROM api.capas_photo_liste(c_lib, 'https://app.anarbib.is/livro/' || b2 || '?ex=' || e2, 20, 0);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ids = ARRAY[b2] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, v_err, 'rien')); END IF;

  v_t := 'T6 un titre, casse ignorée : les couvertes aussi (pour remplacer), jamais le numérique ni l''autre biblio';
  v_ids := NULL; v_err := NULL;
  BEGIN SELECT array_agg(book_id ORDER BY book_id) INTO v_ids FROM api.capas_photo_liste(c_lib, 'ANARQUISMO', 20, 0);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ids = ARRAY[b2, b3]
     AND (SELECT a_une_capa FROM api.capas_photo_liste(c_lib, 'coberto', 20, 0)) THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, v_err, 'rien')); END IF;

  v_t := 'T7 poser : provenance photo, et la proposition du lot en attente devient sans objet';
  INSERT INTO public.cover_proposals (book_id, statut, candidates)
  VALUES (b1, 'a_revoir', '[{"fullUrl":"https://covers.openlibrary.org/b/id/1-L.jpg","thumbnailUrl":"https://covers.openlibrary.org/b/id/1-M.jpg","source":"openlibrary"}]');
  v_txt := NULL;
  BEGIN v_txt := api.capas_photo_poser(b1, 'books/TEST-PHOTO-1/photo-mg4a2b.jpg', false);
  EXCEPTION WHEN OTHERS THEN v_txt := 'erreur : ' || SQLERRM; END;
  SELECT b.cover_object_path, b.cover_source, b.cover_license, b.updated_by, p.statut INTO v_row
    FROM public.books b JOIN public.cover_proposals p ON p.book_id = b.id WHERE b.id = b1;
  IF v_txt = 'posee' AND v_row.cover_object_path = 'books/TEST-PHOTO-1/photo-mg4a2b.jpg' AND v_row.cover_source = 'photo'
     AND v_row.cover_license IS NULL AND v_row.updated_by = c_staff AND v_row.statut = 'perimee' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '') || ' ' || row_to_json(v_row)::text); END IF;

  v_t := 'T8 une couverture présente n''est pas remplacée sans le demander';
  v_txt := NULL;
  BEGIN v_txt := api.capas_photo_poser(b3, 'books/TEST-PHOTO-3/photo-mg4a2c.jpg', false);
  EXCEPTION WHEN OTHERS THEN v_txt := 'erreur : ' || SQLERRM; END;
  IF v_txt = 'deja_une_capa'
     AND (SELECT cover_object_path FROM public.books WHERE id = b3) = 'books/TEST-PHOTO-3/front.jpg' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '')); END IF;

  v_t := 'T9 … et l''est quand on le demande';
  v_txt := NULL;
  BEGIN v_txt := api.capas_photo_poser(b3, 'books/TEST-PHOTO-3/photo-mg4a2c.jpg', true);
  EXCEPTION WHEN OTHERS THEN v_txt := 'erreur : ' || SQLERRM; END;
  IF v_txt = 'posee' AND (SELECT cover_source FROM public.books WHERE id = b3) = 'photo' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '')); END IF;

  v_t := 'T10 hors du dossier de la notice, ou sous un autre nom : refusé (bib_ref à nettoyer compris)';
  v_err := NULL;
  BEGIN PERFORM api.capas_photo_poser(b2, 'books/TEST-PHOTO-1/photo-abc.jpg', false); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err = 'capa_chemin_invalide' THEN
    v_err := NULL;
    BEGIN PERFORM api.capas_photo_poser(b2, 'books/TEST_PHOTO_2/front.jpg', false); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err = 'capa_chemin_invalide' THEN
      v_txt := NULL;
      BEGIN v_txt := api.capas_photo_poser(b2, 'books/TEST_PHOTO_2/photo-abc.jpg', false); EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
      IF v_txt = 'posee' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (bon chemin) : ' || coalesce(v_txt, '')); END IF;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (front) : ' || coalesce(v_err, 'accepté')); END IF;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (autre dossier) : ' || coalesce(v_err, 'accepté')); END IF;

  v_t := 'T11 la notice d''une autre bibliothèque : refusée (42501), rien d''écrit';
  v_err := NULL;
  BEGIN PERFORM api.capas_photo_poser(b5, 'books/TEST-PHOTO-5/photo-abc.jpg', false);
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM; END;
  IF v_err = '42501 capa_hors_perimetre' AND (SELECT cover_object_path FROM public.books WHERE id = b5) IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'accepté')); END IF;

  v_t := 'T12 le compte suit : plus rien sans couverture, trois photographiées';
  BEGIN v_j := api.capas_photo_resume(c_lib); EXCEPTION WHEN OTHERS THEN v_j := jsonb_build_object('erreur', SQLERRM); END;
  IF (v_j->>'sans_capa')::int = 0 AND (v_j->>'photographiees')::int = 3 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_j::text); END IF;

  v_t := 'T13 une lectrice, ou une personne d''une autre bibliothèque : refusées (42501)';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_reader, 'role', 'authenticated')::text, true);
  v_err := NULL;
  BEGIN PERFORM * FROM api.capas_photo_liste(c_lib, NULL, 20, 0); EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE; END;
  IF v_err = '42501' THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_autre_personne, 'role', 'authenticated')::text, true);
    v_err := NULL;
    BEGIN PERFORM api.capas_photo_resume(c_lib); EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE; END;
    IF v_err = '42501' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (autre personne) : ' || coalesce(v_err, 'rendu')); END IF;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (lectrice) : ' || coalesce(v_err, 'rendu')); END IF;

  v_t := 'T14 rien pour anon ; authenticated passe par la garde du corps';
  IF NOT has_function_privilege('anon', 'api.capas_photo_poser(bigint, text, boolean)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.capas_photo_liste(uuid, text, integer, integer)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.capas_photo_resume(uuid)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'api.capas_photo_poser(bigint, text, boolean)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CAPAS PHOTO ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CAPAS PHOTO OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
