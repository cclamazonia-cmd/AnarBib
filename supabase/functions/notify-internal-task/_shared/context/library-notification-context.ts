import { ADMIN_EMAIL, ADMIN_NAME, BRAND_NAME, FOOTER_TEXT, LOGO_URL, SENDER_EMAIL, SENDER_NAME, supabaseAdmin } from "../core/env.ts";
function asBool(value, fallback) {
  return typeof value === "boolean" ? value : fallback;
}
export function fallbackLibraryNotificationContext(libraryId) {
  return {
    library_id: libraryId || null,
    slug: null,
    library_name: BRAND_NAME,
    library_short_name: String(BRAND_NAME || "AnarBib").trim() || "AnarBib",
    sender_display_name: SENDER_NAME,
    reply_to_name: ADMIN_NAME || SENDER_NAME,
    reply_to_email: ADMIN_EMAIL || null,
    signature_short: ADMIN_NAME || null,
    footer_local: FOOTER_TEXT,
    use_library_name_as_sender: true,
    use_library_logo: true,
    logo_url: LOGO_URL || null,
    logo_file_key: null,
    sender_visible_email: SENDER_EMAIL,
    reservation_created_enabled: true,
    reservation_status_enabled: true,
    reservation_workflow_enabled: true,
    local_consultation_enabled: true,
    loan_lifecycle_enabled: true,
    loan_reminders_enabled: true,
    loan_overdue_enabled: true,
    profile_restriction_enabled: true,
    mid_loan_message_enabled: false,
    reading_recommendations_enabled: false,
    admin_copy_reservations_enabled: true,
    admin_copy_loans_enabled: true,
    tech_alerts_enabled: true,
    task_alerts_enabled: true,
    delivery_mode: "platform_shared",
    admin_notification_email: ADMIN_EMAIL || null,
    weekly_report_email: ADMIN_EMAIL || null,
    severe_alert_email: ADMIN_EMAIL || null,
    transport_state: null,
    transport_channel: "platform_shared",
    last_tested_at: null,
    channel_active: true
  };
}
export function normalizeLibraryNotificationContext(input, libraryId) {
  const base = fallbackLibraryNotificationContext(libraryId);
  const row = input || {};
  return {
    ...base,
    ...row,
    library_id: String(row.library_id || base.library_id || "").trim() || null,
    slug: String(row.slug || base.slug || "").trim() || null,
    library_name: String(row.library_name || base.library_name || "").trim() || base.library_name,
    library_short_name: String(row.library_short_name || base.library_short_name || "").trim() || base.library_short_name,
    sender_display_name: String(row.sender_display_name || base.sender_display_name || "").trim() || null,
    reply_to_name: String(row.reply_to_name || base.reply_to_name || "").trim() || null,
    reply_to_email: String(row.reply_to_email || base.reply_to_email || "").trim() || null,
    signature_short: String(row.signature_short || base.signature_short || "").trim() || null,
    footer_local: String(row.footer_local || base.footer_local || "").trim() || null,
    use_library_name_as_sender: asBool(row.use_library_name_as_sender, true),
    use_library_logo: asBool(row.use_library_logo, true),
    logo_url: String(row.logo_url || base.logo_url || "").trim() || null,
    logo_file_key: String(row.logo_file_key || base.logo_file_key || "").trim() || null,
    sender_visible_email: String(row.sender_visible_email || base.sender_visible_email || "").trim() || null,
    reservation_created_enabled: asBool(row.reservation_created_enabled, true),
    reservation_status_enabled: asBool(row.reservation_status_enabled, true),
    reservation_workflow_enabled: asBool(row.reservation_workflow_enabled, true),
    local_consultation_enabled: asBool(row.local_consultation_enabled, true),
    loan_lifecycle_enabled: asBool(row.loan_lifecycle_enabled, true),
    loan_reminders_enabled: asBool(row.loan_reminders_enabled, true),
    loan_overdue_enabled: asBool(row.loan_overdue_enabled, true),
    profile_restriction_enabled: asBool(row.profile_restriction_enabled, true),
    mid_loan_message_enabled: asBool(row.mid_loan_message_enabled, false),
    reading_recommendations_enabled: asBool(row.reading_recommendations_enabled, false),
    admin_copy_reservations_enabled: asBool(row.admin_copy_reservations_enabled, true),
    admin_copy_loans_enabled: asBool(row.admin_copy_loans_enabled, true),
    tech_alerts_enabled: asBool(row.tech_alerts_enabled, true),
    task_alerts_enabled: asBool(row.task_alerts_enabled, true),
    delivery_mode: String(row.delivery_mode || base.delivery_mode || "platform_shared").trim() || "platform_shared",
    admin_notification_email: String(row.admin_notification_email || base.admin_notification_email || "").trim() || null,
    weekly_report_email: String(row.weekly_report_email || base.weekly_report_email || "").trim() || null,
    severe_alert_email: String(row.severe_alert_email || base.severe_alert_email || "").trim() || null,
    transport_state: String(row.transport_state || base.transport_state || "").trim() || null,
    transport_channel: String(row.transport_channel || row.delivery_mode || base.transport_channel || "platform_shared").trim() || "platform_shared",
    last_tested_at: String(row.last_tested_at || base.last_tested_at || "").trim() || null,
    channel_active: asBool(row.channel_active, true)
  };
}
export async function resolveLibraryNotificationContext(libraryId) {
  const normalizedId = String(libraryId || "").trim();
  if (!normalizedId) {
    return fallbackLibraryNotificationContext(null);
  }
  try {
    const { data, error } = await supabaseAdmin.from("v_library_notification_context").select("*").eq("library_id", normalizedId).maybeSingle();
    if (error) throw error;
    return normalizeLibraryNotificationContext(data || null, normalizedId);
  } catch (error) {
    console.warn("resolveLibraryNotificationContext fallback:", error);
    return fallbackLibraryNotificationContext(normalizedId);
  }
}
