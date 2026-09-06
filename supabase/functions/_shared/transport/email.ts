import { resolveMailRouting, transportDisabledReason } from "../context/library-mail-routing.ts";
import { renderEmail, footerPadrao } from "../mail/layout.ts";
import { inlineLogosInHtml } from "../mail/inline-images.ts";
import { firstNameOnly, fullName, isValidEmail } from "../shared/format.ts";

// ============================================================================
// Transport mail — envoi via Resend
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend) : R.2 avait introduit un dispatch
// Brevo/Resend pilote par MAIL_PROVIDER ; R.6 (05/06/2026) a retire Brevo.
// sendEmail() appelle desormais directement sendViaResend(). Le secret
// MAIL_PROVIDER a ete retire de Supabase en R.7 (08/06/2026) ; n'est
// plus lu par le code. safeSendEmail() est inchange, donc aucun handler de
// _shared/domain/* n'est touche.
// Spec : docs/specs/spec-migration-mail-resend.md.
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

// --- Wrapper neutre ------------------------------------------------------
// Point d'entree unique. C'est la seule fonction d'envoi que le reste du
// module (safeSendEmail) doit connaitre.
export async function sendEmail(opts) {
  console.log(`[transport] envoi via resend (label=${opts.label ?? "?"})`);
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
