import { getReservaDetalhes } from "../data/reservas.ts";
import { getEmprestimoDetalhes } from "../data/emprestimos.ts";
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { reservationCreatedEnabled, reservationAdminCopyEnabled, loanLifecycleEnabled, loanAdminCopyEnabled, reminderFamilyEnabled } from "../context/policies.ts";
import { adminDisplayName, esc, firstNameOnly, formatDateBR, fullNameFromParts } from "../shared/format.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, sendAdminNotification, skippedEmailResult } from "../transport/email.ts";
import type { EmailSendResult, EmailTarget } from "../core/types.ts";
import { LIBRARIAN_PHONE } from "../core/env.ts";

export async function handleReservaCriadaOld(recordId: number) {
  const r = await getReservaDetalhes(recordId);
  const ctx = await resolveLibraryNotificationContext(String(r.library_id || r.default_library_id || "").trim() || null);
  const brandTag = subjectTag(ctx);
  const userFullName = fullNameFromParts(r.first_name, r.last_name);
  const user: EmailTarget = { email: String(r.user_email || r.email || "").trim(), name: firstNameOnly(r.first_name) || firstNameOnly(userFullName) || undefined };
  const adminUserName = adminDisplayName(userFullName, user.email);
  const titulo = String(r.titulo || "Livro").trim();
  const bibRef = String(r.bib_ref || "").trim();
  const reservaEm = String(r.reserva_em || "");
  const subjectUser = bibRef ? `Reserva recebida — ${bibRef} — ${brandTag}` : `Reserva recebida — ${brandTag}`;
  const { html, text } = renderEmail({ preheader: "Sua reserva foi registrada.", title: "Reserva recebida", greeting: user.name ? `Olá, ${user.name}!` : "Olá!",
    introHtml: `<p style="margin:0 0 10px;">Recebemos sua <b>reserva</b>. Em breve a biblioteca confirmará a disponibilidade.</p>${LIBRARIAN_PHONE ? `<p style="margin:0 0 10px;">Contato: <b>${esc(LIBRARIAN_PHONE)}</b>.</p>` : ""}<p style="margin:0;">Guarde esta mensagem.</p>`,
    details: [{ label: "Livro", value: titulo }, ...(bibRef ? [{ label: "Referência", value: bibRef }] : []), ...(reservaEm ? [{ label: "Data", value: formatDateBR(reservaEm) }] : [])],
    footerHtml: footerPadrao(ctx), context: ctx });
  const userResult = reservationCreatedEnabled(ctx) ? await safeSendEmail(user, applyBrandingText(subjectUser, ctx), html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "reservation_created_disabled");
  const { html: ha, text: ta } = renderEmail({ preheader: "Nova reserva registrada.", title: "Nova reserva registrada", introHtml: `<p style="margin:0;">Uma nova reserva foi registrada (sistema antigo).</p>`,
    details: [{ label: "Leitor(a/e)", value: adminUserName }, { label: "Livro", value: titulo }, ...(bibRef ? [{ label: "Referência", value: bibRef }] : [])], footerHtml: footerPadrao(ctx), context: ctx });
  const adminResult = reservationCreatedEnabled(ctx) && reservationAdminCopyEnabled(ctx) ? await safeSendEmail(adminTarget(ctx), applyBrandingText(`Nova reserva — ${adminUserName} — ${brandTag}`, ctx), ha, ta, "admin_copy", ctx) : skippedEmailResult("admin_copy", "reservation_admin_copy_disabled");
  return { user_result: userResult, admin_result: adminResult };
}

export async function handleEmprestimoOld(recordId: number, event: string) {
  const e = await getEmprestimoDetalhes(recordId);
  const ctx = await resolveLibraryNotificationContext(String(e.library_id || e.default_library_id || "").trim() || null);
  const brandTag = subjectTag(ctx);
  const userFullName = String(e.user_nome || e.nome || "").trim();
  const user: EmailTarget = { email: String(e.user_email || e.email || "").trim(), name: firstNameOnly(userFullName) || undefined };
  const adminUserName = adminDisplayName(userFullName, user.email);
  const titulo = String(e.titulo || e.book_title || "Livro").trim();
  const bibRef = String(e.bib_ref || e.bibref || "").trim();
  const dueDate = e.due_date ? String(e.due_date) : "";
  let subject = brandTag, title = "Notificação", introHtml = "<p>Atualização da biblioteca.</p>";
  if (event === "emprestimo_criado") { subject = `Empréstimo registrado — ${brandTag}`; title = "Empréstimo registrado"; introHtml = `<p style="margin:0 0 10px;">Seu <b>empréstimo</b> foi registrado.</p>${dueDate ? `<p style="margin:0;">Devolução prevista: <b>${esc(formatDateBR(dueDate))}</b>.</p>` : ""}`; }
  else if (event === "emprestimo_prorrogado") { subject = `Prorrogação confirmada — ${brandTag}`; title = "Prorrogação confirmada"; introHtml = `<p>Sua <b>prorrogação</b> foi confirmada.</p>${dueDate ? `<p>Nova devolução: <b>${esc(formatDateBR(dueDate))}</b>.</p>` : ""}`; }
  else if (event === "emprestimo_devolvido") { subject = `Devolução registrada — ${brandTag}`; title = "Devolução registrada"; introHtml = `<p>Registramos a <b>devolução</b>. Obrigado!</p>`; }
  else if (event.startsWith("lembrete_") || event.startsWith("aviso_")) { subject = `${title = event.includes("atraso") ? "Aviso de atraso" : "Lembrete de devolução"} — ${brandTag}`; introHtml = `<p>Atualização sobre seu empréstimo.</p>`; }
  const { html, text } = renderEmail({ preheader: title, title, greeting: user.name ? `Olá, ${user.name}!` : "Olá!", introHtml,
    details: [{ label: "Livro", value: titulo }, ...(bibRef ? [{ label: "Referência", value: bibRef }] : []), ...(dueDate ? [{ label: "Devolução prevista", value: formatDateBR(dueDate) }] : [])],
    footerHtml: footerPadrao(ctx), context: ctx });
  subject = applyBrandingText(subject, ctx);
  const isLifecycle = ["emprestimo_criado","emprestimo_prorrogado","emprestimo_devolvido"].includes(event);
  const userResult = isLifecycle ? (loanLifecycleEnabled(ctx) ? await safeSendEmail(user, subject, html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "loan_lifecycle_disabled")) : (reminderFamilyEnabled(ctx, event) ? await safeSendEmail(user, subject, html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "loan_reminder_disabled"));
  let adminResult: EmailSendResult | null = null;
  if (isLifecycle && loanLifecycleEnabled(ctx) && loanAdminCopyEnabled(ctx)) { adminResult = await sendAdminNotification({ context: ctx, subject: applyBrandingText(`[${brandTag}] ${title} — ${adminUserName}`, ctx), title, introHtml: `<p>Atualização de empréstimo (sistema antigo).</p>`, details: [{ label: "Leitor(a/e)", value: adminUserName }, { label: "Livro", value: titulo }] }); }
  return { user_result: userResult, admin_result: adminResult };
}
