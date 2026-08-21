-- ============================================================
-- Tests d'acceptation paquet DOUBLONS P10 — balayage global des autorités
-- ============================================================
-- Migration couverte : 20260821130003_balayage_global_des_autorites.sql
--
-- Ce que ces tests protègent, dans l'ordre d'importance :
--
--   1. La COHÉRENCE avec la détection par autorité (`DEDUP-6`). Deux vues qui
--      se contredisent sont pires qu'une seule imparfaite : le test 7 vérifie
--      qu'une paire vue par `suggest_author_duplicates` se retrouve dans le
--      balayage.
--   2. Le classement par niveau de preuve, qui décide de ce que la
--      coordination regarde en premier.
--   3. Le piège des dates NULL. Lors de la mesure du 21/08, l'expression de
--      concordance rendait NULL quand AUCUNE des deux autorités n'avait de
--      date : 27 paires sur 95 tombaient alors dans aucun niveau et
--      disparaissaient silencieusement. Le test 6 garde ce cas.
--
-- 7 tests :
--   1. Un compte non staff est refusé (42501).
--   2. Noms identiques après normalisation → niveau `nom_exact`.
--   3. L'ordre des mots n'empêche pas la correspondance (la normalisation trie).
--   4. Identifiant externe partagé → niveau `identifiant`, qui prime sur le nom.
--   5. Coquille + dates concordantes → niveau `nom_et_dates`.
--   6. Coquille SANS aucune date des deux côtés → `nom_seul`, jamais perdue.
--   7. Cohérence : ce que voit la détection par autorité, le balayage le voit.
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p10-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Balayage', 'P10' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-p10-' || substr(gen_random_uuid()::text, 1, 8), 'Essai P10') RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'coordenador', 'active' FROM prof, lib RETURNING user_id
-- Paire A : ordre des mots inversé, aucun identifiant, aucune date -> nom_exact.
), a1 AS (
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Emma Goldman P10', 'GOLDMAN P10, Emma') RETURNING id
), a2 AS (
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Goldman P10 Emma', 'GOLDMAN P10, Emma') RETURNING id
-- Paire B : identifiant VIAF partagé -> identifiant, qui doit primer.
), b1 AS (
  INSERT INTO public.authors (preferred_name, sort_name, viaf_id)
  VALUES ('Ricardo Flores Magon P10', 'FLORES MAGON P10, Ricardo', 'VIAF-P10-777') RETURNING id
), b2 AS (
  INSERT INTO public.authors (preferred_name, sort_name, viaf_id)
  VALUES ('Ricardo Flores Magon P10', 'MAGON P10, Ricardo Flores', 'VIAF-P10-777') RETURNING id
-- Paire C : coquille + mêmes dates -> nom_et_dates.
), c1 AS (
  INSERT INTO public.authors (preferred_name, sort_name, birth_year, death_year)
  VALUES ('Pietro Ferrua P10', 'FERRUA P10, Pietro', 1930, 2024) RETURNING id
), c2 AS (
  INSERT INTO public.authors (preferred_name, sort_name, birth_year, death_year)
  VALUES ('Pietro Ferroa P10', 'FERROA P10, Pietro', 1930, 2024) RETURNING id
-- Paire D : coquille SANS aucune date -> nom_seul (le cas des 27 paires perdues).
), d1 AS (
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Luce Fabbri P10', 'FABBRI P10, Luce') RETURNING id
), d2 AS (
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Luce Fabri P10', 'FABRI P10, Luce') RETURNING id
)
SELECT (SELECT id FROM prof) AS uid,
       (SELECT id FROM a1) AS a1, (SELECT id FROM a2) AS a2,
       (SELECT id FROM b1) AS b1, (SELECT id FROM b2) AS b2,
       (SELECT id FROM c1) AS c1, (SELECT id FROM c2) AS c2,
       (SELECT id FROM d1) AS d1, (SELECT id FROM d2) AS d2,
       (SELECT user_id FROM memb) AS ok;

DO $$
DECLARE
  v_uid uuid;
  v_a1 bigint; v_a2 bigint; v_b1 bigint; v_b2 bigint;
  v_c1 bigint; v_c2 bigint; v_d1 bigint; v_d2 bigint;
  v_niv text; v_n int;
BEGIN
  SELECT uid, a1, a2, b1, b2, c1, c2, d1, d2
    INTO v_uid, v_a1, v_a2, v_b1, v_b2, v_c1, v_c2, v_d1, v_d2 FROM t_fix;
  IF v_uid IS NULL OR v_d2 IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 1 ---------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.suggest_authority_duplicates(500);
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : un compte non staff a obtenu le balayage.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 1 OK — balayage refusé à un compte non staff.';
  END;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- 2 · 3 -----------------------------------------------------------
  SELECT niveau_preuve INTO v_niv FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = least(v_a1, v_a2) AND author_id_b = greatest(v_a1, v_a2);
  IF v_niv IS DISTINCT FROM 'nom_exact' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : niveau « % » au lieu de nom_exact.', coalesce(v_niv, '(absente)');
  END IF;
  RAISE NOTICE 'TEST 2 OK — noms identiques après normalisation : niveau nom_exact.';
  RAISE NOTICE 'TEST 3 OK — « Emma Goldman » et « Goldman Emma » se rejoignent : la normalisation trie les mots.';

  -- 4 ---------------------------------------------------------------
  SELECT niveau_preuve INTO v_niv FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = least(v_b1, v_b2) AND author_id_b = greatest(v_b1, v_b2);
  IF v_niv IS DISTINCT FROM 'identifiant' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : niveau « % » au lieu de identifiant.', coalesce(v_niv, '(absente)');
  END IF;
  RAISE NOTICE 'TEST 4 OK — un VIAF partagé prime sur la correspondance de nom.';

  -- 5 ---------------------------------------------------------------
  SELECT niveau_preuve INTO v_niv FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = least(v_c1, v_c2) AND author_id_b = greatest(v_c1, v_c2);
  IF v_niv IS DISTINCT FROM 'nom_et_dates' THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : niveau « % » au lieu de nom_et_dates.', coalesce(v_niv, '(absente)');
  END IF;
  RAISE NOTICE 'TEST 5 OK — coquille avec dates concordantes : niveau nom_et_dates.';

  -- 6 ---------------------------------------------------------------
  -- Le cas qui disparaissait : aucune date des deux côtés.
  SELECT niveau_preuve INTO v_niv FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = least(v_d1, v_d2) AND author_id_b = greatest(v_d1, v_d2);
  IF v_niv IS DISTINCT FROM 'nom_seul' THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : paire sans dates classée « % » — elle doit être nom_seul, jamais perdue.',
      coalesce(v_niv, '(ABSENTE — le coalesce sur les dates manque)');
  END IF;
  RAISE NOTICE 'TEST 6 OK — une paire sans aucune date reste classée en nom_seul.';

  -- 7 ---------------------------------------------------------------
  -- DEDUP-6 : ce que voit la détection par autorité, le balayage le voit.
  SELECT count(*) INTO v_n FROM public.suggest_author_duplicates(v_c1) s
   WHERE s.author_id = v_c2;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'SETUP FAILED : la détection par autorité ne voit pas la coquille (% ligne).', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM public.suggest_authority_duplicates(500) g
   WHERE g.author_id_a = least(v_c1, v_c2) AND g.author_id_b = greatest(v_c1, v_c2);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : les deux vues divergent — paire vue par autorité, absente du balayage.';
  END IF;
  RAISE NOTICE 'TEST 7 OK — balayage et détection par autorité voient la même paire.';

  RAISE NOTICE 'DOUBLONS-P10 OK : 7/7 tests passés';
END $$;

ROLLBACK;
