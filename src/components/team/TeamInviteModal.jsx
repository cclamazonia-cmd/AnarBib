// ============================================================================
// src/components/team/TeamInviteModal.jsx
// ============================================================================
//
// Modale « accueillir dans l'équipe » (lot 3 — invitation-équipe).
// Saisie de l'identifiant public (U…) de la personne à accueillir, puis appel
// de fn_team_propose_invitation. Le rôle est TOUJOURS 'librarian' (le rôle
// coordenador ne s'invite pas : promotion/transfert — cf. CADRAGE_accueil_equipe).
//
// Props :
//   - isOpen     : bool
//   - onClose    : () => void
//   - onSuccess  : (result) => void
//   - libraryId  : uuid de la bibliothèque courante
// ============================================================================

import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import Modal from '@/components/ui/Modal';
import { useTeamMutations } from '@/lib/teamMutations';
import { localizeError } from '@/lib/localizeError';
import { normalizePublicId } from '@/lib/publicId';

export default function TeamInviteModal({ isOpen, onClose, onSuccess, libraryId }) {
  const { formatMessage: t } = useIntl();
  const mutations = useTeamMutations();
  const [publicId, setPublicId] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  useEffect(() => {
    if (isOpen) { setPublicId(''); setErrorMsg(''); }
  }, [isOpen]);

  if (!isOpen) return null;

  const canSubmit = !mutations.loading && publicId.trim().length > 0;

  const handleConfirm = async () => {
    setErrorMsg('');
    if (!publicId.trim()) {
      setErrorMsg(t({ id: 'team.invite.error.emptyPublicId' }));
      return;
    }
    // normalizePublicId : l'identifiant est affiche par groupes de quatre sur la
    // fiche et la carte — recolle avant l'envoi (cf. src/lib/publicId.js).
    const result = await mutations.proposeInvitation(libraryId, normalizePublicId(publicId), 'librarian');
    if (result.success) {
      onSuccess?.(result);
      onClose();
    } else {
      setErrorMsg(localizeError({ code: result.error, message: result.message }, t, 'team.invite.error.generic'));
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={t({ id: 'team.invite.title' })} size="medium">
      <div className="ab-team-modal-content">
        <div className="ab-team-modal-description ab-team-modal-description--positive">
          {t({ id: 'team.invite.description' })}
        </div>

        <div className="ab-team-modal-field">
          <label htmlFor="ab-team-invite-pubid" className="ab-team-modal-label">
            {t({ id: 'team.invite.publicId.label' })} *
          </label>
          <input
            id="ab-team-invite-pubid"
            className="ab-input"
            type="text"
            value={publicId}
            onChange={(e) => setPublicId(e.target.value)}
            placeholder={t({ id: 'team.invite.publicId.placeholder' })}
            autoFocus
          />
          <div className="ab-team-modal-hint">{t({ id: 'team.invite.publicId.hint' })}</div>
        </div>

        {errorMsg && <div className="ab-team-modal-error">{errorMsg}</div>}

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
            className="cat-btn primary"
            onClick={handleConfirm}
            disabled={!canSubmit}
          >
            {mutations.loading ? t({ id: 'common.saving' }) : t({ id: 'team.invite.submit' })}
          </button>
        </div>
      </div>
    </Modal>
  );
}
