-- ============================================================
-- Tests d'acceptation CONV-O7 — type d'autorité et collectivités inversées
-- ============================================================
-- Migrations couvertes :
--   20260821190000_conventions_15_type_autorite.sql
--   20260821200000_conventions_16_lot_collectivites.sql
--
-- CE QUE CES TESTS PROTÈGENT. Le chantier CONV écrit dans le corpus PARTAGÉ
-- du réseau : un point d'accès faux se propage à toutes les bibliothèques.
-- L'outillage a déjà, une fois, appliqué la règle d'inversion sans savoir à
-- quoi il avait affaire — c'est précisément le défaut que CONV-O7 répare.
-- Les gardes ci-dessous sont donc les seules choses qui empêchent de le
-- refaire, en plus grand.
--
-- Le test 6 est le moins évident et le plus important : il vérifie qu'une
-- action ANODINE (rouvrir puis sauvegarder une fiche dans le formulaire de
-- catalogage) ne défait pas un verdict humain. Le formulaire lit le jsonb,
-- pas la colonne ; si l'application n'écrivait que la colonne, le trigger de
-- la migration 15 ferait rebasculer le type au premier enregistrement venu,
-- sans que personne ne voie rien.
--
-- 8 tests :
--   1. Un compte non staff est refusé (42501).
--   2. Un lot inconnu est refusé — la CHECK et l'allowlist bougent ensemble.
--   3. « valider » écrit les TROIS faces : colonne, jsonb, point d'accès.
--   4. « écarter » n'écrit RIEN — un refus n'affirme pas « c'est une personne ».
--   5. Anti-écrasement : une fiche modifiée depuis la proposition est refusée,
--      pas écrasée, et la ligne n'est PAS marquée appliquée (CONV-O6).
--   6. Le verdict humain survit à une réouverture du brouillon (trigger).
--   7. « corriger » prend la valeur saisie par la personne, pas la proposition.
--   8. Le repérage ne confond pas une personne à la casse non normalisée
--      avec une collectivité — le piège retiré de la migration 15.
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'o7-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Revue', 'O7' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-o7-' || substr(gen_random_uuid()::text, 1, 8), 'Essai O7')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'librarian', 'active' FROM prof, lib
  RETURNING user_id
-- Quatre autorités : trois collectivités inversées (une par verdict testé)
-- et une personne dont la casse n'est pas normalisée, qui est le piège.
), a_valide AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Krisis, Grupo', 'Grupo Krisis') RETURNING id
), a_ecarte AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Proletaria, Grupo de Lucha', 'Grupo de Lucha Proletaria') RETURNING id
), a_bouge AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Libertários, Instituto de Estudos', 'Instituto de Estudos Libertários') RETURNING id
), a_corrige AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('Marseille, CIRA', 'CIRA Marseille') RETURNING id
), a_piege AS (
  INSERT INTO public.authors (sort_name, preferred_name)
  VALUES ('DOCTOROW, E. L.', 'E. L. DOCTOROW') RETURNING id
)
SELECT (SELECT id FROM prof)      AS uid,
       (SELECT id FROM a_valide)  AS id_valide,
       (SELECT id FROM a_ecarte)  AS id_ecarte,
       (SELECT id FROM a_bouge)   AS id_bouge,
       (SELECT id FROM a_corrige) AS id_corrige,
       (SELECT id FROM a_piege)   AS id_piege,
       (SELECT user_id FROM memb) AS memb_ok;

DO $$
DECLARE
  v_uid     uuid;
  v_valide  bigint;
  v_ecarte  bigint;
  v_bouge   bigint;
  v_corrige bigint;
  v_piege   bigint;
  v_app     bigint;
  v_ref     bigint;
  v_txt     text;
  v_json    text;
  v_stamp   timestamptz;
  v_n       int;
BEGIN
  SELECT uid, id_valide, id_ecarte, id_bouge, id_corrige, id_piege
    INTO v_uid, v_valide, v_ecarte, v_bouge, v_corrige, v_piege FROM t_fix;
  IF v_uid IS NULL OR v_valide IS NULL OR v_piege IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 8 (avant tout le reste : c'est une lecture) ----------------------
  -- La personne à la casse non normalisée ne doit PAS être proposée comme
  -- collectivité. C'est le motif `[A-Z]{3,}` retiré de la migration 15 :
  -- il attrapait un défaut du lot « casse » et le faisait passer pour un
  -- défaut de type.
  SELECT count(*) INTO v_n
    FROM private.v_conv_collectivites_inversees WHERE id = v_piege;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : « DOCTOROW, E. L. » proposé comme collectivité.';
  END IF;
  SELECT count(*) INTO v_n
    FROM private.v_conv_collectivites_inversees WHERE id = v_valide;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : « Krisis, Grupo » non repéré (attendu 1, obtenu %).', v_n;
  END IF;
  RAISE NOTICE 'TEST 8 OK — repérage : la collectivité oui, la personne non.';

  -- La file, telle que la migration 16 la remplit.
  -- `valeur_retenue` posée DANS l'insertion, pas après : la CHECK
  -- « corrige ⇒ valeur_retenue non vide » est vérifiée par instruction, un
  -- INSERT suivi d'un UPDATE la violerait au passage.
  INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose, decision, valeur_retenue)
  VALUES ('autorite_collectivite', 'author', v_valide,  'Krisis, Grupo', 'Grupo Krisis', 'valide', NULL),
         ('autorite_collectivite', 'author', v_ecarte,  'Proletaria, Grupo de Lucha', 'Grupo de Lucha Proletaria', 'ecarte', NULL),
         ('autorite_collectivite', 'author', v_bouge,   'Libertários, Instituto de Estudos', 'Instituto de Estudos Libertários', 'valide', NULL),
         ('autorite_collectivite', 'author', v_corrige, 'Marseille, CIRA', 'CIRA Marseille', 'corrige',
          'CIRA — Centre international de recherches sur l''anarchisme (Marseille)');

  -- La fiche « bouge » a changé depuis la proposition : quelqu'un d'autre
  -- est passé par là. L'instantané `avant` est donc périmé.
  UPDATE public.authors SET sort_name = 'Libertarios, Instituto de Estudos'
   WHERE id = v_bouge;

  -- 1 ----------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM api.conv_revue_appliquer('autorite_collectivite');
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : un compte non staff a appliqué des verdicts.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 1 OK — application refusée à un compte non staff.';
  END;

  -- Contexte staff pour la suite.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- 2 ----------------------------------------------------------------
  BEGIN
    PERFORM api.conv_revue_appliquer('autorite_collectivites');  -- pluriel : n'existe pas
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : un lot inconnu a été accepté.';
  EXCEPTION WHEN invalid_parameter_value THEN
    RAISE NOTICE 'TEST 2 OK — lot inconnu refusé.';
  END;

  -- Application.
  SELECT applique, refuse INTO v_app, v_ref
    FROM api.conv_revue_appliquer('autorite_collectivite');

  -- 3 ----------------------------------------------------------------
  SELECT sort_name INTO v_txt FROM public.authors WHERE id = v_valide;
  IF v_txt <> 'Grupo Krisis' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : point d''accès non dé-inversé (obtenu « % »).', v_txt;
  END IF;
  SELECT preferred_name INTO v_txt FROM public.authors WHERE id = v_valide;
  IF v_txt <> 'Grupo Krisis' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : forme d''affichage incorrecte (obtenu « % »).', v_txt;
  END IF;
  SELECT authority_type INTO v_txt FROM public.authors WHERE id = v_valide;
  IF v_txt IS DISTINCT FROM 'collective' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : authority_type = % au lieu de collective.', coalesce(v_txt, 'NULL');
  END IF;
  SELECT structured_meta->>'authorityType' INTO v_json FROM public.authors WHERE id = v_valide;
  IF v_json IS DISTINCT FROM 'collective' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : le jsonb n''a pas suivi (obtenu %). Le formulaire '
                    'de catalogage lirait encore l''ancienne valeur.', coalesce(v_json, 'NULL');
  END IF;
  SELECT applique_le INTO v_stamp FROM public.catalog_review_queue
   WHERE entity_id = v_valide AND lot = 'autorite_collectivite';
  IF v_stamp IS NULL THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : ligne appliquée mais non marquée — elle serait rejouée.';
  END IF;
  RAISE NOTICE 'TEST 3 OK — colonne, jsonb et point d''accès écrits ensemble.';

  -- 4 ----------------------------------------------------------------
  SELECT sort_name INTO v_txt FROM public.authors WHERE id = v_ecarte;
  IF v_txt <> 'Proletaria, Grupo de Lucha' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : une fiche écartée a été réécrite (« % »).', v_txt;
  END IF;
  SELECT authority_type INTO v_txt FROM public.authors WHERE id = v_ecarte;
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : un refus a écrit le type « % ». Refuser « c''est une '
                    'collectivité inversée » ne dit pas « c''est une personne ».', v_txt;
  END IF;
  RAISE NOTICE 'TEST 4 OK — un refus n''écrit rien.';

  -- 5 ----------------------------------------------------------------
  SELECT sort_name INTO v_txt FROM public.authors WHERE id = v_bouge;
  IF v_txt <> 'Libertarios, Instituto de Estudos' THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : une fiche modifiée depuis la proposition a été '
                    'écrasée (« % »). Le travail de quelqu''un d''autre est perdu.', v_txt;
  END IF;
  SELECT applique_le INTO v_stamp FROM public.catalog_review_queue
   WHERE entity_id = v_bouge AND lot = 'autorite_collectivite';
  IF v_stamp IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : ligne marquée appliquée alors que rien ne l''a été — '
                    'elle sortirait de la file sans que le catalogue ait bougé.';
  END IF;
  IF v_ref < 1 THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : la ligne refusée n''est pas comptée (refuse = %).', v_ref;
  END IF;
  RAISE NOTICE 'TEST 5 OK — fiche périmée refusée, comptée, non marquée.';

  -- 6 ----------------------------------------------------------------
  -- On rejoue ce que fait le formulaire de catalogage : il réécrit
  -- `structured_meta` entier à partir de son propre état. Comme
  -- l'application a écrit le jsonb en même temps que la colonne, le
  -- formulaire relit « collective » et le renvoie tel quel.
  UPDATE public.authors
     SET structured_meta = jsonb_build_object('authorityType',
                             structured_meta->>'authorityType')
   WHERE id = v_valide;
  SELECT authority_type INTO v_txt FROM public.authors WHERE id = v_valide;
  IF v_txt IS DISTINCT FROM 'collective' THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le verdict humain a été défait par une simple '
                    'réouverture de brouillon (type devenu %).', coalesce(v_txt, 'NULL');
  END IF;
  RAISE NOTICE 'TEST 6 OK — le verdict survit à une réouverture du brouillon.';

  -- 7 ----------------------------------------------------------------
  SELECT sort_name INTO v_txt FROM public.authors WHERE id = v_corrige;
  IF v_txt <> 'CIRA — Centre international de recherches sur l''anarchisme (Marseille)' THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : la valeur saisie par la personne a été ignorée au '
                    'profit de la proposition de l''outil (obtenu « % »).', v_txt;
  END IF;
  RAISE NOTICE 'TEST 7 OK — la valeur humaine prime sur la proposition.';

  -- Bilan au format attendu par le runner : il ne considère une suite comme
  -- verte que s'il lit « … OK : N/N ». Sans cette ligne, tous les tests
  -- peuvent passer et la suite compter pour rouge (« crash précoce »).
  RAISE NOTICE 'CONV-O7 OK : 8/8 tests passés (appliquées=%, refusées=%).', v_app, v_ref;
END $$;

ROLLBACK;
