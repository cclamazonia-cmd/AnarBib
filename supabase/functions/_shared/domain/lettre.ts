// ============================================================================
// domain/lettre.ts — Handler des events lettre.* (Lettre de la fédération)
// ============================================================================
// Events :
//   - lettre.optin.confirm  → e-mail de confirmation du double opt-in (Lot 2c)
//   - lettre.issue.sent     → envoi d'un numéro à un·e abonné·e (Lot 3)
// Contexte RÉSEAU (resolve(null)) ; locale du destinataire ; lien de désabonnement
// 1-clic dans chaque numéro. Même architecture que domain/gazette.ts.
// ============================================================================
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail } from "../transport/email.ts";
import { tMail, greeting } from "../i18n/mail-strings.ts";

const OUTBOX = "lettre_notification_outbox";
const APP_URL = "https://app.anarbib.org";
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
    } else if (event === "lettre.issue.sent") {
      result = await handleIssueSent(payload, ctx);
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

// lettre.issue.sent → un numéro de la Lettre. Digest structuré (cercles / assemblées /
// gazette) rendu dans la locale du·de la destinataire + intro libre staff + désabonnement.
async function handleIssueSent(payload, ctx) {
  const to = String(payload.to || "").trim();
  if (!to) return { recipients_count: 0, reason: "no_email" };
  const locale = String(payload.locale || "").trim() || ctx?.default_locale || "pt-BR";
  const number = String(payload.number ?? "");
  const intro = String(payload.intro || "").trim();
  const items = Array.isArray(payload.items) ? payload.items : [];
  const unsubToken = String(payload.unsub_token || "").trim();

  const sub = tMail(locale, "lettre.issue.subject", { number });
  const H = `style="font-size:1rem;margin:1.2rem 0 .4rem;color:#cf1f27"`;
  let body = "";
  if (intro) body += `<p>${esc(intro)}</p>`;

  const circles = items.filter((i) => i && i.kind === "circle");
  const assemblies = items.filter((i) => i && i.kind === "assembly");
  const gazette = items.find((i) => i && i.kind === "gazette");

  if (circles.length) {
    body += `<h3 ${H}>${esc(tMail(locale, "lettre.issue.section.circles"))}</h3><ul style="margin:.2rem 0 .6rem;padding-left:1.2rem">`;
    for (const c of circles) body += `<li>${esc(c.name)}</li>`;
    body += `</ul>`;
  }
  if (assemblies.length) {
    body += `<h3 ${H}>${esc(tMail(locale, "lettre.issue.section.assemblies"))}</h3><ul style="margin:.2rem 0 .6rem;padding-left:1.2rem">`;
    for (const a of assemblies) {
      let when = "";
      try { when = a.scheduled_at ? ` — ${new Date(a.scheduled_at).toLocaleDateString(locale)}` : ""; } catch { when = ""; }
      body += `<li>${esc(a.title)}${esc(when)}</li>`;
    }
    body += `</ul>`;
  }
  if (gazette) {
    body += `<p><a href="${APP_URL}/federacao/gazeta">`
      + `${esc(tMail(locale, "lettre.issue.gazetteLink", { number: String(gazette.number ?? "") }))}</a></p>`;
  }
  if (!intro && !circles.length && !assemblies.length && !gazette) {
    body += `<p>${esc(tMail(locale, "lettre.issue.empty"))}</p>`;
  }

  // Désabonnement 1-clic (token stable) ; repli sur /conta si token absent.
  const unsubUrl = unsubToken
    ? `${FUNCTIONS_BASE}/lettre-unsubscribe?token=${encodeURIComponent(unsubToken)}`
    : `${APP_URL}/conta`;
  body += `<p style="font-size:.78rem;color:#888;margin-top:1.6rem">`
    + `${esc(tMail(locale, "lettre.issue.unsubscribePrefix"))} `
    + `<a href="${esc(unsubUrl)}" style="color:#888">${esc(tMail(locale, "lettre.issue.unsubscribeLink"))}</a>.</p>`;

  const { html, text } = renderEmail({
    locale,
    preheader: sub,
    title: sub,
    greeting: greeting(locale, payload.to_name || undefined),
    introHtml: body,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx,
  });
  const target = { email: to, name: payload.to_name || undefined };
  const result = await safeSendEmail(target, sub, html, text, "lettre_issue", ctx);
  return { recipients_count: 1, result };
}
