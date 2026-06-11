import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { APP_BASE_URL, supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult } from "../transport/email.ts";
import { tMail } from "../i18n/mail-strings.ts";

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
