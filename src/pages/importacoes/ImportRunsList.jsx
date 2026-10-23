// Lots d'import : liste, archiver, supprimer — section de la face Import, sortie d'ImportacoesPage.jsx telle
// quelle (E6, 23/10/2026), avec l'état et les actions qu'elle est seule à lire
// (calculés par @babel/traverse) ; la page lui passe le reste.
// Garde : src/tests/importacoes-sections-montees.test.jsx.
import { useIntl } from 'react-intl';
import { useState, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import AppIcon from '@/components/ui/AppIcon';
import { assertRpcOk } from '../../lib/rpcStatus.js';

// La pastille d'état, la même que celle de la page.
function Pill({ children, variant = 'muted' }) {
  return <span className={`cat-pill ${variant}`}>{children}</span>;
}

export default function ImportRunsList(p) {
  const { formatMessage: t } = useIntl();
  const {
    loadRunRows, loadRuns, runs, selectedRunId, setMsg, setRunRows, setSelectedRunId,
  } = p;

  // ── Status labels ──────────────────────────────────────
  const STATUS = useMemo(() => ({
    pending: t({ id: 'importacoes.status.pending' }),
    uploaded: t({ id: 'importacoes.status.uploaded' }),
    parsing: t({ id: 'importacoes.status.parsing' }),
    parsed: t({ id: 'importacoes.status.parsed' }),
    ready_for_review: t({ id: 'importacoes.status.ready_for_review' }),
    reviewed: t({ id: 'importacoes.status.reviewed' }),
    drafts_created: t({ id: 'importacoes.status.drafts_created' }),
    failed: t({ id: 'importacoes.status.failed' }),
  }), [t]);

  const [showArchived, setShowArchived] = useState(false);

  // ── Supprimer un run d'import (+ son fichier) ──────────
  async function handleDeleteRun(runId) {
    if (!window.confirm(t({ id: 'importacoes.deleteRunConfirm' }, { id: runId }))) return;
    setMsg({ text: t({ id: 'importacoes.deletingRun' }), kind: 'info' });
    try {
      const { data: rpcData, error } = await supabase.rpc('fn_import_delete_run', { p_run_id: Number(runId) });
      if (error) throw error;
      assertRpcOk(rpcData);
      setMsg({ text: t({ id: 'importacoes.runDeleted' }), kind: 'ok' });
      if (selectedRunId === runId) { setSelectedRunId(null); setRunRows([]); }
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  // ── Archiver / désarchiver un run (masquage doux) ─────
  async function handleArchiveRun(runId, archived) {
    setMsg({ text: t({ id: 'importacoes.archiving' }), kind: 'info' });
    try {
      const { data: rpcData, error } = await supabase.rpc('fn_import_archive_run', { p_run_id: Number(runId), p_archived: archived });
      if (error) throw error;
      assertRpcOk(rpcData);
      setMsg({ text: t({ id: archived ? 'importacoes.runArchived' : 'importacoes.runUnarchived' }), kind: 'ok' });
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  return (
    <div className="imp-sheet" style={{ marginBottom: 18 }}>
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">{t({ id: 'importacoes.lotes.title' })}</span>
              <label style={{ fontSize: '.78rem', color: 'var(--brand-muted)', display: 'flex', alignItems: 'center', gap: 5, cursor: 'pointer' }}>
                <input type="checkbox" checked={showArchived} onChange={e => setShowArchived(e.target.checked)} />
                {t({ id: 'importacoes.showArchived' })}
              </label>
            </div>
            <div className="imp-sheet__body">
              {runs.filter(r => showArchived || !r.archived_at).length === 0 && (
                <p className="imp-note">{t({ id: 'importacoes.lotes.empty' })}</p>
              )}
              {runs.filter(r => showArchived || !r.archived_at).length > 0 && (
                <div style={{ maxHeight: 260, overflowY: 'auto', border: '1px solid rgba(255,255,255,.06)', borderRadius: 8 }}>
                  {runs.filter(r => showArchived || !r.archived_at).slice(0, 20).map(r => (
                    <div key={r.id} onClick={() => { setSelectedRunId(r.id); loadRunRows(r.id); }}
                      style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 6, padding: '8px 10px', cursor: 'pointer', borderBottom: '1px solid rgba(255,255,255,.04)', background: selectedRunId === r.id ? 'rgba(29,78,216,.12)' : 'transparent', opacity: r.archived_at ? 0.5 : 1 }}>
                      <div>
                        <span style={{ fontWeight: 600, fontSize: '.88rem' }}>#{r.id}</span>
                        <span style={{ color: 'var(--brand-muted)', fontSize: '.82rem', marginLeft: 8 }}>{r.source_name || r.original_filename || '—'}</span>
                      </div>
                      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                        <Pill variant={r.run_status === 'drafts_created' ? 'ok' : r.run_status === 'failed' ? 'danger' : r.run_status === 'ready_for_review' ? 'warn' : 'info'}>
                          {STATUS[r.run_status] || r.run_status}
                        </Pill>
                        {/* E12 lot A : une icône seule n'est pas un libellé — le titre
                            (survol) devient aussi le nom accessible du bouton. */}
                        <button className="cat-btn ghost" title={t({ id: r.archived_at ? 'importacoes.unarchiveRun' : 'importacoes.archiveRun' })}
                          aria-label={t({ id: r.archived_at ? 'importacoes.unarchiveRun' : 'importacoes.archiveRun' })}
                          style={{ fontSize: '.9rem', padding: '4px 8px', minHeight: 0 }}
                          onClick={e => { e.stopPropagation(); handleArchiveRun(r.id, !r.archived_at); }}>
                          <AppIcon name={r.archived_at ? "archiveRestore" : "archive"} size={15} />
                        </button>
                        <button className="cat-btn ghost" title={t({ id: 'importacoes.deleteRun' })}
                          aria-label={t({ id: 'importacoes.deleteRun' })}
                          style={{ fontSize: '.9rem', padding: '4px 8px', minHeight: 0 }}
                          onClick={e => { e.stopPropagation(); handleDeleteRun(r.id); }}>
                          <AppIcon name="trash" size={15} />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

  );
}
