import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { profileRestrictionEnabled } from "../context/policies.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { ADMIN_EMAIL, ADMIN_NAME, supabaseAdmin } from "../core/env.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { adminDisplayName, formatDateBR, fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

// ============================================================================
// #NOTIFY-Painel-acts — Famille 2 : restriction locale + gel global (et levées).
// ----------------------------------------------------------------------------
// Events : member_restricted_local / member_unrestricted_local /
//          member_frozen_global / member_unfrozen_global.
// Destinataires (validés 08/06) :
//   - le MEMBRE : e-mail OBLIGATOIRE (NOTIF-PA3, B3 impact droits).
//   - la/les BIBLIO(s) : copie gardée par profile_restriction_enabled de chaque
//     biblio. Local = la biblio de l'acte ; global = TOUTES les biblios actives
//     du membre (le gel les impacte aussi).
//   - le RÉSEAU (gel global uniquement) : ADMIN_EMAIL, toujours.
// Contenu : motif + portée (locale/réseau) + date. Réutilise les clés prof.*.
// DOC-NOTIF-1 : on notifie le membre/les biblios impactées, pas l'acteur.
// ============================================================================
export async function handleMembershipRestriction(event, payload) {
  const userId = String(payload?.user_id || "").trim();
  if (!userId) throw new Error("user_id manquant.");
  const isGlobal = event.indexOf("global") >= 0;
  const isLift = event.indexOf("unrestricted") >= 0 || event.indexOf("unfrozen") >= 0;
  const reason = String(payload?.reason || "").trim();
  const libraryId = String(payload?.library_id || "").trim();
  const atRaw = String(payload?.at || "").trim();

  const { data: profile, error } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!profile) throw new Error("Perfil não encontrado.");

  // Biblios concernées : locale = celle de l'acte ; globale = toutes les biblios
  // actives du membre (primaire en tête pour le branding du mail membre).
  let libIds = [];
  if (!isGlobal && libraryId) {
    libIds = [libraryId];
  } else {
    const { data: mems } = await supabaseAdmin
      .from("user_library_memberships")
      .select("library_id,is_primary")
      .eq("user_id", userId)
      .eq("status", "active");
    const all = (mems || []).map((m) => ({ id: String(m.library_id || "").trim(), primary: !!m.is_primary })).filter((m) => m.id);
    all.sort((a, b) => (b.primary ? 1 : 0) - (a.primary ? 1 : 0));
    const seen = new Set();
    for (const m of all) {
      if (!seen.has(m.id)) { seen.add(m.id); libIds.push(m.id); }
    }
  }

  const brandingLibId = libIds[0] || null;
  const ctx = await resolveLibraryNotificationContext(brandingLibId);
  const user = userTargetFromProfile(profile);
  const locale = String(profile?.preferred_language || "").trim() || null;
  const aun = adminDisplayName(fullName(profile), user?.email);

  const scopeFor = (loc, c) => isGlobal ? tMail(loc, "restriction.scope.network") : (c?.library_name || subjectTag(c));
  const titleFor = (loc) => isLift
    ? tMail(loc, "restriction.lifted.subject")
    : (isGlobal ? tMail(loc, "restriction.global.subject") : tMail(loc, "prof.restricted"));
  const introFor = (loc) => {
    if (isLift) return `<p>${tMail(loc, "restriction.lifted.intro")}</p>`;
    if (isGlobal) return `<p>${tMail(loc, "restriction.global.intro")}</p><p>${tMail(loc, "prof.contactLibrary")}</p>`;
    return `<p>${tMail(loc, "prof.restricted.intro")}</p><p>${tMail(loc, "prof.contactLibrary")}</p>`;
  };
  const detFor = (loc, c, fmt) => {
    const d = [{ label: label(loc, "scope"), value: scopeFor(loc, c) }];
    if (!isLift && reason) d.push({ label: label(loc, "reason"), value: reason });
    if (atRaw) d.push({ label: label(loc, "restrictedSince"), value: fmt(atRaw) });
    return d;
  };

  // (1) Membre — OBLIGATOIRE.
  let user_result = skippedEmailResult("user_mail", "no_recipient_email");
  if (user?.email) {
    const fmtD = (x) => formatDateLocale(x, locale) || formatDateBR(x) || "";
    const tit = titleFor(locale);
    const { html, text } = renderEmail({
      locale, preheader: tit, title: tit, greeting: greeting(locale, user?.name),
      introHtml: introFor(locale), details: detFor(locale, ctx, fmtD),
      footerHtml: footerPadrao(ctx, locale), context: ctx
    });
    user_result = await safeSendEmail(user, applyBrandingText(`${tit} — ${subjectTag(ctx)}`, ctx), html, text, "user_mail", ctx);
  }

  // Construit + envoie une copie staff (biblio ou réseau) dans la locale de la biblio.
  const sendStaffCopy = async (targetCtx, target, lbl) => {
    const lloc = String(targetCtx?.default_locale || "pt-BR").trim() || "pt-BR";
    const fmtL = (x) => formatDateLocale(x, lloc) || formatDateBR(x) || "";
    const titL = titleFor(lloc);
    const { html: ha, text: ta } = renderEmail({
      locale: lloc, preheader: titL, title: titL,
      introHtml: `<p>${titL}.</p>`,
      details: [{ label: label(lloc, "reader"), value: aun }, ...detFor(lloc, targetCtx, fmtL)],
      footerHtml: footerPadrao(targetCtx, lloc), context: targetCtx
    });
    return await safeSendEmail(target, applyBrandingText(`[${subjectTag(targetCtx)}] ${titL} — ${aun}`, targetCtx), ha, ta, lbl, targetCtx);
  };

  // (2) Copies biblio — toutes les biblios concernées, gardées par leur policy.
  const biblio_results = [];
  for (const libId of libIds) {
    const lctx = libId === brandingLibId ? ctx : await resolveLibraryNotificationContext(libId);
    if (!profileRestrictionEnabled(lctx)) { biblio_results.push(skippedEmailResult("admin_copy", "staff_copy_disabled")); continue; }
    biblio_results.push(await sendStaffCopy(lctx, adminTarget(lctx), "admin_copy"));
  }

  // (3) Réseau — gel global uniquement, toujours (ADMIN_EMAIL).
  let network_result = null;
  if (isGlobal) {
    const nemail = String(ADMIN_EMAIL || "").trim();
    network_result = nemail
      ? await sendStaffCopy(ctx, { email: nemail, name: ADMIN_NAME || "AnarBib" }, "network_copy")
      : skippedEmailResult("network_copy", "no_network_email");
  }

  return { user_result, biblio_results, network_result };
}
