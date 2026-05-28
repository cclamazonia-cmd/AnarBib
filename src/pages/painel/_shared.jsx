import { useState, useMemo } from 'react';
import { useIntl } from 'react-intl';

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
