// AnarBib — Panneau, les deux modales des consultations (E6, lot C, 12/10/2026) :
// planifier (date, heures, note, fuseau de la bibliothèque) et annuler avec
// un motif obligatoire. JSX déplacé tel quel depuis PanelPage.jsx ; l'état et
// les gestes viennent de usePanelConsultas, étalés en props.
import Modal from '@/components/ui/Modal';
import { Button } from '@/components/ui';

export default function ConsultaModals({ t, consultationTz, scheduleTarget, scheduleForm, setScheduleForm, scheduling, scheduleError, closeScheduleModal, handleScheduleSubmit, cancelTarget, cancelForm, setCancelForm, cancelling, cancelError, closeCancelModal, handleCancelSubmit }) {
  return (
    <>
          {/* Paquet 27.A.4 (5.B) : modal de proposition de creneau pour consulta */}
      <Modal
        isOpen={!!scheduleTarget}
        onClose={closeScheduleModal}
        title={t({ id: 'panel.consultation.schedule.title' })}
        size="medium"
      >
        <div className="ab-modal__body">
          {scheduleTarget && (
            <>
              <p style={{ marginBottom: 8 }}>
                <strong>{t({ id: 'panel.consultation.schedule.subtitle' })} :</strong>{' '}
                {scheduleTarget.user_name || scheduleTarget.user_email || scheduleTarget.user_public_id || '?'}
              </p>
              <p style={{ marginBottom: 16, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.schedule.book' })} : {scheduleTarget.titulo || scheduleTarget.bib_ref || '?'}
              </p>
            </>
          )}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.schedule.dateLabel' })}
              </span>
              <input type="date" value={scheduleForm.date} onChange={(e) => setScheduleForm(f => ({ ...f, date: e.target.value }))} className="ab-input" disabled={scheduling} />
            </label>
            <div style={{ display: 'flex', gap: 12 }}>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 4, flex: 1 }}>
                <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                  {t({ id: 'panel.consultation.schedule.startsAtLabel' })}
                </span>
                <input type="time" value={scheduleForm.startsAt} onChange={(e) => setScheduleForm(f => ({ ...f, startsAt: e.target.value }))} className="ab-input" disabled={scheduling} />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: 4, flex: 1 }}>
                <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                  {t({ id: 'panel.consultation.schedule.endsAtLabel' })}
                </span>
                <input type="time" value={scheduleForm.endsAt} onChange={(e) => setScheduleForm(f => ({ ...f, endsAt: e.target.value }))} className="ab-input" disabled={scheduling} />
              </label>
            </div>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.schedule.noteLabel' })}
              </span>
              <textarea value={scheduleForm.note} onChange={(e) => setScheduleForm(f => ({ ...f, note: e.target.value }))} placeholder={t({ id: 'panel.consultation.schedule.notePlaceholder' })} className="ab-input" rows={3} maxLength={300} disabled={scheduling} />
              <span style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.schedule.noteHint' })} ({scheduleForm.note.length}/300)
              </span>
            </label>
            <p style={{ fontSize: '.75rem', color: 'var(--brand-muted)', marginTop: 4 }}>
              {t({ id: 'panel.consultation.schedule.timezoneHint' }, { tz: consultationTz || 'America/Belem' })}
            </p>
            {scheduleError && (
              <p style={{ color: 'var(--brand-danger, #c62828)', fontSize: '.9rem', margin: 0 }}>{scheduleError}</p>
            )}
          </div>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={closeScheduleModal} disabled={scheduling}>
            {t({ id: 'panel.consultation.schedule.cancelButton' })}
          </Button>
          <Button onClick={handleScheduleSubmit} disabled={scheduling}>
            {scheduling ? t({ id: 'panel.consultation.schedule.submitting' }) : t({ id: 'panel.consultation.schedule.submitButton' })}
          </Button>
        </div>
      </Modal>

      {/* B6 (15/05/2026) : modal d'annulation biblio avec note obligatoire */}
      <Modal
        isOpen={!!cancelTarget}
        onClose={closeCancelModal}
        title={t({ id: 'panel.consultation.cancel.title' })}
        size="medium"
      >
        <div className="ab-modal__body">
          {cancelTarget && (
            <>
              <p style={{ marginBottom: 8 }}>
                <strong>{t({ id: 'panel.consultation.cancel.subtitle' })} :</strong>{' '}
                {cancelTarget.user_name || cancelTarget.user_email || cancelTarget.user_public_id || '?'}
              </p>
              <p style={{ marginBottom: 16, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.book' })} : {cancelTarget.titulo || cancelTarget.bib_ref || '?'}
              </p>
            </>
          )}
          <p style={{ marginBottom: 12, fontSize: '.9rem' }}>
            {t({ id: 'panel.consultation.cancel.description' })}
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.noteLabel' })}
              </span>
              <textarea
                value={cancelForm.note}
                onChange={(e) => setCancelForm({ note: e.target.value })}
                placeholder={t({ id: 'panel.consultation.cancel.notePlaceholder' })}
                className="ab-input"
                rows={4}
                maxLength={300}
                disabled={cancelling}
              />
              <span style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.noteHint' })} ({cancelForm.note.length}/300, min 5)
              </span>
            </label>
            {cancelError && (
              <p style={{ color: 'var(--brand-danger, #c62828)', fontSize: '.9rem', margin: 0 }}>{cancelError}</p>
            )}
          </div>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={closeCancelModal} disabled={cancelling}>
            {t({ id: 'panel.consultation.cancel.backButton' })}
          </Button>
          <Button onClick={handleCancelSubmit} disabled={cancelling || cancelForm.note.trim().length < 5}>
            {cancelling ? t({ id: 'panel.consultation.cancel.submitting' }) : t({ id: 'panel.consultation.cancel.confirmButton' })}
          </Button>
        </div>
      </Modal>
    </>
  );
}
