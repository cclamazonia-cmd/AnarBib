import { useState, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useToast } from '@/contexts/ToastContext';

// ═══════════════════════════════════════════════════════════
// Helpers et composants partagés du Painel (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Extraits de PanelPage.jsx lors du découpage par onglet. Code
// rigoureusement identique à l'original (iso-comportement).
// ═══════════════════════════════════════════════════════════

export function fmtD(d) { if (!d) return '—'; try { return new Date(d).toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'short' }); } catch { return d; } }

// ═══════════════════════════════════════════════════════════
// UserDisplay — composant interne (paquet 5f)
// ───────────────────────────────────────────────────────────
// Affiche un·e lecteur·rice dans une cellule de tableau ou un item de
// liste : nom complet sur la ligne principale, code public_id (ex:
// U0000030) en sous-titre discret en dessous.
//
// Cascade de fallback pour la ligne principale :
//   user_name → user_email → fragment d'UUID (8 premiers chars)
//
// Le sous-titre public_id n'est affiché que si :
//   - user_public_id est dispo (sinon rien à montrer en sous-titre)
//   - ET la ligne principale n'est PAS déjà l'UUID (sinon redondance)
//
// Cohérent avec le pattern existant emprestimo_itens_painel_ui qui
// expose user_public_id depuis le paquet 5e.
// ═══════════════════════════════════════════════════════════
export function UserDisplay({ name, email, publicId, userId, fallback = '—' }) {
  const main = name || email || (userId ? userId.slice(0, 8) : fallback);
  const showSub = publicId && (name || email);
  return (
    <div className="ab-painel-user-display">
      <span>{main}</span>
      {showSub && <span className="ab-painel-user-display__sub">{publicId}</span>}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// useSort — hook pour tri ascendant/descendant sur un tableau (paquet 18)
// ───────────────────────────────────────────────────────────
// Usage :
//   const { sortedItems, sortKey, sortDir, toggleSort } = useSort(items);
//   <SortHeader sortKey="due_at" current={sortKey} dir={sortDir} onClick={toggleSort}>Échéance</SortHeader>
//   ... sortedItems.map(...)
//
// toggleSort(key) : null → asc → desc → null (cycle 3 etats).
// Si null, l'ordre original est preserve.
// ═══════════════════════════════════════════════════════════
export function useSort(items) {
  const [sortKey, setSortKey] = useState(null);
  const [sortDir, setSortDir] = useState(null);

  const toggleSort = (key) => {
    if (sortKey !== key) { setSortKey(key); setSortDir('asc'); return; }
    if (sortDir === 'asc') { setSortDir('desc'); return; }
    if (sortDir === 'desc') { setSortKey(null); setSortDir(null); return; }
  };

  const sortedItems = useMemo(() => {
    if (!sortKey || !sortDir) return items;
    const arr = [...items];
    arr.sort((a, b) => {
      const va = a?.[sortKey], vb = b?.[sortKey];
      // null/undefined toujours en bas
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      // dates ISO (heuristique : string commencant par YYYY-)
      const isaDate = typeof va === 'string' && /^\d{4}-\d{2}-\d{2}/.test(va);
      const isbDate = typeof vb === 'string' && /^\d{4}-\d{2}-\d{2}/.test(vb);
      if (isaDate && isbDate) {
        const cmp = new Date(va).getTime() - new Date(vb).getTime();
        return sortDir === 'asc' ? cmp : -cmp;
      }
      // nombres (y compris strings purement numeriques)
      const na = Number(va), nb = Number(vb);
      if (!Number.isNaN(na) && !Number.isNaN(nb) && typeof va !== 'object' && typeof vb !== 'object') {
        const cmp = na - nb;
        if (cmp !== 0) return sortDir === 'asc' ? cmp : -cmp;
      }
      // fallback : comparaison string
      const sa = String(va), sb = String(vb);
      const cmp = sa.localeCompare(sb, undefined, { numeric: true, sensitivity: 'base' });
      return sortDir === 'asc' ? cmp : -cmp;
    });
    return arr;
  }, [items, sortKey, sortDir]);

  return { sortedItems, sortKey, sortDir, toggleSort };
}

// ═══════════════════════════════════════════════════════════
// SortHeader — composant <th> cliquable avec fleche (paquet 18)
// ═══════════════════════════════════════════════════════════
export function SortHeader({ sortKey, current, dir, onClick, children }) {
  const { formatMessage: t } = useIntl();
  const isActive = current === sortKey;
  const arrow = isActive ? (dir === 'asc' ? ' ↑' : ' ↓') : '';
  return (
    <th onClick={() => onClick(sortKey)} style={{ cursor: 'pointer', userSelect: 'none' }} title={t({ id: 'panel.sort.tooltip' })}>
      {children}{arrow}
    </th>
  );
}

// ═══════════════════════════════════════════════════════════
// StageFilterBar — barre de filtres par étape (pills + compteurs)
// ───────────────────────────────────────────────────────────
// Partagée entre les onglets consultas-locais et reservas.
// Extraite de PanelPage.jsx (chantier E.1 / OT-4), iso-comportement.
// ═══════════════════════════════════════════════════════════
export function StageFilterBar({ counts, current, onSelect, labels, allLabel, unknownLabel }) {
  const total = [...counts.values()].reduce((a, b) => a + b, 0);
  return (
    <div className="ab-painel-stage-filter">
      <button
        type="button"
        className={`ab-painel-stage-pill ${current === 'all' ? 'active' : ''}`}
        onClick={() => onSelect('all')}
        aria-pressed={current === 'all'}
      >
        {allLabel} ({total})
      </button>
      {[...counts.entries()].map(([stage, n]) => (
        <button
          key={stage}
          type="button"
          className={`ab-painel-stage-pill ${current === stage ? 'active' : ''}`}
          onClick={() => onSelect(stage)}
          aria-pressed={current === stage}
        >
          {(labels && labels[stage]) || unknownLabel || stage} ({n})
        </button>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// SummaryCard — carte de compteur (résumé) (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Partagée entre le Hero/résumé et l'onglet trabalho-do-dia.
// ═══════════════════════════════════════════════════════════
export function SummaryCard({ label, count, variant = 'default' }) {
  return (
    <div className={`ab-painel-summary ab-painel-summary--${variant}`}>
      <span className="ab-painel-summary__count">{count}</span>
      <span className="ab-painel-summary__label">{label}</span>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// TaskBucket — panier de tâches du jour (chantier E.1 / OT-4)
// ───────────────────────────────────────────────────────────
// Utilisé par l'onglet trabalho-do-dia. Autonome : récupère t et
// notifyError via hooks ; setTab et onTaskAction passés en props.
// ═══════════════════════════════════════════════════════════
export function TaskBucket({ title, tasks, setTab, onTaskAction }) {
  const { formatMessage: t } = useIntl();
  const { notifyError } = useToast();
  return (
    <div className="ab-painel-task-bucket">
      <h3 className="ab-painel-h3">{title} ({tasks.length})</h3>
      <div className="ab-painel-items">
        {tasks.map((tk, i) => (
          <div key={i} className={`ab-painel-item ${tk.priority === 'alta' ? 'ab-painel-item--overdue' : ''}`}>
            <div>
              <span className="ab-painel-item__title">{tk.kind}</span>
              <span className="ab-painel-item__meta">{tk.label}</span>
              <span className="ab-painel-item__meta">{tk.detail}</span>
            </div>
            <div className="ab-painel-item__btn-row">
              <span className={`ab-painel-task-priority ab-painel-task-priority--${tk.priority}`}>
                {tk.priority === 'alta' ? t({id:'panel.task.priority.high'}) : t({id:'panel.task.priority.normal'})}
              </span>
              {tk.actionType === 'reserva' && (
                <button className="ab-button ab-button--mini" onClick={() => setTab('reservas')}>{t({ id: 'panel.openReservations' })}</button>
              )}
              {tk.actionType === 'emprestimo' && (
                <button className="ab-button ab-button--mini" onClick={() => setTab('emprestimos-livro')}>{t({ id: 'panel.openLoans' })}</button>
              )}
              {tk.actionType === 'consulta' && (
                <button className="ab-button ab-button--mini" onClick={() => setTab('consultas-locais')}>{t({ id: 'panel.openConsultations' })}</button>
              )}
              {tk.actionType === 'tarefa' && (
                <select style={{ fontSize:'.78rem', padding:'3px 6px', borderRadius:6, border:'1px solid rgba(255,255,255,.15)', background:'rgba(0,0,0,.3)', color:'#f4f4f4' }}
                  defaultValue="" onChange={async e => {
                    if (!e.target.value) return;
                    // Chantier #TASKS : router par fn_task_update_status (RPC)
                    // au lieu d'un update() direct, sinon la regeneration des
                    // taches recurrentes ne se declenche jamais a l'achevement.
                    const newStatus = e.target.value;
                    e.target.value = '';
                    try {
                      const { error } = await supabase.rpc('fn_task_update_status', {
                        p_task_id: tk.task_id, p_new_status: newStatus,
                      });
                      if (error) throw error;
                      if (onTaskAction) onTaskAction();
                    } catch (err) {
                      notifyError(localizeError(err, t, 'panel.error.taskStatus'), err);
                    }
                  }}>
                  <option value="">{t({ id: 'panel.tasks.advance' })}</option>
                  <option value="em_andamento">{t({ id: 'task.status.em_andamento' })}</option>
                  <option value="concluida">{t({ id: 'task.status.concluida' })}</option>
                  <option value="cancelada">{t({ id: 'task.status.cancelada' })}</option>
                </select>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// TabHeader — en-tête uniforme avec titre + bouton refresh
// (chantier E.2 / OT-1, 28/05/2026)
// ───────────────────────────────────────────────────────────
// Pattern « ↻ Actualiser » à côté du titre d'onglet, demandé par
// l'audit Painel OT-1. Mutualisé pour garantir l'homogénéité
// visuelle entre tous les onglets concernés.
//
// Le bouton n'est rendu que si onRefresh est fourni — permet aux
// onglets qui n'ont pas de refresh (Ações, Gerir leitor·e) de
// réutiliser TabHeader pour le seul titre, si voulu un jour.
// ═══════════════════════════════════════════════════════════
export function TabHeader({ title, onRefresh, refreshLabel }) {
  const { formatMessage: t } = useIntl();
  // E.2 (28/05/2026) : feedback visuel pendant le rechargement. Sans ça,
  // si la base n'a pas changé, l'utilisateur a l'impression que rien ne
  // s'est passé. Désactive le bouton + spinner pendant l'appel.
  const [busy, setBusy] = useState(false);
  const handleClick = async () => {
    if (busy) return;
    setBusy(true);
    try { await onRefresh(); }
    finally {
      // Délai mini pour que le feedback soit perceptible même sur appel
      // ultra-rapide (cache, RPC < 100ms). 400ms est un bon compromis.
      setTimeout(() => setBusy(false), 400);
    }
  };
  const label = refreshLabel || t({ id: 'common.refresh' });
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12, flexWrap: 'wrap', marginBottom: 8 }}>
      <h2 className="ab-painel-h2" style={{ margin: 0 }}>{title}</h2>
      {onRefresh && (
        <button
          type="button"
          className="ab-button ab-button--secondary ab-button--mini"
          onClick={handleClick}
          disabled={busy}
          title={label}
          style={busy ? { opacity: 0.5, cursor: 'wait' } : undefined}
        >
          ↻ {busy ? `${label}…` : label}
        </button>
      )}
    </div>
  );
}
