import { useState, useEffect, useCallback, useRef } from 'react';
import { Button, Spinner } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { generateMultiReportPdf } from '@/lib/reportPdf';
import CardScanner from './CardScanner';

// ═══════════════════════════════════════════════════════════
// TabRecolement — aide au récolement (inventaire du fonds par scan)
// ───────────────────────────────────────────────────────────
// MOBILE Paquet 4, option B (sessions persistées). On démarre (ou reprend)
// une session, on enchaîne le scan des étiquettes QR d'exemplaires (mode
// `continuous` du CardScanner), un compteur suit la progression, puis on
// clôture pour obtenir le rapport présents / manquants / intrus, exportable
// en CSV et PDF.
//
// L'étiquette QR encode une URL `…/livro/<book_id>?ex=<exemplar_id>`
// (cf. LabelSheetPrinter) → on en extrait l'`exemplar_id` (bigint). Toute la
// logique sensible (qualité staff, appartenance biblio, idempotence,
// présents/manquants/intrus) est côté serveur : 4 RPC SECDEF staff-gated
// (recolement_start / scan / finish / open_sessions). Le front ne fait
// qu'orchestrer + présenter.
// ═══════════════════════════════════════════════════════════

// Extrait l'exemplar_id d'un QR d'étiquette (URL avec ?ex=) ou d'une saisie
// manuelle (nombre brut). null si rien d'exploitable.
function parseExemplarId(raw) {
  if (!raw) return null;
  const s = String(raw).trim();
  const m = s.match(/[?&]ex=(\d+)/);
  if (m) return Number(m[1]);
  if (/^\d+$/.test(s)) return Number(s);
  return null;
}

export default function TabRecolement({ t, locale, libraryId, libraryName }) {
  const [phase, setPhase] = useState('idle');     // idle | scanning | report
  const [sessionId, setSessionId] = useState(null);
  const [acervoCount, setAcervoCount] = useState(0);
  const [scannedCount, setScannedCount] = useState(0);
  const [lastScan, setLastScan] = useState(null);  // { kind, title, tombo, id }
  const [openSessions, setOpenSessions] = useState([]);
  const [report, setReport] = useState(null);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState('');
  const [scanning, setScanning] = useState(false);
  const [manual, setManual] = useState('');

  // Bip de confirmation (AudioContext réutilisé, créé au 1er geste = "Démarrer").
  const audioRef = useRef(null);
  const beep = useCallback((ok) => {
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      if (!audioRef.current) audioRef.current = new Ctx();
      const ctx = audioRef.current;
      const o = ctx.createOscillator();
      const g = ctx.createGain();
      o.connect(g); g.connect(ctx.destination);
      o.frequency.value = ok ? 880 : 320;
      g.gain.value = 0.05;
      o.start();
      o.stop(ctx.currentTime + (ok ? 0.09 : 0.22));
    } catch { /* audio indisponible : silencieux */ }
  }, []);

  const reasonMsg = useCallback((reason) => {
    const key = `recolement.error.${reason || 'generic'}`;
    return t({ id: key, defaultMessage: t({ id: 'recolement.error.generic' }) });
  }, [t]);

  // Sessions ouvertes (reprise) au montage / changement de biblio.
  const loadOpen = useCallback(async () => {
    if (!libraryId) return;
    try {
      const { data, error } = await supabase.schema('api').rpc('recolement_open_sessions', { p_library_id: libraryId });
      if (!error && data?.ok) setOpenSessions(data.sessions || []);
    } catch { /* silencieux : la reprise est un bonus */ }
  }, [libraryId]);

  useEffect(() => { loadOpen(); }, [loadOpen]);

  const start = async () => {
    if (!libraryId || busy) return;
    setBusy(true); setMsg('');
    try {
      const { data, error } = await supabase.schema('api').rpc('recolement_start', { p_library_id: libraryId });
      if (error || !data?.ok) { setMsg(reasonMsg(data?.reason)); return; }
      setSessionId(data.session_id);
      setAcervoCount(data.acervo_count || 0);
      setScannedCount(0);
      setLastScan(null);
      setReport(null);
      setPhase('scanning');
      setScanning(true);
    } catch { setMsg(reasonMsg()); }
    finally { setBusy(false); }
  };

  const resume = async (s) => {
    setSessionId(s.session_id);
    setAcervoCount(0); // recalculé au finish ; on n'affiche que le compteur scanné en reprise
    setScannedCount(s.scanned_count || 0);
    setLastScan(null);
    setReport(null);
    setMsg('');
    setPhase('scanning');
    setScanning(true);
  };

  const registerScan = useCallback(async (exId) => {
    if (!sessionId) return;
    try {
      const { data, error } = await supabase.schema('api').rpc('recolement_scan', {
        p_session_id: sessionId, p_exemplar_id: exId,
      });
      if (error || !data?.ok) { setLastScan({ kind: 'error' }); beep(false); setMsg(reasonMsg(data?.reason)); return; }
      setScannedCount(data.scanned_count || 0);
      const kind = data.already_scanned ? 'already' : (data.in_acervo ? 'present' : 'intrus');
      setLastScan({ kind, title: data.title, tombo: data.tombo, id: data.exemplar_id });
      beep(kind !== 'intrus');
    } catch { setLastScan({ kind: 'error' }); beep(false); }
  }, [sessionId, beep, reasonMsg]);

  const handleScanned = useCallback((raw) => {
    const exId = parseExemplarId(raw);
    if (exId == null) { setLastScan({ kind: 'unknown' }); beep(false); return; }
    registerScan(exId);
  }, [registerScan, beep]);

  const submitManual = () => {
    const exId = parseExemplarId(manual);
    if (exId == null) { setLastScan({ kind: 'unknown' }); return; }
    setManual('');
    registerScan(exId);
  };

  const finish = async () => {
    if (!sessionId || busy) return;
    if (!window.confirm(t({ id: 'recolement.confirmFinish' }))) return;
    setBusy(true); setMsg(''); setScanning(false);
    try {
      const { data, error } = await supabase.schema('api').rpc('recolement_finish', { p_session_id: sessionId });
      if (error || !data?.ok) { setMsg(reasonMsg(data?.reason)); return; }
      setReport(data);
      setPhase('report');
    } catch { setMsg(reasonMsg()); }
    finally { setBusy(false); }
  };

  const resetAll = () => {
    setPhase('idle'); setSessionId(null); setReport(null);
    setScannedCount(0); setLastScan(null); setMsg('');
    loadOpen();
  };

  // ── Exports ────────────────────────────────────────────────
  const stamp = () => new Date().toLocaleString(locale);
  const fileBase = () => `recolement-${(libraryName || 'biblio').replace(/[^\w.-]+/g, '_')}`;

  const exportCsv = () => {
    if (!report) return;
    const esc = (v) => {
      const s = v == null ? '' : String(v);
      return /[",\n;]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    const head = [
      t({ id: 'recolement.csv.type' }), t({ id: 'recolement.col.tombo' }),
      t({ id: 'recolement.col.shelf' }), t({ id: 'recolement.col.lib' }),
      t({ id: 'recolement.col.title' }), t({ id: 'recolement.col.id' }),
    ];
    const rows = [head];
    (report.missing || []).forEach((m) => rows.push([
      t({ id: 'recolement.report.missing' }), m.tombo, m.shelf, '', m.title, m.exemplar_id,
    ]));
    (report.intrus || []).forEach((i) => rows.push([
      t({ id: 'recolement.report.intrus' }), i.tombo, '', i.lib, '', i.exemplar_id,
    ]));
    const csv = '﻿' + rows.map((r) => r.map(esc).join(',')).join('\r\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `${fileBase()}.csv`;
    document.body.appendChild(a); a.click(); a.remove();
    URL.revokeObjectURL(url);
  };

  const exportPdf = async () => {
    if (!report) return;
    setBusy(true);
    try {
      const subtitle = t(
        { id: 'recolement.report.subtitle' },
        {
          acervo: report.acervo_count, scanned: report.scanned_count,
          present: report.present_count, missing: report.missing_count, intrus: report.intrus_count,
        },
      );
      await generateMultiReportPdf({
        filename: `${fileBase()}.pdf`,
        networkName: libraryName || '',
        labels: { generatedAt: stamp() },
        sections: [
          {
            title: t({ id: 'recolement.report.missingTitle' }),
            subtitle,
            columns: [
              { header: t({ id: 'recolement.col.tombo' }), width: 1.2 },
              { header: t({ id: 'recolement.col.shelf' }), width: 1.4 },
              { header: t({ id: 'recolement.col.title' }), width: 3 },
            ],
            rows: (report.missing || []).map((m) => [m.tombo, m.shelf, m.title]),
            totalLabel: `${t({ id: 'recolement.report.missing' })}: ${report.missing_count}`,
          },
          {
            title: t({ id: 'recolement.report.intrusTitle' }),
            columns: [
              { header: t({ id: 'recolement.col.tombo' }), width: 1.2 },
              { header: t({ id: 'recolement.col.lib' }), width: 1.5 },
              { header: t({ id: 'recolement.col.id' }), width: 1, align: 'right' },
            ],
            rows: (report.intrus || []).map((i) => [i.tombo, i.lib, i.exemplar_id]),
            totalLabel: `${t({ id: 'recolement.report.intrus' })}: ${report.intrus_count}`,
          },
        ],
      });
    } catch { setMsg(reasonMsg()); }
    finally { setBusy(false); }
  };

  // ── Rendu ──────────────────────────────────────────────────
  const lastScanLine = () => {
    if (!lastScan) return null;
    const { kind, title, tombo, id } = lastScan;
    const cls = kind === 'present' ? 'ab-recolement-last--ok'
      : kind === 'already' ? 'ab-recolement-last--dup'
      : 'ab-recolement-last--warn';
    let text;
    if (kind === 'present') text = `✓ ${title || ''} ${tombo ? `(${tombo})` : ''}`.trim();
    else if (kind === 'already') text = t({ id: 'recolement.last.already' }, { title: title || tombo || id });
    else if (kind === 'intrus') text = t({ id: 'recolement.last.intrus' }, { id });
    else if (kind === 'unknown') text = t({ id: 'recolement.last.unknown' });
    else text = t({ id: 'recolement.error.generic' });
    return <p className={`ab-recolement-last ${cls}`}>{text}</p>;
  };

  return (
    <div className="ab-recolement">
      <h2 className="ab-painel-section-title">{t({ id: 'recolement.title' })}</h2>
      <p className="ab-painel-hint">{t({ id: 'recolement.intro' })}</p>

      {msg && <p className="ab-painel-msg">{msg}</p>}

      {/* ── IDLE : démarrer / reprendre ── */}
      {phase === 'idle' && (
        <div className="ab-recolement-start">
          <Button onClick={start} disabled={busy || !libraryId}>
            {busy ? <Spinner /> : t({ id: 'recolement.start' })}
          </Button>

          {openSessions.length > 0 && (
            <div className="ab-recolement-resume">
              <h3 className="ab-painel-subtitle">{t({ id: 'recolement.openSessions' })}</h3>
              <ul className="ab-recolement-sessions">
                {openSessions.map((s) => (
                  <li key={s.session_id}>
                    <span>
                      {new Date(s.started_at).toLocaleString(locale)}
                      {' · '}
                      {t({ id: 'recolement.session.scanned' }, { n: s.scanned_count })}
                    </span>
                    <Button onClick={() => resume(s)} disabled={busy}>{t({ id: 'recolement.resume' })}</Button>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      {/* ── SCANNING : caméra + compteur ── */}
      {phase === 'scanning' && (
        <div className="ab-recolement-scan">
          <div className="ab-recolement-counter">
            <strong>{scannedCount}</strong>
            {acervoCount > 0 && <span> / {acervoCount}</span>}
            <span className="ab-recolement-counter__label"> {t({ id: 'recolement.counter.label' })}</span>
          </div>

          {lastScanLine()}

          {scanning
            ? (
              <CardScanner
                t={t}
                continuous
                formats={['qr_code']}
                prompt={t({ id: 'recolement.scan.prompt' })}
                onScan={handleScanned}
                onClose={() => setScanning(false)}
              />
            )
            : <Button onClick={() => setScanning(true)}>{t({ id: 'recolement.scan.open' })}</Button>}

          <div className="ab-recolement-manual">
            <input
              type="text"
              className="ab-painel-input"
              value={manual}
              onChange={(e) => setManual(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && submitManual()}
              placeholder={t({ id: 'recolement.manual.placeholder' })}
              autoComplete="off"
            />
            <Button onClick={submitManual}>{t({ id: 'recolement.manual.action' })}</Button>
          </div>

          <div className="ab-recolement-actions">
            <Button onClick={finish} disabled={busy}>
              {busy ? <Spinner /> : t({ id: 'recolement.finish' })}
            </Button>
          </div>
        </div>
      )}

      {/* ── REPORT : rapport + exports ── */}
      {phase === 'report' && report && (
        <div className="ab-recolement-report">
          <div className="ab-recolement-stats">
            <span>{t({ id: 'recolement.report.acervo' })}: <strong>{report.acervo_count}</strong></span>
            <span>{t({ id: 'recolement.report.scanned' })}: <strong>{report.scanned_count}</strong></span>
            <span>{t({ id: 'recolement.report.present' })}: <strong>{report.present_count}</strong></span>
            <span className="ab-recolement-stat--warn">{t({ id: 'recolement.report.missing' })}: <strong>{report.missing_count}</strong></span>
            <span className="ab-recolement-stat--warn">{t({ id: 'recolement.report.intrus' })}: <strong>{report.intrus_count}</strong></span>
          </div>

          <div className="ab-recolement-actions">
            <Button onClick={exportCsv}>{t({ id: 'recolement.export.csv' })}</Button>
            <Button onClick={exportPdf} disabled={busy}>{t({ id: 'recolement.export.pdf' })}</Button>
            <Button onClick={resetAll}>{t({ id: 'recolement.new' })}</Button>
          </div>

          <h3 className="ab-painel-subtitle">{t({ id: 'recolement.report.missingTitle' })} ({report.missing_count})</h3>
          {report.missing?.length
            ? (
              <ul className="ab-recolement-list">
                {report.missing.map((m) => (
                  <li key={`m-${m.exemplar_id}`}>
                    <code>{m.tombo || m.exemplar_id}</code> {m.title || ''}
                    {m.shelf ? <em> — {m.shelf}</em> : null}
                  </li>
                ))}
              </ul>
            )
            : <p className="ab-painel-hint">{t({ id: 'recolement.report.none' })}</p>}

          <h3 className="ab-painel-subtitle">{t({ id: 'recolement.report.intrusTitle' })} ({report.intrus_count})</h3>
          {report.intrus?.length
            ? (
              <ul className="ab-recolement-list">
                {report.intrus.map((i) => (
                  <li key={`i-${i.exemplar_id}`}>
                    <code>{i.tombo || i.exemplar_id}</code>
                    {i.lib ? <em> — {i.lib}</em> : null}
                  </li>
                ))}
              </ul>
            )
            : <p className="ab-painel-hint">{t({ id: 'recolement.report.none' })}</p>}
        </div>
      )}
    </div>
  );
}
