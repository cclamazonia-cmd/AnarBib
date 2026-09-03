-- ============================================================
-- Tests d'acceptation — évidences 2/4 : le retrait d'un non-agent
-- ============================================================
-- Migration couverte : *_quatre_non_agents_retires.sql
--
-- CE QUE CES TESTS PROTÈGENT. Retirer une autorité liée doit laisser le NOM sur
-- le contributeur (la transcription reste, C5 = B), vider la table dérivée,
-- détacher l'œuvre, écarter la file, journaliser — et refuser si la fiche n'est
-- pas exactement celle attendue.
--
-- 4 tests :
--   1. Nom qui ne correspond pas : refus, rien n'est écrit.
--   2. Fixture de formation : refus.
--   3. Retrait : contributeur délié mais nommé, book_authors vide, œuvre détachée,
--      ligne de la file écartée, journal écrit, fiche supprimée.
--   4. Pas de porte applicative.
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH a AS (
  INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zz??', 'Zz??') RETURNING id
), a_fix AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_label) VALUES ('Zzbruit', 'Zzbruit', 'formacao-e9') RETURNING id
), b AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre au bruit', 'Zz??') RETURNING id
), c AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b.id, a.id, 1, 'Zz??', 'autor', true FROM b, a RETURNING id
), w AS (
  INSERT INTO public.works (uniform_title, primary_author_id) SELECT 'Œuvre au bruit', a.id FROM a RETURNING id
), q AS (
  INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose)
  SELECT 'autorite_forme', 'author', a.id, 'Zz??', NULL FROM a RETURNING id
)
SELECT (SELECT id FROM a) AS aid, (SELECT id FROM a_fix) AS fix, (SELECT id FROM b) AS book,
       (SELECT id FROM c) AS contrib, (SELECT id FROM w) AS work, (SELECT id FROM q) AS qid;

DO $$
DECLARE v_a bigint; v_fix bigint; v_book bigint; v_contrib bigint; v_work bigint; v_qid bigint; v_ok boolean; v_n bigint; v_txt text;
BEGIN
  SELECT aid, fix, book, contrib, work, qid INTO v_a, v_fix, v_book, v_contrib, v_work, v_qid FROM t_fix;
  IF v_qid IS NULL OR v_work IS NULL THEN RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.'; END IF;

  -- 1
  v_ok := public.fn_conv_retirer_non_agent(v_a, 'Zzautre');
  IF v_ok OR NOT EXISTS (SELECT 1 FROM public.authors WHERE id = v_a) THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : un nom qui ne correspond pas a été retiré.';
  END IF;
  RAISE NOTICE 'TEST 1 OK — nom différent : refus.';

  -- 2
  v_ok := public.fn_conv_retirer_non_agent(v_fix, 'Zzbruit');
  IF v_ok OR NOT EXISTS (SELECT 1 FROM public.authors WHERE id = v_fix) THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : une fixture de formation a été retirée.';
  END IF;
  RAISE NOTICE 'TEST 2 OK — fixture : refus.';

  -- 3
  v_ok := public.fn_conv_retirer_non_agent(v_a, 'Zz??');
  IF NOT v_ok THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le retrait a été refusé.'; END IF;
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = v_a) THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : la fiche existe encore.'; END IF;
  SELECT name INTO v_txt FROM public.book_contributors WHERE id = v_contrib AND author_id IS NULL;
  IF v_txt IS DISTINCT FROM 'Zz??' THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le contributeur devait rester nommé et délié (obtenu %).', v_txt; END IF;
  SELECT count(*) INTO v_n FROM public.book_authors WHERE book_id = v_book;
  IF v_n <> 0 THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : book_authors porte encore % ligne(s).', v_n; END IF;
  IF (SELECT primary_author_id FROM public.works WHERE id = v_work) IS NOT NULL THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : l''œuvre garde l''auteur.'; END IF;
  SELECT decision INTO v_txt FROM public.catalog_review_queue WHERE id = v_qid;
  IF v_txt IS DISTINCT FROM 'ecarte' THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : la ligne de la file devait être écartée (obtenu %).', v_txt; END IF;
  SELECT count(*) INTO v_n FROM public.catalog_audit_log WHERE entity_type = 'author' AND entity_id = v_a AND action = 'discard';
  IF v_n <> 1 THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le journal n''a pas l''instantané.'; END IF;
  RAISE NOTICE 'TEST 3 OK — retrait : nom conservé, dérivée vide, œuvre détachée, file écartée, journal écrit.';

  -- 4
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_retirer_non_agent(v_fix, 'Zzbruit');
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : le rôle authenticated a exécuté le retrait.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_retirer_non_agent(bigint,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_retirer_non_agent(bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : porte applicative ouverte.';
  END IF;
  RAISE NOTICE 'TEST 4 OK — pas de porte applicative.';

  RAISE EXCEPTION 'CONV-EVIDENCE-NON-AGENTS OK : 4/4 tests passés';
END $$;

ROLLBACK;
