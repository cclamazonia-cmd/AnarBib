import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { adminDisplayName, formatDateBR, fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

// ============================================================================
// #NOTIFY-Painel-acts — Famille 1 : reçu de paiement de cotisation.
// ----------------------------------------------------------------------------
// Émis par public.fn_record_membership_payment via
//   fn_dispatch_notify_event('cotisation_payment_recorded', 1, {payment_id})
// record_id factice = 1 (l'EF exige record_id > 0) ; la donnée utile (uuid du
// paiement) vit dans payload. Le handler re-interroge membership_payments par
// payment_id (source autoritaire), résout le membre + sa locale, vérifie la
// politique biblio (NOTIF-PA2, configurable, défaut ON), et envoie le reçu au
// membre (e-mail seul ; pas de réplique in-app — le bandeau de compte suffit,
// doctrine §4.4). DOC-NOTIF-1 : on notifie le membre, pas le staff.
// ============================================================================
export async function handleCotisationPayment(payload) {
  const paymentId = String(payload?.payment_id || "").trim();
  if (!paymentId) throw new Error("payment_id manquant.");

  const { data: pay, error: e1 } = await supabaseAdmin
    .from("membership_payments")
    .select("id,user_id,library_id,amount_paid,currency,paid_at,valid_from,valid_until,payment_method")
    .eq("id", paymentId)
    .maybeSingle();
  if (e1) throw e1;
  if (!pay) throw new Error("Pagamento não encontrado.");

  // Politique biblio (NOTIF-PA2) : configurable, défaut ON. Lecture directe
  // (évite de toucher la vue partagée v_library_notification_context).
  const { data: pol } = await supabaseAdmin
    .from("library_notification_policies")
    .select("cotisation_payment_mail_enabled")
    .eq("library_id", pay.library_id)
    .maybeSingle();
  if (pol && pol.cotisation_payment_mail_enabled === false) {
    return { user_result: skippedEmailResult("user_mail", "cotisation_payment_mail_disabled") };
  }

  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", pay.user_id)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");

  const ctx = await resolveLibraryNotificationContext(String(pay.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  if (!user?.email) {
    return { user_result: skippedEmailResult("user_mail", "no_recipient_email") };
  }
  const locale = String(profile?.preferred_language || "").trim() || null;
  const fmtD = (d) => formatDateLocale(d, locale) || formatDateBR(d);

  const amountStr = `${pay.amount_paid} ${String(pay.currency || "").trim()}`.trim();
  const untilStr = pay.valid_until ? fmtD(pay.valid_until) : tMail(locale, "cot.noExpiry");
  const periodStr = `${fmtD(pay.valid_from)} — ${untilStr}`;
  const methodStr = tMail(locale, `cot.method.${String(pay.payment_method || "other")}`);

  const tit = tMail(locale, "cotisation.payment.subject");
  const det = [
    { label: label(locale, "cotAmount"), value: amountStr },
    { label: label(locale, "cotPeriod"), value: periodStr },
    { label: label(locale, "cotMethod"), value: methodStr }
  ];
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: `<p>${tMail(locale, "cotisation.payment.intro")}</p>`,
    details: det,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
  const user_result = await safeSendEmail(user, sub, html, text, "user_mail", ctx);

  // Copie biblio (admin de la biblio du paiement) — même garde que le mail
  // membre (cotisation_payment_mail_enabled déjà vérifiée). Locale biblio.
  const aun = adminDisplayName(fullName(profile), user?.email);
  const libLoc = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const fmtL = (d) => formatDateLocale(d, libLoc) || formatDateBR(d) || "";
  const periodL = `${fmtL(pay.valid_from)} — ${pay.valid_until ? fmtL(pay.valid_until) : tMail(libLoc, "cot.noExpiry")}`;
  const methodL = tMail(libLoc, `cot.method.${String(pay.payment_method || "other")}`);
  const titL = tMail(libLoc, "cotisation.payment.subject");
  const { html: ha, text: ta } = renderEmail({
    locale: libLoc,
    preheader: titL,
    title: titL,
    introHtml: `<p>${titL}.</p>`,
    details: [
      { label: label(libLoc, "reader"), value: aun },
      { label: label(libLoc, "cotAmount"), value: amountStr },
      { label: label(libLoc, "cotPeriod"), value: periodL },
      { label: label(libLoc, "cotMethod"), value: methodL }
    ],
    footerHtml: footerPadrao(ctx, libLoc),
    context: ctx
  });
  const admin_result = await safeSendEmail(adminTarget(ctx), applyBrandingText(`[${bt}] ${titL} — ${aun}`, ctx), ha, ta, "admin_copy", ctx);

  return { user_result, admin_result };
}
