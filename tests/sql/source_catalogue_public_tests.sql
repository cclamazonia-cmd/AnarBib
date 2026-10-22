-- =====================================================================
-- AnarBib — Tests d'acceptation : une bibliothèque « source » publie ses
-- notices sans entrer à l'annuaire
-- Date    : 2026-10-19  ·  décision de Xavier du 19/10/2026
-- Ref     : migration 20261019122125_une_source_publie_ses_notices_sans_entrer_a_l_annuaire
--
-- Ce que voit le PUBLIC (SET LOCAL ROLE anon, aucun jeton), pour une source
-- privée, observatrice, inscription FERMÉE (sa ligne ne se lit donc que par la
-- branche neuve de libraries_read, pas par celle de l'inscription) :
--   T1 ses notices se lisent (books, book_holdings, book_authors, authors),
--      celles d'une privée ordinaire non ;
--   T2 la liste anonyme les montre, sans exemplaire, au nom de la source ; la
--      privée ordinaire en reste absente ;
--   T3 la fiche (catalog_book_detail_public_v2, book_copies_by_library_v1)
--      nomme la source qui tient la notice ;
--   T4 ressources numériques : la publique validée se lit (table, RPC
--      get_book_primary_public…, catalog_digital_access_v1,
--      get_accessible_digital_asset_by_id_v2) ; la restreinte reste fermée ;
--      une publique NON validée ne sort pas ;
--   T5 la recherche unifiée (search_catalog_v1) trouve la notice ;
--   T6 la bibliothèque reste absente de l'annuaire : public_libraries,
--      libraries_public_v1, v_libraries_for_signup, library_service_public,
--      v_library_service_public, fn_visible_library_ids,
--      fn_library_visible_to_caller ;
--   T7 OAI : jamais éligible — même passée en 'network', même avec une
--      demande propre ouverte et une ouverture réseau ouverte ; ses notices
--      ne se moissonnent pas ;
--   T8 connecté·e sans adhésion, et membre du réseau : la liste de session
--      montre la notice ;
--   T9 la garde : une coordination de la source ne peut pas changer
--      catalog_public (42501), l'administration du réseau le peut ;
--   T10 forme : aides dans private, ouvertes à anon/authenticated, DEFINER,
--      search_path posé ; 12 policies de notices sur l'aide de catalogue ;
--      la colonne naît fausse.
--   T11 le flux OPDS (EF `opds`, lue en anon depuis le 19/10/2026) : sa
--      requête sous anon sert la ressource de la source et celle de la
--      publique, jamais celle d'une privée ordinaire, ni passée en 'network',
--      ni d'une publique isolée ; source remise à catalog_public = false →
--      sa ressource sort du flux.
--
--   T12 le filtre « Bibliothèques AnarBib » du catalogue (api.catalog_filter_libraries_v1)
--      propose la source, sous anon comme connecté·e ; pas la privée ordinaire ;
--      la publique oui ; libraries_public_v1 (annuaire du filtre d'avant, RSS) reste sans la source.
--
--   T13 une bibliothèque de formation (is_training) sort du filtre pour tout le
--      monde (décision de Xavier, 22/10/2026 ; migration
--      20261022204656_une_bibliotheque_de_formation_sort_du_filtre_du_catalogue) :
--      ni anon, ni l'administration du réseau, ni sa propre équipe ne l'y
--      voient — même source active ; sans l'étiquette, anon et l'équipe la
--      verraient (contrôle à vide).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'SOURCE-CATALOGUE-PUBLIC OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_src    constant uuid := '5c5c5c5c-0000-4000-8000-0000000000a1';  -- source : privée, observatrice, inscription fermée
  c_priv   constant uuid := '5c5c5c5c-0000-4000-8000-0000000000a2';  -- privée ordinaire
  c_pub    constant uuid := '5c5c5c5c-0000-4000-8000-0000000000a3';  -- publique ordinaire
  c_form   constant uuid := '5c5c5c5c-0000-4000-8000-0000000000a4';  -- bibliothèque de formation (T13)
  c_coord  constant uuid := '5c5c5c5c-0000-4000-8000-000000000011';  -- coordination de la source
  c_admin  constant uuid := '5c5c5c5c-0000-4000-8000-000000000012';  -- administration du réseau
  c_sans   constant uuid := '5c5c5c5c-0000-4000-8000-000000000013';  -- compte sans adhésion
  c_membre constant uuid := '5c5c5c5c-0000-4000-8000-000000000014';  -- lectrice de la publique
  v_b_src bigint; v_b_pdf bigint; v_b_priv bigint; v_author bigint;
  v_r_pub bigint; v_r_restr bigint; v_r_nonval bigint;
  v_b_pubpdf bigint; v_r_pubpdf bigint; v_r_privpdf bigint; v_ids bigint[];
  v_n int; v_txt text; v_j jsonb; v_ok boolean; r record;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.libraries (id, slug, name, short_name, visibility_level, network_mode, catalog_mode, accepts_public_signup, is_active)
  VALUES (c_src,  'src-essai-source', 'Source d''essai (test source)', 'SrcEssai', 'private', 'observer',  'network_published', false, true),
         (c_priv, 'src-essai-privee', 'Privée d''essai (test source)', 'PrivEssai', 'private', 'federated', 'network_published', false, true),
         (c_pub,  'src-essai-publique', 'Publique d''essai (test source)', 'PubEssai', 'public', 'federated', 'network_published', true, true);
  INSERT INTO public.library_service_state (library_id) VALUES (c_src), (c_priv), (c_pub) ON CONFLICT (library_id) DO NOTHING;

  FOR r IN SELECT * FROM (VALUES (c_coord, 'coord'), (c_admin, 'admin'), (c_sans, 'sans'), (c_membre, 'membre')) x(id, nom) LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', r.id, 'authenticated', 'authenticated', 'src.' || r.nom || '@anarbib.local',
            now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
    VALUES (r.id, 'src.' || r.nom || '@anarbib.local', 'Src', r.nom, 'fr') ON CONFLICT (id) DO NOTHING;
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_coord, c_src, 'coordenador', 'active'), (c_membre, c_pub, 'reader', 'active');
  INSERT INTO public.network_administrators (user_id, status) VALUES (c_admin, 'active');

  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Zzsourceautrice Essai', 'ESSAI, Zzsourceautrice') RETURNING id INTO v_author;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material) VALUES ('Zzsourcetitre notice de source', 'ESSAI, Zzsourceautrice', 'SRC-1', 'livro') RETURNING id INTO v_b_src;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzsourcepdf notice numérisée', 'SRC-2', 'livro') RETURNING id INTO v_b_pdf;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzsourceprivee notice privée', 'SRC-3', 'livro') RETURNING id INTO v_b_priv;
  INSERT INTO public.book_authors (book_id, author_id, role, ord) VALUES (v_b_src, v_author, 'autor', 1);
  -- la source n'a pas d'exemplaire ; la privée en a un
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref, exemplares_total, available_count)
  VALUES (v_b_src, c_src, 'SRCESSAI-1', 0, 0), (v_b_pdf, c_src, 'SRCESSAI-2', 0, 0), (v_b_priv, c_priv, 'PRIV-1', 1, 1);

  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
                                             storage_bucket, storage_path, bibliographic_match_validated, label)
  VALUES (v_b_pdf, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'essai/source-publique.pdf', true, 'publique validée')
  RETURNING id INTO v_r_pub;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
                                             source_url, bibliographic_match_validated, label)
  VALUES (v_b_pdf, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'active', true, 'https://example.invalid/restreinte.pdf', true, 'restreinte')
  RETURNING id INTO v_r_restr;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
                                             source_url, bibliographic_match_validated, label)
  VALUES (v_b_src, 'link_externo', 'link_externo', 'publico', 'active', true, 'https://example.invalid/non-validee', false, 'publique non validée')
  RETURNING id INTO v_r_nonval;
  -- T11 (flux OPDS) : une publique validée tenue par la publique ordinaire, une
  -- autre tenue par la privée ordinaire
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzsourcepubpdf notice publique numérisée', 'SRC-4', 'livro') RETURNING id INTO v_b_pubpdf;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref, exemplares_total, available_count)
  VALUES (v_b_pubpdf, c_pub, 'PUB-4', 1, 1);
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
                                             storage_bucket, storage_path, bibliographic_match_validated, label)
  VALUES (v_b_pubpdf, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'essai/publique.pdf', true, 'publique de la publique')
  RETURNING id INTO v_r_pubpdf;
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
                                             storage_bucket, storage_path, bibliographic_match_validated, label)
  VALUES (v_b_priv, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'essai/privee.pdf', true, 'publique de la privée')
  RETURNING id INTO v_r_privpdf;

  -- la bascule : une ligne, posée en SQL (postgres) — c'est le geste de production
  UPDATE public.libraries SET catalog_public = true WHERE id = c_src;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
  REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
  PERFORM set_config('request.jwt.claims', '', true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 sous anon, les notices de la source se lisent, pas celles d''une privée ordinaire';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT count(*) INTO v_n FROM public.books WHERE id IN (v_b_src, v_b_pdf);
    v_ok := v_n = 2;
    SELECT count(*) INTO v_n FROM public.books WHERE id = v_b_priv;
    v_ok := v_ok AND v_n = 0;
    SELECT count(*) INTO v_n FROM public.book_holdings WHERE book_id IN (v_b_src, v_b_pdf) AND library_id = c_src;
    v_ok := v_ok AND v_n = 2;
    SELECT count(*) INTO v_n FROM public.book_holdings WHERE book_id = v_b_priv;
    v_ok := v_ok AND v_n = 0;
    SELECT count(*) INTO v_n FROM public.book_authors WHERE book_id = v_b_src;
    v_ok := v_ok AND v_n = 1;
    SELECT count(*) INTO v_n FROM public.authors WHERE id = v_author;
    v_ok := v_ok AND v_n = 1;
    -- la ligne de la source se lit (par la branche neuve : inscription fermée)
    SELECT count(*) INTO v_n FROM public.libraries WHERE id = c_src;
    v_ok := v_ok AND v_n = 1;
    SELECT count(*) INTO v_n FROM public.libraries WHERE id = c_priv;
    v_ok := v_ok AND v_n = 0;
    EXECUTE 'RESET ROLE';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la liste anonyme montre les notices de la source, sans exemplaire, à son nom';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT count(*), string_agg(DISTINCT library_name, ',') INTO v_n, v_txt
      FROM api.catalog_list_anon_v1 WHERE book_id IN (v_b_src, v_b_pdf);
    v_ok := v_n = 2 AND v_txt = 'Source d''essai (test source)';
    SELECT count(*) INTO v_n FROM api.catalog_list_anon_v1 WHERE book_id = v_b_priv;
    v_ok := v_ok AND v_n = 0;
    SELECT count(*) INTO v_n FROM api.catalog_list_anon_v1 WHERE book_id = v_b_src AND exemplares_total = 0 AND bibliotecas_count = 1;
    v_ok := v_ok AND v_n = 1;
    EXECUTE 'RESET ROLE';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : lu ' || v_n || ' / ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 la fiche nomme la source qui tient la notice';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT d.bibliotecas_count, d.holding_libraries_json INTO v_n, v_j
      FROM api.catalog_book_detail_public_v2 d WHERE d.book_id = v_b_src;
    v_ok := v_n = 1 AND v_j @> jsonb_build_array(jsonb_build_object('library_slug', 'src-essai-source', 'local_bib_ref', 'SRCESSAI-1'));
    v_j := api.book_copies_by_library_v1(v_b_src);
    v_ok := v_ok AND jsonb_array_length(v_j -> 'libraries') = 1
                 AND (v_j -> 'libraries' -> 0 ->> 'library_name') = 'Source d''essai (test source)';
    EXECUTE 'RESET ROLE';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_j::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 ressources : la publique validée se lit, la restreinte et la non validée non';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT count(*) INTO v_n FROM public.book_digital_resources WHERE id = v_r_pub;
    v_ok := v_n = 1;
    SELECT count(*) INTO v_n FROM public.book_digital_resources WHERE id = v_r_restr;
    v_ok := v_ok AND v_n = 0;
    SELECT count(*) INTO v_n FROM public.get_book_primary_public_digital_asset_v2(v_b_pdf) WHERE asset_id = v_r_pub;
    v_ok := v_ok AND v_n = 1;
    -- la seule publique de v_b_src n'est pas validée : rien ne sort
    SELECT count(*) INTO v_n FROM public.get_book_primary_public_digital_asset_v2(v_b_src);
    v_ok := v_ok AND v_n = 0;
    SELECT count(*) INTO v_n FROM public.catalog_digital_access_v1(ARRAY[v_b_pdf])
     WHERE public_usages = ARRAY['leitura_online'] AND has_restricted AND NOT can_read_restricted
       AND restricted_libraries @> '[{"slug": "src-essai-source"}]'::jsonb;
    v_ok := v_ok AND v_n = 1;
    SELECT count(*) INTO v_n FROM public.get_accessible_digital_asset_by_id_v2(v_r_pub) WHERE access_granted;
    v_ok := v_ok AND v_n = 1;
    SELECT count(*) INTO v_n FROM public.get_accessible_digital_asset_by_id_v2(v_r_restr);
    v_ok := v_ok AND v_n = 0;
    EXECUTE 'RESET ROLE';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 la recherche unifiée trouve la notice de la source';
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT count(*) INTO v_n FROM api.search_catalog_v1('Zzsourcetitre') s WHERE s.kind = 'book' AND s.id = v_b_src;
    EXECUTE 'RESET ROLE';
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 la source reste absente de l''annuaire et de ses vues';
  BEGIN
    v_txt := NULL;
    EXECUTE 'SET LOCAL ROLE anon';
    IF EXISTS (SELECT 1 FROM api.public_libraries WHERE id = c_src) THEN v_txt := concat_ws(',', v_txt, 'public_libraries'); END IF;
    IF EXISTS (SELECT 1 FROM api.libraries_public_v1 WHERE id = c_src) THEN v_txt := concat_ws(',', v_txt, 'libraries_public_v1'); END IF;
    IF EXISTS (SELECT 1 FROM public.v_libraries_for_signup WHERE slug = 'src-essai-source') THEN v_txt := concat_ws(',', v_txt, 'v_libraries_for_signup'); END IF;
    IF EXISTS (SELECT 1 FROM api.library_service_public WHERE library_id = c_src) THEN v_txt := concat_ws(',', v_txt, 'library_service_public'); END IF;
    IF EXISTS (SELECT 1 FROM public.v_library_service_public WHERE library_id = c_src) THEN v_txt := concat_ws(',', v_txt, 'v_library_service_public'); END IF;
    IF c_src = ANY (public.fn_visible_library_ids()) THEN v_txt := concat_ws(',', v_txt, 'fn_visible_library_ids'); END IF;
    IF public.fn_library_visible_to_caller(c_src) THEN v_txt := concat_ws(',', v_txt, 'fn_library_visible_to_caller'); END IF;
    -- et la publique ordinaire y est bien (le test lit ce qu'il croit lire)
    IF NOT EXISTS (SELECT 1 FROM api.public_libraries WHERE id = c_pub)
       OR NOT EXISTS (SELECT 1 FROM api.libraries_public_v1 WHERE id = c_pub) THEN v_txt := concat_ws(',', v_txt, 'témoin publique absent'); END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : présente dans ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 OAI : la source n''est jamais moissonnable';
  BEGIN
    -- au pire : passée en 'network' (éligible sans le drapeau), demande propre
    -- ouverte, ouverture réseau ouverte
    UPDATE public.libraries SET visibility_level = 'network' WHERE id = c_src;
    INSERT INTO public.oai_opening_requests (kind, library_id, status) VALUES ('library', c_src, 'open');
    INSERT INTO public.oai_opening_requests (kind, external_entity, status) VALUES ('network', 'essai source', 'open');
    v_ok := NOT public.fn_oai_library_is_harvest_eligible(c_src);
    v_ok := v_ok AND NOT EXISTS (SELECT 1 FROM public.fn_oai_harvestable_libraries() WHERE library_id = c_src);
    v_j := public.fn_oai_harvestable_records('src-essai-source');
    v_ok := v_ok AND (v_j ->> 'ok')::boolean = false AND (v_j ->> 'reason') = 'not_open';
    -- témoin : la publique ordinaire est moissonnable par l'ouverture réseau
    v_ok := v_ok AND EXISTS (SELECT 1 FROM public.fn_oai_harvestable_libraries() WHERE library_id = c_pub);
    -- et sans le drapeau, la même demande propre l'ouvrirait (c'est bien le drapeau qui ferme)
    UPDATE public.libraries SET catalog_public = false WHERE id = c_src;
    v_ok := v_ok AND EXISTS (SELECT 1 FROM public.fn_oai_harvestable_libraries() WHERE library_id = c_src);
    UPDATE public.libraries SET catalog_public = true, visibility_level = 'private' WHERE id = c_src;
    DELETE FROM public.oai_opening_requests WHERE library_id = c_src OR external_entity = 'essai source';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_j::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 connecté·e : la liste de session montre la notice, sans adhésion comme membre du réseau';
  BEGIN
    v_txt := NULL;
    FOR r IN SELECT * FROM (VALUES ('sans', c_sans), ('membre', c_membre)) x(nom, uid) LOOP
      PERFORM set_config('request.jwt.claims', json_build_object('sub', r.uid, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      SELECT count(*) INTO v_n FROM api.catalog_list_session_v1 WHERE book_id IN (v_b_src, v_b_pdf);
      IF v_n <> 2 THEN v_txt := concat_ws(',', v_txt, r.nom || ' voit ' || v_n || '/2'); END IF;
      SELECT count(*) INTO v_n FROM api.catalog_list_session_v1 WHERE book_id = v_b_priv;
      IF v_n <> 0 THEN v_txt := concat_ws(',', v_txt, r.nom || ' voit la privée'); END IF;
      SELECT count(*) INTO v_n FROM public.book_digital_resources WHERE id = v_r_pub;
      IF v_n <> 1 THEN v_txt := concat_ws(',', v_txt, r.nom || ' sans la ressource publique'); END IF;
      EXECUTE 'RESET ROLE';
    END LOOP;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 la garde : la coordination de la source ne change pas catalog_public, l''administration du réseau le peut';
  BEGIN
    v_txt := NULL;
    -- coordination : UPDATE de sa propre ligne permis par libraries_staff_update, refusé par la garde
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      UPDATE public.libraries SET catalog_public = false WHERE id = c_src;
      v_txt := 'coordination acceptée';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    -- un autre champ de sa ligne reste modifiable (la garde ne vise que catalog_public)
    BEGIN
      UPDATE public.libraries SET short_name = 'SrcEssai2' WHERE id = c_src;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      IF v_n <> 1 THEN v_txt := concat_ws(',', v_txt, 'short_name non modifié (' || v_n || ')'); END IF;
    EXCEPTION WHEN OTHERS THEN v_txt := concat_ws(',', v_txt, 'short_name refusé : ' || SQLERRM);
    END;
    EXECUTE 'RESET ROLE';
    IF (SELECT catalog_public FROM public.libraries WHERE id = c_src) IS DISTINCT FROM true THEN
      v_txt := concat_ws(',', v_txt, 'drapeau perdu sous la coordination');
    END IF;
    -- administration du réseau (libraries_staff_update la laisse écrire) : la garde la laisse passer
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      UPDATE public.libraries SET catalog_public = false WHERE id = c_src;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      IF v_n <> 1 THEN v_txt := concat_ws(',', v_txt, 'admin : ' || v_n || ' ligne'); END IF;
    EXCEPTION WHEN OTHERS THEN v_txt := concat_ws(',', v_txt, 'admin refusée : ' || SQLERRM);
    END;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
    IF (SELECT catalog_public FROM public.libraries WHERE id = c_src) IS DISTINCT FROM false THEN
      v_txt := concat_ws(',', v_txt, 'admin sans effet');
    END IF;
    UPDATE public.libraries SET catalog_public = true WHERE id = c_src;  -- postgres : permis
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 forme : aides privées ouvertes aux lecteurs, garde fermée, 12 policies, colonne fausse par défaut';
  BEGIN
    v_ok := has_function_privilege('anon', 'private.fn_catalog_library_ids()', 'EXECUTE')
        AND has_function_privilege('authenticated', 'private.fn_catalog_library_ids()', 'EXECUTE')
        AND has_function_privilege('anon', 'private.fn_catalog_library_visible_to_caller(uuid)', 'EXECUTE')
        AND NOT has_function_privilege('anon', 'public.tg_libraries_catalog_public_admin_only()', 'EXECUTE')
        AND NOT has_function_privilege('authenticated', 'public.tg_libraries_catalog_public_admin_only()', 'EXECUTE')
        AND (SELECT bool_and(prosecdef AND proconfig::text LIKE '%search_path=public, pg_temp%') FROM pg_proc
              WHERE oid IN ('private.fn_catalog_library_ids()'::regprocedure, 'private.fn_catalog_library_visible_to_caller(uuid)'::regprocedure))
        AND (SELECT count(*) FROM pg_policy p WHERE pg_get_expr(p.polqual, p.polrelid) ~ 'fn_catalog_library_ids') = 12
        AND (SELECT column_default FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'libraries' AND column_name = 'catalog_public') = 'false'
        AND (SELECT is_nullable FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'libraries' AND column_name = 'catalog_public') = 'NO';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- La requête de supabase/functions/opds/index.ts (/all), telle que PostgREST
  -- la joue sous la clé publique sans jeton : rôle anon, prédicat PUBLIC_PREDICATE,
  -- puis les notices des ressources lues.
  v_t := 'T11 flux OPDS sous anon : source et publique servies, privée jamais, source retirée → hors du flux';
  BEGIN
    v_txt := NULL;
    FOR r IN SELECT * FROM (VALUES
        ('source', NULL::text, NULL::text, true,  ARRAY[v_r_pub, v_r_pubpdf]),
        ('privée en network', 'network', NULL, true, ARRAY[v_r_pub, v_r_pubpdf]),
        ('publique isolée', NULL, 'isolated', true, ARRAY[v_r_pub]),
        ('source retirée', NULL, NULL, false, ARRAY[v_r_pubpdf])
      ) x(cas, vis_priv, mode_pub, src_public, attendu) LOOP
      -- postgres : le décor du cas
      IF r.vis_priv IS NOT NULL THEN UPDATE public.libraries SET visibility_level = r.vis_priv WHERE id = c_priv; END IF;
      -- isolée ⇒ catalogue local (chk_catalog_published_requires_network)
      IF r.mode_pub IS NOT NULL THEN UPDATE public.libraries SET network_mode = r.mode_pub, catalog_mode = 'local_only' WHERE id = c_pub; END IF;
      UPDATE public.libraries SET catalog_public = r.src_public WHERE id = c_src;
      EXECUTE 'SET LOCAL ROLE anon';
      SELECT coalesce(array_agg(id ORDER BY id), '{}') INTO v_ids
        FROM public.book_digital_resources
       WHERE access_scope = 'publico' AND status = 'active' AND is_active AND bibliographic_match_validated
         AND id IN (v_r_pub, v_r_restr, v_r_nonval, v_r_pubpdf, v_r_privpdf);
      IF v_ids IS DISTINCT FROM (SELECT array_agg(x ORDER BY x) FROM unnest(r.attendu) x) THEN
        v_txt := concat_ws(' ; ', v_txt, r.cas || ' : lu ' || v_ids::text);
      END IF;
      -- chaque ressource servie a sa notice lisible (titre de l'entrée)
      SELECT count(*) INTO v_n FROM public.books b
       WHERE b.id IN (SELECT d.book_id FROM public.book_digital_resources d WHERE d.id = ANY (v_ids));
      IF v_n <> cardinality(v_ids) THEN v_txt := concat_ws(' ; ', v_txt, r.cas || ' : notices lues ' || v_n); END IF;
      EXECUTE 'RESET ROLE';
      UPDATE public.libraries SET visibility_level = 'private' WHERE id = c_priv;
      UPDATE public.libraries SET network_mode = 'federated', catalog_mode = 'network_published' WHERE id = c_pub;
    END LOOP;
    UPDATE public.libraries SET catalog_public = true WHERE id = c_src;
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T12 le filtre du catalogue propose la source, pas la privée ordinaire ; libraries_public_v1 inchangée';
  BEGIN
    v_txt := NULL;
    FOR r IN SELECT * FROM (VALUES ('anon', '', 'anon'),
                                   ('sans', json_build_object('sub', c_sans, 'role', 'authenticated')::text, 'authenticated')) x(nom, claims, role) LOOP
      PERFORM set_config('request.jwt.claims', r.claims, true);
      EXECUTE format('SET LOCAL ROLE %I', r.role);
      IF NOT EXISTS (SELECT 1 FROM api.catalog_filter_libraries_v1 WHERE id = c_src) THEN v_txt := concat_ws(',', v_txt, r.nom || ' : source absente du filtre'); END IF;
      IF NOT EXISTS (SELECT 1 FROM api.catalog_filter_libraries_v1 WHERE id = c_pub) THEN v_txt := concat_ws(',', v_txt, r.nom || ' : publique absente du filtre'); END IF;
      IF EXISTS (SELECT 1 FROM api.catalog_filter_libraries_v1 WHERE id = c_priv) THEN v_txt := concat_ws(',', v_txt, r.nom || ' : privée dans le filtre'); END IF;
      IF EXISTS (SELECT 1 FROM api.libraries_public_v1 WHERE id = c_src) THEN v_txt := concat_ws(',', v_txt, r.nom || ' : source dans libraries_public_v1'); END IF;
      EXECUTE 'RESET ROLE';
    END LOOP;
    PERFORM set_config('request.jwt.claims', '', true);
    -- une source retirée quitte le filtre
    UPDATE public.libraries SET catalog_public = false WHERE id = c_src;
    EXECUTE 'SET LOCAL ROLE anon';
    IF EXISTS (SELECT 1 FROM api.catalog_filter_libraries_v1 WHERE id = c_src) THEN v_txt := concat_ws(',', v_txt, 'source retirée encore dans le filtre'); END IF;
    EXECUTE 'RESET ROLE';
    UPDATE public.libraries SET catalog_public = true WHERE id = c_src;
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T13 une bibliothèque de formation sort du filtre, pour tout le monde';
  BEGIN
    v_txt := NULL;
    -- privée, isolée comme blmf-teste, avec son équipe (branche « membre »), et
    -- source active (branche ouverte à tous) : seule is_training la retient.
    -- Slug sans segment « formation » : le normaliseur forcerait is_training,
    -- et le contrôle à vide ci-dessous ne pourrait plus le lever.
    INSERT INTO public.libraries (id, slug, name, short_name, visibility_level, network_mode, catalog_mode, accepts_public_signup, is_active, is_training)
    VALUES (c_form, 'src-essai-atelier', 'Atelier d''essai (test source)', 'AtelierEssai', 'private', 'isolated', 'local_only', false, true, true);
    INSERT INTO public.library_service_state (library_id) VALUES (c_form) ON CONFLICT (library_id) DO NOTHING;
    UPDATE public.libraries SET catalog_public = true WHERE id = c_form;
    INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES (c_sans, c_form, 'coordenador', 'active');
    FOR r IN SELECT * FROM (VALUES ('anon', '', 'anon'),
                                   ('admin', json_build_object('sub', c_admin, 'role', 'authenticated')::text, 'authenticated'),
                                   ('equipe', json_build_object('sub', c_sans, 'role', 'authenticated')::text, 'authenticated')) x(nom, claims, role) LOOP
      PERFORM set_config('request.jwt.claims', r.claims, true);
      EXECUTE format('SET LOCAL ROLE %I', r.role);
      IF EXISTS (SELECT 1 FROM api.catalog_filter_libraries_v1 WHERE id = c_form) THEN v_txt := concat_ws(',', v_txt, r.nom || ' : formation dans le filtre'); END IF;
      IF NOT EXISTS (SELECT 1 FROM api.catalog_filter_libraries_v1 WHERE id = c_pub) THEN v_txt := concat_ws(',', v_txt, r.nom || ' : publique absente du filtre'); END IF;
      EXECUTE 'RESET ROLE';
    END LOOP;
    -- contrôle à vide : sans l'étiquette, l'équipe et anon la verraient
    UPDATE public.libraries SET is_training = false WHERE id = c_form;
    FOR r IN SELECT * FROM (VALUES ('anon', '', 'anon'),
                                   ('equipe', json_build_object('sub', c_sans, 'role', 'authenticated')::text, 'authenticated')) x(nom, claims, role) LOOP
      PERFORM set_config('request.jwt.claims', r.claims, true);
      EXECUTE format('SET LOCAL ROLE %I', r.role);
      IF NOT EXISTS (SELECT 1 FROM api.catalog_filter_libraries_v1 WHERE id = c_form) THEN v_txt := concat_ws(',', v_txt, r.nom || ' : contrôle à vide, l''atelier non étiqueté manque'); END IF;
      EXECUTE 'RESET ROLE';
    END LOOP;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'SOURCE-CATALOGUE-PUBLIC OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'SOURCE-CATALOGUE-PUBLIC ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
