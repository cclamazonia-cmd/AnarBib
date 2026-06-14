// ============================================================================
// notify-weekly-report — Relatório semanal por biblioteca
// ============================================================================
// Refactor du 06/05/2026 :
//   - Imports _shared/ racine pour la résolution du contexte de notification
//     (élimination de ~150 lignes de duplication avec _shared/context/)
//   - Wrapper local resolveWeeklyMailRouting pour ajouter recipientEmail/Name
//     spécifiques au weekly report (basés sur weekly_report_email)
//   - Helpers locaux conservés pour la logique métier weekly (renderTable,
//     renderReportEmail, group*, tryUpdateRunStatus)
//
// Webhook secret : WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT
// Mail           : Resend (RESEND_API_KEY) — Brevo retire en R.6 (05/06/2026)
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  ADMIN_EMAIL,
  ADMIN_NAME,
  FOOTER_TEXT,
  SENDER_EMAIL,
  SENDER_NAME,
  supabaseAdmin
} from "../_shared/core/env.ts";
import { resolveLibraryNotificationContext } from "../_shared/context/library-notification-context.ts";
import { resolveMailRouting } from "../_shared/context/library-mail-routing.ts";

// ─── Helpers locaux ─────────────────────────────────────────────────────────

function mustEnv(name) {
  const v = Deno.env.get(name);
  if (!v || !v.trim()) throw new Error(`Missing env: ${name}`);
  return v.trim();
}

function json(status, data) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" }
  });
}

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[c]);
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email || "").trim());
}

function asRecord(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

async function resolveWeeklyLibrarySummaryEnabled(sb, libraryId) {
  const { data, error } = await sb.from("library_document_governance").select("config").eq("library_id", libraryId).maybeSingle();
  if (error) throw new Error(`Weekly report governance query failed: ${error.message}`);
  const config = asRecord(data?.config);
  const reports = asRecord(config.reports);
  return reports.weekly_library_summary_enabled === true;
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

function isoDateOnly(value) {
  return String(value || "").trim().slice(0, 10) || "—";
}

function isoDateTime(value) {
  return String(value || "").trim().slice(0, 19) || "—";
}

function fullName(row) {
  return [String(row?.first_name || "").trim(), String(row?.last_name || "").trim()]
    .filter(Boolean)
    .join(" ")
    .trim();
}

function firstNameOnly(row) {
  const first = String(row?.first_name || "").trim();
  if (first) return first;
  const full = fullName(row);
  return full ? full.split(/\s+/)[0] : "";
}

function countOr0(v) {
  return (v ?? 0).toString();
}

function compactTitleList(values) {
  const clean = values.map((v) => String(v || "").trim()).filter(Boolean);
  if (!clean.length) return "—";
  if (clean.length === 1) return clean[0];
  if (clean.length === 2) return `${clean[0]} · ${clean[1]}`;
  return `${clean[0]} (+${clean.length - 1})`;
}

function renderTable(title, cols, rows) {
  const header = cols.map((c) => `<th style="text-align:left;padding:8px;border-bottom:1px solid rgba(255,255,255,0.14);font-size:13px;background:rgba(255,255,255,0.06);">${esc(c)}</th>`).join("");
  const body = rows.map((r) => `
    <tr>
      ${r.map((cell) => `<td style="padding:8px;border-bottom:1px solid rgba(255,255,255,.08);font-size:13px;vertical-align:top;">${esc(cell)}</td>`).join("")}
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

// ─── Wrapper local pour ajouter recipient* au routing partagé ──────────────
// Le routing _shared/ ne couvre pas weekly_report_email. On enrichit ici.

function resolveWeeklyMailRouting(ctx) {
  const baseRouting = resolveMailRouting(ctx);
  const recipientEmail = String(
    ctx?.weekly_report_email
      || ctx?.admin_notification_email
      || ADMIN_EMAIL
      || ""
  ).trim() || null;
  const recipientName = String(
    ctx?.reply_to_name
      || ctx?.signature_short
      || ADMIN_NAME
      || baseRouting.senderName
      || ""
  ).trim() || null;
  return { ...baseRouting, recipientEmail, recipientName };
}

// ─── Render du mail HTML rapport ─────────────────────────────────────────

function renderReportEmail(opts) {
  const pre = String(opts.preheader || "").trim();
  const showNetworkLogo = !!opts.routing.networkLogoUrl;
  const showLibraryLogo = !!opts.routing.libraryLogoUrl && opts.routing.libraryLogoUrl !== opts.routing.networkLogoUrl;
  const networkLogoHtml = showNetworkLogo ? `<img src="${esc(opts.routing.networkLogoUrl)}" alt="AnarBib" style="display:block;max-width:84px;max-height:52px;width:auto;height:auto;object-fit:contain;">` : "";
  const libraryLogoHtml = showLibraryLogo ? `<img src="${esc(opts.routing.libraryLogoUrl)}" alt="${esc(opts.routing.brandName)}" style="display:block;max-width:84px;max-height:52px;width:auto;height:auto;object-fit:contain;">` : "";
  const html = `<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(opts.subject)}</title>
</head>
<body style="margin:0;background:#0f0f10;color:#ffffff;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;">
  ${pre ? `<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${esc(pre)}</div>` : ""}
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;">
    <tr>
      <td align="center" style="padding:24px 12px;">
        <table role="presentation" width="680" cellspacing="0" cellpadding="0" style="border-collapse:collapse;max-width:680px;width:100%;">
          <tr>
            <td style="background:rgba(27,27,27,0.94);border:1px solid rgba(255,255,255,0.12);border-radius:18px;overflow:hidden;">
              <div style="padding:18px 18px 14px;display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;">
                <div style="display:flex;align-items:center;gap:12px;min-width:0;">
                  ${networkLogoHtml}
                  <div>
                    <div style="font-size:18px;font-weight:800;line-height:1.2;">${esc(opts.routing.brandName)}</div>
                    <div style="font-size:13px;color:#cfcfcf;line-height:1.2;">Relatório semanal automático</div>
                  </div>
                </div>
                ${showLibraryLogo ? `<div style="display:flex;align-items:center;justify-content:flex-end;">${libraryLogoHtml}</div>` : ""}
              </div>
              <div style="height:3px;background:#c00000;"></div>
              <div style="padding:18px;">
                <h1 style="margin:0 0 12px;font-size:20px;line-height:1.25;">${esc(opts.title)}</h1>
                <div style="font-size:16px;line-height:1.55;color:#f2f2f2;">${opts.summaryHtml}</div>
                <div style="margin-top:18px;">${opts.tablesHtml.join("\n")}</div>
                <div style="margin:18px 0 0;font-size:13px;line-height:1.5;color:#cfcfcf;">${opts.routing.footerHtml}</div>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 6px 0;color:#9c9c9c;font-size:12px;line-height:1.4;text-align:center;">
              © ${esc(opts.routing.subjectTag)} — ${esc(opts.routing.footerText)}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body></html>`;
  const summaryText = opts.summaryHtml.replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>\s*<p>/gi, "\n\n").replace(/<[^>]+>/g, "").replace(/&nbsp;/g, " ").trim();
  const textParts = [
    `${opts.routing.brandName} (${opts.routing.subjectTag})`,
    opts.title,
    "",
    summaryText,
    "",
    `Rodapé local: ${opts.routing.footerText}`
  ];
  return { html, text: textParts.join("\n") };
}

// ─── Helpers de fetch / groupage ──────────────────────────────────────────

async function fetchProfiles(sb, userIds) {
  const map = new Map();
  const ids = Array.from(new Set(userIds.filter(Boolean)));
  if (!ids.length) return map;
  const { data, error } = await sb.from("profiles").select("id,email,first_name,last_name").in("id", ids);
  if (error) throw new Error(`Profiles query failed: ${error.message}`);
  for (const row of data || []) {
    map.set(String(row.id), row);
  }
  return map;
}

function groupReservationItems(items) {
  const map = new Map();
  for (const item of items || []) {
    const key = Number(item.reserva_id || 0);
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(item);
  }
  for (const entry of map.values()) {
    entry.sort((a, b) => Number(a.line_no || 0) - Number(b.line_no || 0));
  }
  return map;
}

function groupLoanItems(items) {
  const map = new Map();
  for (const item of items || []) {
    const key = Number(item.emprestimo_id || 0);
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(item);
  }
  for (const entry of map.values()) {
    entry.sort((a, b) => Number(a.line_no || 0) - Number(b.line_no || 0));
  }
  return map;
}

function groupReturnRows(rows) {
  const map = new Map();
  for (const row of rows || []) {
    const key = Number(row.emprestimo_id || 0);
    if (!map.has(key)) map.set(key, []);
    map.get(key).push(row);
  }
  for (const entry of map.values()) {
    entry.sort((a, b) => Number(a.line_no || 0) - Number(b.line_no || 0));
  }
  return map;
}

async function tryUpdateRunStatus(sb, runId, patch) {
  if (!runId) return;
  try {
    const { error } = await sb.from("weekly_admin_report_runs").update(patch).eq("id", runId);
    if (error) console.warn("weekly_admin_report_runs update skipped:", error.message);
  } catch (error) {
    console.warn("weekly_admin_report_runs update failed:", error);
  }
}

// ─── Handler principal ─────────────────────────────────────────────────────

// ============================================================================
// Transport mail — envoi via Resend
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend) : R.3.2 avait introduit un dispatch
// Brevo/Resend pilote par MAIL_PROVIDER ; R.6 (05/06/2026) a retire Brevo.
// sendEmail() appelle desormais directement sendViaResend(). Le secret
// MAIL_PROVIDER a ete retire de Supabase en R.7 (08/06/2026) ; n'est
// plus lu par le code.
//
// CONTRAT : string en succes, throw sur erreur HTTP. Le serve garde sa gestion
// du run : tryUpdateRunStatus(failed) avant re-throw, tryUpdateRunStatus(sent)
// apres succes — comportement strictement preserve.
// ============================================================================
function formatMailAddress(email, name) {
  const n = String(name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Resend (cf. spec §4.4) ---------------------------------
async function sendViaResend(opts) {
  const { routing, subject, htmlContent, textContent } = opts;
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (!resendKey) {
    throw new Error("RESEND_API_KEY absente des secrets Edge Function");
  }
  const payload: Record<string, unknown> = {
    from: formatMailAddress(routing.senderEmail, routing.senderName),
    to: [routing.recipientEmail],
    subject,
    html: htmlContent,
    text: textContent
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
  console.log(`[weekly-report] envoi via resend`);
  return await sendViaResend(opts);
}

serve(async (req) => {
  const body = await req.json().catch(() => null);
  const runId = body?.run_id ?? null;
  try {
    if (req.method !== "POST") return json(405, { ok: false, error: "Method not allowed" });
    const expected = mustEnv("WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT");
    const got = (req.headers.get("x-webhook-secret") ?? "").trim();
    if (!got || got !== expected) return json(401, { ok: false, error: "Unauthorized" });
    if (!body?.week_start || !body?.week_end) {
      return json(400, { ok: false, error: "Bad payload: week_start and week_end are required" });
    }
    const libraryId = String(body.library_id || "").trim();
    if (!libraryId) {
      return json(400, { ok: false, error: "Bad payload: library_id is required" });
    }
    const weekStart = body.week_start;
    const weekEnd = body.week_end;
    const tz = (body.tz ?? Deno.env.get("DEFAULT_NOTIFICATION_TIMEZONE") ?? Deno.env.get("DEFAULT_TIMEZONE") ?? Deno.env.get("NETWORK_DEFAULT_TIMEZONE") ?? "UTC").trim();

    // On utilise supabaseAdmin partagé depuis _shared/core/env.ts
    const sb = supabaseAdmin;

    const weeklyLibrarySummaryEnabled = await resolveWeeklyLibrarySummaryEnabled(sb, libraryId);
    if (!weeklyLibrarySummaryEnabled) {
      await tryUpdateRunStatus(sb, runId, { status: "skipped", error: null });
      return json(200, {
        ok: true,
        skipped: true,
        reason: "weekly_library_summary_disabled",
        run_id: runId,
        library_id: libraryId,
        week_start: weekStart,
        week_end: weekEnd
      });
    }

    const startISO = toISO00Z(weekStart);
    const endExclusiveISO = addDaysISO(weekEnd, 1);
    const weekEndPlusOneDate = addDaysISO(weekEnd, 1).slice(0, 10);

    // Résolution du contexte et du routing via _shared/
    const ctx = await resolveLibraryNotificationContext(libraryId);
    const routing = resolveWeeklyMailRouting(ctx);

    if (!routing.channelActive) {
      return json(409, { ok: false, error: "Weekly report channel is disabled for this library", library_id: libraryId });
    }
    if (!routing.recipientEmail || !isValidEmail(routing.recipientEmail)) {
      return json(422, { ok: false, error: "No valid weekly report recipient configured for this library", library_id: libraryId });
    }

    // ─── Réservations créées dans la semaine ───────────────────────────────
    const { count: reservasCount, error: reservasCountErr } = await sb.from("reservas_v2").select("id", { count: "exact", head: true }).eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO);
    if (reservasCountErr) throw new Error(`Reservations count query failed: ${reservasCountErr.message}`);
    const { data: reservasRaw, error: reservasErr } = await sb.from("reservas_v2").select("id,user_id,created_at").eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO).order("created_at", { ascending: false }).limit(50);
    if (reservasErr) throw new Error(`Reservations query failed: ${reservasErr.message}`);
    const reservas = reservasRaw || [];
    const reservationIds = reservas.map((r) => Number(r.id || 0)).filter((v) => v > 0);
    const { data: reservaItemsRaw, error: reservaItemsErr } = reservationIds.length ? await sb.schema("api").from("reserva_itens_followup_ui").select("reserva_id,line_no,bib_ref,titulo,autor").in("reserva_id", reservationIds).order("line_no", { ascending: true }) : { data: [], error: null };
    if (reservaItemsErr) throw new Error(`Reservation items query failed: ${reservaItemsErr.message}`);
    const reservaItems = reservaItemsRaw || [];
    const reservationProfiles = await fetchProfiles(sb, reservas.map((r) => String(r.user_id || "")).filter(Boolean));
    const reservationItemsByReserva = groupReservationItems(reservaItems);
    const reservasRows = reservas.map((r) => {
      const profile = reservationProfiles.get(String(r.user_id || ""));
      const items = reservationItemsByReserva.get(Number(r.id || 0)) || [];
      return [
        String(r.id ?? "—"),
        isoDateOnly(r.created_at),
        compactTitleList(items.map((it) => String(it.titulo || it.bib_ref || "").trim()).filter(Boolean)),
        String(profile?.email || "—"),
        fullName(profile) || "—"
      ];
    });

    // ─── Consultas locais registradas dans la semaine ──────────────────────
    const { count: consultasCount, error: consultasCountErr } = await sb.from("consultas_locais_v2").select("id", { count: "exact", head: true }).eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO);
    if (consultasCountErr) throw new Error(`Consultations count query failed: ${consultasCountErr.message}`);
    const { data: consultasRaw, error: consultasErr } = await sb.from("consultas_locais_v2").select("id,user_id,created_at").eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO).order("created_at", { ascending: false }).limit(50);
    if (consultasErr) throw new Error(`Consultations query failed: ${consultasErr.message}`);
    const consultas = consultasRaw || [];
    const consultasProfiles = await fetchProfiles(sb, consultas.map((c) => String(c.user_id || "")).filter(Boolean));
    const consultasRows = consultas.map((c) => {
      const profile = consultasProfiles.get(String(c.user_id || ""));
      return [
        String(c.id ?? "—"),
        isoDateOnly(c.created_at),
        String(profile?.email || "—"),
        fullName(profile) || "—"
      ];
    });

    // ─── Empréstimos criados dans la semaine ───────────────────────────────
    const { count: loansCreatedCount, error: loansCreatedCountErr } = await sb.from("emprestimos_v2").select("id", { count: "exact", head: true }).eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO);
    if (loansCreatedCountErr) throw new Error(`Loans(created) count query failed: ${loansCreatedCountErr.message}`);
    const { data: loansCreatedRaw, error: loansCreatedErr } = await sb.from("emprestimos_v2").select("id,user_id,created_at,due_at,extended_at").eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO).order("created_at", { ascending: false }).limit(50);
    if (loansCreatedErr) throw new Error(`Loans(created) query failed: ${loansCreatedErr.message}`);
    const loansCreated = loansCreatedRaw || [];
    const loansCreatedIds = loansCreated.map((l) => Number(l.id || 0)).filter((v) => v > 0);
    const { data: loansCreatedItemsRaw, error: loansCreatedItemsErr } = loansCreatedIds.length ? await sb.schema("api").from("emprestimo_itens_painel_ui").select("emprestimo_id,line_no,bib_ref,titulo,autor,user_email,user_name,due_at").in("emprestimo_id", loansCreatedIds).order("line_no", { ascending: true }) : { data: [], error: null };
    if (loansCreatedItemsErr) throw new Error(`Loan items(created) query failed: ${loansCreatedItemsErr.message}`);
    const loansCreatedItems = loansCreatedItemsRaw || [];
    const loansCreatedProfiles = await fetchProfiles(sb, loansCreated.map((l) => String(l.user_id || "")).filter(Boolean));
    const loansCreatedItemsByLoan = groupLoanItems(loansCreatedItems);
    const loansCreatedRows = loansCreated.map((l) => {
      const items = loansCreatedItemsByLoan.get(Number(l.id || 0)) || [];
      const firstItem = items[0];
      const profile = loansCreatedProfiles.get(String(l.user_id || ""));
      return [
        String(l.id ?? "—"),
        isoDateOnly(l.created_at),
        String(l.due_at || firstItem?.due_at || "—"),
        compactTitleList(items.map((it) => String(it.titulo || it.bib_ref || "").trim()).filter(Boolean)),
        String(firstItem?.user_name || firstNameOnly(profile) || fullName(profile) || "—")
      ];
    });

    // ─── Renouvellements (extended_at dans la semaine) ─────────────────────
    const { count: renewalsCount, error: renewalsCountErr } = await sb.from("emprestimos_v2").select("id", { count: "exact", head: true }).eq("library_id", libraryId).not("extended_at", "is", null).gte("extended_at", startISO).lt("extended_at", endExclusiveISO);
    if (renewalsCountErr) throw new Error(`Renewals count query failed: ${renewalsCountErr.message}`);
    const { data: renewalsRaw, error: renewalsErr } = await sb.from("emprestimos_v2").select("id,user_id,created_at,due_at,extended_at").eq("library_id", libraryId).not("extended_at", "is", null).gte("extended_at", startISO).lt("extended_at", endExclusiveISO).order("extended_at", { ascending: false }).limit(50);
    if (renewalsErr) throw new Error(`Renewals query failed: ${renewalsErr.message}`);
    const renewals = renewalsRaw || [];
    const renewalIds = renewals.map((l) => Number(l.id || 0)).filter((v) => v > 0);
    const { data: renewalsItemsRaw, error: renewalsItemsErr } = renewalIds.length ? await sb.schema("api").from("emprestimo_itens_painel_ui").select("emprestimo_id,line_no,bib_ref,titulo,autor,user_email,user_name,due_at").in("emprestimo_id", renewalIds).order("line_no", { ascending: true }) : { data: [], error: null };
    if (renewalsItemsErr) throw new Error(`Loan items(renewals) query failed: ${renewalsItemsErr.message}`);
    const renewalsItems = renewalsItemsRaw || [];
    const renewalsProfiles = await fetchProfiles(sb, renewals.map((l) => String(l.user_id || "")).filter(Boolean));
    const renewalsItemsByLoan = groupLoanItems(renewalsItems);
    const renewalsRows = renewals.map((l) => {
      const items = renewalsItemsByLoan.get(Number(l.id || 0)) || [];
      const firstItem = items[0];
      const profile = renewalsProfiles.get(String(l.user_id || ""));
      return [
        String(l.id ?? "—"),
        isoDateTime(l.extended_at),
        String(l.due_at || firstItem?.due_at || "—"),
        compactTitleList(items.map((it) => String(it.titulo || it.bib_ref || "").trim()).filter(Boolean)),
        String(firstItem?.user_name || firstNameOnly(profile) || fullName(profile) || "—")
      ];
    });

    // ─── Devoluções (returned_at dans la semaine) ──────────────────────────
    const joinedLoanSelect = "id,emprestimo_id,line_no,bib_ref,titulo_cache,autor_cache,returned_at,due_at,emprestimos_v2!inner(id,library_id,user_id)";
    const { count: returnsCount, error: returnsCountErr } = await sb.from("emprestimo_itens_v2").select(joinedLoanSelect, { count: "exact", head: true }).eq("emprestimos_v2.library_id", libraryId).not("returned_at", "is", null).gte("returned_at", startISO).lt("returned_at", endExclusiveISO);
    if (returnsCountErr) throw new Error(`Returns count query failed: ${returnsCountErr.message}`);
    const { data: returnsRaw, error: returnsErr } = await sb.from("emprestimo_itens_v2").select(joinedLoanSelect).eq("emprestimos_v2.library_id", libraryId).not("returned_at", "is", null).gte("returned_at", startISO).lt("returned_at", endExclusiveISO).order("returned_at", { ascending: false }).limit(50);
    if (returnsErr) throw new Error(`Returns query failed: ${returnsErr.message}`);
    const returns = returnsRaw || [];
    const returnProfiles = await fetchProfiles(sb, returns.map((row) => String(row.emprestimos_v2?.user_id || "")).filter(Boolean));
    const returnsByLoan = groupReturnRows(returns);
    const returnsRows = Array.from(returnsByLoan.entries()).map(([emprestimoId, items]) => {
      const first = items[0];
      const profile = returnProfiles.get(String(first?.emprestimos_v2?.user_id || ""));
      return [
        String(emprestimoId || "—"),
        isoDateTime(first?.returned_at),
        compactTitleList(items.map((it) => String(it.titulo_cache || it.bib_ref || "").trim()).filter(Boolean)),
        fullName(profile) || firstNameOnly(profile) || "—"
      ];
    });

    // ─── Atrasos ativos ────────────────────────────────────────────────────
    const { count: overdueActiveCount, error: overdueCountErr } = await sb.from("emprestimo_itens_v2").select(joinedLoanSelect, { count: "exact", head: true }).eq("emprestimos_v2.library_id", libraryId).eq("item_status", "aberto").lt("due_at", weekEndPlusOneDate);
    if (overdueCountErr) throw new Error(`Overdue(active) count query failed: ${overdueCountErr.message}`);
    const { data: overdueRaw, error: overdueErr } = await sb.from("emprestimo_itens_v2").select(joinedLoanSelect).eq("emprestimos_v2.library_id", libraryId).eq("item_status", "aberto").lt("due_at", weekEndPlusOneDate).order("due_at", { ascending: true }).limit(50);
    if (overdueErr) throw new Error(`Overdue(active) query failed: ${overdueErr.message}`);
    const overdueActive = overdueRaw || [];
    const overdueProfiles = await fetchProfiles(sb, overdueActive.map((row) => String(row.emprestimos_v2?.user_id || "")).filter(Boolean));
    const overdueByLoan = groupReturnRows(overdueActive);
    const overdueRows = Array.from(overdueByLoan.entries()).map(([emprestimoId, items]) => {
      const first = items[0];
      const profile = overdueProfiles.get(String(first?.emprestimos_v2?.user_id || ""));
      return [
        String(emprestimoId || "—"),
        String(first?.due_at || "—"),
        compactTitleList(items.map((it) => String(it.titulo_cache || it.bib_ref || "").trim()).filter(Boolean)),
        fullName(profile) || firstNameOnly(profile) || "—"
      ];
    });

    // ─── Activité PEB (prêt interbibliothèques) — chantier #ILL-reports ─────
    // Une bibliothèque est tantôt prêteuse, tantôt emprunteuse : son activité
    // PEB se lit donc des deux côtés. Trois compteurs :
    //   - PEB consentis  : prêts où elle est prêteuse, créés dans la semaine
    //   - PEB sollicités : prêts où elle est emprunteuse, créés dans la semaine
    //   - PEB en circulation : prêts (tout rôle) encore dehors à la clôture
    // NB : le compteur « en circulation » s'appuie sur status_global, dont la
    // fiabilité reste imparfaite tant que #ILL-lifecycle n'est pas traité.
    // Le bloc PEB est toujours rendu, même sans activité (compteurs à 0).
    const pebInCirculationStatuses = ["emprestado", "parcialmente_devolvido", "atrasado"];

    const { count: pebLentCount, error: pebLentCountErr } = await sb.from("interlibrary_loans_v2")
      .select("id", { count: "exact", head: true })
      .eq("lender_library_id", libraryId)
      .gte("created_at", startISO).lt("created_at", endExclusiveISO);
    if (pebLentCountErr) throw pebLentCountErr;

    const { count: pebBorrowedCount, error: pebBorrowedCountErr } = await sb.from("interlibrary_loans_v2")
      .select("id", { count: "exact", head: true })
      .eq("borrower_library_id", libraryId)
      .gte("created_at", startISO).lt("created_at", endExclusiveISO);
    if (pebBorrowedCountErr) throw pebBorrowedCountErr;

    const { count: pebInCirculationCount, error: pebInCirculationCountErr } = await sb.from("interlibrary_loans_v2")
      .select("id", { count: "exact", head: true })
      .or(`lender_library_id.eq.${libraryId},borrower_library_id.eq.${libraryId}`)
      .in("status_global", pebInCirculationStatuses);
    if (pebInCirculationCountErr) throw pebInCirculationCountErr;

    // Détail : les PEB créés dans la semaine, les deux rôles confondus.
    const { data: pebRowsRaw, error: pebRowsErr } = await sb.from("interlibrary_loans_v2")
      .select("id,request_id,lender_library_id,borrower_library_id,status_global,created_at")
      .or(`lender_library_id.eq.${libraryId},borrower_library_id.eq.${libraryId}`)
      .gte("created_at", startISO).lt("created_at", endExclusiveISO)
      .order("created_at", { ascending: false }).limit(50);
    if (pebRowsErr) throw pebRowsErr;
    const pebRowsList = Array.isArray(pebRowsRaw) ? pebRowsRaw : [];

    // Nombre de documents par PEB (un seul appel groupé, puis comptage en JS).
    const pebLoanIds = pebRowsList.map((p) => p.id).filter(Boolean);
    const { data: pebItemsRaw, error: pebItemsErr } = pebLoanIds.length
      ? await sb.from("interlibrary_loan_items_v2")
          .select("interlibrary_loan_id").in("interlibrary_loan_id", pebLoanIds)
      : { data: [], error: null };
    if (pebItemsErr) throw pebItemsErr;
    const pebItemCountByLoan = new Map();
    for (const it of (pebItemsRaw || [])) {
      const k = String(it.interlibrary_loan_id);
      pebItemCountByLoan.set(k, (pebItemCountByLoan.get(k) || 0) + 1);
    }

    // Noms des bibliothèques partenaires (corrélation rôle/partenaire en JS,
    // comme fetchProfiles pour les profils — pas de jointure PostgREST).
    const pebPartnerIds = Array.from(new Set(
      pebRowsList.map((p) => String(p.lender_library_id) === libraryId
        ? p.borrower_library_id : p.lender_library_id).filter(Boolean)
    ));
    const pebLibNames = new Map();
    if (pebPartnerIds.length) {
      const { data: libsRaw, error: libsErr } = await sb.from("libraries")
        .select("id,name,short_name").in("id", pebPartnerIds);
      if (libsErr) throw libsErr;
      for (const l of (libsRaw || [])) {
        pebLibNames.set(String(l.id), String(l.name || l.short_name || l.id));
      }
    }

    const pebRows = pebRowsList.map((p) => {
      const isLender = String(p.lender_library_id) === libraryId;
      const partnerId = isLender ? p.borrower_library_id : p.lender_library_id;
      return [
        String(p.request_id || p.id || "—"),
        isLender ? "Emprestadora" : "Tomadora",
        pebLibNames.get(String(partnerId)) || "—",
        String(p.status_global || "—"),
        String(pebItemCountByLoan.get(String(p.id)) || 0)
      ];
    });

    // ─── Activité Trocas (intercâmbios interbibliotecas) — chantier #EA-11 ──
    // Une troca = document_permission_request d'object_type 'interlibrary_exchange'.
    // La bibliothèque est « impliquée » qu'elle soit requérante (requester) ou
    // cible (target). Trois compteurs :
    //   - propostas  : trocas créées dans la semaine, bibliothèque impliquée
    //   - aceitas    : trocas acceptées (status='accepted', decided_at dans la
    //                  semaine), bibliothèque impliquée
    //   - em curso   : trocas acceptées dont la phase d'exécution n'est ni
    //                  'completed' ni 'cancelled' (phase manquante/illisible =
    //                  en cours), bibliothèque impliquée, instantané à la clôture
    const trocasInvolving = `requester_library_id.eq.${libraryId},target_library_id.eq.${libraryId}`;

    const { count: trocasProposedCount, error: trocasProposedCountErr } = await sb.from("document_permission_requests")
      .select("id", { count: "exact", head: true })
      .eq("object_type", "interlibrary_exchange")
      .or(trocasInvolving)
      .gte("created_at", startISO).lt("created_at", endExclusiveISO);
    if (trocasProposedCountErr) throw trocasProposedCountErr;

    const { count: trocasAcceptedCount, error: trocasAcceptedCountErr } = await sb.from("document_permission_requests")
      .select("id", { count: "exact", head: true })
      .eq("object_type", "interlibrary_exchange")
      .eq("status", "accepted")
      .or(trocasInvolving)
      .gte("decided_at", startISO).lt("decided_at", endExclusiveISO);
    if (trocasAcceptedCountErr) throw trocasAcceptedCountErr;

    // En circulation : on récupère les trocas acceptées impliquant la
    // bibliothèque puis on compte côté JS celles dont la phase n'est ni
    // 'completed' ni 'cancelled' (object_ref illisible/sans phase = en cours).
    const { data: trocasOngoingRaw, error: trocasOngoingErr } = await sb.from("document_permission_requests")
      .select("id,status,object_ref")
      .eq("object_type", "interlibrary_exchange")
      .eq("status", "accepted")
      .or(trocasInvolving);
    if (trocasOngoingErr) throw trocasOngoingErr;
    const trocasOngoingCount = (Array.isArray(trocasOngoingRaw) ? trocasOngoingRaw : []).filter((row) => {
      try {
        const o = JSON.parse(row.object_ref || "null");
        const ph = o && o.execution_followup && o.execution_followup.phase;
        return !["completed", "cancelled"].includes(ph);
      } catch {
        return true;
      }
    }).length;

    // ─── Activité Partage numérique (ILL-digital) — chantier #ILL-7 ────────
    // La biblioteca est tantôt fonte (source_library_id), tantôt solicitante
    // (requester_library_id). Trois compteurs :
    //   - fornecidas  : partages où elle est source, demandés dans la semaine
    //   - solicitadas : partages où elle est demandeuse, demandés dans la semaine
    //   - em curso    : partages (tout rôle) non terminaux (≠ refuse/indisponible/cloture)
    const pdInvolving = `requester_library_id.eq.${libraryId},source_library_id.eq.${libraryId}`;
    const pdOngoingStates = ["demande", "accepte", "numerisation", "transmis"];

    const { count: pdProvidedCount, error: pdProvErr } = await sb.from("ill_digital_shares")
      .select("id", { count: "exact", head: true })
      .eq("source_library_id", libraryId)
      .gte("requested_at", startISO).lt("requested_at", endExclusiveISO);
    if (pdProvErr) throw pdProvErr;

    const { count: pdRequestedCount, error: pdReqErr } = await sb.from("ill_digital_shares")
      .select("id", { count: "exact", head: true })
      .eq("requester_library_id", libraryId)
      .gte("requested_at", startISO).lt("requested_at", endExclusiveISO);
    if (pdReqErr) throw pdReqErr;

    const { count: pdOngoingCount, error: pdOngErr } = await sb.from("ill_digital_shares")
      .select("id", { count: "exact", head: true })
      .or(pdInvolving)
      .in("flux_state", pdOngoingStates);
    if (pdOngErr) throw pdOngErr;

    const { data: pdRowsRaw, error: pdRowsErr } = await sb.from("ill_digital_shares")
      .select("id,requester_library_id,source_library_id,flux_state,requested_at,books(titulo),requester:libraries!requester_library_id(name,short_name),source:libraries!source_library_id(name,short_name)")
      .or(pdInvolving)
      .gte("requested_at", startISO).lt("requested_at", endExclusiveISO)
      .order("requested_at", { ascending: false }).limit(50);
    if (pdRowsErr) throw pdRowsErr;
    const pdRows = (Array.isArray(pdRowsRaw) ? pdRowsRaw : []).map((s) => {
      const isSource = String(s.source_library_id) === libraryId;
      const partner = isSource ? s.requester : s.source;
      return [
        String(s.books?.titulo || "—"),
        isSource ? "Fornecedora" : "Solicitante",
        String(partner?.short_name || partner?.name || "—"),
        String(s.flux_state || "—")
      ];
    });

    // ─── Composition du mail ───────────────────────────────────────────────
    const subject = `${routing.subjectTag} · Relatório semanal (${formatBR(weekStart)} → ${formatBR(weekEnd)})`;
    const title = `Relatório semanal — ${routing.brandName}`;
    const summaryHtml = `
      <div style="line-height:1.5;color:#f2f2f2;">
        <p style="margin:0 0 10px 0;"><b>Biblioteca:</b> ${esc(routing.brandName)}</p>
        <p style="margin:0 0 10px 0;"><b>Período:</b> ${esc(formatBR(weekStart))} → ${esc(formatBR(weekEnd))} (${esc(tz)})</p>
        <table role="presentation" cellspacing="0" cellpadding="0"
               style="border-collapse:collapse;border:1px solid rgba(255,255,255,0.14);width:100%;max-width:640px;">
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Reservas criadas</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(reservasCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Consultas registradas</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(consultasCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Empréstimos criados</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(loansCreatedCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Renovações</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(renewalsCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Devoluções</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(returnsCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Atrasos ativos (à clôture da semana)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(overdueActiveCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>PEB consentidos (como emprestadora)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(pebLentCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>PEB solicitados (como tomadora)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(pebBorrowedCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>PEB em circulação (à clôture da semana)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(pebInCirculationCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Partilhas digitais fornecidas (semana)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(pdProvidedCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Partilhas digitais solicitadas (semana)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(pdRequestedCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Partilhas digitais em curso (à clôture da semana)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(pdOngoingCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Trocas propostas (semana)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(trocasProposedCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);"><b>Trocas aceitas (semana)</b></td>
            <td style="padding:10px;border-bottom:1px solid rgba(255,255,255,.08);text-align:right;"><b>${countOr0(trocasAcceptedCount)}</b></td>
          </tr>
          <tr>
            <td style="padding:10px;"><b>Trocas em curso</b></td>
            <td style="padding:10px;text-align:right;"><b>${countOr0(trocasOngoingCount)}</b></td>
          </tr>
        </table>
      </div>
    `;
    const { html: htmlContent, text: textContent } = renderReportEmail({
      subject,
      title,
      preheader: `${routing.brandName} · relatório semanal`,
      summaryHtml,
      tablesHtml: [
        renderTable("Reservas criadas (últimas 50)", ["ID", "Data", "Livro", "Email", "Leitor(a/e)"], reservasRows),
        renderTable("Consultas registradas (últimas 50)", ["ID", "Data", "Email", "Leitor(a/e)"], consultasRows),
        renderTable("Empréstimos criados (últimos 50)", ["ID", "Criado em", "Vencimento", "Livro(s)", "Leitor(a/e)"], loansCreatedRows),
        renderTable("Renovações (últimas 50)", ["ID", "Renovado em", "Vencimento", "Livro(s)", "Leitor(a/e)"], renewalsRows),
        renderTable("Devoluções (últimas 50 linhas agrupadas por empréstimo)", ["Empréstimo", "Devolvido em", "Livro(s)", "Leitor(a/e)"], returnsRows),
        renderTable("Atrasos ativos (top 50)", ["Empréstimo", "Vencimento", "Livro(s)", "Leitor(a/e)"], overdueRows),
        renderTable("Intercâmbios interbibliotecas (PEB criados na semana, últimos 50)", ["Referência", "Papel", "Biblioteca parceira", "Estado", "Documentos"], pebRows),
        renderTable("Partilhas digitais (pedidos da semana, últimos 50)", ["Documento", "Papel", "Biblioteca parceira", "Estado"], pdRows)
      ],
      context: ctx,
      routing
    });

    // ─── Envoi mail ─────────────────────────────────────────────────────────
    // Transport mail : envoi via Resend (chantier #110, Brevo retire en R.6).
    // Le suivi du run (tryUpdateRunStatus) reste ici car il releve de la
    // logique de l'EF. En cas d'echec, on ecrit le statut "failed" avant de
    // re-propager l'exception.
    try {
      await sendEmail({ routing, subject, htmlContent, textContent });
    } catch (sendError) {
      await tryUpdateRunStatus(sb, runId, { status: "failed", error: String(sendError?.message ?? sendError) });
      throw sendError;
    }
    await tryUpdateRunStatus(sb, runId, { status: "sent", sent_at: new Date().toISOString(), error: null });
    return json(200, {
      ok: true,
      run_id: runId,
      library_id: libraryId,
      week_start: weekStart,
      week_end: weekEnd,
      recipient_email: routing.recipientEmail,
      subject,
      summary: {
        reservas: reservasCount ?? 0,
        consultas: consultasCount ?? 0,
        emprestimos_criados: loansCreatedCount ?? 0,
        renovacoes: renewalsCount ?? 0,
        devolucoes: returnsCount ?? 0,
        atrasos_ativos: overdueActiveCount ?? 0,
        peb_consentidos: pebLentCount ?? 0,
        peb_solicitados: pebBorrowedCount ?? 0,
        peb_em_circulacao: pebInCirculationCount ?? 0,
        trocas: trocasProposedCount ?? 0,
        partilhas_fornecidas: pdProvidedCount ?? 0,
        partilhas_solicitadas: pdRequestedCount ?? 0,
        partilhas_em_curso: pdOngoingCount ?? 0
      }
    });
  } catch (e) {
    try {
      await tryUpdateRunStatus(supabaseAdmin, runId, { status: "failed", error: String(e?.message ?? e) });
    } catch {
      // no-op
    }
    return json(500, { ok: false, error: String(e?.message ?? e), run_id: runId });
  }
});
