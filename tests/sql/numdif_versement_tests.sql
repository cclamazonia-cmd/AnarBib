-- =====================================================================
-- AnarBib — Tests d'acceptation : verser un candidat validé côté serveur
-- (backlog v34 D16 ; REGISTRE §47 NUMDIF-4, et NUMDIF-1, 2, 3)
-- Date    : 2026-10-15  ·  Session : File de candidats PDF
-- Ref     : migration 20261015182432_numdif_versement_cote_serveur
--
-- La fonction Edge deposit-digital-candidate enchaîne : garde (sous le jeton)
-- → téléchargement → empreinte → dépôt → enregistrement (clé de service). Ici,
-- les trois fonctions de la base qu'elle appelle, avec un objet de stockage
-- posé à la main à la place du dépôt.
--
-- T1  la garde : sans compte, une autre bibliothèque, un candidat non validé —
--     refusés ; la coordination reçoit URL, empreinte, seau, et son identité
-- T2  le refus se dit et se garde (deposit_error), le candidat reste à verser
-- T3  l'enregistrement est fermé à authenticated, ouvert à service_role
-- T4  l'enregistrement refuse : empreinte différente, mauvais seau, chemin hors
--     books/<notice>/, objet absent, personne sans portée
-- T5  cas statut_inconnu : ressource restreinte dans pdf-restrito, sob_direitos,
--     validée, le fichier en provenance et la page à montrer (D17 : la porte
--     du lectorat ne rend que la page), métadonnées 77/78,
--     primaire ; candidat versé
-- T6  après versement : la garde dit « déjà versé » ; T1 de
--     documents_numeriques (aucun restreint dans un seau public) tient
-- T7  cas anti_copyright : ressource publique dans anarbib-pdf-public,
--     licenca_livre, justification avec la mention et sa page, non primaire
-- T8  une source MediaWiki qui ne donne que le SHA-1 (consigne du 15/10) : le
--     candidat se propose et se valide sans SHA-256 ; un SHA-1 différent est
--     refusé ; le bon SHA-1 verse, et le SHA-256 calculé est retenu (candidat
--     et ressource)
--
--   Bilan OK : 'NUMDIF-VERSEMENT OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_blmf   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- seed
  v_coordA constant uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_coordB constant uuid := 'b1600000-0000-4000-8000-000000000001';
  v_libB uuid;
  v_book bigint;
  v_sha constant text := repeat('cd', 32);
  v_sha2 constant text := repeat('ef', 32);
  v_res jsonb; v_g jsonb;
  v_c1 bigint; v_c2 bigint; v_c3 bigint; v_c4 bigint;
  v_sha1 constant text := repeat('1a', 20);
  v_sha256_calc constant text := repeat('9f', 32);
  v_path3 text;
  v_hint text; v_n int;
  v_path text; v_path2 text;
  v_r public.book_digital_resources%rowtype;
  v_row ingest.digital_candidates%rowtype;
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-numdif-vers-b', 'Essai NUMDIF versement B', true, 'public') RETURNING id INTO v_libB;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_coordB, 'authenticated', 'authenticated', 'numdif.vers.b@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (v_coordB, 'numdif.vers.b@anarbib.local', 'CoordB', 'Test', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES (v_coordB, v_libB, 'coordenador', 'active');

  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable, editora, local_publicacao, ano, idioma)
  VALUES ('Essai NUMDIF versement', 'TEST-NUMDIF-V', 'livro', 'ambos', true, 'Harper', 'New York', '1873', 'en')
  RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_book, c_blmf, 1, 1);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  PERFORM public.fn_digital_candidates_propose(c_blmf, jsonb_build_array(
    jsonb_build_object('book_id', v_book, 'file_url', 'https://archive.org/download/essai/restreint.pdf',
                       'page_url', 'https://archive.org/details/essai', 'source_name', 'Internet Archive',
                       'source_identifier', 'essai', 'found_publisher', 'Harper', 'found_place', 'New York', 'found_year', '1873',
                       'title_page_number', 3, 'sha256', v_sha, 'file_size_bytes', 1000, 'page_count', 12,
                       'original_filename', 'restreint.pdf'),
    jsonb_build_object('book_id', v_book, 'file_url', 'https://example.org/libre.pdf', 'page_url', 'https://example.org/libre',
                       'source_name', 'Exemple', 'sha256', v_sha2, 'file_size_bytes', 2000),
    jsonb_build_object('book_id', v_book, 'file_url', 'https://example.org/pas-valide.pdf', 'sha256', v_sha),
    jsonb_build_object('book_id', v_book, 'file_url', 'https://anarchief.org/images/a/ab/wiki.pdf',
                       'page_url', 'https://anarchief.org/wiki/Bestand:wiki.pdf', 'source_name', 'Anarchief', 'sha1', v_sha1)));
  SELECT id INTO v_c1 FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%restreint.pdf';
  SELECT id INTO v_c2 FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%libre.pdf';
  SELECT id INTO v_c3 FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%pas-valide.pdf';
  SELECT id INTO v_c4 FROM ingest.digital_candidates WHERE book_id = v_book AND file_url LIKE '%wiki.pdf';
  PERFORM public.fn_digital_candidate_decide(v_c1, 'valider', 'meme_edition', 'statut_inconnu', 'Exemplaire détenu par BLMF, cote TEST-NUMDIF-V.');
  PERFORM public.fn_digital_candidate_decide(v_c2, 'valider', 'meme_edition', 'anti_copyright', 'Édition militante.',
                                             'Copyleft : reproduction libre', '2');

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 la garde : anon, autre bibliotheque, non valide refuses ; coordination servie';
  v_n := 0;
  PERFORM set_config('request.jwt.claims', '{}', true);
  BEGIN PERFORM public.fn_digital_candidate_deposit_garde(v_c1);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.coord_only' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
  BEGIN PERFORM public.fn_digital_candidate_deposit_garde(v_c1);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.not_found' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  BEGIN PERFORM public.fn_digital_candidate_deposit_garde(v_c3);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.not_validated' THEN v_n := v_n + 1; END IF; END;
  v_g := public.fn_digital_candidate_deposit_garde(v_c1);
  IF v_n = 3 AND v_g->>'sha256' = v_sha AND v_g->>'file_url' LIKE '%restreint.pdf'
     AND v_g->'destination'->>'storage_bucket' = 'pdf-restrito' AND (v_g->>'caller')::uuid = v_coordA
     AND (v_g->>'book_id')::bigint = v_book THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/3 ' || coalesce(v_g::text, '-')); END IF;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 le refus se dit et se garde, le candidat reste a verser';
  v_res := public.fn_digital_candidate_deposit_failed(v_c1, 'empreinte SHA-256 différente');
  SELECT * INTO v_row FROM ingest.digital_candidates WHERE id = v_c1;
  IF v_row.status = 'valide' AND v_row.deposit_error LIKE 'empreinte%' AND v_row.deposit_attempted_at IS NOT NULL THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_row)::text); END IF;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 enregistrement ferme a authenticated et anon, ouvert a service_role ; garde et refus ouverts';
  IF NOT has_function_privilege('authenticated', 'ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)', 'EXECUTE')
     AND has_function_privilege('service_role', 'ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.fn_digital_candidate_deposit_garde(bigint)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_digital_candidate_deposit_garde(bigint)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_digital_candidate_deposit_failed(bigint, text)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 enregistrement refuse : empreinte, seau, chemin, objet absent, personne sans portee';
  v_path := 'books/' || v_book || '/1792020000000_restreint.pdf';
  v_n := 0;
  BEGIN PERFORM ingest.fn_digital_candidate_deposit_record(v_c1, v_coordA, 'pdf-restrito', v_path, v_sha2, NULL, 1000);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.fingerprint_mismatch' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_candidate_deposit_record(v_c1, v_coordA, 'anarbib-pdf-public', v_path, v_sha, NULL, 1000);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.wrong_bucket' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_candidate_deposit_record(v_c1, v_coordA, 'pdf-restrito', 'books/999999/x.pdf', v_sha, NULL, 1000);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.bad_path' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_candidate_deposit_record(v_c1, v_coordA, 'pdf-restrito', v_path, v_sha, NULL, 1000);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.object_missing' THEN v_n := v_n + 1; END IF; END;
  INSERT INTO storage.objects (bucket_id, name) VALUES ('pdf-restrito', v_path);
  BEGIN PERFORM ingest.fn_digital_candidate_deposit_record(v_c1, v_coordB, 'pdf-restrito', v_path, v_sha, NULL, 1000);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.coord_only' THEN v_n := v_n + 1; END IF; END;
  IF v_n = 5 AND (SELECT status FROM ingest.digital_candidates WHERE id = v_c1) = 'valide'
     AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources WHERE book_id = v_book) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/5'); END IF;

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 statut_inconnu : ressource restreinte, la page en source, champs 77/78, candidat verse';
  v_res := ingest.fn_digital_candidate_deposit_record(v_c1, v_coordA, 'pdf-restrito', v_path, upper(v_sha), NULL, 1000);
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = (v_res->>'resource_id')::bigint;
  SELECT * INTO v_row FROM ingest.digital_candidates WHERE id = v_c1;
  IF v_r.access_scope = 'conta_ativa' AND v_r.resource_type = 'pdf_restrito' AND v_r.rights_status = 'sob_direitos'
     AND v_r.storage_bucket = 'pdf-restrito' AND v_r.storage_path = v_path AND v_r.status = 'active' AND v_r.is_active
     AND v_r.bibliographic_match_validated AND v_r.is_primary AND v_r.usage_type = 'leitura_online'
     AND v_r.source_url = 'https://archive.org/download/essai/restreint.pdf'
     AND v_r.source_page_url = 'https://archive.org/details/essai' AND v_r.source_name = 'Internet Archive'
     AND v_r.attribution_text LIKE 'Fonte: Internet Archive (identificador essai)'
     AND v_r.rights_justification LIKE 'Exemplaire détenu%' AND v_r.language_code = 'en'
     AND v_r.metadata->>'sha256' = v_sha AND (v_r.metadata->>'page_count')::int = 12
     AND v_r.metadata->>'source_file' = 'restreint.pdf' AND (v_r.metadata->>'numdif_candidate_id')::bigint = v_c1
     AND v_r.label LIKE 'Essai NUMDIF versement — Harper, New York, 1873 (fac-símile)'
     AND v_r.notes LIKE '%(p. 3 do arquivo)%'
     -- D17 : la porte du lectorat rend la page, jamais le fichier d'une ressource restreinte stockée
     AND NOT EXISTS (SELECT 1 FROM public.get_accessible_digital_asset_by_id_v2(v_r.id) a WHERE a.source_url IS NOT NULL)
     AND v_row.status = 'verse' AND v_row.resource_id = v_r.id AND v_row.deposited_by = v_coordA
     AND v_row.deposited_at IS NOT NULL AND v_row.deposit_error IS NULL THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_r)::text); END IF;

  -- ── T6 ────────────────────────────────────────────────────────────
  v_t := 'T6 deja verse ; aucun restreint dans un seau public (documents_numeriques T1)';
  BEGIN
    PERFORM public.fn_digital_candidate_deposit_garde(v_c1);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : garde ouverte');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.already_deposited'
       AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources r JOIN storage.buckets b ON b.id = r.storage_bucket
                        WHERE r.access_scope <> 'publico' AND r.status = 'active' AND r.is_active AND b.public) THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_hint, SQLERRM)); END IF;
  END;

  -- ── T7 ────────────────────────────────────────────────────────────
  v_t := 'T7 anti_copyright : ressource publique, licenca_livre, mention et page, non primaire';
  v_path2 := 'books/' || v_book || '/1792020000001_libre.pdf';
  INSERT INTO storage.objects (bucket_id, name) VALUES ('anarbib-pdf-public', v_path2);
  v_res := ingest.fn_digital_candidate_deposit_record(v_c2, v_coordA, 'anarbib-pdf-public', v_path2, v_sha2, NULL, 2000);
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = (v_res->>'resource_id')::bigint;
  IF v_r.access_scope = 'publico' AND v_r.resource_type = 'pdf_publico' AND v_r.rights_status = 'licenca_livre'
     AND v_r.storage_bucket = 'anarbib-pdf-public' AND NOT v_r.is_primary
     AND v_r.rights_justification LIKE '%p. 2%Copyleft : reproduction libre%'
     AND v_r.source_url = 'https://example.org/libre.pdf' AND v_r.source_page_url = 'https://example.org/libre'
     AND v_r.bibliographic_match_validated THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_r)::text); END IF;

  -- ── T8 ────────────────────────────────────────────────────────────
  v_t := 'T8 source MediaWiki : SHA-1 seul, valide, compare, SHA-256 retenu';
  v_n := 0;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  IF (SELECT sha1 = v_sha1 AND sha256 IS NULL FROM ingest.digital_candidates WHERE id = v_c4) THEN v_n := v_n + 1; END IF;
  PERFORM public.fn_digital_candidate_decide(v_c4, 'valider', 'meme_edition', 'domaine_public', 'Domaine public : auteur mort en 1890.');
  v_g := public.fn_digital_candidate_deposit_garde(v_c4);
  IF v_g->>'sha1' = v_sha1 AND v_g->>'sha256' IS NULL THEN v_n := v_n + 1; END IF;
  v_path3 := 'books/' || v_book || '/1792020000002_wiki.pdf';
  INSERT INTO storage.objects (bucket_id, name) VALUES ('anarbib-pdf-public', v_path3);
  BEGIN PERFORM ingest.fn_digital_candidate_deposit_record(v_c4, v_coordA, 'anarbib-pdf-public', v_path3, v_sha256_calc, repeat('2b', 20), 3000);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.fingerprint_mismatch' THEN v_n := v_n + 1; END IF; END;
  v_res := ingest.fn_digital_candidate_deposit_record(v_c4, v_coordA, 'anarbib-pdf-public', v_path3, v_sha256_calc, v_sha1, 3000);
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = (v_res->>'resource_id')::bigint;
  SELECT * INTO v_row FROM ingest.digital_candidates WHERE id = v_c4;
  IF v_n = 3 AND v_row.status = 'verse' AND v_row.sha256 = v_sha256_calc AND v_r.metadata->>'sha256' = v_sha256_calc
     AND v_r.metadata->>'sha1' = v_sha1 AND v_r.rights_status = 'dominio_publico' AND v_r.access_scope = 'publico' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/3 ' || to_jsonb(v_r)::text); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'NUMDIF-VERSEMENT OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'NUMDIF-VERSEMENT ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || ');
  END IF;
END $$;
