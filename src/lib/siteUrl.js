// ═══════════════════════════════════════════════════════════
// Adresse du site de présentation (la « vitrine ») — foyer UNIQUE côté front.
//
// anarbib.org est le domaine canonique ; anarbib.is et anarbib.org.br sont des
// routes de repli qui redirigent vers lui (REGISTRE OPS-10). Le jour où le
// canonique change, c'est cette valeur qui change — par la variable de build
// VITE_SITE_URL, sans toucher au code ni aux dix locales, qui ne portent que
// des CHEMINS (« /fr/accueil/ »). Une instance auto-hébergée qui a son propre
// site règle la même variable.
//
// Garde : src/tests/site-url-unique.test.js refuse « https://anarbib.org » écrit
// ailleurs qu'ici (et que dans son jumeau des Edge Functions,
// supabase/functions/_shared/core/site-url.ts).
// ═══════════════════════════════════════════════════════════

export const SITE_BASE_URL = String(import.meta.env?.VITE_SITE_URL || 'https://anarbib.org').replace(/\/+$/, '');

/** Adresse complète d'une page de la vitrine à partir de son chemin (« /fr/accueil/ »). */
export function siteUrl(path = '/') {
  const p = String(path || '/');
  return SITE_BASE_URL + (p.startsWith('/') ? p : '/' + p);
}
