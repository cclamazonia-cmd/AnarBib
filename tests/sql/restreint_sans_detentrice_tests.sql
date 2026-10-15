-- =====================================================================
-- AnarBib — Tests d'acceptation : un PDF restreint sans bibliothèque
-- détentrice devient observable (backlog v34 D19 ; décision du 20/08,
-- DOC-SILENCE-1)
-- Date    : 2026-10-15  ·  Session : File de candidats PDF
-- Ref     : migration 20261015202816_restreint_sans_detentrice_observable
--
-- T1  retirer la dernière détention d'un livre à PDF restreint : la
--     coordination de cette bibliothèque et l'administration du réseau sont
--     avisées (une notification chacune, lien vers la fiche) ; le contrôle
--     liste la ressource
-- T2  une détentrice reste : aucun avis, rien au contrôle
-- T3  un PDF public sans détentrice : aucun avis (il reste lisible)
-- T4  le contrôle est vide pour une coordination, refusé à anon ; le
--     déclencheur n'est exécutable par personne
-- T5  rien n'est interdit : la ressource reste active
--
--   Bilan OK : 'RESTREINT-SANS-DETENTRICE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_blmf   constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- seed
  v_coordA constant uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin  constant uuid := 'b1900000-0000-4000-8000-000000000001';
  v_libB uuid;
  v_seul bigint; v_partage bigint; v_public bigint;
  v_rseul bigint;
  v_res jsonb;
  v_n int;
BEGIN
  INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_admin, 'authenticated', 'authenticated', 'numdif.d19.admin@anarbib.local',
          now(), now(), now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb) ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
  VALUES (v_admin, 'numdif.d19.admin@anarbib.local', 'Admin', 'D19', 'fr') ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.libraries (slug, name, is_active, visibility_level)
  VALUES ('essai-d19-b', 'Essai D19 B', true, 'public') RETURNING id INTO v_libB;

  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Essai D19 seul', 'TEST-D19-1', 'livro', 'ambos', true) RETURNING id INTO v_seul;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Essai D19 partagé', 'TEST-D19-2', 'livro', 'ambos', true) RETURNING id INTO v_partage;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Essai D19 public', 'TEST-D19-3', 'livro', 'ambos', true) RETURNING id INTO v_public;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count)
  VALUES (v_seul, c_blmf, 0, 0), (v_partage, c_blmf, 1, 1), (v_partage, v_libB, 1, 1), (v_public, c_blmf, 0, 0);
  INSERT INTO public.book_digital_resources (book_id, resource_type, access_scope, status, is_active, storage_bucket, storage_path,
                                             rights_status, bibliographic_match_validated)
  VALUES (v_seul, 'pdf_restrito', 'conta_ativa', 'active', true, 'pdf-restrito', 'books/' || v_seul || '/1_x.pdf', 'sob_direitos', true)
  RETURNING id INTO v_rseul;
  INSERT INTO public.book_digital_resources (book_id, resource_type, access_scope, status, is_active, storage_bucket, storage_path,
                                             rights_status, bibliographic_match_validated)
  VALUES (v_partage, 'pdf_restrito', 'conta_ativa', 'active', true, 'pdf-restrito', 'books/' || v_partage || '/1_y.pdf', 'sob_direitos', true),
         (v_public, 'pdf_publico', 'publico', 'active', true, 'anarbib-pdf-public', 'books/' || v_public || '/1_z.pdf', 'dominio_publico', true);

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 derniere detention retiree : coordination et administration avisees, controle la liste';
  DELETE FROM public.book_holdings WHERE book_id = v_seul;
  SELECT count(*) INTO v_n FROM public.user_notifications
   WHERE link_type = 'restricted_without_holder' AND link_id = v_seul::text AND title = 'notif.restrictedOrphan.title'
     AND user_id IN (v_coordA, v_admin) AND library_id = c_blmf;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  v_res := public.fn_restricted_resources_without_holder();
  IF v_n = 2 AND EXISTS (SELECT 1 FROM jsonb_array_elements(v_res->'resources') x WHERE (x->>'resource_id')::bigint = v_rseul) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : avis=' || v_n || ' ' || v_res::text); END IF;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 une detentrice reste : aucun avis, rien au controle';
  DELETE FROM public.book_holdings WHERE book_id = v_partage AND library_id = c_blmf;
  v_res := public.fn_restricted_resources_without_holder();
  IF NOT EXISTS (SELECT 1 FROM public.user_notifications WHERE link_type = 'restricted_without_holder' AND link_id = v_partage::text)
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_res->'resources') x WHERE (x->>'book_id')::bigint = v_partage) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 un PDF public sans detentrice : aucun avis';
  DELETE FROM public.book_holdings WHERE book_id = v_public;
  IF NOT EXISTS (SELECT 1 FROM public.user_notifications WHERE link_type = 'restricted_without_holder' AND link_id = v_public::text) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 controle vide pour une coordination, ferme a anon ; declencheur executable par personne';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
  v_res := public.fn_restricted_resources_without_holder();
  IF (v_res->>'total')::int = 0
     AND NOT has_function_privilege('anon', 'public.fn_restricted_resources_without_holder()', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.tg_book_holdings_restreint_sans_detentrice()', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.tg_book_holdings_restreint_sans_detentrice()', 'EXECUTE') THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 rien n est interdit : la ressource reste active';
  IF (SELECT status = 'active' AND is_active FROM public.book_digital_resources WHERE id = v_rseul) THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'RESTREINT-SANS-DETENTRICE OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'RESTREINT-SANS-DETENTRICE ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || ');
  END IF;
END $$;
