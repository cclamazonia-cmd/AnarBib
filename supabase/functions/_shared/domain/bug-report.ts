// ============================================================================
// domain/bug-report.ts — Handler des events bug_report.* (« Signaler un problème », E14)
// ============================================================================
// Lit la ligne bug_report_notification_outbox par recordId (BIGINT), envoie :
//   1. l'alerte à l'administration du réseau — les destinataires viennent de
//      _shared/context/network-admins.ts (F15, 24/09) : les admins actif·ves de
//      la table ET la boîte collective (NETWORK_ADMIN_CC, repli HEALTH_ALERT_CC) ;
//      repli ultime admins@anarbib.org si rien n'est configuré. Langue de travail :
//      français, données brutes telles que saisies. Lien vers la file /signalar/fila ;
//   2. si la personne a laissé une adresse, un accusé de réception simple dans SA
//      langue (« reçu, merci », numéro du signalement) — décision de Xavier du 24/09,
//      sans suivi ensuite. L'adresse humaine est dans le corps, jamais en Reply-To (F14).
// Puis pose le statut de la file d'après le RÉSULTAT des envois (outbox-verdict.ts).
// Même architecture que domain/cartography.ts. Contexte RÉSEAU → ctx = resolve(null).
//
// Events traités :
//   - bug_report.received → admins réseau (+ accusé de réception facultatif)
// ============================================================================
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { destinatairesAdminsReseau } from "../context/network-admins.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail } from "../transport/email.ts";
import { APP_BASE_URL } from "../core/app-url.ts";
import { tMail } from "../i18n/mail-strings.ts";
import { verdictEnvois } from "./outbox-verdict.ts";

const OUTBOX = "bug_report_notification_outbox";
const APP_URL = APP_BASE_URL; // foyer unique : ../core/app-url.ts
const ADMINS_FALLBACK = "admins@anarbib.org"; // repli ultime, si ni admin actif ni boîte configurée
const CANAL_HUMAIN = "anarbib@proton.me";      // décision du 16/09 : jamais une adresse .org pour joindre une personne

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
function bloc(titre, corps) {
  if (!corps) return "";
  return `<p style="margin:.6rem 0 .2rem"><strong>${esc(titre)}</strong></p><p style="margin:0;white-space:pre-wrap">${esc(corps)}</p>`;
}

async function marquer(id, champs) {
  await supabaseAdmin.from(OUTBOX).update(champs).eq("id", id);
}

export async function handleBugReportEvent(recordId) {
  const { data: outbox, error } = await supabaseAdmin
    .from(OUTBOX).select("id,event,payload,status").eq("id", recordId).maybeSingle();
  if (error) throw error;
  if (!outbox) throw new Error(`${OUTBOX} row ${recordId} not found`);
  const event = String(outbox.event || "").trim();
  const p = outbox.payload || {};
  const ctx = await resolveLibraryNotificationContext(null); // contexte réseau

  try {
    if (event !== "bug_report.received") {
      console.warn(`[bug-report] unknown event: ${event}`);
      await marquer(outbox.id, { status: "skipped", skip_reason: "unknown_bug_report_event" });
      return { ok: true, ignored: true, reason: "unknown_bug_report_event", event };
    }

    const ref = String(p.report_id || "").slice(0, 8);
    const localeAdmins = ctx?.default_locale || "pt-BR";
    const fila = `${APP_URL}/signalar/fila`;

    // 1. L'alerte à l'administration du réseau (une résolution des destinataires, F15).
    let admins = await destinatairesAdminsReseau(supabaseAdmin);
    if (!admins.length) admins = [{ email: ADMINS_FALLBACK, name: "Administration AnarBib", locale: localeAdmins, source: "extra" }];
    const sub = `Signalement ${ref} — ${String(p.page_path || "page inconnue")}`;
    let introHtml = `<p>Un problème vient d'être signalé depuis l'application (E14) :</p>`;
    introHtml += bloc("Ce qui s'est passé", p.what_happened);
    introHtml += bloc("Ce qui était attendu", p.expected);
    introHtml += bloc("Comment refaire", p.steps);
    introHtml += `<ul style="margin:.6rem 0;padding-left:1.1rem">`;
    introHtml += `<li>Page : ${esc(p.page_path || "—")}</li>`;
    introHtml += `<li>Langue : ${esc(p.locale || "—")} · Rôle : ${esc(p.role_hint || "aucun compte")} · Bibliothèque : ${esc(p.library_hint || "—")}</li>`;
    introHtml += `<li>Navigateur : ${esc(p.user_agent || "—")}</li>`;
    introHtml += `<li>Contact : ${esc(p.reporter_email || "aucune adresse laissée")}</li>`;
    introHtml += `</ul>`;
    introHtml += `<p>File des signalements : <a href="${esc(fila)}">${esc(fila)}</a></p>`;
    const results = [];
    for (const d of admins) {
      const loc = d.locale || localeAdmins;
      const rendu = renderEmail({
        locale: loc, preheader: sub, title: sub, introHtml, details: [],
        footerHtml: footerPadrao(ctx, loc), context: ctx,
      });
      results.push(await safeSendEmail({ email: d.email, name: d.name || "Administration AnarBib" }, sub, rendu.html, rendu.text, "bug_report", ctx));
    }

    // 2. L'accusé de réception à la personne, dans sa langue, si elle a laissé une adresse.
    const email = String(p.reporter_email || "").trim();
    if (email) {
      const loc = String(p.locale || localeAdmins);
      const subAck = tMail(loc, "bugreport.ack.sub", { ref });
      const ackHtml = `<p>${esc(tMail(loc, "bugreport.ack.intro"))}</p>`
        + `<p>${esc(tMail(loc, "bugreport.ack.ref", { ref }))}</p>`
        + `<p style="margin:.6rem 0 0"><em>${esc(tMail(loc, "bugreport.ack.noreply", { email: CANAL_HUMAIN }))}</em></p>`;
      const ack = renderEmail({
        locale: loc, preheader: subAck, title: subAck, introHtml: ackHtml, details: [],
        footerHtml: footerPadrao(ctx, loc), context: ctx,
      });
      results.push(await safeSendEmail({ email }, subAck, ack.html, ack.text, "bug_report_ack", ctx));
    }

    const verdict = verdictEnvois({ recipients_count: results.length, results });
    if (verdict.status === "skipped") await marquer(outbox.id, { status: "skipped", skip_reason: verdict.detail });
    else if (verdict.status === "failed") await marquer(outbox.id, { status: "failed", last_error: verdict.detail });
    else await marquer(outbox.id, { status: "sent", sent_at: new Date().toISOString() });
    return { ok: verdict.status !== "failed", event, outbox_status: verdict.status, recipients_count: results.length, results };
  } catch (err) {
    await marquer(outbox.id, { status: "failed", last_error: String(err?.message || err) });
    throw err;
  }
}
