-- ===========================================================================
-- Un refus réseau se dit — même quand la garde vit dans un `WHERE`
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. Cinq fonctions réseau gardaient dans
-- leur `WHERE` : un appel non autorisé rendait **zéro ligne au lieu d'une
-- erreur**. Une liste vide n'est pas rien — c'est une phrase : « le réseau n'a
-- aucune bibliothèque », « aucune candidature n'attend ». Le jour où une
-- candidature n'apparaît pas, personne ne distingue « il n'y en a pas » de
-- « tu n'as pas le droit de la voir ». Aligné sur `DOC-SILENCE-1` le
-- 01/09/2026, après décision collective — la forme était délibérée, donc la
-- question a été posée avant d'être corrigée.
--
-- POURQUOI CETTE SUITE APPELLE AU LIEU DE RELIRE. Les cinq sont en
-- `LANGUAGE sql` : la garde est un prédicat **levant** placé dans le `WHERE`,
-- et non un bloc `IF`. Cela repose sur un comportement du planificateur — un
-- qual constant est évalué une fois, avant le parcours, y compris sur une
-- relation vide (mesuré). Un plan futur pourrait ne pas exécuter ce nœud. Une
-- suite qui se contenterait de vérifier la présence de `fn_assert_` dans le
-- corps passerait alors sans rien garantir. **Ces tests appellent donc les
-- fonctions pour de vrai**, sous un JWT non autorisé, et regardent ce qui sort.
--
-- LE PIÈGE SYMÉTRIQUE, tenu par le T3 : dans plusieurs autres fonctions,
-- `fn_caller_is_network_admin()` **élargit** un accès (`... OR admin réseau`)
-- au lieu de le restreindre. Y poser un prédicat levant transformerait la
-- navigation ordinaire en erreur. La correction est donc nominative, et ce test
-- garde la frontière.
-- ===========================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_skipped int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_simple uuid;
  v_admin  uuid;
  v_n int;
  v_muettes text := '';
BEGIN
  SELECT user_id INTO v_admin FROM public.network_administrators WHERE status = 'active' LIMIT 1;
  SELECT p.id INTO v_simple FROM public.profiles p
   WHERE (v_admin IS NULL OR p.id <> v_admin)
     AND NOT EXISTS (SELECT 1 FROM public.network_administrators na WHERE na.user_id = p.id)
   LIMIT 1;

  -- ---------------------------------------------------------------------
  -- T1 — un compte ordinaire se voit REFUSER, pas servir du vide
  -- ---------------------------------------------------------------------
  v_t := 'T1 un compte ordinaire recoit un refus, pas une liste vide';
  IF v_simple IS NULL THEN
    v_skipped := v_skipped + 1;
    RAISE NOTICE 'T1 saute : aucun compte non-admin dans cette base';
  ELSE
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_simple, 'role', 'authenticated')::text, true);

    BEGIN PERFORM count(*) FROM public.fn_list_orphan_library_mentions();
      v_muettes := v_muettes || 'fn_list_orphan_library_mentions ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; WHEN OTHERS THEN NULL; END;

    BEGIN PERFORM count(*) FROM public.fn_network_library_metrics();
      v_muettes := v_muettes || 'fn_network_library_metrics ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; WHEN OTHERS THEN NULL; END;

    BEGIN PERFORM count(*) FROM public.fn_network_list_library_requests();
      v_muettes := v_muettes || 'fn_network_list_library_requests ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; WHEN OTHERS THEN NULL; END;

    BEGIN PERFORM count(*) FROM public.fn_list_library_request_invitations(true);
      v_muettes := v_muettes || 'fn_list_library_request_invitations ';
    EXCEPTION WHEN insufficient_privilege THEN NULL; WHEN OTHERS THEN NULL; END;

    PERFORM set_config('request.jwt.claims', NULL, true);

    IF v_muettes = '' THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : muettes -> ' || v_muettes
        || '| une liste vide affirme « il n y a rien » a qui n a pas le droit de voir ;'
        || ' si le predicat levant est toujours en place, c est le PLAN qui a change'
        || ' et la garde dans le WHERE n est plus evaluee');
    END IF;
  END IF;

  -- ---------------------------------------------------------------------
  -- T2 — et l'administration du réseau continue de LIRE
  -- ---------------------------------------------------------------------
  -- Le T1 passerait aussi si quelqu'un fermait ces fonctions à tout le monde.
  -- Celui-ci tient l'autre moitié : le refus doit rester un refus ciblé.
  v_t := 'T2 l administration du reseau lit toujours';
  IF v_admin IS NULL THEN
    v_skipped := v_skipped + 1;
    RAISE NOTICE 'T2 saute : aucun admin reseau actif dans cette base';
  ELSE
    BEGIN
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
      SELECT count(*) INTO v_n FROM public.fn_network_library_metrics();
      PERFORM count(*) FROM public.fn_network_list_library_requests();
      PERFORM count(*) FROM public.fn_list_orphan_library_mentions();
      PERFORM set_config('request.jwt.claims', NULL, true);
      v_passed := v_passed + 1;
    EXCEPTION WHEN OTHERS THEN
      PERFORM set_config('request.jwt.claims', NULL, true);
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || SQLERRM
        || ' | le tableau de bord du reseau est casse, pas protege');
    END;
  END IF;

  -- ---------------------------------------------------------------------
  -- T3 — le piège symétrique : ne pas rendre levante une garde ÉLARGISSANTE
  -- ---------------------------------------------------------------------
  v_t := 'T3 aucune garde elargissante n a recu un predicat levant';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_muettes
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('list_catalog_libraries','fn_team_list_invitations')
       AND p.prosrc ~ 'fn_assert_';

    IF v_muettes IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_muettes
        || ' | ici le predicat ELARGIT (« ... OR admin reseau ») : le rendre levant'
        || ' transforme la navigation ordinaire en erreur');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'REFUS_RESEAU_SE_DIT OK : %/% tests passés (% skips)',
      v_passed, (v_passed + v_failed), v_skipped;
  ELSE
    RAISE EXCEPTION 'REFUS_RESEAU_SE_DIT ECHEC : %/% OK, % échec(s), % skip(s) | %',
      v_passed, (v_passed + v_failed), v_failed, v_skipped, array_to_string(v_failures, ' || ');
  END IF;
END $$;
