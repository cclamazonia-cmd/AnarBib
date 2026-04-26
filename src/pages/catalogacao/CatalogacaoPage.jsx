import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useIntl } from 'react-intl';
import { useLibrary } from '@/contexts/LibraryContext';
import { SUPPORTED_LOCALES, setLocale, detectLocale } from '@/i18n';
import './CatalogacaoPage.css';
import BookDraftForm from './BookDraftForm';
import AuthorDraftForm from './AuthorDraftForm';
import ExemplarDraftForm from './ExemplarDraftForm';
import LabelSheetPrinter from './LabelSheetPrinter';
import QueuePanel from './QueuePanel';
import CatalogPanel from './CatalogPanel';

// ── Storage keys ────────────────────────────────────────────
const MODE_KEY = 'catalogacaoMode';
const TAB_KEY  = 'catalogacaoActiveTab';

// ═══════════════════════════════════════════════════════════
// CatalogacaoPage — Tranche 1 : squelette complet
// ═══════════════════════════════════════════════════════════

export default function CatalogacaoPage() {
  const { user } = useAuth();
  const { config } = useLibrary();
  const { formatMessage: t } = useIntl();
  const navigate = useNavigate();

  const TABS = [
    { id: 'booksPanel',     label: t({ id: 'catalogacao.tab.documento' }) },
    { id: 'authorsPanel',   label: t({ id: 'catalogacao.tab.autoria' }) },
    { id: 'indexPanel',     label: t({ id: 'catalogacao.tab.indexacao' }) },
    { id: 'queuePanel',     label: t({ id: 'catalogacao.tab.fila' }), separator: true },
    { id: 'batchesPanel',   label: t({ id: 'catalogacao.tab.lotes' }) },
    { id: 'catalogPanel',   label: t({ id: 'catalogacao.tab.catalogo' }) },
  ];

  // ── Mode simple / completo ─────────────────────────────
  const [mode, setMode] = useState(() => {
    try { return localStorage.getItem(MODE_KEY) || 'simple'; } catch { return 'simple'; }
  });

  // ── Active tab ─────────────────────────────────────────
  const [activeTab, setActiveTab] = useState(() => {
    const hash = window.location.hash.replace('#tab=', '');
    if (TABS.some(t => t.id === hash)) return hash;
    try {
      const stored = localStorage.getItem(TAB_KEY);
      if (TABS.some(t => t.id === stored)) return stored;
    } catch {}
    return 'booksPanel';
  });

  // ── Stats ──────────────────────────────────────────────
  const [stats, setStats] = useState({ openBatches: 0, drafts: 0, books: 0, authors: 0 });

  // ── Dados de catálogo ────────────────────────────────────
  const [batches, setBatches] = useState([]);
  const [loading, setLoading] = useState(true);

  // ═══════════════════════════════════════════════════════
  // Load stats + batches (same pattern as PanelPage)
  // ═══════════════════════════════════════════════════════

  const loadStats = useCallback(async () => {
    try {
      const [batchRes, bookDraftRes, authorDraftRes, exemplarDraftRes, booksRes, authorsRes] = await Promise.allSettled([
        supabase.from('catalog_batches').select('id', { count: 'exact', head: true }).eq('status', 'open'),
        supabase.from('book_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('author_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('exemplar_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('books').select('id', { count: 'exact', head: true }),
        supabase.from('authors').select('id', { count: 'exact', head: true }),
      ]);

      const count = (r) => r.status === 'fulfilled' ? (r.value.count ?? 0) : 0;

      setStats({
        openBatches: count(batchRes),
        drafts: count(bookDraftRes) + count(authorDraftRes) + count(exemplarDraftRes),
        books: count(booksRes),
        authors: count(authorsRes),
      });
    } catch (err) {
      console.warn('loadStats error:', err);
    }
  }, []);

  const loadBatches = useCallback(async () => {
    try {
      const { data } = await supabase.from('catalog_batches')
        .select('*')
        .order('created_at', { ascending: false });
      setBatches(data || []);
    } catch (err) {
      console.warn('loadBatches error:', err);
    }
  }, []);

  const refreshAll = useCallback(async () => {
    setLoading(true);
    await Promise.allSettled([loadStats(), loadBatches()]);
    setLoading(false);
  }, [loadStats, loadBatches]);

  // Initial load — ProtectedRoute guarantees user is logged in
  useEffect(() => { refreshAll(); }, [refreshAll]);

  // ═══════════════════════════════════════════════════════
  // Mode toggle
  // ═══════════════════════════════════════════════════════

  function switchMode(nextMode) {
    const m = nextMode === 'complete' ? 'complete' : 'simple';
    setMode(m);
    try { localStorage.setItem(MODE_KEY, m); } catch {}
  }

  // Apply mode to body for CSS selectors
  useEffect(() => {
    document.body.setAttribute('data-catalog-mode', mode);
    return () => document.body.removeAttribute('data-catalog-mode');
  }, [mode]);

  // ═══════════════════════════════════════════════════════
  // Tab management
  // ═══════════════════════════════════════════════════════

  function switchTab(tabId) {
    if (!TABS.some(t => t.id === tabId)) return;
    setActiveTab(tabId);
    try { localStorage.setItem(TAB_KEY, tabId); } catch {}
    try { window.history.replaceState(null, '', `#tab=${tabId}`); } catch {}
  }

  // Listen for hash changes
  useEffect(() => {
    function onHashChange() {
      const hash = window.location.hash.replace('#tab=', '');
      if (TABS.some(t => t.id === hash)) setActiveTab(hash);
    }
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  // ═══════════════════════════════════════════════════════
  // Render
  // ═══════════════════════════════════════════════════════

  const modeHint = mode === 'simple'
    ? t({ id: 'catalogacao.modeSimple' })
    : t({ id: 'catalogacao.modeComplete' });

  return (
    <div className="catalogacao-wrap">

      {/* ── Hero / topbar ────────────────────────────────── */}
      <div className="cat-topbar">
        <div className="cat-brand">
          <div className="cat-hero-copy">
            <h1>{t({ id: 'catalogacao.areaTitle' })}</h1>
            <p>{t({ id: 'catalogacao.areaSubtitle' })}</p>
          </div>
          {config?.logoUrl && (
            <img className="cat-logo" src={config.logoUrl} alt={config?.libraryName || 'AnarBib'} />
          )}
        </div>
        <div className="cat-hero-actions">
          <a className="btn" href="#" onClick={(e) => { e.preventDefault(); navigate('/painel'); }}>
            {t({ id: 'nav.panel' })}
          </a>
          <a className="btn" href="#" onClick={(e) => { e.preventDefault(); navigate('/importacoes'); }}>
            {t({ id: 'nav.imports' })}
          </a>
          <a className="btn" href="#" onClick={(e) => { e.preventDefault(); navigate('/'); }}>
            {t({ id: 'nav.catalog' })}
          </a>
          {/* Language selector */}
          <select
            value={detectLocale()}
            onChange={e => setLocale(e.target.value)}
            style={{ fontSize: '.78rem', padding: '4px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#ccc', cursor: 'pointer' }}
            aria-label={t({ id: 'language.selector' })}
          >
            {SUPPORTED_LOCALES.map(l => (
              <option key={l.code} value={l.code}>{l.flag} {l.label}</option>
            ))}
          </select>
        </div>
      </div>

      {/* ── Toolbar: session + mode toggle ────────────────── */}
      <div className="cat-toolbar">
        <div className="cat-toolbar-meta">
          <div className="cat-toolbar-status">
            <span className="cat-pill info">
              {user?.email || ''}
            </span>
            <span className="cat-pill ok">{t({ id: 'catalogacao.librarianAccess' })}</span>
          </div>
          <div className="cat-toolbar-main">
            <button className="cat-btn secondary" onClick={refreshAll} disabled={loading}>
              {loading ? t({id:'common.loading'}) : t({id:'common.update'})}
            </button>
          </div>
        </div>

        <div className="cat-mode-switch">
          <span className="cat-mode-switch-label">{t({ id: 'catalogacao.modeLabel' })}</span>
          <div className="cat-mode-switch-buttons">
            <button
              className={mode === 'simple' ? 'is-mode-active' : ''}
              aria-pressed={mode === 'simple' ? 'true' : 'false'}
              onClick={() => switchMode('simple')}
            >
              {t({ id: 'catalogacao.interfaceSimple' })}
            </button>
            <button
              className={mode === 'complete' ? 'is-mode-active' : ''}
              aria-pressed={mode === 'complete' ? 'true' : 'false'}
              onClick={() => switchMode('complete')}
            >
              {t({ id: 'catalogacao.interfaceComplete' })}
            </button>
          </div>
          <span className="cat-mode-hint">{modeHint}</span>
        </div>
      </div>

      {/* ── Statusbar (stats) ────────────────────────────── */}
      <div className="cat-statusbar">
            <div className="cat-stat">
              <div className="cat-stat-label">Lotes abertos</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title="Ver lotes abertos"
                onClick={() => switchTab('batchesPanel')}
                onKeyDown={(e) => e.key === 'Enter' && switchTab('batchesPanel')}
              >
                {stats.openBatches}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">Rascunhos ativos</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title="Ver rascunhos ativos"
                onClick={() => switchTab('queuePanel')}
                onKeyDown={(e) => e.key === 'Enter' && switchTab('queuePanel')}
              >
                {stats.drafts}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">Livros publicados</div>
              <div className="cat-stat-value">{stats.books}</div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">Autores cadastrados</div>
              <div className="cat-stat-value">{stats.authors}</div>
            </div>
          </div>

          {/* ── Tabs ─────────────────────────────────────── */}
          <div className="cat-tabs">
            {TABS.map((tab) => (
              <button
                key={tab.id}
                className={`cat-tab-btn${activeTab === tab.id ? ' active' : ''}${tab.separator ? ' tab-separator' : ''}`}
                onClick={() => switchTab(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* ── Panels ───────────────────────────────────── */}

          {/* 1. Documento */}
          <div className={`cat-panel${activeTab === 'booksPanel' ? ' active' : ''}`}>
            <div className="cat-panel-header">
              <h3>{t({id:'catalogacao.tab.documento'})}</h3>
            </div>
            <BookDraftForm batches={batches} mode={mode} onSaved={refreshAll} />
          </div>

          {/* 2. Autoria */}
          <div className={`cat-panel${activeTab === 'authorsPanel' ? ' active' : ''}`}>
            <AuthorDraftForm mode={mode} batches={batches} />
          </div>

          {/* 3. Indexação (exemplar + rótulo + impression étiquettes) */}
          <div className={`cat-panel${activeTab === 'indexPanel' ? ' active' : ''}`}>
            <ExemplarDraftForm mode={mode} batches={batches} />
            <LabelSheetPrinter />
          </div>

          {/* 4. Fila editorial */}
          <div className={`cat-panel${activeTab === 'queuePanel' ? ' active' : ''}`}>
            <QueuePanel batches={batches} />
          </div>

          {/* 6. Lotes */}
          <div className={`cat-panel${activeTab === 'batchesPanel' ? ' active' : ''}`}>
            <div className="cat-panel-header">
              <h3>{t({id:'catalogacao.tab.lotes'})}</h3>
            </div>
            <BatchesPanel batches={batches} onRefresh={refreshAll} />
          </div>

          {/* 6. Catálogo(s) já publicado(s) */}
          <div className={`cat-panel${activeTab === 'catalogPanel' ? ' active' : ''}`}>
            <CatalogPanel />
          </div>
    </div>
  );
}


// ═══════════════════════════════════════════════════════════
// BatchesPanel — mini componente funcional de gestão de lotes
// ═══════════════════════════════════════════════════════════

function BatchesPanel({ batches, onRefresh }) {
  const { formatMessage: t } = useIntl();
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState('');
  const [newNotes, setNewNotes] = useState('');
  const [msg, setMsg] = useState('');

  async function createBatch() {
    if (!newName.trim()) { setMsg(t({id:'catalogacao.batchNameRequired'})); return; }
    setCreating(true);
    setMsg('');
    try {
      const { error } = await supabase.from('catalog_batches').insert({
        name: newName.trim(),
        notes: newNotes.trim() || null,
        status: 'open',
      });
      if (error) throw error;
      setNewName('');
      setNewNotes('');
      setMsg(t({id:'common.dataSaved'}));
      onRefresh();
    } catch (err) {
      setMsg(t({id:'common.errorPrefix'},{message:err.message}));
    } finally {
      setCreating(false);
    }
  }

  async function closeBatch(id) {
    if (!confirm(t({id:'catalogacao.closeBatchConfirm'}))) return;
    try {
      const { error } = await supabase.from('catalog_batches')
        .update({ status: 'closed' })
        .eq('id', id);
      if (error) throw error;
      onRefresh();
    } catch (err) {
      alert(t({id:'common.errorPrefix'},{message:err.message}));
    }
  }

  async function publishBatch(id) {
    if (!confirm(t({id:'catalogacao.publishBatchConfirm'}))) return;
    try {
      const { error } = await supabase.rpc('publish_catalog_batch', { p_batch_id: Number(id) });
      if (error) throw error;
      alert(t({id:'common.dataSaved'}));
      onRefresh();
    } catch (err) {
      alert(t({id:'common.errorPrefix'},{message:err.message}));
    }
  }

  const openBatches = batches.filter(b => b.status === 'open');
  const closedBatches = batches.filter(b => b.status !== 'open');

  function formatDate(v) {
    if (!v) return '—';
    try { return new Date(v).toLocaleDateString(); } catch { return v; }
  }

  return (
    <div>
      {/* Créer un lote */}
      <div style={{
        padding: 16, marginBottom: 16, borderRadius: 10,
        background: 'var(--brand-panel-bg, rgba(16,16,16,.86))',
        border: '1px solid var(--brand-panel-border, rgba(255,255,255,.1))',
      }}>
        <h4 style={{ margin: '0 0 10px', fontSize: '.9rem', fontWeight: 700 }}>Criar novo lote</h4>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'flex-end' }}>
          <div style={{ flex: '1 1 200px' }}>
            <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batchName'})}</label>
            <input
              type="text" value={newName} onChange={e => setNewName(e.target.value)}
              placeholder={t({id:'catalogacao.batchNamePlaceholder'})}
              style={{
                width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)',
                background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem',
              }}
            />
          </div>
          <div style={{ flex: '1 1 200px' }}>
            <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>Notas (opcional)</label>
            <input
              type="text" value={newNotes} onChange={e => setNewNotes(e.target.value)}
              placeholder={t({id:'catalogacao.batchNotesPlaceholder'})}
              style={{
                width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)',
                background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem',
              }}
            />
          </div>
          <button className="cat-btn primary" onClick={createBatch} disabled={creating}>
            {creating ? t({id:'common.saving'}) : t({id:'catalogacao.createBatch'})}
          </button>
        </div>
        {msg && <div style={{ marginTop: 8, fontSize: '.82rem', color: msg.startsWith('Erro') ? '#f87171' : '#4ade80' }}>{msg}</div>}
      </div>

      {/* Lotes ouverts */}
      {openBatches.length > 0 && (
        <div style={{ marginBottom: 16 }}>
          <h4 style={{ margin: '0 0 10px', fontSize: '.88rem', fontWeight: 700 }}>Lotes abertos ({openBatches.length})</h4>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>Nome</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>Notas</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>Criado em</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>Ações</th>
              </tr>
            </thead>
            <tbody>
              {openBatches.map(b => (
                <tr key={b.id} style={{ borderBottom: '1px solid rgba(255,255,255,.06)' }}>
                  <td style={{ padding: '8px' }}>{b.name}</td>
                  <td style={{ padding: '8px', color: 'var(--brand-muted, #aaa)' }}>{b.notes || '—'}</td>
                  <td style={{ padding: '8px' }}>{formatDate(b.created_at)}</td>
                  <td style={{ padding: '8px', textAlign: 'right' }}>
                    <button className="cat-btn secondary" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                      onClick={() => publishBatch(b.id)}>{t({id:'catalogacao.publishBatch'})}</button>
                    <button className="cat-btn ghost" style={{ fontSize: '.75rem', padding: '4px 10px' }}
                      onClick={() => closeBatch(b.id)}>{t({id:'catalogacao.closeBatch'})}</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Lotes fermés */}
      {closedBatches.length > 0 && (
        <details style={{ marginTop: 12 }}>
          <summary style={{ cursor: 'pointer', fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
            Lotes encerrados ({closedBatches.length})
          </summary>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem', marginTop: 8 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>Nome</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>Status</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>Criado em</th>
              </tr>
            </thead>
            <tbody>
              {closedBatches.map(b => (
                <tr key={b.id} style={{ borderBottom: '1px solid rgba(255,255,255,.06)', opacity: 0.6 }}>
                  <td style={{ padding: '8px' }}>{b.name}</td>
                  <td style={{ padding: '8px' }}>
                    <span className={`cat-pill ${b.status === 'published' ? 'ok' : 'warn'}`}>
                      {b.status === 'published' ? t({id:'catalogacao.published'}) : b.status}
                    </span>
                  </td>
                  <td style={{ padding: '8px' }}>{formatDate(b.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      )}

      {batches.length === 0 && (
        <div className="cat-placeholder">Nenhum lote encontrado. Crie o primeiro lote acima.</div>
      )}
    </div>
  );
}
