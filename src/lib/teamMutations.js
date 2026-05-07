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
//   - quitAdminFunctions  : self-demote depuis admin avec garde-fou last admin
//   - promoteToAdministrador : promotion d'un staff existant en admin
//   - requestRemoveMember : retrait avec carence 7j (raison obligatoire)
//   - cancelRemoveMember  : annule le retrait pendant la carence
//
// Convention : chaque mutation retourne { success: bool, error?: string,
// data?: any }. Le caller décide quoi faire (toast, refresh, fermer modale).
// ============================================================================

import { useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';

export const LAST_ADMIN_CONFIRM_PHRASE = 'JE FERME LA GOUVERNANCE ANARBIB';

export function useTeamMutations() {
  const [loading, setLoading] = useState(false);

  // Wrapper commun
  const callRpc = useCallback(async (rpcName, params) => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc(rpcName, params);
      if (error) {
        // Détecter spécifiquement le code last_admin_lockdown
        const msg = error.message || '';
        if (msg.includes('last_admin_lockdown')) {
          return {
            success: false,
            error: 'last_admin_lockdown',
            message: msg,
          };
        }
        return {
          success: false,
          error: error.code || 'rpc_error',
          message: msg || 'Erreur RPC inconnue',
        };
      }
      // Format Lot 5 : { ok: true, ... } ou { success: true, ... }
      // (les RPCs anciennes utilisent 'ok', les nouvelles 'success')
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

  // ─── Phase B1 : promotions ────────────────────────────
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

  // ─── Phase B1 : self-demote (non-admin) ───────────────
  const selfDemote = useCallback(
    (libraryId, targetRole = 'librarian') => callRpc('fn_team_self_demote', {
      p_library_id: libraryId,
      p_target_role: targetRole,
    }),
    [callRpc]
  );

  // ─── Phase B1 : suspension ────────────────────────────
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

  // ─── Phase B2 : quitter ses fonctions d'admin ─────────
  // Wrapper qui appelle fn_team_self_demote avec le 3ème paramètre.
  // Si le caller n'est pas le dernier admin, confirmPhrase peut être null.
  // Si le caller est le dernier admin, confirmPhrase doit valoir
  // LAST_ADMIN_CONFIRM_PHRASE exactement (sinon la DB renvoie last_admin_lockdown).
  const quitAdminFunctions = useCallback(
    (libraryId, confirmPhrase = null, targetRole = 'librarian') =>
      callRpc('fn_team_self_demote', {
        p_library_id: libraryId,
        p_target_role: targetRole,
        p_confirm_close_governance: confirmPhrase,
      }),
    [callRpc]
  );

  // ─── Phase B2 : promotion administrador ───────────────
  const promoteToAdministrador = useCallback(
    (userId, libraryId) => callRpc('fn_team_promote_to_administrador', {
      p_user_id: userId,
      p_library_id: libraryId,
    }),
    [callRpc]
  );

  // ─── Phase B2 : retraits avec carence 7j ──────────────
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

  return {
    loading,
    // Phase B1
    promoteToLibrarian,
    promoteToCoordenador,
    selfDemote,
    suspendMember,
    unsuspendMember,
    // Phase B2
    quitAdminFunctions,
    promoteToAdministrador,
    requestRemoveMember,
    cancelRemoveMember,
  };
}
