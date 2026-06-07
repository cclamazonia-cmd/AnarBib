import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const SUPABASE_URL = mustEnv("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = mustEnv("SUPABASE_SERVICE_ROLE_KEY");
const WEBHOOK_SECRET = mustEnv("WEBHOOK_SECRET_NOTIFY_DOCUMENT_PERMISSION_REQUEST");
const SENDER_EMAIL = firstEnv([
  "SENDER_EMAIL",
  "ANARBIB_SENDER_EMAIL"
], "admin@anarbib.org");
const SENDER_NAME = firstEnv([
  "SENDER_NAME",
  "ANARBIB_SENDER_NAME"
], "AnarBib");
const REPLY_TO_EMAIL = firstEnv([
  "REPLY_TO_EMAIL",
  "ANARBIB_REPLY_TO_EMAIL"
], "");
const REPLY_TO_NAME = firstEnv([
  "REPLY_TO_NAME",
  "ANARBIB_ADMIN_NAME",
  "ANARBIB_SENDER_NAME"
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
const FOOTER_TEXT = firstEnv([
  "FOOTER_TEXT",
  "ANARBIB_FOOTER_TEXT"
], "Em caso de dúvida, responda a este e-mail.");
const MANUAL_URL = firstEnv([
  "REGIMENTO_URL",
  "ANARBIB_MANUAL_URL"
], "");
const LIBRARIAN_PHONE = firstEnv([
  "LIBRARIAN_PHONE",
  "ANARBIB_LIBRARIAN_PHONE"
], "");
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
  return String(value ?? "").replace(/[&<>"']/g, (c)=>({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;"
    })[c]);
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
function authorizeWebhook(req, manualTest) {
  const gotSecret = String(req.headers.get("x-webhook-secret") || "").trim();
  const authz = String(req.headers.get("authorization") || "").trim();
  const webhookOk = !!gotSecret && gotSecret === WEBHOOK_SECRET;
  const dashboardTestOk = manualTest && /^Bearer\s+/i.test(authz);
  return {
    ok: webhookOk || dashboardTestOk,
    webhookOk,
    dashboardTestOk
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
function docLabel(doc) {
  if (!doc || typeof doc !== "object") return "";
  const title = firstFilled(doc.titulo, doc.title, doc.label, "Documento");
  const author = firstFilled(doc.autor, doc.author);
  const count = firstFilled(doc.exemplar_count, doc.count);
  const bits = [
    title
  ];
  if (author) bits.push(author);
  if (count) bits.push(`${count} exemplar(es)`);
  return bits.join(" — ");
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
<html lang="pt-BR">
  <body style="margin:0;padding:0;background:#0b0b0d;color:#f3f4f6;font-family:Arial,Helvetica,sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;">${esc(opts.preheader || opts.title)}</div>
    <div style="max-width:720px;margin:0 auto;padding:24px;">
      <div style="background:#111216;border:1px solid #262932;border-radius:18px;padding:24px;box-shadow:0 18px 40px rgba(0,0,0,.32);">
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
function stripHtml(value) {
  return String(value || "").replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>/gi, "\n").replace(/<[^>]+>/g, "").replace(/\n{3,}/g, "\n\n").trim();
}
function footerHtml() {
  const parts = [];
  if (MANUAL_URL) parts.push(`Manual / regimento da rede: <a href="${esc(MANUAL_URL)}" style="color:#fff;text-decoration:underline;">abrir</a>`);
  if (LIBRARIAN_PHONE) parts.push(`Contato rápido: <b>${esc(LIBRARIAN_PHONE)}</b>`);
  parts.push(esc(FOOTER_TEXT));
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
function formatMailAddress(email, name) {
  const n = String(name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Resend (cf. spec §4.4) ---------------------------------
// Format Resend : auth Bearer, from "Nom <email>", to tableau de strings,
// reply_to "Nom <email>", corps html/text. Contrat identique a sendViaBrevo :
// renvoie la string brute, throw sur erreur HTTP.
async function sendViaResend(opts) {
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (!resendKey) {
    throw new Error("RESEND_API_KEY absente des secrets Edge Function");
  }
  const payload: Record<string, unknown> = {
    from: formatMailAddress(SENDER_EMAIL, SENDER_NAME),
    to: [opts.toEmail],
    subject: opts.subject,
    html: opts.html,
    text: opts.text
  };
  if (isValidEmail(REPLY_TO_EMAIL)) {
    payload.reply_to = formatMailAddress(REPLY_TO_EMAIL, REPLY_TO_NAME);
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
async function sendEmail(opts) {
  console.log(`[document-permission-request] envoi via resend`);
  return await sendViaResend(opts);
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
function buildPayloadDetails(row, requester, target) {
  const parsed = parseObjectRef(row.object_ref);
  const localDoc = parsed && typeof parsed === "object" ? parsed.local_document : null;
  const partnerDoc = parsed && typeof parsed === "object" ? parsed.partner_document : null;
  return [
    {
      label: "Biblioteca solicitante",
      value: firstFilled(requester?.short_name, requester?.name, row.requester_library_id)
    },
    {
      label: "Biblioteca destinatária",
      value: firstFilled(target?.short_name, target?.name, row.target_library_id)
    },
    {
      label: "Tipo de solicitação",
      value: firstFilled(row.requested_action, "—")
    },
    {
      label: "Documento que a solicitante pode disponibilizar",
      value: firstFilled(docLabel(localDoc), "—")
    },
    {
      label: "Documento que a solicitante gostaria de receber",
      value: firstFilled(docLabel(partnerDoc), "—")
    },
    {
      label: "Registro inicial",
      value: formatDateTimeBR(row.created_at) || "—"
    },
    ...row.decided_at ? [
      {
        label: "Resposta registrada em",
        value: formatDateTimeBR(row.decided_at) || "—"
      }
    ] : [],
    ...row.response_note ? [
      {
        label: "Observação da resposta",
        value: row.response_note
      }
    ] : []
  ];
}
function buildOutgoingMessage(row, requester, target) {
  const requesterName = firstFilled(requester?.short_name, requester?.name, "biblioteca solicitante");
  const targetName = firstFilled(target?.short_name, target?.name, "biblioteca destinatária");
  return {
    subject: `[${BRAND_NAME}] Consulta de troca documental interbibliotecas — ${requesterName} ↔ ${targetName}`,
    title: "Consulta de troca documental interbibliotecas",
    introHtml: [
      `<p>A biblioteca <b>${esc(requesterName)}</b> registrou uma consulta de troca documental dirigida a <b>${esc(targetName)}</b>, no âmbito da rede <b>${esc(BRAND_NAME)}</b>.</p>`,
      `<p>Trata-se de uma proposta inicial de discernimento, não de um compromisso fechado. A ideia é verificar se a troca faz sentido para os dois acervos, considerando duplicidade, pertinência local, estado físico e viabilidade concreta de circulação entre as bibliotecas.</p>`,
      `<p>Mensagem registrada pela biblioteca solicitante:</p>`,
      `<blockquote style="margin:0 0 0 14px;padding-left:14px;border-left:3px solid #7f1d1d;color:#f3f4f6;">${esc(row.message).replace(/\n/g, "<br>")}</blockquote>`,
      `<p style="margin-top:16px;">Se houver interesse, a resposta ideal é registrar a decisão no módulo <b>Trocas interbibliotecas</b> da página <b>Biblioteca</b>, para que o acompanhamento permaneça visível e comum às duas bibliotecas.</p>`
    ].join("")
  };
}
function buildRequesterAckMessage(row, requester, target) {
  const requesterName = firstFilled(requester?.short_name, requester?.name, "sua biblioteca");
  const targetName = firstFilled(target?.short_name, target?.name, "biblioteca parceira");
  return {
    subject: `[${BRAND_NAME}] Consulta de troca registrada — ${requesterName} ↔ ${targetName}`,
    title: "Consulta de troca registrada",
    introHtml: [
      `<p>A consulta de troca aberta por <b>${esc(requesterName)}</b> para <b>${esc(targetName)}</b> foi registrada no sistema.</p>`,
      `<p>Quando o webhook estiver ativo, o aviso para a biblioteca parceira é disparado automaticamente. Em paralelo, a proposta continua acompanhável no módulo <b>Trocas interbibliotecas</b>.</p>`,
      `<p>Esta etapa serve para abrir o diálogo entre bibliotecas e permitir uma avaliação bibliográfica, política e material antes de qualquer confirmação definitiva.</p>`,
      `<p>Mensagem registrada:</p>`,
      `<blockquote style="margin:0 0 0 14px;padding-left:14px;border-left:3px solid #7f1d1d;color:#f3f4f6;">${esc(row.message).replace(/\n/g, "<br>")}</blockquote>`
    ].join("")
  };
}
function buildDecisionMessage(row, requester, target, accepted) {
  const requesterName = firstFilled(requester?.short_name, requester?.name, "biblioteca solicitante");
  const targetName = firstFilled(target?.short_name, target?.name, "biblioteca destinatária");
  return {
    subject: `[${BRAND_NAME}] Resposta à consulta de troca — ${targetName}: ${accepted ? "aceita" : "recusada"}`,
    title: accepted ? "Consulta de troca aceita" : "Consulta de troca recusada",
    introHtml: accepted ? [
      `<p>A biblioteca <b>${esc(targetName)}</b> aceitou a consulta de troca enviada por <b>${esc(requesterName)}</b>.</p>`,
      `<p>Esta aceitação abre a fase de acerto fino entre as bibliotecas: conferência dos exemplares, verificação do estado físico, definição da quantidade exata a trocar e combinação de retirada, envio ou entrega.</p>`,
      row.response_note ? `<p>Observação registrada pela biblioteca destinatária:</p><blockquote style="margin:0 0 0 14px;padding-left:14px;border-left:3px solid #7f1d1d;color:#f3f4f6;">${esc(row.response_note).replace(/\n/g, "<br>")}</blockquote>` : `<p>Não foi registrada observação complementar. Vale combinar os próximos passos diretamente entre as bibliotecas e manter o andamento anotado no módulo interbibliotecas.</p>`
    ].join("") : [
      `<p>A biblioteca <b>${esc(targetName)}</b> recusou a consulta de troca enviada por <b>${esc(requesterName)}</b>.</p>`,
      `<p>Isso não encerra o vínculo entre as bibliotecas: apenas indica que esta proposta específica não pareceu adequada neste momento, seja por prioridade local do acervo, seja por estado dos exemplares ou por outro critério interno.</p>`,
      row.response_note ? `<p>Observação registrada pela biblioteca destinatária:</p><blockquote style="margin:0 0 0 14px;padding-left:14px;border-left:3px solid #7f1d1d;color:#f3f4f6;">${esc(row.response_note).replace(/\n/g, "<br>")}</blockquote>` : `<p>Não foi registrada observação complementar. Uma nova proposta poderá ser feita mais adiante, se houver outra combinação bibliográfica mais pertinente.</p>`
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
    const requester = libraries.get(String(row.requester_library_id));
    const target = libraries.get(String(row.target_library_id));
    const requesterContact = contacts.get(String(row.requester_library_id));
    const targetContact = contacts.get(String(row.target_library_id));
    const details = buildPayloadDetails(row, requester, target);
    const sends = [];
    if (eventType === "document_permission_request_created") {
      const outgoing = buildOutgoingMessage(row, requester, target);
      const requesterAck = buildRequesterAckMessage(row, requester, target);
      const toTarget = renderEmail({
        title: outgoing.title,
        preheader: outgoing.title,
        greeting: firstNameOnly(firstFilled(targetContact?.contact_name, targetContact?.contact_role)),
        introHtml: outgoing.introHtml,
        details,
        footerHtml: footerHtml()
      });
      const toRequester = renderEmail({
        title: requesterAck.title,
        preheader: requesterAck.title,
        greeting: firstNameOnly(firstFilled(requesterContact?.contact_name, requesterContact?.contact_role)),
        introHtml: requesterAck.introHtml,
        details,
        footerHtml: footerHtml()
      });
      sends.push(safeSendEmail(contactTarget(targetContact), outgoing.subject, toTarget.html, toTarget.text, "target_library"));
      sends.push(safeSendEmail(contactTarget(requesterContact), requesterAck.subject, toRequester.html, toRequester.text, "requester_copy"));
      const admin = adminTarget();
      if (admin) {
        sends.push(safeSendEmail(admin, outgoing.subject, toTarget.html, toTarget.text, "network_admin_copy"));
      }
    }
    if (eventType === "document_permission_request_accepted" || eventType === "document_permission_request_refused") {
      const accepted = eventType === "document_permission_request_accepted";
      const decision = buildDecisionMessage(row, requester, target, accepted);
      const toRequester = renderEmail({
        title: decision.title,
        preheader: decision.title,
        greeting: firstNameOnly(firstFilled(requesterContact?.contact_name, requesterContact?.contact_role)),
        introHtml: decision.introHtml,
        details,
        footerHtml: footerHtml()
      });
      const toTarget = renderEmail({
        title: decision.title,
        preheader: decision.title,
        greeting: firstNameOnly(firstFilled(targetContact?.contact_name, targetContact?.contact_role)),
        introHtml: decision.introHtml,
        details,
        footerHtml: footerHtml()
      });
      sends.push(safeSendEmail(contactTarget(requesterContact), decision.subject, toRequester.html, toRequester.text, "requester_library"));
      sends.push(safeSendEmail(contactTarget(targetContact), decision.subject, toTarget.html, toTarget.text, "target_copy"));
    }
    const results = await Promise.all(sends);
    return jsonResponse(200, {
      ok: true,
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
