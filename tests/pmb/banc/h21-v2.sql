-- =====================================================================
-- H21 lot 8 — le « deuxième export » : ce qu'une bibliothèque change dans
-- son PMB entre deux exports (10/10/2026).
--
-- Joué par tests/pmb/banc/deuxieme-export-h21.sh sur la base du banc (jeu
-- de test PMB 8.1.1.1), sauvegardée avant et RESTAURÉE après : PMB exporte
-- ensuite lui-même le fichier (tests/pmb/fixtures/pmb-8.1.1.1_jeu-de-test-v2.*).
-- Chaque bloc est un cas de tests/pmb/h21-bout-en-bout-cas.json (même
-- identifiant) ; ce que fait AnarBib de chaque cas est prouvé par
-- tests/sql/h21_bout_en_bout_tests.sql.
--
-- Une notice PMB = son notice_id (001 du fichier) ; un exemplaire = son
-- expl_id (996 $9 expl_id) et son code-barres expl_cb (995 $f).
-- =====================================================================

-- notice-inchangee (001 1) et exemplaire-inchange (expl_id 1) : rien.

-- exemplaire-ajoute : un deuxième exemplaire sur « Catfish blues » (001 2),
-- comme le premier (même type, section, statut, localisation, prêteur).
INSERT INTO exemplaires (expl_cb, expl_notice, expl_bulletin, expl_typdoc, expl_cote, expl_section, expl_statut,
                         expl_location, expl_codestat, expl_date_depot, expl_note, expl_owner, create_date)
SELECT 'H21L8-AJOUT-2', 2, 0, expl_typdoc, 'JR HER', expl_section, expl_statut,
       expl_location, expl_codestat, expl_date_depot, '', expl_owner, '2026-10-10 10:00:00'
  FROM exemplaires WHERE expl_id = 2;

-- cote-fichier-seul : la cote de l'exemplaire 3 (« Trois fêlés et un pendu »)
-- changée dans PMB.
UPDATE exemplaires SET expl_cote = 'ER OPP 2' WHERE expl_id = 3;

-- champ-pmb-seul : l'année de « Le dieu devenu homme » (001 4) changée dans
-- PMB ; note-fichier-seul : une note ajoutée à son exemplaire (expl_id 4).
UPDATE notices SET year = '1999' WHERE notice_id = 4;
UPDATE exemplaires SET expl_note = 'Envoyé en reliure en 2026' WHERE expl_id = 4;

-- champ-anarbib-seul (001 5) et cote-anarbib-seul (expl_id 5) : rien dans PMB.

-- note-deux-cotes : la note de l'exemplaire 6 (« Le mille-pattes ») changée
-- dans PMB (et autrement dans AnarBib).
UPDATE exemplaires SET expl_note = 'Reliure refaite en 2026, peut sortir.' WHERE expl_id = 6;

-- responsabilites-changees : « Le puits » (001 7) perd sa traductrice
-- (Vassallo-Villaneau, 702).
DELETE FROM responsability WHERE responsability_notice = 7 AND responsability_author = 8;

-- conflit : l'année de « Ghetto 9 » (001 8) changée dans PMB (1993 → 1994) ;
-- AnarBib la change autrement (1995).
UPDATE notices SET year = '1994' WHERE notice_id = 8;

-- champ-vide-par-pmb : la pagination de « Zaks » (001 9) effacée dans PMB.
UPDATE notices SET npages = '' WHERE notice_id = 9;

-- partagee-appliquee : l'année de « La chambre verte » (001 10), notice que
-- la bibliothèque B détient aussi dans AnarBib.
UPDATE notices SET year = '1996' WHERE notice_id = 10;

-- partagee-ecartee : l'année du « Chirurgien hollandais » (001 11), partagée
-- elle aussi.
UPDATE notices SET year = '1997' WHERE notice_id = 11;

-- reattribuee : l'année de « Monsieur Je-sais-tout » (001 13), notice que
-- l'administration a réattribuée à B dans AnarBib.
UPDATE notices SET year = '2000' WHERE notice_id = 13;

-- reetiquete : l'exemplaire 15 (« Paroles de bonheur ») reçoit une nouvelle
-- étiquette — même expl_id, autre code-barres.
UPDATE exemplaires SET expl_cb = 'H21L8-REETIQ-15' WHERE expl_id = 15;

-- sans-code : l'exemplaire 16 (« La métamorphose des fleurs ») perd son
-- code-barres.
UPDATE exemplaires SET expl_cb = NULL WHERE expl_id = 16;

-- notice-absente : « Rwanda » (001 16) et son exemplaire (expl_id 17)
-- supprimés de PMB.
DELETE FROM exemplaires WHERE expl_notice = 16;
DELETE FROM notices WHERE notice_id = 16;

-- disparu-engage : l'exemplaire 19 (carte routière, 001 17) supprimé de PMB ;
-- dans AnarBib, il est en prêt.
DELETE FROM exemplaires WHERE expl_id = 19;

-- disparu-proposable : l'exemplaire 18 (DVD « Chili », 001 18) supprimé de PMB.
DELETE FROM exemplaires WHERE expl_id = 18;

-- code-repris : l'exemplaire 20 (CD-ROM, 001 19) supprimé, et son code-barres
-- recollé sur un nouvel exemplaire de la même notice (autre expl_id).
CREATE TEMPORARY TABLE h21_expl20 AS SELECT * FROM exemplaires WHERE expl_id = 20;
DELETE FROM exemplaires WHERE expl_id = 20;
INSERT INTO exemplaires (expl_cb, expl_notice, expl_bulletin, expl_typdoc, expl_cote, expl_section, expl_statut,
                         expl_location, expl_codestat, expl_date_depot, expl_note, expl_owner, create_date)
SELECT expl_cb, expl_notice, 0, expl_typdoc, expl_cote, expl_section, expl_statut,
       expl_location, expl_codestat, expl_date_depot, '', expl_owner, '2026-10-10 10:00:00'
  FROM h21_expl20;

-- deplace : l'exemplaire 23 (la charte, 001 42) rangé sous « Bruit de
-- cochon » (001 44).
UPDATE exemplaires SET expl_notice = 44 WHERE expl_id = 23;

-- notice-nouvelle : une notice créée dans PMB (copie de la ligne de « Bac en
-- poche », titre, ISBN, année, pagination, résumé changés), avec un exemplaire
-- neuf ; deplace-vers-nouvelle : l'exemplaire 28 (« Le Cochon d'Hollywood »,
-- 001 50) rangé sous elle.
CREATE TEMPORARY TABLE h21_notice AS SELECT * FROM notices WHERE notice_id = 1;
ALTER TABLE h21_notice MODIFY notice_id int(10) unsigned NULL;
UPDATE h21_notice SET notice_id = NULL, tit1 = 'Une notice nouvelle (H21 lot 8)', tit2 = '', tit3 = '', tit4 = '',
       code = '', year = '2026', npages = '64 p.', coll_id = 0, subcoll_id = 0, nocoll = '', n_gen = '', n_contenu = '',
       n_resume = '', indexint = 0, index_l = '', thumbnail_url = '', create_date = '2026-10-10 10:00:00';
INSERT INTO notices SELECT * FROM h21_notice;
SET @nouvelle = LAST_INSERT_ID();
INSERT INTO responsability (responsability_author, responsability_notice, responsability_fonction, responsability_type, responsability_ordre)
SELECT responsability_author, @nouvelle, responsability_fonction, responsability_type, responsability_ordre
  FROM responsability WHERE responsability_notice = 1;
INSERT INTO notices_langues (num_notice, type_langue, code_langue, ordre_langue)
SELECT @nouvelle, type_langue, code_langue, ordre_langue FROM notices_langues WHERE num_notice = 1;
INSERT INTO exemplaires (expl_cb, expl_notice, expl_bulletin, expl_typdoc, expl_cote, expl_section, expl_statut,
                         expl_location, expl_codestat, expl_date_depot, expl_note, expl_owner, create_date)
SELECT 'H21L8-NOUV-1', @nouvelle, 0, expl_typdoc, 'JR NOU', expl_section, expl_statut,
       expl_location, expl_codestat, expl_date_depot, '', expl_owner, '2026-10-10 10:00:00'
  FROM exemplaires WHERE expl_id = 1;
UPDATE exemplaires SET expl_notice = @nouvelle WHERE expl_id = 28;
