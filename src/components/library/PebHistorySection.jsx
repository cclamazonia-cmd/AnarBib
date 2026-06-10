import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

/**
 * PebHistorySection
 * --------------------------------------------------------------------------
 * Consultation des prêts entre bibliothèques (PEB) archivés.
 * Chantier #ILL-archive, étape frontend.
 * Spec : docs/journal/chantiers/CHANTIER_cloture_ILL_2026-05-24.md (section 4)
 *
 * Affiché dans l'onglet Rapports de la page Biblioteca. Liste les PEB
 * archivés de la bibliothèque (ceux que le staff a sortis de la file
 * active), avec possibilité de les désarchiver — ils réintègrent alors
 * la file active de l'onglet PEB.
 *
 * Lecture   : vue api.peb_history_v1 (from(), security_invoker, doctrine v3).
 * Écriture  : RPC fn_peb_unarchive_loan (désarchivage).
 * Droit     : l'onglet Rapports est déjà réservé au staff ; les RPC
 *             revérifient le droit côté base (staff de l'une ou l'autre
 *             bibliothèque du PEB).
 *
 * Props :
 *   libraryId    uuid de la bibliothèque courante
 *   allLibraries liste déjà chargée par BibliotecaPage (pour les noms)
 *   onChange     callback optionnel appelé après un désarchivage réussi —
 *                BibliotecaPage y branche loadAll() pour que la file active
 *                de l'onglet PEB se rafraîchisse sans refresh manuel.
 */
export default function PebHistorySection({ libraryId, allLibraries = [], onChange }) {
  const intl = useIntl();
  const t = (d, v) => intl.formatMessage(d, v);

  const [loans, setLoans] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);

  // ── styles alignés sur BibliotecaPage (thème sombre) ──────────────────────
  const bx = { padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)',
    border: '1px solid rgba(255,255,255,.08)', marginTop: 16 };
  const lw = { border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, overflow: 'hidden' };
  const lr = (i) => ({ padding: '10px 12px',
    background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
    borderBottom: '1px solid rgba(255,255,255,.04)',
    display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 });
  const muted = { fontSize: '.82rem', color: 'var(--brand-muted)' };

  // ── chargement ────────────────────────────────────────────────────────────
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      // Vue UI : security_invoker, RLS appliquée. Ne renvoie que les PEB
      // archivés ; on filtre sur les deux rôles possibles de la bibliothèque.
      const { data, error: err } = await supabase
        .schema('api').from('peb_history_v1')
        .select('*')
        .or(`lender_library_id.eq.${libraryId},borrower_library_id.eq.${libraryId}`)
        .order('archived_at', { ascending: false });
      if (err) throw err;
      setLoans(data || []);
      setError('');
    } catch (err) {
      console.warn('PebHistorySection.load:', err);
      setError(t({ id: 'biblioteca.pebHistory.loadError' }));
    } finally {
      setLoading(false);
    }
  }, [libraryId]); // eslint-disable-line react-hooks/exhaustive-deps

  // Chargement différé : on ne lit la vue qu'à la première ouverture du bloc,
  // pour ne pas alourdir l'onglet Rapports si le staff ne le consulte pas.
  useEffect(() => {
    if (open) load();
  }, [open, load]);

  // ── désarchivage ──────────────────────────────────────────────────────────
  const handleUnarchive = async (loanId) => {
    if (busy) return;
    if (!window.confirm(t({ id: 'biblioteca.pebHistory.unarchiveConfirm' }, { id: loanId }))) return;
    setBusy(true);
    setError('');
    try {
      const { error: err } = await supabase.rpc('fn_peb_unarchive_loan', {
        p_loan_id: loanId,
      });
      if (err) throw err;
      await load();
      // #ILL-reports volet B : prévenir le parent (BibliotecaPage) pour qu'il
      // rafraîchisse la file active de l'onglet PEB — le PEB désarchivé doit y
      // réapparaître sans refresh manuel de la page.
      if (typeof onChange === 'function') onChange();
    } catch (err) {
      console.warn('PebHistorySection.handleUnarchive:', err);
      setError(t({ id: 'biblioteca.pebHistory.unarchiveError' }));
    } finally {
      setBusy(false);
    }
  };

  // ── nom court d'une bibliothèque ──────────────────────────────────────────
  const libShort = (id, fallback) => {
    const l = allLibraries.find(x => x.id === id);
    return l?.short_name || l?.name || fallback || '—';
  };

  // ── rendu ─────────────────────────────────────────────────────────────────
  return (
    <div style={bx}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
        <h4 style={{ margin: 0 }}>{t({ id: 'biblioteca.pebHistory.title' })}</h4>
        <button
          className="cat-btn ghost"
          style={{ fontSize: '.8rem', padding: '4px 10px' }}
          onClick={() => setOpen(o => !o)}
        >
          {open ? t({ id: 'biblioteca.pebHistory.hide' })
                : t({ id: 'biblioteca.pebHistory.show' })}
        </button>
      </div>
      <div style={{ ...muted, marginTop: 4 }}>{t({ id: 'biblioteca.pebHistory.hint' })}</div>

      {open && (
        <div style={{ marginTop: 12 }}>
          {error && (
            <div className="cat-pill warn" style={{ display: 'block', marginBottom: 10, fontSize: '.78rem' }}>
              {error}
            </div>
          )}

          {loading && <div style={muted}>{t({ id: 'biblioteca.pebHistory.loading' })}</div>}

          {!loading && loans.length === 0 && (
            <div style={muted}>{t({ id: 'biblioteca.pebHistory.empty' })}</div>
          )}

          {!loading && loans.length > 0 && (
            <div style={lw}>
              {loans.map((loan, i) => (
                <div key={loan.id} style={lr(i)}>
                  <div style={{ minWidth: 0, flex: 1 }}>
                    <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                      #{loan.id} — {libShort(loan.lender_library_id, loan.lender_name)}
                      {' \u2192 '}
                      {libShort(loan.borrower_library_id, loan.borrower_name)}
                    </div>
                    <div style={muted}>
                      {t({ id: `ill.status.${loan.status_global}` })}
                      {loan.items_count > 0 && ` \u00b7 ${t({ id: 'biblioteca.ill.itemsCount' }, { count: loan.items_count })}`}
                      {loan.archived_at && ` \u00b7 ${t({ id: 'biblioteca.pebHistory.archivedOn' })} ${new Date(loan.archived_at).toLocaleDateString()}`}
                    </div>
                    {loan.archive_reason && (
                      <div style={{ ...muted, fontStyle: 'italic' }}>{loan.archive_reason}</div>
                    )}
                  </div>
                  <button
                    className="cat-btn ghost"
                    style={{ fontSize: '.78rem', padding: '4px 8px', flexShrink: 0 }}
                    disabled={busy}
                    onClick={() => handleUnarchive(loan.id)}
                  >
                    {t({ id: 'biblioteca.pebHistory.unarchive' })}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
