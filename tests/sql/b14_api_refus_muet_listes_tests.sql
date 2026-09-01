-- ===========================================================================
-- B14 — une liste réservée refuse, elle ne paraît pas vide
--       (les cinq report_* et fn_authority_list)
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. Six fonctions de liste réservées
-- écrivaient leur garde avec un `RETURN;` nu : pour l'appelant·e, « vous n'avez
-- pas le droit » et « il n'y a rien » étaient le même octet. Sur des RAPPORTS
-- DE QUALITÉ, c'est pire qu'ailleurs — une liste vide y signifie « le catalogue
-- est sain ». Un refus déguisé en bilan rassurant (`DOC-SILENCE-1`).
--
-- L'invariant gardé ici est une FORME, pas un cas : *aucune fonction de liste
-- réservée du schéma `api` ne refuse en rendant vide.* Il se vérifie par
-- introspection (T1), ce qui le rend insensible à l'ajout d'une septième
-- fonction — elle sera attrapée le jour où elle arrivera avec un `RETURN;` nu.
--
-- T2 et T3 éprouvent l'EFFET sur le cas réellement atteignable par l'interface
-- (`fn_authority_list`, servie par `/atelier-autoridades`, une page sans garde
-- de rôle) : une personne inscrite sans mandat reçoit un refus, pas un vide.
--
-- Acteurs (supabase/seed.sql) :
--   22222222-…  compte sans aucun rôle    → ni staff, ni contributeur, ni admin
--   11111111-…  coordenador de BLMF-test  → staff : passe la garde de l'Atelier
-- ===========================================================================

DO $$
DECLARE
  c_sans_role constant uuid := '22222222-2222-2222-2222-222222222222';
  c_staff     constant uuid := '11111111-1111-1111-1111-111111111111';

  v_passed  int := 0;
  v_failed  int := 0;
  v_skipped int := 0;
  v_failures text[] := '{}';
  v_skips    text[] := '{}';
  v_t text;
  v_reste text;
  v_n int;
BEGIN
  -- ---------------------------------------------------------------------
  -- T1 — la FORME : aucune garde de liste ne se termine par un RETURN nu
  -- ---------------------------------------------------------------------
  v_t := 'T1 aucune fonction de liste reservee ne refuse en rendant vide';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname)
      INTO v_reste
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'api'
       AND p.proname IN ('report_auteurs_non_resolus', 'report_autorites_a_completer',
                         'report_autorites_doublons', 'report_documents_incomplets',
                         'report_incoherences_auteurs', 'fn_authority_list')
       AND p.prosrc ~ 'THEN\s*\n\s*RETURN;';

    IF v_reste IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : refus muet sur -> ' || v_reste
        || ' | une liste reservee qui rend vide fait passer un refus pour un bilan');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T1b — les six existent toujours et restent appelables par authenticated
  -- ---------------------------------------------------------------------
  -- Le refus vit dans le CORPS, jamais dans le droit (doctrine RPC du projet) :
  -- fermer EXECUTE casserait les écrans au lieu de refuser proprement.
  v_t := 'T1b les six restent exposees a authenticated';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'api'
       AND p.proname IN ('report_auteurs_non_resolus', 'report_autorites_a_completer',
                         'report_autorites_doublons', 'report_documents_incomplets',
                         'report_incoherences_auteurs', 'fn_authority_list')
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

    IF v_n = 6 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_n || '/6 exposees'
        || ' | un EXECUTE retire casserait l''ecran au lieu de refuser');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — L'EFFET : sans mandat, l'Atelier refuse au lieu de paraître vide
  -- ---------------------------------------------------------------------
  v_t := 'T2 fn_authority_list refuse a qui n''a aucun mandat';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = c_sans_role) THEN
      v_skipped := v_skipped + 1;
      v_skips := v_skips || (v_t || ' : persona « sans role » absent du seed');
    ELSE
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', c_sans_role, 'role', 'authenticated')::text, true);
      BEGIN
        PERFORM count(*) FROM api.fn_authority_list();
        PERFORM set_config('request.jwt.claims', '', true);
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t
          || ' : l''appel a REUSSI (liste vide) au lieu de lever'
          || ' | « pas le droit » et « rien a deliberer » redeviennent indiscernables');
      EXCEPTION WHEN insufficient_privilege THEN
        PERFORM set_config('request.jwt.claims', '', true);
        v_passed := v_passed + 1;
      WHEN OTHERS THEN
        PERFORM set_config('request.jwt.claims', '', true);
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t || ' : leve, mais pas en 42501 -> ' || SQLERRM);
      END;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — et le staff, lui, passe toujours (on n'a pas fermé la porte)
  -- ---------------------------------------------------------------------
  v_t := 'T3 le staff accede toujours a l''Atelier';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = c_staff) THEN
      v_skipped := v_skipped + 1;
      v_skips := v_skips || (v_t || ' : persona staff absent du seed');
    ELSE
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);
      PERFORM count(*) FROM api.fn_authority_list();
      PERFORM set_config('request.jwt.claims', '', true);
      v_passed := v_passed + 1;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM
      || ' | le durcissement a ferme la porte au staff');
  END;

  -- =====================================================================
  -- BILAN (RAISE = rollback de toute la transaction, fixtures comprises)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'B14_REFUS_MUET OK : %/% tests passés (% skips)%',
      v_passed, (v_passed + v_failed), v_skipped,
      CASE WHEN v_skipped > 0 THEN ' | SKIPS: ' || array_to_string(v_skips, ' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'B14_REFUS_MUET ECHEC : %/% OK, % échec(s) | %  (skips: %)',
      v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || '), array_to_string(v_skips, ' ; ');
  END IF;
END $$;
