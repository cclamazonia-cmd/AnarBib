import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { profileRestrictionEnabled } from "../context/policies.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { adminDisplayName, esc, formatDateBR, fullName, joinTitles } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";
export async function handleProfileNotice(recordId) {
  const { data: notice, error: e1 } = await supabaseAdmin.from("profile_notice_queue").select("id,user_id,kind,reason,created_at").eq("id", recordId).maybeSingle();
  if (e1) throw e1;
  if (!notice) throw new Error("Aviso não encontrado.");
  const { data: profile, error: e2 } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,phone,address,default_library_id,is_restricted,restricted_since,restricted_reason,preferred_language").eq("id", notice.user_id).maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");
  const { data: emps, error: e3 } = await supabaseAdmin.from("v_emprestimos_v2_notificaveis").select("*").eq("user_id", notice.user_id).order("due_at", {
    ascending: true
  });
  if (e3) throw e3;
  const ctx = await resolveLibraryNotificationContext(String((emps || [])[0]?.library_id || profile.default_library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);
  const locale = String(profile?.preferred_language || "").trim() || null;
  const libLocale = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const fmtD = (d)=>formatDateLocale(d, locale) || formatDateBR(d);
  const kind = String(notice.kind || "");
  const reason = String(notice.reason || profile.restricted_reason || "").trim();
  const rSince = String(profile.restricted_since || "");
  const tits = joinTitles((emps || []).map((e)=>String(e.titulos || "")));
  const nDue = String((emps || [])[0]?.due_at || "");
  let sub = `${tMail(locale, "admin.profileNotice")} — BLMF`, tit = tMail(locale, "admin.profileNotice"), intro = `<p>${tMail(locale, "admin.profileNotice")}.</p>`;
  if (kind === "cadastro_restrito") {
    sub = `${tMail(locale, "prof.restricted")} — BLMF`;
    tit = tMail(locale, "prof.restricted");
    intro = `<p>${tMail(locale, "prof.restricted.intro")}</p><p>${tMail(locale, "prof.contactLibrary")}</p>`;
  } else if (kind === "aviso_formal_restricao") {
    sub = `${tMail(locale, "prof.formalNotice")} — BLMF`;
    tit = tMail(locale, "prof.formalNotice");
    intro = `<p>${tMail(locale, "prof.formalNotice.intro")}</p>`;
  }
  const det = [
    ...reason ? [
      {
        label: label(locale, "reason"),
        value: reason
      }
    ] : [],
    ...rSince ? [
      {
        label: label(locale, "restrictedSince"),
        value: fmtD(rSince)
      }
    ] : [],
    ...tits ? [
      {
        label: label(locale, "pendingItems"),
        value: tits
      }
    ] : [],
    ...nDue ? [
      {
        label: label(locale, "firstDate"),
        value: fmtD(nDue)
      }
    ] : []
  ];
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: intro,
    details: det,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  sub = applyBrandingText(sub.replace(/BLMF/g, bt), ctx);
  const ur = profileRestrictionEnabled(ctx) ? await safeSendEmail(user, sub, html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "profile_notice_disabled");
  // Admin — locale biblio (doctrine 2C, 18/05/2026)
  const { html: ha, text: ta } = renderEmail({
    locale: libLocale,
    preheader: tit,
    title: tit,
    introHtml: `<p>${tMail(libLocale, "admin.profileNotice")}: <b>${esc(kind)}</b>.</p>`,
    details: [
      {
        label: label(libLocale, "reader"),
        value: aun
      },
      ...det
    ],
    footerHtml: footerPadrao(ctx, libLocale),
    context: ctx
  });
  const ar = profileRestrictionEnabled(ctx) ? await safeSendEmail(adminTarget(ctx), applyBrandingText(`[BLMF] ${tit} — ${aun}`, ctx), ha, ta, "admin_copy", ctx) : skippedEmailResult("admin_copy", "profile_notice_disabled");
  return {
    user_result: ur,
    admin_result: ar
  };
}
