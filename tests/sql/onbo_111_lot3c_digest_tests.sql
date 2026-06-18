-- =====================================================================
-- AnarBib — Tests d'acceptation : #111 Lot 3c (digest cron d'évaluation)
-- Date    : 2026-06-18  ·  Session : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
-- Réf     : migration 20260618223417_onbo_111_lot3c_eval_digest_cron.
-- Teste fn_cron_request_eval_digest (le job pg_cron n'est pas testé : cron parfois
-- absent de la base de test ; il est créé INACTIF, vérifié en prod).
--   Bilan OK : '#111-L3c OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_a uuid := gen_random_uuid(); v_b uuid := gen_random_uuid(); v_c uuid := gen_random_uuid();
  v_s uuid := gen_random_uuid(); v_req uuid; v_req2 uuid; v_res jsonb;
BEGIN
  INSERT INTO auth.users(id,email) VALUES (v_a,'a@ex.org'),(v_b,'b@ex.org'),(v_c,'c@ex.org'),(v_s,'s@ex.org');
  INSERT INTO public.profiles(id,email) VALUES (v_a,'a@ex.org'),(v_b,'b@ex.org'),(v_c,'c@ex.org'),(v_s,'s@ex.org');
  INSERT INTO public.network_administrators(user_id) VALUES (v_a),(v_b),(v_c);
  -- proposition ouverte, seul A a voté (B,C en attente)
  INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact,request_status,proposed_by_admin_id,proposed_decision,proposed_disclose_identity)
    VALUES (v_s,'s@ex.org','BibDig','Cidade','bd@ex.org','em_montagem','C','cd@ex.org','Resumo #111 L3c.',true,true,'proposta_aprovacao',v_a,'aprovacao',true) RETURNING id INTO v_req;
  INSERT INTO public.library_request_votes (request_id,voter_admin_id,vote,disclose_identity) VALUES (v_req,v_a,'favorable',true);

  v_t := 'T1 proposition non votée par tous -> open_proposals_reminded>=1';
  BEGIN
    SELECT public.fn_cron_request_eval_digest() INTO v_res;
    IF (v_res->>'open_proposals_reminded')::int >= 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_res->>'open_proposals_reminded','?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 backlog pendente >7j -> pending_backlog>=1';
  BEGIN
    INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
      VALUES (v_s,'s@ex.org','BibOld','Cidade','bo@ex.org','em_montagem','C','co@ex.org','Resumo antigo.',true,true) RETURNING id INTO v_req2;
    UPDATE public.library_requests SET created_at = now() - interval '9 days' WHERE id = v_req2;
    SELECT public.fn_cron_request_eval_digest() INTO v_res;
    IF (v_res->>'pending_backlog')::int >= 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_res->>'pending_backlog','?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 proposition entièrement votée -> non rappelée (0)';
  BEGIN
    INSERT INTO public.library_request_votes (request_id,voter_admin_id,vote,disclose_identity)
      VALUES (v_req,v_b,'favorable',true),(v_req,v_c,'favorable',true);
    SELECT public.fn_cron_request_eval_digest() INTO v_res;
    IF (v_res->>'open_proposals_reminded')::int = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_res->>'open_proposals_reminded','?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN RAISE EXCEPTION '#111-L3c OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE RAISE EXCEPTION '#111-L3c ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || '); END IF;
END $$;
