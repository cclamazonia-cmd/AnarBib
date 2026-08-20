-- ============================================================
-- Tests d'acceptation paquet DOUBLONS P3 — « Pas un doublon » réversible
-- ============================================================
-- Migration couverte : 20260821020001_pas_un_doublon_reversible.sql
--
-- Ce que ces tests protègent : écarter une paire la retire de TOUTES les
-- détections du réseau. Tant que le geste était sans retour arrière, une
-- erreur de bonne foi masquait un vrai doublon pour toujours. Le paquet P3
-- rend le geste réversible ; ces tests vérifient que l'aller ET le retour
-- fonctionnent, parce qu'un retour cassé serait pire que pas de retour du
-- tout : on croirait pouvoir se rattraper.
--
-- 7 tests :
--   0. Deux notices jumelles sont bien détectées par le balayage.
--   1. mark_books_not_duplicate écrit la paire et nettoie le motif (btrim).
--   2. La paire écartée disparaît du balayage.
--   3. list_books_not_duplicate restitue titres, motif et personne ayant arbitré.
--   4. unmark_books_not_duplicate retire la ligne, même appelé en ordre inverse.
--   5. La paire redevient détectable — c'est tout l'objet du paquet.
--   6. Un compte non staff est refusé (42501).
--
-- Les données sont fabriquées ici : la suite ne dépend d'aucun contenu de la
-- base et reste valable quand le catalogue de démonstration change. Tout est
-- annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fixture ON COMMIT DROP AS
WITH usr AS (
  -- profiles.id référence auth.users : il faut donc le compte d'abord.
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(),
          '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'doublons-p3@example.invalid', now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Essai', 'P3' FROM usr
  RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-doublons-p3', 'Bibliotheque d''essai P3')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'coordenador', 'active' FROM prof, lib
  RETURNING user_id
-- Deux notices JUMELLES : même titre, même auteur. Elles doivent donc être
-- détectées comme doublon, sinon les tests 0/2/5 ne prouveraient rien.
), ba AS (
  INSERT INTO public.books (titulo, autor, ano)
  VALUES ('O Apoio Mutuo', 'KROPOTKIN, Piotr', '1902')
  RETURNING id
), bb AS (
  INSERT INTO public.books (titulo, autor, ano)
  VALUES ('O Apoio Mutuo', 'KROPOTKIN, Piotr', '1902')
  RETURNING id
)
SELECT (SELECT id FROM prof)      AS uid,
       (SELECT id FROM ba)        AS book_a,
       (SELECT id FROM bb)        AS book_b,
       (SELECT user_id FROM memb) AS memb_ok;

DO $$
DECLARE
  v_uid    uuid;
  v_a      bigint;
  v_b      bigint;
  v_lo     bigint;
  v_hi     bigint;
  v_n      int;
  v_reason text;
  v_who    text;
BEGIN
  SELECT uid, book_a, book_b INTO v_uid, v_a, v_b FROM t_fixture;
  IF v_uid IS NULL OR v_a IS NULL OR v_b IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;
  v_lo := least(v_a, v_b);
  v_hi := greatest(v_a, v_b);

  -- Contexte authenticated simulé : auth.uid() lit la claim « sub ».
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- 0 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.suggest_catalog_duplicates(500) s
   WHERE s.book_id_a = v_lo AND s.book_id_b = v_hi;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 0 ÉCHOUÉ : la paire jumelle n''est pas détectée au départ (% fois).', v_n;
  END IF;
  RAISE NOTICE 'TEST 0 OK — la paire jumelle est détectée par le balayage.';

  -- 1 ---------------------------------------------------------------
  -- Espaces superflus volontaires : le motif doit être nettoyé côté serveur.
  PERFORM public.mark_books_not_duplicate(v_a, v_b, '  deux volumes  ');

  SELECT count(*) INTO v_n FROM public.book_not_duplicate
   WHERE book_id_a = v_lo AND book_id_b = v_hi;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : % ligne(s) d''arbitrage au lieu d''une.', v_n;
  END IF;

  SELECT reason INTO v_reason FROM public.book_not_duplicate
   WHERE book_id_a = v_lo AND book_id_b = v_hi;
  IF v_reason IS DISTINCT FROM 'deux volumes' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : motif « % » — le btrim n''a pas eu lieu.', coalesce(v_reason, '(null)');
  END IF;
  RAISE NOTICE 'TEST 1 OK — paire écartée, motif « % ».', v_reason;

  -- 2 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.suggest_catalog_duplicates(500) s
   WHERE s.book_id_a = v_lo AND s.book_id_b = v_hi;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la paire écartée apparaît encore dans le balayage (% fois).', v_n;
  END IF;
  RAISE NOTICE 'TEST 2 OK — la paire écartée a quitté le balayage.';

  -- 3 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.list_books_not_duplicate(200);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : list renvoie % ligne(s) au lieu d''une.', v_n;
  END IF;

  SELECT created_by_name INTO v_who FROM public.list_books_not_duplicate(200)
   WHERE book_id_a = v_lo AND book_id_b = v_hi;
  IF v_who IS DISTINCT FROM 'Essai P3' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : arbitre « % » au lieu de « Essai P3 ».', coalesce(v_who, '(null)');
  END IF;
  RAISE NOTICE 'TEST 3 OK — list restitue la paire, son motif et son arbitre.';

  -- 4 ---------------------------------------------------------------
  -- Appel volontairement en ordre INVERSE : la fonction doit ordonner la paire.
  PERFORM public.unmark_books_not_duplicate(v_b, v_a);
  SELECT count(*) INTO v_n FROM public.book_not_duplicate
   WHERE book_id_a = v_lo AND book_id_b = v_hi;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : % ligne(s) restante(s) après rétablissement.', v_n;
  END IF;
  RAISE NOTICE 'TEST 4 OK — rétablissement effectif, ordre inverse accepté.';

  -- 5 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.suggest_catalog_duplicates(500) s
   WHERE s.book_id_a = v_lo AND s.book_id_b = v_hi;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : après rétablissement, la paire n''est pas redétectée (% fois).', v_n;
  END IF;
  RAISE NOTICE 'TEST 5 OK — la paire rétablie est de nouveau détectée.';

  -- 6 ---------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  BEGIN
    PERFORM public.unmark_books_not_duplicate(v_a, v_b);
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : un compte non staff a pu rétablir une paire.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 6 OK — compte non staff refusé (42501).';
  END;

  RAISE NOTICE 'DOUBLONS-P3 OK : 7/7 tests passés';
END $$;

ROLLBACK;
