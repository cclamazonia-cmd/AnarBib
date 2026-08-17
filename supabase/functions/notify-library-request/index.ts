import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { inlineLogosInHtml } from "../_shared/mail/inline-images.ts";
import { tr, normalizeLocale, FALLBACK_LOCALE } from "./strings.ts";
const SUPABASE_URL = mustEnv("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = mustEnv("SUPABASE_SERVICE_ROLE_KEY");
const WEBHOOK_SECRET = mustEnv("WEBHOOK_SECRET_NOTIFY_LIBRARY_REQUEST");
const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") || "").trim();
const ADMIN_NAME = (Deno.env.get("ADMIN_NAME") || "").trim() || "Coordenação do AnarBib";
const BRAND_NAME = (Deno.env.get("BRAND_NAME") || "").trim() || "AnarBib";
const SENDER_EMAIL = (Deno.env.get("SENDER_EMAIL") || "").trim() || "anarbib@anarbib.org";
const FOOTER_TEXT = (Deno.env.get("FOOTER_TEXT") || "").trim() || "Em caso de dúvida, responda a este e-mail.";
const LOGO_URL = (Deno.env.get("LOGO_URL") || "").trim();
const REGIMENTO_URL = (Deno.env.get("REGIMENTO_URL") || "").trim();
const LIBRARIAN_PHONE = (Deno.env.get("LIBRARIAN_PHONE") || "").trim();
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});
function mustEnv(name) {
  const value = (Deno.env.get(name) || "").trim();
  if (!value) throw new Error(`Missing required env: ${name}`);
  return value;
}
function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8"
    }
  });
}
function esc(value) {
  return String(value ?? "").replace(/[&<>"']/g, (c)=>({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;"
    })[c]);
}
function firstNameOnly(value) {
  const s = String(value || "").trim();
  if (!s) return "";
  return s.split(/\s+/)[0] || "";
}
function fullName(first, last) {
  return [
    first,
    last
  ].map((x)=>String(x || "").trim()).filter(Boolean).join(" ");
}
function isValidEmail(email) {
  const s = String(email || "").trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}
function formatDateBR(isoOrDate) {
  if (!isoOrDate) return "";
  const d = isoOrDate instanceof Date ? isoOrDate : new Date(isoOrDate);
  if (Number.isNaN(d.getTime())) return String(isoOrDate);
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: "UTC",
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).format(d);
}
function formatDateTimeBR(isoOrDate) {
  if (!isoOrDate) return "";
  const d = isoOrDate instanceof Date ? isoOrDate : new Date(isoOrDate);
  if (Number.isNaN(d.getTime())) return String(isoOrDate);
  return new Intl.DateTimeFormat("pt-BR", {
    timeZone: "UTC",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  }).format(d);
}
async function parsePayload(req) {
  const payload = await req.json().catch(()=>null);
  const manualTest = !!payload?.manual_test;
  return {
    payload,
    manualTest
  };
}
// Durci le 2026-08-17 : le repli « manual_test + Bearer bien formé » est
// retiré. verify_jwt = false sur cette fonction, donc le Bearer n'était validé
// par personne et `manual_test` est fourni par l'appelant : un simple
// {"manual_test":true} + Authorization: Bearer aaaa suffisait à passer.
// Seul le secret webhook autorise désormais l'appel.
function authorizeWebhook(req, manualTest) {
  const gotSecret = String(req.headers.get("x-webhook-secret") || "").trim();
  const webhookOk = !!WEBHOOK_SECRET && !!gotSecret && gotSecret === WEBHOOK_SECRET;
  return {
    ok: webhookOk,
    webhookOk,
    dashboardTestOk: false
  };
}
async function fetchRequest(requestId) {
  const { data, error } = await supabaseAdmin.from("library_requests").select("*").eq("id", requestId).maybeSingle();
  if (error) throw new Error(`library_request_fetch_failed: ${error.message}`);
  return data || null;
}
async function fetchProfile(profileId) {
  const id = String(profileId || "").trim();
  if (!id) return null;
  const { data, error } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,public_id,preferred_language").eq("id", id).maybeSingle();
  if (error) throw new Error(`profile_fetch_failed: ${error.message}`);
  return data || null;
}
// #111 follow-up mail — langue du·de la solicitante (preferred_language du profil).
async function resolveSubmitterLocale(row) {
  const p = await fetchProfile(row.submitted_by_user_id).catch(() => null);
  return normalizeLocale(p?.preferred_language);
}
// Admins réseau actif·ves avec e-mail + langue (fan-out individuel, chacun·e
// dans sa langue) — remplace l'envoi à une boîte ADMIN_EMAIL unique.
async function fetchActiveAdmins() {
  const { data: admins, error } = await supabaseAdmin.from("network_administrators").select("user_id").eq("status", "active");
  if (error || !admins?.length) return [];
  const ids = admins.map((a) => a.user_id);
  const { data: profs } = await supabaseAdmin.from("profiles").select("email,preferred_language").in("id", ids);
  return (profs || []).filter((p) => isValidEmail(p.email)).map((p) => ({
    email: String(p.email).trim().toLowerCase(),
    locale: normalizeLocale(p.preferred_language),
  }));
}
// Fan-out vers les admins actif·ves (fallback ADMIN_EMAIL si aucun·e résolu·e,
// pour ne jamais perdre une notification). buildFn(locale) -> e-mail rendu.
async function sendToAdmins(label, buildFn, results) {
  let admins = await fetchActiveAdmins();
  if (admins.length === 0) {
    const a = adminTarget();
    if (a) admins = [{ email: a.email, locale: FALLBACK_LOCALE }];
  }
  const seen = new Set();
  for (const ad of admins) {
    if (seen.has(ad.email)) continue;
    seen.add(ad.email);
    const email = buildFn(ad.locale);
    const rendered = renderEmail(email);
    results.push(await safeSendEmail(label, { email: ad.email }, email.subject, rendered.html, rendered.text));
  }
}
function dedupeTargets(...targets) {
  const seen = new Set();
  return targets.filter((t)=>!!t && isValidEmail(t.email)).filter((t)=>{
    const key = String(t.email).trim().toLowerCase();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
function applicantTargets(row) {
  const main = isValidEmail(row.contact_email) ? {
    email: row.contact_email.trim().toLowerCase(),
    name: firstNameOnly(row.contact_name) || undefined
  } : null;
  const submitted = isValidEmail(row.submitted_by_email_snapshot) ? {
    email: row.submitted_by_email_snapshot.trim().toLowerCase()
  } : null;
  return dedupeTargets(main, submitted);
}
function adminTarget() {
  if (!isValidEmail(ADMIN_EMAIL)) return null;
  return {
    email: ADMIN_EMAIL.trim().toLowerCase(),
    name: ADMIN_NAME || undefined
  };
}
function footerHtml(locale) {
  const parts = [];
  if (REGIMENTO_URL) {
    parts.push(`Regimento da rede: <a href="${esc(REGIMENTO_URL)}" style="color:#fff;text-decoration:underline;">abrir</a>`);
  }
  if (LIBRARIAN_PHONE) {
    parts.push(`Contato rápido: <b>${esc(LIBRARIAN_PHONE)}</b>`);
  }
  parts.push(esc(tr(locale || FALLBACK_LOCALE, "footer")));
  return parts.join("<br>");
}
function footerText(locale) {
  const parts = [];
  if (REGIMENTO_URL) parts.push(`Regimento da rede: ${REGIMENTO_URL}`);
  if (LIBRARIAN_PHONE) parts.push(`Contato rápido: ${LIBRARIAN_PHONE}`);
  parts.push(tr(locale || FALLBACK_LOCALE, "footer"));
  return parts.join("\n");
}
function renderEmail(opts) {
  const detailRows = (opts.details || []).map((row)=>`
    <tr>
      <td style="padding:8px 0;color:#cfcfcf;font-size:14px;vertical-align:top;">${esc(row.label)}</td>
      <td style="padding:8px 0;color:#ffffff;font-size:14px;text-align:right;"><b>${esc(row.value)}</b></td>
    </tr>
  `).join("");
  const detailsHtml = detailRows ? `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:14px 0 0;border-collapse:collapse;">${detailRows}</table>
       <div style="height:1px;background:rgba(255,255,255,0.12);margin:14px 0 0;"></div>` : "";
  const greetingHtml = opts.greeting ? `<p style="margin:0 0 12px;font-size:16px;line-height:1.5;">${esc(opts.greeting)}</p>` : "";
  const logoHtml = LOGO_URL ? `<img src="${esc(LOGO_URL)}" alt="${esc(BRAND_NAME)}" style="display:block;max-width:84px;max-height:52px;width:auto;height:auto;object-fit:contain;">` : "";
  const html = `<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(opts.title)}</title>
</head>
<body style="margin:0;background:#0f0f10;color:#ffffff;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${esc(opts.preheader || opts.title)}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;">
    <tr>
      <td align="center" style="padding:24px 12px;">
        <table role="presentation" width="640" cellspacing="0" cellpadding="0" style="border-collapse:collapse;max-width:640px;width:100%;">
          <tr>
            <td style="background:rgba(27,27,27,0.94);border:1px solid rgba(255,255,255,0.12);border-radius:18px;overflow:hidden;">
              <div style="padding:18px 18px 14px;display:flex;align-items:center;gap:12px;">
                ${logoHtml}
                <div>
                  <div style="font-size:18px;font-weight:800;line-height:1.2;">${esc(BRAND_NAME)}</div>
                  <div style="font-size:13px;color:#cfcfcf;line-height:1.2;">${esc(tr(opts.locale || FALLBACK_LOCALE, "subtitle"))}</div>
                </div>
              </div>
              <div style="height:3px;background:#c00000;"></div>
              <div style="padding:18px;">
                <h1 style="margin:0 0 12px;font-size:20px;line-height:1.25;">${esc(opts.title)}</h1>
                ${greetingHtml}
                <div style="font-size:16px;line-height:1.55;color:#f2f2f2;">${opts.introHtml}</div>
                ${detailsHtml}
                <div style="margin:16px 0 0;font-size:13px;line-height:1.5;color:#cfcfcf;">${footerHtml(opts.locale)}</div>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 6px 0;color:#9c9c9c;font-size:12px;line-height:1.4;text-align:center;">
              © ${esc(BRAND_NAME)} — ${esc(FOOTER_TEXT)}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body></html>`;
  const text = [
    BRAND_NAME,
    opts.title,
    "",
    opts.greeting || "",
    opts.introHtml.replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>\s*<p>/gi, "\n\n").replace(/<[^>]+>/g, "").trim(),
    "",
    ...(opts.details || []).map((row)=>`${row.label}: ${row.value}`),
    "",
    footerText(opts.locale)
  ].filter((line, index, arr)=>!(line === "" && arr[index - 1] === "")).join("\n");
  return {
    html,
    text
  };
}
// ============================================================================
// Transport mail — envoi via Resend
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend) : R.3.2 avait introduit un dispatch
// Brevo/Resend pilote par MAIL_PROVIDER ; R.6 (05/06/2026) a retire Brevo.
// sendEmail() inline les logos (spec §4.5) puis appelle sendViaResend(). Le
// secret MAIL_PROVIDER a ete retire de Supabase en R.7 (08/06/2026) ;
// n'est plus lu par le code.
//
// Signature positionnelle (target, subject, html, text) conservee : c'est le
// contrat que consomme safeSendEmail. Contrat de retour : string + throw.
// ============================================================================
function formatMailAddress(email, name) {
  const n = String(name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Resend (cf. spec §4.4) ---------------------------------
// htmlInlined : meme HTML deja inline que pour Brevo (§4.5).
async function sendViaResend(target, subject, htmlInlined, text) {
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (!resendKey) {
    throw new Error("RESEND_API_KEY absente des secrets Edge Function");
  }
  const payload: Record<string, unknown> = {
    from: formatMailAddress(SENDER_EMAIL, BRAND_NAME),
    to: [target.email],
    subject,
    html: htmlInlined,
    text
  };
  if (isValidEmail(ADMIN_EMAIL)) {
    payload.reply_to = formatMailAddress(ADMIN_EMAIL.trim().toLowerCase(), ADMIN_NAME);
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`Resend error HTTP ${res.status}: ${body}`);
  return body;
}
// --- Wrapper neutre --------------------------------------------------------
// Inline les logos une fois (spec §4.5), puis envoie via Resend.
async function sendEmail(target, subject, html, text) {
  // Inlining des logos Supabase Storage en data URI base64 — inconditionnel.
  // Defensif : en cas d'echec, HTML d'origine.
  let htmlInlined = html;
  if (html && typeof html === "string") {
    try {
      htmlInlined = await inlineLogosInHtml(html);
    } catch (e) {
      console.warn(`notify-library-request: inlineLogosInHtml failed (mail sent anyway):`, e);
    }
  }
  console.log(`[library-request] envoi via resend`);
  return await sendViaResend(target, subject, htmlInlined, text);
}
async function safeSendEmail(label, target, subject, html, text) {
  if (!target || !isValidEmail(target.email)) {
    return {
      ok: false,
      label,
      skipped: true,
      reason: "invalid_or_empty_email",
      email: target?.email || null
    };
  }
  try {
    const response = await sendEmail(target, subject, html, text);
    return {
      ok: true,
      label,
      email: target.email,
      response
    };
  } catch (error) {
    return {
      ok: false,
      label,
      email: target.email,
      error: String(error?.message || error)
    };
  }
}
// #111 follow-up mail Phase 2 — libellés de valeur localisés (fallback : la valeur brute).
function labelOr(locale, prefix, value) {
  const v = tr(locale, prefix + value);
  return v === prefix + value ? (value || "—") : v;
}
function statusLabel(locale, status) { return labelOr(locale, "status.", status); }
function projectStageLabel(locale, value) { return labelOr(locale, "stage.", value); }
function firstManagerLabel(locale, value) { return labelOr(locale, "mgr.", value); }
function normalizeReviewNotesForEmail(value, stripComplementPrefix = false) {
  const raw = String(value || "").trim();
  if (!raw) return "";
  if (!stripComplementPrefix) return raw;
  return raw.replace(/^pedido\s+de\s+complemento\s*:\s*/i, "").trim() || raw;
}
function commonDetails(locale, row) {
  return [
    { label: tr(locale, "lbl.library"), value: row.library_name },
    { label: tr(locale, "lbl.shortName"), value: row.library_short_name || "—" },
    { label: tr(locale, "lbl.location"), value: [row.city, row.state_region, row.country].filter(Boolean).join(" · ") || "—" },
    { label: tr(locale, "lbl.stage"), value: projectStageLabel(locale, row.project_stage) },
    { label: tr(locale, "lbl.contact"), value: row.contact_name },
    { label: tr(locale, "lbl.contactEmail"), value: row.contact_email },
    { label: tr(locale, "lbl.firstManager"), value: firstManagerLabel(locale, row.first_manager_intent) },
    { label: tr(locale, "lbl.currentStatus"), value: statusLabel(locale, row.request_status) },
  ];
}
function greetingFor(locale, name) {
  const n = firstNameOnly(name);
  return n ? tr(locale, "greetingNamed", { name: n }) : tr(locale, "greeting");
}
const APPLICANT_EV = {
  library_request_created: "created",
  library_request_in_analysis: "in_analysis",
  library_request_more_info: "more_info",
  library_request_approved: "approved",
  library_request_refused: "refused",
};
// #111 follow-up mail — tout localisé selon la langue du·de la destinataire
// (sujet/titre/salutation/intro + libellés du tableau via strings.ts). {library} interpolé.
function buildApplicantEmail(locale, eventType, row, reviewerName) {
  const evKey = APPLICANT_EV[eventType] || "in_analysis";
  const details = [...commonDetails(locale, row)];
  if (eventType === "library_request_created") {
    details.push({ label: tr(locale, "lbl.sentAt"), value: formatDateTimeBR(row.created_at) || "—" });
  } else if (reviewerName) {
    details.push({ label: tr(locale, "lbl.coordination"), value: reviewerName });
  }
  if (row.review_notes && ["library_request_more_info", "library_request_approved", "library_request_refused"].includes(eventType)) {
    details.push({ label: tr(locale, "lbl.coordinationMessage"), value: normalizeReviewNotesForEmail(row.review_notes, eventType === "library_request_more_info") });
  }
  return {
    locale,
    subject: `[${BRAND_NAME}] ${tr(locale, evKey + ".subject")}`,
    title: tr(locale, evKey + ".subject"),
    greeting: greetingFor(locale, row.contact_name),
    introHtml: `<p style="margin:0;">${esc(tr(locale, evKey + ".intro", { library: row.library_name }))}</p>`,
    details,
  };
}
function buildAdminEmail(locale, eventType, row, reviewerName) {
  const evKey = eventType === "library_request_created" ? "admin_created" : "admin_update";
  const details = [
    ...commonDetails(locale, row),
    { label: tr(locale, "lbl.libraryEmail"), value: row.library_email },
    { label: tr(locale, "lbl.libraryPhone"), value: row.library_phone || "—" },
    { label: tr(locale, "lbl.submitterEmail"), value: row.submitted_by_email_snapshot || "—" },
  ];
  if (eventType === "library_request_created") {
    details.push({ label: tr(locale, "lbl.presentation"), value: row.summary || "—" });
  } else {
    details.push({ label: tr(locale, "lbl.newStatus"), value: statusLabel(locale, row.request_status) });
  }
  if (reviewerName) details.push({ label: tr(locale, "lbl.coordination"), value: reviewerName });
  if (row.review_notes) details.push({ label: tr(locale, "lbl.reviewNote"), value: row.review_notes });
  return {
    locale,
    subject: `[${BRAND_NAME}] ${tr(locale, evKey + ".subject")}`,
    title: tr(locale, evKey + ".subject"),
    introHtml: `<p style="margin:0;">${esc(tr(locale, evKey + ".intro", { library: row.library_name }))}</p>`,
    details,
  };
}
// ============================================================================
// #111 Lot 2b — échange humain : messages + invitations (« proposer um diálogo »)
// L'enqueue ne transmet que {request_id, event_type} : on récupère le message /
// l'invitation le·la plus récent·e de la demande (volume faible, workflow dormant
// jusqu'à Bologne). Rendu localisé (strings.ts) selon la langue du·de la destinataire.
// ============================================================================
async function fetchLatestMessage(requestId) {
  const { data, error } = await supabaseAdmin.from("library_request_messages").select("*").eq("request_id", requestId).order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (error) throw new Error(`message_fetch_failed: ${error.message}`);
  return data || null;
}
async function fetchLatestInvitation(requestId) {
  const { data, error } = await supabaseAdmin.from("library_request_invitations").select("*").eq("request_id", requestId).order("created_at", { ascending: false }).limit(1).maybeSingle();
  if (error) throw new Error(`invitation_fetch_failed: ${error.message}`);
  return data || null;
}
function summarize(requestId, eventType, results) {
  const sentCount = results.filter((x)=>x.ok === true).length;
  const skippedCount = results.filter((x)=>x.skipped === true).length;
  const failedCount = results.filter((x)=>x.ok === false && !x.skipped).length;
  return { ok: failedCount === 0, request_id: requestId, event_type: eventType, sent_count: sentCount, skipped_count: skippedCount, failed_count: failedCount, results };
}
function buildMessageEmail(locale, row, msg, toSolicitante) {
  const evKey = toSolicitante ? "message" : "admin_message";
  return {
    locale,
    subject: `[${BRAND_NAME}] ${tr(locale, evKey + ".subject")}`,
    title: tr(locale, evKey + ".subject"),
    greeting: toSolicitante ? greetingFor(locale, row.contact_name) : "",
    introHtml: `<p style="margin:0;">${esc(tr(locale, evKey + ".intro", { library: row.library_name }))}</p>`,
    details: [{ label: tr(locale, "lbl.message"), value: msg.content }],
  };
}
function buildInvitationEmail(locale, row, inv, notifySolicitante, isResponse) {
  // proposition côté solicitante → 'invitation_proposed' ; côté admin → 'admin_invitation' ;
  // réponse côté solicitante → 'invitation_response' ; côté admin → 'admin_invitation' (réutilisé).
  const evKey = !isResponse
    ? (notifySolicitante ? "invitation_proposed" : "admin_invitation")
    : (notifySolicitante ? "invitation_response" : "admin_invitation");
  const details = [{ label: tr(locale, "lbl.subject"), value: inv.subject }];
  if (inv.proposed_at_text) details.push({ label: tr(locale, "lbl.proposedTime"), value: inv.proposed_at_text });
  return {
    locale,
    subject: `[${BRAND_NAME}] ${tr(locale, evKey + ".subject")}`,
    title: tr(locale, evKey + ".subject"),
    greeting: notifySolicitante ? greetingFor(locale, row.contact_name) : "",
    introHtml: `<p style="margin:0;">${esc(tr(locale, evKey + ".intro", { library: row.library_name }))}</p>`,
    details,
  };
}
async function handleMessageNotify(row) {
  const msg = await fetchLatestMessage(row.id);
  if (!msg) return { ok: true, skipped: "no_message", request_id: row.id, event_type: "library_request_message" };
  const toSolicitante = msg.direction === "admin_to_solicitante";
  const results = [];
  if (toSolicitante) {
    const locale = await resolveSubmitterLocale(row);
    const email = buildMessageEmail(locale, row, msg, true);
    const rendered = renderEmail(email);
    for (const target of applicantTargets(row)) {
      results.push(await safeSendEmail("message", target, email.subject, rendered.html, rendered.text));
    }
  } else {
    await sendToAdmins("message", (loc) => buildMessageEmail(loc, row, msg, false), results);
  }
  return summarize(row.id, "library_request_message", results);
}
async function handleInvitationNotify(row) {
  const inv = await fetchLatestInvitation(row.id);
  if (!inv) return { ok: true, skipped: "no_invitation", request_id: row.id, event_type: "library_request_invitation" };
  const isResponse = inv.status === "accepted" || inv.status === "declined";
  // proposition → notifie l'autre côté ; réponse → notifie l'initiateur·rice.
  const notifySolicitante = isResponse ? (inv.initiator_side === "solicitante") : (inv.initiator_side === "admin");
  const results = [];
  if (notifySolicitante) {
    const locale = await resolveSubmitterLocale(row);
    const email = buildInvitationEmail(locale, row, inv, true, isResponse);
    const rendered = renderEmail(email);
    for (const target of applicantTargets(row)) {
      results.push(await safeSendEmail("invitation", target, email.subject, rendered.html, rendered.text));
    }
  } else {
    await sendToAdmins("invitation", (loc) => buildInvitationEmail(loc, row, inv, false, isResponse), results);
  }
  return summarize(row.id, "library_request_invitation", results);
}
async function handleNotify(payload) {
  const requestId = String(payload?.request_id || "").trim();
  const eventType = String(payload?.event_type || "").trim();
  if (!requestId) {
    return {
      ok: false,
      error: "request_id_missing"
    };
  }
  const allowedEvents = [
    "library_request_created",
    "library_request_in_analysis",
    "library_request_more_info",
    "library_request_approved",
    "library_request_refused",
    "library_request_message",
    "library_request_invitation"
  ];
  if (!allowedEvents.includes(eventType)) {
    return {
      ok: false,
      error: "invalid_event_type",
      event_type: eventType
    };
  }
  const row = await fetchRequest(requestId);
  if (!row) {
    return {
      ok: true,
      skipped: "request_not_found",
      request_id: requestId,
      event_type: eventType
    };
  }
  // #111 Lot 2b — messages / invitations : routage et rendu propres.
  if (eventType === "library_request_message") return await handleMessageNotify(row);
  if (eventType === "library_request_invitation") return await handleInvitationNotify(row);
  const reviewer = await fetchProfile(row.reviewed_by_user_id).catch(()=>null);
  const reviewerName = reviewer ? fullName(reviewer.first_name, reviewer.last_name) || reviewer.public_id || reviewer.email || null : null;
  // E-mail au·à la solicitante dans SA langue (preferred_language).
  const applicantLocale = await resolveSubmitterLocale(row);
  const applicantEmail = buildApplicantEmail(applicantLocale, eventType, row, reviewerName);
  const applicantRendered = renderEmail(applicantEmail);
  const results = [];
  for (const target of applicantTargets(row)){
    results.push(await safeSendEmail("applicant", target, applicantEmail.subject, applicantRendered.html, applicantRendered.text));
  }
  // Copie à la coordination : fan-out vers chaque admin actif·ve, dans sa langue.
  if (eventType === "library_request_created") {
    await sendToAdmins("admin_copy", (loc) => buildAdminEmail(loc, eventType, row, reviewerName), results);
  }
  const sentCount = results.filter((x)=>x.ok === true).length;
  const skippedCount = results.filter((x)=>x.skipped === true).length;
  const failedCount = results.filter((x)=>x.ok === false && !x.skipped).length;
  return {
    ok: failedCount === 0,
    request_id: requestId,
    event_type: eventType,
    sent_count: sentCount,
    skipped_count: skippedCount,
    failed_count: failedCount,
    results
  };
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: {
        "access-control-allow-origin": "*",
        "access-control-allow-methods": "POST, OPTIONS",
        "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret"
      }
    });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, {
      ok: false,
      error: "Method not allowed"
    });
  }
  try {
    const { payload, manualTest } = await parsePayload(req);
    const auth = authorizeWebhook(req, manualTest);
    if (!auth.ok) {
      return jsonResponse(401, {
        ok: false,
        error: "Unauthorized"
      });
    }
    const result = await handleNotify(payload);
    return jsonResponse(200, result);
  } catch (error) {
    return jsonResponse(500, {
      ok: false,
      error: String(error?.message || error)
    });
  }
});
