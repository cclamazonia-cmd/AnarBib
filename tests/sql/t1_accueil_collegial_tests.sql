-- =====================================================================
-- AnarBib — Tests d'acceptation : L'ACCUEIL AUSSI EST COLLÉGIAL (T1)
-- Date    : 2026-09-01  ·  Session : T1 collégiale (GOUV-13)
-- Réf     : migration 20260901175233_l_accueil_aussi_est_collegial.sql.
--
-- Couvre : la promotion directe reader -> librarian lève
-- collegiality_required (0A000) même pour un·e coordenador légitime, et
-- le chemin de remplacement — le circuit d'invitation avec
-- p_role='librarian' — reste praticable de bout en bout (le détail du
-- circuit est couvert par invitation_equipe_tests.sql, 17 tests).
--   Bilan OK : 'T1-COLLEGIALE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int:=0; v_failed int:=0; v_failures text[]:=ARRAY[]::text[]; v_t text;
  c_blmf constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_coord uuid;
  v_r1 uuid := 'b0000000-0000-4000-8000-000000000021';  -- reader actif
  v_r1_pub text;
  v_json jsonb;
  v_state text;
BEGIN
  SELECT user_id INTO v_coord FROM public.user_library_memberships
    WHERE library_id=c_blmf AND role='coordenador' AND status='active' LIMIT 1;
  IF v_coord IS NULL THEN RAISE EXCEPTION 'SETUP: pas de coordenador BLMF seedé'; END IF;

  INSERT INTO auth.users (instance_id,id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
  VALUES ('00000000-0000-0000-0000-000000000000', v_r1,'authenticated','authenticated',
          't1r1.accueil@anarbib.local', now(),now(),now(),
          '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.profiles (id,email,first_name,last_name,preferred_language)
  VALUES (v_r1,'t1r1.accueil@anarbib.local','t1r1','Test','fr')
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_library_memberships (user_id,library_id,role,status)
  VALUES (v_r1,c_blmf,'reader','active')
  ON CONFLICT (user_id,library_id,role) DO UPDATE SET status='active';

  UPDATE public.libraries SET team_admission_mode='cosignature' WHERE id=c_blmf;
  SELECT public_id INTO v_r1_pub FROM public.profiles WHERE id=v_r1;
  IF v_r1_pub IS NULL THEN RAISE EXCEPTION 'SETUP: public_id non généré (trigger absent ?)'; END IF;

  -- ── T1 : la promotion directe lève collegiality_required (0A000) ──
  v_t:='T1 promotion directe -> collegiality_required (0A000)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
    PERFORM public.fn_team_promote_to_librarian(v_r1, c_blmf);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE;
    IF v_state='0A000' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvais SQLSTATE '||v_state); END IF;
  END;

  -- ── T2 : rien n'a été promu par l'appel condamné ──
  v_t:='T2 aucune ligne librarian créée par le chemin condamné';
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships
                  WHERE user_id=v_r1 AND library_id=c_blmf AND role='librarian')
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' KO'); END IF;

  -- ── T3 : le chemin de remplacement est praticable (proposition d'accueil) ──
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord,'role','authenticated')::text, true);
  v_json := public.fn_team_propose_invitation(c_blmf, v_r1_pub, 'librarian');
  v_t:='T3 accueil via le circuit -> proposition déposée';
  IF (v_json->>'ok')='true' AND (v_json->>'status') IN ('pending_ratification','ready')
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_json::text,'NULL')); END IF;

  IF v_failed=0 THEN
    RAISE EXCEPTION 'T1-COLLEGIALE OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'T1-COLLEGIALE ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || ');
  END IF;
END $$;
