import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { tMail, greeting } from "../i18n/mail-strings.ts";

// ============================================================================
// DEPOT-GARANTIE — reçus de dépôt de garantie (collecte + remboursement).
// ----------------------------------------------------------------------------
// Émis par public.fn_record_deposit / fn_refund_deposit / fn_retain_deposit via
//   fn_dispatch_notify_event('deposit_collected'|'deposit_refunded',
//                            <emprestimo_id>, {deposit_id}).
// record_id = l'emprunt (bigint > 0, exigé par l'EF) ; la donnée utile (uuid du
// dépôt) vit dans payload. Le handler relit loan_deposits par deposit_id (source
// autoritaire), résout le membre + sa locale, vérifie la politique biblio
// (deposit_receipt_mail_enabled, défaut ON), et envoie le reçu AU MEMBRE
// seulement (DOC-NOTIF-1, spec §7). Pas de copie staff ; pas de réplique in-app
// (un dépôt n'expire pas — le bandeau /conta suffit pour l'état permanent).
// fn_retain_deposit n'émet 'deposit_refunded' QUE pour une rétention partielle
// (un montant a réellement été rendu) ; une rétention totale n'envoie rien.
// ============================================================================

async function loadDeposit(depositId) {
  const id = String(depositId || "").trim();
  if (!id) throw new Error("deposit_id manquant.");
  const { data: dep, error } = await supabaseAdmin
    .from("loan_deposits")
    .select("id,user_id,library_id,emprestimo_id,amount,currency,collected_method,status,refunded_amount,refunded_method")
    .eq("id", id)
    .maybeSingle();
  if (error) throw error;
  if (!dep) throw new Error("Caução não encontrada.");
  return dep;
}

// Politique biblio (deposit_receipt_mail_enabled, défaut ON) + profil + contexte.
// Renvoie null si l'e-mail doit être sauté (politique OFF ou pas d'adresse).
async function resolveRecipient(dep) {
  const { data: pol } = await supabaseAdmin
    .from("library_notification_policies")
    .select("deposit_receipt_mail_enabled")
    .eq("library_id", dep.library_id)
    .maybeSingle();
  if (pol && pol.deposit_receipt_mail_enabled === false) {
    return { skip: skippedEmailResult("user_mail", "deposit_receipt_mail_disabled") };
  }

  const { data: profile, error } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", dep.user_id)
    .maybeSingle();
  if (error) throw error;
  if (!profile) throw new Error("Perfil não encontrado.");

  const ctx = await resolveLibraryNotificationContext(String(dep.library_id || "").trim() || null);
  const user = userTargetFromProfile(profile);
  if (!user?.email) {
    return { skip: skippedEmailResult("user_mail", "no_recipient_email") };
  }
  return {
    ctx,
    bt: subjectTag(ctx),
    user,
    locale: String(profile?.preferred_language || "").trim() || null
  };
}

export async function handleDepositCollected(payload) {
  const dep = await loadDeposit(payload?.deposit_id);
  const r = await resolveRecipient(dep);
  if (r.skip) return { user_result: r.skip };
  const { ctx, bt, user, locale } = r;

  const amountStr = `${dep.amount} ${String(dep.currency || "").trim()}`.trim();
  const methodStr = tMail(locale, `cot.method.${String(dep.collected_method || "other")}`);

  const tit = tMail(locale, "deposit.collected.subject");
  const det = [
    { label: tMail(locale, "deposit.amountLabel"), value: amountStr },
    { label: tMail(locale, "deposit.loanLabel"), value: `#${dep.emprestimo_id}` },
    { label: tMail(locale, "deposit.methodLabel"), value: methodStr }
  ];
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: `<p>${tMail(locale, "deposit.collected.intro")}</p>`,
    details: det,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
  const user_result = await safeSendEmail(user, sub, html, text, "user_mail", ctx);
  return { user_result };
}

export async function handleDepositRefunded(payload) {
  const dep = await loadDeposit(payload?.deposit_id);
  const r = await resolveRecipient(dep);
  if (r.skip) return { user_result: r.skip };
  const { ctx, bt, user, locale } = r;

  const isPartial = dep.status === "partiel";
  const curr = String(dep.currency || "").trim();
  const refundedStr = `${dep.refunded_amount ?? 0} ${curr}`.trim();
  const methodStr = tMail(locale, `cot.method.${String(dep.refunded_method || "other")}`);
  const base = isPartial ? "deposit.refunded_partial" : "deposit.refunded";

  const det = [];
  if (isPartial) {
    det.push({ label: tMail(locale, "deposit.amountLabel"), value: `${dep.amount} ${curr}`.trim() });
  }
  det.push({ label: tMail(locale, "deposit.refundedLabel"), value: refundedStr });
  det.push({ label: tMail(locale, "deposit.loanLabel"), value: `#${dep.emprestimo_id}` });
  det.push({ label: tMail(locale, "deposit.methodLabel"), value: methodStr });

  const tit = tMail(locale, `${base}.subject`);
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: `<p>${tMail(locale, `${base}.intro`)}</p>`,
    details: det,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
  const user_result = await safeSendEmail(user, sub, html, text, "user_mail", ctx);
  return { user_result };
}
