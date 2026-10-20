-- =====================================================================
-- AnarBib — Tests d'acceptation : la page 1 des PDF comme couverture, en lot
-- Date : 2026-10-20 · Migration 20261020203753_capas_la_page_un_des_pdf_en_lot
-- Session : Anarchief — capas page 1 des PDF
--
-- CE QUE LA SUITE GARDE.
--   · le compte : faisables = détenues, sans couverture, avec un PDF versé et
--     actif ; restreintes = celles d'entre elles sans PDF public (décision du
--     20/10 : elles sont traitées, l'écran les annonce) ;
--   · la liste : seulement les faisables, un PDF public d'abord, puis le
--     principal ; un PDF retiré ne compte pas ; `exclure` écarte une notice ;
--   · poser : provenance pdf_page1, dossier de la notice (bib_ref nettoyée,
--     ou l'id quand elle manque) ; jamais de remplacement ; jamais sans PDF
--     actif ; une proposition du lot en attente devient sans objet ;
--   · le staff de la bibliothèque seulement ; rien pour anon ;
--   · api.capas_pdf_bibliotheques (20261020211530) : l'administration du
--     réseau seule, qui y voit les bibliothèques ayant à faire.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'CAPAS PDF OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib    constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_staff  constant uuid := '11111111-1111-1111-1111-111111111111';   -- coordenador blmf-test
  c_reader constant uuid := '33333333-3333-3333-3333-333333333333';
  b1 bigint; b2 bigint; b3 bigint; b4 bigint; b5 bigint;
  v_ids bigint[]; v_txt text; v_err text; v_j jsonb; v_row record;
  v_admin uuid := gen_random_uuid(); v_n int;
BEGIN
  -- Un monde à soi : les notices du seed ont une couverture le temps de la suite.
  UPDATE public.books SET cover_object_path = 'books/seed/front.jpg'
   WHERE nullif(btrim(coalesce(cover_object_path, '')), '') IS NULL;

  -- b1 : un PDF public secondaire et un restreint principal — le public passe
  -- devant ; b2 : sans bib_ref, deux PDF publics — le principal passe devant ;
  -- b3 : PDF restreint seulement ; b4 : déjà couverte ; b5 : PDF public retiré.
  -- (Un seul PDF principal actif par notice : ux_book_digital_resources_primary_active.)
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Brochure un', 'TEST PDF/1', 'livro', c_lib) RETURNING id INTO b1;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Brochure deux', NULL, 'livro', c_lib) RETURNING id INTO b2;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Brochure restreinte', 'TEST-PDF-3', 'livro', c_lib) RETURNING id INTO b3;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id, cover_object_path, cover_source)
  VALUES ('Brochure couverte', 'TEST-PDF-4', 'livro', c_lib, 'books/TEST-PDF-4/front.jpg', 'photo') RETURNING id INTO b4;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Brochure retirée', 'TEST-PDF-5', 'livro', c_lib) RETURNING id INTO b5;

  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count)
  SELECT x, c_lib, 0, 0 FROM unnest(ARRAY[b1, b2, b3, b4, b5]) x;

  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, storage_bucket, storage_path, mime_type, is_primary)
  VALUES (b1, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'books/t/annexe.pdf', 'application/pdf', false),
         (b1, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'active', true, 'pdf-restrito', 'books/t/b1-reserve.pdf', 'application/pdf', true),
         (b2, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'books/t/deux-annexe.pdf', 'application/pdf', false),
         (b2, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'books/t/deux.PDF', 'application/octet-stream', true),
         (b3, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'active', true, 'pdf-restrito', 'books/t/reserve.pdf', 'application/pdf', true),
         (b4, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'books/t/quatre.pdf', 'application/pdf', true),
         (b5, 'pdf_publico', 'leitura_online', 'publico', 'retired', false, 'anarbib-pdf-public', 'books/t/cinq.pdf', 'application/pdf', true);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);

  v_t := 'T1 compte : trois faisables, dont une restreinte, aucune page 1 posée';
  BEGIN v_j := api.capas_pdf_resume(c_lib); EXCEPTION WHEN OTHERS THEN v_j := jsonb_build_object('erreur', SQLERRM); END;
  IF (v_j->>'faisables')::int = 3 AND (v_j->>'restreintes')::int = 1 AND (v_j->>'posees')::int = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_j::text); END IF;

  v_t := 'T2 liste : les trois faisables ; un PDF public d''abord, puis le principal ; extension en capitales comprise';
  v_ids := NULL; v_err := NULL;
  BEGIN SELECT array_agg(book_id ORDER BY book_id) INTO v_ids FROM api.capas_pdf_liste(c_lib, 20, '{}');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ids = ARRAY[b1, b2, b3]
     AND (SELECT storage_path FROM api.capas_pdf_liste(c_lib, 20, '{}') WHERE book_id = b1) = 'books/t/annexe.pdf'
     AND (SELECT storage_path FROM api.capas_pdf_liste(c_lib, 20, '{}') WHERE book_id = b2) = 'books/t/deux.PDF'
     AND (SELECT storage_bucket FROM api.capas_pdf_liste(c_lib, 20, '{}') WHERE book_id = b3) = 'pdf-restrito' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, v_err, 'rien')); END IF;

  v_t := 'T3 exclure : une notice au rendu raté ne revient pas dans la passe';
  v_ids := NULL; v_err := NULL;
  BEGIN SELECT array_agg(book_id) INTO v_ids FROM api.capas_pdf_liste(c_lib, 20, ARRAY[b1]);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_ids = ARRAY[b2, b3] THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ids::text, v_err, 'rien')); END IF;

  v_t := 'T4 poser : provenance pdf_page1, dossier de la bib_ref nettoyée, proposition en attente périmée';
  INSERT INTO public.cover_proposals (book_id, statut, candidates)
  VALUES (b1, 'a_revoir', '[{"fullUrl":"https://covers.openlibrary.org/b/id/1-L.jpg","thumbnailUrl":"https://covers.openlibrary.org/b/id/1-M.jpg","source":"openlibrary"}]');
  v_txt := NULL;
  BEGIN v_txt := api.capas_pdf_poser(b1, 'books/TEST_PDF_1/capa-mgz1.jpg');
  EXCEPTION WHEN OTHERS THEN v_txt := 'erreur : ' || SQLERRM; END;
  SELECT b.cover_object_path, b.cover_source, b.cover_license, b.updated_by, p.statut INTO v_row
    FROM public.books b JOIN public.cover_proposals p ON p.book_id = b.id WHERE b.id = b1;
  IF v_txt = 'posee' AND v_row.cover_object_path = 'books/TEST_PDF_1/capa-mgz1.jpg' AND v_row.cover_source = 'pdf_page1'
     AND v_row.cover_license IS NULL AND v_row.updated_by = c_staff AND v_row.statut = 'perimee' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '') || ' ' || row_to_json(v_row)::text); END IF;

  v_t := 'T5 sans bib_ref, le dossier est l''id ; un autre dossier ou un autre nom : refusés';
  v_err := NULL;
  BEGIN PERFORM api.capas_pdf_poser(b2, 'books/TEST_PDF_1/capa-mgz2.jpg'); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err = 'capa_chemin_invalide' THEN
    v_err := NULL;
    BEGIN PERFORM api.capas_pdf_poser(b2, 'books/' || b2 || '/photo-mgz2.jpg'); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err = 'capa_chemin_invalide' THEN
      v_txt := NULL;
      BEGIN v_txt := api.capas_pdf_poser(b2, 'books/' || b2 || '/capa-mgz2.jpg'); EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
      IF v_txt = 'posee' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (bon chemin) : ' || coalesce(v_txt, '')); END IF;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (photo-) : ' || coalesce(v_err, 'accepté')); END IF;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (autre dossier) : ' || coalesce(v_err, 'accepté')); END IF;

  v_t := 'T6 jamais de remplacement : une couverture présente gagne';
  v_txt := NULL;
  BEGIN v_txt := api.capas_pdf_poser(b4, 'books/TEST-PDF-4/capa-mgz4.jpg');
  EXCEPTION WHEN OTHERS THEN v_txt := 'erreur : ' || SQLERRM; END;
  IF v_txt = 'deja_une_capa'
     AND (SELECT cover_object_path FROM public.books WHERE id = b4) = 'books/TEST-PDF-4/front.jpg' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '')); END IF;

  v_t := 'T7 un PDF restreint donne sa page 1 (décision du 20/10) ; un PDF retiré, non';
  v_txt := NULL;
  BEGIN v_txt := api.capas_pdf_poser(b3, 'books/TEST-PDF-3/capa-mgz3.jpg'); EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  IF v_txt = 'posee' THEN
    v_err := NULL;
    BEGIN PERFORM api.capas_pdf_poser(b5, 'books/TEST-PDF-5/capa-mgz5.jpg'); EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err = 'capa_sans_pdf' AND (SELECT cover_object_path FROM public.books WHERE id = b5) IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (retiré) : ' || coalesce(v_err, 'accepté')); END IF;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' (restreint) : ' || coalesce(v_txt, '')); END IF;

  v_t := 'T8 le compte suit : plus rien de faisable ni de restreint, trois pages 1 posées';
  BEGIN v_j := api.capas_pdf_resume(c_lib); EXCEPTION WHEN OTHERS THEN v_j := jsonb_build_object('erreur', SQLERRM); END;
  IF (v_j->>'faisables')::int = 0 AND (v_j->>'posees')::int = 3 AND (v_j->>'restreintes')::int = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_j::text); END IF;

  v_t := 'T9 une lectrice : refusée (42501) ; rien pour anon';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_reader, 'role', 'authenticated')::text, true);
  v_err := NULL;
  BEGIN PERFORM * FROM api.capas_pdf_liste(c_lib, 20, '{}'); EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE; END;
  IF v_err = '42501'
     AND NOT has_function_privilege('anon', 'api.capas_pdf_poser(bigint, text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.capas_pdf_liste(uuid, integer, bigint[])', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'api.capas_pdf_resume(uuid)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'api.capas_pdf_poser(bigint, text)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_err, 'rendu')); END IF;

  v_t := 'T10 api.capas_pdf_bibliotheques : l''administration du réseau seule ; la bibliothèque y figure avec ses faisables';
  -- Remet b3 sans couverture : une faisable, restreinte.
  UPDATE public.books SET cover_object_path = NULL, cover_source = NULL WHERE id = b3;
  v_err := NULL;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);
  BEGIN PERFORM * FROM api.capas_pdf_bibliotheques(); EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE; END;
  INSERT INTO auth.users (id, email) VALUES (v_admin, 'capas-pdf-admin-' || substr(replace(v_admin::text, '-', ''), 1, 8) || '@example.invalid');
  INSERT INTO public.profiles (id) VALUES (v_admin) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  v_n := NULL;
  BEGIN SELECT count(*) INTO v_n FROM api.capas_pdf_bibliotheques() WHERE library_id = c_lib AND faisables = 1 AND restreintes = 1;
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM; END;
  IF v_err = '42501' AND v_n = 1
     AND NOT has_function_privilege('anon', 'api.capas_pdf_bibliotheques()', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : staff=' || coalesce(v_err, 'rendu') || ' admin=' || coalesce(v_n::text, v_txt, '?')); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CAPAS PDF ECHEC : %/% OK, % échec(s) | %', v_passed, v_passed + v_failed, v_failed,
      array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CAPAS PDF OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
