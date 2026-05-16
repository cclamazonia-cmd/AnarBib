// =============================================================================
// _shared/domain/consultas.ts - Paquet 26 L4 v2.4
// =============================================================================
// Handlers Edge Function notify-event pour les 6 events consulta_v2_* :
//
//   handleConsultaCriadaV2(recordId)
//     -> consulta_v2_criada (INSERT consulta_linhas_v2)
//
//   handleConsultaV2LifecycleEvent(recordId, event, payload)
//     -> consulta_v2_realizada / _cancelada / _expirada (UPDATE item_status)
//
//   handleConsultaV2WorkflowEvent(recordId, event, payload)
//     -> consulta_v2_agendada / _resposta_creneau (UPDATE workflow_stage / schedule_reply_status)
//
// Calque structure : _shared/domain/reservas.ts (handleReservaCriadaV2,
// handleReservaV2StatusChange, handleReservaV2WorkflowEvent).
//
// v2.4 : 2 fixes deno strict :
//   - 3x cast 'ctx as Record<string, unknown> | null | undefined' (lignes 152, 247, 400)
//     remplaces par 'ctx.default_locale' direct (resolveLibraryNotificationContext
//     garantit Promise<LibraryNotificationContext> non-null + default_locale est
//     dans l'interface). Le cast etait redondant et rejete par TS2352.
//   - 3x 'actionBox = condition ? {...} : null' remplaces par ': undefined'
//     (lignes 325, 491, 526). 'renderEmail' accepte ActionBox|undefined, pas null.
// PREREQUIS v2.4 : library-notification-context.ts patche pour 7 defaults
// consulta_mail_*. Voir 00bis_lncontext_patch.ts.
// v2.1 : typage explicite calque sur reservas.ts pour passer deno check strict.
//   - recordId: number (calque handleReservaCriadaV2)
//   - event: string, payload?: NotifyPayload|null (calque handleReservaV2WorkflowEvent)
//   - ctx: LibraryNotificationContext|null|undefined (cohérent policies.ts)
//
// Conventions appliquees (paquet 6) :
//   - Locale lecteur : profile.preferred_language
//   - Locale biblio  : ctx.default_locale (fallback 'pt-BR')
//   - User_result / admin_result via safeSendEmail vs skippedEmailResult
//   - actionBox HTML pour CTA (kind: 'action' | 'info'), via renderEmail
//   - URL CTA : APP_BASE_URL + /conta (lecteur) ou /painel (staff)
// =============================================================================

import type { LibraryNotificationContext, NotifyPayload } from "../core/types.ts";
import { APP_BASE_URL, LIBRARIAN_PHONE } from "../core/env.ts";
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import {
  consultaCriadaEnabled,
  consultaAgendadaEnabled,
  consultaRespostaCreneauEnabled,
  consultaRealizadaEnabled,
  consultaCanceladaEnabled,
  consultaExpiradaEnabled,
  consultaEmPreparacaoEnabled,
  consultaNaoCompareceuEnabled,
  consultaAdminCopyEnabled,
  localConsultationEnabled
} from "../context/policies.ts";
import { getConsultaV2Bundle, getConsultaWorkflowBundle } from "../data/consultas.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import {
  adminTarget,
  safeSendEmail,
  skippedEmailResult,
  userTargetFromProfile
} from "../transport/email.ts";
import {
  adminDisplayName,
  esc,
  firstNameOnly,
  formatDateBR,
  formatDateTimeInZone,
  fullName,
  isValidEmail,
  joinTitles,
  DEFAULT_NOTIFICATION_TIMEZONE
} from "../shared/format.ts";
import {
  consultaCancelledByFromPayload,
  consultaScheduleReplyFromPayload,
  normalizeConsultaLifecycleEvent,
  normalizeConsultaWorkflowEvent
} from "../shared/events.ts";
import { getPayloadValue, normalizeLineNos } from "../shared/payload.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

// =============================================================================
// URLs CTA (calque reserva - hard-coded en attendant un refactor APP_BASE_URL
// global pour tous les handlers de circulation).
// =============================================================================

const READER_PAGE = `${APP_BASE_URL}/conta`;
const STAFF_PAGE = `${APP_BASE_URL}/painel`;

// =============================================================================
// Helpers internes
// =============================================================================

/**
 * Resolve la timezone a utiliser pour formater un creneau. Priorite :
 *   1. ctx.consultation_timezone (parametre par biblio dans library_service_state)
 *   2. ctx.default_timezone (parametre ailleurs)
 *   3. DEFAULT_NOTIFICATION_TIMEZONE
 */
function resolveConsultaTimezone(ctx: LibraryNotificationContext | null | undefined): string {
  const anyCtx = ctx as Record<string, unknown> | null | undefined;
  return String(
    anyCtx?.consultation_timezone
    || anyCtx?.default_timezone
    || DEFAULT_NOTIFICATION_TIMEZONE
  ).trim() || DEFAULT_NOTIFICATION_TIMEZONE;
}

/**
 * Interpolation simple des variables {date} {time_start} {time_end} {tz}
 * dans une chaine i18n. (Pas de moteur Mustache pour rester leger.)
 */
function interpolate(template: string, vars: Record<string, string>): string {
  let s = String(template || "");
  for (const k of Object.keys(vars || {})) {
    s = s.split(`{${k}}`).join(String(vars[k] || ""));
  }
  return s;
}

/**
 * Construit les variables {date} {time_start} {time_end} {tz} a partir
 * d'une fenetre starts_at/ends_at, en formatant dans la timezone biblio.
 */
function buildSlotVars(
  startsAt: string,
  endsAt: string,
  tz: string,
  locale: string | null,
  workflowNote?: string | null
): Record<string, string> {
  const note = String(workflowNote || "").trim();
  if (!startsAt) return { date: "", time_start: "", time_end: "", tz, workflow_note: note };
  const startStr = formatDateTimeInZone(startsAt, tz);
  const endStr = endsAt ? formatDateTimeInZone(endsAt, tz) : "";
  // formatDateTimeInZone renvoie "DD/MM/YYYY HH:MM" depuis paquet 141.3.
  // Extraire les parties date/heure pour une interpolation propre.
  const [startDate, startTime] = startStr.split(" ");
  const endTime = endStr ? endStr.split(" ")[1] || "" : "";
  return {
    date: formatDateLocale(startsAt, locale) || startDate || "",
    time_start: startTime || "",
    time_end: endTime || "",
    tz: tz || "",
    workflow_note: note
  };
}

// =============================================================================
// 1. handleConsultaCriadaV2 - INSERT consulta_linhas_v2 (item_status='ativa')
// =============================================================================

export async function handleConsultaCriadaV2(recordId: number) {
  const { consulta, profile, items } = await getConsultaV2Bundle(recordId);
  const ctx = await resolveLibraryNotificationContext(
    String(consulta.library_id || "").trim() || null
  );
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);

  // Locale lecteur vs locale biblio (paquet 6)
  const locale = String(profile?.preferred_language || "").trim() || null;
  const libLocale = String(ctx.default_locale || "pt-BR").trim() || "pt-BR";

  const fmtD = (d: string | Date | null | undefined) => formatDateLocale(d, locale) || formatDateBR(d);

  // Garde 1 : master switch
  if (!localConsultationEnabled(ctx)) {
    return {
      user_result: skippedEmailResult("user_mail", "local_consultation_disabled"),
      admin_result: skippedEmailResult("admin_copy", "local_consultation_disabled")
    };
  }

  const tits = joinTitles(items.map((i) => String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
  const brfs = joinTitles(items.map((i) => String(i.bib_ref || "")), ", ");
  const sids = joinTitles(items.map((i) => String(i.sub_id || "")), ", ");
  const ca = String(consulta.created_at || "");
  const su = `${tMail(locale, "con.created.sub")} - ${bt}`;

  // ---- Mail lecteur ----
  const { html, text } = renderEmail({
    preheader: tMail(locale, "con.created.pre"),
    title: tMail(locale, "con.created.sub"),
    greeting: greeting(locale, user?.name),
    introHtml:
      `<p style="margin:0 0 10px;">${tMail(locale, "con.created.intro")}</p>` +
      `<p style="margin:0 0 10px;">${tMail(locale, "con.created.hint")}</p>` +
      (LIBRARIAN_PHONE
        ? `<p style="margin:0;">${label(locale, "contact")}: <b>${esc(LIBRARIAN_PHONE)}</b>.</p>`
        : ""),
    details: [
      ...(tits ? [{ label: label(locale, "items"), value: tits }] : []),
      ...(brfs ? [{ label: label(locale, "refs"), value: brfs }] : []),
      ...(sids ? [{ label: label(locale, "ids"), value: sids }] : []),
      ...(ca ? [{ label: label(locale, "date"), value: fmtD(ca) }] : [])
    ],
    footerHtml: footerPadrao(ctx),
    context: ctx,
    libreDiffusionLabel: tMail(locale, "subj.libreDiffusion")
  });

  const ur = consultaCriadaEnabled(ctx)
    ? await safeSendEmail(user, applyBrandingText(su, ctx), html, text, "user_mail", ctx)
    : skippedEmailResult("user_mail", "consulta_criada_disabled");

  // ---- Mail copie admin biblio (locale biblio paquet 6) ----
  const { html: ha, text: ta } = renderEmail({
    preheader: tMail(libLocale, "con.created.admin"),
    title: tMail(libLocale, "con.created.admin"),
    introHtml: applyBrandingText(`<p>${tMail(libLocale, "con.created.admin")}.</p>`, ctx),
    details: [
      { label: label(libLocale, "reader"), value: aun },
      ...(tits ? [{ label: label(libLocale, "items"), value: tits }] : []),
      ...(brfs ? [{ label: label(libLocale, "refs"), value: brfs }] : []),
      ...(ca ? [{ label: label(libLocale, "date"), value: formatDateBR(ca) }] : [])
    ],
    footerHtml: footerPadrao(ctx),
    context: ctx,
    libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion")
  });

  const ar = consultaCriadaEnabled(ctx) && consultaAdminCopyEnabled(ctx)
    ? await safeSendEmail(
        adminTarget(ctx),
        applyBrandingText(`${tMail(libLocale, "con.created.admin")} - ${aun} - ${bt}`, ctx),
        ha, ta, "admin_copy", ctx
      )
    : skippedEmailResult(
        "admin_copy",
        consultaCriadaEnabled(ctx) ? "consulta_admin_copy_disabled" : "consulta_criada_disabled"
      );

  return { user_result: ur, admin_result: ar };
}

// =============================================================================
// 2. handleConsultaV2LifecycleEvent - UPDATE item_status ativa->*
// =============================================================================

export async function handleConsultaV2LifecycleEvent(
  recordId: number,
  event: string,
  payload?: NotifyPayload | null
) {
  const we = normalizeConsultaLifecycleEvent(event) || event;
  const cancelledBy = consultaCancelledByFromPayload(payload);
  // Paquet 141.2 (B3 generalise + complement B6) : extraction workflow_note
  // depuis le payload (la note d'annulation par la biblio doit etre affichee
  // au lecteur, le motif d'annulation par le lecteur doit etre affiche a la
  // biblio, etc.).
  const workflowNote = String(getPayloadValue(payload, "workflow_note") || "").trim();

  const { consulta, profile, items } = await getConsultaV2Bundle(recordId);
  const ctx = await resolveLibraryNotificationContext(
    String(consulta.library_id || "").trim() || null
  );
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);

  const locale = String(profile?.preferred_language || "").trim() || null;
  const libLocale = String(ctx.default_locale || "pt-BR").trim() || "pt-BR";

  // Garde 1 : master switch
  if (!localConsultationEnabled(ctx)) {
    return {
      user_result: skippedEmailResult("user_mail", "local_consultation_disabled"),
      admin_result: skippedEmailResult("admin_copy", "local_consultation_disabled")
    };
  }

  // ---- Resolution des cles + flags + destinataires selon l'event ----
  let readerKey: string | null = null;
  let staffKey: string | null = null;
  let readerMailEnabled = true;
  let staffMailEnabled = true;
  let granularFlag: boolean | null = null;  // booleen flag granulaire a verifier

  if (we === "consulta_v2_realizada") {
    readerKey = null;  // anti-spam : le lecteur sait, il etait sur place
    readerMailEnabled = false;
    staffKey = "con.realized";
    granularFlag = consultaRealizadaEnabled(ctx);  // default false
  } else if (we === "consulta_v2_cancelada") {
    granularFlag = consultaCanceladaEnabled(ctx);
    if (cancelledBy === "leitor") {
      // Le lecteur a annule -> mail a la biblio uniquement
      readerKey = null;
      readerMailEnabled = false;
      staffKey = "con.cancelReader";
    } else if (cancelledBy === "biblioteca") {
      // La biblio a annule -> mail au lecteur uniquement
      readerKey = "con.cancelStaff";
      staffKey = null;
      staffMailEnabled = false;
    } else {
      // Discriminant absent du payload (cas degrade) -> mail aux deux cotes
      // par securite, avec la cle generique "reservation annulee".
      readerKey = "con.cancelStaff";
      staffKey = "con.cancelReader";
    }
  } else if (we === "consulta_v2_expirada") {
    readerKey = "con.expired";
    staffKey = "con.expired";
    granularFlag = consultaExpiradaEnabled(ctx);
  } else {
    // Event inconnu - return sans rien faire (coherent avec dispatch.ts)
    return {
      user_result: skippedEmailResult("user_mail", "unknown_lifecycle_event"),
      admin_result: skippedEmailResult("admin_copy", "unknown_lifecycle_event")
    };
  }

  // Garde 2 : flag granulaire
  if (granularFlag === false) {
    return {
      user_result: skippedEmailResult("user_mail", `consulta_${we}_disabled`),
      admin_result: skippedEmailResult("admin_copy", `consulta_${we}_disabled`)
    };
  }

  const tits = joinTitles(items.map((i) => String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
  const brfs = joinTitles(items.map((i) => String(i.bib_ref || "")), ", ");
  // Paquet 141.2 (B3 generalise + complement B6) : ligne 'Note' a injecter
  // dans les 2 mails (lecteur et staff) si workflowNote presente.
  // Utilise label cle 'note' (sera ajoutee a mail-strings.ts en paquet 141.2.C
  // si pas encore presente). En attendant : fallback texte 'Note'.
  const noteDetailReader = workflowNote ? [{ label: label(locale, "note") || "Note", value: workflowNote }] : [];
  const noteDetailStaff = workflowNote ? [{ label: label(libLocale, "note") || "Note", value: workflowNote }] : [];

  // ---- Mail lecteur ----
  let ur;
  if (readerKey && readerMailEnabled && user) {
    const readerSubject = `${tMail(locale, readerKey)} - ${bt}`;
    const readerIntro = `<p style="margin:0 0 10px;">${tMail(locale, readerKey)}</p>`;

    // CTA si annulation par biblio ou expiration -> renvoyer le lecteur sur /conta
    const actionBox = (we === "consulta_v2_cancelada" && cancelledBy === "biblioteca") ||
                      (we === "consulta_v2_expirada")
      ? {
          kind: "info" as const,
          title: tMail(locale, readerKey),
          ctaUrl: READER_PAGE,
          ctaLabel: tMail(locale, "cwf.actionBox.replySlot")
        }
      : undefined;

    const { html, text } = renderEmail({
      preheader: tMail(locale, readerKey),
      title: tMail(locale, readerKey),
      greeting: greeting(locale, user?.name),
      introHtml: readerIntro,
      actionBox,
      details: [
        ...(tits ? [{ label: label(locale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(locale, "refs"), value: brfs }] : [])
      ],
      footerHtml: footerPadrao(ctx),
      context: ctx,
      libreDiffusionLabel: tMail(locale, "subj.libreDiffusion")
    });
    ur = await safeSendEmail(user, applyBrandingText(readerSubject, ctx), html, text, "user_mail", ctx);
  } else {
    ur = skippedEmailResult("user_mail", readerMailEnabled ? "no_reader_recipient" : "reader_mail_skipped_by_event");
  }

  // ---- Mail staff ----
  let ar;
  if (staffKey && staffMailEnabled && consultaAdminCopyEnabled(ctx)) {
    const staffSubject = `${tMail(libLocale, staffKey)} - ${aun} - ${bt}`;
    const staffIntro = `<p>${tMail(libLocale, staffKey)}.</p>`;

    const { html: ha, text: ta } = renderEmail({
      preheader: tMail(libLocale, staffKey),
      title: tMail(libLocale, staffKey),
      introHtml: applyBrandingText(staffIntro, ctx),
      details: [
        { label: label(libLocale, "reader"), value: aun },
        ...(tits ? [{ label: label(libLocale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(libLocale, "refs"), value: brfs }] : [])
      ],
      footerHtml: footerPadrao(ctx),
      context: ctx,
      libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion")
    });
    ar = await safeSendEmail(adminTarget(ctx), applyBrandingText(staffSubject, ctx), ha, ta, "admin_copy", ctx);
  } else {
    ar = skippedEmailResult(
      "admin_copy",
      !staffMailEnabled ? "staff_mail_skipped_by_event" : "consulta_admin_copy_disabled"
    );
  }

  return { user_result: ur, admin_result: ar };
}

// =============================================================================
// 3. handleConsultaV2WorkflowEvent - UPDATE workflow_stage / schedule_reply_status
// =============================================================================

export async function handleConsultaV2WorkflowEvent(
  recordId: number,
  event: string,
  payload?: NotifyPayload | null
) {
  const we = normalizeConsultaWorkflowEvent(event) || event;
  const lineNos = normalizeLineNos(getPayloadValue(payload, "line_nos"));

  const { consulta, profile, items } = await getConsultaWorkflowBundle(
    recordId,
    lineNos.length ? lineNos : undefined
  );
  const ctx = await resolveLibraryNotificationContext(
    String(consulta.library_id || "").trim() || null
  );
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);

  const locale = String(profile?.preferred_language || "").trim() || null;
  const libLocale = String(ctx.default_locale || "pt-BR").trim() || "pt-BR";
  const tz = resolveConsultaTimezone(ctx);

  // Garde 1 : master switch
  if (!localConsultationEnabled(ctx)) {
    return {
      user_result: skippedEmailResult("user_mail", "local_consultation_disabled"),
      admin_result: skippedEmailResult("admin_copy", "local_consultation_disabled")
    };
  }

  // Extraire le creneau depuis le payload OU depuis les items DB en fallback
  const startsAtPayload = String(getPayloadValue(payload, "consultation_starts_at") || "").trim();
  const endsAtPayload = String(getPayloadValue(payload, "consultation_ends_at") || "").trim();
  const startsAt = startsAtPayload || items.find((i) => i.consultation_starts_at)?.consultation_starts_at || "";
  const endsAt = endsAtPayload || items.find((i) => i.consultation_ends_at)?.consultation_ends_at || "";
  // Paquet 141.2 : extraction workflow_note (note staff lors de proposition,
  // note lecteur lors de refus, note staff lors de no-show, etc.).
  // Propagee via slotVars pour interpolation {workflow_note} dans templates i18n.
  const workflowNote = String(getPayloadValue(payload, "workflow_note") || items.find((i) => i.workflow_note)?.workflow_note || "").trim();
  const slotVars = buildSlotVars(startsAt, endsAt, tz, locale, workflowNote);
  const slotVarsLib = buildSlotVars(startsAt, endsAt, tz, libLocale, workflowNote);

  // Schedule reply status pour resposta_creneau
  const replyStatus = consultaScheduleReplyFromPayload(payload)
    || items.find((i) => i.schedule_reply_status)?.schedule_reply_status
    || "";

  // Resolution cles + flags + destinataires
  let readerKey: string | null = null;
  let staffKey: string | null = null;
  let readerMailEnabled = true;
  let staffMailEnabled = true;
  let readerActionUrl: string | null = null;
  let staffActionUrl: string | null = null;
  let granularFlag: boolean | null = null;

  if (we === "em_preparacao") {
    // Paquet 141 B2 : transition solicitada -> em_preparacao.
    // Mail lecteur uniquement (action courante de la biblio, pas de portee
    // collective). Pas de CTA : info pure, le lecteur attend la suite.
    readerKey = "cwf.reader.em_preparacao";
    staffKey = null;
    staffMailEnabled = false;  // pas de mail coordination (cf. doctrine R5)
    granularFlag = consultaEmPreparacaoEnabled(ctx);
  } else if (we === "consulta_agendada") {
    // Detection re-proposition : un workflow_stage qui etait deja 'consulta_agendada'
    // avant. Comme on n'a pas l'OLD dans le payload, on infere depuis schedule_reply_at
    // (si NULL = premiere proposition, sinon re-proposition).
    const isReschedule = items.some((i) => i.schedule_reply_at);
    readerKey = isReschedule ? "cwf.reader.rescheduled" : "cwf.reader.scheduled";
    staffKey = isReschedule ? "cwf.staff.rescheduled" : "cwf.staff.scheduled";
    readerActionUrl = READER_PAGE;  // CTA "Repondre a la proposition"
    granularFlag = consultaAgendadaEnabled(ctx);
  } else if (we === "nao_compareceu") {
    // Paquet 141 B5 : transition vers nao_compareceu.
    // Doctrine : mail no-show = rappel d'engagement reciproque, pas punition.
    // Mail lecteur (B5) + mail coordination (R8 tracabilite coordination :
    // tous les bibliothecaires + coordenadores doivent etre informes de
    // l'absence, pas seulement la personne qui a clique).
    readerKey = "cwf.reader.nao_compareceu";
    staffKey = "cwf.staff.nao_compareceu";
    staffMailEnabled = true;  // mail collectif a admin_notification_email
    // Pas de staffActionUrl : info pure pour la coordination, action terminee.
    granularFlag = consultaNaoCompareceuEnabled(ctx);
  } else if (we === "resposta_creneau") {
    // Le lecteur a repondu -> notif staff uniquement (le lecteur sait)
    readerKey = null;
    readerMailEnabled = false;
    if (replyStatus === "confirmado_leitor") {
      staffKey = "cwf.staff.readerConfirmed";
    } else if (replyStatus === "recusado_leitor") {
      staffKey = "cwf.staff.readerRefused";
    } else {
      // Reply status manquant : pas d'event, return sans mail (rare)
      return {
        user_result: skippedEmailResult("user_mail", "no_reply_status"),
        admin_result: skippedEmailResult("admin_copy", "no_reply_status")
      };
    }
    staffActionUrl = STAFF_PAGE;  // CTA "Ouvrir le painel" (preparer ou re-proposer)
    granularFlag = consultaRespostaCreneauEnabled(ctx);
  } else {
    return {
      user_result: skippedEmailResult("user_mail", "unknown_workflow_event"),
      admin_result: skippedEmailResult("admin_copy", "unknown_workflow_event")
    };
  }

  // Garde 2 : flag granulaire
  if (granularFlag === false) {
    return {
      user_result: skippedEmailResult("user_mail", `consulta_${we}_disabled`),
      admin_result: skippedEmailResult("admin_copy", `consulta_${we}_disabled`)
    };
  }

  const tits = joinTitles(items.map((i) => String(i.titulo || `[linha ${i.line_no || "?"}]`)));
  const brfs = joinTitles(items.map((i) => String(i.bib_ref || "")), ", ");
  // Paquet 141.2 : enrichir 'when' avec heure de fin si dispo (avant 141.2,
  // seule l'heure de debut etait affichee dans mail biblio). On affiche
  // "DD/MM/YYYY HH:MM - HH:MM" si endsAt present, sinon "DD/MM/YYYY HH:MM".
  const whenStart = startsAt ? formatDateTimeInZone(startsAt, tz) : "";
  const whenEnd = endsAt ? (formatDateTimeInZone(endsAt, tz).split(" ")[1] || "") : "";
  const when = whenStart && whenEnd ? `${whenStart} - ${whenEnd}` : whenStart;

  // ---- Mail lecteur ----
  let ur;
  if (readerKey && readerMailEnabled && user) {
    const interpolated = interpolate(tMail(locale, readerKey), slotVars);
    const readerSubject = `${interpolated.split(":")[0] || interpolated} - ${bt}`;

    const actionBox = readerActionUrl
      ? {
          kind: "action" as const,
          title: interpolated,
          ctaUrl: readerActionUrl,
          ctaLabel: tMail(locale, "cwf.actionBox.replySlot")
        }
      : undefined;

    const { html, text } = renderEmail({
      preheader: interpolated,
      title: tMail(locale, readerKey).split(":")[0] || tMail(locale, readerKey),
      greeting: greeting(locale, user?.name),
      introHtml: `<p style="margin:0 0 10px;">${interpolated}</p>`,
      actionBox,
      details: [
        ...(tits ? [{ label: label(locale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(locale, "refs"), value: brfs }] : []),
        ...(when ? [{ label: label(locale, "date"), value: when }] : [])
      ],
      footerHtml: footerPadrao(ctx),
      context: ctx,
      libreDiffusionLabel: tMail(locale, "subj.libreDiffusion")
    });
    ur = await safeSendEmail(user, applyBrandingText(readerSubject, ctx), html, text, "user_mail", ctx);
  } else {
    ur = skippedEmailResult("user_mail", readerMailEnabled ? "no_reader_recipient" : "reader_mail_skipped_by_event");
  }

  // ---- Mail staff ----
  let ar;
  if (staffKey && staffMailEnabled && consultaAdminCopyEnabled(ctx)) {
    const staffIntroBase = tMail(libLocale, staffKey);
    const staffSubject = `${staffIntroBase} - ${aun} - ${bt}`;

    const actionBox = staffActionUrl
      ? {
          kind: "action" as const,
          title: staffIntroBase,
          ctaUrl: staffActionUrl,
          ctaLabel: tMail(libLocale, "cwf.actionBox.preparePainel")
        }
      : undefined;

    const { html: ha, text: ta } = renderEmail({
      preheader: staffIntroBase,
      title: staffIntroBase,
      introHtml: applyBrandingText(`<p>${staffIntroBase}.</p>`, ctx),
      actionBox,
      details: [
        { label: label(libLocale, "reader"), value: aun },
        ...(tits ? [{ label: label(libLocale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(libLocale, "refs"), value: brfs }] : []),
        ...(when ? [{ label: label(libLocale, "date"), value: when }] : [])
      ],
      footerHtml: footerPadrao(ctx),
      context: ctx,
      libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion")
    });
    ar = await safeSendEmail(adminTarget(ctx), applyBrandingText(staffSubject, ctx), ha, ta, "admin_copy", ctx);
  } else {
    ar = skippedEmailResult(
      "admin_copy",
      !staffMailEnabled ? "staff_mail_skipped_by_event" : "consulta_admin_copy_disabled"
    );
  }

  return { user_result: ur, admin_result: ar };
}
