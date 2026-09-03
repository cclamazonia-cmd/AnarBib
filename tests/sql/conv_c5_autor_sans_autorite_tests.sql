-- ============================================================
-- Tests d'acceptation C5/B — le lot « autor_sans_autorite »
-- ============================================================
-- Migration couverte : 20260903150117_le_lot_des_auteurs_sans_autorite.sql
--
-- CE QUE CES TESTS PROTÈGENT. Ce lot ne réécrit pas un texte, il POSE UN LIEN
-- entre un livre et une autorité — et crée l'autorité au besoin. Les deux
-- risques sont donc : lier deux fois (une autorité doublon pour un nom qui
-- existait déjà), et lier à tort (un livre dont la transcription a changé, ou
-- qui a reçu une autorité entre-temps). Et un piège : proposer une autorité
-- pour « Anônimo ».
--
-- 8 tests :
--   1. Le semis n'entre que les livres SANS AUCUNE autorité liée — un livre dont
--      un contributeur porte déjà `author_id` n'y est pas ; un livre à contributeurs
--      nommés mais non liés y est.
--   2. La proposition de l'outil : premier nom de la chaîne ; rien pour « Anônimo ».
--   3. Un compte non staff est refusé (42501).
--   4. « valider » crée l'autorité (deux formes) et pose le lien sur le contributeur
--      homonyme — sans ligne de contributeur en double.
--   5. « valider » sur un livre sans contributeur crée la ligne, en position 1,
--      primaire.
--   6. « corriger » lie la valeur saisie ; si l'autorité existe déjà (sans casse),
--      elle est RÉUTILISÉE, pas dupliquée.
--   7. Anti-écrasement (CONV-O6) : transcription changée depuis le semis → rien,
--      et la ligne n'est pas marquée appliquée.
--   8. « écarter » n'écrit rien ; `conv_revue_list` rend `actuel` = la
--      transcription pour ce lot.
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'c5-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Revue', 'C5' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-c5-' || substr(gen_random_uuid()::text, 1, 8), 'Essai C5')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'librarian', 'active' FROM prof, lib
  RETURNING user_id
), a_existante AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Reclus, Élisée', 'Élisée Reclus') RETURNING id
-- Cinq livres : lié (hors lot) ; nommé non lié ; sans contributeur ; à corriger
-- vers une autorité existante ; anonyme ; et un sixième qui bougera.
), b_lie AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre déjà lié', 'Reclus, Élisée') RETURNING id
), c_lie AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b_lie.id, a_existante.id, 1, 'Reclus, Élisée', 'autor', true FROM b_lie, a_existante RETURNING book_id
), b_nomme AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre nommé non lié', 'Moissonnier, Maurice ; Pruvost, Georges') RETURNING id
), c_nomme AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b_nomme.id, NULL::bigint, 1, 'Moissonnier, Maurice', 'autor', true FROM b_nomme
  UNION ALL
  SELECT b_nomme.id, NULL::bigint, 2, 'Pruvost, Georges', 'autor', false FROM b_nomme
  RETURNING book_id
), b_vide AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre sans contributeur', 'BESNARD, Pierre') RETURNING id
), b_corrige AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre à corriger', 'RECLUS, Elisée') RETURNING id
), b_anonyme AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre anonyme', 'Anônimo') RETURNING id
), b_bouge AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre qui bouge', 'OITICICA, José') RETURNING id
)
SELECT (SELECT id FROM prof)        AS uid,
       (SELECT id FROM a_existante) AS id_reclus,
       (SELECT id FROM b_lie)       AS b_lie,
       (SELECT id FROM b_nomme)     AS b_nomme,
       (SELECT id FROM b_vide)      AS b_vide,
       (SELECT id FROM b_corrige)   AS b_corrige,
       (SELECT id FROM b_anonyme)   AS b_anonyme,
       (SELECT id FROM b_bouge)     AS b_bouge,
       (SELECT count(*) FROM c_lie) + (SELECT count(*) FROM c_nomme) AS contribs;

DO $$
DECLARE
  v_uid      uuid;
  v_reclus   bigint;
  v_lie      bigint;
  v_nomme    bigint;
  v_vide     bigint;
  v_corrige  bigint;
  v_anonyme  bigint;
  v_bouge    bigint;
  v_n        bigint;
  v_txt      text;
  v_app      bigint;
  v_ref      bigint;
  v_author   bigint;
  v_authors_avant bigint;
BEGIN
  SELECT uid, id_reclus, b_lie, b_nomme, b_vide, b_corrige, b_anonyme, b_bouge
    INTO v_uid, v_reclus, v_lie, v_nomme, v_vide, v_corrige, v_anonyme, v_bouge FROM t_fix;
  IF v_uid IS NULL OR v_reclus IS NULL OR v_bouge IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- Contexte staff : le semis comme l'application y sont réservés.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- 1 ----------------------------------------------------------------
  PERFORM public.fn_conv_lot_autor_sans_autorite_seed();
  SELECT count(*) INTO v_n FROM public.catalog_review_queue
   WHERE lot = 'autor_sans_autorite' AND entity_id = v_lie;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : un livre déjà lié à une autorité est entré dans le lot.';
  END IF;
  SELECT count(*) INTO v_n FROM public.catalog_review_queue
   WHERE lot = 'autor_sans_autorite' AND entity_id IN (v_nomme, v_vide, v_corrige, v_anonyme, v_bouge);
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : 5 livres sans autorité attendus dans le lot, obtenu %.', v_n;
  END IF;
  -- Rejouable : un second semis n'ajoute rien.
  SELECT public.fn_conv_lot_autor_sans_autorite_seed() INTO v_n;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : le second semis a inséré % ligne(s).', v_n;
  END IF;
  RAISE NOTICE 'TEST 1 OK — le semis ne prend que les livres sans autorité, et ne rejoue pas.';

  -- 2 ----------------------------------------------------------------
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue
   WHERE lot = 'autor_sans_autorite' AND entity_id = v_nomme;
  IF v_txt IS DISTINCT FROM 'Moissonnier, Maurice' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : proposition attendue « Moissonnier, Maurice », obtenu « % ».', v_txt;
  END IF;
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue
   WHERE lot = 'autor_sans_autorite' AND entity_id = v_anonyme;
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : « Anônimo » a reçu une proposition (« % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 2 OK — premier nom proposé, rien pour l''anonyme.';

  -- 3 ----------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM api.conv_revue_appliquer('autor_sans_autorite');
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : un compte non staff a appliqué des verdicts.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 3 OK — application refusée à un compte non staff.';
  END;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- Les verdicts, par la porte officielle.
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autor_sans_autorite' AND entity_id = v_nomme), 'valide', NULL, NULL);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autor_sans_autorite' AND entity_id = v_vide), 'valide', NULL, NULL);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autor_sans_autorite' AND entity_id = v_corrige), 'corrige', 'reclus, élisée', NULL);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autor_sans_autorite' AND entity_id = v_anonyme), 'ecarte', NULL, NULL);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autor_sans_autorite' AND entity_id = v_bouge), 'valide', NULL, NULL);
  -- Le livre « bouge » a été recatalogué entre-temps : sa transcription a changé.
  UPDATE public.books SET autor = 'Oiticica, José' WHERE id = v_bouge;

  SELECT count(*) INTO v_authors_avant FROM public.authors;
  SELECT applique, refuse INTO v_app, v_ref FROM api.conv_revue_appliquer('autor_sans_autorite');

  -- 4 ----------------------------------------------------------------
  SELECT c.author_id INTO v_author FROM public.book_contributors c
   WHERE c.book_id = v_nomme AND c.name = 'Moissonnier, Maurice';
  IF v_author IS NULL THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : le contributeur homonyme n''a pas reçu d''autorité.';
  END IF;
  SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = v_nomme;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : ligne de contributeur en double (attendu 2, obtenu %).', v_n;
  END IF;
  SELECT preferred_name INTO v_txt FROM public.authors WHERE id = v_author;
  IF v_txt IS DISTINCT FROM 'Maurice Moissonnier' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : forme d''affichage attendue « Maurice Moissonnier », obtenu « % ».', v_txt;
  END IF;
  RAISE NOTICE 'TEST 4 OK — autorité créée aux deux formes, lien posé sur l''homonyme, pas de doublon.';

  -- 5 ----------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.book_contributors c
   WHERE c.book_id = v_vide AND c.author_id IS NOT NULL AND c.position = 1 AND c.is_primary AND c.role = 'autor';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : le livre sans contributeur n''a pas reçu sa ligne primaire en position 1.';
  END IF;
  RAISE NOTICE 'TEST 5 OK — ligne de contributeur créée, primaire, position 1.';

  -- 6 ----------------------------------------------------------------
  SELECT c.author_id INTO v_author FROM public.book_contributors c WHERE c.book_id = v_corrige;
  IF v_author IS DISTINCT FROM v_reclus THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : « reclus, élisée » devait retrouver l''autorité existante % (obtenu %).', v_reclus, v_author;
  END IF;
  SELECT count(*) INTO v_n FROM public.authors WHERE lower(sort_name) = 'reclus, élisée';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : autorité dupliquée pour Reclus (% fiches).', v_n;
  END IF;
  RAISE NOTICE 'TEST 6 OK — la correction réutilise l''autorité existante, sans casse.';

  -- 7 ----------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = v_bouge;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : un livre dont la transcription a changé a été lié.';
  END IF;
  SELECT applique_le::text INTO v_txt FROM public.catalog_review_queue
   WHERE lot = 'autor_sans_autorite' AND entity_id = v_bouge;
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : la ligne périmée a été marquée appliquée.';
  END IF;
  IF v_ref < 1 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : le compteur « refusées » devait valoir au moins 1 (obtenu %).', v_ref;
  END IF;
  RAISE NOTICE 'TEST 7 OK — transcription changée : rien d''écrit, ligne toujours en attente.';

  -- 8 ----------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = v_anonyme;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : « écarter » a écrit un contributeur.';
  END IF;
  SELECT l.actuel INTO v_txt FROM api.conv_revue_list('autor_sans_autorite', NULL, 200, 0) l
   WHERE l.entity_id = v_bouge;
  IF v_txt IS DISTINCT FROM 'Oiticica, José' THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : « actuel » devait être la transcription courante (obtenu « % »).', v_txt;
  END IF;
  SELECT (SELECT count(*) FROM public.authors) - v_authors_avant INTO v_n;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : 2 autorités neuves attendues (Moissonnier, Besnard), obtenu %.', v_n;
  END IF;
  RAISE NOTICE 'TEST 8 OK — écarter n''écrit rien ; « actuel » est la transcription.';

  RAISE NOTICE 'CONV-C5 OK : 8/8 tests passés (appliquées=%, refusées=%).', v_app, v_ref;
END $$;

ROLLBACK;
