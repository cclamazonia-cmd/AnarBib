-- =====================================================================
-- AnarBib — Tests d'acceptation : la file de candidats PDF est fermée
-- (backlog v34 D13 ; REGISTRE §47 NUMDIF-1, NUMDIF-2, NUMDIF-5)
-- Date    : 2026-10-15  ·  Session : File de candidats PDF
-- Ref     : migration 20261015172008_numdif_file_de_candidats_pdf
--
-- Monde : BLMF (seed, sa coordination 1111…) détient les notices X et Z ;
-- une bibliothèque B (sa coordination créée ici) détient la notice Y ; un
-- librarian de BLMF ; une administration du réseau.
--
-- T1  la table : RLS sans FORCE, aucune politique, commentaire INGEST-RLS,
--     aucun droit pour anon ni authenticated
-- T2  sous le rôle authenticated, la lecture directe est refusée (42501)
-- T3  sans compte : la liste est vide, proposer est refusé (coord_only)
-- T4  la coordination de BLMF propose : créés ; notice non détenue et
--     empreinte mal formée ignorées avec leur raison
-- T5  la coordination de B ne voit rien de BLMF, ne propose pas pour elle,
--     et un candidat de BLMF lui est « introuvable »
-- T6  un librarian de BLMF ne voit rien (la coordination décide)
-- T7  valider : autre édition refusée (NUMDIF-1), justification exigée,
--     mention + page exigées pour un cas public sous licence (NUMDIF-2) ;
--     statut_inconnu validé -> « valide », destination restreinte
-- T8  rejeter : motif exigé ; le rejet garde motif, édition trouvée, auteur
-- T9  reproposer un candidat décidé : ignoré (deja_traite), rien réécrit
-- T10 l'administration du réseau voit les deux bibliothèques ; B ne voit que
--     le sien
-- T11 une bibliothèque qui ne détient plus la notice ne décide plus
-- T12 droits : portes fermées à anon, aides fermées à authenticated
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'NUMDIF-FILE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_blmf   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- seed
  v_coordA constant uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_coordB constant uuid := 'b1300000-0000-4000-8000-000000000001';
  v_librA  constant uuid := 'b1300000-0000-4000-8000-000000000002';
  v_admin  constant uuid := 'b1300000-0000-4000-8000-000000000003';
  v_libB uuid;
  v_bookX bigint; v_bookY bigint; v_bookZ bigint;
  v_sha constant text := repeat('ab', 32);
  v_res jsonb;
  v_c1 bigint; v_c2 bigint; v_cz bigint;
  v_state text; v_hint text;
  v_row ingest.digital_candidates%rowtype;
  v_n int;
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-numdif-b', 'Essai NUMDIF B', true, 'public') RETURNING id INTO v_libB;

  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at,
                          raw_app_meta_data, raw_user_meta_data)
  SELECT '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email, now(), now(), now(),
         '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
    FROM (VALUES (v_coordB, 'numdif.coordb@anarbib.local'), (v_librA, 'numdif.libra@anarbib.local'),
                 (v_admin, 'numdif.admin@anarbib.local')) AS u(id, email)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (v_coordB, 'numdif.coordb@anarbib.local', 'CoordB', 'Test', 'fr'),
         (v_librA, 'numdif.libra@anarbib.local', 'LibrA', 'Test', 'fr'),
         (v_admin, 'numdif.admin@anarbib.local', 'Admin', 'Test', 'fr')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_coordB, v_libB, 'coordenador', 'active'), (v_librA, c_blmf, 'librarian', 'active');
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable, editora, local_publicacao, ano)
  VALUES ('Essai NUMDIF X', 'TEST-NUMDIF-X', 'livro', 'ambos', true, 'Altamira', 'Buenos Aires', '1992')
  RETURNING id INTO v_bookX;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Essai NUMDIF Y', 'TEST-NUMDIF-Y', 'livro', 'ambos', true) RETURNING id INTO v_bookY;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Essai NUMDIF Z', 'TEST-NUMDIF-Z', 'livro', 'ambos', true) RETURNING id INTO v_bookZ;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count)
  VALUES (v_bookX, c_blmf, 1, 1), (v_bookZ, c_blmf, 1, 1), (v_bookY, v_libB, 1, 1);

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 table fermee : RLS sans FORCE, sans politique, INGEST-RLS, aucun droit API';
  IF (SELECT c.relrowsecurity AND NOT c.relforcerowsecurity FROM pg_class c WHERE c.oid = 'ingest.digital_candidates'::regclass)
     AND NOT EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = 'ingest.digital_candidates'::regclass)
     AND coalesce(obj_description('ingest.digital_candidates'::regclass, 'pg_class'), '') LIKE '%INGEST-RLS%'
     AND NOT has_table_privilege('anon', 'ingest.digital_candidates', 'SELECT,INSERT,UPDATE,DELETE')
     AND NOT has_table_privilege('authenticated', 'ingest.digital_candidates', 'SELECT,INSERT,UPDATE,DELETE')
     AND NOT has_schema_privilege('authenticated', 'ingest', 'USAGE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 sous authenticated, lecture directe refusee';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM count(*) FROM ingest.digital_candidates;
    EXECUTE 'RESET ROLE';
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : la lecture a abouti');
  EXCEPTION WHEN insufficient_privilege THEN
    v_passed := v_passed + 1;
  END;
  EXECUTE 'RESET ROLE';

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 sans compte : liste vide, proposer refuse';
  PERFORM set_config('request.jwt.claims', '{}', true);
  v_res := public.fn_digital_candidates_list();
  BEGIN
    PERFORM public.fn_digital_candidates_propose(c_blmf,
      jsonb_build_array(jsonb_build_object('book_id', v_bookX, 'file_url', 'https://example.org/anon.pdf')));
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : proposition acceptee');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_hint = PG_EXCEPTION_HINT;
    IF v_state = '42501' AND v_hint = 'error.digital_candidate.coord_only' AND (v_res->>'total')::int = 0 THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_state || ' ' || coalesce(v_hint, '-') || ' ' || v_res::text); END IF;
  END;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 la coordination propose ; non detenue et invalide ignorees';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  v_res := public.fn_digital_candidates_propose(c_blmf, jsonb_build_array(
    jsonb_build_object('book_id', v_bookX, 'file_url', 'https://archive.org/download/essai/meme.pdf',
                       'page_url', 'https://archive.org/details/essai', 'source_name', 'Internet Archive',
                       'found_publisher', 'Altamira', 'found_place', 'Buenos Aires', 'found_year', '1992',
                       'proposed_verdict', 'meme_edition', 'proposed_case', 'statut_inconnu',
                       'sha256', v_sha, 'file_size_bytes', 1234, 'tool_notes', jsonb_build_object('outil', 'test')),
    jsonb_build_object('book_id', v_bookX, 'file_url', 'https://example.org/autre.pdf',
                       'found_publisher', 'Anarres', 'found_place', 'Buenos Aires', 'found_year', '2003',
                       'proposed_verdict', 'autre_edition', 'proposed_case', 'diffusion_autorisee', 'sha256', v_sha),
    jsonb_build_object('book_id', v_bookZ, 'file_url', 'https://example.org/z.pdf', 'sha256', v_sha),
    jsonb_build_object('book_id', v_bookY, 'file_url', 'https://example.org/y.pdf'),
    jsonb_build_object('book_id', v_bookX, 'file_url', 'https://example.org/bad.pdf', 'sha256', 'zz')));
  SELECT id INTO v_c1 FROM ingest.digital_candidates WHERE book_id = v_bookX AND file_url LIKE '%meme.pdf';
  SELECT id INTO v_c2 FROM ingest.digital_candidates WHERE book_id = v_bookX AND file_url LIKE '%autre.pdf';
  SELECT id INTO v_cz FROM ingest.digital_candidates WHERE book_id = v_bookZ;
  IF (v_res->>'created')::int = 3 AND (v_res->'skipped'->>'pas_detentrice')::int = 1
     AND (v_res->'skipped'->>'invalide')::int = 1 AND v_c1 IS NOT NULL AND v_c2 IS NOT NULL AND v_cz IS NOT NULL
     AND (SELECT proposed_by FROM ingest.digital_candidates WHERE id = v_c1) = v_coordA THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 la coordination de B ne voit ni ne touche les candidats de BLMF';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
  v_res := public.fn_digital_candidates_list();
  v_n := 0;
  IF (v_res->>'total')::int = 0 AND (public.fn_digital_candidates_list(c_blmf)->>'total')::int = 0 THEN v_n := v_n + 1; END IF;
  BEGIN
    PERFORM public.fn_digital_candidates_propose(c_blmf,
      jsonb_build_array(jsonb_build_object('book_id', v_bookX, 'file_url', 'https://example.org/b.pdf')));
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.coord_only' THEN v_n := v_n + 1; END IF;
  END;
  BEGIN
    PERFORM public.fn_digital_candidate_decide(v_c2, 'rejeter', p_rejection_reason => 'intrusion');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_hint = PG_EXCEPTION_HINT;
    IF v_state = 'P0002' AND v_hint = 'error.digital_candidate.not_found' THEN v_n := v_n + 1; END IF;
  END;
  IF v_n = 3 AND (SELECT status FROM ingest.digital_candidates WHERE id = v_c2) = 'propose' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/3'); END IF;

  -- ── T6 ────────────────────────────────────────────────────────────
  v_t := 'T6 un librarian de BLMF ne voit rien';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_librA, 'role', 'authenticated')::text, true);
  v_res := public.fn_digital_candidates_list();
  IF (v_res->>'total')::int = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;

  -- ── T7 ────────────────────────────────────────────────────────────
  v_t := 'T7 valider : meme edition seulement, justification, mention+page ; puis a verser';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  v_n := 0;
  BEGIN
    PERFORM public.fn_digital_candidate_decide(v_c2, 'valider', 'autre_edition', 'diffusion_autorisee', 'x', 'm', '4');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.same_edition_only' THEN v_n := v_n + 1; END IF;
  END;
  BEGIN
    PERFORM public.fn_digital_candidate_decide(v_c1, 'valider', 'meme_edition', 'statut_inconnu', '  ');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.justification_required' THEN v_n := v_n + 1; END IF;
  END;
  BEGIN
    PERFORM public.fn_digital_candidate_decide(v_c1, 'valider', 'meme_edition', 'anti_copyright', 'Copyleft imprimé', 'Copyleft', NULL);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.mention_required' THEN v_n := v_n + 1; END IF;
  END;
  v_res := public.fn_digital_candidate_decide(v_c1, 'valider', 'meme_edition', 'statut_inconnu',
                                              'Exemplaire détenu par BLMF, cote TEST-NUMDIF-X.');
  SELECT * INTO v_row FROM ingest.digital_candidates WHERE id = v_c1;
  IF v_n = 3 AND v_res->>'status' = 'valide' AND v_row.status = 'valide' AND v_row.decided_by = v_coordA
     AND v_row.decided_at IS NOT NULL AND v_row.verdict = 'meme_edition'
     AND ingest.fn_numdif_destination(v_row.source_case)->>'storage_bucket' = 'pdf-restrito'
     AND (SELECT c->'destination'->>'access_scope' FROM jsonb_array_elements(public.fn_digital_candidates_list()->'candidates') c
           WHERE (c->>'id')::bigint = v_c1) = 'conta_ativa' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/3 ' || coalesce(v_res::text, '-')); END IF;

  -- ── T8 ────────────────────────────────────────────────────────────
  v_t := 'T8 rejeter : motif exige ; motif, edition trouvee et auteur gardes';
  v_n := 0;
  BEGIN
    PERFORM public.fn_digital_candidate_decide(v_c2, 'rejeter');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.reason_required' THEN v_n := v_n + 1; END IF;
  END;
  PERFORM public.fn_digital_candidate_decide(v_c2, 'rejeter', p_rejection_reason => 'Autre édition : Anarres, ~2003.');
  SELECT * INTO v_row FROM ingest.digital_candidates WHERE id = v_c2;
  IF v_n = 1 AND v_row.status = 'rejete' AND v_row.rejection_reason LIKE 'Autre édition%'
     AND v_row.found_publisher = 'Anarres' AND v_row.found_year = '2003' AND v_row.verdict = 'autre_edition'
     AND v_row.decided_by = v_coordA THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' ' || to_jsonb(v_row)::text); END IF;

  -- ── T9 ────────────────────────────────────────────────────────────
  v_t := 'T9 reproposer un candidat decide : ignore, rien reecrit';
  v_res := public.fn_digital_candidates_propose(c_blmf, jsonb_build_array(
    jsonb_build_object('book_id', v_bookX, 'file_url', 'https://example.org/autre.pdf', 'found_publisher', 'Écrasé'),
    jsonb_build_object('book_id', v_bookX, 'file_url', 'https://archive.org/download/essai/meme.pdf', 'found_publisher', 'Écrasé')));
  IF (v_res->'skipped'->>'deja_traite')::int = 2 AND (v_res->>'created')::int = 0
     AND (SELECT found_publisher FROM ingest.digital_candidates WHERE id = v_c2) = 'Anarres'
     AND (SELECT status FROM ingest.digital_candidates WHERE id = v_c1) = 'valide' THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;

  -- ── T10 ───────────────────────────────────────────────────────────
  v_t := 'T10 l administration voit tout ; B ne voit que le sien';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
  PERFORM public.fn_digital_candidates_propose(v_libB, jsonb_build_array(
    jsonb_build_object('book_id', v_bookY, 'file_url', 'https://example.org/y.pdf')));
  v_n := (public.fn_digital_candidates_list()->>'total')::int;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  v_res := public.fn_digital_candidates_list();
  IF v_n = 1 AND (v_res->>'total')::int >= 4
     AND (SELECT count(DISTINCT c->>'library_id') FROM jsonb_array_elements(v_res->'candidates') c
           WHERE (c->'book'->>'id')::bigint IN (v_bookX, v_bookY, v_bookZ)) = 2
     AND (public.fn_digital_candidates_list(v_libB)->>'total')::int = 1 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : B=' || v_n || ' admin=' || (v_res->>'total')); END IF;

  -- ── T11 ───────────────────────────────────────────────────────────
  v_t := 'T11 plus detentrice : plus de decision';
  DELETE FROM public.book_holdings WHERE book_id = v_bookZ AND library_id = c_blmf;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.fn_digital_candidate_decide(v_cz, 'rejeter', p_rejection_reason => 'x');
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : decision acceptee');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.not_holding'
       AND (SELECT (c->>'holding')::boolean FROM jsonb_array_elements(public.fn_digital_candidates_list()->'candidates') c
             WHERE (c->>'id')::bigint = v_cz) = false THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_hint, SQLERRM)); END IF;
  END;

  -- ── T12 ───────────────────────────────────────────────────────────
  v_t := 'T12 portes fermees a anon, aides fermees a authenticated';
  IF NOT has_function_privilege('anon', 'public.fn_digital_candidates_propose(uuid, jsonb)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_digital_candidates_list(uuid, text, bigint, integer, integer)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_digital_candidate_decide(bigint, text, text, text, text, text, text, text, text)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.fn_digital_candidate_decide(bigint, text, text, text, text, text, text, text, text)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'ingest.fn_numdif_peut_agir(uuid, bigint)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'ingest.fn_numdif_destination(text)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'NUMDIF-FILE OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'NUMDIF-FILE ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || ');
  END IF;
END $$;
