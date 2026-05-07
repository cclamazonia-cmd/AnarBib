// ============================================================================
// src/lib/roles.js
// ============================================================================
//
// Helpers centralisés pour la hiérarchie des rôles AnarBib.
//
// Hiérarchie (du moins au plus de droits) :
//   - reader        : lecteur·rice ordinaire
//   - librarian     : bibliothécaire
//   - coordenador   : coordinateur·rice (per-library)
//   - administrador : admin AnarBib cross-biblio
//
// Convention : tous les helpers acceptent role=null/undefined sans crasher
// (retournent false). Permet d'appeler en sécurité même si le contexte
// n'a pas encore chargé le rôle.
// ============================================================================

// ── Tests de rôle hiérarchiques (cumulatifs) ─────────────────

export function isReader(role) {
  return role === 'reader' || isLibrarian(role);
}

export function isLibrarian(role) {
  return role === 'librarian' || isCoord(role);
}

export function isCoord(role) {
  return role === 'coordenador' || isAdmin(role);
}

export function isAdmin(role) {
  return role === 'administrador';
}

// ── Permissions par page de navigation ───────────────────────

export function canSeeCatalog(_role) { return true; }
export function canSeeAccount(role) { return Boolean(role); }
export function canSeePainel(role) { return isLibrarian(role); }
export function canSeeCatalogacao(role) { return isLibrarian(role); }
export function canSeeImportacoes(role) { return isCoord(role); }
export function canSeeBiblioteca(role) { return isCoord(role); }
export function canSeeRede(role) { return isAdmin(role); }

// ── Permissions de gouvernance d'équipe ──────────────────────

export function canManageTeam(role) { return isCoord(role); }
export function canManageNetworkTeam(role) { return isAdmin(role); }

// ── Helpers d'affichage ──────────────────────────────────────

export function roleSortOrder(role) {
  const order = { administrador: 4, coordenador: 3, librarian: 2, reader: 1 };
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
// Phase B1 : promote_to_librarian, promote_to_coordenador, self_demote,
//            suspend, unsuspend
// Phase B2 : ajout de
//            - quit_admin_functions    (self uniquement, sur ligne admin)
//            - request_remove          (sur staff non-admin actif)
//            - cancel_remove           (sur staff non-admin pending_removal)
//
// Conventions :
//   - Hors action 'quit_admin_functions', on ne touche PAS aux administradores
//     via cette UI. La gestion des admins (promotion + retrait) se fait dans
//     l'onglet admins refondu de RedePage avec un autre composant.
//   - Self-demote : non-admin uniquement (un coord se rétrograde en librarian).
//     Pour les admins, c'est 'quit_admin_functions' qui prend la suite (modale
//     spécifique avec confirmation renforcée last admin).
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
    // Filtre par scope (dual-role admin/coord, fix 07/05/2026 matin)
    // ----------------------------------------------------------------
    // Avec le modèle dual-role validé politiquement :
    //   - administrador AnarBib et coordenador d'une lib sont deux
    //     délégations DISTINCTES, matérialisées par 2 memberships séparés.
    //   - Chaque action doit s'afficher dans le bon contexte UI :
    //       * quit_admin_functions  → /rede uniquement (scope='network')
    //       * self_demote (coord→librarian) → /biblioteca (scope='library')
    //
    // Hors de ces contextes, on n'affiche rien sur la ligne soi-même
    // (l'utilisateur·rice doit aller dans le bon onglet pour agir).

    // Phase B2 : un admin peut quitter ses fonctions d'admin
    // → uniquement dans le contexte réseau (RedePage onglet Admins)
    if (
      targetRole === 'administrador'
      && targetStatus === 'active'
      && scope === 'network'
    ) {
      actions.push({
        action: 'quit_admin_functions',
        label: 'team.action.quitAdmin',
        kind: 'warning',
        requiresReason: false,
      });
    }
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

  // ─── Garde-fou admin : on ne touche pas aux admin via cette UI ───
  // (la gestion des admins se fait dans l'onglet admins refondu)
  if (targetRole === 'administrador') return actions;

  // ─── À partir d'ici : observer ≠ target, target n'est pas admin ───

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
      actions.push({
        action: 'promote_to_coordenador',
        label: 'team.action.promoteToCoordenador',
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
