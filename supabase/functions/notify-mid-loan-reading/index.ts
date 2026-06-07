// ============================================================================
// notify-mid-loan-reading — Mensagem de meio de empréstimo + recomendações
// ============================================================================
// Audit du 06/05/2026 (P2-B) :
//   - Lecture détaillée des 599 lignes : pas de duplication critique avec
//     _shared/. La fonction utilise des cascades de variables d'environnement
//     subtilement différentes (ex: senderNameFromContext fallback sur
//     BREVO_SENDER_NAME que _shared/core/env.ts ne couvre pas) et un renderEmail
//     spécifique avec section recommendations.
//   - Mini-refactor minimal appliqué : supabaseAdmin partagé depuis _shared/
//     pour économiser quelques lignes et harmoniser avec notify-event /
//     notify-weekly-report. Le reste du code reste intentionnellement spécifique.
//
// Webhook secret : WEBHOOK_SECRET_NOTIFY_MID_LOAN
// Mail           : Resend (RESEND_API_KEY) — Brevo retire en R.6 (05/06/2026)
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { supabaseAdmin } from "../_shared/core/env.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
function json(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders
    }
  });
}
function mustEnv(name) {
  const value = Deno.env.get(name);
  if (!value || !value.trim()) throw new Error(`Missing env: ${name}`);
  return value.trim();
}
function esc(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char)=>({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;"
    })[char]);
}
function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email || "").trim());
}
function normalizeDateInput(value) {
  const raw = String(value || "").trim();
  if (!raw) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}
function todayUTC() {
  return new Date().toISOString().slice(0, 10);
}
function parseDateOnly(value) {
  const raw = normalizeDateInput(value);
  if (!raw) return null;
  const [y, m, d] = raw.split("-").map((part)=>Number(part));
  return new Date(Date.UTC(y, m - 1, d));
}
function diffDays(a, b) {
  return Math.floor((b.getTime() - a.getTime()) / 86400000);
}
function addDays(date, days) {
  const next = new Date(date.getTime());
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}
function formatBR(dateStr) {
  const raw = normalizeDateInput(dateStr);
  if (!raw) return "—";
  const [y, m, d] = raw.split("-");
  return `${d}/${m}/${y}`;
}
function fullName(profile) {
  const parts = [
    profile?.first_name,
    profile?.last_name
  ].map((part)=>String(part || "").trim()).filter(Boolean);
  return parts.join(" ").trim();
}
function firstName(profile) {
  const name = String(profile?.first_name || "").trim();
  if (name) return name.split(/\s+/)[0] || name;
  const fallback = fullName(profile);
  return fallback ? fallback.split(/\s+/)[0] || fallback : "";
}
function normalizeText(value) {
  return String(value ?? "").trim();
}
function tokenizeSubjects(value) {
  return Array.from(new Set(normalizeText(value).toLowerCase().split(/[;,|/]+/).map((part)=>part.trim()).filter(Boolean)));
}
function cddPrefix(value, size) {
  const digits = normalizeText(value).replace(/[^\d]/g, "");
  return digits.slice(0, size);
}
function senderNameFromContext(ctx) {
  return normalizeText(ctx?.sender_display_name || (ctx?.use_library_name_as_sender !== false ? ctx?.library_short_name || ctx?.library_name || "" : "") || Deno.env.get("SENDER_NAME") || Deno.env.get("ANARBIB_SENDER_NAME") || Deno.env.get("NETWORK_SENDER_NAME") || "Biblioteca da rede AnarBib") || "Biblioteca da rede AnarBib";
}
function senderEmailFromContext(ctx) {
  return normalizeText(ctx?.sender_visible_email || Deno.env.get("SENDER_EMAIL") || Deno.env.get("ANARBIB_SENDER_EMAIL") || Deno.env.get("NETWORK_SENDER_EMAIL") || "no-reply@example.org");
}
function replyToFromContext(ctx) {
  const email = normalizeText(ctx?.reply_to_email || ctx?.admin_notification_email || Deno.env.get("REPLY_TO_EMAIL") || Deno.env.get("ANARBIB_REPLY_TO_EMAIL") || Deno.env.get("NETWORK_REPLY_TO_EMAIL") || "");
  const name = normalizeText(ctx?.reply_to_name || ctx?.signature_short || Deno.env.get("ADMIN_NAME") || Deno.env.get("ANARBIB_ADMIN_NAME") || Deno.env.get("NETWORK_ADMIN_NAME") || senderNameFromContext(ctx));
  if (!email) return null;
  return {
    email,
    name: name || undefined
  };
}
function logoUrlFromContext(ctx) {
  const explicit = normalizeText(ctx?.logo_url || "");
  if (/^https?:\/\//i.test(explicit)) return explicit;
  // #153.E TR-6.3 : cascade alignée sur le jeu de 5 variables du
  // _shared/core/env.ts central. Ordre standard (EF non réseau). La résolution
  // depuis ctx.logo_url ci-dessus (logo de la bibliothèque) reste inchangée.
  return normalizeText(Deno.env.get("LOGO_URL") || Deno.env.get("LIBRARY_LOGO_URL") || Deno.env.get("ANARBIB_LOGO_URL") || Deno.env.get("NETWORK_LOGO_URL") || Deno.env.get("BLMF_LOGO_URL") || "");
}
function brandNameFromContext(ctx) {
  return normalizeText(ctx?.library_short_name || ctx?.library_name || Deno.env.get("ANARBIB_BRAND_NAME") || Deno.env.get("NETWORK_BRAND_NAME") || Deno.env.get("BRAND_NAME") || "AnarBib") || "AnarBib";
}
function footerTextFromContext(ctx) {
  return normalizeText(ctx?.footer_local || Deno.env.get("FOOTER_TEXT") || Deno.env.get("ANARBIB_FOOTER_TEXT") || Deno.env.get("NETWORK_FOOTER_TEXT") || "Mensagem automática da biblioteca. Em caso de dúvida, responda a este e-mail ou use os canais da biblioteca.");
}
function canSendForContext(ctx) {
  const channelActive = typeof ctx?.channel_active === "boolean" ? ctx.channel_active : true;
  const deliveryMode = normalizeText(ctx?.delivery_mode || "platform_shared");
  if (!channelActive) return false;
  if (deliveryMode === "disabled") return false;
  return true;
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
// CONTRAT DE RETOUR LOCAL PRESERVE : cette EF attend { ok, status, body } et
// ne throw jamais sur erreur HTTP (le serve lit sendResult.ok / .status /
// .body) — sendViaResend renvoie ce meme objet.
// ============================================================================
function formatMailAddress(email, name) {
  const n = (name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Resend (cf. spec §4.4) ---------------------------------
// Format Resend : auth Bearer, from "Nom <email>", to tableau de strings,
// reply_to "Nom <email>", corps html/text. Retour aligne sur le contrat
// local { ok, status, body } : pas de throw sur erreur HTTP.
async function sendViaResend(opts) {
  const senderEmail = senderEmailFromContext(opts.context);
  const senderName = senderNameFromContext(opts.context);
  const replyTo = replyToFromContext(opts.context);
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (!resendKey) {
    return {
      ok: false,
      status: 0,
      body: "RESEND_API_KEY absente des secrets Edge Function"
    };
  }
  const payload: Record<string, unknown> = {
    from: formatMailAddress(senderEmail, senderName),
    to: [opts.toEmail],
    subject: opts.subject,
    html: opts.html,
    text: opts.text
  };
  if (replyTo && replyTo.email) {
    payload.reply_to = formatMailAddress(replyTo.email, replyTo.name);
  }
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  const body = await response.text();
  return {
    ok: response.ok,
    status: response.status,
    body
  };
}
// --- Wrapper neutre --------------------------------------------------------
// sendEmail() : seule fonction d'envoi connue du reste de l'EF.
async function sendEmail(opts) {
  console.log(`[mid-loan-reading] envoi via resend`);
  return await sendViaResend(opts);
}
function renderEmail(opts) {
  const brandName = brandNameFromContext(opts.context);
  const footerText = footerTextFromContext(opts.context);
  const logoUrl = logoUrlFromContext(opts.context);
  const detailRowsHtml = (opts.detailRows || []).map((row)=>`
    <tr>
      <td style="padding:8px 0;color:#cfcfcf;font-size:14px;">${esc(row.label)}</td>
      <td style="padding:8px 0;color:#ffffff;font-size:14px;text-align:right;"><b>${esc(row.value)}</b></td>
    </tr>
  `).join("");
  const recommendationsHtml = (opts.recommendations || []).length ? `
      <div style="margin-top:18px;">
        <h3 style="margin:0 0 10px;font-size:16px;color:#fff;">Leituras próximas disponíveis na sua biblioteca</h3>
        <ul style="margin:0;padding-left:18px;color:#f2f2f2;line-height:1.55;">
          ${(opts.recommendations || []).map((item)=>`
            <li style="margin:0 0 8px;">
              <b>${esc(item.titulo)}</b>${item.autor ? ` — ${esc(item.autor)}` : ""}
              ${item.local_bib_ref ? `<br><span style="color:#cfcfcf;">Referência local: ${esc(item.local_bib_ref)}</span>` : ""}
            </li>
          `).join("")}
        </ul>
      </div>
    ` : "";
  const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>${esc(opts.title)}</title>
  </head>
  <body style="margin:0;background:#0f0f10;color:#ffffff;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;">
      <tr>
        <td align="center" style="padding:24px 12px;">
          <table role="presentation" width="640" cellspacing="0" cellpadding="0" style="border-collapse:collapse;max-width:640px;width:100%;">
            <tr>
              <td style="background:rgba(27,27,27,0.96);border:1px solid rgba(255,255,255,0.12);border-radius:18px;overflow:hidden;">
                <div style="padding:18px 18px 14px;display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;">
                  <div style="display:flex;align-items:center;gap:12px;min-width:0;">
                    ${logoUrl ? `<img src="${esc(logoUrl)}" alt="${esc(brandName)}" style="display:block;max-width:84px;max-height:52px;width:auto;height:auto;object-fit:contain;">` : ""}
                    <div>
                      <div style="font-size:18px;font-weight:800;line-height:1.2;">${esc(brandName)}</div>
                      <div style="font-size:13px;color:#cfcfcf;line-height:1.2;">Mensagem automática</div>
                    </div>
                  </div>
                </div>
                <div style="height:3px;background:#c00000;"></div>
                <div style="padding:18px;">
                  <h1 style="margin:0 0 12px;font-size:20px;line-height:1.25;">${esc(opts.title)}</h1>
                  ${opts.greeting ? `<p style="margin:0 0 12px;font-size:16px;line-height:1.5;">${esc(opts.greeting)}</p>` : ""}
                  <div style="font-size:16px;line-height:1.55;color:#f2f2f2;">${opts.introHtml}</div>
                  ${(opts.detailRows || []).length ? `
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:14px 0 0;border-collapse:collapse;">
                      ${detailRowsHtml}
                    </table>
                  ` : ""}
                  ${recommendationsHtml}
                  <div style="margin:16px 0 0;font-size:13px;line-height:1.5;color:#cfcfcf;">${esc(footerText)}</div>
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
  const textParts = [
    brandName,
    opts.title,
    "",
    opts.greeting || "",
    "",
    opts.introHtml.replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>\s*<p>/gi, "\n\n").replace(/<[^>]+>/g, "").trim(),
    ""
  ];
  for (const row of opts.detailRows || []){
    textParts.push(`${row.label}: ${row.value}`);
  }
  if ((opts.recommendations || []).length) {
    textParts.push("", "Leituras próximas disponíveis na sua biblioteca:");
    for (const item of opts.recommendations || []){
      textParts.push(`- ${item.titulo}${item.autor ? " — " + item.autor : ""}${item.local_bib_ref ? " | ref. " + item.local_bib_ref : ""}`);
    }
  }
  textParts.push("", footerText);
  const text = textParts.filter((part, idx, arr)=>!(part === "" && arr[idx - 1] === "")).join("\n");
  return {
    html,
    text
  };
}
function chunk(items, size) {
  const out = [];
  for(let i = 0; i < items.length; i += size)out.push(items.slice(i, i + size));
  return out;
}
function arrayOverlap(a, b) {
  const setB = new Set(b);
  return a.some((item)=>setB.has(item));
}
function recommendationScore(current, candidate) {
  let score = 0;
  if (current.authorIds.length && candidate.authorIds.length && arrayOverlap(current.authorIds, candidate.authorIds)) score += 100;
  const currentCdd3 = cddPrefix(current.cdd, 3);
  const candidateCdd3 = cddPrefix(candidate.cdd, 3);
  const currentCdd2 = cddPrefix(current.cdd, 2);
  const candidateCdd2 = cddPrefix(candidate.cdd, 2);
  if (currentCdd3 && candidateCdd3 && currentCdd3 === candidateCdd3) score += 60;
  else if (currentCdd2 && candidateCdd2 && currentCdd2 === candidateCdd2) score += 25;
  const subjectOverlap = current.assuntos.filter((token)=>candidate.assuntos.includes(token)).length;
  score += Math.min(subjectOverlap * 10, 40);
  if (current.colecao && candidate.colecao && current.colecao === candidate.colecao) score += 20;
  if (current.editora && candidate.editora && current.editora === candidate.editora) score += 10;
  if (current.idioma && candidate.idioma && current.idioma === candidate.idioma) score += 5;
  score += Math.min(candidate.availableCount || 0, 5);
  return score;
}
async function fetchRecommendations(sb, libraryId, currentBookId) {
  const { data: currentBook, error: currentBookError } = await sb.from("books").select("id,titulo,autor,cdd,assuntos,colecao,editora,idioma,loanable").eq("id", currentBookId).maybeSingle();
  if (currentBookError || !currentBook) return [];
  const { data: currentAuthorsData } = await sb.from("book_authors").select("book_id,author_id").eq("book_id", currentBookId);
  const currentAuthorIds = (currentAuthorsData || []).map((row)=>Number(row.author_id)).filter((n)=>Number.isFinite(n));
  const { data: holdingsData, error: holdingsError } = await sb.from("book_holdings").select("book_id,available_count,local_bib_ref,loanable").eq("library_id", libraryId).gt("available_count", 0).limit(120);
  if (holdingsError || !holdingsData?.length) return [];
  const holdings = holdingsData.filter((row)=>Number(row.book_id) !== currentBookId);
  const candidateBookIds = Array.from(new Set(holdings.map((row)=>Number(row.book_id)).filter((n)=>Number.isFinite(n))));
  if (!candidateBookIds.length) return [];
  const { data: booksData, error: booksError } = await sb.from("books").select("id,titulo,autor,cdd,assuntos,colecao,editora,idioma,loanable").in("id", candidateBookIds);
  if (booksError || !booksData?.length) return [];
  const { data: authorData } = await sb.from("book_authors").select("book_id,author_id").in("book_id", candidateBookIds);
  const authorsByBook = new Map();
  for (const row of authorData || []){
    const key = Number(row.book_id);
    const current = authorsByBook.get(key) || [];
    current.push(Number(row.author_id));
    authorsByBook.set(key, current);
  }
  const holdingByBook = new Map();
  for (const row of holdings){
    const key = Number(row.book_id);
    const prev = holdingByBook.get(key);
    if (!prev || Number(row.available_count || 0) > Number(prev.available_count || 0)) {
      holdingByBook.set(key, row);
    }
  }
  const current = {
    cdd: normalizeText(currentBook.cdd),
    assuntos: tokenizeSubjects(currentBook.assuntos),
    colecao: normalizeText(currentBook.colecao).toLowerCase(),
    editora: normalizeText(currentBook.editora).toLowerCase(),
    idioma: normalizeText(currentBook.idioma).toLowerCase(),
    authorIds: currentAuthorIds
  };
  const recommendations = [];
  for (const book of booksData){
    const holding = holdingByBook.get(Number(book.id));
    if (!holding) continue;
    const loanable = holding.loanable === false || book.loanable === false ? false : true;
    if (!loanable) continue;
    const candidate = {
      cdd: normalizeText(book.cdd),
      assuntos: tokenizeSubjects(book.assuntos),
      colecao: normalizeText(book.colecao).toLowerCase(),
      editora: normalizeText(book.editora).toLowerCase(),
      idioma: normalizeText(book.idioma).toLowerCase(),
      authorIds: authorsByBook.get(Number(book.id)) || [],
      availableCount: Number(holding.available_count || 0)
    };
    const score = recommendationScore(current, candidate);
    if (score <= 0) continue;
    recommendations.push({
      book_id: Number(book.id),
      titulo: normalizeText(book.titulo) || `[${Number(book.id)}]`,
      autor: normalizeText(book.autor),
      local_bib_ref: normalizeText(holding.local_bib_ref),
      available_count: candidate.availableCount,
      score
    });
  }
  recommendations.sort((a, b)=>b.score - a.score || b.available_count - a.available_count || a.titulo.localeCompare(b.titulo, "pt-BR"));
  return recommendations.slice(0, 5);
}
serve(async (req)=>{
  if (req.method === "OPTIONS") return new Response("ok", {
    headers: corsHeaders
  });
  try {
    if (req.method !== "POST") return json(405, {
      ok: false,
      error: "Method not allowed"
    });
    const expectedSecret = mustEnv("WEBHOOK_SECRET_NOTIFY_MID_LOAN");
    const gotSecret = normalizeText(req.headers.get("x-webhook-secret"));
    if (!gotSecret || gotSecret !== expectedSecret) return json(401, {
      ok: false,
      error: "Unauthorized"
    });
    const body = await req.json().catch(()=>({}));
    const targetDate = normalizeDateInput(body?.date) || todayUTC();
    const dryRun = body?.dry_run === true;
    const limit = Math.min(Math.max(Number(body?.limit || 50), 1), 200);
    const libraryFilter = Array.from(new Set((body?.library_ids || []).map((value)=>normalizeText(value)).filter(Boolean)));
    const sb = supabaseAdmin;
    let loansQuery = sb.from("emprestimos_v2").select("id,user_id,library_id,due_at,created_at,status_global").eq("status_global", "aberto").gte("due_at", targetDate);
    if (libraryFilter.length) loansQuery = loansQuery.in("library_id", libraryFilter);
    const { data: loansData, error: loansError } = await loansQuery.limit(1000);
    if (loansError) throw loansError;
    const loans = loansData || [];
    if (!loans.length) return json(200, {
      ok: true,
      target_date: targetDate,
      processed: 0,
      sent: 0,
      skipped: 0,
      candidates: []
    });
    const loansById = new Map(loans.map((row)=>[
        Number(row.id),
        row
      ]));
    const loanIds = loans.map((row)=>Number(row.id)).filter((n)=>Number.isFinite(n));
    const userIds = Array.from(new Set(loans.map((row)=>normalizeText(row.user_id)).filter(Boolean)));
    const libraryIds = Array.from(new Set(loans.map((row)=>normalizeText(row.library_id)).filter(Boolean)));
    const itemChunks = chunk(loanIds, 200);
    const items = [];
    for (const group of itemChunks){
      const { data, error } = await sb.from("emprestimo_itens_v2").select("id,emprestimo_id,book_id,bib_ref,titulo_cache,autor_cache,due_at,item_status").in("emprestimo_id", group).eq("item_status", "aberto");
      if (error) throw error;
      items.push(...data || []);
    }
    const profileChunks = chunk(userIds, 200);
    const profiles = [];
    for (const group of profileChunks){
      const { data, error } = await sb.from("profiles").select("id,email,first_name,last_name,consent_email,is_restricted").in("id", group);
      if (error) throw error;
      profiles.push(...data || []);
    }
    const profilesById = new Map(profiles.map((row)=>[
        normalizeText(row.id),
        row
      ]));
    const contextChunks = chunk(libraryIds, 100);
    const contexts = [];
    for (const group of contextChunks){
      const { data, error } = await sb.from("v_library_notification_context").select("*").in("library_id", group);
      if (error) throw error;
      contexts.push(...data || []);
    }
    const contextsByLibrary = new Map(contexts.map((row)=>[
        normalizeText(row.library_id),
        row
      ]));
    const itemIds = items.map((row)=>Number(row.id)).filter((n)=>Number.isFinite(n));
    const existingLogIds = new Set();
    if (itemIds.length) {
      for (const group of chunk(itemIds, 200)){
        const { data, error } = await sb.from("loan_midpoint_message_log").select("emprestimo_item_id").in("emprestimo_item_id", group);
        if (error) throw error;
        for (const row of data || []){
          existingLogIds.add(Number(row.emprestimo_item_id));
        }
      }
    }
    const targetDateObj = parseDateOnly(targetDate);
    const candidates = [];
    for (const item of items){
      const loan = loansById.get(Number(item.emprestimo_id));
      if (!loan) continue;
      const profile = profilesById.get(normalizeText(loan.user_id));
      if (!profile) continue;
      const context = contextsByLibrary.get(normalizeText(loan.library_id)) || null;
      if (!context || context.mid_loan_message_enabled !== true) continue;
      if (context.channel_active === false || context.delivery_mode === "disabled") continue;
      if (profile.consent_email !== true) continue;
      if (profile.is_restricted === true) continue;
      if (existingLogIds.has(Number(item.id))) continue;
      if (!isValidEmail(profile.email)) continue;
      const startDate = parseDateOnly(loan.created_at);
      const dueDate = parseDateOnly(item.due_at || loan.due_at);
      if (!startDate || !dueDate) continue;
      const totalDays = diffDays(startDate, dueDate);
      if (totalDays < 2) continue;
      const midpointDate = addDays(startDate, Math.max(Math.floor(totalDays / 2), 1));
      const midpointISO = midpointDate.toISOString().slice(0, 10);
      if (midpointISO !== targetDate) continue;
      candidates.push({
        loan,
        item,
        profile,
        context,
        midpoint_date: midpointISO
      });
      if (candidates.length >= limit) break;
    }
    const results = [];
    let sent = 0;
    let skipped = 0;
    for (const candidate of candidates){
      const { loan, item, profile, context, midpoint_date } = candidate;
      const libraryName = normalizeText(context?.library_short_name || context?.library_name || "AnarBib");
      const userName = firstName(profile) || "compa";
      const currentTitle = normalizeText(item.titulo_cache) || `Livro ${item.book_id || ""}`.trim();
      const currentAuthor = normalizeText(item.autor_cache);
      const dueAtFormatted = formatBR(item.due_at || loan.due_at);
      const recommendations = context?.reading_recommendations_enabled && item.book_id ? await fetchRecommendations(sb, normalizeText(loan.library_id), Number(item.book_id)) : [];
      const subject = `${libraryName} | Como vai a leitura?`;
      const introHtml = `
        <p style="margin:0 0 10px;">Olá, <b>${esc(userName)}</b>!</p>
        <p style="margin:0 0 10px;">Passamos no meio do caminho do seu empréstimo para saber <b>como vai a leitura</b>.</p>
        <p style="margin:0 0 10px;">Você está com <b>${esc(currentTitle)}</b>${currentAuthor ? ` — ${esc(currentAuthor)}` : ""}.</p>
        <p style="margin:0;">A devolução prevista continua marcada para <b>${esc(dueAtFormatted)}</b>.</p>
      `;
      const detailRows = [
        {
          label: "Livro",
          value: currentTitle
        },
        ...currentAuthor ? [
          {
            label: "Autoria",
            value: currentAuthor
          }
        ] : [],
        ...normalizeText(item.bib_ref) ? [
          {
            label: "Referência local",
            value: normalizeText(item.bib_ref)
          }
        ] : [],
        {
          label: "Devolução prevista",
          value: dueAtFormatted
        }
      ];
      const { html, text } = renderEmail({
        title: "Como vai a leitura?",
        greeting: `Olá, ${userName}!`,
        introHtml,
        detailRows,
        recommendations,
        context
      });
      let sendResult = {
        ok: true,
        status: 200,
        body: "dry_run"
      };
      if (!dryRun) {
        if (!canSendForContext(context)) {
          skipped += 1;
          results.push({
            emprestimo_item_id: item.id,
            library_id: loan.library_id,
            user_id: loan.user_id,
            status: "skipped",
            reason: "channel_disabled"
          });
          continue;
        }
        sendResult = await sendEmail({
          toEmail: normalizeText(profile.email),
          toName: fullName(profile) || undefined,
          subject,
          html,
          text,
          context
        });
      }
      if (!sendResult.ok) {
        skipped += 1;
        results.push({
          emprestimo_item_id: item.id,
          library_id: loan.library_id,
          user_id: loan.user_id,
          status: "failed",
          http_status: sendResult.status,
          error: sendResult.body
        });
        continue;
      }
      if (!dryRun) {
        const { error: insertError } = await sb.from("loan_midpoint_message_log").insert({
          emprestimo_item_id: Number(item.id),
          emprestimo_id: Number(loan.id),
          user_id: normalizeText(loan.user_id),
          library_id: normalizeText(loan.library_id),
          midpoint_date,
          recommended_book_ids: recommendations.map((row)=>Number(row.book_id)),
          payload: {
            subject,
            current_title: currentTitle,
            current_author: currentAuthor,
            current_bib_ref: normalizeText(item.bib_ref),
            target_date: targetDate,
            recommendations: recommendations.map((row)=>({
                book_id: row.book_id,
                titulo: row.titulo,
                autor: row.autor,
                local_bib_ref: row.local_bib_ref,
                score: row.score
              }))
          }
        });
        if (insertError) throw insertError;
      }
      sent += 1;
      results.push({
        emprestimo_item_id: item.id,
        library_id: loan.library_id,
        user_id: loan.user_id,
        status: dryRun ? "would_send" : "sent",
        recommendations: recommendations.length
      });
    }
    return json(200, {
      ok: true,
      target_date: targetDate,
      processed: candidates.length,
      sent,
      skipped,
      dry_run: dryRun,
      results
    });
  } catch (error) {
    console.error("notify-mid-loan-reading error:", error);
    return json(500, {
      ok: false,
      error: String(error?.message || error)
    });
  }
});
