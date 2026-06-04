// =============================================================================
// _shared/domain/reader-message.ts
// =============================================================================
// Handler notify-event pour l'event reader_message_sent : une personne ecrit a
// sa bibliotheque via le canal in-systeme (carte « ma bibliotheque » cote
// lecteur). Envoie :
//   - un mail au staff (adminTarget, locale biblio) avec le recad,
//   - un accuse de reception au lecteur·rice (locale perso), copie du recad.
// Pas d'actionBox (un recad libre n'a pas de CTA tant qu'il n'y a pas de boite
// in-app). Met a jour mail_status sur reader_library_messages.
//
// Calque structurel : _shared/domain/consultas.ts (handleConsultaCriadaV2).
// =============================================================================

import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import {
  adminTarget,
  safeSendEmail,
  skippedEmailResult,
  userTargetFromProfile
} from "../transport/email.ts";
import { adminDisplayName, esc, fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";
import { getReaderMessageBundle, markReaderMessageMailStatus } from "../data/reader-messages.ts";

// Echappe le corps + convertit les retours ligne en <br> pour l'HTML.
function bodyToHtml(raw: string): string {
  return esc(raw).replace(/\r\n|\r|\n/g, "<br>");
}

export async function handleReaderMessageEvent(recordId: number) {
  const { message, profile } = await getReaderMessageBundle(recordId);
  const ctx = await resolveLibraryNotificationContext(
    String(message.library_id || "").trim() || null
  );
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);

  const locale = String(profile?.preferred_language || "").trim() || null;
  const libLocale = String(ctx.default_locale || "pt-BR").trim() || "pt-BR";

  const subject = String(message.subject || "").trim();
  const body = String(message.body || "").trim();
  const bodyHtml = bodyToHtml(body);
  const createdStaff = formatDateLocale(String(message.created_at || ""), libLocale);

  // ---- Mail staff (destinataire principal : la biblio est avisee) ----
  const staffTitle = tMail(libLocale, "rmsg.staff.sub");
  const staffSubject = `${staffTitle} - ${aun} - ${bt}`;
  const staffIntro =
    `<p style="margin:0 0 10px;">${tMail(libLocale, "rmsg.staff.intro")}</p>` +
    (subject ? `<p style="margin:0 0 6px;"><b>${esc(subject)}</b></p>` : "") +
    `<div style="margin:0;padding:10px 12px;background:rgba(255,255,255,.05);border-left:3px solid rgba(255,255,255,.2);border-radius:4px;line-height:1.55;">${bodyHtml}</div>`;

  const { html: ha, text: ta } = renderEmail({
    locale: libLocale,
    preheader: staffTitle,
    title: staffTitle,
    introHtml: applyBrandingText(staffIntro, ctx),
    details: [
      { label: label(libLocale, "reader"), value: aun },
      ...(createdStaff ? [{ label: label(libLocale, "date"), value: createdStaff }] : [])
    ],
    footerHtml: footerPadrao(ctx, libLocale),
    context: ctx,
    libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion")
  });
  const ar = await safeSendEmail(adminTarget(ctx), applyBrandingText(staffSubject, ctx), ha, ta, "admin_copy", ctx);

  // ---- Accuse de reception lecteur·rice (copie de son recad) ----
  let ur;
  if (user) {
    const readerTitle = tMail(locale, "rmsg.reader.sub");
    const readerSubject = `${readerTitle} - ${bt}`;
    const readerIntro =
      `<p style="margin:0 0 10px;">${tMail(locale, "rmsg.reader.intro")}</p>` +
      (subject ? `<p style="margin:0 0 6px;"><b>${esc(subject)}</b></p>` : "") +
      `<div style="margin:0;padding:10px 12px;background:rgba(255,255,255,.05);border-left:3px solid rgba(255,255,255,.2);border-radius:4px;line-height:1.55;">${bodyHtml}</div>`;

    const { html, text } = renderEmail({
      locale: locale,
      preheader: readerTitle,
      title: readerTitle,
      greeting: greeting(locale, user?.name),
      introHtml: readerIntro,
      footerHtml: footerPadrao(ctx, locale),
      context: ctx,
      libreDiffusionLabel: tMail(locale, "subj.libreDiffusion")
    });
    ur = await safeSendEmail(user, applyBrandingText(readerSubject, ctx), html, text, "user_mail", ctx);
  } else {
    ur = skippedEmailResult("user_mail", "no_reader_recipient");
  }

  // ---- Statut mail : la livraison qui compte est celle au staff ----
  const staffOk = (ar as { ok?: boolean } | null | undefined)?.ok === true;
  await markReaderMessageMailStatus(recordId, staffOk ? "sent" : "failed");

  return { user_result: ur, admin_result: ar };
}