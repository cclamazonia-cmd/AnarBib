// ═══════════════════════════════════════════════════════════
// EpubReader — lecteur ePub AnarBib (coquille du moteur epubEngine)
// ═══════════════════════════════════════════════════════════
//
// Frère des autres viewers (AudioPlayer / VideoPlayer / ImageViewer).
// S'appuie sur le moteur pur `@/lib/reader/epubEngine` (partagé, sans
// dépendance applicative) et l'habille pour AnarBib :
//
//   - chargement en blob (l'URL signée n'est jamais exposée au DOM)
//   - anti-copie scopée au viewer + filigrane injecté DANS l'iframe
//     (hook onContent du moteur) — anti-DRM honnête, cf. multiformat-viewers.md
//   - i18n react-intl (clés reader.epub.* + reader.* génériques)
//   - persistance de lecture CÔTÉ SERVEUR par ressource (position + temps),
//     via apiRpc (schéma api) ; l'index de progression (locations) reste un
//     cache local (donnée dérivée, non sensible)
//
// Props :
//   src         : string — URL signée de l'ePub (fetché en blob)
//   fileName    : string — titre affiché
//   watermark   : string — texte du filigrane (ex: AnarBib · biblio · email)
//   resourceId  : number — id de la ressource numérique (clé de persistance)
//   onError     : (msg) => void
//
// Limites connues (anti-DRM honnête) : le décourageant ne remplace pas un
// DRM. Le filigrane attribue une fuite, le blob complique ; rien n'est absolu.

import { useEffect, useRef, useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import ePub from 'epubjs';
import { apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { createEpubEngine } from '@/lib/reader/epubEngine';
import './EpubReader.css';

const SAVE_DEBOUNCE_MS = 1500;

// ── Anti-copie scopée au viewer (même logique que ReaderPage) ──
function useViewerCopyProtection(viewerRef) {
  useEffect(() => {
    const inViewer = (e) => {
      const node = viewerRef.current;
      return Boolean(node && e.target && node.contains(e.target));
    };
    const block = (e) => { if (!inViewer(e)) return; e.preventDefault(); e.stopPropagation(); };
    const blockKeys = (e) => {
      if (!viewerRef.current) return;
      const k = (e.key || '').toLowerCase();
      if ((e.ctrlKey && !e.shiftKey && ['s', 'p', 'c', 'u'].includes(k)) ||
          (e.ctrlKey && e.shiftKey && ['i', 'j', 'c'].includes(k))) {
        e.preventDefault(); e.stopPropagation();
      }
    };
    document.addEventListener('contextmenu', block, true);
    document.addEventListener('dragstart', block, true);
    document.addEventListener('copy', block, true);
    document.addEventListener('selectstart', block, true);
    document.addEventListener('keydown', blockKeys, true);
    return () => {
      document.removeEventListener('contextmenu', block, true);
      document.removeEventListener('dragstart', block, true);
      document.removeEventListener('copy', block, true);
      document.removeEventListener('selectstart', block, true);
      document.removeEventListener('keydown', blockKeys, true);
    };
  }, [viewerRef]);
}

// ── Filigrane + anti-copie injectés DANS l'iframe (hook onContent) ──
function injectWatermarkAndGuard(doc, watermark) {
  try {
    if (!doc || !doc.body) return;
    if (watermark && !doc.getElementById('ab-epub-wm')) {
      const wm = doc.createElement('div');
      wm.id = 'ab-epub-wm';
      wm.setAttribute('aria-hidden', 'true');
      wm.textContent = watermark;
      // Style INLINE : le filigrane vit dans l'iframe (document séparé), il ne
      // charge pas EpubReader.css — l'inline est le seul moyen fiable.
      wm.style.cssText = 'position:fixed;inset:0;pointer-events:none;display:flex;align-items:center;justify-content:center;opacity:.06;font:600 18px system-ui,sans-serif;color:#777;transform:rotate(-28deg);z-index:2147483646;white-space:nowrap;';
      doc.body.appendChild(wm);
    }
    const block = (ev) => ev.preventDefault();
    doc.addEventListener('contextmenu', block, true);
    doc.addEventListener('copy', block, true);
    doc.addEventListener('dragstart', block, true);
  } catch (e) { /* no-op */ }
}

const THEME_LIGHT = { night: false, bg: '#ffffff', fg: '#111111', link: '#0b57d0' };
const THEME_DARK = { night: true, bg: '#0f1115', fg: '#e9edf1', link: '#8ab4f8' };

export default function EpubReader({ src, fileName, watermark, resourceId, onError }) {
  const { formatMessage: t } = useIntl();
  const viewerRef = useRef(null);
  const hostRef = useRef(null);
  const engineRef = useRef(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [progress, setProgress] = useState({ page: null, total: null, percent: null });
  const [locReady, setLocReady] = useState(false);
  const [seconds, setSeconds] = useState(0);
  const [night, setNight] = useState(false);
  const [prefs, setPrefs] = useState({ fontPct: 110, justify: false, hyphen: false, fontMode: 'serif', marginMode: 'normal' });
  const [spread, setSpread] = useState(false);
  const [toc, setToc] = useState([]);
  const [tocOpen, setTocOpen] = useState(false);
  const [note, setNote] = useState(null);
  const [zen, setZen] = useState(false);
  const [uiVisible, setUiVisible] = useState(true);
  const [isFs, setIsFs] = useState(false);

  const zenTimerRef = useRef(null);
  const saveStateRef = useRef({ cfi: null, percent: null, seconds: 0 });
  const saveTimerRef = useRef(null);

  useViewerCopyProtection(viewerRef);

  // L'index de progression (locations) = cache LOCAL (dérivé, non sensible).
  const locKey = resourceId ? `anarbib.epub.loc.${resourceId}` : null;

  // ── Persistance SERVEUR (débouncée), dégrade en silence ──
  const scheduleSave = useCallback(() => {
    if (!resourceId) return;
    if (saveTimerRef.current) clearTimeout(saveTimerRef.current);
    saveTimerRef.current = setTimeout(() => {
      const s = saveStateRef.current;
      apiRpc('fn_upsert_reading_progress', {
        p_resource_id: resourceId,
        p_cfi: s.cfi,
        p_percent: s.percent,
        p_seconds: s.seconds,
      }).catch(() => { /* persistance best-effort : la lecture marche sans */ });
    }, SAVE_DEBOUNCE_MS);
  }, [resourceId]);

  useEffect(() => {
    let disposed = false;
    let engine = null;
    setLoading(true); setError('');
    (async () => {
      try {
        // Position initiale depuis le serveur (best-effort)
        let startCfi;
        let initialSeconds = 0;
        if (resourceId) {
          try {
            const { data } = await apiRpc('fn_get_reading_progress', { p_resource_id: resourceId });
            const row = Array.isArray(data) ? data[0] : data;
            if (row) { startCfi = row.cfi || undefined; initialSeconds = Number(row.reading_seconds) || 0; }
          } catch (e) { /* pas de reprise, pas grave */ }
        }
        if (disposed) return;

        // L'ePub : fetché en blob, jamais l'URL signée dans le DOM
        const res = await fetch(src);
        if (!res.ok) throw new Error(`${res.status}`);
        const buf = await res.arrayBuffer();
        if (disposed) return;

        engine = createEpubEngine({
          ePub,
          container: hostRef.current,
          theme: THEME_LIGHT,
          prefs: { fontPct: 110 },
          lang: 'pt-BR',
          onReady: () => { if (!disposed) setLoading(false); },
          onRelocate: ({ cfi, percent, page, total }) => {
            if (disposed) return;
            setProgress({ page, total, percent });
            saveStateRef.current = { ...saveStateRef.current, cfi, percent };
            scheduleSave();
          },
          onTick: (s) => {
            if (disposed) return;
            setSeconds(s);
            saveStateRef.current = { ...saveStateRef.current, seconds: s };
            scheduleSave();
          },
          onNote: ({ html, label }) => { if (!disposed) setNote({ html, label }); },
          onLocationsState: ({ ready }) => { if (!disposed) setLocReady(!!ready); },
          onLocationsGenerated: (saved) => { if (locKey) { try { localStorage.setItem(locKey, saved); } catch (e) { /* quota */ } } },
          onContent: ({ doc }) => injectWatermarkAndGuard(doc, watermark),
          onError: (e) => {
            if (disposed) return;
            const msg = `${t({ id: 'reader.errorOpening' })}: ${localizeError(e, t)}`;
            setError(msg); setLoading(false); onError && onError(msg);
          },
        });
        engineRef.current = engine;

        await engine.open(buf, {
          startCfi,
          initialSeconds,
          locations: locKey ? (localStorage.getItem(locKey) || undefined) : undefined,
        });
        if (disposed) return;
        const toc_ = await engine.getToc();
        if (!disposed) setToc(toc_);
      } catch (err) {
        if (disposed) return;
        const msg = `${t({ id: 'reader.errorOpening' })}: ${localizeError(err, t)}`;
        setError(msg); setLoading(false); onError && onError(msg);
      }
    })();

    return () => {
      disposed = true;
      if (saveTimerRef.current) clearTimeout(saveTimerRef.current);
      if (engine) engine.destroy();
      engineRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [src, resourceId]);

  const eng = () => engineRef.current;

  const stepFont = useCallback((d) => setPrefs((p) => {
    const fontPct = Math.max(80, Math.min(200, p.fontPct + d));
    if (eng()) eng().setPrefs({ fontPct });
    return { ...p, fontPct };
  }), []);
  const toggle = useCallback((key) => setPrefs((p) => {
    const next = { ...p, [key]: !p[key] };
    if (eng()) eng().setPrefs({ [key]: next[key] });
    return next;
  }), []);
  const setMode = useCallback((key, value) => setPrefs((p) => {
    if (eng()) eng().setPrefs({ [key]: value });
    return { ...p, [key]: value };
  }), []);
  const toggleNight = useCallback(() => setNight((n) => {
    const nn = !n;
    if (eng()) eng().setTheme(nn ? THEME_DARK : THEME_LIGHT);
    return nn;
  }), []);
  const toggleSpread = useCallback(() => setSpread((s) => {
    const ns = !s;
    if (eng()) eng().setPrefs({ spread: ns });
    return ns;
  }), []);
  const onSlide = useCallback((e) => { if (eng()) eng().jumpToPercent(Number(e.target.value) / 1000); }, []);

  // Plein écran
  useEffect(() => {
    const onFs = () => setIsFs(Boolean(document.fullscreenElement));
    document.addEventListener('fullscreenchange', onFs);
    return () => document.removeEventListener('fullscreenchange', onFs);
  }, []);
  const toggleFs = useCallback(() => {
    const node = viewerRef.current;
    if (!node) return;
    if (!document.fullscreenElement) { if (node.requestFullscreen) node.requestFullscreen(); }
    else if (document.exitFullscreen) document.exitFullscreen();
  }, []);

  // Zen : ré-masque l'UI après 3 s ; le mouvement souris la réveille.
  const wakeUi = useCallback(() => {
    if (!zen) return;
    setUiVisible(true);
    if (zenTimerRef.current) clearTimeout(zenTimerRef.current);
    zenTimerRef.current = setTimeout(() => setUiVisible(false), 3000);
  }, [zen]);
  const toggleZen = useCallback(() => { setZen((z) => !z); setUiVisible(true); }, []);
  useEffect(() => {
    if (!zen) { setUiVisible(true); if (zenTimerRef.current) clearTimeout(zenTimerRef.current); return undefined; }
    zenTimerRef.current = setTimeout(() => setUiVisible(false), 3000);
    return () => { if (zenTimerRef.current) clearTimeout(zenTimerRef.current); };
  }, [zen]);

  const fmtTime = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
  const pct = progress.percent != null ? Math.round(progress.percent * 100) : null;
  const uiHidden = zen && !uiVisible;

  return (
    <div
      ref={viewerRef}
      onMouseMove={wakeUi}
      className={`ab-epub ${night ? 'ab-epub--night' : ''} ${isFs ? 'ab-epub--fullscreen' : ''}`}
      tabIndex={0}
    >
      {/* Barre d'outils */}
      <div className={`ab-epub-toolbar ${uiHidden ? 'ab-epub-toolbar--hidden' : ''}`}>
        <div className="ab-epub-toolbar__group">
          <button className="ab-epub-tb-btn" onClick={() => eng() && eng().prev()} title={t({ id: 'reader.prevPage' })}>◀</button>
          <button className="ab-epub-tb-btn" onClick={() => eng() && eng().next()} title={t({ id: 'reader.pageNav' })}>▶</button>
          <button className="ab-epub-tb-btn" onClick={() => eng() && eng().chapterStart()} title={t({ id: 'reader.epub.chapterStart' })}>⤒</button>
          <button className="ab-epub-tb-btn" onClick={() => eng() && eng().chapterEnd()} title={t({ id: 'reader.epub.chapterEnd' })}>⤓</button>
        </div>
        <div className="ab-epub-toolbar__group">
          <button className="ab-epub-tb-btn" onClick={() => stepFont(-10)} title={t({ id: 'reader.epub.fontDecrease' })}>A−</button>
          <button className="ab-epub-tb-btn" onClick={() => stepFont(10)} title={t({ id: 'reader.epub.fontIncrease' })}>A+</button>
          <button className={`ab-epub-tb-btn ${prefs.justify ? 'is-active' : ''}`} onClick={() => toggle('justify')} title={t({ id: 'reader.epub.justify' })}>↹</button>
          <button className={`ab-epub-tb-btn ${prefs.hyphen ? 'is-active' : ''}`} onClick={() => toggle('hyphen')} title={t({ id: 'reader.epub.hyphen' })}>­-­</button>
          <select className="ab-epub-tb-select" value={prefs.fontMode} onChange={(e) => setMode('fontMode', e.target.value)} title={t({ id: 'reader.epub.fontFamily' })}>
            <option value="serif">{t({ id: 'reader.epub.fontSerif' })}</option>
            <option value="sans">{t({ id: 'reader.epub.fontSans' })}</option>
          </select>
          <select className="ab-epub-tb-select" value={prefs.marginMode} onChange={(e) => setMode('marginMode', e.target.value)} title={t({ id: 'reader.epub.margins' })}>
            <option value="compact">{t({ id: 'reader.epub.marginCompact' })}</option>
            <option value="normal">{t({ id: 'reader.epub.marginNormal' })}</option>
            <option value="large">{t({ id: 'reader.epub.marginLarge' })}</option>
          </select>
        </div>
        <div className="ab-epub-toolbar__group">
          <button className="ab-epub-tb-btn" onClick={toggleNight} title={t({ id: night ? 'reader.epub.themeLight' : 'reader.epub.themeDark' })}>{night ? '☀' : '☾'}</button>
          <button className={`ab-epub-tb-btn ${tocOpen ? 'is-active' : ''}`} onClick={() => setTocOpen((o) => !o)} title={t({ id: 'reader.epub.toc' })}>☰</button>
          <button className={`ab-epub-tb-btn ${spread ? 'is-active' : ''}`} onClick={toggleSpread} title={t({ id: 'reader.epub.spread' })}>▥</button>
          <button className="ab-epub-tb-btn" onClick={toggleFs} title={t({ id: isFs ? 'reader.fullscreenExit' : 'reader.fullscreen' })}>{isFs ? '⤡' : '⤢'}</button>
          <button className={`ab-epub-tb-btn ${zen ? 'is-active' : ''}`} onClick={toggleZen} title={t({ id: 'reader.epub.zen' })}>☯</button>
        </div>
      </div>

      {/* Barre d'état + progression */}
      <div className={`ab-epub-status ${uiHidden ? 'ab-epub-status--hidden' : ''}`}>
        <span className="ab-epub-status__pos">
          {progress.page ? t({ id: 'reader.page' }, { num: `${progress.page}/${progress.total}` }) : '—'}
          {pct != null ? ` · ${pct}%` : ''}
        </span>
        <span className="ab-epub-status__time">{t({ id: 'reader.epub.readingTime' }, { time: fmtTime(seconds) })}</span>
        <span className="ab-epub-status__loc">{locReady ? t({ id: 'reader.epub.progress' }) : t({ id: 'reader.epub.progressPending' })}</span>
        <input
          type="range" className="ab-epub-range" min={0} max={1000}
          value={pct != null ? pct * 10 : 0} disabled={!locReady}
          onChange={onSlide} aria-label={t({ id: 'reader.epub.progress' })}
        />
      </div>

      {/* Corps : sommaire + zone de rendu */}
      <div className="ab-epub-body">
        {tocOpen && (
          <nav className="ab-epub-toc">
            {toc.length === 0
              ? <p className="ab-epub-toc__empty">{t({ id: 'reader.epub.tocEmpty' })}</p>
              : toc.map((item, i) => (
                <button
                  key={i} className="ab-epub-toc__item" style={{ paddingLeft: `${8 + item.level * 14}px` }}
                  onClick={() => { if (eng()) eng().goToHref(item.href); setTocOpen(false); }}
                >{item.label}</button>
              ))}
          </nav>
        )}
        <div className="ab-epub-stage">
          {loading && <div className="ab-epub-overlay">{t({ id: 'reader.loadingPrep' })}</div>}
          {error && <div className="ab-epub-overlay ab-epub-overlay--error">{error}</div>}
          <div ref={hostRef} className="ab-epub-host" />
        </div>
      </div>

      {/* Notice anti-DRM honnête */}
      <p className="ab-epub-notice">{t({ id: 'reader.notice' })}</p>

      {/* Modale de note */}
      {note && (
        <div className="ab-epub-note-modal" data-close="1" onClick={(e) => { if (e.target.dataset.close === '1') setNote(null); }}>
          <div className="ab-epub-note-box">
            {note.label && <h4 className="ab-epub-note-title">{t({ id: 'reader.epub.note' }, { num: note.label })}</h4>}
            {/* eslint-disable-next-line react/no-danger */}
            <div className="ab-epub-note-content" dangerouslySetInnerHTML={{ __html: note.html || '' }} />
            <button className="ab-epub-tb-btn" onClick={() => setNote(null)}>{t({ id: 'reader.epub.noteClose' })}</button>
          </div>
        </div>
      )}
    </div>
  );
}
