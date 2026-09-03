-- ============================================================
-- Tests d'acceptation CONV-2 / A1′ — la forme d'affichage suit le point d'accès
-- ============================================================
-- Migration couverte : *_la_forme_d_affichage_suit_le_point_d_acces.sql
--
-- CE QUE CES TESTS PROTÈGENT. La fonction réécrit `preferred_name` sur le
-- corpus PARTAGÉ. Le risque n'est pas qu'elle fasse trop peu : c'est qu'elle
-- fasse trop — dériver une forme d'affichage depuis un point d'accès encore
-- en capitales (et fabriquer `Fábio Luz FILHO`), inverser une collectivité,
-- ou « corriger » un écart qui n'est pas de casse (`Eric HOBSBAWM` sous
-- `Hobsbawm, Eric J.` : c'est un prénom qui manque, pas une casse).
--
-- 6 tests :
--   1. Le cas visé : `Zzbeauvoir, Simone de` / `Simone DE ZZBEAUVOIR` → `Simone de Zzbeauvoir`.
--   2. Point d'accès en capitales : rien n'est touché (le lot casse passe d'abord).
--   3. Collectivité typée : rien n'est touché.
--   4. Écart qui n'est pas de casse (prénom en plus) : rien n'est touché.
--   5. Forme déjà dérivée à la lettre : rien n'est touché, et pas comptée.
--   6. Le rôle `authenticated` ne peut pas l'exécuter (42501) ; ni anon. La fonction
--      n'a pas de porte applicative : seule une migration la lance.
--
-- Fixtures à noms improbables (préfixe Zz) pour ne pas croiser le seed ; tout
-- est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'a1p-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Revue', 'A1prime' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-a1p-' || substr(gen_random_uuid()::text, 1, 8), 'Essai A1 prime')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'librarian', 'active' FROM prof, lib
  RETURNING user_id
), a1 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzbeauvoir, Simone de', 'Simone DE ZZBEAUVOIR') RETURNING id
), a2 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('ZZFILHO, Fábio Luz', 'Fábio Luz Zzfilho') RETURNING id
), a3 AS (
  INSERT INTO public.authors (sort_name, preferred_name, authority_type)
  VALUES ('Zzkrisis, Grupo', 'GRUPO ZZKRISIS', 'collective') RETURNING id
), a4 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzhobsbawm, Eric J.', 'Eric ZZHOBSBAWM') RETURNING id
), a5 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzreclus, Élisée', 'Élisée Zzreclus') RETURNING id
)
SELECT (SELECT id FROM prof) AS uid,
       (SELECT id FROM a1) AS a_visee,
       (SELECT id FROM a2) AS a_capitales,
       (SELECT id FROM a3) AS a_collective,
       (SELECT id FROM a4) AS a_prenom,
       (SELECT id FROM a5) AS a_deja,
       (SELECT count(*) FROM memb) AS n_memb;

DO $$
DECLARE
  v_uid uuid;
  v_visee bigint; v_cap bigint; v_coll bigint; v_prenom bigint; v_deja bigint;
  v_txt text;
  v_n bigint;
BEGIN
  SELECT uid, a_visee, a_capitales, a_collective, a_prenom, a_deja
    INTO v_uid, v_visee, v_cap, v_coll, v_prenom, v_deja FROM t_fix;
  IF v_uid IS NULL OR v_deja IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 6 : le rôle de l'application n'a pas le droit d'exécuter (SET LOCAL ROLE dans
  --     un sous-bloc : l'exception annule le sous-bloc, et le rôle avec lui).
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_preferred_name_derive();
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le rôle authenticated a exécuté la fonction.';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_preferred_name_derive()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_preferred_name_derive()', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : la fonction est exécutable depuis l''application.';
  END IF;
  RAISE NOTICE 'TEST 6 OK — aucune porte applicative : ni authenticated ni anon.';

  -- L'application, comme en migration : rôle postgres.
  SELECT public.fn_conv_preferred_name_derive() INTO v_n;

  -- 1
  SELECT preferred_name INTO v_txt FROM public.authors WHERE id = v_visee;
  IF v_txt IS DISTINCT FROM 'Simone de Zzbeauvoir' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : attendu « Simone de Zzbeauvoir », obtenu « % ».', v_txt;
  END IF;
  IF v_n < 1 THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : la fonction devait compter au moins 1 fiche (obtenu %).', v_n;
  END IF;
  RAISE NOTICE 'TEST 1 OK — la casse de la forme d''affichage suit le point d''accès.';

  -- 2
  SELECT preferred_name INTO v_txt FROM public.authors WHERE id = v_cap;
  IF v_txt IS DISTINCT FROM 'Fábio Luz Zzfilho' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : un point d''accès en capitales a été dérivé (« % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 2 OK — un point d''accès en capitales n''est pas touché.';

  -- 3
  SELECT preferred_name INTO v_txt FROM public.authors WHERE id = v_coll;
  IF v_txt IS DISTINCT FROM 'GRUPO ZZKRISIS' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : une collectivité a été réécrite (« % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 3 OK — une collectivité n''est pas touchée.';

  -- 4
  SELECT preferred_name INTO v_txt FROM public.authors WHERE id = v_prenom;
  IF v_txt IS DISTINCT FROM 'Eric ZZHOBSBAWM' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : un écart qui n''est pas de casse a été « corrigé » (« % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 4 OK — un écart de contenu n''est pas une casse : rien n''est écrit.';

  -- 5 : rejouer ne compte plus rien sur les fixtures.
  SELECT preferred_name INTO v_txt FROM public.authors WHERE id = v_deja;
  IF v_txt IS DISTINCT FROM 'Élisée Zzreclus' THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : une forme déjà dérivée a changé (« % »).', v_txt;
  END IF;
  SELECT public.fn_conv_preferred_name_derive() INTO v_n;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : le second passage a compté % fiche(s) — la règle n''est pas idempotente.', v_n;
  END IF;
  RAISE NOTICE 'TEST 5 OK — idempotente : le second passage ne compte rien.';

  RAISE EXCEPTION 'CONV-A1PRIME OK : 6/6 tests passés';
END $$;

ROLLBACK;
