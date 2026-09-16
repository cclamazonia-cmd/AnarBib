-- ===========================================================================
-- B22 — quarante-sept fonctions ouvertes à anon sans qu'aucune ligne du dépôt
-- ne le dise, et cinq vues fermées sans qu'aucune ligne ne le dise non plus.
-- Relevé en production le 16/09/2026 (lecture seule), classement contre le
-- dépôt (aucun GRANT ... TO anon/PUBLIC écrit pour ces 47), appelants
-- cherchés AVANT tout REVOKE : vues (pg_views, security_invoker ou non),
-- policies (pg_policy), fonctions (prosrc + prosecdef), triggers, expressions
-- d'index et défauts générés — REGISTRE « avant un REVOKE, chercher les VUES ».
--
-- Le principe (DOC-GRANT-1) : chaque ouverture à anon est une ligne écrite.
-- Ce qu'on a trouvé :
--
--   * quatre ouvertures qui SERVENT, mais que rien n'écrivait :
--     private.fn_book_work_id (lue par api.catalog_list_anon_v1 et
--     catalog_list_session_v1, deux vues security_invoker que anon lit),
--     public.fn_book_restricted_pdf_state et _for_current_user (la page
--     publique du livre et l'Edge Function read-pdf), public.fn_volume_rank
--     (appelée par api.catalog_works_v1 et api.work_public_detail, INVOKER,
--     que anon appelle). Elles n'étaient ouvertes que par un défaut du
--     moment de leur création ; on écrit le GRANT ;
--
--   * quarante-trois ouvertures qui ne servent à rien sous anon, et se ferment :
--     - 10 RPC de circulation d'api (prêts, consultations) et 2 à ACL nulle,
--       ouvertes par PUBLIC ; le front ne les appelle que connecté (BookPage
--       teste `user` avant create_consulta_local) ; elles refusaient déjà,
--       mais un visiteur anonyme n'a pas à pouvoir les appeler ;
--     - 17 helpers et triggers d'ingest ouverts par PUBLIC ; leurs appelants
--       sont des DEFINER (fn_match_partner_catalog_row, fn_create_book_drafts_
--       from_import_rows…), des triggers, ou trois vues security_invoker de
--       l'écran d'import lues par le staff — d'où authenticated conservé ou
--       écrit ; fn_match_normalize_text et fn_normalize_isxn sont dans des
--       expressions d'index de books/book_drafts, évaluées par qui écrit :
--       authenticated les garde ;
--     - 5 triggers et helpers des périodiques (serials, tomes) créés le 27/08
--       et le 04/09 sans REVOKE, plus fn_serial_issue_key (défaut généré de
--       books.issue_key, évalué par qui écrit : authenticated le garde) ;
--     - fn_title_sans_volume, fn_title_lisible_sans_volume, fn_volume_marker
--       n'est pas concernée (GRANT écrit) ; fn_conv_est_non_agent (deux vues
--       DEFINER et fn_batch_review_report) ; les trois fn_assert_* (appelées
--       par des DEFINER) ;
--     - deux DEFINER qui étaient dans T10 « attestées ouvertes » sans qu'aucune
--       ligne ne les ouvre : fn_current_user_is_member_of_holding_library
--       (appelée par deux DEFINER seulement) et fn_reading_notes_enabled_for
--       (une policy d'INSERT sur book_reading_notes, évaluée par qui insère :
--       authenticated). Elles changent de camp : T10 passe de 28 à 26, et le
--       lint 0028 doit rendre 26 ;
--
--   * cinq vues du socle sans security_invoker (listes de travail de
--     dédoublonnage, Terra Livre) que la production ne laisse lire à personne
--     (anon=m, authenticated=m : MAINTAIN seul, aucun SELECT) — mais le
--     REVOKE SELECT qui les a fermées n'était écrit nulle part : au rejeu sur
--     une image réelle (défaut anon=arwdm sur les relations) elles naissent
--     lisibles et T7 rougit (expérience I17, 07/09). Personne ne les lit sous
--     anon ni authenticated : api.report_auteurs_non_resolus est DEFINER,
--     v_terra_livre_books_ready_stats lit v_terra_livre_books_ready sous le
--     rôle de la vue, aucune policy ne les cite. On écrit le REVOKE.
--
-- Rien d'autre ne change : ni corps de fonction, ni policy, ni donnée. Le
-- bloc DO final vérifie chaque camp ; tests/sql/grants_herites_tests.sql T12
-- porte désormais la liste fermée de TOUT ce qui reste exécutable par anon.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Les quatre ouvertures qui servent : écrites.
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION private.fn_book_work_id(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION private.fn_book_work_id(bigint) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_book_restricted_pdf_state(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_book_restricted_pdf_state(text) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_book_restricted_pdf_state_for_current_user(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_book_restricted_pdf_state_for_current_user(text) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_volume_rank(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_volume_rank(text) TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Les deux DEFINER qui changent de camp (sortent de T10).
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.fn_current_user_is_member_of_holding_library(bigint) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_current_user_is_member_of_holding_library(bigint) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_reading_notes_enabled_for(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_reading_notes_enabled_for(uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Périodiques et tomes : triggers (aucun grant nécessaire pour se déclencher)
--    et helpers évalués par qui écrit.
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.fn_book_drafts_serial_id_requires_periodico() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_books_serial_id_requires_periodico()       FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_serials_autoslug()                         FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_serials_filiation_no_cycle()               FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_serials_filiation_symmetry()               FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.fn_serial_issue_key(text, text, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_serial_issue_key(text, text, text, text, text) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_title_sans_volume(text)         FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_title_sans_volume(text)         TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_title_lisible_sans_volume(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_title_lisible_sans_volume(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. Helpers de public ouverts par PUBLIC, appelés par des DEFINER.
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.fn_conv_est_non_agent(text)              FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_conv_est_non_agent(text)              TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_assert_can_review_library_requests()  FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_assert_can_review_library_requests()  TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_assert_can_view_network_metrics()     FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_assert_can_view_network_metrics()     TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_assert_network_admin()                FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_assert_network_admin()                TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Circulation (api) : connecté seulement.
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION api.advance_consulta(bigint, integer[], text, text, timestamptz, timestamptz, timestamptz, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.advance_consulta(bigint, integer[], text, text, timestamptz, timestamptz, timestamptz, text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.cancel_consulta_as_reader(bigint, integer[], text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.cancel_consulta_as_reader(bigint, integer[], text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.create_consulta_local(uuid, bigint[], timestamptz, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.create_consulta_local(uuid, bigint[], timestamptz, text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.create_loan_at_counter(uuid, bigint[], date, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.create_loan_at_counter(uuid, bigint[], date, text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.dismiss_consulta_cancelled(bigint, integer[], text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.dismiss_consulta_cancelled(bigint, integer[], text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.extend_loan_as_library(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.extend_loan_as_library(bigint) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.renew_my_loan(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.renew_my_loan(bigint) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.reply_consulta_schedule(bigint, integer[], text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.reply_consulta_schedule(bigint, integer[], text, text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.return_loan_partial(bigint, integer[], text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.return_loan_partial(bigint, integer[], text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.return_loan_total(bigint, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.return_loan_total(bigint, text) TO authenticated, service_role;
-- ACL nulle (défaut natif de PostgreSQL = PUBLIC) : on l'écrit.
REVOKE EXECUTE ON FUNCTION api.extend_loan_item_as_library(bigint, integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.extend_loan_item_as_library(bigint, integer) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION api.renew_my_loan_item(bigint, integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.renew_my_loan_item(bigint, integer) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. ingest : helpers et triggers du rapprochement de catalogues partenaires.
--    service_role reste (les dispatchs) ; authenticated pour ce que les vues
--    security_invoker de l'écran d'import et les expressions d'index évaluent.
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION ingest.fn_apply_duplicate_signal_to_match_candidate()                              FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_classify_duplicate_signal(text, boolean, boolean, boolean, boolean)      FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_classify_responsibility_match(text, text)                                FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_extract_year4(text)                                                      FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_format_partner_authors(jsonb)                                            FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_match_normalize_responsibility(text)                                     FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_match_normalize_publisher(text)                                          FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_match_responsibility_initialism(text)                                    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_oai_harvest_state_touch_updated()                                        FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.fn_stamp_run_library_id()                                                   FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.set_partner_catalog_import_dispatch_log_updated_at()                        FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION ingest.set_updated_at()                                                            FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_apply_duplicate_signal_to_match_candidate()                              TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_classify_duplicate_signal(text, boolean, boolean, boolean, boolean)      TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_classify_responsibility_match(text, text)                                TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_extract_year4(text)                                                      TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_format_partner_authors(jsonb)                                            TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_match_normalize_responsibility(text)                                     TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_match_normalize_publisher(text)                                          TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_match_responsibility_initialism(text)                                    TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_oai_harvest_state_touch_updated()                                        TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.fn_stamp_run_library_id()                                                   TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.set_partner_catalog_import_dispatch_log_updated_at()                        TO service_role;
GRANT  EXECUTE ON FUNCTION ingest.set_updated_at()                                                            TO service_role;
-- Expressions d'index sur books et book_drafts (idx_*_tit_aut_norm, idx_*_isbn_norm, idx_*_issn_norm).
REVOKE EXECUTE ON FUNCTION ingest.fn_match_normalize_text(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_match_normalize_text(text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION ingest.fn_normalize_isxn(text)       FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_normalize_isxn(text)       TO authenticated, service_role;
-- Vues security_invoker de l'écran d'import (api.partner_catalog_import_*_ui), lues par le staff.
REVOKE EXECUTE ON FUNCTION ingest.fn_is_editorial_decision_compatible(text, text)                             FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_is_editorial_decision_compatible(text, text)                             TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION ingest.fn_partner_catalog_extract_collection_hint(jsonb, jsonb)                    FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_partner_catalog_extract_collection_hint(jsonb, jsonb)                    TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION ingest.fn_partner_catalog_extract_local_classification_hint(jsonb, jsonb)          FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_partner_catalog_extract_local_classification_hint(jsonb, jsonb)          TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7. Les cinq vues de T7 : l'état de la production, écrit.
-- ---------------------------------------------------------------------------
REVOKE SELECT ON public.v_author_alias_candidates_unique FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON public.v_author_alias_worklist          FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON public.v_author_seed_candidates         FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON public.v_terra_livre_books_ready        FROM PUBLIC, anon, authenticated;
REVOKE SELECT ON public.v_terra_livre_books_ready_stats  FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. Vérification : chaque camp est celui qu'on vient d'écrire.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_ouvertes text[] := ARRAY[
    'private.fn_book_work_id(bigint)',
    'public.fn_book_restricted_pdf_state(text)',
    'public.fn_book_restricted_pdf_state_for_current_user(text)',
    'public.fn_volume_rank(text)'];
  v_fermees text[] := ARRAY[
    'public.fn_current_user_is_member_of_holding_library(bigint)',
    'public.fn_reading_notes_enabled_for(uuid)',
    'public.fn_book_drafts_serial_id_requires_periodico()',
    'public.fn_books_serial_id_requires_periodico()',
    'public.fn_serials_autoslug()',
    'public.fn_serials_filiation_no_cycle()',
    'public.fn_serials_filiation_symmetry()',
    'public.fn_serial_issue_key(text,text,text,text,text)',
    'public.fn_title_sans_volume(text)',
    'public.fn_title_lisible_sans_volume(text)',
    'public.fn_conv_est_non_agent(text)',
    'public.fn_assert_can_review_library_requests()',
    'public.fn_assert_can_view_network_metrics()',
    'public.fn_assert_network_admin()',
    'api.advance_consulta(bigint,integer[],text,text,timestamptz,timestamptz,timestamptz,text)',
    'api.cancel_consulta_as_reader(bigint,integer[],text)',
    'api.create_consulta_local(uuid,bigint[],timestamptz,text)',
    'api.create_loan_at_counter(uuid,bigint[],date,text)',
    'api.dismiss_consulta_cancelled(bigint,integer[],text)',
    'api.extend_loan_as_library(bigint)',
    'api.renew_my_loan(bigint)',
    'api.reply_consulta_schedule(bigint,integer[],text,text)',
    'api.return_loan_partial(bigint,integer[],text)',
    'api.return_loan_total(bigint,text)',
    'api.extend_loan_item_as_library(bigint,integer)',
    'api.renew_my_loan_item(bigint,integer)',
    'ingest.fn_apply_duplicate_signal_to_match_candidate()',
    'ingest.fn_classify_duplicate_signal(text,boolean,boolean,boolean,boolean)',
    'ingest.fn_classify_responsibility_match(text,text)',
    'ingest.fn_extract_year4(text)',
    'ingest.fn_format_partner_authors(jsonb)',
    'ingest.fn_is_editorial_decision_compatible(text,text)',
    'ingest.fn_match_normalize_publisher(text)',
    'ingest.fn_match_normalize_responsibility(text)',
    'ingest.fn_match_normalize_text(text)',
    'ingest.fn_match_responsibility_initialism(text)',
    'ingest.fn_normalize_isxn(text)',
    'ingest.fn_oai_harvest_state_touch_updated()',
    'ingest.fn_partner_catalog_extract_collection_hint(jsonb,jsonb)',
    'ingest.fn_partner_catalog_extract_local_classification_hint(jsonb,jsonb)',
    'ingest.fn_stamp_run_library_id()',
    'ingest.set_partner_catalog_import_dispatch_log_updated_at()',
    'ingest.set_updated_at()'];
  v_vues text[] := ARRAY['v_author_alias_candidates_unique','v_author_alias_worklist','v_author_seed_candidates',
                         'v_terra_livre_books_ready','v_terra_livre_books_ready_stats'];
  s text; ko text[] := '{}';
BEGIN
  FOREACH s IN ARRAY v_ouvertes LOOP
    IF NOT has_function_privilege('anon', s::regprocedure, 'EXECUTE') THEN ko := ko || ('fermee a tort : '||s); END IF;
  END LOOP;
  FOREACH s IN ARRAY v_fermees LOOP
    IF has_function_privilege('anon', s::regprocedure, 'EXECUTE') THEN ko := ko || ('encore ouverte a anon : '||s); END IF;
  END LOOP;
  IF array_length(v_fermees, 1) <> 43 THEN ko := ko || ('la liste des fermees doit compter 43, pas '||array_length(v_fermees, 1)); END IF;
  FOREACH s IN ARRAY v_vues LOOP
    IF has_table_privilege('anon', 'public.'||s, 'SELECT') OR has_table_privilege('authenticated', 'public.'||s, 'SELECT') THEN
      ko := ko || ('vue encore lisible : '||s);
    END IF;
  END LOOP;
  IF array_length(ko, 1) > 0 THEN
    RAISE EXCEPTION 'B22 : % ecart(s) -> %', array_length(ko, 1), array_to_string(ko, ' | ');
  END IF;
  RAISE NOTICE 'B22 : 4 ouvertures ecrites, 43 fermetures, 5 vues fermees — conforme.';
END $$;
