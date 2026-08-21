-- ============================================================
-- Tests d'acceptation paquet DOUBLONS P7 — reprise de champs avant fusion
-- ============================================================
-- Migration couverte : 20260821100001_reprendre_les_champs_avant_de_fusionner.sql
--
-- Ce que ces tests protègent : la reprise de champs existe pour éviter une
-- perte. Une reprise qui échouerait EN SILENCE serait pire que pas de reprise
-- du tout — on croirait la donnée sauvée alors qu'elle est détruite. D'où les
-- tests 2 et 3, qui vérifient qu'un champ mal nommé ou non reprenable lève une
-- erreur, et le test 5, qui vérifie qu'on ne reprend QUE ce qui est demandé.
--
-- 7 tests :
--   1. Une bibliothécaire ne peut pas fusionner avec reprise (42501).
--   2. Un champ inexistant lève une erreur, il n'est pas ignoré.
--   3. Un champ non reprenable (`bib_ref`, index unique) lève une erreur.
--   4. Les champs demandés passent bien sur la canonique (éditeur, couverture).
--   5. Un champ NON demandé n'est pas repris — la reprise est un choix.
--   6. La délégation a lieu : le doublon disparaît et la fusion est journalisée.
--   7. Sans reprise (tableau vide), la fusion se comporte comme avant.
--
-- Fixtures fabriquées ici, identifiants tirés au hasard, tout est annulé par le
-- ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH u_coord AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p7-coord-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), u_biblio AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p7-biblio-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), p_coord AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Coordination', 'P7' FROM u_coord RETURNING id
), p_biblio AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Bibliothecaire', 'P7' FROM u_biblio RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-p7-' || substr(gen_random_uuid()::text, 1, 8), 'Essai P7')
  RETURNING id
), m_coord AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_coord.id, lib.id, 'coordenador', 'active' FROM p_coord, lib RETURNING user_id
), m_biblio AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_biblio.id, lib.id, 'librarian', 'active' FROM p_biblio, lib RETURNING user_id
-- Paire 1 : la canonique est pauvre, le doublon porte éditeur, couverture et
-- notes. C'est exactement le cas qui faisait perdre de l'information.
), canon1 AS (
  INSERT INTO public.books (titulo, autor, ano)
  VALUES ('Deus e o Estado', 'BAKUNIN, Mikhail', '1882') RETURNING id
), dup1 AS (
  INSERT INTO public.books (titulo, autor, ano, editora, cover_object_path, notas)
  VALUES ('Deus e o Estado', 'BAKUNIN, Mikhail', '1882',
          'Imprensa Anarquista', 'capas/p7-deus-e-o-estado.jpg',
          'exemplaire annote a la main')
  RETURNING id
-- Paire 2 : pour la fusion sans reprise.
), canon2 AS (
  INSERT INTO public.books (titulo, autor, ano)
  VALUES ('A Moral Anarquista', 'KROPOTKIN, Piotr', '1890') RETURNING id
), dup2 AS (
  INSERT INTO public.books (titulo, autor, ano, editora)
  VALUES ('A Moral Anarquista', 'KROPOTKIN, Piotr', '1890', 'Editora Perdida')
  RETURNING id
)
SELECT (SELECT id FROM p_coord)  AS uid_coord,
       (SELECT id FROM p_biblio) AS uid_biblio,
       (SELECT id FROM canon1)   AS canon1,
       (SELECT id FROM dup1)     AS dup1,
       (SELECT id FROM canon2)   AS canon2,
       (SELECT id FROM dup2)     AS dup2,
       (SELECT user_id FROM m_coord)  AS ok1,
       (SELECT user_id FROM m_biblio) AS ok2;

DO $$
DECLARE
  v_coord  uuid;
  v_biblio uuid;
  v_c1 bigint; v_d1 bigint;
  v_c2 bigint; v_d2 bigint;
  v_txt text;
  v_n   int;
BEGIN
  SELECT uid_coord, uid_biblio, canon1, dup1, canon2, dup2
    INTO v_coord, v_biblio, v_c1, v_d1, v_c2, v_d2 FROM t_fix;
  IF v_coord IS NULL OR v_c1 IS NULL OR v_d2 IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 1 ---------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_biblio, 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.merge_book_with_fields(v_c1, v_d1, ARRAY['editora']);
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : une bibliothécaire a pu fusionner avec reprise.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 1 OK — reprise refusée à une bibliothécaire.';
  END;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- 2 ---------------------------------------------------------------
  BEGIN
    PERFORM public.merge_book_with_fields(v_c1, v_d1, ARRAY['editoraa']);
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : un champ inexistant a été accepté.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 2 ÉCHOUÉ%' THEN RAISE; END IF;
    RAISE NOTICE 'TEST 2 OK — un champ inexistant lève une erreur.';
  END;

  -- 3 ---------------------------------------------------------------
  BEGIN
    PERFORM public.merge_book_with_fields(v_c1, v_d1, ARRAY['bib_ref']);
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : bib_ref a été accepté à la reprise.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 3 ÉCHOUÉ%' THEN RAISE; END IF;
    RAISE NOTICE 'TEST 3 OK — un champ non reprenable lève une erreur.';
  END;

  -- Rien n'a dû fusionner jusqu'ici : les erreurs ci-dessus doivent avoir
  -- annulé leur propre appel, pas la transaction de test.
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = v_d1) THEN
    RAISE EXCEPTION 'SETUP FAILED : le doublon 1 a disparu avant la fusion attendue.';
  END IF;

  -- 4 · 5 · 6 -------------------------------------------------------
  -- On reprend l'éditeur et la couverture, PAS les notes.
  PERFORM public.merge_book_with_fields(v_c1, v_d1, ARRAY['editora', 'cover_object_path']);

  SELECT editora INTO v_txt FROM public.books WHERE id = v_c1;
  IF v_txt IS DISTINCT FROM 'Imprensa Anarquista' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : éditeur non repris (« % »).', coalesce(v_txt, '(null)');
  END IF;
  SELECT cover_object_path INTO v_txt FROM public.books WHERE id = v_c1;
  IF v_txt IS DISTINCT FROM 'capas/p7-deus-e-o-estado.jpg' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : couverture non reprise (« % »).', coalesce(v_txt, '(null)');
  END IF;
  RAISE NOTICE 'TEST 4 OK — éditeur et couverture repris sur la fiche conservée.';

  SELECT notas INTO v_txt FROM public.books WHERE id = v_c1;
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : un champ non demandé a été repris (« % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 5 OK — un champ non demandé n''est pas repris.';

  IF EXISTS (SELECT 1 FROM public.books WHERE id = v_d1) THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le doublon existe encore — la délégation n''a pas eu lieu.';
  END IF;
  SELECT count(*) INTO v_n FROM public.merge_log
   WHERE entity_type = 'book' AND canonical_id = v_c1 AND duplicate_id = v_d1;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : fusion non journalisée (% ligne(s)).', v_n;
  END IF;
  RAISE NOTICE 'TEST 6 OK — la délégation à merge_book fusionne et journalise.';

  -- 7 ---------------------------------------------------------------
  PERFORM public.merge_book_with_fields(v_c2, v_d2, '{}'::text[]);
  SELECT editora INTO v_txt FROM public.books WHERE id = v_c2;
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : reprise effectuée sans qu''on la demande (« % »).', v_txt;
  END IF;
  IF EXISTS (SELECT 1 FROM public.books WHERE id = v_d2) THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : sans reprise, la fusion n''a pas eu lieu.';
  END IF;
  RAISE NOTICE 'TEST 7 OK — sans reprise, la fusion se comporte comme avant.';

  RAISE NOTICE 'DOUBLONS-P7 OK : 7/7 tests passés';
END $$;

ROLLBACK;
