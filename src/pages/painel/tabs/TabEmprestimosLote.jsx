import { Link } from 'react-router-dom';
import { EmptyState } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';
import { fmtD, TabHeader } from '../_shared';

// ═══════════════════════════════════════════════════════════
// TabEmprestimosLote — onglet « Emprunts groupés » (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extrait de PanelPage.jsx (bloc tab === 'emprestimos-lote').
// Présentational : état et handlers de circulation restent dans
// PanelPage, passés en props. notifyError vient du contexte toast
// (même pattern que TaskBucket). Iso-comportement strict.
// ═══════════════════════════════════════════════════════════
export default function TabEmprestimosLote({
  t,
  activeLoans,
  loteStatusFilter,
  setLoteStatusFilter,
  loteSortKey,
  setLoteSortKey,
  EMPRESTIMO_STATUS_LABELS,
  extendLoan,
  loadData,
}) {
  const { notifyError } = useToast();
  return (
    <div>
      <TabHeader title={t({ id: 'panel.loan.grouped' })} onRefresh={loadData} />

      {/* EA-08 (chantier B, 27/05/2026) : controles filtre + tri. */}
      <div className="ab-painel-lote-controls" style={{ display: 'flex', gap: 12, marginBottom: 12, flexWrap: 'wrap' }}>
        <div>
          <label style={{ marginRight: 8 }}>{t({ id: 'panel.loanGrouped.filter' })}</label>
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
          <label style={{ marginRight: 8 }}>{t({ id: 'panel.loanGrouped.sort' })}</label>
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

      {(() => {
        const grouped = {};
        // Audit UX 25/05/2026 (P1) : ne grouper que les emprunts ayant
        // au moins un item ouvert. Les emprunts entierement clotures
        // vont dans l'onglet Historique.
        activeLoans.forEach(l => {
          if (!grouped[l.emprestimo_id]) grouped[l.emprestimo_id] = { ...l, items: [] };
          grouped[l.emprestimo_id].items.push(l);
        });
        // EA-08 (chantier B, 27/05/2026) : filtre par emprestimo_status
        // puis tri selon la cle choisie. Tri par defaut : echeances les
        // plus proches en premier (sens metier au comptoir).
        // BUG fix (28/05/2026) : 'aberto' filtrait trop strict — un emprunt
        // dont un seul item est rendu passe en parcialmente_devolvido cote DB.
        // La semantique "Aberto" cote UX inclut tout ce qui n'est pas clos,
        // en coherence avec le backend (fn_check_loan_action v_active_status).
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
        if (groups.length === 0) {
          return <EmptyState message={t({ id: 'panel.loanGrouped.empty' })} />;
        }
        return groups.map((g, i) => {
          // Paquet 19 v2 (11/05/2026) : bouton Prorrogar disponible si emprunt actif
          // (aberto OU parcialmente_devolvido) et non deja prolonge. Meme logique
          // que le RPC api.extend_loan_as_library qui accepte les deux statuts via
          // fn_check_loan_action (v_active_status = aberto OU parcialmente_devolvido).
          // BUG-lote-extend (28/05/2026) : ajout 'parcialmente_devolvido', le statut
          // strict 'aberto' empechait l'extension d'un emprunt aux items mixtes.
          const canExtend = ['aberto', 'parcialmente_devolvido'].includes(g.emprestimo_status)
            && !g.extended_once
            && !g.extended_until;
          // Paquet 19 v3 (11/05/2026) : bouton Restituer tout disponible si au
          // moins un item est encore ouvert dans l'emprunt
          const hasOpenItem = g.items.some(it => it.item_status === 'aberto');
          return (
          <div key={i} className="ab-painel-lote">
            <div className="ab-painel-lote__head" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
              <div>
                <strong>#{g.emprestimo_id}</strong> · {g.user_name || g.user_email || g.user_public_id || '—'} · {g.items.length} {t({id:'panel.loan.items'},{count:g.items.length})} · {t({id:'panel.task.detail.deadline'})}: {fmtD(g.due_at)} · {EMPRESTIMO_STATUS_LABELS[g.emprestimo_status] || t({ id: 'panel.stage.unknown' })}
              </div>
              <div style={{ display: 'flex', gap: 6 }}>
                {hasOpenItem && (
                  <button className="ab-button ab-button--mini" onClick={async () => {
                    try {
                      const { error } = await supabase.schema('api').rpc('return_loan_total', { p_emprestimo_id: g.emprestimo_id });
                      if (error) throw error;
                      loadData();
                    } catch (e) { notifyError(localizeError(e, t, 'panel.error.loanReturn'), e); }
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
            <div className="ab-painel-lote__items">
              {g.items.map((l, j) => (
                <div key={j} className="ab-painel-lote__item">
                  {l.sub_id} · <Link to={`/livro/${l.book_id}`}>{l.titulo || l.bib_ref}</Link> · {l.item_status === 'aberto' ? t({id:'panel.loan.inProgress'}) : t({id:'panel.loan.returned'})}
                </div>
              ))}
            </div>
          </div>
          );
        });
      })()}
    </div>
  );
}
