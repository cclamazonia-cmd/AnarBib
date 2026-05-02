import type { LibraryNotificationContext } from "../core/types.ts";
function asBool(v: unknown, f: boolean) { return typeof v==="boolean"?v:f; }
export function reservationCreatedEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.reservation_created_enabled,true); }
export function reservationStatusEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.reservation_status_enabled,true); }
export function reservationWorkflowEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.reservation_workflow_enabled,true); }
export function loanLifecycleEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.loan_lifecycle_enabled,true); }
export function loanReminderEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.loan_reminders_enabled,true); }
export function loanOverdueEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.loan_overdue_enabled,true); }
export function profileRestrictionEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.profile_restriction_enabled,true); }
export function reservationAdminCopyEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.admin_copy_reservations_enabled,true); }
export function loanAdminCopyEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.admin_copy_loans_enabled,true); }
export function reminderFamilyEnabled(ctx: LibraryNotificationContext|null|undefined, event: string) { const n=String(event||"").trim(); if (n.startsWith("aviso_v2_atraso_")||n.startsWith("aviso_atraso_")) return loanOverdueEnabled(ctx); return loanReminderEnabled(ctx); }
export function techAlertsEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.tech_alerts_enabled,true); }
export function taskAlertsEnabled(ctx?: LibraryNotificationContext|null) { return asBool(ctx?.task_alerts_enabled,true); }
