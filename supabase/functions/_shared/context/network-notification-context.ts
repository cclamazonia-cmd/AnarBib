// ============================================================================
// network-notification-context.ts — Contexte de notification pour events network.*
// ============================================================================
// Spec de référence : docs/specs/spec-administrateur-reseau.md v0.3
// Spec d'implémentation : docs/specs/spec-implementation-114a-network-cooptation.md
//
// Le réseau AnarBib est une entité politique transverse, indépendante des biblios
// individuelles. Les mails de gouvernance réseau (cooptation, retrait collectif)
// utilisent leur propre branding "Rede AnarBib", distinct des branding par biblio.
//
// Implémentation actuelle : retourne un fallback hardcodé sur la base du fallback
// biblio existant, avec branding "Rede AnarBib" forcé. Les variables d'env
// NETWORK_* (LOGO_URL, FOOTER_TEXT, SENDER_NAME, etc.) sont déjà lues par les
// chaînes de fallback dans env.ts, donc le contexte hérite automatiquement de
// ces réglages s'ils sont définis dans les secrets EF.
//
// Évolution future (TODO backlog) : créer une vue DB `v_network_notification_context`
// (équivalent réseau de `v_library_notification_context`) que ce helper pourra
// interroger pour permettre un branding réseau configurable depuis la DB.
// La signature `async` est déjà en place pour ce hook futur.
// ============================================================================
import { fallbackLibraryNotificationContext, normalizeLibraryNotificationContext } from "./library-notification-context.ts";
// import { supabaseAdmin } from "../core/env.ts";  // décommenter avec le hook DB futur

export async function resolveNetworkNotificationContext() {
  // TODO #114.future : quand v_network_notification_context existera, décommenter :
  // try {
  //   const { data, error } = await supabaseAdmin
  //     .from("v_network_notification_context")
  //     .select("*")
  //     .maybeSingle();
  //   if (!error && data) return normalizeLibraryNotificationContext(data, null);
  // } catch (e) {
  //   console.warn("resolveNetworkNotificationContext fallback:", e);
  // }

  // Fallback : ctx biblio neutre + override branding réseau
  const base = fallbackLibraryNotificationContext(null);
  return {
    ...base,
    library_id: null,
    slug: null,
    library_name: "Rede AnarBib",
    library_short_name: "Rede AnarBib",
    // Le reste hérite du fallback, qui lit déjà les fallbacks env :
    // NETWORK_LOGO_URL, NETWORK_FOOTER_TEXT, NETWORK_SENDER_NAME, etc.
    // via les chaînes BRAND_NAME / FOOTER_TEXT / LOGO_URL définies dans env.ts.
  };
}
