-- =====================================================================
-- AnarBib — Tests de non-régression : la notion de source ne change rien
-- aux bibliothèques ordinaires (public / network / private)
-- Date    : 2026-10-19
-- Ref     : migration 20261019122125_une_source_publie_ses_notices_sans_entrer_a_l_annuaire
--
-- Sans aucune source (catalog_public faux partout), pour cinq identités —
-- anonyme, lectrice d'une privée, membre du réseau, compte sans adhésion,
-- coordination d'une bibliothèque « network » :
--   T1 private.fn_catalog_library_ids() = public.fn_visible_library_ids(), et
--      fn_catalog_library_visible_to_caller = fn_library_visible_to_caller,
--      bibliothèque par bibliothèque ;
--   T2 les notices lisibles (books, book_holdings) sont celles d'avant :
--      publique pour toutes, réseau pour les membres, privée pour sa lectrice ;
--   T3 la liste anonyme ne montre toujours que les notices publiques À
--      exemplaire (une notice publique sans exemplaire en reste absente) ;
--      la liste de session montre à un compte sans adhésion les notices
--      publiques, et le réseau à un·e membre ;
--   T4 ressources numériques : une publique validée tenue par une biblio
--      « network » reste fermée à l'anonyme, ouverte au membre ; celle d'une
--      publique s'ouvre à tous (table et get_book_primary_public…) ;
--   T5 OAI : éligibilité inchangée (publique et réseau publiées oui, privée
--      non, isolée non) ;
--   T6 annuaire : la publique y est, la réseau et la privée non ; une privée à
--      inscription ouverte reste lisible en ligne (branche d'inscription de
--      libraries_read intacte), une réseau à inscription fermée non.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'SOURCE-RIEN-NE-CHANGE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_pub    constant uuid := '5c5c5c5c-0000-4000-8000-0000000000b1';
  c_rede   constant uuid := '5c5c5c5c-0000-4000-8000-0000000000b2';
  c_priv   constant uuid := '5c5c5c5c-0000-4000-8000-0000000000b3';  -- privée, inscription ouverte
  c_iso    constant uuid := '5c5c5c5c-0000-4000-8000-0000000000b4';  -- publique mais isolée
  c_lect   constant uuid := '5c5c5c5c-0000-4000-8000-000000000021';  -- lectrice de la privée
  c_membre constant uuid := '5c5c5c5c-0000-4000-8000-000000000022';  -- lectrice de la publique
  c_sans   constant uuid := '5c5c5c5c-0000-4000-8000-000000000023';  -- sans adhésion
  c_coord  constant uuid := '5c5c5c5c-0000-4000-8000-000000000024';  -- coordination de la réseau
  v_b_pub bigint; v_b_pub0 bigint; v_b_rede bigint; v_b_priv bigint;
  v_r_rede bigint; v_r_pub bigint;
  v_n int; v_txt text; v_ok boolean; r record; v_ids uuid[]; v_attendu uuid[];
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.libraries (id, slug, name, visibility_level, network_mode, catalog_mode, accepts_public_signup, is_active)
  VALUES (c_pub,  'rnc-publique', 'Publique (rien ne change)', 'public',  'federated', 'network_published', true,  true),
         (c_rede, 'rnc-reseau',   'Réseau (rien ne change)',   'network', 'federated', 'network_published', false, true),
         (c_priv, 'rnc-privee',   'Privée (rien ne change)',   'private', 'federated', 'network_published', true,  true),
         (c_iso,  'rnc-isolee',   'Isolée (rien ne change)',   'public',  'isolated',  'local_only',        false, true);
  FOR r IN SELECT * FROM (VALUES (c_lect, 'lectrice'), (c_membre, 'membre'), (c_sans, 'sans'), (c_coord, 'coord')) x(id, nom) LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', r.id, 'authenticated', 'authenticated', 'rnc.' || r.nom || '@anarbib.local',
            now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
    VALUES (r.id, 'rnc.' || r.nom || '@anarbib.local', 'Rnc', r.nom, 'fr') ON CONFLICT (id) DO NOTHING;
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_lect, c_priv, 'reader', 'active'), (c_membre, c_pub, 'reader', 'active'), (c_coord, c_rede, 'coordenador', 'active');

  INSERT INTO public.books (titulo, bib_ref) VALUES ('Zzrnc publique', 'RNC-1') RETURNING id INTO v_b_pub;
  INSERT INTO public.books (titulo, bib_ref) VALUES ('Zzrnc publique sans exemplaire', 'RNC-2') RETURNING id INTO v_b_pub0;
  INSERT INTO public.books (titulo, bib_ref) VALUES ('Zzrnc réseau', 'RNC-3') RETURNING id INTO v_b_rede;
  INSERT INTO public.books (titulo, bib_ref) VALUES ('Zzrnc privée', 'RNC-4') RETURNING id INTO v_b_priv;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count)
  VALUES (v_b_pub, c_pub, 1, 1), (v_b_pub0, c_pub, 0, 0), (v_b_rede, c_rede, 1, 1), (v_b_priv, c_priv, 1, 1);
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
                                             storage_bucket, storage_path, bibliographic_match_validated)
  VALUES (v_b_rede, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'essai/rnc-reseau.pdf', true)
  RETURNING id INTO v_r_rede;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
                                             storage_bucket, storage_path, bibliographic_match_validated)
  VALUES (v_b_pub, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'essai/rnc-publique.pdf', true)
  RETURNING id INTO v_r_pub;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 sans source, l''aide de catalogue rend exactement les bibliothèques visibles, pour cinq identités';
  BEGIN
    v_txt := NULL;
    -- une source laissée par une autre suite du banc est écartée de la comparaison
    FOR r IN SELECT * FROM (VALUES ('anon', ''), ('lectrice', json_build_object('sub', c_lect, 'role', 'authenticated')::text),
                                   ('membre', json_build_object('sub', c_membre, 'role', 'authenticated')::text),
                                   ('sans', json_build_object('sub', c_sans, 'role', 'authenticated')::text),
                                   ('coord', json_build_object('sub', c_coord, 'role', 'authenticated')::text)) x(nom, claims)
    LOOP
      PERFORM set_config('request.jwt.claims', r.claims, true);
      SELECT coalesce(array_agg(x ORDER BY x), '{}') INTO v_ids
        FROM unnest(private.fn_catalog_library_ids()) x
       WHERE x NOT IN (SELECT id FROM public.libraries WHERE catalog_public);
      v_attendu := public.fn_visible_library_ids();
      IF v_ids IS DISTINCT FROM v_attendu THEN v_txt := concat_ws(' ; ', v_txt, r.nom || ' (ensemble)'); END IF;
      SELECT count(*) INTO v_n FROM public.libraries l
       WHERE NOT l.catalog_public
         AND private.fn_catalog_library_visible_to_caller(l.id) IS DISTINCT FROM public.fn_library_visible_to_caller(l.id);
      IF v_n <> 0 THEN v_txt := concat_ws(' ; ', v_txt, r.nom || ' (' || v_n || ' bibliothèque(s))'); END IF;
    END LOOP;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : divergent pour ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 les notices lisibles sont celles d''avant, identité par identité';
  BEGIN
    v_txt := NULL;
    -- attendu : (publique, réseau, privée) visibles ?
    FOR r IN SELECT * FROM (VALUES
        ('anon',     '',                                                                     'anon',          true, false, false),
        ('lectrice', json_build_object('sub', c_lect,   'role', 'authenticated')::text,   'authenticated', true, true,  true),
        ('membre',   json_build_object('sub', c_membre, 'role', 'authenticated')::text,   'authenticated', true, true,  false),
        ('sans',     json_build_object('sub', c_sans,   'role', 'authenticated')::text,   'authenticated', true, false, false),
        ('coord',    json_build_object('sub', c_coord,  'role', 'authenticated')::text,   'authenticated', true, true,  false)
      ) x(nom, claims, role, voit_pub, voit_rede, voit_priv)
    LOOP
      PERFORM set_config('request.jwt.claims', r.claims, true);
      EXECUTE format('SET LOCAL ROLE %I', r.role);
      IF EXISTS (SELECT 1 FROM public.books WHERE id = v_b_pub)  IS DISTINCT FROM r.voit_pub
         OR EXISTS (SELECT 1 FROM public.books WHERE id = v_b_rede) IS DISTINCT FROM r.voit_rede
         OR EXISTS (SELECT 1 FROM public.books WHERE id = v_b_priv) IS DISTINCT FROM r.voit_priv
         OR EXISTS (SELECT 1 FROM public.book_holdings WHERE book_id = v_b_rede) IS DISTINCT FROM r.voit_rede
         OR EXISTS (SELECT 1 FROM public.book_holdings WHERE book_id = v_b_priv) IS DISTINCT FROM r.voit_priv THEN
        v_txt := concat_ws(' ; ', v_txt, r.nom);
      END IF;
      EXECUTE 'RESET ROLE';
    END LOOP;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : divergent pour ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 listes : l''anonyme ne voit que le public à exemplaire ; la session, le public ou le réseau selon l''adhésion';
  BEGIN
    v_txt := NULL;
    PERFORM set_config('request.jwt.claims', '', true);
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT string_agg(bib_ref, ',' ORDER BY bib_ref) INTO v_txt FROM api.catalog_list_anon_v1 WHERE bib_ref LIKE 'RNC-%';
    EXECUTE 'RESET ROLE';
    v_ok := v_txt IS NOT DISTINCT FROM 'RNC-1';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_sans, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT string_agg(bib_ref, ',' ORDER BY bib_ref) INTO v_txt FROM api.catalog_list_session_v1 WHERE bib_ref LIKE 'RNC-%';
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND v_txt IS NOT DISTINCT FROM 'RNC-1,RNC-2';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT string_agg(bib_ref, ',' ORDER BY bib_ref) INTO v_txt FROM api.catalog_list_session_v1 WHERE bib_ref LIKE 'RNC-%';
    EXECUTE 'RESET ROLE';
    v_ok := v_ok AND v_txt IS NOT DISTINCT FROM 'RNC-1,RNC-2,RNC-3';
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : dernier lu ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 ressources : réseau fermée à l''anonyme et ouverte au membre ; publique ouverte à tous';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    EXECUTE 'SET LOCAL ROLE anon';
    v_ok := NOT EXISTS (SELECT 1 FROM public.book_digital_resources WHERE id = v_r_rede)
        AND NOT EXISTS (SELECT 1 FROM public.get_book_primary_public_digital_asset_v2(v_b_rede))
        AND EXISTS (SELECT 1 FROM public.book_digital_resources WHERE id = v_r_pub)
        AND EXISTS (SELECT 1 FROM public.get_book_primary_public_digital_asset_v2(v_b_pub) WHERE asset_id = v_r_pub)
        AND NOT EXISTS (SELECT 1 FROM public.catalog_digital_access_v1(ARRAY[v_b_rede]))
        AND EXISTS (SELECT 1 FROM public.catalog_digital_access_v1(ARRAY[v_b_pub]));
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_ok := v_ok AND EXISTS (SELECT 1 FROM public.book_digital_resources WHERE id = v_r_rede)
                 AND EXISTS (SELECT 1 FROM public.get_book_primary_public_digital_asset_v2(v_b_rede))
                 AND EXISTS (SELECT 1 FROM public.get_accessible_digital_asset_by_id_v2(v_r_rede));
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 OAI : éligibilité inchangée';
  BEGIN
    IF public.fn_oai_library_is_harvest_eligible(c_pub) AND public.fn_oai_library_is_harvest_eligible(c_rede)
       AND NOT public.fn_oai_library_is_harvest_eligible(c_priv) AND NOT public.fn_oai_library_is_harvest_eligible(c_iso) THEN
      v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 annuaire inchangé, branche d''inscription de libraries_read intacte';
  BEGIN
    v_txt := NULL;
    PERFORM set_config('request.jwt.claims', '', true);
    EXECUTE 'SET LOCAL ROLE anon';
    IF NOT EXISTS (SELECT 1 FROM api.public_libraries WHERE id = c_pub) THEN v_txt := concat_ws(',', v_txt, 'publique absente'); END IF;
    IF EXISTS (SELECT 1 FROM api.public_libraries WHERE id IN (c_rede, c_priv)) THEN v_txt := concat_ws(',', v_txt, 'réseau/privée dans public_libraries'); END IF;
    IF NOT EXISTS (SELECT 1 FROM api.libraries_public_v1 WHERE id = c_pub)
       OR EXISTS (SELECT 1 FROM api.libraries_public_v1 WHERE id IN (c_rede, c_priv, c_iso)) THEN v_txt := concat_ws(',', v_txt, 'libraries_public_v1'); END IF;
    -- la branche d'inscription de libraries_read est intacte
    IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = c_priv) THEN v_txt := concat_ws(',', v_txt, 'ligne privée-inscription illisible'); END IF;
    IF EXISTS (SELECT 1 FROM public.libraries WHERE id = c_rede) THEN v_txt := concat_ws(',', v_txt, 'ligne réseau lisible'); END IF;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'SOURCE-RIEN-NE-CHANGE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'SOURCE-RIEN-NE-CHANGE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
