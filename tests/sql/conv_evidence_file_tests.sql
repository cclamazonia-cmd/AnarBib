-- ============================================================
-- Tests d'acceptation — évidences 4/4 : trancher une ligne évidente de la file
-- ============================================================
-- Migration couverte : *_les_evidences_de_la_file_tranchees.sql
--
-- CE QUE CES TESTS PROTÈGENT. La fonction écrit un verdict à la place d'une
-- personne. Elle ne doit le faire que sur une ligne encore « à revoir », que
-- si la fiche est encore celle que la file a vue (CONV-O6), et écrire exactement
-- ce que l'écran aurait écrit.
--
-- 7 tests :
--   1. Forme directe, proposition retenue : sort_name inversé, forme d'affichage
--      suit, ligne « valide » appliquée.
--   2. Valeur différente de la proposition : ligne « corrige » avec la valeur.
--   3. Collectivité inversée, type congress : les trois faces, ligne appliquée.
--   4. « ecarte » : rien sur la fiche, ligne écartée.
--   5. Ligne déjà tranchée : refus.
--   6. Fiche modifiée depuis la file : refus (CONV-O6).
--   7. Pas de porte applicative.
--
-- Fixtures à préfixe Zz ; lignes de la file insérées directement (rôle postgres,
-- comme la suite O7) ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH a1 AS (INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zzcarme Regina Schons', 'Zzcarme Regina Schons') RETURNING id),
     a2 AS (INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Jr., Armando Zzboito', 'Armando Zzboito Jr.') RETURNING id),
     a3 AS (INSERT INTO public.authors (sort_name, preferred_name) VALUES ('International, Congrès Anarchiste Zz', 'Congrès Anarchiste Zz International') RETURNING id),
     a4 AS (INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Di Zzfilippo, Luis', 'Luis Di Zzfilippo') RETURNING id),
     a5 AS (INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zzdeja, Tranchée', 'Tranchée Zzdeja') RETURNING id),
     a6 AS (INSERT INTO public.authors (sort_name, preferred_name) VALUES ('Zzbouge, Fiche', 'Fiche Zzbouge') RETURNING id),
     q1 AS (INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose) SELECT 'autorite_forme', 'author', id, 'Zzcarme Regina Schons', 'Schons, Zzcarme Regina' FROM a1 RETURNING id),
     q2 AS (INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose) SELECT 'autorite_forme', 'author', id, 'Jr., Armando Zzboito', 'Zzboito Jr., Armando' FROM a2 RETURNING id),
     q3 AS (INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose) SELECT 'autorite_collectivite', 'author', id, 'International, Congrès Anarchiste Zz', 'Congrès Anarchiste Zz International' FROM a3 RETURNING id),
     q4 AS (INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose) SELECT 'autorite_forme', 'author', id, 'Di Zzfilippo, Luis', 'Zzfilippo, Luis di' FROM a4 RETURNING id),
     q5 AS (INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose, decision) SELECT 'autorite_forme', 'author', id, 'Zzdeja, Tranchée', 'Zzdeja, Tranchee', 'ecarte' FROM a5 RETURNING id),
     q6 AS (INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose) SELECT 'autorite_casse', 'author', id, 'ZZBOUGE, Fiche', 'Zzbouge, Fiche' FROM a6 RETURNING id)
SELECT (SELECT id FROM a1) a1, (SELECT id FROM a2) a2, (SELECT id FROM a3) a3, (SELECT id FROM a4) a4, (SELECT id FROM a5) a5, (SELECT id FROM a6) a6,
       (SELECT id FROM q1) q1, (SELECT id FROM q2) q2, (SELECT id FROM q3) q3, (SELECT id FROM q4) q4, (SELECT id FROM q5) q5, (SELECT id FROM q6) q6;

DO $$
DECLARE f record; v_ok boolean; v_s text; v_p text; v_t text; v_j text; v_d text; v_v text; v_app timestamptz;
BEGIN
  SELECT * INTO f FROM t_fix;
  IF f.q6 IS NULL THEN RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.'; END IF;

  -- 1
  v_ok := public.fn_conv_trancher_evidence(f.q1, 'Schons, Zzcarme Regina', 'appliquer', NULL);
  SELECT sort_name, preferred_name INTO v_s, v_p FROM public.authors WHERE id = f.a1;
  SELECT decision, applique_le INTO v_d, v_app FROM public.catalog_review_queue WHERE id = f.q1;
  IF NOT v_ok OR v_s IS DISTINCT FROM 'Schons, Zzcarme Regina' OR v_p IS DISTINCT FROM 'Zzcarme Regina Schons' OR v_d IS DISTINCT FROM 'valide' OR v_app IS NULL THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : obtenu « % » / « % » / % / %.', v_s, v_p, v_d, v_app;
  END IF;
  RAISE NOTICE 'TEST 1 OK — forme directe : point d''accès inversé, affichage suit, ligne valide appliquée.';

  -- 2
  v_ok := public.fn_conv_trancher_evidence(f.q2, 'Zzboito Júnior, Armando', 'appliquer', NULL);
  SELECT sort_name, preferred_name INTO v_s, v_p FROM public.authors WHERE id = f.a2;
  SELECT decision, valeur_retenue INTO v_d, v_v FROM public.catalog_review_queue WHERE id = f.q2;
  IF NOT v_ok OR v_s IS DISTINCT FROM 'Zzboito Júnior, Armando' OR v_p IS DISTINCT FROM 'Armando Zzboito Júnior' OR v_d IS DISTINCT FROM 'corrige' OR v_v IS DISTINCT FROM 'Zzboito Júnior, Armando' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : obtenu « % » / « % » / % / « % ».', v_s, v_p, v_d, v_v;
  END IF;
  RAISE NOTICE 'TEST 2 OK — valeur différente : « corrige » avec la valeur, appliquée.';

  -- 3
  v_ok := public.fn_conv_trancher_evidence(f.q3, 'Congrès Anarchiste Zz International', 'appliquer', 'congress');
  SELECT sort_name, authority_type, structured_meta->>'authorityType' INTO v_s, v_t, v_j FROM public.authors WHERE id = f.a3;
  IF NOT v_ok OR v_s IS DISTINCT FROM 'Congrès Anarchiste Zz International' OR v_t IS DISTINCT FROM 'congress' OR v_j IS DISTINCT FROM 'congress' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : obtenu « % » / % / %.', v_s, v_t, v_j;
  END IF;
  RAISE NOTICE 'TEST 3 OK — collectivité : dé-inversée, typée congress sur les trois faces.';

  -- 4
  v_ok := public.fn_conv_trancher_evidence(f.q4, 'italien moderne : la particule se conserve', 'ecarte', NULL);
  SELECT sort_name INTO v_s FROM public.authors WHERE id = f.a4;
  SELECT decision, applique_le INTO v_d, v_app FROM public.catalog_review_queue WHERE id = f.q4;
  IF NOT v_ok OR v_s IS DISTINCT FROM 'Di Zzfilippo, Luis' OR v_d IS DISTINCT FROM 'ecarte' OR v_app IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : obtenu « % » / % / %.', v_s, v_d, v_app;
  END IF;
  RAISE NOTICE 'TEST 4 OK — écarter n''écrit rien sur la fiche.';

  -- 5
  v_ok := public.fn_conv_trancher_evidence(f.q5, 'Zzdeja, Tranchee', 'appliquer', NULL);
  SELECT sort_name INTO v_s FROM public.authors WHERE id = f.a5;
  IF v_ok OR v_s IS DISTINCT FROM 'Zzdeja, Tranchée' THEN RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : une ligne déjà tranchée a été rejouée.'; END IF;
  RAISE NOTICE 'TEST 5 OK — ligne déjà tranchée : refus.';

  -- 6
  v_ok := public.fn_conv_trancher_evidence(f.q6, 'Zzbouge, Fiche', 'appliquer', NULL);
  SELECT decision INTO v_d FROM public.catalog_review_queue WHERE id = f.q6;
  IF v_ok OR v_d IS DISTINCT FROM 'a_revoir' THEN RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : une fiche qui a changé depuis la file a été écrite.'; END IF;
  RAISE NOTICE 'TEST 6 OK — CONV-O6 : la fiche a changé, refus.';

  -- 7
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_trancher_evidence(f.q6, 'x', 'ecarte', NULL);
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : le rôle authenticated a tranché.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_trancher_evidence(bigint,text,text,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_trancher_evidence(bigint,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : porte applicative ouverte.';
  END IF;
  RAISE NOTICE 'TEST 7 OK — pas de porte applicative.';

  RAISE EXCEPTION 'CONV-EVIDENCE-FILE OK : 7/7 tests passés';
END $$;

ROLLBACK;
