// ============================================================================
// src/lib/roles.js
// ============================================================================
//
// Helpers centralisés pour la hiérarchie des rôles AnarBib.
//
// Hiérarchie locale (du moins au plus de droits) :
//   - reader        : lecteur·rice ordinaire
//   - librarian     : bibliothécaire
//   - coordenador   : coordinateur·rice (per-library) — sommet de la hiérarchie
//                     locale depuis F.1 (suppression du role 'administrador').
//
// L'admin réseau (cross-biblio) est désormais un concept séparé, transverse,
// stocké dans la table network_administrators et exposé par LibraryContext
// via le flag booléen isNetworkAdmin. Les helpers de permission liés au
// réseau prennent ce flag en argument, pas le rôle local.
//
// Convention : tous les helpers acceptent role=null/undefined sans crasher
// (retournent false). Permet d'appeler en sécurité même si le contexte
// n'a pas encore chargé le rôle.
//
// F.4 v0.3 (13/05/2026) : finalisation chantier admin réseau v0.3.
//   - Suppression isAdmin(role) (le role local 'administrador' n'existe
//     plus depuis F.1, schéma + fonctions DB nettoyées en F.2.bis et F.3).
//   - Suppression canManageNetworkTeam(role) (mort code post-F.1).
//   - canSeeRede prend désormais isNetworkAdmin (booléen) au lieu de role.
//   - isCoord simplifié (plus de cascade vers isAdmin).
//   - roleSortOrder : retrait de 'administrador' (orphelin).
//   - availableTeamActions : retrait du bloc 'quit_admin_functions' (mort
//     code post-F.3) + retrait du garde-fou targetRole='administrador'.
// ============================================================================

// ── Tests de rôle hiérarchiques (cumulatifs) ─────────────────────

export function isReader(role) {
  return role === 'reader' || isLibrarian(role);
}

export function isLibrarian(role) {
  return role === 'librarian' || isCoord(role);
}

export function isCoord(role) {
  return role === 'coordenador';
}

// ── Permissions par page de navigation ──────────────────────────

export function canSeeCatalog(_role) { return true; }
export function canSeeAccount(role) { return Boolean(role); }
export function canSeePainel(role) { return isLibrarian(role); }
export function canSeeCatalogacao(role) { return isLibrarian(role); }
export function canSeeImportacoes(role) { return isCoord(role); }
export function canSeeBiblioteca(role) { return isCoord(role); }

// canSeeFederacao : face fédération (cercles). Voir = tout membre rattaché à
// une biblio (FED-2, « voir ≠ agir ») ; agir est gardé coordenador côté RPC.
// Distinct de isNetworkAdmin (la fédération n'est pas de l'admin réseau).
export function canSeeFederacao(role) { return Boolean(role); }

// canSeeRede : prend isNetworkAdmin (booléen depuis LibraryContext),
// PAS le role local. Doctrine v0.3 : la page Rede est le périmètre des
// admins réseau, pas des admins locaux (qui n'existent plus).
export function canSeeRede(isNetworkAdmin) { return Boolean(isNetworkAdmin); }

// ── Permissions de gouvernance d'équipe ─────────────────────────

export function canManageTeam(role) { return isCoord(role); }

// ── Helpers d'affichage ─────────────────────────────────────────

export function roleSortOrder(role) {
  const order = { coordenador: 3, librarian: 2, reader: 1 };
  return order[role] || 0;
}

export function statusLabel(status) {
  return `team.status.${status || 'active'}`;
}

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

// ── Permissions row-level pour les actions de gouvernance ───
//
// Phase B1 : promote_to_librarian, propose_coordenador, self_demote,
//            suspend, unsuspend
// Phase B2 : ajout de
//            - request_remove          (sur staff actif)
//            - cancel_remove           (sur staff pending_removal)
//
// F.4 v0.3 : suppression de l'action 'quit_admin_functions' (le role
// local 'administrador' n'existe plus depuis F.1). L'auto-retrait d'un
// admin réseau passe désormais par fn_network_admin_self_remove (RPC
// dédiée appelée depuis AdminsPanel).
//
// Conventions :
//   - Self-demote : un coord se rétrograde en librarian (dans le contexte
//     library uniquement).
//   - Hiérarchie stricte : un coord ne peut pas modifier un autre coord.
//   - Tout est validé côté DB par les RPCs SECURITY DEFINER.

/**
 * @param {object} ctx
 * @param {string} ctx.observerRole       Rôle de l'utilisateur courant
 * @param {string} ctx.observerUserId     ID de l'utilisateur courant
 * @param {string} ctx.targetRole         Rôle de la cible
 * @param {string} ctx.targetUserId       user_id de la cible
 * @param {string} ctx.targetStatus       active | suspended | pending_removal | inactive | removed
 * @param {boolean} ctx.targetHasPendingRemoval  true si pending_removal_until futur
 * @param {string} ctx.scope              'library' | 'network'
 *
 * @returns {Array<{action, label, kind, requiresReason}>}
 */
export function availableTeamActions(ctx) {
  const {
    observerRole,
    observerUserId,
    targetRole,
    targetUserId,
    targetStatus,
    targetHasPendingRemoval,
    scope,
  } = ctx || {};

  const actions = [];
  const isSelf = observerUserId && targetUserId && observerUserId === targetUserId;
  const observerCanManage = isCoord(observerRole);

  // Si pas de droit de gestion ET pas soi-même → pas d'actions
  if (!observerCanManage && !isSelf) return actions;

  // ─── Cas particulier : actions sur soi-même ───
  if (isSelf) {
    // self-demote : un coord se rétrograde en librarian
    // → uniquement dans le contexte de la lib (BibliotecaPage onglet équipe)
    if (
      targetRole === 'coordenador'
      && targetStatus === 'active'
      && scope === 'library'
    ) {
      actions.push({
        action: 'self_demote',
        label: 'team.action.selfDemote',
        kind: 'secondary',
        requiresReason: false,
      });
    }
    // Pas de promote/suspend/unsuspend/remove sur soi-même
    return actions;
  }

  // ─── À partir d'ici : observer ≠ target ───

  // Hiérarchie stricte : un coord ne peut agir que sur reader/librarian
  const targetRank = roleSortOrder(targetRole);
  const observerRank = roleSortOrder(observerRole);
  if (targetRank >= observerRank) return actions;

  // ─── Actions selon le status courant de la cible ───
  if (targetStatus === 'active' && !targetHasPendingRemoval) {
    // Promotion
    if (targetRole === 'reader') {
      actions.push({
        action: 'promote_to_librarian',
        label: 'team.action.promoteToLibrarian',
        kind: 'primary',
        requiresReason: false,
      });
    } else if (targetRole === 'librarian') {
      // Collégialité (migration 20260826120000) : ce n'est plus une promotion
      // immédiate mais une proposition soumise à ratification puis acceptation.
      actions.push({
        action: 'propose_coordenador',
        label: 'team.action.proposeCoordenador',
        kind: 'primary',
        requiresReason: false,
      });
    }
    // Suspension
    if (targetRole === 'librarian' || targetRole === 'coordenador') {
      actions.push({
        action: 'suspend',
        label: 'team.action.suspend',
        kind: 'warning',
        requiresReason: true,
      });
    }
    // Phase B2 : demande de retrait avec carence 7j
    if (targetRole === 'librarian' || targetRole === 'coordenador') {
      actions.push({
        action: 'request_remove',
        label: 'team.action.requestRemove',
        kind: 'danger',
        requiresReason: true,
      });
    }
  } else if (targetStatus === 'suspended') {
    actions.push({
      action: 'unsuspend',
      label: 'team.action.unsuspend',
      kind: 'primary',
      requiresReason: false,
    });
  } else if (targetStatus === 'pending_removal' || targetHasPendingRemoval) {
    // Phase B2 : annuler le retrait pendant la carence
    actions.push({
      action: 'cancel_remove',
      label: 'team.action.cancelRemove',
      kind: 'primary',
      requiresReason: false,
    });
  }

  return actions;
}
