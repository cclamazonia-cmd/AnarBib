-- =====================================================================
-- AnarBib — Tests d'acceptation : la fin de l'atelier active la bibliothèque
-- Date    : 2026-10-21  ·  Session : Activation de la constitution
-- Ref     : migration 20261021193002_l_atelier_active_la_bibliotheque
--           docs/specs/spec-onboarding-biblioteca-v2.0.md §6.4
--
-- Deux portes, et deux seulement, pour activer une bibliothèque en
-- constitution : la coordination termine l'atelier (profil + règlement),
-- ou l'administration du réseau active avant la fin, avec un motif. Les
-- tests gardent les deux portes, le mur entre elles (un UPDATE nu de
-- is_active est refusé), et ce qui suit l'activation : la coordination
-- sort de la constitution, la demande garde la trace de l'appartenance.
--   Bilan OK : 'CONST-ACT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid();
  v_coord1 uuid := gen_random_uuid();
  v_coord2 uuid := gen_random_uuid();
  v_autre uuid := gen_random_uuid();
  v_req1 uuid; v_req2 uuid; v_lib1 uuid; v_lib2 uuid; v_lib_hors uuid;
  v_n int; v_b boolean; v_hint text;
BEGIN
  INSERT INTO auth.users(id,email) VALUES
    (v_admin,'admin@ex.org'),(v_coord1,'coord1@ex.org'),(v_coord2,'coord2@ex.org'),(v_autre,'autre@ex.org');
  INSERT INTO public.profiles(id,email) VALUES
    (v_admin,'admin@ex.org'),(v_coord1,'coord1@ex.org'),(v_coord2,'coord2@ex.org'),(v_autre,'autre@ex.org');
  INSERT INTO public.network_administrators(user_id,status) VALUES (v_admin,'active');

  INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
    VALUES (v_coord1,'coord1@ex.org','Biblioteca Porta Um','Cidade','b1@ex.org','em_montagem','C1','coord1@ex.org','Porte 1.',true,true)
    RETURNING id INTO v_req1;
  INSERT INTO public.library_requests (submitted_by_user_id,submitted_by_email_snapshot,library_name,city,library_email,project_stage,contact_name,contact_email,summary,confirm_real,confirm_contact)
    VALUES (v_coord2,'coord2@ex.org','Biblioteca Porta Dois','Cidade','b2@ex.org','em_montagem','C2','coord2@ex.org','Porte 2.',true,true)
    RETURNING id INTO v_req2;

  -- L'administration approuve : biblio pré-active + atelier + constitution.
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_admin,'role','authenticated')::text, true);
  PERFORM api.fn_approve_library_request(v_req1);
  PERFORM api.fn_approve_library_request(v_req2);
  SELECT library_id INTO v_lib1 FROM public.library_constitution_progress WHERE request_id = v_req1;
  SELECT library_id INTO v_lib2 FROM public.library_constitution_progress WHERE request_id = v_req2;

  v_t := 'T1 apres approbation : biblio pre-active, coordination en constitution';
  BEGIN
    SELECT count(*) INTO v_n FROM public.libraries l JOIN public.profiles p ON p.id = v_coord1
     WHERE l.id = v_lib1 AND NOT l.is_active AND p.solicitante_state = 'coordenador_em_constituicao';
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Le mur : pas d'activation hors des deux portes ─────────────────────
  v_t := 'T2 UPDATE nu de is_active (bouton Reseau) -> refuse';
  BEGIN
    UPDATE public.libraries SET is_active = true WHERE id = v_lib1;
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : activation acceptee');
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.constitution.activation_outside_doors' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : hint '||coalesce(v_hint,'∅')); END IF;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T3 une biblio sans atelier s''active librement';
  BEGIN
    INSERT INTO public.libraries (slug, name, is_active) VALUES ('hors-atelier-t3', 'Hors atelier', false)
      RETURNING id INTO v_lib_hors;
    UPDATE public.libraries SET is_active = true WHERE id = v_lib_hors;
    SELECT is_active INTO v_b FROM public.libraries WHERE id = v_lib_hors;
    IF v_b THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : restee inactive'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Porte 1 : la coordination termine l'atelier ────────────────────────
  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord1,'role','authenticated')::text, true);

  v_t := 'T4 terminer sans profil (volet 0) -> refuse';
  BEGIN
    PERFORM api.fn_constitution_complete(v_req1);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : accepte');
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.constitution.profile_required' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : hint '||coalesce(v_hint,'∅')); END IF;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  -- NB : un sous-bloc qui lève annule tout ce qu'il a fait, set_config compris.
  -- Les préparations (profil, identité de l'appelant) se font donc HORS des
  -- blocs qui attendent un refus.
  PERFORM api.fn_constitution_set_profile(v_req1, 'local_only', 'informal', 'observer', 'staff_roles');

  v_t := 'T5 terminer sans reglement (volet 10) -> refuse';
  BEGIN
    PERFORM api.fn_constitution_complete(v_req1);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : accepte');
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.constitution.regimento_required' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : hint '||coalesce(v_hint,'∅')); END IF;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T6 une autre personne ne termine pas l''atelier';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_autre,'role','authenticated')::text, true);
    PERFORM api.fn_constitution_complete(v_req1);
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : accepte');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord1,'role','authenticated')::text, true);

  v_t := 'T7 profil + reglement : terminer active la biblio, axes du volet 0';
  BEGIN
    PERFORM api.fn_constitution_set_regimento(v_req1, 'https://exemplo.test/regimento.pdf');
    PERFORM api.fn_constitution_complete(v_req1);
    SELECT count(*) INTO v_n FROM public.libraries l
     WHERE l.id = v_lib1 AND l.is_active
       AND l.catalog_mode = 'local_only' AND l.circulation_mode = 'informal'
       AND l.network_mode = 'observer' AND l.governance_mode = 'staff_roles'
       AND l.accepts_public_signup = false;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T8 la coordination sort de la constitution, la demande garde l''appartenance';
  BEGIN
    SELECT count(*) INTO v_n FROM public.profiles p, public.library_requests r, public.library_constitution_progress c
     WHERE p.id = v_coord1 AND p.solicitante_state IS NULL
       AND r.id = v_req1 AND r.approved_membership_ref IS NOT NULL
       AND c.request_id = v_req1 AND c.completed_at IS NOT NULL AND c.early_activated_at IS NULL;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T9 terminer une seconde fois : sans effet, sans erreur';
  BEGIN
    PERFORM api.fn_constitution_complete(v_req1);
    v_passed:=v_passed+1;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T10 la vue de la coordination dit la biblio active';
  BEGIN
    SELECT library_is_active INTO v_b FROM api.my_constitution_progress_v1 WHERE request_id = v_req1;
    IF v_b THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||coalesce(v_b::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Porte 2 : l'administration active avant la fin ─────────────────────
  v_t := 'T11 une coordination n''active pas par anticipation';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord2,'role','authenticated')::text, true);
    PERFORM api.fn_constitution_activate_early(v_req2, 'je suis pressee');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : accepte');
  EXCEPTION WHEN insufficient_privilege THEN v_passed:=v_passed+1;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  PERFORM set_config('request.jwt.claims', json_build_object('sub',v_admin,'role','authenticated')::text, true);

  v_t := 'T12 activation anticipee sans motif -> refusee';
  BEGIN
    PERFORM api.fn_constitution_activate_early(v_req2, '   ');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : accepte');
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.constitution.reason_required' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : hint '||coalesce(v_hint,'∅')); END IF;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T13 activation anticipee motivee : active, signee, atelier ouvert';
  BEGIN
    PERFORM api.fn_constitution_activate_early(v_req2, 'Fonds a verser avant l''assemblee');
    SELECT count(*) INTO v_n FROM public.libraries l, public.library_constitution_progress c, public.profiles p
     WHERE l.id = v_lib2 AND l.is_active
       AND c.request_id = v_req2 AND c.completed_at IS NULL
       AND c.early_activated_by = v_admin AND c.early_activation_reason = 'Fonds a verser avant l''assemblee'
       AND p.id = v_coord2 AND p.solicitante_state IS NULL;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T14 seconde activation anticipee -> refusee';
  BEGIN
    PERFORM api.fn_constitution_activate_early(v_req2, 'encore');
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : acceptee');
  EXCEPTION WHEN check_violation THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.constitution.already_active' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : hint '||coalesce(v_hint,'∅')); END IF;
    WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : mauvaise erreur -> '||SQLERRM); END;

  v_t := 'T15 une porte franchie, desactiver puis reactiver reste libre';
  BEGIN
    UPDATE public.libraries SET is_active = false WHERE id = v_lib2;
    UPDATE public.libraries SET is_active = true WHERE id = v_lib2;
    SELECT is_active INTO v_b FROM public.libraries WHERE id = v_lib2;
    IF v_b THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : restee inactive'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T16 biblio deja active : le volet 0 s''applique tout de suite';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub',v_coord2,'role','authenticated')::text, true);
    PERFORM api.fn_constitution_set_profile(v_req2, 'network_published', 'off', 'federated', 'informal');
    SELECT count(*) INTO v_n FROM public.libraries l
     WHERE l.id = v_lib2 AND l.circulation_mode = 'off' AND l.governance_mode = 'informal';
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T17 terminer l''atelier apres coup : date, la biblio reste active';
  BEGIN
    PERFORM api.fn_constitution_set_regimento(v_req2, 'https://exemplo.test/regimento2.pdf');
    PERFORM api.fn_constitution_complete(v_req2);
    SELECT count(*) INTO v_n FROM public.libraries l, public.library_constitution_progress c
     WHERE l.id = v_lib2 AND l.is_active AND c.request_id = v_req2
       AND c.completed_at IS NOT NULL AND c.early_activated_at IS NOT NULL;
    IF v_n = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' got '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  -- ── Droits ─────────────────────────────────────────────────────────────
  v_t := 'T18 portes fermees a anon, bascule privee fermee a authenticated';
  BEGIN
    IF NOT has_function_privilege('anon', 'api.fn_constitution_complete(uuid)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'api.fn_constitution_activate_early(uuid,text)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'api.fn_constitution_activate_early(uuid,text)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_constitution_activer(uuid)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_constitution_sortir(uuid)', 'EXECUTE')
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : droits inattendus'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN RAISE EXCEPTION 'CONST-ACT OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE RAISE EXCEPTION 'CONST-ACT ECHEC : %/% OK, % échec(s) | %', v_passed,(v_passed+v_failed),v_failed,array_to_string(v_failures,' || '); END IF;
END $$;
