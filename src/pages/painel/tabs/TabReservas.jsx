import { Fragment } from 'react';
import { Link } from 'react-router-dom';
import { Button, EmptyState } from '@/components/ui';
import NegotiationStateBadge from '@/components/reservation/NegotiationStateBadge';
import { fmtD, UserDisplay, SortHeader, StageFilterBar, TabHeader } from '../_shared';

// ═══════════════════════════════════════════════════════════
// TabReservas — onglet « Réservations » (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'reservas'). Le plus dense
// des onglets : négociation de créneaux (contre-propositions, accordion),
// sélection multiple, filtre par étape, transitions de workflow.
// Présentational : tout l'état et les handlers restent dans PanelPage,
// passés ici en props. Iso-comportement strict.
// ═══════════════════════════════════════════════════════════
export default function TabReservas({
  t,
  // état & dérivés
  reservations,
  activeRes,
  sortRes,
  selectedRes,
  resNote, setResNote,
  resSchedule, setResSchedule,
  resStage, setResStage,
  resStageCounts,
  resStageFilter, setResStageFilter,
  actionMsg,
  negotiationForm, setNegotiationForm,
  RES_STAGES,
  WORKFLOW_LABELS,
  actorRole,
  canTransition,
  // handlers
  confirmSelectedPickup,
  cancelSelectedRes,
  loadData,
  applyResWorkflow,
  toggleAllRes,
  toggleRes,
  confirmReaderSlot,
  openCounterProposalForm,
  cancelWithReason,
  submitCounterProposal,
}) {
  return (
    <div>
      <TabHeader title={t({ id: 'panel.tab.reservations' })} onRefresh={loadData} />
      <div className="ab-painel-res-toolbar">
        <Button onClick={confirmSelectedPickup}>{t({ id: 'panel.reservations.confirmPickup' }, { count: selectedRes.size })}</Button>
        <Button variant="secondary" onClick={() => cancelSelectedRes()}>{t({ id: 'common.cancel' })} ({selectedRes.size})</Button>
      </div>
      <div className="ab-painel-res-workflow">
        <input type="text" value={resNote} onChange={e => setResNote(e.target.value)} placeholder={t({id:"panel.loan.notePh"})} className="ab-painel-input" />
        <input type="datetime-local" value={resSchedule} onChange={e => setResSchedule(e.target.value)} className="ab-painel-input" />
        {/* PATCH 07/05/2026 : grisage des transitions illégales depuis le(s) stage(s) sélectionné(s).
            - Calcul de l'intersection des transitions valides pour toutes les lignes sélectionnées
            - Si sélection vide : toutes options actives (mode exploratoire)
            - Si une option n'est valide pour aucune des lignes : disabled + title explicatif */}
        <select value={resStage} onChange={e => setResStage(e.target.value)} className="ab-painel-input">
          <option value="">{t({ id: 'panel.reservations.selectStage' })}</option>
          {(() => {
            const selectedStages = [...selectedRes]
              .map(key => {
                const [rid, lno] = key.split('-').map(Number);
                const row = reservations.find(r => r.reserva_id === rid && r.line_no === lno);
                return row?.workflow_stage_effective || row?.item_status || null;
              })
              .filter(Boolean);
            return RES_STAGES.map(s => {
              // Mode exploratoire : pas de sélection, tout est actif
              if (!selectedStages.length) {
                return <option key={s.value} value={s.value}>{s.label}</option>;
              }
              // Sinon, transition autorisée pour TOUTES les lignes sélectionnées (intersection)
              const allValid = selectedStages.every(from => canTransition(from, s.value, actorRole));
              const distinctStages = [...new Set(selectedStages)];
              const stageList = distinctStages
                .map(st => WORKFLOW_LABELS[st] || t({ id: 'panel.stage.unknown' }))
                .join(', ');
              const reasonHint = allValid
                ? undefined
                : t({ id: 'panel.reservations.transitionBlocked' }, { stages: stageList });
              return (
                <option
                  key={s.value}
                  value={s.value}
                  disabled={!allValid}
                  title={reasonHint}
                  style={!allValid ? { color: '#888' } : undefined}
                >
                  {allValid ? s.label : `${s.label} ✗`}
                </option>
              );
            });
          })()}
        </select>
        <Button variant="secondary" onClick={applyResWorkflow}>{t({ id: 'panel.reservations.applyStep' })}</Button>
      </div>
      {/* PATCH 07/05/2026 : aide UX pour clarifier les actions hors menu */}
      <p className="ab-painel-help">
        {t({ id: 'panel.reservations.menuHelp' })}
      </p>
      <StageFilterBar
        counts={resStageCounts}
        current={resStageFilter}
        onSelect={setResStageFilter}
        labels={WORKFLOW_LABELS}
        allLabel={t({ id: 'panel.stageFilter.all' })}
        unknownLabel={t({ id: 'panel.stage.unknown' })}
      />
      {actionMsg && <p className="ab-painel-msg">{actionMsg}</p>}
      {sortRes.sortedItems.length === 0 ? (
        <EmptyState message={t({
          id: resStageFilter === 'all'
            ? 'panel.reservations.empty'
            : 'panel.reservations.emptyStage'
        })} />
      ) : (
      <div className="ab-painel-table-wrap">
        <table className="ab-painel-table">
          <thead>
            <tr>
              <th><input type="checkbox" checked={selectedRes.size === activeRes.length && activeRes.length > 0} onChange={toggleAllRes} /></th>
              <SortHeader sortKey="sub_id" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.subId'})}</SortHeader>
              <SortHeader sortKey="user_name" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.reader'})}</SortHeader>
              <SortHeader sortKey="titulo" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.book'})}</SortHeader>
              <SortHeader sortKey="bib_ref" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.ref'})}</SortHeader>
              <SortHeader sortKey="rotulo" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.label'})}</SortHeader>
              <SortHeader sortKey="workflow_stage_effective" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.step'})}</SortHeader>
              <SortHeader sortKey="pickup_scheduled_for" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.pickup'})}</SortHeader>
              <SortHeader sortKey="expires_at" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.validity'})}</SortHeader>
              <SortHeader sortKey="pickup_proposed_by" current={sortRes.sortKey} dir={sortRes.sortDir} onClick={sortRes.toggleSort}>{t({id:'panel.table.negotiation'})}</SortHeader>
              <th>{t({id:'panel.table.actions'})}</th>
            </tr>
          </thead>
          <tbody>
            {sortRes.sortedItems.map((r, i) => {
              const key = `${r.reserva_id}-${r.line_no}`;
              // PATCH 08/05/2026 paquet 3B : ligne accordion ouverte si on
              // est en train de contre-proposer pour cette ligne précisément
              const isFormOpen = negotiationForm?.reservaId === r.reserva_id
                              && negotiationForm?.lineNo === r.line_no;
              // Détermine si les actions inline sont disponibles : seulement
              // quand le lecteur·rice a contre-proposé (= staff a la balle).
              // PATCH 09/05/2026 paquet 5b : refactor sémantique v3.
              // La négociation se déroule désormais dans retirada_a_combinar.
              const showStaffActions = r.pickup_proposed_by === 'leitor'
                                    && r.workflow_stage_effective === 'retirada_a_combinar';
              // Indicateur "esperando resposta" quand notre biblio a déjà proposé
              const isWaitingReader = r.pickup_proposed_by === 'biblio'
                                   && r.workflow_stage_effective === 'retirada_a_combinar';
              return (
                <Fragment key={i}>
                  <tr className={selectedRes.has(key) ? 'selected' : ''}>
                    <td><input type="checkbox" checked={selectedRes.has(key)} onChange={() => toggleRes(key)} /></td>
                    <td>{r.sub_id}</td>
                    <td>
                      <UserDisplay
                        name={r.user_name}
                        email={r.user_email}
                        publicId={r.user_public_id}
                        userId={r.user_id}
                      />
                    </td>
                    <td><Link to={`/livro/${r.book_id}`}>{r.titulo || '—'}</Link></td>
                    <td>{r.bib_ref}</td>
                    <td>{r.rotulo || '—'}</td>
                    <td><span className="ab-painel-stage" data-stage={r.workflow_stage_effective}>{WORKFLOW_LABELS[r.workflow_stage_effective] || WORKFLOW_LABELS[r.item_status] || t({ id: 'panel.stage.unknown' })}</span></td>
                    <td>{fmtD(r.pickup_scheduled_for)}</td>
                    <td>{fmtD(r.expires_at)}</td>
                    {/* Colonne Negociação : badge d'état */}
                    <td>
                      <NegotiationStateBadge
                        proposedBy={r.pickup_proposed_by}
                        iterationCount={r.negotiation_iteration_count}
                        stage={r.workflow_stage_effective}
                        viewerRole="staff"
                      />
                    </td>
                    {/* Colonne Ações : 3 boutons inline si lecteur·rice a contre-proposé,
                        texte simple si on attend, rien sinon */}
                    <td className="ab-painel-actions-cell">
                      {showStaffActions && (
                        <div className="ab-painel-res-actions">
                          <button
                            className="ab-button ab-button--mini"
                            onClick={() => confirmReaderSlot(r.reserva_id, r.line_no)}
                            title={t({id:'panel.reservations.action.confirmReaderSlot.tooltip'})}
                          >
                            {t({id:'panel.reservations.action.confirmReaderSlot'})}
                          </button>
                          <button
                            className="ab-button ab-button--secondary ab-button--mini"
                            onClick={() => isFormOpen
                              ? setNegotiationForm(null)
                              : openCounterProposalForm(r.reserva_id, r.line_no, r.pickup_scheduled_for)}
                            title={t({id:'panel.reservations.action.counterProposeSlot.tooltip'})}
                          >
                            {isFormOpen
                              ? t({id:'panel.reservations.counterProposeForm.cancelForm'})
                              : t({id:'panel.reservations.action.counterProposeSlot'})}
                          </button>
                          <button
                            className="ab-button ab-button--mini ab-button--danger"
                            onClick={() => cancelWithReason(r.reserva_id, r.line_no)}
                            title={t({id:'panel.reservations.action.cancelWithReason.tooltip'})}
                          >
                            {t({id:'panel.reservations.action.cancelWithReason'})}
                          </button>
                        </div>
                      )}
                      {!showStaffActions && isWaitingReader && (
                        <span className="ab-painel-res-waiting">
                          {t({id:'panel.reservations.negotiation.waitingReaderInline'})}
                        </span>
                      )}
                    </td>
                  </tr>
                  {/* PATCH 08/05/2026 paquet 3B : ligne accordion contenant le mini-form
                      de contre-proposition. Utilise colSpan=11 pour couvrir toutes les
                      colonnes (1 checkbox + 8 colonnes data + negotiation + actions). */}
                  {isFormOpen && (
                    <tr className="ab-painel-counter-form-row">
                      <td colSpan={11}>
                        <div className="ab-painel-counter-form">
                          <div className="ab-painel-counter-field">
                            <label>
                              {t({id:'panel.reservations.counterProposeForm.datetime'})}
                            </label>
                            <input
                              type="datetime-local"
                              value={negotiationForm.datetime}
                              onChange={e => setNegotiationForm(prev => prev ? { ...prev, datetime: e.target.value } : prev)}
                              className="ab-painel-input"
                            />
                          </div>
                          <div className="ab-painel-counter-field ab-painel-counter-field--wide">
                            <label>
                              {t({id:'panel.reservations.counterProposeForm.note'})}
                            </label>
                            <input
                              type="text"
                              value={negotiationForm.note}
                              onChange={e => setNegotiationForm(prev => prev ? { ...prev, note: e.target.value } : prev)}
                              className="ab-painel-input"
                              placeholder={t({id:'panel.reservations.counterProposeForm.notePlaceholder'})}
                            />
                          </div>
                          <div className="ab-painel-counter-actions">
                            <Button onClick={submitCounterProposal}>
                              {t({id:'panel.reservations.counterProposeForm.submit'})}
                            </Button>
                            <Button variant="secondary" onClick={() => setNegotiationForm(null)}>
                              {t({id:'panel.reservations.counterProposeForm.cancelForm'})}
                            </Button>
                          </div>
                        </div>
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>
      )}
    </div>
  );
}
