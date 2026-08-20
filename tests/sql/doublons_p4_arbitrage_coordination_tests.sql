-- ============================================================
-- Tests d'acceptation paquet DOUBLONS P4 — arbitrage réservé à la coordination
-- ============================================================
-- Migration couverte : 20260821020002_arbitrage_doublons_reserve_coordination.sql
--
-- Ce que ces tests protègent : la frontière entre ce qu'un·e bibliothécaire
-- peut faire (signaler, rapprocher) et ce que seule la coordination peut faire
-- (fusionner, écarter). Une garde qui se relâche silencieusement redonne à un
-- profil non formé le pouvoir de supprimer une notice sans retour arrière.
--
-- Le test 6 mérite une explication : le paquet P4 a REcopié le corps de
-- merge_book pour n'en changer que la garde. Un corps recopié est un corps
-- qu'on peut abîmer sans s'en apercevoir — d'où une fusion réellement exécutée
-- de bout en bout, plutôt qu'un simple contrôle de permission.
--
-- 8 tests :
--   1. Une bibliothécaire NE PEUT PAS écarter une paire (42501).
--   2. Une bibliothécaire NE PEUT PAS fusionner deux notices (42501).
--   3. Une bibliothécaire NE PEUT PAS fusionner deux autorités (42501).
--   4. Une bibliothécaire PEUT signaler ; signaler deux fois n'empile pas.
--   5. list_duplicate_reports restitue le signalement et son autrice.
--   6. La coordination peut fusionner : le doublon disparaît, le journal est écrit.
--   7. Écarter clôt le signalement ouvert de la paire.
--   8. La coordination peut rétablir une paire écartée.
--
-- Données fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fixture ON COMMIT DROP AS
WITH usr_coord AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES ('22222222-2222-2222-2222-222222222222',
          '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'p4-coord@example.invalid', now(), now())
  RETURNING id
), usr_biblio AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES ('33333333-3333-3333-3333-333333333333',
          '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'p4-biblio@example.invalid', now(), now())
  RETURNING id
), prof_coord AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Coordination', 'P4' FROM usr_coord RETURNING id
), prof_biblio AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Bibliothecaire', 'P4' FROM usr_biblio RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-doublons-p4', 'Bibliotheque d''essai P4')
  RETURNING id
), memb_coord AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof_coord.id, lib.id, 'coordenador', 'active' FROM prof_coord, lib
  RETURNING user_id
), memb_biblio AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof_biblio.id, lib.id, 'librarian', 'active' FROM prof_biblio, lib
  RETURNING user_id
-- Deux notices jumelles, sans exemplaire : la garde de rattachement de
-- merge_book laisse passer quand aucune des deux n'appartient à personne.
), ba AS (
  INSERT INTO public.books (titulo, autor, ano)
  VALUES ('A Conquista do Pao', 'KROPOTKIN, Piotr', '1892') RETURNING id
), bb AS (
  INSERT INTO public.books (titulo, autor, ano)
  VALUES ('A Conquista do Pao', 'KROPOTKIN, Piotr', '1892') RETURNING id
), aut_a AS (
  INSERT INTO public.authors (preferred_name) VALUES ('FERRUA, Pietro') RETURNING id
), aut_b AS (
  INSERT INTO public.authors (preferred_name) VALUES ('FERROA, Pietro') RETURNING id
)
SELECT (SELECT id FROM prof_coord)  AS uid_coord,
       (SELECT id FROM prof_biblio) AS uid_biblio,
       (SELECT id FROM ba)          AS book_a,
       (SELECT id FROM bb)          AS book_b,
       (SELECT id FROM aut_a)       AS author_a,
       (SELECT id FROM aut_b)       AS author_b,
       (SELECT user_id FROM memb_coord)  AS memb1_ok,
       (SELECT user_id FROM memb_biblio) AS memb2_ok;

DO $$
DECLARE
  v_coord  uuid;
  v_biblio uuid;
  v_a      bigint;
  v_b      bigint;
  v_aa     bigint;
  v_ab     bigint;
  v_lo     bigint;
  v_hi     bigint;
  v_n      int;
  v_who    text;
BEGIN
  SELECT uid_coord, uid_biblio, book_a, book_b, author_a, author_b
    INTO v_coord, v_biblio, v_a, v_b, v_aa, v_ab
    FROM t_fixture;
  IF v_coord IS NULL OR v_biblio IS NULL OR v_a IS NULL OR v_aa IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;
  v_lo := least(v_a, v_b);
  v_hi := greatest(v_a, v_b);

  -- ══ En contexte BIBLIOTHÉCAIRE ═════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_biblio, 'role', 'authenticated')::text, true);

  IF public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'SETUP FAILED : la bibliothécaire est reconnue comme arbitre.';
  END IF;

  -- 1 ---------------------------------------------------------------
  BEGIN
    PERFORM public.mark_books_not_duplicate(v_a, v_b, 'tentative');
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : une bibliothécaire a pu écarter une paire.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 1 OK — écarter est refusé à une bibliothécaire.';
  END;

  -- 2 ---------------------------------------------------------------
  BEGIN
    PERFORM public.merge_book(v_a, v_b);
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : une bibliothécaire a pu fusionner deux notices.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 2 OK — fusionner une notice est refusé à une bibliothécaire.';
  END;

  -- 3 ---------------------------------------------------------------
  BEGIN
    PERFORM public.merge_author(v_aa, v_ab);
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : une bibliothécaire a pu fusionner deux autorités.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 3 OK — fusionner une autorité est refusé à une bibliothécaire.';
  END;

  -- 4 ---------------------------------------------------------------
  -- Ce qui lui reste, et qui doit marcher : signaler.
  PERFORM public.report_duplicate_pair(v_a, v_b, '  memes titre et annee  ');
  PERFORM public.report_duplicate_pair(v_b, v_a, 'signale une seconde fois');

  SELECT count(*) INTO v_n FROM public.catalog_duplicate_reports
   WHERE book_id_a = v_lo AND book_id_b = v_hi AND status = 'open';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : % signalement(s) ouvert(s) au lieu d''un.', v_n;
  END IF;

  SELECT note INTO v_who FROM public.catalog_duplicate_reports
   WHERE book_id_a = v_lo AND book_id_b = v_hi AND status = 'open';
  IF v_who IS DISTINCT FROM 'memes titre et annee' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : note « % » — le btrim n''a pas eu lieu.', coalesce(v_who, '(null)');
  END IF;
  RAISE NOTICE 'TEST 4 OK — signalement enregistré une seule fois, note nettoyée.';

  -- 5 ---------------------------------------------------------------
  SELECT reported_by_name INTO v_who FROM public.list_duplicate_reports(200)
   WHERE book_id_a = v_lo AND book_id_b = v_hi;
  IF v_who IS DISTINCT FROM 'Bibliothecaire P4' THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : signalé par « % » au lieu de « Bibliothecaire P4 ».',
      coalesce(v_who, '(null)');
  END IF;
  RAISE NOTICE 'TEST 5 OK — le signalement est lisible, avec son autrice.';

  -- ══ En contexte COORDINATION ═══════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'SETUP FAILED : la coordination n''est pas reconnue comme arbitre.';
  END IF;

  -- 7 (avant 6 : la fusion supprimerait la notice et donc le signalement) -----
  PERFORM public.mark_books_not_duplicate(v_a, v_b, 'deux volumes');

  SELECT count(*) INTO v_n FROM public.catalog_duplicate_reports
   WHERE book_id_a = v_lo AND book_id_b = v_hi AND status = 'open';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : le signalement est resté ouvert après arbitrage.';
  END IF;
  SELECT count(*) INTO v_n FROM public.catalog_duplicate_reports
   WHERE book_id_a = v_lo AND book_id_b = v_hi AND status = 'closed' AND closed_by = v_coord;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : le signalement n''est pas clos par la coordination.';
  END IF;
  RAISE NOTICE 'TEST 7 OK — arbitrer une paire signalée clôt le signalement.';

  -- 8 ---------------------------------------------------------------
  PERFORM public.unmark_books_not_duplicate(v_a, v_b);
  SELECT count(*) INTO v_n FROM public.book_not_duplicate
   WHERE book_id_a = v_lo AND book_id_b = v_hi;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : la paire n''a pas été rétablie.';
  END IF;
  RAISE NOTICE 'TEST 8 OK — la coordination peut rétablir une paire écartée.';

  -- 6 ---------------------------------------------------------------
  -- Fusion réelle : c'est ce test qui protège le corps recopié de merge_book.
  PERFORM public.merge_book(v_lo, v_hi);

  IF EXISTS (SELECT 1 FROM public.books WHERE id = v_hi) THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le doublon existe encore après fusion.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = v_lo) THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : la notice canonique a disparu.';
  END IF;
  SELECT count(*) INTO v_n FROM public.merge_log
   WHERE entity_type = 'book' AND canonical_id = v_lo AND duplicate_id = v_hi
     AND merged_by = v_coord;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : la fusion n''est pas journalisée (% ligne(s)).', v_n;
  END IF;
  RAISE NOTICE 'TEST 6 OK — fusion exécutée de bout en bout et journalisée.';

  RAISE NOTICE '✅ DOUBLONS P4 : 8/8 tests verts.';
END $$;

ROLLBACK;
