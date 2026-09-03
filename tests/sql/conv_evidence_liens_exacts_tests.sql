-- ============================================================
-- Tests d'acceptation — évidences 3/4 : les contributeurs homonymes exacts sont liés
-- ============================================================
-- Migration couverte : *_les_contributeurs_homonymes_exacts_sont_lies.sql
--
-- 4 tests :
--   1. « ZZADDOR, Carlos Augusto » (capitales) et « Carlos Augusto Zzaddor » (forme
--      directe) sont liés à « Zzaddor, Carlos Augusto » ; le nom imprimé reste.
--   2. Un nom inconnu reste sans lien ; un contributeur dont la fiche est déjà liée
--      au même livre par une autre ligne n'est pas lié ; une fixture n'est jamais liée.
--   3. Rejouable : second passage, rien de plus sur ces fixtures.
--   4. Pas de porte applicative.
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH a AS (
  INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zzaddor, Carlos Augusto', 'Carlos Augusto Zzaddor') RETURNING id
), a_fix AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_label) VALUES ('Zzformacao, Nestor', 'Nestor Zzformacao', 'formacao-e9') RETURNING id
), b1 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre 1', 'ZZADDOR, Carlos Augusto') RETURNING id
), b2 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre 2', 'Carlos Augusto Zzaddor ; Zzinconnu, X') RETURNING id
), b3 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre 3', 'Zzaddor, Carlos Augusto ; Zzaddor, Carlos Augusto') RETURNING id
), b4 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre 4', 'Zzformacao, Nestor') RETURNING id
), c1 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b1.id, NULL, 1, 'ZZADDOR, Carlos Augusto', 'autor', true FROM b1 RETURNING id
), c2 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b2.id, NULL, 1, 'Carlos Augusto Zzaddor', 'autor', true FROM b2 RETURNING id
), c2b AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b2.id, NULL, 2, 'Zzinconnu, X', 'autor', false FROM b2 RETURNING id
), c3a AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b3.id, a.id, 1, 'Zzaddor, Carlos Augusto', 'autor', true FROM b3, a RETURNING id
), c3b AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b3.id, NULL, 2, 'Zzaddor, Carlos Augusto', 'tradutor', false FROM b3 RETURNING id
), c4 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b4.id, NULL, 1, 'Zzformacao, Nestor', 'autor', true FROM b4 RETURNING id
)
SELECT (SELECT id FROM a) AS aid, (SELECT id FROM c1) AS c1, (SELECT id FROM c2) AS c2, (SELECT id FROM c2b) AS c2b,
       (SELECT id FROM c3b) AS c3b, (SELECT id FROM c4) AS c4, (SELECT count(*) FROM c3a) AS n3a;

DO $$
DECLARE v_a bigint; v_c1 bigint; v_c2 bigint; v_c2b bigint; v_c3b bigint; v_c4 bigint; v_n bigint; v_txt text;
BEGIN
  SELECT aid, c1, c2, c2b, c3b, c4 INTO v_a, v_c1, v_c2, v_c2b, v_c3b, v_c4 FROM t_fix;
  IF v_c4 IS NULL THEN RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.'; END IF;

  SELECT public.fn_conv_lier_contributeurs_exacts() INTO v_n;
  IF v_n < 2 THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : au moins 2 liens attendus (obtenu %).', v_n; END IF;
  IF (SELECT author_id FROM public.book_contributors WHERE id = v_c1) IS DISTINCT FROM v_a
     OR (SELECT author_id FROM public.book_contributors WHERE id = v_c2) IS DISTINCT FROM v_a THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : les homonymes exacts (capitales, forme directe) ne sont pas liés.';
  END IF;
  SELECT name INTO v_txt FROM public.book_contributors WHERE id = v_c1;
  IF v_txt IS DISTINCT FROM 'ZZADDOR, Carlos Augusto' THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : le nom imprimé a changé (« % »).', v_txt; END IF;
  RAISE NOTICE 'TEST 1 OK — homonymes exacts liés, nom imprimé intact.';

  IF (SELECT author_id FROM public.book_contributors WHERE id = v_c2b) IS NOT NULL THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : un inconnu a été lié.'; END IF;
  IF (SELECT author_id FROM public.book_contributors WHERE id = v_c3b) IS NOT NULL THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : une fiche déjà liée au livre a été liée une seconde fois.'; END IF;
  IF (SELECT author_id FROM public.book_contributors WHERE id = v_c4) IS NOT NULL THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : une fixture de formation a reçu un lien.'; END IF;
  RAISE NOTICE 'TEST 2 OK — inconnu, doublon de lien sur le livre, fixture : rien.';

  SELECT public.fn_conv_lier_contributeurs_exacts() INTO v_n;
  IF v_n <> 0 THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le second passage a lié % ligne(s).', v_n; END IF;
  RAISE NOTICE 'TEST 3 OK — rejouable.';

  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_lier_contributeurs_exacts();
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : le rôle authenticated a exécuté le liage.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_lier_contributeurs_exacts()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_lier_contributeurs_exacts()', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : porte applicative ouverte.';
  END IF;
  RAISE NOTICE 'TEST 4 OK — pas de porte applicative.';

  RAISE EXCEPTION 'CONV-EVIDENCE-LIENS OK : 4/4 tests passés';
END $$;

ROLLBACK;
