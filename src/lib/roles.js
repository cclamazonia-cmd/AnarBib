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

// ── Permissions de gouvernance d'équipe (Lot 5 / Phase B) ───
//
// Ces helpers seront utilisés par <TeamPanel /> en Phase B pour décider
// d'afficher ou non les boutons d'action sur chaque ligne.
//
// IMPORTANT : ces helpers donnent la permission "scope-level" (ai-je le
// droit de gérer DES équipes ?). La permission "row-level" (ai-je le
// droit d'agir sur CETTE ligne précise ?) dépend en plus de :
//   - role de la cible (un coord ne peut pas modifier un autre coord)
//   - lien utilisateur·ice ↔ bibliothèque (un coord BLMF ne peut pas
//     modifier l'équipe d'une autre bibli)
//   - cas particuliers (self-demote toujours autorisé pour soi-même)
//
// La logique row-level vit dans <TeamPanel /> directement, en Phase B.

/** Peut gérer l'équipe d'une bibliothèque (≥ coord). */
export function canManageTeam(role) {
  return isCoord(role);
}

/** Peut gérer les équipes du réseau (admin uniquement). */
export function canManageNetworkTeam(role) {
  return isAdmin(role);
}

// ── Helpers d'affichage ──────────────────────────────────────
//
// Ces helpers ne déterminent pas des permissions mais aident l'UI à
// rendre les rôles et statuts de façon cohérente partout.

/**
 * Ordre de tri des rôles, du plus de droits au moins (utilisé pour
 * afficher les listes du staff "admin d'abord, librarian en dernier").
 * Les rôles inconnus tombent à 0.
 */
export function roleSortOrder(role) {
  const order = { administrador: 4, coordenador: 3, librarian: 2, reader: 1 };
  return order[role] || 0;
}

/**
 * Renvoie le nom de la clé i18n pour le label d'un status de membership.
 * Convention : team.status.{status}
 *   - active         : actif·ve
 *   - suspended      : suspendu·e (is_restricted=true OU status='suspended')
 *   - pending_removal: en cours de retrait (carence 7j non écoulée)
 *   - inactive       : inactif·ve (260+ jours sans connexion)
 *   - removed        : retiré·e (carence écoulée, fn_cron a fait son travail)
 */
export function statusLabel(status) {
  return `team.status.${status || 'active'}`;
}

/**
 * Renvoie le kind de pill (.cat-pill X) à utiliser pour un status donné.
 * Cohérent avec la convention visuelle existante :
 *   - ok      : vert (.cat-pill ok) — actif
 *   - warn    : jaune (.cat-pill warn) — suspendu, pending_removal, inactif
 *   - danger  : rouge (.cat-pill danger) — removed
 */
export function statusBadgeKind(status) {
  switch (status) {
    case 'active': return 'ok';
    case 'suspended': return 'warn';
    case 'pending_removal': return 'warn';
    case 'inactive': return 'warn';
    case 'removed': return 'danger';
    default: return 'info';
  }
}
