-- =====================================================================
-- AnarBib — Tests d'acceptation : les ressources communes s'écrivent par
-- l'administration
-- Date    : 2026-10-19
-- Ref     : migration 20261019140631_les_ressources_communes_par_l_administration
-- Session : Modele de menace
--
-- Le stub CI de storage.objects n'a pas de RLS : on éprouve les PRÉDICATS des
-- trois politiques (lus dans pg_policies) en les évaluant sous authenticated,
-- pour un compte quelconque, une équipe et l'administration du réseau.
-- T1 les trois politiques existent et ne contiennent plus la porte
--    « IS DISTINCT FROM 'themes' ».
-- T2 compte quelconque : rien, ni dans themes/ d'une bibliothèque, ni hors
--    de themes/.
-- T3 équipe d'une bibliothèque : son dossier themes/<slug>/ oui, celui d'une
--    autre non, hors de themes/ non.
-- T4 administration du réseau : partout.
--   Bilan OK : 'RESSOURCES-COMMUNES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text; v_txt text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_libA uuid; v_slugA text; v_slugB text;
  v_quelconque uuid := gen_random_uuid(); v_coordA uuid := gen_random_uuid(); v_admin uuid := gen_random_uuid();
  v_u uuid; v_pred text; v_ok boolean;
BEGIN
  v_slugA := 'rc-a-' || v_suf; v_slugB := 'rc-b-' || v_suf;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES (v_slugA, 'Ressources A (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES (v_slugB, 'Ressources B (essai)', 'federated', 'full_sigb', true, 'public', false);
  FOREACH v_u IN ARRAY ARRAY[v_quelconque, v_coordA, v_admin] LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, created_at, updated_at)
    VALUES ('00000000-0000-0000-0000-000000000000', v_u, 'authenticated', 'authenticated', 'rc-' || v_u || '@example.invalid', now(), now());
    INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_u, 'Essai', 'RC') ON CONFLICT (id) DO NOTHING;
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_coordA, v_libA, 'coordenador', 'active', true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  SELECT with_check INTO v_pred FROM pg_policies
   WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'ui assets: scoped insert';

  -- évalue le prédicat d'INSERT pour un chemin, sous l'identité donnée
  EXECUTE $f$CREATE FUNCTION pg_temp.rc_peut(p_pred text, p_sub uuid, p_nom text) RETURNS boolean LANGUAGE plpgsql AS $b$
    DECLARE r boolean;
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_sub, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      EXECUTE format('SELECT (%s) FROM (SELECT %L::text AS bucket_id, %L::text AS name) AS objects', p_pred, 'library-ui-assets', p_nom) INTO r;
      EXECUTE 'RESET ROLE';
      RETURN coalesce(r, false);
    EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; RAISE;
    END $b$ $f$;

  v_t := 'T1 politiques posees, porte hors themes refermee';
  BEGIN
    IF v_pred IS NULL THEN RAISE EXCEPTION 'politique d''insertion absente'; END IF;
    IF (SELECT count(*) FROM pg_policies WHERE schemaname = 'storage' AND policyname LIKE 'ui assets: scoped %'
          AND coalesce(with_check, qual) ILIKE '%IS DISTINCT FROM%') > 0 THEN
      RAISE EXCEPTION 'la porte hors themes subsiste';
    END IF;
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := 'T2 compte quelconque : rien';
  BEGIN
    v_txt := '';
    IF pg_temp.rc_peut(v_pred, v_quelconque, 'manuals/x.pdf') THEN v_txt := v_txt || 'manuals '; END IF;
    IF pg_temp.rc_peut(v_pred, v_quelconque, 'piege.html') THEN v_txt := v_txt || 'racine '; END IF;
    IF pg_temp.rc_peut(v_pred, v_quelconque, 'themes/' || v_slugA || '/logo.png') THEN v_txt := v_txt || 'theme-A '; END IF;
    IF v_txt = '' THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := 'T3 equipe : son dossier de theme seulement';
  BEGIN
    v_txt := '';
    IF NOT pg_temp.rc_peut(v_pred, v_coordA, 'themes/' || v_slugA || '/logo.png') THEN v_txt := v_txt || 'son-theme-refuse '; END IF;
    IF pg_temp.rc_peut(v_pred, v_coordA, 'themes/' || v_slugB || '/logo.png') THEN v_txt := v_txt || 'theme-B '; END IF;
    IF pg_temp.rc_peut(v_pred, v_coordA, 'manuals/x.pdf') THEN v_txt := v_txt || 'manuals '; END IF;
    IF v_txt = '' THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := 'T4 administration du reseau : partout';
  BEGIN
    v_txt := '';
    IF NOT pg_temp.rc_peut(v_pred, v_admin, 'manuals/x.pdf') THEN v_txt := v_txt || 'manuals '; END IF;
    IF NOT pg_temp.rc_peut(v_pred, v_admin, 'themes/' || v_slugB || '/logo.png') THEN v_txt := v_txt || 'theme-B '; END IF;
    IF v_txt = '' THEN v_passed := v_passed + 1; ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'RESSOURCES-COMMUNES OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'RESSOURCES-COMMUNES ECHEC : %/% — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
