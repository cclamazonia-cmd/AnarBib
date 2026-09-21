// ============================================================================
// domain/gazette.ts — Handler des events gazette.* (notifications Gazette)
// ============================================================================
// Lit la ligne gazette_submission_notification_outbox par recordId (BIGINT),
// résout destinataire(s) + locale, rend le mail i18n, envoie via safeSendEmail,
// puis pose le statut outbox (sent / skipped / failed). Même architecture que
// domain/team.ts. Contexte RÉSEAU (pas de biblio) → ctx = resolve(null) :
// expéditeur par défaut (SENDER_EMAIL, sous-domaine vérifié), pas de kill-switch
// biblio (les notifications éditoriales/réseau ne sont pas opt-out par biblio).
//
// Events traités (Étape A) :
//   - gazette.contribution.received   → fede@anarbib.org (boîte éditoriale fixe)
//   - gazette.draft.ready_for_review  → network_staff (fan-out, chacun·e sa locale)
//   - gazette.issue.published         → 1 destinataire par ligne (fan-out SQL)
// GAZ-7 (15/09/2026) — la décision est dite à la personne qui a écrit :
//   - gazette.contribution.rejected   → contributor_email, dans SA locale : le motif
//                                       écrit par le staff + le lien de reprise (jeton
//                                       d'usage unique, 60 jours). Le jeton arrive en
//                                       clair dans le payload ; la base n'en garde que
//                                       l'empreinte. L'URL se construit ICI (le front
//                                       n'est pas l'affaire du SQL).
//   - gazette.contribution.accepted   → contributor_email : la brève entrera dans la
//                                       page « Vie du réseau » du prochain numéro.
//   Sans e-mail, la base n'enfile rien (personne à prévenir) ; si une ligne arrive
//   quand même sans `to`, elle est sautée en le disant (no_recipients).
// ============================================================================
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, userTargetFromProfile } from "../transport/email.ts";
import { APP_BASE_URL } from "../core/app-url.ts";
import { verdictEnvois } from "./outbox-verdict.ts";
import { tMail, greeting, formatDateLocale } from "../i18n/mail-strings.ts";

const OUTBOX = "gazette_submission_notification_outbox";
const APP_URL = APP_BASE_URL; // foyer unique : ../core/app-url.ts (secret APP_BASE_URL)
const EDITORIAL_FALLBACK = "fede@anarbib.org";

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
function safeUrl(u) {
  const s = String(u ?? "").trim();
  return /^https?:\/\//i.test(s) ? s : "";
}

async function markOutboxSent(id) {
  await supabaseAdmin.from(OUTBOX).update({ status: "sent", sent_at: new Date().toISOString() }).eq("id", id);
}
// B12 / DOC-SILENCE-1 : un saut doit dire pourquoi. La raison part dans
// `skip_reason`, distincte de `last_error` -- un saut delibere n'est pas une
// panne. Et pas de `sent_at` : dans un journal, il veut dire « un courriel est
// parti ». Les CHECK de la migration 20260831090412 refusent l'oubli.
async function markOutboxSkipped(id, reason) {
  await supabaseAdmin.from(OUTBOX).update({ status: "skipped", skip_reason: String(reason || "raison_non_precisee") }).eq("id", id);
}
async function markOutboxFailed(id, errorMsg) {
  await supabaseAdmin.from(OUTBOX).update({ status: "failed", last_error: errorMsg }).eq("id", id);
}

// network_staff = network_administrators status='active', joints aux profiles
// (email + preferred_language). Même source que team.ts loadAdministradores.
async function loadNetworkStaff() {
  const { data: members, error: e1 } = await supabaseAdmin
    .from("network_administrators").select("user_id").eq("status", "active");
  if (e1 || !members || members.length === 0) return [];
  const userIds = Array.from(new Set(members.map((m) => m.user_id)));
  const { data: profiles, error: e2 } = await supabaseAdmin
    .from("profiles").select("id,email,first_name,last_name,preferred_language").in("id", userIds);
  if (e2 || !profiles) return [];
  return profiles;
}

export async function handleGazetteEvent(recordId) {
  const { data: outbox, error } = await supabaseAdmin
    .from(OUTBOX).select("id,event,payload,status").eq("id", recordId).maybeSingle();
  if (error) throw error;
  if (!outbox) throw new Error(`${OUTBOX} row ${recordId} not found`);
  const event = String(outbox.event || "").trim();
  const payload = outbox.payload || {};
  const ctx = await resolveLibraryNotificationContext(null); // contexte réseau

  try {
    let result;
    if (event === "gazette.contribution.received") {
      result = await handleContributionReceived(payload, ctx);
    } else if (event === "gazette.draft.ready_for_review") {
      result = await handleDraftReady(payload, ctx);
    } else if (event === "gazette.issue.published") {
      result = await handleIssuePublished(payload, ctx);
    } else if (event === "gazette.contribution.rejected") {
      result = await handleContributionRejected(payload, ctx);
    } else if (event === "gazette.contribution.accepted") {
      result = await handleContributionAccepted(payload, ctx);
    } else {
      console.warn(`[gazette] unknown event: ${event}`);
      await markOutboxSkipped(outbox.id, "unknown_gazette_event");
      return { ok: true, ignored: true, reason: "unknown_gazette_event", event };
    }
    // DOC-SILENCE-1 (21/09/2026) : le statut de la ligne se lit sur le RÉSULTAT des
    // envois (outbox-verdict.ts), plus sur le seul nombre de destinataires — un
    // envoi refusé par le transport passait pour « sent ».
    const verdict = verdictEnvois(result);
    if (verdict.status === "skipped") await markOutboxSkipped(outbox.id, verdict.detail);
    else if (verdict.status === "failed") await markOutboxFailed(outbox.id, verdict.detail);
    else await markOutboxSent(outbox.id);
    return { ...result, ok: verdict.status !== "failed", event, outbox_status: verdict.status };
  } catch (err) {
    await markOutboxFailed(outbox.id, String(err?.message || err));
    throw err;
  }
}

// gazette.contribution.received → boîte éditoriale fixe (fede@anarbib.org).
// Mail dans la langue de travail réseau (ctx.default_locale, repli fr).
async function handleContributionReceived(payload, ctx) {
  const to = String(payload.to || EDITORIAL_FALLBACK).trim();
  // Enrobage dans la langue de la contribution (choix : la notif éditoriale suit
  // la locale de l'auteur·rice) ; repli sur la langue de base réseau si absente.
  const locale = String(payload.locale || "").trim() || ctx?.default_locale || "pt-BR";
  const rubric = String(payload.rubric || "—");
  const title = String(payload.title || "");
  const excerpt = String(payload.excerpt || "");
  const link = safeUrl(payload.link);
  const namePart = String(payload.contributor_name || "").trim();
  const collPart = String(payload.contributor_collective || "").trim();
  const author = [namePart, collPart].filter(Boolean).join(" · ") || "—";

  const sub = tMail(locale, "gazette.contribution.received.sub");
  let introHtml = `<p>${esc(tMail(locale, "gazette.contribution.received.intro", { rubric, title, author }))}</p>`;
  // GAZ-7 : une reprise se présente comme telle — le staff relit une v2, pas un inconnu.
  if (payload.parent_submission_id) {
    introHtml += `<p><b>${esc(tMail(locale, "gazette.contribution.received.resubmitted"))}</b></p>`;
  }
  if (excerpt) introHtml += `<blockquote style="margin:.6rem 0;padding-left:.8rem;border-left:3px solid #cf1f27;color:#444">${esc(excerpt)}</blockquote>`;
  if (link) introHtml += `<p><a href="${esc(link)}">${esc(link)}</a></p>`;
  introHtml += `<p><a href="${APP_URL}/rede">${APP_URL}/rede</a></p>`;

  const { html, text } = renderEmail({
    locale,
    preheader: sub,
    title: sub,
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx,
  });
  const target = { email: to, name: "Gazette AnarBib" };
  const result = await safeSendEmail(target, sub, html, text, "gazette_contribution", ctx);
  return { recipients_count: 1, result };
}

// gazette.contribution.rejected → la personne qui a écrit, dans sa locale : le
// motif tel que le staff l'a écrit, et le lien de reprise (jeton en clair dans
// le payload, empreinte seule en base ; 60 jours ; usage unique).
async function handleContributionRejected(payload, ctx) {
  const to = String(payload.to || "").trim();
  if (!to) return { recipients_count: 0, reason: "no_email" };
  const locale = String(payload.locale || "").trim() || ctx?.default_locale || "pt-BR";
  const title = String(payload.title || "");
  const rubric = String(payload.rubric || "—");
  const note = String(payload.review_note || "").trim();
  const token = String(payload.resubmit_token || "").trim();
  const expires = formatDateLocale(payload.expires_at, locale);

  const sub = tMail(locale, "gazette.contribution.rejected.sub", { title });
  let introHtml = `<p>${esc(tMail(locale, "gazette.contribution.rejected.intro", { rubric, title }))}</p>`;
  if (note) introHtml += `<blockquote style="margin:.6rem 0;padding-left:.8rem;border-left:3px solid #cf1f27;color:#444;white-space:pre-wrap">${esc(note)}</blockquote>`;
  let actionBox;
  if (token) {
    actionBox = {
      kind: "action",
      title: tMail(locale, "gazette.contribution.rejected.resubmit.title"),
      ctaLabel: tMail(locale, "gazette.contribution.rejected.resubmit.cta"),
      ctaUrl: `${APP_URL}/federacao/gazeta?reprise=${encodeURIComponent(token)}`,
    };
    introHtml += `<p>${esc(tMail(locale, "gazette.contribution.rejected.resubmit.expires", { date: expires }))}</p>`;
  }

  const { html, text } = renderEmail({
    locale,
    preheader: sub,
    title: sub,
    greeting: greeting(locale, payload.to_name || undefined),
    actionBox,
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx,
  });
  const target = { email: to, name: payload.to_name || undefined };
  const result = await safeSendEmail(target, sub, html, text, "gazette_contribution_rejected", ctx);
  return { recipients_count: 1, result };
}

// gazette.contribution.accepted → la personne qui a écrit, dans sa locale.
async function handleContributionAccepted(payload, ctx) {
  const to = String(payload.to || "").trim();
  if (!to) return { recipients_count: 0, reason: "no_email" };
  const locale = String(payload.locale || "").trim() || ctx?.default_locale || "pt-BR";
  const title = String(payload.title || "");
  const sub = tMail(locale, "gazette.contribution.accepted.sub", { title });
  let introHtml = `<p>${esc(tMail(locale, "gazette.contribution.accepted.intro", { title }))}</p>`;
  // GAZ-9 : retenue AVEC corrections du staff — la personne voit le texte qui
  // paraîtra, pas seulement la nouvelle.
  if (payload.corrected) {
    introHtml += `<p>${esc(tMail(locale, "gazette.contribution.accepted.corrected"))}</p>`
      + `<blockquote style="margin:.6rem 0;padding-left:.8rem;border-left:3px solid #cf1f27;color:#444;white-space:pre-wrap">`
      + `<b>${esc(title)}</b>\n${esc(String(payload.body || ""))}</blockquote>`;
  }
  introHtml += `<p><a href="${APP_URL}/federacao/gazeta">${APP_URL}/federacao/gazeta</a></p>`;
  const { html, text } = renderEmail({
    locale,
    preheader: sub,
    title: sub,
    greeting: greeting(locale, payload.to_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx,
  });
  const target = { email: to, name: payload.to_name || undefined };
  const result = await safeSendEmail(target, sub, html, text, "gazette_contribution_accepted", ctx);
  return { recipients_count: 1, result };
}

// gazette.draft.ready_for_review → fan-out network_staff, chacun·e dans sa locale.
async function handleDraftReady(payload, ctx) {
  const number = String(payload.issue_number ?? "");
  const staff = await loadNetworkStaff();
  if (staff.length === 0) return { recipients_count: 0, reason: "no_network_staff" };

  const results = [];
  for (const person of staff) {
    const locale = person.preferred_language || null;
    const target = userTargetFromProfile(person);
    if (!target) continue;
    const sub = tMail(locale, "gazette.draft.ready_for_review.sub", { number });
    const introHtml =
      `<p>${esc(tMail(locale, "gazette.draft.ready_for_review.intro", { number }))}</p>`
      + `<p><a href="${APP_URL}/rede">${APP_URL}/rede</a></p>`;
    const { html, text } = renderEmail({
      locale,
      preheader: sub,
      title: sub,
      greeting: greeting(locale, person.first_name || undefined),
      introHtml,
      details: [],
      footerHtml: footerPadrao(ctx, locale),
      context: ctx,
    });
    results.push(await safeSendEmail(target, sub, html, text, "gazette_draft_review", ctx));
  }
  return { recipients_count: results.length, results };
}

// gazette.issue.published → 1 destinataire (le fan-out est fait à l'énumération
// par api.fn_gazette_broadcast : 1 ligne d'outbox par personne). Mail dans la
// locale du destinataire ; lien vers la gazette PUBLIQUE (le numéro est publié).
async function handleIssuePublished(payload, ctx) {
  const to = String(payload.to || "").trim();
  if (!to) return { recipients_count: 0, reason: "no_email" };
  const locale = String(payload.locale || "").trim() || ctx?.default_locale || "pt-BR";
  const number = String(payload.issue_number ?? "");
  const sub = tMail(locale, "gazette.issue.published.sub", { number });
  const introHtml =
    `<p>${esc(tMail(locale, "gazette.issue.published.intro", { number }))}</p>`
    + `<p><a href="${APP_URL}/federacao/gazeta">${APP_URL}/federacao/gazeta</a></p>`;
  const { html, text } = renderEmail({
    locale,
    preheader: sub,
    title: sub,
    greeting: greeting(locale, payload.to_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx,
  });
  const target = { email: to, name: payload.to_name || undefined };
  const result = await safeSendEmail(target, sub, html, text, "gazette_published", ctx);
  return { recipients_count: 1, result };
}
