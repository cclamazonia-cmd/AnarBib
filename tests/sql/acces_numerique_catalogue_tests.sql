-- =====================================================================
-- AnarBib — Tests d'acceptation : le catalogue dit ce qui se lit en ligne
-- Date    : 2026-10-04
-- Ref     : migration 20261004215035_le_catalogue_dit_ce_qui_se_lit_en_ligne
-- Session : Retours du catalogage & numérique
--
-- T1 PDF public validé : usage « lecture » pour l'anonyme ; non validé : rien.
-- T2 PDF réservé : signalé à tous, lisible par un membre de la bibliothèque
--    détentrice, pas par l'anonyme ni par un compte d'une autre bibliothèque ;
--    la bibliothèque détentrice est nommée.
-- T3 l'administration du réseau lit le réservé sans adhésion (décision du
--    04/10), et get_accessible_digital_asset_by_id_v2 l'accorde aussi.
-- T4 livre détenu par une bibliothèque privée : rien pour l'anonyme.
-- T5 un livre sans ressource ne sort pas ; la liste est bornée à 500.
-- T6 droits : anon et authenticated exécutent la fonction.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'ACCES-NUMERIQUE-CATALOGUE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_libPub uuid; v_libAutre uuid; v_libPriv uuid;
  v_membre uuid; v_etranger uuid; v_admin uuid;
  v_bPub bigint; v_bNonValide bigint; v_bRes bigint; v_bPriv bigint; v_bVide bigint;
  v_rRes bigint;
  v_row record; v_n int; v_txt text; v_ok boolean;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-an-pub', 'Essai AN publique', true, 'public') RETURNING id INTO v_libPub;
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-an-autre', 'Essai AN autre', true, 'public') RETURNING id INTO v_libAutre;
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-an-priv', 'Essai AN privée', true, 'private') RETURNING id INTO v_libPriv;

  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'an-' || n || '-' || gen_random_uuid() || '@example.invalid', now(), now()
    FROM generate_series(1, 3) n;
  SELECT id INTO v_membre   FROM auth.users WHERE email LIKE 'an-1-%';
  SELECT id INTO v_etranger FROM auth.users WHERE email LIKE 'an-2-%';
  SELECT id INTO v_admin    FROM auth.users WHERE email LIKE 'an-3-%';
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT u, 'Essai', 'AN' FROM unnest(ARRAY[v_membre, v_etranger, v_admin]) u ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_membre, v_libPub, 'reader', 'active', true),
    (v_etranger, v_libAutre, 'reader', 'active', true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('AN public', 'AN-1', 'livro') RETURNING id INTO v_bPub;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('AN non valide', 'AN-2', 'livro') RETURNING id INTO v_bNonValide;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('AN reserve', 'AN-3', 'livro') RETURNING id INTO v_bRes;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('AN prive', 'AN-4', 'livro') RETURNING id INTO v_bPriv;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('AN sans ressource', 'AN-5', 'livro') RETURNING id INTO v_bVide;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES
    (v_bPub, v_libPub), (v_bNonValide, v_libPub), (v_bRes, v_libPub), (v_bPriv, v_libPriv), (v_bVide, v_libPub);

  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, bibliographic_match_validated, source_url)
  VALUES (v_bPub, 'pdf_publico', 'leitura_online', 'publico', 'active', true, true, 'https://exemple.invalid/a.pdf'),
         (v_bNonValide, 'pdf_publico', 'leitura_online', 'publico', 'active', true, false, 'https://exemple.invalid/b.pdf'),
         (v_bPriv, 'pdf_publico', 'leitura_online', 'publico', 'active', true, true, 'https://exemple.invalid/d.pdf');
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active, source_url)
  VALUES (v_bRes, 'pdf_restrito', 'leitura_online', 'conta_ativa', 'active', true, 'https://exemple.invalid/c.pdf')
  RETURNING id INTO v_rRes;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 public valide lu par l''anonyme, non valide tait';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT * INTO v_row FROM public.catalog_digital_access_v1(ARRAY[v_bPub]) LIMIT 1;
    SELECT count(*) INTO v_n FROM public.catalog_digital_access_v1(ARRAY[v_bNonValide]);
    EXECUTE 'RESET ROLE';
    IF v_row.public_usages = ARRAY['leitura_online'] AND NOT v_row.has_restricted AND v_n = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : usages='||coalesce(v_row.public_usages::text,'∅')||' non_valide='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 reserve : signale a tous, lisible par la detentrice seule';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', '', true);
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT * INTO v_row FROM public.catalog_digital_access_v1(ARRAY[v_bRes]) LIMIT 1;
    EXECUTE 'RESET ROLE';
    IF NOT coalesce(v_row.has_restricted, false) OR v_row.can_read_restricted THEN v_txt := v_txt || 'anon '; END IF;
    IF NOT coalesce(v_row.restricted_libraries @> '[{"slug":"essai-an-pub"}]'::jsonb, false) THEN v_txt := v_txt || 'detentrice-non-nommee '; END IF;

    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_membre, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_row FROM public.catalog_digital_access_v1(ARRAY[v_bRes]) LIMIT 1;
    EXECUTE 'RESET ROLE';
    IF NOT coalesce(v_row.can_read_restricted, false) THEN v_txt := v_txt || 'membre-refuse '; END IF;

    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_etranger, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_row FROM public.catalog_digital_access_v1(ARRAY[v_bRes]) LIMIT 1;
    EXECUTE 'RESET ROLE';
    IF coalesce(v_row.can_read_restricted, true) OR NOT v_row.has_restricted THEN v_txt := v_txt || 'etranger '; END IF;
    IF v_txt = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 l''administration du reseau lit le reserve';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_row FROM public.catalog_digital_access_v1(ARRAY[v_bRes]) LIMIT 1;
    SELECT coalesce(bool_or(a.access_granted), false) INTO v_ok FROM public.get_accessible_digital_asset_by_id_v2(v_rRes) a;
    EXECUTE 'RESET ROLE';
    IF coalesce(v_row.can_read_restricted, false) AND v_ok
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : catalogue='||coalesce(v_row.can_read_restricted::text,'∅')||' lecture='||v_ok); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 bibliotheque privee : rien pour l''anonyme';
  BEGIN
    PERFORM set_config('request.jwt.claims', '', true);
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT count(*) INTO v_n FROM public.catalog_digital_access_v1(ARRAY[v_bPriv]);
    EXECUTE 'RESET ROLE';
    IF v_n = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 sans ressource absent, liste bornee';
  BEGIN
    SELECT count(*) INTO v_n FROM public.catalog_digital_access_v1(ARRAY[v_bVide, v_bPub, v_bPub, NULL]);
    v_ok := (SELECT count(*) FROM public.catalog_digital_access_v1(
               array_cat(array_fill(0::bigint, ARRAY[500]), ARRAY[v_bPub]))) = 0;
    IF v_n = 1 AND v_ok
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lignes='||v_n||' borne='||v_ok); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──────────────────────────────────────────────────────────────
  v_t := 'T6 droits';
  BEGIN
    IF has_function_privilege('anon', 'public.catalog_digital_access_v1(bigint[])', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.catalog_digital_access_v1(bigint[])', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : privileges'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ACCES-NUMERIQUE-CATALOGUE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'ACCES-NUMERIQUE-CATALOGUE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
