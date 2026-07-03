-- Matérialise des policies deny-all EXPLICITES sur les tables PII / secret (Scénario C).
-- Neutre en comportement : service_role et SECURITY DEFINER (owner) contournent la RLS ;
-- anon/authenticated étaient déjà en deny-all (RLS on, 0 policy). On rend ce deny
-- explicite via une policy RESTRICTIVE USING(false) : à l'épreuve d'un futur ajout
-- accidentel de policy permissive, et fait taire l'advisor 0008 sur ces tables sensibles.
-- Cf. docs/journal/audits/MATRICE_rls_deny_all_2026-06-23.md (mise à jour 2026-07-03).
do $$
declare
  t text;
  pii_tables text[] := array[
    'auth_rate_limits',
    'authority_proposal_notification_outbox',
    'cartography_entries',
    'cartography_submission_notification_outbox',
    'cartography_submissions',
    'gazette_submission_notification_outbox',
    'interlibrary_loan_notification_events',
    'lettre_consent_tokens',
    'lettre_notification_outbox',
    'library_email_identity',
    'library_request_claims',
    'library_request_notification_events',
    'loan_midpoint_message_log',
    'membership_expiry_notifications',
    'user_history_retention_preferences'
  ];
begin
  foreach t in array pii_tables loop
    execute format('drop policy if exists deny_direct_access_secdef_only on public.%I', t);
    execute format(
      'create policy deny_direct_access_secdef_only on public.%I '
      'as restrictive for all to anon, authenticated '
      'using (false) with check (false)', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;
