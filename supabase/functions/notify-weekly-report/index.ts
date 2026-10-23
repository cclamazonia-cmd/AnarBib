// ============================================================================
// notify-weekly-report — rapport hebdomadaire d'UNE bibliothèque
// ============================================================================
// RET-1 (REGISTRE §48, décision du 21/10/2026, livré le 23/10/2026) : le rapport
// ne porte plus que des COMPTEURS, et un lien vers le panneau. Il recopiait
// chaque semaine un fichier « qui lit quoi » — noms, courriels, titres rattachés
// à une personne, inscriptions et départs nominatifs — dans une boîte souvent
// hébergée hors du réseau, où il reste sans fin (copies du fournisseur,
// transferts, archives). Le détail se lit connecté, sous la double
// authentification des comptes d'équipe (2FA-1). Ici, plus aucune lecture de
// `profiles`, de titres ni de bibliothèque partenaire : seulement des comptages
// (`count`, `head: true`), et les états des échanges, sans personne.
//
// Suite de F26 (20/10/2026) : le rapport était composé en pt-BR seul, dans le
// code. Il part désormais dans la langue de la bibliothèque (default_locale de
// v_library_notification_context, comme les autres notify-*) : clés wr.* et
// net.* de _shared/i18n/mail-strings.ts, dates par formatDateLocale, pied du
// routage partagé dans la même langue. Un seul destinataire (weekly_report_email,
// à défaut admin_notification_email puis ADMIN_EMAIL) : une seule langue.
//
// Refactor du 06/05/2026 :
//   - Imports _shared/ racine pour la résolution du contexte de notification
//     (élimination de ~150 lignes de duplication avec _shared/context/)
//   - Wrapper local resolveWeeklyMailRouting pour ajouter recipientEmail/Name
//     spécifiques au weekly report (basés sur weekly_report_email)
//
// Webhook secret : WEBHOOK_SECRET_NOTIFY_WEEKLY_REPORT
// Mail           : Resend (RESEND_API_KEY) — Brevo retire en R.6 (05/06/2026)
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  ADMIN_EMAIL,
  ADMIN_NAME,
  SENDER_EMAIL,
  SENDER_NAME,
  supabaseAdmin
} from "../_shared/core/env.ts";
import { resolveLibraryNotificationContext } from "../_shared/context/library-notification-context.ts";
import { resolveMailRouting } from "../_shared/context/library-mail-routing.ts";
import { sendEmail as sendEmailPartage } from "../_shared/transport/email.ts";
import { appUrl } from "../_shared/core/app-url.ts";
import { localeDeProfil } from "../_shared/context/network-admins.ts";
import { tMailTexte, formatDateLocale } from "../_shared/i18n/mail-strings.ts";
import { esc as echapperHtml, desechapper } from "../_shared/shared/format.ts";

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
  // l'esc partagé, qui n'échappe pas deux fois une phrase de tMail
  return echapperHtml(s);
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

// Une date « AAAA-MM-JJ » dans la langue du rapport (même format que les autres courriels).
function formatDate(dateStr, loc) {
  const s = String(dateStr || "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return s || "—";
  return formatDateLocale(`${s}T00:00:00.000Z`, loc);
}

function countOr0(v) {
  return (v ?? 0).toString();
}

// ─── Wrapper local pour ajouter recipient* au routing partagé ──────────────
// Le routing _shared/ ne couvre pas weekly_report_email. On enrichit ici.
// La locale fait le pied (signature traduite, sinon layout.footerText) dans la
// langue du rapport.

function resolveWeeklyMailRouting(ctx, loc) {
  const baseRouting = resolveMailRouting(ctx, loc);
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
<html lang="${esc(opts.locale)}"><head>
<meta charset="utf-8"><meta name="color-scheme" content="dark"><meta name="supported-color-schemes" content="dark">
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
            <td style="background:rgba(27,27,27,0.94);color:#ffffff;border:1px solid rgba(255,255,255,0.12);border-radius:18px;overflow:hidden;">
              <div style="padding:18px 18px 14px;display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;">
                <div style="display:flex;align-items:center;gap:12px;min-width:0;">
                  ${networkLogoHtml}
                  <div>
                    <div style="font-size:18px;font-weight:800;line-height:1.2;">${esc(opts.routing.brandName)}</div>
                    <div style="font-size:13px;color:#cfcfcf;line-height:1.2;">${esc(tMailTexte(opts.locale, "wr.kicker"))}</div>
                  </div>
                </div>
                ${showLibraryLogo ? `<div style="display:flex;align-items:center;justify-content:flex-end;">${libraryLogoHtml}</div>` : ""}
              </div>
              <div style="height:3px;background:#c00000;"></div>
              <div style="padding:18px;">
                <h1 style="margin:0 0 12px;font-size:20px;line-height:1.25;">${esc(opts.title)}</h1>
                <div style="font-size:16px;line-height:1.55;color:#f2f2f2;">${opts.summaryHtml}</div>
                <p style="margin:18px 0 10px;font-size:15px;line-height:1.55;color:#f2f2f2;">${esc(opts.detail)}</p>
                <p style="margin:0;"><a href="${esc(opts.ctaUrl)}" style="display:inline-block;padding:10px 16px;border-radius:10px;background:#c00000;color:#ffffff;font-weight:700;text-decoration:none;">${esc(opts.ctaLabel)}</a></p>
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
  // le texte brut sans balises NI entités (« d&#039;inscription » → « d'inscription »),
  // une ligne par libellé et par nombre, sans l'indentation du gabarit HTML
  const summaryText = desechapper(opts.summaryHtml.replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>\s*<p>/gi, "\n\n").replace(/<[^>]+>/g, "").replace(/&nbsp;/g, " "))
    .split("\n").map((ligne) => ligne.trim()).filter(Boolean).join("\n");
  const textParts = [
    `${opts.routing.brandName} (${opts.routing.subjectTag})`,
    opts.title,
    "",
    summaryText,
    "",
    opts.detail,
    `${opts.ctaLabel} : ${opts.ctaUrl}`,
    "",
    opts.routing.footerText
  ];
  return { html, text: textParts.join("\n") };
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
// CONTRAT : string en succes, throw sur erreur HTTP. Le suivi d'un « run »
// (weekly_admin_report_runs) est retire le 01/10/2026 (F1) : la table n'existe
// pas en production et aucun appelant ne passe de run_id.
// ============================================================================
// --- Envoi : une seule implementation, celle de _shared (F7, 23/09/2026) ---
// Cette fonction portait sa propre copie de l'appel Resend. Le routage par
// bibliotheque est calcule ici comme avant et passe EXPLICITEMENT : le From et
// le Reply-To des messages restent ceux d'hier, seul le transport est partage.
async function sendEmail(opts) {
  const { routing, subject, htmlContent, textContent } = opts;
  return await sendEmailPartage({
    toEmail: routing.recipientEmail,
    subject,
    html: htmlContent,
    text: textContent,
    routing,
    label: "weekly-report"
  });
}

serve(async (req) => {
  const body = await req.json().catch(() => null);
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
      return json(200, {
        ok: true,
        skipped: true,
        reason: "weekly_library_summary_disabled",
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
    // La langue du rapport : celle de la bibliothèque (pt-BR si absente ou inconnue).
    const loc = localeDeProfil(ctx?.default_locale);
    const t = (cle, params = undefined) => tMailTexte(loc, cle, params);
    const routing = resolveWeeklyMailRouting(ctx, loc);

    if (!routing.channelActive) {
      return json(409, { ok: false, error: "Weekly report channel is disabled for this library", library_id: libraryId });
    }
    if (!routing.recipientEmail || !isValidEmail(routing.recipientEmail)) {
      return json(422, { ok: false, error: "No valid weekly report recipient configured for this library", library_id: libraryId });
    }

    // ─── Comptages de la semaine (RET-1 : des nombres, aucune personne) ────
    // Un comptage = { count: "exact", head: true } : PostgREST ne renvoie aucune
    // ligne, seulement le nombre. Rien de nominatif ne quitte la base.
    const compter = async (libelle, requete) => {
      const { count, error } = await requete;
      if (error) throw new Error(`${libelle} count query failed: ${error.message}`);
      return count ?? 0;
    };
    const tete = { count: "exact", head: true };
    const reservasCount = await compter("Reservations", sb.from("reservas_v2").select("id", tete).eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO));
    const consultasCount = await compter("Consultations", sb.from("consultas_locais_v2").select("id", tete).eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO));
    const loansCreatedCount = await compter("Loans(created)", sb.from("emprestimos_v2").select("id", tete).eq("library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO));
    const renewalsCount = await compter("Renewals", sb.from("emprestimos_v2").select("id", tete).eq("library_id", libraryId).not("extended_at", "is", null).gte("extended_at", startISO).lt("extended_at", endExclusiveISO));
    const joinedLoanSelect = "id,emprestimos_v2!inner(library_id)";
    const returnsCount = await compter("Returns", sb.from("emprestimo_itens_v2").select(joinedLoanSelect, tete).eq("emprestimos_v2.library_id", libraryId).not("returned_at", "is", null).gte("returned_at", startISO).lt("returned_at", endExclusiveISO));
    const overdueActiveCount = await compter("Overdue(active)", sb.from("emprestimo_itens_v2").select(joinedLoanSelect, tete).eq("emprestimos_v2.library_id", libraryId).eq("item_status", "aberto").lt("due_at", weekEndPlusOneDate));

    // PEB : une bibliothèque est tantôt prêteuse, tantôt emprunteuse. « En
    // circulation » s'appuie sur status_global (fiabilité imparfaite tant que
    // #ILL-lifecycle n'est pas traité).
    const pebInCirculationStatuses = ["emprestado", "parcialmente_devolvido", "atrasado"];
    const pebLentCount = await compter("ILL(lent)", sb.from("interlibrary_loans_v2").select("id", tete).eq("lender_library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO));
    const pebBorrowedCount = await compter("ILL(borrowed)", sb.from("interlibrary_loans_v2").select("id", tete).eq("borrower_library_id", libraryId).gte("created_at", startISO).lt("created_at", endExclusiveISO));
    const pebInCirculationCount = await compter("ILL(circulating)", sb.from("interlibrary_loans_v2").select("id", tete).or(`lender_library_id.eq.${libraryId},borrower_library_id.eq.${libraryId}`).in("status_global", pebInCirculationStatuses));

    // Trocas (document_permission_requests d'object_type 'interlibrary_exchange'),
    // bibliothèque requérante ou cible. « En cours » : acceptées dont la phase
    // d'exécution n'est ni 'completed' ni 'cancelled' (illisible = en cours) ; on
    // ne lit que l'état, jamais une personne.
    const trocasInvolving = `requester_library_id.eq.${libraryId},target_library_id.eq.${libraryId}`;
    const trocasProposedCount = await compter("Exchanges(proposed)", sb.from("document_permission_requests").select("id", tete).eq("object_type", "interlibrary_exchange").or(trocasInvolving).gte("created_at", startISO).lt("created_at", endExclusiveISO));
    const trocasAcceptedCount = await compter("Exchanges(accepted)", sb.from("document_permission_requests").select("id", tete).eq("object_type", "interlibrary_exchange").eq("status", "accepted").or(trocasInvolving).gte("decided_at", startISO).lt("decided_at", endExclusiveISO));
    const { data: trocasOngoingRaw, error: trocasOngoingErr } = await sb.from("document_permission_requests")
      .select("object_ref")
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

    // Partage numérique : la bibliothèque est source ou demandeuse.
    const pdInvolving = `requester_library_id.eq.${libraryId},source_library_id.eq.${libraryId}`;
    const pdOngoingStates = ["demande", "accepte", "numerisation", "transmis"];
    const pdProvidedCount = await compter("Digital(provided)", sb.from("ill_digital_shares").select("id", tete).eq("source_library_id", libraryId).gte("requested_at", startISO).lt("requested_at", endExclusiveISO));
    const pdRequestedCount = await compter("Digital(requested)", sb.from("ill_digital_shares").select("id", tete).eq("requester_library_id", libraryId).gte("requested_at", startISO).lt("requested_at", endExclusiveISO));
    const pdOngoingCount = await compter("Digital(ongoing)", sb.from("ill_digital_shares").select("id", tete).or(pdInvolving).in("flux_state", pdOngoingStates));

    // Lecteur·rices : inscriptions effectives et départs (reader_membership_events,
    // journal alimenté par trigger), demandes encore en attente de validation.
    const inscricoesCount = await compter("Reader inscriptions", sb.from("reader_membership_events").select("id", tete).eq("library_id", libraryId).eq("event_type", "inscricao").gte("changed_at", startISO).lt("changed_at", endExclusiveISO));
    const saidasCount = await compter("Reader departures", sb.from("reader_membership_events").select("id", tete).eq("library_id", libraryId).eq("event_type", "saida").gte("changed_at", startISO).lt("changed_at", endExclusiveISO));
    const solicitacoesPendentesCount = await compter("Reader pending requests", sb.from("user_library_memberships").select("id", tete).eq("library_id", libraryId).eq("role", "reader").eq("status", "pending_validation").gte("created_at", startISO).lt("created_at", endExclusiveISO));

    // ─── Composition du mail ───────────────────────────────────────────────
    // Suite de F26 (20/10/2026) : tout dans la langue de la bibliothèque (loc),
    // clés wr.* et, pour les libellés qu'il partage avec lui, celles du rapport
    // du réseau (net.*).
    const ligneSynthese = (label, valeur, derniere = false) => {
      const bord = derniere ? "" : "border-bottom:1px solid rgba(255,255,255,.08);";
      return `
          <tr>
            <td style="padding:10px;${bord}"><b>${esc(label)}</b></td>
            <td style="padding:10px;${bord}text-align:right;"><b>${countOr0(valeur)}</b></td>
          </tr>`;
    };
    const periode = { start: formatDate(weekStart, loc), end: formatDate(weekEnd, loc) };
    const subject = t("wr.subject", { tag: routing.subjectTag, ...periode });
    const title = t("wr.title", { brand: routing.brandName });
    const summaryHtml = `
      <div style="line-height:1.5;color:#f2f2f2;">
        <p style="margin:0 0 10px 0;"><b>${esc(t("wr.lbl.library"))}</b> ${esc(routing.brandName)}</p>
        <p style="margin:0 0 10px 0;"><b>${esc(t("net.lbl.period"))}</b> ${esc(periode.start)} → ${esc(periode.end)} (${esc(tz)})</p>
        <table role="presentation" cellspacing="0" cellpadding="0"
               style="border-collapse:collapse;border:1px solid rgba(255,255,255,0.14);width:100%;max-width:640px;">${[
          ligneSynthese(t("net.sum.readersIn"), inscricoesCount),
          ligneSynthese(t("net.sum.readersOut"), saidasCount),
          ligneSynthese(t("wr.sum.pendingRequests"), solicitacoesPendentesCount),
          ligneSynthese(t("net.sum.reservations"), reservasCount),
          ligneSynthese(t("net.sum.consultations"), consultasCount),
          ligneSynthese(t("net.sum.loans"), loansCreatedCount),
          ligneSynthese(t("net.sum.renewals"), renewalsCount),
          ligneSynthese(t("net.sum.returns"), returnsCount),
          ligneSynthese(t("net.sum.overdue"), overdueActiveCount),
          ligneSynthese(t("wr.sum.illLent"), pebLentCount),
          ligneSynthese(t("wr.sum.illBorrowed"), pebBorrowedCount),
          ligneSynthese(t("wr.sum.illCirculating"), pebInCirculationCount),
          ligneSynthese(t("wr.sum.digitalProvided"), pdProvidedCount),
          ligneSynthese(t("wr.sum.digitalRequested"), pdRequestedCount),
          ligneSynthese(t("wr.sum.digitalOngoing"), pdOngoingCount),
          ligneSynthese(t("net.sum.exchanges"), trocasProposedCount),
          ligneSynthese(t("wr.sum.exchangesAccepted"), trocasAcceptedCount),
          ligneSynthese(t("wr.sum.exchangesOngoing"), trocasOngoingCount, true)
        ].join("")}
        </table>
      </div>
    `;
    const { html: htmlContent, text: textContent } = renderReportEmail({
      locale: loc,
      subject,
      title,
      preheader: t("wr.preheader", { brand: routing.brandName }),
      summaryHtml,
      detail: t("wr.detail"),
      ctaLabel: t("wr.cta"),
      ctaUrl: appUrl("/painel"),
      context: ctx,
      routing
    });

    // ─── Envoi mail ─────────────────────────────────────────────────────────
    // Transport mail : envoi via Resend (chantier #110, Brevo retire en R.6).
    // Un echec remonte au catch du serve (500).
    await sendEmail({ routing, subject, htmlContent, textContent });
    return json(200, {
      ok: true,
      library_id: libraryId,
      week_start: weekStart,
      week_end: weekEnd,
      locale: loc,
      subject,
      summary: {
        novas_inscricoes_leitores: inscricoesCount ?? 0,
        saidas_leitores: saidasCount ?? 0,
        solicitacoes_pendentes: solicitacoesPendentesCount ?? 0,
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
    return json(500, { ok: false, error: String(e?.message ?? e) });
  }
});
