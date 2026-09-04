-- =====================================================================
-- AnarBib -- Le schema de sauvegarde de mai est purge (B9, decision BG2-9)
-- Date    : 2026-09-04  ·  decision Xavier (« Purge. », 04/09 au soir)
-- Depend  : 20260904184434 (la purge differee, qui a laisse le schema en place)
--
-- CE QUI A ETE RELU. Cinq tables a dix lignes, la sixieme vide : dix
-- reservations et dix prets a la BLMF du 29/03 au 30/04/2026, tous clotures,
-- avec leurs lignes et leurs etapes de workflow. Deux comptes seulement, ceux
-- des deux personnes qui testaient la circulation v2 ; des documents d'essai
-- (« Por uma Economia libertaria » quatre fois, « Renovacao 1919 »…). Copie
-- faite le 7 mai avant la bascule, tables vivantes remises a zero ensuite
-- (les reservations vivantes commencent le 18/06, id 39). Rien de reel, mais
-- deux adresses nominatives hors de toute RLS : une raison de plus de purger.
--
-- Sur une base ou le schema n'existe pas (rejeu en CI), rien a faire.
-- =====================================================================

BEGIN;

DO $$
BEGIN
  IF to_regnamespace('backup_2026_05_07') IS NULL THEN
    RAISE NOTICE 'backup_2026_05_07 : schéma absent, rien à purger';
    RETURN;
  END IF;
  EXECUTE 'DROP SCHEMA backup_2026_05_07 CASCADE';
  RAISE NOTICE 'backup_2026_05_07 : schéma supprimé (relu et décidé le 04/09/2026)';
END $$;

DO $$
BEGIN
  IF to_regnamespace('backup_2026_05_07') IS NOT NULL THEN
    RAISE EXCEPTION 'backup_2026_05_07 existe encore';
  END IF;
END $$;

COMMIT;
