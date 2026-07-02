-- ===========================================================================
-- 20260702160920_fk_support_indexes_8_2.sql
-- ---------------------------------------------------------------------------
-- Point 8.2 GLB v16 : instrumentation des cles etrangeres sans index de support.
-- 136 index btree mono-colonne, un par FK public.* non indexee pointant vers une
-- table reelle (profiles, auth.users, libraries, entites operationnelles). Les 15
-- FK vers catalog_ref_* (tables de codes) sont VOLONTAIREMENT exclues : index de
-- support sans valeur sur des tables de <50 lignes.
--
-- Pourquoi maintenant : les couches civiques/federales sont encore quasi vides
-- (arbitrage GLB ch.11 : instrumenter AVANT l'activation tierce CIRA Marseille).
-- A ce volume, CREATE INDEX simple est instantane et transactionnel (compatible
-- supabase db push) ; pas besoin de CONCURRENTLY. Post-activation, il faudrait
-- CONCURRENTLY (et sortir de transaction).
--
-- Ces FK degradent DELETE/UPDATE en cascade et les jointures d'audit ; en
-- particulier les colonnes d'acteur network_* que fn_delete_my_account (BG2-14)
-- balaye par user_id a l'effacement RGPD : les indexer accelere l'effacement.
--
-- Idempotent (IF NOT EXISTS). Reversible : rollback = DROP INDEX IF EXISTS <nom>
-- pour chacun (memes noms deterministes ix_<table>_<colonne>).
-- Deploiement : commit -> push -> CI Forgejo (supabase db push).
-- ===========================================================================

CREATE INDEX IF NOT EXISTS ix_assembleia_agenda_items_proposed_by ON public.assembleia_agenda_items (proposed_by);
CREATE INDEX IF NOT EXISTS ix_assembleia_facilitators_designated_by ON public.assembleia_facilitators (designated_by);
CREATE INDEX IF NOT EXISTS ix_assembleias_created_by ON public.assembleias (created_by);
CREATE INDEX IF NOT EXISTS ix_audio_tracks_created_by ON public.audio_tracks (created_by);
CREATE INDEX IF NOT EXISTS ix_author_translations_reviewed_by ON public.author_translations (reviewed_by);
CREATE INDEX IF NOT EXISTS ix_authority_proposal_objections_objecting_by ON public.authority_proposal_objections (objecting_by);
CREATE INDEX IF NOT EXISTS ix_authority_proposal_objections_objecting_library_id ON public.authority_proposal_objections (objecting_library_id);
CREATE INDEX IF NOT EXISTS ix_authority_proposals_proposed_by ON public.authority_proposals (proposed_by);
CREATE INDEX IF NOT EXISTS ix_book_catalog_context_source_draft_id ON public.book_catalog_context (source_draft_id);
CREATE INDEX IF NOT EXISTS ix_book_contributors_author_id ON public.book_contributors (author_id);
CREATE INDEX IF NOT EXISTS ix_book_draft_contributors_author_id ON public.book_draft_contributors (author_id);
CREATE INDEX IF NOT EXISTS ix_book_drafts_holder_library_id ON public.book_drafts (holder_library_id);
CREATE INDEX IF NOT EXISTS ix_book_drafts_owner_library_id ON public.book_drafts (owner_library_id);
CREATE INDEX IF NOT EXISTS ix_book_drafts_publisher_id ON public.book_drafts (publisher_id);
CREATE INDEX IF NOT EXISTS ix_book_not_duplicate_book_id_b ON public.book_not_duplicate (book_id_b);
CREATE INDEX IF NOT EXISTS ix_book_not_duplicate_created_by ON public.book_not_duplicate (created_by);
CREATE INDEX IF NOT EXISTS ix_books_holder_library_id ON public.books (holder_library_id);
CREATE INDEX IF NOT EXISTS ix_books_owner_library_id ON public.books (owner_library_id);
CREATE INDEX IF NOT EXISTS ix_books_publisher_id ON public.books (publisher_id);
CREATE INDEX IF NOT EXISTS ix_cartography_entries_updated_by ON public.cartography_entries (updated_by);
CREATE INDEX IF NOT EXISTS ix_cartography_submissions_created_entry_id ON public.cartography_submissions (created_entry_id);
CREATE INDEX IF NOT EXISTS ix_cartography_submissions_reviewed_by ON public.cartography_submissions (reviewed_by);
CREATE INDEX IF NOT EXISTS ix_circle_join_objections_objecting_by ON public.circle_join_objections (objecting_by);
CREATE INDEX IF NOT EXISTS ix_circle_join_objections_objecting_library_id ON public.circle_join_objections (objecting_library_id);
CREATE INDEX IF NOT EXISTS ix_circle_join_requests_library_id ON public.circle_join_requests (library_id);
CREATE INDEX IF NOT EXISTS ix_circle_join_requests_requested_by ON public.circle_join_requests (requested_by);
CREATE INDEX IF NOT EXISTS ix_circle_memberships_requested_by ON public.circle_memberships (requested_by);
CREATE INDEX IF NOT EXISTS ix_circles_created_by ON public.circles (created_by);
CREATE INDEX IF NOT EXISTS ix_document_permission_request_notification_events_triggered_by ON public.document_permission_request_notification_events (triggered_by_user_id);
CREATE INDEX IF NOT EXISTS ix_emprestimo_itens_v2_book_id ON public.emprestimo_itens_v2 (book_id);
CREATE INDEX IF NOT EXISTS ix_emprestimo_itens_v2_reserva_id ON public.emprestimo_itens_v2 (reserva_id);
CREATE INDEX IF NOT EXISTS ix_emprestimo_itens_v2_return_scheduled_by ON public.emprestimo_itens_v2 (return_scheduled_by);
CREATE INDEX IF NOT EXISTS ix_entraide_help_offers_helper_library_id ON public.entraide_help_offers (helper_library_id);
CREATE INDEX IF NOT EXISTS ix_entraide_help_offers_helper_user_id ON public.entraide_help_offers (helper_user_id);
CREATE INDEX IF NOT EXISTS ix_entraide_help_requests_author_library_id ON public.entraide_help_requests (author_library_id);
CREATE INDEX IF NOT EXISTS ix_entraide_help_requests_author_user_id ON public.entraide_help_requests (author_user_id);
CREATE INDEX IF NOT EXISTS ix_fonds_export_runs_created_by ON public.fonds_export_runs (created_by);
CREATE INDEX IF NOT EXISTS ix_fonds_export_runs_target_library_id ON public.fonds_export_runs (target_library_id);
CREATE INDEX IF NOT EXISTS ix_gazette_issue_locales_updated_by ON public.gazette_issue_locales (updated_by);
CREATE INDEX IF NOT EXISTS ix_gazette_submissions_reviewed_by ON public.gazette_submissions (reviewed_by);
CREATE INDEX IF NOT EXISTS ix_ill_digital_share_events_actor ON public.ill_digital_share_events (actor);
CREATE INDEX IF NOT EXISTS ix_ill_digital_share_events_actor_library_id ON public.ill_digital_share_events (actor_library_id);
CREATE INDEX IF NOT EXISTS ix_ill_digital_shares_closed_by ON public.ill_digital_shares (closed_by);
CREATE INDEX IF NOT EXISTS ix_ill_digital_shares_digital_asset_id ON public.ill_digital_shares (digital_asset_id);
CREATE INDEX IF NOT EXISTS ix_ill_digital_shares_partnership_id ON public.ill_digital_shares (partnership_id);
CREATE INDEX IF NOT EXISTS ix_ill_digital_shares_requested_by ON public.ill_digital_shares (requested_by);
CREATE INDEX IF NOT EXISTS ix_ill_digital_shares_responded_by ON public.ill_digital_shares (responded_by);
CREATE INDEX IF NOT EXISTS ix_ill_digital_shares_transmitted_by ON public.ill_digital_shares (transmitted_by);
CREATE INDEX IF NOT EXISTS ix_interlibrary_loan_events_interlibrary_loan_item_id ON public.interlibrary_loan_events (interlibrary_loan_item_id);
CREATE INDEX IF NOT EXISTS ix_interlibrary_loan_items_v2_book_id ON public.interlibrary_loan_items_v2 (book_id);
CREATE INDEX IF NOT EXISTS ix_interlibrary_loans_v2_initiated_by_library_id ON public.interlibrary_loans_v2 (initiated_by_library_id);
CREATE INDEX IF NOT EXISTS ix_lettre_issues_created_by ON public.lettre_issues (created_by);
CREATE INDEX IF NOT EXISTS ix_lettre_issues_sent_by ON public.lettre_issues (sent_by);
CREATE INDEX IF NOT EXISTS ix_library_circulation_policy_sets_regulation_document_id ON public.library_circulation_policy_sets (regulation_document_id);
CREATE INDEX IF NOT EXISTS ix_library_constitution_progress_library_id ON public.library_constitution_progress (library_id);
CREATE INDEX IF NOT EXISTS ix_library_membership_audit_actor_user_id ON public.library_membership_audit (actor_user_id);
CREATE INDEX IF NOT EXISTS ix_library_membership_rules_created_by ON public.library_membership_rules (created_by);
CREATE INDEX IF NOT EXISTS ix_library_opening_hours_updated_by ON public.library_opening_hours (updated_by);
CREATE INDEX IF NOT EXISTS ix_library_partnerships_broken_by ON public.library_partnerships (broken_by);
CREATE INDEX IF NOT EXISTS ix_library_partnerships_created_by ON public.library_partnerships (created_by);
CREATE INDEX IF NOT EXISTS ix_library_partnerships_partner_catalog_id ON public.library_partnerships (partner_catalog_id);
CREATE INDEX IF NOT EXISTS ix_library_partnerships_partner_library_id ON public.library_partnerships (partner_library_id);
CREATE INDEX IF NOT EXISTS ix_library_partnerships_proposed_by ON public.library_partnerships (proposed_by);
CREATE INDEX IF NOT EXISTS ix_library_partnerships_responded_by ON public.library_partnerships (responded_by);
CREATE INDEX IF NOT EXISTS ix_library_profile_history_changed_by ON public.library_profile_history (changed_by);
CREATE INDEX IF NOT EXISTS ix_library_profile_proposals_cancelled_by ON public.library_profile_proposals (cancelled_by);
CREATE INDEX IF NOT EXISTS ix_library_profile_proposals_proposed_by ON public.library_profile_proposals (proposed_by);
CREATE INDEX IF NOT EXISTS ix_library_public_contact_updated_by ON public.library_public_contact (updated_by);
CREATE INDEX IF NOT EXISTS ix_library_request_claims_created_by_user_id ON public.library_request_claims (created_by_user_id);
CREATE INDEX IF NOT EXISTS ix_library_request_claims_used_by_request_id ON public.library_request_claims (used_by_request_id);
CREATE INDEX IF NOT EXISTS ix_library_request_comments_author_admin_id ON public.library_request_comments (author_admin_id);
CREATE INDEX IF NOT EXISTS ix_library_request_comments_request_id ON public.library_request_comments (request_id);
CREATE INDEX IF NOT EXISTS ix_library_request_invitations_initiated_by ON public.library_request_invitations (initiated_by);
CREATE INDEX IF NOT EXISTS ix_library_request_invitations_request_id ON public.library_request_invitations (request_id);
CREATE INDEX IF NOT EXISTS ix_library_request_mandate_transfers_request_id ON public.library_request_mandate_transfers (request_id);
CREATE INDEX IF NOT EXISTS ix_library_request_messages_author_id ON public.library_request_messages (author_id);
CREATE INDEX IF NOT EXISTS ix_library_request_messages_request_id ON public.library_request_messages (request_id);
CREATE INDEX IF NOT EXISTS ix_library_request_notification_events_triggered_by_user_id ON public.library_request_notification_events (triggered_by_user_id);
CREATE INDEX IF NOT EXISTS ix_library_request_votes_voter_admin_id ON public.library_request_votes (voter_admin_id);
CREATE INDEX IF NOT EXISTS ix_library_requests_proposed_by_admin_id ON public.library_requests (proposed_by_admin_id);
CREATE INDEX IF NOT EXISTS ix_library_requests_reviewed_by_user_id ON public.library_requests (reviewed_by_user_id);
CREATE INDEX IF NOT EXISTS ix_library_retention_policies_updated_by ON public.library_retention_policies (updated_by);
CREATE INDEX IF NOT EXISTS ix_library_team_invitation_ratifications_ratifier_user_id ON public.library_team_invitation_ratifications (ratifier_user_id);
CREATE INDEX IF NOT EXISTS ix_library_team_invitations_invited_user_id ON public.library_team_invitations (invited_user_id);
CREATE INDEX IF NOT EXISTS ix_library_team_invitations_proposed_by ON public.library_team_invitations (proposed_by);
CREATE INDEX IF NOT EXISTS ix_library_unarchive_log_unarchived_by ON public.library_unarchive_log (unarchived_by);
CREATE INDEX IF NOT EXISTS ix_loan_deposits_emprestimo_item_id ON public.loan_deposits (emprestimo_item_id);
CREATE INDEX IF NOT EXISTS ix_loan_deposits_recorded_by ON public.loan_deposits (recorded_by);
CREATE INDEX IF NOT EXISTS ix_loan_deposits_refunded_by ON public.loan_deposits (refunded_by);
CREATE INDEX IF NOT EXISTS ix_loan_deposits_rule_id ON public.loan_deposits (rule_id);
CREATE INDEX IF NOT EXISTS ix_loan_midpoint_message_log_emprestimo_id ON public.loan_midpoint_message_log (emprestimo_id);
CREATE INDEX IF NOT EXISTS ix_loan_midpoint_message_log_user_id ON public.loan_midpoint_message_log (user_id);
CREATE INDEX IF NOT EXISTS ix_membership_payments_recorded_by ON public.membership_payments (recorded_by);
CREATE INDEX IF NOT EXISTS ix_membership_payments_rule_id ON public.membership_payments (rule_id);
CREATE INDEX IF NOT EXISTS ix_merge_log_merged_by ON public.merge_log (merged_by);
CREATE INDEX IF NOT EXISTS ix_network_admin_collective_removal_proposals_cancelled_by ON public.network_admin_collective_removal_proposals (cancelled_by);
CREATE INDEX IF NOT EXISTS ix_network_admin_collective_removal_proposals_proposed_by ON public.network_admin_collective_removal_proposals (proposed_by);
CREATE INDEX IF NOT EXISTS ix_network_administrator_audit_actor_user_id ON public.network_administrator_audit (actor_user_id);
CREATE INDEX IF NOT EXISTS ix_network_administrator_audit_target_user_id ON public.network_administrator_audit (target_user_id);
CREATE INDEX IF NOT EXISTS ix_network_administrator_cooptation_proposals_proposed_by ON public.network_administrator_cooptation_proposals (proposed_by);
CREATE INDEX IF NOT EXISTS ix_network_administrator_cooptation_votes_voter_user_id ON public.network_administrator_cooptation_votes (voter_user_id);
CREATE INDEX IF NOT EXISTS ix_network_contributors_sponsored_by ON public.network_contributors (sponsored_by);
CREATE INDEX IF NOT EXISTS ix_network_reviewers_added_by_user_id ON public.network_reviewers (added_by_user_id);
CREATE INDEX IF NOT EXISTS ix_network_staff_added_by_user_id ON public.network_staff (added_by_user_id);
CREATE INDEX IF NOT EXISTS ix_network_staff_updated_by_user_id ON public.network_staff (updated_by_user_id);
CREATE INDEX IF NOT EXISTS ix_oai_opening_requests_admin_decided_by ON public.oai_opening_requests (admin_decided_by);
CREATE INDEX IF NOT EXISTS ix_oai_opening_requests_closed_by ON public.oai_opening_requests (closed_by);
CREATE INDEX IF NOT EXISTS ix_oai_opening_requests_requested_by ON public.oai_opening_requests (requested_by);
CREATE INDEX IF NOT EXISTS ix_oai_opening_votes_library_id ON public.oai_opening_votes (library_id);
CREATE INDEX IF NOT EXISTS ix_oai_opening_votes_voted_by ON public.oai_opening_votes (voted_by);
CREATE INDEX IF NOT EXISTS ix_painel_internal_task_invitation_outbox_invite_id ON public.painel_internal_task_invitation_outbox (invite_id);
CREATE INDEX IF NOT EXISTS ix_painel_internal_task_invitation_outbox_task_id ON public.painel_internal_task_invitation_outbox (task_id);
CREATE INDEX IF NOT EXISTS ix_painel_internal_tasks_created_by ON public.painel_internal_tasks (created_by);
CREATE INDEX IF NOT EXISTS ix_painel_internal_tasks_owner_user_id ON public.painel_internal_tasks (owner_user_id);
CREATE INDEX IF NOT EXISTS ix_painel_internal_tasks_updated_by ON public.painel_internal_tasks (updated_by);
CREATE INDEX IF NOT EXISTS ix_painel_recurring_task_rules_library_id ON public.painel_recurring_task_rules (library_id);
CREATE INDEX IF NOT EXISTS ix_partner_source_holdings_partner_source_record_id ON public.partner_source_holdings (partner_source_record_id);
CREATE INDEX IF NOT EXISTS ix_partner_source_items_partner_source_holding_id ON public.partner_source_items (partner_source_holding_id);
CREATE INDEX IF NOT EXISTS ix_partnership_break_log_broken_by ON public.partnership_break_log (broken_by);
CREATE INDEX IF NOT EXISTS ix_partnership_rights_granted_by ON public.partnership_rights (granted_by);
CREATE INDEX IF NOT EXISTS ix_publishers_created_by ON public.publishers (created_by);
CREATE INDEX IF NOT EXISTS ix_publishers_updated_by ON public.publishers (updated_by);
CREATE INDEX IF NOT EXISTS ix_reader_library_messages_deleted_by ON public.reader_library_messages (deleted_by);
CREATE INDEX IF NOT EXISTS ix_reader_library_messages_staff_archived_by ON public.reader_library_messages (staff_archived_by);
CREATE INDEX IF NOT EXISTS ix_reader_membership_events_membership_id ON public.reader_membership_events (membership_id);
CREATE INDEX IF NOT EXISTS ix_reader_partnership_consent_partnership_id ON public.reader_partnership_consent (partnership_id);
CREATE INDEX IF NOT EXISTS ix_reading_progress_resource_id ON public.reading_progress (resource_id);
CREATE INDEX IF NOT EXISTS ix_reserva_item_workflow_v2_updated_by ON public.reserva_item_workflow_v2 (updated_by);
CREATE INDEX IF NOT EXISTS ix_user_history_retention_preferences_library_id ON public.user_history_retention_preferences (library_id);
CREATE INDEX IF NOT EXISTS ix_user_library_memberships_pending_removal_requested_by ON public.user_library_memberships (pending_removal_requested_by);
CREATE INDEX IF NOT EXISTS ix_user_library_memberships_physically_validated_by_user_id ON public.user_library_memberships (physically_validated_by_user_id);
CREATE INDEX IF NOT EXISTS ix_user_notifications_library_id ON public.user_notifications (library_id);
CREATE INDEX IF NOT EXISTS ix_user_wishlist_book_id ON public.user_wishlist (book_id);
CREATE INDEX IF NOT EXISTS ix_user_wishlist_library_id ON public.user_wishlist (library_id);
CREATE INDEX IF NOT EXISTS ix_works_created_by ON public.works (created_by);
CREATE INDEX IF NOT EXISTS ix_works_primary_author_id ON public.works (primary_author_id);
