import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { profileRestrictionEnabled } from "../context/policies.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { supabaseAdmin } from "../core/env.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { adminDisplayName, formatDateBR, fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

// ============================================================================
// #NOTIFY-Painel-acts — Famille 2 : restriction locale + gel global (et levées).
// ----------------------------------------------------------------------------
// Events : member_restricted_local / member_unrestricted_local /
//          member_frozen_global / member_unfrozen_global, émis par
//          api.restrict_member / unrestrict_member / freeze_account /
//          unfreeze_account via fn_dispatch_notify_event (record_id factice=1,
//          données en payload : user_id, library_id [local], reason, at).
//
// Doctrine : e-mail au membre OBLIGATOIRE (NOTIF-PA3, B3 impact droits, jamais
// gardé par une politique) ; copie staff OPTIONNELLE gardée par
// profile_restriction_enabled (repurposé en toggle « copie staff »). Contenu :
// motif + portée (biblio locale / réseau) + date. DOC-NOTIF-1 : le membre, pas
// l'acteur. Réutilise les clés i18n prof.* (restriction).
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
    .select("id,email,first_name,last_name,preferred_language,default_library_id")
    .eq("id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!profile) throw new Error("Perfil não encontrado.");

  // Branding/locale : la biblio concernée (local) ou la biblio par défaut (global).
  const ctxLibId = (!isGlobal && libraryId ? libraryId : String(profile.default_library_id || "").trim()) || null;
  const ctx = await resolveLibraryNotificationContext(ctxLibId);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const locale = String(profile?.preferred_language || "").trim() || null;
  const libLocale = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const fmtD = (d) => formatDateLocale(d, locale) || formatDateBR(d) || "";
  const fmtDLib = (d) => formatDateLocale(d, libLocale) || formatDateBR(d) || "";

  // Portée : nom de la biblio (local) ou « réseau » (global).
  const scopeFor = (loc) => isGlobal ? tMail(loc, "restriction.scope.network") : (ctx?.library_name || bt);

  let tit, introHtml;
  if (isLift) {
    tit = tMail(locale, "restriction.lifted.subject");
    introHtml = `<p>${tMail(locale, "restriction.lifted.intro")}</p>`;
  } else if (isGlobal) {
    tit = tMail(locale, "restriction.global.subject");
    introHtml = `<p>${tMail(locale, "restriction.global.intro")}</p><p>${tMail(locale, "prof.contactLibrary")}</p>`;
  } else {
    tit = tMail(locale, "prof.restricted");
    introHtml = `<p>${tMail(locale, "prof.restricted.intro")}</p><p>${tMail(locale, "prof.contactLibrary")}</p>`;
  }

  const detFor = (loc, fmt) => {
    const d = [{ label: label(loc, "scope"), value: scopeFor(loc) }];
    if (!isLift && reason) d.push({ label: label(loc, "reason"), value: reason });
    if (atRaw) d.push({ label: label(loc, "restrictedSince"), value: fmt(atRaw) });
    return d;
  };

  // (1) Mail au membre — OBLIGATOIRE (NOTIF-PA3).
  let user_result = skippedEmailResult("user_mail", "no_recipient_email");
  if (user?.email) {
    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, user?.name),
      introHtml,
      details: detFor(locale, fmtD),
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });
    const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
    user_result = await safeSendEmail(user, sub, html, text, "user_mail", ctx);
  }

  // (2) Copie staff — OPTIONNELLE (profile_restriction_enabled repurposé).
  let admin_result = skippedEmailResult("admin_copy", "staff_copy_disabled");
  if (profileRestrictionEnabled(ctx)) {
    const aun = adminDisplayName(fullName(profile), user?.email);
    const titLib = isLift
      ? tMail(libLocale, "restriction.lifted.subject")
      : (isGlobal ? tMail(libLocale, "restriction.global.subject") : tMail(libLocale, "prof.restricted"));
    const { html: ha, text: ta } = renderEmail({
      locale: libLocale,
      preheader: titLib,
      title: titLib,
      introHtml: `<p>${titLib}.</p>`,
      details: [{ label: label(libLocale, "reader"), value: aun }, ...detFor(libLocale, fmtDLib)],
      footerHtml: footerPadrao(ctx, libLocale),
      context: ctx
    });
    admin_result = await safeSendEmail(adminTarget(ctx), applyBrandingText(`[${bt}] ${titLib} — ${aun}`, ctx), ha, ta, "admin_copy", ctx);
  }

  return { user_result, admin_result };
}
