import { useState, useEffect, useCallback, useMemo } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useIntl } from 'react-intl';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import UserHeroBadge from '@/components/UserHeroBadge';
import HeroDocumentationActions from '@/components/HeroDocumentationActions';
import './ImportacoesPage.css';

const BUCKET = 'catalogos_parceiros_raw';
const ACCEPTED_EXTENSIONS = '.csv,.tsv,.txt,.ris,.bib,.bibtex,.mrc,.xlsx,.xls,.ods,.pdf,.json,.xml,.zip,.marc,.marcxml';

function detectFileKind(fileName) {
  const n = (fileName || '').toLowerCase();
  if (n.endsWith('.csv')) return 'csv';
  if (n.endsWith('.tsv')) return 'tsv';
  if (n.endsWith('.ris')) return 'ris';
  if (n.endsWith('.bib') || n.endsWith('.bibtex')) return 'bibtex';
  if (n.endsWith('.mrc') || n.endsWith('.marc')) return 'marc21';
  if (n.endsWith('.marcxml')) return 'marcxml';
  if (n.endsWith('.json')) return 'json';
  if (n.endsWith('.xml')) return 'xml';
  return 'unknown';
}

function formatDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' })
    + ' ' + d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

export default function ImportacoesPage() {
  useAuth();
  const { role, libraryId, isNetworkAdmin } = useLibrary();
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'importacoes.title' }));

  // ── Core UI state ──────────────────────────────────────
  const [sentido, setSentido] = useState('import');
  // Origine d'ajout (fusion des 3 ex-circuits) : fichier / busca / oai.
  const [addMode, setAddMode] = useState('arquivo');
  const [msg, setMsg] = useState({ text: '', kind: '' });
  // ── Export de lote (Lot 5, IMP-13) ─────────────────────
  const [exportFormat, setExportFormat] = useState('csv');
  const [exportLoading, setExportLoading] = useState(false);

  // ── Data state ─────────────────────────────────────────
  const [sources, setSources] = useState([]);
  const [runs, setRuns] = useState([]);
  const [_runsLoading, setRunsLoading] = useState(false);
  const [selectedRunId, setSelectedRunId] = useState(null);
  const [runRows, setRunRows] = useState([]);
  const [runRowsLoading, setRunRowsLoading] = useState(false);

  // ── Fila filters ───────────────────────────────────────
  const [filaSourceFilter, setFilaSourceFilter] = useState('');
  const [filaStateFilter, setFilaStateFilter] = useState('');

  // ── Arquivo upload state ───────────────────────────────
  const [file, setFile] = useState(null);
  const [sourceId, setSourceId] = useState('');
  const [uploading, setUploading] = useState(false);

  // ── Fontes externas search ─────────────────────────────
  const [searchQuery, setSearchQuery] = useState('');
  const [searchSource, setSearchSource] = useState('bn');
  const [searchResults, setSearchResults] = useState([]);
  const [searching, setSearching] = useState(false);

  // ── OAI-PMH harvesting ────────────────────────────────
  const [oaiSources, setOaiSources] = useState([]);
  const [oaiLoading, setOaiLoading] = useState(false);

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

  // ── Load sources via Lot 0 API ─────────────────────────
  const loadSources = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc('fn_import_list_sources');
      if (!error && data) setSources(data);
    } catch { /* guard */ }
  }, []);

  // ── Load runs via Lot 0 API ────────────────────────────
  const loadRuns = useCallback(async () => {
    setRunsLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_import_list_runs');
      if (!error && data) setRuns(data);
    } catch { /* guard */ }
    finally { setRunsLoading(false); }
  }, []);

  // ── Load run rows via Lot 0 API ────────────────────────
  const loadRunRows = useCallback(async (runId) => {
    if (!runId) return;
    setRunRowsLoading(true);
    setRunRows([]);
    try {
      const { data, error } = await supabase.rpc('fn_import_list_run_rows', { p_run_id: Number(runId) });
      if (!error && data) setRunRows(data);
    } catch { /* guard */ }
    finally { setRunRowsLoading(false); }
  }, []);

  // ── Load OAI sources ────────────────────────────────────
  const loadOaiSources = useCallback(async () => {
    setOaiLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_import_list_oai_sources');
      if (!error && data) setOaiSources(data);
    } catch { /* guard */ }
    finally { setOaiLoading(false); }
  }, []);

  useEffect(() => { loadSources(); loadRuns(); loadOaiSources(); }, [loadSources, loadRuns, loadOaiSources]);

  // Refresh manuel : le traitement (parse + matching) est asynchrone côté EF ;
  // les compteurs/états ne se mettent pas à jour en direct. Ce bouton recharge.
  const [refreshing, setRefreshing] = useState(false);
  const [showArchived, setShowArchived] = useState(false);
  const [rowLimit, setRowLimit] = useState(50);
  // Validation par-ligne : sélection de nouveautés à promouvoir en lot.
  const [selectedRows, setSelectedRows] = useState(() => new Set());
  const [promotingSel, setPromotingSel] = useState(false);
  const [filaMatchFilter, setFilaMatchFilter] = useState('');
  async function handleRefresh() {
    setRefreshing(true);
    try {
      await Promise.all([loadSources(), loadRuns(), loadOaiSources()]);
      if (selectedRunId) await loadRunRows(selectedRunId);
    } finally { setRefreshing(false); }
  }

  // ── Derived data (hooks must be before early returns) ──
  const runStats = useMemo(() => {
    const total = runs.length;
    const draftsCreated = runs.filter(r => r.run_status === 'drafts_created').length;
    const pending = runs.filter(r => r.run_status === 'ready_for_review').length;
    const totalRows = runs.reduce((s, r) => s + (r.imported_rows || 0), 0);
    return { total, draftsCreated, pending, totalRows };
  }, [runs]);

  const filteredRunRows = useMemo(() => {
    let rows = runRows;
    if (filaStateFilter) {
      rows = rows.filter(r => r.review_status === filaStateFilter);
    }
    if (filaMatchFilter === 'new') {
      rows = rows.filter(r => r.match_status === 'new_record');
    } else if (filaMatchFilter === 'dup') {
      rows = rows.filter(r => ['possible_duplicate', 'matched_book', 'matched_draft'].includes(r.match_status));
    }
    return rows;
  }, [runRows, filaStateFilter, filaMatchFilter]);

  // Run sélectionné + barrière : on ne montre les lignes que si le traitement
  // (parse + matching) est terminé. Sinon « en cours » ou « échoué ».
  const selectedRun = useMemo(() => runs.find(r => r.id === selectedRunId) || null, [runs, selectedRunId]);
  const runProcessing = !!selectedRun && ['pending', 'uploaded', 'parsing', 'parsed'].includes(selectedRun.run_status);
  const runFailed = !!selectedRun && selectedRun.run_status === 'failed';

  // Lignes à traiter (sélectionnables) : non promues ET décision encore en
  // attente — nouveautés ET doublons (pour pouvoir les écarter/rejeter).
  const selectableIds = useMemo(
    () => filteredRunRows
      .filter(r => !r.created_book_draft_id && !r.created_exemplar_draft_id && (r.editorial_decision == null || r.editorial_decision === 'pending'))
      .map(r => r.id),
    [filteredRunRows]
  );
  const allVisibleSelected = selectableIds.length > 0 && selectableIds.every(id => selectedRows.has(id));
  // Combien de sélectionnées sont des nouveautés promouvables (pour le bouton Criar).
  const selectedNewCount = useMemo(
    () => filteredRunRows.filter(r => selectedRows.has(r.id) && r.match_status === 'new_record' && !r.created_book_draft_id).length,
    [filteredRunRows, selectedRows]
  );
  // Combien de sélectionnées sont des doublons rapprochables (livre publié) — bouton Rapprocher.
  const selectedDupCount = useMemo(
    () => filteredRunRows.filter(r => selectedRows.has(r.id)
      && r.proposed_book_id
      && !r.created_exemplar_draft_id
      && (r.match_status === 'possible_duplicate' || r.match_status === 'matched_book')).length,
    [filteredRunRows, selectedRows]
  );

  // Réinitialise pagination + sélection quand on change de run ou de filtre.
  useEffect(() => { setRowLimit(50); setSelectedRows(new Set()); }, [selectedRunId, filaStateFilter, filaMatchFilter]);

  // ── Role gating ────────────────────────────────────────
  const roleLoaded = role !== null && role !== undefined;
  // IMP-14 : import/export sous l'autorité des coordinateurs (aligné sur le
  // backend fn_import_* coordenador-only + la nav canSeeImportacoes=isCoord).
  // Les librarians sont volontairement exclus ici.
  const canImport = role === 'coordenador' || role === 'administrador' || isNetworkAdmin;

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

  // ── Upload + dispatch (arquivo circuit) ────────────────
  async function handleUploadAndProcess() {
    if (!file) { setMsg({ text: t({ id: 'importacoes.selectFile' }), kind: 'error' }); return; }
    if (!sourceId) { setMsg({ text: t({ id: 'importacoes.selectSource' }), kind: 'error' }); return; }
    setUploading(true);
    setMsg({ text: t({ id: 'importacoes.sendingFile' }), kind: 'info' });
    try {
      const slug = 'import';
      const path = `partner/manual/${slug}/${new Date().toISOString().slice(0, 10)}/${Date.now()}-${(file.name || 'file').replace(/[^a-zA-Z0-9._-]/g, '_')}`;
      const { error: upErr } = await supabase.storage.from(BUCKET).upload(path, file, { upsert: true });
      if (upErr) throw upErr;

      const { data: createData, error: createErr } = await supabase.rpc('fn_import_create', {
        p_source_id: Number(sourceId),
        p_storage_path: path,
        p_original_filename: file.name,
        p_bucket_id: BUCKET,
        p_mime_type: file.type || 'application/octet-stream',
        p_size_bytes: file.size,
        p_detected_format: detectFileKind(file.name),
      });
      if (createErr) throw createErr;
      const runId = createData?.run_id;
      if (!runId) throw new Error(t({ id: 'importacoes.noRunId' }));

      setMsg({ text: t({ id: 'importacoes.runCreatedDispatching' }, { id: runId }), kind: 'info' });
      await supabase.rpc('fn_import_dispatch', { p_run_id: Number(runId) });

      setMsg({ text: t({ id: 'importacoes.runDispatched' }, { id: runId }), kind: 'ok' });
      setFile(null);
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setUploading(false); }
  }

  // ── Validation par-ligne : sélection puis promotion en lot ─────
  function toggleRow(id) {
    setSelectedRows(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }
  function toggleAllVisible() {
    setSelectedRows(prev => {
      const allSel = selectableIds.length > 0 && selectableIds.every(id => prev.has(id));
      return allSel ? new Set() : new Set(selectableIds);
    });
  }
  async function handlePromoteSelected() {
    if (!selectedRunId) return;
    // On ne promeut QUE les nouveautés sélectionnées (les doublons ne se créent
    // pas à l'aveugle — ils s'écartent via Rejeter, ou se rapprochent par
    // l'Adaptador). On filtre donc la sélection sur match_status='new_record'.
    const ids = filteredRunRows
      .filter(r => selectedRows.has(r.id) && r.match_status === 'new_record' && !r.created_book_draft_id)
      .map(r => r.id);
    if (!ids.length) return;
    setPromotingSel(true);
    setMsg({ text: t({ id: 'importacoes.generatingDrafts' }), kind: 'info' });
    try {
      await supabase.rpc('fn_import_set_editorial', {
        p_run_id: Number(selectedRunId),
        p_row_ids: ids,
        p_editorial_decision: 'accept_new',
        p_editorial_note: 'page import: validation individuelle',
      });
      const { error } = await supabase.rpc('fn_import_promote', { p_run_id: Number(selectedRunId) });
      if (error) throw error;
      setMsg({ text: t({ id: 'importacoes.draftsCreated' }), kind: 'ok' });
      setSelectedRows(new Set());
      await loadRuns();
      await loadRunRows(selectedRunId);
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setPromotingSel(false);
    }
  }
  // Rapprocher des doublons (livre déjà publié au catalogue) : crée un brouillon
  // d'exemplaire pour la biblio, rattaché au proposed_book_id (pas un book_draft).
  async function handleReconcileSelected() {
    if (!selectedRunId) return;
    const ids = filteredRunRows
      .filter(r => selectedRows.has(r.id) && r.proposed_book_id && !r.created_exemplar_draft_id
        && (r.match_status === 'possible_duplicate' || r.match_status === 'matched_book'))
      .map(r => r.id);
    if (!ids.length) return;
    setPromotingSel(true);
    setMsg({ text: t({ id: 'importacoes.fila.reconciling' }), kind: 'info' });
    try {
      const { error } = await supabase.rpc('fn_import_reconcile_duplicates', {
        p_run_id: Number(selectedRunId),
        p_row_ids: ids,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'importacoes.fila.reconciled' }), kind: 'ok' });
      setSelectedRows(new Set());
      await loadRuns();
      await loadRunRows(selectedRunId);
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setPromotingSel(false);
    }
  }
  // Écarter des lignes (doublons, hors-sujet) : décision 'reject'. Elles ne
  // seront jamais promues et apparaissent « Rejeitada » (rouge).
  async function handleRejectSelected() {
    const ids = [...selectedRows];
    if (!ids.length || !selectedRunId) return;
    setPromotingSel(true);
    setMsg({ text: t({ id: 'importacoes.fila.rejecting' }), kind: 'info' });
    try {
      const { error } = await supabase.rpc('fn_import_set_editorial', {
        p_run_id: Number(selectedRunId),
        p_row_ids: ids,
        p_editorial_decision: 'reject',
        p_editorial_note: 'page import: écarté (doublon / non pertinent)',
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'importacoes.fila.rejected' }), kind: 'ok' });
      setSelectedRows(new Set());
      await loadRunRows(selectedRunId);
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      setPromotingSel(false);
    }
  }

  // ── Supprimer un run d'import (+ son fichier) ──────────
  async function handleDeleteRun(runId) {
    if (!window.confirm(t({ id: 'importacoes.deleteRunConfirm' }, { id: runId }))) return;
    setMsg({ text: t({ id: 'importacoes.deletingRun' }), kind: 'info' });
    try {
      const { error } = await supabase.rpc('fn_import_delete_run', { p_run_id: Number(runId) });
      if (error) throw error;
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
      const { error } = await supabase.rpc('fn_import_archive_run', { p_run_id: Number(runId), p_archived: archived });
      if (error) throw error;
      setMsg({ text: t({ id: archived ? 'importacoes.runArchived' : 'importacoes.runUnarchived' }), kind: 'ok' });
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  // ── Fontes externas search (ISBN lookup via EF) ────────
  async function handleSearch() {
    if (!searchQuery.trim()) return;
    setSearching(true);
    setSearchResults([]);
    try {
      const { data } = await supabase.functions.invoke('catalog_metadata_lookup', {
        body: { isbn: searchQuery.trim() },
      });
      if (data?.candidates?.length) {
        setSearchResults(data.candidates);
        setMsg({ text: t({ id: 'importacoes.isbnResults' }, { count: data.candidates.length, isbn: searchQuery.trim() }), kind: 'ok' });
      } else {
        setMsg({ text: t({ id: 'importacoes.isbnNotFound' }), kind: 'info' });
      }
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSearching(false); }
  }

  // ── Trigger OAI harvest (manual) ────────────────────────
  async function handleHarvestOai(sourceId) {
    setMsg({ text: t({ id: 'importacoes.oai.harvesting' }), kind: 'info' });
    try {
      const { data, error } = await supabase.rpc('fn_import_harvest_oai', {
        p_source_id: Number(sourceId),
      });
      if (error) throw error;
      if (data?.note) {
        setMsg({ text: data.note, kind: 'info' });
      } else {
        setMsg({ text: t({ id: 'importacoes.oai.harvestStarted' }, { id: data?.run_id || '?' }), kind: 'ok' });
      }
      await loadOaiSources();
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  // ── Ingest candidate → staging_row (Lot 2) ────────────
  async function handleIngestCandidate(candidate) {
    setMsg({ text: t({ id: 'importacoes.fontes.importingCandidate' }), kind: 'info' });
    try {
      const { error } = await supabase.rpc('fn_import_ingest_candidate', {
        p_candidate: candidate,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'importacoes.fontes.candidateImported' }, { title: candidate.title || '—' }), kind: 'ok' });
      await loadRuns();
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  // ── Export de lote : appelle l'EF export-catalog-lote, télécharge le fichier ──
  // L'accès (coordenador de la biblio, IMP-14) est re-validé côté RPC ; un rôle
  // insuffisant renvoie 403 et le message d'erreur s'affiche.
  async function handleExportLote() {
    if (!libraryId) {
      setMsg({ text: t({ id: 'importacoes.export.lote.error' }, { message: 'library_id' }), kind: 'error' });
      return;
    }
    setExportLoading(true);
    setMsg({ text: t({ id: 'importacoes.export.lote.exporting' }), kind: 'info' });
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/export-catalog-lote`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${session?.access_token}`,
            apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ library_id: libraryId, format: exportFormat }),
        }
      );
      if (!res.ok) {
        let m = `HTTP ${res.status}`;
        try { const j = await res.json(); if (j?.error) m = j.error; } catch { /* corps non-JSON */ }
        throw new Error(m);
      }
      const blob = await res.blob();
      const cd = res.headers.get('Content-Disposition') || '';
      const match = cd.match(/filename="?([^"]+)"?/);
      const ext = exportFormat === 'marcxml' ? 'xml' : exportFormat;
      const filename = match ? match[1] : `catalogo.${ext}`;
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
      setMsg({ text: t({ id: 'importacoes.export.lote.success' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.lote.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setExportLoading(false);
    }
  }

  // ── Pill helper ────────────────────────────────────────
  function Pill({ children, variant = 'muted' }) {
    return <span className={`cat-pill ${variant}`}>{children}</span>;
  }

  // ══════════════════════════════════════════════════════════
  //  RENDER
  // ══════════════════════════════════════════════════════════
  return (
    <PageShell><Topbar />

      <Hero title={t({ id: 'importacoes.title' })} subtitle={t({ id: 'importacoes.v7.subtitle' })}>
        <UserHeroBadge />
        <HeroDocumentationActions />
      </Hero>

      <div className="imp-wrap">

        {/* ── Message bar ───────────────────────────────── */}
        {msg.text && (
          <div className={`cat-message ${msg.kind}`} style={{ marginBottom: 14 }}>
            {msg.text}
            <button onClick={() => setMsg({ text: '', kind: '' })} style={{ marginLeft: 'auto', background: 'none', border: 0, color: 'inherit', cursor: 'pointer', fontSize: '1.1rem' }}>×</button>
          </div>
        )}

        {/* ── Sentido toggle ────────────────────────────── */}
        <div className="imp-sentido">
          <span className="imp-sentido__label">{t({ id: 'importacoes.sentido.label' })}</span>
          <div className="imp-seg" role="group">
            <button className={sentido === 'import' ? 'on' : ''} onClick={() => setSentido('import')}>
              {t({ id: 'importacoes.sentido.import' })}
            </button>
            <button className={sentido === 'export' ? 'on' : ''} onClick={() => setSentido('export')}>
              {t({ id: 'importacoes.sentido.export' })}
            </button>
          </div>
          <span className="imp-sentido__hint">
            {t({ id: 'importacoes.sentido.hint' })}
          </span>
        </div>

        {/* ════════════════════════════════════════════════ */}
        {/*  FACE IMPORT                                    */}
        {/* ════════════════════════════════════════════════ */}
        {sentido === 'import' && (<>

          {/* ── Frontier banner ─────────────────────────── */}
          <div className="imp-frontier">
            <span aria-hidden="true">⇄</span>
            <div>
              <b>{t({ id: 'importacoes.import.frontier.title' })}</b>{' '}
              {t({ id: 'importacoes.import.frontier.desc' })}
            </div>
          </div>

          {/* ── CTA : assistant « Novo import » (wizard IMP-8) ─── */}
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginBottom: 14 }}>
            <button className="cat-btn secondary" type="button" onClick={handleRefresh} disabled={refreshing}>
              {refreshing ? t({ id: 'importacoes.refreshing' }) : t({ id: 'importacoes.refresh' })}
            </button>
            <Link to="/importacoes/novo" style={{ textDecoration: 'none' }}>
              <button className="cat-btn primary" type="button">
                {t({ id: 'importacoes.wizard.launch' })}
              </button>
            </Link>
          </div>

          {/* ── Adapter strip (read-only) ───────────────── */}
          <div className="imp-sheet" style={{ marginBottom: 18 }}>
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">
                {t({ id: 'importacoes.adapter.title' })}
                <Pill>{t({ id: 'importacoes.adapter.orthogonal' })}</Pill>
              </span>
            </div>
            <div className="imp-sheet__body">
              <div className="imp-row3" style={{ marginBottom: 10 }}>
                <div className="ab-field">
                  <label className="ab-field__label">{t({ id: 'importacoes.adapter.structure' })}</label>
                  <select className="ab-select" disabled>
                    <option>{t({ id: 'importacoes.adapter.autoDetect' })}</option>
                  </select>
                </div>
                <div className="ab-field">
                  <label className="ab-field__label">{t({ id: 'importacoes.adapter.vocabulary' })}</label>
                  <select className="ab-select" disabled>
                    <option>UNIMARC</option>
                  </select>
                </div>
                <div className="ab-field">
                  <label className="ab-field__label">{t({ id: 'importacoes.adapter.profile' })}</label>
                  <select className="ab-select" disabled>
                    <option>{t({ id: 'importacoes.adapter.defaultProfile' })}</option>
                  </select>
                </div>
              </div>
              <p className="imp-note" style={{ margin: 0 }}>
                {t({ id: 'importacoes.adapter.explanation' })}
              </p>
            </div>
          </div>

          {/* ── Tableau de bord ─────────────────────────── */}
          <div className="imp-sheet" style={{ marginBottom: 18 }}>
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">{t({ id: 'importacoes.dashboard.title' })}</span>
            </div>
            <div className="imp-sheet__body">
              <div className="imp-stats">
                <div className="imp-stat"><div className="imp-stat__n">{runStats.total}</div><div className="imp-stat__l">{t({ id: 'importacoes.stat.runs' })}</div></div>
                <div className="imp-stat"><div className="imp-stat__n">{runStats.totalRows}</div><div className="imp-stat__l">{t({ id: 'importacoes.stat.stagingRows' })}</div></div>
                <div className="imp-stat"><div className="imp-stat__n">{runStats.pending}</div><div className="imp-stat__l">{t({ id: 'importacoes.stat.pending' })}</div></div>
                <div className="imp-stat"><div className="imp-stat__n">{runStats.draftsCreated}</div><div className="imp-stat__l">{t({ id: 'importacoes.stat.promoted' })}</div></div>
              </div>
            </div>
          </div>

          {/* ── Adicionar registros (origine unique : fichier / busca / oai) ── */}
          <div className="imp-sheet" style={{ marginBottom: 18 }}>
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">{t({ id: 'importacoes.add.title' })}</span>
            </div>
            <div className="imp-sheet__body">
              <div className="imp-seg" role="group" style={{ marginBottom: 14 }}>
                {['arquivo', 'busca', 'oai'].map(m => (
                  <button key={m} className={addMode === m ? 'on' : ''} onClick={() => setAddMode(m)}>
                    {t({ id: 'importacoes.add.mode.' + m })}
                  </button>
                ))}
              </div>

              {/* Origine : fichier — upload unifié, toute source, via fn_import_create */}
              {addMode === 'arquivo' && (
                <>
                  <div className="imp-row3" style={{ marginBottom: 14 }}>
                    <div className="ab-field">
                      <label className="ab-field__label">{t({ id: 'importacoes.file.source' })}</label>
                      <select className="ab-select" value={sourceId} onChange={e => setSourceId(e.target.value)}>
                        <option value="">{t({ id: 'importacoes.reception.selectSourcePlaceholder' })}</option>
                        {sources.map(s => <option key={s.id} value={String(s.id)}>{s.partner_name}</option>)}
                      </select>
                    </div>
                    <div className="ab-field" style={{ gridColumn: 'span 2' }}>
                      <label className="ab-field__label">{t({ id: 'importacoes.arquivo.fileLabel' })}</label>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <label className="cat-btn secondary" style={{ cursor: 'pointer', fontSize: '.85rem' }}>
                          {t({ id: 'importacoes.reception.chooseFile' })}
                          <input type="file" accept={ACCEPTED_EXTENSIONS} onChange={e => setFile(e.target.files?.[0] || null)} style={{ display: 'none' }} />
                        </label>
                        {file && <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>{file.name} ({(file.size / 1024).toFixed(0)} KB)</span>}
                      </div>
                    </div>
                  </div>
                  <button className="cat-btn primary" onClick={handleUploadAndProcess} disabled={uploading || !file || !sourceId}>
                    {uploading ? t({ id: 'importacoes.uploading' }) : t({ id: 'importacoes.arquivo.uploadAndProcess' })}
                  </button>
                </>
              )}

              {/* Origine : recherche externe (BN / WorldCat) */}
              {addMode === 'busca' && (
                <>
                  <div className="imp-row3" style={{ marginBottom: 12 }}>
                    <div className="ab-field">
                      <label className="ab-field__label">{t({ id: 'importacoes.fontes.sourceLabel' })}</label>
                      <select className="ab-select" value={searchSource} onChange={e => setSearchSource(e.target.value)}>
                        <option value="bn">Biblioteca Nacional</option>
                        <option value="worldcat">WorldCat / OCLC</option>
                      </select>
                    </div>
                    <div className="ab-field" style={{ gridColumn: 'span 2' }}>
                      <label className="ab-field__label">{t({ id: 'importacoes.fontes.searchLabel' })}</label>
                      <div style={{ display: 'flex', gap: 8 }}>
                        <input className="ab-input" value={searchQuery} onChange={e => setSearchQuery(e.target.value)}
                          placeholder="9788575591360"
                          onKeyDown={e => { if (e.key === 'Enter') handleSearch(); }} />
                        <button className="cat-btn primary" onClick={handleSearch} disabled={searching} style={{ flexShrink: 0 }}>
                          {searching ? t({ id: 'common.searching' }) : t({ id: 'importacoes.fontes.search' })}
                        </button>
                      </div>
                    </div>
                  </div>
                  {searchResults.length > 0 && (
                    <table className="imp-map">
                      <thead><tr>
                        <th>{t({ id: 'importacoes.fontes.result' })}</th>
                        <th>{t({ id: 'importacoes.fontes.author' })}</th>
                        <th>{t({ id: 'importacoes.fontes.format' })}</th>
                        <th></th>
                      </tr></thead>
                      <tbody>
                        {searchResults.map((c, i) => (
                          <tr key={i}>
                            <td style={{ fontWeight: 600 }}>{c.title}</td>
                            <td style={{ color: 'var(--brand-muted)' }}>{c.responsibility_statement || c.contributors?.[0]?.label || '—'}</td>
                            <td><Pill>{c.source || '—'}</Pill></td>
                            <td>
                              <button className="cat-btn primary" style={{ fontSize: '.78rem', padding: '4px 10px', minHeight: 0 }}
                                onClick={() => handleIngestCandidate(c)}>
                                {t({ id: 'importacoes.fontes.importCandidate' })}
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </>
              )}

              {/* Origine : moisson OAI-PMH */}
              {addMode === 'oai' && (
                <>
                  <p className="imp-note" style={{ marginBottom: 12 }}>{t({ id: 'importacoes.oai.desc' })}</p>
                  {oaiLoading && <p className="imp-note">{t({ id: 'common.loading' })}</p>}
                  {!oaiLoading && oaiSources.length === 0 && (
                    <p className="imp-note">{t({ id: 'importacoes.oai.noSources' })}</p>
                  )}
                  {oaiSources.length > 0 && (
                    <div className="imp-partners">
                      {oaiSources.map(s => (
                        <div key={s.id} className="imp-pcard">
                          <div className="imp-pcard__top">
                            <h4>{s.partner_name}</h4>
                            <Pill variant={s.harvest_status === 'idle' ? 'muted' : s.harvest_status === 'in_progress' ? 'info' : s.harvest_status === 'error' ? 'danger' : s.harvest_status === 'completed' ? 'ok' : 'warn'}>
                              {t({ id: `importacoes.oai.status.${s.harvest_status || 'idle'}` })}
                            </Pill>
                          </div>
                          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginBottom: 6 }}>
                            {s.oai_endpoint_url}
                            {s.oai_set && <span> — set: {s.oai_set}</span>}
                          </div>
                          <div className="imp-flags" style={{ marginBottom: 8 }}>
                            <span className="imp-flagchip imp-flagchip--on">{s.oai_metadata_prefix || 'marcxml'}</span>
                            <span className="imp-flagchip">{t({ id: 'importacoes.oai.lotsPerCycle' }, { n: s.lots_per_cycle || 5 })}</span>
                            {s.total_records_harvested > 0 && (
                              <span className="imp-flagchip imp-flagchip--on">{t({ id: 'importacoes.oai.totalHarvested' }, { n: s.total_records_harvested })}</span>
                            )}
                            {s.last_harvest_at && (
                              <span className="imp-flagchip">{t({ id: 'importacoes.oai.lastHarvest' })} {formatDate(s.last_harvest_at)}</span>
                            )}
                          </div>
                          {s.last_error && (
                            <p style={{ fontSize: '.8rem', color: 'var(--color-danger)', margin: '0 0 8px' }}>{s.last_error}</p>
                          )}
                          <button className="cat-btn primary" style={{ fontSize: '.82rem', padding: '5px 14px', minHeight: 0 }}
                            onClick={() => handleHarvestOai(s.id)}
                            disabled={s.harvest_status === 'in_progress'}>
                            {s.harvest_status === 'in_progress' ? t({ id: 'importacoes.oai.harvesting' }) : t({ id: 'importacoes.oai.harvestNow' })}
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </>
              )}
            </div>
          </div>

          {/* ── Lotes de importação (liste unique : archiver / supprimer) ── */}
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
                      style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '8px 10px', cursor: 'pointer', borderBottom: '1px solid rgba(255,255,255,.04)', background: selectedRunId === r.id ? 'rgba(29,78,216,.12)' : 'transparent', opacity: r.archived_at ? 0.5 : 1 }}>
                      <div>
                        <span style={{ fontWeight: 600, fontSize: '.88rem' }}>#{r.id}</span>
                        <span style={{ color: 'var(--brand-muted)', fontSize: '.82rem', marginLeft: 8 }}>{r.source_name || r.original_filename || '—'}</span>
                      </div>
                      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                        <Pill variant={r.run_status === 'drafts_created' ? 'ok' : r.run_status === 'failed' ? 'danger' : r.run_status === 'ready_for_review' ? 'warn' : 'info'}>
                          {STATUS[r.run_status] || r.run_status}
                        </Pill>
                        <button className="cat-btn ghost" title={t({ id: r.archived_at ? 'importacoes.unarchiveRun' : 'importacoes.archiveRun' })}
                          style={{ fontSize: '.9rem', padding: '4px 8px', minHeight: 0 }}
                          onClick={e => { e.stopPropagation(); handleArchiveRun(r.id, !r.archived_at); }}>
                          {r.archived_at ? '↩' : '🗄'}
                        </button>
                        <button className="cat-btn ghost" title={t({ id: 'importacoes.deleteRun' })}
                          style={{ fontSize: '.9rem', padding: '4px 8px', minHeight: 0 }}
                          onClick={e => { e.stopPropagation(); handleDeleteRun(r.id); }}>
                          🗑
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* ── Fontes parceiras (référence : qui autorise l'import) ── */}
          {sources.filter(s => s.source_kind !== 'institutional').length > 0 && (
            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">
                  {t({ id: 'importacoes.fontes.companheiras' })}
                  <Pill>{t({ id: 'importacoes.fontes.consentFirst' })}</Pill>
                </span>
              </div>
              <div className="imp-sheet__body">
                <div className="imp-partners">
                  {sources.filter(s => s.source_kind !== 'institutional').map(s => (
                    <div key={s.id} className="imp-pcard">
                      <div className="imp-pcard__top">
                        <h4>{s.partner_name}</h4>
                        <span className="imp-rel-badge">{s.relation_status || '—'}</span>
                      </div>
                      <div className="imp-flags">
                        <span className={`imp-flagchip ${s.import_enabled ? 'imp-flagchip--on' : 'imp-flagchip--off'}`}>
                          {t({ id: 'importacoes.fontes.flag.import' })}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* ── Fila de revisão ───────────────────────────── */}
          <div className="imp-sheet">
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">
                {t({ id: 'importacoes.fila.title' })}
              </span>
            </div>
            <div className="imp-sheet__body">
              {/* Filters */}
              <div className="imp-filters">
                <span className="imp-filters__label">{t({ id: 'importacoes.fila.filter' })}</span>
                <select className="ab-select" style={{ width: 'auto' }} value={filaSourceFilter} onChange={e => {
                  setFilaSourceFilter(e.target.value);
                  if (e.target.value) {
                    const run = runs.find(r => String(r.source_id) === e.target.value);
                    if (run && run.id !== selectedRunId) { setSelectedRunId(run.id); loadRunRows(run.id); }
                  }
                }}>
                  <option value="">{t({ id: 'importacoes.fila.allSources' })}</option>
                  {sources.map(s => <option key={s.id} value={String(s.id)}>{s.partner_name}</option>)}
                </select>
                <select className="ab-select" style={{ width: 'auto' }} value={filaStateFilter} onChange={e => setFilaStateFilter(e.target.value)}>
                  <option value="">{t({ id: 'importacoes.fila.allStates' })}</option>
                  <option value="pending">{t({ id: 'importacoes.fila.state.pending' })}</option>
                  <option value="approved">{t({ id: 'importacoes.fila.state.approved' })}</option>
                  <option value="rejected">{t({ id: 'importacoes.fila.state.rejected' })}</option>
                </select>
                <select className="ab-select" style={{ width: 'auto' }} value={filaMatchFilter} onChange={e => setFilaMatchFilter(e.target.value)}>
                  <option value="">{t({ id: 'importacoes.fila.allMatches' })}</option>
                  <option value="new">{t({ id: 'importacoes.fila.filterNew' })}</option>
                  <option value="dup">{t({ id: 'importacoes.fila.filterDup' })}</option>
                </select>
              </div>

              {/* Run selector */}
              {!selectedRunId && runs.length > 0 && (
                <p className="imp-note" style={{ marginBottom: 12 }}>
                  {t({ id: 'importacoes.fila.selectRun' })}
                </p>
              )}
              {!selectedRunId && runs.length > 0 && (
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 12 }}>
                  {runs.slice(0, 8).map(r => (
                    <button key={r.id} className="cat-btn secondary" style={{ fontSize: '.82rem', padding: '6px 12px' }}
                      onClick={() => { setSelectedRunId(r.id); loadRunRows(r.id); }}>
                      #{r.id} — {r.source_name || r.original_filename || '—'}
                    </button>
                  ))}
                </div>
              )}

              {/* Barrière : import en cours de traitement (parse + matching) */}
              {selectedRunId && runProcessing && (
                <div className="imp-sheet" style={{ textAlign: 'center', padding: '28px 20px' }}>
                  <div style={{ fontSize: '1.6rem', marginBottom: 8 }}>⏳</div>
                  <p style={{ fontWeight: 600, margin: '0 0 6px' }}>{t({ id: 'importacoes.fila.processing.title' })}</p>
                  <p className="imp-note" style={{ maxWidth: 520, margin: '0 auto 14px' }}>{t({ id: 'importacoes.fila.processing.desc' })}</p>
                  <button className="cat-btn secondary" disabled={refreshing} onClick={handleRefresh}>
                    {refreshing ? t({ id: 'importacoes.refreshing' }) : t({ id: 'importacoes.refresh' })}
                  </button>
                </div>
              )}

              {/* Barrière : import échoué */}
              {selectedRunId && runFailed && (
                <div className="imp-sheet" style={{ textAlign: 'center', padding: '28px 20px' }}>
                  <div style={{ fontSize: '1.6rem', marginBottom: 8 }}>⚠️</div>
                  <p style={{ fontWeight: 600, margin: '0 0 6px' }}>{t({ id: 'importacoes.fila.failed.title' })}</p>
                  <p className="imp-note" style={{ maxWidth: 520, margin: '0 auto' }}>{t({ id: 'importacoes.fila.failed.desc' })}</p>
                </div>
              )}

              {/* Rows table (uniquement si traitement terminé) */}
              {selectedRunId && !runProcessing && !runFailed && (
                <div style={{ overflowX: 'auto' }}>
                  {runRowsLoading && <p className="imp-note">{t({ id: 'importacoes.loadingRows' })}</p>}
                  {!runRowsLoading && filteredRunRows.length === 0 && <p className="imp-note">{t({ id: 'importacoes.noRowsAvailable' })}</p>}
                  {selectedRows.size > 0 && (
                    <div className="imp-batchbar" style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '4px 0 12px', padding: '8px 12px', background: 'var(--brand-surface-2, rgba(0,0,0,.04))', borderRadius: 8, flexWrap: 'wrap' }}>
                      <span className="imp-note">{t({ id: 'importacoes.fila.selectedCount' }, { n: selectedRows.size })}</span>
                      <button className="cat-btn" disabled={promotingSel || selectedNewCount === 0} onClick={handlePromoteSelected}>
                        {promotingSel ? t({ id: 'importacoes.generatingDrafts' }) : t({ id: 'importacoes.fila.createSelected' }, { n: selectedNewCount })}
                      </button>
                      <button className="cat-btn" disabled={promotingSel || selectedDupCount === 0} onClick={handleReconcileSelected}>
                        {t({ id: 'importacoes.fila.reconcile' }, { n: selectedDupCount })}
                      </button>
                      <button className="cat-btn secondary" disabled={promotingSel} onClick={handleRejectSelected}
                        style={{ borderColor: 'var(--brand-danger, #b42318)', color: 'var(--brand-danger, #b42318)' }}>
                        {t({ id: 'importacoes.fila.reject' }, { n: selectedRows.size })}
                      </button>
                      <button className="cat-btn secondary" disabled={promotingSel} onClick={() => setSelectedRows(new Set())}>
                        {t({ id: 'importacoes.fila.clearSelection' })}
                      </button>
                    </div>
                  )}
                  {filteredRunRows.length > 0 && (
                    <table className="imp-queue">
                      <thead>
                        <tr>
                          <th style={{ width: 28 }}>
                            <input type="checkbox" aria-label={t({ id: 'importacoes.fila.selectAll' })}
                              checked={allVisibleSelected} disabled={selectableIds.length === 0}
                              onChange={toggleAllVisible} />
                          </th>
                          <th>{t({ id: 'importacoes.fila.col.record' })}</th>
                          <th>{t({ id: 'importacoes.fila.col.source' })}</th>
                          <th>{t({ id: 'importacoes.fila.col.match' })}</th>
                          <th className="imp-hide-sm">{t({ id: 'importacoes.fila.col.decision' })}</th>
                          <th>{t({ id: 'importacoes.fila.col.state' })}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {filteredRunRows.slice(0, rowLimit).map(row => {
                          const ms = row.match_status || 'unreviewed';
                          const isNew = ms === 'new_record';
                          const isMatched = ms === 'matched_book' || ms === 'matched_draft';
                          const isDup = ms === 'possible_duplicate' || isMatched;
                          const ed = row.editorial_decision || 'pending';
                          // Sélectionnable : pas encore promue ET décision en attente.
                          const reviewable = !row.created_book_draft_id && !row.created_exemplar_draft_id && ed === 'pending';
                          return (
                            <tr key={row.id} style={ed === 'reject' ? { opacity: 0.55 } : undefined}>
                              <td>
                                {reviewable && (
                                  <input type="checkbox" checked={selectedRows.has(row.id)}
                                    onChange={() => toggleRow(row.id)} />
                                )}
                              </td>
                              <td>
                                <div className="ttl">{row.title || t({ id: 'importacoes.noTitle' })}</div>
                                <div className="au">{row.responsibility_statement || '—'}</div>
                              </td>
                              <td><Pill>{runs.find(r => r.id === row.run_id)?.source_name || '—'}</Pill></td>
                              <td>
                                <Pill variant={isNew ? 'ok' : isMatched ? 'info' : isDup ? 'warn' : 'muted'}>
                                  {t({ id: 'importacoes.fila.match.' + ms })}
                                </Pill>
                                {Number(row.confidence) > 0 && (
                                  <span style={{ marginLeft: 6, fontSize: '.72rem', fontWeight: 700, color: 'var(--brand-muted, #94a3b8)' }}>
                                    {Math.round(Number(row.confidence))}%
                                  </span>
                                )}
                                {isDup && (
                                  <div className="imp-note" style={{ marginTop: 3, fontSize: '.72rem' }}>
                                    {row.proposed_title
                                      ? t({ id: 'importacoes.fila.matchAgainst' }, { title: row.proposed_title })
                                      : t({ id: 'importacoes.fila.matchVerify' })}
                                  </div>
                                )}
                              </td>
                              <td className="imp-hide-sm">
                                <Pill variant={ed === 'accept_new' || ed === 'accept_duplicate' ? 'ok' : ed === 'reject' ? 'danger' : 'muted'}>
                                  {t({ id: 'importacoes.fila.decision.' + ed })}
                                </Pill>
                              </td>
                              <td>
                                {row.created_book_draft_id
                                  ? <Pill variant="ok">{t({ id: 'importacoes.fila.draftCreated' })}</Pill>
                                  : row.created_exemplar_draft_id
                                  ? <Pill variant="ok">{t({ id: 'importacoes.fila.exemplarCreated' })}</Pill>
                                  : <Pill>{t({ id: 'importacoes.fila.inQueue' })}</Pill>}
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  )}
                  {filteredRunRows.length > rowLimit && (
                    <div style={{ marginTop: 10, textAlign: 'center' }}>
                      <button className="cat-btn secondary" onClick={() => setRowLimit(rowLimit + 50)}>
                        {t({ id: 'importacoes.fila.loadMore' })}
                      </button>
                      <p className="imp-note" style={{ marginTop: 6 }}>
                        {t({ id: 'importacoes.fila.showing' }, { shown: Math.min(rowLimit, filteredRunRows.length), total: filteredRunRows.length })}
                      </p>
                    </div>
                  )}
                  {filteredRunRows.length > 50 && filteredRunRows.length <= rowLimit && (
                    <p className="imp-note" style={{ marginTop: 8 }}>
                      {t({ id: 'importacoes.fila.showingAll' }, { total: filteredRunRows.length })}
                    </p>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* ── Diário de importação ──────────────────────── */}
          <div className="imp-sheet">
            <div className="imp-sheet__head">
              <span className="imp-sheet__title">
                {t({ id: 'importacoes.diario.title' })}
              </span>
            </div>
            <div className="imp-sheet__body">
              {runs.length === 0 && <p className="imp-note">{t({ id: 'importacoes.history.empty' })}</p>}
              <ul className="imp-timeline">
                {runs.slice(0, 10).map(r => (
                  <li key={r.id}>
                    <span className="imp-timeline__when">{formatDate(r.created_at)}</span>
                    <div className="imp-timeline__ev">
                      <b>{r.run_status === 'drafts_created' ? t({ id: 'importacoes.diario.promoted' }) : t({ id: 'importacoes.diario.runCreated' })}</b>
                      {' — '}{r.original_filename || t({ id: 'importacoes.noFile' })}
                      {r.source_name && ` (${r.source_name})`}
                      <div className="imp-timeline__meta">
                        <Pill>{r.detected_format || '—'}</Pill>
                        {r.imported_rows != null && <Pill>{t({ id: 'importacoes.rowsCount' }, { count: r.imported_rows })}</Pill>}
                        {r.created_drafts != null && r.created_drafts > 0 && <Pill variant="ok">{t({ id: 'importacoes.draftsCount' }, { count: r.created_drafts })}</Pill>}
                      </div>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          </div>

        </>)}

        {/* ════════════════════════════════════════════════ */}
        {/*  FACE EXPORT (placeholder — Lot 5)              */}
        {/* ════════════════════════════════════════════════ */}
        {sentido === 'export' && (
          <>
            <div className="imp-frontier imp-frontier--export">
              <span aria-hidden="true">⇄</span>
              <div>
                <b>{t({ id: 'importacoes.export.frontier.title' })}</b>{' '}
                {t({ id: 'importacoes.export.frontier.desc' })}
              </div>
            </div>

            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.partilha.title' })}<Pill>ILL-1..9</Pill></span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.partilha.desc' })}</p>
              </div>
            </div>

            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.lote.title' })}<Pill variant="ok">CSV · MARCXML · JSON</Pill></span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.lote.desc' })}</p>
                <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
                  <select
                    className="ab-select"
                    aria-label={t({ id: 'importacoes.export.lote.format' })}
                    value={exportFormat}
                    onChange={(e) => setExportFormat(e.target.value)}
                    disabled={exportLoading}
                    style={{ maxWidth: 240 }}
                  >
                    <option value="csv">CSV</option>
                    <option value="marcxml">MARCXML (MARC21)</option>
                    <option value="json">JSON</option>
                  </select>
                  <button
                    className="cat-btn primary"
                    onClick={handleExportLote}
                    disabled={exportLoading || !libraryId}
                  >
                    {exportLoading ? t({ id: 'importacoes.export.lote.exporting' }) : t({ id: 'importacoes.export.lote.download' })}
                  </button>
                </div>
              </div>
            </div>

            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.serFonte.title' })}</span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.serFonte.desc' })}</p>
              </div>
            </div>
          </>
        )}

      </div>
    <Footer /></PageShell>
  );
}
