-- =====================================================================
-- AnarBib — Tests d'acceptation : la page Réseau compte les bibliothèques privées
-- Date    : 2026-10-16
-- Ref     : migration 20261016085021_rede_compteurs_des_bibliotheques_privees
--
-- T1 l'administration du réseau, sans adhésion, lit les compteurs d'une
--    bibliothèque privée (documents, exemplaires, lecteur·rices) ; la vue,
--    lue sous le même jeton, rend 0 — c'est le défaut corrigé.
-- T2 une bibliothèque publique garde les mêmes nombres que dans la vue.
-- T3 un compte connecté qui n'administre pas le réseau est refusé (42501),
--    même membre de la bibliothèque privée.
-- T4 droits : anon n'exécute pas, authenticated exécute ; DEFINER, search_path posé.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'REDE-COMPTEURS OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_libPriv uuid; v_libPub uuid;
  v_admin uuid; v_membre uuid;
  v_b1 bigint; v_b2 bigint; v_b3 bigint;
  v_row record; v_vue bigint; v_state text;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-rc-priv', 'Essai RC privée', true, 'private') RETURNING id INTO v_libPriv;
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-rc-pub', 'Essai RC publique', true, 'public') RETURNING id INTO v_libPub;

  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'rc-' || n || '-' || gen_random_uuid() || '@example.invalid', now(), now()
    FROM generate_series(1, 2) n;
  SELECT id INTO v_admin  FROM auth.users WHERE email LIKE 'rc-1-%';
  SELECT id INTO v_membre FROM auth.users WHERE email LIKE 'rc-2-%';
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT u, 'Essai', 'RC' FROM unnest(ARRAY[v_admin, v_membre]) u ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_membre, v_libPriv, 'reader', 'active', true);

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('RC un', 'RC-1', 'livro') RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('RC deux', 'RC-2', 'livro') RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('RC trois', 'RC-3', 'livro') RETURNING id INTO v_b3;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES
    (v_b1, v_libPriv), (v_b2, v_libPriv), (v_b3, v_libPub);

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 privée comptée pour l''administration, vue a 0';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_row FROM public.fn_rede_library_counters() c WHERE c.library_id = v_libPriv;
    SELECT coalesce(max(s.holdings_count), 0) INTO v_vue
      FROM api.library_circulation_stats s WHERE s.library_id = v_libPriv;
    EXECUTE 'RESET ROLE';
    IF v_row.holdings_count = 2 AND v_row.readers_active = 1 AND v_row.exemplars_count = 0 AND v_vue = 0
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fonction='||coalesce(v_row.holdings_count::text,'∅')
           ||' lecteurs='||coalesce(v_row.readers_active::text,'∅')||' vue='||v_vue); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 publique : memes nombres que la vue';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_row FROM public.fn_rede_library_counters() c WHERE c.library_id = v_libPub;
    SELECT s.holdings_count INTO v_vue FROM api.library_circulation_stats s WHERE s.library_id = v_libPub;
    EXECUTE 'RESET ROLE';
    IF v_row.holdings_count = 1 AND v_vue = 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fonction='||coalesce(v_row.holdings_count::text,'∅')||' vue='||coalesce(v_vue::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 membre non administrateur refuse';
  v_state := NULL;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_membre, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      PERFORM * FROM public.fn_rede_library_counters();
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE;
    END;
    EXECUTE 'RESET ROLE';
    IF v_state = '42501'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : etat='||coalesce(v_state,'aucune erreur')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 droits et forme';
  BEGIN
    IF NOT has_function_privilege('anon', 'public.fn_rede_library_counters()', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_rede_library_counters()', 'EXECUTE')
       AND (SELECT prosecdef FROM pg_proc WHERE oid = 'public.fn_rede_library_counters()'::regprocedure)
       AND EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'public.fn_rede_library_counters()'::regprocedure
                     AND proconfig::text LIKE '%search_path=public, pg_temp%')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : privileges ou forme'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'REDE-COMPTEURS OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'REDE-COMPTEURS ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
