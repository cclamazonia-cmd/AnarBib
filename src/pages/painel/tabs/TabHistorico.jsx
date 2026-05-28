import { TabHeader } from '../_shared';
// ═══════════════════════════════════════════════════════════
// TabHistorico — onglet « Historique » (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'historico').
// Présentational : état (historyTypes/Data/HasMore/Loading) et
// handlers (toggleHistoryType, loadHistorySection) restent dans
// PanelPage, passés ici en props. Iso-comportement strict.
// ═══════════════════════════════════════════════════════════
export default function TabHistorico({
  t,
  historyTypes,
  historyData,
  historyHasMore,
  historyLoading,
  toggleHistoryType,
  loadHistorySection,
  refreshHistorico,
}) {
  return (
    <div>
      <TabHeader title={t({ id: 'panel.history.title' })} onRefresh={refreshHistorico} />
      <p className="ab-painel-hint">{t({ id: 'panel.history.subtitle' })}</p>

      <div className="ab-painel-history-filters">
        {['reservas', 'consultas', 'emprestimos'].map(type => (
          <button
            key={type}
            type="button"
            className={`ab-painel-history-pill ${(historyTypes || new Set()).has(type) ? 'active' : ''}`}
            onClick={() => toggleHistoryType(type)}
            aria-pressed={(historyTypes || new Set()).has(type)}
          >
            {t({ id: `panel.history.filter.${type}` })}
          </button>
        ))}
      </div>

      {(historyTypes || new Set()).size === 0 ? (
        <p className="ab-painel-hint">{t({ id: 'panel.history.noFilter' })}</p>
      ) : (
        <div className="ab-painel-history-list">

          {/* Section Reservations */}
          {(historyTypes || new Set()).has('reservas') && (
            <details className="ab-painel-history-section">
              <summary className="ab-painel-history-section__summary">
                <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.reservations' })}</span>
                <span className="ab-painel-history-section__count">
                  {t({ id: 'panel.history.itemsCount' }, { count: historyData.reservas.length })}
                </span>
              </summary>
              <div className="ab-painel-history-section__body">
                {historyLoading.reservas && historyData.reservas.length === 0 ? (
                  <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                ) : historyData.reservas.length === 0 ? (
                  <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                ) : (
                  <>
                    <div className="ab-painel-table-wrap">
                      <table className="ab-painel-history-table">
                        <thead>
                          <tr>
                            <th>{t({ id: 'panel.history.col.title' })}</th>
                            <th>{t({ id: 'panel.history.col.status' })}</th>
                            <th>{t({ id: 'panel.history.col.reader' })}</th>
                            <th>{t({ id: 'panel.history.col.requested' })}</th>
                            <th>{t({ id: 'panel.history.col.closed' })}</th>
                            <th>{t({ id: 'panel.history.col.motif' })}</th>
                          </tr>
                        </thead>
                        <tbody>
                          {historyData.reservas.map((r, i) => (
                            <tr key={`hr-${r.reserva_item_id || r.reserva_id + '-' + r.line_no || i}`}>
                              <td data-label={t({ id: 'panel.history.col.title' })}>
                                <div className="truncate">{r.titulo || r.bib_ref || '—'}</div>
                              </td>
                              <td data-label={t({ id: 'panel.history.col.status' })}>
                                {t({ id: `reservation.stage.${r.item_status}`, defaultMessage: t({ id: 'panel.stage.unknown' }) })}
                              </td>
                              <td data-label={t({ id: 'panel.history.col.reader' })}>
                                {r.user_name || r.user_email || r.user_public_id || '—'}
                              </td>
                              <td data-label={t({ id: 'panel.history.col.requested' })}>
                                {r.requested_at ? new Date(r.requested_at).toLocaleDateString() : '—'}
                              </td>
                              <td data-label={t({ id: 'panel.history.col.closed' })}>
                                {r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '—'}
                              </td>
                              <td data-label={t({ id: 'panel.history.col.motif' })} className="cell-motif">
                                {r.workflow_note || '—'}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                    {historyHasMore.reservas && (
                      <div className="ab-painel-history-loadmore">
                        <button type="button"
                          onClick={() => loadHistorySection('reservas', true)}
                          disabled={historyLoading.reservas}>
                          {historyLoading.reservas ? '...' : t({ id: 'panel.history.loadMore' })}
                        </button>
                      </div>
                    )}
                  </>
                )}
              </div>
            </details>
          )}

          {/* Section Consultas */}
          {(historyTypes || new Set()).has('consultas') && (
            <details className="ab-painel-history-section">
              <summary className="ab-painel-history-section__summary">
                <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.consultas' })}</span>
                <span className="ab-painel-history-section__count">
                  {t({ id: 'panel.history.itemsCount' }, { count: historyData.consultas.length })}
                </span>
              </summary>
              <div className="ab-painel-history-section__body">
                {historyLoading.consultas && historyData.consultas.length === 0 ? (
                  <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                ) : historyData.consultas.length === 0 ? (
                  <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                ) : (
                  <>
                    <div className="ab-painel-table-wrap">
                      <table className="ab-painel-history-table">
                        <thead>
                          <tr>
                            <th>{t({ id: 'panel.history.col.title' })}</th>
                            <th>{t({ id: 'panel.history.col.status' })}</th>
                            <th>{t({ id: 'panel.history.col.reader' })}</th>
                            <th>{t({ id: 'panel.history.col.scheduled' })}</th>
                            <th>{t({ id: 'panel.history.col.closed' })}</th>
                            <th>{t({ id: 'panel.history.col.motif' })}</th>
                          </tr>
                        </thead>
                        <tbody>
                          {historyData.consultas.map((c, i) => {
                            const motif = c.schedule_reply_note || c.workflow_note;
                            return (
                              <tr key={`hc-${c.consulta_item_id || c.consulta_id + '-' + c.line_no || i}`}>
                                <td data-label={t({ id: 'panel.history.col.title' })}>
                                  <div className="truncate">{c.titulo || c.bib_ref || '—'}</div>
                                </td>
                                <td data-label={t({ id: 'panel.history.col.status' })}>
                                  {t({ id: `consultation.stage.${c.item_status}`, defaultMessage: t({ id: 'panel.stage.unknown' }) })}
                                </td>
                                <td data-label={t({ id: 'panel.history.col.reader' })}>
                                  {c.user_name || c.user_email || c.user_public_id || '—'}
                                </td>
                                <td data-label={t({ id: 'panel.history.col.scheduled' })}>
                                  {c.scheduled_for ? new Date(c.scheduled_for).toLocaleDateString() : '—'}
                                </td>
                                <td data-label={t({ id: 'panel.history.col.closed' })}>
                                  {c.closed_at ? new Date(c.closed_at).toLocaleDateString() : '—'}
                                </td>
                                <td data-label={t({ id: 'panel.history.col.motif' })} className="cell-motif">
                                  {motif || '—'}
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                    {historyHasMore.consultas && (
                      <div className="ab-painel-history-loadmore">
                        <button type="button"
                          onClick={() => loadHistorySection('consultas', true)}
                          disabled={historyLoading.consultas}>
                          {historyLoading.consultas ? '...' : t({ id: 'panel.history.loadMore' })}
                        </button>
                      </div>
                    )}
                  </>
                )}
              </div>
            </details>
          )}

          {/* Section Emprestimos */}
          {(historyTypes || new Set()).has('emprestimos') && (
            <details className="ab-painel-history-section">
              <summary className="ab-painel-history-section__summary">
                <span className="ab-painel-history-section__title">{t({ id: 'panel.history.section.emprestimos' })}</span>
                <span className="ab-painel-history-section__count">
                  {t({ id: 'panel.history.itemsCount' }, { count: historyData.emprestimos.length })}
                </span>
              </summary>
              <div className="ab-painel-history-section__body">
                {historyLoading.emprestimos && historyData.emprestimos.length === 0 ? (
                  <p className="ab-painel-hint">{t({ id: 'common.loading' })}</p>
                ) : historyData.emprestimos.length === 0 ? (
                  <p className="ab-painel-hint">{t({ id: 'panel.history.section.empty' })}</p>
                ) : (
                  <>
                    <div className="ab-painel-table-wrap">
                      <table className="ab-painel-history-table">
                        <thead>
                          <tr>
                            <th>{t({ id: 'panel.history.col.items' })}</th>
                            <th>{t({ id: 'panel.history.col.type' })}</th>
                            <th>{t({ id: 'panel.history.col.reader' })}</th>
                            <th>{t({ id: 'panel.history.col.returned' })}</th>
                          </tr>
                        </thead>
                        <tbody>
                          {historyData.emprestimos.map((e, i) => (
                            <tr key={`he-${e.emprestimo_id || i}`}>
                              <td data-label={t({ id: 'panel.history.col.items' })}>
                                <div className="truncate" title={e.titulos || ''}>
                                  {e.titulos || e.bib_refs || '—'}
                                </div>
                              </td>
                              <td data-label={t({ id: 'panel.history.col.type' })}>
                                <span className="ab-painel-history-typepill" data-type={e.loan_type}>
                                  {/* PATCH EA-13 (27/05/2026) : defaultMessage en i18n
                                      au lieu de e.loan_type brut. Valeurs connues : groupe, uni. */}
                                  {t({ id: `panel.history.type.${e.loan_type}`, defaultMessage: t({ id: 'panel.stage.unknown' }) })}
                                  {e.items_count > 1 && ` (${e.items_count})`}
                                </span>
                              </td>
                              <td data-label={t({ id: 'panel.history.col.reader' })}>
                                {e.user_name || e.user_email || e.user_public_id || '—'}
                              </td>
                              <td data-label={t({ id: 'panel.history.col.returned' })}>
                                {e.returned_at ? new Date(e.returned_at).toLocaleDateString() : '—'}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                    {historyHasMore.emprestimos && (
                      <div className="ab-painel-history-loadmore">
                        <button type="button"
                          onClick={() => loadHistorySection('emprestimos', true)}
                          disabled={historyLoading.emprestimos}>
                          {historyLoading.emprestimos ? '...' : t({ id: 'panel.history.loadMore' })}
                        </button>
                      </div>
                    )}
                  </>
                )}
              </div>
            </details>
          )}

        </div>
      )}
    </div>
  );
}
