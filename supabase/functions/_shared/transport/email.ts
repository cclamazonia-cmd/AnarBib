import { BREVO_KEY } from "../core/env.ts";
import { resolveMailRouting, transportDisabledReason } from "../context/library-mail-routing.ts";
import { renderEmail, footerPadrao } from "../mail/layout.ts";
import { inlineLogosInHtml } from "../mail/inline-images.ts";
import { firstNameOnly, fullName, isValidEmail } from "../shared/format.ts";
export async function sendBrevoEmail(opts) {
  const r = resolveMailRouting(opts.context);
  const rt = r.replyToEmail ? {
    email: r.replyToEmail,
    ...r.replyToName ? {
      name: r.replyToName
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
        name: r.senderName,
        email: r.senderEmail
      },
      to: [
        {
          email: opts.toEmail,
          ...opts.toName?.trim() ? {
            name: opts.toName.trim()
          } : {}
        }
      ],
      ...rt ? {
        replyTo: rt
      } : {},
      subject: opts.subject,
      htmlContent: opts.html,
      textContent: opts.text
    })
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`Brevo HTTP ${res.status}: ${body}`);
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
  const dr = transportDisabledReason(context);
  if (dr) return skippedEmailResult(label, dr);
  const em = target?.email?.trim() || "";
  if (!em || !isValidEmail(em)) return skippedEmailResult(label, em ? "invalid_email" : "empty_email", em || undefined);
  try {
    // Inline les logos Supabase Storage en base64 pour éviter la réécriture
    // d'URLs par Brevo qui casse les images dans les archives mail.
    // Cf. docs/decisions/BUG_LOGOS_BREVO_TRACKER_2026-05-06.md
    const inlinedHtml = await inlineLogosInHtml(html);
    const response = await sendBrevoEmail({
      toEmail: em,
      toName: target?.name?.trim(),
      subject,
      html: inlinedHtml,
      text,
      context
    });
    console.log(`[${label}] sent to ${em}`);
    return {
      ok: true,
      label,
      email: em,
      response
    };
  } catch (err) {
    console.error(`[${label}] failed for ${em}:`, err);
    return {
      ok: false,
      label,
      email: em,
      error: String(err?.message || err)
    };
  }
}
export function userTargetFromProfile(p) {
  const e = String(p.email || "").trim();
  if (!isValidEmail(e)) return null;
  return {
    email: e,
    name: firstNameOnly(p.first_name) || firstNameOnly(fullName(p)) || undefined
  };
}
export function adminTarget(ctx) {
  const r = resolveMailRouting(ctx);
  const e = String(r.adminEmail || "").trim();
  if (!isValidEmail(e)) return null;
  return {
    email: e,
    name: r.adminName || undefined
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
