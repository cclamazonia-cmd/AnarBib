// src/contexts/libraryPatch.js — un réglage de bibliothèque changé à l'écran se
// voit tout de suite dans les écrans qui lisent le contexte (29/09/2026).
//
// LE CONSTAT. Le contexte de bibliothèque (LibraryContext) est chargé une fois,
// à la connexion ou au chargement de la page, puis gardé en sessionStorage.
// « Mon compte » et le tableau de bord y lisent `membership_enabled`,
// `reader_cards_enabled`… pour décider de ce qu'ils montrent. Un interrupteur
// basculé dans la page Bibliothèque écrivait en base et mettait à jour SA page,
// pas le contexte : la cotisation réactivée pour la BLMF le 29/09 n'apparaissait
// nulle part ailleurs avant un rechargement complet (constat de Xavier).
//
// LA RÈGLE. Seuls les réglages que le contexte porte déjà se reportent, par
// liste fermée ; rien d'autre n'y entre par ce chemin (ni rôle, ni identité de
// la bibliothèque). Le report ne touche le contexte COURANT que si la
// bibliothèque réglée est la bibliothèque active ; la liste des adhésions est
// mise à jour dans tous les cas, pour qu'un changement de bibliothèque active
// (setLibrary) reparte de la bonne valeur.

export const REGLAGES_DU_CONTEXTE = [
  'catalog_mode',
  'circulation_mode',
  'network_mode',
  'governance_mode',
  'membership_enabled',
  'reader_cards_enabled',
  'allow_direct_coordenador',
];

const BOOLEENS = new Set(['membership_enabled', 'reader_cards_enabled', 'allow_direct_coordenador']);

// Rend { ctx, libraries } mis à jour — ou les MÊMES références quand rien ne
// change, pour ne provoquer aucun rendu inutile.
export function appliquerReglage(ctx, libraries, libraryId, fields) {
  if (!libraryId || !fields || typeof fields !== 'object') return { ctx, libraries };
  const propre = {};
  for (const [cle, valeur] of Object.entries(fields)) {
    if (!REGLAGES_DU_CONTEXTE.includes(cle)) continue;
    if (BOOLEENS.has(cle)) propre[cle] = valeur === true;
    else if (typeof valeur === 'string' && valeur) propre[cle] = valeur;
  }
  if (Object.keys(propre).length === 0) return { ctx, libraries };

  const liste = Array.isArray(libraries) ? libraries : [];
  const touchee = liste.some(m => m?.libraries?.id === libraryId);
  const nextLibraries = touchee
    ? liste.map(m => (m?.libraries?.id === libraryId ? { ...m, libraries: { ...m.libraries, ...propre } } : m))
    : libraries;

  const active = ctx && ctx.libraryId === libraryId;
  const change = active && Object.entries(propre).some(([cle, valeur]) => ctx[cle] !== valeur);
  const nextCtx = change ? { ...ctx, ...propre } : ctx;
  return { ctx: nextCtx, libraries: nextLibraries };
}
