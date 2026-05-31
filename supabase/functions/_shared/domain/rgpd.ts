import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, skippedEmailResult, userTargetFromProfile } from "../transport/email.ts";
import { greeting, tMail } from "../i18n/mail-strings.ts";

// ============================================================================
// Handler RGPD — préavis de purge de données (Spec §7.1, phase 2)
// ----------------------------------------------------------------------------
// Émis par la chaîne SQL fn_notify_users_before_purge → fn_dispatch_rgpd_warning
// (cf. migration 20260531150000_rgpd_dispatch_phase1_sql.sql) sur les événements :
//   - rgpd_purge_warning_loans
//   - rgpd_purge_warning_reservations
//   - rgpd_purge_warning_consultations
//
// Pour chaque ligne user_notifications créée par la phase 1, ce handler :
//   1. lit la notification (user_id, library_id, category)
//   2. récupère le profil → locale, email, prénom
//   3. résout le contexte mail biblio (identité, branding, locale par défaut)
//   4. construit le mail dans la langue préférée de la lectrice (fallback pt-BR)
//   5. envoie via safeSendEmail
//
// Doctrine B (Spec) : l'in-app est déjà en place via la phase 1 ; ce handler
// ajoute le canal e-mail comme canal primaire légal. Les deux canaux sont
// désormais émis en parallèle pour chaque préavis RGPD.
//
// Pas de mail admin : la RGPD est une affaire entre la lectrice et le système,
// pas un événement staff à doubler côté painel.
// ============================================================================

const CATEGORY_FROM_EVENT: Record<string, string> = {
  rgpd_purge_warning_loans: "rgpd_retention_loans",
  rgpd_purge_warning_reservations: "rgpd_retention_reservations",
  rgpd_purge_warning_consultations: "rgpd_retention_consultations",
};

const CATEGORY_LABEL_KEY: Record<string, string> = {
  rgpd_retention_loans: "rgpd.purge.loans",
  rgpd_retention_reservations: "rgpd.purge.reservations",
  rgpd_retention_consultations: "rgpd.purge.consultations",
};

export async function handleRgpdPurgeWarning(recordId: number, event: string) {
  // 1. Lecture de la notification créée par la phase 1
  const { data: notif, error: e1 } = await supabaseAdmin
    .from("user_notifications")
    .select("id, user_id, library_id, category")
    .eq("id", recordId)
    .maybeSingle();
  if (e1) throw e1;
  if (!notif) throw new Error(`RGPD: user_notification ${recordId} non trouvée`);

  // Sanity check : event doit correspondre à la catégorie en base
  const expectedCategory = CATEGORY_FROM_EVENT[event];
  if (expectedCategory && notif.category !== expectedCategory) {
    console.warn(
      `[rgpd] event=${event} attendait category=${expectedCategory}, ` +
      `trouvé ${notif.category} pour notification id=${recordId}`
    );
  }

  // 2. Récupération du profil (email + locale)
  const { data: profile, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id, email, first_name, last_name, preferred_language, default_library_id")
    .eq("id", notif.user_id)
    .maybeSingle();
  if (e2) throw e2;
  if (!profile) throw new Error(`RGPD: profil ${notif.user_id} non trouvé`);

  // 3. Contexte mail biblio (utilise library_id de la notif ou fallback profil)
  const libraryId = String(notif.library_id || profile.default_library_id || "").trim() || null;
  const ctx = await resolveLibraryNotificationContext(libraryId);

  // 4. Locale lectrice (priorité), fallback locale biblio, fallback pt-BR
  const locale = String(profile?.preferred_language || "").trim() || null;

  // 5. Cible mail
  const user = userTargetFromProfile(profile);
  if (!user) {
    console.warn(`[rgpd] notification ${recordId}: profil ${notif.user_id} sans email valide, mail skippé`);
    return {
      user_result: skippedEmailResult("rgpd_purge_warning", "empty_email"),
    };
  }

  // 6. Construction du mail
  const categoryKey = CATEGORY_LABEL_KEY[notif.category] || "rgpd.purge.generic";
  const bt = subjectTag(ctx);

  const title = tMail(locale, `${categoryKey}.title`);
  const introHtml = `<p>${tMail(locale, `${categoryKey}.intro`)}</p>` +
                    `<p>${tMail(locale, "rgpd.purge.windowExplain")}</p>` +
                    `<p>${tMail(locale, "rgpd.purge.howToCancel")}</p>`;

  const { html, text } = renderEmail({
    locale,
    preheader: title,
    title,
    greeting: greeting(locale, user.name),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx,
  });

  const subject = applyBrandingText(`${title} — BLMF`.replace(/BLMF/g, bt), ctx);

  // 7. Envoi inconditionnel (pas de policy biblio désactivable — Spec §4.6)
  const user_result = await safeSendEmail(user, subject, html, text, "rgpd_purge_warning", ctx);

  return { user_result };
}
