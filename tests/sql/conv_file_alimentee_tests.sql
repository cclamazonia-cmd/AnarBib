-- ============================================================
-- Tests d'acceptation C6 §7.3 — la file de vérification s'alimente seule
-- ============================================================
-- Migration couverte : 20260927121437_c6_la_file_de_verification_s_alimente_seule.sql
--
-- CE QUE CES TESTS PROTÈGENT. Un passage hebdomadaire sème la file de l'Atelier
-- par les semeurs existants. Les risques : semer les exercices de formation
-- (fausses exprès), semer deux fois, reproposer ce qu'une personne a tranché,
-- ou laisser « Audit 03/09 » sur une ligne née aujourd'hui.
--
-- 7 tests :
--   1. un titre à mot-outil capitalisé est semé, avec la proposition de la règle ;
--   2. une notice du bac à sable (`…-teste`) ne l'est pas ;
--   3. une autorité en capitales est semée, pas une autorité `formacao-*` ;
--   4. les notes des lignes neuves sont datées « Contrôle du », jamais « Audit » ;
--   5. un second passage n'ajoute rien, et ne double pas le préfixe des notes ;
--   6. une ligne écartée n'est jamais reproposée, même si la notice change ;
--   7. le passage est fermé à `authenticated`, le cron est planifié et attendu.
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-c6f-' || substr(gen_random_uuid()::text, 1, 8), 'Essai C6 file')
  RETURNING id
), bac AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-c6f-' || substr(gen_random_uuid()::text, 1, 8) || '-teste', 'Bac à sable C6')
  RETURNING id
), b_casse AS (
  INSERT INTO public.books (titulo, idioma, owner_library_id)
  SELECT 'História Do Anarquismo No Brasil', 'pt-BR', lib.id FROM lib RETURNING id
), b_bac AS (
  INSERT INTO public.books (titulo, idioma, owner_library_id)
  SELECT 'O Cinema E A Anarquia No Brasil', 'pt-BR', bac.id FROM bac RETURNING id
), a_casse AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('BESNARD, Pierre', 'Pierre Besnard') RETURNING id
), a_formation AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_label)
  VALUES ('MAGÓN, Ricardo Flores', 'Ricardo Flores Magón', 'formacao-e3') RETURNING id
)
SELECT (SELECT id FROM b_casse) AS b_casse, (SELECT id FROM b_bac) AS b_bac,
       (SELECT id FROM a_casse) AS a_casse, (SELECT id FROM a_formation) AS a_formation;

DO $$
DECLARE
  f record; ok int := 0; total int := 7; v jsonb; v_n bigint; v_txt text;
BEGIN
  SELECT * INTO f FROM t_fix;
  IF f.b_casse IS NULL OR f.a_formation IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  v := private.fn_conv_file_alimenter();

  -- 1 ----------------------------------------------------------------
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue
   WHERE lot = 'titre_casse' AND entity_id = f.b_casse AND decision = 'a_revoir';
  IF v_txt = 'História do Anarquismo no Brasil' THEN ok := ok + 1;
  ELSE RAISE WARNING 'T1 titre semé : proposition « % »', v_txt; END IF;

  -- 2 ----------------------------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM public.catalog_review_queue WHERE entity_id = f.b_bac AND lot = 'titre_casse') THEN ok := ok + 1;
  ELSE RAISE WARNING 'T2 une notice du bac à sable est semée'; END IF;

  -- 3 ----------------------------------------------------------------
  IF EXISTS (SELECT 1 FROM public.catalog_review_queue WHERE lot = 'autorite_casse' AND entity_id = f.a_casse)
     AND NOT EXISTS (SELECT 1 FROM public.catalog_review_queue WHERE entity_id = f.a_formation AND entity_kind = 'author') THEN
    ok := ok + 1;
  ELSE RAISE WARNING 'T3 autorités : capitales non semées, ou formation semée'; END IF;

  -- 4 ----------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.catalog_review_queue
   WHERE created_at = now() AND (note IS NULL OR note !~ '^Contrôle du \d\d/\d\d · ' OR note ~ 'Audit');
  IF v_n = 0 AND EXISTS (SELECT 1 FROM public.catalog_review_queue WHERE created_at = now()) THEN ok := ok + 1;
  ELSE RAISE WARNING 'T4 % note(s) mal datée(s)', v_n; END IF;

  -- 5 ----------------------------------------------------------------
  v := private.fn_conv_file_alimenter();
  SELECT count(*) INTO v_n FROM public.catalog_review_queue
   WHERE created_at = now() AND note ~ 'Contrôle du .*Contrôle du';
  IF (SELECT sum(x::bigint) FROM jsonb_each_text(v) AS e(k, x)) = 0 AND v_n = 0
     AND (SELECT count(*) FROM jsonb_object_keys(v)) = 5 THEN ok := ok + 1;
  ELSE RAISE WARNING 'T5 second passage : % ; préfixes doublés : %', v, v_n; END IF;

  -- 6 ----------------------------------------------------------------
  UPDATE public.catalog_review_queue SET decision = 'ecarte'
   WHERE lot = 'titre_casse' AND entity_id = f.b_casse;
  UPDATE public.books SET titulo = 'Memória Do Movimento Operário' WHERE id = f.b_casse;
  PERFORM private.fn_conv_file_alimenter();
  SELECT count(*) INTO v_n FROM public.catalog_review_queue WHERE lot = 'titre_casse' AND entity_id = f.b_casse;
  IF v_n = 1 AND (SELECT decision FROM public.catalog_review_queue WHERE lot = 'titre_casse' AND entity_id = f.b_casse) = 'ecarte' THEN
    ok := ok + 1;
  ELSE RAISE WARNING 'T6 un verdict a été reproposé (% ligne(s))', v_n; END IF;

  -- 7 ----------------------------------------------------------------
  IF NOT has_function_privilege('authenticated', 'private.fn_conv_file_alimenter()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_conv_lot_titre_casse_seed()', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_conv_lot_titre_casse_seed()', 'EXECUTE')
     AND EXISTS (SELECT 1 FROM private.fn_crons_attendus() WHERE jobname = 'anarbib-conv-file-alimenter' AND schedule = '10 5 * * 1')
     AND EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anarbib-conv-file-alimenter') THEN
    ok := ok + 1;
  ELSE RAISE WARNING 'T7 droits ou cron'; END IF;

  IF ok = total THEN
    RAISE NOTICE 'CONV-FILE-ALIMENTEE OK : %/% tests passés', ok, total;
  ELSE
    RAISE EXCEPTION 'CONV-FILE-ALIMENTEE ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
