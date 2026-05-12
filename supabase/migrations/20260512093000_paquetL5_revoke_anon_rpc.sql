-- =========================================================================
-- Paquet L.5 — REVOKE EXECUTE FROM anon sur les RPC métier + liste blanche
-- =========================================================================
-- Contexte : après L.4 et L.4bis qui ont nettoyé triggers/helpers/cron, il
-- reste ~120 RPC métier SECURITY DEFINER avec EXECUTE anon par défaut.
-- Doctrine adoptée (session 2026-05-11) : révoquer anon partout sauf liste
-- blanche pour les parcours publics.
--
-- AUDIT JWT PRÉALABLE (session 2026-05-12 matin) :
--   - Vérifié que les 3 helpers utilisés dans des RLS de tables anon-lisibles
--     (fn_library_visible_to_caller, fn_current_user_is_in_network,
--     fn_current_user_is_member_of) ont déjà GRANT anon depuis L.4bis
--   - Vérifié en contexte PostgREST-like que le catalogue public retourne
--     bien : 240 livres, 47 auteur·rices, 2 biblios, 240 holdings
--   - Confirmé que les fonctions de circulation (resolve_circulation_rule,
--     get_due_date_*, get_remaining_renewals, get_future_availability) ne
--     sont pas utilisées en parcours anon (statut prêt accessible après login
--     seulement) — donc PAS dans la liste blanche
--
-- LISTE BLANCHE (7 fonctions accessibles à anon par design) :
--   1. api.search_catalog_v1                       — catalogue public anonyme
--   2. public.fn_consume_library_request_claim     — workflow claim email
--   3. public.fn_get_library_request_claim_context — workflow claim email
--   4. public.fn_submit_library_request            — formulaire public
--   5. public.fn_submit_library_request_via_claim  — variante claim token
--   6. public.get_book_primary_public_digital_asset_v2 — asset public
--   7. public.resolve_login_email                  — login (LoginPage.jsx)
--
-- VÉRIFICATION AUTOMATIQUE en fin de migration :
--   Un DO block teste 4 parcours anon critiques. Si l'un échoue, toute la
--   transaction roll-back et Woodpecker remonte l'erreur.
--
-- Risque : modéré, fortement atténué par l'audit JWT et la vérification.
-- Rollback ciblé si régression imprévue :
--   GRANT EXECUTE ON FUNCTION <signature> TO anon;
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Schema api : révocation
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION api.get_library_circulation_policy_rules_ui(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.get_library_circulation_policy_sets_ui(uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.get_library_institutional_workspace(uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.get_library_regulation_documents_ui(uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.resolve_circulation_rule(
  uuid, text, uuid, bigint, bigint, integer, date, date, integer
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.get_batch_loan_projection(
  uuid, uuid, bigint[], bigint[], integer, date
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.get_due_date_after_renewal(
  uuid, uuid, bigint, bigint, integer, date, integer, date
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.get_due_date_for_loan(
  uuid, uuid, bigint, bigint, integer, date
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.get_future_availability(uuid, bigint, bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.get_remaining_renewals(
  uuid, uuid, bigint, bigint, integer, integer, date
) FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 2. Schema public : actions circulation
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.circulation_reader_scope(uuid, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_renew_my_loan(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_dispatch_circulation_notify_event(text, bigint, jsonb)
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 3. Schema public : actions catalogage
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.copy_book_catalog_context_to_draft(bigint, bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.copy_book_digital_resources_to_draft(bigint, bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_author_draft_from_author(bigint, bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_book_draft_from_book(bigint, bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_exemplar_draft_from_exemplar(bigint, bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_author_draft(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_book_draft(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_book_draft_digital_resources(bigint, bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_catalog_batch(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_exemplar_draft(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_book_catalog_context_from_marc_json(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_book_draft_catalog_context_from_marc_json(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_bulk_create_book_drafts_from_run(bigint, bigint, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_bulk_set_partner_catalog_editorial_decision(bigint[], text, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_set_partner_catalog_editorial_decision(bigint, text, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.link_author_to_book_contributors(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.link_book_contributors_to_authors(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.resolve_library_holding_bridge(uuid, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.resolve_managed_library_id(uuid)
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 4. Schema public : actions assets numériques
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_book_restricted_digital_state(text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_book_restricted_pdf_state_for_current_user(text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_accessible_digital_asset_by_id_v2(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_book_primary_accessible_digital_asset_v2(bigint)
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 5. Schema public : actions équipe
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_librarian(uuid, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_coordenador(uuid, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_promote_to_administrador(uuid, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_self_demote(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_suspend_member(uuid, uuid, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_unsuspend_member(uuid, uuid, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_request_remove_member(uuid, uuid, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_cancel_remove_member(uuid, uuid, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_team_list_memberships(text, uuid)
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 6. Schema public : compte personnel
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_delete_my_account()
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_ensure_current_user_profile()
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_mark_notifications_read(bigint[])
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 7. Schema public : library_requests modération
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_activate_approved_library_request(uuid, text, boolean, boolean)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_review_library_request(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_discard_library_request(uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_get_library_request(uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_list_library_requests()
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_dashboard_summary()
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_library_metrics()
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 8. Schema public : notifications et permissions documents
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.create_document_permission_request(uuid, uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decide_document_permission_request(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.enqueue_task_level_notifications_from_task(uuid, text, text[])
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_enqueue_document_permission_request_notification(uuid, text, text, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_enqueue_emprestimo_interbibliotecas_notification(bigint, text, text, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_enqueue_library_request_notification(uuid, text, text, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_notify_document_permission_request_now(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_notify_emprestimo_interbibliotecas_webhook(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_notify_library_request_now(uuid, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.preview_library_notification(uuid, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.test_library_mail_channel(uuid)
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 9. Schema public : panel administration
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_painel_find_profile_by_email(text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_painel_find_profile_by_lookup(text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_painel_get_profile_by_id(uuid)
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 10. Schema public : circulation policies, regulation, theme, contact, mail
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.delete_library_circulation_policy_rule(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_library_circulation_policy_set_active(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_library_regulation_document_active(bigint, boolean)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_library_theme_config(text, text, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_library_theme_config_by_library_id(uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_library_circulation_policy_rule(bigint, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_library_circulation_policy_set(uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_library_contact_profile(uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_library_document_governance(uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_library_mail_channel(uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_library_notification_policies(uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_library_notification_profile(uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_library_regulation_document(uuid, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_library_contact_for_cooperation(uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_library_notification_context(uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_library_theme_config(text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_library_theme_config_by_library_id(uuid)
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 11. Schema public : compute helpers métier
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_compute_membership_validity(
  uuid, timestamp with time zone
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_is_loan_blocked_by_dues(uuid, uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_list_membership_payments_for_user(uuid)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_record_membership_payment(
  uuid, uuid, numeric, public.membership_payment_method,
  timestamp with time zone, text, date, date
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.user_has_library_staff_role(uuid, uuid)
  FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 12. Schema public : actions admin réseau
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_network_admin_propose_cooptation(uuid, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_admin_vote_cooptation(
  uuid, text, boolean, text
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_admin_request_removal(uuid, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_admin_self_remove(text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_admin_propose_collective_removal(
  uuid, text
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_admin_vote_collective_removal(
  uuid, text, boolean, text
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_network_admin_cancel_collective_removal(
  uuid, text
) FROM PUBLIC, anon;

-- -------------------------------------------------------------------------
-- 13. Schema public : fonctions v2 (emprestimo, reserva, consulta, interbibliotecas)
-- -------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.fn_v2_add_emprestimo_interbibliotecas_itens(bigint, bigint[], date, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_book_session_availability_for_current_user(bigint[])
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_book_session_context_for_current_user(bigint, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_cancel_consulta_linhas_as_leitor(bigint, integer[], text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_cancel_emprestimo_interbibliotecas(bigint, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_cancel_reserva_linhas_as_biblioteca(bigint, integer[], text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_cancel_reserva_linhas_as_leitor(bigint, integer[], text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_clear_emprestimo_return_schedule(bigint, integer[], text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_convert_reserva_linhas_to_emprestimo(bigint, integer[], date, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_create_consulta_local_by_holdings(uuid, bigint[], timestamp with time zone, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_create_emprestimo_by_holdings(uuid, bigint[], date, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_create_emprestimo_interbibliotecas(jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_create_reserva_by_holdings(uuid, bigint[], timestamp with time zone, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_dismiss_consulta_cancelled_as_leitor(bigint, integer[], text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_dispatch_emprestimo_interbibliotecas(bigint, date, date, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_extend_emprestimo_once(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_log_emprestimo_interbibliotecas_event(bigint, bigint, text, text, jsonb)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_mark_emprestimo_return_missed(bigint, integer[], text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_recompute_from_emprestimo_interbibliotecas_linhas(bigint, integer[])
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_recompute_from_emprestimo_lines(bigint, integer[])
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_recompute_from_reserva_lines(bigint, integer[])
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_recompute_holdings_availability(bigint[], bigint[])
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_refresh_consulta_status_global(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_refresh_emprestimo_interbibliotecas_status_global(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_refresh_reserva_status_global(bigint)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_remove_emprestimo_interbibliotecas_item(bigint, integer[])
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_remove_emprestimo_interbibliotecas_itens(bigint, bigint[], text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_resolve_catalog_refs_for_current_user(text[])
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_return_emprestimo_interbibliotecas_linhas(bigint, integer[], text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_return_emprestimo_linhas(bigint, integer[], text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_return_emprestimo_total(bigint, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_schedule_emprestimo_return(bigint, integer[], timestamp with time zone, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_set_consulta_linhas_schedule_reply(bigint, integer[], text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_set_consulta_linhas_workflow(bigint, integer[], text, text, timestamp with time zone)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_set_consulta_linhas_workflow_slot(bigint, integer[], text, text, text, text, text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_set_reserva_linhas_pickup_reply(bigint, integer[], text, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_set_reserva_linhas_workflow(
  bigint, integer[], text, text, timestamp with time zone, text, boolean
) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_v2_start_devolucao_emprestimo_interbibliotecas(bigint, text)
  FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_validate_consulta_schedule_window(uuid, bigint, timestamp with time zone, timestamp with time zone)
  FROM PUBLIC, anon;

-- =========================================================================
-- LISTE BLANCHE : GRANT EXECUTE TO anon explicite pour les 7 fonctions
-- =========================================================================

GRANT EXECUTE ON FUNCTION api.search_catalog_v1(text)
  TO anon;
GRANT EXECUTE ON FUNCTION public.fn_consume_library_request_claim(text, uuid)
  TO anon;
GRANT EXECUTE ON FUNCTION public.fn_get_library_request_claim_context(text)
  TO anon;
GRANT EXECUTE ON FUNCTION public.fn_submit_library_request(
  text, text, text, text, text, text, text, text, text, text, text, text,
  text, text, text, text, text, text, boolean, boolean
) TO anon;
GRANT EXECUTE ON FUNCTION public.fn_submit_library_request_via_claim(
  text, text, text, text, text, text, text, text, text, text, text, text,
  text, text, text, text, text, text, text, boolean, boolean
) TO anon;
GRANT EXECUTE ON FUNCTION public.get_book_primary_public_digital_asset_v2(bigint)
  TO anon;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(text)
  TO anon;

-- =========================================================================
-- Commentaires de traçabilité sur les fonctions de la liste blanche
-- =========================================================================

COMMENT ON FUNCTION api.search_catalog_v1(text) IS
  'Catalogue public anonyme. EXECUTE anon explicite depuis paquet L.5 (2026-05-12).';

COMMENT ON FUNCTION public.resolve_login_email(text) IS
  'Resolution identifiant -> email pour login case-insensitive. EXECUTE anon '
  'explicite depuis paquet L.5 (2026-05-12). Appelée par LoginPage.jsx ligne 60. '
  'Note : version api.resolve_login_email supprimée par paquet L.6.';

COMMENT ON FUNCTION public.get_book_primary_public_digital_asset_v2(bigint) IS
  'Asset numérique public d''un livre. EXECUTE anon explicite depuis paquet L.5 '
  '(2026-05-12). Filtrage par access_scope dans la fonction.';

-- =========================================================================
-- VÉRIFICATION AUTOMATIQUE POST-DÉPLOIEMENT
-- =========================================================================
-- 4 tests en contexte PostgREST-like anon. Si l'un échoue, ROLLBACK auto.

DO $$
DECLARE
  v_books_count       int;
  v_libraries_count   int;
  v_holdings_count    int;
  v_catalog_results   int;
  v_whitelist_ok      boolean;
BEGIN
  -- Test 1 : catalogue lisible en mode anon (parcours visiteur·euse)
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';

  SELECT count(*) INTO v_books_count     FROM public.books;
  SELECT count(*) INTO v_libraries_count FROM public.libraries;
  SELECT count(*) INTO v_holdings_count  FROM public.book_holdings;

  IF v_books_count < 1 THEN
    RAISE EXCEPTION 'Test 1 échec : books invisible en anon (% lignes). Rollback automatique.', v_books_count;
  END IF;

  IF v_libraries_count < 2 THEN
    RAISE EXCEPTION 'Test 1 échec : libraries < 2 en anon (% lignes, attendu BLMF + BTL).', v_libraries_count;
  END IF;

  IF v_holdings_count < 1 THEN
    RAISE EXCEPTION 'Test 1 échec : book_holdings invisible en anon (% lignes).', v_holdings_count;
  END IF;

  -- Test 2 : api.search_catalog_v1 appelable en anon
  BEGIN
    SELECT count(*) INTO v_catalog_results FROM api.search_catalog_v1('a');
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Test 2 échec : api.search_catalog_v1 inaccessible en anon (%). Liste blanche cassée.', SQLERRM;
  END;

  -- Test 3 : la fonction de demande de biblio reste appelable en anon
  --          (on ne l'invoque pas pour de vrai, juste vérifie EXECUTE)
  v_whitelist_ok := has_function_privilege('anon',
    'public.fn_consume_library_request_claim(text, uuid)', 'EXECUTE');
  IF NOT v_whitelist_ok THEN
    RAISE EXCEPTION 'Test 3 échec : fn_consume_library_request_claim plus accessible à anon.';
  END IF;

  -- Test 4 : une fonction métier RÉVOQUÉE n'est plus accessible à anon
  v_whitelist_ok := has_function_privilege('anon',
    'public.fn_team_promote_to_librarian(uuid, uuid)', 'EXECUTE');
  IF v_whitelist_ok THEN
    RAISE EXCEPTION 'Test 4 échec : fn_team_promote_to_librarian encore accessible à anon (révocation cassée).';
  END IF;

  RESET ROLE;

  RAISE NOTICE 'Paquet L.5 vérifications OK :';
  RAISE NOTICE '  - Catalogue anon : % livres, % biblios, % holdings', v_books_count, v_libraries_count, v_holdings_count;
  RAISE NOTICE '  - api.search_catalog_v1 (liste blanche) : % résultats pour ''a''', v_catalog_results;
  RAISE NOTICE '  - fn_consume_library_request_claim (liste blanche) : accessible anon';
  RAISE NOTICE '  - fn_team_promote_to_librarian (révoquée) : inaccessible anon';
END $$;

COMMIT;

-- =========================================================================
-- TESTS MANUELS OBLIGATOIRES après push (navigation privée) :
-- =========================================================================
-- 1. https://app.anarbib.org/criar-conta — signup avec BLMF et BTL visibles
-- 2. https://app.anarbib.org/login — login avec un compte existant
-- 3. https://app.anarbib.org/catalogo — recherche d'un livre sans connexion
-- 4. https://app.anarbib.org/solicitar-biblioteca — formulaire accessible
-- =========================================================================
-- Vérification finale du linter Supabase après push :
-- =========================================================================
-- SELECT count(*) FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname IN ('public', 'api')
--   AND p.prosecdef = true
--   AND has_function_privilege('anon', p.oid, 'EXECUTE');
-- Résultat attendu : 7 (liste blanche stricte) + 8 (helpers RLS via L.4bis) = 15
-- =========================================================================
-- Rollback ciblé si régression imprévue sur une fonction précise :
-- =========================================================================
-- GRANT EXECUTE ON FUNCTION <schema>.<fonction>(<signature>) TO anon;
-- =========================================================================
