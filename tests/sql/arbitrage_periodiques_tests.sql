-- ===========================================================================
-- Arbitrer une revue se garde comme arbitrer un livre
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. Le chantier DOUBLONS P4 a tranché que
-- **l'arbitrage destructeur revient à la coordination** : `merge_book` et ses
-- sœurs appellent `fn_is_dedup_arbiter()`. Les périodiques, livrés le 27/08/2026,
-- n'ont pas repris la décision — leurs trois fonctions d'arbitrage appelaient
-- `fn_caller_is_staff()`, qui accepte tout rôle `librarian` dans n'importe
-- quelle bibliothèque du réseau. Aligné le 01/09/2026, après décision
-- collective et préavis aux quatre personnes concernées.
--
-- **Une décision prise à un endroit ne se propage pas toute seule à un chantier
-- livré trois mois plus tard.** C'est le vrai objet de cette suite : elle ne
-- garde pas une fonction, elle garde la *correspondance* entre deux familles de
-- gestes. Le T3 est donc aussi important que le T1 — il tient l'autre moitié de
-- la décision, celle qu'un correctif trop large emporterait sans le dire :
-- **cataloguer une revue reste ouvert au catalogage.** Repérer un doublon et
-- trancher un doublon sont deux actes différents ; fermer le premier priverait
-- la coordination de ce qui la fait travailler (DOUBLONS P8, « le test 1 garde
-- l'OUVERTURE du geste »).
-- ===========================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_skipped int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_manque text;
  v_lib uuid;
  v_serial bigint;
  v_msg text;
BEGIN
  -- ---------------------------------------------------------------------
  -- T1 — les trois gestes d'arbitrage exigent l'arbitre
  -- ---------------------------------------------------------------------
  v_t := 'T1 l arbitrage des revues exige fn_is_dedup_arbiter';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_manque
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('merge_serial','mark_serials_not_duplicate','unmark_serials_not_duplicate')
       AND p.prosrc !~ 'fn_is_dedup_arbiter';

    IF v_manque IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ouvert au staff sur -> ' || v_manque
        || ' | DOUBLONS P4 reserve l arbitrage destructeur a la coordination ;'
        || ' merge_book le fait, merge_serial doit le faire aussi');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — l'épreuve : une bibliothécaire sans coordination est refusée
  -- ---------------------------------------------------------------------
  -- Relire le corps ne prouve pas que la garde mord. On APPELLE, avec un couple
  -- d'identifiants identiques : le contrôle métier refusera ce couple de toute
  -- façon, donc rien ne peut être détruit — et le MESSAGE dit lequel des deux
  -- contrôles a parlé.
  v_t := 'T2 une bibliothecaire sans coordination est refusee a la garde';
  BEGIN
    SELECT m.user_id INTO v_lib FROM public.user_library_memberships m
     WHERE m.status = 'active' AND m.role = 'librarian'
       AND m.user_id NOT IN (SELECT user_id FROM public.user_library_memberships
                              WHERE status = 'active' AND role = 'coordenador')
       AND m.user_id NOT IN (SELECT user_id FROM public.network_administrators
                              WHERE status = 'active')
     LIMIT 1;
    SELECT id INTO v_serial FROM public.serials LIMIT 1;

    IF v_lib IS NULL OR v_serial IS NULL THEN
      v_skipped := v_skipped + 1;
      RAISE NOTICE 'T2 saute : pas de bibliothecaire sans coordination, ou pas de periodique';
    ELSE
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', v_lib, 'role', 'authenticated')::text, true);
      v_msg := '';
      BEGIN
        PERFORM public.mark_serials_not_duplicate(v_serial, v_serial, 'test');
        v_msg := '(aucun refus)';
      EXCEPTION WHEN OTHERS THEN v_msg := SQLERRM;
      END;
      PERFORM set_config('request.jwt.claims', NULL, true);

      IF v_msg ~ 'Arbitragem' THEN v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t || ' : message rendu = « ' || v_msg || ' »'
          || ' | attendu le refus d arbitrage ; un autre message signifie que la garde'
          || ' a ete franchie et que seul le controle metier a parle');
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', NULL, true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — l'autre moitié : cataloguer une revue reste ouvert au catalogage
  -- ---------------------------------------------------------------------
  v_t := 'T3 le catalogage des revues n a pas ete ferme au passage';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_manque
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_serial_create','fn_serial_update','fn_serial_attach_issue',
                         'fn_serial_detach_issue','fn_serial_set_filiation',
                         'suggest_serial_duplicates','list_serials_not_duplicate')
       AND p.prosrc !~ 'fn_caller_is_staff';

    IF v_manque IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ferme sur -> ' || v_manque
        || ' | la decision porte sur l ARBITRAGE, pas sur la saisie ni sur le'
        || ' signalement ; fermer le signalement priverait la coordination de ce'
        || ' qui la fait travailler (DOUBLONS P8)');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T4 — les deux familles se refusent dans les mêmes termes
  -- ---------------------------------------------------------------------
  -- Deux refus qui disent la même chose de deux façons finissent par diverger,
  -- et l'interface les traite alors comme deux cas.
  v_t := 'T4 revues et livres refusent l arbitrage dans les memes termes';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_manque
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('merge_serial','mark_serials_not_duplicate','unmark_serials_not_duplicate',
                         'merge_book','mark_books_not_duplicate','unmark_books_not_duplicate')
       AND p.prosrc !~ 'Arbitragem reservada';

    IF v_manque IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : libelle divergent sur -> ' || v_manque);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ARBITRAGE_PERIODIQUES OK : %/% tests passés (% skips)',
      v_passed, (v_passed + v_failed), v_skipped;
  ELSE
    RAISE EXCEPTION 'ARBITRAGE_PERIODIQUES ECHEC : %/% OK, % échec(s), % skip(s) | %',
      v_passed, (v_passed + v_failed), v_failed, v_skipped, array_to_string(v_failures, ' || ');
  END IF;
END $$;
