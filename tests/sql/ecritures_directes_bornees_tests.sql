-- =====================================================================
-- AnarBib — Tests d'acceptation : écritures directes bornées, lectures au
-- plus juste
-- Date    : 2026-10-17
-- Ref     : migration 20261018211324_ecritures_directes_bornees
-- Session : Modele de menace
--
-- T1 profiles, sous authenticated : la personne change son nom, son
--    téléphone, son adresse, sa langue, consent_email ; elle ne change ni son
--    gel, ni son parcours d'inscription, ni son consentement à la Lettre.
--    L'équipe de sa bibliothèque change son nom et son courriel, pas son gel.
--    Une procédure DEFINER (rôle postgres) pose le gel.
-- T2 notes de lecture : la fonction rend les notes publiées sans
--    l'identifiant de l'auteur·rice et is_mine juste ; la table ne rend en
--    direct que ses propres notes à un compte d'une autre bibliothèque ;
--    l'équipe de la bibliothèque d'origine voit les notes (modération).
-- T3 réservations : plus aucun INSERT ni UPDATE direct sous authenticated ;
--    la lecture de ses propres réservations reste.
-- T4 ouvertures OAI : une coordination (qui vote) lit la demande ; un
--    lecteur, non.
-- T5 network_administrators : removal_reason illisible en direct ; la vue
--    publique de l'administration se lit toujours.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'ECRITURES-BORNEES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_libA uuid; v_libB uuid;
  v_lectA uuid := gen_random_uuid(); v_staffA uuid := gen_random_uuid();
  v_lectB uuid := gen_random_uuid(); v_coordB uuid := gen_random_uuid();
  v_admin uuid := gen_random_uuid();
  v_work bigint; v_note bigint; v_resa bigint; v_oai uuid;
  v_u uuid; v_txt text; v_state text; v_n int; v_b boolean; v_rec record;
BEGIN
  -- ── Décor (postgres) ────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('eb-a-' || v_suf, 'Bornes A (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('eb-b-' || v_suf, 'Bornes B (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libB;
  FOREACH v_u IN ARRAY ARRAY[v_lectA, v_staffA, v_lectB, v_coordB, v_admin] LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, created_at, updated_at)
    VALUES ('00000000-0000-0000-0000-000000000000', v_u, 'authenticated', 'authenticated', 'eb-' || v_u || '@example.invalid', now(), now());
    INSERT INTO public.profiles (id, email, first_name, last_name) VALUES (v_u, 'eb-' || v_u || '@example.invalid', 'Essai', 'EB') ON CONFLICT (id) DO NOTHING;
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_lectA, v_libA, 'reader', 'active', true),
    (v_staffA, v_libA, 'librarian', 'active', true),
    (v_lectB, v_libB, 'reader', 'active', true),
    (v_coordB, v_libB, 'coordenador', 'active', true);
  INSERT INTO public.network_administrators (user_id, status, removal_reason) VALUES (v_admin, 'active', 'motif interne');

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 profiles : gouvernance par procedure';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lectA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.profiles SET first_name = 'Nouveau', phone = '000', address = 'ici', preferred_language = 'fr', consent_email = true WHERE id = v_lectA;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN v_txt := v_txt || 'champs-libres-refuses '; END IF;
    v_state := NULL;
    BEGIN UPDATE public.profiles SET is_restricted = false, restricted_reason = NULL WHERE id = v_lectA;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    -- (pas de gel posé : la valeur ne change pas → passer à true pour tester)
    v_state := NULL;
    BEGIN UPDATE public.profiles SET is_restricted = true WHERE id = v_lectA;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    IF v_state IS DISTINCT FROM '42501' THEN v_txt := v_txt || 'gel-modifiable=' || coalesce(v_state, 'accepte') || ' '; END IF;
    v_state := NULL;
    BEGIN UPDATE public.profiles SET consent_lettre = true WHERE id = v_lectA;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    IF v_state IS DISTINCT FROM '42501' THEN v_txt := v_txt || 'lettre-modifiable=' || coalesce(v_state, 'accepte') || ' '; END IF;
    v_state := NULL;
    BEGIN UPDATE public.profiles SET solicitante_state = 'x' WHERE id = v_lectA;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    IF v_state IS DISTINCT FROM '42501' THEN v_txt := v_txt || 'inscription-modifiable=' || coalesce(v_state, 'accepte') || ' '; END IF;
    EXECUTE 'RESET ROLE';

    -- la procédure (postgres) pose le gel ; la personne ne le lève pas
    UPDATE public.profiles SET is_restricted = true, restricted_reason = 'essai', restricted_since = now() WHERE id = v_lectA;
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := NULL;
    BEGIN UPDATE public.profiles SET is_restricted = false WHERE id = v_lectA;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    IF v_state IS DISTINCT FROM '42501' THEN v_txt := v_txt || 'auto-degel=' || coalesce(v_state, 'accepte') || ' '; END IF;
    EXECUTE 'RESET ROLE';

    -- l'équipe de A : nom et courriel oui, gel non
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staffA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    UPDATE public.profiles SET last_name = 'Corrige', email = 'eb-corrige-' || v_suf || '@example.invalid' WHERE id = v_lectA;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN v_txt := v_txt || 'equipe-champs-refuses '; END IF;
    v_state := NULL;
    BEGIN UPDATE public.profiles SET is_restricted = false WHERE id = v_lectA;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    IF v_state IS DISTINCT FROM '42501' THEN v_txt := v_txt || 'equipe-degel=' || coalesce(v_state, 'accepte') || ' '; END IF;
    EXECUTE 'RESET ROLE';
    IF NOT (SELECT is_restricted FROM public.profiles WHERE id = v_lectA) THEN v_txt := v_txt || 'gel-perdu '; END IF;
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 notes de lecture sans l''auteur';
  BEGIN
    v_txt := '';
    INSERT INTO public.works (uniform_title) VALUES ('EB oeuvre ' || v_suf) RETURNING id INTO v_work;
    -- l'auteur·rice est posé·e par trigger depuis auth.uid() : on écrit en son nom
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lectA, 'role', 'authenticated')::text, true);
    INSERT INTO public.book_reading_notes (work_id, author_user_id, author_pseudonym, origin_library_id, body, status)
    VALUES (v_work, v_lectA, 'pseudo-a', v_libA, 'une note', 'published') RETURNING id INTO v_note;

    -- lecteur de B : la fonction rend la note, sans auteur, is_mine faux ;
    -- la table ne la rend pas
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lectB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_rec FROM api.reading_notes_published_v1(v_work) LIMIT 1;
    IF v_rec.id IS DISTINCT FROM v_note THEN v_txt := v_txt || 'fonction-sans-note '; END IF;
    IF v_rec.is_mine THEN v_txt := v_txt || 'is_mine-faux-positif '; END IF;
    SELECT count(*) INTO v_n FROM public.book_reading_notes WHERE id = v_note;
    IF v_n <> 0 THEN v_txt := v_txt || 'table-rend-la-note-d-autrui '; END IF;
    EXECUTE 'RESET ROLE';

    -- l'auteur·rice : is_mine vrai, sa note en direct
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lectA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_rec FROM api.reading_notes_published_v1(v_work) LIMIT 1;
    IF NOT coalesce(v_rec.is_mine, false) THEN v_txt := v_txt || 'is_mine-absent '; END IF;
    SELECT count(*) INTO v_n FROM public.book_reading_notes WHERE id = v_note AND author_user_id = v_lectA;
    IF v_n <> 1 THEN v_txt := v_txt || 'auteur-perd-sa-note '; END IF;
    EXECUTE 'RESET ROLE';

    -- l'équipe de A (modération) : la voit
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staffA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.book_reading_notes WHERE id = v_note;
    IF v_n <> 1 THEN v_txt := v_txt || 'moderation-aveugle '; END IF;
    EXECUTE 'RESET ROLE';

    IF has_function_privilege('anon', 'api.reading_notes_published_v1(bigint)', 'EXECUTE') THEN v_txt := v_txt || 'fonction-anon '; END IF;
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 reservations : pas d''ecriture directe';
  BEGIN
    v_txt := '';
    IF has_table_privilege('authenticated', 'public.reservas_v2', 'INSERT') THEN v_txt := v_txt || 'insert-entete '; END IF;
    IF has_table_privilege('authenticated', 'public.reservas_v2', 'UPDATE') THEN v_txt := v_txt || 'update-entete '; END IF;
    IF has_table_privilege('authenticated', 'public.reserva_linhas_v2', 'INSERT') THEN v_txt := v_txt || 'insert-ligne '; END IF;
    IF has_table_privilege('authenticated', 'public.reserva_linhas_v2', 'UPDATE') THEN v_txt := v_txt || 'update-ligne '; END IF;
    IF NOT has_table_privilege('authenticated', 'public.reservas_v2', 'SELECT') THEN v_txt := v_txt || 'lecture-perdue '; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lectA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := NULL;
    BEGIN INSERT INTO public.reservas_v2 (user_id, library_id) VALUES (v_lectA, v_libA);
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    IF v_state IS DISTINCT FROM '42501' THEN v_txt := v_txt || 'insert-direct=' || coalesce(v_state, 'accepte') || ' '; END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 ouvertures OAI lues par qui delibere';
  BEGIN
    v_txt := '';
    INSERT INTO public.oai_opening_requests (kind, library_id, notes, status, requested_by)
    VALUES ('library', v_libA, 'note interne', 'pending_admin', v_staffA) RETURNING id INTO v_oai;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.oai_opening_requests WHERE id = v_oai;
    IF v_n <> 1 THEN v_txt := v_txt || 'coordination-aveugle '; END IF;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lectB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT count(*) INTO v_n FROM public.oai_opening_requests WHERE id = v_oai;
    IF v_n <> 0 THEN v_txt := v_txt || 'lecteur-lit '; END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──────────────────────────────────────────────────────────────
  v_t := 'T5 administration : motif de retrait illisible, liste lisible';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lectB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_state := NULL;
    BEGIN PERFORM removal_reason FROM public.network_administrators LIMIT 1;
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE; END;
    IF v_state IS DISTINCT FROM '42501' THEN v_txt := v_txt || 'motif-lisible=' || coalesce(v_state, 'accepte') || ' '; END IF;
    SELECT count(*) INTO v_n FROM api.network_administrators_public_v1 WHERE user_id = v_admin;
    IF v_n <> 1 THEN v_txt := v_txt || 'liste-publique-cassee '; END IF;
    SELECT count(*) INTO v_n FROM public.network_administrators WHERE user_id = v_admin AND status = 'active';
    IF v_n <> 1 THEN v_txt := v_txt || 'statut-illisible '; END IF;
    EXECUTE 'RESET ROLE';
    IF v_txt = '' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Bilan ───────────────────────────────────────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ECRITURES-BORNEES OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'ECRITURES-BORNEES ECHEC : %/% — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
