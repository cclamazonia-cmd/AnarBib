-- =====================================================================
-- AnarBib — Tests d'acceptation : restreindre une ressource publique sans
-- candidat NUMDIF (J13, NUMDIF-2 amendé le 22/10/2026)
-- Date    : 2026-10-22
-- Ref     : migration 20261022213527_j13_restreindre_une_ressource_sans_candidat ;
--           supabase/functions/realign-digital-resource/index.ts
--
-- T1  la garde : une coordination (pas l'administration du réseau) sur une
--     ressource marquée, l'administration sur une ressource NON marquée —
--     refusées ; l'administration sur la ressource marquée reçoit
--     sans_candidat, destination pdf-restrito, aucune empreinte, non alignée
-- T2  l'enregistrement refuse : personne hors administration, mauvais seau,
--     chemin changé, empreinte mal formée, objet absent — rien ne bouge
-- T3  l'enregistrement fait : pdf-restrito, conta_ativa, pdf_restrito,
--     sob_direitos, motif ajouté à la justification, empreinte gardée,
--     restriction_faite, un historique ; la garde dit ensuite « aligned »
-- T4  le chemin des candidats est intact : une ressource sans candidat ni
--     décision reste introuvable pour la coordination ; droits inchangés
--
--   Bilan OK : 'NUMDIF-RESTREINDRE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_blmf   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- seed
  v_coordA constant uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin  constant uuid := 'b1600000-0000-4000-8000-0000000000a3';
  c_restrito constant text := 'pdf-restrito';
  c_public constant text := 'anarbib-pdf-public';
  v_sha constant text := repeat('ef', 32);
  v_book bigint; v_marquee bigint; v_libre bigint; v_path text;
  v_g jsonb; v_hint text; v_n int;
  v_r public.book_digital_resources%rowtype;
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_admin, 'authenticated', 'authenticated', 'j13.admin@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (v_admin, 'j13.admin@anarbib.local', 'Admin', 'J13', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active') ON CONFLICT DO NOTHING;

  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable, idioma)
  VALUES ('Essai J13 sans candidat', 'TEST-J13-SC', 'livro', 'ambos', true, 'es') RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_book, c_blmf, 1, 1);
  v_path := 'books/' || v_book || '/16_tesis.pdf';
  INSERT INTO storage.objects (bucket_id, name) VALUES (c_public, v_path);
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, mime_type,
                                             storage_bucket, storage_path, rights_status, rights_justification, metadata)
  VALUES (v_book, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'application/pdf',
          c_public, v_path, 'dominio_publico', NULL,
          jsonb_build_object('restriction_demandee', jsonb_build_object('le', '2026-10-22', 'par', 'essai', 'item', 'J13',
                             'motif', 'auteur mort en 2021, cas (c)')))
  RETURNING id INTO v_marquee;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, mime_type,
                                             storage_bucket, storage_path, rights_status, rights_justification)
  VALUES (v_book, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'application/pdf',
          c_public, 'books/' || v_book || '/libre.pdf', 'dominio_publico', 'Sans décision.')
  RETURNING id INTO v_libre;

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 garde : coordination et ressource non marquée refusées ; administration servie';
  v_n := 0;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  BEGIN PERFORM public.fn_digital_resource_realign_garde(v_marquee);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.not_found' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  BEGIN PERFORM public.fn_digital_resource_realign_garde(v_libre);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.not_found' THEN v_n := v_n + 1; END IF; END;
  v_g := public.fn_digital_resource_realign_garde(v_marquee);
  IF v_n = 2 AND (v_g->>'sans_candidat')::boolean AND v_g->>'sha256' IS NULL AND v_g->>'candidate_id' IS NULL
     AND v_g->'from'->>'bucket' = c_public AND v_g->'from'->>'path' = v_path
     AND v_g->'destination'->>'storage_bucket' = c_restrito AND v_g->'destination'->>'access_scope' = 'conta_ativa'
     AND NOT (v_g->>'aligned')::boolean AND (v_g->>'caller')::uuid = v_admin THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/2 ' || coalesce(v_g::text, '-')); END IF;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 enregistrement refuse : hors administration, seau, chemin, empreinte, objet absent ; rien ne bouge';
  v_n := 0;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_marquee, v_coordA, c_public, v_path, c_restrito, v_path, v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.coord_only' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_marquee, v_admin, c_public, v_path, c_public, v_path, v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.wrong_bucket' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_marquee, v_admin, c_public, v_path, c_restrito, 'books/' || v_book || '/autre.pdf', v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.bad_path' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_marquee, v_admin, c_public, v_path, c_restrito, v_path, 'pas-une-empreinte');
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.fingerprint_mismatch' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_marquee, v_admin, c_public, v_path, c_restrito, v_path, v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.object_missing' THEN v_n := v_n + 1; END IF; END;
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_marquee;
  IF v_n = 5 AND v_r.storage_bucket = c_public AND v_r.access_scope = 'publico' AND NOT (v_r.metadata ? 'realignements') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/5 ' || to_jsonb(v_r)::text); END IF;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 fait : restreint, motif, empreinte, restriction_faite, historique ; puis aligned';
  INSERT INTO storage.objects (bucket_id, name) VALUES (c_restrito, v_path);   -- la copie faite par la fonction Edge
  PERFORM ingest.fn_digital_resource_realign_record(v_marquee, v_admin, c_public, v_path, c_restrito, v_path, upper(v_sha));
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_marquee;
  IF v_r.storage_bucket = c_restrito AND v_r.storage_path = v_path AND v_r.access_scope = 'conta_ativa'
     AND v_r.resource_type = 'pdf_restrito' AND v_r.rights_status = 'sob_direitos' AND v_r.is_active
     AND v_r.rights_justification LIKE 'Restreint le %auteur mort en 2021, cas (c).'
     AND v_r.metadata->>'sha256' = v_sha
     AND v_r.metadata ? 'restriction_demandee'
     AND (v_r.metadata->'restriction_faite'->>'fait_par')::uuid = v_admin
     AND jsonb_array_length(v_r.metadata->'realignements') = 1
     AND (v_r.metadata->'realignements'->0->>'sans_candidat')::boolean
     AND v_r.metadata->'realignements'->0->'de'->>'bucket' = c_public
     AND (public.fn_digital_resource_realign_garde(v_marquee)->>'aligned')::boolean THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_r)::text); END IF;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 chemin des candidats intact, droits inchangés';
  v_n := 0;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  BEGIN PERFORM public.fn_digital_resource_realign_garde(v_libre);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.not_found' THEN v_n := v_n + 1; END IF; END;
  IF v_n = 1
     AND NOT has_function_privilege('authenticated', 'ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text)', 'EXECUTE')
     AND has_function_privilege('service_role', 'ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.fn_digital_resource_realign_garde(bigint)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_digital_resource_realign_garde(bigint)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/1'); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'NUMDIF-RESTREINDRE OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'NUMDIF-RESTREINDRE ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || ');
  END IF;
END $$;
