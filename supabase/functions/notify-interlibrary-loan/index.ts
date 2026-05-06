// ============================================================================
// notify-interlibrary-loan — STUB (NON OPERATIONNEL)
// ============================================================================
// État : MODULE EN CHANTIER, NE PAS UTILISER EN PRODUCTION
//
// Cette Edge Function est appelée par le trigger DB
// `trg_interlibrary_loan_enqueue_notifications` sur `interlibrary_loans_v2`,
// via `fn_notify_emprestimo_interbibliotecas_webhook`.
//
// Elle est intentionnellement non implémentée pour le moment :
//   - Le module "Prêts interbibliothèques" est en cours de redéfinition.
//   - L'envoi effectif des mails (Brevo) reste à brancher.
//   - Les politiques d'accès, de consentement, et le format des messages
//     doivent être validés politiquement avant toute mise en service réelle.
//
// Comportement actuel :
//   - Authentifie le webhook (secret).
//   - Logue la payload reçue avec un avertissement explicite (console.warn).
//   - Renvoie HTTP 501 Not Implemented pour signaler clairement le statut.
//
// Pour reprise du chantier :
//   - Voir docs/decisions/MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md
//   - Le code de formatage (subjectMap, textBody) ci-dessous est conservé
//     comme point de départ pour l'implémentation finale.
//
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const expectedSecret = Deno.env.get("NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET") || "";
    const receivedSecret = req.headers.get("x-webhook-secret") || "";
    if (!expectedSecret || receivedSecret !== expectedSecret) {
      return new Response("Unauthorized", { status: 401 });
    }

    const body = await req.json();
    const eventType = body?.event_type || "";
    const loan = body?.loan || {};
    const items = Array.isArray(body?.items) ? body.items : [];

    // ─── Pré-formatage conservé pour reprise ulterieure ─────────────────────
    const lenderName = loan?.lender_library_short_name || loan?.lender_library_name || "Biblioteca emprestadora";
    const borrowerName = loan?.borrower_library_short_name || loan?.borrower_library_name || "Biblioteca tomadora";

    const subjectMap = {
      interlibrary_loan_created: `Novo empréstimo interbibliotecas — ${lenderName} ↔ ${borrowerName}`,
      interlibrary_loan_prepared: `Empréstimo interbibliotecas preparado — ${lenderName} ↔ ${borrowerName}`,
      interlibrary_loan_dispatched: `Empréstimo interbibliotecas despachado — ${lenderName} ↔ ${borrowerName}`,
      interlibrary_loan_return_started: `Devolução iniciada — ${lenderName} ↔ ${borrowerName}`,
      interlibrary_loan_returned: `Empréstimo interbibliotecas devolvido — ${lenderName} ↔ ${borrowerName}`,
      interlibrary_loan_cancelled: `Empréstimo interbibliotecas cancelado — ${lenderName} ↔ ${borrowerName}`,
      interlibrary_loan_overdue: `Empréstimo interbibliotecas em atraso — ${lenderName} ↔ ${borrowerName}`
    };
    const subject = subjectMap[eventType] || `Atualização de empréstimo interbibliotecas — ${lenderName} ↔ ${borrowerName}`;

    const lines = items.map((it) => `- ${it?.titulo || it?.bib_ref || "Documento"} · ${it?.tombo || "sem tombo"} · status ${it?.item_status || "—"}`).join("\n");

    const textBody = [
      `Evento: ${eventType}`,
      ``,
      `Empréstimo #${loan?.id || "—"}`,
      `Biblioteca emprestadora: ${loan?.lender_library_name || "—"}`,
      `Biblioteca tomadora: ${loan?.borrower_library_name || "—"}`,
      `Status global: ${loan?.status_global || "—"}`,
      `Saída: ${loan?.start_date || "—"}`,
      `Retorno previsto: ${loan?.due_date || "—"}`,
      `Contato: ${loan?.coordination_contact_name || "—"} / ${loan?.coordination_contact_email || "—"}`,
      `Logística: ${loan?.logistics_mode || "—"}`,
      `Ponto de encontro: ${loan?.meeting_point || "—"}`,
      ``,
      `Itens:`,
      lines || "- nenhum item",
      ``,
      `Observações: ${loan?.notes || "—"}`
    ].join("\n");

    // ─── Log d'avertissement explicite ──────────────────────────────────────
    console.warn(
      "⚠️  [STUB] notify-interlibrary-loan called — module not yet operational. " +
      "Mail NOT sent. See docs/decisions/MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md"
    );
    console.warn(JSON.stringify({
      stub: true,
      eventType,
      loanId: loan?.id || null,
      subject,
      textBody
    }, null, 2));

    // ─── Retourne 501 Not Implemented ───────────────────────────────────────
    return new Response(JSON.stringify({
      ok: false,
      stub: true,
      not_implemented: true,
      eventType,
      loanId: loan?.id || null,
      message: "Module Prêts interbibliothèques non opérationnel — mail non envoyé. Voir docs/decisions/MODULE_INTERBIBLIOTECAS_STATUT_2026-05-06.md"
    }), {
      status: 501,
      headers: { "content-type": "application/json" }
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({
      ok: false,
      error: String(err?.message || err)
    }), {
      status: 500,
      headers: { "content-type": "application/json" }
    });
  }
});
