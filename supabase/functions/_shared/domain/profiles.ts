import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { profileRestrictionEnabled } from "../context/policies.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { adminDisplayName, esc, formatDateBR, fullName, joinTitles } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

export async function handleProfileNotice(recordId:number) {
  const {data:notice,error:e1}=await supabaseAdmin.from("profile_notice_queue").select("id,user_id,kind,reason,created_at").eq("id",recordId).maybeSingle(); if (e1) throw e1; if (!notice) throw new Error("Aviso não encontrado.");
  const {data:profile,error:e2}=await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,phone,address,default_library_id,is_restricted,restricted_since,restricted_reason,preferred_language").eq("id",notice.user_id).maybeSingle(); if (e2) throw e2; if (!profile) throw new Error("Perfil não encontrado.");
  const {data:emps,error:e3}=await supabaseAdmin.from("v_emprestimos_v2_notificaveis").select("*").eq("user_id",notice.user_id).order("due_at",{ascending:true}); if (e3) throw e3;
  const ctx=await resolveLibraryNotificationContext(String((emps||[])[0]?.library_id||profile.default_library_id||"").trim()||null); const bt=subjectTag(ctx); const user=userTargetFromProfile(profile as Record<string,unknown>); const aun=adminDisplayName(fullName(profile as Record<string,unknown>),user?.email);
  const locale=String((profile as Record<string,unknown>)?.preferred_language||"").trim()||null;
  const fmtD=(d:string)=>formatDateLocale(d,locale)||formatDateBR(d);
  const kind=String((notice as Record<string,unknown>).kind||""); const reason=String((notice as Record<string,unknown>).reason||(profile as Record<string,unknown>).restricted_reason||"").trim();
  const rSince=String((profile as Record<string,unknown>).restricted_since||""); const tits=joinTitles((emps||[]).map((e:Record<string,unknown>)=>String(e.titulos||""))); const nDue=String(((emps||[])[0] as Record<string,unknown>)?.due_at||"");
  let sub=`${tMail(locale,"admin.profileNotice")} — BLMF`,tit=tMail(locale,"admin.profileNotice"),intro=`<p>${tMail(locale,"admin.profileNotice")}.</p>`;
  if (kind==="cadastro_restrito") { sub=`${tMail(locale,"prof.restricted")} — BLMF`; tit=tMail(locale,"prof.restricted"); intro=`<p>${tMail(locale,"prof.restricted.intro")}</p><p>${tMail(locale,"prof.contactLibrary")}</p>`; }
  else if (kind==="aviso_formal_restricao") { sub=`${tMail(locale,"prof.formalNotice")} — BLMF`; tit=tMail(locale,"prof.formalNotice"); intro=`<p>${tMail(locale,"prof.formalNotice.intro")}</p>`; }
  const det=[...(reason?[{label:label(locale,"reason"),value:reason}]:[]),...(rSince?[{label:label(locale,"restrictedSince"),value:fmtD(rSince)}]:[]),...(tits?[{label:label(locale,"pendingItems"),value:tits}]:[]),...(nDue?[{label:label(locale,"firstDate"),value:fmtD(nDue)}]:[])];
  const {html,text}=renderEmail({preheader:tit,title:tit,greeting:greeting(locale,user?.name),introHtml:intro,details:det,footerHtml:footerPadrao(ctx),context:ctx}); sub=applyBrandingText(sub.replace(/BLMF/g,bt),ctx);
  const ur=profileRestrictionEnabled(ctx)?await safeSendEmail(user,sub,html,text,"user_mail",ctx):skippedEmailResult("user_mail","profile_notice_disabled");
  // Admin — PT-BR
  const {html:ha,text:ta}=renderEmail({preheader:tit,title:tit,introHtml:`<p>${tMail(null,"admin.profileNotice")}: <b>${esc(kind)}</b>.</p>`,details:[{label:label(null,"reader"),value:aun},...det],footerHtml:footerPadrao(ctx),context:ctx});
  const ar=profileRestrictionEnabled(ctx)?await safeSendEmail(adminTarget(ctx),applyBrandingText(`[BLMF] ${tit} — ${aun}`,ctx),ha,ta,"admin_copy",ctx):skippedEmailResult("admin_copy","profile_notice_disabled");
  return {user_result:ur,admin_result:ar};
}
