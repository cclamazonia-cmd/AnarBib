import { resolveMailRouting, transportDisabledReason } from "../context/library-mail-routing.ts";
import { renderEmail, footerPadrao } from "../mail/layout.ts";
import { inlineLogosInHtml } from "../mail/inline-images.ts";
import { firstNameOnly, fullName, isValidEmail } from "../shared/format.ts";

import { sendViaSmtp, resolveTimeout } from "../mail/smtp.ts";

// ============================================================================
// Transport mail — Hybride universel : SMTP ou API Resend
// ----------------------------------------------------------------------------
// Supporte :
//   1. SMTP standard (mail.domaine.org, OVH, Gandi, Postfix, etc.)
//   2. API Resend (https://api.resend.com/emails)
//   3. Mock local (simulation explicite avec MAIL_TRANSPORT=mock, DOC-SILENCE-1)
// ============================================================================

// --- Implementation Resend ----------------------------------------------
// Nouvelle. Format Resend (cf. spec §4.4) :
//   - auth : header "Authorization: Bearer <RESEND_API_KEY>"
//   - expediteur : champ "from" au format "Nom <email>"
//   - destinataire : champ "to" = tableau de strings
//   - reponse : champ "reply_to" au format "Nom <email>"
//   - corps : champs "html" et "text"
// DECISION 1 (format de retour) : on retourne res.text() — la string brute,
// exactement comme sendViaBrevo. safeSendEmail n'a donc rien a adapter.
function formatAddress(email: string, name?: string): string {
  const n = name?.trim();
  return n ? `${n} <${email}>` : email;
}

async function sendViaResend(opts) {
  const r = resolveMailRouting(opts.context);
  const RESEND_KEY = Deno.env.get("RESEND_API_KEY") || "";
  if (!RESEND_KEY) {
    throw new Error("RESEND_API_KEY absente des secrets Edge Function");
  }
  const payload: Record<string, unknown> = {
    from: formatAddress(r.senderEmail, r.senderName),
    to: [opts.toEmail],
    subject: opts.subject,
    html: opts.html,
    text: opts.text
  };
  if (r.replyToEmail) {
    payload.reply_to = formatAddress(r.replyToEmail, r.replyToName);
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  const body = await res.text();
  if (!res.ok) throw new Error(`Resend HTTP ${res.status}: ${body}`);
  return body;
}

async function sendViaConfiguredSmtp(opts) {
  const r = resolveMailRouting(opts.context);
  const host = (Deno.env.get("SMTP_HOST") || "").trim();
  const port = parseInt(Deno.env.get("SMTP_PORT") || "587", 10);
  const user = (Deno.env.get("SMTP_USER") || "").trim();
  const pass = (Deno.env.get("SMTP_PASS") || "").trim();
  const secure = (Deno.env.get("SMTP_SECURE") || "").trim() === "true" || port === 465;
  const allowInsecure = (Deno.env.get("SMTP_ALLOW_INSECURE") || "").trim().toLowerCase() === "true";
  const timeoutMs = resolveTimeout(Deno.env.get("SMTP_TIMEOUT_MS"));

  return await sendViaSmtp({
    host,
    port,
    user,
    pass,
    secure,
    allowInsecure,
    timeoutMs,
    from: formatAddress(r.senderEmail, r.senderName),
    to: [opts.toEmail],
    replyTo: r.replyToEmail ? formatAddress(r.replyToEmail, r.replyToName) : undefined,
    subject: opts.subject,
    html: opts.html,
    text: opts.text
  });
}

// --- Wrapper neutre ------------------------------------------------------
// Point d'entree unique. C'est la seule fonction d'envoi que le reste du
// module (safeSendEmail) doit connaitre.
export async function sendEmail(opts) {
  const smtpHost = (Deno.env.get("SMTP_HOST") || "").trim();
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  const mailTransport = (Deno.env.get("MAIL_TRANSPORT") || "").trim().toLowerCase();

  // 1. Simulation explicite demandée
  if (mailTransport === "mock") {
    console.log(`[transport] [EMAIL SIMULATION] MAIL_TRANSPORT=mock actif (DOC-SILENCE-1) : mail simulé à ${opts.toEmail} (« ${opts.subject} »)`);
    return JSON.stringify({ ok: true, mocked: true, to: opts.toEmail, subject: opts.subject });
  }

  // 2. SMTP explicitement demandé ou configuré via SMTP_HOST (sauf si MAIL_TRANSPORT=resend)
  if (mailTransport === "smtp" || (smtpHost && mailTransport !== "resend")) {
    if (!smtpHost) {
      throw new Error("MAIL_TRANSPORT=smtp configuré mais SMTP_HOST est vide ou manquant");
    }
    console.log(`[transport] envoi via SMTP (${smtpHost}) (label=${opts.label ?? "?"})`);
    return await sendViaConfiguredSmtp(opts);
  }

  // 3. Resend configuré (ou transport explicite resend)
  if (mailTransport === "resend" || resendKey) {
    console.log(`[transport] envoi via Resend (label=${opts.label ?? "?"})`);
    return await sendViaResend(opts);
  }

  // 4. Aucune configuration valide : interdiction du silence en prod (DOC-SILENCE-1)
  throw new Error(
    "Aucun service d'e-mail configuré : RESEND_API_KEY ou SMTP_HOST requis, " +
    "ou MAIL_TRANSPORT=mock pour la simulation locale explicite (DOC-SILENCE-1)"
  );
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
    // Inline les logos Supabase Storage en base64 pour eviter la reecriture
    // d'URLs par Brevo qui casse les images dans les archives mail.
    // Conserve aussi sous Resend comme garantie d'archivage (spec §4.5).
    // Cf. docs/decisions/BUG_LOGOS_BREVO_TRACKER_2026-05-06.md
    const inlinedHtml = await inlineLogosInHtml(html);
    const response = await sendEmail({
      toEmail: em,
      toName: target?.name?.trim(),
      subject,
      html: inlinedHtml,
      text,
      context,
      label
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
