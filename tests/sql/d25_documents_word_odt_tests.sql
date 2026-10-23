-- =====================================================================
-- AnarBib — Tests d'acceptation : les fichiers Word et ODT, en
-- téléchargement seulement (D25, décision de Xavier du 23/10/2026)
-- Date    : 2026-10-23
-- Ref     : migration 20261023130916_d25_word_et_odt_admis_en_telechargement ;
--           supabase/functions/deposit-digital-candidate (le versement)
--
-- T1  un .docx d'un cas public se verse en « documento » / « telechargement »,
--     MIME docx, libellé « (arquivo de texto) », note « Arquivo de texto »,
--     dans le seau public, JAMAIS principal (la notice n'a pourtant rien d'autre)
-- T2  un .odt d'un cas restreint : pdf-restrito, conta_ativa, MIME odt
-- T3  un PDF versé ensuite reste un PDF : pdf_publico, leitura_online,
--     application/pdf, « (fac-símile) », et principal
-- T4  le réalignement garde le type : le .docx public se dit « aligné » ; le cas
--     passé à statut_inconnu, il part en pdf-restrito, restreint, et reste
--     « documento » ; puis « aligné » de nouveau
-- T5  api.book_documents_v1 sous anon : le public (accès accordé), le restreint
--     (signalé, non accordé), ni le PDF, ni un document non validé, ni un
--     inactif ; rien d'une notice d'un catalogue non lisible
-- T6  les contraintes (notices ET brouillons) et les seaux admettent le neuf ;
--     la porte est ouverte à anon et authenticated, pas à PUBLIC
--
--   Bilan OK : 'D25-DOCUMENTS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_blmf   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- seed
  v_coordA constant uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  c_restrito constant text := 'pdf-restrito';
  c_public constant text := 'anarbib-pdf-public';
  v_sha_docx constant text := repeat('d1', 32);
  v_sha_odt  constant text := repeat('d2', 32);
  v_sha_pdf  constant text := repeat('d3', 32);
  v_book bigint; v_cachee uuid; v_book_cache bigint;
  v_c_docx bigint; v_c_odt bigint; v_c_pdf bigint;
  v_docx bigint; v_odt bigint; v_pdf bigint; v_brouillon bigint; v_inactif bigint;
  v_p_docx text; v_p_odt text; v_p_pdf text;
  v_res jsonb; v_g jsonb; v_n int; v_txt text;
  v_r public.book_digital_resources%rowtype;
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable, idioma)
  VALUES ('Essai D25 documents', 'TEST-D25-DOC', 'livro', 'ambos', true, 'nl') RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_book, c_blmf, 1, 1);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  PERFORM public.fn_digital_candidates_propose(c_blmf, jsonb_build_array(
    jsonb_build_object('book_id', v_book, 'file_url', 'https://anarchief.org/images/1/12/Tekst.docx',
                       'page_url', 'https://anarchief.org/wiki/Bestand:Tekst.docx', 'source_name', 'Anarchief',
                       'sha256', v_sha_docx, 'file_size_bytes', 41000, 'original_filename', 'Tekst.docx'),
    jsonb_build_object('book_id', v_book, 'file_url', 'https://anarchief.org/images/2/23/Vertaling.odt',
                       'page_url', 'https://anarchief.org/wiki/Bestand:Vertaling.odt', 'source_name', 'Anarchief',
                       'sha256', v_sha_odt, 'file_size_bytes', 52000, 'original_filename', 'Vertaling.odt'),
    jsonb_build_object('book_id', v_book, 'file_url', 'https://anarchief.org/images/3/34/Scan.pdf',
                       'source_name', 'Anarchief', 'sha256', v_sha_pdf, 'file_size_bytes', 900000)));
  SELECT id INTO v_c_docx FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%.docx';
  SELECT id INTO v_c_odt  FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%.odt';
  SELECT id INTO v_c_pdf  FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%.pdf';
  PERFORM public.fn_digital_candidate_decide(v_c_docx, 'valider', 'meme_edition', 'diffusion_autorisee',
                                             'Lettre A de l''archiviste.', 'Vrij te verspreiden', '1');
  PERFORM public.fn_digital_candidate_decide(v_c_odt, 'valider', 'meme_edition', 'statut_inconnu',
                                             'Traduction, traducteur inconnu.');
  PERFORM public.fn_digital_candidate_decide(v_c_pdf, 'valider', 'meme_edition', 'domaine_public',
                                             'Auteur mort en 1921.');
  v_p_docx := 'books/' || v_book || '/1792020000000_Tekst.docx';
  v_p_odt  := 'books/' || v_book || '/1792020000001_Vertaling.odt';
  v_p_pdf  := 'books/' || v_book || '/1792020000002_Scan.pdf';
  INSERT INTO storage.objects (bucket_id, name) VALUES (c_public, v_p_docx), (c_restrito, v_p_odt), (c_public, v_p_pdf);

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 .docx public : documento, telechargement, MIME docx, arquivo de texto, jamais principal';
  v_res := ingest.fn_digital_candidate_deposit_record(v_c_docx, v_coordA, c_public, v_p_docx, v_sha_docx, NULL, 41000);
  v_docx := (v_res->>'resource_id')::bigint;
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_docx;
  IF v_r.resource_type = 'documento' AND v_r.usage_type = 'telechargement'
     AND v_r.mime_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
     AND v_r.access_scope = 'publico' AND v_r.storage_bucket = c_public AND v_r.rights_status = 'licenca_livre'
     AND NOT v_r.is_primary AND v_r.label = 'Essai D25 documents (arquivo de texto)'
     AND v_r.metadata->>'source_file' = 'Tekst.docx' AND v_r.metadata->>'sha256' = v_sha_docx THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_r)::text); END IF;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 .odt restreint : pdf-restrito, conta_ativa, documento, MIME odt';
  v_res := ingest.fn_digital_candidate_deposit_record(v_c_odt, v_coordA, c_restrito, v_p_odt, v_sha_odt, NULL, 52000);
  v_odt := (v_res->>'resource_id')::bigint;
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_odt;
  IF v_r.resource_type = 'documento' AND v_r.usage_type = 'telechargement'
     AND v_r.mime_type = 'application/vnd.oasis.opendocument.text'
     AND v_r.access_scope = 'conta_ativa' AND v_r.storage_bucket = c_restrito AND v_r.rights_status = 'sob_direitos'
     AND NOT v_r.is_primary AND v_r.label LIKE '%(arquivo de texto)' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_r)::text); END IF;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 un PDF reste un PDF, et devient principal';
  v_res := ingest.fn_digital_candidate_deposit_record(v_c_pdf, v_coordA, c_public, v_p_pdf, v_sha_pdf, NULL, 900000);
  v_pdf := (v_res->>'resource_id')::bigint;
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_pdf;
  IF v_r.resource_type = 'pdf_publico' AND v_r.usage_type = 'leitura_online' AND v_r.mime_type = 'application/pdf'
     AND v_r.is_primary AND v_r.label LIKE '%(fac-símile)' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_r)::text); END IF;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 réalignement : le document reste documento, change de seau et de portée';
  v_n := 0;
  IF (public.fn_digital_resource_realign_garde(v_docx)->>'aligned')::boolean THEN v_n := v_n + 1; END IF;
  UPDATE ingest.digital_candidates SET source_case = 'statut_inconnu', rights_mention = NULL, rights_mention_page = NULL
   WHERE id = v_c_docx;
  v_g := public.fn_digital_resource_realign_garde(v_docx);
  IF NOT (v_g->>'aligned')::boolean AND v_g->'destination'->>'storage_bucket' = c_restrito THEN v_n := v_n + 1; END IF;
  INSERT INTO storage.objects (bucket_id, name) VALUES (c_restrito, v_p_docx);   -- la copie faite par la fonction Edge
  PERFORM ingest.fn_digital_resource_realign_record(v_docx, v_coordA, c_public, v_p_docx, c_restrito, v_p_docx, v_sha_docx);
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_docx;
  IF v_n = 2 AND v_r.resource_type = 'documento' AND v_r.usage_type = 'telechargement'
     AND v_r.storage_bucket = c_restrito AND v_r.access_scope = 'conta_ativa' AND v_r.rights_status = 'sob_direitos'
     AND (public.fn_digital_resource_realign_garde(v_docx)->>'aligned')::boolean THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/2 ' || to_jsonb(v_r)::text); END IF;
  -- le .docx redevient public pour T5 (même chemin, un seau public)
  UPDATE public.book_digital_resources SET storage_bucket = c_public, access_scope = 'publico' WHERE id = v_docx;

  -- un document public NON validé, et un inactif : ni l'un ni l'autre ne se liste
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, mime_type,
                                             storage_bucket, storage_path, label, bibliographic_match_validated)
  VALUES (v_book, 'documento', 'telechargement', 'publico', 'active', true, 'application/msword',
          c_public, 'books/' || v_book || '/brouillon.doc', 'Non validé', false) RETURNING id INTO v_brouillon;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, mime_type,
                                             storage_bucket, storage_path, label, bibliographic_match_validated)
  VALUES (v_book, 'documento', 'telechargement', 'publico', 'active', false, 'application/msword',
          c_public, 'books/' || v_book || '/retire.doc', 'Retiré', true) RETURNING id INTO v_inactif;
  -- une notice d'une bibliothèque privée, avec un document public
  INSERT INTO public.libraries (slug, name, is_active, visibility_level) VALUES ('essai-d25-cachee', 'Essai D25 cachée', true, 'private')
  RETURNING id INTO v_cachee;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Essai D25 cachée', 'TEST-D25-CACHE', 'livro', 'ambos', true) RETURNING id INTO v_book_cache;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_book_cache, v_cachee, 1, 1);
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, mime_type,
                                             storage_bucket, storage_path, label, bibliographic_match_validated)
  VALUES (v_book_cache, 'documento', 'telechargement', 'publico', 'active', true, 'application/msword',
          c_public, 'books/' || v_book_cache || '/x.doc', 'Caché', true);

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 api.book_documents_v1 sous anon : public accordé, restreint signalé, rien d''autre';
  PERFORM set_config('request.jwt.claims', '{}', true);
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT string_agg(d.asset_id || ':' || d.access_scope || ':' || d.access_granted || ':' || coalesce(d.file_size_bytes::text, '-'),
                      ',' ORDER BY d.asset_id)
      INTO v_txt FROM api.book_documents_v1(v_book) d;
    SELECT count(*) INTO v_n FROM api.book_documents_v1(v_book_cache);
    EXECUTE 'RESET ROLE';
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_txt := 'ERREUR ' || SQLERRM; v_n := -1;
  END;
  IF v_txt = v_docx || ':publico:true:41000,' || v_odt || ':conta_ativa:false:52000' AND v_n = 0 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '(vide)') || ' / cachée ' || v_n); END IF;

  -- ── T6 ────────────────────────────────────────────────────────────
  v_t := 'T6 contraintes notices et brouillons, seaux, droits de la porte';
  IF (SELECT count(*) FROM pg_constraint
       WHERE conname IN ('book_digital_resources_resource_type_chk', 'book_draft_digital_resources_resource_type_chk')
         AND pg_get_constraintdef(oid) LIKE '%''documento''%') = 2
     AND (SELECT count(*) FROM pg_constraint
           WHERE conname IN ('book_digital_resources_usage_type_chk', 'book_draft_digital_resources_usage_type_chk')
             AND pg_get_constraintdef(oid) LIKE '%''telechargement''%') = 2
     AND (SELECT count(*) FROM storage.buckets WHERE id IN (c_public, c_restrito)
           AND allowed_mime_types @> ARRAY['application/pdf', 'application/msword',
                 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                 'application/vnd.oasis.opendocument.text']) = 2
     AND has_function_privilege('anon', 'api.book_documents_v1(bigint)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'api.book_documents_v1(bigint)', 'EXECUTE')
     AND (SELECT proacl::text FROM pg_proc WHERE oid = 'api.book_documents_v1(bigint)'::regprocedure) !~ '(^|[{,])=X/'
     AND NOT has_function_privilege('anon', 'ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'D25-DOCUMENTS OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'D25-DOCUMENTS ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || ');
  END IF;
END $$;
