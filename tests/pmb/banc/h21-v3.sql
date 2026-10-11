-- =====================================================================
-- H21 lot 8 — le « troisième export » : joué APRÈS h21-v2.sql, sur la même
-- base (tests/pmb/banc/deuxieme-export-h21.sh), sauvegardée avant et
-- restaurée après ; PMB exporte ensuite le fichier
-- (tests/pmb/fixtures/pmb-8.1.1.1_jeu-de-test-v3.*).
-- =====================================================================

-- retire-reapparait : l'exemplaire 18 (DVD « Chili », 001 18), supprimé avant
-- le deuxième export — et retiré dans AnarBib depuis —, revient dans PMB tel
-- qu'il était (restauré d'une sauvegarde : même expl_id, même code-barres).
INSERT INTO exemplaires (expl_id, expl_cb, expl_notice, expl_bulletin, expl_typdoc, expl_cote, expl_section, expl_statut,
                         expl_location, expl_codestat, expl_date_depot, expl_note, expl_owner, create_date)
VALUES (18, '3370000451290', 18, 0, 14, 'DVD TF1', 10, 1, 1, 12, '2004-08-04',
        'vérifier la présence du livret avant de prêter', 2, '2005-01-01 00:00:00');

-- ajoute-apres-v2 : un exemplaire neuf sur « Nimitz » (001 53), entré dans
-- PMB après le deuxième export (sert au cas « plus récent que le run »).
INSERT INTO exemplaires (expl_cb, expl_notice, expl_bulletin, expl_typdoc, expl_cote, expl_section, expl_statut,
                         expl_location, expl_codestat, expl_date_depot, expl_note, expl_owner, create_date)
SELECT 'H21L8-V3-53', 53, 0, expl_typdoc, 'RK ROB 2', expl_section, expl_statut,
       expl_location, expl_codestat, expl_date_depot, '', expl_owner, '2026-10-11 10:00:00'
  FROM exemplaires WHERE expl_id = 30;
