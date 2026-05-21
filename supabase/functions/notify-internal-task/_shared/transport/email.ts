import { BREVO_KEY } from "../core/env.ts";
import { resolveMailRouting, transportDisabledReason } from "../context/library-mail-routing.ts";
import { renderEmail, footerPadrao } from "../mail/layout.ts";
import { firstNameOnly, fullName, isValidEmail } from "../shared/format.ts";
// ============================================================================
// Transport mail — wrapper neutre + dispatch par provider
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend), sous-paquet R.3.1 (EF #6).
// Spec : docs/specs/spec-migration-mail-resend.md (v0.2), §4.3.
//
// notify-internal-task embarque une COPIE PRIVEE du transport partage. Le
// traitement est identique a R.2 : sendBrevoEmail dedouble en sendViaBrevo /
// sendViaResend, derriere un wrapper neutre sendEmail() qui dispatche selon
// MAIL_PROVIDER. safeSendEmail appelle sendEmail() ; le handler internal-task.ts
// ne consomme que safeSendEmail / skippedEmailResult, il n'est pas touche.
//
// CONTRAT : string en succes, throw sur erreur HTTP — inchange.
//
// Tant que MAIL_PROVIDER n'est pas "resend", comportement = avant-R.3 (brevo).
// ============================================================================
const VALID_MAIL_PROVIDERS = new Set(["brevo", "resend"]);
function resolveMailProvider() {
  const raw = (Deno.env.get("MAIL_PROVIDER") || "brevo").trim().toLowerCase();
  if (!VALID_MAIL_PROVIDERS.has(raw)) {
    console.warn(`[internal-task] MAIL_PROVIDER="${raw}" inconnu, repli sur brevo`);
    return "brevo";
  }
  return raw;
}
function formatMailAddress(email: string, name?: string): string {
  const n = (name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Brevo (corps inchange : ancien sendBrevoEmail) ----------
async function sendViaBrevo(opts) {
  const routing = resolveMailRouting(opts.context);
  const replyTo = routing.replyToEmail ? {
    email: routing.replyToEmail,
    ...routing.replyToName ? {
      name: routing.replyToName
    } : {}
  } : undefined;
  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/json",
      "api-key": BREVO_KEY
    },
    body: JSON.stringify({
      sender: {
        name: routing.senderName,
        email: routing.senderEmail
      },
      to: [
        (()=>{
          const t = {
            email: opts.toEmail
          };
          const n = (opts.toName || "").trim();
          if (n) t.name = n;
          return t;
        })()
      ],
      ...replyTo ? {
        replyTo
      } : {},
      subject: opts.subject,
      htmlContent: opts.html,
      textContent: opts.text
    })
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`Brevo error HTTP ${res.status}: ${body}`);
  return body;
}
// --- Implementation Resend (nouvelle, cf. spec §4.4) -----------------------
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
  const provider = resolveMailProvider();
  console.log(`[internal-task] envoi via ${provider}`);
  if (provider === "resend") {
    return await sendViaResend(opts);
  }
  return await sendViaBrevo(opts);
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
