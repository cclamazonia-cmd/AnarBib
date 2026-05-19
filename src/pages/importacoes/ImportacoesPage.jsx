import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useIntl } from 'react-intl';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import '../catalogacao/CatalogacaoPage.css';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';

const BUCKET = 'catalogos_parceiros_raw';
const ACCEPTED_EXTENSIONS = '.csv,.tsv,.txt,.ris,.bib,.bibtex,.mrc,.xlsx,.xls,.ods,.pdf,.json,.xml,.zip,.marc,.marcxml';
const ACCEPTED_MIME = 'text/csv,text/plain,application/pdf,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.oasis.opendocument.spreadsheet,application/json,application/xml,text/xml,application/x-research-info-systems,application/marc,application/zip';

function detectFileKind(fileName) {
  const n = (fileName || '').toLowerCase();
  if (n.endsWith('.csv')) return 'csv';
  if (n.endsWith('.tsv')) return 'tsv';
  if (n.endsWith('.txt')) return 'txt';
  if (n.endsWith('.ris')) return 'ris';
  if (n.endsWith('.bib') || n.endsWith('.bibtex')) return 'bibtex';
  if (n.endsWith('.mrc') || n.endsWith('.marc')) return 'marc21';
  if (n.endsWith('.marcxml')) return 'marcxml';
  if (n.endsWith('.xlsx')) return 'xlsx';
  if (n.endsWith('.xls')) return 'xls';
  if (n.endsWith('.ods')) return 'ods';
  if (n.endsWith('.pdf')) return 'pdf';
  if (n.endsWith('.json')) return 'json';
  if (n.endsWith('.xml')) return 'xml';
  if (n.endsWith('.zip')) return 'zip';
  return 'desconhecido';
}

function formatBytes(bytes) {
  if (!bytes) return '—';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

// FORMAT_LABELS is mostly technical terms (CSV, MARC21, etc.) — only 'desconhecido' needs i18n
// STATUS_LABELS are built inside the component using t()

export default function ImportacoesPage() {
  const { user } = useAuth();
  const { role } = useLibrary();
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'pageTitle.imports' }));

  const FORMAT_LABELS = useMemo(() => ({
    csv: 'CSV', tsv: 'TSV', txt: 'Text', ris: 'RIS', bibtex: 'BibTeX', marc21: 'MARC21', marcxml: 'MARCXML',
    xlsx: 'Excel (XLSX)', xls: 'Excel (XLS)', ods: 'ODS', pdf: 'PDF', json: 'JSON', xml: 'XML', zip: 'ZIP',
    rss: 'RSS/Atom', url: 'URL', opds: 'OPDS', desconhecido: t({ id: 'importacoes.format.unknown' }),
  }), [t]);
  const STATUS_LABELS = useMemo(() => ({
    pending: t({ id: 'importacoes.status.pending' }), uploaded: t({ id: 'importacoes.status.uploaded' }),
    parsing: t({ id: 'importacoes.status.parsing' }), parsed: t({ id: 'importacoes.status.parsed' }),
    ready_for_review: t({ id: 'importacoes.status.ready_for_review' }), reviewed: t({ id: 'importacoes.status.reviewed' }),
    drafts_created: t({ id: 'importacoes.status.drafts_created' }),
    failed: t({ id: 'importacoes.status.failed' }), cancelled: t({ id: 'importacoes.status.cancelled' }),
  }), [t]);

  // ── Tab state ───────────────────────────────────────────
  const [tab, setTab] = useState('reception'); // reception | history | url | rss

  // ── Reception state ─────────────────────────────────────
  const [file, setFile] = useState(null);
  const [filePreview, setFilePreview] = useState('');
  const [libName, setLibName] = useState('');
  const [libShort, setLibShort] = useState('');
  const [libSlug, setLibSlug] = useState('');
  const [libTerritory, setLibTerritory] = useState('');
  const [catalogNote, setCatalogNote] = useState('');
  const [sourceId, setSourceId] = useState('');
  const [sources, setSources] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [lastRunId, setLastRunId] = useState('');

  // ── URL import state ────────────────────────────────────
  const [urlInput, setUrlInput] = useState('');
  const [urlLoading, setUrlLoading] = useState(false);
  const [urlResult, setUrlResult] = useState(null);

  // ── RSS import state ────────────────────────────────────
  const [rssUrl, setRssUrl] = useState('');
  const [rssLoading, setRssLoading] = useState(false);
  const [rssItems, setRssItems] = useState([]);

  // ── Run history ─────────────────────────────────────────
  const [runs, setRuns] = useState([]);
  const [runsLoading, setRunsLoading] = useState(false);
  const [selectedRun, setSelectedRun] = useState(null);
  const [runRows, setRunRows] = useState([]);
  const [runRowsLoading, setRunRowsLoading] = useState(false);

  // ── Load sources ────────────────────────────────────────
  const loadSources = useCallback(async () => {
    try {
      const attempts = [
        () => supabase.from('partner_catalog_sources_ui').select('*').limit(200),
        () => supabase.schema('ingest').from('partner_catalog_sources').select('*').limit(200),
      ];
      for (const attempt of attempts) {
        try { const { data } = await attempt(); if (data?.length) { setSources(data); return; } } catch {}
      }
    } catch {}
  }, []);

  useEffect(() => { loadSources(); }, [loadSources]);

  // ── Load run history ────────────────────────────────────
  const loadRuns = useCallback(async () => {
    setRunsLoading(true);
    try {
      const attempts = [
        () => supabase.from('partner_catalog_import_runs_ui').select('*').order('requested_at', { ascending: false }).limit(30),
        () => supabase.schema('ingest').from('partner_catalog_import_runs').select('*').order('created_at', { ascending: false }).limit(30),
      ];
      for (const attempt of attempts) {
        try { const { data } = await attempt(); if (data) { setRuns(data); return; } } catch {}
      }
    } catch {} finally { setRunsLoading(false); }
  }, []);

  useEffect(() => { loadRuns(); }, [loadRuns]);

  // ── Role gating (must come AFTER all hooks to comply with Rules of Hooks) ──
  const roleLoaded = role !== null && role !== undefined;
  const canImport = role === 'librarian' || role === 'coordenador' || role === 'administrador';

  if (!roleLoaded) return (
    <PageShell><Topbar />
      <div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</div>
    <Footer /></PageShell>
  );

  if (!canImport) return (
    <PageShell><Topbar />
      <Hero title={t({ id: 'importacoes.title' })} subtitle={t({ id: 'importacoes.restricted' })} />
    <Footer /></PageShell>
  );

  // ── File handling ───────────────────────────────────────
  function handleFileChange(e) {
    const f = e.target.files?.[0];
    if (!f) return;
    setFile(f);
    setFilePreview('');
    // Read preview for text-based formats
    const kind = detectFileKind(f.name);
    if (['csv', 'tsv', 'txt', 'ris', 'bibtex', 'json', 'xml', 'marcxml'].includes(kind)) {
      const reader = new FileReader();
      reader.onload = (ev) => setFilePreview((ev.target?.result || '').slice(0, 2000));
      reader.readAsText(f.slice(0, 2000));
    }
  }

  function buildStoragePath() {
    const slug = (libSlug || libShort || libName || '').replace(/[^a-zA-Z0-9._-]/g, '_').toLowerCase() || 'parceira';
    const date = new Date().toISOString().slice(0, 10);
    const safeName = (file?.name || 'catalogo').replace(/[^a-zA-Z0-9._-]/g, '_');
    return `partner/manual/${slug}/${date}/${Date.now()}-${safeName}`;
  }

  // ── Upload + Create run ─────────────────────────────────
  async function handleUploadAndProcess() {
    if (!file) { setMsg({ text: t({id:'importacoes.selectFile'}), kind: 'error' }); return; }
    if (!sourceId) { setMsg({ text: t({id:'importacoes.selectSource'}), kind: 'error' }); return; }

    setUploading(true); setMsg({ text: t({id:'importacoes.sendingFile'}), kind: 'info' });
    try {
      const path = buildStoragePath();
      const { error: uploadErr } = await supabase.storage.from(BUCKET).upload(path, file, { upsert: true });
      if (uploadErr) throw uploadErr;

      setMsg({ text: t({id:'importacoes.fileSent'}), kind: 'info' });
      setProcessing(true);

      // Create import run via RPC
      const createParams = {
        p_source_id: Number(sourceId),
        p_bucket_id: BUCKET,
        p_storage_path: path,
        p_original_filename: file.name,
        p_mime_type: file.type || 'application/octet-stream',
        p_size_bytes: file.size,
      };

      let runId = null;
      try {
        const { data } = await supabase.schema('ingest').rpc('fn_create_partner_catalog_import', createParams);
        runId = data;
      } catch {
        const { data } = await supabase.rpc('fn_create_partner_catalog_import', createParams);
        runId = data;
      }

      if (!runId) throw new Error(t({id:'importacoes.noRunId'}));
      setLastRunId(String(runId));

      // Dispatch parsing
      setMsg({ text: t({ id: 'importacoes.runCreatedDispatching' }, { id: runId }), kind: 'info' });
      try {
        await supabase.schema('ingest').rpc('fn_dispatch_partner_catalog_import', { p_run_id: Number(runId), p_force_reparse: false });
      } catch {
        await supabase.rpc('fn_dispatch_partner_catalog_import', { p_run_id: Number(runId), p_force_reparse: false });
      }

      setMsg({ text: t({ id: 'importacoes.runDispatched' }, { id: runId }), kind: 'ok' });
      await loadRuns();
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' });
    } finally { setUploading(false); setProcessing(false); }
  }

  // ── Load run detail ─────────────────────────────────────
  async function loadRunDetail(run) {
    setSelectedRun(run);
    setRunRowsLoading(true); setRunRows([]);
    try {
      const runId = Number(run.id);
      const attempts = [
        () => supabase.from('partner_catalog_import_rows_ui').select('*').eq('run_id', runId).order('row_no').limit(500),
        () => supabase.schema('ingest').from('partner_catalog_staging_rows').select('*').eq('run_id', runId).order('row_no').limit(500),
      ];
      for (const attempt of attempts) {
        try { const { data } = await attempt(); if (data) { setRunRows(data); return; } } catch {}
      }
    } catch {} finally { setRunRowsLoading(false); }
  }

  // ── Bulk create drafts from run ─────────────────────────
  async function bulkCreateDrafts() {
    if (!selectedRun) return;
    if (!confirm(t({ id: 'importacoes.bulkDraftsConfirm' }, { id: selectedRun.id }))) return;
    setMsg({ text: t({id:'importacoes.generatingDrafts'}), kind: 'info' });
    try {
      try {
        await supabase.schema('ingest').rpc('fn_bulk_create_book_drafts_from_run', { p_run_id: Number(selectedRun.id) });
      } catch {
        await supabase.rpc('fn_bulk_create_book_drafts_from_run', { p_run_id: Number(selectedRun.id) });
      }
      setMsg({ text: t({ id: 'importacoes.draftsCreated' }), kind: 'ok' });
      await loadRuns();
      await loadRunDetail(selectedRun);
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' });
    }
  }

  // ── URL import (metadata lookup) ────────────────────────
  async function handleUrlImport() {
    if (!urlInput.trim()) { setMsg({ text: t({id:'importacoes.enterUrl'}), kind: 'error' }); return; }
    setUrlLoading(true); setUrlResult(null); setMsg({ text: t({id:'importacoes.consultingUrl'}), kind: 'info' });
    try {
      // Extract ISBN from URL if possible
      const isbnMatch = urlInput.match(/isbn[=/:]?\s*([0-9X-]{10,17})/i) || urlInput.match(/\b(97[89]\d{10})\b/) || urlInput.match(/\b(\d{9}[\dXx])\b/);
      const isbn = isbnMatch ? isbnMatch[1].replace(/[^0-9Xx]/g, '') : '';

      if (isbn) {
        const { data } = await supabase.functions.invoke('catalog_metadata_lookup', { body: { isbn } });
        if (data?.candidates?.length) {
          setUrlResult({ type: 'isbn', isbn, candidates: data.candidates, url: urlInput });
          setMsg({ text: t({ id: 'importacoes.isbnResults' }, { count: data.candidates.length, isbn }), kind: 'ok' });
        } else {
          setMsg({ text: t({id:'importacoes.isbnNotFound'}), kind: 'info' });
        }
      } else {
        // Fetch URL metadata via fetch-url-metadata
        const { data } = await supabase.functions.invoke('fetch-url-metadata', { body: { url: urlInput.trim(), mode: 'html' } });
        if (data?.ok) {
          setUrlResult({ type: 'html', metadata: data, url: urlInput });
          setMsg({ text: data.title ? t({ id: 'importacoes.metadataExtracted' }, { title: data.title }) : t({ id: 'importacoes.urlAccessedFewMeta' }), kind: data.title ? 'ok' : 'info' });
        } else {
          setMsg({ text: data?.error || t({ id: 'importacoes.urlError' }), kind: 'error' });
        }
      }
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' });
    } finally { setUrlLoading(false); }
  }

  // ── RSS/Atom import ─────────────────────────────────────
  async function handleRssImport() {
    if (!rssUrl.trim()) { setMsg({ text: t({id:'importacoes.enterRssUrl'}), kind: 'error' }); return; }
    setRssLoading(true); setRssItems([]); setMsg({ text: t({id:'importacoes.fetchingRss'}), kind: 'info' });
    try {
      const { data } = await supabase.functions.invoke('fetch-url-metadata', {
        body: { url: rssUrl.trim(), mode: 'rss' },
      });
      if (data?.ok && data?.items?.length) {
        setRssItems(data.items);
        setMsg({ text: t({ id: 'importacoes.rss.itemsFromFeed' }, { count: data.items.length, feed: data.feed_title || '' }), kind: 'ok' });
      } else if (data?.ok && data?.mode === 'html') {
        setMsg({ text: t({ id: 'importacoes.notRss' }), kind: 'info' });
      } else {
        setMsg({ text: data?.error || t({id:'importacoes.noRssItems'}), kind: 'info' });
      }
    } catch (err) {
      setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' });
    } finally { setRssLoading(false); }
  }

  // ── Styles ──────────────────────────────────────────────
  const fs = { width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.9rem' };
  const ls = { display: 'block', fontSize: '.85rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' };
  const tabs = [
    { id: 'reception', label: t({ id: 'importacoes.tab.reception' }) },
    { id: 'url', label: t({id:'importacoes.tab.url'}) },
    { id: 'rss', label: t({id:'importacoes.tab.rss'}) },
    { id: 'history', label: t({ id: 'importacoes.tab.history' }) },
  ];

  return (
    <PageShell><Topbar />

      <Hero title={t({ id: 'importacoes.title' })} subtitle={t({ id: 'importacoes.subtitle' })}>
        <UserHeroBadge />
        <HeroDocumentationActions />
      </Hero>

      <div className="catalogacao-wrap" style={{ maxWidth: 1200, margin: '0 auto' }}>

        {/* ── Messages ───────────────────────────────── */}
        {msg.text && <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.9rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'info' ? 'rgba(29,78,216,.1)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'info' ? '#60a5fa' : '#f87171' }}>{msg.text}</div>}

        {/* ── Sub-tabs ───────────────────────────────── */}
        <div style={{ display: 'flex', gap: 0, borderBottom: '2px solid rgba(255,255,255,.08)', marginBottom: 18 }}>
          {tabs.map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              padding: '10px 18px', fontSize: '.92rem', fontWeight: 600,
              background: 'none', border: 'none', cursor: 'pointer',
              borderBottom: `2px solid ${tab === t.id ? 'var(--brand-color-primary, #7a0b14)' : 'transparent'}`,
              color: tab === t.id ? 'var(--brand-text)' : 'var(--brand-muted)',
              marginBottom: -2, transition: 'all .15s',
            }}>{t.label}</button>
          ))}
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/*  TAB 1: Recepção artesanal de arquivo           */}
        {/* ═══════════════════════════════════════════════ */}
        {tab === 'reception' && (
          <div>
            <div style={{ padding: 16, borderRadius: 10, background: 'rgba(29,78,216,.06)', border: '1px solid rgba(29,78,216,.15)', marginBottom: 16 }}>
              <h3 style={{ margin: '0 0 6px', fontSize: '1.1rem' }}>{t({ id: 'importacoes.reception.title' })}</h3>
              <p style={{ fontSize: '.85rem', color: 'var(--brand-muted)', margin: 0 }} dangerouslySetInnerHTML={{ __html: t({ id: 'importacoes.reception.formats' }) }} />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
              {/* Left: file + identity */}
              <div>
                <div style={{ marginBottom: 14 }}>
                  <label style={ls}>{t({ id: 'importacoes.reception.fileLabel' })}</label>
                  <label style={{ display: 'inline-block', padding: '8px 16px', borderRadius: 8, background: 'var(--brand-panel-bg)', border: '1px solid rgba(255,255,255,.15)', cursor: 'pointer', fontSize: '.85rem', fontWeight: 600 }}>
                    {t({ id: 'importacoes.reception.chooseFile' })}
                    <input type="file" accept={`${ACCEPTED_EXTENSIONS},${ACCEPTED_MIME}`} onChange={handleFileChange} style={{ display: 'none' }} />
                  </label>
                  {file && (
                    <div style={{ marginTop: 8, fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                      <strong>{file.name}</strong> · {formatBytes(file.size)} · {t({ id: 'importacoes.reception.formatPrefix' })}: <strong>{FORMAT_LABELS[detectFileKind(file.name)] || t({ id: 'importacoes.format.unknown' })}</strong>
                    </div>
                  )}
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 14 }}>
                  <div><label style={ls}>{t({ id: 'importacoes.reception.libNameLabel' })}</label><input type="text" value={libName} onChange={e => setLibName(e.target.value)} placeholder={t({ id: 'importacoes.reception.libNamePlaceholder' })} style={fs} /></div>
                  <div><label style={ls}>{t({ id: 'importacoes.reception.libShortLabel' })}</label><input type="text" value={libShort} onChange={e => setLibShort(e.target.value)} placeholder={t({ id: 'importacoes.reception.libShortPlaceholder' })} style={fs} /></div>
                  <div><label style={ls}>{t({ id: 'importacoes.reception.libSlugLabel' })}</label><input type="text" value={libSlug} onChange={e => setLibSlug(e.target.value)} placeholder={t({ id: 'importacoes.reception.libSlugPlaceholder' })} style={{ ...fs, fontFamily: 'monospace' }} /></div>
                  <div><label style={ls}>{t({ id: 'importacoes.reception.libTerritoryLabel' })}</label><input type="text" value={libTerritory} onChange={e => setLibTerritory(e.target.value)} placeholder={t({ id: 'importacoes.reception.libTerritoryPlaceholder' })} style={fs} /></div>
                </div>

                <div style={{ marginBottom: 14 }}>
                  <label style={ls}>{t({ id: 'importacoes.reception.noteLabel' })}</label>
                  <input type="text" value={catalogNote} onChange={e => setCatalogNote(e.target.value)} placeholder={t({ id: 'importacoes.reception.notePlaceholder' })} style={fs} />
                </div>
              </div>

              {/* Right: source + preview */}
              <div>
                <div style={{ marginBottom: 14 }}>
                  <label style={ls}>{t({ id: 'importacoes.file.source' })}</label>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <select value={sourceId} onChange={e => setSourceId(e.target.value)} style={{ ...fs, flex: 1 }}>
                      <option value="">{t({ id: 'importacoes.reception.selectSourcePlaceholder' })}</option>
                      {sources.map(s => <option key={s.id} value={String(s.id)}>{s.partner_name || s.label || t({ id: 'importacoes.reception.sourceNumberFallback' }, { id: s.id })}</option>)}
                    </select>
                    <button type="button" className="cat-btn secondary" style={{ fontSize: '.8rem', padding: '6px 12px', flexShrink: 0 }} onClick={loadSources}>{t({ id: 'common.update' })}</button>
                  </div>
                </div>

                {filePreview && (
                  <div style={{ marginBottom: 14 }}>
                    <label style={ls}>{t({ id: 'importacoes.reception.previewLabel' })}</label>
                    <pre style={{ ...fs, height: 160, overflow: 'auto', fontSize: '.78rem', whiteSpace: 'pre-wrap', wordBreak: 'break-all' }}>{filePreview}</pre>
                  </div>
                )}

                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <button type="button" className="cat-btn primary" style={{ fontSize: '.9rem', padding: '9px 18px' }}
                    onClick={handleUploadAndProcess} disabled={uploading || processing || !file}>
                    {uploading ? t({id:'importacoes.uploading'}) : processing ? t({id:'importacoes.processing'}) : t({id:'importacoes.launch'})}
                  </button>
                  <button type="button" className="cat-btn ghost" style={{ fontSize: '.85rem', padding: '7px 14px' }}
                    onClick={() => { setFile(null); setFilePreview(''); setMsg({ text: '', kind: '' }); }}>
                    {t({ id: 'importacoes.reception.clear' })}
                  </button>
                </div>

                {lastRunId && (
                  <div style={{ marginTop: 10, fontSize: '.85rem', color: '#4ade80' }}>
                    {t({ id: 'importacoes.lastRunNotice' }, { id: lastRunId })}
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* ═══════════════════════════════════════════════ */}
        {/*  TAB 2: Import by URL                           */}
        {/* ═══════════════════════════════════════════════ */}
        {tab === 'url' && (
          <div>
            <div style={{ padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16 }}>
              <h3 style={{ margin: '0 0 6px', fontSize: '1.1rem' }}>{t({ id: 'importacoes.tab.url' })}</h3>
              <p style={{ fontSize: '.85rem', color: 'var(--brand-muted)', margin: 0 }}>
                {t({ id: 'importacoes.url.help' })}
              </p>
            </div>

            <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
              <input type="url" value={urlInput} onChange={e => setUrlInput(e.target.value)}
                placeholder={t({ id: 'importacoes.url.placeholder' })} style={{ ...fs, flex: 1 }} />
              <button type="button" className="cat-btn primary" style={{ fontSize: '.9rem', padding: '9px 18px', flexShrink: 0 }}
                onClick={handleUrlImport} disabled={urlLoading}>
                {urlLoading ? t({ id: 'common.searching' }) : t({ id: 'importacoes.url.fetchMetadata' })}
              </button>
            </div>

            {urlResult?.candidates?.length > 0 && (
              <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, maxHeight: 400, overflowY: 'auto' }}>
                {urlResult.candidates.map((c, i) => (
                  <div key={i} style={{ padding: '10px 12px', borderBottom: '1px solid rgba(255,255,255,.04)', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent' }}>
                    <div style={{ fontSize: '.95rem', fontWeight: 700 }}>{c.title}{c.subtitle ? ` : ${c.subtitle}` : ''}</div>
                    <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                      {[c.responsibility_statement || c.contributors?.[0]?.label, c.publisher, c.year].filter(Boolean).join(' · ')}
                      {c.isbn?.length > 0 && ` · ISBN: ${c.isbn[0]}`}
                      {c.source && t({ id: 'importacoes.url.sourceFragment' }, { source: c.source })}
                    </div>
                  </div>
                ))}
              </div>
            )}

            {urlResult?.type === 'html' && urlResult.metadata && (
              <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
                <h4 style={{ margin: '0 0 8px', fontSize: '1rem' }}>{t({ id: 'importacoes.url.extractedTitle' })}</h4>
                <div style={{ fontSize: '.88rem', lineHeight: 1.7 }}>
                  {urlResult.metadata.title && <div><strong>{t({id:'importacoes.url.resultTitle'})}:</strong> {urlResult.metadata.title}</div>}
                  {urlResult.metadata.author && <div><strong>{t({ id: 'importacoes.url.resultAuthor' })}:</strong> {urlResult.metadata.author}</div>}
                  {urlResult.metadata.publisher && <div><strong>{t({ id: 'importacoes.url.resultPublisher' })}:</strong> {urlResult.metadata.publisher}</div>}
                  {urlResult.metadata.date && <div><strong>{t({ id: 'importacoes.url.resultDate' })}:</strong> {urlResult.metadata.date}</div>}
                  {urlResult.metadata.isbn && <div><strong>ISBN:</strong> {urlResult.metadata.isbn}</div>}
                  {urlResult.metadata.language && <div><strong>{t({ id: 'importacoes.url.resultLanguage' })}:</strong> {urlResult.metadata.language}</div>}
                  {urlResult.metadata.description && <div><strong>{t({id:'importacoes.url.resultDescription'})}:</strong> {urlResult.metadata.description}</div>}
                  {urlResult.metadata.image && <div style={{ marginTop: 8 }}><img src={urlResult.metadata.image} alt="" style={{ maxHeight: 120, borderRadius: 6, border: '1px solid rgba(255,255,255,.1)' }} /></div>}
                </div>
                <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginTop: 8 }}>
                  {t({ id: 'importacoes.url.sourceTypeFragment' }, { url: urlResult.url, type: urlResult.metadata.content_type || '—' })}
                </div>
              </div>
            )}
          </div>
        )}

        {/* ═══════════════════════════════════════════════ */}
        {/*  TAB 3: RSS / Atom                              */}
        {/* ═══════════════════════════════════════════════ */}
        {tab === 'rss' && (
          <div>
            <div style={{ padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16 }}>
              <h3 style={{ margin: '0 0 6px', fontSize: '1.1rem' }}>{t({ id: 'importacoes.tab.rss' })}</h3>
              <p style={{ fontSize: '.85rem', color: 'var(--brand-muted)', margin: 0 }}>
                {t({ id: 'importacoes.rss.help' })}
              </p>
            </div>

            <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
              <input type="url" value={rssUrl} onChange={e => setRssUrl(e.target.value)}
                placeholder={t({ id: 'importacoes.rss.exampleUrl' })} style={{ ...fs, flex: 1 }} />
              <button type="button" className="cat-btn primary" style={{ fontSize: '.9rem', padding: '9px 18px', flexShrink: 0 }}
                onClick={handleRssImport} disabled={rssLoading}>
                {rssLoading ? t({ id: 'common.searching' }) : t({ id: 'importacoes.rss.fetch' })}
              </button>
            </div>

            {rssItems.length > 0 && (
              <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, maxHeight: 400, overflowY: 'auto' }}>
                {rssItems.map((item, i) => (
                  <div key={i} style={{ padding: '10px 12px', borderBottom: '1px solid rgba(255,255,255,.04)', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent' }}>
                    <div style={{ fontSize: '.95rem', fontWeight: 700 }}>{item.title || t({id:'importacoes.noTitle'})}</div>
                    <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
                      {[item.author, item.date, item.category].filter(Boolean).join(' · ')}
                    </div>
                    {item.link && <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)', marginTop: 2 }}>{item.link}</div>}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ═══════════════════════════════════════════════ */}
        {/*  TAB 4: Histórico de tratamentos                */}
        {/* ═══════════════════════════════════════════════ */}
        {tab === 'history' && (
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
              <h3 style={{ margin: 0, fontSize: '1.1rem' }}>{t({ id: 'importacoes.tab.history' })}</h3>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.85rem', padding: '7px 14px' }}
                onClick={loadRuns} disabled={runsLoading}>{runsLoading ? t({ id: 'rede.refreshing' }) : t({ id: 'common.update' })}</button>
            </div>

            {/* Run list */}
            <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 250, overflowY: 'auto', marginBottom: 16 }}>
              {runs.length === 0 && !runsLoading && <div style={{ padding: 16, textAlign: 'center', fontSize: '.9rem', color: 'var(--brand-muted)' }}>{t({ id: 'importacoes.history.empty' })}</div>}
              {runs.map((r, i) => (
                <div key={r.id} onClick={() => loadRunDetail(r)} style={{
                  display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', cursor: 'pointer',
                  background: selectedRun?.id === r.id ? 'rgba(29,78,216,.12)' : i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
                  borderBottom: '1px solid rgba(255,255,255,.04)',
                }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: '.9rem', fontWeight: 600 }}>
                      #{r.id} — {r.original_filename || t({ id: 'importacoes.noFile' })}
                    </div>
                    <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)' }}>
                      {t({ id: 'importacoes.reception.formatPrefix' })}: {FORMAT_LABELS[r.detected_format] || r.detected_format || '—'}
                      {r.imported_rows != null && ` · ${t({ id: 'importacoes.rowsCount' }, { count: r.imported_rows })}`}
                      {r.created_drafts != null && ` · ${t({ id: 'importacoes.draftsCount' }, { count: r.created_drafts })}`}
                      {r.parser_version && ` · parser: ${r.parser_version}`}
                    </div>
                  </div>
                  <span className={`cat-pill ${r.run_status === 'drafts_created' || r.run_status === 'reviewed' ? 'ok' : r.run_status === 'failed' ? 'danger' : r.run_status === 'ready_for_review' ? 'warn' : 'info'}`}
                    style={{ fontSize: '.7rem', flexShrink: 0 }}>
                    {STATUS_LABELS[r.run_status] || r.run_status}
                  </span>
                </div>
              ))}
            </div>

            {/* Run detail */}
            {selectedRun && (
              <div style={{ padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                  <h4 style={{ margin: 0, fontSize: '1rem' }}>{t({ id: 'importacoes.history.runId' }, { id: selectedRun.id })} — {selectedRun.original_filename}</h4>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button type="button" className="cat-btn primary" style={{ fontSize: '.85rem', padding: '7px 14px' }}
                      onClick={bulkCreateDrafts} disabled={selectedRun.run_status === 'drafts_created'}>
                      {selectedRun.run_status === 'drafts_created' ? t({ id: 'importacoes.draftsAlreadyCreated' }) : t({ id: 'importacoes.generateDrafts' })}
                    </button>
                    <button type="button" className="cat-btn secondary" style={{ fontSize: '.85rem', padding: '7px 14px' }}
                      onClick={() => loadRunDetail(selectedRun)}>{t({ id: 'importacoes.refreshRows' })}</button>
                  </div>
                </div>

                {/* Staging rows */}
                {runRowsLoading && <div style={{ fontSize: '.9rem', color: 'var(--brand-muted)', padding: 12 }}>{t({ id: 'importacoes.loadingRows' })}</div>}
                {!runRowsLoading && runRows.length === 0 && <div style={{ fontSize: '.9rem', color: 'var(--brand-muted)', padding: 12 }}>{t({ id: 'importacoes.noRowsAvailable' })}</div>}
                {runRows.length > 0 && (
                  <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 350, overflowY: 'auto' }}>
                    {runRows.map((row, i) => (
                      <div key={row.id} style={{
                        padding: '8px 10px',
                        background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
                        borderBottom: '1px solid rgba(255,255,255,.04)',
                      }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ fontSize: '.88rem', fontWeight: 600 }}>
                              {row.title || t({id:'importacoes.noTitle'})}
                              {row.subtitle && <span style={{ fontWeight: 400, color: 'var(--brand-muted)' }}> : {row.subtitle}</span>}
                            </div>
                            <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>
                              {[row.responsibility_statement, row.publisher, row.publication_year, row.isbn].filter(Boolean).join(' · ')}
                            </div>
                          </div>
                          <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                            {row.parse_status && <span className={`cat-pill ${row.parse_status === 'ok' ? 'ok' : 'warn'}`} style={{ fontSize: '.62rem' }}>{row.parse_status}</span>}
                            {row.match_status && <span className={`cat-pill ${row.match_status === 'matched' ? 'ok' : row.match_status === 'new' ? 'info' : 'warn'}`} style={{ fontSize: '.62rem' }}>{row.match_status}</span>}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    <Footer /></PageShell>
  );
}
