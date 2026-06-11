import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { APP_BASE_URL, supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { tMail, greeting } from "../i18n/mail-strings.ts";

// ============================================================================
// §21 PARTNER — NOTIF-1 : cycle de vie d'un partenariat → coordenador.
// ----------------------------------------------------------------------------
// Émis par les RPC fn_partnership_propose/accept/refuse/break via
//   fn_dispatch_notify_event('partnership_<x>', 1,
//     {partnership_id, recipient_library_id, partner_library_id}).
// record_id factice = 1 ; tout vit dans le payload (partenariats = UUID).
// Destinataire = le CONTACT de la biblio `recipient_library_id` (adminTarget) —
// même résolution que membership_validation_requested. Mail dans la locale biblio
// + branding ; lien CTA vers /biblioteca (console partenariats du·de la coordenador).
// DOC-NOTIF-1 : on notifie la coordination concernée, pas l'acteur lui-même.
// ============================================================================
const PARTNERSHIP_EVENTS = new Set([
  "partnership_proposed",
  "partnership_accepted",
  "partnership_refused",
  "partnership_broken",
]);

export function isPartnershipEvent(event: string): boolean {
  return PARTNERSHIP_EVENTS.has(event);
}

export async function handlePartnershipLifecycle(event: string, payload: any) {
  const recipientLib = String(payload?.recipient_library_id || "").trim();
  const partnerLib = String(payload?.partner_library_id || "").trim();
  if (!recipientLib) throw new Error("recipient_library_id manquant.");

  // Nom de la biblio partenaire (mentionnée dans le corps du mail).
  let partnerName = "";
  if (partnerLib) {
    const { data: pl } = await supabaseAdmin
      .from("libraries")
      .select("short_name,name")
      .eq("id", partnerLib)
      .maybeSingle();
    partnerName = String(pl?.short_name || pl?.name || "").trim();
  }

  const ctx = await resolveLibraryNotificationContext(recipientLib || null);
  const bt = subjectTag(ctx);
  const libLoc = String(ctx?.default_locale || "pt-BR").trim() || "pt-BR";

  const tit = tMail(libLoc, `${event}.subject`);
  const details = partnerName
    ? [{ label: tMail(libLoc, "partnership.partnerLabel"), value: partnerName }]
    : undefined;

  const { html, text } = renderEmail({
    locale: libLoc,
    preheader: tit,
    title: tit,
    introHtml: `<p>${tMail(libLoc, `${event}.intro`)}</p>`,
    details,
    actionBox: {
      kind: "action",
      title: tMail(libLoc, "partnership.actionTitle"),
      ctaUrl: `${APP_BASE_URL}/biblioteca`,
      ctaLabel: tMail(libLoc, "partnership.cta"),
    },
    footerHtml: footerPadrao(ctx, libLoc),
    context: ctx,
  });

  const target = adminTarget(ctx);
  if (!target?.email) {
    return { admin_result: skippedEmailResult("admin_copy", "no_recipient_email") };
  }
  const sub = applyBrandingText(`[${bt}] ${tit}`, ctx);
  const admin_result = await safeSendEmail(target, sub, html, text, "admin_copy", ctx);
  return { admin_result };
}

// ============================================================================
// §21 PARTNER — NOTIF-2 : transparence activée → inviter les lectrices communes.
// ----------------------------------------------------------------------------
// Émis par fn_partnership_set_right quand le droit `transparence` est nouvellement
// activé : fn_dispatch_notify_event('partnership_transparence_enabled', 1,
//   {partnership_id, library_a, library_b}). Fan-out ici : on notifie chaque
// lectrice MEMBRE ACTIVE DES DEUX biblios pour l'inviter à consentir au partage
// (CTA /conta). Mail lectrice (locale de la personne) ; le corps nomme les deux
// biblios. Enveloppe/branding : contexte de library_a (neutre suffirait, on garde
// simple). DOC-NOTIF-1 : on notifie les personnes concernées, pas la coordination.
// NB scaling : envoi séquentiel ; pour de très gros recouvrements, prévoir un
// découpage/queue (l'invocation a ~30 s). Suffisant à l'échelle pilote.
// ============================================================================
export async function handleTransparenceEnabled(payload: any) {
  const libA = String(payload?.library_a || "").trim();
  const libB = String(payload?.library_b || "").trim();
  if (!libA || !libB) throw new Error("library_a/library_b manquant.");

  const activeMembers = async (lib: string): Promise<Set<string>> => {
    const { data } = await supabaseAdmin
      .from("user_library_memberships")
      .select("user_id")
      .eq("library_id", lib)
      .eq("status", "active");
    return new Set((data || []).map((r: any) => String(r.user_id)));
  };
  const [setA, setB] = await Promise.all([activeMembers(libA), activeMembers(libB)]);
  const common = [...setA].filter((u) => setB.has(u));
  if (common.length === 0) {
    return { sent: 0, skipped: "no_common_readers" };
  }

  // Noms des deux biblios (corps du mail).
  const { data: libs } = await supabaseAdmin
    .from("libraries")
    .select("id,short_name,name")
    .in("id", [libA, libB]);
  const nameOf = (id: string) => {
    const l = (libs || []).find((x: any) => String(x.id) === id);
    return String(l?.short_name || l?.name || "").trim();
  };
  const libNames = [nameOf(libA), nameOf(libB)].filter(Boolean).join(" — ");

  // Enveloppe/branding : contexte de library_a (le corps nomme les deux côtés).
  const ctx = await resolveLibraryNotificationContext(libA || null);
  const bt = subjectTag(ctx);

  const { data: profiles } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .in("id", common);

  let sent = 0;
  for (const profile of profiles || []) {
    const user = userTargetFromProfile(profile);
    if (!user?.email) continue;
    const locale = String(profile?.preferred_language || "").trim() || null;
    const tit = tMail(locale, "partnership_transparence_enabled.subject");
    const details = libNames
      ? [{ label: tMail(locale, "partnership_transparence_enabled.librariesLabel"), value: libNames }]
      : undefined;
    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, user?.name),
      introHtml: `<p>${tMail(locale, "partnership_transparence_enabled.intro")}</p>`,
      details,
      actionBox: {
        kind: "action",
        title: tMail(locale, "partnership_transparence_enabled.actionTitle"),
        ctaUrl: `${APP_BASE_URL}/conta`,
        ctaLabel: tMail(locale, "partnership_transparence_enabled.cta"),
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx,
    });
    const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
    await safeSendEmail(user, sub, html, text, "user_mail", ctx);
    sent++;
  }
  return { sent, recipients: common.length };
}
