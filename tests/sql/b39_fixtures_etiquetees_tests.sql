-- =====================================================================
-- AnarBib — Tests : B39 (12/10/2026), les fixtures de formation sont
-- étiquetées en base et toute mesure d'usage les exclut par une requête.
-- Réf : 20261012…_b39_les_fixtures_de_formation_sont_etiquetees
--
-- Fixtures de la suite : une bibliothèque de formation (slug « -teste »),
-- deux comptes qui n'ont qu'elle, une personne qui forme (membre d'une vraie
-- bibliothèque aussi), une bibliothèque réelle, un exemplaire et une
-- réservation vivante dans chacune. On lit private.fn_mesures_hors_fixtures()
-- AVANT et APRÈS, et on compare les écarts : la suite vaut quel que soit
-- l'état de la base (CI ou production).
--   T1 l'étiquette naît du slug (« x-teste », « formation-x », « x-test »),
--      jamais d'un slug ordinaire, et ne se retire pas d'elle-même ;
--   T2 une bibliothèque de formation et ses comptes ne font pas bouger les
--      comptes réels, et font bouger les comptes de formation du bon nombre ;
--   T3 la personne qui forme, membre d'une vraie bibliothèque, reste un compte
--      réel ; une bibliothèque réelle et son compte comptent au réel ;
--   T4 une réservation vivante dans la bibliothèque de formation ne compte
--      pas dans la circulation réelle ; celle de la vraie bibliothèque oui ;
--   T5 la mesure est INVOKER, search_path figé, fermée à anon et à
--      authenticated, ouverte au rôle de service, et porte sa date.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'B39-FIXTURES OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_avant jsonb; v_apres jsonb; v_b boolean;
  v_libf uuid; v_libr uuid; v_libx uuid;
  v_e1 uuid := gen_random_uuid(); v_e2 uuid := gen_random_uuid(); v_form uuid := gen_random_uuid(); v_lect uuid := gen_random_uuid();
  v_book bigint; v_hold bigint; v_hold2 bigint;
  d int;
BEGIN
  v_avant := private.fn_mesures_hors_fixtures();

  -- ───────────────────────────────────────────────────────
  v_t := 'T1 l''étiquette naît du slug, jamais d''un slug ordinaire, et ne se retire pas d''elle-même';
  BEGIN
    INSERT INTO public.libraries (slug, name, is_active, visibility_level) VALUES ('b39-' || v_suf || '-teste', 'B39 formation (essai)', true, 'private') RETURNING id INTO v_libf;
    INSERT INTO public.libraries (slug, name, is_active, visibility_level) VALUES ('b39-' || v_suf || '-reelle', 'B39 réelle (essai)', true, 'private') RETURNING id INTO v_libr;
    INSERT INTO public.libraries (slug, name, is_active, visibility_level) VALUES ('formation-b39-' || v_suf, 'B39 formation 2 (essai)', true, 'private') RETURNING id INTO v_libx;
    v_b := (SELECT is_training FROM public.libraries WHERE id = v_libf) AND NOT (SELECT is_training FROM public.libraries WHERE id = v_libr) AND (SELECT is_training FROM public.libraries WHERE id = v_libx);
    -- une étiquette posée ne se retire pas par le déclencheur : un UPDATE qui la remet à faux la garde ? Non — à la main, on peut :
    -- le déclencheur n'agit que pour la POSER. On vérifie seulement qu'il ne la pose pas sur un slug ordinaire renommé.
    UPDATE public.libraries SET slug = 'b39-' || v_suf || '-reelle-2' WHERE id = v_libr;
    v_b := v_b AND NOT (SELECT is_training FROM public.libraries WHERE id = v_libr);
    DELETE FROM public.libraries WHERE id = v_libx;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : étiquettes inattendues'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- les comptes : deux de formation (seulement la bibliothèque de formation), une personne qui forme (les deux), un lecteur réel
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  SELECT '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', 'b39-' || u.n || '-' || v_suf || '@anarbib.local', now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
    FROM (VALUES (v_e1, 'e1'), (v_e2, 'e2'), (v_form, 'form'), (v_lect, 'lect')) u(id, n);
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  SELECT u.id, 'b39-' || u.n || '-' || v_suf || '@anarbib.local', 'B39', u.n, 'fr' FROM (VALUES (v_e1, 'e1'), (v_e2, 'e2'), (v_form, 'form'), (v_lect, 'lect')) u(id, n);
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_e1, v_libf, 'reader', 'active', true), (v_e2, v_libf, 'coordenador', 'active', true),
    (v_form, v_libf, 'coordenador', 'active', false), (v_form, v_libr, 'coordenador', 'active', true),
    (v_lect, v_libr, 'reader', 'active', true);
  -- un fonds et un exemplaire dans chacune, une réservation vivante dans chacune
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material) VALUES ('B39 (essai)', 'Essai, Autrice', 'B39-' || v_suf, 'livro') RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_libf) RETURNING id INTO v_hold;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_libr) RETURNING id INTO v_hold2;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility) VALUES ('B39-' || v_suf, 'B39' || v_suf || '-F', v_libf, v_hold, 'ambos', 'public');
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility) VALUES ('B39-' || v_suf, 'B39' || v_suf || '-R', v_libr, v_hold2, 'ambos', 'public');
  INSERT INTO public.reservas_v2 (user_id, library_id, notes, status_global) VALUES (v_e1, v_libf, 'B39 formation', 'ativa'), (v_lect, v_libr, 'B39 réelle', 'ativa');
  v_apres := private.fn_mesures_hors_fixtures();

  -- ───────────────────────────────────────────────────────
  v_t := 'T2 la bibliothèque de formation et ses deux comptes comptent en formation, pas au réel';
  BEGIN
    d := (v_apres->'bibliotheques'->>'formation')::int - (v_avant->'bibliotheques'->>'formation')::int;
    v_b := d = 1
       AND (v_apres->'comptes'->>'formation')::int - (v_avant->'comptes'->>'formation')::int = 2
       AND (v_apres->'appartenances_actives'->>'formation')::int - (v_avant->'appartenances_actives'->>'formation')::int = 3
       AND (v_apres->'exemplaires'->>'formation')::int - (v_avant->'exemplaires'->>'formation')::int = 1
       AND (v_apres->'bibliotheques'->'formation_slugs') ? ('b39-' || v_suf || '-teste');
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : avant ' || (v_avant - 'mesure_a')::text || ' / après ' || (v_apres - 'mesure_a')::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T3 la personne qui forme et le lecteur réel comptent au réel, avec la bibliothèque réelle et son exemplaire';
  BEGIN
    v_b := (v_apres->'bibliotheques'->>'reelles')::int - (v_avant->'bibliotheques'->>'reelles')::int = 1
       AND (v_apres->'comptes'->>'reels')::int - (v_avant->'comptes'->>'reels')::int = 2
       AND (v_apres->'comptes'->>'reels_confirmes')::int - (v_avant->'comptes'->>'reels_confirmes')::int = 2
       AND (v_apres->'appartenances_actives'->>'reelles')::int - (v_avant->'appartenances_actives'->>'reelles')::int = 2
       AND (v_apres->'exemplaires'->>'reels')::int - (v_avant->'exemplaires'->>'reels')::int = 1;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : avant ' || (v_avant - 'mesure_a')::text || ' / après ' || (v_apres - 'mesure_a')::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T4 la réservation vivante de formation ne compte pas dans la circulation réelle ; celle de la vraie bibliothèque, oui';
  BEGIN
    v_b := (v_apres->'circulation_vivante'->>'reservations')::int - (v_avant->'circulation_vivante'->>'reservations')::int = 1
       AND (v_apres->'circulation_vivante'->>'formation')::int - (v_avant->'circulation_vivante'->>'formation')::int = 1
       AND (v_apres->'circulation_vivante'->>'emprunts')::int = (v_avant->'circulation_vivante'->>'emprunts')::int;
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : avant ' || (v_avant->'circulation_vivante')::text || ' / après ' || (v_apres->'circulation_vivante')::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- ───────────────────────────────────────────────────────
  v_t := 'T5 la mesure est INVOKER, search_path figé, fermée à anon et authenticated, ouverte au rôle de service, datée';
  BEGIN
    SELECT NOT p.prosecdef AND EXISTS (SELECT 1 FROM unnest(p.proconfig) c WHERE c LIKE 'search_path=%') INTO v_b
      FROM pg_proc p WHERE p.oid = 'private.fn_mesures_hors_fixtures()'::regprocedure;
    v_b := v_b AND NOT has_function_privilege('anon', 'private.fn_mesures_hors_fixtures()', 'EXECUTE')
               AND NOT has_function_privilege('authenticated', 'private.fn_mesures_hors_fixtures()', 'EXECUTE')
               AND has_function_privilege('service_role', 'private.fn_mesures_hors_fixtures()', 'EXECUTE')
               AND (v_apres->>'mesure_a') IS NOT NULL
               AND (SELECT column_default FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'libraries' AND column_name = 'is_training') = 'false';
    IF v_b THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : droits ou date'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'B39-FIXTURES ECHEC : %/% tests passés — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'B39-FIXTURES OK : %/% tests passés', v_passed, v_passed + v_failed;
END $$;
