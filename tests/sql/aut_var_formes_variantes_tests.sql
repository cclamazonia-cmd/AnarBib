-- ============================================================
-- Tests AUT-VAR — les formes variantes d'une autorité servent
-- ============================================================
-- Migration couverte : 20261012145418_les_formes_variantes_rattachent_les_oeuvres.sql
--
-- Le cas d'origine (12/10/2026) : « Serge Netchaïev » portait « Serguei
-- Netchaev » dans « Formes variantes » et ses graphies Wikidata ; l'ouvrage au
-- contributeur « Netchaev » restait introuvable par « Rattacher aux œuvres ».
--
-- 8 tests :
--   1. Une graphie Wikidata ({"fr": [...]}) rattache un contributeur (exact).
--   2. « Formes variantes » saisies à la main (, et ;) rattachent (exact).
--   3. « Pseudonymes » rattachent aussi (exact).
--   4. variant_forms en tableau de {form} (fusions) rattache (exact).
--   5. Deux fiches au même VIAF (Wikidata avant le 20/10), noms sans rapport : la détection par
--      autorité les voit, dans les deux sens.
--   6. Le balayage global les voit aussi, au niveau « identifiant » (DEDUP-6).
--   7. Une paire écartée (« pas un doublon ») reste écartée des deux vues.
--   8. Publier un brouillon sans graphies ne vide pas celles de l'autorité.
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH u_coord AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'autvar-coord-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), p_coord AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Coordination', 'AUTVAR' FROM u_coord RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-autvar-' || substr(gen_random_uuid()::text, 1, 8), 'Essai AUT-VAR') RETURNING id
), m_coord AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_coord.id, lib.id, 'coordenador', 'active' FROM p_coord, lib RETURNING user_id
), a_wd AS (
  INSERT INTO public.authors (preferred_name, sort_name, variant_forms, structured_meta)
  VALUES ('Serge Zvarkiev', 'Zvarkiev, Serge',
          '{"fr": ["Zvarkiev"], "es": ["Zvarkof"]}'::jsonb,
          '{"variantNames": "Sergueï Guennadievitch Zvarkiev, Serguei Zvarquev ; Zvarkieff", "pseudonyms": "Qwolpin"}'::jsonb)
  RETURNING id
), a_fus AS (
  INSERT INTO public.authors (preferred_name, sort_name, variant_forms)
  VALUES ('Emma Plovdinsk', 'Plovdinsk, Emma',
          '[{"form": "Plowdinska, E.", "source": "fusion essai"}]'::jsonb)
  RETURNING id
), a_id1 AS (
  -- 20/10/2026 : un Wikidata ne se pose plus sur deux fiches (index unique,
  -- 20261020174755) ; la paire partage donc un VIAF, que les deux détections
  -- comparent de la même façon.
  INSERT INTO public.authors (preferred_name, sort_name, viaf_id)
  VALUES ('Brunhilde Okkervil', 'Okkervil, Brunhilde', '987654321') RETURNING id
), a_id2 AS (
  INSERT INTO public.authors (preferred_name, sort_name, viaf_id)
  VALUES ('Tchoung Mavlast', 'Mavlast, Tchoung', '987654321') RETURNING id
), b AS (
  INSERT INTO public.books (titulo, autor)
  VALUES ('Livre AUT-VAR', 'Zvarkof ; Serguei Zvarquev ; Qwolpin ; Plowdinska, E.') RETURNING id
), c AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b.id, NULL::bigint, 1, 'Zvarkof', 'autor', true FROM b
  UNION ALL SELECT b.id, NULL::bigint, 2, 'Serguei Zvarquev', 'autor', false FROM b
  UNION ALL SELECT b.id, NULL::bigint, 3, 'Qwolpin', 'autor', false FROM b
  UNION ALL SELECT b.id, NULL::bigint, 4, 'Plowdinska, E.', 'autor', false FROM b
  RETURNING book_id
)
SELECT (SELECT id FROM p_coord) AS uid_coord,
       (SELECT id FROM a_wd) AS a_wd, (SELECT id FROM a_fus) AS a_fus,
       (SELECT id FROM a_id1) AS a_id1, (SELECT id FROM a_id2) AS a_id2,
       (SELECT id FROM b) AS book,
       (SELECT user_id FROM m_coord) AS ok1,
       (SELECT count(*) FROM c) AS n_c;

DO $$
DECLARE
  v_coord uuid;
  v_wd bigint; v_fus bigint; v_i1 bigint; v_i2 bigint; v_book bigint;
  v_n int; v_txt text; v_draft bigint; v_vf jsonb;
BEGIN
  SELECT uid_coord, a_wd, a_fus, a_id1, a_id2, book
    INTO v_coord, v_wd, v_fus, v_i1, v_i2, v_book FROM t_fix;
  IF v_coord IS NULL OR v_wd IS NULL OR v_book IS NULL OR (SELECT n_c FROM t_fix) <> 4 THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- 1 ---------------------------------------------------------------
  SELECT match_kind INTO v_txt FROM public.suggest_author_book_matches(v_wd) m
   WHERE m.book_id = v_book AND m.contributor_name = 'Zvarkof';
  IF v_txt IS DISTINCT FROM 'exact' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : graphie Wikidata « Zvarkof » → %.', coalesce(v_txt, 'introuvable');
  END IF;
  RAISE NOTICE 'TEST 1 OK — une graphie Wikidata (objet par langue) rattache le contributeur.';

  -- 2 ---------------------------------------------------------------
  SELECT match_kind INTO v_txt FROM public.suggest_author_book_matches(v_wd) m
   WHERE m.book_id = v_book AND m.contributor_name = 'Serguei Zvarquev';
  IF v_txt IS DISTINCT FROM 'exact' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : forme variante saisie « Serguei Zvarquev » → %.', coalesce(v_txt, 'introuvable');
  END IF;
  RAISE NOTICE 'TEST 2 OK — les formes variantes saisies (découpées sur , et ;) rattachent.';

  -- 3 ---------------------------------------------------------------
  SELECT match_kind INTO v_txt FROM public.suggest_author_book_matches(v_wd) m
   WHERE m.book_id = v_book AND m.contributor_name = 'Qwolpin';
  IF v_txt IS DISTINCT FROM 'exact' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : pseudonyme « Qwolpin » → %.', coalesce(v_txt, 'introuvable');
  END IF;
  RAISE NOTICE 'TEST 3 OK — les pseudonymes rattachent.';

  -- 4 ---------------------------------------------------------------
  SELECT match_kind INTO v_txt FROM public.suggest_author_book_matches(v_fus) m
   WHERE m.book_id = v_book AND m.contributor_name = 'Plowdinska, E.';
  IF v_txt IS DISTINCT FROM 'exact' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : variant_forms en tableau de {form} → %.', coalesce(v_txt, 'introuvable');
  END IF;
  RAISE NOTICE 'TEST 4 OK — variant_forms en tableau de {form} (fusions) rattache.';

  -- 5 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.suggest_author_duplicates(v_i1) s
   WHERE s.author_id = v_i2 AND s.match_kind = 'exact';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : même VIAF, la détection par autorité ne voit pas la paire.';
  END IF;
  SELECT count(*) INTO v_n FROM public.suggest_author_duplicates(v_i2) s WHERE s.author_id = v_i1;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : la paire n''est pas vue depuis l''autre fiche.';
  END IF;
  RAISE NOTICE 'TEST 5 OK — même VIAF, noms sans rapport : la détection par autorité voit la paire.';

  -- 6 ---------------------------------------------------------------
  SELECT niveau_preuve INTO v_txt FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = least(v_i1, v_i2) AND author_id_b = greatest(v_i1, v_i2);
  IF v_txt IS DISTINCT FROM 'identifiant' THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le balayage global rend % pour la paire au même VIAF.', coalesce(v_txt, 'rien');
  END IF;
  RAISE NOTICE 'TEST 6 OK — le balayage global la voit aussi, au niveau « identifiant ».';

  -- 7 ---------------------------------------------------------------
  INSERT INTO public.author_not_duplicate (author_id_a, author_id_b, reason, created_by)
  VALUES (least(v_i1, v_i2), greatest(v_i1, v_i2), 'essai AUT-VAR', v_coord);
  SELECT count(*) INTO v_n FROM public.suggest_author_duplicates(v_i1) s WHERE s.author_id = v_i2;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : la paire écartée revient dans la détection par autorité.';
  END IF;
  SELECT count(*) INTO v_n FROM public.suggest_authority_duplicates(500)
   WHERE author_id_a = least(v_i1, v_i2) AND author_id_b = greatest(v_i1, v_i2);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : la paire écartée revient dans le balayage global.';
  END IF;
  RAISE NOTICE 'TEST 7 OK — une paire écartée reste écartée des deux vues.';

  -- 8 ---------------------------------------------------------------
  INSERT INTO public.author_drafts (preferred_name, sort_name, status, created_by, published_author_id, variant_forms)
  VALUES ('Serge Zvarkiev', 'Zvarkiev, Serge', 'draft', v_coord, v_wd, NULL)
  RETURNING id INTO v_draft;
  PERFORM public.publish_author_draft(v_draft);
  SELECT variant_forms INTO v_vf FROM public.authors WHERE id = v_wd;
  IF v_vf IS DISTINCT FROM '{"fr": ["Zvarkiev"], "es": ["Zvarkof"]}'::jsonb THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : après publication d''un brouillon sans graphies, variant_forms = %.', coalesce(v_vf::text, 'NULL');
  END IF;
  RAISE NOTICE 'TEST 8 OK — un brouillon sans graphies ne vide pas celles de l''autorité.';

  RAISE NOTICE 'AUT-VAR OK : 8/8 tests passés';
END $$;

ROLLBACK;
