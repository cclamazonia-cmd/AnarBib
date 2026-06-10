import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import './ImportacoesPage.css';

// =============================================================================
// ImportWizard — assistant « Novo import » (IMP-8).
// =============================================================================
// Route /importacoes/novo, coordenador-only (IMP-14). Stepper lineaire qui
// RE-DERIVE le flux de la page v7 (IMP-15) : ne fait que cabler les RPC
// fn_import_* existants. Ecriture book_drafts UNIQUEMENT a l'etape finale.
//
// Increments : 1 = coquille + Circuit ; 2 (ici) = Source (arquivo/migracao =
// upload ; fontes = lookup ISBN) -> produit un runId. 3 (a venir) = Pre-vis +
// Promocao. Mapping differe (IMP-10) -> 4 etapes.
// =============================================================================

const BUCKET = 'catalogos_parceiros_raw';
const CIRCUITS = ['migracao', 'arquivo', 'fontes'];
const STEPS = [
  { n: 1, key: 'circuit' },
  { n: 2, key: 'source' },
  { n: 3, key: 'preview' },
  { n: 4, key: 'promote' },
];

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

export default function ImportWizard() {
  const { role, isNetworkAdmin } = useLibrary();
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'importacoes.wizard.title' }));

  const canImport = role === 'coordenador' || role === 'administrador' || isNetworkAdmin;

  const [step, setStep] = useState(1);
  const [circuit, setCircuit] = useState(null);
  const [runId, setRunId] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [busy, setBusy] = useState(false);

  // arquivo / migração
  const [sources, setSources] = useState([]);
  const [sourceId, setSourceId] = useState('');
  const [file, setFile] = useState(null);
  // fontes
  const [isbn, setIsbn] = useState('');
  const [candidates, setCandidates] = useState([]);

  const loadSources = useCallback(async () => {
    try {
      const { data, error } = await supabase.rpc('fn_import_list_sources');
      if (!error && data) setSources(data);
    } catch { /* guard */ }
  }, []);

  // Charge les sources en entrant à l'étape 2 des circuits à fichier.
  useEffect(() => {
    if (step === 2 && (circuit === 'arquivo' || circuit === 'migracao')) loadSources();
  }, [step, circuit, loadSources]);

  if (!canImport) {
    return (
      <PageShell>
        <Topbar />
        <Hero title={t({ id: 'importacoes.wizard.title' })} subtitle={t({ id: 'importacoes.restricted' })} />
        <Footer />
      </PageShell>
    );
  }

  // ── Handlers ──────────────────────────────────────────────
  async function handleUpload() {
    if (!sourceId) { setMsg({ text: t({ id: 'importacoes.selectSource' }), kind: 'error' }); return; }
    if (!file) { setMsg({ text: t({ id: 'importacoes.selectFile' }), kind: 'error' }); return; }
    setBusy(true);
    setMsg({ text: t({ id: 'importacoes.wizard.source.importing' }), kind: 'info' });
    try {
      const safe = (file.name || 'file').replace(/[^a-zA-Z0-9._-]/g, '_');
      const path = `partner/manual/import/${new Date().toISOString().slice(0, 10)}/${Date.now()}-${safe}`;
      const { error: upErr } = await supabase.storage.from(BUCKET).upload(path, file, { upsert: true });
      if (upErr) throw upErr;
      const { data: created, error: createErr } = await supabase.rpc('fn_import_create', {
        p_source_id: Number(sourceId),
        p_storage_path: path,
        p_original_filename: file.name,
        p_bucket_id: BUCKET,
        p_mime_type: file.type || 'application/octet-stream',
        p_size_bytes: file.size,
        p_detected_format: detectFileKind(file.name),
      });
      if (createErr) throw createErr;
      const newRunId = created?.run_id;
      if (!newRunId) throw new Error(t({ id: 'importacoes.noRunId' }));
      await supabase.rpc('fn_import_dispatch', { p_run_id: Number(newRunId) });
      setRunId(Number(newRunId));
      setMsg({ text: t({ id: 'importacoes.wizard.source.ready' }, { id: newRunId }), kind: 'ok' });
      setStep(3);
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setBusy(false); }
  }

  async function handleSearch() {
    if (!isbn.trim()) return;
    setBusy(true);
    setCandidates([]);
    setMsg({ text: '', kind: '' });
    try {
      const { data } = await supabase.functions.invoke('catalog_metadata_lookup', { body: { isbn: isbn.trim() } });
      if (data?.candidates?.length) {
        setCandidates(data.candidates);
        setMsg({ text: t({ id: 'importacoes.isbnResults' }, { count: data.candidates.length, isbn: isbn.trim() }), kind: 'ok' });
      } else {
        setMsg({ text: t({ id: 'importacoes.isbnNotFound' }), kind: 'info' });
      }
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setBusy(false); }
  }

  async function handleIngest(candidate) {
    setBusy(true);
    setMsg({ text: t({ id: 'importacoes.fontes.importingCandidate' }), kind: 'info' });
    try {
      const { data, error } = await supabase.rpc('fn_import_ingest_candidate', { p_candidate: candidate });
      if (error) throw error;
      let newRunId = data?.run_id;
      if (!newRunId) {
        // Repli : le run le plus récent de la biblio.
        const { data: runs } = await supabase.rpc('fn_import_list_runs');
        newRunId = Array.isArray(runs) && runs.length ? runs[0].id : null;
      }
      if (!newRunId) throw new Error(t({ id: 'importacoes.noRunId' }));
      setRunId(Number(newRunId));
      setMsg({ text: t({ id: 'importacoes.wizard.source.ingested' }), kind: 'ok' });
      setStep(3);
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setBusy(false); }
  }

  // ── Rendu ─────────────────────────────────────────────────
  const cardBtn = (selected) => ({
    textAlign: 'left', cursor: 'pointer', width: '100%',
    padding: '14px 16px', borderRadius: 10, color: 'inherit',
    background: selected ? 'rgba(248,113,113,.08)' : 'rgba(255,255,255,.03)',
    border: '1px solid ' + (selected ? 'var(--brand-accent, #f87171)' : 'rgba(255,255,255,.12)'),
    transition: 'all .15s ease',
  });

  function renderStepper() {
    return (
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', margin: '18px 0 22px' }}>
        {STEPS.map((s) => {
          const active = step === s.n;
          const done = step > s.n;
          return (
            <div key={s.n} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '7px 14px', borderRadius: 999,
              fontSize: '.85rem', fontWeight: active ? 700 : 500,
              background: active ? 'var(--brand-accent, #f87171)' : 'rgba(255,255,255,.06)',
              color: active ? '#fff' : (done ? 'var(--brand-fg, #e8e2d6)' : 'var(--brand-muted, #9a948a)'),
              border: '1px solid ' + (active ? 'transparent' : 'rgba(255,255,255,.10)'),
            }}>
              <span style={{
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                width: 22, height: 22, borderRadius: '50%', fontSize: '.78rem', fontWeight: 700,
                background: active ? 'rgba(0,0,0,.25)' : 'rgba(255,255,255,.10)',
              }}>{done ? '✓' : s.n}</span>
              {t({ id: `importacoes.wizard.step.${s.key}` })}
            </div>
          );
        })}
      </div>
    );
  }

  function renderCircuit() {
    return (
      <div className="imp-sheet">
        <div className="imp-sheet__head">
          <span className="imp-sheet__title">{t({ id: 'importacoes.wizard.step.circuit' })}</span>
        </div>
        <div className="imp-sheet__body" style={{ display: 'grid', gap: 10 }}>
          {CIRCUITS.map((c) => (
            <button key={c} type="button" onClick={() => setCircuit(c)} style={cardBtn(circuit === c)}>
              <strong style={{ display: 'block', marginBottom: 4 }}>{t({ id: `importacoes.wizard.circuit.${c}` })}</strong>
              <span className="imp-note">{t({ id: `importacoes.circuit.${c}.hint` })}</span>
            </button>
          ))}
        </div>
      </div>
    );
  }

  function renderSource() {
    const isFile = circuit === 'arquivo' || circuit === 'migracao';
    return (
      <div className="imp-sheet">
        <div className="imp-sheet__head">
          <span className="imp-sheet__title">
            {t({ id: isFile ? 'importacoes.wizard.source.uploadTitle' : 'importacoes.wizard.source.fontesTitle' })}
          </span>
        </div>
        <div className="imp-sheet__body" style={{ display: 'grid', gap: 12 }}>
          {isFile ? (
            <>
              <label style={{ display: 'grid', gap: 6 }}>
                <span className="imp-note">{t({ id: 'importacoes.wizard.source.sourceLabel' })}</span>
                <select className="ab-select" value={sourceId} onChange={(e) => setSourceId(e.target.value)} disabled={busy}>
                  <option value="">—</option>
                  {sources.map((s) => (
                    <option key={s.id} value={s.id}>{s.partner_name || `#${s.id}`}</option>
                  ))}
                </select>
                {sources.length === 0 && <span className="imp-note">{t({ id: 'importacoes.wizard.source.noSources' })}</span>}
              </label>
              <label style={{ display: 'grid', gap: 6 }}>
                <span className="imp-note">{t({ id: 'importacoes.wizard.source.fileLabel' })}</span>
                <input type="file" accept=".csv,.tsv,.txt,.ris,.bib,.bibtex,.mrc,.marc,.marcxml,.xml,.json" onChange={(e) => setFile(e.target.files?.[0] || null)} disabled={busy} />
              </label>
              <div>
                <button className="cat-btn primary" type="button" onClick={handleUpload} disabled={busy || !file || !sourceId}>
                  {busy ? t({ id: 'importacoes.wizard.source.importing' }) : t({ id: 'importacoes.wizard.source.import' })}
                </button>
              </div>
            </>
          ) : (
            <>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <input className="ab-input" value={isbn} onChange={(e) => setIsbn(e.target.value)} placeholder={t({ id: 'importacoes.wizard.source.isbnLabel' })} disabled={busy} style={{ minWidth: 200 }} />
                <button className="cat-btn primary" type="button" onClick={handleSearch} disabled={busy || !isbn.trim()}>
                  {t({ id: 'importacoes.wizard.source.search' })}
                </button>
              </div>
              {candidates.map((cand, i) => (
                <div key={i} style={cardBtn(false)}>
                  <strong style={{ display: 'block' }}>{cand.title || '—'}</strong>
                  <span className="imp-note">{[cand.author, cand.publisher, cand.year].filter(Boolean).join(' · ')}</span>
                  <div style={{ marginTop: 8 }}>
                    <button className="cat-btn secondary" type="button" onClick={() => handleIngest(cand)} disabled={busy}>
                      {t({ id: 'importacoes.wizard.source.ingest' })}
                    </button>
                  </div>
                </div>
              ))}
            </>
          )}
        </div>
      </div>
    );
  }

  function renderWip(stepKey) {
    return (
      <div className="imp-sheet">
        <div className="imp-sheet__head">
          <span className="imp-sheet__title">{t({ id: `importacoes.wizard.step.${stepKey}` })}</span>
        </div>
        <div className="imp-sheet__body">
          <p className="imp-note">{t({ id: 'importacoes.wizard.wip' })}</p>
        </div>
      </div>
    );
  }

  const canNext = step === 1 ? !!circuit : (step === 2 ? !!runId : step < 4);

  return (
    <PageShell>
      <Topbar />
      <div className="imp-shell" style={{ maxWidth: 880, margin: '0 auto', padding: '0 16px 40px' }}>
        <nav style={{ fontSize: '.85rem', color: 'var(--brand-muted, #9a948a)', margin: '20px 0 0' }}>
          <Link to="/importacoes" style={{ color: 'inherit' }}>{t({ id: 'importacoes.title' })}</Link>
          <span style={{ margin: '0 8px' }}>›</span>
          <span style={{ color: 'var(--brand-fg, #e8e2d6)' }}>{t({ id: 'importacoes.wizard.title' })}</span>
        </nav>

        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, margin: '8px 0 0', fontFamily: 'var(--brand-font-body)' }}>
          {t({ id: 'importacoes.wizard.title' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', margin: '4px 0 0', fontSize: '.9rem' }}>
          {t({ id: 'importacoes.wizard.subtitle' })}
        </p>

        {renderStepper()}

        {msg.text && (
          <div style={{
            padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 14,
            background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'error' ? 'rgba(220,38,38,.12)' : 'rgba(255,255,255,.05)',
            color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'error' ? '#f87171' : 'var(--brand-fg, #e8e2d6)',
            border: '1px solid ' + (msg.kind === 'ok' ? 'rgba(21,128,61,.25)' : msg.kind === 'error' ? 'rgba(220,38,38,.25)' : 'rgba(255,255,255,.10)'),
          }}>{msg.text}</div>
        )}

        {step === 1 && renderCircuit()}
        {step === 2 && renderSource()}
        {step === 3 && renderWip('preview')}
        {step === 4 && renderWip('promote')}

        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 22 }}>
          <button className="cat-btn secondary" type="button" disabled={step === 1 || busy} onClick={() => setStep((s) => Math.max(1, s - 1))}>
            {t({ id: 'importacoes.wizard.back' })}
          </button>
          <button className="cat-btn primary" type="button" disabled={!canNext || busy} onClick={() => setStep((s) => Math.min(4, s + 1))}>
            {t({ id: 'importacoes.wizard.next' })}
          </button>
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
