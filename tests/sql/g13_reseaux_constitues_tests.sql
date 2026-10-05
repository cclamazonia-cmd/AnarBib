-- =====================================================================
-- AnarBib — Tests : les réseaux constitués, du texte de la carte au
-- catalogue public (G13).
-- Date    : 2026-10-05
-- Réf     : supabase/migrations/20261005173015_les_reseaux_constitues_ont_un_vocabulaire.sql
--
--   · le vocabulaire : FICEDL, RebAL, NORLA, ABABA en « documentation » ; FAI,
--     FAI Reggiana, FAO, AFI en « organisation_politique » ; les centres sociaux
--     et Radical Routes en « autre » ; plus rien à classer ;
--   · la lecture d'un texte de réseaux (séparateurs, casse, doublons, ordre,
--     jetons hors vocabulaire) ;
--   · le déclencheur tient `reseaux` sur `reseau`, et l'emporte sur une
--     écriture directe ;
--   · aucune fiche existante n'a de `reseaux` qui diverge de son texte ;
--   · le catalogue public (anon) ne voit que les réseaux « documentation »,
--     par une fiche de carte PUBLIQUE d'une bibliothèque visible ;
--   · droits : la fonction du catalogue s'exécute en anon, les deux autres
--     non ; le vocabulaire se lit, ne s'écrit pas.
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'G13-RESEAUX OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_pub uuid; v_isolee uuid; v_e1 uuid; v_e2 uuid; v_e3 uuid;
  v_arr text[]; v_res jsonb; v_n int;
BEGIN
  -- Classement complété le 05/10 (migration « les cinq réseaux à classer… »).
  v_t := 'T1 le vocabulaire et ses natures';
  IF (SELECT count(*) FROM public.networks) >= 10
     AND (SELECT array_agg(slug ORDER BY slug) FROM public.networks WHERE kind = 'documentation') = ARRAY['ababa','ficedl','norla','rebal']
     AND (SELECT array_agg(slug ORDER BY slug) FROM public.networks WHERE kind = 'organisation_politique') = ARRAY['afi','fai','fai-reggiana','fao']
     AND (SELECT array_agg(slug ORDER BY slug) FROM public.networks WHERE kind = 'autre') = ARRAY['radical-routes','uk-social-centre-network']
     AND (SELECT count(*) FROM public.networks WHERE kind IS NULL) = 0
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  v_t := 'T2 la lecture d''un texte : séparateurs, casse, doublons, ordre, jetons inconnus';
  IF public.fn_cartography_reseaux_de('RebAL ; FICEDL') = ARRAY['rebal','ficedl']
     AND public.fn_cartography_reseaux_de('rebal, FAI') = ARRAY['rebal','fai']
     AND public.fn_cartography_reseaux_de('FAI Reggiana') = ARRAY['fai-reggiana']
     AND public.fn_cartography_reseaux_de('Inconnu ;  ficedl ,FICEDL') = ARRAY['ficedl']
     AND public.fn_cartography_reseaux_de('') = '{}'::text[]
     AND public.fn_cartography_reseaux_de(NULL) = '{}'::text[]
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(public.fn_cartography_reseaux_de('RebAL ; FICEDL')::text,'NULL')); END IF;

  INSERT INTO public.libraries (slug, name, short_name, network_mode, circulation_mode, is_active, visibility_level)
    VALUES ('g13-pub-' || v_suf, 'G13 Publique', 'G13P', 'federated', 'full_sigb', true, 'public') RETURNING id INTO v_pub;
  INSERT INTO public.libraries (slug, name, short_name, network_mode, catalog_mode, circulation_mode, is_active, visibility_level)
    VALUES ('g13-iso-' || v_suf, 'G13 Isolée', 'G13I', 'isolated', 'local_only', 'full_sigb', true, 'public') RETURNING id INTO v_isolee;

  v_t := 'T3 le déclencheur tient reseaux sur reseau, et l''emporte sur une écriture directe';
  INSERT INTO public.cartography_entries (library_id, slug, categorie, statut_anarbib, statut_public, lat, lon, reseau)
    VALUES (v_pub, 'g13-a-' || v_suf, 'biblioteca', 'membre', true, 0, 0, 'FICEDL, Truc') RETURNING id INTO v_e1;
  SELECT reseaux INTO v_arr FROM public.cartography_entries WHERE id = v_e1;
  IF v_arr = ARRAY['ficedl'] THEN
    UPDATE public.cartography_entries SET reseau = 'RebAL; FICEDL' WHERE id = v_e1;
    SELECT reseaux INTO v_arr FROM public.cartography_entries WHERE id = v_e1;
    IF v_arr = ARRAY['rebal','ficedl'] THEN
      UPDATE public.cartography_entries SET reseaux = ARRAY['fai'] WHERE id = v_e1;
      SELECT reseaux INTO v_arr FROM public.cartography_entries WHERE id = v_e1;
    END IF;
  END IF;
  IF v_arr = ARRAY['rebal','ficedl'] THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_arr::text,'NULL')); END IF;

  v_t := 'T4 aucune fiche n''a de reseaux qui diverge de son texte';
  SELECT count(*) INTO v_n FROM public.cartography_entries WHERE reseaux IS DISTINCT FROM public.fn_cartography_reseaux_de(reseau);
  IF v_n = 0 THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n); END IF;

  -- Une fiche NON publique (même bibliothèque), une fiche d'une bibliothèque
  -- isolée, et un réseau politique : aucun ne doit paraître au catalogue.
  INSERT INTO public.cartography_entries (library_id, slug, categorie, statut_anarbib, statut_public, lat, lon, reseau)
    VALUES (v_pub, 'g13-b-' || v_suf, 'biblioteca', 'membre', false, 0, 0, 'NORLA') RETURNING id INTO v_e2;
  INSERT INTO public.cartography_entries (library_id, slug, categorie, statut_anarbib, statut_public, lat, lon, reseau)
    VALUES (v_isolee, 'g13-c-' || v_suf, 'biblioteca', 'membre', true, 0, 0, 'FICEDL; FAI') RETURNING id INTO v_e3;

  PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  SET LOCAL ROLE anon;
  v_res := api.fn_catalog_networks_v1();
  RESET ROLE;

  v_t := 'T5 le catalogue public voit FICEDL et RebAL avec la bibliothèque publique';
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_res) r, jsonb_array_elements(r->'libraries') l
              WHERE r->>'slug' = 'ficedl' AND l->>'slug' = 'g13-pub-' || v_suf AND l->>'short_name' = 'G13P')
     AND EXISTS (SELECT 1 FROM jsonb_array_elements(v_res) r, jsonb_array_elements(r->'libraries') l
              WHERE r->>'slug' = 'rebal' AND l->>'slug' = 'g13-pub-' || v_suf)
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text, 300)); END IF;

  v_t := 'T6 ni fiche non publique (NORLA), ni bibliothèque isolée, ni organisation politique (FAI)';
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_res) r WHERE r->>'slug' IN ('norla', 'fai'))
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_res) r, jsonb_array_elements(r->'libraries') l
                      WHERE l->>'slug' = 'g13-iso-' || v_suf)
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_res::text, 300)); END IF;

  v_t := 'T7 droits : le catalogue s''exécute en anon ; la lecture et le déclencheur non ; le vocabulaire se lit, ne s''écrit pas';
  IF has_function_privilege('anon', 'api.fn_catalog_networks_v1()', 'EXECUTE')
     AND has_function_privilege('authenticated', 'api.fn_catalog_networks_v1()', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_cartography_reseaux_de(text)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.fn_cartography_reseaux_de(text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.tg_cartography_reseaux()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.tg_cartography_reseaux()', 'EXECUTE')
     AND has_table_privilege('anon', 'public.networks', 'SELECT')
     AND NOT has_table_privilege('anon', 'public.networks', 'INSERT')
     AND NOT has_table_privilege('authenticated', 'public.networks', 'UPDATE')
     AND (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.networks'::regclass)
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  PERFORM set_config('request.jwt.claims', '', true);
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'G13-RESEAUX OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'G13-RESEAUX ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
