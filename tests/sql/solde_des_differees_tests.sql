-- Suite d'acceptation — migration 20260902104830 (B20, solde des différées).
--
-- Les 47 fonctions de `public` différées le 01/09 (« elles attendent leur
-- écran ») rejoignent le régime commun : fermées à anon et authenticated,
-- corps et suites intacts, restauration = GRANT le jour où l'écran arrive.
-- `fn_book_due_dates` est LA sortie du solde : ouverte à anon par verdict
-- écrit (T10 de grants_herites, audit B2 du 30/08) — cette suite garde la
-- frontière entre les deux régimes.
--
-- Rattrapage 20260902175631 : `fn_circle_member_count` est SORTIE du solde —
-- appelée par les vues api.my_library_circles_v1 et circles_directory_v1
-- (security_invoker, lues par FederacaoPage et EntraideTab), ce que la
-- mesure « 0 appelant » n'avait pas vu (pg_rewrite). 46 fermées ; elle
-- rejoint T3 avec les chemins vivants.

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_test_name text;
  v_liste text;
  v_n int;
BEGIN
  -- T1 : les 46 fermées à la porte du navigateur (fn_circle_member_count : voir T3)
  v_test_name := 'T1 les 46 fermées';
  SELECT count(*) INTO v_n
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'assign_book_to_work','fn_activate_approved_library_request',
      'fn_book_restricted_digital_state','fn_can_engage_library_for_storage',
      'fn_import_process_deposit',
      'fn_import_register_oai_source','fn_import_set_rows_review',
      'fn_is_cross_library_action','fn_library_has_staff_roles',
      'fn_library_publishes_catalog','fn_library_uses_governance',
      'fn_network_admin_request_removal','fn_network_dashboard_summary',
      'fn_network_discard_library_request','fn_network_get_library_request',
      'fn_network_library_metrics','fn_network_list_library_requests',
      'fn_notify_document_permission_request_now','fn_notify_library_request_now',
      'fn_required_governance_for_transition','fn_review_library_request',
      'fn_unarchive_transaction','get_book_primary_accessible_digital_asset_v2',
      'list_authors_not_duplicate','mark_authors_not_duplicate',
      'merge_author_with_fields','preview_library_notification',
      'preview_merge_author','set_library_regulation_document_active',
      'set_library_theme_config_by_library_id','suggest_authority_duplicates',
      'suggest_subject_duplicates','test_library_mail_channel',
      'unlink_author_book','unmark_authors_not_duplicate',
      'upsert_library_notification_policies','upsert_library_notification_profile',
      'upsert_library_regulation_document',
      'fn_v2_add_emprestimo_interbibliotecas_itens',
      'fn_v2_cancel_emprestimo_interbibliotecas',
      'fn_v2_create_emprestimo_interbibliotecas',
      'fn_v2_dispatch_emprestimo_interbibliotecas',
      'fn_v2_remove_emprestimo_interbibliotecas_item',
      'fn_v2_remove_emprestimo_interbibliotecas_itens',
      'fn_v2_return_emprestimo_interbibliotecas_linhas',
      'fn_v2_start_devolucao_emprestimo_interbibliotecas');
  IF v_n <> 46 THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : ' || v_n || '/46 présentes — liste et base divergent');
  ELSE
    SELECT string_agg(p.proname, ', ') INTO v_liste
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'assign_book_to_work','fn_activate_approved_library_request',
        'fn_book_restricted_digital_state','fn_can_engage_library_for_storage',
        'fn_import_process_deposit',
        'fn_import_register_oai_source','fn_import_set_rows_review',
        'fn_is_cross_library_action','fn_library_has_staff_roles',
        'fn_library_publishes_catalog','fn_library_uses_governance',
        'fn_network_admin_request_removal','fn_network_dashboard_summary',
        'fn_network_discard_library_request','fn_network_get_library_request',
        'fn_network_library_metrics','fn_network_list_library_requests',
        'fn_notify_document_permission_request_now','fn_notify_library_request_now',
        'fn_required_governance_for_transition','fn_review_library_request',
        'fn_unarchive_transaction','get_book_primary_accessible_digital_asset_v2',
        'list_authors_not_duplicate','mark_authors_not_duplicate',
        'merge_author_with_fields','preview_library_notification',
        'preview_merge_author','set_library_regulation_document_active',
        'set_library_theme_config_by_library_id','suggest_authority_duplicates',
        'suggest_subject_duplicates','test_library_mail_channel',
        'unlink_author_book','unmark_authors_not_duplicate',
        'upsert_library_notification_policies','upsert_library_notification_profile',
        'upsert_library_regulation_document',
        'fn_v2_add_emprestimo_interbibliotecas_itens',
        'fn_v2_cancel_emprestimo_interbibliotecas',
        'fn_v2_create_emprestimo_interbibliotecas',
        'fn_v2_dispatch_emprestimo_interbibliotecas',
        'fn_v2_remove_emprestimo_interbibliotecas_item',
        'fn_v2_remove_emprestimo_interbibliotecas_itens',
        'fn_v2_return_emprestimo_interbibliotecas_linhas',
        'fn_v2_start_devolucao_emprestimo_interbibliotecas')
      AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'));
    IF v_liste IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : encore ouvertes — ' || v_liste); END IF;
  END IF;

  -- T2 : la sortie du solde — fn_book_due_dates reste ouverte (verdict B2/T10)
  v_test_name := 'T2 fn_book_due_dates hors du solde';
  IF has_function_privilege('anon', 'public.fn_book_due_dates(bigint)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.fn_book_due_dates(bigint)', 'EXECUTE') THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : fermée — le verdict B2 (T10) serait contredit'); END IF;

  -- T3 : les chemins vivants des mêmes familles restent ouverts — dont
  --      fn_circle_member_count, appelée par les vues des cercles
  --      (rattrapage 20260902175631).
  v_test_name := 'T3 chemins vivants ouverts';
  SELECT string_agg(a.nsp||'.'||a.nom, ', ') INTO v_liste
  FROM (VALUES ('api','fn_approve_library_request'),('public','fn_import_list_oai_sources'),
               ('public','fn_import_harvest_oai'),('public','merge_book_with_fields'),
               ('public','fn_circle_member_count')) a(nsp, nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = a.nsp AND p.proname = a.nom
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_test_name || ' : fermés ou introuvables — ' || v_liste); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'SOLDE_DIFFEREES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'SOLDE_DIFFEREES OK : %/% tests passés', v_passed, v_passed;
END $$;
