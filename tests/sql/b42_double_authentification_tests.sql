-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — B42, lot 2 (13/10/2026) : la double authentification s'exige côté
-- serveur (migration 20261013171710, livrée ÉTEINTE : mode 'off', fonction
-- d'avant-requête non branchée).
--   T1  objets et droits : mode 'off' à la livraison ; fn_avant_requete
--       INVOKER, exécutable par anon/authenticated ; fn_aal2_exige_pour_moi
--       DEFINER, fermée à anon ; les trois RPC api fermées à anon ; les deux
--       tables fermées à authenticated ;
--   T2  mode 'off' : une coordination aal1 AVEC facteur passe ;
--   T3  mode 'facteurs' : lecteur à facteur vérifié en aal1 → 403
--       AAL2_REQUIRED ; le même en aal2 passe ; facteur inachevé seul : passe ;
--       coordination sans facteur : passe ;
--   T4  mode 'equipes' : coordination, bibliothécaire, administration du
--       réseau sans facteur en aal1 → refus ; adhésion non active, lecteur
--       sans facteur, anon, service_role, absence de jeton → passent ;
--   T5  liste blanche : rpc/fn_mon_etat_double_facteur passe (avec ou sans
--       « / »), une autre RPC est refusée ;
--   T6  échec ouvert : un jeton au sub illisible laisse passer ;
--   T7  fn_avant_requete jouée SOUS les rôles anon et authenticated (droits
--       réels, pas ceux de postgres) ;
--   T8  api.fn_mon_etat_double_facteur : coordination sans facteur en
--       'equipes' → exige, equipe, pas de facteur ; lecteur → rien d'exigé ;
--   T9  api.fn_admin_double_facteur_comptes : refus hors administration ;
--       les comptes d'équipe ET le lecteur à facteur vérifié (appareil perdu) ;
--       ni facteur inachevé seul, ni adhésion inactive ;
--   T10 api.fn_admin_retirer_double_facteur : refus hors administration ;
--       administration en aal1 → aal2_required ; motif trop court ; retrait
--       réel : facteurs et sessions supprimés, une ligne de journal.
-- Fixtures : une bibliothèque et cinq comptes créés ici. Tout se fait sous
-- postgres avec un JWT simulé (stub auth), sauf T7. La suite lève toujours
-- (OK ou ECHEC) : rien ne reste, le mode revient à 'off'.
-- Mutants éprouvés le 13/10 : refus jamais levé (« IF false AND v_bloque »)
-- → 16/22, T3, T4, T5, T7 rougissent ; sans l'échec ouvert (RAISE à la place
-- du WARNING) → 21/22, T6 rougit.
--   Bilan OK : 'B42 OK : N/N tests passés'
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_lib uuid;
  v_coord uuid := gen_random_uuid();   -- coordination, sans facteur
  v_biblio uuid := gen_random_uuid();  -- bibliothécaire, sans facteur
  v_admin uuid := gen_random_uuid();   -- administration du réseau, avec facteur
  v_lect uuid := gen_random_uuid();    -- lecteur, facteur vérifié
  v_lect2 uuid := gen_random_uuid();   -- lecteur, facteur inachevé seul
  v_ancien uuid := gen_random_uuid();  -- ancienne coordination (adhésion inactive)
  v_u uuid; v_txt text; v_state text; v_json jsonb; v_n int; v_b boolean;
  v_rec record;
BEGIN
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('b42-' || v_suf, 'B42 (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_lib;
  FOREACH v_u IN ARRAY ARRAY[v_coord, v_biblio, v_admin, v_lect, v_lect2, v_ancien] LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', v_u, 'authenticated', 'authenticated', 'b42-' || v_u || '@anarbib.local', now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}');
    INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
    VALUES (v_u, 'b42-' || v_u || '@anarbib.local', 'B42', left(v_u::text, 8), 'fr');
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_coord, v_lib, 'coordenador', 'active', true),
    (v_biblio, v_lib, 'librarian', 'active', true),
    (v_lect, v_lib, 'reader', 'active', true),
    (v_lect2, v_lib, 'reader', 'active', true),
    (v_ancien, v_lib, 'coordenador', 'inactive', false);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at) VALUES
    (gen_random_uuid(), v_admin, 'Téléphone', 'totp', 'verified', now(), now()),
    (gen_random_uuid(), v_lect, 'Téléphone', 'totp', 'verified', now(), now()),
    (gen_random_uuid(), v_lect2, 'Appareil 1', 'totp', 'unverified', now(), now());
  INSERT INTO auth.sessions (id, user_id, created_at, updated_at, aal) VALUES
    (gen_random_uuid(), v_lect, now(), now(), 'aal2'),
    (gen_random_uuid(), v_lect, now(), now(), 'aal1');

  -- ───────────────────────────────────────────────────────
  v_t := 'T1 objets et droits';
  BEGIN
    SELECT mode INTO v_txt FROM private.double_facteur_reglage WHERE id;
    IF v_txt IS DISTINCT FROM 'off' THEN RAISE EXCEPTION 'mode livré %', v_txt; END IF;
    SELECT prosecdef INTO v_b FROM pg_proc WHERE oid = 'private.fn_avant_requete()'::regprocedure;
    IF v_b THEN RAISE EXCEPTION 'fn_avant_requete devrait être INVOKER'; END IF;
    IF NOT has_function_privilege('anon', 'private.fn_avant_requete()', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'private.fn_avant_requete()', 'EXECUTE')
       OR NOT has_function_privilege('service_role', 'private.fn_avant_requete()', 'EXECUTE') THEN
      RAISE EXCEPTION 'fn_avant_requete doit être exécutable par anon, authenticated, service_role';
    END IF;
    SELECT prosecdef INTO v_b FROM pg_proc WHERE oid = 'private.fn_aal2_exige_pour_moi()'::regprocedure;
    IF NOT v_b THEN RAISE EXCEPTION 'fn_aal2_exige_pour_moi devrait être DEFINER'; END IF;
    IF has_function_privilege('anon', 'private.fn_aal2_exige_pour_moi()', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'private.fn_aal2_exige_pour_moi()', 'EXECUTE') THEN
      RAISE EXCEPTION 'fn_aal2_exige_pour_moi : fermée à anon, ouverte à authenticated';
    END IF;
    IF has_function_privilege('anon', 'api.fn_mon_etat_double_facteur()', 'EXECUTE')
       OR has_function_privilege('anon', 'api.fn_admin_double_facteur_comptes()', 'EXECUTE')
       OR has_function_privilege('anon', 'api.fn_admin_retirer_double_facteur(uuid, text)', 'EXECUTE') THEN
      RAISE EXCEPTION 'une RPC api B42 est ouverte à anon';
    END IF;
    IF NOT has_function_privilege('authenticated', 'api.fn_admin_retirer_double_facteur(uuid, text)', 'EXECUTE') THEN
      RAISE EXCEPTION 'fn_admin_retirer_double_facteur fermée à authenticated';
    END IF;
    IF has_table_privilege('authenticated', 'private.double_facteur_reglage', 'SELECT')
       OR has_table_privilege('authenticated', 'private.double_facteur_reglage', 'UPDATE')
       OR has_table_privilege('authenticated', 'private.double_facteur_journal', 'SELECT')
       OR has_table_privilege('anon', 'private.double_facteur_journal', 'INSERT') THEN
      RAISE EXCEPTION 'une table B42 est ouverte';
    END IF;
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  -- Jeu de cas : (n° de test, mode, sub, role, aal, chemin, attendu 'passe'|'refus')
  FOR v_rec IN
    SELECT * FROM (VALUES
      ('T2 off, admin à facteur en aal1',              'off',      v_admin::text,  'authenticated', 'aal1', 'rpc/x',                          'passe'),
      ('T3 facteurs, lecteur à facteur en aal1',       'facteurs', v_lect::text,   'authenticated', 'aal1', 'books',                          'refus'),
      ('T3 facteurs, lecteur à facteur en aal2',       'facteurs', v_lect::text,   'authenticated', 'aal2', 'books',                          'passe'),
      ('T3 facteurs, facteur inachevé seul',           'facteurs', v_lect2::text,  'authenticated', 'aal1', 'books',                          'passe'),
      ('T3 facteurs, coordination sans facteur',       'facteurs', v_coord::text,  'authenticated', 'aal1', 'books',                          'passe'),
      ('T4 equipes, coordination sans facteur',        'equipes',  v_coord::text,  'authenticated', 'aal1', 'rpc/fn_v2_lister',               'refus'),
      ('T4 equipes, bibliothécaire sans facteur',      'equipes',  v_biblio::text, 'authenticated', 'aal1', 'emprestimos_v2',                 'refus'),
      ('T4 equipes, administration en aal1',           'equipes',  v_admin::text,  'authenticated', 'aal1', 'rpc/x',                          'refus'),
      ('T4 equipes, administration en aal2',           'equipes',  v_admin::text,  'authenticated', 'aal2', 'rpc/x',                          'passe'),
      ('T4 equipes, adhésion non active',              'equipes',  v_ancien::text, 'authenticated', 'aal1', 'books',                          'passe'),
      ('T4 equipes, lecteur sans facteur',             'equipes',  v_lect2::text,  'authenticated', 'aal1', 'books',                          'passe'),
      ('T4 equipes, anon',                             'equipes',  NULL,           'anon',          NULL,   'books',                          'passe'),
      ('T4 equipes, service_role',                     'equipes',  NULL,           'service_role',  NULL,   'books',                          'passe'),
      ('T5 liste blanche, sans /',                     'equipes',  v_coord::text,  'authenticated', 'aal1', 'rpc/fn_mon_etat_double_facteur',  'passe'),
      ('T5 liste blanche, avec /',                     'equipes',  v_coord::text,  'authenticated', 'aal1', '/rpc/fn_mon_etat_double_facteur', 'passe'),
      ('T5 hors liste blanche',                        'equipes',  v_coord::text,  'authenticated', 'aal1', '/rpc/fn_admin_double_facteur_comptes', 'refus'),
      ('T6 échec ouvert : sub illisible',              'equipes',  'pas-un-uuid',  'authenticated', 'aal1', 'books',                          'passe')
    ) AS c(t, mode, sub, role, aal, chemin, attendu)
  LOOP
    v_t := v_rec.t;
    BEGIN
      UPDATE private.double_facteur_reglage SET mode = v_rec.mode WHERE id;
      PERFORM set_config('request.jwt.claims',
        jsonb_strip_nulls(jsonb_build_object('sub', v_rec.sub, 'role', v_rec.role, 'aal', v_rec.aal))::text, true);
      PERFORM set_config('request.path', v_rec.chemin, true);
      BEGIN
        PERFORM private.fn_avant_requete(); v_state := 'passe'; v_txt := NULL;
      EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; v_txt := SQLERRM; END;
      PERFORM set_config('request.jwt.claims', '', true);
      PERFORM set_config('request.path', '', true);
      IF (v_rec.attendu = 'passe' AND v_state = 'passe')
         OR (v_rec.attendu = 'refus' AND v_state = 'PGRST' AND (v_txt::jsonb ->> 'code') = 'AAL2_REQUIRED') THEN
        v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1; v_failures := v_failures || (v_t || format(' : attendu %s, obtenu %s %s', v_rec.attendu, v_state, v_txt));
      END IF;
    EXCEPTION WHEN OTHERS THEN
      PERFORM set_config('request.jwt.claims', '', true); PERFORM set_config('request.path', '', true);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
    END;
  END LOOP;

  -- ───────────────────────────────────────────────────────
  v_t := 'T7 fn_avant_requete jouée sous les rôles réels (anon, authenticated refusé, authenticated aal2)';
  BEGIN
    UPDATE private.double_facteur_reglage SET mode = 'equipes' WHERE id;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('role', 'anon')::text, true);
    SET LOCAL ROLE anon;
    PERFORM private.fn_avant_requete();
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_coord, 'role', 'authenticated', 'aal', 'aal1')::text, true);
    PERFORM set_config('request.path', 'books', true);
    SET LOCAL ROLE authenticated;
    BEGIN
      PERFORM private.fn_avant_requete(); v_state := 'passe';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; v_txt := SQLERRM; END;
    RESET ROLE;
    IF v_state <> 'PGRST' THEN RAISE EXCEPTION 'coordination aal1 sous authenticated : % %', v_state, v_txt; END IF;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    SET LOCAL ROLE authenticated;
    PERFORM private.fn_avant_requete();
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true); PERFORM set_config('request.path', '', true);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE; PERFORM set_config('request.jwt.claims', '', true); PERFORM set_config('request.path', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ───────────────────────────────────────────────────────
  v_t := 'T8 api.fn_mon_etat_double_facteur';
  BEGIN
    UPDATE private.double_facteur_reglage SET mode = 'equipes' WHERE id;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_coord, 'role', 'authenticated', 'aal', 'aal1')::text, true);
    v_json := api.fn_mon_etat_double_facteur();
    IF NOT (v_json ->> 'mode' = 'equipes' AND (v_json ->> 'exige')::boolean AND (v_json ->> 'equipe')::boolean
            AND NOT (v_json ->> 'a_facteur')::boolean AND v_json ->> 'aal' = 'aal1') THEN
      RAISE EXCEPTION 'coordination : %', v_json;
    END IF;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_lect2, 'role', 'authenticated', 'aal', 'aal1')::text, true);
    v_json := api.fn_mon_etat_double_facteur();
    IF (v_json ->> 'exige')::boolean OR (v_json ->> 'equipe')::boolean OR (v_json ->> 'a_facteur')::boolean THEN
      RAISE EXCEPTION 'lecteur à facteur inachevé : %', v_json;
    END IF;
    PERFORM set_config('request.jwt.claims', '', true);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  v_t := 'T9 api.fn_admin_double_facteur_comptes';
  BEGIN
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_coord, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    BEGIN
      PERFORM * FROM api.fn_admin_double_facteur_comptes(); v_state := 'passé';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; END;
    IF v_state <> '42501' THEN RAISE EXCEPTION 'coordination admise à la liste : %', v_state; END IF;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    SELECT count(*) INTO v_n FROM api.fn_admin_double_facteur_comptes() c WHERE c.user_id IN (v_coord, v_biblio, v_admin, v_lect);
    IF v_n <> 4 THEN RAISE EXCEPTION 'comptes d''équipe et lecteur à facteur trouvés : % sur 4', v_n; END IF;
    IF EXISTS (SELECT 1 FROM api.fn_admin_double_facteur_comptes() c WHERE c.user_id IN (v_lect2, v_ancien)) THEN
      RAISE EXCEPTION 'un facteur inachevé ou une adhésion inactive figure dans la liste';
    END IF;
    SELECT c.facteurs, c.equipes INTO v_n, v_txt FROM api.fn_admin_double_facteur_comptes() c WHERE c.user_id = v_lect;
    IF v_n <> 1 OR v_txt IS NOT NULL THEN RAISE EXCEPTION 'lecteur à facteur : % facteur(s), équipes %', v_n, v_txt; END IF;
    SELECT c.facteurs, c.administration INTO v_n, v_b FROM api.fn_admin_double_facteur_comptes() c WHERE c.user_id = v_admin;
    IF v_n <> 1 OR NOT v_b THEN RAISE EXCEPTION 'administration : % facteur(s), admin %', v_n, v_b; END IF;
    SELECT c.equipes INTO v_txt FROM api.fn_admin_double_facteur_comptes() c WHERE c.user_id = v_coord;
    IF v_txt NOT LIKE '%B42 (essai) (coordenador)%' THEN RAISE EXCEPTION 'équipes de la coordination : %', v_txt; END IF;
    PERFORM set_config('request.jwt.claims', '', true);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  v_t := 'T10 api.fn_admin_retirer_double_facteur';
  BEGIN
    -- hors administration, même en aal2
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_coord, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    BEGIN v_json := api.fn_admin_retirer_double_facteur(v_lect, 'Téléphone perdu, identité vérifiée en assemblée'); v_state := 'passé';
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; END;
    IF v_state <> '42501' THEN RAISE EXCEPTION 'coordination : %', v_state; END IF;
    -- administration en aal1
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin, 'role', 'authenticated', 'aal', 'aal1')::text, true);
    BEGIN v_json := api.fn_admin_retirer_double_facteur(v_lect, 'Téléphone perdu, identité vérifiée en assemblée'); v_state := 'passé'; v_txt := NULL;
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; v_txt := SQLERRM; END;
    IF v_state <> '42501' OR v_txt <> 'aal2_required' THEN RAISE EXCEPTION 'administration aal1 : % %', v_state, v_txt; END IF;
    -- motif trop court
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    BEGIN v_json := api.fn_admin_retirer_double_facteur(v_lect, 'perdu'); v_state := 'passé'; v_txt := NULL;
    EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE; v_txt := SQLERRM; END;
    IF v_txt IS DISTINCT FROM 'motif_required' THEN RAISE EXCEPTION 'motif court : % %', v_state, v_txt; END IF;
    -- retrait réel
    v_json := api.fn_admin_retirer_double_facteur(v_lect, 'Téléphone perdu, identité vérifiée en assemblée');
    IF (v_json ->> 'facteurs_retires')::int <> 1 OR (v_json ->> 'sessions_fermees')::int <> 2 THEN RAISE EXCEPTION 'bilan %', v_json; END IF;
    IF EXISTS (SELECT 1 FROM auth.mfa_factors WHERE user_id = v_lect) OR EXISTS (SELECT 1 FROM auth.sessions WHERE user_id = v_lect) THEN
      RAISE EXCEPTION 'facteurs ou sessions restants';
    END IF;
    SELECT count(*) INTO v_n FROM private.double_facteur_journal j
     WHERE j.par = v_admin AND j.compte = v_lect AND j.facteurs_retires = 1 AND j.sessions_fermees = 2
       AND j.motif = 'Téléphone perdu, identité vérifiée en assemblée';
    IF v_n <> 1 THEN RAISE EXCEPTION 'journal : % ligne(s)', v_n; END IF;
    -- les facteurs des autres comptes sont intacts
    IF NOT EXISTS (SELECT 1 FROM auth.mfa_factors WHERE user_id = v_admin) THEN RAISE EXCEPTION 'facteur de l''administration emporté'; END IF;
    PERFORM set_config('request.jwt.claims', '', true);
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN PERFORM set_config('request.jwt.claims', '', true); v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'B42 OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'B42 ECHEC : %/% tests passés — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
