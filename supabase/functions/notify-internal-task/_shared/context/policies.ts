function asBool(value, fallback) {
  return typeof value === "boolean" ? value : fallback;
}
export function reservationCreatedEnabled(ctx) {
  return asBool(ctx?.reservation_created_enabled, true);
}
export function reservationStatusEnabled(ctx) {
  return asBool(ctx?.reservation_status_enabled, true);
}
export function reservationWorkflowEnabled(ctx) {
  return asBool(ctx?.reservation_workflow_enabled, true);
}
export function loanLifecycleEnabled(ctx) {
  return asBool(ctx?.loan_lifecycle_enabled, true);
}
export function loanReminderEnabled(ctx) {
  return asBool(ctx?.loan_reminders_enabled, true);
}
export function loanOverdueEnabled(ctx) {
  return asBool(ctx?.loan_overdue_enabled, true);
}
export function profileRestrictionEnabled(ctx) {
  return asBool(ctx?.profile_restriction_enabled, true);
}
export function reservationAdminCopyEnabled(ctx) {
  return asBool(ctx?.admin_copy_reservations_enabled, true);
}
export function loanAdminCopyEnabled(ctx) {
  return asBool(ctx?.admin_copy_loans_enabled, true);
}
export function reminderFamilyEnabled(ctx, event) {
  const normalized = String(event || "").trim();
  if (normalized.startsWith("aviso_v2_atraso_") || normalized.startsWith("aviso_atraso_")) {
    return loanOverdueEnabled(ctx);
  }
  return loanReminderEnabled(ctx);
}
export function techAlertsEnabled(ctx) {
  return asBool(ctx?.tech_alerts_enabled, true);
}
export function taskAlertsEnabled(ctx) {
  return asBool(ctx?.task_alerts_enabled, true);
}
