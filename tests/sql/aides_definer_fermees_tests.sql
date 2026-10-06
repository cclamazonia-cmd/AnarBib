-- =====================================================================
-- AnarBib — Suite : trente-quatre fonctions SECURITY DEFINER fermées aux
-- comptes connectés (advisor 0029, 451 → 417).
-- Date : 2026-10-06
-- Ref  : migration 20261006202320_aides_definer_sans_appelant_fermees
--
-- Une ouverture doit servir (DOC-GRANT-1). Ces 34 fonctions n'ont aucun
-- appelant qui s'exécute sous le rôle authenticated : leurs seuls appelants
-- sont des fonctions DEFINER (qui les exécutent sous leur propriétaire), ou
-- des déclencheurs, ou personne. La fermeture ne se défend que si cela reste
-- vrai ; c'est ce que garde la suite :
--
-- T1 les 34 sont fermées à anon, authenticated et PUBLIC — et existent.
-- T2 aucune n'a d'appelant sous authenticated : ni politique, ni vue, ni
--    dépendance de catalogue (hors déclencheur et DEFINER), ni fonction
--    INVOKER. Si T2 rougit, ce n'est pas la liste qu'il faut corriger : le
--    nouvel appelant casse un écran — rouvrir par un GRANT écrit, avec lui.
-- T3 les portes : les fonctions DEFINER ouvertes par lesquelles le front
--    atteint les fermées le restent, et restent DEFINER.
-- T4 ces portes, jouées SOUS le rôle authenticated, répondent ou refusent
--    pour une raison métier — jamais « permission denied for function »
--    (le code 42501 seul ne suffit pas : des gardes métier le lèvent aussi).
--
-- Rien n'est écrit : la suite se termine par un RAISE.
-- =====================================================================
DO $$
DECLARE
  v_passed   int := 0;
  v_failed   int := 0;
  v_failures text[] := '{}';
  v_t        text;
  v_txt      text;
  v_f        text;
  v_oid      oid;
  v_nom      text;
  v_err      text;
  v_inconnu  uuid := '00000000-0000-4000-8000-0000000a1de5';
  c_fermees  text[] := ARRAY[
    'public.fn_audit_draft_deletion()',
    'public.fn_guard_catalog_batch_delete()',
    'api.get_due_date_after_renewal(uuid, uuid, bigint, bigint, integer, date, integer, date)',
    'api.get_future_availability(uuid, bigint, bigint)',
    'api.get_library_circulation_policy_sets_ui(uuid)',
    'api.get_library_regulation_documents_ui(uuid)',
    'api.resolve_circulation_rule(uuid, text, uuid, bigint, bigint, integer, date, date, integer)',
    'public.fn_batch_caller_can_edit(bigint)',
    'public.fn_caller_is_assembleia_facilitator(uuid)',
    'public.fn_circulation_concurrent_max(uuid, text)',
    'public.fn_classify_transition(text, text, text)',
    'public.fn_compute_membership_validity(uuid, timestamp with time zone)',
    'public.fn_current_user_is_in_network()',
    'public.fn_current_user_is_member_of(uuid)',
    'public.fn_current_user_is_member_of_holding_library(bigint)',
    'public.fn_library_active_staff_count(uuid)',
    'public.fn_library_is_federated(uuid)',
    'public.fn_library_uses_authority(uuid, text, bigint)',
    'public.fn_painel_find_profile_by_lookup(text)',
    'public.fn_partnership_canonical_id(uuid)',
    'public.fn_partnership_has_active_right(uuid, uuid, text)',
    'public.fn_partnership_reciprocal_id(uuid)',
    'public.fn_partnership_transparence_active(uuid, uuid, uuid)',
    'public.fn_request_caller_is_owner(uuid)',
    'public.get_library_notification_context(uuid)',
    'public.get_library_theme_config(text)',
    'public.get_library_theme_config_by_library_id(uuid)',
    'public.merge_serial(bigint, bigint)',
    'public.merge_subject(bigint, bigint)',
    'public.resolve_managed_library_id(uuid)',
    'public.set_library_theme_config(text, text, text, text)',
    'api.revoke_my_reader_card(uuid)',
    'public.discard_book(bigint)',
    'public.fn_ensure_current_user_profile()'
  ];
  c_portes   text[] := ARRAY[
    'api.get_library_institutional_workspace(uuid)',
    'api.get_batch_loan_projection(uuid, uuid, bigint[], bigint[], integer, date)',
    'public.fn_v2_book_session_availability_for_current_user(bigint[])',
    'public.fn_v2_extend_core(bigint, integer[], boolean)',
    'public.fn_batch_rubrics(bigint)',
    'public.catalog_digital_access_v1(bigint[])',
    'public.fn_library_visible_to_caller(uuid)',
    'public.fn_record_membership_payment(uuid, uuid, numeric, membership_payment_method, timestamp with time zone, text, date, date)',
    'public.fn_propose_library_profile_change(uuid, text, text, text)',
    'public.fn_painel_reader_other_memberships(uuid, uuid)',
    'public.fn_ill_request(uuid, uuid, bigint, text, text)',
    'api.fn_authority_apply(uuid)',
    'api.fn_authority_object(uuid, uuid, text)',
    'api.fn_assembleia_set_status(uuid, text)',
    'api.fn_request_mark_messages_read(uuid)'
  ];
BEGIN
  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 les 34 existent et sont fermees a anon, authenticated et PUBLIC';
  BEGIN
    v_txt := '';
    IF cardinality(c_fermees) <> 34 THEN v_txt := 'liste:' || cardinality(c_fermees) || ' '; END IF;
    FOREACH v_f IN ARRAY c_fermees LOOP
      v_oid := to_regprocedure(v_f);
      IF v_oid IS NULL THEN v_txt := v_txt || 'absente:' || v_f || ' '; CONTINUE; END IF;
      IF has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN v_txt := v_txt || 'authenticated:' || v_f || ' '; END IF;
      IF has_function_privilege('anon', v_oid, 'EXECUTE') THEN v_txt := v_txt || 'anon:' || v_f || ' '; END IF;
      IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  WHERE p.oid = v_oid AND a.grantee = 0) THEN
        v_txt := v_txt || 'PUBLIC:' || v_f || ' ';
      END IF;
    END LOOP;
    IF v_txt = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 aucune n a d appelant sous authenticated (politique, vue, dependance, INVOKER)';
  BEGIN
    v_txt := '';
    FOREACH v_f IN ARRAY c_fermees LOOP
      v_oid := to_regprocedure(v_f);
      CONTINUE WHEN v_oid IS NULL;
      SELECT p.proname INTO v_nom FROM pg_proc p WHERE p.oid = v_oid;
      IF EXISTS (SELECT 1 FROM pg_depend d
                  WHERE d.refclassid = 'pg_proc'::regclass AND d.refobjid = v_oid
                    AND d.classid <> 'pg_trigger'::regclass
                    AND (d.classid <> 'pg_proc'::regclass
                         OR NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = d.objid))) THEN
        v_txt := v_txt || 'dependance:' || v_nom || ' ';
      END IF;
      IF EXISTS (SELECT 1 FROM pg_policy pol
                  WHERE (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' '
                         || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~ ('\m' || v_nom || '\M')) THEN
        v_txt := v_txt || 'politique:' || v_nom || ' ';
      END IF;
      IF EXISTS (SELECT 1 FROM pg_views v
                  WHERE v.schemaname NOT IN ('pg_catalog', 'information_schema')
                    AND v.definition ~ ('\m' || v_nom || '\M')) THEN
        v_txt := v_txt || 'vue:' || v_nom || ' ';
      END IF;
      IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE NOT p.prosecdef AND p.oid <> v_oid
                    AND n.nspname NOT IN ('pg_catalog', 'information_schema')
                    AND p.prosrc ~ ('\m' || v_nom || '\s*\(')) THEN
        v_txt := v_txt || 'appelant-invoker:' || v_nom || ' ';
      END IF;
    END LOOP;
    IF v_txt = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_txt
        || '| un appelant sous authenticated est ne : rouvrir par un GRANT ecrit avec lui, et retirer la fonction de cette liste');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 les portes DEFINER restent ouvertes a authenticated';
  BEGIN
    v_txt := '';
    FOREACH v_f IN ARRAY c_portes LOOP
      v_oid := to_regprocedure(v_f);
      IF v_oid IS NULL THEN v_txt := v_txt || 'absente:' || v_f || ' '; CONTINUE; END IF;
      IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN v_txt := v_txt || 'fermee:' || v_f || ' '; END IF;
      IF NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = v_oid) THEN v_txt := v_txt || 'invoker:' || v_f || ' '; END IF;
    END LOOP;
    IF v_txt = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  -- Un compte sans adhésion (identifiant inconnu) frappe aux portes. Chaque
  -- porte appelle au moins une fermée ; le seul échec interdit est celui du
  -- privilège sur une fonction.
  v_t := 'T4 les portes, sous authenticated, ne butent jamais sur le privilege d une fermee';
  BEGIN
    v_txt := '';
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_inconnu, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';

    v_err := NULL;
    BEGIN PERFORM api.get_library_institutional_workspace(v_inconnu);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err ~* 'permission denied for function' THEN v_txt := v_txt || 'workspace:' || v_err || ' '; END IF;

    v_err := NULL;
    BEGIN PERFORM public.catalog_digital_access_v1(ARRAY[1, 2]::bigint[]);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err ~* 'permission denied for function' THEN v_txt := v_txt || 'acces-numerique:' || v_err || ' '; END IF;

    v_err := NULL;
    BEGIN PERFORM public.fn_library_visible_to_caller(v_inconnu);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err ~* 'permission denied for function' THEN v_txt := v_txt || 'visible:' || v_err || ' '; END IF;

    v_err := NULL;
    BEGIN PERFORM public.fn_v2_book_session_availability_for_current_user(ARRAY[1]::bigint[]);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err ~* 'permission denied for function' THEN v_txt := v_txt || 'disponibilite:' || v_err || ' '; END IF;

    v_err := NULL;
    BEGIN PERFORM public.fn_painel_reader_other_memberships(v_inconnu, v_inconnu);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err ~* 'permission denied for function' THEN v_txt := v_txt || 'autres-adhesions:' || v_err || ' '; END IF;

    v_err := NULL;
    BEGIN PERFORM api.fn_request_mark_messages_read(v_inconnu);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err ~* 'permission denied for function' THEN v_txt := v_txt || 'demande-lue:' || v_err || ' '; END IF;

    v_err := NULL;
    BEGIN PERFORM api.fn_assembleia_set_status(v_inconnu, 'open');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err ~* 'permission denied for function' THEN v_txt := v_txt || 'assemblee:' || v_err || ' '; END IF;

    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_txt = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ── Bilan ───────────────────────────────────────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'AIDES_DEFINER_FERMEES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'AIDES_DEFINER_FERMEES ECHEC : %/% OK, % échec(s) | %',
      v_passed, v_passed + v_failed, v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
