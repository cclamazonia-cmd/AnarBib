-- =====================================================================
-- AnarBib — Tests d'acceptation : réaligner une ressource versée sur le cas
-- de son candidat (REGISTRE §47 NUMDIF-2, NUMDIF-4, NUMDIF-6)
-- Date    : 2026-10-19  ·  Session : Anarchief — ouvrir le lot Overige
-- Ref     : migration 20261019145347_numdif_overige_a_b_et_realignement ;
--           supabase/functions/realign-digital-resource/index.ts
--
-- La fonction Edge enchaîne : garde (sous le jeton) → empreinte du fichier en
-- place → copie vers le seau du cas → empreinte de la copie → enregistrement
-- (clé de service) → effacement de l'original. Ici, les deux fonctions de la
-- base qu'elle appelle, avec les objets de stockage posés à la main.
--
-- T1  la garde : sans compte, une autre bibliothèque, une ressource sans
--     candidat — refusés ; la coordination reçoit seau, chemin, empreinte,
--     destination, et « aligned » tant que rien n'a changé
-- T2  l'enregistrement est fermé à authenticated et anon, ouvert à service_role ;
--     la garde ouverte à authenticated, fermée à anon
-- T3  l'enregistrement refuse : ressource déplacée depuis la garde, mauvais
--     seau, chemin changé, empreinte différente, objet absent du seau de
--     destination, personne sans portée — et rien ne bouge
-- T4  cas repassé en diffusion_autorisee (lot) : la ressource passe au seau
--     public, publico, pdf_publico, licenca_livre, justification du lot,
--     historique ; la garde dit « aligned » ; aucune portée ne contredit son seau
-- T5  l'autre sens (retrait à première demande) : cas repassé en
--     statut_inconnu, la ressource revient dans pdf-restrito, conta_ativa,
--     sob_direitos ; deux entrées d'historique
--
--   Bilan OK : 'NUMDIF-REALIGNEMENT OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_blmf   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- seed
  v_coordA constant uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_coordB constant uuid := 'b1600000-0000-4000-8000-000000000002';
  c_restrito constant text := 'pdf-restrito';
  c_public constant text := 'anarbib-pdf-public';
  v_libB uuid;
  v_book bigint;
  v_sha constant text := repeat('ab', 32);
  v_c bigint; v_rid bigint; v_autre bigint;
  v_path text;
  v_g jsonb; v_hint text; v_n int;
  v_r public.book_digital_resources%rowtype;
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-numdif-realign-b', 'Essai NUMDIF réalignement B', true, 'public') RETURNING id INTO v_libB;
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_coordB, 'authenticated', 'authenticated', 'numdif.realign.b@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (v_coordB, 'numdif.realign.b@anarbib.local', 'CoordB', 'Test', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES (v_coordB, v_libB, 'coordenador', 'active');

  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable, idioma)
  VALUES ('Essai NUMDIF réalignement', 'TEST-NUMDIF-R', 'livro', 'ambos', true, 'nl') RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count) VALUES (v_book, c_blmf, 1, 1);

  -- un PDF versé par lot en statut_inconnu, comme les 156 d'« Overige bestanden »
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  PERFORM public.fn_digital_candidates_propose(c_blmf, jsonb_build_array(
    jsonb_build_object('book_id', v_book, 'file_url', 'https://anarchief.org/w/images/a/ab/essai.pdf',
                       'page_url', 'https://anarchief.org/wiki/Bestand:essai.pdf', 'source_name', 'Essai wiki',
                       'source_identifier', 'essai.pdf', 'sha256', v_sha, 'file_size_bytes', 1000,
                       'original_filename', 'essai.pdf')));
  SELECT id INTO v_c FROM ingest.digital_candidates WHERE book_id = v_book;
  PERFORM public.fn_digital_candidate_decide(v_c, 'valider', 'meme_edition', 'statut_inconnu',
    'Lot « Essai », lettre « — » ; NUMDIF-6 : notice et fichier de la même source ; validation par lot par l''administration du réseau.');
  v_path := 'books/' || v_book || '/1792100000000_essai.pdf';
  INSERT INTO storage.objects (bucket_id, name) VALUES (c_restrito, v_path);
  v_rid := (ingest.fn_digital_candidate_deposit_record(v_c, v_coordA, c_restrito, v_path, v_sha, NULL, 1000)->>'resource_id')::bigint;
  -- une ressource sans candidat NUMDIF (ajoutée à la main)
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, mime_type,
                                             storage_bucket, storage_path, rights_status, rights_justification)
  VALUES (v_book, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'active', true, 'application/pdf',
          c_restrito, 'books/' || v_book || '/main.pdf', 'sob_direitos', 'Ajout manuel.')
  RETURNING id INTO v_autre;

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 la garde : anon, autre bibliotheque, sans candidat refuses ; coordination servie, aligned';
  v_n := 0;
  PERFORM set_config('request.jwt.claims', '{}', true);
  BEGIN PERFORM public.fn_digital_resource_realign_garde(v_rid);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.coord_only' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
  BEGIN PERFORM public.fn_digital_resource_realign_garde(v_rid);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.not_found' THEN v_n := v_n + 1; END IF; END;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  BEGIN PERFORM public.fn_digital_resource_realign_garde(v_autre);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.not_found' THEN v_n := v_n + 1; END IF; END;
  v_g := public.fn_digital_resource_realign_garde(v_rid);
  IF v_n = 3 AND v_g->>'sha256' = v_sha AND v_g->'from'->>'bucket' = c_restrito AND v_g->'from'->>'path' = v_path
     AND v_g->'destination'->>'storage_bucket' = c_restrito AND (v_g->>'aligned')::boolean
     AND (v_g->>'caller')::uuid = v_coordA AND (v_g->>'candidate_id')::bigint = v_c THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/3 ' || coalesce(v_g::text, '-')); END IF;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 enregistrement ferme a authenticated et anon, ouvert a service_role ; garde ouverte a authenticated seulement';
  IF NOT has_function_privilege('authenticated', 'ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text)', 'EXECUTE')
     AND has_function_privilege('service_role', 'ingest.fn_digital_resource_realign_record(bigint, uuid, text, text, text, text, text)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.fn_digital_resource_realign_garde(bigint)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_digital_resource_realign_garde(bigint)', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- le cas change, comme le fait la migration pour « Overige bestanden »
  UPDATE ingest.digital_candidates
     SET source_case = 'diffusion_autorisee', rights_mention = 'idem',
         rights_mention_page = 'déclaration par lot (essai, précisée le 19/10/2026)',
         justification = replace(justification, 'lettre « — »', 'lettre « A + B »')
   WHERE id = v_c;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 enregistrement refuse : deplacee, seau, chemin, empreinte, objet absent, sans portee ; rien ne bouge';
  v_n := 0;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_rid, v_coordA, c_public, v_path, c_public, v_path, v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.wrong_bucket' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_rid, v_coordA, c_restrito, v_path, c_restrito, v_path, v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.wrong_bucket' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_rid, v_coordA, c_restrito, v_path, c_public, 'books/' || v_book || '/autre.pdf', v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.bad_path' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_rid, v_coordA, c_restrito, v_path, c_public, v_path, repeat('cd', 32));
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.fingerprint_mismatch' THEN v_n := v_n + 1; END IF; END;
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_rid, v_coordA, c_restrito, v_path, c_public, v_path, v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.object_missing' THEN v_n := v_n + 1; END IF; END;
  INSERT INTO storage.objects (bucket_id, name) VALUES (c_public, v_path);
  BEGIN PERFORM ingest.fn_digital_resource_realign_record(v_rid, v_coordB, c_restrito, v_path, c_public, v_path, v_sha);
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.digital_candidate.coord_only' THEN v_n := v_n + 1; END IF; END;
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_rid;
  IF v_n = 6 AND v_r.storage_bucket = c_restrito AND v_r.access_scope = 'conta_ativa' AND NOT (v_r.metadata ? 'realignements') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || '/6 ' || to_jsonb(v_r)::text); END IF;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 diffusion_autorisee : seau public, publico, licenca_livre, justification du lot, historique, aligned';
  v_g := public.fn_digital_resource_realign_garde(v_rid);
  PERFORM ingest.fn_digital_resource_realign_record(v_rid, v_coordA, c_restrito, v_path, c_public, v_path, upper(v_sha));
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_rid;
  IF NOT (v_g->>'aligned')::boolean AND v_g->'destination'->>'storage_bucket' = c_public
     AND v_r.storage_bucket = c_public AND v_r.storage_path = v_path AND v_r.access_scope = 'publico'
     AND v_r.resource_type = 'pdf_publico' AND v_r.rights_status = 'licenca_livre' AND v_r.is_active
     AND v_r.rights_justification LIKE '%lettre « A + B »%Declaração de direitos por lote do arquivista (Rechtenregeling v0.1).'
     AND v_r.rights_justification NOT LIKE '%Menção impressa%'
     AND v_r.metadata->>'source_case' = 'diffusion_autorisee' AND v_r.metadata->>'sha256' = v_sha
     AND jsonb_array_length(v_r.metadata->'realignements') = 1
     AND v_r.metadata->'realignements'->0->'de'->>'bucket' = c_restrito
     AND v_r.metadata->'realignements'->0->'vers'->>'access_scope' = 'publico'
     AND (public.fn_digital_resource_realign_garde(v_rid)->>'aligned')::boolean
     AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources r JOIN storage.buckets b ON b.id = r.storage_bucket
                      WHERE r.status = 'active' AND r.is_active
                        AND ((r.access_scope <> 'publico' AND b.public) OR (r.access_scope = 'publico' AND NOT b.public))) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_r)::text); END IF;

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 retrait : statut_inconnu ramene dans pdf-restrito, conta_ativa, sob_direitos, deux entrees';
  UPDATE ingest.digital_candidates SET source_case = 'statut_inconnu' WHERE id = v_c;
  DELETE FROM storage.objects WHERE bucket_id = c_restrito AND name = v_path;   -- l'original effacé au premier passage
  INSERT INTO storage.objects (bucket_id, name) VALUES (c_restrito, v_path);    -- la copie du retour
  PERFORM ingest.fn_digital_resource_realign_record(v_rid, v_coordA, c_public, v_path, c_restrito, v_path, v_sha);
  SELECT * INTO v_r FROM public.book_digital_resources WHERE id = v_rid;
  IF v_r.storage_bucket = c_restrito AND v_r.access_scope = 'conta_ativa' AND v_r.resource_type = 'pdf_restrito'
     AND v_r.rights_status = 'sob_direitos' AND v_r.rights_justification NOT LIKE '%Declaração de direitos%'
     AND jsonb_array_length(v_r.metadata->'realignements') = 2 THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || to_jsonb(v_r)::text); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'NUMDIF-REALIGNEMENT OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'NUMDIF-REALIGNEMENT ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || ');
  END IF;
END $$;
