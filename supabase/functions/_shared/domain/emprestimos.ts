import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { loanAdminCopyEnabled, loanLifecycleEnabled } from "../context/policies.ts";
import { getEmprestimoV2Bundle } from "../data/emprestimos.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { adminDisplayName, esc, formatDateBR, fullName, joinTitles } from "../shared/format.ts";
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
  // Admin mail — dans la locale de la bibliothèque (libLocale), aligné sur les réservations (annule le choix historique du Paquet 17 / 96006b81 qui forçait pt-BR)
  let ai = `<p>${tMail(libLocale, "admin.loanUpdate")}</p>`, as2 = `[BLMF] ${tit} — ${aun}`, titAdmin = tit;
  if (event === "emprestimo_v2_criado") {
    ai = `<p>${tMail(libLocale, "admin.newLoan")}</p>`;
    titAdmin = tMail(libLocale, "loan.created.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  } else if (event === "emprestimo_v2_prorrogado") {
    ai = `<p>${tMail(libLocale, "admin.renewalDone")}</p>`;
    titAdmin = tMail(libLocale, "loan.renewed.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  } else if (event === "emprestimo_v2_devolvido") {
    ai = `<p>${tMail(libLocale, "admin.returnDone")}</p>`;
    titAdmin = tMail(libLocale, "loan.returned.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  } else if (event === "emprestimo_v2_parcialmente_devolvido") {
    ai = `<p>${tMail(libLocale, "admin.partialReturnDone")}</p>`;
    titAdmin = tMail(libLocale, "loan.partialReturn.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  } else if (event === "emprestimo_v2_devolvido_apos_parcial") {
    ai = `<p>${tMail(libLocale, "admin.fullyReturnedAfterPartialDone")}</p>`;
    titAdmin = tMail(libLocale, "loan.fullyReturnedAfterPartial.sub");
    as2 = `[BLMF] ${titAdmin} — ${aun}`;
  }
  // Paquet 17 (10/05/2026) : adminDet construit depuis detKeys (cles stables)
  // au lieu d'un mapping inverse fragile sur les labels traduits.
  const adminDet = [
    {
      label: label(libLocale, "reader"),
      value: aun
    },
    ...detKeys.map((k)=>({
        label: k.label ?? label(libLocale, k.key),
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
