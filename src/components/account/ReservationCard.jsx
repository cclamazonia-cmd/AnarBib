import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui';
import NegotiationStateBadge from '@/components/reservation/NegotiationStateBadge';

// ═══════════════════════════════════════════════════════════
// ReservationCard — extrait d'AccountPage en module LAZY (refactor 08/06/2026,
// « onglets lourds »). Interface de props inchangée (mêmes props qu'au point
// d'appel) ; chargé en lazy depuis l'onglet « reservar » → sort ~245 lignes du
// chunk initial d'AccountPage. fmtDate (exclusif à ce composant) déplacé ici.
//
// Refondue paquet 4 (workflow réservation v2 négociation), sémantique v3
// (PATCH 09/05/2026 paquet 5b). Affiche une réservation avec actions
// contextuelles selon l'état de la négociation symétrique (champs
// pickup_proposed_by, negotiation_iteration_count). <NegotiationStateBadge
// viewerRole="reader" /> (paquet 3B) rend l'état de négociation visuellement.
// ═══════════════════════════════════════════════════════════

function fmtDate(d) {
  if (!d) return '';
  try { return new Date(d).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }); }
  catch { return String(d); }
}

export default function ReservationCard({
  r,
  libTag,            // #CL.10 : tag biblio d'origine (multi-biblio), rendu par AccountPage
  sameTitleSignal,   // #CL.10 : signal « même titre dans 2 biblios »
  onCancel,
  onConfirmPickup,
  onOpenCounterProposalForm,
  onCloseCounterProposalForm,
  onSubmitCounterProposal,
  negotiationForm,
  setNegotiationForm,
}) {
  const { formatMessage: t } = useIntl();

  const WORKFLOW_LABELS = {
    solicitada: t({ id: 'reservation.stage.solicitada' }),
    em_preparacao: t({ id: 'reservation.stage.em_preparacao' }),
    pronta_para_retirada: t({ id: 'reservation.stage.pronta_para_retirada' }),
    retirada_a_combinar: t({ id: 'reservation.stage.retirada_a_combinar' }),
    retirada_agendada: t({ id: 'reservation.stage.retirada_agendada' }),
    're-retirada_agendada': t({ id: 'reservation.stage.re_retirada_agendada' }),
    nao_retirada: t({ id: 'reservation.stage.nao_retirada' }),
    cancelada_leitor: t({ id: 'reservation.stage.cancelada_leitor' }),
    cancelada_biblioteca: t({ id: 'reservation.stage.cancelada_biblioteca' }),
    expirada: t({ id: 'reservation.stage.expirada' }),
  };

  const stage = String(r.workflow_stage_effective || r.status || '').trim();
  const stageLabel = WORKFLOW_LABELS[stage] || stage || '—';
  const proposedBy = r.pickup_proposed_by || null;
  const iterCount = r.negotiation_iteration_count ?? 0;
  const MAX_ITER = 3;

  const inNegotiationStage = stage === 'retirada_a_combinar';
  const isLockedSlot = stage === 'retirada_agendada';
  const bibliotaProposed = inNegotiationStage && proposedBy === 'biblio';
  const leitorAlreadyProposed = inNegotiationStage && proposedBy === 'leitor';
  const counterMaxReached = iterCount >= MAX_ITER;
  const canCounterPropose = bibliotaProposed && !counterMaxReached;

  const TERMINAL_STAGES = ['cancelada_leitor', 'cancelada_biblioteca', 'expirada', 'retirada_efetivada', 'liberada_para_circulacao', 'convertida_em_emprestimo'];
  const canCancel = !TERMINAL_STAGES.includes(stage) && !['cancelada_leitor', 'cancelada_biblioteca', 'expirada'].includes(r.status);

  const isFormOpen = negotiationForm?.reservaId === r.reserva_id
                  && negotiationForm?.lineNo === r.line_no;

  return (
    <div className="ab-conta-item ab-conta-item--reservation">
      <div className="ab-conta-item__main">
        <Link to={`/livro/${r.book_id}`} className="ab-conta-item__title">
          {r.titulo || r.bib_ref || '—'}
        </Link>
        <span className="ab-conta-item__meta">
          ref: {r.bib_ref || '—'} · {r.rotulo || ''} · {libTag || r.library_name || ''}
        </span>
        {sameTitleSignal}
        <span className="ab-conta-item__status" data-stage={stage}>
          {stageLabel}
          {inNegotiationStage && proposedBy && (
            <span style={{ marginLeft: 8 }}>
              <NegotiationStateBadge
                proposedBy={proposedBy}
                iterationCount={iterCount}
                stage={stage}
                viewerRole="reader"
              />
            </span>
          )}
        </span>

        {stage === 'solicitada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#60a5fa' }}>{t({ id: 'reservation.nextStep.solicitada' })}</span>}
        {stage === 'em_preparacao' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#60a5fa' }}>{t({ id: 'reservation.nextStep.em_preparacao' })}</span>}
        {stage === 'pronta_para_retirada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#4ade80' }}>{t({ id: 'reservation.nextStep.pronta_para_retirada' })}</span>}
        {inNegotiationStage && bibliotaProposed && !counterMaxReached && (
          <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#fbbf24' }}>
            {t({ id: 'reservation.nextStep.bibliotaProposed' })}
          </span>
        )}
        {inNegotiationStage && leitorAlreadyProposed && (
          <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#fbbf24' }}>
            {t({ id: 'reservation.nextStep.leitorProposed' }, { count: iterCount, max: MAX_ITER })}
          </span>
        )}
        {isLockedSlot && (
          <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#4ade80' }}>
            {t({ id: 'reservation.nextStep.retirada_agendada' })}
          </span>
        )}
        {stage === 'nao_retirada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#f87171' }}>{t({ id: 'reservation.nextStep.nao_retirada' })}</span>}

        {r.pickup_scheduled_for && inNegotiationStage && (
          <span className="ab-conta-item__detail">
            {bibliotaProposed
              ? t({ id: 'reservation.pickup.proposedByLibrary' }, { date: fmtDate(r.pickup_scheduled_for) })
              : leitorAlreadyProposed
                ? t({ id: 'reservation.pickup.proposedByYou' }, { date: fmtDate(r.pickup_scheduled_for) })
                : t({ id: 'reservation.pickup.scheduled' }, { date: fmtDate(r.pickup_scheduled_for) })}
          </span>
        )}
        {r.pickup_scheduled_for && !inNegotiationStage && (
          <span className="ab-conta-item__detail">
            {t({ id: 'reservation.pickup.scheduled' }, { date: fmtDate(r.pickup_scheduled_for) })}
          </span>
        )}

        {counterMaxReached && bibliotaProposed && (
          <span className="ab-conta-item__detail" style={{ color: '#f87171', fontStyle: 'italic', marginTop: 6 }}>
            {t({ id: 'reservation.negotiation.maxIterationsReached' })}
          </span>
        )}
        {/* workflow_note masquée côté lecteur (notes d'audit machine) — cf. paquet 5d */}
      </div>

      {/* Actions selon l'état de négociation */}
      <div className="ab-conta-item__actions">
        {bibliotaProposed && (
          <>
            <button className="ab-button ab-button--mini"
              onClick={() => onConfirmPickup(r.reserva_id, r.line_no)}>
              {t({ id: 'reservation.action.acceptThisSlot' })}
            </button>
            {canCounterPropose && (
              <button className="ab-button ab-button--secondary ab-button--mini"
                onClick={() => isFormOpen
                  ? onCloseCounterProposalForm()
                  : onOpenCounterProposalForm(r.reserva_id, r.line_no, r.pickup_scheduled_for)}>
                {isFormOpen
                  ? t({ id: 'reservation.action.closeForm' })
                  : t({ id: 'reservation.action.proposeOtherSlot' })}
              </button>
            )}
          </>
        )}

        {leitorAlreadyProposed && (
          <button className="ab-button ab-button--secondary ab-button--mini"
            onClick={() => isFormOpen
              ? onCloseCounterProposalForm()
              : onOpenCounterProposalForm(r.reserva_id, r.line_no, r.pickup_scheduled_for)}>
            {isFormOpen
              ? t({ id: 'reservation.action.closeForm' })
              : t({ id: 'reservation.action.modifyMyProposal' })}
          </button>
        )}

        {canCancel && (
          <button className="ab-button ab-button--mini ab-button--danger"
            onClick={() => onCancel(r.reserva_id)}>
            {t({ id: 'reservation.action.cancel' })}
          </button>
        )}
      </div>

      {/* Panneau accordion : mini-form de contre-proposition */}
      {isFormOpen && (
        <div className="ab-conta-item__counter-form" style={{
          gridColumn: '1 / -1',
          marginTop: 12,
          padding: '12px 14px',
          background: 'rgba(251,191,36,.08)',
          border: '1px solid rgba(251,191,36,.3)',
          borderRadius: 6,
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
        }}>
          <div style={{ fontSize: '.92rem', fontWeight: 600 }}>
            {leitorAlreadyProposed
              ? t({ id: 'reservation.counterProposeForm.modifyTitle' })
              : t({ id: 'reservation.counterProposeForm.title' })}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <label style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
              {t({ id: 'reservation.counterProposeForm.datetime' })}
            </label>
            <input
              type="datetime-local"
              value={negotiationForm.datetime}
              onChange={e => setNegotiationForm(prev => prev ? { ...prev, datetime: e.target.value } : prev)}
              className="ab-input"
              style={{ maxWidth: 250 }}
            />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <label style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
              {t({ id: 'reservation.counterProposeForm.note' })}
            </label>
            <input
              type="text"
              value={negotiationForm.note}
              onChange={e => setNegotiationForm(prev => prev ? { ...prev, note: e.target.value } : prev)}
              className="ab-input"
              placeholder={t({ id: 'reservation.counterProposeForm.notePlaceholder' })}
            />
          </div>

          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
            <Button onClick={onSubmitCounterProposal}>
              {t({ id: 'reservation.counterProposeForm.submit' })}
            </Button>
            <Button variant="secondary" onClick={onCloseCounterProposalForm}>
              {t({ id: 'reservation.action.closeForm' })}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
