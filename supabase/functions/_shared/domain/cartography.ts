// ============================================================================
// domain/cartography.ts — Handler des events cartography.* (auto-déclaration carte)
// ============================================================================
// Lit la ligne cartography_submission_notification_outbox par recordId (BIGINT),
// rend un e-mail d'alerte à la boîte éditoriale réseau (fede@anarbib.org) et pose
// le statut outbox (sent / skipped / failed). Même architecture que domain/gazette.ts.
// Contexte RÉSEAU (pas de biblio) → ctx = resolve(null). Alerte interne de
// coordination : corps en français (langue de travail), données brutes language-neutres.
//
// Events traités :
//   - cartography.submission_received → fede@anarbib.org (à modérer sur /cartografia/moderacao)
// ============================================================================
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail } from "../transport/email.ts";

const OUTBOX = "cartography_submission_notification_outbox";
const APP_URL = "https://app.anarbib.org";
const EDITORIAL_FALLBACK = "fede@anarbib.org";

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
function safeUrl(u) {
  const s = String(u ?? "").trim();
  return /^https?:\/\//i.test(s) ? s : "";
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

export async function handleCartographyEvent(recordId) {
  const { data: outbox, error } = await supabaseAdmin
    .from(OUTBOX).select("id,event,payload,status").eq("id", recordId).maybeSingle();
  if (error) throw error;
  if (!outbox) throw new Error(`${OUTBOX} row ${recordId} not found`);
  const event = String(outbox.event || "").trim();
  const payload = outbox.payload || {};
  const ctx = await resolveLibraryNotificationContext(null); // contexte réseau

  try {
    if (event !== "cartography.submission_received") {
      console.warn(`[cartography] unknown event: ${event}`);
      await markOutboxSkipped(outbox.id);
      return { ok: true, ignored: true, reason: "unknown_cartography_event", event };
    }

    const to = String(payload.to || EDITORIAL_FALLBACK).trim();
    const locale = ctx?.default_locale || "pt-BR";
    const name = String(payload.name || "—");
    const place = [payload.city, payload.country].filter(Boolean).join(", ");
    const cat = String(payload.categorie || "—");
    const site = safeUrl(payload.site_url);

    const sub = "Nouvelle bibliothèque proposée sur la carte du réseau";
    let introHtml = `<p>Une auto-déclaration vient d'être soumise sur la carte du réseau (à modérer) :</p>`;
    introHtml += `<ul style="margin:.4rem 0;padding-left:1.1rem">`;
    introHtml += `<li><strong>${esc(name)}</strong></li>`;
    if (place) introHtml += `<li>${esc(place)}</li>`;
    introHtml += `<li>Catégorie : ${esc(cat)}</li>`;
    if (site) introHtml += `<li><a href="${esc(site)}">${esc(site)}</a></li>`;
    introHtml += `</ul>`;
    introHtml += `<p><a href="${APP_URL}/cartografia/moderacao">${APP_URL}/cartografia/moderacao</a></p>`;

    const { html, text } = renderEmail({
      locale,
      preheader: sub,
      title: sub,
      introHtml,
      details: [],
      footerHtml: footerPadrao(ctx, locale),
      context: ctx,
    });
    const target = { email: to, name: "Cartographie AnarBib" };
    const result = await safeSendEmail(target, sub, html, text, "cartography_submission", ctx);
    await markOutboxSent(outbox.id);
    return { ok: true, event, recipients_count: 1, result };
  } catch (err) {
    await markOutboxFailed(outbox.id, String(err?.message || err));
    throw err;
  }
}
