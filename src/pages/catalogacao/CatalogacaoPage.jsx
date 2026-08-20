import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useAuth } from '@/contexts/AuthContext';
import { useIntl } from 'react-intl';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import './CatalogacaoPage.css';
import BookDraftForm from './BookDraftForm';
import OcrDepositTab from './OcrDepositTab';
import AuthorDraftForm from './AuthorDraftForm';
import ExemplarDraftForm from './ExemplarDraftForm';
import LabelSheetPrinter from './LabelSheetPrinter';
import QueuePanel from './QueuePanel';
import CatalogPanel from './CatalogPanel';
import SubjectGovernancePanel from './SubjectGovernancePanel';
import CatalogacaoWizard, { shouldShowWizard } from './CatalogacaoWizard';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';

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
  useDocumentTitle(t({ id: 'pageTitle.cataloging' }));

  const TABS = [
    { id: 'booksPanel',     label: t({ id: 'catalogacao.tab.documento' }) },
    { id: 'authorsPanel',   label: t({ id: 'catalogacao.tab.autoria' }) },
    { id: 'indexPanel',     label: t({ id: 'catalogacao.tab.indexacao' }) },
    { id: 'labelsPanel',    label: t({ id: 'catalogacao.tab.etiquetas' }) },
    // Flux d'ingestion distinct (depot de scans OCR) — isole entre 2 separateurs.
    { id: 'ocrPanel',       label: t({ id: 'catalogacao.tab.ocr' }), separator: true },
    { id: 'queuePanel',     label: t({ id: 'catalogacao.tab.fila' }), separator: true },
    { id: 'batchesPanel',   label: t({ id: 'catalogacao.tab.lotes' }) },
    { id: 'catalogPanel',   label: t({ id: 'catalogacao.tab.catalogo' }) },
    { id: 'materiaPanel',   label: t({ id: 'catalogacao.tab.materia' }), separator: true },
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
  const [stats, setStats] = useState({ openBatches: 0, drafts: 0, books: 0, authors: 0, exemplares: 0 });

  // ── Wizard de découverte ───────────────────────────────
  const [wizardOpen, setWizardOpen] = useState(() => shouldShowWizard());

  // ── Dados de catálogo ────────────────────────────────────
  const [batches, setBatches] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editTarget, setEditTarget] = useState(null); // { kind, id } -- handoff catalogo/fila -> editeur (Lot 0)
  // Pilotage de la sous-vue du CatalogPanel depuis les compteurs (nonce pour re-declencher meme vue)
  const [catalogReq, setCatalogReq] = useState({ view: 'book', nonce: 0 });

  // ═══════════════════════════════════════════════════════
  // Load stats + batches (same pattern as PanelPage)
  // ═══════════════════════════════════════════════════════

  const loadStats = useCallback(async () => {
    try {
      const [batchRes, bookDraftRes, authorDraftRes, exemplarDraftRes, booksRes, authorsRes, exemplaresRes] = await Promise.allSettled([
        supabase.from('catalog_batches').select('id', { count: 'exact', head: true }).eq('status', 'open'),
        supabase.from('book_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('author_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('exemplar_drafts').select('id', { count: 'exact', head: true }).in('status', ['draft', 'ready']),
        supabase.from('books').select('id', { count: 'exact', head: true }),
        supabase.from('authors').select('id', { count: 'exact', head: true }),
        supabase.from('exemplares').select('id', { count: 'exact', head: true }),
      ]);

      const count = (r) => r.status === 'fulfilled' ? (r.value.count ?? 0) : 0;

      setStats({
        openBatches: count(batchRes),
        drafts: count(bookDraftRes) + count(authorDraftRes) + count(exemplarDraftRes),
        books: count(booksRes),
        authors: count(authorsRes),
        exemplares: count(exemplaresRes),
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

  // Track A Lot 3 — ternary tiers: simple | advanced | complete
  function switchMode(nextMode) {
    const VALID = ['simple', 'advanced', 'complete'];
    const m = VALID.includes(nextMode) ? nextMode : 'simple';
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

  // P1.6-b.2 : pré-ciblage de l'attache depuis le bandeau doublon (BookDraftForm).
  const [attachTarget, setAttachTarget] = useState('');
  // Ouverture de la fiche existante depuis le bandeau / la modale « doublon ».
  //
  // PAS de 'noopener' ici, et c'est délibéré. Les sessions STAFF vivent dans
  // sessionStorage (cf. src/lib/staffStorage.js, backlog #76) ; or un onglet
  // ouvert avec 'noopener' est un contexte de navigation NEUF, qui n'hérite pas
  // de la copie du sessionStorage de l'onglet source. La session staff ne
  // suivait donc pas : le nouvel onglet s'ouvrait en ANONYME et la fiche
  // n'apparaissait pas (constaté le 19/08/2026 sur une fiche BTL, dont la
  // bibliothèque est en visibility_level = 'network', donc invisible hors
  // session).
  //
  // La cible est interne et de même origine : 'noopener' n'y apporte aucune
  // protection, le tabnabbing ne concernant que les cibles externes. Il reste
  // en place sur les liens sortants (BN, WorldCat, ISSN, Jitsi).
  function openBook(bookId) {
    if (bookId) window.open(`/livro/${bookId}`, '_blank');
  }
  async function attachToBook(bookId) {
    if (!bookId) return;
    try {
      const { data } = await supabase.from('books').select('bib_ref').eq('id', Number(bookId)).single();
      if (data?.bib_ref) setAttachTarget(String(data.bib_ref));
    } catch {}
    switchTab('indexPanel');
  }

  function openForEdit(kind, id) {
    const tabByKind = { book: 'booksPanel', author: 'authorsPanel', exemplar: 'indexPanel' };
    // Trace la dernière ouverture du brouillon (colonne « Ouvert le » de la file
    // éditoriale). Fire-and-forget : ne bloque pas la navigation et n'altère pas
    // updated_at (cf. RPC fn_touch_draft_opened + garde anarbib.skip_touch_updated_at).
    if (id != null) {
      supabase.rpc('fn_touch_draft_opened', { p_type: kind, p_id: Number(id) })
        .then(({ error }) => { if (error) console.warn('fn_touch_draft_opened:', error.message); });
    }
    setEditTarget({ kind, id: id != null ? String(id) : null });
    switchTab(tabByKind[kind] || 'booksPanel');
  }

  // Ouvre un exemplaire PUBLIÉ dans l'éditeur d'exemplaires (depuis la fiche
  // document). Le modèle de l'app édite des brouillons : on « retake » l'exemplaire
  // (création d'un brouillon d'édition) puis on bascule sur l'éditeur. Le RPC n'est
  // PAS idempotent → on confirme, comme CatalogPanel, pour éviter les doublons.
  async function editPublishedExemplar(exemplarId) {
    if (exemplarId == null) return;
    const typeLabel = t({ id: 'catalogacao.type.exemplar' }).toLowerCase();
    if (!confirm(t({ id: 'catalogacao.catalog.retakeConfirm' }, { type: typeLabel }))) return;
    try {
      const { data, error } = await supabase.rpc('create_exemplar_draft_from_exemplar', { p_exemplar_id: Number(exemplarId) });
      if (error) throw error;
      if (data) openForEdit('exemplar', data);
    } catch (err) {
      alert(localizeError(err, t));
    }
  }

  function switchTab(tabId) {
    if (!TABS.some(t => t.id === tabId)) return;
    setActiveTab(tabId);
    try { localStorage.setItem(TAB_KEY, tabId); } catch {}
    try { window.history.replaceState(null, '', `#tab=${tabId}`); } catch {}
  }

  // Ouvre l'onglet Catalogo sur la sous-vue voulue (depuis les compteurs)
  function openCatalog(view) {
    setCatalogReq((r) => ({ view, nonce: r.nonce + 1 }));
    switchTab('catalogPanel');
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
    : mode === 'advanced'
      ? t({ id: 'catalogacao.modeAdvanced' })
      : t({ id: 'catalogacao.modeComplete' });

  return (
    <PageShell>
      <Topbar />

      <Hero title={t({ id: 'catalogacao.areaTitle' })} subtitle={t({ id: 'catalogacao.areaSubtitle' })}>
        <UserHeroBadge />
        <HeroDocumentationActions
          extraActions={<>
            <button className="ab-button ab-button--secondary" onClick={refreshAll} disabled={loading}>
              {loading ? t({ id: 'common.loading' }) : t({ id: 'common.update' })}
            </button>
            <button className="ab-button ab-button--secondary" onClick={() => setWizardOpen(true)} style={{ gap: 6 }}>
              <span aria-hidden="true">?</span> {t({ id: 'catalogacao.wizard.helpButton' })}
            </button>
          </>}
        />
      </Hero>

      {/* ── Wizard de découverte ── */}
      {wizardOpen && (
        <CatalogacaoWizard
          onClose={() => setWizardOpen(false)}
          onSwitchTab={(tabId) => { switchTab(tabId); setWizardOpen(false); }}
        />
      )}

      <div className="catalogacao-wrap">

        {/* ── Toolbar: mode toggle ──────────────────────────── */}
        <div className="cat-toolbar">
          <div className="cat-mode-switch">
          <span className="cat-mode-switch-label">{t({ id: 'catalogacao.modeLabel' })}</span>
          <div className="cat-mode-switch-buttons">
            {['simple', 'advanced', 'complete'].map(m => (
              <button
                key={m}
                className={mode === m ? 'is-mode-active' : ''}
                aria-pressed={mode === m ? 'true' : 'false'}
                onClick={() => switchMode(m)}
              >
                {t({ id: `catalogacao.interface${m.charAt(0).toUpperCase() + m.slice(1)}` })}
              </button>
            ))}
          </div>
          <span className="cat-mode-hint">{modeHint}</span>
        </div>
      </div>

      {/* ── Statusbar (stats) ────────────────────────────── */}
      <div className="cat-statusbar">
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.openBatches'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.openBatchesTitle'})}
                onClick={() => switchTab('batchesPanel')}
                onKeyDown={(e) => e.key === 'Enter' && switchTab('batchesPanel')}
              >
                {stats.openBatches}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.activeDrafts'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.activeDraftsTitle'})}
                onClick={() => switchTab('queuePanel')}
                onKeyDown={(e) => e.key === 'Enter' && switchTab('queuePanel')}
              >
                {stats.drafts}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.publishedBooks'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.publishedBooksTitle'})}
                onClick={() => openCatalog('book')}
                onKeyDown={(e) => e.key === 'Enter' && openCatalog('book')}
              >
                {stats.books}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.registeredAuthors'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.registeredAuthorsTitle'})}
                onClick={() => openCatalog('author')}
                onKeyDown={(e) => e.key === 'Enter' && openCatalog('author')}
              >
                {stats.authors}
              </div>
            </div>
            <div className="cat-stat">
              <div className="cat-stat-label">{t({id:'catalogacao.stats.publishedExemplars'})}</div>
              <div
                className="cat-stat-value clickable"
                role="button"
                tabIndex={0}
                title={t({id:'catalogacao.stats.publishedExemplarsTitle'})}
                onClick={() => openCatalog('exemplar')}
                onKeyDown={(e) => e.key === 'Enter' && openCatalog('exemplar')}
              >
                {stats.exemplares}
              </div>
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
            <BookDraftForm panelActive={activeTab === 'booksPanel'} batches={batches} mode={mode} onSaved={refreshAll} onOpenBook={openBook} onAttachToBook={attachToBook} editingId={editTarget?.kind === 'book' ? editTarget.id : null} onConsumed={() => setEditTarget(null)} onNavigateTab={switchTab} onEditExemplar={editPublishedExemplar} />
          </div>

          {/* 2. Autoria */}
          <div className={`cat-panel${activeTab === 'authorsPanel' ? ' active' : ''}`}>
            <AuthorDraftForm mode={mode} batches={batches} editingId={editTarget?.kind === 'author' ? editTarget.id : null} onConsumed={() => setEditTarget(null)} onChanged={refreshAll} />
          </div>

          {/* 3. Indexação (exemplar + rótulo) */}
          <div className={`cat-panel${activeTab === 'indexPanel' ? ' active' : ''}`}>
            <ExemplarDraftForm mode={mode} batches={batches} prefillBibRef={attachTarget} editingId={editTarget?.kind === 'exemplar' ? editTarget.id : null} onConsumed={() => setEditTarget(null)} onChanged={refreshAll} />
          </div>

          {/* 3b. Etiquetas (impressão das etiquetas de cote) */}
          <div className={`cat-panel${activeTab === 'labelsPanel' ? ' active' : ''}`}>
            <LabelSheetPrinter onChanged={refreshAll} isActive={activeTab === 'labelsPanel'} />
          </div>

          {/* 3c. Fundo escaneado (OCR navegador) — piste B, flux d'ingestion distinct */}
          <div className={`cat-panel${activeTab === 'ocrPanel' ? ' active' : ''}`}>
            <div className="cat-panel-header">
              <h3>{t({id:'catalogacao.tab.ocr'})}</h3>
            </div>
            {activeTab === 'ocrPanel' && (
              <OcrDepositTab batches={batches} mode={mode} onSaved={refreshAll} />
            )}
          </div>

          {/* 4. Fila editorial */}
          <div className={`cat-panel${activeTab === 'queuePanel' ? ' active' : ''}`}>
            <QueuePanel batches={batches} onEditItem={openForEdit} onChanged={refreshAll} isActive={activeTab === 'queuePanel'} />
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
            <CatalogPanel onEdit={openForEdit} requestedView={catalogReq.view} requestNonce={catalogReq.nonce} onChanged={refreshAll} />
          </div>

          {/* 7. Coordenação de matéria (gouvernance thésaurus — étape 2c) */}
          <div className={`cat-panel${activeTab === 'materiaPanel' ? ' active' : ''}`}>
            <SubjectGovernancePanel />
          </div>
      </div>
      <Footer />
    </PageShell>
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
  const [msg, setMsg] = useState(null);

  async function createBatch() {
    if (!newName.trim()) { setMsg({text: t({id:'catalogacao.batchNameRequired'}), kind:'error'}); return; }
    setCreating(true);
    setMsg(null);
    try {
      const { error } = await supabase.from('catalog_batches').insert({
        name: newName.trim(),
        notes: newNotes.trim() || null,
        status: 'open',
      });
      if (error) throw error;
      setNewName('');
      setNewNotes('');
      setMsg({text: t({id:'common.dataSaved'}), kind:'ok'});
      onRefresh();
    } catch (err) {
      setMsg({text: t({id:'common.errorPrefix'},{message:localizeError(err, t)}), kind:'error'});
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
      alert(t({id:'common.errorPrefix'},{message:localizeError(err, t)}));
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
      alert(t({id:'common.errorPrefix'},{message:localizeError(err, t)}));
    }
  }

  async function archiveBatch(id) {
    if (!confirm(t({id:'catalogacao.archiveBatchConfirm'}))) return;
    try {
      const { error } = await supabase.from('catalog_batches')
        .update({ status: 'archived' })
        .eq('id', id);
      if (error) throw error;
      onRefresh();
    } catch (err) {
      alert(t({id:'common.errorPrefix'},{message:localizeError(err, t)}));
    }
  }

  async function deleteBatch(id) {
    if (!confirm(t({id:'catalogacao.deleteBatchConfirm'}))) return;
    try {
      // Check for orphan drafts before deleting
      const counts = await Promise.all([
        supabase.from('book_drafts').select('id', { count: 'exact', head: true }).eq('batch_id', id),
        supabase.from('author_drafts').select('id', { count: 'exact', head: true }).eq('batch_id', id),
        supabase.from('exemplar_drafts').select('id', { count: 'exact', head: true }).eq('batch_id', id),
      ]);
      const total = counts.reduce((s, r) => s + (r.count || 0), 0);
      if (total > 0) {
        alert(t({id:'catalogacao.batchHasDrafts'},{count: total}));
        return;
      }
      const { error } = await supabase.from('catalog_batches')
        .delete()
        .eq('id', id);
      if (error) throw error;
      onRefresh();
    } catch (err) {
      alert(t({id:'common.errorPrefix'},{message:localizeError(err, t)}));
    }
  }

  const openBatches = batches.filter(b => b.status === 'open');
  const closedBatches = batches.filter(b => b.status !== 'open' && b.status !== 'archived');
  const archivedBatches = batches.filter(b => b.status === 'archived');

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
        <h4 style={{ margin: '0 0 10px', fontSize: '.9rem', fontWeight: 700 }}>{t({id:'catalogacao.batch.createTitle'})}</h4>
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
            <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.notesLabel'})}</label>
            <input
              type="text" value={newNotes} onChange={e => setNewNotes(e.target.value)}
              placeholder={t({id:'catalogacao.batchNotesPlaceholder'})}
              style={{
                width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)',
                background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem',
              }}
            />
          </div>
          <button className="ab-button" onClick={createBatch} disabled={creating}>
            {creating ? t({id:'common.saving'}) : t({id:'catalogacao.createBatch'})}
          </button>
        </div>
        {msg && <div style={{ marginTop: 8, fontSize: '.82rem', color: msg.kind === 'error' ? '#f87171' : '#4ade80' }}>{msg.text}</div>}
      </div>

      {/* Lotes ouverts */}
      {openBatches.length > 0 && (
        <div style={{ marginBottom: 16 }}>
          <h4 style={{ margin: '0 0 10px', fontSize: '.88rem', fontWeight: 700 }}>{t({id:'catalogacao.batch.openBatchesCount'}, {count: openBatches.length})}</h4>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thName'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thNotes'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thCreatedAt'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batchActions'})}</th>
              </tr>
            </thead>
            <tbody>
              {openBatches.map(b => (
                <tr key={b.id} style={{ borderBottom: '1px solid rgba(255,255,255,.06)' }}>
                  <td style={{ padding: '8px' }}>{b.name}</td>
                  <td style={{ padding: '8px', color: 'var(--brand-muted, #aaa)' }}>{b.notes || '—'}</td>
                  <td style={{ padding: '8px' }}>{formatDate(b.created_at)}</td>
                  <td style={{ padding: '8px', textAlign: 'right' }}>
                    <button className="ab-button ab-button--secondary" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                      onClick={() => publishBatch(b.id)}>{t({id:'catalogacao.publishBatch'})}</button>
                    <button className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px' }}
                      onClick={() => closeBatch(b.id)}>{t({id:'catalogacao.closeBatch'})}</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Lotes fermés (non archivés) */}
      {closedBatches.length > 0 && (
        <details style={{ marginTop: 12 }}>
          <summary style={{ cursor: 'pointer', fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
            {t({id:'catalogacao.closedBatches'},{count: closedBatches.length})}
          </summary>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem', marginTop: 8 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thName'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thStatus'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thCreatedAt'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batchActions'})}</th>
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
                  <td style={{ padding: '8px', textAlign: 'right' }}>
                    <button className="ab-button ab-button--ghost" style={{ marginRight: 6, fontSize: '.75rem', padding: '4px 10px' }}
                      onClick={() => archiveBatch(b.id)}>{t({id:'catalogacao.archiveBatch'})}</button>
                    <button className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px', color: '#f87171' }}
                      onClick={() => deleteBatch(b.id)}>{t({id:'catalogacao.deleteBatch'})}</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      )}

      {/* Lotes archivés */}
      {archivedBatches.length > 0 && (
        <details style={{ marginTop: 12 }}>
          <summary style={{ cursor: 'pointer', fontSize: '.82rem', color: 'var(--brand-muted, #666)' }}>
            {t({id:'catalogacao.archivedBatches'},{count: archivedBatches.length})}
          </summary>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem', marginTop: 8 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid rgba(255,255,255,.1)' }}>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thName'})}</th>
                <th style={{ textAlign: 'left', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batch.thCreatedAt'})}</th>
                <th style={{ textAlign: 'right', padding: '6px 8px', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.batchActions'})}</th>
              </tr>
            </thead>
            <tbody>
              {archivedBatches.map(b => (
                <tr key={b.id} style={{ borderBottom: '1px solid rgba(255,255,255,.06)', opacity: 0.4 }}>
                  <td style={{ padding: '8px' }}>{b.name}</td>
                  <td style={{ padding: '8px' }}>{formatDate(b.created_at)}</td>
                  <td style={{ padding: '8px', textAlign: 'right' }}>
                    <button className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px', color: '#f87171' }}
                      onClick={() => deleteBatch(b.id)}>{t({id:'catalogacao.deleteBatch'})}</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      )}

      {batches.length === 0 && (
        <div className="cat-placeholder">{t({id:'catalogacao.noBatches'})}</div>
      )}
    </div>
  );
}
