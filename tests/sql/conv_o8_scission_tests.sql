-- ============================================================
-- Tests d'acceptation CONV-O8 — scission d'autorité
-- ============================================================
-- Migration couverte : 20260821210000_conventions_17_scission_autorite.sql
--
-- CE QUE CES TESTS PROTÈGENT. La scission crée des fiches dans le corpus
-- PARTAGÉ et recopie des liaisons de livres. Une erreur ici ne se voit pas
-- tout de suite : elle se voit trois mois plus tard, sous la forme d'un
-- livre attribué à quelqu'un qui ne l'a pas écrit, dans le catalogue public
-- de plusieurs bibliothèques. Et contrairement à la casse, ça ne se répare
-- pas d'un UPDATE — il faut refaire le travail à la main.
--
-- Les deux tests qui comptent le plus :
--   · le 6, qui garde la clé primaire (book_id, author_id, role, ord) quand
--     la fiche composée figure DEUX FOIS sur le même livre. Un `max(ord)+1`
--     seul donnerait deux fois la même valeur et l'insertion sauterait ;
--   · le 8, qui garde `book_contributors.name` — une COPIE du nom, pas une
--     jointure. Sans lui, l'autorité serait scindée et le livre continuerait
--     d'afficher le nom composé, ce qui est le plus discret des échecs.
--
-- 10 tests :
--   1. Un non-contributeur ne peut pas proposer (42501).
--   2. Une scission à moins de deux parts est refusée.
--   3. Une part sans nom de tri est refusée.
--   4. Une part qui porte le nom d'une AUTRE fiche existante est refusée,
--      en nommant la fiche — on ne rattache pas d'autorité à sa place.
--   5. Deux parts identiques entre elles sont refusées.
--   6. L'application crée les fiches manquantes et recopie les liaisons,
--      y compris quand l'originale figure deux fois sur le même livre.
--   7. La fiche d'origine est CONSERVÉE (même id) et renommée.
--   8. `book_contributors.name` suit, pour toutes les parts.
--   9. Le champ libre `books.autor` est recomposé s'il portait l'ancien nom,
--      et laissé intact s'il dit autre chose (saisie humaine).
--  10. Une fiche modifiée depuis la proposition n'est PAS écrasée.
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'o8-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Scission', 'O8' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-o8-' || substr(gen_random_uuid()::text, 1, 8), 'Essai O8')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'coordenador', 'active' FROM prof, lib
  RETURNING user_id
-- La fiche composée : « Postmortem » est de William Young ET David E. Kaiser.
-- L'import en a fait un seul Kaiser à deux prénoms.
), a_comp AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('KAISER, William Young and David E.', 'William Young and David E. KAISER')
  RETURNING id
-- Une fiche qui existe déjà et dont une part voudrait prendre le nom.
), a_occupe AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Occupé, Nom Déjà', 'Nom Déjà Occupé')
  RETURNING id
), b_un AS (
  INSERT INTO public.books (titulo, autor, ano)
  VALUES ('Postmortem', 'KAISER, William Young and David E.', '1985')
  RETURNING id
-- Deuxième livre : la fiche composée y figure DEUX fois, avec deux rôles.
-- C'est le cas qui casse un `max(ord)+1` naïf.
), b_deux AS (
  INSERT INTO public.books (titulo, autor, ano)
  VALUES ('Recueil à deux rôles', 'Saisie humaine differente', '1990')
  RETURNING id
), ba1 AS (
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
  SELECT b_un.id, a_comp.id, 'autor', 1 FROM b_un, a_comp RETURNING book_id
), ba2 AS (
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
  SELECT b_deux.id, a_comp.id, 'autor', 1 FROM b_deux, a_comp RETURNING book_id
), ba3 AS (
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
  SELECT b_deux.id, a_comp.id, 'organizador', 2 FROM b_deux, a_comp RETURNING book_id
), bc1 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role)
  SELECT b_un.id, a_comp.id, 1, 'Kaiser, William Young and David E.', 'autor'
  FROM b_un, a_comp RETURNING id
)
SELECT (SELECT id FROM prof)     AS uid,
       (SELECT id FROM a_comp)   AS id_comp,
       (SELECT id FROM a_occupe) AS id_occupe,
       (SELECT id FROM b_un)     AS id_livre1,
       (SELECT id FROM b_deux)   AS id_livre2,
       (SELECT user_id FROM memb) AS memb_ok;

DO $$
DECLARE
  v_uid    uuid;
  v_comp   bigint;
  v_occupe bigint;
  v_livre1 bigint;
  v_livre2 bigint;
  v_prop   uuid;
  v_parts  jsonb;
  v_txt    text;
  v_n      int;
BEGIN
  SELECT uid, id_comp, id_occupe, id_livre1, id_livre2
    INTO v_uid, v_comp, v_occupe, v_livre1, v_livre2 FROM t_fix;
  IF v_uid IS NULL OR v_comp IS NULL OR v_livre2 IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- Le découpage JUSTE, celui qu'aucune fonction ne pouvait deviner :
  -- ce n'est pas deux Kaiser, c'est William Young et David E. Kaiser.
  v_parts := jsonb_build_object('parts', jsonb_build_array(
    jsonb_build_object('preferred_name', 'William Young',    'sort_name', 'Young, William',    'authority_type', 'person'),
    jsonb_build_object('preferred_name', 'David E. Kaiser',  'sort_name', 'Kaiser, David E.',  'authority_type', 'person')));

  -- 1 ----------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM api.fn_authority_propose('scission', 'author', v_comp, NULL, v_parts, 'essai');
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : un non-contributeur a proposé une scission.';
  EXCEPTION WHEN raise_exception THEN
    -- `raise exception 'forbidden'` sans ERRCODE : c'est P0001, pas 42501.
    -- On vérifie donc le message, sans quoi ce test attraperait n'importe
    -- quelle autre erreur et passerait au vert pour de mauvaises raisons.
    IF sqlerrm LIKE 'TEST 1 ÉCHOUÉ%' THEN RAISE; END IF;
    IF sqlerrm NOT LIKE '%forbidden%' THEN
      RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : refusée, mais pas pour la bonne raison (%).', sqlerrm;
    END IF;
    RAISE NOTICE 'TEST 1 OK — proposition refusée à un non-contributeur.';
  END;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- 2 ----------------------------------------------------------------
  BEGIN
    PERFORM api.fn_authority_propose('scission', 'author', v_comp, NULL,
      jsonb_build_object('parts', jsonb_build_array(
        jsonb_build_object('preferred_name', 'Seul', 'sort_name', 'Seul, Un'))), 'essai');
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : une scission à une seule part a été acceptée.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 2 ÉCHOUÉ%' THEN RAISE; END IF;
    RAISE NOTICE 'TEST 2 OK — scission à moins de deux parts refusée.';
  END;

  -- 3 ----------------------------------------------------------------
  BEGIN
    PERFORM api.fn_authority_propose('scission', 'author', v_comp, NULL,
      jsonb_build_object('parts', jsonb_build_array(
        jsonb_build_object('preferred_name', 'William Young', 'sort_name', 'Young, William'),
        jsonb_build_object('preferred_name', 'Sans tri',      'sort_name', '   '))), 'essai');
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : une part sans nom de tri a été acceptée.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 3 ÉCHOUÉ%' THEN RAISE; END IF;
    RAISE NOTICE 'TEST 3 OK — part incomplète refusée.';
  END;

  -- 4 ----------------------------------------------------------------
  BEGIN
    PERFORM api.fn_authority_propose('scission', 'author', v_comp, NULL,
      jsonb_build_object('parts', jsonb_build_array(
        jsonb_build_object('preferred_name', 'William Young',   'sort_name', 'Young, William'),
        jsonb_build_object('preferred_name', 'Nom Déjà Occupé', 'sort_name', 'Occupé, Nom Déjà'))), 'essai');
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : une part a pris le nom d''une fiche existante.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 4 ÉCHOUÉ%' THEN RAISE; END IF;
    IF sqlerrm NOT LIKE '%scission_part_exists%' THEN
      RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : refusée, mais pas pour la bonne raison (%).', sqlerrm;
    END IF;
    RAISE NOTICE 'TEST 4 OK — collision avec une fiche existante refusée et nommée.';
  END;

  -- 5 ----------------------------------------------------------------
  BEGIN
    PERFORM api.fn_authority_propose('scission', 'author', v_comp, NULL,
      jsonb_build_object('parts', jsonb_build_array(
        jsonb_build_object('preferred_name', 'William Young', 'sort_name', 'Young, William'),
        jsonb_build_object('preferred_name', 'William Young', 'sort_name', 'Young, William'))), 'essai');
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : deux parts identiques ont été acceptées.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 5 ÉCHOUÉ%' THEN RAISE; END IF;
    RAISE NOTICE 'TEST 5 OK — parts identiques refusées.';
  END;

  -- La proposition valide, menée jusqu'à l'application.
  v_prop := api.fn_authority_propose('scission', 'author', v_comp, NULL, v_parts,
    'Postmortem est de William Young et David E. Kaiser : l''import a fabriqué un seul Kaiser.');
  UPDATE public.authority_proposals
     SET status = 'resolved_consent', resolved_at = now() WHERE id = v_prop;
  PERFORM api.fn_authority_apply(v_prop);

  -- 7 ----------------------------------------------------------------
  SELECT sort_name INTO v_txt FROM public.authors WHERE id = v_comp;
  IF v_txt IS NULL THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : la fiche d''origine a disparu — son public_id '
                    'et les adresses qui pointaient dessus avec elle.';
  END IF;
  IF v_txt <> 'Young, William' THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : la fiche d''origine n''a pas été renommée (« % »).', v_txt;
  END IF;
  SELECT count(*) INTO v_n FROM public.authors WHERE sort_name = 'Kaiser, David E.';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : la seconde part n''a pas été créée (obtenu %).', v_n;
  END IF;
  RAISE NOTICE 'TEST 7 OK — fiche d''origine conservée et renommée, seconde part créée.';

  -- 6 ----------------------------------------------------------------
  SELECT count(*) INTO v_n
    FROM public.book_authors ba
    JOIN public.authors a ON a.id = ba.author_id
   WHERE ba.book_id = v_livre1 AND a.sort_name IN ('Young, William', 'Kaiser, David E.');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le livre simple devrait porter les 2 parts (obtenu %).', v_n;
  END IF;
  -- Le livre où l'originale figurait deux fois : 2 rôles x 2 parts = 4.
  SELECT count(*) INTO v_n
    FROM public.book_authors ba
    JOIN public.authors a ON a.id = ba.author_id
   WHERE ba.book_id = v_livre2 AND a.sort_name IN ('Young, William', 'Kaiser, David E.');
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le livre à deux rôles devrait porter 4 liaisons '
                    '(2 rôles x 2 parts), obtenu %. Une collision de clé primaire a '
                    'probablement fait sauter une insertion en silence.', v_n;
  END IF;
  RAISE NOTICE 'TEST 6 OK — liaisons recopiées, y compris sur le livre à deux rôles.';

  -- 8 ----------------------------------------------------------------
  SELECT count(*) INTO v_n
    FROM public.book_contributors
   WHERE book_id = v_livre1 AND name = 'Kaiser, William Young and David E.';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : le nom composé subsiste dans book_contributors — '
                    'l''autorité est scindée mais le livre affiche encore l''ancien nom.';
  END IF;
  SELECT count(*) INTO v_n
    FROM public.book_contributors
   WHERE book_id = v_livre1 AND name IN ('William Young', 'David E. Kaiser');
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : les deux noms de parts devraient figurer (obtenu %).', v_n;
  END IF;
  RAISE NOTICE 'TEST 8 OK — les noms recopiés suivent la scission.';

  -- 9 ----------------------------------------------------------------
  SELECT autor INTO v_txt FROM public.books WHERE id = v_livre1;
  IF v_txt <> 'Young, William ; Kaiser, David E.' THEN
    RAISE EXCEPTION 'TEST 9 ÉCHOUÉ : books.autor non recomposé (« % »).', v_txt;
  END IF;
  SELECT autor INTO v_txt FROM public.books WHERE id = v_livre2;
  IF v_txt <> 'Saisie humaine differente' THEN
    RAISE EXCEPTION 'TEST 9 ÉCHOUÉ : une saisie humaine a été écrasée (« % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 9 OK — champ libre recomposé, saisie humaine préservée.';

  -- 10 ---------------------------------------------------------------
  -- Nouvelle proposition sur la fiche, puis la fiche bouge avant
  -- l'application : quelqu'un d'autre est passé par là pendant les
  -- quatorze jours de délibération.
  v_prop := api.fn_authority_propose('scission', 'author', v_comp, NULL,
    jsonb_build_object('parts', jsonb_build_array(
      jsonb_build_object('preferred_name', 'Un',   'sort_name', 'Un, Part'),
      jsonb_build_object('preferred_name', 'Deux', 'sort_name', 'Deux, Part'))), 'essai');
  UPDATE public.authority_proposals
     SET status = 'resolved_consent', resolved_at = now() WHERE id = v_prop;
  UPDATE public.authors SET sort_name = 'Young, William W.' WHERE id = v_comp;
  BEGIN
    PERFORM api.fn_authority_apply(v_prop);
    RAISE EXCEPTION 'TEST 10 ÉCHOUÉ : une fiche modifiée depuis la proposition a été scindée.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 10 ÉCHOUÉ%' THEN RAISE; END IF;
    IF sqlerrm NOT LIKE '%split_target_changed%' THEN
      RAISE EXCEPTION 'TEST 10 ÉCHOUÉ : refusée, mais pas pour la bonne raison (%).', sqlerrm;
    END IF;
    RAISE NOTICE 'TEST 10 OK — fiche modifiée depuis la proposition : refus d''écrire.';
  END;

  RAISE NOTICE 'CONV-O8 OK : 10/10 tests passés.';
END $$;

ROLLBACK;
