-- ============================================================
-- Tests d'acceptation CONV-8 — « AA. VV. » n'est pas un contributeur
-- ============================================================
-- Migration couverte : *_les_auteurs_divers_ne_sont_pas_des_contributeurs.sql
--
-- 4 tests :
--   1. Nom différent, ou ligne déjà liée à une autorité : refus, rien n'est écrit.
--   2. Retrait d'un « AA. VV. » primaire sur un livre à trois contributeurs :
--      la ligne part, la transcription reste, le traducteur suivant devient
--      primaire, le journal est écrit.
--   3. Retrait du seul contributeur d'un livre : le livre reste, entré au titre.
--   4. Pas de porte applicative.
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH a AS (
  INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zzxerri, Elio', 'Elio Zzxerri') RETURNING id
), b1 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Dietro le Zzsbarre', 'AA. VV. ; ZZXERRI, Elio ; ZZBURATTI, Simone') RETURNING id
), b2 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre Zzanonyme', 'Anônimo') RETURNING id
), c1 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b1.id, NULL, 1, 'AA. VV.', 'autor', true FROM b1 RETURNING id
), c2 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b1.id, a.id, 2, 'ZZXERRI, Elio', 'tradutor', false FROM b1, a RETURNING id
), c3 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b1.id, NULL, 3, 'ZZBURATTI, Simone', 'tradutor', false FROM b1 RETURNING id
), c4 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b2.id, NULL, 1, 'Anônimo', 'autor', true FROM b2 RETURNING id
)
SELECT (SELECT id FROM b1) b1, (SELECT id FROM b2) b2, (SELECT id FROM c1) c1, (SELECT id FROM c2) c2, (SELECT id FROM c3) c3, (SELECT id FROM c4) c4;

DO $$
DECLARE f record; v_ok boolean; v_n bigint; v_txt text;
BEGIN
  SELECT * INTO f FROM t_fix;
  IF f.c4 IS NULL THEN RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.'; END IF;

  -- 1
  v_ok := public.fn_conv_retirer_contributeur_non_agent(f.c1, 'AA. VV');
  IF v_ok OR NOT EXISTS (SELECT 1 FROM public.book_contributors WHERE id = f.c1) THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : nom différent accepté.'; END IF;
  v_ok := public.fn_conv_retirer_contributeur_non_agent(f.c2, 'ZZXERRI, Elio');
  IF v_ok OR NOT EXISTS (SELECT 1 FROM public.book_contributors WHERE id = f.c2) THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : une ligne liée à une autorité a été retirée.'; END IF;
  RAISE NOTICE 'TEST 1 OK — nom différent ou autorité liée : refus.';

  -- 2
  v_ok := public.fn_conv_retirer_contributeur_non_agent(f.c1, 'AA. VV.');
  IF NOT v_ok OR EXISTS (SELECT 1 FROM public.book_contributors WHERE id = f.c1) THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la ligne AA. VV. n''est pas partie.'; END IF;
  SELECT autor INTO v_txt FROM public.books WHERE id = f.b1;
  IF v_txt IS DISTINCT FROM 'AA. VV. ; ZZXERRI, Elio ; ZZBURATTI, Simone' THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la transcription a bougé (« % »).', v_txt; END IF;
  IF NOT (SELECT is_primary FROM public.book_contributors WHERE id = f.c2) THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la première ligne restante n''est pas devenue primaire.'; END IF;
  SELECT count(*) INTO v_n FROM public.catalog_audit_log WHERE entity_type = 'book' AND entity_id = f.b1 AND label = 'AA. VV.';
  IF v_n <> 1 THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : le journal n''a pas la trace.'; END IF;
  RAISE NOTICE 'TEST 2 OK — AA. VV. retiré, transcription intacte, primaire réattribuée, journal écrit.';

  -- 3
  v_ok := public.fn_conv_retirer_contributeur_non_agent(f.c4, 'Anônimo');
  SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = f.b2;
  IF NOT v_ok OR v_n <> 0 OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = f.b2 AND autor = 'Anônimo') THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le livre anonyme devait rester, entré au titre, sans contributeur (obtenu %).', v_n;
  END IF;
  RAISE NOTICE 'TEST 3 OK — le livre anonyme est entré au titre, la transcription reste.';

  -- 4
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_retirer_contributeur_non_agent(f.c3, 'ZZBURATTI, Simone');
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : le rôle authenticated a exécuté le retrait.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_retirer_contributeur_non_agent(bigint,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_retirer_contributeur_non_agent(bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : porte applicative ouverte.';
  END IF;
  RAISE NOTICE 'TEST 4 OK — pas de porte applicative.';

  RAISE EXCEPTION 'CONV-8 OK : 4/4 tests passés';
END $$;

ROLLBACK;
