-- Perf : advisor 0006 multiple_permissive_policies — lot 3 (tables staff/admin, froides).
-- Sémantique strictement préservée (api.my_access est limité à l'appelant·e : une ligne).
-- Idempotent. Clôt le 0006. Cf. lots 1 (…235900) et 2 (…000100).

-- ═══ A. SELECT redondant (cond SELECT == cond de la policy ALL) → drop le SELECT.
--        La policy ALL couvre déjà le SELECT avec la même condition.
drop policy if exists library_mail_channels_select on public.library_mail_channels;
drop policy if exists library_notification_policies_select on public.library_notification_policies;
drop policy if exists library_notification_profiles_select on public.library_notification_profiles;
drop policy if exists gazette_sources_read_network_staff on public.gazette_sources;

-- ═══ B. catalog_batches : la policy ALL == les 4 policies par commande → drop l'ALL.
drop policy if exists catalog_batches_catalogacao_librarian_all on public.catalog_batches;

-- ═══ C. « no_direct_write » = policy PERMISSIVE `false` (no-op : ne refuse rien de
--        plus que le deny-par-défaut, mais crée un chevauchement SELECT) → drop.
--        Écritures restent refusées (aucune policy permissive d'écriture) ; SELECT inchangé.
drop policy if exists rls_crp_no_direct_write on public.network_admin_collective_removal_proposals;
drop policy if exists rls_crv_no_direct_write on public.network_admin_collective_removal_votes;

-- ═══ D. Deux policies SELECT sans ALL → fusion en OR.
drop policy if exists library_requests_admin_read on public.library_requests;
drop policy if exists library_requests_select_own on public.library_requests;
drop policy if exists library_requests_select on public.library_requests;
create policy library_requests_select on public.library_requests
  for select to authenticated
  using (public.fn_caller_is_network_admin() or (submitted_by_user_id = (select auth.uid())));

drop policy if exists cross_lib_log_select_local_staff on public.network_admin_cross_library_actions_log;
drop policy if exists cross_lib_log_select_network_admins on public.network_admin_cross_library_actions_log;
drop policy if exists cross_lib_log_select on public.network_admin_cross_library_actions_log;
create policy cross_lib_log_select on public.network_admin_cross_library_actions_log
  for select to authenticated
  using (public.user_can_act_as_staff_on_library(library_id) or public.fn_caller_is_network_admin());

-- ═══ E. Deux policies INSERT → fusion des WITH CHECK en OR.
drop policy if exists reader_library_messages_insert_library on public.reader_library_messages;
drop policy if exists reader_library_messages_insert_reader on public.reader_library_messages;
drop policy if exists reader_library_messages_insert on public.reader_library_messages;
create policy reader_library_messages_insert on public.reader_library_messages
  for insert to authenticated
  with check (
    ((direction = 'library'::text) and (sender_id = (select auth.uid())) and (recipient_id is not null)
     and public.user_has_library_staff_role((select auth.uid()), library_id)
     and exists (select 1 from public.user_library_memberships m
                 where m.library_id = reader_library_messages.library_id
                   and m.user_id = reader_library_messages.recipient_id and m.status = 'active'::text))
    or
    ((direction = 'reader'::text) and (sender_id = (select auth.uid()))
     and exists (select 1 from public.user_library_memberships m
                 where m.library_id = reader_library_messages.library_id
                   and m.user_id = (select auth.uid()) and m.status = 'active'::text))
  );

-- ═══ F. Policy ALL (gestion) qui déborde sur un SELECT plus large → scinder l'ALL
--        en INSERT/UPDATE/DELETE (même cond de gestion) + un SELECT fusionné (OR).
--        Chevauchement uniquement sur SELECT ; écritures inchangées.

-- library_membership_rules : gestion = user_can_engage_library ; lecture = membre actif.
drop policy if exists lmr_modify on public.library_membership_rules;
drop policy if exists lmr_select on public.library_membership_rules;
create policy lmr_select on public.library_membership_rules
  for select to authenticated
  using (
    (exists (select 1 from public.user_library_memberships m
             where m.user_id = (select auth.uid()) and m.library_id = library_membership_rules.library_id
               and m.status = 'active'::text))
    or public.user_can_engage_library(library_id)
  );
create policy lmr_insert on public.library_membership_rules for insert to authenticated
  with check (public.user_can_engage_library(library_id));
create policy lmr_update on public.library_membership_rules for update to authenticated
  using (public.user_can_engage_library(library_id)) with check (public.user_can_engage_library(library_id));
create policy lmr_delete on public.library_membership_rules for delete to authenticated
  using (public.user_can_engage_library(library_id));

-- library_retention_policies : gestion = engage ; lecture = staff de la biblio.
drop policy if exists lrp_modify_management on public.library_retention_policies;
drop policy if exists lrp_select_staff on public.library_retention_policies;
create policy lrp_select_staff on public.library_retention_policies
  for select to authenticated
  using (public.user_can_act_as_staff_on_library(library_id) or public.user_can_engage_library(library_id));
create policy lrp_insert on public.library_retention_policies for insert to authenticated
  with check (public.user_can_engage_library(library_id));
create policy lrp_update on public.library_retention_policies for update to authenticated
  using (public.user_can_engage_library(library_id)) with check (public.user_can_engage_library(library_id));
create policy lrp_delete on public.library_retention_policies for delete to authenticated
  using (public.user_can_engage_library(library_id));

-- loan_deposits : gestion = engage ; lecture = mien OU staff (engage).
drop policy if exists loan_deposits_modify_staff on public.loan_deposits;
drop policy if exists loan_deposits_select_own on public.loan_deposits;
drop policy if exists loan_deposits_select_staff on public.loan_deposits;
create policy loan_deposits_select on public.loan_deposits
  for select to authenticated
  using ((user_id = (select auth.uid())) or public.user_can_engage_library(library_id));
create policy loan_deposits_insert on public.loan_deposits for insert to authenticated
  with check (public.user_can_engage_library(library_id));
create policy loan_deposits_update on public.loan_deposits for update to authenticated
  using (public.user_can_engage_library(library_id)) with check (public.user_can_engage_library(library_id));
create policy loan_deposits_delete on public.loan_deposits for delete to authenticated
  using (public.user_can_engage_library(library_id));

-- membership_payments : gestion = engage ; lecture = mien OU staff (engage).
drop policy if exists mp_modify_staff on public.membership_payments;
drop policy if exists mp_select_own on public.membership_payments;
drop policy if exists mp_select_staff on public.membership_payments;
create policy mp_select on public.membership_payments
  for select to authenticated
  using ((user_id = (select auth.uid())) or public.user_can_engage_library(library_id));
create policy mp_insert on public.membership_payments for insert to authenticated
  with check (public.user_can_engage_library(library_id));
create policy mp_update on public.membership_payments for update to authenticated
  using (public.user_can_engage_library(library_id)) with check (public.user_can_engage_library(library_id));
create policy mp_delete on public.membership_payments for delete to authenticated
  using (public.user_can_engage_library(library_id));
