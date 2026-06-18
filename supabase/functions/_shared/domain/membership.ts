import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { APP_BASE_URL, supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { adminDisplayName, formatDateBR, fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

// ============================================================================
// #NOTIFY-Painel-acts — Famille 1 : reçu de paiement de cotisation.
// ----------------------------------------------------------------------------
// Émis par public.fn_record_membership_payment via
//   fn_dispatch_notify_event('cotisation_payment_recorded', 1, {payment_id})
// record_id factice = 1 (l'EF exige record_id > 0) ; la donnée utile (uuid du
// paiement) vit dans payload. Le handler re-interroge membership_payments par
// payment_id (source autoritaire), résout le membre + sa locale, vérifie la
// politique biblio (NOTIF-PA2, configurable, défaut ON), et envoie le reçu au
// membre (e-mail seul ; pas de réplique in-app — le bandeau de compte suffit,
// doctrine §4.4). DOC-NOTIF-1 : on notifie le membre, pas le staff.
// ============================================================================
export async function handleCotisationPayment(payload) {
  const paymentId = String(payload?.payment_id || "").trim();
  if (!paymentId) throw new Error("payment_id manquant.");

  const { data: pay, error: e1 } = await supabaseAdmin
    .from("membership_payments")
    .select("id,user_id,library_id,amount_paid,currency,paid_at,valid_from,valid_until,payment_method")
    .eq("id", paymentId)
    .maybeSingle();
  if (e1) throw e1;
  if (!pay) throw new Error("Pagamento não encontrado.");

  // Politique biblio (NOTIF-PA2) : configurable, défaut ON. Lecture directe
  // (évite de toucher la vue partagée v_library_notification_context).
  const { data: pol } = await supabaseAdmin
    .from("library_notification_policies")
    .select("cotisation_payment_mail_enabled")
    .eq("library_id", pay.library_id)
    .maybeSingle();
  if (pol && pol.cotisation_payment_mail_enabled === false) {
    return { user_result: skippedEmailResult("user_mail", "cotisation_payment_mail_disabled") };
  }

  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", pay.user_id)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");

  const ctx = await resolveLibraryNotificationContext(String(pay.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  if (!user?.email) {
    return { user_result: skippedEmailResult("user_mail", "no_recipient_email") };
  }
  const locale = String(profile?.preferred_language || "").trim() || null;
  const fmtD = (d) => formatDateLocale(d, locale) || formatDateBR(d);

  const amountStr = `${pay.amount_paid} ${String(pay.currency || "").trim()}`.trim();
  const untilStr = pay.valid_until ? fmtD(pay.valid_until) : tMail(locale, "cot.noExpiry");
  const periodStr = `${fmtD(pay.valid_from)} — ${untilStr}`;
  const methodStr = tMail(locale, `cot.method.${String(pay.payment_method || "other")}`);

  const tit = tMail(locale, "cotisation.payment.subject");
  const det = [
    { label: label(locale, "cotAmount"), value: amountStr },
    { label: label(locale, "cotPeriod"), value: periodStr },
    { label: label(locale, "cotMethod"), value: methodStr }
  ];
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: `<p>${tMail(locale, "cotisation.payment.intro")}</p>`,
    details: det,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
  const user_result = await safeSendEmail(user, sub, html, text, "user_mail", ctx);

  // Copie biblio (admin de la biblio du paiement) — même garde que le mail
  // membre (cotisation_payment_mail_enabled déjà vérifiée). Locale biblio.
  const aun = adminDisplayName(fullName(profile), user?.email);
  const libLoc = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const fmtL = (d) => formatDateLocale(d, libLoc) || formatDateBR(d) || "";
  const periodL = `${fmtL(pay.valid_from)} — ${pay.valid_until ? fmtL(pay.valid_until) : tMail(libLoc, "cot.noExpiry")}`;
  const methodL = tMail(libLoc, `cot.method.${String(pay.payment_method || "other")}`);
  const titL = tMail(libLoc, "cotisation.payment.subject");
  const { html: ha, text: ta } = renderEmail({
    locale: libLoc,
    preheader: titL,
    title: titL,
    introHtml: `<p>${titL}.</p>`,
    details: [
      { label: label(libLoc, "reader"), value: aun },
      { label: label(libLoc, "cotAmount"), value: amountStr },
      { label: label(libLoc, "cotPeriod"), value: periodL },
      { label: label(libLoc, "cotMethod"), value: methodL }
    ],
    footerHtml: footerPadrao(ctx, libLoc),
    context: ctx
  });
  const admin_result = await safeSendEmail(adminTarget(ctx), applyBrandingText(`[${bt}] ${titL} — ${aun}`, ctx), ha, ta, "admin_copy", ctx);

  return { user_result, admin_result };
}

// ============================================================================
// MULTI P4b — notification « inscription validée » (validation_confirmed).
// ----------------------------------------------------------------------------
// Émis par api.validate_membership via
//   fn_dispatch_notify_event('validation_confirmed', 1, {user_id, library_id, membership_id})
// record_id factice = 1 ; la donnée utile (uuid de l'appartenance) vit dans
// payload. On relit l'appartenance (source autoritaire) par membership_id, on
// s'assure qu'elle est bien active (validée), puis on envoie à la lectrice
// l'e-mail de confirmation avec CTA vers son espace /conta. Notif lectrice
// uniquement : le staff a déclenché la validation, il sait déjà (DOC-NOTIF-1).
// ============================================================================
export async function handleValidationConfirmed(payload) {
  const membershipId = String(payload?.membership_id || "").trim();
  if (!membershipId) throw new Error("membership_id manquant.");

  const { data: m, error: e1 } = await supabaseAdmin
    .from("user_library_memberships")
    .select("id,user_id,library_id,status,local_reader_number")
    .eq("id", membershipId)
    .maybeSingle();
  if (e1) throw e1;
  if (!m) throw new Error("Associação não encontrada.");
  // Garde : ne notifier que si réellement active (validée). Évite un faux
  // positif si l'appartenance a changé d'état entre dispatch et traitement.
  if (m.status !== "active") {
    return { user_result: skippedEmailResult("user_mail", "membership_not_active") };
  }

  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", m.user_id)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");

  const ctx = await resolveLibraryNotificationContext(String(m.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  if (!user?.email) {
    return { user_result: skippedEmailResult("user_mail", "no_recipient_email") };
  }
  const locale = String(profile?.preferred_language || "").trim() || null;
  const libName = String(ctx?.library_name || ctx?.library_short_name || "").trim();

  const tit = tMail(locale, "validation_confirmed.subject");
  const det = [];
  if (libName) det.push({ label: tMail(locale, "validation_confirmed.libraryLabel"), value: libName });
  if (m.local_reader_number) {
    det.push({ label: tMail(locale, "validation_confirmed.readerNumberLabel"), value: String(m.local_reader_number) });
  }

  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: `<p>${tMail(locale, "validation_confirmed.intro")}</p>`,
    details: det.length ? det : undefined,
    actionBox: {
      kind: "action",
      title: tMail(locale, "validation_confirmed.actionTitle"),
      ctaUrl: `${APP_BASE_URL}/conta`,
      ctaLabel: tMail(locale, "validation_confirmed.cta")
    },
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
  const user_result = await safeSendEmail(user, sub, html, text, "user_mail", ctx);
  return { user_result };
}

// ============================================================================
// CARD-LOCAL-N4 — notification « identité attribuée » (reader_identity_assigned).
// ----------------------------------------------------------------------------
// Émis par api.set_local_reader_identity (édition staff) UNIQUEMENT quand
// l'appartenance est déjà active et que l'identité change vers une valeur non
// nulle → e-mail de réconciliation. DÉDUP avec validation_confirmed : à la
// validation, l'identité passe déjà dans cet e-mail-là ; on ne redouble pas
// (la RPC ne dispatche pas sur une appartenance pending_validation).
// CARD-LOCAL-N4 : lectrice + COPIE biblio.
// ============================================================================
export async function handleReaderIdentityAssigned(payload) {
  const membershipId = String(payload?.membership_id || "").trim();
  if (!membershipId) throw new Error("membership_id manquant.");

  const { data: m, error: e1 } = await supabaseAdmin
    .from("user_library_memberships")
    .select("id,user_id,library_id,status,local_reader_number")
    .eq("id", membershipId)
    .maybeSingle();
  if (e1) throw e1;
  if (!m) throw new Error("Associação não encontrada.");
  // Garde : seulement sur appartenance active + identité présente (la dédup est
  // déjà faite côté RPC, c'est un filet en cas d'état changé entre-temps).
  if (m.status !== "active") {
    return { user_result: skippedEmailResult("user_mail", "membership_not_active") };
  }
  if (!m.local_reader_number) {
    return { user_result: skippedEmailResult("user_mail", "no_identity") };
  }

  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", m.user_id)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");

  const ctx = await resolveLibraryNotificationContext(String(m.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const user = userTargetFromProfile(profile);
  const locale = String(profile?.preferred_language || "").trim() || null;
  const libName = String(ctx?.library_name || ctx?.library_short_name || "").trim();
  const identity = String(m.local_reader_number);

  const det = [];
  if (libName) det.push({ label: tMail(locale, "validation_confirmed.libraryLabel"), value: libName });
  det.push({ label: tMail(locale, "reader_identity_assigned.identityLabel"), value: identity });

  // 1) E-mail à la lectrice (réconciliation).
  let user_result;
  if (!user?.email) {
    user_result = skippedEmailResult("user_mail", "no_recipient_email");
  } else {
    const tit = tMail(locale, "reader_identity_assigned.subject");
    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, user?.name),
      introHtml: `<p>${tMail(locale, "reader_identity_assigned.intro")}</p>`,
      details: det,
      actionBox: {
        kind: "action",
        title: tMail(locale, "validation_confirmed.actionTitle"),
        ctaUrl: `${APP_BASE_URL}/conta`,
        ctaLabel: tMail(locale, "validation_confirmed.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });
    const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
    user_result = await safeSendEmail(user, sub, html, text, "user_mail", ctx);
  }

  // 2) Copie biblio (CARD-LOCAL-N4 : lectrice + biblio). Même langue que la lectrice.
  const readerName = fullName(profile) || user?.email || "—";
  const aTit = tMail(locale, "reader_identity_assigned.adminSubject");
  const { html: aHtml, text: aText } = renderEmail({
    locale,
    preheader: aTit,
    title: aTit,
    introHtml: `<p>${tMail(locale, "reader_identity_assigned.adminIntro", { reader: readerName, library: libName || "—" })}</p>`,
    details: det,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const aSub = applyBrandingText(`${aTit} — ${bt}`, ctx);
  const admin_result = await safeSendEmail(adminTarget(ctx), aSub, aHtml, aText, "admin_copy", ctx);

  return { user_result, admin_result };
}

// ============================================================================
// VALID-C3 — notification staff « compte en attente de validation ».
// ----------------------------------------------------------------------------
// Émis par api.request_membership via fn_dispatch_notify_event(
//   'membership_validation_requested', 1, {user_id, library_id, membership_id}).
// Prévient la biblio (adresse de contact, locale biblio) qu'une demande attend
// validation, avec CTA vers /painel — pour que le vetting humain (vraie
// personne ? camarade ?) se fasse promptement. Pendant « staff » de
// validation_confirmed (P4b, côté lectrice).
// ============================================================================
export async function handleMembershipValidationRequested(payload) {
  const membershipId = String(payload?.membership_id || "").trim();
  if (!membershipId) throw new Error("membership_id manquant.");

  const { data: m, error: e1 } = await supabaseAdmin
    .from("user_library_memberships")
    .select("id,user_id,library_id,status")
    .eq("id", membershipId)
    .maybeSingle();
  if (e1) throw e1;
  if (!m) throw new Error("Associação não encontrada.");
  // Ne notifier que si toujours en attente (l'état peut avoir changé entre
  // dispatch et traitement — ex. validation immédiate).
  if (m.status !== "pending_validation") {
    return { admin_result: skippedEmailResult("admin_copy", "membership_not_pending") };
  }

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name")
    .eq("id", m.user_id)
    .maybeSingle();

  const ctx = await resolveLibraryNotificationContext(String(m.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const libLoc = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";
  const applicant = adminDisplayName(fullName(profile), profile?.email);

  const tit = tMail(libLoc, "membership_validation_requested.subject");
  const { html, text } = renderEmail({
    locale: libLoc,
    preheader: tit,
    title: tit,
    introHtml: `<p>${tMail(libLoc, "membership_validation_requested.intro")}</p>`,
    details: [{ label: label(libLoc, "reader"), value: applicant }],
    actionBox: {
      kind: "action",
      title: tMail(libLoc, "membership_validation_requested.actionTitle"),
      ctaUrl: `${APP_BASE_URL}/painel`,
      ctaLabel: tMail(libLoc, "membership_validation_requested.cta")
    },
    footerHtml: footerPadrao(ctx, libLoc),
    context: ctx
  });
  const sub = applyBrandingText(`[${bt}] ${tit}`, ctx);
  const admin_result = await safeSendEmail(adminTarget(ctx), sub, html, text, "admin_copy", ctx);
  return { admin_result };
}

// ============================================================================
// #25 — notification d'expiration de cotisation (cotisation_expiring).
// ----------------------------------------------------------------------------
// Émise par le cron public.fn_cron_notify_membership_expiry via
//   fn_dispatch_notify_event('cotisation_expiring', 1,
//     {membership_id, user_id, library_id, threshold_days, valid_until}).
// threshold_days = 7 (rappel J-7) ou 0 (jour J). BICANAL au membre (COTIS-4/5,
// amendé 18/06 : le gate de circulation étant dur et sans grâce, le rappel est
// e-mail + notification in-app) ; le bandeau /conta (days_until_expiry) reste
// l'état permanent. La notif in-app part TOUJOURS (protection du membre) ;
// l'e-mail, lui, est gardé par la politique biblio (cotisation_payment_mail_-
// enabled, défaut ON).
// ============================================================================
export async function handleCotisationExpiring(payload) {
  const membershipId = String(payload?.membership_id || "").trim();
  if (!membershipId) throw new Error("membership_id manquant.");
  const threshold = Number(payload?.threshold_days);
  const validUntil = String(payload?.valid_until || "").trim();

  const { data: m, error: e1 } = await supabaseAdmin
    .from("user_library_memberships")
    .select("id,user_id,library_id,status")
    .eq("id", membershipId)
    .maybeSingle();
  if (e1) throw e1;
  if (!m) throw new Error("Associação não encontrada.");
  // Garde : ne notifier que si l'appartenance est toujours active.
  if (m.status !== "active") {
    return { user_result: skippedEmailResult("user_mail", "membership_not_active") };
  }

  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", m.user_id)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error("Perfil não encontrado.");

  const ctx = await resolveLibraryNotificationContext(String(m.library_id || "").trim() || null);
  const bt = subjectTag(ctx);
  const locale = String(profile?.preferred_language || "").trim() || null;
  const libName = String(ctx?.library_name || ctx?.library_short_name || "").trim() || "—";
  const dateStr = formatDateLocale(validUntil, locale) || formatDateBR(validUntil) || validUntil;

  const base = threshold === 0 ? "cotisation.expiring_today" : "cotisation.expiring";
  const tit = tMail(locale, `${base}.subject`);
  const intro = tMail(locale, `${base}.intro`, { library: libName, date: dateStr });

  // (in-app) Réplique in-app B3 du rappel d'expiration — émise EN PREMIER et
  // TOUJOURS (protection du membre, décision 18/06). COTIS-5 : le gate de
  // circulation étant DUR et sans période de grâce, la notif in-app part à
  // J-7/J-0 MÊME SI la biblio a désactivé l'e-mail de cotisation (le drapeau
  // cotisation_payment_mail_enabled ne gouverne QUE l'e-mail). Catégorie 'alerta'
  // (libellée dans les 10 locales), titre/corps pré-rendus dans la langue du
  // membre (patron réplique restriction/gel). Best-effort : un échec n'invalide
  // pas le reste. Le bandeau /conta reste l'état permanent.
  let inapp_result = null;
  try {
    const { error: eIn } = await supabaseAdmin.from("user_notifications").insert({
      user_id: m.user_id,
      library_id: m.library_id || null,
      category: "alerta",
      title: tit,
      body: intro
    });
    inapp_result = eIn ? { ok: false, error: eIn.message } : { ok: true };
  } catch (eIn) {
    inapp_result = { ok: false, error: String(eIn?.message || eIn) };
  }

  // E-mail : gardé par la politique biblio (cotisation_payment_mail_enabled,
  // défaut ON). Contrairement à la notif in-app ci-dessus, l'e-mail peut être
  // coupé par la biblio.
  const { data: pol } = await supabaseAdmin
    .from("library_notification_policies")
    .select("cotisation_payment_mail_enabled")
    .eq("library_id", m.library_id)
    .maybeSingle();
  if (pol && pol.cotisation_payment_mail_enabled === false) {
    return { inapp_result, user_result: skippedEmailResult("user_mail", "cotisation_mail_disabled") };
  }

  const user = userTargetFromProfile(profile);
  if (!user?.email) {
    return { inapp_result, user_result: skippedEmailResult("user_mail", "no_recipient_email") };
  }

  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, user?.name),
    introHtml: `<p>${intro}</p>`,
    actionBox: {
      kind: "action",
      title: tMail(locale, "validation_confirmed.actionTitle"),
      ctaUrl: `${APP_BASE_URL}/conta`,
      ctaLabel: tMail(locale, "validation_confirmed.cta")
    },
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
  const user_result = await safeSendEmail(user, sub, html, text, "user_mail", ctx);
  return { user_result, inapp_result };
}
