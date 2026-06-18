-- =====================================================================
-- AnarBib — Tests d'acceptation : ONBO-Q13 (transfert du mandat de
--           coordenador·a de constitution)
-- Date    : 2026-06-18
-- Session : Audit 360 — morceaux 🔴 (ONBO-Q13 + #111)
-- Réf     : REGISTRE ONBO-Q13 ; migration 20260618161110_onbo_q13_*.
--
-- USAGE : harness scripts/ci/run-sql-suites.sh (base jetable). Tout est dans
--   UN bloc DO $$ qui SEEDE son PROPRE fixture (acteurs dédiés, créés dans la
--   transaction) et se termine par une EXCEPTION portant le bilan → ROLLBACK
--   total. Aucune dépendance au seed prod, aucune écriture persistée.
--   - Bilan OK : 'ONBO-Q13 OK : N/N tests passés'
--   - Bilan KO : 'ONBO-Q13 ECHEC : ...'
--
-- Construit l'état réaliste via les VRAIES fonctions : on insère une demande
-- puis on appelle api.fn_approve_library_request (qui provisionne biblio
-- pré-active + membership coordenador + progress + solicitante_state). On
-- teste ensuite api.fn_constitution_transfer_mandate.
-- =====================================================================

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := ARRAY[]::text[];
  v_t text;

  v_admin uuid := gen_random_uuid();
  v_old   uuid := gen_random_uuid();
  v_new   uuid := gen_random_uuid();
  v_new_email text := 'nouvelle-coord-' || substr(replace(gen_random_uuid()::text,'-',''),1,8) || '@exemple.org';

  v_req  uuid;
  v_prog uuid;
  v_lib  uuid;
  v_state text;
  v_role  text;
  v_status text;
  v_n int;
BEGIN
  -- ── Fixture : 3 comptes (admin réseau, ancien·ne coord = submitter, nouveau·elle) ──
  INSERT INTO auth.users (id, email) VALUES
    (v_admin, 'admin-reseau@exemple.org'),
    (v_old,   'ancienne-coord@exemple.org'),
    (v_new,   v_new_email);
  INSERT INTO public.profiles (id, email, solicitante_state) VALUES
    (v_admin, 'admin-reseau@exemple.org', NULL),
    (v_old,   'ancienne-coord@exemple.org', NULL),
    (v_new,   v_new_email, NULL);
  INSERT INTO public.network_administrators (user_id) VALUES (v_admin);

  INSERT INTO public.library_requests (
    submitted_by_user_id, submitted_by_email_snapshot,
    library_name, library_short_name, city, country, library_email,
    project_stage, contact_name, contact_email, summary,
    requested_catalog_mode, requested_network_mode,
    confirm_real, confirm_contact, request_status
  ) VALUES (
    v_old, 'ancienne-coord@exemple.org',
    'Biblioteca Teste ONBO-Q13', 'BTQ13', 'Cidade Teste', 'Brasil', 'biblio-q13@exemple.org',
    'em_montagem', 'Contato Teste', 'contato-q13@exemple.org', 'Resumo de teste ONBO-Q13.',
    'network_published', 'federated',
    true, true, 'pendente'
  ) RETURNING id INTO v_req;

  -- Approbation (admin) → provisionne tout l'état de constitution.
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  SELECT "api"."fn_approve_library_request"(v_req) INTO v_prog;
  PERFORM set_config('request.jwt.claims', '', true);

  SELECT library_id INTO v_lib FROM public.library_constitution_progress WHERE request_id = v_req;

  -- Pré-condition : un volet déjà saisi (pour vérifier la préservation).
  UPDATE public.library_constitution_progress
     SET volet_1_identite_done = true, volet_0_catalog_mode = 'network_published'
   WHERE request_id = v_req;

  -- Sanity fixture (non compté mais bloque tôt si KO).
  IF v_prog IS NULL OR v_lib IS NULL THEN
    RAISE EXCEPTION 'ONBO-Q13 ECHEC : fixture invalide (prog=% lib=%)', v_prog, v_lib;
  END IF;

  -- =================================================================
  -- T1 — appel non-admin rejeté (42501)
  -- =================================================================
  v_t := 'T1 non-admin -> 42501';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_new, 'role', 'authenticated')::text, true);
    PERFORM "api"."fn_constitution_transfer_mandate"(v_req, v_new);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION
    WHEN insufficient_privilege THEN v_passed := v_passed + 1;
    WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : SQLSTATE ' || SQLSTATE || ' ' || SQLERRM);
  END;
  PERFORM set_config('request.jwt.claims', '', true);

  -- =================================================================
  -- T2 — appel anonyme rejeté (claims sans 'sub' → auth.uid() NULL, comme un
  --      vrai appel anon PostgREST ; pas la chaîne vide qui ferait un 22P02
  --      artificiel côté stub).
  -- =================================================================
  v_t := 'T2 anon -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
    PERFORM "api"."fn_constitution_transfer_mandate"(v_req, v_new);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION
    WHEN insufficient_privilege THEN v_passed := v_passed + 1;
    WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : SQLSTATE ' || SQLSTATE || ' ' || SQLERRM);
  END;
  PERFORM set_config('request.jwt.claims', '', true);

  -- =================================================================
  -- T3 — transfert admin nominal → renvoie l'id de progression
  -- =================================================================
  v_t := 'T3 transfert admin -> progress id';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    SELECT "api"."fn_constitution_transfer_mandate"(v_req, v_new, 'la 1ʳᵉ personne a quitté le collectif') INTO v_prog;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_prog IS NOT NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : retour NULL'); END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =================================================================
  -- T4 — progress.coordenador_id repointé vers le·la nouveau·elle
  -- =================================================================
  v_t := 'T4 coordenador_id = nouveau';
  BEGIN
    SELECT coordenador_id INTO v_old FROM public.library_constitution_progress WHERE request_id = v_req;
    IF v_old = v_new THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_old::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  -- (v_old a été écrasé ci-dessus ; on le restaure pour les contrôles suivants)
  v_old := NULL;
  SELECT from_user_id INTO v_old FROM public.library_request_mandate_transfers WHERE request_id = v_req LIMIT 1;

  -- =================================================================
  -- T5 — membership : ancien removed, nouveau coordenador/active
  -- =================================================================
  v_t := 'T5a ancienne membership coordenador -> removed';
  BEGIN
    SELECT status INTO v_status FROM public.user_library_memberships
      WHERE user_id = v_old AND library_id = v_lib AND role = 'coordenador';
    IF v_status = 'removed' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_status,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := 'T5b nouvelle membership coordenador active';
  BEGIN
    SELECT status INTO v_status FROM public.user_library_memberships
      WHERE user_id = v_new AND library_id = v_lib AND role = 'coordenador';
    IF v_status = 'active' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_status,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- =================================================================
  -- T6 — submitter + snapshot e-mail repointés (clé de l'activation)
  -- =================================================================
  v_t := 'T6 submitted_by_user_id + email_snapshot = nouveau';
  BEGIN
    SELECT submitted_by_user_id::text || '|' || submitted_by_email_snapshot
      INTO v_state FROM public.library_requests WHERE id = v_req;
    IF v_state = (v_new::text || '|' || v_new_email) THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_state,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- =================================================================
  -- T7 — solicitante_state : nouveau en constitution, ancien remis à NULL
  -- =================================================================
  v_t := 'T7a nouveau solicitante_state = coordenador_em_constituicao';
  BEGIN
    SELECT solicitante_state INTO v_state FROM public.profiles WHERE id = v_new;
    IF v_state = 'coordenador_em_constituicao' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_state,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := 'T7b ancien solicitante_state remis à NULL';
  BEGIN
    SELECT solicitante_state INTO v_state FROM public.profiles WHERE id = v_old;
    IF v_state IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_state,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- =================================================================
  -- T8 — volets préservés (volet_1 toujours done)
  -- =================================================================
  v_t := 'T8 volet_1_identite_done préservé';
  BEGIN
    SELECT volet_1_identite_done::text INTO v_state FROM public.library_constitution_progress WHERE request_id = v_req;
    IF v_state = 'true' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' obtenu ' || coalesce(v_state,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- =================================================================
  -- T9 — audit tracé (from=ancien, to=nouveau, by=admin)
  -- =================================================================
  v_t := 'T9 audit library_request_mandate_transfers';
  BEGIN
    SELECT count(*) INTO v_n FROM public.library_request_mandate_transfers
      WHERE request_id = v_req AND to_user_id = v_new AND transferred_by = v_admin;
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' n=' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- =================================================================
  -- T10 — transfert vers le·la coordenador·a actuel·le rejeté (23514)
  -- =================================================================
  v_t := 'T10 transfert vers coordenador·a actuel·le -> rejet';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM "api"."fn_constitution_transfer_mandate"(v_req, v_new);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION
    WHEN check_violation THEN v_passed := v_passed + 1;
    WHEN OTHERS THEN
      IF SQLSTATE = '23514' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : SQLSTATE ' || SQLSTATE || ' ' || SQLERRM); END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);

  -- =================================================================
  -- T11 — transfert vers un profil inexistant rejeté (P0002)
  -- =================================================================
  v_t := 'T11 cible inexistante -> P0002';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    PERFORM "api"."fn_constitution_transfer_mandate"(v_req, gen_random_uuid());
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
  EXCEPTION
    WHEN no_data_found THEN v_passed := v_passed + 1;
    WHEN OTHERS THEN
      IF SQLSTATE = 'P0002' THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : SQLSTATE ' || SQLSTATE || ' ' || SQLERRM); END IF;
  END;
  PERFORM set_config('request.jwt.claims', '', true);

  -- =================================================================
  -- T12 — constitution déjà terminée -> transfert rejeté (23514)
  -- =================================================================
  v_t := 'T12 constitution terminée -> rejet';
  BEGIN
    UPDATE public.library_constitution_progress SET completed_at = now() WHERE request_id = v_req;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM "api"."fn_constitution_transfer_mandate"(v_req, v_admin);
      v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aurait dû lever');
    EXCEPTION
      WHEN check_violation THEN v_passed := v_passed + 1;
      WHEN OTHERS THEN
        IF SQLSTATE = '23514' THEN v_passed := v_passed + 1;
        ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : SQLSTATE ' || SQLSTATE || ' ' || SQLERRM); END IF;
    END;
    PERFORM set_config('request.jwt.claims', '', true);
    UPDATE public.library_constitution_progress SET completed_at = NULL WHERE request_id = v_req;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =================================================================
  -- BILAN (RAISE = rollback de toute la transaction, fixtures comprises)
  -- =================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ONBO-Q13 OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'ONBO-Q13 ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed + v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
