// ============================================================================
// src/components/team/TeamActionModal.jsx
// ============================================================================
//
// Modale de confirmation pour une action de gouvernance d'équipe.
// Paramétrée par le type d'action + la cible. Appelle la mutation appropriée
// du hook useTeamMutations et notifie le parent du résultat.
//
// Phase B1 actions : promote_to_librarian, promote_to_coordenador,
//                    self_demote, suspend, unsuspend
// Phase B2 actions : quit_admin_functions, request_remove, cancel_remove
//                    (la promotion administrador a sa propre modale dédiée
//                     dans AdminsPanel)
//
// Cas particulier "quit_admin_functions" :
//   - Le composant interroge la DB pour savoir si l'utilisateur·rice est le
//     DERNIER admin actif du réseau.
//   - Si oui, exige la saisie exacte de 'JE FERME LA GOUVERNANCE ANARBIB'.
//   - Sinon, demande une confirmation simple renforcée.
//
// Props :
//   - isOpen        : bool
//   - onClose       : () => void
//   - onSuccess     : (result) => void
//   - onError       : (error) => void
//   - action        : { action, label, kind, requiresReason }
//   - membership    : objet membership de la cible (avec profiles + libraries)
//   - currentUserId : user_id de l'observateur·rice (pour self-actions)
//
// ============================================================================

import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import Modal from '@/components/ui/Modal';
import { useTeamMutations, LAST_ADMIN_CONFIRM_PHRASE } from '@/lib/teamMutations';

export default function TeamActionModal({
  isOpen,
  onClose,
  onSuccess,
  onError,
  action,
  membership,
  currentUserId,
}) {
  const { formatMessage: t } = useIntl();
  const mutations = useTeamMutations();
  const [reason, setReason] = useState('');
  const [confirmPhrase, setConfirmPhrase] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  const [isLastAdmin, setIsLastAdmin] = useState(null); // null = en cours, true/false
  const [adminCheckLoading, setAdminCheckLoading] = useState(false);

  // Reset interne à chaque ouverture
  useEffect(() => {
    if (isOpen) {
      setReason('');
      setConfirmPhrase('');
      setErrorMsg('');
      setIsLastAdmin(null);
    }
  }, [isOpen]);

  // ── Si action = quit_admin_functions, détecter le cas last admin ──
  useEffect(() => {
    if (!isOpen || action?.action !== 'quit_admin_functions') return;

    let cancelled = false;
    setAdminCheckLoading(true);

    (async () => {
      try {
        const { data, error } = await supabase
          .from('user_library_memberships')
          .select('user_id', { count: 'exact', head: false })
          .eq('role', 'administrador')
          .eq('status', 'active');

        if (cancelled) return;

        if (error) {
          // En cas d'erreur, on suppose conservativement qu'on est last admin
          // (fallback safe : demande la confirmation renforcée)
          setIsLastAdmin(true);
        } else {
          // Compter les admins distincts autres que soi-même
          const distinctOthers = new Set(
            (data || [])
              .map(r => r.user_id)
              .filter(uid => uid !== currentUserId)
          );
          setIsLastAdmin(distinctOthers.size === 0);
        }
      } catch (_) {
        if (!cancelled) setIsLastAdmin(true);
      } finally {
        if (!cancelled) setAdminCheckLoading(false);
      }
    })();

    return () => { cancelled = true; };
  }, [isOpen, action, currentUserId]);

  if (!isOpen || !action || !membership) return null;

  const profile = membership.profiles || {};
  const targetName = [profile.first_name, profile.last_name].filter(Boolean).join(' ')
    || profile.email
    || t({ id: 'team.unnamedMember' });
  const libraryName = membership.libraries?.short_name || membership.libraries?.name || '';

  // ── Configuration locale par type d'action ──────────
  const config = buildConfig(action.action, t, isLastAdmin);

  // ── Validations locales ─────────────────────────────
  const phraseValid = action.action !== 'quit_admin_functions'
    || !isLastAdmin
    || confirmPhrase === LAST_ADMIN_CONFIRM_PHRASE;

  const canSubmit = !mutations.loading
    && !adminCheckLoading
    && (!action.requiresReason || reason.trim().length > 0)
    && phraseValid;

  // ── Submit ──────────────────────────────────────────
  const handleConfirm = async () => {
    setErrorMsg('');

    if (action.requiresReason && !reason.trim()) {
      setErrorMsg(t({ id: 'team.modal.reason.required' }));
      return;
    }

    if (action.action === 'quit_admin_functions' && isLastAdmin && !phraseValid) {
      setErrorMsg(t({ id: 'team.modal.quitAdmin.invalidPhrase' }));
      return;
    }

    let result;
    switch (action.action) {
      case 'promote_to_librarian':
        result = await mutations.promoteToLibrarian(membership.user_id, membership.library_id);
        break;
      case 'promote_to_coordenador':
        result = await mutations.promoteToCoordenador(membership.user_id, membership.library_id);
        break;
      case 'self_demote':
        result = await mutations.selfDemote(membership.library_id, 'librarian');
        break;
      case 'quit_admin_functions':
        // Si last admin, on passe la phrase ; sinon null (la DB n'en aura pas besoin)
        result = await mutations.quitAdminFunctions(
          membership.library_id,
          isLastAdmin ? confirmPhrase : null,
          'librarian'
        );
        break;
      case 'suspend':
        result = await mutations.suspendMember(
          membership.user_id, membership.library_id, membership.role, reason.trim()
        );
        break;
      case 'unsuspend':
        result = await mutations.unsuspendMember(
          membership.user_id, membership.library_id, membership.role
        );
        break;
      case 'request_remove':
        result = await mutations.requestRemoveMember(
          membership.user_id, membership.library_id, membership.role, reason.trim()
        );
        break;
      case 'cancel_remove':
        result = await mutations.cancelRemoveMember(
          membership.user_id, membership.library_id, membership.role
        );
        break;
      default:
        setErrorMsg(t({ id: 'team.modal.error.unknownAction' }));
        return;
    }

    if (result.success) {
      onSuccess?.(result);
      onClose();
    } else {
      const dbMsg = result.message || result.error || t({ id: 'team.modal.error.generic' });
      setErrorMsg(dbMsg);
      onError?.(result);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={config.title}
      size="medium"
    >
      <div className="ab-team-modal-content">
        {/* ── Cible ── */}
        <div className="ab-team-modal-target">
          <div className="ab-team-modal-target__name">{targetName}</div>
          {profile.email && (
            <div className="ab-team-modal-target__meta">{profile.email}</div>
          )}
          {libraryName && (
            <div className="ab-team-modal-target__meta">{libraryName}</div>
          )}
        </div>

        {/* ── Loading admin check ── */}
        {action.action === 'quit_admin_functions' && adminCheckLoading && (
          <div className="ab-team-modal-description">
            {t({ id: 'common.loading' })}
          </div>
        )}

        {/* ── Description ── */}
        {!adminCheckLoading && (
          <div className={`ab-team-modal-description ab-team-modal-description--${config.kind}`}>
            {config.description}
          </div>
        )}

        {/* ── Avertissement self-demote ── */}
        {action.action === 'self_demote' && (
          <div className="ab-team-modal-warning">
            {t({ id: 'team.modal.warningSelfDemote' })}
          </div>
        )}

        {/* ── Avertissement renforcé last admin ── */}
        {action.action === 'quit_admin_functions' && isLastAdmin === true && (
          <div className="ab-team-modal-warning ab-team-modal-warning--strong">
            {t({ id: 'team.modal.quitAdmin.lastAdminWarning' })}
          </div>
        )}

        {/* ── Saisie phrase (last admin uniquement) ── */}
        {action.action === 'quit_admin_functions' && isLastAdmin === true && (
          <div className="ab-team-modal-field">
            <label htmlFor="ab-team-modal-confirm" className="ab-team-modal-label">
              {t({ id: 'team.modal.quitAdmin.confirmLabel' }, { phrase: LAST_ADMIN_CONFIRM_PHRASE })}
            </label>
            <input
              id="ab-team-modal-confirm"
              type="text"
              className="ab-team-modal-input"
              value={confirmPhrase}
              onChange={(e) => setConfirmPhrase(e.target.value)}
              placeholder={LAST_ADMIN_CONFIRM_PHRASE}
              autoComplete="off"
              autoFocus
            />
            <div className="ab-team-modal-hint">
              {t({ id: 'team.modal.quitAdmin.hint' })}
            </div>
          </div>
        )}

        {/* ── Avertissement spécifique request_remove ── */}
        {action.action === 'request_remove' && (
          <div className="ab-team-modal-warning">
            {t({ id: 'team.modal.requestRemove.cooldownNotice' })}
          </div>
        )}

        {/* ── Champ raison (si requiresReason) ── */}
        {action.requiresReason && (
          <div className="ab-team-modal-field">
            <label htmlFor="ab-team-modal-reason" className="ab-team-modal-label">
              {action.action === 'request_remove'
                ? t({ id: 'team.modal.removeReason.label' })
                : t({ id: 'team.modal.reason.label' })} *
            </label>
            <textarea
              id="ab-team-modal-reason"
              className="ab-team-modal-textarea"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder={t({ id: action.action === 'request_remove'
                ? 'team.modal.removeReason.placeholder'
                : 'team.modal.reason.placeholder' })}
              rows={3}
              maxLength={500}
              autoFocus={action.action !== 'quit_admin_functions'}
            />
            <div className="ab-team-modal-hint">
              {t({ id: 'team.modal.reason.hint' })}
            </div>
          </div>
        )}

        {/* ── Erreur ── */}
        {errorMsg && (
          <div className="ab-team-modal-error">
            {errorMsg}
          </div>
        )}

        {/* ── Actions ── */}
        <div className="ab-team-modal-actions">
          <button
            type="button"
            className="cat-btn ghost"
            onClick={onClose}
            disabled={mutations.loading}
          >
            {t({ id: 'team.modal.cancel' })}
          </button>
          <button
            type="button"
            className={`cat-btn ${config.buttonKind}`}
            onClick={handleConfirm}
            disabled={!canSubmit}
          >
            {mutations.loading
              ? t({ id: 'common.saving' })
              : config.confirmLabel}
          </button>
        </div>
      </div>
    </Modal>
  );
}

// ────────────────────────────────────────────────────────────
// Configuration par type d'action
// ────────────────────────────────────────────────────────────

function buildConfig(actionType, t, isLastAdmin) {
  switch (actionType) {
    case 'promote_to_librarian':
      return {
        title: t({ id: 'team.modal.title.promoteToLibrarian' }),
        description: t({ id: 'team.modal.description.promoteToLibrarian' }),
        confirmLabel: t({ id: 'team.modal.confirm.promote' }),
        kind: 'positive',
        buttonKind: 'primary',
      };
    case 'promote_to_coordenador':
      return {
        title: t({ id: 'team.modal.title.promoteToCoordenador' }),
        description: t({ id: 'team.modal.description.promoteToCoordenador' }),
        confirmLabel: t({ id: 'team.modal.confirm.promote' }),
        kind: 'positive',
        buttonKind: 'primary',
      };
    case 'self_demote':
      return {
        title: t({ id: 'team.modal.title.selfDemote' }),
        description: t({ id: 'team.modal.description.selfDemote' }),
        confirmLabel: t({ id: 'team.modal.confirm.selfDemote' }),
        kind: 'warning',
        buttonKind: 'secondary',
      };
    case 'quit_admin_functions':
      return {
        title: t({ id: 'team.modal.title.quitAdmin' }),
        description: isLastAdmin === true
          ? t({ id: 'team.modal.description.quitAdminLast' })
          : t({ id: 'team.modal.description.quitAdmin' }),
        confirmLabel: t({ id: 'team.modal.confirm.quitAdmin' }),
        kind: isLastAdmin === true ? 'danger' : 'warning',
        buttonKind: isLastAdmin === true ? 'warning' : 'secondary',
      };
    case 'suspend':
      return {
        title: t({ id: 'team.modal.title.suspend' }),
        description: t({ id: 'team.modal.description.suspend' }),
        confirmLabel: t({ id: 'team.modal.confirm.suspend' }),
        kind: 'warning',
        buttonKind: 'warning',
      };
    case 'unsuspend':
      return {
        title: t({ id: 'team.modal.title.unsuspend' }),
        description: t({ id: 'team.modal.description.unsuspend' }),
        confirmLabel: t({ id: 'team.modal.confirm.unsuspend' }),
        kind: 'positive',
        buttonKind: 'primary',
      };
    case 'request_remove':
      return {
        title: t({ id: 'team.modal.title.requestRemove' }),
        description: t({ id: 'team.modal.description.requestRemove' }),
        confirmLabel: t({ id: 'team.modal.confirm.requestRemove' }),
        kind: 'danger',
        buttonKind: 'warning',
      };
    case 'cancel_remove':
      return {
        title: t({ id: 'team.modal.title.cancelRemove' }),
        description: t({ id: 'team.modal.description.cancelRemove' }),
        confirmLabel: t({ id: 'team.modal.confirm.cancelRemove' }),
        kind: 'positive',
        buttonKind: 'primary',
      };
    default:
      return {
        title: '',
        description: '',
        confirmLabel: t({ id: 'team.modal.confirm.generic' }),
        kind: 'default',
        buttonKind: 'primary',
      };
  }
}
