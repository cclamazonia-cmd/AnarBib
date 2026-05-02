import type { EmailDetails, NotifyPayload } from "../core/types.ts";
import { LIBRARIAN_PHONE } from "../core/env.ts";
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { reservationAdminCopyEnabled, reservationCreatedEnabled, reservationStatusEnabled, reservationWorkflowEnabled } from "../context/policies.ts";
import { getReservaV2Bundle, getReservaWorkflowBundle } from "../data/reservas.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { adminDisplayName, esc, firstNameOnly, formatDateBR, formatDateTimeInZone, fullName, isValidEmail, joinTitles, DEFAULT_NOTIFICATION_TIMEZONE } from "../shared/format.ts";
import { normalizeReservaPickupReplyEvent, normalizeReservaStatusChangeEvent, normalizeReservaWorkflowEvent, pickupReplyLabel, workflowStageFromEvent, workflowStageLabel } from "../shared/events.ts";
import { getPayloadValue, normalizeLineNos, normalizeWorkflowItems } from "../shared/payload.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

export async function handleReservaCriadaV2(recordId:number) {
  const {reserva,profile,items}=await getReservaV2Bundle(recordId); const ctx=await resolveLibraryNotificationContext(String(reserva.library_id||"").trim()||null); const bt=subjectTag(ctx); const user=userTargetFromProfile(profile); const aun=adminDisplayName(fullName(profile),user?.email);
  const locale=String(profile?.preferred_language||"").trim()||null;
  const fmtD=(d:string)=>formatDateLocale(d,locale)||formatDateBR(d);
  const tits=joinTitles(items.map(i=>String(i.titulo||`[${String(i.bib_ref||"").trim()}]`))); const sids=joinTitles(items.map(i=>String(i.sub_id||"")),", "); const brfs=joinTitles(items.map(i=>String(i.bib_ref||"")),", "); const ca=String(reserva.created_at||"");
  const su=`${tMail(locale,"res.created.sub")} — ${bt}`;
  const {html,text}=renderEmail({preheader:tMail(locale,"res.created.pre"),title:tMail(locale,"res.created.sub"),greeting:greeting(locale,user?.name),introHtml:`<p style="margin:0 0 10px;">${tMail(locale,"res.created.intro")}</p><p style="margin:0 0 10px;">${tMail(locale,"res.created.hint")}</p>${LIBRARIAN_PHONE?`<p style="margin:0;">${label(locale,"contact")}: <b>${esc(LIBRARIAN_PHONE)}</b>.</p>`:""}`  ,details:[...(tits?[{label:label(locale,"items"),value:tits}]:[]),...(brfs?[{label:label(locale,"refs"),value:brfs}]:[]),...(sids?[{label:label(locale,"ids"),value:sids}]:[]),...(ca?[{label:label(locale,"date"),value:fmtD(ca)}]:[])],footerHtml:footerPadrao(ctx),context:ctx});
  const ur=reservationCreatedEnabled(ctx)?await safeSendEmail(user,applyBrandingText(su,ctx),html,text,"user_mail",ctx):skippedEmailResult("user_mail","reservation_created_disabled");
  // Admin mail — always PT-BR
  const {html:ha,text:ta}=renderEmail({preheader:tMail(null,"res.created.admin"),title:tMail(null,"res.created.admin"),introHtml:applyBrandingText(`<p>${tMail(null,"res.created.admin")}.</p>`,ctx),details:[{label:label(null,"reader"),value:aun},...(tits?[{label:label(null,"items"),value:tits}]:[]),...(brfs?[{label:label(null,"refs"),value:brfs}]:[]),...(ca?[{label:label(null,"date"),value:formatDateBR(ca)}]:[])],footerHtml:footerPadrao(ctx),context:ctx});
  const ar=reservationCreatedEnabled(ctx)&&reservationAdminCopyEnabled(ctx)?await safeSendEmail(adminTarget(ctx),applyBrandingText(`${tMail(null,"res.created.admin")} — ${aun} — ${bt}`,ctx),ha,ta,"admin_copy",ctx):skippedEmailResult("admin_copy",reservationCreatedEnabled(ctx)?"reservation_admin_copy_disabled":"reservation_created_disabled");
  return {user_result:ur,admin_result:ar};
}

export async function handleReservaV2StatusChange(recordId:number,event:string) {
  const se=normalizeReservaStatusChangeEvent(event)||event; const {reserva,profile,items}=await getReservaV2Bundle(recordId); const ctx=await resolveLibraryNotificationContext(String(reserva.library_id||"").trim()||null); const bt=subjectTag(ctx); const user=userTargetFromProfile(profile); const aun=adminDisplayName(fullName(profile),user?.email);
  const locale=String(profile?.preferred_language||"").trim()||null;
  const tits=joinTitles(items.map(i=>String(i.titulo||`[${String(i.bib_ref||"").trim()}]`))); const motivo=String(reserva.notes||"").trim();
  let sub=`${tMail(locale,"admin.resUpdate")} — BLMF`,tit=tMail(locale,"admin.resUpdate"),intro=`<p>${tMail(locale,"admin.resUpdate")}</p>`;
  if (se==="reserva_v2_recusada") { sub=`BLMF | ${tMail(locale,"res.refused")}`; tit=tMail(locale,"res.refused"); intro=`<p>${tMail(locale,"res.refused")}.</p>${motivo?`<p>${label(locale,"reason")}: <b>${esc(motivo)}</b>.</p>`:""}`; }
  else if (se==="reserva_cancelada_biblioteca") { sub=`BLMF | ${tMail(locale,"res.cancelStaff")}`; tit=tMail(locale,"res.cancelStaff"); intro=`<p>${tMail(locale,"res.cancelStaff")}.</p>${motivo?`<p>${label(locale,"reason")}: <b>${esc(motivo)}</b>.</p>`:""}`; }
  else if (se==="reserva_cancelada_leitor") { sub=`BLMF | ${tMail(locale,"res.cancelReader")}`; tit=tMail(locale,"res.cancelReader"); intro=`<p>${tMail(locale,"res.cancelReader")}.</p>`; }
  else if (se==="reserva_expirada") { sub=`BLMF | ${tMail(locale,"res.expired")}`; tit=tMail(locale,"res.expired"); intro=`<p>${tMail(locale,"res.expired")}.</p>`; }
  else if (se==="reserva_convertida_em_emprestimo") { sub=`BLMF | ${tMail(locale,"res.converted")}`; tit=tMail(locale,"res.converted"); intro=`<p>${tMail(locale,"res.converted")}.</p>`; }
  const det:EmailDetails=[...(tits?[{label:label(locale,"items"),value:tits}]:[])]; const {html,text}=renderEmail({preheader:tit,title:tit,greeting:greeting(locale,user?.name),introHtml:intro,details:det,footerHtml:footerPadrao(ctx),context:ctx}); sub=applyBrandingText(sub.replace(/BLMF/g,bt),ctx);
  const ur=reservationStatusEnabled(ctx)?await safeSendEmail(user,sub,html,text,"user_mail",ctx):skippedEmailResult("user_mail","reservation_status_disabled");
  // Admin — PT-BR
  const {html:ha,text:ta}=renderEmail({preheader:tit,title:tit,introHtml:`<p>${tMail(null,"admin.resUpdate")}</p>`,details:[{label:label(null,"reader"),value:aun},...det],footerHtml:footerPadrao(ctx),context:ctx}); const ar=reservationStatusEnabled(ctx)&&reservationAdminCopyEnabled(ctx)?await safeSendEmail(adminTarget(ctx),applyBrandingText(`[BLMF] ${tit} — ${aun}`,ctx),ha,ta,"admin_copy",ctx):skippedEmailResult("admin_copy","reservation_admin_copy_disabled");
  return {user_result:ur,admin_result:ar};
}

export async function handleReservaV2WorkflowEvent(recordId:number,event:string,payload?:NotifyPayload|null) {
  const we=normalizeReservaWorkflowEvent(event)||event; if (we==="retirada_a_combinar") return {user_result:{ok:true,skipped:true,reason:"workflow_marker_only"},admin_result:{ok:true,skipped:true,reason:"workflow_marker_only"}};
  const pln=normalizeLineNos(getPayloadValue(payload,"line_nos")); const pi=normalizeWorkflowItems(getPayloadValue(payload,"items"));
  const {reserva,profile,items:db}=await getReservaWorkflowBundle(recordId,pln.length?pln:undefined); const ctx=await resolveLibraryNotificationContext(String(reserva.library_id||"").trim()||null); const bt=subjectTag(ctx);
  const locale=String(profile?.preferred_language||"").trim()||null;
  const items=db.length?db:pi; const pe=String(getPayloadValue(payload,"user_email")||"").trim(); const pn=String(getPayloadValue(payload,"user_name")||"").trim();
  const user=userTargetFromProfile(profile)||(isValidEmail(pe)?{email:pe,name:firstNameOnly(pn)||undefined}:null); const aun=adminDisplayName(fullName(profile)||pn,user?.email);
  const tits=joinTitles(items.map(i=>String(i.titulo||`[linha ${i.line_no||"?"}]`))); const sl=workflowStageLabel(workflowStageFromEvent(event));
  const note=String(getPayloadValue(payload,"workflow_note")||items.find(i=>i.workflow_note)?.workflow_note||"").trim();
  const psf=String(getPayloadValue(payload,"pickup_scheduled_for")||items.find(i=>i.pickup_scheduled_for)?.pickup_scheduled_for||"").trim();
  const tz=String(getPayloadValue(payload,"timezone")||DEFAULT_NOTIFICATION_TIMEZONE).trim()||DEFAULT_NOTIFICATION_TIMEZONE; const when=psf?formatDateTimeInZone(psf,tz):"";
  let sub=`${tMail(locale,"admin.resUpdate")} — BLMF`,tit=tMail(locale,"admin.resUpdate"),intro=`<p>${tMail(locale,"admin.resUpdate")}.</p>`;
  if (we==="retirada_agendada") { sub=`BLMF | ${tMail(locale,"wf.pickupScheduled")}`; tit=tMail(locale,"wf.pickupScheduled"); intro=`<p>${tMail(locale,"wf.pickupScheduled")}.</p>${when?`<p>${label(locale,"pickup")}: <b>${esc(when)}</b>.</p>`:""}<p>${tMail(locale,"wf.checkAccount")}</p>`; }
  else if (we==="retirada_reagendada") { sub=`BLMF | ${tMail(locale,"wf.pickupRescheduled")}`; tit=tMail(locale,"wf.pickupRescheduled"); intro=`<p>${tMail(locale,"wf.pickupRescheduled")}: <b>${when||"—"}</b>.</p>`; }
  else if (we==="pronta_para_retirada") { sub=`BLMF | ${tMail(locale,"wf.readyShort")}`; tit=tMail(locale,"wf.ready"); intro=`<p>${tMail(locale,"wf.ready")}.</p>${LIBRARIAN_PHONE?`<p>${label(locale,"contact")}: <b>${esc(LIBRARIAN_PHONE)}</b>.</p>`:""}`; }
  else if (we==="retirada_no_show") { sub=`BLMF | ${tMail(locale,"wf.noShow")}`; tit=tMail(locale,"wf.noShow"); intro=`<p>${tMail(locale,"wf.noShow")}.</p>${when?`<p>${label(locale,"pickup")}: <b>${esc(when)}</b>.</p>`:""}`; }
  else if (we==="liberada_para_circulacao") { sub=`BLMF | ${tMail(locale,"wf.closed")}`; tit=tMail(locale,"wf.closed"); intro=`<p>${tMail(locale,"wf.closed")}.</p>`; }
  const prs=String(items.find(i=>i.pickup_reply_status)?.pickup_reply_status||"").trim(); const prn=String(items.find(i=>i.pickup_reply_note)?.pickup_reply_note||"").trim(); const prl=pickupReplyLabel(prs);
  const det:EmailDetails=[...(tits?[{label:label(locale,"items"),value:tits}]:[]),...(sl?[{label:label(locale,"status"),value:sl}]:[]),...(when?[{label:label(locale,"pickup"),value:`${when} (local)`}]:[]),...(prl?[{label:label(locale,"reply"),value:prl}]:[]),...(prn?[{label:label(locale,"readerNote"),value:prn}]:[]),...(note?[{label:label(locale,"note"),value:note}]:[])]; 
  const {html,text}=renderEmail({preheader:tit,title:tit,greeting:greeting(locale,user?.name),introHtml:intro,details:det,footerHtml:footerPadrao(ctx),context:ctx}); sub=applyBrandingText(sub.replace(/BLMF/g,bt),ctx);
  const ur=reservationWorkflowEnabled(ctx)?await safeSendEmail(user,sub,html,text,"user_mail",ctx):skippedEmailResult("user_mail","reservation_workflow_disabled");
  // Admin — PT-BR
  const {html:ha,text:ta}=renderEmail({preheader:tit,title:tit,introHtml:`<p>${tMail(null,"admin.resUpdate")}</p>`,details:[{label:label(null,"reader"),value:aun},...det],footerHtml:footerPadrao(ctx),context:ctx});
  const ar=reservationWorkflowEnabled(ctx)&&reservationAdminCopyEnabled(ctx)?await safeSendEmail(adminTarget(ctx),applyBrandingText(`[BLMF] ${tit} — ${aun}`,ctx),ha,ta,"admin_copy",ctx):skippedEmailResult("admin_copy",reservationWorkflowEnabled(ctx)?"reservation_admin_copy_disabled":"reservation_workflow_disabled");
  return {user_result:ur,admin_result:ar};
}

export async function handleReservaPickupReplyEvent(recordId:number,event:string,payload?:NotifyPayload|null) {
  const re=normalizeReservaPickupReplyEvent(event)||event; const pln=normalizeLineNos(getPayloadValue(payload,"line_nos"));
  const {reserva,profile,items}=await getReservaWorkflowBundle(recordId,pln.length?pln:undefined); const ctx=await resolveLibraryNotificationContext(String(reserva.library_id||"").trim()||null); const bt=subjectTag(ctx);
  const user=userTargetFromProfile(profile); const aun=adminDisplayName(fullName(profile),user?.email);
  // Pickup reply is admin-only, always PT-BR
  const tits=joinTitles(items.map(i=>String(i.titulo||`[linha ${i.line_no||"?"}]`))); const psf=String(items.find(i=>i.pickup_scheduled_for)?.pickup_scheduled_for||"").trim(); const when=psf?formatDateTimeInZone(psf,DEFAULT_NOTIFICATION_TIMEZONE):"";
  const rs=String(items.find(i=>i.pickup_reply_status)?.pickup_reply_status||"").trim(); const rl=pickupReplyLabel(rs); const rn=String(items.find(i=>i.pickup_reply_note)?.pickup_reply_note||"").trim();
  let tit=tMail(null,"pr.readerReply"),sub=`[BLMF] ${tMail(null,"pr.readerReply")} — ${aun}`,intro=`<p>${tMail(null,"pr.readerReply")}.</p>`;
  if (re==="retirada_confirmada_leitor") { tit=tMail(null,"pr.confirmed"); sub=`[BLMF] ${tMail(null,"pr.confirmed")} — ${aun}`; intro=`<p>${tMail(null,"pr.confirmed")}.</p>`; }
  else if (re==="retirada_recusada_leitor") { tit=tMail(null,"pr.declined"); sub=`[BLMF] ${tMail(null,"pr.declined")} — ${aun}`; intro=`<p>${tMail(null,"pr.declined")}.</p>`; }
  const {html:ha,text:ta}=renderEmail({preheader:tit,title:tit,introHtml:intro,details:[{label:label(null,"reader"),value:aun},...(tits?[{label:label(null,"items"),value:tits}]:[]),...(when?[{label:label(null,"pickup"),value:`${when} (local)`}]:[]),...(rl?[{label:label(null,"reply"),value:rl}]:[]),...(rn?[{label:label(null,"note"),value:rn}]:[])],footerHtml:footerPadrao(ctx),context:ctx}); sub=applyBrandingText(sub.replace(/BLMF/g,bt),ctx);
  const ar=reservationWorkflowEnabled(ctx)&&reservationAdminCopyEnabled(ctx)?await safeSendEmail(adminTarget(ctx),sub,ha,ta,"admin_copy",ctx):skippedEmailResult("admin_copy",reservationWorkflowEnabled(ctx)?"reservation_admin_copy_disabled":"reservation_workflow_disabled");
  return {user_result:{ok:true,skipped:true,reason:"admin_only"},admin_result:ar};
}
