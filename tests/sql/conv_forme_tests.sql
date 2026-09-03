-- ============================================================
-- Tests d'acceptation — le lot « autorite_forme » : la forme du point
-- d'accès se relit à la main
-- ============================================================
-- Migration couverte : *_le_lot_autorite_forme.sql
--
-- CE QUE CES TESTS PROTÈGENT. Le lot écrit le POINT D'ACCÈS sur le corpus
-- partagé. Le risque est double : une proposition qui casse ce qui était
-- juste (une collectivité inversée, une particule italienne rejetée, deux
-- personnes recoupées en une), et un semis qui déborde sur ce qui n'est
-- pas de ce lot (fiches doubles, doublons à fusionner, fixtures).
--
-- 8 tests :
--   1. La proposition : forme directe avec particule, mention de rôle, dates,
--      filiation en tête, particule en tête, mononyme, capitales, plusieurs personnes.
--   2. Le semis entre la forme directe, le mononyme (proposition = avant) et
--      la filiation ; il n'entre PAS la collectivité au motif, la fiche double,
--      la fixture, le doublon signalé, la forme inversée ordinaire, ni la particule
--      d'une fiche dont name_lang la conserve (af).
--   3. Rejouable : second semis, 0.
--   4. conv_revue_list rend le lot, avec « actuel » = sort_name.
--   5. Valider la forme directe écrit le point d'accès et la forme d'affichage suit.
--   6. Valider le mononyme n'écrit rien de neuf mais marque la ligne appliquée.
--   7. Corriger la filiation prend la valeur saisie.
--   8. Le semis n'a pas de porte applicative ; un lot inconnu reste refusé.
--
-- Fixtures à préfixe Zz ; tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'frm-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Revue', 'Forme' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-frm-' || substr(gen_random_uuid()::text, 1, 8), 'Essai forme')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'librarian', 'active' FROM prof, lib
  RETURNING user_id
), a_directe AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zznewton Stadler de Souza', 'Zznewton Stadler de Souza') RETURNING id
), a_mono AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzvoltaire', 'Zzvoltaire') RETURNING id
), a_fil AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Jr., Armando Zzboito', 'Armando Zzboito Jr.') RETURNING id
), a_coll AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Comitê Zz de Resistência', 'Comitê Zz de Resistência') RETURNING id
), a_double AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzantonio Serra & Zzcristina Pereira', 'Zzantonio Serra & Zzcristina Pereira') RETURNING id
), a_fixture AS (
  INSERT INTO public.authors (sort_name, preferred_name, source_label)
  VALUES ('Zzmakhno Nestor', 'Zzmakhno Nestor', 'formacao-e9') RETURNING id
), a_ok AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzreclus, Élisée', 'Élisée Zzreclus') RETURNING id
), a_af AS (
  INSERT INTO public.authors (sort_name, preferred_name, name_lang)
  VALUES ('Van Der Zzwalt, Lucien', 'Lucien Van Der Zzwalt', 'af') RETURNING id
), a_pt AS (
  INSERT INTO public.authors (sort_name, preferred_name, name_lang)
  VALUES ('De Zzserpa Pimentel, Antonio', 'Antonio De Zzserpa Pimentel', 'pt') RETURNING id
), a_dup1 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Zzfabio López López', 'Zzfabio López López') RETURNING id
), a_dup2 AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('López, Zzfabio López', 'Zzfabio López López') RETURNING id
), rep AS (
  INSERT INTO public.authority_duplicate_reports (author_id_a, author_id_b, note)
  SELECT least(a_dup1.id, a_dup2.id), greatest(a_dup1.id, a_dup2.id), 'fixture' FROM a_dup1, a_dup2
  RETURNING id
)
SELECT (SELECT id FROM prof)      AS uid,
       (SELECT id FROM a_directe) AS id_directe,
       (SELECT id FROM a_mono)    AS id_mono,
       (SELECT id FROM a_fil)     AS id_fil,
       (SELECT id FROM a_coll)    AS id_coll,
       (SELECT id FROM a_double)  AS id_double,
       (SELECT id FROM a_fixture) AS id_fixture,
       (SELECT id FROM a_ok)      AS id_ok,
       (SELECT id FROM a_af)      AS id_af,
       (SELECT id FROM a_pt)      AS id_pt,
       (SELECT id FROM a_dup1)    AS id_dup1,
       (SELECT count(*) FROM rep) AS n_rep,
       (SELECT count(*) FROM memb) AS n_memb;

DO $$
DECLARE
  v_uid uuid;
  v_directe bigint; v_mono bigint; v_fil bigint; v_coll bigint; v_double bigint;
  v_fixture bigint; v_ok bigint; v_af bigint; v_pt bigint; v_dup1 bigint;
  v_n bigint; v_txt text; v_pref text;
BEGIN
  SELECT uid, id_directe, id_mono, id_fil, id_coll, id_double, id_fixture, id_ok, id_af, id_pt, id_dup1
    INTO v_uid, v_directe, v_mono, v_fil, v_coll, v_double, v_fixture, v_ok, v_af, v_pt, v_dup1 FROM t_fix;
  IF v_uid IS NULL OR v_dup1 IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 1 ----------------------------------------------------------------
  IF public.fn_conv_forme_proposition('Newton Stadler de Souza') IS DISTINCT FROM 'Souza, Newton Stadler de' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : forme directe avec particule (obtenu « % »).', public.fn_conv_forme_proposition('Newton Stadler de Souza');
  END IF;
  IF public.fn_conv_forme_proposition('Kauan Willian dos Santos (Org.)') IS DISTINCT FROM 'Santos, Kauan Willian dos' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : mention de rôle (obtenu « % »).', public.fn_conv_forme_proposition('Kauan Willian dos Santos (Org.)');
  END IF;
  IF public.fn_conv_forme_proposition('Hakim Bey 1945-2022') IS DISTINCT FROM 'Bey, Hakim' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : dates dans le nom (obtenu « % »).', public.fn_conv_forme_proposition('Hakim Bey 1945-2022');
  END IF;
  IF public.fn_conv_forme_proposition('Jr., Armando Boito') IS DISTINCT FROM 'Boito Jr., Armando' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : filiation en tête (obtenu « % »).', public.fn_conv_forme_proposition('Jr., Armando Boito');
  END IF;
  IF public.fn_conv_forme_proposition('De Serpa Pimentel, Antonio') IS DISTINCT FROM 'Serpa Pimentel, Antonio de' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : particule en tête (obtenu « % »).', public.fn_conv_forme_proposition('De Serpa Pimentel, Antonio');
  END IF;
  IF public.fn_conv_forme_proposition('Voltaire') IS DISTINCT FROM 'Voltaire' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : mononyme (obtenu « % »).', public.fn_conv_forme_proposition('Voltaire');
  END IF;
  IF public.fn_conv_forme_proposition('LUDMILA, Aline (et al.)') IS DISTINCT FROM 'Ludmila, Aline' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : capitales + mention (obtenu « % »).', public.fn_conv_forme_proposition('LUDMILA, Aline (et al.)');
  END IF;
  IF public.fn_conv_forme_proposition('Golarons, Ricard de Vargas (org.)') IS DISTINCT FROM 'Golarons, Ricard de Vargas' THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : inversée avec mention (obtenu « % »).', public.fn_conv_forme_proposition('Golarons, Ricard de Vargas (org.)');
  END IF;
  IF public.fn_conv_forme_proposition('Antonio Serra & Cristina Pereira') IS NOT NULL
     OR public.fn_conv_forme_proposition('Giorgio Sacchetti, Augusto Gayubas, Manuel Vicent') IS NOT NULL
     OR public.fn_conv_forme_proposition('Doris Accioly e Silva, Sonia Alem Marrach (Org.)') IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : plusieurs personnes ont reçu une proposition.';
  END IF;
  RAISE NOTICE 'TEST 1 OK — la proposition : directe, mention, dates, filiation, particule, mononyme, capitales ; rien pour plusieurs personnes.';

  -- 2 ----------------------------------------------------------------
  SELECT public.fn_conv_lot_autorite_forme_seed() INTO v_n;
  IF v_n < 4 THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : le semis devait entrer au moins 4 fiches (obtenu %).', v_n;
  END IF;
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = v_directe;
  IF v_txt IS DISTINCT FROM 'Souza, Zznewton Stadler de' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la forme directe devait proposer « Souza, Zznewton Stadler de » (obtenu « % »).', v_txt;
  END IF;
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = v_mono;
  IF v_txt IS DISTINCT FROM 'Zzvoltaire' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : le mononyme devait proposer lui-même (obtenu « % »).', v_txt;
  END IF;
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = v_fil;
  IF v_txt IS DISTINCT FROM 'Zzboito Jr., Armando' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la filiation devait proposer « Zzboito Jr., Armando » (obtenu « % »).', v_txt;
  END IF;
  SELECT apres_propose INTO v_txt FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = v_pt;
  IF v_txt IS DISTINCT FROM 'Zzserpa Pimentel, Antonio de' THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : la particule pt devait proposer « Zzserpa Pimentel, Antonio de » (obtenu « % »).', v_txt;
  END IF;
  SELECT count(*) INTO v_n FROM public.catalog_review_queue
   WHERE lot = 'autorite_forme' AND entity_id IN (v_coll, v_double, v_fixture, v_ok, v_af, v_dup1);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : % fiche(s) hors périmètre sont entrées (collectivité, double, fixture, inversée ordinaire, af, doublon signalé).', v_n;
  END IF;
  RAISE NOTICE 'TEST 2 OK — le semis prend la forme, laisse le reste.';

  -- 3 ----------------------------------------------------------------
  SELECT public.fn_conv_lot_autorite_forme_seed() INTO v_n;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le second semis a inséré % ligne(s).', v_n;
  END IF;
  RAISE NOTICE 'TEST 3 OK — rejouable.';

  -- 4 ----------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
  SELECT l.actuel INTO v_txt FROM api.conv_revue_list('autorite_forme', 'a_revoir', 200, 0) l WHERE l.entity_id = v_directe;
  IF v_txt IS DISTINCT FROM 'Zznewton Stadler de Souza' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : conv_revue_list devait rendre « actuel » = sort_name (obtenu « % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 4 OK — la liste connaît le lot.';

  -- 5 / 6 / 7 --------------------------------------------------------
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = v_directe), 'valide', NULL, NULL);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = v_mono), 'valide', NULL, NULL);
  PERFORM api.conv_revue_decide((SELECT id FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = v_fil), 'corrige', 'Zzboito Júnior, Armando', NULL);
  PERFORM api.conv_revue_appliquer('autorite_forme');

  SELECT sort_name, preferred_name INTO v_txt, v_pref FROM public.authors WHERE id = v_directe;
  IF v_txt IS DISTINCT FROM 'Souza, Zznewton Stadler de' OR v_pref IS DISTINCT FROM 'Zznewton Stadler de Souza' THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : attendu « Souza, Zznewton Stadler de » / « Zznewton Stadler de Souza », obtenu « % » / « % ».', v_txt, v_pref;
  END IF;
  RAISE NOTICE 'TEST 5 OK — valider inverse le point d''accès, la forme d''affichage suit.';

  SELECT sort_name INTO v_txt FROM public.authors WHERE id = v_mono;
  IF v_txt IS DISTINCT FROM 'Zzvoltaire'
     OR (SELECT applique_le FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = v_mono) IS NULL THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le mononyme devait rester tel quel et la ligne être appliquée.';
  END IF;
  RAISE NOTICE 'TEST 6 OK — confirmer un mononyme : rien d''écrit, ligne appliquée.';

  SELECT sort_name, preferred_name INTO v_txt, v_pref FROM public.authors WHERE id = v_fil;
  IF v_txt IS DISTINCT FROM 'Zzboito Júnior, Armando' OR v_pref IS DISTINCT FROM 'Armando Zzboito Júnior' THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : corriger devait écrire la valeur saisie (obtenu « % » / « % »).', v_txt, v_pref;
  END IF;
  RAISE NOTICE 'TEST 7 OK — corriger prend la valeur saisie.';

  -- 8 ----------------------------------------------------------------
  BEGIN
    PERFORM api.conv_revue_appliquer('lot_inconnu');
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : un lot inconnu a été accepté.';
  EXCEPTION WHEN invalid_parameter_value THEN
    NULL;
  END;
  BEGIN
    EXECUTE 'set local role authenticated';
    PERFORM public.fn_conv_lot_autorite_forme_seed();
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : le rôle authenticated a lancé le semis.';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  EXECUTE 'reset role';
  IF has_function_privilege('anon', 'public.fn_conv_lot_autorite_forme_seed()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_conv_lot_autorite_forme_seed()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_conv_forme_proposition(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : une fonction est exécutable là où elle ne doit pas.';
  END IF;
  RAISE NOTICE 'TEST 8 OK — lot inconnu refusé, semis sans porte applicative.';

  RAISE EXCEPTION 'CONV-FORME OK : 8/8 tests passés';
END $$;

ROLLBACK;
