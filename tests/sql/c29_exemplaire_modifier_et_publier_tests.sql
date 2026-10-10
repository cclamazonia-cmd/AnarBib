-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — C29 lot 3 (10/10/2026) : modifier un exemplaire publié en un geste.
--   fn_exemplaire_modifier_et_publier(p_exemplar_id, p_changes) enchaîne, dans
--   une seule transaction, la reprise (create_exemplar_draft_from_exemplar), la
--   mise à jour des champs permis et publish_exemplar_draft TEL QUEL.
--   T1 sous une coordination de la bibliothèque : cote et notes changent, le
--      numéro, la circulation et la visibilité (« équipe uniquement ») restent ;
--      le brouillon publié reste comme trace ;
--   T2 la reprise copie désormais circulation et visibilité (défaut d'avant :
--      le brouillon naissait « public » et la republication le propageait) ;
--   T3 circulation, visibilité et date d'acquisition changent quand on le demande ;
--   T4 un champ hors liste (tombo) : refusé 22023, HINT error.copies.field_not_allowed,
--      rien ne change, aucun brouillon vivant ne reste ;
--   T5 un brouillon de mise à jour déjà vivant : refusé, HINT error.copies.update_pending ;
--   T6 un compte sans rôle d'équipe dans cette bibliothèque : refusé 42501,
--      HINT error.catalog.draft_other_library ;
--   T7 sans compte (auth.uid() nul) : refusé 42501 ;
--   T8 droits : DEFINER, search_path figé, EXECUTE à authenticated et
--      service_role, fermée à anon ;
--   T9 une valeur que la base refuse (visibilité inconnue, 23514) : rien ne
--      change, aucun brouillon ne reste.
-- Tout se fait sous postgres avec un JWT simulé (stub auth) ; la suite lève
-- toujours (OK ou ECHEC) : rien ne reste en base.
-- Mutant éprouvé : sans la copie de circulation/visibilité dans la reprise, T1 et T2 rougissent.
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_lib uuid; v_book bigint; v_hold bigint; v_ex bigint; v_ret bigint; v_tombo text;
  v_coord uuid := gen_random_uuid(); v_autre uuid := gen_random_uuid();
  v_d bigint; v_n int; v_b boolean; v_txt text; v_hint text; v_state text;
  r record; v_fn oid;
BEGIN
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, tombo_pattern)
  VALUES ('c29-' || v_suf, 'C29 (essai)', 'federated', 'full_sigb', true, 'public', jsonb_build_object('prefix', 'C29' || v_suf || '-', 'pad', 3, 'year', false))
  RETURNING id INTO v_lib;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material) VALUES ('C29 (essai)', 'Essai, Autrice', 'C29-' || v_suf, 'livro') RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib) RETURNING id INTO v_hold;
  v_tombo := public.fn_next_tombo(v_lib);
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility, shelf_location, notes)
  VALUES ('C29-' || v_suf, v_tombo, v_lib, v_hold, 'consulta', 'staff_only', 'Setor/sala: Sala A', 'ancienne note') RETURNING id INTO v_ex;
  -- La coordination de la bibliothèque, et un compte sans rôle d'équipe.
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_coord, 'authenticated', 'authenticated', 'c29-coord-' || v_suf || '@anarbib.local', now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb),
         ('00000000-0000-0000-0000-000000000000', v_autre, 'authenticated', 'authenticated', 'c29-autre-' || v_suf || '@anarbib.local', now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb);
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (v_coord, 'c29-coord-' || v_suf || '@anarbib.local', 'C29', 'Coord', 'fr'),
         (v_autre, 'c29-autre-' || v_suf || '@anarbib.local', 'C29', 'Autre', 'fr');
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES (v_coord, v_lib, 'coordenador', 'active');

  -- ───────────────────────────────────────────────────────
  v_t := 'T1 coordination : cote et notes changent ; numéro, circulation et visibilité « équipe uniquement » restent ; le brouillon publié reste comme trace';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_ret := public.fn_exemplaire_modifier_et_publier(v_ex, jsonb_build_object('shelf_location', 'Setor/sala: Sala B · Estante: 4', 'notes', 'reliure refaite'));
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT * INTO r FROM public.exemplares e WHERE e.id = v_ex;
    SELECT count(*) INTO v_n FROM public.exemplar_drafts d WHERE d.published_exemplar_id = v_ex AND d.status = 'published' AND d.action = 'update';
    v_b := v_ret = v_ex AND r.shelf_location = 'Setor/sala: Sala B · Estante: 4' AND r.notes = 'reliure refaite'
       AND r.tombo = v_tombo AND r.circulation_policy = 'consulta' AND r.visibility = 'staff_only' AND r.library_id = v_lib AND v_n = 1;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : ret %s, cote %s, notes %s, tombo %s, circ %s, vis %s, traces %s', v_ret, r.shelf_location, r.notes, r.tombo, r.circulation_policy, r.visibility, v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T2 la reprise copie circulation et visibilité de l''exemplaire';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_d := public.create_exemplar_draft_from_exemplar(v_ex, NULL);
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT * INTO r FROM public.exemplar_drafts d WHERE d.id = v_d;
    v_b := r.circulation_policy = 'consulta' AND r.visibility = 'staff_only' AND r.published_exemplar_id = v_ex AND r.action = 'update';
    DELETE FROM public.exemplar_drafts WHERE id = v_d;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : circ %s, vis %s', r.circulation_policy, r.visibility)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T3 circulation, visibilité et date d''acquisition changent quand on le demande ; une valeur vide efface la note';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_ret := public.fn_exemplaire_modifier_et_publier(v_ex, jsonb_build_object('circulation_policy', 'ambos', 'visibility', 'public', 'acquisition_date', '2026-10-10', 'notes', ''));
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT * INTO r FROM public.exemplares e WHERE e.id = v_ex;
    v_b := r.circulation_policy = 'ambos' AND r.visibility = 'public' AND r.acquisition_date = date '2026-10-10'
       AND r.shelf_location = 'Setor/sala: Sala B · Estante: 4' AND r.tombo = v_tombo;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : circ %s, vis %s, date %s, cote %s, notes %s', r.circulation_policy, r.visibility, r.acquisition_date, r.shelf_location, r.notes)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T4 un champ hors liste (tombo) : refusé 22023 error.copies.field_not_allowed ; rien ne change ; aucun brouillon vivant';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_exemplaire_modifier_et_publier(v_ex, jsonb_build_object('tombo', 'C29' || v_suf || '-099', 'notes', 'x')); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT * INTO r FROM public.exemplares e WHERE e.id = v_ex;
    SELECT count(*) INTO v_n FROM public.exemplar_drafts d WHERE d.published_exemplar_id = v_ex AND d.status IN ('draft', 'ready');
    v_b := v_txt = 'refusé' AND v_state = '22023' AND v_hint = 'error.copies.field_not_allowed' AND r.tombo = v_tombo AND r.notes IS NULL AND v_n = 0;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s, tombo %s, vivants %s', v_txt, v_state, v_hint, r.tombo, v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T5 un brouillon de mise à jour déjà vivant : refusé, error.copies.update_pending (la reprise se poursuit dans l''éditeur)';
  BEGIN
    -- created_at dans le passé : le déclencheur des reprises ne le marque pas « jamais touché ».
    INSERT INTO public.exemplar_drafts (published_exemplar_id, action, status, target_bib_ref, target_library_id, tombo, created_by, created_at)
    VALUES (v_ex, 'update', 'draft', 'C29-' || v_suf, v_lib, v_tombo, v_coord, now() - interval '1 minute') RETURNING id INTO v_d;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_exemplaire_modifier_et_publier(v_ex, jsonb_build_object('notes', 'y')); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT retake_untouched INTO v_b FROM public.exemplar_drafts WHERE id = v_d;
    DELETE FROM public.exemplar_drafts WHERE id = v_d;
    v_b := v_txt = 'refusé' AND v_hint = 'error.copies.update_pending' AND NOT v_b;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s', v_txt, v_state, v_hint)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T6 un compte sans rôle d''équipe dans la bibliothèque : refusé 42501 error.catalog.draft_other_library ; rien ne change';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_exemplaire_modifier_et_publier(v_ex, jsonb_build_object('notes', 'intrus')); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT * INTO r FROM public.exemplares e WHERE e.id = v_ex;
    v_b := v_txt = 'refusé' AND v_state = '42501' AND v_hint = 'error.catalog.draft_other_library' AND r.notes IS NULL;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s', v_txt, v_state, v_hint)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T7 sans compte (auth.uid() nul) : refusé 42501';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    BEGIN
      PERFORM public.fn_exemplaire_modifier_et_publier(v_ex, jsonb_build_object('notes', 'anonyme')); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; v_state := SQLSTATE; v_txt := 'refusé'; END;
    v_b := v_txt = 'refusé' AND v_state = '42501';
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s %s', v_txt, v_state, v_hint)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T8 droits : DEFINER, search_path figé, EXECUTE à authenticated et service_role, fermée à anon';
  BEGIN
    v_fn := 'public.fn_exemplaire_modifier_et_publier(bigint, jsonb)'::regprocedure;
    SELECT p.prosecdef AND coalesce(array_to_string(p.proconfig, ' '), '') LIKE '%search_path%' INTO v_b FROM pg_proc p WHERE p.oid = v_fn;
    v_b := v_b AND NOT has_function_privilege('anon', v_fn, 'EXECUTE')
       AND has_function_privilege('authenticated', v_fn, 'EXECUTE')
       AND has_function_privilege('service_role', v_fn, 'EXECUTE');
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : anon %s, authenticated %s', has_function_privilege('anon', v_fn, 'EXECUTE'), has_function_privilege('authenticated', v_fn, 'EXECUTE'))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T9 une valeur que la base refuse (visibilité inconnue) : 23514, rien ne change, aucun brouillon ne reste';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_exemplaire_modifier_et_publier(v_ex, jsonb_build_object('visibility', 'secret')); v_txt := 'passé';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; v_txt := 'refusé'; END;
    PERFORM set_config('request.jwt.claims', '', true);
    SELECT * INTO r FROM public.exemplares e WHERE e.id = v_ex;
    SELECT count(*) INTO v_n FROM public.exemplar_drafts d WHERE d.published_exemplar_id = v_ex AND d.status IN ('draft', 'ready');
    v_b := v_txt = 'refusé' AND v_state = '23514' AND r.visibility = 'public' AND v_n = 0;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : %s %s, vis %s, vivants %s', v_txt, v_state, r.visibility, v_n)); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'C29-MODIFIER-ET-PUBLIER ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'C29-MODIFIER-ET-PUBLIER OK : %/%', v_passed, v_passed;
END $$;
