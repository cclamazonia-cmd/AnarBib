-- =========================================================================
-- Paquet L.9 — GRANT explicites futur-proof (conformité Supabase 30/10/2026)
-- =========================================================================
-- Contexte : Supabase annonce un changement de defaults sur la Data API à
-- partir du 30/05/2026 pour les nouveaux projets, et du 30/10/2026 pour les
-- projets existants (dont AnarBib). À partir de cette date, les tables
-- créées dans `public` ne seront plus automatiquement accessibles à anon
-- ou authenticated via la Data API : un GRANT explicite sera requis.
--
-- Ce paquet RÉ-AFFIRME EXPLICITEMENT les permissions actuellement en
-- vigueur sur toutes les tables de `public`, telles qu'elles ressortent
-- de l'audit du 12/05/2026. Aucune permission n'est ajoutée ou retirée :
-- ce paquet est IDEMPOTENT et a un risque NUL.
--
-- Objectif : que le 30/10/2026, AnarBib continue de fonctionner
-- identiquement même si Supabase resserre les defaults. Les GRANT
-- explicites en migration deviennent la source de vérité, et toute
-- création future de table devra suivre le même pattern.
--
-- Note : le paquet L.8 (à venir) resserrera les permissions anon
-- excessives (INSERT/UPDATE/DELETE sans policy correspondante). L.9 fige
-- l'état actuel, L.8 le rétrécira ensuite proprement.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Tables avec lecture anon (catalogue public + référentiels)
-- -------------------------------------------------------------------------
-- 43 tables visibles publiquement. SELECT pour anon, opérations complètes
-- pour authenticated (filtré par RLS).

GRANT SELECT ON public.author_name_aliases TO anon;
GRANT SELECT ON public.author_translations TO anon;
GRANT SELECT ON public.authors TO anon;
GRANT SELECT ON public.book_authors TO anon;
GRANT SELECT ON public.book_catalog_context TO anon;
GRANT SELECT ON public.book_digital_resources TO anon;
GRANT SELECT ON public.book_holdings TO anon;
GRANT SELECT ON public.books TO anon;
GRANT SELECT ON public.catalog_partner_capabilities TO anon;
GRANT SELECT ON public.catalog_partner_probe_runs TO anon;
GRANT SELECT ON public.catalog_ref_acquisition_modes TO anon;
GRANT SELECT ON public.catalog_ref_confidence_levels TO anon;
GRANT SELECT ON public.catalog_ref_import_methods TO anon;
GRANT SELECT ON public.catalog_ref_mutualization_statuses TO anon;
GRANT SELECT ON public.catalog_ref_review_statuses TO anon;
GRANT SELECT ON public.catalog_ref_source_formats TO anon;
GRANT SELECT ON public.catalog_ref_source_partners TO anon;
GRANT SELECT ON public.catalog_ref_source_systems TO anon;
GRANT SELECT ON public.digital_assets TO anon;
GRANT SELECT ON public.emprestimo_itens_v2 TO anon;
GRANT SELECT ON public.exemplares TO anon;
GRANT SELECT ON public.libraries TO anon;
GRANT SELECT ON public.library_circulation_policy_rules TO anon;
GRANT SELECT ON public.library_circulation_policy_sets TO anon;
GRANT SELECT ON public.library_commons TO anon;
GRANT SELECT ON public.library_document_governance TO anon;
GRANT SELECT ON public.library_membership_audit TO anon;
GRANT SELECT ON public.library_membership_rules TO anon;
GRANT SELECT ON public.library_regulation_documents TO anon;
GRANT SELECT ON public.library_retention_policies TO anon;
GRANT SELECT ON public.library_service_state TO anon;
GRANT SELECT ON public.library_theme_configs TO anon;
GRANT SELECT ON public.library_themes TO anon;
GRANT SELECT ON public.membership_payments TO anon;
GRANT SELECT ON public.network_admin_collective_removal_proposals TO anon;
GRANT SELECT ON public.network_admin_collective_removal_votes TO anon;
GRANT SELECT ON public.network_admin_cross_library_actions_log TO anon;
GRANT SELECT ON public.network_administrator_audit TO anon;
GRANT SELECT ON public.network_administrator_cooptation_proposals TO anon;
GRANT SELECT ON public.network_administrator_cooptation_votes TO anon;
GRANT SELECT ON public.network_administrators TO anon;
GRANT SELECT ON public.team_notification_outbox TO anon;

-- Cas particulier : auth_rate_limits, table dédiée au rate-limit anonyme
GRANT SELECT ON public.auth_rate_limits TO anon;

-- -------------------------------------------------------------------------
-- 2. Tables authenticated-only (95 tables au total, 47 + 43 + 5)
-- -------------------------------------------------------------------------
-- Pour ces tables, authenticated a actuellement les 4 opérations. On
-- ré-affirme. RLS filtre ensuite ligne par ligne.

GRANT SELECT, INSERT, UPDATE, DELETE ON public._backup_library_request_claims_20260408 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public._backup_library_request_notification_events_20260408 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public._backup_library_requests_20260408 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.auth_rate_limits TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.author_drafts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.author_name_aliases TO authenticated;
GRANT SELECT                         ON public.author_translations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.authors TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_authors TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_authors_backup_suspect_mono TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_catalog_context TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_contributors TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_digital_resources TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_draft_catalog_context TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_draft_contributors TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_draft_digital_resources TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_draft_import_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_drafts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.book_holdings TO authenticated;
GRANT SELECT                         ON public.books TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_batches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_partner_capabilities TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_partner_probe_runs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_ref_acquisition_modes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_ref_confidence_levels TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_ref_import_methods TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_ref_mutualization_statuses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_ref_review_statuses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_ref_source_formats TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_ref_source_partners TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.catalog_ref_source_systems TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.consulta_item_workflow_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.consulta_linhas_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.consultas_locais_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.digital_assets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_permission_request_notification_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_permission_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.emprestimo_itens_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.emprestimos_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.exemplar_drafts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.exemplares TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.import_blmf_books_rows TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.import_blmf_exemplares_rows TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.import_terra_livre_zotero_staging TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.interlibrary_loan_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.interlibrary_loan_items_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.interlibrary_loan_notification_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.interlibrary_loans_v2 TO authenticated;
GRANT SELECT,         UPDATE         ON public.libraries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_circulation_policy_rules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_circulation_policy_sets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_commons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_contact_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_document_governance TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_email_identity TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_mail_channels TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_membership_audit TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_membership_rules TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_notification_policies TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_notification_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_regulation_documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_request_notification_events TO authenticated;
GRANT SELECT                         ON public.library_requests TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_retention_policies TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_service_state TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_theme_configs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.library_themes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.loan_midpoint_message_log TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.membership_payments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.network_admin_collective_removal_proposals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.network_admin_collective_removal_votes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.network_admin_cross_library_actions_log TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.network_administrator_audit TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.network_administrator_cooptation_proposals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.network_administrator_cooptation_votes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.network_administrators TO authenticated;
GRANT SELECT                         ON public.network_reviewers TO authenticated;
GRANT SELECT                         ON public.network_staff TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.painel_internal_task_invitation_outbox TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.painel_internal_task_invites TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.painel_internal_task_notification_outbox TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.painel_internal_tasks TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reserva_item_workflow_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reserva_linhas_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reservas_v2 TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.team_notification_outbox TO authenticated;
GRANT SELECT                         ON public.user_library_memberships TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_wishlist TO authenticated;

-- -------------------------------------------------------------------------
-- 3. Tables verrouillées (5 tables : aucun accès anon ni authenticated)
-- -------------------------------------------------------------------------
-- Ces tables ne sont pas exposées à PostgREST côté Data API. Toute lecture
-- ou écriture passe par RPC SECURITY DEFINER. On NE GRANT RIEN à anon ni
-- authenticated. On ré-affirme via REVOKE explicite pour figer l'état.

REVOKE ALL ON public.catalog_partners FROM anon, authenticated;
REVOKE ALL ON public.library_request_claims FROM anon, authenticated;
REVOKE ALL ON public.partner_source_holdings FROM anon, authenticated;
REVOKE ALL ON public.partner_source_items FROM anon, authenticated;
REVOKE ALL ON public.partner_source_records FROM anon, authenticated;

-- -------------------------------------------------------------------------
-- 4. service_role conserve tous les droits sur toutes les tables
-- -------------------------------------------------------------------------
-- Standard Supabase. service_role est utilisé par les Edge Functions avec
-- la clé service_role (à ne JAMAIS exposer côté frontend). Bypass RLS.

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

-- -------------------------------------------------------------------------
-- 5. Vérification finale
-- -------------------------------------------------------------------------
-- On compte les tables et leurs grants pour s'assurer qu'on n'a rien
-- raté. Le compte exact peut varier si de nouvelles tables ont été
-- créées entre l'audit (12/05 matin) et l'application de cette migration.

DO $$
DECLARE
  v_n_tables_public int;
  v_n_with_select_anon int;
  v_n_with_select_auth int;
BEGIN
  SELECT count(*) INTO v_n_tables_public
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r';

  SELECT count(*) INTO v_n_with_select_anon
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
    AND has_table_privilege('anon', c.oid, 'SELECT');

  SELECT count(*) INTO v_n_with_select_auth
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r'
    AND has_table_privilege('authenticated', c.oid, 'SELECT');

  RAISE NOTICE 'Paquet L.9 OK : % tables public, % lisibles anon, % lisibles auth',
    v_n_tables_public, v_n_with_select_anon, v_n_with_select_auth;
END $$;

COMMIT;

-- =========================================================================
-- Post-conditions
-- =========================================================================
-- - Aucun changement fonctionnel (paquet idempotent)
-- - GRANT/REVOKE désormais explicites en migration
-- - À partir du 30/10/2026, quand Supabase resserre les defaults : aucun
--   impact sur AnarBib, les permissions restent celles déclarées ici
-- =========================================================================
-- Doctrine pour les FUTURES migrations qui créent des tables :
-- =========================================================================
-- Toute nouvelle CREATE TABLE dans public doit être suivie de GRANT
-- explicites adaptés :
--   - Tables de catalogue public : GRANT SELECT TO anon + GRANT all TO auth
--   - Tables métier privées : GRANT SELECT, INSERT, UPDATE, DELETE TO auth
--   - Tables hors Data API : REVOKE ALL FROM anon, authenticated
-- Et systématiquement : ALTER TABLE ... ENABLE ROW LEVEL SECURITY +
-- policies RLS correspondantes.
-- =========================================================================
