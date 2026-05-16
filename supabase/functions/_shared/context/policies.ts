function asBool(v, f) {
  return typeof v === "boolean" ? v : f;
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
  const n = String(event || "").trim();
  if (n.startsWith("aviso_v2_atraso_") || n.startsWith("aviso_atraso_")) return loanOverdueEnabled(ctx);
  return loanReminderEnabled(ctx);
}
export function techAlertsEnabled(ctx) {
  return asBool(ctx?.tech_alerts_enabled, true);
}
export function taskAlertsEnabled(ctx) {
  return asBool(ctx?.task_alerts_enabled, true);
}

// ===== Consultas locais (paquet 26) ==========================================
export function localConsultationEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.local_consultation_enabled, true);
}
export function consultaCriadaEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_criada_enabled, true);
}
export function consultaAgendadaEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_agendada_enabled, true);
}
export function consultaRespostaCreneauEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_resposta_creneau_enabled, true);
}
export function consultaRealizadaEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_realizada_enabled, false);
}
export function consultaCanceladaEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_cancelada_enabled, true);
}
export function consultaExpiradaEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_expirada_enabled, true);
}
export function consultaAdminCopyEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.admin_copy_consultas_enabled, true);
}
export function consultaEmPreparacaoEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_em_preparacao_enabled, true);
}
export function consultaNaoCompareceuEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_nao_compareceu_enabled, true);
}