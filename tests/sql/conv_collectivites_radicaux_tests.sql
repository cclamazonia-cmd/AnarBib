-- ============================================================
-- Tests d'acceptation CONV-O7, suite — le motif des collectivités lit les
-- radicaux, et le lot reçoit les non inversées
-- ============================================================
-- Migration couverte : *_le_motif_des_collectivites_lit_les_radicaux.sql
--
-- CE QUE CES TESTS PROTÈGENT. Le motif PROPOSE des collectivités à un œil
-- humain ; s'il attrape des personnes, la file se remplit de faux positifs
-- et la personne qui tranche s'use ; s'il rate les formes fléchies, les
-- collectivités restent rangées comme des personnes (quatorze le 03/09).
-- Et le lot doit pouvoir TYPER sans renommer : « Fédération Anarchiste »
-- n'a rien à dé-inverser, il lui manque seulement son type.
--
-- 7 tests :
--   1. Radical ouvert : « Zzuruguai, Federação Anarquista » et « Comitê Zz de
--      Resistência » sont repérés ; sigle fermé : « Zzsnider, Paul » ne l'est pas ;
--      « Zzcasanova, Pablo González » et « Paulo Zzcapra (Organizador) » non plus.
--   2. Le semis entre la collectivité inversée avec sa dé-inversion, et la non
--      inversée avec son nom tel quel.
--   3. Le semis ignore : la fixture de formation, la fiche déjà typée non inversée,
--      la fiche engagée dans un signalement de doublon ouvert.
--   4. Le semis est rejouable : second passage, 0.
--   5. Valider une NON inversée pose le type (colonne + jsonb) sans changer le nom,
--      et marque la ligne appliquée.
--   6. Valider une inversée dé-inverse et type (régression de la migration 16).
--   7. Le semis n'a pas de porte applicative (authenticated refusé, anon rien).
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'col-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Revue', 'Collectivites' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-col-' || substr(gen_random_uuid()::text, 1, 8), 'Essai collectivites')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'librarian', 'active' FROM prof, lib
  RETURNING user_id
), a_inv AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzuruguai, Federação Anarquista', 'Federação Anarquista Zzuruguai') RETURNING id
), a_plain AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Comitê Zz de Resistência', 'Comitê Zz de Resistência') RETURNING id
), a_snider AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzsnider, Paul', 'Paul Zzsnider') RETURNING id
), a_casas AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzcasanova, Pablo González', 'Pablo González Zzcasanova') RETURNING id
), a_capra AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Paulo Zzcapra (Organizador)', 'Paulo Zzcapra (Organizador)') RETURNING id
), a_fixture AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_label)
  VALUES ('Zzformação, Federação da', 'Federação da Zzformação', 'formacao-e9') RETURNING id
), a_typed AS (
  INSERT INTO public.authors (sort_name, preferred_name, authority_type)
  VALUES ('Grupo Zzkrisis', 'Grupo Zzkrisis', 'collective') RETURNING id
), a_dup1 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzcomitê Doublon', 'Zzcomitê Doublon') RETURNING id
), a_dup2 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzcomitê Doublon bis', 'Zzcomitê Doublon bis') RETURNING id
), rep AS (
  INSERT INTO public.authority_duplicate_reports (author_id_a, author_id_b, note)
  SELECT least(a_dup1.id, a_dup2.id), greatest(a_dup1.id, a_dup2.id), 'fixture' FROM a_dup1, a_dup2
  RETURNING id
)
SELECT (SELECT id FROM prof)      AS uid,
       (SELECT id FROM a_inv)     AS id_inv,
       (SELECT id FROM a_plain)   AS id_plain,
       (SELECT id FROM a_snider)  AS id_snider,
       (SELECT id FROM a_casas)   AS id_casas,
       (SELECT id FROM a_capra)   AS id_capra,
       (SELECT id FROM a_fixture) AS id_fixture,
       (SELECT id FROM a_typed)   AS id_typed,
       (SELECT id FROM a_dup1)    AS id_dup1,
       (SELECT count(*) FROM rep) AS n_rep,
       (SELECT count(*) FROM memb) AS n_memb;

DO $$
DECLARE
  v_uid uuid;
  v_inv bigint; v_plain bigint; v_snider bigint; v_casas bigint; v_capra bigint;
  v_fixture bigint; v_typed bigint; v_dup1 bigint;
  v_n bigint; v_txt text; v_type text; v_json text;
BEGIN
  SELECT uid, id_inv, id_plain, id_snider, id_casas, id_capra, id_fixture, id_typed, id_dup1
    INTO v_uid, v_inv, v_plain, v_snider, v_casas, v_capra, v_fixture, v_typed, v_dup1 FROM t_fix;
  IF v_uid IS NULL OR v_dup1 IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 1 ----------------------------------------------------------------
  IF NOT ('Zzuruguai, Federação Anarquista' ~* private.conv_motifs_collectivite()) THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : « Federação » (radical federa) n''est pas repéré.';
  END IF;
  IF NOT ('Comitê Zz de Resistência' ~* private.conv_motifs_collectivite()) THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : « Comitê » (radical comit) n''est pas repéré.';
  END IF;
  IF ('Zzsnider, Paul' ~* private.conv_motifs_collectivite()) THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : « Snider » est pris par le sigle SNI — le sigle n''est pas fermé.';
  END IF;
  IF ('Zzcasanova, Pablo González' ~* private.conv_motifs_collectivite())
     OR ('Paulo Zzcapra (Organizador)' ~* private.conv_motifs_collectivite()) THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : une personne est prise pour une collectivité (casa / organizador).';
  END IF;
  RAISE NOTICE 'TEST 1 OK — radicaux ouverts, sigles fermés, faux positifs connus écartés.';

  -- 2 / 3 ------------------------------------------------------------
  SELECT public.fn_conv_lot_autorite_collectivite_seed() INTO v_n;
  IF v_n < 2 THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : le semis devait entrer au moins 2 candidates (obtenu %).', v_n;
  END IF;
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue
   WHERE lot = 'autorite_collectivite' AND entity_id = v_inv;
  IF v_txt IS DISTINCT FROM 'Federação Anarquista Zzuruguai' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : l''inversée devait proposer « Federação Anarquista Zzuruguai » (obtenu « % »).', v_txt;
  END IF;
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue
   WHERE lot = 'autorite_collectivite' AND entity_id = v_plain;
  IF v_txt IS DISTINCT FROM 'Comitê Zz de Resistência' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la non inversée devait proposer son nom tel quel (obtenu « % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 2 OK — inversée dé-inversée, non inversée telle quelle.';

  SELECT count(*) INTO v_n FROM public.catalog_review_queue
   WHERE lot = 'autorite_collectivite' AND entity_id IN (v_fixture, v_typed, v_dup1, v_snider, v_casas, v_capra);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : % fiche(s) à ignorer sont entrées dans le lot (fixture, typée, doublon signalé, personnes).', v_n;
  END IF;
  RAISE NOTICE 'TEST 3 OK — fixture, typée, doublon signalé et personnes restent dehors.';

  -- 4 ----------------------------------------------------------------
  SELECT public.fn_conv_lot_autorite_collectivite_seed() INTO v_n;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : le second semis a inséré % ligne(s).', v_n;
  END IF;
  RAISE NOTICE 'TEST 4 OK — rejouable.';

  -- 5 / 6 ------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autorite_collectivite' AND entity_id = v_plain), 'valide', NULL, NULL);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autorite_collectivite' AND entity_id = v_inv), 'valide', NULL, NULL);
  PERFORM api.conv_revue_appliquer('autorite_collectivite');

  SELECT sort_name, authority_type, structured_meta->>'authorityType' INTO v_txt, v_type, v_json
    FROM public.authors WHERE id = v_plain;
  IF v_txt IS DISTINCT FROM 'Comitê Zz de Resistência' OR v_type IS DISTINCT FROM 'collective' OR v_json IS DISTINCT FROM 'collective' THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : attendu nom inchangé + type collective (colonne et jsonb), obtenu « % » / % / %.', v_txt, v_type, v_json;
  END IF;
  IF (SELECT applique_le FROM public.catalog_review_queue WHERE lot = 'autorite_collectivite' AND entity_id = v_plain) IS NULL THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : la ligne de la non inversée n''est pas marquée appliquée.';
  END IF;
  RAISE NOTICE 'TEST 5 OK — typer sans renommer : les trois faces, ligne appliquée.';

  SELECT sort_name, authority_type INTO v_txt, v_type FROM public.authors WHERE id = v_inv;
  IF v_txt IS DISTINCT FROM 'Federação Anarquista Zzuruguai' OR v_type IS DISTINCT FROM 'collective' THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : l''inversée devait être dé-inversée et typée (obtenu « % » / %).', v_txt, v_type;
  END IF;
  RAISE NOTICE 'TEST 6 OK — l''inversée est dé-inversée et typée (migration 16 intacte).';

  -- 7 ----------------------------------------------------------------
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_lot_autorite_collectivite_seed();
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : le rôle authenticated a lancé le semis.';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_lot_autorite_collectivite_seed()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_lot_autorite_collectivite_seed()', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : le semis est exécutable depuis l''application.';
  END IF;
  RAISE NOTICE 'TEST 7 OK — le semis n''a pas de porte applicative.';

  RAISE EXCEPTION 'CONV-O7-RADICAUX OK : 7/7 tests passés';
END $$;

ROLLBACK;
