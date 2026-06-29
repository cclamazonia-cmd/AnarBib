// supabase/functions/notify-network-weekly-report/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const PAGE_SIZE = 1000;
function mustEnv(name) {
  const value = Deno.env.get(name);
  if (!value || !value.trim()) throw new Error(`Missing env: ${name}`);
  return value.trim();
}
function json(status, data) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8"
    }
  });
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
function toISO00Z(dateStr) {
  return new Date(`${dateStr}T00:00:00.000Z`).toISOString();
}
function addDaysISO(dateStr, days) {
  const d = new Date(`${dateStr}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString();
}
function formatBR(dateStr) {
  const [y, m, d] = String(dateStr || "").split("-");
  return y && m && d ? `${d}/${m}/${y}` : String(dateStr || "—");
}
function countOr0(v) {
  return String(v ?? 0);
}
function resolveEnvBrandName() {
  return (Deno.env.get("NETWORK_BRAND_NAME") || Deno.env.get("BRAND_NAME") || "AnarBib").trim();
}
function resolveEnvLogoUrl() {
  // #153.E TR-6.3 : cascade alignée sur le jeu de variables du _shared/core/env.ts
  // central (LOGO_URL, LIBRARY_LOGO_URL, ANARBIB_LOGO_URL, NETWORK_LOGO_URL,
  // BLMF_LOGO_URL). Divergence d'ordre ASSUMÉE et documentée : cette EF émet le
  // rapport hebdomadaire du réseau, NETWORK_LOGO_URL est donc lu en priorité.
  return (Deno.env.get("NETWORK_LOGO_URL") || Deno.env.get("LOGO_URL") || Deno.env.get("LIBRARY_LOGO_URL") || Deno.env.get("ANARBIB_LOGO_URL") || Deno.env.get("BLMF_LOGO_URL") || "").trim();
}
function resolveEnvFooterText() {
  return (Deno.env.get("NETWORK_FOOTER_TEXT") || Deno.env.get("FOOTER_TEXT") || "Mensagem automática de coordenação do AnarBib.").trim();
}
function resolveEnvSenderName() {
  // R.7 : harmonise sur SENDER_NAME canonique (NETWORK_SENDER_NAME etait aligne).
  return (Deno.env.get("SENDER_NAME") || resolveEnvBrandName()).trim();
}
function resolveEnvSenderEmail() {
  // R.7 : harmonise sur SENDER_EMAIL canonique (NETWORK_SENDER_EMAIL etait aligne).
  return (Deno.env.get("SENDER_EMAIL") || "anarbib@anarbib.org").trim();
}
function resolveEnvReplyToName() {
  return (Deno.env.get("NETWORK_REPLY_TO_NAME") || Deno.env.get("ADMIN_NAME") || resolveEnvSenderName()).trim();
}
function resolveEnvReplyToEmail() {
  return (Deno.env.get("NETWORK_REPLY_TO_EMAIL") || Deno.env.get("ANARBIB_REPLY_TO_EMAIL") || Deno.env.get("ADMIN_EMAIL") || Deno.env.get("SENDER_EMAIL") || "").trim();
}
function resolveEnvNetworkWeeklyRecipient() {
  return (Deno.env.get("NETWORK_WEEKLY_REPORT_EMAIL") || Deno.env.get("ANARBIB_NETWORK_WEEKLY_REPORT_EMAIL") || Deno.env.get("WEEKLY_REPORT_NETWORK_EMAIL") || Deno.env.get("ADMIN_EMAIL") || "").trim();
}
function normalizeLibraryContext(input) {
  const row = input || {};
  return {
    library_id: String(row.library_id || "").trim() || null,
    slug: String(row.slug || "").trim() || null,
    library_name: String(row.library_name || "").trim() || null,
    library_short_name: String(row.library_short_name || "").trim() || null,
    delivery_mode: String(row.delivery_mode || "").trim() || null,
    admin_notification_email: String(row.admin_notification_email || "").trim() || null,
    weekly_report_email: String(row.weekly_report_email || "").trim() || null,
    severe_alert_email: String(row.severe_alert_email || "").trim() || null,
    transport_state: String(row.transport_state || "").trim() || null,
    transport_channel: String(row.transport_channel || "").trim() || null,
    channel_active: typeof row.channel_active === "boolean" ? row.channel_active : null
  };
}
// Libellés humains du canal de notification (delivery_mode) — évite d'exposer les
// valeurs techniques (platform_shared, etc.) dans le rapport destiné à la coordination.
// Enum source : library_mail_channels.delivery_mode.
const DELIVERY_MODE_LABELS_PT = {
  platform_shared: "Plataforma (compartilhado)",
  platform_shared_local_reply: "Plataforma (resposta local)",
  library_own_transport: "Transporte próprio da biblioteca",
  disabled: "Desativado"
};
function deliveryModeLabel(mode) {
  const m = String(mode || "").trim();
  if (!m) return "Plataforma (padrão)";
  return DELIVERY_MODE_LABELS_PT[m] || m.replace(/_/g, " ");
}
// Libellés humains des statuts de PEB (interlibrary_loans_v2.status_global).
const PEB_STATUS_LABELS_PT = {
  preparacao: "Em preparação",
  aguardando_saida: "Aguardando saída",
  emprestado: "Emprestado",
  parcialmente_devolvido: "Parcialmente devolvido",
  em_devolucao: "Em devolução",
  devolvido: "Devolvido",
  cancelado: "Cancelado",
  atrasado: "Atrasado"
};
function pebStatusLabel(status) {
  const s = String(status || "").trim();
  if (!s) return "—";
  return PEB_STATUS_LABELS_PT[s] || s.replace(/_/g, " ");
}
async function fetchAllRows(build) {
  const rows = [];
  let from = 0;
  while(true){
    const to = from + PAGE_SIZE - 1;
    const { data, error } = await build(from, to);
    if (error) throw new Error(error.message);
    const batch = data || [];
    rows.push(...batch);
    if (batch.length < PAGE_SIZE) break;
    from += PAGE_SIZE;
  }
  return rows;
}
function renderTable(title, cols, rows) {
  const header = cols.map((c)=>`<th style="text-align:left;padding:8px;border-bottom:1px solid rgba(255,255,255,0.14);font-size:13px;background:rgba(255,255,255,0.06);">${esc(c)}</th>`).join("");
  const body = rows.map((r)=>`
    <tr>
      ${r.map((cell)=>`<td style="padding:8px;border-bottom:1px solid rgba(255,255,255,.08);font-size:13px;vertical-align:top;">${esc(cell)}</td>`).join("")}
    </tr>
  `).join("");
  return `
    <h3 style="margin:18px 0 8px 0;font-size:16px;color:#fff;">${esc(title)}</h3>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0"
           style="border-collapse:collapse;border:1px solid rgba(255,255,255,0.14);">
      <thead><tr>${header}</tr></thead>
      <tbody>${body || `<tr><td style="padding:8px;font-size:13px;" colspan="${cols.length}">—</td></tr>`}</tbody>
    </table>
  `.trim();
}
function renderEmail(opts) {
  const logoHtml = opts.routing.logoUrl ? `<img src="${esc(opts.routing.logoUrl)}" alt="${esc(opts.routing.brandName)}" style="display:block;max-width:96px;max-height:60px;width:auto;height:auto;object-fit:contain;">` : `<div style="font-size:20px;font-weight:700;color:#fff;">${esc(opts.routing.brandName)}</div>`;
  const html = `
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>${esc(opts.subject)}</title>
  </head>
  <body style="margin:0;padding:0;background:#0f0f10;color:#f2f2f2;font-family:Arial,Helvetica,sans-serif;">
    <div style="display:none;opacity:0;max-height:0;overflow:hidden;">${esc(opts.preheader)}</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0f0f10;">
      <tr>
        <td align="center" style="padding:24px;">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:860px;background:#18181b;border:1px solid rgba(255,255,255,0.08);border-radius:16px;overflow:hidden;">
            <tr>
              <td style="padding:22px 24px;background:linear-gradient(135deg,#6f000f 0%,#b30018 45%,#111 100%);">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                  <tr>
                    <td valign="middle" style="width:120px;">${logoHtml}</td>
                    <td valign="middle" style="padding-left:16px;">
                      <div style="font-size:13px;letter-spacing:.04em;text-transform:uppercase;opacity:.9;">Coordenação de rede</div>
                      <h1 style="margin:6px 0 0 0;font-size:24px;line-height:1.2;color:#fff;">${esc(opts.title)}</h1>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:24px;">
                ${opts.summaryHtml}
                ${opts.tablesHtml.join("\n")}
              </td>
            </tr>
            <tr>
              <td style="padding:16px 24px;border-top:1px solid rgba(255,255,255,0.08);font-size:12px;color:#d4d4d8;line-height:1.5;">
                ${esc(opts.routing.footerText)}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
  `.trim();
  const text = [
    opts.title,
    "",
    opts.preheader,
    "",
    opts.routing.footerText
  ].join("\n");
  return {
    html,
    text
  };
}
function resolveRouting() {
  return {
    senderName: resolveEnvSenderName(),
    senderEmail: resolveEnvSenderEmail(),
    replyToName: resolveEnvReplyToName() || null,
    replyToEmail: resolveEnvReplyToEmail() || null,
    recipientEmail: resolveEnvNetworkWeeklyRecipient(),
    recipientName: resolveEnvReplyToName() || null,
    brandName: resolveEnvBrandName(),
    logoUrl: resolveEnvLogoUrl(),
    footerText: resolveEnvFooterText()
  };
}
function normalizeName(row, ctx) {
  const shortName = String(ctx?.library_short_name || row?.short_name || "").trim();
  const fullName = String(ctx?.library_name || row?.name || "").trim();
  return {
    fullName: fullName || shortName || "Biblioteca sem nome",
    shortName: shortName || fullName || "Biblioteca"
  };
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
// CONTRAT : sendEmail ne renvoie rien d'utile au serve (envoi pour effet) et
// throw sur erreur HTTP.
// ============================================================================
function formatMailAddress(email, name) {
  const n = String(name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Resend (cf. spec §4.4) ---------------------------------
// Format Resend : auth Bearer, from "Nom <email>", to tableau de strings,
// reply_to "Nom <email>", corps html/text. throw sur erreur HTTP.
async function sendViaResend(opts) {
  const { routing, subject, html, text } = opts;
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (!resendKey) {
    throw new Error("RESEND_API_KEY absente des secrets Edge Function");
  }
  const payload: Record<string, unknown> = {
    from: formatMailAddress(routing.senderEmail, routing.senderName),
    to: [routing.recipientEmail],
    subject,
    html,
    text
  };
  if (routing.replyToEmail) {
    payload.reply_to = formatMailAddress(routing.replyToEmail, routing.replyToName);
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  const resText = await res.text();
  if (!res.ok) {
    throw new Error(`Resend error HTTP ${res.status}: ${resText}`);
  }
  return resText;
}
// --- Wrapper neutre --------------------------------------------------------
async function sendEmail(opts) {
  console.log(`[network-weekly-report] envoi via resend`);
  return await sendViaResend(opts);
}

serve(async (req)=>{
  const body = await req.json().catch(()=>null);
  const runId = body?.run_id ?? null;
  try {
    if (req.method !== "POST") return json(405, {
      ok: false,
      error: "Method not allowed"
    });
    const expected = mustEnv("WEBHOOK_SECRET_NOTIFY_NETWORK_WEEKLY_REPORT");
    const got = (req.headers.get("x-webhook-secret") ?? "").trim();
    if (!got || got !== expected) return json(401, {
      ok: false,
      error: "Unauthorized"
    });
    if (!body?.week_start || !body?.week_end) {
      return json(400, {
        ok: false,
        error: "Bad payload: week_start and week_end are required",
        run_id: runId
      });
    }
    const weekStart = body.week_start;
    const weekEnd = body.week_end;
    const tz = String(body.tz || Deno.env.get("NETWORK_DEFAULT_TIMEZONE") || Deno.env.get("DEFAULT_TIMEZONE") || "UTC").trim() || "UTC";
    const filterLibraryIds = Array.isArray(body.library_ids) ? body.library_ids.map((v)=>String(v || "").trim()).filter(Boolean) : [];
    const startISO = toISO00Z(weekStart);
    const endExclusiveISO = addDaysISO(weekEnd, 1);
    const weekEndPlusOneDate = endExclusiveISO.slice(0, 10);
    const supabaseUrl = mustEnv("SUPABASE_URL");
    const serviceKey = mustEnv("SUPABASE_SERVICE_ROLE_KEY");
    const sb = createClient(supabaseUrl, serviceKey, {
      auth: {
        persistSession: false
      }
    });
    const routing = resolveRouting();
    if (!routing.recipientEmail || !isValidEmail(routing.recipientEmail)) {
      return json(422, {
        ok: false,
        error: "No valid network weekly report recipient configured",
        run_id: runId
      });
    }
    const { data: librariesRaw, error: librariesErr } = await sb.from("libraries").select("id,name,short_name,is_active").eq("is_active", true).order("name", {
      ascending: true
    });
    if (librariesErr) throw new Error(`Libraries query failed: ${librariesErr.message}`);
    let libraries = (librariesRaw || []).filter((row)=>String(row.id || "").trim());
    if (filterLibraryIds.length) {
      const allowed = new Set(filterLibraryIds);
      libraries = libraries.filter((row)=>allowed.has(String(row.id || "").trim()));
    }
    if (!libraries.length) {
      return json(404, {
        ok: false,
        error: "No active libraries found for this network report",
        run_id: runId
      });
    }
    const libraryIds = libraries.map((row)=>String(row.id));
    const { data: ctxRaw, error: ctxErr } = await sb.from("v_library_notification_context").select("library_id,slug,library_name,library_short_name,delivery_mode,admin_notification_email,weekly_report_email,severe_alert_email,transport_state,transport_channel,channel_active").in("library_id", libraryIds);
    if (ctxErr) throw new Error(`Notification context query failed: ${ctxErr.message}`);
    const ctxByLibrary = new Map((ctxRaw || []).map((row)=>normalizeLibraryContext(row)).filter((row)=>row.library_id).map((row)=>[
        String(row.library_id),
        row
      ]));
    const reservations = await fetchAllRows((from, to)=>sb.from("reservas_v2").select("library_id").gte("created_at", startISO).lt("created_at", endExclusiveISO).range(from, to));
    const consultas = await fetchAllRows((from, to)=>sb.from("consultas_locais_v2").select("library_id").gte("created_at", startISO).lt("created_at", endExclusiveISO).range(from, to));
    // Trocas (intercâmbios) propostas na semana — chantier #EA-11. Attribuées à
    // la bibliothèque INITIATRICE (requester) pour éviter le double comptage.
    const trocasCreated = await fetchAllRows((from, to)=>sb.from("document_permission_requests").select("requester_library_id").eq("object_type", "interlibrary_exchange").gte("created_at", startISO).lt("created_at", endExclusiveISO).range(from, to));
    const loansCreated = await fetchAllRows((from, to)=>sb.from("emprestimos_v2").select("library_id,extended_at").gte("created_at", startISO).lt("created_at", endExclusiveISO).range(from, to));
    const renewals = await fetchAllRows((from, to)=>sb.from("emprestimos_v2").select("library_id,extended_at").not("extended_at", "is", null).gte("extended_at", startISO).lt("extended_at", endExclusiveISO).range(from, to));
    const returns = await fetchAllRows((from, to)=>sb.from("emprestimo_itens_v2").select("returned_at,emprestimos_v2!inner(library_id)").not("returned_at", "is", null).gte("returned_at", startISO).lt("returned_at", endExclusiveISO).range(from, to));
    const overdue = await fetchAllRows((from, to)=>sb.from("emprestimo_itens_v2").select("item_status,due_at,emprestimos_v2!inner(library_id)").eq("item_status", "aberto").lt("due_at", weekEndPlusOneDate).range(from, to));

    // ─── Activité PEB de niveau réseau — chantier #ILL-reports (étape 2) ────
    // Un PEB relie DEUX bibliothèques : ce n'est pas une donnée d'un collectif
    // mais une relation entre collectifs. Au niveau réseau on le présente donc
    // comme une section distincte (pas une colonne de la synthèse par
    // bibliothèque), ce qui évite tout double comptage. Deux compteurs
    // globaux et un tableau listant les échanges de la semaine.
    // NB : « PEB en circulation » s'appuie sur status_global, dont la
    // fiabilité reste imparfaite tant que #ILL-lifecycle n'est pas traité.
    const pebInCirculationStatuses = ["emprestado", "parcialmente_devolvido", "atrasado"];

    // Échanges créés dans la semaine (la maille réseau : un échange = une ligne).
    const pebCreated = await fetchAllRows((from, to)=>sb.from("interlibrary_loans_v2")
      .select("id,request_id,lender_library_id,borrower_library_id,status_global,created_at")
      .gte("created_at", startISO).lt("created_at", endExclusiveISO)
      .order("created_at", { ascending: false }).range(from, to));

    // Échanges encore en circulation à la clôture (tout le réseau).
    const pebInCirculation = await fetchAllRows((from, to)=>sb.from("interlibrary_loans_v2")
      .select("id").in("status_global", pebInCirculationStatuses).range(from, to));

    // Nombre de documents par PEB créé cette semaine (un appel groupé).
    const pebCreatedIds = pebCreated.map((p)=>p.id).filter(Boolean);
    const pebItems = pebCreatedIds.length
      ? await fetchAllRows((from, to)=>sb.from("interlibrary_loan_items_v2")
          .select("interlibrary_loan_id").in("interlibrary_loan_id", pebCreatedIds).range(from, to))
      : [];
    const pebItemCountByLoan = new Map();
    for (const it of pebItems){
      const k = String(it.interlibrary_loan_id);
      pebItemCountByLoan.set(k, (pebItemCountByLoan.get(k) || 0) + 1);
    }

    const pebTotals = {
      criados: pebCreated.length,
      em_circulacao: pebInCirculation.length
    };

    // ─── Inscrições e saídas de leitores na rede — chantier #reader-churn ───
    // Source : reader_membership_events (migration 20260622182246). Agrégat par
    // bibliothèque des inscriptions effectives (event_type='inscricao') et des
    // départs (event_type='saida') de la semaine.
    const readerEvents = await fetchAllRows((from, to)=>sb.from("reader_membership_events")
      .select("library_id,event_type")
      .in("event_type", ["inscricao", "saida"])
      .in("library_id", libraryIds)
      .gte("changed_at", startISO).lt("changed_at", endExclusiveISO)
      .range(from, to));

    const summaryByLibrary = new Map();
    for (const library of libraries){
      const libraryId = String(library.id);
      const ctx = ctxByLibrary.get(libraryId) || null;
      const names = normalizeName(library, ctx);
      summaryByLibrary.set(libraryId, {
        library_id: libraryId,
        library_name: names.fullName,
        library_short_name: names.shortName,
        delivery_mode: String(ctx?.delivery_mode || "platform_shared").trim() || "platform_shared",
        channel_active: ctx?.channel_active !== false,
        weekly_report_email: ctx?.weekly_report_email || null,
        admin_notification_email: ctx?.admin_notification_email || null,
        reservas: 0,
        consultas: 0,
        trocas: 0,
        emprestimos_criados: 0,
        renovacoes: 0,
        devolucoes: 0,
        atrasos_ativos: 0,
        inscricoes_leitores: 0,
        saidas_leitores: 0
      });
    }
    for (const row of reservations){
      const libraryId = String(row.library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      summaryByLibrary.get(libraryId).reservas += 1;
    }
    for (const row of consultas){
      const libraryId = String(row.library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      summaryByLibrary.get(libraryId).consultas += 1;
    }
    for (const row of trocasCreated){
      const libraryId = String(row.requester_library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      summaryByLibrary.get(libraryId).trocas += 1;
    }
    for (const row of loansCreated){
      const libraryId = String(row.library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      summaryByLibrary.get(libraryId).emprestimos_criados += 1;
    }
    for (const row of renewals){
      const libraryId = String(row.library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      summaryByLibrary.get(libraryId).renovacoes += 1;
    }
    for (const row of returns){
      const libraryId = String(row.emprestimos_v2?.library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      summaryByLibrary.get(libraryId).devolucoes += 1;
    }
    for (const row of overdue){
      const libraryId = String(row.emprestimos_v2?.library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      summaryByLibrary.get(libraryId).atrasos_ativos += 1;
    }
    for (const row of readerEvents){
      const libraryId = String(row.library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      const entry = summaryByLibrary.get(libraryId);
      if (row.event_type === "inscricao") entry.inscricoes_leitores += 1;
      else if (row.event_type === "saida") entry.saidas_leitores += 1;
    }
    const librarySummaries = Array.from(summaryByLibrary.values()).sort((a, b)=>a.library_name.localeCompare(b.library_name, "pt-BR", {
        sensitivity: "base"
      }));
    const totals = librarySummaries.reduce((acc, row)=>{
      acc.bibliotecas += 1;
      acc.com_caixa_local += row.weekly_report_email ? 1 : 0;
      acc.sem_caixa_local += row.weekly_report_email ? 0 : 1;
      acc.canais_desativados += row.channel_active ? 0 : 1;
      acc.reservas += row.reservas;
      acc.consultas += row.consultas;
      acc.trocas += row.trocas;
      acc.emprestimos_criados += row.emprestimos_criados;
      acc.renovacoes += row.renovacoes;
      acc.devolucoes += row.devolucoes;
      acc.atrasos_ativos += row.atrasos_ativos;
      acc.inscricoes_leitores += row.inscricoes_leitores;
      acc.saidas_leitores += row.saidas_leitores;
      return acc;
    }, {
      bibliotecas: 0,
      com_caixa_local: 0,
      sem_caixa_local: 0,
      canais_desativados: 0,
      reservas: 0,
      consultas: 0,
      trocas: 0,
      emprestimos_criados: 0,
      renovacoes: 0,
      devolucoes: 0,
      atrasos_ativos: 0,
      inscricoes_leitores: 0,
      saidas_leitores: 0
    });
    const summaryHtml = `
      <div style="line-height:1.5;color:#f2f2f2;">
        <p style="margin:0 0 10px 0;"><b>Rede:</b> ${esc(routing.brandName)}</p>
        <p style="margin:0 0 10px 0;"><b>Período:</b> ${esc(formatBR(weekStart))} → ${esc(formatBR(weekEnd))} (${esc(tz)})</p>
        <table role="presentation" cellspacing="0" cellpadding="0"
               style="border-collapse:collapse;border:1px solid rgba(255,255,255,0.14);width:100%;max-width:720px;">
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Bibliotecas ativas na rede</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.bibliotecas)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Bibliotecas com caixa semanal local</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.com_caixa_local)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Bibliotecas sem caixa semanal local</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.sem_caixa_local)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Canais locais desativados</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.canais_desativados)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Novas inscrições de leitores</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.inscricoes_leitores)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Saídas de leitores</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.saidas_leitores)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Reservas criadas</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.reservas)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Consultas registradas</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.consultas)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Trocas propostas</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.trocas)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Empréstimos criados</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.emprestimos_criados)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Renovações</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.renovacoes)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Devoluções</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.devolucoes)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Atrasos ativos (fim da semana)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.atrasos_ativos)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>PEB criados na semana (intercâmbios)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(pebTotals.criados)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;"><b>PEB em circulação na rede (fim da semana)</b></td>
            <td style="padding:10px;text-align:right;"><b>${countOr0(pebTotals.em_circulacao)}</b></td>
          </tr>
        </table>
      </div>
    `;
    const perLibraryRows = librarySummaries.map((row)=>[
        row.library_short_name,
        row.weekly_report_email || "—",
        row.channel_active ? deliveryModeLabel(row.delivery_mode) : `${deliveryModeLabel(row.delivery_mode)} (desativado)`,
        countOr0(row.inscricoes_leitores),
        countOr0(row.saidas_leitores),
        countOr0(row.reservas),
        countOr0(row.consultas),
        countOr0(row.trocas),
        countOr0(row.emprestimos_criados),
        countOr0(row.renovacoes),
        countOr0(row.devolucoes),
        countOr0(row.atrasos_ativos)
      ]);
    const attentionRows = librarySummaries.filter((row)=>!row.weekly_report_email || !row.channel_active).map((row)=>[
        row.library_short_name,
        row.weekly_report_email || "sem e-mail de relatório semanal",
        row.admin_notification_email || "sem e-mail de notificação",
        row.channel_active ? deliveryModeLabel(row.delivery_mode) : "Canal desativado"
      ]);

    // ─── Lignes du tableau des échanges PEB (#ILL-reports étape 2) ──────────
    // Résolution des noms via summaryByLibrary, déjà rempli pour toutes les
    // bibliothèques actives — pas de requête supplémentaire. Une bibliothèque
    // inactive ou inconnue (cas limite) retombe sur son identifiant.
    const pebLibLabel = (id)=>{
      const entry = summaryByLibrary.get(String(id || ""));
      return entry ? (entry.library_short_name || entry.library_name) : String(id || "—");
    };
    const pebExchangeRows = pebCreated.map((p)=>[
        pebLibLabel(p.lender_library_id),
        pebLibLabel(p.borrower_library_id),
        pebStatusLabel(p.status_global),
        String(pebItemCountByLoan.get(String(p.id)) || 0),
        String(p.created_at || "").slice(0, 10) || "—"
      ]);

    const subject = `${routing.brandName} · Relatório semanal da rede (${formatBR(weekStart)} → ${formatBR(weekEnd)})`;
    const title = `Relatório semanal da rede — ${routing.brandName}`;
    const { html, text } = renderEmail({
      subject,
      title,
      preheader: `${routing.brandName} · resumo global das bibliotecas`,
      summaryHtml,
      tablesHtml: [
        renderTable("Síntese por biblioteca", [
          "Biblioteca",
          "Caixa local",
          "Canal",
          "Inscrições",
          "Saídas",
          "Reservas",
          "Consultas",
          "Trocas",
          "Empréstimos",
          "Renovações",
          "Devoluções",
          "Atrasos"
        ], perLibraryRows),
        renderTable("Pontos de atenção de configuração", [
          "Biblioteca",
          "E-mail de relatório semanal",
          "E-mail de notificação (admin)",
          "Estado"
        ], attentionRows),
        renderTable("Intercâmbios interbibliotecas da rede (PEB criados na semana)", [
          "Biblioteca emprestadora",
          "Biblioteca tomadora",
          "Estado",
          "Documentos",
          "Criado em"
        ], pebExchangeRows)
      ],
      routing
    });
    // Transport mail : envoi via Resend (chantier #110, Brevo retire en R.6).
    // routing / subject / html / text deja calcules.
    await sendEmail({
      routing,
      subject,
      html,
      text
    });
    return json(200, {
      ok: true,
      run_id: runId,
      week_start: weekStart,
      week_end: weekEnd,
      recipient_email: routing.recipientEmail,
      subject,
      totals,
      peb_totals: pebTotals,
      libraries: librarySummaries
    });
  } catch (error) {
    return json(500, {
      ok: false,
      run_id: runId,
      error: String(error?.message ?? error)
    });
  }
});
