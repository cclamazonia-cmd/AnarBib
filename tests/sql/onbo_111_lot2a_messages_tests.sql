-- =====================================================================
-- AnarBib — Tests d'acceptation : #111 Lot 2a (messages + invitations)
-- Date    : 2026-06-18
-- Session : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
-- Réf     : CADRAGE_111_… §4 ; migration 20260618215910_onbo_111_lot2a_*.
-- UN bloc DO $$ fixturé (admin A + solicitante propriétaire S + tiers X + 1
-- demande), RAISE bilan final → ROLLBACK total.  Bilan OK : '#111-L2a OK : N/N'.
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_a uuid := gen_random_uuid();  -- admin réseau
  v_s uuid := gen_random_uuid();  -- solicitante propriétaire
  v_x uuid := gen_random_uuid();  -- tiers (ni admin ni propriétaire)
  v_req uuid; v_inv uuid; v_status text; v_n int;
BEGIN
  INSERT INTO auth.users (id,email) VALUES (v_a,'a@ex.org'),(v_s,'s@ex.org'),(v_x,'x@ex.org');
  INSERT INTO public.profiles (id,email) VALUES (v_a,'a@ex.org'),(v_s,'s@ex.org'),(v_x,'x@ex.org');
  INSERT INTO public.network_administrators (user_id) VALUES (v_a);
  INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
    VALUES (v_s,'s@ex.org','BibMsg','Cidade','bm@ex.org','em_montagem','C','cm@ex.org','Resumo #111 L2a.',true,true) RETURNING id INTO v_req;

  -- T1 admin -> message
  v_t := 'T1 admin send_message';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    PERFORM api.fn_request_send_message(v_req,'Bonjour, une question.');
    SELECT count(*) INTO v_n FROM public.library_request_messages WHERE request_id=v_req AND direction='admin_to_solicitante';
    IF v_n=1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' n='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- T2 non-admin send_message -> 42501
  v_t := 'T2 non-admin send_message -> 42501';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_x,'role','authenticated')::text, true);
    PERFORM api.fn_request_send_message(v_req,'tentative');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM); END;

  -- T3 admin more_info -> aguardando_info
  v_t := 'T3 send_message more_info -> aguardando_info';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    PERFORM api.fn_request_send_message(v_req,'Merci de compléter le dossier.', true);
    SELECT request_status INTO v_status FROM public.library_requests WHERE id=v_req;
    IF v_status='aguardando_info' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- T4 solicitante répond -> message + retour em_analise
  v_t := 'T4 solicitante_message -> em_analise';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_s,'role','authenticated')::text, true);
    PERFORM api.fn_request_solicitante_message(v_req,'Voici les compléments.');
    SELECT request_status INTO v_status FROM public.library_requests WHERE id=v_req;
    SELECT count(*) INTO v_n FROM public.library_request_messages WHERE request_id=v_req AND direction='solicitante_to_admin';
    IF v_status='em_analise' AND v_n=1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')||' n='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- T5 non-propriétaire solicitante_message -> 42501
  v_t := 'T5 non-propriétaire solicitante_message -> 42501';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_x,'role','authenticated')::text, true);
    PERFORM api.fn_request_solicitante_message(v_req,'pas à moi');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : aurait dû lever');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM); END;

  -- T6 admin propose un échange
  v_t := 'T6 admin propose_exchange -> proposed';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    SELECT api.fn_request_propose_exchange(v_req,'Visio de présentation','semaine prochaine') INTO v_inv;
    SELECT status INTO v_status FROM public.library_request_invitations WHERE id=v_inv;
    IF v_status='proposed' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- T7 solicitante accepte
  v_t := 'T7 solicitante accepte -> accepted';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_s,'role','authenticated')::text, true);
    PERFORM api.fn_request_exchange_respond(v_inv, true);
    SELECT status INTO v_status FROM public.library_request_invitations WHERE id=v_inv;
    IF v_status='accepted' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- T8 admin marque réalisé
  v_t := 'T8 complete -> completed';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    PERFORM api.fn_request_exchange_complete(v_inv);
    SELECT status INTO v_status FROM public.library_request_invitations WHERE id=v_inv;
    IF v_status='completed' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- T9 solicitante demande, admin décline
  v_t := 'T9 solicitante demande -> admin décline';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_s,'role','authenticated')::text, true);
    SELECT api.fn_request_solicitante_request_exchange(v_req,'Rappel téléphonique') INTO v_inv;
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    PERFORM api.fn_request_exchange_respond(v_inv, false);
    SELECT status INTO v_status FROM public.library_request_invitations WHERE id=v_inv;
    IF v_status='declined' THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statut='||coalesce(v_status,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- T10 mark_messages_read (admin lit les entrants solicitante)
  v_t := 'T10 mark_messages_read';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_a,'role','authenticated')::text, true);
    PERFORM api.fn_request_mark_messages_read(v_req);
    SELECT count(*) INTO v_n FROM public.library_request_messages WHERE request_id=v_req AND direction='solicitante_to_admin' AND read_at IS NOT NULL;
    IF v_n>=1 THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' lus='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;
  PERFORM set_config('request.jwt.claims','',true);

  IF v_failed = 0 THEN
    RAISE EXCEPTION '#111-L2a OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION '#111-L2a ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures,' || ');
  END IF;
END $$;
