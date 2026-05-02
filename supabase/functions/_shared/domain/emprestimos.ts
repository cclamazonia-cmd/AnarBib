import type { EmailDetails, EmailSendResult, EmailTarget, NotifyPayload } from "../core/types.ts";
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { loanAdminCopyEnabled, loanLifecycleEnabled, reminderFamilyEnabled } from "../context/policies.ts";
import { getEmprestimoDevolucaoBundle, getEmprestimoV2Bundle, getEmprestimoV2Notificavel } from "../data/emprestimos.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, sendAdminNotification, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { DEFAULT_NOTIFICATION_TIMEZONE, adminDisplayName, esc, firstNameOnly, formatDateBR, formatDateTimeInZone, fullName, fullNameFromParts, joinTitles } from "../shared/format.ts";
import { actionKindFromPayload, actorRoleFromPayload } from "../shared/events.ts";
import { getPayloadValue, normalizeLineNos } from "../shared/payload.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

export async function handleEmprestimoV2(recordId:number,event:string) {
  const {emprestimo,profile,items}=await getEmprestimoV2Bundle(recordId);
  const ctx=await resolveLibraryNotificationContext(String(emprestimo.library_id||"").trim()||null);
  const bt=subjectTag(ctx); const user=userTargetFromProfile(profile); const aun=adminDisplayName(fullName(profile),user?.email);
  const locale=String(profile?.preferred_language||"").trim()||null;
  const fmtD=(d:string)=>formatDateLocale(d,locale)||formatDateBR(d);
  const oi=items.filter(i=>String(i.item_status||"")==="aberto"); const ri=items.filter(i=>String(i.item_status||"")==="devolvido");
  const da=String(emprestimo.due_at||""); const ca=String(emprestimo.created_at||""); const ea=String(emprestimo.extended_at||"");
  let sub="",tit="",intro=""; let det:EmailDetails=[];
  if (event==="emprestimo_v2_criado") { const t=joinTitles(oi.map(i=>String(i.titulo||`[${String(i.bib_ref||"").trim()}]`))); sub=`${tMail(locale,"loan.created.sub")} — BLMF`; tit=tMail(locale,"loan.created.sub"); intro=`<p style="margin:0 0 10px;">${tMail(locale,"loan.created.intro")}</p>${da?`<p style="margin:0 0 10px;">${tMail(locale,"loan.dueIn",{date:esc(fmtD(da))})}</p>`:""}<p style="margin:0;">${tMail(locale,"layout.keepMsg")}</p>`; det=[...(t?[{label:label(locale,"items"),value:t}]:[]),...(ca?[{label:label(locale,"registration"),value:fmtD(ca)}]:[]),...(da?[{label:label(locale,"dueDate"),value:fmtD(da)}]:[])]; }
  else if (event==="emprestimo_v2_prorrogado") { const t=joinTitles((oi.length?oi:items).map(i=>String(i.titulo||`[${String(i.bib_ref||"").trim()}]`))); sub=`${tMail(locale,"loan.renewed.sub")} — BLMF`; tit=tMail(locale,"loan.renewed.sub"); intro=`<p style="margin:0 0 10px;">${tMail(locale,"loan.renewed.intro")}</p>${da?`<p style="margin:0 0 10px;">${tMail(locale,"loan.newDue",{date:esc(fmtD(da))})}</p>`:""}<p style="margin:0;">${tMail(locale,"loan.renewed.once")}</p>`; det=[...(t?[{label:label(locale,"items"),value:t}]:[]),...(da?[{label:label(locale,"newDueDate"),value:fmtD(da)}]:[]),...(ea?[{label:label(locale,"renewal"),value:fmtD(ea)}]:[])]; }
  else if (event==="emprestimo_v2_devolvido") { const t=joinTitles((ri.length?ri:items).map(i=>String(i.titulo||`[${String(i.bib_ref||"").trim()}]`))); const ra=ri.find(i=>i.returned_at)?.returned_at; sub=`${tMail(locale,"loan.returned.sub")} — BLMF`; tit=tMail(locale,"loan.returned.sub"); intro=`<p style="margin:0 0 10px;">${tMail(locale,"loan.returned.intro")}</p><p style="margin:0;">${tMail(locale,"loan.returned.browse")}</p>`; det=[...(t?[{label:label(locale,"items"),value:t}]:[]),...(ra?[{label:label(locale,"return"),value:fmtD(String(ra))}]:[])]; }
  else throw new Error(`Evento não suportado: ${event}`);
  const {html,text}=renderEmail({preheader:tit,title:tit,greeting:greeting(locale,user?.name),introHtml:intro,details:det,footerHtml:footerPadrao(ctx),context:ctx});
  sub=applyBrandingText(sub.replace(/BLMF/g,bt),ctx);
  const ur=loanLifecycleEnabled(ctx)?await safeSendEmail(user,sub,html,text,"user_mail",ctx):skippedEmailResult("user_mail","loan_lifecycle_disabled");
  // Admin mail — always PT-BR (locale=null)
  let ai=`<p>${tMail(null,"admin.loanUpdate")}</p>`,as2=`[BLMF] ${tit} — ${aun}`;
  if (event==="emprestimo_v2_criado") { ai=`<p>${tMail(null,"admin.newLoan")}</p>`; as2=`[BLMF] ${tMail(null,"loan.created.sub")} — ${aun}`; }
  else if (event==="emprestimo_v2_prorrogado") { ai=`<p>${tMail(null,"admin.renewalDone")}</p>`; as2=`[BLMF] ${tMail(null,"loan.renewed.sub")} — ${aun}`; }
  else if (event==="emprestimo_v2_devolvido") { ai=`<p>${tMail(null,"admin.returnDone")}</p>`; as2=`[BLMF] ${tMail(null,"loan.returned.sub")} — ${aun}`; }
  const adminDet:EmailDetails=[{label:label(null,"reader"),value:aun},...det.map(d=>({label:tMail(null,`l.${Object.entries({"items":"items","registration":"registration","dueDate":"dueDate","newDueDate":"newDueDate","renewal":"renewal","return":"return"}).find(([_,v])=>label(locale,v)===d.label)?.[0]||""}`)||d.label,value:d.value}))];
  const {html:ha,text:ta}=renderEmail({preheader:tit,title:tit,introHtml:ai,details:[{label:label(null,"reader"),value:aun},...det],footerHtml:footerPadrao(ctx),context:ctx}); as2=applyBrandingText(as2.replace(/BLMF/g,bt),ctx);
  const ar=loanLifecycleEnabled(ctx)&&loanAdminCopyEnabled(ctx)?await safeSendEmail(adminTarget(ctx),as2,ha,ta,"admin_copy",ctx):skippedEmailResult("admin_copy",loanLifecycleEnabled(ctx)?"loan_admin_copy_disabled":"loan_lifecycle_disabled");
  return {user_result:ur,admin_result:ar};
}

export async function handleEmprestimoDevolucaoEvent(recordId:number,event:string,payload?:NotifyPayload|null) {
  const pln=normalizeLineNos(getPayloadValue(payload,"line_nos")); const rows=await getEmprestimoDevolucaoBundle(recordId,pln.length?pln:undefined);
  const f=rows[0]||{}; const ctx=await resolveLibraryNotificationContext(String(f.library_id||"").trim()||null); const bt=subjectTag(ctx);
  const user:EmailTarget={email:String(f.user_email||"").trim(),name:firstNameOnly(f.first_name)||undefined}; const aun=adminDisplayName(fullNameFromParts(f.first_name,f.last_name),user.email);
  const locale=String(f.preferred_language||"").trim()||null;
  const fmtD=(d:string)=>formatDateLocale(d,locale)||formatDateBR(d);
  const tits=joinTitles(rows.map(r=>String(r.titulo||`[${String(r.bib_ref||"").trim()}]`))); const when=formatDateTimeInZone(String(f.return_scheduled_for||"").trim()||null,DEFAULT_NOTIFICATION_TIMEZONE); const da=fmtD(String(f.due_at||"").trim()||"");
  let sub=`${tMail(locale,"loan.returnScheduled")} — ${bt}`,tit=tMail(locale,"loan.returnScheduled"),intro=`<p>${tMail(locale,"loan.returnScheduled")}.</p>`;
  if (event==="emprestimo_devolucao_agendada") { sub=`${tMail(locale,"loan.returnScheduled")} — ${bt}`; tit=tMail(locale,"loan.returnScheduled"); intro=`<p>${tMail(locale,"loan.returnScheduled")}.</p>${when?`<p>${label(locale,"pickup")}: <b>${esc(when)}</b>.</p>`:""}`; }
  else if (event==="emprestimo_devolucao_cancelada") { sub=`${tMail(locale,"loan.returnCancelled")} — ${bt}`; tit=tMail(locale,"loan.returnCancelled"); intro=`<p>${tMail(locale,"loan.returnCancelled")}.</p>`; }
  else if (event==="emprestimo_devolucao_nao_realizada") { sub=`${tMail(locale,"loan.returnMissed")} — ${bt}`; tit=tMail(locale,"loan.returnMissed"); intro=`<p>${tMail(locale,"loan.returnMissed")}.</p>`; }
  const det:EmailDetails=[...(tits?[{label:label(locale,"items"),value:tits}]:[]),...(when&&event!=="emprestimo_devolucao_cancelada"?[{label:label(locale,"dueDate"),value:when}]:[]),...(da?[{label:label(locale,"deadline"),value:da}]:[])];
  const {html,text}=renderEmail({preheader:tit,title:tit,greeting:greeting(locale,user.name),introHtml:intro,details:det,footerHtml:footerPadrao(ctx),context:ctx});
  sub=applyBrandingText(sub,ctx);
  const ur=loanLifecycleEnabled(ctx)?await safeSendEmail(user,sub,html,text,"user_mail",ctx):skippedEmailResult("user_mail","loan_lifecycle_disabled");
  const {html:ha,text:ta}=renderEmail({preheader:tit,title:tit,introHtml:`<p>${tMail(null,"admin.returnUpdate")}</p>`,details:[{label:label(null,"reader"),value:aun},...det],footerHtml:footerPadrao(ctx),context:ctx});
  const ar=loanLifecycleEnabled(ctx)&&loanAdminCopyEnabled(ctx)?await safeSendEmail(adminTarget(ctx),`[${bt}] ${tit} — ${aun}`,ha,ta,"admin_copy",ctx):skippedEmailResult("admin_copy","loan_admin_copy_disabled");
  return {user_result:ur,admin_result:ar};
}

export async function handleEmprestimoV2Reminder(recordId:number,event:string) {
  const e=await getEmprestimoV2Notificavel(recordId); const ctx=await resolveLibraryNotificationContext(String(e.library_id||e.default_library_id||"").trim()||null); const bt=subjectTag(ctx);
  const ufn=String(e.user_nome||"").trim(); const user:EmailTarget={email:String(e.user_email||"").trim(),name:firstNameOnly(ufn)||undefined}; const aun=adminDisplayName(ufn,user.email);
  // Note: v_emprestimos_v2_notificaveis may not have preferred_language — fallback to null (PT-BR)
  const locale=String(e.preferred_language||"").trim()||null;
  const fmtD=(d:string)=>formatDateLocale(d,locale)||formatDateBR(d);
  const tits=String(e.titulos||"").trim(); const da=String(e.due_at||""); const dpv=Number(e.dias_para_vencer||0); const dat=Number(e.dias_atraso||0);
  let sub="",tit="",intro="";
  if (event.includes("5d")) { sub=`${tMail(locale,"rem.5d")} — BLMF`; tit=tMail(locale,"rem.title"); intro=`<p>${tMail(locale,"rem.5d.body")}${da?` (${esc(fmtD(da))})`:""}.`; }
  else if (event.includes("3d")) { sub=`${tMail(locale,"rem.3d")} — BLMF`; tit=tMail(locale,"rem.title"); intro=`<p>${tMail(locale,"rem.3d.body")}</p>`; }
  else if (event.includes("hoje")) { sub=`${tMail(locale,"rem.today")} — BLMF`; tit=tMail(locale,"rem.title"); intro=`<p>${tMail(locale,"rem.today.body")}${da?` (${esc(fmtD(da))})`:""}.`; }
  else if (event.includes("1d")) { sub=`${tMail(locale,"ov.1d")} — BLMF`; tit=tMail(locale,"ov.title"); intro=`<p>${tMail(locale,"ov.1d.body",{date:da?esc(fmtD(da)):""})}`; }
  else if (event.includes("7d")) { sub=`${tMail(locale,"ov.7d")} — BLMF`; tit=tMail(locale,"ov.title"); intro=`<p>${tMail(locale,"ov.7d.body",{days:String(dat||7)})}</p>`; }
  else if (event.includes("30d")) { sub=`${tMail(locale,"ov.30d")} — BLMF`; tit=tMail(locale,"ov.title"); intro=`<p>${tMail(locale,"ov.30d.body",{days:String(dat||30)})}</p>`; }
  const {html,text}=renderEmail({preheader:tit,title:tit,greeting:greeting(locale,user.name),introHtml:intro,details:[...(tits?[{label:label(locale,"items"),value:tits}]:[]),...(da?[{label:label(locale,"dueDate"),value:fmtD(da)}]:[])],footerHtml:footerPadrao(ctx),context:ctx});
  sub=applyBrandingText(sub.replace(/BLMF/g,bt),ctx);
  const ur=reminderFamilyEnabled(ctx,event)?await safeSendEmail(user,sub,html,text,"user_mail",ctx):skippedEmailResult("user_mail","loan_reminder_disabled");
  let ar:EmailSendResult|null=null;
  if (event.includes("30d")) { ar=loanAdminCopyEnabled(ctx)&&reminderFamilyEnabled(ctx,event)?await sendAdminNotification({context:ctx,subject:applyBrandingText(`[BLMF] ${tMail(null,"ov.30d.admin")} — ${aun}`,ctx),title:tMail(null,"ov.30d.admin"),introHtml:`<p>${tMail(null,"ov.30d.body",{days:String(dat||30)})}</p>`,details:[{label:label(null,"reader"),value:aun},...(tits?[{label:label(null,"items"),value:tits}]:[]),...(da?[{label:label(null,"dueDate"),value:formatDateBR(da)}]:[])]}):skippedEmailResult("admin_copy","loan_reminder_disabled"); }
  return {user_result:ur,admin_result:ar};
}
