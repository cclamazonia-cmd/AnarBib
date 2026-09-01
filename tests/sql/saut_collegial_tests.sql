-- =====================================================================
-- AnarBib — Tests d'acceptation : SAUT COLLÉGIAL reader -> coordenador
-- Date    : 2026-09-01  ·  Session : saut collégial v1 (GOUV-11/GOUV-12)
-- Réf     : migration 20260901162610_le_saut_collegial_est_un_choix_de_biblio.sql ;
--           cadrage CADRAGE_promotion_directe_reader_coordenador_2026-09-01.
--
-- Couvre : réglage OFF par défaut (le saut reste interdit), réglage ON
-- (reader actif proposable ; pending refusé ; sans adhésion refusé),
-- circuit complet propose -> ratifie -> accepte (rôle exclusif : la ligne
-- reader se ferme ; audit from_role='reader'), revérification à
-- l'acceptation quand la biblio désactive entre-temps, et non-régression
-- de l'échelle librarian -> coordenador avec réglage OFF.
--   Bilan OK : 'SAUT-COLLEGIAL OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int:=0; v_failed int:=0; v_failures text[]:=ARRAY[]::text[]; v_t text;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_coord uuid;
  v_lib2 uuid := 'a0000000-0000-4000-8000-000000000012';
  v_lib3 uuid := 'a0000000-0000-4000-8000-000000000013';
  v_r1 uuid := 'b0000000-0000-4000-8000-000000000011';  -- reader actif
  v_r2 uuid := 'b0000000-0000-4000-8000-000000000012';  -- reader pending_validation
  v_r3 uuid := 'b0000000-0000-4000-8000-000000000013';  -- reader actif (T7)
  v_x1 uuid := 'b0000000-0000-4000-8000-000000000014';  -- aucune adhésion
  v_r1_pub text; v_r2_pub text; v_r3_pub text; v_x1_pub text; v_lib2_pub text;
  v_json jsonb; v_inv uuid; v_rec record; v_meta jsonb;
BEGIN
  SELECT user_id INTO v_coord FROM public.user_library_memberships
    WHERE library_id=c_blmf AND role='coordenador' AND status='active' LIMIT 1;
  IF v_coord IS NULL THEN RAISE EXCEPTION 'SETUP: pas de coordenador BLMF seedé'; END IF;

  -- comptes auth + profils (fixtures dynamiques, DOC-FIXT-1)
  FOR v_rec IN SELECT * FROM (VALUES
    (v_lib2,'sclib2'),(v_lib3,'sclib3'),(v_r1,'scr1'),(v_r2,'scr2'),(v_r3,'scr3'),(v_x1,'scx1')
  ) AS x(uid, sfx) LOOP
    INSERT INTO auth.users (instance_id,id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', v_rec.uid,'authenticated','authenticated',
            v_rec.sfx||'.saut@anarbib.local', now(),now(),now(),
            '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.profiles (id,email,first_name,last_name,preferred_language)
    VALUES (v_rec.uid, v_rec.sfx||'.saut@anarbib.local', v_rec.sfx, 'Test','fr')
    ON CONFLICT (id) DO NOTHING;
  END LOOP;

  INSERT INTO public.user_library_memberships (user_id,library_id,role,status) VALUES
    (v_lib2,c_blmf,'librarian','active'),
    (v_lib3,c_blmf,'librarian','active'),
    (v_r1,c_blmf,'reader','active'),
    (v_r2,c_blmf,'reader','pending_validation'),
    (v_r3,c_blmf,'reader','active')
  ON CONFLICT (user_id,library_id,role) DO UPDATE SET status=EXCLUDED.status;

  UPDATE public.libraries
     SET team_admission_mode='cosignature', allow_direct_coordenador=false
   WHERE id=c_blmf;

  SELECT public_id INTO v_r1_pub  FROM public.profiles WHERE id=v_r1;
  SELECT public_id INTO v_r2_pub  FROM public.profiles WHERE id=v_r2;
  SELECT public_id INTO v_r3_pub  FROM public.profiles WHERE id=v_r3;
  SELECT public_id INTO v_x1_pub  FROM public.profiles WHERE id=v_x1;
  SELECT public_id INTO v_lib2_pub FROM public.profiles WHERE id=v_lib2;
  IF v_r1_pub IS NULL THEN RAISE EXCEPTION 'SETUP: public_id non généré (trigger absent ?)'; END IF;

  -- ── T1 : réglage OFF (défaut) — le saut reste interdit ──
  v_t:='T1 réglage OFF : proposer un reader actif -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
    PERFORM public.fn_team_propose_invitation(c_blmf, v_r1_pub, 'coordenador');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  UPDATE public.libraries SET allow_direct_coordenador=true WHERE id=c_blmf;

  -- ── T2 : réglage ON — reader 'pending_validation' refusé (active STRICT, GOUV-12) ──
  v_t:='T2 réglage ON : reader pending_validation -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
    PERFORM public.fn_team_propose_invitation(c_blmf, v_r2_pub, 'coordenador');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  -- ── T3 : réglage ON — aucune adhésion refusée (pas d'entrée extérieure) ──
  v_t:='T3 réglage ON : sans adhésion -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
    PERFORM public.fn_team_propose_invitation(c_blmf, v_x1_pub, 'coordenador');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  -- ── T4 : réglage ON — reader actif proposable, quorum inchangé ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_r1_pub, 'coordenador');
  v_inv := (v_json->>'invitation_id')::uuid;
  v_t:='T4 réglage ON : reader actif -> pending + required=2 (cosignature)';
  IF (v_json->>'status')='pending_ratification' AND (v_json->>'required_ratifications')='2'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')); END IF;

  -- ── T5 : ratification -> ready ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_lib2,'role','authenticated')::text, true);
  v_json := public.fn_team_ratify_invitation(v_inv);
  v_t:='T5 2e endossement -> ready';
  IF (v_json->>'status')='ready'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json->>'status','NULL')); END IF;

  -- ── T6 : acceptation -> coordenador actif, ligne reader fermée, audit fidèle ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_r1,'role','authenticated')::text, true);
  v_json := public.fn_team_accept_invitation(v_inv);
  v_t:='T6a acceptation -> coordenador actif + reader removed';
  IF (v_json->>'ok')='true'
     AND EXISTS (SELECT 1 FROM public.user_library_memberships WHERE user_id=v_r1 AND library_id=c_blmf AND role='coordenador' AND status='active')
     AND EXISTS (SELECT 1 FROM public.user_library_memberships WHERE user_id=v_r1 AND library_id=c_blmf AND role='reader' AND status='removed')
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  SELECT metadata INTO v_meta FROM public.library_membership_audit
   WHERE library_id=c_blmf AND target_user_id=v_r1 AND action='promoted_to_coordenador'
   ORDER BY created_at DESC LIMIT 1;
  v_t:='T6b audit promoted_to_coordenador porte from_role=reader';
  IF v_meta->>'from_role'='reader'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_meta::text,'NULL')); END IF;

  v_t:='T6c audit removal_completed sur la ligne reader';
  IF EXISTS (SELECT 1 FROM public.library_membership_audit
              WHERE library_id=c_blmf AND target_user_id=v_r1
                AND action='removal_completed' AND role='reader'
                AND metadata->>'superseded_by'='coordenador')
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  -- ── T7 : la biblio désactive entre ready et acceptation -> rejet ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_r3_pub, 'coordenador');
  v_inv := (v_json->>'invitation_id')::uuid;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_lib2,'role','authenticated')::text, true);
  PERFORM public.fn_team_ratify_invitation(v_inv);
  UPDATE public.libraries SET allow_direct_coordenador=false WHERE id=c_blmf;
  v_t:='T7 réglage recoupé avant acceptation -> rejet (revérification)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_r3,'role','authenticated')::text, true);
    PERFORM public.fn_team_accept_invitation(v_inv);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  -- ── T8 : non-régression — l'échelle librarian -> coordenador, réglage OFF ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_lib2_pub, 'coordenador');
  v_t:='T8 réglage OFF : librarian actif toujours proposable';
  IF (v_json->>'status') IN ('pending_ratification','ready')
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')); END IF;

  IF v_failed=0 THEN
    RAISE EXCEPTION 'SAUT-COLLEGIAL OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'SAUT-COLLEGIAL ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
