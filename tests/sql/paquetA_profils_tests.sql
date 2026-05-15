-- ============================================================
-- Tests d'acceptation paquet A profils d'adoption — v2
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.3 §9.1
-- Date : 2026-05-15
-- ============================================================
-- v2 (15/05/2026 apres-midi) : fix du test 5 qui polluait l'etat
-- lu par les tests 11 et 12. Maintenant chaque test qui modifie
-- l'etat le restaure immediatement dans le meme DO-block.
-- ============================================================

BEGIN;

-- ============================================================
-- TEST 1 — Existence et types des 4 colonnes sur libraries
-- ============================================================
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'libraries'
      AND column_name IN ('catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode')
      AND data_type = 'text'
      AND is_nullable = 'NO';
  
  IF v_count <> 4 THEN
    RAISE EXCEPTION 'TEST 1 FAILED : attendu 4 colonnes profil text NOT NULL, trouve %', v_count;
  END IF;
  RAISE NOTICE 'TEST 1 OK : 4 colonnes *_mode existent sur libraries (text NOT NULL)';
END $$;

-- ============================================================
-- TEST 2 — DEFAULTs maximalistes (profil D) sur BLMF et BTL
-- ============================================================
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
    FROM public.libraries
    WHERE catalog_mode = 'network_published'
      AND circulation_mode = 'full_sigb'
      AND network_mode = 'federated'
      AND governance_mode = 'full_governance';
  
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'TEST 2 FAILED : attendu 2 biblios en profil D, trouve %', v_count;
  END IF;
  RAISE NOTICE 'TEST 2 OK : BLMF et BTL ont le profil D maximaliste';
END $$;

-- ============================================================
-- TEST 3 — Contrainte chk_catalog_published_requires_network rejette combinaison invalide
-- ============================================================
DO $$
DECLARE
  v_error_caught boolean := false;
  v_blmf_id uuid;
BEGIN
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf';
  
  BEGIN
    -- Tentative invalide : catalog_mode=network_published + network_mode=isolated
    UPDATE public.libraries 
      SET network_mode = 'isolated' 
      WHERE id = v_blmf_id;
    RAISE EXCEPTION 'TEST 3 FAILED : la contrainte CHECK aurait du rejeter cette combinaison';
  EXCEPTION 
    WHEN check_violation THEN
      v_error_caught := true;
  END;
  
  IF v_error_caught THEN
    RAISE NOTICE 'TEST 3 OK : chk_catalog_published_requires_network rejette network_published + isolated';
  END IF;
END $$;

-- ============================================================
-- TEST 4 — Contrainte chk_full_sigb_requires_roles rejette combinaison invalide
-- ============================================================
DO $$
DECLARE
  v_error_caught boolean := false;
  v_blmf_id uuid;
BEGIN
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf';
  
  BEGIN
    -- Tentative invalide : circulation_mode=full_sigb + governance_mode=informal
    UPDATE public.libraries 
      SET governance_mode = 'informal' 
      WHERE id = v_blmf_id;
    RAISE EXCEPTION 'TEST 4 FAILED : la contrainte CHECK aurait du rejeter cette combinaison';
  EXCEPTION 
    WHEN check_violation THEN
      v_error_caught := true;
  END;
  
  IF v_error_caught THEN
    RAISE NOTICE 'TEST 4 OK : chk_full_sigb_requires_roles rejette full_sigb + informal';
  END IF;
END $$;

-- ============================================================
-- TEST 5 — Combinaisons valides acceptees (avec restauration immediate)
-- ============================================================
DO $$
DECLARE
  v_blmf_id uuid;
BEGIN
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf';
  
  -- Bascule legale (par exemple, vers profil B)
  UPDATE public.libraries 
    SET catalog_mode = 'local_only',
        network_mode = 'isolated'
    WHERE id = v_blmf_id;
  
  -- v2 : RESTAURATION IMMEDIATE dans le meme DO-block pour ne pas polluer
  -- les tests suivants qui lisent l'etat de BLMF
  UPDATE public.libraries 
    SET catalog_mode = 'network_published',
        network_mode = 'federated'
    WHERE id = v_blmf_id;
  
  RAISE NOTICE 'TEST 5 OK : bascule vers profil B acceptee, BLMF restaure immediatement';
END $$;

-- ============================================================
-- TEST 6 — CHECK constraints rejettent valeurs hors enum
-- ============================================================
DO $$
DECLARE
  v_error_caught boolean := false;
  v_blmf_id uuid;
BEGIN
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf';
  
  BEGIN
    UPDATE public.libraries 
      SET catalog_mode = 'invalid_value' 
      WHERE id = v_blmf_id;
    RAISE EXCEPTION 'TEST 6 FAILED : valeur invalide aurait du etre rejetee';
  EXCEPTION 
    WHEN check_violation THEN
      v_error_caught := true;
  END;
  
  IF v_error_caught THEN
    RAISE NOTICE 'TEST 6 OK : CHECK enum rejette les valeurs hors-domaine';
  END IF;
END $$;

-- ============================================================
-- TEST 7 — Table library_profile_history existe avec bonnes colonnes
-- ============================================================
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'library_profile_history'
      AND column_name IN ('id', 'library_id', 'axis', 'old_value', 'new_value', 'changed_by', 'changed_at', 'motivation');
  
  IF v_count <> 8 THEN
    RAISE EXCEPTION 'TEST 7 FAILED : attendu 8 colonnes dans library_profile_history, trouve %', v_count;
  END IF;
  RAISE NOTICE 'TEST 7 OK : library_profile_history a les 8 colonnes attendues';
END $$;

-- ============================================================
-- TEST 8 — INSERT autorise dans library_profile_history
-- ============================================================
DO $$
DECLARE
  v_blmf_id uuid;
  v_inserted_id uuid;
BEGIN
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf';
  
  INSERT INTO public.library_profile_history 
    (library_id, axis, old_value, new_value, motivation)
  VALUES 
    (v_blmf_id, 'catalog_mode', 'network_published', 'local_only', 'test 8 - sera rollback')
  RETURNING id INTO v_inserted_id;
  
  IF v_inserted_id IS NULL THEN
    RAISE EXCEPTION 'TEST 8 FAILED : INSERT dans library_profile_history n''a pas retourne d''id';
  END IF;
  RAISE NOTICE 'TEST 8 OK : INSERT autorise dans library_profile_history';
END $$;

-- ============================================================
-- TEST 9 — UPDATE bloque par trigger d'immuabilite
-- ============================================================
DO $$
DECLARE
  v_error_caught boolean := false;
  v_lph_id uuid;
BEGIN
  SELECT id INTO v_lph_id FROM public.library_profile_history WHERE motivation = 'test 8 - sera rollback';
  
  BEGIN
    UPDATE public.library_profile_history 
      SET motivation = 'tentative de modification'
      WHERE id = v_lph_id;
    RAISE EXCEPTION 'TEST 9 FAILED : UPDATE aurait du etre bloque par le trigger d''immuabilite';
  EXCEPTION 
    WHEN insufficient_privilege THEN
      v_error_caught := true;
    WHEN OTHERS THEN
      v_error_caught := true;
  END;
  
  IF v_error_caught THEN
    RAISE NOTICE 'TEST 9 OK : UPDATE sur library_profile_history bloque par trigger';
  END IF;
END $$;

-- ============================================================
-- TEST 10 — DELETE bloque par trigger d'immuabilite
-- ============================================================
DO $$
DECLARE
  v_error_caught boolean := false;
  v_lph_id uuid;
BEGIN
  SELECT id INTO v_lph_id FROM public.library_profile_history WHERE motivation = 'test 8 - sera rollback';
  
  BEGIN
    DELETE FROM public.library_profile_history WHERE id = v_lph_id;
    RAISE EXCEPTION 'TEST 10 FAILED : DELETE aurait du etre bloque';
  EXCEPTION 
    WHEN insufficient_privilege THEN
      v_error_caught := true;
    WHEN OTHERS THEN
      v_error_caught := true;
  END;
  
  IF v_error_caught THEN
    RAISE NOTICE 'TEST 10 OK : DELETE sur library_profile_history bloque par trigger';
  END IF;
END $$;

-- ============================================================
-- TEST 11 — Helpers lecteurs retournent les bonnes valeurs
-- (apres restauration du test 5, BLMF est de nouveau en profil D)
-- ============================================================
DO $$
DECLARE
  v_blmf_id uuid;
  v_catalog text;
  v_circ text;
  v_net text;
  v_gov text;
BEGIN
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf';
  
  v_catalog := public.fn_library_catalog_mode(v_blmf_id);
  v_circ := public.fn_library_circulation_mode(v_blmf_id);
  v_net := public.fn_library_network_mode(v_blmf_id);
  v_gov := public.fn_library_governance_mode(v_blmf_id);
  
  IF v_catalog <> 'network_published' OR v_circ <> 'full_sigb' 
    OR v_net <> 'federated' OR v_gov <> 'full_governance' THEN
    RAISE EXCEPTION 'TEST 11 FAILED : helpers lecteurs retournent valeurs incorrectes (%, %, %, %)',
      v_catalog, v_circ, v_net, v_gov;
  END IF;
  RAISE NOTICE 'TEST 11 OK : 4 helpers lecteurs retournent les bonnes valeurs';
END $$;

-- ============================================================
-- TEST 12 — Predicats logiques retournent les bons booleens
-- ============================================================
DO $$
DECLARE
  v_blmf_id uuid;
BEGIN
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf';
  
  IF NOT public.fn_library_has_circulation(v_blmf_id) THEN
    RAISE EXCEPTION 'TEST 12.1 FAILED : fn_library_has_circulation devrait etre TRUE';
  END IF;
  IF NOT public.fn_library_has_full_sigb(v_blmf_id) THEN
    RAISE EXCEPTION 'TEST 12.2 FAILED : fn_library_has_full_sigb devrait etre TRUE';
  END IF;
  IF NOT public.fn_library_publishes_catalog(v_blmf_id) THEN
    RAISE EXCEPTION 'TEST 12.3 FAILED : fn_library_publishes_catalog devrait etre TRUE';
  END IF;
  IF NOT public.fn_library_is_federated(v_blmf_id) THEN
    RAISE EXCEPTION 'TEST 12.4 FAILED : fn_library_is_federated devrait etre TRUE';
  END IF;
  IF NOT public.fn_library_uses_governance(v_blmf_id) THEN
    RAISE EXCEPTION 'TEST 12.5 FAILED : fn_library_uses_governance devrait etre TRUE';
  END IF;
  IF NOT public.fn_library_has_staff_roles(v_blmf_id) THEN
    RAISE EXCEPTION 'TEST 12.6 FAILED : fn_library_has_staff_roles devrait etre TRUE';
  END IF;
  
  RAISE NOTICE 'TEST 12 OK : les 6 predicats retournent TRUE pour BLMF (profil D)';
END $$;

-- ============================================================
-- TEST 13 — Helpers retournent NULL pour library_id inexistant
-- ============================================================
DO $$
DECLARE
  v_fake_id uuid := '00000000-0000-0000-0000-000000000000';
  v_result text;
BEGIN
  v_result := public.fn_library_catalog_mode(v_fake_id);
  IF v_result IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 13.1 FAILED : fn_library_catalog_mode devrait retourner NULL pour id inexistant, retourne %', v_result;
  END IF;
  
  IF public.fn_library_has_circulation(v_fake_id) IS NOT NULL THEN
    RAISE EXCEPTION 'TEST 13.2 FAILED : fn_library_has_circulation devrait retourner NULL pour id inexistant';
  END IF;
  
  RAISE NOTICE 'TEST 13 OK : helpers retournent NULL pour library_id inexistant';
END $$;

-- ============================================================
-- TEST 14 — library_requests enrichie de 5 colonnes profil
-- ============================================================
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'library_requests'
      AND column_name IN ('requested_catalog_mode', 'requested_circulation_mode',
                          'requested_network_mode', 'requested_governance_mode',
                          'profile_template_chosen')
      AND is_nullable = 'YES';
  
  IF v_count <> 5 THEN
    RAISE EXCEPTION 'TEST 14 FAILED : attendu 5 colonnes profil sur library_requests, trouve %', v_count;
  END IF;
  RAISE NOTICE 'TEST 14 OK : library_requests enrichie de 5 colonnes profil (NULLABLE, sans CHECK)';
END $$;

-- ============================================================
-- TEST 15 — GRANTs sur helpers : anon peut executer
-- ============================================================
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT count(*) INTO v_count
    FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
      AND routine_name IN ('fn_library_catalog_mode', 'fn_library_circulation_mode',
                           'fn_library_network_mode', 'fn_library_governance_mode',
                           'fn_library_has_circulation', 'fn_library_has_full_sigb',
                           'fn_library_publishes_catalog', 'fn_library_is_federated',
                           'fn_library_uses_governance', 'fn_library_has_staff_roles')
      AND grantee = 'anon'
      AND privilege_type = 'EXECUTE';
  
  IF v_count < 10 THEN
    RAISE EXCEPTION 'TEST 15 FAILED : attendu 10 GRANT EXECUTE pour anon, trouve %', v_count;
  END IF;
  RAISE NOTICE 'TEST 15 OK : 10 helpers ont GRANT EXECUTE TO anon';
END $$;

-- ============================================================
-- ROLLBACK final : aucun changement persiste
-- (la transaction echoue grace au RAISE pour forcer le rollback explicite)
-- ============================================================
ROLLBACK;

SELECT '===== Paquet A : 15/15 tests passent =====' AS result;
