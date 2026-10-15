// =============================================================================
// supabaseUrl.js — LE résolveur de l'adresse de l'API, sans effet de bord
// =============================================================================
// Si VITE_SUPABASE_URL='auto' (mode auto-hébergé avec Caddy servant le front et
// l'API sur la même origine), l'URL est résolue dynamiquement sur
// window.location.origin. Si une URL explicite est fournie (ex :
// http://127.0.0.1:54321 pour supabase start, ou https://*.supabase.co en
// cloud), elle est STRICTEMENT respectée pour ne pas casser le flux de dev
// Supabase CLI standard.
//
// Pourquoi un module à part (15/10/2026, ticket #36 du camarade) : `supabase.js`
// lève à l'import si les variables manquent, et `npm test` tourne sans elles.
// `mapTiles.js` et `coverThumbs.js` lisaient donc `import.meta.env.VITE_SUPABASE_URL`
// en direct pour rester testables — et fabriquaient `auto/storage/v1/…` sur une
// pile auto-hébergée : Caddy rendait index.html au lieu du fichier PMTiles, la
// carte restait blanche. Ici, rien ne lève : tout module peut l'importer.
// Garde : src/tests/adresse-supabase-garde.test.js (liste fermée des lecteurs
// de la variable).
// =============================================================================

export function resolveSupabaseUrl(explicitUrl = import.meta.env.VITE_SUPABASE_URL) {
  if (explicitUrl === 'auto') {
    return typeof window !== 'undefined' && window.location?.origin
      ? window.location.origin
      : 'http://localhost';
  }
  return explicitUrl;
}
