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
  return (Deno.env.get("NETWORK_LOGO_URL") || Deno.env.get("LOGO_URL") || "").trim();
}
function resolveEnvFooterText() {
  return (Deno.env.get("NETWORK_FOOTER_TEXT") || Deno.env.get("FOOTER_TEXT") || "Mensagem automática de coordenação do AnarBib.").trim();
}
function resolveEnvSenderName() {
  return (Deno.env.get("NETWORK_SENDER_NAME") || Deno.env.get("SENDER_NAME") || resolveEnvBrandName()).trim();
}
function resolveEnvSenderEmail() {
  return (Deno.env.get("NETWORK_SENDER_EMAIL") || Deno.env.get("SENDER_EMAIL") || "anarbib@anarbib.org").trim();
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
    const brevoKey = (Deno.env.get("BREVO_API_KEY_NOTIFICATIONS") ?? "").trim() || (Deno.env.get("BREVO_API_KEY_NOTIFY_RESERVA") ?? "").trim() || mustEnv("BREVO_API_KEY_NOTIFY_RESERVA");
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
    const loansCreated = await fetchAllRows((from, to)=>sb.from("emprestimos_v2").select("library_id,extended_at").gte("created_at", startISO).lt("created_at", endExclusiveISO).range(from, to));
    const renewals = await fetchAllRows((from, to)=>sb.from("emprestimos_v2").select("library_id,extended_at").not("extended_at", "is", null).gte("extended_at", startISO).lt("extended_at", endExclusiveISO).range(from, to));
    const returns = await fetchAllRows((from, to)=>sb.from("emprestimo_itens_v2").select("returned_at,emprestimos_v2!inner(library_id)").not("returned_at", "is", null).gte("returned_at", startISO).lt("returned_at", endExclusiveISO).range(from, to));
    const overdue = await fetchAllRows((from, to)=>sb.from("emprestimo_itens_v2").select("item_status,due_at,emprestimos_v2!inner(library_id)").eq("item_status", "aberto").lt("due_at", weekEndPlusOneDate).range(from, to));
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
        emprestimos_criados: 0,
        renovacoes: 0,
        devolucoes: 0,
        atrasos_ativos: 0
      });
    }
    for (const row of reservations){
      const libraryId = String(row.library_id || "").trim();
      if (!libraryId || !summaryByLibrary.has(libraryId)) continue;
      summaryByLibrary.get(libraryId).reservas += 1;
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
    const librarySummaries = Array.from(summaryByLibrary.values()).sort((a, b)=>a.library_name.localeCompare(b.library_name, "pt-BR", {
        sensitivity: "base"
      }));
    const totals = librarySummaries.reduce((acc, row)=>{
      acc.bibliotecas += 1;
      acc.com_caixa_local += row.weekly_report_email ? 1 : 0;
      acc.sem_caixa_local += row.weekly_report_email ? 0 : 1;
      acc.canais_desativados += row.channel_active ? 0 : 1;
      acc.reservas += row.reservas;
      acc.emprestimos_criados += row.emprestimos_criados;
      acc.renovacoes += row.renovacoes;
      acc.devolucoes += row.devolucoes;
      acc.atrasos_ativos += row.atrasos_ativos;
      return acc;
    }, {
      bibliotecas: 0,
      com_caixa_local: 0,
      sem_caixa_local: 0,
      canais_desativados: 0,
      reservas: 0,
      emprestimos_criados: 0,
      renovacoes: 0,
      devolucoes: 0,
      atrasos_ativos: 0
    });
    const summaryHtml = `
      <div style="line-height:1.5;color:#f2f2f2;">
        <p style="margin:0 0 10px 0;"><b>Rede:</b> ${esc(routing.brandName)}</p>
        <p style="margin:0 0 10px 0;"><b>Período:</b> ${esc(formatBR(weekStart))} → ${esc(formatBR(weekEnd))} (${esc(tz)})</p>
        <table role="presentation" cellspacing="0" cellpadding="0"
               style="border-collapse:collapse;border:1px solid rgba(255,255,255,0.14);width:100%;max-width:720px;">
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Bibliotecas ativas incluídas</b></td>
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
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Reservas criadas</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(totals.reservas)}</b></td>
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
            <td style="padding:10px;"><b>Atrasos ativos (fim da semana)</b></td>
            <td style="padding:10px;text-align:right;"><b>${countOr0(totals.atrasos_ativos)}</b></td>
          </tr>
        </table>
      </div>
    `;
    const perLibraryRows = librarySummaries.map((row)=>[
        row.library_short_name,
        row.weekly_report_email || "—",
        row.channel_active ? row.delivery_mode : `${row.delivery_mode} (desativado)`,
        countOr0(row.reservas),
        countOr0(row.emprestimos_criados),
        countOr0(row.renovacoes),
        countOr0(row.devolucoes),
        countOr0(row.atrasos_ativos)
      ]);
    const attentionRows = librarySummaries.filter((row)=>!row.weekly_report_email || !row.channel_active).map((row)=>[
        row.library_short_name,
        row.weekly_report_email || "sem weekly_report_email",
        row.admin_notification_email || "sem admin_notification_email",
        row.channel_active ? row.delivery_mode : "canal desativado"
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
          "Reservas",
          "Empréstimos",
          "Renovações",
          "Devoluções",
          "Atrasos"
        ], perLibraryRows),
        renderTable("Pontos de atenção de configuração", [
          "Biblioteca",
          "weekly_report_email",
          "admin_notification_email",
          "Estado"
        ], attentionRows)
      ],
      routing
    });
    const brevoBody = {
      sender: {
        email: routing.senderEmail,
        name: routing.senderName
      },
      to: [
        {
          email: routing.recipientEmail,
          ...routing.recipientName ? {
            name: routing.recipientName
          } : {}
        }
      ],
      subject,
      textContent: text,
      htmlContent: html
    };
    if (routing.replyToEmail) {
      brevoBody.replyTo = {
        email: routing.replyToEmail,
        ...routing.replyToName ? {
          name: routing.replyToName
        } : {}
      };
    }
    const brevoRes = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        accept: "application/json",
        "content-type": "application/json",
        "api-key": brevoKey
      },
      body: JSON.stringify(brevoBody)
    });
    const brevoText = await brevoRes.text();
    if (!brevoRes.ok) {
      throw new Error(`Brevo error HTTP ${brevoRes.status}: ${brevoText}`);
    }
    return json(200, {
      ok: true,
      run_id: runId,
      week_start: weekStart,
      week_end: weekEnd,
      recipient_email: routing.recipientEmail,
      subject,
      totals,
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
