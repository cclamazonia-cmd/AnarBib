import { lazy, Suspense } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui';
import { formatSchedule } from '@/lib/scheduleFormat';
import { decodeSystemNote } from '@/lib/systemNotes';
import ContaTabHeader from '@/pages/account/ContaTabHeader';

// #REFACTOR 08/06 (onglets lourds) : ReservationCard (~245 lignes) en chunk lazy,
// chargé seulement depuis l'onglet « reservar ».
const ReservationCard = lazy(() => import('@/components/account/ReservationCard'));

// ═══════════════════════════════════════════════════════════
// AnarBib — l'onglet « Réserver » de Mon compte (E6, AccountPage lot 5,
// 07/10/2026). Sorti d'AccountPage.jsx tel quel, lignes déplacées par script :
// le formulaire de réservation par référence, les réservations actives, les
// créneaux de consultation proposés, les consultations actives et celles
// annulées par la bibliothèque. Les données et TOUS les gestes (réserver,
// annuler, confirmer un retrait, contre-proposer, confirmer ou refuser un
// créneau, effacer une annulation) restent au parent, avec leurs modales ;
// les props portent les noms du parent.
// ═══════════════════════════════════════════════════════════

export default function TabReservar({
  reserveRef, setReserveRef, handleReserve, reserveMsg, reservations, consultations, tzMap, loadData,
  renderLibTag, renderSameTitleSignal, cancelReservation, handleConfirmPickup,
  openCounterProposalForm, handleSubmitCounterProposal, negotiationForm, setNegotiationForm,
  handleConfirmSchedule, replying, openRefuseModal, setCancelTarget, handleDismissConsultaCancelled,
}) {
  const { formatMessage: t } = useIntl();
  return (
    <div>
      <ContaTabHeader title={t({ id: 'account.reserve.title' })} onRefresh={() => loadData({ silent: true })} />
      <p className="ab-conta-hint">
        No catálogo, copie a referência e cole aqui. Use <strong>{t({ id: 'account.reserve.loan' })}</strong> para materiais emprestáveis
        ou <strong>{t({ id: 'account.reserve.consult' })}</strong> para periódicos e materiais consultáveis.
      </p>

      <div className="ab-conta-reserve-form">
        <input type="text" value={reserveRef} onChange={e => setReserveRef(e.target.value)}
          placeholder={t({ id: 'account.reserve.placeholder' })} className="ab-input" />
        <Button variant="secondary" onClick={() => handleReserve('reserve')}>{t({ id: 'account.reserve.loan' })}</Button>
        <Button variant="secondary" onClick={() => handleReserve('consult')}>{t({ id: 'account.reserve.consult' })}</Button>
      </div>
      {reserveMsg && <p className="ab-conta-msg">{reserveMsg}</p>}

      <h3 className="ab-conta-subsection">{t({ id: 'account.reservations.active' })}</h3>
      {reservations.length === 0 ? (
        <p className="ab-conta-empty">{t({ id: 'account.reservations.empty' })}</p>
      ) : (
        <Suspense fallback={null}>
        <div className="ab-conta-items">
          {reservations.map((r, i) => (
            <ReservationCard
              key={i}
              r={r}
              timeZone={tzMap[r.library_id]}
              libTag={renderLibTag(r.library_id)}
              sameTitleSignal={renderSameTitleSignal(r.titulo)}
              onCancel={cancelReservation}
              onConfirmPickup={handleConfirmPickup}
              onOpenCounterProposalForm={openCounterProposalForm}
              onCloseCounterProposalForm={() => setNegotiationForm(null)}
              onSubmitCounterProposal={handleSubmitCounterProposal}
              negotiationForm={negotiationForm}
              setNegotiationForm={setNegotiationForm}
              loadData={loadData}
            />
          ))}
        </div>
        </Suspense>
      )}

      {/* Paquet 27.A.5 (4.3) : creneau propose par la biblio, en attente de reponse */}
      {consultations.filter(c => c.workflow_stage_effective === 'consulta_agendada' && !c.schedule_reply_status).length > 0 && (
        <>
          <h3 className="ab-conta-subsection" style={{ marginTop: 0 }}>
            {t({ id: 'account.consultations.scheduleProposed.title' })}
          </h3>
          <p className="ab-conta-hint">{t({ id: 'account.consultations.scheduleProposed.hint' })}</p>
          <div className="ab-conta-items">
            {consultations.filter(c => c.workflow_stage_effective === 'consulta_agendada' && !c.schedule_reply_status).map((c, i) => (
              <div key={`prop-${i}`} className="ab-conta-item" style={{ borderLeft: '3px solid #2563eb' }}>
                <div className="ab-conta-item__main">
                  <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || ''}</Link>
                  <span className="ab-conta-item__meta">ref: {c.bib_ref || ''}</span>
                  <p style={{ margin: '8px 0 0', fontWeight: 600 }}>
                    {t({ id: 'account.consultations.scheduleProposed.dateLabel' })} : {formatSchedule(c, tzMap[c.library_id])}
                  </p>
                  {c.workflow_note && (
                    <p style={{ margin: '4px 0 0', fontStyle: 'italic', color: 'var(--brand-muted)' }}>
                      {t({ id: 'account.consultations.scheduleProposed.noteLabel' })} : {decodeSystemNote(c.workflow_note, t)}
                    </p>
                  )}
                </div>
                <div className="ab-conta-item__actions" style={{ display: 'flex', gap: 8 }}>
                  <Button onClick={() => handleConfirmSchedule(c)} disabled={replying}>
                    {t({ id: 'account.consultations.scheduleProposed.confirmButton' })}
                  </Button>
                  <Button variant="secondary" onClick={() => openRefuseModal(c)} disabled={replying}>
                    {t({ id: 'account.consultations.scheduleProposed.refuseButton' })}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      <h3 className="ab-conta-subsection">{t({ id: 'account.consultations.active' })}</h3>
      {consultations.filter(c => c.status === 'ativa').length === 0 ? (
        <p className="ab-conta-empty">{t({ id: 'account.consultations.empty' })}</p>
      ) : (
        <div className="ab-conta-items">
          {consultations.filter(c => c.status === 'ativa').map((c, i) => (
            <div key={`act-${i}`} className="ab-conta-item">
              <div className="ab-conta-item__main">
                <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || '—'}</Link>
                <span className="ab-conta-item__meta">ref: {c.bib_ref || '—'} · {c.workflow_stage || c.status || '—'}</span>
                {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status === 'confirmado_leitor' && (
                  <p style={{ margin: '4px 0 0', color: '#15803d', fontWeight: 600 }}>
                    ✓ {t({ id: 'account.consultations.scheduleConfirmed.badge' }, { date: formatSchedule(c, tzMap[c.library_id]) })}
                  </p>
                )}
              </div>
              <div className="ab-conta-item__actions">
                <Button variant="secondary" onClick={() => setCancelTarget(c)}>
                  {t({ id: 'account.consultations.cancelButton' })}
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      {consultations.filter(c => c.status === 'cancelada_biblioteca').length > 0 && (
        <>
          <h3 className="ab-conta-subsection" style={{ marginTop: 24 }}>
            {t({ id: 'account.consultations.cancelledByLibrary' })}
          </h3>
          <p className="ab-conta-hint">{t({ id: 'account.consultations.cancelledByLibraryHint' })}</p>
          <div className="ab-conta-items">
            {consultations.filter(c => c.status === 'cancelada_biblioteca').map((c, i) => (
              <div key={`cnx-${i}`} className="ab-conta-item" style={{ borderLeft: '3px solid #f59e0b' }}>
                <div className="ab-conta-item__main">
                  <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || '—'}</Link>
                  <span className="ab-conta-item__meta">
                    ref: {c.bib_ref || '—'}
                    {c.cancelled_at && <> · {new Date(c.cancelled_at).toLocaleDateString()}</>}
                  </span>
                </div>
                <div className="ab-conta-item__actions">
                  <Button variant="secondary" onClick={() => handleDismissConsultaCancelled(c)}>
                    {t({ id: 'account.consultations.dismissButton' })}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
