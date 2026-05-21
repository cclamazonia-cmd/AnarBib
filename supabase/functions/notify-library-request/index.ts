import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { inlineLogosInHtml } from "../_shared/mail/inline-images.ts";
const SUPABASE_URL = mustEnv("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = mustEnv("SUPABASE_SERVICE_ROLE_KEY");
const BREVO_KEY = mustEnv("BREVO_API_KEY_NOTIFICATIONS");
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
  const { data, error } = await supabaseAdmin.from("library_requests").select("*").eq("id", requestId).maybeSingle();
  if (error) throw new Error(`library_request_fetch_failed: ${error.message}`);
  return data || null;
}
async function fetchProfile(profileId) {
  const id = String(profileId || "").trim();
  if (!id) return null;
  const { data, error } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,public_id").eq("id", id).maybeSingle();
  if (error) throw new Error(`profile_fetch_failed: ${error.message}`);
  return data || null;
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
function footerHtml() {
  const parts = [];
  if (REGIMENTO_URL) {
    parts.push(`Regimento da rede: <a href="${esc(REGIMENTO_URL)}" style="color:#fff;text-decoration:underline;">abrir</a>`);
  }
  if (LIBRARIAN_PHONE) {
    parts.push(`Contato rápido: <b>${esc(LIBRARIAN_PHONE)}</b>`);
  }
  parts.push(esc(FOOTER_TEXT));
  return parts.join("<br>");
}
function footerText() {
  const parts = [];
  if (REGIMENTO_URL) parts.push(`Regimento da rede: ${REGIMENTO_URL}`);
  if (LIBRARIAN_PHONE) parts.push(`Contato rápido: ${LIBRARIAN_PHONE}`);
  parts.push(FOOTER_TEXT);
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
                  <div style="font-size:13px;color:#cfcfcf;line-height:1.2;">Solicitação institucional · notificação automática</div>
                </div>
              </div>
              <div style="height:3px;background:#c00000;"></div>
              <div style="padding:18px;">
                <h1 style="margin:0 0 12px;font-size:20px;line-height:1.25;">${esc(opts.title)}</h1>
                ${greetingHtml}
                <div style="font-size:16px;line-height:1.55;color:#f2f2f2;">${opts.introHtml}</div>
                ${detailsHtml}
                <div style="margin:16px 0 0;font-size:13px;line-height:1.5;color:#cfcfcf;">${footerHtml()}</div>
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
    footerText()
  ].filter((line, index, arr)=>!(line === "" && arr[index - 1] === "")).join("\n");
  return {
    html,
    text
  };
}
// ============================================================================
// Transport mail — wrapper neutre + dispatch par provider
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend), sous-paquet R.3.2 (EF #5).
// Spec : docs/specs/spec-migration-mail-resend.md (v0.2), §4.3 et §4.5.
//
// Decision §4.3 : EXTRACTION PROPRE. sendBrevoEmail etait deja une fonction
// isolee ; on la dedouble en sendViaBrevo / sendViaResend, exposees derriere
// un wrapper neutre sendEmail() qui dispatche selon MAIL_PROVIDER.
//
// §4.5 : l'inlining des logos (inlineLogosInHtml) est INCONDITIONNEL et commun
// aux deux providers. On le factorise dans sendEmail(), AVANT le dispatch :
// les deux implementations recoivent donc du HTML deja inline. Pas de
// duplication du bloc try/catch.
//
// Signature positionnelle (target, subject, html, text) conservee : c'est le
// contrat que consomme safeSendEmail. Contrat de retour : string + throw.
//
// Tant que MAIL_PROVIDER n'est pas "resend", comportement = avant-R.3 (brevo).
// ============================================================================
const VALID_MAIL_PROVIDERS = new Set(["brevo", "resend"]);
function resolveMailProvider() {
  const raw = (Deno.env.get("MAIL_PROVIDER") || "brevo").trim().toLowerCase();
  if (!VALID_MAIL_PROVIDERS.has(raw)) {
    console.warn(`[library-request] MAIL_PROVIDER="${raw}" inconnu, repli sur brevo`);
    return "brevo";
  }
  return raw;
}
function formatMailAddress(email, name) {
  const n = String(name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Brevo --------------------------------------------------
// htmlInlined : HTML deja passe par inlineLogosInHtml (factorise dans sendEmail).
async function sendViaBrevo(target, subject, htmlInlined, text) {
  const payload = {
    sender: {
      name: BRAND_NAME,
      email: SENDER_EMAIL
    },
    to: [
      {
        email: target.email,
        ...target.name ? {
          name: target.name
        } : {}
      }
    ],
    subject,
    htmlContent: htmlInlined,
    textContent: text
  };
  if (isValidEmail(ADMIN_EMAIL)) {
    payload.replyTo = {
      email: ADMIN_EMAIL.trim().toLowerCase(),
      ...ADMIN_NAME ? {
        name: ADMIN_NAME
      } : {}
    };
  }
  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "api-key": BREVO_KEY
    },
    body: JSON.stringify(payload)
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`Brevo error HTTP ${res.status}: ${body}`);
  return body;
}
// --- Implementation Resend (nouvelle, cf. spec §4.4) -----------------------
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
// Inline les logos une fois (spec §4.5), puis dispatche selon MAIL_PROVIDER.
async function sendEmail(target, subject, html, text) {
  // Inlining des logos Supabase Storage en data URI base64 — inconditionnel,
  // commun aux deux providers. Defensif : en cas d'echec, HTML d'origine.
  let htmlInlined = html;
  if (html && typeof html === "string") {
    try {
      htmlInlined = await inlineLogosInHtml(html);
    } catch (e) {
      console.warn(`notify-library-request: inlineLogosInHtml failed (mail sent anyway):`, e);
    }
  }
  const provider = resolveMailProvider();
  console.log(`[library-request] envoi via ${provider}`);
  if (provider === "resend") {
    return await sendViaResend(target, subject, htmlInlined, text);
  }
  return await sendViaBrevo(target, subject, htmlInlined, text);
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
function statusLabel(status) {
  return ({
    pendente: "Pendente",
    em_analise: "Em análise",
    aprovada: "Aprovada",
    recusada: "Recusada",
    arquivada: "Arquivada"
  })[status] || status || "—";
}
function projectStageLabel(value) {
  return ({
    em_formacao: "Em formação",
    em_organizacao: "Em organização",
    em_funcionamento: "Já em funcionamento"
  })[value] || value || "—";
}
function firstManagerLabel(value) {
  return ({
    sim: "Sim",
    nao: "Não",
    a_definir: "A definir"
  })[value] || value || "—";
}
function normalizeReviewNotesForEmail(value, stripComplementPrefix = false) {
  const raw = String(value || "").trim();
  if (!raw) return "";
  if (!stripComplementPrefix) return raw;
  return raw.replace(/^pedido\s+de\s+complemento\s*:\s*/i, "").trim() || raw;
}
function commonDetails(row) {
  return [
    {
      label: "Biblioteca",
      value: row.library_name
    },
    {
      label: "Sigla",
      value: row.library_short_name || "—"
    },
    {
      label: "Local",
      value: [
        row.city,
        row.state_region,
        row.country
      ].filter(Boolean).join(" · ") || "—"
    },
    {
      label: "Situação",
      value: projectStageLabel(row.project_stage)
    },
    {
      label: "Contato",
      value: row.contact_name
    },
    {
      label: "E-mail de contato",
      value: row.contact_email
    },
    {
      label: "Primeiro perfil responsável",
      value: firstManagerLabel(row.first_manager_intent)
    },
    {
      label: "Status atual",
      value: statusLabel(row.request_status)
    }
  ];
}
function buildApplicantEmail(eventType, row, reviewerName) {
  const details = commonDetails(row);
  const greeting = firstNameOnly(row.contact_name) ? `Olá, ${firstNameOnly(row.contact_name)}!` : "Olá!";
  if (eventType === "library_request_created") {
    return {
      subject: `[AnarBib] Solicitação recebida`,
      title: "Solicitação institucional recebida",
      greeting,
      introHtml: `
        <p style="margin:0 0 10px;">Recebemos a solicitação institucional da biblioteca <b>${esc(row.library_name)}</b>.</p>
        <p style="margin:0;">A coordenação da rede AnarBib vai analisar as informações antes de qualquer liberação de acesso às áreas de gestão bibliotecária.</p>
      `,
      details: [
        ...details,
        {
          label: "Enviada em",
          value: formatDateTimeBR(row.created_at) || "—"
        }
      ]
    };
  }
  if (eventType === "library_request_in_analysis") {
    return {
      subject: `[AnarBib] Solicitação em análise`,
      title: "Solicitação em análise",
      greeting,
      introHtml: `
        <p style="margin:0 0 10px;">A coordenação da rede colocou a solicitação da biblioteca <b>${esc(row.library_name)}</b> em <b>análise</b>.</p>
        <p style="margin:0;">Se precisarmos de informações complementares, enviaremos uma nova mensagem.</p>
      `,
      details: [
        ...details,
        ...reviewerName ? [
          {
            label: "Análise por",
            value: reviewerName
          }
        ] : [],
        ...row.reviewed_at ? [
          {
            label: "Atualizada em",
            value: formatDateTimeBR(row.reviewed_at)
          }
        ] : []
      ]
    };
  }
  if (eventType === "library_request_more_info") {
    return {
      subject: `[AnarBib] Precisamos de informações complementares`,
      title: "Pedido de complemento",
      greeting,
      introHtml: `
        <p style="margin:0 0 10px;">A coordenação da rede precisa de <b>informações complementares</b> para continuar a análise da solicitação da biblioteca <b>${esc(row.library_name)}</b>.</p>
        <p style="margin:0;">Lê com atenção a mensagem abaixo e responde diretamente a este e-mail com os elementos pedidos.</p>
      `,
      details: [
        ...details,
        ...reviewerName ? [
          {
            label: "Mensagem enviada por",
            value: reviewerName
          }
        ] : [],
        ...row.review_notes ? [
          {
            label: "Mensagem da coordenação",
            value: normalizeReviewNotesForEmail(row.review_notes, true)
          }
        ] : []
      ]
    };
  }
  if (eventType === "library_request_approved") {
    return {
      subject: `[AnarBib] Solicitação aprovada`,
      title: "Solicitação aprovada",
      greeting,
      introHtml: `
        <p style="margin:0 0 10px;">A solicitação institucional da biblioteca <b>${esc(row.library_name)}</b> foi <b>aprovada</b>.</p>
        <p style="margin:0;">Isso confirma a validação política e organizativa da entrada na rede. A etapa técnica e os acessos definitivos podem ainda exigir um último alinhamento.</p>
      `,
      details: [
        ...details,
        ...reviewerName ? [
          {
            label: "Aprovação por",
            value: reviewerName
          }
        ] : [],
        ...row.review_notes ? [
          {
            label: "Observação da coordenação",
            value: row.review_notes
          }
        ] : []
      ]
    };
  }
  return {
    subject: `[AnarBib] Solicitação recusada`,
    title: "Solicitação recusada",
    greeting,
    introHtml: `
      <p style="margin:0 0 10px;">A solicitação institucional da biblioteca <b>${esc(row.library_name)}</b> foi <b>recusada</b> nesta etapa.</p>
      <p style="margin:0;">Se houver uma observação da coordenação abaixo, ela resume o motivo ou o contexto desta decisão.</p>
    `,
    details: [
      ...details,
      ...reviewerName ? [
        {
          label: "Resposta por",
          value: reviewerName
        }
      ] : [],
      ...row.review_notes ? [
        {
          label: "Observação da coordenação",
          value: row.review_notes
        }
      ] : []
    ]
  };
}
function buildAdminEmail(eventType, row, reviewerName) {
  const details = [
    ...commonDetails(row),
    {
      label: "E-mail da biblioteca",
      value: row.library_email
    },
    {
      label: "Telefone da biblioteca",
      value: row.library_phone || "—"
    },
    {
      label: "Função do contato",
      value: row.contact_role || "—"
    },
    {
      label: "E-mail do envio",
      value: row.submitted_by_email_snapshot || "—"
    },
    {
      label: "Enviada em",
      value: formatDateTimeBR(row.created_at) || "—"
    }
  ];
  if (eventType === "library_request_created") {
    return {
      subject: `[AnarBib] Nova solicitação institucional`,
      title: "Nova solicitação institucional",
      introHtml: `
        <p style="margin:0 0 10px;">Uma nova solicitação institucional de entrada na rede foi registrada.</p>
        <p style="margin:0;">Consulta o painel de rede para analisar o pedido e responder à biblioteca.</p>
      `,
      details: [
        ...details,
        {
          label: "Apresentação",
          value: row.summary || "—"
        }
      ]
    };
  }
  const statusText = eventType === "library_request_approved" ? "aprovada" : eventType === "library_request_refused" ? "recusada" : eventType === "library_request_more_info" ? "pedido de complemento enviado" : "em análise";
  return {
    subject: `[AnarBib] Atualização de solicitação institucional`,
    title: `Solicitação ${statusText}`,
    introHtml: `
      <p style="margin:0 0 10px;">Uma solicitação institucional foi atualizada no painel de rede.</p>
      <p style="margin:0;">Este e-mail serve como cópia de acompanhamento da coordenação.</p>
    `,
    details: [
      ...details,
      {
        label: "Novo status",
        value: statusLabel(row.request_status)
      },
      ...reviewerName ? [
        {
          label: "Atualizado por",
          value: reviewerName
        }
      ] : [],
      ...row.review_notes ? [
        {
          label: "Nota de revisão",
          value: row.review_notes
        }
      ] : []
    ]
  };
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
    "library_request_refused"
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
  const reviewer = await fetchProfile(row.reviewed_by_user_id).catch(()=>null);
  const reviewerName = reviewer ? fullName(reviewer.first_name, reviewer.last_name) || reviewer.public_id || reviewer.email || null : null;
  const applicantTargetsList = applicantTargets(row);
  const applicantEmail = buildApplicantEmail(eventType, row, reviewerName);
  const applicantRendered = renderEmail(applicantEmail);
  const results = [];
  for (const target of applicantTargetsList){
    results.push(await safeSendEmail("applicant", target, applicantEmail.subject, applicantRendered.html, applicantRendered.text));
  }
  if (eventType === "library_request_created") {
    const admin = adminTarget();
    const adminEmail = buildAdminEmail(eventType, row, reviewerName);
    const adminRendered = renderEmail(adminEmail);
    results.push(await safeSendEmail("admin_copy", admin, adminEmail.subject, adminRendered.html, adminRendered.text));
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
