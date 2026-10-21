import { mustSecretKey } from "../_shared/core/secret-key.ts";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from '../_shared/deps.ts';
import { sendEmail as sendEmailPartage } from "../_shared/transport/email.ts";
import { destinatairesAdminsReseau, localeDeProfil, LOCALE_BOITE_COLLECTIVE } from "../_shared/context/network-admins.ts";
import { tMail, tMailTexte } from "../_shared/i18n/mail-strings.ts";
import { esc as echapperHtml, desechapper } from "../_shared/shared/format.ts";
import { secretValide } from "../_shared/core/egalite-constante.ts";
// F26 (19/10/2026) : le courriel était rédigé en pt-BR seul, dans le code, et son
// pied lisait FOOTER_TEXT (secret supprimé le 19/10, repli portugais en dur).
// Toutes les chaînes passent désormais par tMail (clés docperm.*), dans la langue
// de CHAQUE destinataire : celle de la bibliothèque (default_locale de
// v_library_notification_context) pour les coordinations, celle du profil pour
// les admins réseau, pt-BR pour la boîte collective. Le pied est le pied commun
// du réseau (layout.footerTextNetwork).
const SUPABASE_URL = mustEnv("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = mustSecretKey();
const WEBHOOK_SECRET = mustEnv("WEBHOOK_SECRET_NOTIFY_DOCUMENT_PERMISSION_REQUEST");
const SENDER_EMAIL = firstEnv([
  "SENDER_EMAIL"
], "admin@anarbib.org");
const SENDER_NAME = firstEnv([
  "SENDER_NAME"
], "AnarBib");
const REPLY_TO_EMAIL = firstEnv([
  "REPLY_TO_EMAIL",
  "ANARBIB_REPLY_TO_EMAIL"
], "");
const REPLY_TO_NAME = firstEnv([
  "REPLY_TO_NAME",
  "ANARBIB_ADMIN_NAME",
  "SENDER_NAME"
], "");
const ADMIN_EMAIL = firstEnv([
  "ADMIN_EMAIL",
  "ANARBIB_ADMIN_EMAIL"
], "");
const ADMIN_NAME = firstEnv([
  "ADMIN_NAME",
  "ANARBIB_ADMIN_NAME"
], "AnarBib");
const BRAND_NAME = firstEnv([
  "BRAND_NAME",
  "ANARBIB_BRAND_NAME"
], "AnarBib");
// #153.E TR-6.3 : cascade alignée sur le jeu de 5 variables du _shared/core/env.ts
// central. Ordre standard (cette EF n'est pas une EF réseau, pas de priorité
// particulière à NETWORK_LOGO_URL).
const LOGO_URL = firstEnv([
  "LOGO_URL",
  "LIBRARY_LOGO_URL",
  "ANARBIB_LOGO_URL",
  "NETWORK_LOGO_URL",
  "BLMF_LOGO_URL"
], "");
// F7 (02/09/2026) : la chaine essayait REGIMENTO_URL d'abord — un reglement
// n'est pas un manuel ; le secret (vide) est retire, la chaine dit ce qu'elle
// cherche.
const MANUAL_URL = firstEnv([
  "ANARBIB_MANUAL_URL"
], "");
// LIBRARIAN_PHONE n'est plus lu (16/10/2026) : numéro personnel global.
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});
function firstEnv(names, fallback = "") {
  for (const name of names){
    const value = (Deno.env.get(name) || "").trim();
    if (value) return value;
  }
  return fallback;
}
function mustEnv(name) {
  const value = (Deno.env.get(name) || "").trim();
  if (!value) throw new Error(`Missing required env: ${name}`);
  return value;
}
function mustEnvAny(names) {
  const value = firstEnv(names, "");
  if (!value) throw new Error(`Missing required env: one of ${names.join(", ")}`);
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
  // F26 (19/10/2026) : l'esc partagé, qui n'échappe pas deux fois une phrase de tMail
  return echapperHtml(value);
}
function firstFilled(...values) {
  for (const value of values){
    if (typeof value === "string" && value.trim()) return value.trim();
    if (value !== null && value !== undefined && value !== "") return String(value);
  }
  return "";
}
function firstNameOnly(value) {
  const s = String(value || "").trim();
  if (!s) return "";
  return s.split(/\s+/)[0] || "";
}
function isValidEmail(email) {
  const s = String(email || "").trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
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
function contactTarget(row) {
  const email = String(row?.contact_email || "").trim().toLowerCase();
  if (!isValidEmail(email)) return null;
  return {
    email,
    name: firstNameOnly(firstFilled(row?.contact_name, row?.contact_role)) || undefined
  };
}
function adminTarget() {
  const email = String(ADMIN_EMAIL || "").trim().toLowerCase();
  if (!isValidEmail(email)) return null;
  return {
    email,
    name: firstNameOnly(ADMIN_NAME) || undefined
  };
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
// retiré (cf. _shared/core/webhook.ts). verify_jwt = false ⇒ le Bearer n'était
// validé par personne, et `manual_test` est un drapeau fourni par l'appelant.
// Seul le secret webhook autorise désormais l'appel.
function authorizeWebhook(req, manualTest) {
  const gotSecret = String(req.headers.get("x-webhook-secret") || "").trim();
  const webhookOk = secretValide(WEBHOOK_SECRET, gotSecret);
  return {
    ok: webhookOk,
    webhookOk,
    dashboardTestOk: false
  };
}
async function fetchRequest(requestId) {
  const { data, error } = await supabaseAdmin.from("document_permission_requests").select("*").eq("id", requestId).maybeSingle();
  if (error) throw new Error(`document_permission_request_fetch_failed: ${error.message}`);
  return data || null;
}
async function fetchLibraries(ids) {
  const cleanIds = Array.from(new Set(ids.map((x)=>String(x || "").trim()).filter(Boolean)));
  const map = new Map();
  if (!cleanIds.length) return map;
  const { data, error } = await supabaseAdmin.from("libraries").select("id,name,short_name,slug").in("id", cleanIds);
  if (error) throw new Error(`libraries_fetch_failed: ${error.message}`);
  for (const row of data || []){
    map.set(String(row.id), row);
  }
  return map;
}
async function fetchContacts(ids) {
  const cleanIds = Array.from(new Set(ids.map((x)=>String(x || "").trim()).filter(Boolean)));
  const map = new Map();
  if (!cleanIds.length) return map;
  const { data, error } = await supabaseAdmin.from("library_contact_profiles").select("library_id,contact_name,contact_role,contact_email").in("library_id", cleanIds);
  if (error) throw new Error(`library_contact_profiles_fetch_failed: ${error.message}`);
  for (const row of data || []){
    map.set(String(row.library_id), row);
  }
  return map;
}
// Langue de courriel de chaque bibliothèque : la même source que les autres
// notify-* (ctx.default_locale de la vue de contexte). Une lecture qui échoue ne
// bloque pas l'avis : la bibliothèque le reçoit dans la langue de référence.
async function fetchLibraryLocales(ids) {
  const cleanIds = Array.from(new Set(ids.map((x)=>String(x || "").trim()).filter(Boolean)));
  const map = new Map();
  if (!cleanIds.length) return map;
  const { data, error } = await supabaseAdmin.from("v_library_notification_context").select("library_id,default_locale").in("library_id", cleanIds);
  if (error) {
    console.warn("notify-document-permission-request: default_locale illisible:", error.message);
    return map;
  }
  for (const row of data || []){
    map.set(String(row.library_id), localeDeProfil(row.default_locale));
  }
  return map;
}
function formatDateTime(isoOrDate, locale) {
  if (!isoOrDate) return "";
  const d = isoOrDate instanceof Date ? isoOrDate : new Date(isoOrDate);
  if (Number.isNaN(d.getTime())) return String(isoOrDate);
  const opts = {
    timeZone: "UTC",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  };
  try {
    return `${new Intl.DateTimeFormat(locale, opts).format(d)} UTC`;
  } catch  {
    return `${new Intl.DateTimeFormat("pt-BR", opts).format(d)} UTC`;
  }
}
function parseObjectRef(value) {
  const raw = String(value || "").trim();
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch  {
    return {
      raw
    };
  }
}
function docLabel(doc, locale) {
  if (!doc || typeof doc !== "object") return "";
  const title = firstFilled(doc.titulo, doc.title, doc.label, tMailTexte(locale, "docperm.doc.untitled"));
  const author = firstFilled(doc.autor, doc.author);
  const count = firstFilled(doc.exemplar_count, doc.count);
  const bits = [
    title
  ];
  if (author) bits.push(author);
  if (count) bits.push(tMailTexte(locale, "docperm.doc.copies", { count }));
  return bits.join(" — ");
}
// Type de demande : libellé connu, sinon la valeur telle qu'enregistrée.
function actionLabel(action, locale) {
  const v = String(action || "").trim();
  if (!v) return "—";
  const cle = `docperm.action.${v}`;
  const t = tMailTexte(locale, cle);
  return t === cle ? v : t;
}
function renderEmail(opts) {
  const detailsHtml = (opts.details || []).filter((x)=>x && x.label && x.value).map((item)=>`
      <tr>
        <td style="padding:8px 0;vertical-align:top;width:170px;color:#9ca3af;font-weight:700;">${esc(item.label)}</td>
        <td style="padding:8px 0;vertical-align:top;color:#f3f4f6;">${esc(item.value)}</td>
      </tr>
    `).join("");
  // #153.E TR-6.1 : repli logo uniformisé — logo absent => nom de marque en
  // texte (patron notify-network-weekly-report), et non un bloc vide.
  const logoHtml = LOGO_URL
    ? `<div style="margin-bottom:18px;"><img src="${esc(LOGO_URL)}" alt="${esc(BRAND_NAME)}" style="max-width:140px;height:auto;"></div>`
    : `<div style="margin-bottom:18px;font-size:20px;font-weight:700;color:#ffffff;">${esc(BRAND_NAME)}</div>`;
  const footerHtml = opts.footerHtml ? `<div style="margin-top:22px;color:#d1d5db;font-size:12px;line-height:1.55;">${opts.footerHtml}</div>` : "";
  const html = `<!doctype html>
<html lang="${esc(opts.locale || LOCALE_BOITE_COLLECTIVE)}">
  <head><meta charset="utf-8"><meta name="color-scheme" content="dark"><meta name="supported-color-schemes" content="dark"></head>
  <body style="margin:0;padding:0;background:#0b0b0d;color:#f3f4f6;font-family:Arial,Helvetica,sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${esc(opts.preheader || opts.title)}</div>
    <div style="max-width:720px;margin:0 auto;padding:24px;">
      <div style="background:#111216;color:#f3f4f6;border:1px solid #262932;border-radius:18px;padding:24px;box-shadow:0 18px 40px rgba(0,0,0,.32);">
        ${logoHtml}
        <h1 style="margin:0 0 12px;font-size:24px;line-height:1.25;color:#ffffff;">${esc(opts.title)}</h1>
        ${opts.greeting ? `<p style="margin:0 0 14px;color:#f3f4f6;font-size:15px;line-height:1.6;">${esc(opts.greeting)}</p>` : ""}
        <div style="margin:0 0 18px;color:#f3f4f6;font-size:15px;line-height:1.65;">${opts.introHtml}</div>
        ${detailsHtml ? `<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="width:100%;border-top:1px solid #262932;padding-top:8px;">${detailsHtml}</table>` : ""}
        ${footerHtml}
      </div>
    </div>
  </body>
</html>`;
  const textLines = [
    opts.title,
    "",
    opts.greeting || "",
    stripHtml(opts.introHtml),
    "",
    ...(opts.details || []).flatMap((item)=>item?.label && item?.value ? [
        `${item.label}: ${item.value}`
      ] : []),
    "",
    stripHtml(opts.footerHtml || "")
  ].filter(Boolean);
  return {
    html,
    text: textLines.join("\n")
  };
}
// Version texte : retirer les balises laissait les entités (« l&#039;échange ») ;
// on les rend à la lettre.
function stripHtml(value) {
  return desechapper(String(value || "").replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>/gi, "\n").replace(/<[^>]+>/g, "")).replace(/\n{3,}/g, "\n\n").trim();
}
function footerHtml(locale) {
  const parts = [];
  if (MANUAL_URL) parts.push(`${esc(tMailTexte(locale, "docperm.manual"))}: <a href="${esc(MANUAL_URL)}" style="color:#fff;text-decoration:underline;">${esc(tMailTexte(locale, "layout.regimentoOpen"))}</a>`);
  parts.push(esc(tMailTexte(locale, "layout.footerTextNetwork")));
  return parts.join("<br>");
}
// ============================================================================
// Transport mail — envoi via Resend
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend) : R.3.2 avait introduit un dispatch
// Brevo/Resend pilote par MAIL_PROVIDER ; R.6 (05/06/2026) a retire Brevo.
// sendEmail() appelle desormais directement sendViaResend(). Le secret
// MAIL_PROVIDER a ete retire de Supabase en R.7 (08/06/2026) ; n'est
// plus lu par le code.
//
// CONTRAT DE RETOUR LOCAL : string brute en succes, throw sur erreur HTTP —
// safeSendEmail (try/catch) inchange.
// ============================================================================
// renvoie la string brute, throw sur erreur HTTP.
// --- Envoi : une seule implementation, celle de _shared (F7, lot 2, 24/09/2026) ---
// Le routage est passe EXPLICITEMENT et reste celui d'hier : expediteur depuis
// l'environnement, reply_to seulement si REPLY_TO_EMAIL est une adresse valide
// (vide en production, cf. F14 et la liste fermee de reply-to-meme-domaine).
// Contrat local inchange : string brute en succes, throw sur erreur —
// safeSendEmail (try/catch) ne bouge pas.
async function sendEmail(opts) {
  return await sendEmailPartage({
    toEmail: opts.toEmail,
    toName: opts.toName,
    subject: opts.subject,
    html: opts.html,
    text: opts.text,
    routing: {
      senderEmail: SENDER_EMAIL,
      senderName: SENDER_NAME,
      replyToEmail: isValidEmail(REPLY_TO_EMAIL) ? REPLY_TO_EMAIL : null,
      replyToName: REPLY_TO_NAME
    },
    label: "document-permission-request"
  });
}
async function safeSendEmail(target, subject, html, text, label) {
  const email = String(target?.email || "").trim().toLowerCase();
  if (!isValidEmail(email)) {
    return {
      ok: false,
      skipped: true,
      label,
      reason: "invalid_email",
      email
    };
  }
  try {
    const response = await sendEmail({
      toEmail: email,
      toName: target?.name,
      subject,
      html,
      text
    });
    return {
      ok: true,
      label,
      email,
      response
    };
  } catch (error) {
    return {
      ok: false,
      label,
      email,
      error: String(error?.message || error)
    };
  }
}
function buildPayloadDetails(row, requester, target, locale) {
  const parsed = parseObjectRef(row.object_ref);
  const localDoc = parsed && typeof parsed === "object" ? parsed.local_document : null;
  const partnerDoc = parsed && typeof parsed === "object" ? parsed.partner_document : null;
  return [
    {
      label: tMailTexte(locale, "docperm.lbl.requester"),
      value: firstFilled(requester?.short_name, requester?.name, row.requester_library_id)
    },
    {
      label: tMailTexte(locale, "docperm.lbl.target"),
      value: firstFilled(target?.short_name, target?.name, row.target_library_id)
    },
    {
      label: tMailTexte(locale, "docperm.lbl.action"),
      value: actionLabel(row.requested_action, locale)
    },
    {
      label: tMailTexte(locale, "docperm.lbl.localDoc"),
      value: firstFilled(docLabel(localDoc, locale), "—")
    },
    {
      label: tMailTexte(locale, "docperm.lbl.partnerDoc"),
      value: firstFilled(docLabel(partnerDoc, locale), "—")
    },
    {
      label: tMailTexte(locale, "docperm.lbl.createdAt"),
      value: formatDateTime(row.created_at, locale) || "—"
    },
    ...row.decided_at ? [
      {
        label: tMailTexte(locale, "docperm.lbl.decidedAt"),
        value: formatDateTime(row.decided_at, locale) || "—"
      }
    ] : [],
    ...row.response_note ? [
      {
        label: tMailTexte(locale, "docperm.lbl.responseNote"),
        value: row.response_note
      }
    ] : []
  ];
}
// Noms en gras, déjà échappés : les paramètres *Html de tMail ne sont pas réécrits.
function gras(value) {
  return `<b>${esc(value)}</b>`;
}
function citation(value) {
  return `<blockquote style="margin:0 0 0 14px;padding-left:14px;border-left:3px solid #7f1d1d;color:#f3f4f6;">${esc(value).replace(/\n/g, "<br>")}</blockquote>`;
}
function libraryNames(row, requester, target, locale) {
  return {
    requesterName: firstFilled(requester?.short_name, requester?.name, tMailTexte(locale, "docperm.lbl.requester")),
    targetName: firstFilled(target?.short_name, target?.name, tMailTexte(locale, "docperm.lbl.target"))
  };
}
function buildOutgoingMessage(row, requester, target, locale) {
  const { requesterName, targetName } = libraryNames(row, requester, target, locale);
  return {
    subject: `[${BRAND_NAME}] ${tMailTexte(locale, "docperm.created.subject", { requester: requesterName, target: targetName })}`,
    title: tMailTexte(locale, "docperm.created.title"),
    introHtml: [
      `<p>${tMail(locale, "docperm.created.p1", { requesterHtml: gras(requesterName), targetHtml: gras(targetName), brandHtml: gras(BRAND_NAME) })}</p>`,
      `<p>${tMail(locale, "docperm.created.p2")}</p>`,
      `<p>${tMail(locale, "docperm.created.p3")}</p>`,
      citation(row.message),
      `<p style="margin-top:16px;">${tMail(locale, "docperm.created.p4", { moduleHtml: gras(tMailTexte(locale, "docperm.module")), pageHtml: gras(tMailTexte(locale, "docperm.page")) })}</p>`
    ].join("")
  };
}
function buildRequesterAckMessage(row, requester, target, locale) {
  const { requesterName, targetName } = libraryNames(row, requester, target, locale);
  return {
    subject: `[${BRAND_NAME}] ${tMailTexte(locale, "docperm.ack.subject", { requester: requesterName, target: targetName })}`,
    title: tMailTexte(locale, "docperm.ack.title"),
    introHtml: [
      `<p>${tMail(locale, "docperm.ack.p1", { requesterHtml: gras(requesterName), targetHtml: gras(targetName) })}</p>`,
      `<p>${tMail(locale, "docperm.ack.p2", { moduleHtml: gras(tMailTexte(locale, "docperm.module")) })}</p>`,
      `<p>${tMail(locale, "docperm.ack.p3")}</p>`,
      `<p>${tMail(locale, "docperm.ack.p4")}</p>`,
      citation(row.message)
    ].join("")
  };
}
function buildDecisionMessage(row, requester, target, accepted, locale) {
  const { requesterName, targetName } = libraryNames(row, requester, target, locale);
  const issue = accepted ? "accepted" : "refused";
  const noms = { requesterHtml: gras(requesterName), targetHtml: gras(targetName) };
  return {
    subject: `[${BRAND_NAME}] ${tMailTexte(locale, "docperm.decision.subject", { target: targetName, verdict: tMailTexte(locale, `docperm.verdict.${issue}`) })}`,
    title: tMailTexte(locale, `docperm.${issue}.title`),
    introHtml: [
      `<p>${tMail(locale, `docperm.${issue}.p1`, noms)}</p>`,
      `<p>${tMail(locale, `docperm.${issue}.p2`)}</p>`,
      row.response_note ? `<p>${tMail(locale, "docperm.noteIntro")}</p>${citation(row.response_note)}` : `<p>${tMail(locale, `docperm.${issue}.noNote`, { moduleHtml: gras(tMailTexte(locale, "docperm.module")) })}</p>`
    ].join("")
  };
}
serve(async (req)=>{
  try {
    if (req.method !== "POST") return jsonResponse(405, {
      ok: false,
      error: "method_not_allowed"
    });
    const { payload, manualTest } = await parsePayload(req);
    const auth = authorizeWebhook(req, manualTest);
    if (!auth.ok) return jsonResponse(401, {
      ok: false,
      error: "unauthorized"
    });
    const requestId = String(payload?.request_id || "").trim();
    const eventType = String(payload?.event_type || "").trim();
    if (!requestId) return jsonResponse(400, {
      ok: false,
      error: "missing_request_id"
    });
    if (![
      "document_permission_request_created",
      "document_permission_request_accepted",
      "document_permission_request_refused"
    ].includes(eventType)) {
      return jsonResponse(400, {
        ok: false,
        error: "invalid_event_type"
      });
    }
    // Mode simulation. Défaut FALSE, volontairement : les dispatchers SQL
    // (fn_enqueue_document_permission_request_notification) n'envoient pas ce
    // drapeau et doivent continuer à livrer normalement. C'est l'inverse de
    // notify-security-notice, où dry_run vaut true par défaut parce que cette
    // fonction-là est déclenchée à la main.
    //
    // Pourquoi ce mode : ce flux est reste MORT depuis l'origine (le secret
    // WEBHOOK_SECRET_NOTIFY_DOCUMENT_PERMISSION_REQUEST n'existait pas dans le
    // Vault, cf. migration 20260817125212), et il n'a qu'une seule demande en
    // base, ancienne et deja acceptee. Impossible de l'eprouver de bout en bout
    // sans ecrire a de vraies bibliotheques du reseau a propos d'une demande
    // classee. dry_run resout ca durablement : tout est resolu et rendu
    // (destinataires, sujets, gabarits), rien n'est livre.
    const dryRun = payload?.dry_run === true;
    const send = (target, subject, html, text, label, locale)=>dryRun ? Promise.resolve({
        ok: true,
        simulated: true,
        label,
        to: target?.email ?? null,
        locale,
        subject
      }) : safeSendEmail(target, subject, html, text, label);

    const row = await fetchRequest(requestId);
    if (!row) return jsonResponse(404, {
      ok: false,
      error: "request_not_found",
      request_id: requestId
    });
    const libraries = await fetchLibraries([
      row.requester_library_id,
      row.target_library_id
    ]);
    const contacts = await fetchContacts([
      row.requester_library_id,
      row.target_library_id
    ]);
    const locales = await fetchLibraryLocales([
      row.requester_library_id,
      row.target_library_id
    ]);
    const requester = libraries.get(String(row.requester_library_id));
    const target = libraries.get(String(row.target_library_id));
    const requesterContact = contacts.get(String(row.requester_library_id));
    const targetContact = contacts.get(String(row.target_library_id));
    const requesterLocale = locales.get(String(row.requester_library_id)) || LOCALE_BOITE_COLLECTIVE;
    const targetLocale = locales.get(String(row.target_library_id)) || LOCALE_BOITE_COLLECTIVE;
    // Un courriel rendu dans UNE langue : sujet, corps, détails et pied.
    const rendre = (build, locale, contact)=>{
      const message = build(locale);
      const nom = firstNameOnly(firstFilled(contact?.contact_name, contact?.contact_role));
      const rendu = renderEmail({
        locale,
        title: message.title,
        preheader: message.title,
        greeting: nom ? tMailTexte(locale, "greeting.named", { name: nom }) : "",
        introHtml: message.introHtml,
        details: buildPayloadDetails(row, requester, target, locale),
        footerHtml: footerHtml(locale)
      });
      return { subject: message.subject, html: rendu.html, text: rendu.text, locale };
    };
    const sends = [];
    const envoyer = (cible, mail, label)=>sends.push(send(cible, mail.subject, mail.html, mail.text, label, mail.locale));
    if (eventType === "document_permission_request_created") {
      const outgoing = (loc)=>buildOutgoingMessage(row, requester, target, loc);
      const requesterAck = (loc)=>buildRequesterAckMessage(row, requester, target, loc);
      envoyer(contactTarget(targetContact), rendre(outgoing, targetLocale, targetContact), "target_library");
      envoyer(contactTarget(requesterContact), rendre(requesterAck, requesterLocale, requesterContact), "requester_copy");
      // F15 (24/09/2026) : la copie réseau part aux admins actif·ves ET à la
      // boîte collective (module partagé _shared/context/network-admins.ts) ;
      // ADMIN_EMAIL n'est plus qu'un repli si ni la table ni la variable ne
      // donnent personne. F26 (19/10/2026) : chacun·e dans sa langue.
      let admins = await destinatairesAdminsReseau(supabaseAdmin);
      if (!admins.length) {
        const a = adminTarget();
        if (a) admins = [{ ...a, locale: LOCALE_BOITE_COLLECTIVE }];
      }
      for (const a of admins) {
        envoyer({ email: a.email, name: a.name }, rendre(outgoing, a.locale || LOCALE_BOITE_COLLECTIVE, null), "network_admin_copy");
      }
    }
    if (eventType === "document_permission_request_accepted" || eventType === "document_permission_request_refused") {
      const accepted = eventType === "document_permission_request_accepted";
      const decision = (loc)=>buildDecisionMessage(row, requester, target, accepted, loc);
      envoyer(contactTarget(requesterContact), rendre(decision, requesterLocale, requesterContact), "requester_library");
      envoyer(contactTarget(targetContact), rendre(decision, targetLocale, targetContact), "target_copy");
    }
    const results = await Promise.all(sends);
    return jsonResponse(200, {
      ok: true,
      dry_run: dryRun,
      request_id: requestId,
      event_type: eventType,
      requester_library: firstFilled(requester?.short_name, requester?.name, row.requester_library_id),
      target_library: firstFilled(target?.short_name, target?.name, row.target_library_id),
      results
    });
  } catch (error) {
    console.error("notify-document-permission-request failed:", error);
    return jsonResponse(500, {
      ok: false,
      error: String(error?.message || error)
    });
  }
});
