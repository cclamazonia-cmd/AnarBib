// ============================================================================
// src/lib/roles.js
// ============================================================================
//
// Helpers centralisés pour la hiérarchie des rôles AnarBib.
//
// Hiérarchie (du moins au plus de droits) :
//   - reader        : lecteur·rice ordinaire (1 biblio, droits utilisateur de base)
//   - librarian     : bibliothécaire (gère le quotidien d'une biblio)
//   - coordenador   : coordinateur·rice (gère orga + paramètres d'une biblio)
//   - administrador : admin AnarBib cross-biblio (Xavier pour l'instant)
//
// Convention : tous les helpers acceptent role=null/undefined sans crasher
// (retournent false). Permet d'appeler en sécurité même si le contexte
// n'a pas encore chargé le rôle.
//
// Source de vérité unique. Si on change la spec rôles, c'est ici qu'on agit
// — toutes les pages utilisent ces helpers via import.
// ============================================================================

// ── Tests de rôle hiérarchiques (cumulatifs) ─────────────────

/** Tout user authentifié avec un rôle reconnu. */
export function isReader(role) {
  return role === 'reader' || isLibrarian(role);
}

/** ≥ bibliothécaire (librarian, coordenador ou administrador). */
export function isLibrarian(role) {
  return role === 'librarian' || isCoord(role);
}

/** ≥ coordinateur·rice (coordenador ou administrador). */
export function isCoord(role) {
  return role === 'coordenador' || isAdmin(role);
}

/** Admin AnarBib uniquement. */
export function isAdmin(role) {
  return role === 'administrador';
}

// ── Permissions par page de navigation ───────────────────────
//
// Convention : `canSeeXxx(role)` = a-t-on le droit d'accéder à la page Xxx ?
// Utilisé par la Topbar pour afficher conditionnellement les liens.

/** Accès au catalogue : tout le monde, même anonyme. */
export function canSeeCatalog(_role) {
  return true;
}

/** Accès à /conta : tout user authentifié. */
export function canSeeAccount(role) {
  return Boolean(role); // role !== null/undefined = authentifié
}

/** Accès à /painel : ≥ librarian. */
export function canSeePainel(role) {
  return isLibrarian(role);
}

/** Accès à /catalogacao : ≥ librarian. */
export function canSeeCatalogacao(role) {
  return isLibrarian(role);
}

/** Accès à /importacoes : ≥ coordenador. */
export function canSeeImportacoes(role) {
  return isCoord(role);
}

/** Accès à /biblioteca : ≥ coordenador. */
export function canSeeBiblioteca(role) {
  return isCoord(role);
}

/** Accès à /rede : administrador AnarBib uniquement. */
export function canSeeRede(role) {
  return isAdmin(role);
}
