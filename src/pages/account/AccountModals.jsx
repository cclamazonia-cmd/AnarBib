// Les quatre fenêtres de confirmation de Mon compte — effacer tout un
// historique, effacer une ligne, annuler une consultation, refuser un créneau —
// sorties d'AccountPage.jsx telles quelles (E6, 23/10/2026). La page garde
// l'état et les actions ; ce composant ne fait qu'afficher.
// Garde : src/tests/conta-perfil-modales-montes.test.js.
import { useIntl } from 'react-intl';
import { Button } from '@/components/ui';
import Modal from '@/components/ui/Modal';

export default function AccountModals(p) {
  const { formatMessage: t } = useIntl();
  const {
    cancelTarget, cancelling, closeRefuseModal, deleteAllBusy, deleteAllConfirmText,
    deleteAllTarget, deleteHistoryTarget, handleCancelConsulta, handleDeleteAllHistory,
    handleDeleteHistoryItem, handleRefuseSchedule, libraryName, refuseError, refuseNote,
    refuseTarget, replying, setCancelTarget, setDeleteAllConfirmText, setDeleteAllTarget,
    setDeleteHistoryTarget, setRefuseNote,
  } = p;
  return (
    <>
          <Modal
        isOpen={!!deleteAllTarget}
        onClose={() => { if (!deleteAllBusy) { setDeleteAllTarget(null); setDeleteAllConfirmText(''); } }}
        title={t({ id: 'account.history.deleteAll.title' })}
        size="small"
      >
        <div className="ab-modal__body">
          {deleteAllTarget && (
            <p>{t({ id: 'account.history.deleteAll.body' }, { domain: t({ id: `account.history.deleteAll.domain.${deleteAllTarget.domain}` }), library: libraryName })}</p>
          )}
          <p style={{ marginTop: 8, color: '#f87171', fontSize: '.85rem' }}>
            {t({ id: 'account.history.deleteAll.irreversible' })}
          </p>
          <label style={{ display: 'flex', flexDirection: 'column', gap: 4, marginTop: 12 }}>
            <span style={{ fontSize: '.85rem' }}>
              {t({ id: 'account.history.deleteAll.typeToConfirm' }, { word: t({ id: 'account.history.deleteAll.confirmWord' }) })}
            </span>
            <input
              type="text"
              className="ab-input"
              value={deleteAllConfirmText}
              onChange={(e) => setDeleteAllConfirmText(e.target.value)}
              disabled={deleteAllBusy}
              autoFocus
            />
          </label>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={() => { setDeleteAllTarget(null); setDeleteAllConfirmText(''); }} disabled={deleteAllBusy}>
            {t({ id: 'common.cancel' })}
          </Button>
          <Button
            variant="danger"
            onClick={handleDeleteAllHistory}
            disabled={deleteAllBusy || deleteAllConfirmText.trim().toUpperCase() !== t({ id: 'account.history.deleteAll.confirmWord' }).toUpperCase()}
          >
            {deleteAllBusy ? t({ id: 'common.loading' }) : t({ id: 'account.history.deleteAll.confirmButton' })}
          </Button>
        </div>
      </Modal>
          <Modal
        isOpen={!!deleteHistoryTarget}
        onClose={() => setDeleteHistoryTarget(null)}
        title={t({ id: 'account.history.delete.confirmTitle' })}
        size="small"
      >
        <div className="ab-modal__body">
          <p>{t({ id: 'account.history.delete.confirmBody' })}</p>
          {deleteHistoryTarget?.label && (
            <p style={{ marginTop: 12, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
              {deleteHistoryTarget.label}
            </p>
          )}
          <p style={{ marginTop: 12, color: '#f87171', fontSize: '.85rem' }}>
            {t({ id: 'account.history.delete.irreversible' })}
          </p>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={() => setDeleteHistoryTarget(null)}>
            {t({ id: 'common.cancel' })}
          </Button>
          <Button variant="danger" onClick={handleDeleteHistoryItem}>
            {t({ id: 'account.history.delete.confirm' })}
          </Button>
        </div>
      </Modal>
          <Modal
        isOpen={!!cancelTarget}
        onClose={() => !cancelling && setCancelTarget(null)}
        title={t({ id: 'account.consultations.cancelConfirmTitle' })}
        size="small"
      >
        <div className="ab-modal__body">
          <p>{t({ id: 'account.consultations.cancelConfirm' })}</p>
          {cancelTarget && (cancelTarget.titulo || cancelTarget.bib_ref) && (
            <p style={{ marginTop: 12, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
              {cancelTarget.titulo || cancelTarget.bib_ref}
            </p>
          )}
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={() => setCancelTarget(null)} disabled={cancelling}>
            {t({ id: 'common.cancel' })}
          </Button>
          <Button onClick={handleCancelConsulta} disabled={cancelling}>
            {cancelling ? t({ id: 'common.loading' }) : t({ id: 'account.consultations.cancelButton' })}
          </Button>
        </div>
      </Modal>
          {/* Paquet 27.A.5 (4.3) : modal de refus du creneau (note obligatoire) */}
      <Modal
        isOpen={!!refuseTarget}
        onClose={closeRefuseModal}
        title={t({ id: 'account.consultations.refuseModal.title' })}
        size="small"
      >
        <div className="ab-modal__body">
          {refuseTarget && (
            <p style={{ marginBottom: 12, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
              {refuseTarget.titulo || refuseTarget.bib_ref}
            </p>
          )}
          <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <span style={{ fontSize: '.85rem' }}>
              {t({ id: 'account.consultations.refuseModal.noteLabel' })}
            </span>
            <textarea
              value={refuseNote}
              onChange={(e) => setRefuseNote(e.target.value)}
              placeholder={t({ id: 'account.consultations.refuseModal.notePlaceholder' })}
              className="ab-input"
              rows={3}
              maxLength={300}
              disabled={replying}
              autoFocus
            />
            <span style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>
              ({refuseNote.length}/300)
            </span>
          </label>
          {refuseError && (
            <p style={{ color: 'var(--brand-danger, #c62828)', fontSize: '.9rem', marginTop: 8 }}>
              {refuseError}
            </p>
          )}
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={closeRefuseModal} disabled={replying}>
            {t({ id: 'common.cancel' })}
          </Button>
          <Button onClick={handleRefuseSchedule} disabled={replying}>
            {replying ? t({ id: 'common.loading' }) : t({ id: 'account.consultations.scheduleProposed.refuseButton' })}
          </Button>
        </div>
      </Modal>
    </>
  );
}
