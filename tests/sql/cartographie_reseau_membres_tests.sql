-- ===========================================================================
-- La carte en travail est pour les membres
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. La carte réseau
-- (`api.cartography_network_v1`, corps `private.fn_cartography_network_rows`)
-- rendait TOUTES les entrées de cartographie — y compris les non publiques — à
-- tout compte authentifié. L'inscription étant ouverte, « savoir créer un
-- compte » suffisait à voir des entrées qui peuvent être **en attente de
-- consentement** (doctrine des mentions orphelines : le consentement précède
-- l'exposition d'un collectif). Mesuré le 01/09/2026 : 79 entrées non publiques
-- sur 187, visibles de quiconque. Décision collective du même jour : les
-- entrées non publiques sont pour les **membres actifs**.
--
-- POURQUOI CES TESTS APPELLENT. La garde vit dans un `WHERE` de fonction SQL —
-- vérifier sa présence textuelle ne prouve pas qu'elle filtre. T1 et T2
-- fabriquent le cas (une entrée non publique, un compte sans adhésion) et
-- regardent ce qui sort. Le T3 tient l'autre moitié : l'écran des membres doit
-- continuer de tout montrer — une garde qui cacherait la carte aux membres
-- serait un écran cassé, pas une protection.
-- ===========================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_skipped int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_sans uuid;
  v_membre uuid;
  v_n int;
  v_total int;
BEGIN
  -- Fixture : une entrée NON publique, garantie présente quel que soit le seed.
  -- Pas d'ON CONFLICT : la table n'a AUCUNE contrainte unique sur slug (vérifié
  -- le 01/09), et un ON CONFLICT sans contrainte correspondante est une erreur,
  -- pas un no-op. Le RAISE final annule la fixture ; lat/lon sont NOT NULL.
  INSERT INTO public.cartography_entries (slug, categorie, statut_public, lat, lon, name_i18n)
  VALUES ('carto-test-non-publique', 'biblioteca', false, 0, 0,
          '{"fr":"Entree de test non publique"}'::jsonb);

  SELECT p.id INTO v_sans FROM public.profiles p
   WHERE NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                      WHERE m.user_id = p.id AND m.status = 'active')
     AND NOT EXISTS (SELECT 1 FROM public.network_administrators na
                      WHERE na.user_id = p.id AND na.status = 'active')
   LIMIT 1;
  SELECT m.user_id INTO v_membre FROM public.user_library_memberships m
   WHERE m.status = 'active' LIMIT 1;

  SELECT count(*) INTO v_total FROM public.cartography_entries;

  -- ---------------------------------------------------------------------
  -- T1 — un compte sans adhésion ne voit AUCUNE entrée non publique
  -- ---------------------------------------------------------------------
  v_t := 'T1 un compte sans adhesion ne voit aucune entree non publique';
  IF v_sans IS NULL THEN
    v_skipped := v_skipped + 1;
    RAISE NOTICE 'T1 saute : aucun compte sans adhesion dans cette base';
  ELSE
    BEGIN
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', v_sans, 'role', 'authenticated')::text, true);
      SELECT count(*) INTO v_n FROM private.fn_cartography_network_rows() r
       WHERE r.slug = 'carto-test-non-publique';
      PERFORM set_config('request.jwt.claims', NULL, true);

      IF v_n = 0 THEN v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t || ' : entree non publique servie'
          || ' | l''inscription est ouverte — « savoir creer un compte » redevient'
          || ' un droit de voir ce qui attend un consentement');
      END IF;
    EXCEPTION WHEN OTHERS THEN
      PERFORM set_config('request.jwt.claims', NULL, true);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
    END;
  END IF;

  -- ---------------------------------------------------------------------
  -- T2 — ... mais il voit toujours la carte PUBLIQUE
  -- ---------------------------------------------------------------------
  -- T1 passerait aussi si la fonction ne rendait plus rien : l'ecran des
  -- comptes sans adhesion doit montrer la meme carte que les visiteurs.
  v_t := 'T2 un compte sans adhesion voit la carte publique';
  IF v_sans IS NULL THEN
    v_skipped := v_skipped + 1;
  ELSE
    BEGIN
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', v_sans, 'role', 'authenticated')::text, true);
      SELECT count(*) INTO v_n FROM private.fn_cartography_network_rows();
      PERFORM set_config('request.jwt.claims', NULL, true);

      IF v_n = (SELECT count(*) FROM public.cartography_entries WHERE statut_public) THEN
        v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t || ' : ' || v_n || ' vues au lieu des publiques'
          || ' | la garde a trop mordu — l''ecran montre moins que la page visiteurs');
      END IF;
    EXCEPTION WHEN OTHERS THEN
      PERFORM set_config('request.jwt.claims', NULL, true);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
    END;
  END IF;

  -- ---------------------------------------------------------------------
  -- T3 — un membre actif voit tout
  -- ---------------------------------------------------------------------
  v_t := 'T3 un membre actif voit toutes les entrees';
  IF v_membre IS NULL THEN
    v_skipped := v_skipped + 1;
    RAISE NOTICE 'T3 saute : aucun membre actif dans cette base';
  ELSE
    BEGIN
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', v_membre, 'role', 'authenticated')::text, true);
      SELECT count(*) INTO v_n FROM private.fn_cartography_network_rows();
      PERFORM set_config('request.jwt.claims', NULL, true);

      IF v_n = v_total THEN v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t || ' : ' || v_n || '/' || v_total
          || ' | une garde qui cache la carte aux membres est un ecran casse,'
          || ' pas une protection');
      END IF;
    EXCEPTION WHEN OTHERS THEN
      PERFORM set_config('request.jwt.claims', NULL, true);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
    END;
  END IF;

  -- ---------------------------------------------------------------------
  -- T4 — la carte publique des visiteurs n'a pas bougé
  -- ---------------------------------------------------------------------
  v_t := 'T4 la vue publique reste servie a anon et filtree sur statut_public';
  BEGIN
    IF has_table_privilege('anon', 'api.cartography_public_v1', 'SELECT')
       AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = 'private' AND p.proname = 'fn_cartography_public_rows'
                      AND p.prosrc ~ 'statut_public = true') THEN
      v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : la page visiteurs est cassee ou le filtre a saute');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN (le RAISE annule la fixture)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'CARTO_RESEAU_MEMBRES OK : %/% tests passés (% skips)',
      v_passed, (v_passed + v_failed), v_skipped;
  ELSE
    RAISE EXCEPTION 'CARTO_RESEAU_MEMBRES ECHEC : %/% OK, % échec(s), % skip(s) | %',
      v_passed, (v_passed + v_failed), v_failed, v_skipped, array_to_string(v_failures, ' || ');
  END IF;
END $$;
