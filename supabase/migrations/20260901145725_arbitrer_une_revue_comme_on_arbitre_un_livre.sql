-- Décision du 01/09/2026 : l'arbitrage des doublons de périodiques rejoint
-- celui des livres — la coordination, pas le catalogage.
--
-- ⚠️ CETTE MIGRATION RETIRE UN POUVOIR À QUATRE PERSONNES NOMMÉES.
--    Elle ne devait pas être poussée avant qu'elles aient été prévenues —
--    règle tenue : écrite et éprouvée le 01/09 au matin, **retenue** en local
--    jusqu'à l'envoi du préavis par la coordination, poussée le 01/09
--    après-midi une fois le préavis parti. Texte et arbitrage dans
--    `docs/journal/arbitrages/DECISION_arbitrage_periodiques_2026-09-01.md`.
--
-- ============================================================================
-- L'ÉCART
-- ============================================================================
-- Le chantier DOUBLONS P4 avait tranché : **l'arbitrage destructeur est réservé
-- à la coordination**. `merge_book`, `mark_books_not_duplicate` et
-- `unmark_books_not_duplicate` appellent donc `fn_is_dedup_arbiter()` —
-- administration du réseau **ou** coordenador·es.
--
-- Les périodiques, livrés le 27/08/2026, n'ont pas repris cette décision : leurs
-- trois fonctions d'arbitrage appellent `fn_caller_is_staff()`, qui accepte tout
-- rôle `librarian`, dans n'importe quelle bibliothèque du réseau.
--
--   | Geste                            | Avant                  | Après               |
--   |----------------------------------|------------------------|---------------------|
--   | `merge_serial`                   | tout `librarian`       | arbitre             |
--   | `mark_serials_not_duplicate`     | tout `librarian`       | arbitre             |
--   | `unmark_serials_not_duplicate`   | tout `librarian`       | arbitre             |
--
-- Ce n'était pas une fuite : ce sont des membres du staff du réseau. C'était un
-- **écart de doctrine**, mesuré au paquet 5 de `B14` et porté au collectif
-- plutôt que corrigé seul, précisément parce qu'il retire un pouvoir à des
-- personnes réelles. Décision rendue le 01/09 : on aligne, en prévenant.
--
-- ============================================================================
-- CE QUI N'EST PAS TOUCHÉ, ET POURQUOI
-- ============================================================================
-- `fn_caller_is_staff()` garde dix-sept autres usages parfaitement légitimes.
-- Ne bougent pas :
--
--   * `fn_serial_create`, `fn_serial_update`, `fn_serial_attach_issue`,
--     `fn_serial_detach_issue`, `fn_serial_set_filiation` — **cataloguer reste
--     le travail du catalogage.** La décision porte sur l'arbitrage, pas sur la
--     saisie.
--   * `suggest_serial_duplicates`, `list_serials_not_duplicate` — le
--     **signalement** reste ouvert, exactement comme DOUBLONS P8 l'a voulu pour
--     les autorités : « le test 1 garde l'OUVERTURE du geste ». Repérer un
--     doublon et trancher un doublon sont deux actes différents ; fermer le
--     premier priverait la coordination de ce qui la fait travailler.
--
-- ============================================================================
-- MESSAGE
-- ============================================================================
-- Les libellés actuels deviendraient faux : « Apenas bibliotecárias e
-- coordenadoras podem editar o catálogo » et « Acesso restrito ao staff de
-- catalogacao » annonceraient un droit que la fonction ne donne plus. On reprend
-- **mot pour mot** celui que `merge_book` emploie déjà —
-- « Arbitragem reservada à coordenação. » — pour que les deux gestes se refusent
-- dans les mêmes termes.
--
-- `DOC-MSG-1` respecté : `grep -rn "SQLERRM" tests/sql/` ne rend **aucune**
-- assertion sur ces trois libellés (vérifié le 01/09).
--
-- ============================================================================
-- ÉPREUVE (production, transaction annulée)
-- ============================================================================
-- Appel de `mark_serials_not_duplicate(id, id)` — un couple d'identifiants
-- identiques, qui prouve le franchissement de la garde **sans rien détruire** :
--
--   sous le JWT d'une bibliothécaire sans coordination
--       -> « Arbitragem reservada à coordenação. »   (refusée à la garde)
--   sous le JWT d'une coordination
--       -> « Par de periódicos inválido. »           (garde franchie, contrôle métier atteint)

DO $$
DECLARE
  r record;
  v_def text;
  v_new text;
  n int := 0;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public'
       AND p.proname IN ('merge_serial', 'mark_serials_not_duplicate', 'unmark_serials_not_duplicate')
  LOOP
    v_def := pg_get_functiondef(r.oid);

    v_new := replace(v_def,
      'IF NOT public.fn_caller_is_staff() THEN',
      'IF NOT public.fn_is_dedup_arbiter() THEN');

    v_new := replace(v_new,
      'Apenas bibliotecárias e coordenadoras podem editar o catálogo.',
      'Arbitragem reservada à coordenação.');
    v_new := replace(v_new,
      'Acesso restrito ao staff de catalogacao.',
      'Arbitragem reservada à coordenação.');

    IF v_new = v_def THEN
      RAISE EXCEPTION 'public.% : garde non substituée — la fonction a changé de forme, migration interrompue plutôt que sans effet', r.proname;
    END IF;

    EXECUTE v_new;
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'arbitrage des périodiques aligné sur celui des livres : % fonction(s)', n;
END $$;

COMMENT ON FUNCTION public.merge_serial(bigint, bigint) IS
  'Fusionne deux autorités de périodique. Réservée à l''arbitrage (administration du réseau ou coordenador·es) depuis le 01/09/2026 : livrée le 27/08 avec fn_caller_is_staff, elle acceptait tout rôle librarian, ce que la décision DOUBLONS P4 refuse pour les livres. Quatre personnes ont été prévenues avant l''alignement. Cataloguer une revue reste ouvert au catalogage ; seul l''arbitrage se ferme.';

-- ============================================================================
-- GARDES DE FIN
-- ============================================================================
DO $$
DECLARE v_reste text;
BEGIN
  -- 1) Les trois portent bien la garde d'arbitrage.
  SELECT string_agg(p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('merge_serial','mark_serials_not_duplicate','unmark_serials_not_duplicate')
     AND p.prosrc !~ 'fn_is_dedup_arbiter';

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'arbitrage encore ouvert au staff sur : % — rollback', v_reste;
  END IF;

  -- 2) Le catalogage des revues n'a PAS été fermé au passage. C'est la moitié
  --    de la décision qu'un correctif trop large emporterait sans le dire.
  SELECT string_agg(p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_serial_create','fn_serial_update','fn_serial_attach_issue',
                       'fn_serial_detach_issue','fn_serial_set_filiation',
                       'suggest_serial_duplicates','list_serials_not_duplicate')
     AND p.prosrc !~ 'fn_caller_is_staff';

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'le catalogage des revues a été fermé par erreur sur : % — rollback', v_reste;
  END IF;
END $$;
