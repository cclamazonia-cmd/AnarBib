// ============================================================================
// app-url.ts — adresse de l'APPLICATION (le front), foyer UNIQUE côté Edge Functions.
// Jumeau de site-url.ts (la vitrine).
//
// app.anarbib.org est le canonique ; app.anarbib.is et app.anarbib.org.br sont des
// routes de repli qui servent le même bundle (REGISTRE OPS-10). Tout lien vers
// l'application écrit dans un mail part d'ici : le jour où le canonique change, ou
// sur une instance auto-hébergée, on règle le secret APP_BASE_URL — et rien d'autre.
//
// Module SANS effet de bord (pas de client supabase, pas de clé) : les fonctions
// autonomes comme `register` l'importent sans embarquer _shared/core/env.ts, qui
// le ré-exporte pour les autres. Les trois autres noms de variable sont les
// replis historiques d'env.ts, conservés à l'identique.
//
// Dette : src/tests/app-url-dette.test.js nomme les fichiers qui écrivent encore
// l'adresse en dur. La liste ne peut que rétrécir.
// ============================================================================

export const APP_BASE_URL = (Deno.env.get("APP_BASE_URL") || Deno.env.get("ANARBIB_APP_URL") || Deno.env.get("NETWORK_APP_URL") || Deno.env.get("ANARBIB_FRONTEND_URL") || "https://app.anarbib.org").trim().replace(/\/+$/, "");

/** Adresse complète d'une page de l'application à partir de son chemin (« /catalogo »). */
export function appUrl(path = "/"): string {
  const p = String(path || "/");
  return APP_BASE_URL + (p.startsWith("/") ? p : "/" + p);
}
