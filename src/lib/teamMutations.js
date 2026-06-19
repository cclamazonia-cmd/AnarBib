// ============================================================================
// src/lib/teamMutations.js
// ============================================================================
//
// Hook React qui encapsule les appels aux RPCs fn_team_* du Lot 5 + Phase B2.
//
// Toutes les RPCs sont SECURITY DEFINER côté DB. L'UI fait juste de la
// prévention d'affichage via availableTeamActions() — si quelqu'un bypass
// l'UI, la DB rejette.
//
// Phase B1 :
//   - promoteToLibrarian, promoteToCoordenador
//   - selfDemote (non-admin)
//   - suspendMember, unsuspendMember
//
// Phase B2 (cette version) :
//   - requestRemoveMember : retrait avec carence 7j (raison obligatoire)
//   - cancelRemoveMember  : annule le retrait pendant la carence
//
// F.3 v0.3 (13/05/2026) : suppression des wrappers obsoletes lies au role
// local 'administrador' supprime en F.1 :
//   - LAST_ADMIN_CONFIRM_PHRASE export (plus utilise)
//   - quitAdminFunctions wrapper (la branche A de fn_team_self_demote a
//     ete supprimee en F.3 backend)
//   - promoteToAdministrador wrapper (RPC depreciee en D.8)
//
// L'auto-retrait d'un admin reseau passe desormais par les RPC
// fn_network_admin_* (cf. AdminsPanel et modals collectiveRemoval).
//
// Convention : chaque mutation retourne { success: bool, error?: string,
// data?: any }. Le caller décide quoi faire (toast, refresh, fermer modale).
// ============================================================================

import { useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';

export function useTeamMutations() {
  const [loading, setLoading] = useState(false);

  // Wrapper commun
  const callRpc = useCallback(async (rpcName, params) => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc(rpcName, params);
      if (error) {
        return {
          success: false,
          error: error.code || 'rpc_error',
          message: error.message || 'Erreur RPC inconnue',
        };
      }
      // Format Lot 5 : { ok: true, ... } ou { success: true, ... }
      if (data && typeof data === 'object') {
        if ('ok' in data) {
          return { success: data.ok, ...data };
        }
        if ('success' in data) {
          return data;
        }
      }
      return { success: true, data };
    } catch (err) {
      return {
        success: false,
        error: 'exception',
        message: err.message || String(err),
      };
    } finally {
      setLoading(false);
    }
  }, []);

  // ─── Phase B1 : promotions ─────────────────────────────────────────────
  const promoteToLibrarian = useCallback(
    (userId, libraryId) => callRpc('fn_team_promote_to_librarian', {
      p_user_id: userId,
      p_library_id: libraryId,
    }),
    [callRpc]
  );

  const promoteToCoordenador = useCallback(
    (userId, libraryId) => callRpc('fn_team_promote_to_coordenador', {
      p_user_id: userId,
      p_library_id: libraryId,
    }),
    [callRpc]
  );

  // ─── Phase B1 : self-demote ─────────────────────────────────────────────
  const selfDemote = useCallback(
    (libraryId, targetRole = 'librarian') => callRpc('fn_team_self_demote', {
      p_library_id: libraryId,
      p_target_role: targetRole,
    }),
    [callRpc]
  );

  // ─── Phase B1 : suspension ─────────────────────────────────────────────
  const suspendMember = useCallback(
    (userId, libraryId, role, reason) => callRpc('fn_team_suspend_member', {
      p_user_id: userId,
      p_library_id: libraryId,
      p_role: role,
      p_reason: reason,
    }),
    [callRpc]
  );

  const unsuspendMember = useCallback(
    (userId, libraryId, role) => callRpc('fn_team_unsuspend_member', {
      p_user_id: userId,
      p_library_id: libraryId,
      p_role: role,
    }),
    [callRpc]
  );

  // ─── Phase B2 : retraits avec carence 7j ─────────────────────────────
  const requestRemoveMember = useCallback(
    (userId, libraryId, role, reason) => callRpc('fn_team_request_remove_member', {
      p_user_id: userId,
      p_library_id: libraryId,
      p_role: role,
      p_reason: reason,
    }),
    [callRpc]
  );

  const cancelRemoveMember = useCallback(
    (userId, libraryId, role) => callRpc('fn_team_cancel_remove_member', {
      p_user_id: userId,
      p_library_id: libraryId,
      p_role: role,
    }),
    [callRpc]
  );

  // ─── Lot 3 : accueil dans l'équipe (invitations) ──────────────────────
  // Cooptation collégiale (voie médiane : librarian propose, ≥1 coordenador
  // requis pour aboutir). RPC en schéma public (SECURITY DEFINER).
  const proposeInvitation = useCallback(
    (libraryId, invitedPublicId, role = 'librarian') => callRpc('fn_team_propose_invitation', {
      p_library_id: libraryId,
      p_invited_public_id: invitedPublicId,
      p_role: role,
    }),
    [callRpc]
  );

  const ratifyInvitation = useCallback(
    (invitationId) => callRpc('fn_team_ratify_invitation', {
      p_invitation_id: invitationId,
    }),
    [callRpc]
  );

  const acceptInvitation = useCallback(
    (invitationId) => callRpc('fn_team_accept_invitation', {
      p_invitation_id: invitationId,
    }),
    [callRpc]
  );

  const declineInvitation = useCallback(
    (invitationId) => callRpc('fn_team_decline_invitation', {
      p_invitation_id: invitationId,
    }),
    [callRpc]
  );

  const revokeInvitation = useCallback(
    (invitationId, reason = null) => callRpc('fn_team_revoke_invitation', {
      p_invitation_id: invitationId,
      p_reason: reason,
    }),
    [callRpc]
  );

  return {
    loading,
    // Phase B1
    promoteToLibrarian,
    promoteToCoordenador,
    selfDemote,
    suspendMember,
    unsuspendMember,
    // Phase B2
    requestRemoveMember,
    cancelRemoveMember,
    // Lot 3 : invitations
    proposeInvitation,
    ratifyInvitation,
    acceptInvitation,
    declineInvitation,
    revokeInvitation,
  };
}
