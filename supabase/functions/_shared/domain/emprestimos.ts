import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { loanAdminCopyEnabled, loanLifecycleEnabled, reminderFamilyEnabled } from "../context/policies.ts";
import { getEmprestimoDevolucaoBundle, getEmprestimoV2Bundle, getEmprestimoV2Notificavel } from "../data/emprestimos.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, sendAdminNotification, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { DEFAULT_NOTIFICATION_TIMEZONE, adminDisplayName, esc, firstNameOnly, formatDateBR, formatDateTimeInZone, fullName, fullNameFromParts, joinTitles } from "../shared/format.ts";
import { getPayloadValue, normalizeLineNos } from "../shared/payload.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";
export async function handleEmprestimoV2(recordId, event, payload) {
  const { emprestimo, profile, items } = await getEmprestimoV2Bundle(recordId);
  const ctx = await resolveLibraryNotificationContext(String(emprestimo.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const aun = adminDisplayName(fullName(profile), user?.email);
  // TR-2 (#153.A) : sur une conversion reserva->emprestimo, la RPC
  // fn_v2_convert_reserva_linhas_to_emprestimo passe suppress_user_mail dans le
  // payload. Le mail lecteur·rice est alors porte par 'res.converted' (workflow
  // de reservation) ; on saute l'envoi lecteur·rice ici. Le mail admin reste emis.
  const suppressUserMail = getPayloadValue(payload, "suppress_user_mail") === true;
  const locale = String(profile?.preferred_language || "").trim() || null;
  const libLocale = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const fmtD = (d)=>formatDateLocale(d, locale) || formatDateBR(d);
  const oi = items.filter((i)=>String(i.item_status || "") === "aberto");
  const ri = items.filter((i)=>String(i.item_status || "") === "devolvido");
  const da = String(emprestimo.due_at || "");
  const ca = String(emprestimo.created_at || "");
  const ea = String(emprestimo.extended_at || "");
  let sub = "", tit = "", intro = "";
  // Paquet 17 (10/05/2026) : refactor propre du bloc admin i18n.
  // Avant : adminDet utilisait un mapping inverse fragile (matcher des labels traduits
  // contre des cles, qui cassait silencieusement quand le label n'etait pas trouve).
  // Maintenant : on garde une liste intermediaire detKeys avec la cle stable (ex. "items"),
  // depuis laquelle on derive le det lecteur (avec labels localises) ET adminDet (labels pt-BR).
  let detKeys = [];
  if (event === "emprestimo_v2_criado") {
    const t = joinTitles(oi.map((i)=>String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
    sub = `${tMail(locale, "loan.created.sub")} — BLMF`;
    tit = tMail(locale, "loan.created.sub");
    intro = `<p style="margin:0 0 10px;">${tMail(locale, "loan.created.intro")}</p>${da ? `<p style="margin:0 0 10px;">${tMail(locale, "loan.dueIn", {
      date: esc(fmtD(da))
    })}</p>` : ""}<p style="margin:0;">${tMail(locale, "layout.keepMsg")}</p>`;
    detKeys = [
      ...t ? [
        {
          key: "items",
          value: t
        }
      ] : [],
      ...ca ? [
        {
          key: "registration",
          value: fmtD(ca)
        }
      ] : [],
      ...da ? [
        {
          key: "dueDate",
          value: fmtD(da)
        }
      ] : []
    ];
  } else if (event === "emprestimo_v2_prorrogado") {
    // #NOTIFY-prorrogacao (B, 29/05/2026) : notification PAR ITEM.
    // Cibler les items renouvelés via payload.line_nos ; échéance = extended_until
    // (source de vérité), jamais due_at header. Liste « titre — date » par item (D6).
    const pln = normalizeLineNos(getPayloadValue(payload, "line_nos"));
    const ti = pln.length ? items.filter((i)=>pln.includes(i.line_no)) : oi;
    sub = `${tMail(locale, "loan.renewed.sub")} — BLMF`;
    tit = tMail(locale, "loan.renewed.sub");
    intro = `<p style="margin:0 0 10px;">${tMail(locale, "loan.renewed.intro")}</p><p style="margin:0;">${tMail(locale, "loan.renewed.once")}</p>`;
    detKeys = ti.map((i)=>({
      label: String(i.titulo || `[${String(i.bib_ref || "").trim()}]`),
      value: fmtD(String(i.extended_until || i.due_at || "").trim())
    }));
  } else if (event === "emprestimo_v2_devolvido") {
    const t = joinTitles((ri.length ? ri : items).map((i)=>String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
    const ra = ri.find((i)=>i.returned_at)?.returned_at;
    sub = `${tMail(locale, "loan.returned.sub")} — BLMF`;
    tit = tMail(locale, "loan.returned.sub");
    intro = `<p style="margin:0 0 10px;">${tMail(locale, "loan.returned.intro")}</p><p style="margin:0;">${tMail(locale, "loan.returned.browse")}</p>`;
    detKeys = [
      ...t ? [
        {
          key: "items",
          value: t
        }
      ] : [],
      ...ra ? [
        {
          key: "return",
          value: fmtD(String(ra))
        }
      ] : []
    ];
  } else if (event === "emprestimo_v2_parcialmente_devolvido") {
    const tReturned = joinTitles(ri.map((i)=>String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
    const tRemaining = joinTitles(oi.map((i)=>String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
    const remainingDueAt = oi.reduce((acc, i)=>{
      const d = String(i.extended_until || i.due_at || "").trim();
      return d && (!acc || d > acc) ? d : acc;
    }, "");
    sub = `${tMail(locale, "loan.partialReturn.sub")} — BLMF`;
    tit = tMail(locale, "loan.partialReturn.sub");
    intro = `<p style="margin:0 0 10px;">${tMail(locale, "loan.partialReturn.intro")}</p>${remainingDueAt ? `<p style="margin:0 0 10px;">${tMail(locale, "loan.partialReturn.dueReminder", {
      date: esc(fmtD(remainingDueAt))
    })}</p>` : ""}<p style="margin:0;">${tMail(locale, "loan.partialReturn.outro")}</p>`;
    detKeys = [
      ...tReturned ? [
        {
          key: "itemsReturned",
          value: tReturned
        }
      ] : [],
      ...tRemaining ? [
        {
          key: "itemsRemaining",
          value: tRemaining
        }
      ] : [],
      ...remainingDueAt ? [
        {
          key: "dueDate",
          value: fmtD(remainingDueAt)
        }
      ] : []
    ];
  } else if (event === "emprestimo_v2_devolvido_apos_parcial") {
    const tAll = joinTitles((ri.length ? ri : items).map((i)=>String(i.titulo || `[${String(i.bib_ref || "").trim()}]`)));
    const ra = ri.find((i)=>i.returned_at)?.returned_at;
    sub = `${tMail(locale, "loan.fullyReturnedAfterPartial.sub")} — BLMF`;
    tit = tMail(locale, "loan.fullyReturnedAfterPartial.sub");
    intro = `<p style="margin:0 0 10px;">${tMail(locale, "loan.fullyReturnedAfterPartial.intro")}</p><p style="margin:0;">${tMail(locale, "loan.fullyReturnedAfterPartial.browse")}</p>`;
    detKeys = [
      ...tAll ? [
        {
          key: "items",
          value: tAll
        }
      ] : [],
      ...ra ? [
        {
          key: "return",
          value: fmtD(String(ra))
        }
      ] : []
    ];
  } else throw new Error(`Evento não suportado: ${event}`);
  // Derive det (locale du lecteur) et adminDet (force pt-BR) depuis detKeys
  const det = detKeys.map((k)=>({
      label: k.label ?? label(locale, k.key),
      value: k.value
    }));
  const { html, text } = renderEmail({
    locale: locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: intro,
    details: det,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  sub = applyBrandingText(sub.replace(/BLMF/g, bt), ctx);
  // TR-2 (#153.A) : si suppress_user_mail (conversion), on saute l'envoi
  // lecteur·rice avec un motif explicite. Sinon, comportement inchange.
  const ur = suppressUserMail ? skippedEmailResult("user_mail", "suppressed_conversion") : loanLifecycleEnabled(ctx) ? await safeSendEmail(user, sub, html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "loan_lifecycle_disabled");
  // Admin mail — always PT-BR (locale=null)
  // Paquet 17 (10/05/2026, fin de session) : titre admin force pt-BR (avant : utilisait tit qui etait en langue lecteur)
  let ai = `<p>${tMail(null, "admin.loanUpdate")}</p>`, as2 = `[BLMF] ${tit} — ${aun}`, titAdmin = tit;
  if (event === "emprestimo_v2_criado") {
    ai = `<p>${tMail(null, "admin.newLoan")}</p>`;
    titAdmin = tMail(null, "loan.created.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  } else if (event === "emprestimo_v2_prorrogado") {
    ai = `<p>${tMail(null, "admin.renewalDone")}</p>`;
    titAdmin = tMail(null, "loan.renewed.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  } else if (event === "emprestimo_v2_devolvido") {
    ai = `<p>${tMail(null, "admin.returnDone")}</p>`;
    titAdmin = tMail(null, "loan.returned.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  } else if (event === "emprestimo_v2_parcialmente_devolvido") {
    ai = `<p>${tMail(null, "admin.partialReturnDone")}</p>`;
    titAdmin = tMail(null, "loan.partialReturn.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  } else if (event === "emprestimo_v2_devolvido_apos_parcial") {
    ai = `<p>${tMail(null, "admin.fullyReturnedAfterPartialDone")}</p>`;
    titAdmin = tMail(null, "loan.fullyReturnedAfterPartial.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  }
  // Paquet 17 (10/05/2026) : adminDet construit depuis detKeys (cles stables)
  // au lieu d'un mapping inverse fragile sur les labels traduits.
  const adminDet = [
    {
      label: label(null, "reader"),
      value: aun
    },
    ...detKeys.map((k)=>({
        label: k.label ?? label(null, k.key),
        value: k.value
      }))
  ];
  const { html: ha, text: ta } = renderEmail({
    locale: libLocale,
    preheader: titAdmin,
    title: titAdmin,
    introHtml: ai,
    details: adminDet,
    footerHtml: footerPadrao(ctx, libLocale),
    context: ctx
  });
  as2 = applyBrandingText(as2.replace(/BLMF/g, bt), ctx);
  const ar = loanLifecycleEnabled(ctx) && loanAdminCopyEnabled(ctx) ? await safeSendEmail(adminTarget(ctx), as2, ha, ta, "admin_copy", ctx) : skippedEmailResult("admin_copy", loanLifecycleEnabled(ctx) ? "loan_admin_copy_disabled" : "loan_lifecycle_disabled");
  return {
    user_result: ur,
    admin_result: ar
  };
}
export async function handleEmprestimoDevolucaoEvent(recordId, event, payload) {
  const pln = normalizeLineNos(getPayloadValue(payload, "line_nos"));
  const rows = await getEmprestimoDevolucaoBundle(recordId, pln.length ? pln : undefined);
  const f = rows[0] || {};
  const ctx = await resolveLibraryNotificationContext(String(f.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = {
    email: String(f.user_email || "").trim(),
    name: firstNameOnly(f.first_name) || undefined
  };
  const aun = adminDisplayName(fullNameFromParts(f.first_name, f.last_name), user.email);
  const locale = String(f.preferred_language || "").trim() || null;
  const libLocale = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const fmtD = (d)=>formatDateLocale(d, locale) || formatDateBR(d);
  const tits = joinTitles(rows.map((r)=>String(r.titulo || `[${String(r.bib_ref || "").trim()}]`)));
  const when = formatDateTimeInZone(String(f.return_scheduled_for || "").trim() || null, DEFAULT_NOTIFICATION_TIMEZONE);
  const da = fmtD(String(f.due_at || "").trim() || "");
  let sub = `${tMail(locale, "loan.returnScheduled")} — ${bt}`, tit = tMail(locale, "loan.returnScheduled"), intro = `<p>${tMail(locale, "loan.returnScheduled")}.</p>`;
  if (event === "emprestimo_devolucao_agendada") {
    sub = `${tMail(locale, "loan.returnScheduled")} — ${bt}`;
    tit = tMail(locale, "loan.returnScheduled");
    intro = `<p>${tMail(locale, "loan.returnScheduled")}.</p>${when ? `<p>${label(locale, "pickup")}: <b>${esc(when)}</b>.</p>` : ""}`;
  } else if (event === "emprestimo_devolucao_cancelada") {
    sub = `${tMail(locale, "loan.returnCancelled")} — ${bt}`;
    tit = tMail(locale, "loan.returnCancelled");
    intro = `<p>${tMail(locale, "loan.returnCancelled")}.</p>`;
  } else if (event === "emprestimo_devolucao_nao_realizada") {
    sub = `${tMail(locale, "loan.returnMissed")} — ${bt}`;
    tit = tMail(locale, "loan.returnMissed");
    intro = `<p>${tMail(locale, "loan.returnMissed")}.</p>`;
  }
  // Paquet 17 (10/05/2026) : meme refactor que handleEmprestimoV2 — cles stables.
  const detKeys2 = [
    ...tits ? [
      {
        key: "items",
        value: tits
      }
    ] : [],
    ...when && event !== "emprestimo_devolucao_cancelada" ? [
      {
        key: "dueDate",
        value: when
      }
    ] : [],
    ...da ? [
      {
        key: "deadline",
        value: da
      }
    ] : []
  ];
  const det = detKeys2.map((k)=>({
      label: label(locale, k.key),
      value: k.value
    }));
  const { html, text } = renderEmail({
    locale: locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user.name),
    introHtml: intro,
    details: det,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  sub = applyBrandingText(sub, ctx);
  const ur = loanLifecycleEnabled(ctx) ? await safeSendEmail(user, sub, html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "loan_lifecycle_disabled");
  // Paquet 17 (10/05/2026, fin de session) : titre admin force pt-BR
  let titAdmin2 = tit;
  if (event === "emprestimo_devolucao_agendada") titAdmin2 = tMail(null, "loan.returnScheduled");
  else if (event === "emprestimo_devolucao_cancelada") titAdmin2 = tMail(null, "loan.returnCancelled");
  else if (event === "emprestimo_devolucao_nao_realizada") titAdmin2 = tMail(null, "loan.returnMissed");
  const adminDet2 = [
    {
      label: label(null, "reader"),
      value: aun
    },
    ...detKeys2.map((k)=>({
        label: label(null, k.key),
        value: k.value
      }))
  ];
  const { html: ha, text: ta } = renderEmail({
    locale: libLocale,
    preheader: titAdmin2,
    title: titAdmin2,
    introHtml: `<p>${tMail(null, "admin.returnUpdate")}</p>`,
    details: adminDet2,
    footerHtml: footerPadrao(ctx, libLocale),
    context: ctx
  });
  const ar = loanLifecycleEnabled(ctx) && loanAdminCopyEnabled(ctx) ? await safeSendEmail(adminTarget(ctx), `[${bt}] ${titAdmin2} — ${aun}`, ha, ta, "admin_copy", ctx) : skippedEmailResult("admin_copy", "loan_admin_copy_disabled");
  return {
    user_result: ur,
    admin_result: ar
  };
}
export async function handleEmprestimoV2Reminder(recordId, event) {
  const e = await getEmprestimoV2Notificavel(recordId);
  const ctx = await resolveLibraryNotificationContext(String(e.library_id || e.default_library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const ufn = String(e.user_nome || "").trim();
  const user = {
    email: String(e.user_email || "").trim(),
    name: firstNameOnly(ufn) || undefined
  };
  const aun = adminDisplayName(ufn, user.email);
  // Note: v_emprestimos_v2_notificaveis may not have preferred_language — fallback to null (PT-BR)
  const locale = String(e.preferred_language || "").trim() || null;
  const fmtD = (d)=>formatDateLocale(d, locale) || formatDateBR(d);
  const tits = String(e.titulos || "").trim();
  const da = String(e.due_at || "");
  const dpv = Number(e.dias_para_vencer || 0);
  const dat = Number(e.dias_atraso || 0);
  let sub = "", tit = "", intro = "";
  if (event.includes("5d")) {
    sub = `${tMail(locale, "rem.5d")} — BLMF`;
    tit = tMail(locale, "rem.title");
    intro = `<p>${tMail(locale, "rem.5d.body")}${da ? ` (${esc(fmtD(da))})` : ""}.`;
  } else if (event.includes("3d")) {
    sub = `${tMail(locale, "rem.3d")} — BLMF`;
    tit = tMail(locale, "rem.title");
    intro = `<p>${tMail(locale, "rem.3d.body")}</p>`;
  } else if (event.includes("hoje")) {
    sub = `${tMail(locale, "rem.today")} — BLMF`;
    tit = tMail(locale, "rem.title");
    intro = `<p>${tMail(locale, "rem.today.body")}${da ? ` (${esc(fmtD(da))})` : ""}.`;
  } else if (event.includes("1d")) {
    sub = `${tMail(locale, "ov.1d")} — BLMF`;
    tit = tMail(locale, "ov.title");
    intro = `<p>${tMail(locale, "ov.1d.body", {
      date: da ? esc(fmtD(da)) : ""
    })}`;
  } else if (event.includes("7d")) {
    sub = `${tMail(locale, "ov.7d")} — BLMF`;
    tit = tMail(locale, "ov.title");
    intro = `<p>${tMail(locale, "ov.7d.body", {
      days: String(dat || 7)
    })}</p>`;
  } else if (event.includes("30d")) {
    sub = `${tMail(locale, "ov.30d")} — BLMF`;
    tit = tMail(locale, "ov.title");
    intro = `<p>${tMail(locale, "ov.30d.body", {
      days: String(dat || 30)
    })}</p>`;
  }
  const { html, text } = renderEmail({
    locale: locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user.name),
    introHtml: intro,
    details: [
      ...tits ? [
        {
          label: label(locale, "items"),
          value: tits
        }
      ] : [],
      ...da ? [
        {
          label: label(locale, "dueDate"),
          value: fmtD(da)
        }
      ] : []
    ],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  sub = applyBrandingText(sub.replace(/BLMF/g, bt), ctx);
  const ur = reminderFamilyEnabled(ctx, event) ? await safeSendEmail(user, sub, html, text, "user_mail", ctx) : skippedEmailResult("user_mail", "loan_reminder_disabled");
  let ar = null;
  if (event.includes("30d")) {
    ar = loanAdminCopyEnabled(ctx) && reminderFamilyEnabled(ctx, event) ? await sendAdminNotification({
      context: ctx,
      subject: applyBrandingText(`[BLMF] ${tMail(null, "ov.30d.admin")} — ${aun}`, ctx),
      title: tMail(null, "ov.30d.admin"),
      introHtml: `<p>${tMail(null, "ov.30d.body", {
        days: String(dat || 30)
      })}</p>`,
      details: [
        {
          label: label(null, "reader"),
          value: aun
        },
        ...tits ? [
          {
            label: label(null, "items"),
            value: tits
          }
        ] : [],
        ...da ? [
          {
            label: label(null, "dueDate"),
            value: formatDateBR(da)
          }
        ] : []
      ]
    }) : skippedEmailResult("admin_copy", "loan_reminder_disabled");
  }
  return {
    user_result: ur,
    admin_result: ar
  };
}
