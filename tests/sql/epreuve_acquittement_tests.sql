-- =====================================================================
-- AnarBib — ÉPREUVE JETABLE : un épisode rouge ne donne qu'un seul ticket
-- Date    : 2026-08-31  ·  Item I5  ·  doctrine OPS-8
--
-- CE FICHIER EST FAIT POUR ÉCHOUER, ET POUR ÊTRE RETIRÉ LE JOUR MÊME.
--
-- Ce qu'il éprouve. Le job `alerte` d'OPS-6 n'ouvre pas de ticket s'il en
-- existe déjà un portant le marqueur. Cet anti-doublon n'a JAMAIS servi :
-- jusqu'au 31/08, aucun ticket ne restait ouvert plus d'une vingtaine de
-- secondes — il était refermé à la main pour dire « j'ai vu », ce qui
-- réarmait l'alarme. D'où dix tickets le 30/08 pour un seul et même rouge.
--
-- Le va-et-vient rouge → vert a été vu ce matin sur le ticket #27 : ouvert
-- à 09:56:31 par un run rouge, refermé à 10:06:58 par le job `acquittement`,
-- une seconde après son propre commentaire. Ce qui reste à voir est l'autre
-- moitié : DEUX pushs rouges d'affilée, et un seul ticket.
--
-- Le protocole. (1) Ce fichier part au rouge : un ticket doit s'ouvrir.
-- (2) Un second push, toujours rouge : AUCUN second ticket ne doit
-- apparaître. (3) Ce fichier et sa ligne de manifeste sont retirés : le
-- ticket doit se refermer seul, avec son commentaire.
--
-- Pourquoi une suite jetable plutôt qu'une vraie suite abîmée : on ne
-- touche à rien qui compte, et le retrait est un `git rm` sans reste.
--
--   Bilan attendu : 'EPREUVE-ACQUITTEMENT ECHEC : 0/1'
--   (jamais la forme de succès — « OK » suivi de N/N — que le lanceur
--   cherche dans la SORTIE. Elle n'apparaît volontairement pas non plus
--   dans ce commentaire : psql n'échoit pas les commentaires, mais une
--   exécution en ECHO_ALL rendrait la suite verte sans qu'un seul test
--   soit passé, et l'épreuve du jour ne vaudrait plus rien.)
-- =====================================================================

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_t text;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 echec delibere, pour faire rougir la CI';
  BEGIN
    -- Aucune donnée, aucune table, aucune fonction du produit n'est touchée.
    IF 1 = 2 THEN
      v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : echec voulu, SECOND rouge de l''epreuve I5 : le ticket #27 etant deja ouvert, aucun nouveau ticket ne doit apparaitre et le job alerte doit le dire');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'EPREUVE-ACQUITTEMENT OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'EPREUVE-ACQUITTEMENT ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed + v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
