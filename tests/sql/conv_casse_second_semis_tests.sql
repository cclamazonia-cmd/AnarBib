-- ============================================================
-- Tests d'acceptation CONV-1, second semis — le lot casse reçoit les
-- capitales nées du lot C5
-- ============================================================
-- Migration couverte : *_le_lot_casse_recoit_les_capitales_nees_de_c5.sql
--
-- CE QUE CES TESTS PROTÈGENT. Le semis doit prendre les « NOM, Prénoms » en
-- capitales, et RIEN d'autre : pas les sigles de collectivités (leurs
-- capitales sont leur nom), pas les fiches doubles à plusieurs virgules
-- (elles ne sont pas de ce lot), pas les mononymes ni les mentions de rôle
-- (la forme est en cause : lot autorite_forme), pas les fixtures de la
-- formation, pas une fiche dont on attend la fusion. Et l'application doit
-- rester celle du 21/08 : le point d'accès en casse naturelle, la forme
-- d'affichage qui suit.
--
-- 5 tests :
--   1. « ZZBONANNO, Alfredo » → proposition « Zzbonanno, Alfredo ».
--   2. Restent dehors : « ZZRATGEB » (mononyme : lot forme), « ZZFEDERAÇÃO
--      ANARQUISTA » (radical de collectivité), « ZZMORAES, Carla. Acioli, Edane »
--      (deux virgules), « ZZLUDMILA, Aline (et al.) » (mention : lot forme),
--      « Zzsimples, Jean » (aucune capitale), la fixture de formation, la fiche au
--      doublon signalé.
--   3. Rejouable : second semis, 0.
--   4. Valider « ZZBONANNO, Alfredo » écrit « Zzbonanno, Alfredo » et « Alfredo Zzbonanno ».
--   5. Le semis n'a pas de porte applicative.
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'cas-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Revue', 'Casse' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-cas-' || substr(gen_random_uuid()::text, 1, 8), 'Essai casse')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'librarian', 'active' FROM prof, lib
  RETURNING user_id
), a_bon AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('ZZBONANNO, Alfredo', 'Alfredo ZZBONANNO') RETURNING id
), a_rat AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('ZZRATGEB', 'ZZRATGEB') RETURNING id
), a_fed AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('ZZFEDERAÇÃO ANARQUISTA', 'ZZFEDERAÇÃO ANARQUISTA') RETURNING id
), a_double AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('ZZMORAES, Carla. Acioli, Edane', 'ZZMORAES, Carla. Acioli, Edane') RETURNING id
), a_mention AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('ZZLUDMILA, Aline (et al.)', 'Aline (et al.) ZZLUDMILA') RETURNING id
), a_simple AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzsimples, Jean', 'Jean Zzsimples') RETURNING id
), a_fixture AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_label)
  VALUES ('ZZMAKHNO, Nestor', 'Nestor Zzmakhno', 'formacao-e9') RETURNING id
), a_dup1 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('ZZGUATTARI, Felix', 'Felix ZZGUATTARI') RETURNING id
), a_dup2 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzguattari, Félix', 'Félix Zzguattari') RETURNING id
), rep AS (
  INSERT INTO public.authority_duplicate_reports (author_id_a, author_id_b, note)
  SELECT least(a_dup1.id, a_dup2.id), greatest(a_dup1.id, a_dup2.id), 'fixture' FROM a_dup1, a_dup2
  RETURNING id
)
SELECT (SELECT id FROM prof)      AS uid,
       (SELECT id FROM a_bon)     AS id_bon,
       (SELECT id FROM a_rat)     AS id_rat,
       (SELECT id FROM a_fed)     AS id_fed,
       (SELECT id FROM a_double)  AS id_double,
       (SELECT id FROM a_mention) AS id_mention,
       (SELECT id FROM a_simple)  AS id_simple,
       (SELECT id FROM a_fixture) AS id_fixture,
       (SELECT id FROM a_dup1)    AS id_dup1,
       (SELECT count(*) FROM rep) AS n_rep,
       (SELECT count(*) FROM memb) AS n_memb;

DO $$
DECLARE
  v_uid uuid;
  v_bon bigint; v_rat bigint; v_fed bigint; v_double bigint; v_mention bigint; v_simple bigint; v_fixture bigint; v_dup1 bigint;
  v_n bigint; v_txt text; v_pref text;
BEGIN
  SELECT uid, id_bon, id_rat, id_fed, id_double, id_mention, id_simple, id_fixture, id_dup1
    INTO v_uid, v_bon, v_rat, v_fed, v_double, v_mention, v_simple, v_fixture, v_dup1 FROM t_fix;
  IF v_uid IS NULL OR v_dup1 IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 1 / 2 ------------------------------------------------------------
  SELECT public.fn_conv_lot_autorite_casse_seed() INTO v_n;
  IF v_n < 1 THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : le semis devait entrer au moins 1 fiche (obtenu %).', v_n;
  END IF;
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue WHERE lot = 'autorite_casse' AND entity_id = v_bon;
  IF v_txt IS DISTINCT FROM 'Zzbonanno, Alfredo' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : attendu « Zzbonanno, Alfredo », obtenu « % ».', v_txt;
  END IF;
  RAISE NOTICE 'TEST 1 OK — « NOM, Prénoms » en capitales : proposition initcap du patronyme.';

  SELECT count(*) INTO v_n FROM public.catalog_review_queue
   WHERE lot = 'autorite_casse' AND entity_id IN (v_rat, v_fed, v_double, v_mention, v_simple, v_fixture, v_dup1);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : % fiche(s) hors périmètre sont entrées (mononyme, collectivité, double, mention, sans capitale, fixture, doublon).', v_n;
  END IF;
  RAISE NOTICE 'TEST 2 OK — mononyme, sigle, fiche double, mention, casse naturelle, fixture, doublon : dehors.';

  -- 3 ----------------------------------------------------------------
  SELECT public.fn_conv_lot_autorite_casse_seed() INTO v_n;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le second semis a inséré % ligne(s).', v_n;
  END IF;
  RAISE NOTICE 'TEST 3 OK — rejouable.';

  -- 4 ----------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autorite_casse' AND entity_id = v_bon), 'valide', NULL, NULL);
  PERFORM api.conv_revue_appliquer('autorite_casse');
  SELECT sort_name, preferred_name INTO v_txt, v_pref FROM public.authors WHERE id = v_bon;
  IF v_txt IS DISTINCT FROM 'Zzbonanno, Alfredo' OR v_pref IS DISTINCT FROM 'Alfredo Zzbonanno' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : attendu « Zzbonanno, Alfredo » / « Alfredo Zzbonanno », obtenu « % » / « % ».', v_txt, v_pref;
  END IF;
  RAISE NOTICE 'TEST 4 OK — valider écrit le point d''accès en casse naturelle et la forme d''affichage suit.';

  -- 5 ----------------------------------------------------------------
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_lot_autorite_casse_seed();
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : le rôle authenticated a lancé le semis.';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_lot_autorite_casse_seed()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_lot_autorite_casse_seed()', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : le semis est exécutable depuis l''application.';
  END IF;
  RAISE NOTICE 'TEST 5 OK — pas de porte applicative.';

  RAISE EXCEPTION 'CONV-CASSE-2 OK : 5/5 tests passés';
END $$;

ROLLBACK;
