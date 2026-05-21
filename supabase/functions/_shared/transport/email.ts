import { BREVO_KEY } from "../core/env.ts";
import { resolveMailRouting, transportDisabledReason } from "../context/library-mail-routing.ts";
import { renderEmail, footerPadrao } from "../mail/layout.ts";
import { inlineLogosInHtml } from "../mail/inline-images.ts";
import { firstNameOnly, fullName, isValidEmail } from "../shared/format.ts";

// ============================================================================
// Transport mail — wrapper neutre + dispatch par provider
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend), sous-paquet R.2.
// Spec : docs/specs/spec-migration-mail-resend.md (v0.2), §4.
//
// Le point d'entree est sendEmail() : il ne mentionne aucun provider et
// choisit Brevo ou Resend selon la variable d'environnement MAIL_PROVIDER.
// safeSendEmail() appelle sendEmail() ; sa signature est inchangee, donc
// aucun handler de _shared/domain/* n'est touche.
//
// Tant que MAIL_PROVIDER n'est pas mis a "resend", le comportement est
// strictement identique a l'avant-R.2 (defaut = brevo).
// ============================================================================

// --- Dispatch -----------------------------------------------------------
// MAIL_PROVIDER admet "brevo" ou "resend". Toute autre valeur (typo dans
// le dashboard Supabase) declenche un avertissement et un repli sur brevo.
// Cf. spec §6.5 hardening H.2.
const VALID_PROVIDERS = new Set(["brevo", "resend"]);

function resolveProvider(): "brevo" | "resend" {
  const raw = (Deno.env.get("MAIL_PROVIDER") || "brevo").trim().toLowerCase();
  if (!VALID_PROVIDERS.has(raw)) {
    console.warn(`[transport] MAIL_PROVIDER="${raw}" inconnu, repli sur brevo`);
    return "brevo";
  }
  return raw as "brevo" | "resend";
}

// --- Implementation Brevo -----------------------------------------------
// Corps inchange par rapport a l'ancien sendBrevoEmail : meme appel, memes
// champs. Seul le nom de la fonction change (sendBrevoEmail -> sendViaBrevo).
async function sendViaBrevo(opts) {
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
  const provider = resolveProvider();
  console.log(`[transport] envoi via ${provider} (label=${opts.label ?? "?"})`);
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
