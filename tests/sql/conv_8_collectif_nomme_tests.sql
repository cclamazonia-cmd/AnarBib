-- ============================================================
-- Tests d'acceptation CONV-8, suite — requalifier un contributeur en collectivité
-- ============================================================
-- Migration couverte : *_coletivo_edgard_leuenroth.sql
--
-- 4 tests :
--   1. Nom, autorité déjà liée ou transcription différente : refus, rien n'est écrit.
--   2. Requalification : autorité collective créée (trois faces), ligne renommée,
--      reliée, rôle organizacao, premier segment de la transcription réparé, les
--      autres segments intacts, journal écrit, book_authors dérivée posée.
--   3. Une collectivité déjà existante est réutilisée, pas dupliquée.
--   4. Pas de porte applicative.
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH b1 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Movimento Zz', 'Zzleueroth, Pelo Coletivo Edgar ; Löwy, Michael') RETURNING id
), c1 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b1.id, NULL, 1, 'Zzleueroth, Pelo Coletivo Edgar', 'autor', true FROM b1 RETURNING id
), c1b AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b1.id, NULL, 2, 'Löwy, Michael', 'autor', false FROM b1 RETURNING id
), a_exist AS (
  INSERT INTO public.authors (sort_name, preferred_name, authority_type) VALUES ('Zzcoletivo Existant', 'Zzcoletivo Existant', 'collective') RETURNING id
), b2 AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Livre Zz2', 'Existant, Pelo Zzcoletivo') RETURNING id
), c2 AS (
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  SELECT b2.id, NULL, 1, 'Existant, Pelo Zzcoletivo', 'autor', true FROM b2 RETURNING id
)
SELECT (SELECT id FROM b1) b1, (SELECT id FROM c1) c1, (SELECT id FROM c1b) c1b, (SELECT id FROM a_exist) a_exist, (SELECT id FROM b2) b2, (SELECT id FROM c2) c2;

DO $$
DECLARE f record; v_ok boolean; v_n bigint; v_txt text; v_aid bigint; v_type text; v_json text; v_role text;
BEGIN
  SELECT * INTO f FROM t_fix;
  IF f.c2 IS NULL THEN RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.'; END IF;

  -- 1
  v_ok := public.fn_conv_requalifier_contributeur_collectif(f.c1, 'Autre nom', 'Coletivo Zz', 'organizacao', 'Zzleueroth, Pelo Coletivo Edgar ; Löwy, Michael', 'Coletivo Zz ; Löwy, Michael');
  IF v_ok THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : nom différent accepté.'; END IF;
  v_ok := public.fn_conv_requalifier_contributeur_collectif(f.c1, 'Zzleueroth, Pelo Coletivo Edgar', 'Coletivo Zz', 'organizacao', 'autre transcription', 'x');
  IF v_ok THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : transcription différente acceptée.'; END IF;
  SELECT count(*) INTO v_n FROM public.authors WHERE sort_name = 'Coletivo Zz';
  IF v_n <> 0 THEN RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : une autorité a été créée malgré le refus.'; END IF;
  RAISE NOTICE 'TEST 1 OK — gardes : refus sans écriture.';

  -- 2
  v_ok := public.fn_conv_requalifier_contributeur_collectif(f.c1, 'Zzleueroth, Pelo Coletivo Edgar', 'Coletivo Edgard Zzleuenroth', 'organizacao',
            'Zzleueroth, Pelo Coletivo Edgar ; Löwy, Michael', 'Coletivo Edgard Zzleuenroth ; Löwy, Michael');
  IF NOT v_ok THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : requalification refusée.'; END IF;
  SELECT name, role, author_id INTO v_txt, v_role, v_aid FROM public.book_contributors WHERE id = f.c1;
  IF v_txt IS DISTINCT FROM 'Coletivo Edgard Zzleuenroth' OR v_role IS DISTINCT FROM 'organizacao' OR v_aid IS NULL THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : ligne obtenue « % » / % / %.', v_txt, v_role, v_aid;
  END IF;
  SELECT sort_name, authority_type, structured_meta->>'authorityType' INTO v_txt, v_type, v_json FROM public.authors WHERE id = v_aid;
  IF v_txt IS DISTINCT FROM 'Coletivo Edgard Zzleuenroth' OR v_type IS DISTINCT FROM 'collective' OR v_json IS DISTINCT FROM 'collective' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : autorité « % » / % / %.', v_txt, v_type, v_json;
  END IF;
  SELECT autor INTO v_txt FROM public.books WHERE id = f.b1;
  IF v_txt IS DISTINCT FROM 'Coletivo Edgard Zzleuenroth ; Löwy, Michael' THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : transcription « % ».', v_txt; END IF;
  IF (SELECT name FROM public.book_contributors WHERE id = f.c1b) IS DISTINCT FROM 'Löwy, Michael' THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : l''autre contributeur a bougé.'; END IF;
  SELECT count(*) INTO v_n FROM public.book_authors WHERE book_id = f.b1 AND author_id = v_aid;
  IF v_n <> 1 THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : book_authors n''a pas suivi (%).', v_n; END IF;
  SELECT count(*) INTO v_n FROM public.catalog_audit_log WHERE entity_type = 'book' AND entity_id = f.b1 AND label = 'Coletivo Edgard Zzleuenroth';
  IF v_n <> 1 THEN RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : journal absent.'; END IF;
  RAISE NOTICE 'TEST 2 OK — collectivité créée sur trois faces, ligne reliée au rôle organizacao, transcription réparée, journal écrit.';

  -- 3
  v_ok := public.fn_conv_requalifier_contributeur_collectif(f.c2, 'Existant, Pelo Zzcoletivo', 'Zzcoletivo Existant', 'organizacao', 'Existant, Pelo Zzcoletivo', 'Zzcoletivo Existant');
  IF NOT v_ok OR (SELECT author_id FROM public.book_contributors WHERE id = f.c2) IS DISTINCT FROM f.a_exist THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : la collectivité existante n''a pas été réutilisée.';
  END IF;
  SELECT count(*) INTO v_n FROM public.authors WHERE lower(sort_name) = 'zzcoletivo existant';
  IF v_n <> 1 THEN RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : collectivité dupliquée (%).', v_n; END IF;
  RAISE NOTICE 'TEST 3 OK — une collectivité existante est réutilisée.';

  -- 4
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_requalifier_contributeur_collectif(f.c1b, 'Löwy, Michael', 'x', 'autor', 'y', 'z');
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : le rôle authenticated a exécuté la fonction.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_requalifier_contributeur_collectif(bigint,text,text,text,text,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_requalifier_contributeur_collectif(bigint,text,text,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : porte applicative ouverte.';
  END IF;
  RAISE NOTICE 'TEST 4 OK — pas de porte applicative.';

  RAISE EXCEPTION 'CONV-8-COLLECTIF OK : 4/4 tests passés';
END $$;

ROLLBACK;
