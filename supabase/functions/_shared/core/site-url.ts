// ============================================================================
// site-url.ts — adresse du site de présentation (la « vitrine »), foyer UNIQUE
// côté Edge Functions. Jumeau de src/lib/siteUrl.js.
//
// anarbib.org est le domaine canonique, .is et .org.br des routes de repli
// (REGISTRE OPS-10). Le jour où le canonique change, on règle le secret
// SITE_BASE_URL — aucun dictionnaire de mail à rouvrir : les chaînes ne portent
// que des CHEMINS (« /fr/accueil/ »). Module SANS effet de bord (pas de client
// supabase, pas de clé) : il s'importe depuis les fonctions autonomes
// (register, notify-library-request) comme depuis les autres.
// ============================================================================

export const SITE_BASE_URL = (Deno.env.get("SITE_BASE_URL") || Deno.env.get("ANARBIB_SITE_URL") || "https://anarbib.org").trim().replace(/\/+$/, "");

/** Adresse complète d'une page de la vitrine à partir de son chemin. */
export function siteUrl(path = "/"): string {
  const p = String(path || "/");
  return SITE_BASE_URL + (p.startsWith("/") ? p : "/" + p);
}
