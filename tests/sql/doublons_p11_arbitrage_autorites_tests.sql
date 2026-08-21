-- ============================================================
-- Tests d'acceptation paquet DOUBLONS P11 — « pas un doublon » (autorités)
-- ============================================================
-- Migration couverte : 20260821130004_pas_un_doublon_pour_les_autorites.sql
--
-- Ce que ces tests protègent avant tout : les DEUX détections doivent exclure
-- les mêmes paires. Si une seule le faisait, une paire écartée disparaîtrait
-- d'un écran et pas de l'autre — c'est exactement ce que `DEDUP-6` interdit, et
-- c'est le risque propre à ce paquet, qui touche deux fonctions à la fois. Les
-- tests 2 et 3 vérifient les deux vues séparément ; le test 6 vérifie que le
-- rétablissement les ramène toutes les deux.
--
-- 8 tests :
--   1. Une bibliothécaire ne peut pas écarter (42501).
--   2. La coordination écarte : la paire quitte le BALAYAGE GLOBAL.
--   3. Elle quitte AUSSI la détection par autorité.
--   4. Motif nettoyé, arbitre restitué par la liste.
--   5. Écarter clôt le signalement ouvert de la paire.
--   6. Rétablir ramène la paire dans les DEUX vues.
--   7. Une bibliothécaire ne peut pas rétablir (relevé ensemble, DEDUP-2).
--   8. L'ordre de la paire est normalisé (appel en ordre inverse accepté).
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH u_coord AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p11-coord-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), u_biblio AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p11-biblio-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), p_coord AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Coordination', 'P11' FROM u_coord RETURNING id
), p_biblio AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Bibliothecaire', 'P11' FROM u_biblio RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-p11-' || substr(gen_random_uuid()::text, 1, 8), 'Essai P11') RETURNING id
), m_coord AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_coord.id, lib.id, 'coordenador', 'active' FROM p_coord, lib RETURNING user_id
), m_biblio AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_biblio.id, lib.id, 'librarian', 'active' FROM p_biblio, lib RETURNING user_id
-- Deux autorités DIFFÉRENTES au nom proche : le faux positif type, celui qu'on
-- veut pouvoir écarter une fois pour toutes.
), a1 AS (
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Jean Grave P11', 'GRAVE P11, Jean') RETURNING id
), a2 AS (
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Jean Grav P11', 'GRAV P11, Jean') RETURNING id
)
SELECT (SELECT id FROM p_coord) AS uid_coord,
       (SELECT id FROM p_biblio) AS uid_biblio,
       (SELECT id FROM a1) AS a1, (SELECT id FROM a2) AS a2,
       (SELECT user_id FROM m_coord) AS ok1,
       (SELECT user_id FROM m_biblio) AS ok2;

DO $$
DECLARE
  v_coord uuid; v_biblio uuid;
  v_a bigint; v_b bigint; v_lo bigint; v_hi bigint;
  v_n int; v_txt text;
BEGIN
  SELECT uid_coord, uid_biblio, a1, a2 INTO v_coord, v_biblio, v_a, v_b FROM t_fix;
  IF v_coord IS NULL OR v_a IS NULL OR v_b IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;
  v_lo := least(v_a, v_b); v_hi := greatest(v_a, v_b);

  -- ══ Contexte BIBLIOTHÉCAIRE ═══════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_biblio, 'role', 'authenticated')::text, true);

  -- Point de départ : la paire est bien vue par les deux détections.
  SELECT count(*) INTO v_n FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'SETUP FAILED : la paire n''est pas détectée au départ par le balayage.';
  END IF;
  SELECT count(*) INTO v_n FROM public.suggest_author_duplicates(v_a) s WHERE s.author_id = v_b;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'SETUP FAILED : la paire n''est pas détectée au départ par autorité.';
  END IF;

  -- Elle est signalée, pour éprouver la clôture automatique (test 5).
  PERFORM public.report_authority_pair(v_a, v_b, 'a verifier');

  -- 1 ---------------------------------------------------------------
  BEGIN
    PERFORM public.mark_authors_not_duplicate(v_a, v_b, 'homonymes');
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : une bibliothécaire a pu écarter une paire.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 1 OK — écarter est refusé à une bibliothécaire.';
  END;

  -- 7 ---------------------------------------------------------------
  BEGIN
    PERFORM public.unmark_authors_not_duplicate(v_a, v_b);
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : une bibliothécaire a pu rétablir une paire.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 7 OK — rétablir est refusé aussi : les deux sont relevés ensemble.';
  END;

  -- ══ Contexte COORDINATION ═════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- 8 · 4 -----------------------------------------------------------
  -- Ordre inverse et motif entouré d'espaces.
  PERFORM public.mark_authors_not_duplicate(v_hi, v_lo, '  deux personnes distinctes  ');
  SELECT count(*) INTO v_n FROM public.author_not_duplicate
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : la paire n''a pas été normalisée (% ligne).', v_n;
  END IF;
  RAISE NOTICE 'TEST 8 OK — l''ordre de la paire est normalisé.';

  SELECT reason INTO v_txt FROM public.author_not_duplicate
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_txt IS DISTINCT FROM 'deux personnes distinctes' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : motif « % » — btrim fautif.', coalesce(v_txt, '(null)');
  END IF;
  SELECT created_by_name INTO v_txt FROM public.list_authors_not_duplicate(200)
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_txt IS DISTINCT FROM 'Coordination P11' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : arbitre « % ».', coalesce(v_txt, '(null)');
  END IF;
  RAISE NOTICE 'TEST 4 OK — motif nettoyé et arbitre restitué par la liste.';

  -- 5 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.authority_duplicate_reports
   WHERE author_id_a = v_lo AND author_id_b = v_hi AND status = 'open';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : le signalement est resté ouvert après arbitrage.';
  END IF;
  RAISE NOTICE 'TEST 5 OK — arbitrer clôt le signalement de la paire.';

  -- 2 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la paire écartée figure encore dans le balayage global.';
  END IF;
  RAISE NOTICE 'TEST 2 OK — la paire écartée quitte le balayage global.';

  -- 3 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.suggest_author_duplicates(v_a) s WHERE s.author_id = v_b;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : la paire écartée figure encore dans la détection par autorité — les deux vues divergent.';
  END IF;
  -- Et dans l'autre sens, car la détection par autorité n'est pas symétrique.
  SELECT count(*) INTO v_n FROM public.suggest_author_duplicates(v_b) s WHERE s.author_id = v_a;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : la paire réapparaît en interrogeant l''autre autorité.';
  END IF;
  RAISE NOTICE 'TEST 3 OK — la paire écartée quitte aussi la détection par autorité, dans les deux sens.';

  -- 6 ---------------------------------------------------------------
  PERFORM public.unmark_authors_not_duplicate(v_a, v_b);
  SELECT count(*) INTO v_n FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : la paire rétablie ne revient pas dans le balayage global.';
  END IF;
  SELECT count(*) INTO v_n FROM public.suggest_author_duplicates(v_a) s WHERE s.author_id = v_b;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : la paire rétablie ne revient pas dans la détection par autorité.';
  END IF;
  RAISE NOTICE 'TEST 6 OK — rétablir ramène la paire dans les deux vues.';

  RAISE NOTICE 'DOUBLONS-P11 OK : 8/8 tests passés';
END $$;

ROLLBACK;
