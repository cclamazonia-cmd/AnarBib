import { Link } from 'react-router-dom';
import { EmptyState } from '@/components/ui';
import { fmtD, UserDisplay, SortHeader, TabHeader } from '../_shared';

// ═══════════════════════════════════════════════════════════
// TabEmprestimosLivro — onglet « Emprunts » (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'emprestimos-livro').
// Composant de présentation : tout l'état et les handlers restent
// dans PanelPage, passés ici en props. Iso-comportement strict.
// ═══════════════════════════════════════════════════════════
export default function TabEmprestimosLivro({ t, sortLoans, returnLoanItem, extendLoan, loadData }) {
  return (
    <div>
      <TabHeader title={t({ id: 'panel.tab.loans' })} onRefresh={loadData} />
      {sortLoans.sortedItems.length === 0 ? (
        <EmptyState message={t({ id: 'panel.loans.empty' })} />
      ) : (
      <div className="ab-painel-table-wrap">
        <table className="ab-painel-table">
          <thead><tr>
            <SortHeader sortKey="sub_id" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.subId'})}</SortHeader>
            <SortHeader sortKey="user_name" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.reader'})}</SortHeader>
            <SortHeader sortKey="titulo" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.book'})}</SortHeader>
            <SortHeader sortKey="bib_ref" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.ref'})}</SortHeader>
            <SortHeader sortKey="rotulo" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.label'})}</SortHeader>
            <SortHeader sortKey="emprestimo_created_at" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.exit'})}</SortHeader>
            <SortHeader sortKey="due_at" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.deadline'})}</SortHeader>
            <SortHeader sortKey="extended_until" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.extended'})}</SortHeader>
            <SortHeader sortKey="item_status" current={sortLoans.sortKey} dir={sortLoans.sortDir} onClick={sortLoans.toggleSort}>{t({id:'panel.table.status'})}</SortHeader>
            <th>{t({id:'panel.table.actions'})}</th>
          </tr></thead>
          <tbody>
            {sortLoans.sortedItems.map((l, i) => (
              <tr key={i} className={l.item_status === 'aberto' && l.due_at && new Date(l.due_at) < new Date() ? 'overdue' : ''}>
                <td>{l.sub_id}</td>
                <td>
                  <UserDisplay
                    name={l.user_name}
                    email={l.user_email}
                    publicId={l.user_public_id}
                    userId={l.user_id}
                  />
                </td>
                <td><Link to={`/livro/${l.book_id}`}>{l.titulo || '—'}</Link></td>
                <td>{l.bib_ref}</td>
                <td>{l.rotulo || '—'}</td>
                <td>{fmtD(l.emprestimo_created_at)}</td>
                <td>{fmtD(l.due_at)}</td>
                <td>{l.extended_until ? fmtD(l.extended_until) : '—'}</td>
                <td><span className={`ab-painel-loan-status ab-painel-loan-status--${l.item_status}`}>{l.item_status === 'aberto' ? t({ id: 'panel.loan.status.open' }) : t({ id: 'panel.loan.status.returned' })}</span></td>
                <td className="ab-painel-actions-cell">
                  {l.item_status === 'aberto' && (
                    <>
                      <button className="ab-button ab-button--mini" onClick={() => returnLoanItem(l.emprestimo_id, [l.line_no])}>{t({ id: 'panel.loan.return.btn' })}</button>
                      {!l.extended_once && !l.extended_until && (
                        <button className="ab-button ab-button--secondary ab-button--mini" onClick={() => extendLoan(l.emprestimo_id)}>{t({id:'panel.table.extend'})}</button>
                      )}
                    </>
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
