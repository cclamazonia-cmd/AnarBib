import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { tMail, label } from "../_shared/i18n/mail-strings.ts";
import { inlineLogosInHtml } from "../_shared/mail/inline-images.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
const DEFAULT_ANARBIB_SENDER_EMAIL = "anarbib@anarbib.org";
const DEFAULT_ANARBIB_REPLY_TO_EMAIL = DEFAULT_ANARBIB_SENDER_EMAIL;
const DEFAULT_ANARBIB_ADMIN_EMAIL = DEFAULT_ANARBIB_SENDER_EMAIL;
// Paquet 25.7 — URL par defaut vers la page de demande de bibliotheque.
// Pointe vers le frontend AnarBib actuel (app.anarbib.org).
// Auparavant pointait vers cclamazonia-cmd.github.io qui est un vestige
// GitHub Pages obsolete (paquet L.4 du chantier linter). L'env var
// ANARBIB_LIBRARY_REQUEST_URL reste exposee pour permettre une URL
// differente en staging futur.
const DEFAULT_LIBRARY_REQUEST_URL = "https://app.anarbib.org/solicitar-biblioteca";
const LIBRARY_REQUEST_CLAIM_TTL_DAYS = 14;
const MAIL_BRAND = {
  // Paquet 25.10 — URL logo migree du vestige GitHub Pages vers Supabase Storage.
  // L'URL Supabase est detectee par inlineLogosInHtml() qui telecharge le logo
  // et l'inline en data URI base64 dans le HTML, contournant ainsi la reecriture
  // d'URLs par Brevo (qui passait par sendibt3.com avec TTL court).
  // Avantage : logo garanti present dans les archives mail meme si Brevo ou
  // Supabase deplacent leurs CDNs ; et plus de dependance au repo GitHub vestige.
  anarbibLogoUrl: "https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/themes/default/logo-anarbib.png",
  colors: {
    bg: "#060606",
    hero: "#111111",
    surface: "#ffffff",
    surfaceAlt: "#f5f0e8",
    textOnDark: "#f7f2ea",
    textOnLight: "#111111",
    mutedOnDark: "#d7cfc3",
    mutedOnLight: "#5f5a55",
    borderDark: "#2b2b2b",
    borderLight: "#dad1c3",
    red: "#a31414",
    redAlt: "#d73333",
    redDeep: "#6d0c0c"
  },
  fonts: {
    heading: "'Arial Black', Impact, Haettenschweiler, 'Segoe UI Black', sans-serif",
    body: "'Trebuchet MS', Verdana, Arial, sans-serif",
    mono: "'Courier New', Courier, monospace"
  }
};
function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders
    }
  });
}
function generateTempPassword(length = 14) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  return Array.from({
    length
  }, ()=>chars[Math.floor(Math.random() * chars.length)]).join("");
}
function escapeHtml(value) {
  return String(value ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}
function normalizeEmail(value) {
  return String(value ?? "").trim().toLowerCase();
}
function normalizeSlug(value) {
  return String(value ?? "").trim().toLowerCase();
}
function sleep(ms) {
  return new Promise((resolve)=>setTimeout(resolve, ms));
}
function firstNonEmptyString(...values) {
  for (const value of values){
    const normalized = String(value ?? "").trim();
    if (normalized) return normalized;
  }
  return "";
}
function uniqueEmails(values) {
  const seen = new Set();
  const result = [];
  for (const value of values){
    const email = normalizeEmail(value);
    if (!email || seen.has(email)) continue;
    seen.add(email);
    result.push(email);
  }
  return result;
}
function buildAddressLine(parts) {
  return parts.map((part)=>part.trim()).filter(Boolean).join(" | ");
}
function readEnvEmail(name, fallback = "") {
  return normalizeEmail(Deno.env.get(name) || fallback);
}
function readEnvString(name, fallback = "") {
  return String(Deno.env.get(name) || fallback).trim();
}
function resolveLibraryInternalRedirectEmail(librarySlug) {
  const envKey = `${normalizeSlug(librarySlug).toUpperCase()}_INTERNAL_REDIRECT_EMAIL`;
  return readEnvEmail(envKey);
}
function buildLogoTable({ anarbibLogoUrl, libraryLogoUrl, libraryName, includeLibraryLogo }) {
  const safeLibraryName = escapeHtml(libraryName || "Biblioteca");
  const cells = [];
  if (anarbibLogoUrl) {
    cells.push(`
      <td style="padding:0 12px 0 0; vertical-align:middle;">
        <img src="${escapeHtml(anarbibLogoUrl)}" alt="AnarBib" style="display:block; height:54px; width:auto; max-width:240px; border:0; outline:none; text-decoration:none;">
      </td>
    `);
  }
  if (includeLibraryLogo && libraryLogoUrl) {
    cells.push(`
      <td style="padding:0; vertical-align:middle;">
        <img src="${escapeHtml(libraryLogoUrl)}" alt="${safeLibraryName}" style="display:block; height:54px; width:auto; max-width:220px; border:0; outline:none; text-decoration:none;">
      </td>
    `);
  }
  if (!cells.length) return "";
  return `
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse; margin:0 0 18px;">
      <tr>${cells.join("")}</tr>
    </table>
  `;
}
function buildInfoCard({ label, value, tone = "red" }) {
  const bg = tone === "red" ? MAIL_BRAND.colors.red : MAIL_BRAND.colors.hero;
  const border = tone === "red" ? MAIL_BRAND.colors.redAlt : MAIL_BRAND.colors.borderDark;
  return `
    <div style="margin:16px 0; padding:16px 18px; border-radius:16px; background:${bg}; border:1px solid ${border}; color:${MAIL_BRAND.colors.textOnDark};">
      <div style="font-family:${MAIL_BRAND.fonts.body}; font-size:12px; font-weight:700; letter-spacing:.08em; text-transform:uppercase; color:${MAIL_BRAND.colors.mutedOnDark}; margin-bottom:8px;">${escapeHtml(label)}</div>
      <div style="font-family:${MAIL_BRAND.fonts.mono}; font-size:23px; font-weight:700; line-height:1.25; color:#ffffff; word-break:break-word;">${escapeHtml(value)}</div>
    </div>
  `;
}
function buildParagraph(text) {
  return `<p style="margin:0 0 14px;">${text}</p>`;
}
function buildActionButton({ href, label }) {
  return `
    <div style="margin:18px 0 20px;">
      <a href="${escapeHtml(href)}" style="display:inline-block; padding:12px 18px; border-radius:14px; background:${MAIL_BRAND.colors.red}; border:1px solid ${MAIL_BRAND.colors.redAlt}; color:#ffffff; font-family:${MAIL_BRAND.fonts.body}; font-size:15px; font-weight:700; text-decoration:none;">${escapeHtml(label)}</a>
    </div>
  `;
}
async function sha256Hex(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((byte)=>byte.toString(16).padStart(2, "0")).join("");
}
function generateOpaqueToken(byteLength = 32) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}
function buildMailShell({ pretitle, title, subtitle, logoTable, contentHtml }) {
  return `
    <div style="margin:0; padding:24px 0; background:${MAIL_BRAND.colors.bg}; background-image:linear-gradient(180deg, ${MAIL_BRAND.colors.bg} 0%, #140707 55%, ${MAIL_BRAND.colors.bg} 100%);">
      <div style="max-width:760px; margin:0 auto; padding:0 16px; font-family:${MAIL_BRAND.fonts.body}; color:${MAIL_BRAND.colors.textOnLight};">
        <div style="border:1px solid ${MAIL_BRAND.colors.redDeep}; border-radius:24px; overflow:hidden; background:${MAIL_BRAND.colors.surface}; box-shadow:0 20px 48px rgba(0,0,0,.42);">
          <div style="background:${MAIL_BRAND.colors.hero}; padding:28px 28px 24px; color:${MAIL_BRAND.colors.textOnDark}; border-bottom:5px solid ${MAIL_BRAND.colors.red};">
            ${logoTable || ""}
            ${pretitle ? `<div style="font-size:12px; font-weight:700; letter-spacing:.12em; text-transform:uppercase; color:${MAIL_BRAND.colors.mutedOnDark}; margin-bottom:10px;">${escapeHtml(pretitle)}</div>` : ""}
            <h1 style="margin:0; font-family:${MAIL_BRAND.fonts.heading}; font-size:34px; line-height:1.05; color:#ffffff;">${escapeHtml(title)}</h1>
            ${subtitle ? `<p style="margin:12px 0 0; font-size:15px; line-height:1.6; color:${MAIL_BRAND.colors.textOnDark};">${escapeHtml(subtitle)}</p>` : ""}
          </div>
          <div style="padding:28px; background:${MAIL_BRAND.colors.surface}; color:${MAIL_BRAND.colors.textOnLight}; font-size:15px; line-height:1.7;">
            ${contentHtml}
          </div>
          <div style="padding:16px 28px 22px; background:${MAIL_BRAND.colors.hero}; border-top:1px solid ${MAIL_BRAND.colors.borderDark}; color:${MAIL_BRAND.colors.mutedOnDark}; font-size:12px; line-height:1.6;">
            AnarBib · rede de bibliotecas sociais, autônomas e companheiras.
          </div>
        </div>
      </div>
    </div>
  `;
}
// Paquet 6 criar-conta — conversion locale technique (pt-BR, fr, ...) vers le
// dossier de langue du site de présentation anarbib.org. Équivalent EF du
// helper galleryUrl() du frontend (src/pages/public/CriarContaPage.jsx) —
// mapping calqué à l'identique. Seul pt-BR diffère (-> pt). Fallback 'pt'.
const SITE_LANG_BY_LOCALE = {
  "pt-BR": "pt", pt: "pt", fr: "fr", es: "es",
  it: "it", en: "en", de: "de", ca: "ca", eo: "eo",
};
function localeToSiteLang(locale) {
  return SITE_LANG_BY_LOCALE[String(locale || "").trim()] || "pt";
}
// Paquet 6 criar-conta — page "projet" du site anarbib.org : le dossier de
// langue ET le mot lui-même sont traduits (fr/projet, pt/projeto, ...).
const SITE_PROJECT_SLUG_BY_LOCALE = {
  "pt-BR": "projeto", pt: "projeto", fr: "projet", es: "proyecto",
  it: "progetto", en: "project", de: "projekt", ca: "projecte", eo: "projekto",
};
function projectUrl(locale) {
  const lang = localeToSiteLang(locale);
  const slug = SITE_PROJECT_SLUG_BY_LOCALE[String(locale || "").trim()] || "projeto";
  return `https://anarbib.org/${lang}/${slug}/`;
}
function buildUserMail({ firstName, libraryName, publicId, tempPassword, postalAddress, contactEmail, anarbibLogoUrl, libraryLogoUrl, isWithoutLibrary = false, isOrphan = false, libraryRequestUrl, galleryUrl, aboutUrl, locale = "pt-BR" }) {
  const logoTable = buildLogoTable({
    anarbibLogoUrl,
    libraryLogoUrl,
    libraryName,
    includeLibraryLogo: !isWithoutLibrary
  });
  // Section "context" : message d'intro adapté au cas.
  // isOrphan implique isWithoutLibrary (cf. site d'appel). Si un 4e cas
  // d'inscription apparaît, refondre ces booléens en énum mailKind.
  const contextParagraph = isOrphan
    ? buildParagraph(tMail(locale, "welcome.context.orphan"))
    : isWithoutLibrary
      ? buildParagraph(tMail(locale, "welcome.context.initial"))
      : buildParagraph(tMail(locale, "welcome.context.standard", { libraryName: escapeHtml(libraryName) }));
  const contentHtml = `
    ${buildParagraph(tMail(locale, "welcome.greeting", { firstName: escapeHtml(firstName) }))}
    ${contextParagraph}
    ${buildInfoCard({
      label: tMail(locale, "welcome.publicIdLabel"),
      value: publicId,
      tone: "red"
    })}
    ${buildInfoCard({
      label: tMail(locale, "welcome.tempPasswordLabel"),
      value: tempPassword,
      tone: "dark"
    })}
    ${buildParagraph(tMail(locale, "welcome.nextAccess"))}
    ${buildParagraph(tMail(locale, "welcome.important"))}
    ${buildParagraph(tMail(locale, "welcome.forgotHint"))}
    ${isWithoutLibrary && !isOrphan && libraryRequestUrl ? buildParagraph(tMail(locale, "welcome.libraryRequest.intro")) : ""}
    ${isWithoutLibrary && !isOrphan && libraryRequestUrl ? buildActionButton({
      href: libraryRequestUrl,
      label: tMail(locale, "welcome.libraryRequest.cta")
    }) : ""}
    ${isWithoutLibrary && !isOrphan && libraryRequestUrl ? buildParagraph(tMail(locale, "welcome.libraryRequest.fallback")) : ""}
    ${isOrphan && galleryUrl ? buildActionButton({
      href: galleryUrl,
      label: tMail(locale, "welcome.orphan.exploreCta")
    }) : ""}
    ${isOrphan && galleryUrl ? buildParagraph(`${tMail(locale, "welcome.orphan.fallback")}<br>${escapeHtml(galleryUrl)}`) : ""}
    ${isOrphan && aboutUrl ? buildParagraph(`${tMail(locale, "welcome.orphan.aboutIntro")}<br><a href="${escapeHtml(aboutUrl)}">${escapeHtml(aboutUrl)}</a>`) : ""}
    ${!isWithoutLibrary && postalAddress ? buildParagraph(`<b>${tMail(locale, "welcome.libraryAddressLabel")}</b> ${escapeHtml(postalAddress)}`) : ""}
    ${!isWithoutLibrary && contactEmail ? buildParagraph(`<b>${tMail(locale, "welcome.libraryContactLabel")}</b> ${escapeHtml(contactEmail)}`) : ""}
    <div style="margin-top:18px; padding:14px 16px; border-radius:14px; border:1px solid ${MAIL_BRAND.colors.borderLight}; background:${MAIL_BRAND.colors.surfaceAlt}; color:${MAIL_BRAND.colors.mutedOnLight}; font-size:13px; line-height:1.6;">
      ${tMail(locale, "welcome.autoMessage")}
    </div>
  `;
  return buildMailShell({
    pretitle: isOrphan
      ? tMail(locale, "welcome.pretitle.orphan")
      : isWithoutLibrary ? tMail(locale, "welcome.pretitle.initial") : tMail(locale, "welcome.pretitle"),
    // Paquet 25.11 — Pour le cas signup_without_library, on utilise un titre
    // SANS placeholder libraryName : "Bienvenue dans le réseau AnarBib" plutot
    // que "Bienvenue à la AnarBib" qui est grammaticalement faux dans plusieurs
    // langues (preposition+article fusionnes attendus avec un nom feminin
    // de bibliotheque, pas avec "AnarBib").
    // Paquet 6 — reader_orphan a son propre titre welcome.title.orphan.
    title: isOrphan
      ? tMail(locale, "welcome.title.orphan")
      : isWithoutLibrary
        ? tMail(locale, "welcome.title.initial")
        : tMail(locale, "welcome.title", { libraryName }),
    subtitle: tMail(locale, "welcome.subtitle"),
    logoTable,
    contentHtml
  });
}
function buildInternalMail({ title, pretitle, subtitle, firstName, lastName, publicId, userEmail, phone, libraryName, fullAddress, isTestContext, anarbibLogoUrl, libraryLogoUrl, isWithoutLibrary = false, locale = "pt-BR" }) {
  const logoTable = buildLogoTable({
    anarbibLogoUrl,
    libraryLogoUrl,
    libraryName,
    includeLibraryLogo: !isWithoutLibrary
  });
  // TR-4 (#153.B) : libelles du corps internationalises. La locale est celle du
  // destinataire institutionnel — locale biblio pour le mail biblio, pt-BR pour
  // le mail gestion AnarBib (doctrine 2C, transmise par l'appelant).
  const contentHtml = `
    ${buildParagraph(`<b>${label(locale, "library")}:</b> ${escapeHtml(libraryName)}`)}
    ${buildParagraph(`<b>${label(locale, "publicId")}:</b> ${escapeHtml(publicId)}`)}
    ${buildParagraph(`<b>${label(locale, "name")}:</b> ${escapeHtml(`${firstName} ${lastName}`.trim())}`)}
    ${buildParagraph(`<b>${label(locale, "email")}:</b> ${escapeHtml(userEmail)}`)}
    ${buildParagraph(`<b>${label(locale, "phone")}:</b> ${escapeHtml(phone)}`)}
    ${fullAddress ? buildParagraph(`<b>${label(locale, "address")}:</b> ${escapeHtml(fullAddress)}`) : ""}
    ${buildParagraph(`<b>${label(locale, "registrationDate")}:</b> ${escapeHtml(new Date().toISOString())}`)}
    ${isTestContext ? `<div style="margin-top:18px; padding:14px 16px; border-radius:14px; border:1px solid ${MAIL_BRAND.colors.borderLight}; background:${MAIL_BRAND.colors.surfaceAlt}; color:${MAIL_BRAND.colors.redDeep}; font-size:13px; line-height:1.6;"><b>${label(locale, "testContext")}:</b> ${tMail(locale, "register.internal.testContextNote")}</div>` : ""}
  `;
  return buildMailShell({
    pretitle,
    title,
    subtitle,
    logoTable,
    contentHtml
  });
}
async function cleanupAuthUser(admin, userId, reason) {
  try {
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) {
      console.error("register: cleanup delete user failed", {
        userId,
        reason,
        error
      });
    } else {
      console.log("register: cleanup delete user ok", {
        userId,
        reason
      });
    }
  } catch (cleanupError) {
    console.error("register: cleanup delete user crashed", {
      userId,
      reason,
      cleanupError
    });
  }
}
// ============================================================================
// Transport mail — envoi via Resend
// ----------------------------------------------------------------------------
// Chantier #110 (migration Brevo -> Resend) : R.3.3 avait introduit un dispatch
// Brevo/Resend pilote par MAIL_PROVIDER ; R.6 (05/06/2026) a retire Brevo.
// sendEmail() inline les logos (§4.5) puis appelle sendViaResend(). Le secret
// MAIL_PROVIDER a ete retire de Supabase en R.7 (08/06/2026) ; n'est
// plus lu par le code.
//
// R.7 (08/06/2026) : les 3 sites d'appel construisent desormais directement un
// payload au format Resend ({ from, to:[email...], reply_to, subject, html }) ;
// la traduction brevoPayloadToResend a ete supprimee. Plus aucune trace de Brevo.
//
// CONTRAT DE RETOUR preserve : { requested, apiAccepted, status, responseText }.
// Jamais de throw. Les 3 sites lisent .apiAccepted, inchanges.
// ============================================================================
function formatMailAddress(email, name) {
  const n = String(name || "").trim();
  return n ? `${n} <${email}>` : email;
}
// --- Implementation Resend (cf. spec §4.4) ---------------------------------
// payload : deja au format Resend ({ from, to:[email...], reply_to, subject,
// html }), html deja inline. Envoye tel quel a api.resend.com.
async function sendViaResend({ logLabel, payload }) {
  const resendKey = (Deno.env.get("RESEND_API_KEY") || "").trim();
  if (!resendKey) {
    console.warn(`register: ${logLabel} skipped, missing RESEND_API_KEY`);
    return {
      requested: false,
      apiAccepted: false,
      status: null,
      responseText: "MISSING_RESEND_API_KEY"
    };
  }
  console.log(`register: ${logLabel} request`, {
    to: payload.to,
    subject: payload.subject
  });
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${resendKey}`,
      "Content-Type": "application/json",
      Accept: "application/json"
    },
    body: JSON.stringify(payload)
  });
  const responseText = await response.text();
  if (!response.ok) {
    console.error(`register: ${logLabel} failed`, {
      status: response.status,
      responseText
    });
    return {
      requested: true,
      apiAccepted: false,
      status: response.status,
      responseText
    };
  }
  console.log(`register: ${logLabel} accepted`, {
    status: response.status,
    responseText
  });
  return {
    requested: true,
    apiAccepted: true,
    status: response.status,
    responseText
  };
}
// --- Wrapper neutre --------------------------------------------------------
// Signature { logLabel, payload } : les 3 sites d'appel passent un payload au
// format Resend. L'inlining des logos est fait ici UNE fois (spec §4.5), avant
// l'envoi. sendViaResend lit RESEND_API_KEY.
async function sendEmail({ logLabel, payload }) {
  // Inlining des logos Supabase Storage en data URI base64 — inconditionnel
  // (spec §4.5). Defensif : en cas d'echec, HTML d'origine conserve, mail
  // expedie quand meme.
  if (payload?.html && typeof payload.html === "string") {
    try {
      payload.html = await inlineLogosInHtml(payload.html);
    } catch (e) {
      console.warn(`register: ${logLabel} inlineLogosInHtml failed (mail sent anyway):`, e);
    }
  }
  console.log(`register: ${logLabel} envoi via resend`);
  return await sendViaResend({ logLabel, payload });
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return json({
      error: "METHOD_NOT_ALLOWED"
    }, 405);
  }
  try {
    const body = await req.json();
    const email = normalizeEmail(body?.email);
    const firstName = String(body?.first_name || "").trim();
    const lastName = String(body?.last_name || "").trim();
    const phone = String(body?.phone || "").trim();
    const gender = String(body?.gender || "").trim();
    const address1 = String(body?.address_1 || "").trim();
    const address2 = String(body?.address_2 || "").trim();
    const addressUnit = String(body?.address_unit || "").trim();
    // district : "Bairro" en pt-BR, "Quartier" en français.
    // Champ à part de address_2 (qui correspond au "Complemento" / 2e ligne).
    const district = String(body?.district || "").trim();
    const cep = String(body?.cep || "").trim();
    const city = String(body?.city || "").trim();
    const state = String(body?.state || "").trim();
    // state_code : code ISO 3166-2 (ex: 'SP', 'IDF') si pays a une liste fermée.
    // Permet de stocker [XX] dans le format canonique pour réinitialisation
    // exacte des dropdowns lors de l'édition ultérieure.
    const stateCode = String(body?.state_code || "").trim().toUpperCase();
    const country = String(body?.country || "").trim();
    // country_code : code ISO 3166-1 alpha-2 (ex: 'BR', 'FR') envoyé par le frontend
    // pour préservation explicite. Si non fourni, on utilise `country` directement
    // (peut être un code ISO 2 lettres ou un nom textuel selon legacy).
    const countryCode = String(body?.country_code || "").trim().toUpperCase();
    const consentEmail = body?.consent_email === true;
    // Phase 6 RGPD : timestamp explicite du consentement (art. 7(1) RGPD).
    // On accepte une valeur fournie par le frontend (ISO string), sinon on
    // utilise l'heure du serveur. Validation : doit être un timestamp ISO valide
    // dans une fenêtre de tolérance raisonnable (±5 min vs heure serveur),
    // sinon fallback sur heure serveur (anti-falsification).
    let consentEmailAt: string | null = null;
    if (consentEmail) {
      const provided = body?.consent_email_at;
      if (typeof provided === "string") {
        const parsed = Date.parse(provided);
        const now = Date.now();
        const FIVE_MIN = 5 * 60 * 1000;
        if (!Number.isNaN(parsed) && Math.abs(parsed - now) <= FIVE_MIN) {
          consentEmailAt = new Date(parsed).toISOString();
        } else {
          consentEmailAt = new Date(now).toISOString();
        }
      } else {
        consentEmailAt = new Date().toISOString();
      }
    }
    const acceptRules = body?.accept_rules === true;
    const librarySlug = normalizeSlug(body?.library_slug);
    const signupWithoutLibrary = body?.signup_without_library === true;
    // ── Paquet 2 — signup_intent (spec criar-conta v0.3 §4.2) ──────────────
    // Le frontend (Paquet 4) enverra signup_intent explicitement. Tant que
    // le Paquet 4 n'est pas livré, le frontend envoie encore l'ancien booléen
    // signup_without_library : on dérive alors signup_intent depuis lui.
    // FALLBACK À RETIRER après livraison du Paquet 4.
    const VALID_SIGNUP_INTENTS = new Set([
      "reader_pending",
      "reader_orphan",
      "collective_candidate"
    ]);
    const rawSignupIntent = String(body?.signup_intent || "").trim();
    let signupIntent: string;
    if (rawSignupIntent) {
      if (!VALID_SIGNUP_INTENTS.has(rawSignupIntent)) {
        return json({
          error: "INVALID_SIGNUP_INTENT"
        }, 400);
      }
      signupIntent = rawSignupIntent;
    } else {
      // Fallback rétrocompat : ancien frontend, dérivation depuis le booléen.
      // signup_without_library=true  → collective_candidate (crée un claim)
      // signup_without_library=false → reader_pending       (crée un membership)
      // reader_orphan n'est PAS atteignable par ce chemin : il requiert le
      // nouveau select à 3 cas du Paquet 4.
      signupIntent = signupWithoutLibrary ? "collective_candidate" : "reader_pending";
    }
    // Nom de bibliothèque mentionné par une lectrice orpheline (optionnel).
    // Spec §4.2.3 : longueur max 200. Échappement XSS reporté au point d'usage
    // (construction HTML du mail interne — escapeHtml).
    const orphanLibraryNameMentioned = String(body?.orphan_library_name_mentioned || "")
      .trim()
      .slice(0, 200);
    const requestedLibraryName = String(body?.library_name || "").trim();
    const requestedLibraryContactEmail = normalizeEmail(body?.library_contact_email);
    const requestedLibraryReplyToEmail = normalizeEmail(body?.library_reply_to_email);
    const requestedLibraryAddress = String(body?.library_address || "").trim();
    const requestedLibraryEmailDeliveryMode = String(body?.library_email_delivery_mode || "normal").trim();
    const requestedLibraryIsTestMode = body?.library_is_test_mode === true;
    const preferredLoginIdentifier = String(body?.preferred_login_identifier || "public_id").trim();
    // Locale du destinataire pour le mail de bienvenue.
    // Le frontend (CriarContaPage) passe `locale: detectLocale()` dans le body.
    // Validation : doit être l'une des 6 locales supportées, sinon fallback pt-BR.
    const SUPPORTED_LOCALES = ["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo"];
    const requestedLocale = String(body?.locale || "").trim();
    const userLocale = SUPPORTED_LOCALES.includes(requestedLocale) ? requestedLocale : "pt-BR";
    if (!email || !firstName || !lastName || !phone) {
      return json({
        error: "MISSING_REQUIRED_FIELDS"
      }, 400);
    }
    // CONSENT : acceptation des règles requise sauf pour les cas sans biblio
    // à rejoindre (collective_candidate et reader_orphan ne rejoignent pas
    // une biblio existante). Pendant exact de l'ancien !signupWithoutLibrary.
    if (!consentEmail || (signupIntent === "reader_pending" && !acceptRules)) {
      return json({
        error: "CONSENT_REQUIRED"
      }, 400);
    }
    // ── Paquet 2 — garde-fous par cas (spec criar-conta v0.3 §4.2.3) ───────
    if (signupIntent === "reader_pending") {
      // Lectrice d'une biblio déjà sur AnarBib : library_slug obligatoire.
      if (!librarySlug) {
        return json({
          error: "LIBRARY_REQUIRED"
        }, 400);
      }
    } else if (signupIntent === "collective_candidate") {
      // Candidature à l'ouverture d'une biblio : library_slug interdit.
      if (librarySlug) {
        return json({
          error: "LIBRARY_SLUG_NOT_ALLOWED"
        }, 400);
      }
    }
    // reader_orphan : aucun garde-fou de slug.
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    // Gate dur sur la cle mail (chantier #110 R.6) : Resend est le seul provider.
    // RESEND_API_KEY est lue ici uniquement pour la validation d'env ; l'envoi
    // reel la relit dans sendViaResend.
    const RESEND_API_KEY = (Deno.env.get("RESEND_API_KEY") || "").trim();
    // R.7 : expediteur harmonise sur SENDER_EMAIL canonique (ex-ANARBIB_SENDER_EMAIL, aligne).
    const senderEmailEnv = readEnvEmail("SENDER_EMAIL", DEFAULT_ANARBIB_SENDER_EMAIL);
    const ANARBIB_REPLY_TO_EMAIL = readEnvEmail("ANARBIB_REPLY_TO_EMAIL", DEFAULT_ANARBIB_REPLY_TO_EMAIL);
    const ANARBIB_ADMIN_EMAIL = readEnvEmail("ANARBIB_ADMIN_EMAIL", DEFAULT_ANARBIB_ADMIN_EMAIL);
    const LIBRARY_REQUEST_URL = readEnvString("ANARBIB_LIBRARY_REQUEST_URL", DEFAULT_LIBRARY_REQUEST_URL);
    if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !RESEND_API_KEY || !senderEmailEnv || !ANARBIB_REPLY_TO_EMAIL || !ANARBIB_ADMIN_EMAIL) {
      return json({
        error: "MISSING_ENV"
      }, 500);
    }
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });
    let libraryMeta = null;
    let libraryRow = null;
    const effectiveLibrarySlug = signupIntent === "reader_pending" ? librarySlug : "";
    if (signupIntent !== "reader_pending") {
      libraryMeta = {
        library_slug: null,
        display_name: requestedLibraryName || "AnarBib",
        contact_email: requestedLibraryContactEmail || "",
        reply_to_email: requestedLibraryReplyToEmail || ANARBIB_REPLY_TO_EMAIL,
        postal_address: requestedLibraryAddress || "",
        email_delivery_mode: requestedLibraryEmailDeliveryMode || "normal",
        is_test_mode: requestedLibraryIsTestMode,
        is_active: true
      };
    } else {
      const { data: foundLibraryMeta, error: libraryError } = await admin.from("library_email_identity").select("*").eq("library_slug", effectiveLibrarySlug).eq("is_active", true).maybeSingle();
      if (libraryError || !foundLibraryMeta) {
        console.error("register: invalid library", {
          librarySlug: effectiveLibrarySlug,
          libraryError
        });
        return json({
          error: "INVALID_LIBRARY",
          detail: "No active library_email_identity row found for the requested library slug.",
          library_slug: effectiveLibrarySlug
        }, 400);
      }
      const { data: foundLibraryRow, error: libraryRowError } = await admin.from("libraries").select("id, slug, name, default_locale, logo_url").eq("slug", effectiveLibrarySlug).maybeSingle();
      if (libraryRowError || !foundLibraryRow?.id) {
        console.error("register: library not found in libraries", {
          librarySlug: effectiveLibrarySlug,
          libraryRowError
        });
        return json({
          error: "LIBRARY_NOT_FOUND",
          detail: "No libraries row found for the requested library slug.",
          library_slug: effectiveLibrarySlug
        }, 400);
      }
      libraryMeta = foundLibraryMeta;
      libraryRow = foundLibraryRow;
    }
    const { data: existingProfiles, error: existingProfilesError } = await admin.from("profiles").select("id, email").eq("email", email).limit(1);
    if (existingProfilesError) {
      console.error("register: profile lookup failed", existingProfilesError);
      return json({
        error: "PROFILE_LOOKUP_FAILED"
      }, 500);
    }
    if (Array.isArray(existingProfiles) && existingProfiles.length > 0) {
      return json({
        error: "Este e-mail já está cadastrado. Se você já tem uma conta, faça login em “Conta do/a/e leitor/a/e”."
      }, 400);
    }
    const tempPassword = generateTempPassword();
    const { data: createUserData, error: createUserError } = await admin.auth.admin.createUser({
      email,
      password: tempPassword,
      email_confirm: true,
      user_metadata: {
        first_name: firstName,
        last_name: lastName,
        preferred_login_identifier: preferredLoginIdentifier
      }
    });
    if (createUserError || !createUserData?.user?.id) {
      console.error("register: create user failed", createUserError);
      return json({
        error: "CREATE_USER_FAILED"
      }, 500);
    }
    const userId = createUserData.user.id;
    let publicId = "";
    for(let i = 0; i < 12; i += 1){
      const { data: profileRow, error: profileError } = await admin.from("profiles").select("id, public_id, email").eq("id", userId).maybeSingle();
      if (!profileError && profileRow?.public_id) {
        publicId = String(profileRow.public_id).trim();
        break;
      }
      await sleep(250);
    }
    if (!publicId) {
      console.error("register: public_id not ready", {
        userId
      });
      await cleanupAuthUser(admin, userId, "PUBLIC_ID_NOT_READY");
      return json({
        error: "PUBLIC_ID_NOT_READY"
      }, 500);
    }
    // Format canonique d'adresse (cf. src/lib/addressFormat.js côté frontend) :
    //   - Texte multi-ligne avec préfixes "Clé: Valeur"
    //   - Codes ISO entre crochets [XX] pour pays et état (réinitialisation
    //     exacte des dropdowns CountrySelect/StateSelect lors de l'édition)
    //   - Compatible rétro avec parseAddressText pour les formats legacy
    const stateLine = state
      ? (stateCode ? `Estado/Região: ${state} [${stateCode}]` : `Estado/Região: ${state}`)
      : "";
    const countryLine = country
      ? (countryCode ? `País: ${country} [${countryCode}]` : `País: ${country}`)
      : "";
    const addressParts = [
      address1 ? `Logradouro: ${address1}` : "",
      address2 ? `Complemento: ${address2}` : "",
      addressUnit ? `Casa/Apto: ${addressUnit}` : "",
      cep ? `CEP/Code postal: ${cep}` : "",
      district ? `Bairro/Quartier: ${district}` : "",
      city ? `Cidade/Ville: ${city}` : "",
      stateLine,
      countryLine,
    ].filter(Boolean);
    const fullAddress = addressParts.join("\n");
    const { data: profileUpdatedRow, error: profileUpdateError } = await admin.from("profiles").update({
      email,
      first_name: firstName,
      last_name: lastName,
      phone,
      gender: gender || null,
      address: fullAddress || null,
      consent_email: true,
      consent_email_at: consentEmailAt,
      must_change_password: true,
    }).eq("id", userId).select("id, email, public_id").maybeSingle();
    if (profileUpdateError || !profileUpdatedRow?.id || !profileUpdatedRow?.email) {
      console.error("register: profile update failed", {
        userId,
        profileUpdateError,
        profileUpdatedRow
      });
      await cleanupAuthUser(admin, userId, "PROFILE_UPDATE_FAILED");
      return json({
        error: "PROFILE_UPDATE_FAILED"
      }, 500);
    }
    // ── Paquet 2 — aiguillage des 3 cas (spec criar-conta v0.3 §4.2.2) ─────
    // Le profil est déjà créé/rempli en amont. signup_intent + metadata
    // sont écrits juste après cette section, une fois claim_id connu.
    let libraryRequestClaimUrl = "";
    let signupIntentMetadata: Record<string, unknown> = {};
    if (signupIntent === "reader_pending") {
      // ── Cas 1 : lectrice d'une biblio déjà sur AnarBib ──────────────────
      // libraryRow a normalement été validé en amont (lookup libraries +
      // return LIBRARY_NOT_FOUND si absent). Re-garde explicite : un
      // reader_pending DOIT avoir un membership, jamais de lecteur orphelin
      // silencieux.
      if (!libraryRow?.id) {
        console.error("register: reader_pending sans libraryRow", {
          userId,
          effectiveLibrarySlug
        });
        await cleanupAuthUser(admin, userId, "READER_PENDING_NO_LIBRARY_ROW");
        return json({
          error: "READER_PENDING_NO_LIBRARY_ROW"
        }, 500);
      }
      const { error: membershipError } = await admin.from("user_library_memberships").upsert({
        user_id: userId,
        library_id: libraryRow.id,
        role: "reader",
        status: "active",
        is_primary: true
      }, {
        onConflict: "user_id,library_id,role"
      });
      if (membershipError) {
        console.error("register: membership upsert failed", membershipError);
        await cleanupAuthUser(admin, userId, "MEMBERSHIP_UPSERT_FAILED");
        return json({
          error: "MEMBERSHIP_UPSERT_FAILED"
        }, 500);
      }
      signupIntentMetadata = {
        library_id: libraryRow.id,
        library_slug: effectiveLibrarySlug
      };
    } else if (signupIntent === "collective_candidate") {
      // ── Cas 2 : candidature à l'ouverture d'une biblio ──────────────────
      // Crée le claim library_request, puis calcule l'URL du CTA candidat.
      const libraryRequestClaimToken = generateOpaqueToken();
      const claimTokenHash = await sha256Hex(libraryRequestClaimToken);
      const claimExpiresAt = new Date(Date.now() + LIBRARY_REQUEST_CLAIM_TTL_DAYS * 24 * 60 * 60 * 1000).toISOString();
      const { data: claimRow, error: claimInsertError } = await admin.from("library_request_claims").insert({
        user_id: userId,
        email_snapshot: email,
        claim_token_hash: claimTokenHash,
        claim_purpose: "library_request",
        expires_at: claimExpiresAt,
        metadata: {
          source: "register_signup_without_library",
          preferred_login_identifier: preferredLoginIdentifier
        },
        created_by_user_id: userId
      }).select("id").maybeSingle();
      if (claimInsertError) {
        console.error("register: claim insert failed", claimInsertError);
        await cleanupAuthUser(admin, userId, "CLAIM_CREATE_FAILED");
        return json({
          error: "CLAIM_CREATE_FAILED"
        }, 500);
      }
      signupIntentMetadata = {
        claim_id: claimRow?.id ?? null
      };
      // Paquet 25.11 — URL du CTA reconstruite pour passer par /login d'abord.
      // L'usager doit de toute facon se connecter (must_change_password=true).
      // En passant par /login?next=<finalUrl> on garantit que :
      //  1. Apres login + force-change, il atterrit sur la page finale
      //  2. Le claim token est preserve dans l'URL finale (apres redirect)
      //  3. Pas besoin d'un parcours separe "page de redirection intermediaire"
      // Le `?next=` est lu par LoginPage (cf. commit 25.6) et utilise comme
      // destination apres login standard ET apres force-change.
      const finalUrl = `${LIBRARY_REQUEST_URL}?claim=${encodeURIComponent(libraryRequestClaimToken)}`;
      // Extraire le chemin + query depuis l'URL absolue de LIBRARY_REQUEST_URL
      // pour ne PAS construire un next=https://... (qui serait rejete par
      // getSafeNextUrl cote frontend pour des raisons de securite open redirect).
      // On extrait juste la partie path+query.
      let nextPathAndQuery;
      try {
        const u = new URL(finalUrl);
        nextPathAndQuery = u.pathname + u.search; // ex: "/solicitar-biblioteca?claim=xxx"
      } catch {
        // Fallback defensif : si LIBRARY_REQUEST_URL n'est pas une URL absolue
        // valide, on utilise telle quelle (cas tres improbable).
        nextPathAndQuery = "/solicitar-biblioteca";
      }
      // Construire l'URL de login avec ?next= encode.
      // Le LIBRARY_REQUEST_URL est cense pointer vers app.anarbib.org/solicitar-biblioteca
      // donc l'origine du login = meme origine.
      let loginOrigin;
      try {
        loginOrigin = new URL(LIBRARY_REQUEST_URL).origin; // "https://app.anarbib.org"
      } catch {
        loginOrigin = "https://app.anarbib.org";
      }
      libraryRequestClaimUrl = `${loginOrigin}/login?next=${encodeURIComponent(nextPathAndQuery)}`;
    } else {
      // ── Cas 3 : lectrice orpheline (biblio pas encore sur AnarBib) ──────
      // NI membership, NI claim. Juste le profil (déjà créé) + le tag.
      signupIntentMetadata = orphanLibraryNameMentioned
        ? { library_name_mentioned: orphanLibraryNameMentioned }
        : {};
    }
    // ── Paquet 2 — écriture des colonnes signup_intent (Paquet 1 DB) ───────
    // Second UPDATE dédié : signupIntentMetadata n'est complet qu'ici (le
    // claim_id n'existe qu'après l'insert du claim). Colonnes créées par la
    // migration 20260521120000_profiles_signup_intent.sql.
    const { error: signupIntentUpdateError } = await admin.from("profiles").update({
      signup_intent: signupIntent,
      signup_intent_metadata: signupIntentMetadata,
      signup_intent_set_at: new Date().toISOString()
    }).eq("id", userId);
    if (signupIntentUpdateError) {
      // Non bloquant : compte, membership/claim et profil sont déjà créés et
      // cohérents. signup_intent est un marqueur ; son échec d'écriture ne
      // justifie pas de détruire le compte. On loggue et on poursuit.
      console.error("register: signup_intent update failed (non bloquant)", {
        userId,
        signupIntent,
        signupIntentUpdateError
      });
    }
    // ── Paquet 2 — le mail de bienvenue selon le cas ───────────────────────
    // mailIsWithoutLibrary pilote le registre i18n du mail (titre, intro, logo)
    // et la logique de routage interne :
    //   reader_pending       → false : mail "standard" + nom/logo biblio
    //   collective_candidate → true  : mail "initial" + bloc CTA candidat
    //                                  (libraryRequestClaimUrl non vide)
    //   reader_orphan        → true  : mail "initial" SANS bloc CTA
    //                                  (libraryRequestClaimUrl vide → bloc omis)
    // PAQUET 2 PROVISOIRE — reader_orphan réutilise le registre "initial"
    // existant : zéro nouvelle clé i18n, zéro jetable. Un mail
    // welcome-reader-orphan dédié est prévu au Paquet 6.
    const mailIsWithoutLibrary = signupIntent !== "reader_pending";
    // Paquet 6 criar-conta — reader_orphan a désormais son registre i18n
    // dédié (welcome.*.orphan) et son bloc CTA galerie. mailIsOrphan
    // implique toujours mailIsWithoutLibrary (cf. les 3 cas ci-dessus).
    const mailIsOrphan = signupIntent === "reader_orphan";
    const displayName = firstNonEmptyString(libraryMeta?.display_name, libraryRow?.name, requestedLibraryName, mailIsWithoutLibrary ? "AnarBib" : effectiveLibrarySlug);
    const contactEmail = normalizeEmail(libraryMeta?.contact_email);
    const postalAddress = String(libraryMeta?.postal_address || "").trim();
    const emailDeliveryMode = String(libraryMeta?.email_delivery_mode || "normal").trim();
    const isTestMode = libraryMeta?.is_test_mode === true;
    // #153.C : le logo de la biblio est résolu depuis son contexte (la base)
    // — colonne libraries.logo_url, lue dans le select de libraryRow — et non
    // plus depuis un objet codé en dur dans ce fichier. Une biblio nouvellement
    // ajoutée au réseau affiche ainsi son logo dans ses mails sans aucune
    // édition de code. Cas mailIsWithoutLibrary : pas de biblio rattachée donc
    // pas de logo ; cas logo_url NULL/vide : firstNonEmptyString normalise en
    // chaîne vide et buildLogoTable omet la cellule (repli « pas de logo »).
    const anarbibLogoUrl = MAIL_BRAND.anarbibLogoUrl;
    const libraryLogoUrl = mailIsWithoutLibrary ? "" : firstNonEmptyString(libraryRow?.logo_url);
    const replyToEmail = ANARBIB_REPLY_TO_EMAIL;
    const senderEmail = senderEmailEnv;
    const senderDisplayName = mailIsWithoutLibrary ? "AnarBib" : `AnarBib · ${displayName}`;
    const libraryInternalRedirectEmail = mailIsWithoutLibrary ? "" : resolveLibraryInternalRedirectEmail(effectiveLibrarySlug);
    const effectiveLibraryInternalRecipients = mailIsWithoutLibrary ? [] : uniqueEmails([
      libraryInternalRedirectEmail || contactEmail
    ]);
    const adminRecipients = uniqueEmails([
      ANARBIB_ADMIN_EMAIL
    ]);
    console.log("register: routing", {
      library_slug: effectiveLibrarySlug,
      signup_intent: signupIntent,
      display_name: displayName,
      configured_contact_email: contactEmail,
      effective_library_internal_recipients: effectiveLibraryInternalRecipients,
      admin_recipients: adminRecipients,
      email_delivery_mode: emailDeliveryMode,
      is_test_mode: isTestMode
    });
    const userMailHtml = buildUserMail({
      firstName,
      libraryName: displayName,
      publicId,
      tempPassword,
      postalAddress,
      contactEmail,
      anarbibLogoUrl,
      libraryLogoUrl,
      isWithoutLibrary: mailIsWithoutLibrary,
      isOrphan: mailIsOrphan,
      libraryRequestUrl: libraryRequestClaimUrl,
      galleryUrl: mailIsOrphan ? `https://anarbib.org/${localeToSiteLang(userLocale)}/explorar/` : "",
      aboutUrl: mailIsOrphan ? projectUrl(userLocale) : "",
      locale: userLocale
    });
    // ── TR-4 (#153.B) — libellés internes internationalisés ───────────────
    // Doctrine 2C : le mail biblio est rendu dans la locale de la biblio
    // (libraryRow.default_locale) ; le mail gestion AnarBib en pt-BR, locale
    // de référence du réseau. Cas reader_orphan / collective_candidate : pas
    // de biblio rattachée -> libraryRow null -> repli pt-BR.
    const internalLibLocale = libraryRow?.default_locale || "pt-BR";
    const internalAdminLocale = "pt-BR";
    // Construit les chaines internes pour une locale donnee (biblio ou admin).
    const buildInternalStrings = (loc)=>{
      const orphanLibLine = orphanLibraryNameMentioned
        ? tMail(loc, "register.internal.orphanLib.mentioned", { libraryName: orphanLibraryNameMentioned })
        : tMail(loc, "register.internal.orphanLib.none");
      let title, subtitle;
      if (signupIntent === "reader_orphan") {
        title = tMail(loc, "register.internal.title.orphan", { displayName });
        subtitle = tMail(loc, "register.internal.subtitle.orphan", { publicId }) + orphanLibLine;
      } else if (signupIntent === "collective_candidate") {
        title = tMail(loc, "register.internal.title.initial", { displayName });
        subtitle = tMail(loc, "register.internal.subtitle.initial", { publicId });
      } else {
        title = tMail(loc, "register.internal.title.standard", { displayName });
        subtitle = tMail(loc, "register.internal.subtitle.standard", { publicId });
      }
      return { title, subtitle };
    };
    const libraryStrings = buildInternalStrings(internalLibLocale);
    const adminStrings = buildInternalStrings(internalAdminLocale);
    const libraryMailHtml = buildInternalMail({
      title: libraryStrings.title,
      pretitle: mailIsWithoutLibrary
        ? tMail(internalLibLocale, "register.internal.pretitle.coordination")
        : tMail(internalLibLocale, "register.internal.pretitle.library"),
      subtitle: libraryStrings.subtitle,
      firstName,
      lastName,
      publicId,
      userEmail: email,
      phone,
      libraryName: displayName,
      fullAddress,
      isTestContext: isTestMode || Boolean(libraryInternalRedirectEmail),
      anarbibLogoUrl,
      libraryLogoUrl,
      isWithoutLibrary: mailIsWithoutLibrary,
      locale: internalLibLocale
    });
    const adminMailHtml = buildInternalMail({
      title: adminStrings.title,
      pretitle: tMail(internalAdminLocale, "register.internal.pretitle.management"),
      subtitle: adminStrings.subtitle,
      firstName,
      lastName,
      publicId,
      userEmail: email,
      phone,
      libraryName: displayName,
      fullAddress,
      isTestContext: isTestMode || Boolean(libraryInternalRedirectEmail),
      anarbibLogoUrl,
      libraryLogoUrl,
      isWithoutLibrary: mailIsWithoutLibrary,
      locale: internalAdminLocale
    });
    const userSendResult = await sendEmail({
      logLabel: "welcome email",
      payload: {
        from: formatMailAddress(senderEmail, senderDisplayName),
        to: [email],
        reply_to: formatMailAddress(replyToEmail, senderDisplayName),
        subject: mailIsOrphan
          ? tMail(userLocale, "welcome.subject.orphan")
          : mailIsWithoutLibrary
            ? tMail(userLocale, "welcome.subject.initial", { displayName })
            : tMail(userLocale, "welcome.subject", { displayName }),
        html: userMailHtml
      }
    });
    if (!userSendResult.apiAccepted) {
      console.error("register: welcome email not accepted", {
        userId,
        status: userSendResult.status,
        responseText: userSendResult.responseText
      });
    }
    let librarySendResult = {
      requested: false,
      apiAccepted: false,
      status: null,
      responseText: "NO_LIBRARY_RECIPIENT"
    };
    if (effectiveLibraryInternalRecipients.length) {
      librarySendResult = await sendEmail({
        logLabel: "library internal email",
        payload: {
          from: formatMailAddress(senderEmail, senderDisplayName),
          to: effectiveLibraryInternalRecipients,
          reply_to: formatMailAddress(replyToEmail, senderDisplayName),
          subject: tMail(internalLibLocale, "register.internal.subject", { displayName, publicId }),
          html: libraryMailHtml
        }
      });
    }
    let adminSendResult = {
      requested: false,
      apiAccepted: false,
      status: null,
      responseText: "NO_ADMIN_RECIPIENT"
    };
    if (adminRecipients.length) {
      adminSendResult = await sendEmail({
        logLabel: "admin internal email",
        payload: {
          from: formatMailAddress(senderEmail, senderDisplayName),
          to: adminRecipients,
          reply_to: formatMailAddress(replyToEmail, senderDisplayName),
          subject: tMail(internalAdminLocale, "register.internal.subject", { displayName, publicId }),
          html: adminMailHtml
        }
      });
    }
    return json({
      ok: true,
      public_id: publicId,
      email_usuaria_enviado: userSendResult.apiAccepted,
      internal_notification_enviada: librarySendResult.apiAccepted && adminSendResult.apiAccepted,
      library_notification_enviada: librarySendResult.apiAccepted,
      admin_notification_enviada: adminSendResult.apiAccepted,
      user_email_requested: userSendResult.requested,
      user_email_api_accepted: userSendResult.apiAccepted,
      library_email_requested: librarySendResult.requested,
      library_email_api_accepted: librarySendResult.apiAccepted,
      admin_email_requested: adminSendResult.requested,
      admin_email_api_accepted: adminSendResult.apiAccepted,
      library_slug: signupIntent === "reader_pending" ? effectiveLibrarySlug : null,
      // ── Paquet 2 — réponse alignée sur signup_intent (spec §4.2) ─────────
      signup_intent: signupIntent,
      // signup_without_library conservé pour rétrocompat tant que le Paquet 4
      // (frontend) n'est pas livré. À RETIRER avec le fallback d'entrée.
      signup_without_library: signupIntent !== "reader_pending",
      library_request_claim_created: signupIntent === "collective_candidate"
        ? Boolean(libraryRequestClaimUrl)
        : false
    });
  } catch (error) {
    console.error("register function crash", error);
    return json({
      error: "REGISTER_FAILED"
    }, 500);
  }
});
