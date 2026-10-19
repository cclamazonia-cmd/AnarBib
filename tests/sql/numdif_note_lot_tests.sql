-- =====================================================================
-- AnarBib — Tests d'acceptation : la note d'une ressource versée par lot
-- (REGISTRE §47 NUMDIF-6)
-- Date    : 2026-10-16  ·  Session : NUMDIF — note des ressources versées par lot
-- Ref     : migration 20261016083340_numdif6_la_note_dit_la_validation_par_lot
--
-- Une source partenaire aux droits déclarés par lot est validée par lot, sans
-- ouvrir chaque fichier : la ressource versée ne doit dire ni « verificado na
-- folha de rosto », ni « Menção impressa na edição, p. ». Données fictives
-- (aucun contenu de source réelle).
--
-- T1  diffusion_autorisee, page de mention « déclaration par lot … » : note
--     NUMDIF-6 (même source, folha de rosto não verificada, validado em lote
--     pela administração da rede) ; justification du candidat + déclaration
--     de droits par lot, sans « Menção impressa »
-- T2  statut_inconnu sans page de mention, justification « NUMDIF-6 …
--     validation par lot » : note NUMDIF-6 ; justification = celle du
--     candidat, telle quelle
-- T3  hors lot (anti_copyright, mention imprimée p. 2) : l'ancien texte
--     demeure — folha de rosto (p. 3 do arquivo), coordenação, Menção impressa
-- T4  la fonction garde ses droits (fermée à authenticated et anon, ouverte
--     à service_role) et son SECURITY DEFINER
--
-- T5  D26 (19/10/2026) : la référence de la déclaration et de la délégation
--     vient de la source (meta.declaracao_lote, meta.delegacao_validacao) ;
--     sans elle, la phrase sans référence ; plus aucune date en dur dans le
--     versement ni le réalignement
--
--   Bilan OK : 'NUMDIF-NOTE-LOT OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_blmf   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- seed
  v_coordA constant uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  c_page   constant text := 'déclaration par lot (Règle d''essai v0.1, lettre de l''archiviste du 01/01/2026)';
  c_justif constant text := 'Règle d''essai v0.1 ; lot « Essai — revue », lettre « A » ; remarque de l''archiviste : « tract militant » ; '
                            || 'NUMDIF-6 : notice et fichier de la même source (wiki d''essai, page 1) ; '
                            || 'validation par lot par l''administration du réseau, délégation écrite du 01/01/2026.';
  c_justif2 constant text := 'Règle d''essai v0.1 ; lot « Essai — divers », lettre « — » ; '
                            || 'NUMDIF-6 : notice et fichier de la même source (wiki d''essai, page 2) ; '
                            || 'validation par lot par l''administration du réseau, délégation écrite du 01/01/2026.';
  v_book bigint;
  v_c1 bigint; v_c2 bigint; v_c3 bigint;
  v_res jsonb; v_path text;
  v_r public.book_digital_resources%rowtype;
  c_sig constant text := 'ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)';
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable, editora, local_publicacao, ano, idioma)
  VALUES ('Essai NUMDIF lot', 'TEST-NUMDIF-LOT', 'livro', 'ambos', true, 'Imprimerie d''essai', 'Gand', '1920', 'nl')
  RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_book, c_blmf, 1, 1);
  -- D26 : la source qui alimente la bibliothèque porte la référence de sa déclaration
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled, destination_library_id, meta)
  VALUES ('Wiki d''essai', c_blmf, 'mapeada', 'partner_deposit', true, c_blmf,
          jsonb_build_object('declaracao_lote', 'Règle d''essai v0.1, lettre du 01/01/2026',
                             'delegacao_validacao', 'délégation écrite du 01/01/2026 (essai)'));

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  PERFORM public.fn_digital_candidates_propose(c_blmf, jsonb_build_array(
    jsonb_build_object('book_id', v_book, 'file_url', 'https://wiki.essai.invalid/images/lot1.pdf',
                       'page_url', 'https://wiki.essai.invalid/wiki/Bestand:lot1.pdf', 'source_name', 'Wiki d''essai',
                       'sha1', repeat('3c', 20), 'tool_notes', jsonb_build_object('lot', 'Essai — revue', 'lettre', 'A')),
    jsonb_build_object('book_id', v_book, 'file_url', 'https://wiki.essai.invalid/images/lot2.pdf',
                       'page_url', 'https://wiki.essai.invalid/wiki/Bestand:lot2.pdf', 'source_name', 'Wiki d''essai',
                       'sha1', repeat('4d', 20), 'tool_notes', jsonb_build_object('lot', 'Essai — divers', 'lettre', '')),
    jsonb_build_object('book_id', v_book, 'file_url', 'https://example.invalid/imprime.pdf', 'page_url', 'https://example.invalid/imprime',
                       'source_name', 'Exemple', 'sha256', repeat('5e', 32), 'title_page_number', 3)));
  SELECT id INTO v_c1 FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%lot1.pdf';
  SELECT id INTO v_c2 FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%lot2.pdf';
  SELECT id INTO v_c3 FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%imprime.pdf';
  PERFORM public.fn_digital_candidate_decide(v_c1, 'valider', 'meme_edition', 'diffusion_autorisee', c_justif,
                                             'tract militant', c_page);
  PERFORM public.fn_digital_candidate_decide(v_c2, 'valider', 'meme_edition', 'statut_inconnu', c_justif2);
  PERFORM public.fn_digital_candidate_decide(v_c3, 'valider', 'meme_edition', 'anti_copyright', 'Édition militante.',
                                             'Copyleft : reproduction libre', '2');

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 diffusion_autorisee par lot : note NUMDIF-6, declaration par lot sans Mencao imprimee';
  v_path := 'books/' || v_book || '/1792030000001_lot1.pdf';
  INSERT INTO storage.objects (bucket_id, name) VALUES ('anarbib-pdf-public', v_path);
  v_res := ingest.fn_digital_candidate_deposit_record(v_c1, v_coordA, 'anarbib-pdf-public', v_path, repeat('6f', 32), repeat('3c', 20), 1000);
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = (v_res->>'resource_id')::bigint;
  IF v_r.notes = 'Fac-símile da edição da ficha, fornecido pela mesma fonte que a ficha (NUMDIF-6 ; folha de rosto não verificada '
                 || 'arquivo por arquivo). Candidato NUMDIF n.º ' || v_c1
                 || ', validado em lote pela administração da rede, por délégation écrite du 01/01/2026 (essai).'
     AND v_r.rights_justification = c_justif
                 || ' Declaração de direitos por lote do arquivista (Règle d''essai v0.1, lettre du 01/01/2026).'
     AND v_r.rights_justification NOT LIKE '%Menção impressa%'
     AND v_r.notes NOT LIKE '%coordenação%'
     AND v_r.rights_status = 'licenca_livre' AND v_r.access_scope = 'publico' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_r.notes || ' | ' || v_r.rights_justification); END IF;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 statut_inconnu par lot sans page de mention : note NUMDIF-6, justification intacte';
  v_path := 'books/' || v_book || '/1792030000002_lot2.pdf';
  INSERT INTO storage.objects (bucket_id, name) VALUES ('pdf-restrito', v_path);
  v_res := ingest.fn_digital_candidate_deposit_record(v_c2, v_coordA, 'pdf-restrito', v_path, repeat('7a', 32), repeat('4d', 20), 1000);
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = (v_res->>'resource_id')::bigint;
  IF v_r.notes LIKE 'Fac-símile da edição da ficha, fornecido pela mesma fonte que a ficha (NUMDIF-6 ;%'
     AND v_r.notes LIKE '%n.º ' || v_c2 || ', validado em lote pela administração da rede%'
     AND v_r.rights_justification = c_justif2
     AND v_r.rights_status = 'sob_direitos' AND v_r.access_scope = 'conta_ativa' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_r.notes || ' | ' || v_r.rights_justification); END IF;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 hors lot : folha de rosto, coordenacao, Mencao impressa demeurent';
  v_path := 'books/' || v_book || '/1792030000003_imprime.pdf';
  INSERT INTO storage.objects (bucket_id, name) VALUES ('anarbib-pdf-public', v_path);
  v_res := ingest.fn_digital_candidate_deposit_record(v_c3, v_coordA, 'anarbib-pdf-public', v_path, repeat('5e', 32), NULL, 1000);
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = (v_res->>'resource_id')::bigint;
  IF v_r.notes LIKE 'Fac-símile da edição da ficha, verificado na folha de rosto (p. 3 do arquivo). Candidato NUMDIF n.º ' || v_c3 || ',%'
     AND v_r.notes LIKE '%, validado pela coordenação da biblioteca detentora em %'
     AND v_r.notes NOT LIKE '%NUMDIF-6%'
     AND v_r.rights_justification = 'Édition militante. Menção impressa na edição, p. 2 : «Copyleft : reproduction libre».' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_r.notes || ' | ' || v_r.rights_justification); END IF;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 droits et SECURITY DEFINER inchanges';
  IF NOT has_function_privilege('authenticated', c_sig, 'EXECUTE')
     AND NOT has_function_privilege('anon', c_sig, 'EXECUTE')
     AND has_function_privilege('service_role', c_sig, 'EXECUTE')
     AND (SELECT prosecdef FROM pg_proc WHERE oid = c_sig::regprocedure) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 D26 : la reference vient de la source, rien en dur';
  IF ingest.fn_declaration_par_lot(c_blmf, 'declaracao_lote') = 'Règle d''essai v0.1, lettre du 01/01/2026'
     AND ingest.fn_declaration_par_lot(gen_random_uuid(), 'declaracao_lote') IS NULL
     AND ingest.fn_declaration_par_lot(NULL, 'declaracao_lote') IS NULL
     AND pg_get_functiondef(c_sig::regprocedure) !~ '15/10/2026|Rechtenregeling'
     AND pg_get_functiondef('ingest.fn_digital_resource_realign_record'::regproc) !~ '15/10/2026|Rechtenregeling'
     AND pg_get_functiondef(c_sig::regprocedure) ~ 'fn_declaration_par_lot' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'NUMDIF-NOTE-LOT OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'NUMDIF-NOTE-LOT ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || ');
  END IF;
END $$;
