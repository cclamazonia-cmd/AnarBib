import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { tMail, greeting, label, taskStatusLabel, taskPriorityLabel, formatDateLocale } from "../_shared/i18n/mail-strings.ts";
serve((req)=>{
  const url = new URL(req.url);
  const locale = url.searchParams.get("locale") || "pt-BR";
  const result = {
    locale,
    greeting_named: greeting(locale, "Maria"),
    greeting_anon: greeting(locale),
    label_book: label(locale, "book"),
    label_items: label(locale, "items"),
    label_dueDate: label(locale, "dueDate"),
    label_reader: label(locale, "reader"),
    label_pickup: label(locale, "pickup"),
    subject_reservation: tMail(locale, "res.created.sub"),
    subject_loan: tMail(locale, "loan.created.sub"),
    subject_renewed: tMail(locale, "loan.renewed.sub"),
    subject_returned: tMail(locale, "loan.returned.sub"),
    task_status_open: taskStatusLabel(locale, "aberta"),
    task_status_done: taskStatusLabel(locale, "concluida"),
    task_priority_high: taskPriorityLabel(locale, "alta"),
    date_formatted: formatDateLocale("2026-04-27", locale),
    footer_contact: tMail(locale, "layout.footerContact"),
    keep_msg: tMail(locale, "layout.keepMsg")
  };
  return new Response(JSON.stringify(result, null, 2), {
    headers: {
      "content-type": "application/json; charset=utf-8"
    }
  });
});
