// supabase/functions/notify-network-weekly-report/index.ts
import { mustSecretKey } from "../_shared/core/secret-key.ts";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from '../_shared/deps.ts';
import { sendEmail as sendEmailPartage } from "../_shared/transport/email.ts";
import { destinatairesAdminsReseau, LOCALE_BOITE_COLLECTIVE } from "../_shared/context/network-admins.ts";
import { tMailTexte, formatDateLocale } from "../_shared/i18n/mail-strings.ts";
import { esc as echapperHtml } from "../_shared/shared/format.ts";
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
  // l'esc partagé, qui n'échappe pas deux fois une phrase de tMail
  return echapperHtml(value);
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
// Une date « AAAA-MM-JJ » dans la langue du rapport (même format que les autres courriels).
function formatDate(dateStr, loc) {
  const s = String(dateStr || "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return s || "—";
  return formatDateLocale(`${s}T00:00:00.000Z`, loc);
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
// F26 (19/10/2026) : le pied commun du réseau (layout.footerTextNetwork), rendu
// dans renderEmail ; NETWORK_FOOTER_TEXT / FOOTER_TEXT ne sont plus lus (repli
// portugais en dur, secret supprimé le 19/10). Depuis le 20/10, tout le rapport
// suit la langue du destinataire, le pied avec lui.
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
// F14 (22/09/2026) : le Reply-To ne retombe plus sur l'adresse d'administration —
// un Reply-To sur un autre domaine que l'expéditeur (a fortiori un webmail) fait
// classer le courriel indésirable. Il retombe sur l'expéditeur.
function resolveEnvReplyToEmail() {
  return (Deno.env.get("NETWORK_REPLY_TO_EMAIL") || Deno.env.get("ANARBIB_REPLY_TO_EMAIL") || Deno.env.get("SENDER_EMAIL") || "").trim();
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
// Enum source : library_mail_channels.delivery_mode. Libellés : clés net.mode.*.
// Une valeur inconnue s'affiche telle quelle, soulignés en espaces.
function libelleOuBrut(loc, prefixe, valeur) {
  const cle = `${prefixe}${valeur}`;
  const t = tMailTexte(loc, cle);
  return t === cle ? valeur.replace(/_/g, " ") : t;
}
function deliveryModeLabel(mode, loc) {
  const m = String(mode || "").trim();
  if (!m) return tMailTexte(loc, "net.mode.default");
  return libelleOuBrut(loc, "net.mode.", m);
}
// Libellés humains des statuts de PEB (interlibrary_loans_v2.status_global) :
// clés net.ill.*, celles de l'écran (ill.status.*).
function pebStatusLabel(status, loc) {
  const s = String(status || "").trim();
  if (!s) return "—";
  return libelleOuBrut(loc, "net.ill.", s);
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
  const header = cols.map((c)=>`<th style="text-align:left;padding:8px;border-bottom:1px solid rgba(255,255,255,0.14);font-size:13px;background:rgba(255,255,255,0.06);color:#f2f2f2;">${esc(c)}</th>`).join("");
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
  const footerText = tMailTexte(opts.locale, "layout.footerTextNetwork");
  const logoHtml = opts.routing.logoUrl ? `<img src="${esc(opts.routing.logoUrl)}" alt="${esc(opts.routing.brandName)}" style="display:block;max-width:96px;max-height:60px;width:auto;height:auto;object-fit:contain;">` : `<div style="font-size:20px;font-weight:700;color:#fff;">${esc(opts.routing.brandName)}</div>`;
  const html = `
<!doctype html>
<html lang="${esc(opts.locale)}">
  <head>
    <meta charset="utf-8"><meta name="color-scheme" content="dark"><meta name="supported-color-schemes" content="dark">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>${esc(opts.subject)}</title>
  </head>
  <body style="margin:0;padding:0;background:#0f0f10;color:#f2f2f2;font-family:Arial,Helvetica,sans-serif;">
    <div style="display:none;opacity:0;max-height:0;overflow:hidden;">${esc(opts.preheader)}</div>
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0f0f10;color:#f2f2f2;">
      <tr>
        <td align="center" style="padding:24px;">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:860px;background:#18181b;color:#f2f2f2;border:1px solid rgba(255,255,255,0.08);border-radius:16px;overflow:hidden;">
            <tr>
              <td style="padding:22px 24px;background:linear-gradient(135deg,#6f000f 0%,#b30018 45%,#111 100%);color:#f2f2f2;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                  <tr>
                    <td valign="middle" style="width:120px;">${logoHtml}</td>
                    <td valign="middle" style="padding-left:16px;">
                      <div style="font-size:13px;letter-spacing:.04em;text-transform:uppercase;opacity:.9;">${esc(tMailTexte(opts.locale, "net.kicker"))}</div>
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
                ${esc(footerText)}
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
    footerText
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
    logoUrl: resolveEnvLogoUrl()
  };
}
function normalizeName(row, ctx) {
  const shortName = String(ctx?.library_short_name || row?.short_name || "").trim();
  const fullName = String(ctx?.library_name || row?.name || "").trim();
  // sans aucun nom : chaîne vide, le rendu écrit « Bibliothèque » dans la langue du rapport
  return {
    fullName: fullName || shortName,
    shortName: shortName || fullName
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
// --- Envoi : une seule implementation, celle de _shared (F7, 23/09/2026) ---
// Meme geste que pour notify-weekly-report : le routage reste calcule ici et
// passe explicitement, seul le transport est partage.
async function sendEmail(opts) {
  const { routing, subject, html, text, to } = opts;
  return await sendEmailPartage({
    toEmail: to.email,
    toName: to.name,
    subject,
    html,
    text,
    routing,
    label: "network-weekly-report"
  });
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
    const serviceKey = mustSecretKey();
    const sb = createClient(supabaseUrl, serviceKey, {
      auth: {
        persistSession: false
      }
    });
    const routing = resolveRouting();
    // F15 (24/09/2026) : le rapport hebdo du réseau part aux admins actif·ves
    // ET à la boîte collective (module partagé _shared/context/network-admins.ts),
    // le destinataire historique NETWORK_WEEKLY_REPORT_EMAIL restant en extra.
    // Le rapport est rendu dans la langue de chaque destinataire (20/10/2026) :
    // une composition par langue, N envois.
    // 422 seulement si PERSONNE n'est résolu·e — avant, une variable vide
    // suffisait à rendre le rapport muet.
    const destinataires = await destinatairesAdminsReseau(sb, {
      extras: isValidEmail(routing.recipientEmail) ? [{ email: routing.recipientEmail, name: routing.recipientName || undefined }] : []
    });
    if (!destinataires.length) {
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
    // Suite de F26 (20/10/2026) : le rapport était composé en pt-BR seul. Les
    // chiffres se calculent une fois ; le rendu se fait dans la langue de chaque
    // destinataire (profil des admins ; pt-BR pour la boîte collective et le
    // destinataire historique), une composition par langue.
    const ligneSynthese = (label, valeur, derniere = false)=>{
      const bord = derniere ? "" : "border-bottom:1px solid rgba(255,255,255,.08);";
      return `
          <tr>
            <td style="padding:10px;${bord}"><b>${esc(label)}</b></td>
            <td style="padding:10px;${bord}text-align:right;"><b>${countOr0(valeur)}</b></td>
          </tr>`;
    };
    const rendreRapport = (loc)=>{
      const t = (cle, params)=>tMailTexte(loc, cle, params);
      const nomCourt = (row)=>row.library_short_name || row.library_name || t("net.col.library");
      const summaryHtml = `
      <div style="line-height:1.5;color:#f2f2f2;">
        <p style="margin:0 0 10px 0;"><b>${esc(t("net.lbl.network"))}</b> ${esc(routing.brandName)}</p>
        <p style="margin:0 0 10px 0;"><b>${esc(t("net.lbl.period"))}</b> ${esc(formatDate(weekStart, loc))} → ${esc(formatDate(weekEnd, loc))} (${esc(tz)})</p>
        <table role="presentation" cellspacing="0" cellpadding="0"
               style="border-collapse:collapse;border:1px solid rgba(255,255,255,0.14);width:100%;max-width:720px;">${[
          ligneSynthese(t("net.sum.libraries"), totals.bibliotecas),
          ligneSynthese(t("net.sum.withBox"), totals.com_caixa_local),
          ligneSynthese(t("net.sum.withoutBox"), totals.sem_caixa_local),
          ligneSynthese(t("net.sum.disabledChannels"), totals.canais_desativados),
          ligneSynthese(t("net.sum.readersIn"), totals.inscricoes_leitores),
          ligneSynthese(t("net.sum.readersOut"), totals.saidas_leitores),
          ligneSynthese(t("net.sum.reservations"), totals.reservas),
          ligneSynthese(t("net.sum.consultations"), totals.consultas),
          ligneSynthese(t("net.sum.exchanges"), totals.trocas),
          ligneSynthese(t("net.sum.loans"), totals.emprestimos_criados),
          ligneSynthese(t("net.sum.renewals"), totals.renovacoes),
          ligneSynthese(t("net.sum.returns"), totals.devolucoes),
          ligneSynthese(t("net.sum.overdue"), totals.atrasos_ativos),
          ligneSynthese(t("net.sum.illCreated"), pebTotals.criados),
          ligneSynthese(t("net.sum.illCirculating"), pebTotals.em_circulacao, true)
        ].join("")}
        </table>
      </div>
    `;
      const perLibraryRows = librarySummaries.map((row)=>[
          nomCourt(row),
          row.weekly_report_email || "—",
          row.channel_active ? deliveryModeLabel(row.delivery_mode, loc) : t("net.mode.disabledSuffix", { mode: deliveryModeLabel(row.delivery_mode, loc) }),
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
          nomCourt(row),
          row.weekly_report_email || t("net.attn.noWeeklyEmail"),
          row.admin_notification_email || t("net.attn.noAdminEmail"),
          row.channel_active ? deliveryModeLabel(row.delivery_mode, loc) : t("net.attn.channelDisabled")
        ]);

      // ─── Lignes du tableau des échanges PEB (#ILL-reports étape 2) ────────
      // Résolution des noms via summaryByLibrary, déjà rempli pour toutes les
      // bibliothèques actives — pas de requête supplémentaire. Une bibliothèque
      // inactive ou inconnue (cas limite) retombe sur son identifiant.
      const pebLibLabel = (id)=>{
        const entry = summaryByLibrary.get(String(id || ""));
        return entry ? nomCourt(entry) : String(id || "—");
      };
      const pebExchangeRows = pebCreated.map((p)=>[
          pebLibLabel(p.lender_library_id),
          pebLibLabel(p.borrower_library_id),
          pebStatusLabel(p.status_global, loc),
          String(pebItemCountByLoan.get(String(p.id)) || 0),
          formatDate(String(p.created_at || "").slice(0, 10), loc)
        ]);

      const subject = t("net.subject", { brand: routing.brandName, start: formatDate(weekStart, loc), end: formatDate(weekEnd, loc) });
      const { html, text } = renderEmail({
        locale: loc,
        subject,
        title: t("net.title", { brand: routing.brandName }),
        preheader: t("net.preheader", { brand: routing.brandName }),
        summaryHtml,
        tablesHtml: [
          renderTable(t("net.tbl.perLibrary"), [
            "net.col.library",
            "net.col.localBox",
            "net.col.channel",
            "net.col.readersIn",
            "net.col.readersOut",
            "net.col.reservations",
            "net.col.consultations",
            "net.col.exchanges",
            "net.col.loans",
            "net.col.renewals",
            "net.col.returns",
            "net.col.overdue"
          ].map((c)=>t(c)), perLibraryRows),
          renderTable(t("net.tbl.attention"), [
            "net.col.library",
            "net.col.weeklyEmail",
            "net.col.adminEmail",
            "net.col.state"
          ].map((c)=>t(c)), attentionRows),
          renderTable(t("net.tbl.ill"), [
            "net.col.lender",
            "net.col.borrower",
            "net.col.state",
            "net.col.documents",
            "net.col.createdAt"
          ].map((c)=>t(c)), pebExchangeRows)
        ],
        routing
      });
      return { subject, html, text };
    };
    const rendus = new Map();
    const rendu = (loc)=>{
      if (!rendus.has(loc)) rendus.set(loc, rendreRapport(loc));
      return rendus.get(loc);
    };
    // Transport mail : envoi via Resend (chantier #110, Brevo retire en R.6).
    // Un refus n'empêche pas les envois suivants ; il est relevé à la fin,
    // avec l'adresse, et fait 500 (le cron le voit, le transport partagé a
    // déjà noté l'échec pour la sonde mail_transport).
    const refus = [];
    for (const to of destinataires) {
      const { subject, html, text } = rendu(to.locale || LOCALE_BOITE_COLLECTIVE);
      try {
        await sendEmail({ routing, subject, html, text, to });
      } catch (e) {
        refus.push(`${to.email}: ${String(e?.message ?? e)}`);
      }
    }
    if (refus.length) throw new Error(`network weekly report: ${refus.length}/${destinataires.length} envoi(s) refusé(s) — ${refus.join(" ; ")}`);
    return json(200, {
      ok: true,
      run_id: runId,
      week_start: weekStart,
      week_end: weekEnd,
      recipient_emails: destinataires.map((d)=>d.email),
      // l'objet dans la langue de référence, et celui de chaque langue rendue
      subject: rendu(LOCALE_BOITE_COLLECTIVE).subject,
      subjects: Object.fromEntries([...rendus].map(([loc, r])=>[loc, r.subject])),
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
