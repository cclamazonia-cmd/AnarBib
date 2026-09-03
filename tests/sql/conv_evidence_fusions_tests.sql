-- ============================================================
-- Tests d'acceptation — évidences 1/4 : la fusion d'un doublon exact
-- ============================================================
-- Migration couverte : *_dix_doublons_exacts_fusionnes.sql
--
-- CE QUE CES TESTS PROTÈGENT. La fonction supprime une fiche du corpus partagé.
-- Elle ne doit le faire que pour un doublon EXACT, jamais pour deux personnes
-- qui se ressemblent, jamais pour une fixture de formation ; et quand elle le
-- fait, rien ne doit se perdre : le lien du livre passe à la canonique, la
-- ligne de la file est écartée avec la raison, merge_log garde la trace.
--
-- 4 tests :
--   1. Deux fiches qui se ressemblent sans être identiques (« Zzbonanno, Alfredo » /
--      « Zzbonanno, Alfredo María ») : refus, rien n'est écrit.
--   2. Une fixture de formation : refus.
--   3. Un doublon exact (« DE ZZCARVALHO, Florentino » / « Zzcarvalho, Florentino de ») :
--      fusion — lien déplacé, doublon supprimé, ligne de la file écartée, merge_log écrit.
--   4. Pas de porte applicative.
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH a_can AS (
  INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zzcarvalho, Florentino de', 'Florentino de Zzcarvalho') RETURNING id
), a_dup AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_kind) VALUES ('DE ZZCARVALHO, Florentino', 'Florentino DE ZZCARVALHO', 'conv_revue') RETURNING id
), a_b1 AS (
  INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zzbonanno, Alfredo', 'Alfredo Zzbonanno') RETURNING id
), a_b2 AS (
  INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zzbonanno, Alfredo María', 'Alfredo María Zzbonanno') RETURNING id
), a_fix AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_label) VALUES ('Zzcarvalho, Florentino De', 'Florentino De Zzcarvalho', 'formacao-e9') RETURNING id
), b AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre du doublon', 'DE ZZCARVALHO, Florentino') RETURNING id
), c AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b.id, a_dup.id, 1, 'DE ZZCARVALHO, Florentino', 'autor', true FROM b, a_dup RETURNING id
), q AS (
  INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose)
  SELECT 'autorite_forme', 'author', a_dup.id, 'DE ZZCARVALHO, Florentino', 'De Zzcarvalho, Florentino' FROM a_dup RETURNING id
)
SELECT (SELECT id FROM a_can) AS can, (SELECT id FROM a_dup) AS dup, (SELECT id FROM a_b1) AS b1, (SELECT id FROM a_b2) AS b2,
       (SELECT id FROM a_fix) AS fix, (SELECT id FROM b) AS book, (SELECT id FROM c) AS contrib, (SELECT id FROM q) AS qid;

DO $$
DECLARE v_can bigint; v_dup bigint; v_b1 bigint; v_b2 bigint; v_fix bigint; v_book bigint; v_contrib bigint; v_qid bigint;
        v_ok boolean; v_n bigint; v_txt text;
BEGIN
  SELECT can, dup, b1, b2, fix, book, contrib, qid INTO v_can, v_dup, v_b1, v_b2, v_fix, v_book, v_contrib, v_qid FROM t_fix;
  IF v_qid IS NULL THEN RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.'; END IF;

  -- 1
  v_ok := public.fn_conv_fusionner_doublon_exact(v_b1, v_b2);
  IF v_ok OR NOT EXISTS (SELECT 1 FROM public.authors WHERE id = v_b2) THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : deux fiches qui se ressemblent ont été fusionnées.';
  END IF;
  RAISE NOTICE 'TEST 1 OK — pas un doublon exact : refus, rien d''écrit.';

  -- 2
  v_ok := public.fn_conv_fusionner_doublon_exact(v_can, v_fix);
  IF v_ok OR NOT EXISTS (SELECT 1 FROM public.authors WHERE id = v_fix) THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : une fixture de formation a été fusionnée.';
  END IF;
  RAISE NOTICE 'TEST 2 OK — fixture de formation : refus.';

  -- 3
  v_ok := public.fn_conv_fusionner_doublon_exact(v_can, v_dup);
  IF NOT v_ok THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le doublon exact a été refusé.'; END IF;
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = v_dup) THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le doublon existe encore.'; END IF;
  SELECT author_id INTO v_n FROM public.book_contributors WHERE id = v_contrib;
  IF v_n IS DISTINCT FROM v_can THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le lien du livre n''est pas passé à la canonique (obtenu %).', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.book_authors WHERE book_id = v_book AND author_id = v_can;
  IF v_n <> 1 THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : book_authors ne porte pas la canonique (obtenu %).', v_n; END IF;
  SELECT decision INTO v_txt FROM public.catalog_review_queue WHERE id = v_qid;
  IF v_txt IS DISTINCT FROM 'ecarte' THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : la ligne de la file devait être écartée (obtenu %).', v_txt; END IF;
  SELECT count(*) INTO v_n FROM public.merge_log WHERE entity_type = 'author' AND canonical_id = v_can AND duplicate_id = v_dup;
  IF v_n <> 1 THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : merge_log n''a pas la trace.'; END IF;
  RAISE NOTICE 'TEST 3 OK — fusion : lien déplacé, doublon supprimé, file écartée, trace écrite.';

  -- 4
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_fusionner_doublon_exact(v_b1, v_b2);
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : le rôle authenticated a exécuté la fusion.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_fusionner_doublon_exact(bigint,bigint)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_fusionner_doublon_exact(bigint,bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : porte applicative ouverte.';
  END IF;
  RAISE NOTICE 'TEST 4 OK — pas de porte applicative.';

  RAISE EXCEPTION 'CONV-EVIDENCE-FUSIONS OK : 4/4 tests passés';
END $$;

ROLLBACK;
