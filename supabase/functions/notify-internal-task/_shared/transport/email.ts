import { resolveMailRouting, transportDisabledReason } from "../context/library-mail-routing.ts";
import { renderEmail, footerPadrao } from "../mail/layout.ts";
import { firstNameOnly, fullName, isValidEmail } from "../shared/format.ts";
// ============================================================================
// Transport mail — envoi via Resend (copie privee de notify-internal-task)
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend) : R.3.1 avait introduit un dispatch
// Brevo/Resend pilote par MAIL_PROVIDER ; R.6 (05/06/2026) a retire Brevo.
// sendEmail() appelle desormais directement sendViaResend(). Le secret
// MAIL_PROVIDER reste pose cote Supabase (retrait eventuel en R.7) mais n'est
// plus lu par le code. safeSendEmail / le handler internal-task.ts inchanges.
// CONTRAT : string en succes, throw sur erreur HTTP — inchange.
// Spec : docs/specs/spec-migration-mail-resend.md.
// ============================================================================
function formatMailAddress(email: string, name?: string): string {
  const n = (name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Resend (cf. spec §4.4) ---------------------------------
// Format Resend : auth Bearer, from "Nom <email>", to tableau de strings,
// reply_to "Nom <email>", corps html/text. Contrat identique : string + throw.
async function sendViaResend(opts) {
  const routing = resolveMailRouting(opts.context);
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (!resendKey) {
    throw new Error("RESEND_API_KEY absente des secrets Edge Function");
  }
  const toName = (opts.toName || "").trim();
  const payload: Record<string, unknown> = {
    from: formatMailAddress(routing.senderEmail, routing.senderName),
    to: [opts.toEmail],
    subject: opts.subject,
    html: opts.html,
    text: opts.text
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
  const body = await res.text();
  if (!res.ok) throw new Error(`Resend error HTTP ${res.status}: ${body}`);
  return body;
}
// --- Wrapper neutre --------------------------------------------------------
async function sendEmail(opts) {
  console.log(`[internal-task] envoi via resend`);
  return await sendViaResend(opts);
}
export function skippedEmailResult(label, reason, email) {
  return {
    ok: false,
    label,
    email,
    skipped: true,
    reason
  };
}
export async function safeSendEmail(target, subject, html, text, label = "email", context) {
  const disabledReason = transportDisabledReason(context);
  if (disabledReason) {
    console.warn(`[${label}] skipped: ${disabledReason}`);
    return skippedEmailResult(label, disabledReason);
  }
  const email = target?.email?.trim() || "";
  if (!email) {
    console.warn(`[${label}] skipped: empty email`);
    return skippedEmailResult(label, "empty_email");
  }
  if (!isValidEmail(email)) {
    console.warn(`[${label}] skipped: invalid email ${email}`);
    return skippedEmailResult(label, "invalid_email", email);
  }
  try {
    const response = await sendEmail({
      toEmail: email,
      toName: target?.name?.trim() || undefined,
      subject,
      html,
      text,
      context
    });
    console.log(`[${label}] sent to ${email}`);
    return {
      ok: true,
      label,
      email,
      response
    };
  } catch (err) {
    console.error(`[${label}] failed for ${email}:`, err);
    return {
      ok: false,
      label,
      email,
      error: String(err?.message || err)
    };
  }
}
export function userTargetFromProfile(profile) {
  const email = String(profile.email || "").trim();
  if (!isValidEmail(email)) return null;
  return {
    email,
    name: firstNameOnly(profile.first_name) || firstNameOnly(fullName(profile)) || undefined
  };
}
export function adminTarget(context) {
  const routing = resolveMailRouting(context);
  const email = String(routing.adminEmail || "").trim();
  if (!isValidEmail(email)) return null;
  return {
    email,
    name: routing.adminName || undefined
  };
}
export async function sendAdminNotification(opts) {
  const { html, text } = renderEmail({
    preheader: opts.title,
    title: opts.title,
    introHtml: opts.introHtml,
    details: opts.details,
    footerHtml: footerPadrao(opts.context),
    context: opts.context
  });
  return await safeSendEmail(adminTarget(opts.context), opts.subject, html, text, "admin_copy", opts.context);
}
