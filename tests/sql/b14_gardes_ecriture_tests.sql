-- ===========================================================================
-- B14 — deux fonctions gardées dans le corps, deux fermées dans le droit
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. Le paquet 4 du tri des fonctions
-- `SECURITY DEFINER` de `public` exposées à `authenticated` a trouvé quatre
-- fonctions sans garde d'appelant :
--
--   * `fn_next_tombo(uuid)` — rend le prochain numéro d'inventaire d'une
--     bibliothèque, donc **le nombre d'exemplaires qu'elle a déjà catalogués** ;
--   * `link_book_contributors_to_authors(bigint)` — **écrit**, sans rien
--     vérifier, sur les notices de n'importe quelle bibliothèque ;
--   * `fn_recompute_serial_holdings(bigint, uuid)` — écrit l'état de collection ;
--   * `fn_backup_heartbeat_status()` — état des sauvegardes.
--
-- Les deux premières sont appelées DIRECTEMENT par les écrans de catalogage
-- (`ExemplarDraftForm`, `BookDraftForm`). Leur retirer `EXECUTE` aurait
-- remplacé un refus par un écran mort — le piège déjà rencontré sur
-- `api.confirm_pickup_v1`. Elles gardent donc leur droit et ont reçu une garde
-- dans le corps (`DOC-RPC-3`). Les deux autres n'ont aucun appelant en session :
-- pour elles le droit EST le bon endroit.
--
-- D'où deux invariants de sens opposé, et c'est tout l'intérêt de les tenir
-- ensemble : un correctif qui « uniformiserait » les quatre casserait quelque
-- chose dans un sens ou dans l'autre.
-- ===========================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_manque text;
  v_n int;
BEGIN
  -- ---------------------------------------------------------------------
  -- T1 — les deux gardées portent une garde qui refuse vraiment
  -- ---------------------------------------------------------------------
  -- On ne se contente pas de voir le nom du prédicat : une garde qui ne lève
  -- pas est une garde décorative. On exige le prédicat ET un refus 42501.
  v_t := 'T1 les deux fonctions du catalogage portent une garde qui leve 42501';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname)
      INTO v_manque
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_next_tombo', 'link_book_contributors_to_authors')
       AND (p.prosrc !~ 'user_has_library_staff_role' OR p.prosrc !~ '42501');

    IF v_manque IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : garde absente sur -> ' || v_manque
        || ' | fn_next_tombo rend la volumetrie d''un fonds, link_book_contributors ECRIT');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — ... et restent appelables par authenticated
  -- ---------------------------------------------------------------------
  -- L'invariant inverse du T3. Le catalogage les appelle en session : leur
  -- retirer EXECUTE remplacerait un refus lisible par un ecran mort.
  v_t := 'T2 les deux fonctions du catalogage restent exposees a authenticated';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_next_tombo', 'link_book_contributors_to_authors')
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

    IF v_n = 2 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_n || '/2 exposees'
        || ' | ExemplarDraftForm et BookDraftForm les appellent directement');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — les deux sans appelant en session restent fermées
  -- ---------------------------------------------------------------------
  v_t := 'T3 les deux fonctions sans appelant en session restent fermees';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname)
      INTO v_manque
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_backup_heartbeat_status', 'fn_recompute_serial_holdings')
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

    IF v_manque IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : rouvertes -> ' || v_manque
        || ' | une CREATE OR REPLACE reapplique les droits par defaut du schema :'
        || ' remettre le REVOKE dans la migration qui recree la fonction');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T4 — service_role garde ce dont l'exploitation a besoin
  -- ---------------------------------------------------------------------
  -- Le T3 passerait aussi si quelqu'un revoquait TOUT le monde : health-probe
  -- s'arreterait alors de rapporter, et c'est la sonde des sauvegardes.
  v_t := 'T4 service_role conserve fn_backup_heartbeat_status';
  BEGIN
    IF has_function_privilege('service_role', 'public.fn_backup_heartbeat_status()', 'EXECUTE') THEN
      v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : perdu | health-probe ne rapporterait plus'
        || ' l''etat des sauvegardes, et son silence ressemble a du vert');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN (RAISE = rollback ; le runner lit ce message)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'B14_GARDES_ECRITURE OK : %/% tests passés (0 skips)',
      v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'B14_GARDES_ECRITURE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed + v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
