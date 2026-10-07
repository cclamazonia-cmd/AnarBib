import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { Button } from '@/components/ui';
import ContaTabHeader from '@/pages/account/ContaTabHeader';

// ═══════════════════════════════════════════════════════════
// AnarBib — l'onglet « En cours » de Mon compte (E6, AccountPage lot 4,
// 07/10/2026). Sorti d'AccountPage.jsx tel quel, lignes déplacées par script :
// les emprunts, l'état de renouvellement par item et les deux rendus partagés
// avec d'autres onglets (étiquette de bibliothèque, signal « même titre »)
// restent au parent ; les renouvellements rechargent par loadData. Les props
// portent les noms du parent.
// ═══════════════════════════════════════════════════════════

export default function TabCurso({ loans, renewStatus, loadData, renderLibTag, renderSameTitleSignal }) {
  const { formatMessage: t } = useIntl();
  return (
    <div>
      <ContaTabHeader title={t({ id: 'account.loans.title' })} onRefresh={() => loadData({ silent: true })} />
      <p className="ab-conta-hint">{t({ id: 'account.loans.hint' })}</p>
      {(() => {
        // Refonte conta curso (29/05/2026, parité painel) : items ouverts
        // GROUPÉS par emprunt — en-tête humain (date · n livres · échéance la
        // plus proche) + « Renovar tudo », puis lignes par item avec « Renovar ».
        // Les emprunts clôturés vivent dans l'onglet Histórico (groupés via
        // my_loans_history_v1) ; on ne duplique plus « Devolvidos recentemente ».
        const openItems = loans.filter(l => l.item_status === 'aberto');
        if (openItems.length === 0) {
          return <p className="ab-conta-empty">{t({ id: 'account.loans.empty' })}</p>;
        }
        const order = [];
        const groups = {};
        openItems.forEach(l => {
          if (!groups[l.emprestimo_id]) { groups[l.emprestimo_id] = []; order.push(l.emprestimo_id); }
          groups[l.emprestimo_id].push(l);
        });
        const today = new Date(); today.setHours(0, 0, 0, 0);
        return (
          <div className="ab-conta-loan-groups" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {order.map(empId => {
              const items = groups[empId];
              const checkout = items[0].emprestimo_created_at;
              // Échéance la plus proche parmi les items ouverts (peut diverger
              // après renouvellement par item).
              const dueDates = items.map(it => it.extended_until || it.due_at).filter(Boolean).sort();
              const soonest = dueDates[0] ? new Date(dueDates[0] + 'T00:00:00') : null;
              const soonestOverdue = soonest && soonest < today;
              const groupCanRenewAny = items.some(it => renewStatus[it.sub_id]?.can_renew);
              const showRenewAll = items.length >= 2;
              return (
                <div key={empId} className="ab-conta-loan-group" style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  <div className="ab-conta-loan-group__head" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, padding: '10px 14px', background: 'rgba(255,255,255,.03)' }}>
                    <div style={{ fontWeight: 600, fontSize: '.92rem' }}>
                      {checkout && <>{t({ id: 'account.loans.group.checkedOutOn' }, { date: new Date(checkout).toLocaleDateString() })}</>}
                      {' · '}{t({ id: 'account.loans.group.bookCount' }, { count: items.length })}
                      {soonest && <>{' · '}<span style={{ color: soonestOverdue ? '#ef4444' : 'inherit' }}>{t({ id: 'account.loans.group.dueBy' }, { date: soonest.toLocaleDateString() })}</span></>}
                      {(() => { const tag = renderLibTag(items[0].library_id); return tag ? <>{' · '}{tag}</> : null; })()}
                    </div>
                    {showRenewAll && (
                      <Button
                        variant="mini"
                        disabled={!groupCanRenewAny}
                        title={!groupCanRenewAny ? t({ id: 'account.renew.tooltipBlocked' }, { reason: t({ id: 'account.renew.not_renewable' }) }) : undefined}
                        onClick={async () => {
                          const { data, error } = await supabase.schema('api').rpc('renew_my_loan', { p_emprestimo_id: empId });
                          if (error) { alert(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) })); return; }
                          if (data?.ok === false) { alert(t({ id: `account.renew.${data.reason}` })); return; }
                          alert(t({ id: 'account.renew.renewed' }, { date: new Date(data.new_due_date).toLocaleDateString() }));
                          loadData();
                        }}
                      >
                        {t({ id: 'account.loans.renewAll' })}
                      </Button>
                    )}
                  </div>
                  <div className="ab-conta-loan-group__items">
                    {items.map((l, i) => {
                      const effectiveDue = l.extended_until || l.due_at;
                      const due = effectiveDue ? new Date(effectiveDue + 'T00:00:00') : null;
                      const daysLeft = due ? Math.ceil((due - today) / 86400000) : null;
                      const isOverdue = daysLeft !== null && daysLeft < 0;
                      const isSoon = daysLeft !== null && daysLeft >= 0 && daysLeft <= 3;
                      const renewInfo = renewStatus[l.sub_id] || null;
                      const renewalsUsed = renewInfo ? (renewInfo.renewals_used || 0) : 0;
                      const wasExtended = renewalsUsed > 0;
                      const canRenew = renewInfo ? renewInfo.can_renew : (!wasExtended && !isOverdue);
                      const blockingReason = renewInfo ? renewInfo.blocking_reason : null;
                      const tooltipMsg = blockingReason
                        ? t({ id: 'account.renew.tooltipBlocked' }, { reason: t({ id: `account.renew.${blockingReason}` }) })
                        : null;
                      return (
                        <div key={i} className={`ab-conta-item ${isOverdue ? 'ab-conta-item--overdue' : ''}`}
                          style={{ borderLeft: `3px solid ${isOverdue ? '#ef4444' : isSoon ? '#f59e0b' : 'transparent'}` }}>
                          <div className="ab-conta-item__main" style={{ flex: 1 }}>
                            <Link to={`/livro/${l.book_id}`} className="ab-conta-item__title">{l.titulo || l.bib_ref || '—'}</Link>
                            <span className="ab-conta-item__meta">{l.autor || '—'}</span>
                            <span className="ab-conta-item__meta">
                              ref: {l.bib_ref || '—'}
                              {due && <> · {t({ id: 'account.loans.deadline' })}: <strong style={{ color: isOverdue ? '#ef4444' : isSoon ? '#f59e0b' : 'inherit' }}>{due.toLocaleDateString()}</strong></>}
                              {daysLeft !== null && (isOverdue
                                ? <> · <strong style={{ color: '#ef4444' }}>{t({ id: 'account.loans.daysOverdue' }, { days: Math.abs(daysLeft) })}</strong></>
                                : <> · {t({ id: 'account.loans.daysLeft' }, { days: daysLeft })}</>)}
                            </span>
                            {wasExtended && <span className="ab-conta-item__meta" style={{ color: '#60a5fa' }}>{t({ id: 'account.loans.renewedUntil' }, { date: new Date(l.extended_until + 'T00:00:00').toLocaleDateString() })}</span>}
                            {renderSameTitleSignal(l.titulo)}
                          </div>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                            {!(isOverdue || (wasExtended && !canRenew)) && (
                              <Button
                                variant="mini"
                                disabled={!canRenew}
                                title={tooltipMsg || undefined}
                                onClick={async () => {
                                  const { data, error } = await supabase.schema('api').rpc('renew_my_loan_item', { p_emprestimo_id: l.emprestimo_id, p_line_no: l.line_no });
                                  if (error) { alert(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) })); return; }
                                  if (data?.ok === false) { alert(t({ id: `account.renew.${data.reason}` })); return; }
                                  alert(t({ id: 'account.renew.renewed' }, { date: new Date(data.new_due_date).toLocaleDateString() }));
                                  loadData();
                                }}
                              >
                                {t({ id: 'account.loans.renew' })}
                              </Button>
                            )}
                            {wasExtended && <span style={{ fontSize: '.72rem', color: '#60a5fa', fontWeight: 600 }}>{t({ id: 'account.loans.renewed' })}</span>}
                            {isOverdue && <span style={{ fontSize: '.72rem', color: '#ef4444', fontWeight: 600 }}>{t({ id: 'account.loans.overdue' })}</span>}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        );
      })()}
    </div>
  );
}
