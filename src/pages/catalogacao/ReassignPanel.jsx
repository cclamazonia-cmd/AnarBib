// src/pages/catalogacao/ReassignPanel.jsx — E6, lot 7 (28/09/2026)
// L'attribution d'une notice publiée et de ses exemplaires à une bibliothèque,
// réservée à l'administration du réseau, sortie de BookDraftForm.jsx sans en
// changer une ligne : bibliothèque source (quand la notice a des exemplaires
// dans plusieurs), bibliothèque cible, appel de la RPC, message. Le panneau
// porte ses quatre états et charge lui-même les bibliothèques détentrices ;
// le parent décide de l'afficher (admin réseau, notice publiée) et reçoit
// `onSaved` pour recharger la notice après le déplacement.
import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

export default function ReassignPanel({ bookId, catalogLibraries, setMsg, onSaved }) {
  const { formatMessage: t } = useIntl();
  const [reassignTarget, setReassignTarget] = useState('');
  const [reassignSource, setReassignSource] = useState('');  // biblio source (notice multi-biblios)
  const [reassignBusy, setReassignBusy] = useState(false);
  const [bookLibraries, setBookLibraries] = useState([]);    // biblios ou la notice a des exemplaires

  // Admin reseau : biblios ou la notice publiee a des exemplaires (alimente le source picker).
  useEffect(() => {
    if (!bookId) { setBookLibraries([]); setReassignSource(''); return; }
    let cancelled = false;
    supabase.from('book_holdings').select('library_id').eq('book_id', Number(bookId))
      .then(({ data }) => {
        if (cancelled) return;
        const ids = [...new Set((data || []).map(h => h.library_id).filter(Boolean))];
        setBookLibraries(ids.map(id => ({ id, name: catalogLibraries.find(l => l.id === id)?.name || id })));
      });
    return () => { cancelled = true; };
  }, [bookId, catalogLibraries]);

  // Admin réseau : attribue la notice publiée + ses exemplaires à une bibliothèque.
  async function reassignBookToLibrary() {
    if (!bookId) return;
    if (!reassignTarget) return;
    const lib = catalogLibraries.find(l => l.id === reassignTarget);
    if (!confirm(t({ id: 'catalogacao.reassign.confirm' }, { library: lib?.name || '' }))) return;
    setReassignBusy(true);
    try {
      const rpc = reassignSource ? 'network_admin_reassign_book_from_to_library' : 'network_admin_reassign_book_to_library';
      const params = reassignSource
        ? { p_book_id: Number(bookId), p_source_library_id: reassignSource, p_target_library_id: reassignTarget }
        : { p_book_id: Number(bookId), p_target_library_id: reassignTarget };
      const { data, error } = await supabase.rpc(rpc, params);
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.reassign.done' }, { library: data?.target_library || lib?.name || '', count: data?.exemplares_moved ?? 0 }), kind: 'ok' });
      setReassignTarget(''); setReassignSource('');
      onSaved?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setReassignBusy(false); }
  }

  return (
    <div style={{ marginBottom: 14, padding: '12px 14px', borderRadius: 10, background: 'rgba(29,78,216,.12)', border: '1px solid rgba(96,165,250,.35)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <span className="cat-pill info" style={{ fontSize: '.66rem' }}>{t({ id: 'catalogacao.reassign.badge' })}</span>
        <span style={{ fontSize: '.85rem', fontWeight: 600 }}>{t({ id: 'catalogacao.reassign.title' })}</span>
      </div>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
        <select value={reassignSource} onChange={e => setReassignSource(e.target.value)}
          style={{ padding: '7px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', minWidth: 'min(220px, 100%)' }}>
          <option value="">{t({ id: bookLibraries.length > 1 ? 'catalogacao.reassign.sourcePick' : 'catalogacao.reassign.sourceAll' })}</option>
          {bookLibraries.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
        </select>
        <span aria-hidden="true" style={{ fontSize: '.9rem', color: 'var(--brand-muted,#aaa)' }}>→</span>
        <select value={reassignTarget} onChange={e => setReassignTarget(e.target.value)}
          style={{ padding: '7px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', minWidth: 'min(220px, 100%)' }}>
          <option value="">{t({ id: 'catalogacao.reassign.placeholder' })}</option>
          {catalogLibraries.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
        </select>
        <button type="button" className="ab-button ab-button--sm"
          disabled={!reassignTarget || reassignBusy || (bookLibraries.length > 1 && !reassignSource)}
          onClick={reassignBookToLibrary}>
          {reassignBusy ? t({ id: 'common.saving' }) : t({ id: 'catalogacao.reassign.action' })}
        </button>
      </div>
      {bookLibraries.length > 1 && (
        <div style={{ fontSize: '.74rem', color: '#fbbf24', marginTop: 6 }}>{t({ id: 'catalogacao.reassign.multiHint' })}</div>
      )}
      <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)', marginTop: 6 }}>{t({ id: 'catalogacao.reassign.hint' })}</div>
    </div>
  );
}
