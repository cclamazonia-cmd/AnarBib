import { Link } from 'react-router-dom';
import { EmptyState } from '@/components/ui';
import { formatSchedule } from '@/lib/scheduleFormat';
import { fmtD, UserDisplay, SortHeader, StageFilterBar, TabHeader } from '../_shared';

// ═══════════════════════════════════════════════════════════
// TabConsultasLocais — onglet « Consultations » (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'consultas-locais').
// Présentational : état et handlers restent dans PanelPage, passés
// ici en props. Iso-comportement strict.
// ═══════════════════════════════════════════════════════════
export default function TabConsultasLocais({
  t,
  sortCon,
  conStageCounts,
  conStageFilter,
  setConStageFilter,
  CONSULT_WORKFLOW,
  setConsultaWorkflow,
  openScheduleModal,
  openCancelModal,
  loadData,
}) {
  return (
    <div>
      <TabHeader title={t({ id: 'panel.tab.consultations' })} onRefresh={loadData} />
      <StageFilterBar
        counts={conStageCounts}
        current={conStageFilter}
        onSelect={setConStageFilter}
        labels={CONSULT_WORKFLOW}
        allLabel={t({ id: 'panel.stageFilter.all' })}
        unknownLabel={t({ id: 'panel.stage.unknown' })}
      />
      {sortCon.sortedItems.length === 0 ? (
        <EmptyState message={t({
          id: conStageFilter === 'all'
            ? 'panel.consultations.empty'
            : 'panel.consultations.emptyStage'
        })} />
      ) : (
      <div className="ab-painel-table-wrap">
        <table className="ab-painel-table">
          <thead><tr>
            <SortHeader sortKey="sub_id" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.subId'})}</SortHeader>
            <SortHeader sortKey="user_name" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.reader'})}</SortHeader>
            <SortHeader sortKey="titulo" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.book'})}</SortHeader>
            <SortHeader sortKey="bib_ref" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.ref'})}</SortHeader>
            <SortHeader sortKey="workflow_stage_effective" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({id:'panel.table.step'})}</SortHeader>
            <SortHeader sortKey="consultation_scheduled_for" current={sortCon.sortKey} dir={sortCon.sortDir} onClick={sortCon.toggleSort}>{t({ id: 'panel.loan.scheduling' })}</SortHeader>
            <th>{t({id:'panel.table.actions'})}</th>
          </tr></thead>
          <tbody>
            {sortCon.sortedItems.map((c, i) => (
              <tr key={i}>
                <td>{c.sub_id}</td>
                <td>
                  <UserDisplay
                    name={c.user_name}
                    email={c.user_email}
                    publicId={c.user_public_id}
                    userId={c.user_id}
                  />
                </td>
                <td><Link to={`/livro/${c.book_id}`}>{c.titulo || '—'}</Link></td>
                <td>{c.bib_ref}</td>
                <td><span className="ab-painel-stage" data-stage={c.workflow_stage_effective}>{CONSULT_WORKFLOW[c.workflow_stage_effective] || CONSULT_WORKFLOW[c.item_status] || t({ id: 'panel.stage.unknown' })}</span></td>
                <td>
                  {c.consultation_starts_at ? (
                    <>
                      <div>{formatSchedule(c)}</div>
                      {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status === 'confirmado_leitor' && (
                        <span style={{ color: '#15803d', fontSize: '.85rem', fontWeight: 600 }}>
                          ✓ {t({ id: 'panel.consultation.replyStatus.confirmed' })}
                        </span>
                      )}
                      {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status === 'recusado_leitor' && (
                        <div>
                          <span style={{ color: '#c2410c', fontSize: '.85rem', fontWeight: 600 }}>
                            ✗ {t({ id: 'panel.consultation.replyStatus.refused' })}
                          </span>
                          {c.schedule_reply_note && (
                            <div style={{ fontSize: '.75rem', fontStyle: 'italic', color: 'var(--brand-muted)', marginTop: 2 }}>
                              {t({ id: 'panel.consultation.refuseReason' })} {c.schedule_reply_note}
                            </div>
                          )}
                        </div>
                      )}
                      {c.workflow_stage_effective === 'consulta_agendada' && !c.schedule_reply_status && (
                        <span style={{ color: 'var(--brand-muted)', fontSize: '.85rem' }}>
                          ⏳ {t({ id: 'panel.consultation.replyStatus.pending' })}
                        </span>
                      )}
                    </>
                  ) : fmtD(c.consultation_scheduled_for)}
                </td>
                <td className="ab-painel-actions-cell">
                  {c.workflow_stage_effective === 'solicitada' && (
                    <button className="ab-button ab-button--mini" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'em_preparacao')}>{t({id:'panel.table.prepare'})}</button>
                  )}
                  {c.workflow_stage_effective === 'em_preparacao' && (
                    <button className="ab-button ab-button--mini" onClick={() => openScheduleModal(c)}>{t({ id: 'panel.loan.schedule' })}</button>
                  )}
                  {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status === 'recusado_leitor' && (
                    <button className="ab-button ab-button--mini" onClick={() => openScheduleModal(c)}>{t({ id: 'panel.consultation.action.proposeAnother' })}</button>
                  )}
                  {c.workflow_stage_effective === 'consulta_agendada' && c.consultation_starts_at && new Date(c.consultation_starts_at) < new Date() && c.schedule_reply_status !== 'recusado_leitor' && (
                    <button className="ab-button ab-button--mini ab-button--danger" onClick={() => {
                      if (window.confirm(t({ id: 'panel.consultation.noShowConfirm' }))) {
                        setConsultaWorkflow(c.consulta_id, c.line_no, 'nao_compareceu', t({ id: 'panel.consultation.noShowReason' }));
                      }
                    }}>{t({ id: 'panel.consultation.action.markNoShow' })}</button>
                  )}
                  {c.workflow_stage_effective === 'consulta_agendada' && c.schedule_reply_status !== 'recusado_leitor' && (
                    <button className="ab-button ab-button--mini" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'consulta_realizada')}>{t({id:'panel.table.completed'})}</button>
                  )}
                  {!['consulta_realizada','cancelada_leitor','cancelada_biblioteca','expirada'].includes(c.workflow_stage_effective) && (
                    <button className="ab-button ab-button--mini ab-button--danger" onClick={() => openCancelModal(c)}>{t({ id: 'common.cancel' })}</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      )}
    </div>
  );
}
