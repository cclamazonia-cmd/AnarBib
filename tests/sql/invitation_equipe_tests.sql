-- =====================================================================
-- AnarBib — Tests d'acceptation : ACCUEIL DANS L'ÉQUIPE (invitation-équipe)
-- Date    : 2026-06-19  ·  Session : Invitation-équipe (mise en place)
-- Réf     : migration 20260619125325_invitation_equipe.sql ; CADRAGE_accueil_equipe.
--
-- Couvre : gardes (coordenador non invitable, non-staff, self, membre actif,
-- ratify non-staff, accept par non-invité), la VOIE MÉDIANE (librarian propose →
-- 2 librarians ne suffisent pas → coordenador requis), accept→adhésion librarian,
-- decline, revoke, et le mode coordenador_seul (required=1). Fixtures dynamiques.
--   Bilan OK : 'INVITATION-EQUIPE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int:=0; v_failed int:=0; v_failures text[]:=ARRAY[]::text[]; v_t text;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_coord uuid;
  v_lib2 uuid := 'a0000000-0000-4000-8000-000000000002';
  v_lib3 uuid := 'a0000000-0000-4000-8000-000000000003';
  v_t1 uuid := 'b0000000-0000-4000-8000-000000000001';
  v_t2 uuid := 'b0000000-0000-4000-8000-000000000002';
  v_t3 uuid := 'b0000000-0000-4000-8000-000000000003';
  v_coord_pub text; v_lib2_pub text; v_t1_pub text; v_t2_pub text; v_t3_pub text;
  v_json jsonb; v_inv uuid; v_rec record; v_n int;
BEGIN
  SELECT user_id INTO v_coord FROM public.user_library_memberships
    WHERE library_id=c_blmf AND role='coordenador' AND status='active' LIMIT 1;
  IF v_coord IS NULL THEN RAISE EXCEPTION 'SETUP: pas de coordenador BLMF seedé'; END IF;

  -- créer 2 librarians + 3 cibles (comptes auth + profils)
  FOR v_rec IN SELECT * FROM (VALUES
    (v_lib2,'lib2'),(v_lib3,'lib3'),(v_t1,'tgt1'),(v_t2,'tgt2'),(v_t3,'tgt3')
  ) AS x(uid, sfx) LOOP
    INSERT INTO auth.users (instance_id,id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', v_rec.uid,'authenticated','authenticated',
            v_rec.sfx||'.inv@anarbib.local', now(),now(),now(),
            '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.profiles (id,email,first_name,last_name,preferred_language)
    VALUES (v_rec.uid, v_rec.sfx||'.inv@anarbib.local', v_rec.sfx, 'Test','fr')
    ON CONFLICT (id) DO NOTHING;
  END LOOP;

  INSERT INTO public.user_library_memberships (user_id,library_id,role,status)
  VALUES (v_lib2,c_blmf,'librarian','active'),(v_lib3,c_blmf,'librarian','active')
  ON CONFLICT (user_id,library_id,role) DO UPDATE SET status='active';

  UPDATE public.libraries SET team_admission_mode='cosignature' WHERE id=c_blmf;

  SELECT public_id INTO v_coord_pub FROM public.profiles WHERE id=v_coord;
  SELECT public_id INTO v_lib2_pub FROM public.profiles WHERE id=v_lib2;
  SELECT public_id INTO v_t1_pub FROM public.profiles WHERE id=v_t1;
  SELECT public_id INTO v_t2_pub FROM public.profiles WHERE id=v_t2;
  SELECT public_id INTO v_t3_pub FROM public.profiles WHERE id=v_t3;
  IF v_t1_pub IS NULL THEN RAISE EXCEPTION 'SETUP: public_id non généré (trigger absent ?)'; END IF;

  -- ── Gardes ──
  v_t:='T1 coordenador non invitable';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
    PERFORM public.fn_team_propose_invitation(c_blmf, v_t1_pub, 'coordenador');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  v_t:='T2 non-staff propose -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_t1,'role','authenticated')::text, true);
    PERFORM public.fn_team_propose_invitation(c_blmf, v_t2_pub, 'librarian');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  v_t:='T3 self-invite -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
    PERFORM public.fn_team_propose_invitation(c_blmf, v_coord_pub, 'librarian');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  v_t:='T4 inviter un membre actif -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
    PERFORM public.fn_team_propose_invitation(c_blmf, v_lib2_pub, 'librarian');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  -- ── Voie médiane : lib propose → 2 libs insuffisants → coordenador requis ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_lib2,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_t1_pub, 'librarian');
  v_inv := (v_json->>'invitation_id')::uuid;
  v_t:='T5a librarian propose -> pending + required=2';
  IF (v_json->>'status')='pending_ratification' AND (v_json->>'required_ratifications')='2'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_lib3,'role','authenticated')::text, true);
  v_json := public.fn_team_ratify_invitation(v_inv);
  v_t:='T5b 2e librarian ratifie -> ENCORE pending (règle médiane)';
  IF (v_json->>'status')='pending_ratification'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json->>'status','NULL')); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_ratify_invitation(v_inv);
  v_t:='T5c coordenador ratifie -> ready';
  IF (v_json->>'status')='ready'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json->>'status','NULL')); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_t1,'role','authenticated')::text, true);
  v_json := public.fn_team_accept_invitation(v_inv);
  v_t:='T5d acceptation -> adhésion librarian active + invitation accepted';
  IF (v_json->>'ok')='true'
     AND EXISTS (SELECT 1 FROM public.user_library_memberships WHERE user_id=v_t1 AND library_id=c_blmf AND role='librarian' AND status='active')
     AND (SELECT status FROM public.library_team_invitations WHERE id=v_inv)='accepted'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  -- ── Accept par non-invité ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_t2_pub, 'librarian'); v_inv:=(v_json->>'invitation_id')::uuid;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_lib2,'role','authenticated')::text, true);
  PERFORM public.fn_team_ratify_invitation(v_inv);  -- ready (coord proposeur + lib2)
  v_t:='T6 accept par non-invité -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_t3,'role','authenticated')::text, true);
    PERFORM public.fn_team_accept_invitation(v_inv);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  v_t:='T6b invité·e accepte -> ok';
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_t2,'role','authenticated')::text, true);
  v_json := public.fn_team_accept_invitation(v_inv);
  IF (v_json->>'ok')='true' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  -- ── Decline ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_t3_pub, 'librarian'); v_inv:=(v_json->>'invitation_id')::uuid;
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_t3,'role','authenticated')::text, true);
  v_json := public.fn_team_decline_invitation(v_inv);
  v_t:='T7 décline -> declined';
  IF (v_json->>'status')='declined' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  -- ── Revoke (re-propose t3, declined ayant libéré l'index) ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_t3_pub, 'librarian'); v_inv:=(v_json->>'invitation_id')::uuid;
  v_json := public.fn_team_revoke_invitation(v_inv, 'test révocation');
  v_t:='T8 révoque -> revoked';
  IF (v_json->>'status')='revoked' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  -- ── Ratify par non-staff ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_t3_pub, 'librarian'); v_inv:=(v_json->>'invitation_id')::uuid;
  v_t:='T9 ratify par non-staff -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_t3,'role','authenticated')::text, true);
    PERFORM public.fn_team_ratify_invitation(v_inv);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN v_passed:=v_passed+1; END;

  -- ── Mode coordenador_seul : required=1, ready immédiat ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  PERFORM public.fn_team_revoke_invitation(v_inv, 'cleanup T10');  -- libère l'invitation pending de T9
  UPDATE public.libraries SET team_admission_mode='coordenador_seul' WHERE id=c_blmf;
  v_json := public.fn_team_propose_invitation(c_blmf, v_t3_pub, 'librarian');
  v_t:='T10 coordenador_seul -> ready immédiat (required=1)';
  IF (v_json->>'status')='ready' AND (v_json->>'required_ratifications')='1'
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')); END IF;

  -- ── RPC de liste (lot 3.0) ── (T10 a laissé une invitation 'ready' pour t3)
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.fn_team_list_invitations(c_blmf);
  v_t:='T11 list_invitations (staff) -> au moins 1 ligne';
  IF v_n >= 1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_t3,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.fn_team_list_invitations(c_blmf);
  v_t:='T12 list_invitations (non-staff) -> 0 ligne';
  IF v_n = 0 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_t3,'role','authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.fn_team_my_invitations();
  v_t:='T13 my_invitations (invité·e) -> au moins 1 ligne';
  IF v_n >= 1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;

  IF v_failed=0 THEN
    RAISE EXCEPTION 'INVITATION-EQUIPE OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'INVITATION-EQUIPE ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
