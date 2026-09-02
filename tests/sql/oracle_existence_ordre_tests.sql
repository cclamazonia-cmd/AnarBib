-- ===========================================================================
-- Un refus ne dit pas si la chose existe — même quand il ne dit pas « pertence »
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR, ET EN QUOI ELLE DIFFÈRE DE SA SŒUR.
-- `b14_oracle_existence_forme_tests.sql` garde le même invariant, mais par le
-- MOTIF du message (« não pertence » et ses variantes). Ce motif a fermé
-- quatorze fonctions le 01/09 au matin — et n'a pas pu en voir neuf autres, qui
-- disaient la même chose avec d'autres mots : « Acesso restrito », « Você não
-- tem permissão », « Este empréstimo pertence a outra pessoa ».
--
-- **Chercher un vocabulaire ne trouve que ce qui parle la même langue.** Le
-- critère qui atteint ces neuf-là est structurel : un test d'existence placé
-- avant le contrôle de droit, sur un identifiant qu'on peut deviner. On ne peut
-- pas inverser cet ordre — la garde porte sur la bibliothèque DE L'OBJET, qu'il
-- faut donc avoir lu — donc on unifie ce que les deux refus disent.
--
-- LE PIÈGE QUE CETTE SUITE TIENT, ET QUE L'AUTRE A LAISSÉ PASSER.
-- `fn_attach_received_asset_record` avait été « corrigée » le matin : deux de
-- ses trois refus unifiés, le troisième oublié — et un seul suffit à rouvrir
-- l'oracle. La garde de l'autre suite (« le motif a-t-il disparu ? ») passait au
-- vert. Celle-ci pose la bonne question : **reste-t-il deux refus
-- distinguables ?** Une fonction corrigée n'est pas une fonction close.
--
-- CE QUI N'EST DÉLIBÉRÉMENT PAS GARDÉ : les identifiants `uuid`. Deux refus
-- distincts y sont sans portée — un uuid ne se devine pas — et les inclure
-- ferait rougir la suite sur des cas sains, ce qui est la meilleure façon de
-- faire cesser de la lire.
-- ===========================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_reste text;
  v_n int;
BEGIN
  -- ---------------------------------------------------------------------
  -- T1 — les neuf du paquet 6 ne portent plus deux refus distinguables
  -- ---------------------------------------------------------------------
  v_t := 'T1 les neuf fonctions du paquet 6 rendent un refus unique';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_reste
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_confirm_digital_asset_rights','fn_publish_digital_asset_from_resource',
                         'fn_attach_received_asset_record','fn_import_set_adapter_overrides',
                         'fn_import_set_profile','fn_set_circulation_limits','discard_exemplar',
                         'fn_v2_schedule_emprestimo_return','fn_v2_clear_emprestimo_return_schedule')
       AND (p.prosrc ~ 'Acesso restrito ao coordenador da biblioteca'
            OR p.prosrc ~ 'Acesso restrito ao staff da biblioteca'
            OR p.prosrc ~ 'não tem permissão para descartar exemplares'
            OR p.prosrc ~ 'pertence a outra pessoa');

    IF v_reste IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : refus distinguable sur -> ' || v_reste
        || ' | l identifiant est sequentiel : deux messages distincts laissent'
        || ' enumerer ce qui existe dans le reseau');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — l'identifiant ne revient pas dans le message
  -- ---------------------------------------------------------------------
  -- Rendre l'identifiant dans un refus est deja une confirmation qu'on l'a lu :
  -- le message devient un oracle meme s'il est unique.
  v_t := 'T2 aucun refus de ces fonctions ne renvoie l identifiant demande';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_reste
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_confirm_digital_asset_rights','fn_publish_digital_asset_from_resource',
                         'fn_import_set_adapter_overrides','fn_import_set_profile','discard_exemplar')
       AND p.prosrc ~ 'introuvável\.''\s*,\s*p_|encontrado \(ID %\)';

    IF v_reste IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : identifiant rendu par -> ' || v_reste);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — le refus vit dans le corps, pas dans le droit
  -- ---------------------------------------------------------------------
  -- T1 passerait aussi si quelqu'un fermait ces fonctions a tout le monde :
  -- l ecran mourrait au lieu de refuser proprement (DOC-RPC-3).
  -- 02/09/2026 : T3 exigeait les NEUF exposees — il gardait d'un lot ce qui
  -- n'etait vrai que de sept (quatrieme occurrence du motif note a l'audit du
  -- 01/09 : « un test qui enumere plusieurs objets doit garder ce qui est vrai
  -- de chacun »). Les deux fn_v2_*_return* n'ont jamais servi aucun ecran :
  -- fermees par 20260902103305 (B20 lot circulation), leur forme de refus
  -- reste gardee par T1/T2 — le corps n'a pas change, seul le droit d'entree.
  v_t := 'T3 les sept qui servent un ecran restent appelables par authenticated';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_confirm_digital_asset_rights','fn_publish_digital_asset_from_resource',
                         'fn_attach_received_asset_record','fn_import_set_adapter_overrides',
                         'fn_import_set_profile','fn_set_circulation_limits','discard_exemplar')
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

    IF v_n = 7 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_n || '/7 exposees'
        || ' | fermer l EXECUTE casse l ecran au lieu de refuser');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  v_t := 'T3b les deux fermees le restent';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_v2_schedule_emprestimo_return','fn_v2_clear_emprestimo_return_schedule')
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

    IF v_n = 0 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_n || ' rouverte(s)'
        || ' | l agendamento de retour n a aucun ecran — sa reouverture se decide, ne se constate pas');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ORACLE_EXISTENCE_ORDRE OK : %/% tests passés (0 skips)',
      v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'ORACLE_EXISTENCE_ORDRE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed + v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
