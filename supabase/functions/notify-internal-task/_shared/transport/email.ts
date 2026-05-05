import { BREVO_KEY } from "../core/env.ts";
import { resolveMailRouting, transportDisabledReason } from "../context/library-mail-routing.ts";
import { renderEmail, footerPadrao } from "../mail/layout.ts";
import { firstNameOnly, fullName, isValidEmail } from "../shared/format.ts";
export async function sendBrevoEmail(opts) {
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
    const response = await sendBrevoEmail({
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
