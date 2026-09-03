-- ============================================================
-- Tests d'acceptation — l'homonymie sans accents ni casse, la proposition
-- de C5 devant les anonymes inversés, le signalement des doublons exacts
-- ============================================================
-- Migration couverte : *_l_homonymie_se_cherche_sans_accents_ni_casse.sql
--
-- CE QUE CES TESTS PROTÈGENT. Le 03/09, neuf autorités doublons sont nées
-- d'une recherche d'homonyme qui comparait à la lettre. Ces tests figent la
-- tolérance de la recherche (accents, casse, forme directe ↔ inversée), la
-- préférence pour une vraie fiche sur une fixture de formation, le refus de
-- proposer une autorité pour « identificado, Não » ou « ?? », et le fait que
-- les doublons sont SIGNALÉS et non fusionnés — rejouable sans doublon de
-- signalement.
--
-- 8 tests :
--   1. fn_conv_autor_proposition : « identificado, Não », « ?? », « Autores, Vários »,
--      « Collectif » → NULL ; « Kropotkin, Piotr ; Reclus » → « Kropotkin, Piotr ».
--   2. fn_conv_autorite_homonyme retrouve la fiche par la forme inversée en capitales
--      avec particule en tête (« DE ZZCARVALHO, Florentino » → « Zzcarvalho, Florentino de »).
--   3. … par la forme directe sans accents ni casse (« florentino de zzcarvalho »).
--   4. … et sans accent sur le mononyme (« Zzplatao » → « Zzplatão ») ; rien pour un inconnu.
--   5. Une vraie fiche passe avant une fixture de formation homonyme.
--   6. De bout en bout : appliquer le lot C5 sur « DE ZZCARVALHO, Florentino » LIE la
--      fiche existante, n'en crée pas.
--   7. fn_conv_signaler_doublons_exacts : une paire exacte → un signalement ouvert (lo < hi),
--      le second passage n'en ajoute pas ; la paire avec une fixture est ignorée.
--   8. Le rôle authenticated ne peut exécuter ni le signalement, ni la recherche,
--      ni le semis C5 (42501) ; anon rien ; l'écran garde conv_revue_appliquer.
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'hom-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Revue', 'Homonymie' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-hom-' || substr(gen_random_uuid()::text, 1, 8), 'Essai homonymie')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'librarian', 'active' FROM prof, lib
  RETURNING user_id
), a_carvalho AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzcarvalho, Florentino de', 'Florentino de Zzcarvalho') RETURNING id
), a_platao AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzplatão', 'Zzplatão') RETURNING id
), a_fixture AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_label)
  VALUES ('ZZMAKHNO, Nestor', 'Nestor Zzmakhno', 'formacao-e9') RETURNING id
), a_vraie AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzmakhno, Nestor', 'Nestor Zzmakhno') RETURNING id
), a_g1 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzguattari, Félix', 'Félix Zzguattari') RETURNING id
), a_g2 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzguattari, Felix', 'Felix Zzguattari') RETURNING id
), b_c5 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre homonymie', 'DE ZZCARVALHO, Florentino') RETURNING id
)
SELECT (SELECT id FROM prof)       AS uid,
       (SELECT id FROM a_carvalho) AS id_carvalho,
       (SELECT id FROM a_platao)   AS id_platao,
       (SELECT id FROM a_fixture)  AS id_fixture,
       (SELECT id FROM a_vraie)    AS id_vraie,
       (SELECT id FROM a_g1)       AS id_g1,
       (SELECT id FROM a_g2)       AS id_g2,
       (SELECT id FROM b_c5)       AS b_c5,
       (SELECT count(*) FROM memb) AS n_memb;

DO $$
DECLARE
  v_uid uuid;
  v_carvalho bigint; v_platao bigint; v_fixture bigint; v_vraie bigint; v_g1 bigint; v_g2 bigint; v_b bigint;
  v_id bigint; v_n bigint; v_txt text; v_authors_avant bigint;
BEGIN
  SELECT uid, id_carvalho, id_platao, id_fixture, id_vraie, id_g1, id_g2, b_c5
    INTO v_uid, v_carvalho, v_platao, v_fixture, v_vraie, v_g1, v_g2, v_b FROM t_fix;
  IF v_uid IS NULL OR v_b IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 1 ----------------------------------------------------------------
  IF public.fn_conv_autor_proposition('identificado, Não') IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : « identificado, Não » a reçu une proposition.';
  END IF;
  IF public.fn_conv_autor_proposition('??') IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : « ?? » a reçu une proposition.';
  END IF;
  IF public.fn_conv_autor_proposition('Autores, Vários') IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : « Autores, Vários » a reçu une proposition.';
  END IF;
  IF public.fn_conv_autor_proposition('Collectif') IS NOT NULL
     OR public.fn_conv_autor_proposition('Anônimo') IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : régression sur « Collectif » / « Anônimo ».';
  END IF;
  v_txt := public.fn_conv_autor_proposition('Kropotkin, Piotr ; Reclus, Élisée');
  IF v_txt IS DISTINCT FROM 'Kropotkin, Piotr' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : attendu « Kropotkin, Piotr », obtenu « % ».', v_txt;
  END IF;
  RAISE NOTICE 'TEST 1 OK — la proposition refuse les anonymes dans les deux ordres et le bruit.';

  -- 2 ----------------------------------------------------------------
  v_id := public.fn_conv_autorite_homonyme('DE ZZCARVALHO, Florentino');
  IF v_id IS DISTINCT FROM v_carvalho THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : « DE ZZCARVALHO, Florentino » devait retrouver % (obtenu %).', v_carvalho, v_id;
  END IF;
  RAISE NOTICE 'TEST 2 OK — la forme inversée en capitales, particule en tête, retrouve la fiche.';

  -- 3 ----------------------------------------------------------------
  v_id := public.fn_conv_autorite_homonyme('florentino de zzcarvalho');
  IF v_id IS DISTINCT FROM v_carvalho THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : la forme directe sans casse devait retrouver % (obtenu %).', v_carvalho, v_id;
  END IF;
  v_id := public.fn_conv_autorite_homonyme('Zzcarvalho,  Florentino   De');
  IF v_id IS DISTINCT FROM v_carvalho THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : les espaces surnuméraires et la casse devaient être tolérés (obtenu %).', v_id;
  END IF;
  RAISE NOTICE 'TEST 3 OK — forme directe, casse, espaces : tolérés.';

  -- 4 ----------------------------------------------------------------
  v_id := public.fn_conv_autorite_homonyme('Zzplatao');
  IF v_id IS DISTINCT FROM v_platao THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : « Zzplatao » devait retrouver « Zzplatão » (obtenu %).', v_id;
  END IF;
  IF public.fn_conv_autorite_homonyme('Zzinconnu, Personne') IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : un nom inconnu a retrouvé une fiche.';
  END IF;
  IF public.fn_conv_autorite_homonyme('   ') IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : une chaîne vide a retrouvé une fiche.';
  END IF;
  RAISE NOTICE 'TEST 4 OK — accents tolérés ; inconnu et vide rendent NULL.';

  -- 5 ----------------------------------------------------------------
  v_id := public.fn_conv_autorite_homonyme('ZZMAKHNO, Nestor');
  IF v_id IS DISTINCT FROM v_vraie THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : la vraie fiche % devait passer avant la fixture % (obtenu %).', v_vraie, v_fixture, v_id;
  END IF;
  RAISE NOTICE 'TEST 5 OK — une fixture de formation ne reçoit pas le lien quand une vraie fiche existe.';

  -- 6 ----------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM public.fn_conv_lot_autor_sans_autorite_seed();
  PERFORM api.conv_revue_decide(
    (SELECT id FROM public.catalog_review_queue WHERE lot = 'autor_sans_autorite' AND entity_id = v_b),
    'valide', NULL, NULL);
  SELECT count(*) INTO v_authors_avant FROM public.authors;
  PERFORM api.conv_revue_appliquer('autor_sans_autorite');
  SELECT c.author_id INTO v_id FROM public.book_contributors c WHERE c.book_id = v_b;
  IF v_id IS DISTINCT FROM v_carvalho THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le livre devait être lié à la fiche existante % (obtenu %).', v_carvalho, v_id;
  END IF;
  SELECT count(*) INTO v_n FROM public.authors WHERE lower(extensions.unaccent(sort_name)) LIKE '%zzcarvalho%';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : une autorité doublon a été créée (% fiches Zzcarvalho).', v_n;
  END IF;
  RAISE NOTICE 'TEST 6 OK — appliquer C5 lie la fiche existante, sans doublon.';

  -- 7 ----------------------------------------------------------------
  SELECT public.fn_conv_signaler_doublons_exacts() INTO v_n;
  IF v_n < 1 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : aucun signalement posé (attendu au moins la paire Zzguattari).';
  END IF;
  SELECT count(*) INTO v_n FROM public.authority_duplicate_reports r
   WHERE r.author_id_a = least(v_g1, v_g2) AND r.author_id_b = greatest(v_g1, v_g2) AND r.status = 'open';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : la paire Zzguattari devait avoir exactement 1 signalement ouvert (obtenu %).', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.authority_duplicate_reports r
   WHERE r.author_id_a = least(v_vraie, v_fixture) AND r.author_id_b = greatest(v_vraie, v_fixture);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : une paire avec une fixture de formation a été signalée.';
  END IF;
  SELECT public.fn_conv_signaler_doublons_exacts() INTO v_n;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : le second passage a posé % signalement(s) — pas rejouable.', v_n;
  END IF;
  RAISE NOTICE 'TEST 7 OK — un signalement par paire, rejouable, fixtures ignorées.';

  -- 8 ----------------------------------------------------------------
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_signaler_doublons_exacts();
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : le rôle authenticated a signalé des doublons.';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_autorite_homonyme(text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_conv_signaler_doublons_exacts()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_autorite_homonyme(text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_signaler_doublons_exacts()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_lot_autor_sans_autorite_seed()', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : une fonction de maintenance est exécutable depuis l''application.';
  END IF;
  IF NOT has_function_privilege('authenticated', 'api.conv_revue_appliquer(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : l''écran a perdu conv_revue_appliquer.';
  END IF;
  RAISE NOTICE 'TEST 8 OK — les fonctions de maintenance n''ont pas de porte applicative ; l''écran garde la sienne.';

  RAISE EXCEPTION 'CONV-HOMONYMIE OK : 8/8 tests passés';
END $$;

ROLLBACK;
