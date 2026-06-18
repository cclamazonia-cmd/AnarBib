-- =====================================================================
-- AnarBib — Tests d'acceptation : #111 Lot 1 (évaluation collaborative)
-- Date    : 2026-06-18
-- Session : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
-- Réf     : CADRAGE_111_… §3 ; migration 20260618214415_onbo_111_lot1_*.
--
-- UN bloc DO $$ qui SEEDE son fixture (admins A/B/C + demandes + solicitantes
-- dédiés) et RAISE le bilan final → ROLLBACK total. Construit l'état via les
-- VRAIES fonctions (api.fn_request_propose_decision / fn_request_vote ; la
-- confirmation acceptation appelle api.fn_approve_library_request qui provisionne).
--   Bilan OK : '#111-L1 OK : N/N tests passés'
-- =====================================================================

DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_a uuid := gen_random_uuid();  -- admin A
  v_b uuid := gen_random_uuid();  -- admin B
  v_c uuid := gen_random_uuid();  -- admin C
  v_sub uuid; v_req uuid; v_status text; v_state text; v_n int;
BEGIN
  -- comptes admins (A actif d'emblée ; B/C activés en phase collaborative)
  INSERT INTO auth.users (id,email) VALUES (v_a,'admin-a@ex.org'),(v_b,'admin-b@ex.org'),(v_c,'admin-c@ex.org');
  INSERT INTO public.profiles (id,email) VALUES (v_a,'admin-a@ex.org'),(v_b,'admin-b@ex.org'),(v_c,'admin-c@ex.org');
  INSERT INTO public.network_administrators (user_id) VALUES (v_a);  -- A actif seul → mode dégradé

  -- =========================== GARDES ===========================
  v_t := 'T1 non-admin propose -> 42501';
  BEGIN
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s1@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s1@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s1@ex.org','Bib1','Cidade','b1@ex.org','em_montagem','C','c1@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_sub,'role','authenticated')::text, true);
    PERFORM api.fn_request_propose_decision(v_req,'aprovacao',true);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM); END;
  PERFORM set_config('request.jwt.claims','',true);

  v_t := 'T2 anon propose -> 42501';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
    PERFORM api.fn_request_propose_decision(v_req,'aprovacao',true);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM); END;
  PERFORM set_config('request.jwt.claims','',true);

  -- =================== MODE DÉGRADÉ (1 admin actif) ===================
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);

  v_t := 'T3 dégradé: propose aprovacao -> aprovada + provisioning';
  BEGIN
    -- demande propre (T1/T2 ont rollback leur INSERT en levant l'exception attendue)
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s3@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s3@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s3@ex.org','Bib3','Cidade','b3@ex.org','em_montagem','C','c3@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM api.fn_request_propose_decision(v_req,'aprovacao',true);
    SELECT request_status INTO v_status FROM public.library_requests WHERE id=v_req;
    SELECT count(*) INTO v_n FROM public.library_constitution_progress WHERE request_id=v_req;
    IF v_status='aprovada' AND v_n=1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')||' progress='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 dégradé: propose recusa -> recusada + solicitante_recusada';
  BEGIN
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s4@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s4@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s4@ex.org','Bib4','Cidade','b4@ex.org','em_montagem','C','c4@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM api.fn_request_propose_decision(v_req,'recusa',true,'desalignement_politique','hors valeurs');
    SELECT request_status INTO v_status FROM public.library_requests WHERE id=v_req;
    SELECT solicitante_state INTO v_state FROM public.profiles WHERE id=v_sub;
    IF v_status='recusada' AND v_state='solicitante_recusada' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')||' state='||coalesce(v_state,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T5 dégradé: propose recusa sans catégorie -> 22023';
  BEGIN
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s5@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s5@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s5@ex.org','Bib5','Cidade','b5@ex.org','em_montagem','C','c5@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM api.fn_request_propose_decision(v_req,'recusa',true);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE='22023' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM); END IF; END;

  v_t := 'T6 disclose_identity NULL -> 22023';
  BEGIN
    PERFORM api.fn_request_propose_decision(v_req,'aprovacao',NULL);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE='22023' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM); END IF; END;

  -- =================== COLLABORATIF (3 admins actifs) ===================
  INSERT INTO public.network_administrators (user_id) VALUES (v_b),(v_c);  -- 3 actifs

  v_t := 'T7 collab: propose aprovacao -> proposta_aprovacao (pas auto-confirmé)';
  BEGIN
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s7@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s7@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s7@ex.org','Bib7','Cidade','b7@ex.org','em_montagem','C','c7@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM api.fn_request_propose_decision(v_req,'aprovacao',true);  -- A propose (auto-favorable)
    SELECT request_status INTO v_status FROM public.library_requests WHERE id=v_req;
    IF v_status='proposta_aprovacao' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T8 collab: 2e vote favorable -> toujours proposta (2/3)';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_b,'role','authenticated')::text, true);
    PERFORM api.fn_request_vote(v_req,'favorable',true);
    SELECT request_status INTO v_status FROM public.library_requests WHERE id=v_req;
    IF v_status='proposta_aprovacao' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T9 collab: 3e vote favorable -> unanimité -> aprovada + provisioning';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_c,'role','authenticated')::text, true);
    PERFORM api.fn_request_vote(v_req,'favorable',true);
    SELECT request_status INTO v_status FROM public.library_requests WHERE id=v_req;
    SELECT count(*) INTO v_n FROM public.library_constitution_progress WHERE request_id=v_req;
    IF v_status='aprovada' AND v_n=1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')||' progress='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T10 collab veto: un opposed -> retour em_analise';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s10@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s10@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s10@ex.org','Bib10','Cidade','b10@ex.org','em_montagem','C','c10@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM api.fn_request_propose_decision(v_req,'aprovacao',true);          -- A propose
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_b,'role','authenticated')::text, true);
    PERFORM api.fn_request_vote(v_req,'opposed',true,'Projet non vérifiable, informations contradictoires.');  -- B s'oppose (≥20)
    SELECT request_status INTO v_status FROM public.library_requests WHERE id=v_req;
    IF v_status='em_analise' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T11 collab: opposed rationale <20 -> 22023';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s11@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s11@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s11@ex.org','Bib11','Cidade','b11@ex.org','em_montagem','C','c11@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM api.fn_request_propose_decision(v_req,'aprovacao',true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_b,'role','authenticated')::text, true);
    PERFORM api.fn_request_vote(v_req,'opposed',true,'trop court');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE='22023' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM); END IF; END;

  v_t := 'T12 vote sans proposition ouverte -> 22023';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s12@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s12@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s12@ex.org','Bib12','Cidade','b12@ex.org','em_montagem','C','c12@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM api.fn_request_vote(v_req,'favorable',true);  -- pendente, pas de proposition
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE='22023' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM); END IF; END;

  v_t := 'T13 commentaire admin OK + non-admin 42501';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    -- demande propre + non-admin dédié (les blocs précédents qui ont levé ont rollback leurs INSERT)
    v_sub := gen_random_uuid();
    INSERT INTO auth.users(id,email) VALUES (v_sub,'s13@ex.org'); INSERT INTO public.profiles(id,email) VALUES (v_sub,'s13@ex.org');
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_sub,'s13@ex.org','Bib13','Cidade','b13@ex.org','em_montagem','C','c13@ex.org','Resumo #111.',true,true) RETURNING id INTO v_req;
    PERFORM api.fn_request_comment(v_req,'Note interne de coordination.');
    SELECT count(*) INTO v_n FROM public.library_request_comments WHERE request_id=v_req;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_sub,'role','authenticated')::text, true);
    BEGIN
      PERFORM api.fn_request_comment(v_req,'tentative non-admin');
      v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : non-admin aurait dû lever');
    EXCEPTION WHEN insufficient_privilege THEN
      IF v_n=1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' comment n='||v_n); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;
  PERFORM set_config('request.jwt.claims','',true);

  -- ============================ BILAN ============================
  IF v_failed = 0 THEN
    RAISE EXCEPTION '#111-L1 OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION '#111-L1 ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures,' || ');
  END IF;
END $$;
