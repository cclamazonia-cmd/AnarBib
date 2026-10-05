-- =====================================================================
-- AnarBib — Tests : la colonne de revue de digital_assets s'appelle
-- review_state (C10).
-- Date    : 2026-10-05
-- Réf     : supabase/migrations/20261005162356_l_etat_de_revue_d_un_fichier_s_appelle_review_state.sql
--
--   · digital_assets porte review_state (colonne, CHECK, index renommés) ;
--     les trois autres tables gardent rights_status (vocabulaire des droits,
--     statut déclaré par la partenaire) ;
--   · les six fonctions ne lisent plus digital_assets.rights_status ;
--     fn_attach_received_asset_record garde ses trois mentions de l'AUTRE sens ;
--   · la confirmation, la liste des vérifiés, le compte et l'export des fonds
--     marchent et parlent de review_state ;
--   · la liste des vérifiés, recréée, garde DEFINER, search_path, commentaire
--     et droits (ni PUBLIC ni anon).
-- Convention maison : RAISE EXCEPTION final, tout est annulé.
--   Bilan OK : 'C10-ETAT-DE-REVUE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_lib uuid; v_book bigint; v_asset bigint; v_autre bigint;
  v_res jsonb; v_n int; v_txt text; v_err text; v_etat text;
BEGIN
  INSERT INTO auth.users (id, email) VALUES (v_admin, v_admin::text || '@c10-test.invalid');
  INSERT INTO public.profiles (id) VALUES (v_admin) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active)
    VALUES ('c10-test-' || substr(v_admin::text, 1, 8), 'C10 Test', 'federated', 'full_sigb', true) RETURNING id INTO v_lib;
  INSERT INTO public.books DEFAULT VALUES RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib);
  INSERT INTO public.digital_assets (book_id, title, source_name, bucket_name, object_path, asset_kind, is_public, review_state)
    VALUES (v_book, 'C10 à revoir', 'test', 'pdf-restrito', 'c10/a.pdf', 'pdf', false, 'to_review') RETURNING id INTO v_asset;
  INSERT INTO public.digital_assets (book_id, title, source_name, bucket_name, object_path, asset_kind, is_public, review_state)
    VALUES (v_book, 'C10 restreint', 'test', 'pdf-restrito', 'c10/b.pdf', 'pdf', false, 'restricted') RETURNING id INTO v_autre;

  v_t := 'T1 digital_assets porte review_state (CHECK, index) ; les trois autres tables gardent rights_status';
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='digital_assets' AND column_name='review_state')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='digital_assets' AND column_name='rights_status')
     AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname='digital_assets_review_state_check' AND conrelid='public.digital_assets'::regclass)
     AND to_regclass('public.digital_assets_review_state_idx') IS NOT NULL
     AND to_regclass('public.digital_assets_rights_status_idx') IS NULL
     AND (SELECT count(*) FROM information_schema.columns WHERE column_name='rights_status'
           AND (table_schema, table_name) IN (('public','book_digital_resources'),('public','book_draft_digital_resources'),('ingest','partner_catalog_received_assets'))) = 3
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  v_t := 'T2 plus aucune fonction ne lit digital_assets.rights_status ; l''attachement garde ses trois mentions de l''autre sens';
  SELECT string_agg(p.proname, ', ') INTO v_txt FROM pg_proc p
   WHERE p.proname IN ('fn_confirm_digital_asset_rights','fn_export_fonds_eligible_count','fn_export_fonds_records',
                       'fn_list_verified_digital_assets','fn_publish_digital_asset_from_resource')
     AND pg_get_functiondef(p.oid) LIKE '%rights_status%';
  SELECT (length(d) - length(replace(d, 'rights_status', ''))) / 13 INTO v_n
    FROM (SELECT pg_get_functiondef('public.fn_attach_received_asset_record(bigint,bigint,text,text,text)'::regprocedure) d) x;
  IF v_txt IS NULL AND v_n = 3
     AND pg_get_functiondef('public.fn_attach_received_asset_record(bigint,bigint,text,text,text)'::regprocedure) LIKE '%review_state, bucket_name, object_path%'
     AND pg_get_functiondef('public.fn_attach_received_asset_record(bigint,bigint,text,text,text)'::regprocedure) LIKE '%''review_state'', CASE WHEN v_asset_id%'
     AND NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.prosrc ~ 'da\.rights_status')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : encore='||coalesce(v_txt,'-')||' attachement='||v_n); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;

  v_t := 'T3 la confirmation pose review_state et le rend sous cette clé ; une seconde fois, rien ne change';
  v_res := public.fn_confirm_digital_asset_rights(v_asset);
  RESET ROLE;
  SELECT review_state INTO v_etat FROM public.digital_assets WHERE id = v_asset;
  SET LOCAL ROLE authenticated;
  IF (v_res->>'changed')::boolean AND v_res->>'review_state' = 'public_domain_confirmed' AND NOT v_res ? 'rights_status'
     AND v_etat = 'public_domain_confirmed'
     AND (public.fn_confirm_digital_asset_rights(v_asset)->>'review_state') = 'public_domain_confirmed'
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_res::text,'NULL')||' état='||coalesce(v_etat,'NULL')); END IF;

  v_t := 'T4 un fichier dans un autre état n''est pas confirmé, et le message nomme cet état';
  v_err := NULL;
  BEGIN PERFORM public.fn_confirm_digital_asset_rights(v_autre);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
  IF v_err LIKE '%restricted%' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_err,'aucune erreur')); END IF;

  v_t := 'T5 la liste des vérifiés rend la colonne review_state';
  SELECT count(*) FILTER (WHERE review_state = 'public_domain_confirmed'), count(*) INTO v_n, v_txt
    FROM public.fn_list_verified_digital_assets(v_lib);
  IF v_n = 1 AND v_txt = '2' THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/'||v_txt); END IF;

  v_t := 'T6 le compte des notices exportables lit review_state';
  v_n := public.fn_export_fonds_eligible_count(v_lib);
  IF v_n = 1 THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n); END IF;

  v_t := 'T7 l''export des fonds écrit review_state (format d''échange), plus rights_status';
  v_res := public.fn_export_fonds_records(v_lib, ARRAY[v_book]);
  v_txt := v_res::text;
  IF v_txt LIKE '%"review_state": "public_domain_confirmed"%' AND v_txt NOT LIKE '%"rights_status"%' AND v_txt LIKE '%c10/a.pdf%' AND v_txt NOT LIKE '%c10/b.pdf%'
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(v_txt, 300)); END IF;
  RESET ROLE;

  v_t := 'T8 la liste recréée garde DEFINER, search_path, commentaire et droits (ni PUBLIC ni anon)';
  IF (SELECT prosecdef FROM pg_proc WHERE oid = 'public.fn_list_verified_digital_assets(uuid)'::regprocedure)
     AND (SELECT proconfig::text FROM pg_proc WHERE oid = 'public.fn_list_verified_digital_assets(uuid)'::regprocedure) LIKE '%search_path=public, ingest, auth, pg_catalog%'
     AND obj_description('public.fn_list_verified_digital_assets(uuid)'::regprocedure, 'pg_proc') LIKE '%review_state%'
     AND pg_get_function_result('public.fn_list_verified_digital_assets(uuid)'::regprocedure) LIKE '%review_state text%'
     AND has_function_privilege('authenticated', 'public.fn_list_verified_digital_assets(uuid)', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.fn_list_verified_digital_assets(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_list_verified_digital_assets(uuid)', 'EXECUTE')
     AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                      WHERE p.oid = 'public.fn_list_verified_digital_assets(uuid)'::regprocedure
                        AND a.grantee = 0 AND a.privilege_type = 'EXECUTE')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' KO'); END IF;

  PERFORM set_config('request.jwt.claims', '', true);
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'C10-ETAT-DE-REVUE OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'C10-ETAT-DE-REVUE ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
