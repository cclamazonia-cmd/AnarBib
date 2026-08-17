// ============================================================================
// notify-interlibrary-loan — Notifications des prêts interbibliothèques (PEB)
// ============================================================================
// Remplace le stub non opérationnel (501) par l'implémentation réelle.
//
// Chaîne amont (inchangée) :
//   interlibrary_loans_v2 (INSERT/UPDATE status_global)
//     -> trg_interlibrary_loan_enqueue_notifications
//     -> fn_enqueue_emprestimo_interbibliotecas_notification (file d'attente)
//     -> fn_notify_emprestimo_interbibliotecas_webhook (POST vers cette EF)
//
// Événements gérés (8) :
//   created · prepared · dispatched · return_started · returned
//   · cancelled · overdue · partially_returned
//
//   Deux de ces événements sont DORMANTS — leur branche est prête mais le
//   trigger SQL ne les émet pas encore :
//     - overdue : aucun statut 'atrasado' n'est posé aujourd'hui (cron à venir).
//     - partially_returned : le trigger n'a pas de branche pour le statut
//       'parcialmente_devolvido'. Voir chantier #ILL-partial.
//   Les gérer ici dès maintenant évite de rouvrir l'EF plus tard.
//
// Modèle de notification :
//   - created : 4 contenus selon la matrice {prêteuse|emprunteuse} ×
//     {initiatrice|partenaire}. L'initiatrice reçoit une confirmation ;
//     la partenaire reçoit une sollicitation avec actionBox portant le
//     contact de coordination.
//   - changements de statut : symétrique — les deux bibliothèques reçoivent
//     le même mail, adapté à leur locale et à leur logo.
//
// Table de détails (documents) :
//   - affichée pour tous les événements SAUF 'cancelled' (un prêt annulé
//     n'a plus de détail d'exemplaires à montrer) ;
//   - particulièrement utile sur 'partially_returned', où elle indique
//     document par document ce qui est rentré et ce qui est encore dehors.
//
// Dépendances partagées (lues et vérifiées) :
//   - _shared/transport/email.ts   : safeSendEmail (Resend hérité du wrapper)
//   - _shared/mail/layout.ts       : renderEmail, footerPadrao
//   - _shared/context/library-notification-context.ts : resolveLibraryNotificationContext
//   - _shared/i18n/mail-strings.ts : tMail (8 locales)
//   - _shared/core/webhook.ts      : authorizeWebhook, jsonResponse, parseJsonPayload
//   Secret webhook : variable d'env DÉDIÉE NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET
//   (PAS le WEBHOOK_SECRET de env.ts, qui est celui de notify-event).
//
// Auth : on exige le secret webhook (auth.webhookOk), pas le simple Bearer —
// ce webhook est strictement machine-à-machine. Choix durci validé.
//
// Voir docs/decisions/MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md (à réviser).
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { authorizeWebhook, jsonResponse, parseJsonPayload } from "../_shared/core/webhook.ts";
import { renderEmail, footerPadrao } from "../_shared/mail/layout.ts";
import { safeSendEmail } from "../_shared/transport/email.ts";
import { resolveLibraryNotificationContext } from "../_shared/context/library-notification-context.ts";
import { tMail } from "../_shared/i18n/mail-strings.ts";

// ─── Secret webhook DÉDIÉ au module PEB ─────────────────────────────────────
// IMPORTANT : on NE réutilise PAS le WEBHOOK_SECRET de _shared/core/env.ts —
// celui-ci lit WEBHOOK_SECRET_NOTIFY_EVENT, le secret de l'EF notify-event.
// La chaîne PEB a son propre secret : la fonction SQL
// fn_notify_emprestimo_interbibliotecas_webhook lit dans le vault
// NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET et l'envoie dans x-webhook-secret.
// L'EF doit donc comparer au MÊME secret, lu depuis sa variable d'env dédiée.
// (Le secret est present cote Edge Functions — verifie via `supabase secrets list`.)
const WEBHOOK_SECRET = (Deno.env.get("NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET") || "").trim();

// ─── Types de payload (forme produite par fn_notify_..._webhook) ────────────
interface IllLoan {
  id: number | null;
  request_id: string | null;
  status_global: string | null;
  start_date: string | null;
  due_date: string | null;
  dispatched_at: string | null;
  return_started_at: string | null;
  returned_at: string | null;
  lender_library_id: string | null;
  lender_library_name: string | null;
  lender_library_short_name: string | null;
  borrower_library_id: string | null;
  borrower_library_name: string | null;
  borrower_library_short_name: string | null;
  // Bibliothèque à l'origine du flux PEB — transmise par fn_notify_..._webhook
  // DANS l'objet 'loan' (cf. migration 20260522020000). Sert à la matrice 'created'.
  initiated_by_library_id: string | null;
  coordination_contact_name: string | null;
  coordination_contact_email: string | null;
  coordination_contact_phone: string | null;
  logistics_mode: string | null;
  meeting_point: string | null;
  notes: string | null;
}
interface IllItem {
  line_no: number | null;
  titulo: string | null;
  autor: string | null;
  tombo: string | null;
  bib_ref: string | null;
  item_status: string | null;
}
interface IllPayload {
  source?: string;
  kind?: string;
  event_id?: number;
  event_type?: string;
  event_key?: string;
  created_at?: string;
  loan?: IllLoan;
  items?: IllItem[];
}

// ─── Les huit événements connus ─────────────────────────────────────────────
const KNOWN_EVENTS = new Set([
  "interlibrary_loan_created",
  "interlibrary_loan_prepared",
  "interlibrary_loan_dispatched",
  "interlibrary_loan_return_started",
  "interlibrary_loan_returned",
  "interlibrary_loan_cancelled",
  "interlibrary_loan_overdue",
  "interlibrary_loan_partially_returned",
]);

// Événements pour lesquels la table de détails (documents) n'est PAS affichée.
const EVENTS_WITHOUT_DETAILS = new Set(["cancelled"]);

// event_type complet -> clé courte i18n (ill.subject.<court>, etc.)
function shortKey(eventType: string): string {
  return eventType.replace(/^interlibrary_loan_/, "");
}

// ─── Rendu d'une valeur logistics_mode ──────────────────────────────────────
// logistics_mode est désormais une énumération (CHECK en base, #ILL-logistics) :
// envio_postal, entrega_em_maos, transporte_militante, a_combinar. On traduit
// les valeurs connues via une clé i18n ; toute valeur inconnue (donnée
// ancienne) est affichée brute.
function renderLogistics(mode: string | null, locale: string): string | null {
  if (!mode) return null;
  const KNOWN = new Set([
    "envio_postal",
    "entrega_em_maos",
    "transporte_militante",
    "a_combinar",
  ]);
  if (KNOWN.has(mode)) return tMail(locale, `ill.logistics.${mode}`);
  return mode; // valeur non répertoriée : affichage brut
}

// ─── Détails de la table mail (libellés via tMail, valeurs depuis loan) ─────
// short : événement courant ('partially_returned', 'returned', etc.). Sur
// 'partially_returned' et 'returned', chaque exemplaire affiche son statut
// individuel, et une ligne de synthèse chiffrée précède le détail — c'est
// l'information centrale de ces deux événements.
function buildDetails(loan: IllLoan, items: IllItem[], locale: string, short: string) {
  const d: { label: string; value: string }[] = [];
  d.push({ label: tMail(locale, "ill.detail.loanRef"),
           value: loan.request_id || `#${loan.id ?? "—"}` });
  d.push({ label: tMail(locale, "ill.detail.lender"),
           value: loan.lender_library_name || "—" });
  d.push({ label: tMail(locale, "ill.detail.borrower"),
           value: loan.borrower_library_name || "—" });
  if (loan.start_date) {
    d.push({ label: tMail(locale, "ill.detail.startDate"), value: loan.start_date });
  }
  if (loan.due_date) {
    d.push({ label: tMail(locale, "ill.detail.dueDate"), value: loan.due_date });
  }
  const logistics = renderLogistics(loan.logistics_mode, locale);
  if (logistics) {
    d.push({ label: tMail(locale, "ill.detail.logistics"), value: logistics });
  }
  if (loan.meeting_point) {
    d.push({ label: tMail(locale, "ill.detail.meetingPoint"), value: loan.meeting_point });
  }

  // Faut-il afficher le statut de chaque exemplaire ? Oui sur les deux
  // événements où les exemplaires peuvent être dans des états différents.
  const withItemStatus = short === "partially_returned" || short === "returned";

  d.push({ label: tMail(locale, "ill.detail.itemCount"),
           value: String(items.length) });

  // Ligne de synthèse chiffrée — uniquement sur 'partially_returned', où
  // savoir « combien rendus / combien encore dehors » d'un coup d'œil est
  // l'information clé.
  if (short === "partially_returned") {
    const settled = items.filter((it) =>
      ["devolvido", "perdido", "danificado", "cancelado"].includes(it.item_status || "")).length;
    const outstanding = items.length - settled;
    d.push({
      label: tMail(locale, "ill.detail.returnSummary"),
      value: tMail(locale, "ill.detail.returnSummaryValue",
                   { settled: settled, outstanding: outstanding }),
    });
  }

  for (const it of items) {
    const ref = [it.titulo, it.autor].filter(Boolean).join(" — ") || it.bib_ref || "—";
    const tombo = it.tombo ? ` (${it.tombo})` : "";
    // Sur partially_returned / returned : le statut de l'exemplaire est
    // préfixé en évidence devant le titre.
    const statusPrefix = withItemStatus && it.item_status
      ? `${tMail(locale, `ill.itemStatus.${it.item_status}`)} — `
      : "";
    d.push({ label: `· ${tMail(locale, "ill.detail.itemLine")} ${it.line_no ?? ""}`.trim(),
             value: `${statusPrefix}${ref}${tombo}` });
  }
  return d;
}

// ─── Construit et envoie UN mail vers UNE bibliothèque ──────────────────────
// roleInLoan : 'lender' | 'borrower'  (rôle de la biblio destinataire)
// roleInFlow : 'initiator' | 'partner' | 'symmetric'
async function sendToLibrary(opts: {
  libraryId: string;
  roleInLoan: "lender" | "borrower";
  roleInFlow: "initiator" | "partner" | "symmetric";
  eventType: string;
  loan: IllLoan;
  items: IllItem[];
}) {
  const { libraryId, roleInLoan, roleInFlow, eventType, loan, items } = opts;
  const short = shortKey(eventType);

  // Context de la bibliothèque destinataire : logo, locale, admin email.
  const ctx = await resolveLibraryNotificationContext(libraryId);
  const locale = ctx.default_locale || "pt-BR";

  // Destinataire : l'email d'administration de la bibliothèque elle-même.
  const toEmail = ctx.admin_notification_email;
  if (!toEmail) {
    return { ok: false, libraryId, roleInLoan, roleInFlow,
             skipped: true, reason: "no_admin_notification_email" };
  }

  // Sujet : une clé par événement, neutre, identique pour les 2 destinataires.
  const subject = tMail(locale, `ill.subject.${short}`, {
    lender: loan.lender_library_short_name || loan.lender_library_name || "",
    borrower: loan.borrower_library_short_name || loan.borrower_library_name || "",
  });

  // Intro : pour 'created', clé à 2 axes (rôle dans le prêt + rôle dans le
  // flux). Pour les changements de statut, clé symétrique unique.
  let introKey: string;
  if (short === "created" && roleInFlow !== "symmetric") {
    // ill.intro.created.lender_initiator | borrower_partner |
    //                   borrower_initiator | lender_partner
    introKey = `ill.intro.created.${roleInLoan}_${roleInFlow}`;
  } else {
    // ill.intro.prepared | dispatched | return_started | returned |
    //          cancelled | overdue | partially_returned   (symétrique)
    introKey = `ill.intro.${short}`;
  }
  const introHtml = tMail(locale, introKey, {
    lender: loan.lender_library_name || "—",
    borrower: loan.borrower_library_name || "—",
    loanRef: loan.request_id || `#${loan.id ?? "—"}`,
  });

  // actionBox : uniquement pour la partenaire d'un 'created'. Elle porte le
  // contact de coordination saisi par la biblio initiatrice.
  let actionBox: { kind: string; title: string } | undefined;
  if (short === "created" && roleInFlow === "partner") {
    const contactName = loan.coordination_contact_name || "";
    const contactEmail = loan.coordination_contact_email || "";
    if (contactName || contactEmail) {
      const who = [contactName, contactEmail].filter(Boolean).join(" — ");
      actionBox = {
        kind: "action",
        title: tMail(locale, "ill.actionBox.contactPartner", { contact: who }),
      };
    }
  }

  const title = tMail(locale, `ill.title.${short}`);

  // Table de détails : affichée partout SAUF sur 'cancelled'.
  const details = EVENTS_WITHOUT_DETAILS.has(short)
    ? undefined
    : buildDetails(loan, items, locale, short);

  const { html, text } = renderEmail({
    preheader: subject,
    title,
    introHtml,
    actionBox,
    details,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx,
    locale,
  });

  const label = `ill_${short}_${roleInFlow}`;
  const result = await safeSendEmail(
    { email: toEmail, name: ctx.library_short_name || undefined },
    subject, html, text, label, ctx,
  );
  return { ...result, libraryId, roleInLoan, roleInFlow };
}

// ─── Handler principal ──────────────────────────────────────────────────────
async function handleNotifyIll(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: {
        "access-control-allow-origin": "*",
        "access-control-allow-methods": "POST, OPTIONS",
        "access-control-allow-headers":
          "authorization, x-client-info, apikey, content-type, x-webhook-secret",
      },
    });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "Method not allowed" });
  }

  const { payload, manualTest } = await parseJsonPayload(req);
  const auth = authorizeWebhook(req, manualTest, {
    secretEnv: WEBHOOK_SECRET,
  });
  // Auth durcie : on exige le secret webhook. Aucun repli — ni Bearer simple,
  // ni « test manuel » : verify_jwt = false, donc le Bearer n'est validé par
  // personne (durcissement du 2026-08-17, cf. _shared/core/webhook.ts).
  if (!auth.webhookOk && !auth.dashboardTestOk) {
    return jsonResponse(401, { ok: false, error: "Unauthorized" });
  }

  try {
    const p = (payload || {}) as IllPayload;
    const eventType = String(p.event_type || "").trim();
    const loan = p.loan || ({} as IllLoan);
    const items = Array.isArray(p.items) ? p.items : [];

    if (!eventType || !KNOWN_EVENTS.has(eventType)) {
      return jsonResponse(400, { ok: false, error: "Unknown event_type", eventType });
    }
    if (!loan.lender_library_id || !loan.borrower_library_id) {
      return jsonResponse(400, { ok: false, error: "Missing library ids on loan" });
    }

    const short = shortKey(eventType);
    const results: unknown[] = [];

    if (short === "created") {
      // Matrice à 2 axes : {prêteuse|emprunteuse} × {initiatrice|partenaire}.
      // L'initiatrice est lue dans loan.initiated_by_library_id — la migration
      // 20260522020000 place ce champ DANS l'objet 'loan' de la payload.
      const initiatorId = loan.initiated_by_library_id || null;

      if (initiatorId === loan.lender_library_id) {
        // Cas A — initiatrice = prêteuse
        results.push(await sendToLibrary({
          libraryId: loan.lender_library_id, roleInLoan: "lender",
          roleInFlow: "initiator", eventType, loan, items }));
        results.push(await sendToLibrary({
          libraryId: loan.borrower_library_id, roleInLoan: "borrower",
          roleInFlow: "partner", eventType, loan, items }));
      } else if (initiatorId === loan.borrower_library_id) {
        // Cas B — initiatrice = emprunteuse
        results.push(await sendToLibrary({
          libraryId: loan.borrower_library_id, roleInLoan: "borrower",
          roleInFlow: "initiator", eventType, loan, items }));
        results.push(await sendToLibrary({
          libraryId: loan.lender_library_id, roleInLoan: "lender",
          roleInFlow: "partner", eventType, loan, items }));
      } else {
        // initiated_by_library_id ne correspond ni à la prêteuse ni à
        // l'emprunteuse — cas anormal (champ absent, ou valeur incohérente
        // pointant une bibliothèque tierce). Repli symétrique pour ne JAMAIS
        // perdre la notification, avec un warn pour investigation.
        console.warn(
          "[notify-ill] initiated_by_library_id (" +
          String(loan.initiated_by_library_id) +
          ") ne correspond ni au lender ni au borrower — repli symétrique. " +
          "Vérifier la coherence de la donnée sur interlibrary_loans_v2.");
        results.push(await sendToLibrary({
          libraryId: loan.lender_library_id, roleInLoan: "lender",
          roleInFlow: "symmetric", eventType, loan, items }));
        results.push(await sendToLibrary({
          libraryId: loan.borrower_library_id, roleInLoan: "borrower",
          roleInFlow: "symmetric", eventType, loan, items }));
      }
    } else {
      // Changements de statut (prepared, dispatched, return_started,
      // returned, cancelled, overdue, partially_returned) : symétrique.
      results.push(await sendToLibrary({
        libraryId: loan.lender_library_id, roleInLoan: "lender",
        roleInFlow: "symmetric", eventType, loan, items }));
      results.push(await sendToLibrary({
        libraryId: loan.borrower_library_id, roleInLoan: "borrower",
        roleInFlow: "symmetric", eventType, loan, items }));
    }

    const allOk = results.every((r) => (r as { ok?: boolean }).ok);
    return jsonResponse(allOk ? 200 : 207, {
      ok: allOk,
      event_type: eventType,
      loan_id: loan.id ?? null,
      manual_test: manualTest,
      results,
    });
  } catch (error) {
    console.error("[notify-ill] error:", error);
    return jsonResponse(500, {
      ok: false,
      error: String((error as { message?: string })?.message || error),
    });
  }
}

serve(handleNotifyIll);
