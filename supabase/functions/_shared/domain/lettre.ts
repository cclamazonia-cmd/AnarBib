// ============================================================================
// domain/lettre.ts — Handler des events lettre.* (Lettre de la fédération)
// ============================================================================
// Lit la ligne lettre_notification_outbox par recordId (BIGINT), rend le mail
// i18n, envoie via safeSendEmail, puis pose le statut outbox (sent/skipped/failed).
// Même architecture que domain/gazette.ts. Contexte RÉSEAU (pas de biblio) →
// ctx = resolve(null) : expéditeur par défaut (SENDER_EMAIL), pas de kill-switch
// biblio (la Lettre est un envoi réseau, opt-in par personne — pas opt-out biblio).
//
// Events traités (Lot 2c) :
//   - lettre.optin.confirm   → e-mail de confirmation du double opt-in (lien 1-clic)
// (Les envois de numéros — lettre.issue.sent — viendront au Lot 3.)
// ============================================================================
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail } from "../transport/email.ts";
import { tMail, greeting } from "../i18n/mail-strings.ts";

const OUTBOX = "lettre_notification_outbox";
const FUNCTIONS_BASE = (Deno.env.get("SUPABASE_URL") || "").replace(/\/+$/, "") + "/functions/v1";

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

async function markOutboxSent(id) {
  await supabaseAdmin.from(OUTBOX).update({ status: "sent", sent_at: new Date().toISOString() }).eq("id", id);
}
async function markOutboxSkipped(id) {
  await supabaseAdmin.from(OUTBOX).update({ status: "skipped", sent_at: new Date().toISOString() }).eq("id", id);
}
async function markOutboxFailed(id, errorMsg) {
  await supabaseAdmin.from(OUTBOX).update({ status: "failed", last_error: errorMsg }).eq("id", id);
}

export async function handleLettreEvent(recordId) {
  const { data: outbox, error } = await supabaseAdmin
    .from(OUTBOX).select("id,event,payload,status").eq("id", recordId).maybeSingle();
  if (error) throw error;
  if (!outbox) throw new Error(`${OUTBOX} row ${recordId} not found`);
  const event = String(outbox.event || "").trim();
  const payload = outbox.payload || {};
  const ctx = await resolveLibraryNotificationContext(null); // contexte réseau

  try {
    let result;
    if (event === "lettre.optin.confirm") {
      result = await handleOptinConfirm(payload, ctx);
    } else {
      console.warn(`[lettre] unknown event: ${event}`);
      await markOutboxSkipped(outbox.id);
      return { ok: true, ignored: true, reason: "unknown_lettre_event", event };
    }
    if (result?.recipients_count === 0) await markOutboxSkipped(outbox.id);
    else await markOutboxSent(outbox.id);
    return { ok: true, event, ...result };
  } catch (err) {
    await markOutboxFailed(outbox.id, String(err?.message || err));
    throw err;
  }
}

// lettre.optin.confirm → e-mail de confirmation (double opt-in). Lien 1-clic vers
// l'EF publique lettre-confirm. Mail dans la locale du destinataire.
async function handleOptinConfirm(payload, ctx) {
  const to = String(payload.to || "").trim();
  if (!to) return { recipients_count: 0, reason: "no_email" };
  const token = String(payload.token || "").trim();
  if (!token) return { recipients_count: 0, reason: "no_token" };
  const locale = String(payload.locale || "").trim() || ctx?.default_locale || "pt-BR";
  const confirmUrl = `${FUNCTIONS_BASE}/lettre-confirm?token=${encodeURIComponent(token)}`;

  const sub = tMail(locale, "lettre.optin.confirm.sub");
  const introHtml =
    `<p>${esc(tMail(locale, "lettre.optin.confirm.intro"))}</p>`
    + `<p style="text-align:center;margin:1.5rem 0">`
    + `<a href="${esc(confirmUrl)}" style="background:#cf1f27;color:#fff;padding:.7rem 1.4rem;border-radius:6px;text-decoration:none;font-weight:700;display:inline-block">`
    + `${esc(tMail(locale, "lettre.optin.confirm.cta"))}</a></p>`
    + `<p style="font-size:.82rem;color:#666">${esc(tMail(locale, "lettre.optin.confirm.note"))}</p>`;

  const { html, text } = renderEmail({
    locale,
    preheader: sub,
    title: sub,
    greeting: greeting(locale, payload.to_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx,
  });
  const target = { email: to, name: payload.to_name || undefined };
  const result = await safeSendEmail(target, sub, html, text, "lettre_optin_confirm", ctx);
  return { recipients_count: 1, result };
}
