import { resolveMailRouting, transportDisabledReason } from "../context/library-mail-routing.ts";
import { inlineLogosInHtml } from "../mail/inline-images.ts";
import { firstNameOnly, fullName, isValidEmail } from "../shared/format.ts";

import { sendViaSmtp, resolveTimeout } from "../mail/smtp.ts";
import { supabaseAdmin } from "../core/env.ts";
import { dejaServi } from "./restriction.ts";
// F19 (30/09/2026) : jamais une adresse en clair dans un journal (voir core/journal-masque.ts).
import { masquerAdresse } from "../core/journal-masque.ts";

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
// ─── Rejeu et cadence (F25, 09/10/2026) ───────────────────────────────────
// Resend n'accepte que dix requêtes par seconde. Le 09/10, quatorze propositions
// d'Atelier versées d'un coup ont fait 72 envois en deux secondes : 58 refusés
// (HTTP 429 rate_limit_exceeded), et rien ne les rejouait — les appelants
// comptaient même l'échec comme un envoi. Ici :
//   - cadence : les envois Resend d'un même isolat sont espacés (huit par
//     seconde au plus ; RESEND_MIN_INTERVAL_MS, défaut 125) ;
//   - rejeu : un 429, un 5xx ou une connexion rompue est rejoué jusqu'à trois
//     fois, après le délai que Resend demande (Retry-After, plafonné à 10 s) ou
//     une attente croissante avec un aléa (RESEND_RETRY_BASE_MS, défaut 400 :
//     0,4 s, 0,8 s, 1,6 s) ; un autre 4xx (clé tournée, domaine suspendu,
//     adresse refusée) n'est pas rejoué, il ne changerait pas.
// Des isolats en parallèle ne se voient pas : le rejeu couvre ce que la cadence
// ne peut pas. Un échec après rejeu reste noté dans mail_transport_failures.
// RESEND_API_URL ne sert qu'au banc (un faux Resend) : absent en production.
const dormir = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
function entierEnv(nom: string, defaut: number): number {
  const v = parseInt((Deno.env.get(nom) || "").trim(), 10);
  return Number.isFinite(v) && v >= 0 ? v : defaut;
}
let prochainCreneau = 0;
async function cadencer(): Promise<void> {
  const intervalle = entierEnv("RESEND_MIN_INTERVAL_MS", 125);
  const maintenant = Date.now();
  const creneau = Math.max(maintenant, prochainCreneau);
  prochainCreneau = creneau + intervalle;
  if (creneau > maintenant) await dormir(creneau - maintenant);
}
export function rejouable(status: number): boolean {
  return status === 429 || status === 0 || (status >= 500 && status <= 599);
}
export function attenteAvantRejeu(retryAfter: string | null, tentative: number, base: number): number {
  const ra = parseFloat(String(retryAfter || "").trim());
  if (Number.isFinite(ra) && ra >= 0) return Math.min(Math.round(ra * 1000), 10000);
  return Math.min(base * Math.pow(2, tentative), 4000) + Math.floor(Math.random() * Math.min(base, 250));
}
const REJEUX_MAX = 3;

function formatAddress(email: string, name?: string): string {
  const n = name?.trim();
  return n ? `${n} <${email}>` : email;
}

// ─── Destinataires (F7, lot 3, 24/09/2026) ─────────────────────────────────
// `register` envoie ses avis internes à une LISTE (l'équipe de la biblio, les
// admins) en un seul message ; les autres appelants donnent un `toEmail`.
// `toEmails` l'emporte quand il est fourni et non vide.
function destinataires(opts): string[] {
  const liste = Array.isArray(opts?.toEmails) ? opts.toEmails.filter(Boolean) : [];
  return liste.length ? liste : [opts.toEmail];
}

// Un transport est-il configuré ? Même règle que l'aiguillage de sendEmail —
// pour les gardes d'environnement en tête de fonction (register exigeait
// RESEND_API_KEY : une pile auto-hébergée en SMTP aurait rendu MISSING_ENV à
// chaque inscription).
export function transportConfigure(): boolean {
  const t = (Deno.env.get("MAIL_TRANSPORT") || "").trim().toLowerCase();
  if (t === "mock") return true;
  if ((Deno.env.get("SMTP_HOST") || "").trim()) return true;
  return Boolean((Deno.env.get("RESEND_API_KEY") || "").trim());
}

// ─── Routage explicite (F7, 23/09/2026) ────────────────────────────────────
// Les fonctions qui portaient leur propre copie de l'envoi n'ont pas toutes la
// même politique d'expéditeur : certaines calculent leur routage elles-mêmes
// avant d'appeler, et `notify-library-request` n'envoie JAMAIS de `reply_to`
// depuis F14 (22/09/2026) — une adresse de réponse hors du domaine d'envoi est
// un motif d'usurpation pour les filtres. Les rassembler ici sans ce passage
// explicite changerait le `From` ou rendrait un `Reply-To` retiré exprès : la
// consolidation doit être invisible dans les messages reçus.
//
// `opts.routing` l'emporte sur le contexte ; `noReplyTo: true` coupe l'adresse
// de réponse même quand le routage en porte une.
export function routageEffectif(opts) {
  const r = opts?.routing ? { ...opts.routing } : resolveMailRouting(opts?.context);
  if (opts?.routing?.noReplyTo === true) {
    return { ...r, replyToEmail: null, replyToName: null };
  }
  return r;
}

async function sendViaResend(opts) {
  const r = routageEffectif(opts);
  const RESEND_KEY = Deno.env.get("RESEND_API_KEY") || "";
  if (!RESEND_KEY) {
    throw new Error("RESEND_API_KEY absente des secrets Edge Function");
  }
  const payload: Record<string, unknown> = {
    from: formatAddress(r.senderEmail, r.senderName),
    to: destinataires(opts),
    subject: opts.subject,
    html: opts.html,
    text: opts.text
  };
  if (r.replyToEmail) {
    payload.reply_to = formatAddress(r.replyToEmail, r.replyToName);
  }
  const url = (Deno.env.get("RESEND_API_URL") || "").trim() || "https://api.resend.com/emails";
  const base = entierEnv("RESEND_RETRY_BASE_MS", 400);
  let tentative = 0;
  for (;;) {
    await cadencer();
    let status = 0, body = "", retryAfter: string | null = null;
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${RESEND_KEY}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(payload)
      });
      status = res.status; body = await res.text(); retryAfter = res.headers?.get?.("retry-after") ?? null;
      if (res.ok) return body;
    } catch (err) {
      status = 0; body = String((err as Error)?.message ?? err);
    }
    if (rejouable(status) && tentative < REJEUX_MAX) {
      const attente = attenteAvantRejeu(retryAfter, tentative, base);
      tentative++;
      console.warn(`[transport] Resend HTTP ${status || "(réseau)"} (label=${opts.label ?? "?"}) : rejeu ${tentative}/${REJEUX_MAX} dans ${attente} ms`);
      await dormir(attente);
      continue;
    }
    throw new Error(status ? `Resend HTTP ${status}: ${body}` : `Resend injoignable : ${body}`);
  }
}

async function sendViaConfiguredSmtp(opts) {
  const r = routageEffectif(opts);
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
    to: destinataires(opts),
    replyTo: r.replyToEmail ? formatAddress(r.replyToEmail, r.replyToName) : undefined,
    subject: opts.subject,
    html: opts.html,
    text: opts.text
  });
}

// --- Wrapper neutre ------------------------------------------------------
// Point d'entree unique. C'est la seule fonction d'envoi que le reste du
// module (safeSendEmail) doit connaitre.
// ─── Un échec de transport se note (F7 / DOC-SILENCE-1, 24/09/2026) ────────
// Chaque envoi du réseau passe ici. Quand le transport refuse, on l'écrit dans
// mail_transport_failures AVANT de relancer l'erreur : la sonde
// fn_healthcheck_mail_transport (health-probe) en fait un incident. Sans ça,
// request-password-reset — qui répond 200 quoi qu'il arrive, par
// anti-énumération — laissait une clé tournée invisible à tout le monde.
// Jamais l'adresse du destinataire : le libellé, le nombre de destinataires,
// l'erreur expurgée et tronquée. Et jamais de seconde erreur par-dessus la
// première : si la note échoue, on le journalise et on relance l'originale.
function expurger(message: string): string {
  return String(message || "").replace(/[^\s@<>"']+@[^\s@<>"']+/g, "<adresse>").slice(0, 300);
}

async function noterEchecTransport(opts, err) {
  try {
    const { error } = await supabaseAdmin.from("mail_transport_failures").insert({
      label: String(opts?.label ?? "?").slice(0, 120),
      recipients: destinataires(opts).length,
      error: expurger(err?.message || String(err))
    });
    if (error) console.warn("[transport] échec non noté :", error.message);
  } catch (e) {
    console.warn("[transport] échec non noté :", String((e as Error)?.message ?? e));
  }
}

export async function sendEmail(opts) {
  try {
    return await aiguillerEtEnvoyer(opts);
  } catch (err) {
    await noterEchecTransport(opts, err);
    throw err;
  }
}

async function aiguillerEtEnvoyer(opts) {
  const smtpHost = (Deno.env.get("SMTP_HOST") || "").trim();
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  const mailTransport = (Deno.env.get("MAIL_TRANSPORT") || "").trim().toLowerCase();

  // 1. Simulation explicite demandée
  if (mailTransport === "mock") {
    console.log(`[transport] [EMAIL SIMULATION] MAIL_TRANSPORT=mock actif (DOC-SILENCE-1) : mail simulé à ${masquerAdresse(destinataires(opts).join(", "))} (« ${opts.subject} »)`);
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
  // F12 (25/09/2026) : pendant un rejeu, un destinataire hors de la liste des refusés
  // a déjà reçu ce courriel — on ne le renvoie pas, et il compte comme servi.
  if (dejaServi(em)) {
    console.log(`[${label}] rejeu : ${masquerAdresse(em)} déjà servi, sauté`);
    return { ok: true, label, email: em, deja_servi: true };
  }
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
    console.log(`[${label}] sent to ${masquerAdresse(em)}`);
    return {
      ok: true,
      label,
      email: em,
      response
    };
  } catch (err) {
    console.error(`[${label}] failed for ${masquerAdresse(em)}:`, err);
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
