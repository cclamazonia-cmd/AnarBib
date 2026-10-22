-- =====================================================================
-- AnarBib — Tests : les comportements anormaux ouvrent un incident.
-- Date    : 2026-10-22
-- Session : Modele de menace
-- Réf     : supabase/migrations/20261022223116_les_comportements_anormaux_ouvrent_un_incident.sql
--
--   T1  le fichier des lecteur·rices écrit une ligne : qui, quelle fonction,
--       quelle bibliothèque, combien de fiches ;
--   T2  la recherche par courriel compte 1 si elle trouve, 0 sinon — les deux
--       sont des appels ;
--   T3  les autres adhésions d'une personne comptent une fiche, zéro hors de la
--       bibliothèque ;
--   T4  un appel refusé ne laisse rien (il n'a rien rendu) ;
--   T5  le journal n'a aucune colonne pour la personne consultée ;
--   T6  ni anon ni authenticated ne lisent, n'écrivent, ne sondent ni ne purgent ;
--   T7  la sonde des consultations voit un compte en rafale, pas sous les seuils
--       par défaut ;
--   T8  la sonde des freins voit des blocages en série, sans rendre de clé ;
--       une frappe sortie de la fenêtre ne compte plus ;
--   T9  fenêtre ou seuil hors bornes : 22023 ;
--   T10 la purge retire ce qui a plus de 12 mois, rien d'autre ;
--   T11 les trois fonctions nominatives ne sont plus en lecture seule ;
--   T12 la CHECK des incidents admet abus et consultations.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'ALERTES-COMPORTEMENTS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf   text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_lib   uuid; v_autre uuid;
  v_coord uuid := gen_random_uuid(); v_admin uuid := gen_random_uuid();
  v_l1    uuid := gen_random_uuid(); v_l2 uuid := gen_random_uuid(); v_etr uuid := gen_random_uuid();
  v_n int; v_avant int; v_rows int; v_bilan jsonb; v_state text; v_r record;
BEGIN
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-alertes-' || v_suf, 'Essai alertes', true, 'public') RETURNING id INTO v_lib;
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-alertes-b-' || v_suf, 'Essai alertes B', true, 'public') RETURNING id INTO v_autre;

  INSERT INTO auth.users (id, email) VALUES
    (v_coord, 'al-coord-' || v_suf || '@example.invalid'),
    (v_admin, 'al-admin-' || v_suf || '@example.invalid'),
    (v_l1,    'al-l1-'    || v_suf || '@example.invalid'),
    (v_l2,    'al-l2-'    || v_suf || '@example.invalid'),
    (v_etr,   'al-etr-'   || v_suf || '@example.invalid');
  INSERT INTO public.profiles (id, email, first_name, last_name)
  SELECT u.id, u.email, 'Essai', 'Alertes' FROM auth.users u WHERE u.id IN (v_coord, v_admin, v_l1, v_l2, v_etr)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status) VALUES
    (v_coord, v_lib, 'coordenador', 'active'),
    (v_l1, v_lib, 'reader', 'active'),
    (v_l2, v_lib, 'reader', 'active'),
    (v_etr, v_autre, 'reader', 'active');
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  -- ── T1 ─────────────────────────────────────────────────────────────────
  v_t := 'T1 le fichier des lecteur·rices écrit qui, quoi, où, combien';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  SELECT count(*) INTO v_rows FROM api.get_reader_roster(v_lib);
  RESET ROLE;
  SELECT count(*) INTO v_n FROM private.consultations_nominatives
   WHERE par = v_coord AND fonction = 'api.get_reader_roster' AND library_id = v_lib AND nb = 2;
  IF v_rows = 2 AND v_n = 1 THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lignes='||v_rows||' journal='||v_n); END IF;

  -- ── T2 ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la recherche par courriel compte 1 trouvée, 0 sinon';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  PERFORM public.fn_network_admin_find_user_by_email('al-l1-' || v_suf || '@example.invalid');
  PERFORM public.fn_network_admin_find_user_by_email('personne-' || v_suf || '@example.invalid');
  RESET ROLE;
  SELECT count(*) FILTER (WHERE nb = 1) * 10 + count(*) FILTER (WHERE nb = 0) INTO v_n
    FROM private.consultations_nominatives
   WHERE par = v_admin AND fonction = 'fn_network_admin_find_user_by_email' AND library_id IS NULL;
  IF v_n = 11 THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : code '||v_n); END IF;

  -- ── T3 ─────────────────────────────────────────────────────────────────
  v_t := 'T3 les autres adhésions : une fiche, zéro hors de la bibliothèque';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  PERFORM * FROM public.fn_painel_reader_other_memberships(v_l1, v_lib);
  PERFORM * FROM public.fn_painel_reader_other_memberships(v_etr, v_lib);
  RESET ROLE;
  SELECT count(*) FILTER (WHERE nb = 1) * 10 + count(*) FILTER (WHERE nb = 0) INTO v_n
    FROM private.consultations_nominatives
   WHERE par = v_coord AND fonction = 'fn_painel_reader_other_memberships' AND library_id = v_lib;
  IF v_n = 11 THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : code '||v_n); END IF;

  -- ── T4 ─────────────────────────────────────────────────────────────────
  v_t := 'T4 un appel refusé ne laisse rien';
  SELECT count(*) INTO v_avant FROM private.consultations_nominatives;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_l1, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  v_state := NULL;
  BEGIN
    PERFORM * FROM api.get_reader_roster(v_lib);
  EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; END;
  RESET ROLE;
  SELECT count(*) INTO v_n FROM private.consultations_nominatives;
  IF v_state IS NOT NULL AND v_n = v_avant THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : état='||coalesce(v_state,'aucun')||' '||v_avant||'→'||v_n); END IF;

  -- ── T5 ─────────────────────────────────────────────────────────────────
  v_t := 'T5 aucune colonne pour la personne consultée';
  SELECT string_agg(column_name::text, ',' ORDER BY ordinal_position) INTO v_state
    FROM information_schema.columns
   WHERE table_schema = 'private' AND table_name = 'consultations_nominatives';
  IF v_state = 'id,le,par,fonction,library_id,nb' THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_state,'table absente')); END IF;

  -- ── T6 ─────────────────────────────────────────────────────────────────
  v_t := 'T6 ni anon ni authenticated : lecture, écriture, sondes, purge';
  v_n := 0;
  FOR v_r IN SELECT r FROM unnest(ARRAY['anon', 'authenticated']) r LOOP
    IF has_table_privilege(v_r.r, 'private.consultations_nominatives', 'SELECT')
       OR has_table_privilege(v_r.r, 'private.consultations_nominatives', 'INSERT')
       OR has_table_privilege(v_r.r, 'private.consultations_nominatives', 'DELETE')
       OR has_function_privilege(v_r.r, 'private.fn_noter_consultation(text, uuid, integer)', 'EXECUTE')
       OR has_function_privilege(v_r.r, 'public.fn_healthcheck_consultations(integer, integer, integer, integer)', 'EXECUTE')
       OR has_function_privilege(v_r.r, 'public.fn_healthcheck_abus(integer, integer, integer)', 'EXECUTE')
       OR has_function_privilege(v_r.r, 'public.fn_consultations_purger()', 'EXECUTE') THEN
      v_n := v_n + 1;
    END IF;
  END LOOP;
  IF v_n = 0
     AND has_function_privilege('service_role', 'public.fn_healthcheck_consultations(integer, integer, integer, integer)', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.fn_healthcheck_abus(integer, integer, integer)', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.fn_consultations_purger()', 'EXECUTE')
     AND has_table_privilege('service_role', 'private.consultations_nominatives', 'SELECT') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' rôle(s) ouvert(s) ou service_role privé'); END IF;

  -- ── T7 ─────────────────────────────────────────────────────────────────
  v_t := 'T7 la sonde des consultations voit une rafale, pas sous les seuils par défaut';
  INSERT INTO private.consultations_nominatives (par, fonction, library_id, nb)
  SELECT v_admin, 'fn_network_admin_find_user_by_email', NULL, 0 FROM generate_series(1, 4);
  v_bilan := public.fn_healthcheck_consultations(60, 5, 1000, 4);
  IF (v_bilan->>'ok')::boolean = false
     AND v_bilan->'appels_en_rafale' @> jsonb_build_array(jsonb_build_object('compte', v_admin::text, 'appels', 6))
     AND NOT (public.fn_healthcheck_consultations()->'appels_en_rafale' @> jsonb_build_array(jsonb_build_object('compte', v_admin::text)))
     AND position(v_l1::text IN v_bilan::text) = 0 THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_bilan::text); END IF;

  -- ── T8 ─────────────────────────────────────────────────────────────────
  v_t := 'T8 la sonde des freins : blocages en série, sans clé, fenêtre respectée';
  INSERT INTO public.auth_rate_limits (kind, key, failure_count, first_failure_at, last_failure_at, blocked_until)
  SELECT 'register_dest', repeat(c, 64), 6, now() - interval '5 minutes', now(), now() + interval '1 hour'
    FROM unnest(ARRAY['7', '8', '9']) c;
  INSERT INTO public.auth_rate_limits (kind, key, failure_count, first_failure_at, last_failure_at, blocked_until)
  VALUES ('register_dest', repeat('6', 64), 6, now() - interval '2 hours', now() - interval '1 hour', now() + interval '1 hour');
  v_bilan := public.fn_healthcheck_abus();
  IF (v_bilan->>'ok')::boolean = false
     AND v_bilan->'blocages_en_serie' @> jsonb_build_array(jsonb_build_object('genre', 'register_dest', 'cles_bloquees', 3))
     AND public.fn_healthcheck_abus(15, 3, 100)->'freins_en_pic' @> jsonb_build_array(jsonb_build_object('genre', 'register_dest', 'cles_frappees', 3))
     AND position(repeat('7', 64) IN v_bilan::text) = 0 THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_bilan::text); END IF;

  -- ── T9 ─────────────────────────────────────────────────────────────────
  v_t := 'T9 fenêtre ou seuil hors bornes : 22023';
  v_n := 0;
  BEGIN PERFORM public.fn_healthcheck_abus(0); EXCEPTION WHEN SQLSTATE '22023' THEN v_n := v_n + 1; END;
  BEGIN PERFORM public.fn_healthcheck_consultations(60, 0); EXCEPTION WHEN SQLSTATE '22023' THEN v_n := v_n + 1; END;
  IF v_n = 2 THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/2'); END IF;

  -- ── T10 ────────────────────────────────────────────────────────────────
  v_t := 'T10 la purge retire au-delà de 12 mois, rien d''autre';
  INSERT INTO private.consultations_nominatives (le, par, fonction, library_id, nb)
  VALUES (now() - interval '13 months', v_coord, 'api.get_reader_roster', v_lib, 2);
  SELECT count(*) INTO v_avant FROM private.consultations_nominatives WHERE le >= now() - interval '12 months';
  v_n := public.fn_consultations_purger();
  SELECT count(*) INTO v_rows FROM private.consultations_nominatives;
  IF v_n >= 1 AND v_rows = v_avant
     AND NOT EXISTS (SELECT 1 FROM private.consultations_nominatives WHERE le < now() - interval '12 months') THEN
    v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : purgées='||v_n||' restent='||v_rows||'/'||v_avant); END IF;

  -- ── T11 ────────────────────────────────────────────────────────────────
  v_t := 'T11 les trois fonctions nominatives ne sont plus en lecture seule';
  SELECT count(*) INTO v_n FROM pg_proc
   WHERE oid IN ('api.get_reader_roster(uuid)'::regprocedure,
                 'public.fn_network_admin_find_user_by_email(text)'::regprocedure,
                 'public.fn_painel_reader_other_memberships(uuid, uuid)'::regprocedure)
     AND provolatile = 'v' AND prosecdef;
  IF v_n = 3 THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/3'); END IF;

  -- ── T12 ────────────────────────────────────────────────────────────────
  v_t := 'T12 la CHECK des incidents admet abus et consultations';
  v_state := NULL;
  BEGIN
    INSERT INTO public.service_health_incidents (kind, reason) VALUES ('abus', 'essai'), ('consultations', 'essai');
  EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE || ' ' || SQLERRM; END;
  IF v_state IS NULL THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_state); END IF;

  PERFORM set_config('request.jwt.claims', '', true);
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ALERTES-COMPORTEMENTS OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'ALERTES-COMPORTEMENTS ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
