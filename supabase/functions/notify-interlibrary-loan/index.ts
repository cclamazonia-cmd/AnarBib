import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
serve(async (req)=>{
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", {
        status: 405
      });
    }
    const expectedSecret = Deno.env.get("NOTIFY_INTERLIBRARY_LOAN_WEBHOOK_SECRET") || "";
    const receivedSecret = req.headers.get("x-webhook-secret") || "";
    if (!expectedSecret || receivedSecret !== expectedSecret) {
      return new Response("Unauthorized", {
        status: 401
      });
    }
    const body = await req.json();
    const eventType = body?.event_type || "";
    const loan = body?.loan || {};
    const items = Array.isArray(body?.items) ? body.items : [];
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
    const lines = items.map((it)=>`- ${it?.titulo || it?.bib_ref || "Documento"} · ${it?.tombo || "sem tombo"} · status ${it?.item_status || "—"}`).join("\n");
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
    // TODO:
    // Aqui tu branches ton envoi Brevo réel.
    // Ex.:
    // - BREVO_API_KEY
    // - sender.email = anarbib@anarbib.org
    // - replyTo.email = AnarBib@proton.me
    // - destinataires = contact bibliothèque prêteuse + contact bibliothèque tomadora
    console.log(JSON.stringify({
      subject,
      textBody
    }, null, 2));
    return new Response(JSON.stringify({
      ok: true,
      eventType,
      loanId: loan?.id || null
    }), {
      status: 200,
      headers: {
        "content-type": "application/json"
      }
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({
      ok: false,
      error: String(err?.message || err)
    }), {
      status: 500,
      headers: {
        "content-type": "application/json"
      }
    });
  }
});
