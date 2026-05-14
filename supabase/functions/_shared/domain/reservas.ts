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
export async function handleReservaCriadaV2(recordId) {
  const { reserva, profile, items } = await getReservaV2Bundle(recordId);
  const ctx = await resolveLibraryNotificationContext(String(reserva.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);
  const locale = String(profile?.preferred_language || "").trim() || null;
  // PATCH paquet 6 commit comportement : locale biblio = ctx.default_locale
  // (fallback 'pt-BR'). Permet aux biblios non-lusophones de recevoir les
  // mails admin dans leur propre langue.
  const libLocale = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const fmtD = (d)=>formatDateLocale(d, locale) || formatDateBR(d);
  const tits = joinTitles(items.map((i)=>String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
  const sids = joinTitles(items.map((i)=>String(i.sub_id || "")), ", ");
  const brfs = joinTitles(items.map((i)=>String(i.bib_ref || "")), ", ");
  const ca = String(reserva.created_at || "");
  const su = `${tMail(locale, "res.created.sub")} — ${bt}`;
  const { html, text } = renderEmail({
    preheader: tMail(locale, "res.created.pre"),
    title: tMail(locale, "res.created.sub"),
    greeting: greeting(locale, user?.name),
    introHtml: `<p style="margin:0 0 10px;">${tMail(locale, "res.created.intro")}</p><p style="margin:0 0 10px;">${tMail(locale, "res.created.hint")}</p>${LIBRARIAN_PHONE ? `<p style="margin:0;">${label(locale, "contact")}: <b>${esc(LIBRARIAN_PHONE)}</b>.</p>` : ""}`,
    details: [
      ...tits ? [
        {
          label: label(locale, "items"),
          value: tits
        }
      ] : [],
      ...brfs ? [
        {
          label: label(locale, "refs"),
          value: brfs
        }
      ] : [],
      ...sids ? [
        {
          label: label(locale, "ids"),
          value: sids
        }
      ] : [],
      ...ca ? [
        {
          label: label(locale, "date"),
          value: fmtD(ca)
        }
      ] : []
    ],
    footerHtml: footerPadrao(ctx),
    context: ctx,
    libreDiffusionLabel: tMail(locale, "subj.libreDiffusion")
  });
  const ur = reservationCreatedEnabled(ctx) ? await safeSendEmail(user, applyBrandingText(su, ctx), html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "reservation_created_disabled");
  // Admin mail — locale biblio (ctx.default_locale, paquet 6)
  const { html: ha, text: ta } = renderEmail({
    preheader: tMail(libLocale, "res.created.admin"),
    title: tMail(libLocale, "res.created.admin"),
    introHtml: applyBrandingText(`<p>${tMail(libLocale, "res.created.admin")}.</p>`, ctx),
    details: [
      {
        label: label(libLocale, "reader"),
        value: aun
      },
      ...tits ? [
        {
          label: label(libLocale, "items"),
          value: tits
        }
      ] : [],
      ...brfs ? [
        {
          label: label(libLocale, "refs"),
          value: brfs
        }
      ] : [],
      ...ca ? [
        {
          label: label(libLocale, "date"),
          value: formatDateBR(ca)
        }
      ] : []
    ],
    footerHtml: footerPadrao(ctx),
    context: ctx,
    libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion")
  });
  const ar = reservationCreatedEnabled(ctx) && reservationAdminCopyEnabled(ctx) ? await safeSendEmail(adminTarget(ctx), applyBrandingText(`${tMail(libLocale, "res.created.admin")} — ${aun} — ${bt}`, ctx), ha, ta, "admin_copy", ctx) : skippedEmailResult("admin_copy", reservationCreatedEnabled(ctx) ? "reservation_admin_copy_disabled" : "reservation_created_disabled");
  return {
    user_result: ur,
    admin_result: ar
  };
}
export async function handleReservaV2StatusChange(recordId, event) {
  const se = normalizeReservaStatusChangeEvent(event) || event;
  const { reserva, profile, items } = await getReservaV2Bundle(recordId);
  const ctx = await resolveLibraryNotificationContext(String(reserva.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);
  const locale = String(profile?.preferred_language || "").trim() || null;
  // PATCH paquet 6 commit comportement : locale biblio + suppression hack BLMF
  const libLocale = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const tits = joinTitles(items.map((i)=>String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
  const motivo = String(reserva.notes || "").trim();
  // PATCH fix-up : déterminer la clé i18n spécifique selon l'événement (utilisée
  // par les 2 mails lecteur ET biblio, chacun dans sa locale).
  let mailKey = "admin.resUpdate";
  if (se === "reserva_v2_recusada") mailKey = "res.refused";
  else if (se === "reserva_cancelada_biblioteca") mailKey = "res.cancelStaff";
  else if (se === "reserva_cancelada_leitor") mailKey = "res.cancelReader";
  else if (se === "reserva_expirada") mailKey = "res.expired";
  else if (se === "reserva_convertida_em_emprestimo") mailKey = "res.converted";
  let sub = `${bt} | ${tMail(locale, mailKey)}`, tit = tMail(locale, mailKey), intro = `<p>${tMail(locale, mailKey)}.</p>`;
  if (motivo && (se === "reserva_v2_recusada" || se === "reserva_cancelada_biblioteca")) intro += `<p>${label(locale, "reason")}: <b>${esc(motivo)}</b>.</p>`;
  const det = [
    ...tits ? [
      {
        label: label(locale, "items"),
        value: tits
      }
    ] : []
  ];
  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: intro,
    details: det,
    footerHtml: footerPadrao(ctx),
    context: ctx,
    libreDiffusionLabel: tMail(locale, "subj.libreDiffusion")
  });
  sub = applyBrandingText(sub, ctx);
  const ur = reservationStatusEnabled(ctx) ? await safeSendEmail(user, sub, html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "reservation_status_disabled");
  // Admin — locale biblio (paquet 6) avec titre/intro spécifiques à l'événement (paquet 6 fix-up)
  const adminTit = tMail(libLocale, mailKey);
  const adminIntro = `<p>${tMail(libLocale, mailKey)}.</p>` + (motivo && (se === "reserva_v2_recusada" || se === "reserva_cancelada_biblioteca") ? `<p>${label(libLocale, "reason")}: <b>${esc(motivo)}</b>.</p>` : "");
  const { html: ha, text: ta } = renderEmail({
    preheader: adminTit,
    title: adminTit,
    introHtml: adminIntro,
    details: [
      {
        label: label(libLocale, "reader"),
        value: aun
      },
      {
        label: label(libLocale, "items"),
        value: tits || "—"
      }
    ],
    footerHtml: footerPadrao(ctx),
    context: ctx,
    libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion")
  });
  const ar = reservationStatusEnabled(ctx) && reservationAdminCopyEnabled(ctx) ? await safeSendEmail(adminTarget(ctx), applyBrandingText(`[${bt}] ${adminTit} — ${aun}`, ctx), ha, ta, "admin_copy", ctx) : skippedEmailResult("admin_copy", "reservation_admin_copy_disabled");
  return {
    user_result: ur,
    admin_result: ar
  };
}
// ═══════════════════════════════════════════════════════════
// handleReservaV2WorkflowEvent — paquet 6 commit comportement (2026-05-09)
// ═══════════════════════════════════════════════════════════
// Refonte sémantique v3 avec différenciation lecteur/biblio.
//
// Mappage des transitions (cf. cartographie validée session 2026-05-09) :
//
//   Event                   | Sous-cas                       | Mail lecteur                    | Mail biblio                     | ActionBox
//   ------------------------|--------------------------------|---------------------------------|---------------------------------|----------
//   retirada_a_combinar     | proposed_by=biblio, iter=0     | wf.reader.libraryProposed       | wf.staff.negotiationOpened      | info
//   retirada_a_combinar     | proposed_by=biblio, iter>0     | wf.reader.libraryCounterProposed| wf.staff.staffCounterProposed   | info
//   retirada_a_combinar     | proposed_by=leitor             | wf.reader.youCounterProposed    | wf.staff.readerCounterProposed  | ⚠ ACTION
//   retirada_agendada       | proposed_by=biblio (lecteur a accepté) | wf.reader.slotLocked        | wf.staff.readerAccepted         | info
//   retirada_agendada       | proposed_by=leitor (staff a confirmé)  | wf.reader.slotLocked        | wf.staff.staffConfirmed         | info
//   retirada_reagendada     | DÉPRÉCIÉ v3 (fossile historique)        | wf.pickupRescheduled (v2)   | wf.pickupRescheduled (v2)       | info
//   pronta_para_retirada    | —                              | wf.ready (v2 conservée)         | wf.staff.ready                  | info
//   retirada_no_show        | —                              | wf.noShow (v2 conservée)        | wf.staff.noShow                 | info
//   liberada_para_circulacao| —                              | wf.closed (v2 conservée)        | wf.staff.closed                 | info
//   em_preparacao           | —                              | wf.preparing (v2 conservée)     | PAS DE MAIL BIBLIO              | —
//
// Locale biblio : ctx.default_locale (ajouté au paquet 6.0/6.1/6.2).
// Permet aux biblios non-lusophones (CIRA Lausanne, etc.) de recevoir
// leurs mails dans leur propre langue. Fallback 'pt-BR'.
//
// Hack BLMF (sentinelle remplacée par bt) supprimé : on construit
// directement le subject avec le subjectTag de la biblio.
// ═══════════════════════════════════════════════════════════
export async function handleReservaV2WorkflowEvent(recordId, event, payload) {
  const we = normalizeReservaWorkflowEvent(event) || event;
  const pln = normalizeLineNos(getPayloadValue(payload, "line_nos"));
  const pi = normalizeWorkflowItems(getPayloadValue(payload, "items"));
  const { reserva, profile, items: db } = await getReservaWorkflowBundle(recordId, pln.length ? pln : undefined);
  const ctx = await resolveLibraryNotificationContext(String(reserva.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const locale = String(profile?.preferred_language || "").trim() || null;
  // PATCH paquet 6 : locale biblio = ctx.default_locale (fallback 'pt-BR' si pas configuré)
  const libLocale = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const items = db.length ? db : pi;
  const pe = String(getPayloadValue(payload, "user_email") || "").trim();
  const pn = String(getPayloadValue(payload, "user_name") || "").trim();
  const user = userTargetFromProfile(profile) || (isValidEmail(pe) ? {
    email: pe,
    name: firstNameOnly(pn) || undefined
  } : null);
  const aun = adminDisplayName(fullName(profile) || pn, user?.email);
  const tits = joinTitles(items.map((i)=>String(i.titulo || `[linha ${i.line_no || "?"}]`)));
  const sl = workflowStageLabel(workflowStageFromEvent(event));
  const note = String(getPayloadValue(payload, "workflow_note") || items.find((i)=>i.workflow_note)?.workflow_note || "").trim();
  const psf = String(getPayloadValue(payload, "pickup_scheduled_for") || items.find((i)=>i.pickup_scheduled_for)?.pickup_scheduled_for || "").trim();
  const tz = String(getPayloadValue(payload, "timezone") || DEFAULT_NOTIFICATION_TIMEZONE).trim() || DEFAULT_NOTIFICATION_TIMEZONE;
  const when = psf ? formatDateTimeInZone(psf, tz) : "";
  // PATCH paquet 6 : extraction des champs de négociation pour distinguer
  // les sous-cas de retirada_a_combinar et retirada_agendada.
  const proposedBy = String(getPayloadValue(payload, "pickup_proposed_by") || items.find((i)=>i.pickup_proposed_by)?.pickup_proposed_by || "").trim();
  const iterCount = Number(items.find((i)=>typeof i.negotiation_iteration_count === 'number')?.negotiation_iteration_count ?? 0);
  // Détermination des clés v3 selon l'événement et le sous-cas.
  // readerKey/staffKey : clés i18n. staffActionUrl : si action attendue
  // côté biblio (= ouverture du painel), définit l'encadré actionBox.
  // staffMailEnabled : false si on ne veut pas envoyer de mail biblio
  // (cas em_preparacao Q2 paquet 6).
  let readerKey = null, staffKey = null, staffMailEnabled = true, staffNeedsAction = false;
  if (we === "retirada_a_combinar") {
    if (proposedBy === 'biblio') {
      if (iterCount === 0) {
        readerKey = 'wf.reader.libraryProposed';
        staffKey = 'wf.staff.negotiationOpened';
      } else {
        readerKey = 'wf.reader.libraryCounterProposed';
        staffKey = 'wf.staff.staffCounterProposed';
      }
    } else if (proposedBy === 'leitor') {
      readerKey = 'wf.reader.youCounterProposed';
      staffKey = 'wf.staff.readerCounterProposed';
      staffNeedsAction = true;
    } else {
      // Fallback rare : pickup_proposed_by absent (ne devrait pas arriver en v3
      // car advance_reservation set automatiquement à 'biblio' depuis 2 ter).
      readerKey = 'wf.toCoordinate';
      staffKey = null;
      staffMailEnabled = false;
    }
  } else if (we === "retirada_agendada") {
    readerKey = 'wf.reader.slotLocked';
    // proposedBy au moment de la transition vers retirada_agendada indique
    // l'auteur de la dernière proposition acceptée :
    // - 'biblio' : le lecteur a accepté la proposition staff → readerAccepted
    // - 'leitor' : le staff a confirmé la contre-prop lecteur → staffConfirmed
    staffKey = proposedBy === 'leitor' ? 'wf.staff.staffConfirmed' : 'wf.staff.readerAccepted';
  } else if (we === "retirada_reagendada") {
    // DÉPRÉCIÉ v3 : conservé pour compatibilité résas historiques (fossile).
    // Ne devrait plus être déclenché par les nouveaux flux de négociation.
    readerKey = 'wf.pickupRescheduled';
    staffKey = null;
    staffMailEnabled = false;
  } else if (we === "pronta_para_retirada") {
    readerKey = 'wf.ready';
    staffKey = 'wf.staff.ready';
  } else if (we === "retirada_no_show") {
    readerKey = 'wf.noShow';
    staffKey = 'wf.staff.noShow';
  } else if (we === "liberada_para_circulacao") {
    readerKey = 'wf.closed';
    staffKey = 'wf.staff.closed';
  } else if (we === "em_preparacao") {
    readerKey = 'wf.preparing';
    staffKey = null;
    staffMailEnabled = false; // Q2 paquet 6 : pas de mail biblio pour em_preparacao
  }
  // ─── PATCH paquet 6 fix-up bug #2 + #2bis (2026-05-09) ─────
  // Bug #2 : <b>...</b> apparaissait brut dans le sujet (sujet = texte plat).
  // Bug #2bis : {iter}/{max} non interpolés dans wf.reader.youCounterProposed.
  //
  // Solution : les 16 clés v3 (wf.reader.*, wf.staff.*) ont été dédoublées en
  // .subject (texte plat, court) et .body (HTML autorisé, version développée).
  // splitKey() retourne la paire à utiliser. Les clés v2 conservées
  // (wf.ready, wf.noShow, wf.closed, wf.preparing, wf.toCoordinate,
  // wf.pickupRescheduled) ne sont PAS dédoublées — elles servent comme
  // fallback texte court et sont passées telles quelles.
  // tParams porte {iter, max} pour interpolation dans youCounterProposed.
  const V3_DOUBLED = new Set([
    'wf.reader.libraryProposed',
    'wf.reader.libraryCounterProposed',
    'wf.reader.youCounterProposed',
    'wf.reader.slotLocked',
    'wf.reader.maxIterations',
    'wf.reader.negotiationTimeout',
    'wf.staff.negotiationOpened',
    'wf.staff.staffCounterProposed',
    'wf.staff.readerCounterProposed',
    'wf.staff.readerAccepted',
    'wf.staff.staffConfirmed',
    'wf.staff.ready',
    'wf.staff.noShow',
    'wf.staff.closed',
    'wf.staff.maxIterations',
    'wf.staff.negotiationTimedOut'
  ]);
  const splitKey = (k)=>{
    const base = k || 'admin.resUpdate';
    return V3_DOUBLED.has(base) ? {
      subjectKey: `${base}.subject`,
      bodyKey: `${base}.body`
    } : {
      subjectKey: base,
      bodyKey: base
    };
  };
  const tParams = {
    iter: iterCount,
    max: 3
  };
  // ─── Mail lecteur ────────────────────────────────────────
  // Construction du sujet et du contenu, dans la locale du lecteur.
  // wf.checkAccount ajouté pour les cas négociation et créneau prévu.
  const { subjectKey: readerSubKey, bodyKey: readerBodyKey } = splitKey(readerKey);
  const readerSubject = tMail(locale, readerSubKey, tParams);
  const readerBody = tMail(locale, readerBodyKey, tParams);
  const showCheckAccount = [
    'wf.reader.libraryProposed',
    'wf.reader.libraryCounterProposed',
    'wf.reader.youCounterProposed',
    'wf.reader.slotLocked'
  ].includes(readerKey || '');
  const userIntro = `<p>${readerBody}</p>${when ? `<p>${label(locale, "pickup")}: <b>${esc(when)}</b></p>` : ""}${showCheckAccount ? `<p>${tMail(locale, "wf.checkAccount")}</p>` : ""}`;
  const prs = String(items.find((i)=>i.pickup_reply_status)?.pickup_reply_status || "").trim();
  const prn = String(items.find((i)=>i.pickup_reply_note)?.pickup_reply_note || "").trim();
  const prl = pickupReplyLabel(prs);
  const det = [
    ...tits ? [
      {
        label: label(locale, "items"),
        value: tits
      }
    ] : [],
    ...sl ? [
      {
        label: label(locale, "status"),
        value: sl
      }
    ] : [],
    ...when ? [
      {
        label: label(locale, "pickup"),
        value: `${when} (local)`
      }
    ] : [],
    ...prl ? [
      {
        label: label(locale, "reply"),
        value: prl
      }
    ] : [],
    ...prn ? [
      {
        label: label(locale, "readerNote"),
        value: prn
      }
    ] : [],
    ...note ? [
      {
        label: label(locale, "note"),
        value: note
      }
    ] : []
  ];
  // preheader & title = readerSubject (texte plat) — readerBody (HTML possible) reste dans introHtml.
  const { html: userHtml, text: userText } = renderEmail({
    preheader: readerSubject,
    title: readerSubject,
    greeting: greeting(locale, user?.name),
    introHtml: userIntro,
    details: det,
    footerHtml: footerPadrao(ctx),
    context: ctx,
    libreDiffusionLabel: tMail(locale, "subj.libreDiffusion")
  });
  const userSub = applyBrandingText(`${readerSubject} — ${bt}`, ctx);
  const ur = reservationWorkflowEnabled(ctx) ? await safeSendEmail(user, userSub, userHtml, userText, "user_mail", ctx) : skippedEmailResult("user_mail", "reservation_workflow_disabled");
  // ─── Mail biblio ─────────────────────────────────────────
  // Si staffKey est null (em_preparacao, retirada_reagendada déprécié,
  // ou pickup_proposed_by absent) : skip le mail biblio.
  // Sinon : construit dans la locale de la biblio (libLocale = ctx.default_locale),
  // avec encadré actionBox kind='action' si une action staff est requise
  // (= readerCounterProposed seulement, cf. Q-A validée).
  let ar;
  if (!staffMailEnabled || !staffKey) {
    ar = skippedEmailResult("admin_copy", we === "em_preparacao" ? "em_preparacao_no_admin_mail" : "no_staff_key_for_event");
  } else if (!reservationWorkflowEnabled(ctx) || !reservationAdminCopyEnabled(ctx)) {
    ar = skippedEmailResult("admin_copy", reservationWorkflowEnabled(ctx) ? "reservation_admin_copy_disabled" : "reservation_workflow_disabled");
  } else {
    const { subjectKey: staffSubKey, bodyKey: staffBodyKey } = splitKey(staffKey);
    const staffSubject = tMail(libLocale, staffSubKey, tParams);
    const staffBody = tMail(libLocale, staffBodyKey, tParams);
    const staffIntro = `<p>${staffBody}</p>${when ? `<p>${label(libLocale, "pickup")}: <b>${esc(when)}</b></p>` : ""}`;
    const actionBox = staffNeedsAction ? {
      kind: 'action',
      title: tMail(libLocale, 'wf.staff.actionBox.title'),
      ctaLabel: tMail(libLocale, 'wf.staff.actionBox.openPanel'),
      ctaUrl: 'https://app.anarbib.org/painel'
    } : {
      kind: 'info',
      title: tMail(libLocale, 'wf.staff.infoBox.title')
    };
    const subjPrefix = staffNeedsAction ? tMail(libLocale, 'subj.staff.action') : tMail(libLocale, 'subj.staff.info');
    // Détails côté biblio : nom du lecteur en plus, dans la locale biblio
    const staffDet = [
      {
        label: label(libLocale, "reader"),
        value: aun
      },
      ...tits ? [
        {
          label: label(libLocale, "items"),
          value: tits
        }
      ] : [],
      ...sl ? [
        {
          label: label(libLocale, "status"),
          value: sl
        }
      ] : [],
      ...when ? [
        {
          label: label(libLocale, "pickup"),
          value: `${when} (local)`
        }
      ] : [],
      ...prl ? [
        {
          label: label(libLocale, "reply"),
          value: prl
        }
      ] : [],
      ...prn ? [
        {
          label: label(libLocale, "readerNote"),
          value: prn
        }
      ] : [],
      ...note ? [
        {
          label: label(libLocale, "note"),
          value: note
        }
      ] : []
    ];
    // preheader & title = staffSubject (texte plat) — staffBody (HTML possible) reste dans introHtml.
    const { html: staffHtml, text: staffText } = renderEmail({
      preheader: staffSubject,
      title: staffSubject,
      introHtml: staffIntro,
      details: staffDet,
      footerHtml: footerPadrao(ctx),
      context: ctx,
      actionBox,
      libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion")
    });
    const staffSub = applyBrandingText(`${subjPrefix} ${staffSubject} — ${aun} — ${bt}`, ctx);
    ar = await safeSendEmail(adminTarget(ctx), staffSub, staffHtml, staffText, "admin_copy", ctx);
  }
  return {
    user_result: ur,
    admin_result: ar
  };
}
export async function handleReservaPickupReplyEvent(recordId, event, payload) {
  const re = normalizeReservaPickupReplyEvent(event) || event;
  const pln = normalizeLineNos(getPayloadValue(payload, "line_nos"));
  const { reserva, profile, items } = await getReservaWorkflowBundle(recordId, pln.length ? pln : undefined);
  const ctx = await resolveLibraryNotificationContext(String(reserva.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);
  // PATCH paquet 6 commit comportement : locale biblio + suppression hack BLMF.
  // Note : ce handler est admin-only (legacy v2 pickup_reply). Avec la
  // sémantique v3 négociation symétrique, il devient partiellement redondant
  // avec handleReservaV2WorkflowEvent (qui gère déjà le cas proposed_by='leitor').
  // À déprécier complètement au paquet 7 cleanup.
  const libLocale = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const tits = joinTitles(items.map((i)=>String(i.titulo || `[linha ${i.line_no || "?"}]`)));
  const psf = String(items.find((i)=>i.pickup_scheduled_for)?.pickup_scheduled_for || "").trim();
  const when = psf ? formatDateTimeInZone(psf, DEFAULT_NOTIFICATION_TIMEZONE) : "";
  const rs = String(items.find((i)=>i.pickup_reply_status)?.pickup_reply_status || "").trim();
  const rl = pickupReplyLabel(rs);
  const rn = String(items.find((i)=>i.pickup_reply_note)?.pickup_reply_note || "").trim();
  let tit = tMail(libLocale, "pr.readerReply"), sub = `[${bt}] ${tMail(libLocale, "pr.readerReply")} — ${aun}`, intro = `<p>${tMail(libLocale, "pr.readerReply")}.</p>`;
  if (re === "retirada_confirmada_leitor") {
    tit = tMail(libLocale, "pr.confirmed");
    sub = `[${bt}] ${tMail(libLocale, "pr.confirmed")} — ${aun}`;
    intro = `<p>${tMail(libLocale, "pr.confirmed")}.</p>`;
  } else if (re === "retirada_recusada_leitor") {
    tit = tMail(libLocale, "pr.declined");
    sub = `[${bt}] ${tMail(libLocale, "pr.declined")} — ${aun}`;
    intro = `<p>${tMail(libLocale, "pr.declined")}.</p>`;
  }
  const { html: ha, text: ta } = renderEmail({
    preheader: tit,
    title: tit,
    introHtml: intro,
    details: [
      {
        label: label(libLocale, "reader"),
        value: aun
      },
      ...tits ? [
        {
          label: label(libLocale, "items"),
          value: tits
        }
      ] : [],
      ...when ? [
        {
          label: label(libLocale, "pickup"),
          value: `${when} (local)`
        }
      ] : [],
      ...rl ? [
        {
          label: label(libLocale, "reply"),
          value: rl
        }
      ] : [],
      ...rn ? [
        {
          label: label(libLocale, "note"),
          value: rn
        }
      ] : []
    ],
    footerHtml: footerPadrao(ctx),
    context: ctx,
    libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion")
  });
  sub = applyBrandingText(sub, ctx);
  const ar = reservationWorkflowEnabled(ctx) && reservationAdminCopyEnabled(ctx) ? await safeSendEmail(adminTarget(ctx), sub, ha, ta, "admin_copy", ctx) : skippedEmailResult("admin_copy", reservationWorkflowEnabled(ctx) ? "reservation_admin_copy_disabled" : "reservation_workflow_disabled");
  return {
    user_result: {
      ok: true,
      skipped: true,
      reason: "admin_only"
    },
    admin_result: ar
  };
}
