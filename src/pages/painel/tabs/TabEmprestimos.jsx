import { Link } from 'react-router-dom';
import { EmptyState } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';
import { fmtD, TabHeader } from '../_shared';
import LoanDepositPanel from '@/components/deposit/LoanDepositPanel';

// ═══════════════════════════════════════════════════════════
// TabEmprestimos — onglet « Emprunts » fusionné
// (chantier E.3 / EA-07, 29/05/2026)
// ───────────────────────────────────────────────────────────
// Fusion iso-fonctionnelle des anciens TabEmprestimosLivro
// (vue par item, tableau triable) et TabEmprestimosLote
// (vue groupée par emprunt). Tout passe en lignes maitresses
// dépliables : ligne d'emprunt avec actions (Retourner tout +
// Prolonger), bloc déplié avec items individuels et action
// retour par item.
//
// Choix UX (acté avec Xavier 29/05/2026) :
//   - Toutes les lignes sont dépliables (y compris emprunts à
//     1 item) pour homogénéité visuelle.
//   - "Retourner tout" sur la ligne maitresse : exécution
//     directe via window.confirm (la ligne fait office de
//     contexte, pas besoin de la mécanique preview EA-03).
//   - "Devolver" sur la sous-ligne : appel direct du handler
//     returnLoanItem existant (1 sub_id).
//   - Le tri se fait au niveau emprunt entier (pas par item).
// ═══════════════════════════════════════════════════════════
export default function TabEmprestimos({
  t,
  activeLoans,
  loans,
  loteStatusFilter,
  setLoteStatusFilter,
  loteSortKey,
  setLoteSortKey,
  EMPRESTIMO_STATUS_LABELS,
  expandedLoans,
  toggleExpandedLoan,
  extendLoan,
  returnLoanItem,
  extendLoanItem,
  renewStatusByItem = {},
  loadData,
}) {
  const { notifyError } = useToast();

  // Compteurs par emprunt : items rendus / total. Calculé depuis
  // `loans` (non filtré) pour avoir le total y compris les items
  // déjà rendus. `activeLoans` ne contient que les items 'aberto'.
  const itemCounts = {};
  loans.forEach(l => {
    if (!itemCounts[l.emprestimo_id]) itemCounts[l.emprestimo_id] = { open: 0, total: 0 };
    itemCounts[l.emprestimo_id].total++;
    if (l.item_status === 'aberto') itemCounts[l.emprestimo_id].open++;
  });

  // Groupement des items 'aberto' par emprestimo_id.
  // Audit UX 25/05/2026 (P1) : on ne groupe que les emprunts ayant
  // au moins un item ouvert. Les emprunts entièrement clôturés vont
  // dans l'onglet Histórico.
  const grouped = {};
  activeLoans.forEach(l => {
    if (!grouped[l.emprestimo_id]) grouped[l.emprestimo_id] = { ...l, items: [] };
    grouped[l.emprestimo_id].items.push(l);
  });

  // Filtre + tri (récupérés iso de TabEmprestimosLote, incluant le fix
  // BUG-aberto-filter du 28/05).
  const groups = Object.values(grouped)
    .filter(g => {
      if (loteStatusFilter === 'all') return true;
      if (loteStatusFilter === 'aberto')
        return ['aberto', 'parcialmente_devolvido'].includes(g.emprestimo_status);
      return g.emprestimo_status === loteStatusFilter;
    })
    .sort((a, b) => {
      switch (loteSortKey) {
        case 'due_at_asc':   return (a.due_at || '\uffff') < (b.due_at || '\uffff') ? -1 : 1;
        case 'due_at_desc':  return (a.due_at || '') > (b.due_at || '') ? -1 : 1;
        case 'emprestimo_id_desc': return (b.emprestimo_id || 0) - (a.emprestimo_id || 0);
        case 'emprestimo_id_asc':  return (a.emprestimo_id || 0) - (b.emprestimo_id || 0);
        case 'user_name':    return (a.user_name || '').localeCompare(b.user_name || '');
        default: return 0;
      }
    });

  return (
    <div>
      <TabHeader title={t({ id: 'panel.tab.loans' })} onRefresh={loadData} />

      {/* Toolbar : filtre statut + tri. Repris iso de TabEmprestimosLote. */}
      <div className="ab-painel-lote-controls">
        <div>
          <label>{t({ id: 'panel.loanGrouped.filter' })}</label>
          <select
            value={loteStatusFilter}
            onChange={e => setLoteStatusFilter(e.target.value)}
            className="ab-painel-input"
          >
            <option value="all">{t({ id: 'panel.loanGrouped.filter.all' })}</option>
            <option value="aberto">{t({ id: 'panel.loanGrouped.filter.aberto' })}</option>
            <option value="parcialmente_devolvido">{t({ id: 'panel.loanGrouped.filter.partial' })}</option>
          </select>
        </div>
        <div>
          <label>{t({ id: 'panel.loanGrouped.sort' })}</label>
          <select
            value={loteSortKey}
            onChange={e => setLoteSortKey(e.target.value)}
            className="ab-painel-input"
          >
            <option value="due_at_asc">{t({ id: 'panel.loanGrouped.sort.dueAsc' })}</option>
            <option value="due_at_desc">{t({ id: 'panel.loanGrouped.sort.dueDesc' })}</option>
            <option value="emprestimo_id_desc">{t({ id: 'panel.loanGrouped.sort.recent' })}</option>
            <option value="emprestimo_id_asc">{t({ id: 'panel.loanGrouped.sort.oldest' })}</option>
            <option value="user_name">{t({ id: 'panel.loanGrouped.sort.reader' })}</option>
          </select>
        </div>
      </div>

      {groups.length === 0 ? (
        <EmptyState message={t({ id: 'panel.loanGrouped.empty' })} />
      ) : (
        groups.map(g => {
          const isExpanded = expandedLoans.has(g.emprestimo_id);
          // Paquet 19 v2 + fix BUG-lote-extend (28/05/2026) : extension dispo
          // si emprunt actif (aberto OU parcialmente_devolvido) et non déjà prolongé.
          const canExtend = ['aberto', 'parcialmente_devolvido'].includes(g.emprestimo_status)
            && !g.extended_once
            && !g.extended_until;
          const hasOpenItem = g.items.length > 0;
          const counts = itemCounts[g.emprestimo_id] || { open: g.items.length, total: g.items.length };
          // Granularité (29/05/2026) : échéance effective du lot = la plus proche
          // des items ouverts (extended_until || due_at), pour refléter les
          // renouvellements par item dans l'en-tête maître.
          const groupDue = (g.items || [])
            .map(it => it.extended_until || it.due_at)
            .filter(Boolean)
            .sort()[0] || g.due_at;

          return (
            <div key={g.emprestimo_id} className="ab-painel-lote">
              <div
                className="ab-painel-lote__head"
               
                onClick={() => toggleExpandedLoan(g.emprestimo_id)}
                role="button"
                tabIndex={0}
                onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleExpandedLoan(g.emprestimo_id); } }}
                aria-expanded={isExpanded}
              >
                <div>
                  <span className="ab-painel-lote__caret">
                    {isExpanded ? '▾' : '▸'}
                  </span>
                  <strong>#{g.emprestimo_id}</strong> · {g.user_name || g.user_email || g.user_public_id || '—'}
                  {' · '}{t({id:'panel.loan.itemsReturned'}, { returned: counts.total - counts.open, total: counts.total })}
                  {' · '}{t({id:'panel.task.detail.deadline'})}: {fmtD(groupDue)}
                  {' · '}{EMPRESTIMO_STATUS_LABELS[g.emprestimo_status] || t({ id: 'panel.stage.unknown' })}
                </div>
                {/* Actions : on stoppe la propagation du clic pour éviter
                    qu'un clic sur "Prolonger" ne déplie/replie la ligne. */}
                <div className="ab-painel-lote__actions" onClick={e => e.stopPropagation()}>
                  {hasOpenItem && (
                    <button className="ab-button ab-button--mini" onClick={async () => {
                      // EA-07 (29/05/2026) : confirmation modale en remplacement
                      // de la mécanique preview EA-03 — le contexte visuel de la
                      // ligne fait office de preview (id, lecteur, count visibles).
                      if (!window.confirm(t({id:'panel.loan.returnAllConfirm'}, {id: g.emprestimo_id, count: counts.open}))) return;
                      try {
                        const { error } = await supabase.schema('api').rpc('return_loan_total', { p_emprestimo_id: g.emprestimo_id });
                        if (error) throw error;
                        loadData();
                      } catch (e) {
                        notifyError(localizeError(e, t, 'panel.error.loanReturn'), e);
                      }
                    }}>
                      {t({id:'panel.loan.returnFull'})}
                    </button>
                  )}
                  {canExtend && (
                    <button className="ab-button ab-button--secondary ab-button--mini" onClick={() => extendLoan(g.emprestimo_id)}>
                      {t({id:'panel.table.extend'})}
                    </button>
                  )}
                </div>
              </div>
              <LoanDepositPanel emprestimoId={g.emprestimo_id} />
              {isExpanded && (
                <div className="ab-painel-lote__items">
                  {g.items.map(l => (
                    <div
                      key={l.line_no}
                      className="ab-painel-lote__item"
                    >
                      <span className="ab-painel-lote__subid">{l.sub_id}</span>
                      <Link to={`/livro/${l.book_id}`}>{l.titulo || l.bib_ref}</Link>
                      {(l.extended_until || l.due_at) && (
                        <span className={`ab-painel-lote__due ${l.extended_until ? 'ab-painel-lote__due--extended' : ''}`}>
                          {fmtD(l.extended_until || l.due_at)}
                        </span>
                      )}
                      <span className="ab-painel-lote__item-actions">
                        <span className={`ab-painel-loan-status ab-painel-loan-status--${l.item_status}`}>
                          {l.item_status === 'aberto' ? t({id:'panel.loan.status.open'}) : t({id:'panel.loan.status.returned'})}
                        </span>
                        {l.item_status === 'aberto' && (
                          <button
                            className="ab-button ab-button--mini"
                            onClick={() => returnLoanItem(l.emprestimo_id, [l.line_no])}
                          >
                            {t({id:'panel.loan.return.btn'})}
                          </button>
                        )}
                        {/* Granularité Phase 4 (29/05/2026) : prolongation PAR ITEM,
                            affichée si l'item est éligible (api.staff_loans_renewal_status_by_item_v1).
                            Résout BUG-lote-extend (Prolonger absent sur emprunts partiellement rendus). */}
                        {l.item_status === 'aberto' && renewStatusByItem[l.sub_id]?.can_renew && (
                          <button
                            className="ab-button ab-button--secondary ab-button--mini"
                            onClick={() => extendLoanItem(l.emprestimo_id, l.line_no)}
                          >
                            {t({id:'panel.table.extend'})}
                          </button>
                        )}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })
      )}
    </div>
  );
}
