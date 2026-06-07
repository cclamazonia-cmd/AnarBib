import { normalizeLibraryNotificationContext, resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { taskAlertsEnabled } from "../context/policies.ts";
import { fetchInternalTask, fetchInternalTaskOwnerProfile } from "../data/internal-tasks.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, skippedEmailResult } from "../transport/email.ts";
import { firstNameOnly, formatDateBR, isValidEmail } from "../shared/format.ts";
import { normalizeTaskLocale, taskFieldLabel, taskPriorityLabel, taskStatusLabel, taskVariant, tTask } from "../i18n/task-mail-strings.ts";
function ownerTarget(email, profile) {
  const normalized = String(email || "").trim().toLowerCase();
  if (!isValidEmail(normalized)) return null;
  return {
    email: normalized,
    name: firstNameOnly(profile?.first_name || "") || undefined
  };
}
function invitationTarget(email) {
  const normalized = String(email || "").trim().toLowerCase();
  if (!isValidEmail(normalized)) return null;
  return {
    email: normalized
  };
}
// taskStatusLabel / taskPriorityLabel : desormais importes depuis ../i18n/task-mail-strings.ts
// signature (locale, value) -> libelle localise, repli pt-BR.
function taskTagsLabel(tags) {
  if (Array.isArray(tags)) {
    const clean = tags.map((value)=>String(value || "").trim()).filter(Boolean);
    return clean.join(", ");
  }
  return String(tags || "").trim();
}
function payloadTaskToRow(taskId, libraryId, task) {
  const row = task || {};
  const title = String(row.title || "").trim();
  if (!taskId && !title) return null;
  return {
    id: taskId || String(row.id || "").trim(),
    title,
    description: row.description == null ? null : String(row.description),
    priority: String(row.priority || "media").trim() || "media",
    status: String(row.status || "aberta").trim() || "aberta",
    owner: String(row.owner || "").trim(),
    owner_user_id: null,
    due_date: row.due_date == null ? null : String(row.due_date),
    tags: row.tags ?? null,
    created_at: String(row.created_at || "").trim(),
    library_id: libraryId
  };
}
function buildTaskEmail(eventType, task, ownerName, brandTag, locale) {
  const taskTitle = String(task.title || "").trim() || tTask(locale, "untitled");
  const status = taskStatusLabel(locale, String(task.status || "").trim());
  const priority = taskPriorityLabel(locale, String(task.priority || "").trim());
  const due = formatDateBR(task.due_date);
  const tags = taskTagsLabel(task.tags);
  const description = String(task.description || "").trim();
  const variant = taskVariant(locale, eventType === "assigned" ? "assigned" : "reminder");
  return {
    subject: `${variant.subject} — ${brandTag}`,
    title: variant.title,
    greeting: ownerName ? tTask(locale, "greetingNamed", { name: ownerName }) : tTask(locale, "greetingPlain"),
    introHtml: variant.introHtml,
    details: [
      {
        label: taskFieldLabel(locale, "tarefa"),
        value: taskTitle
      },
      {
        label: taskFieldLabel(locale, "prioridade"),
        value: priority
      },
      {
        label: taskFieldLabel(locale, "situacao"),
        value: status
      },
      ...due ? [
        {
          label: taskFieldLabel(locale, "prazo"),
          value: due
        }
      ] : [],
      ...tags ? [
        {
          label: taskFieldLabel(locale, "marcadores"),
          value: tags
        }
      ] : [],
      ...description ? [
        {
          label: taskFieldLabel(locale, "descricao"),
          value: description
        }
      ] : []
    ]
  };
}
function ensureEmailDelivered(result, contextLabel) {
  if (result.ok || result.skipped) return result;
  const detail = String(result.error || result.reason || "email_send_failed").trim() || "email_send_failed";
  throw new Error(`${contextLabel}:${detail}`);
}
function changedFieldLabels(changedFields, locale) {
  const values = Array.isArray(changedFields) ? changedFields : [];
  const map = {
    due_date: taskFieldLabel(locale, "prazo"),
    priority: taskFieldLabel(locale, "prioridade"),
    status: taskFieldLabel(locale, "situacao"),
    owner: taskFieldLabel(locale, "organizacao")
  };
  return values.map((value)=>String(value || "").trim()).filter(Boolean).map((value)=>map[value] || value);
}
function buildTaskLevelNoticeEmail(recipientRole, eventKind, task, brandTag, changedFields, locale) {
  const taskTitle = String(task.title || "").trim() || tTask(locale, "untitled");
  const status = taskStatusLabel(locale, String(task.status || "").trim());
  const priority = taskPriorityLabel(locale, String(task.priority || "").trim());
  const due = formatDateBR(task.due_date);
  const owner = String(task.owner || "").trim();
  const tags = taskTagsLabel(task.tags);
  const description = String(task.description || "").trim();
  const changed = changedFieldLabels(changedFields, locale);
  let variantKey;
  if (recipientRole === "organizer") {
    variantKey = eventKind === "task_created" ? "orgCreated" : "orgUpdated";
  } else {
    variantKey = eventKind === "task_created" ? "libCreated" : "libUpdated";
  }
  const variant = taskVariant(locale, variantKey);
  return {
    subject: `${variant.subject} — ${brandTag}`,
    title: variant.title,
    greeting: tTask(locale, "greetingPlain"),
    introHtml: variant.introHtml,
    details: [
      {
        label: taskFieldLabel(locale, "tarefa"),
        value: taskTitle
      },
      {
        label: taskFieldLabel(locale, "prioridade"),
        value: priority
      },
      {
        label: taskFieldLabel(locale, "situacao"),
        value: status
      },
      ...owner ? [
        {
          label: taskFieldLabel(locale, "organizacao"),
          value: owner
        }
      ] : [],
      ...due ? [
        {
          label: taskFieldLabel(locale, "prazo"),
          value: due
        }
      ] : [],
      ...changed.length ? [
        {
          label: taskFieldLabel(locale, "mudancas"),
          value: changed.join(", ")
        }
      ] : [],
      ...tags ? [
        {
          label: taskFieldLabel(locale, "marcadores"),
          value: tags
        }
      ] : [],
      ...description ? [
        {
          label: taskFieldLabel(locale, "descricao"),
          value: description
        }
      ] : []
    ]
  };
}
async function handleTaskLevelNotice(payload, taskId, recipientRole) {
  const recipientEmail = String(payload.recipient_email || "").trim().toLowerCase();
  const eventKind = String(payload.event_kind || "task_created").trim() === "task_updated" ? "task_updated" : "task_created";
  const changedFields = Array.isArray(payload.changed_fields) ? payload.changed_fields : [];
  if (!isValidEmail(recipientEmail)) {
    return {
      ok: true,
      skipped: "recipient_email_invalid",
      kind: recipientRole === "library" ? "task_library_notice" : "task_owner_notice",
      task_id: taskId || null,
      recipient_email: recipientEmail || null,
      recipient_role: recipientRole,
      event_kind: eventKind
    };
  }
  let task = taskId ? await fetchInternalTask(taskId) : null;
  const payloadLibraryId = String(payload.library_id || "").trim() || null;
  if (!task) {
    task = payloadTaskToRow(taskId, payloadLibraryId, payload.task || null);
  }
  if (!task) {
    return {
      ok: true,
      skipped: "task_not_found",
      kind: recipientRole === "library" ? "task_library_notice" : "task_owner_notice",
      task_id: taskId || null,
      recipient_email: recipientEmail,
      recipient_role: recipientRole,
      event_kind: eventKind
    };
  }
  const libraryId = payloadLibraryId || String(task.library_id || "").trim() || null;
  const notificationContext = payload.notification_context && typeof payload.notification_context === "object" ? normalizeLibraryNotificationContext(payload.notification_context, libraryId) : await resolveLibraryNotificationContext(libraryId);
  const ownerProfile = recipientRole === "organizer" ? await fetchInternalTaskOwnerProfile(recipientEmail) : null;
  // Locale = langue d'affichage du/de la responsable (organizer) si connue,
  // sinon langue de la biblio. L'avis "library" (canal admin) reste en langue biblio.
  const locale = normalizeTaskLocale((recipientRole === "organizer" ? ownerProfile?.preferred_language : null) || notificationContext.default_locale);
  const target = recipientRole === "organizer" ? ownerTarget(recipientEmail, ownerProfile) || invitationTarget(recipientEmail) : invitationTarget(recipientEmail);
  const brandTag = subjectTag(notificationContext);
  const email = buildTaskLevelNoticeEmail(recipientRole, eventKind, task, brandTag, changedFields, locale);
  const { html, text } = renderEmail({
    preheader: email.title,
    title: email.title,
    greeting: email.greeting,
    introHtml: email.introHtml,
    details: email.details,
    footerHtml: footerPadrao(notificationContext),
    context: notificationContext
  });
  const brandedSubject = applyBrandingText(email.subject, notificationContext);
  const label = recipientRole === "library" ? "task_library_notice" : "task_owner_notice";
  const result = taskAlertsEnabled(notificationContext) ? await safeSendEmail(target, brandedSubject, html, text, label, notificationContext) : skippedEmailResult(label, "task_alerts_disabled", recipientEmail);
  ensureEmailDelivered(result, `${label}_failed`);
  return {
    ok: result.ok,
    sent: result.ok,
    skipped: result.skipped ? result.reason || "skipped" : undefined,
    kind: label,
    task_id: task.id,
    recipient_email: recipientEmail,
    recipient_role: recipientRole,
    event_kind: eventKind,
    changed_fields: changedFields,
    detail: result.error
  };
}
function buildTaskInvitationEmail(task, brandTag, locale) {
  const taskTitle = String(task.title || "").trim() || tTask(locale, "untitled");
  const status = taskStatusLabel(locale, String(task.status || "").trim());
  const priority = taskPriorityLabel(locale, String(task.priority || "").trim());
  const due = formatDateBR(task.due_date);
  const owner = String(task.owner || "").trim();
  const tags = taskTagsLabel(task.tags);
  const description = String(task.description || "").trim();
  const variant = taskVariant(locale, "invitation");
  return {
    subject: `${variant.subject} — ${brandTag}`,
    title: variant.title,
    greeting: tTask(locale, "greetingPlain"),
    introHtml: variant.introHtml,
    details: [
      {
        label: taskFieldLabel(locale, "tarefa"),
        value: taskTitle
      },
      {
        label: taskFieldLabel(locale, "prioridade"),
        value: priority
      },
      {
        label: taskFieldLabel(locale, "situacao"),
        value: status
      },
      ...owner ? [
        {
          label: taskFieldLabel(locale, "organizacao"),
          value: owner
        }
      ] : [],
      ...due ? [
        {
          label: taskFieldLabel(locale, "prazo"),
          value: due
        }
      ] : [],
      ...tags ? [
        {
          label: taskFieldLabel(locale, "marcadores"),
          value: tags
        }
      ] : [],
      ...description ? [
        {
          label: taskFieldLabel(locale, "descricao"),
          value: description
        }
      ] : []
    ]
  };
}
async function handleTaskInvitation(payload, taskId) {
  const inviteId = payload.invite_id == null ? null : String(payload.invite_id).trim() || null;
  const recipientEmail = String(payload.recipient_email || "").trim().toLowerCase();
  if (!isValidEmail(recipientEmail)) {
    return {
      ok: true,
      skipped: "recipient_email_invalid",
      kind: "task_invitation",
      invite_id: inviteId,
      task_id: taskId || null,
      recipient_email: recipientEmail || null
    };
  }
  let task = taskId ? await fetchInternalTask(taskId) : null;
  const payloadLibraryId = String(payload.library_id || "").trim() || null;
  if (!task) {
    task = payloadTaskToRow(taskId, payloadLibraryId, payload.task || null);
  }
  if (!task) {
    return {
      ok: true,
      skipped: "task_not_found",
      kind: "task_invitation",
      invite_id: inviteId,
      task_id: taskId || null,
      recipient_email: recipientEmail
    };
  }
  if ([
    "concluida",
    "cancelada",
    "arquivada"
  ].includes(String(task.status || "").trim())) {
    return {
      ok: true,
      skipped: "task_not_active",
      kind: "task_invitation",
      invite_id: inviteId,
      task_id: task.id,
      recipient_email: recipientEmail
    };
  }
  const libraryId = payloadLibraryId || String(task.library_id || "").trim() || null;
  const notificationContext = payload.notification_context && typeof payload.notification_context === "object" ? normalizeLibraryNotificationContext(payload.notification_context, libraryId) : await resolveLibraryNotificationContext(libraryId);
  const locale = normalizeTaskLocale(notificationContext.default_locale);
  const target = invitationTarget(recipientEmail);
  const brandTag = subjectTag(notificationContext);
  const email = buildTaskInvitationEmail(task, brandTag, locale);
  const { html, text } = renderEmail({
    preheader: email.title,
    title: email.title,
    greeting: email.greeting,
    introHtml: email.introHtml,
    details: email.details,
    footerHtml: footerPadrao(notificationContext),
    context: notificationContext
  });
  const brandedSubject = applyBrandingText(email.subject, notificationContext);
  const result = taskAlertsEnabled(notificationContext) ? await safeSendEmail(target, brandedSubject, html, text, "task_invitation", notificationContext) : skippedEmailResult("task_invitation", "task_alerts_disabled", recipientEmail);
  ensureEmailDelivered(result, "task_invitation_email_failed");
  return {
    ok: result.ok,
    sent: result.ok,
    skipped: result.skipped ? result.reason || "skipped" : undefined,
    kind: "task_invitation",
    invite_id: inviteId,
    task_id: task.id,
    recipient_email: recipientEmail,
    detail: result.error
  };
}
export async function handleInternalTaskNotification(payload) {
  const taskId = String(payload.task_id || payload.id || "").trim();
  const kind = String(payload.kind || "").trim();
  if (kind === "task_invitation") {
    return await handleTaskInvitation(payload, taskId);
  }
  if (kind === "task_owner_notice") {
    return await handleTaskLevelNotice(payload, taskId, "organizer");
  }
  if (kind === "task_library_notice") {
    return await handleTaskLevelNotice(payload, taskId, "library");
  }
  const requestedEvent = String(payload.event_type || payload.event || "assigned").trim();
  const eventType = requestedEvent === "due_today" ? "due_today" : "assigned";
  if (!taskId) throw new Error("task_id_missing");
  const task = await fetchInternalTask(taskId);
  if (!task) {
    return {
      ok: true,
      skipped: "task_not_found",
      task_id: taskId,
      event_type: eventType
    };
  }
  if ([
    "concluida",
    "cancelada"
  ].includes(String(task.status || "").trim())) {
    return {
      ok: true,
      skipped: "task_not_active",
      task_id: taskId,
      event_type: eventType
    };
  }
  const ownerEmail = String(payload.owner_email || "").trim().toLowerCase();
  if (!isValidEmail(ownerEmail)) {
    return {
      ok: true,
      skipped: "owner_email_invalid",
      task_id: taskId,
      event_type: eventType,
      owner_email: ownerEmail || null
    };
  }
  const ownerProfile = await fetchInternalTaskOwnerProfile(ownerEmail);
  if (!ownerProfile || ownerProfile.is_librarian !== true) {
    return {
      ok: true,
      skipped: "owner_not_librarian",
      task_id: taskId,
      event_type: eventType,
      owner_email: ownerEmail
    };
  }
  const ctx = await resolveLibraryNotificationContext(String(task.library_id || "").trim() || null);
  // Locale = langue d'affichage du/de la responsable (owner), repli langue biblio.
  const locale = normalizeTaskLocale(ownerProfile.preferred_language || ctx.default_locale);
  const target = ownerTarget(ownerEmail, ownerProfile);
  const ownerName = firstNameOnly(ownerProfile.first_name || "") || tTask(locale, "fallbackName");
  const brandTag = subjectTag(ctx);
  const email = buildTaskEmail(eventType, task, ownerName, brandTag, locale);
  const { html, text } = renderEmail({
    preheader: email.title,
    title: email.title,
    greeting: email.greeting,
    introHtml: email.introHtml,
    details: email.details,
    footerHtml: footerPadrao(ctx),
    context: ctx
  });
  const brandedSubject = applyBrandingText(email.subject, ctx);
  const result = taskAlertsEnabled(ctx) ? await safeSendEmail(target, brandedSubject, html, text, "task_owner", ctx) : skippedEmailResult("task_owner", "task_alerts_disabled", ownerEmail);
  ensureEmailDelivered(result, "task_owner_email_failed");
  return {
    ok: result.ok,
    sent: result.ok,
    skipped: result.skipped ? result.reason || "skipped" : undefined,
    task_id: taskId,
    event_type: eventType,
    owner_email: ownerEmail,
    detail: result.error
  };
}
