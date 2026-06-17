// ════════════════════════════════════════════════════════════════════
// epubEngine.js — moteur de lecture ePub réutilisable (framework-agnostic)
// ════════════════════════════════════════════════════════════════════
//
// Extrait du lecteur CCLA (editora-ccla / index.html). Objectif : un cœur
// PUR, partageable entre la coquille AnarBib (React) et la coquille CCLA
// (vanilla). Le moteur ne connaît NI React, NI le DOM applicatif, NI
// localStorage, NI l'i18n, NI le filigrane. Tout cela = affaire de coquille.
//
// Le moteur N'EXPOSE que des commandes + des ÉVÉNEMENTS :
//   - onReady()                            : rendu prêt
//   - onRelocate({cfi, percent, page, total})  : position changée  → la coquille persiste
//   - onTick(totalSeconds)                 : temps de lecture cumulé → la coquille persiste
//   - onNote({html, label})                : renvoi de note cliqué  → la coquille ouvre une modale
//   - onContent({doc, window, section})    : un iframe vient d'être rendu → la coquille
//                                            y injecte filigrane + anti-copie (AnarBib)
//   - onLocationsState({ready, generating}): état de l'index de progression
//   - onLocationsGenerated(savedString)    : l'index CFI vient d'être généré → cache (client)
//   - onError(err)
//
// Dépendance INJECTÉE : opts.ePub = constructeur epub.js
//   - AnarBib : import ePub from 'epubjs'; createEpubEngine({ ePub, ... })
//   - CCLA    : createEpubEngine({ ePub: window.ePub, ... })
//
// Persistance : le moteur NE touche PAS au stockage. La coquille fournit
// l'état initial via open(data, { startCfi, initialSeconds, locations }) et
// persiste via les événements.
// ════════════════════════════════════════════════════════════════════

const HARD_STYLE_ID = 'ab-epub-hard-override-style';
const CHUNK_MS = 30000;            // granularité du temps de lecture (30 s)
const FLOW_MODE = 'paginated';     // flux epub.js
const DESKTOP_SPREAD_MIN = 980;    // largeur mini pour la double-page

const DEFAULT_PREFS = {
  fontPct: 110,        // 80–200
  lineHeight: 1.65,    // 1.45–1.90
  marginMode: 'normal', // 'compact' | 'normal' | 'large'
  fontMode: 'serif',   // 'serif' | 'sans'
  justify: false,
  hyphen: false,
  spread: false,       // double-page (desktop only)
};

const DEFAULT_THEME = {
  night: false,
  bg: '#ffffff',
  fg: '#111111',
  link: '#0b57d0',
};

export function createEpubEngine(opts = {}) {
  const {
    ePub,
    container,
    onReady, onRelocate, onTick, onNote, onContent,
    onLocationsState, onLocationsGenerated, onError,
    tapToTurn = true,
  } = opts;

  if (typeof ePub !== 'function') throw new Error('createEpubEngine: opts.ePub (constructeur epub.js) manquant');
  if (!container) throw new Error('createEpubEngine: opts.container (élément DOM) manquant');

  // ── État ────────────────────────────────────────────────────────
  let book = null;
  let rendition = null;
  let prefs = { ...DEFAULT_PREFS, ...(opts.prefs || {}) };
  let theme = { ...DEFAULT_THEME, ...(opts.theme || {}) };
  let locationsReady = false;
  let destroyed = false;

  // temps de lecture
  let readingSeconds = 0;
  let carryMs = 0;
  let lastTs = null;
  let rafId = null;

  // hooks (installés une fois par rendition)
  let langHookInstalled = false;
  let hardCssHookInstalled = false;
  let noteHookInstalled = false;
  let contentHookInstalled = false;

  const safe = (fn) => { try { return fn(); } catch (e) { /* no-op */ } };
  const emitErr = (e) => { try { onError && onError(e); } catch (_) {} };

  // ════════════════════════════════════════════════════════════════
  // CSS DUR (injecté dans chaque iframe : mate le CSS de l'éditeur)
  // ════════════════════════════════════════════════════════════════
  function hardCssText(isCover) {
    const bg = theme.bg, fg = theme.fg, link = theme.link;
    const align = prefs.justify ? 'justify' : 'start';
    const hy = prefs.hyphen ? 'auto' : 'manual';
    const lh = String(prefs.lineHeight || 1.65);
    const pad = prefs.marginMode === 'compact' ? 12 : (prefs.marginMode === 'large' ? 26 : 18);
    const fontFamily = prefs.fontMode === 'sans'
      ? 'system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif'
      : 'ui-serif,"Georgia","Times New Roman",Times,serif';

    return `
html, body { background:${bg} !important; color:${fg} !important; font-family:${fontFamily} !important; }
* { color:inherit !important; background-color:transparent !important; text-shadow:none !important; }
a, a:visited { color:${link} !important; }
p, li, blockquote, div, section, article {
  text-align:${align} !important; hyphens:${hy} !important; -webkit-hyphens:${hy} !important;
  -ms-hyphens:${hy} !important; line-height:${lh} !important;
}
body {
  padding:${isCover ? 0 : pad}px ${isCover ? 0 : pad}px ${isCover ? 0 : Math.round(pad * 1.35)}px ${isCover ? 0 : pad}px !important;
  margin:0 !important; height:100% !important;
}
html { height:100% !important; }
img, svg, video, canvas { background:transparent !important; max-width:100% !important; height:auto !important; object-fit:contain !important; }
svg { display:block !important; }
table, thead, tbody, tr, td, th { background:transparent !important; }
${isCover ? `
body { display:flex !important; align-items:center !important; justify-content:center !important; }
div { width:100% !important; height:100% !important; }
svg, img { width:100% !important; height:100% !important; max-height:100% !important; }
` : ''}`.trim();
  }

  function isCoverDoc(doc) {
    try {
      if (!doc) return false;
      const m = doc.querySelector && doc.querySelector('meta[name="calibre:cover"][content="true"], meta[name="calibre:cover"][content="1"]');
      if (m) return true;
      const t = (doc.title || '').trim().toLowerCase();
      if (t === 'cover') return true;
      const svg = doc.querySelector && doc.querySelector('svg image[xlink\\:href], svg image[href]');
      const href = svg ? (svg.getAttribute('xlink:href') || svg.getAttribute('href') || '') : '';
      if (/cover\.(jpe?g|png|webp|gif)$/i.test(href)) return true;
      return false;
    } catch (e) { return false; }
  }

  function patchCoverDom(doc) {
    try {
      if (!doc) return;
      const svgs = doc.querySelectorAll ? doc.querySelectorAll('svg[preserveAspectRatio]') : [];
      svgs.forEach((svg) => {
        const pa = (svg.getAttribute('preserveAspectRatio') || '').toLowerCase();
        if (!pa || pa === 'none') svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
      });
      if (doc.body) { doc.body.style.margin = '0'; doc.body.style.padding = '0'; }
      if (doc.documentElement) doc.documentElement.style.height = '100%';
    } catch (e) {}
  }

  function upsertHardStyle(contents) {
    try {
      const doc = contents && contents.document;
      if (!doc) return;
      let styleEl = doc.getElementById(HARD_STYLE_ID);
      if (!styleEl) {
        styleEl = doc.createElement('style');
        styleEl.id = HARD_STYLE_ID;
        styleEl.type = 'text/css';
        (doc.head || doc.documentElement).appendChild(styleEl);
      }
      const isCover = isCoverDoc(doc);
      styleEl.textContent = hardCssText(isCover);
      if (isCover) patchCoverDom(doc);
    } catch (e) {}
  }

  function updateAllContentsHardStyle() {
    if (!rendition) return;
    safe(() => {
      const list = typeof rendition.getContents === 'function' ? rendition.getContents() : [];
      for (const c of list) upsertHardStyle(c);
    });
  }

  // ════════════════════════════════════════════════════════════════
  // NOTES (résolution du contenu d'un renvoi — logique pure)
  // ════════════════════════════════════════════════════════════════
  function getNoteLabelFromHref(a) {
    try {
      const href = a && a.getAttribute ? (a.getAttribute('href') || '') : '';
      const t = (a && (a.textContent || '')).replace(/\s+/g, '').trim();
      if (/^\d+$/.test(t)) return t;
      if (href && href.includes('#')) {
        const id = decodeURIComponent(href.split('#')[1] || '');
        const m = id.match(/(\d+)/);
        if (m) return m[1];
      }
    } catch (e) {}
    return '';
  }

  function isNoteRefLink(a) {
    if (!a) return false;
    const href = a.getAttribute('href') || '';
    if (!href || href.startsWith('javascript:')) return false;
    const epubType = (a.getAttribute('epub:type') || '').toLowerCase();
    const role = (a.getAttribute('role') || '').toLowerCase();
    const cls = (a.className || '').toLowerCase();
    if (epubType === 'noteref' || role === 'doc-noteref' || cls.includes('noteref')) return true;
    if (href.includes('#')) {
      const id = href.split('#')[1] || '';
      if (/^(fn|footnote|note|nota|notas|endnote)\b/i.test(id)) return true;
      if (/notes?/i.test(href)) return true;
    }
    return false;
  }

  function isBackrefAnchor(a) {
    try {
      const role = (a.getAttribute('role') || '').toLowerCase();
      const et = (a.getAttribute('epub:type') || '').toLowerCase();
      if (role === 'doc-backlink' || et.indexOf('backlink') >= 0) return true;
      const t = (a.textContent || '').replace(/\s+/g, '');
      if (!t) return true;                                              // ancre vide (retour en icône)
      if (/[←↩⤴↑]/.test(t)) return true;       // contient une flèche de retour (« ←1 », « ↩ »…)
      if (/(retour|voltar|volta|back|return)/i.test(t)) return true;
      if (/^[\[(]?\d{1,4}[\])]?\.?$/.test(t)) return true;             // [1] (1) 1 1. = marqueur de retour
      return false;
    } catch (e) { return false; }
  }

  function extractNoteHTML(el) {
    try {
      if (!el) return '';
      let container2 = el;
      safe(() => {
        const c = el.closest && el.closest('aside[epub\\:type~="footnote"], aside[epub\\:type~="endnote"], aside[epub\\:type*="note"], li.footnote, li.endnote, div.footnote, div.endnote, dl.footnote, section[epub\\:type~="endnotes"] dl, section[epub\\:type~="footnotes"] li');
        if (c) container2 = c;
      });
      // Nettoyage sur un CLONE (ne mute pas la source) : on retire les liens de
      // retour (back-refs) puis les crochets/parenthèses vides qu'ils laissent.
      let html = container2.outerHTML || '';
      safe(() => {
        const clone = container2.cloneNode(true);
        const anchors = clone.querySelectorAll ? clone.querySelectorAll('a') : [];
        anchors.forEach((a) => { if (isBackrefAnchor(a)) a.remove(); });
        html = clone.outerHTML || html;
      });
      safe(() => { html = html.replace(/\[\s*\]/g, '').replace(/\(\s*\)/g, '').replace(/>(?:\s|&nbsp;| )+</g, '><'); });
      return html || '';
    } catch (e) { return ''; }
  }

  async function loadXhtmlText(resolvedHref) {
    const decode = (res) => {
      if (typeof res === 'string') return res;
      try { if (res instanceof ArrayBuffer) return new TextDecoder('utf-8').decode(new Uint8Array(res)); } catch (e) {}
      try { if (ArrayBuffer.isView(res)) return new TextDecoder('utf-8').decode(res); } catch (e) {}
      try { if (res && res.documentElement) return new XMLSerializer().serializeToString(res); } catch (e) {}
      return null;
    };
    try {
      if (book && typeof book.load === 'function') {
        const res = await book.load(resolvedHref);
        if (res) {
          const d = decode(res);
          if (d != null) return d;
          if (typeof res.text === 'function') return await res.text();
          return String(res);
        }
      }
    } catch (e) {}
    try {
      if (book && book.archive && typeof book.archive.request === 'function') {
        const res = await book.archive.request(resolvedHref);
        if (res) {
          const d = decode(res);
          if (d != null) return d;
          if (typeof res.text === 'function') return await res.text();
          return String(res);
        }
      }
    } catch (e) {}
    try {
      const r = await fetch(resolvedHref);
      if (r.ok) return await r.text();
    } catch (e) {}
    return null;
  }

  async function resolveNoteHTMLFromLink(a, contentDoc, baseHref) {
    try {
      const href = a.getAttribute('href') || '';
      const parts = href.split('#');
      const filePartRaw = parts[0] || '';
      const targetId = parts[1] ? decodeURIComponent(parts[1]) : '';

      if (!filePartRaw || href.startsWith('#')) {
        if (!targetId) return '';
        const el = contentDoc.getElementById(targetId);
        return el ? extractNoteHTML(el) : '';
      }

      let filePart = filePartRaw;
      safe(() => {
        if (baseHref) {
          const baseDir = baseHref.includes('/') ? baseHref.slice(0, baseHref.lastIndexOf('/') + 1) : '';
          const norm = (p) => {
            const out = [];
            for (const seg of p.split('/')) {
              if (!seg || seg === '.') continue;
              if (seg === '..') { out.pop(); continue; }
              out.push(seg);
            }
            return out.join('/');
          };
          filePart = norm(baseDir + filePartRaw);
        }
      });

      const candidates = [];
      const pushCand = (x) => { if (x && !candidates.includes(x)) candidates.push(x); };
      pushCand(filePart);
      safe(() => pushCand(decodeURI(filePart)));
      pushCand(filePart.replace(/^\/+/, ''));
      safe(() => { if (book && typeof book.resolve === 'function') pushCand(book.resolve(filePart)); });
      safe(() => { if (book && book.path && typeof book.path.resolve === 'function') pushCand(book.path.resolve(filePart)); });

      let txt = null;
      for (const c of candidates) { txt = await loadXhtmlText(c); if (txt) break; }
      if (!txt) return '';

      const parser = new DOMParser();
      let doc = parser.parseFromString(txt, 'application/xhtml+xml');
      if (doc && doc.getElementsByTagName('parsererror').length > 0) doc = parser.parseFromString(txt, 'text/html');

      if (!targetId) return doc.body ? doc.body.innerHTML : '';
      let el = doc.getElementById(targetId);
      if (!el && targetId.startsWith('#')) el = doc.getElementById(targetId.slice(1));
      if (!el && /^fn/i.test(targetId)) el = doc.getElementById(targetId.replace(/^fn/i, 'footnote'));
      return el ? extractNoteHTML(el) : '';
    } catch (e) { return ''; }
  }

  // ════════════════════════════════════════════════════════════════
  // HOOKS de contenu (langue, CSS dur, notes, + onContent pour la coquille)
  // ════════════════════════════════════════════════════════════════
  function ensureHooks() {
    if (!rendition) return;

    if (!langHookInstalled) {
      langHookInstalled = true;
      safe(() => rendition.hooks.content.register((contents) => {
        safe(() => {
          const doc = contents.document;
          if (!doc) return;
          if (!doc.documentElement.getAttribute('lang')) doc.documentElement.setAttribute('lang', opts.lang || 'pt-BR');
          if (doc.body && !doc.body.getAttribute('lang')) doc.body.setAttribute('lang', opts.lang || 'pt-BR');
        });
      }));
    }

    if (!hardCssHookInstalled) {
      hardCssHookInstalled = true;
      safe(() => rendition.hooks.content.register((contents) => upsertHardStyle(contents)));
    }

    if (!noteHookInstalled) {
      noteHookInstalled = true;
      safe(() => rendition.hooks.content.register((contents) => {
        safe(() => {
          const doc = contents.document;
          if (!doc || !doc.body) return;
          const baseHref = (contents && contents.section && contents.section.href) ? contents.section.href : (contents && contents.href ? contents.href : '');

          if (tapToTurn) {
            doc.addEventListener('click', (ev) => {
              try {
                if (!rendition || ev.defaultPrevented) return;
                const a = ev.target && ev.target.closest ? ev.target.closest('a') : null;
                if (a) return;
                const sel = doc.defaultView && doc.defaultView.getSelection ? doc.defaultView.getSelection() : null;
                if (sel && String(sel.toString() || '').trim()) return;
                const w = doc.defaultView ? doc.defaultView.innerWidth : 0;
                const x = ev.clientX || 0;
                if (w > 0 && x < w * 0.30) api.prev();
                else if (w > 0 && x > w * 0.70) api.next();
              } catch (e) {}
            }, { passive: true });
          }

          doc.addEventListener('click', async (ev) => {
            try {
              const a = ev.target && ev.target.closest ? ev.target.closest('a') : null;
              if (!a || !isNoteRefLink(a)) return;
              ev.preventDefault();
              ev.stopPropagation();
              const html = await resolveNoteHTMLFromLink(a, doc, baseHref);
              onNote && onNote({ html: html || '', label: getNoteLabelFromHref(a) });
            } catch (e) {}
          }, true);
        });
      }));
    }

    // Hook coquille : filigrane + anti-copie (AnarBib) injectés ici.
    if (!contentHookInstalled && typeof onContent === 'function') {
      contentHookInstalled = true;
      safe(() => rendition.hooks.content.register((contents) => {
        safe(() => onContent({
          doc: contents.document,
          window: contents.window || (contents.document && contents.document.defaultView),
          section: contents.section,
        }));
      }));
    }
  }

  function applyThemeToRendition() {
    if (!rendition) return;
    ensureHooks();
    safe(() => {
      rendition.themes.register('app', { a: { color: theme.link } });
      rendition.themes.select('app');
    });
    safe(() => rendition.themes.fontSize(prefs.fontPct + '%'));
    updateAllContentsHardStyle();
  }

  // ════════════════════════════════════════════════════════════════
  // FLUX / DOUBLE-PAGE
  // ════════════════════════════════════════════════════════════════
  function isDesktopForSpread() {
    try {
      const fine = window.matchMedia && window.matchMedia('(pointer:fine)').matches;
      return fine && window.innerWidth >= DESKTOP_SPREAD_MIN;
    } catch (e) { return false; }
  }
  function desiredSpread() {
    return (prefs.spread && isDesktopForSpread()) ? 'auto' : 'none';
  }

  async function applyFlow(keepLocation = true) {
    if (!rendition) return;
    let cfi = null;
    if (keepLocation) safe(() => {
      const loc = rendition.currentLocation && rendition.currentLocation();
      cfi = loc && loc.start && loc.start.cfi ? loc.start.cfi : null;
    });
    safe(() => rendition.spread(desiredSpread()));
    safe(() => rendition.flow(FLOW_MODE));
    if (cfi) { try { await rendition.display(cfi); } catch (e) {} }
    safe(() => rendition.resize());
  }

  // ════════════════════════════════════════════════════════════════
  // LOCATIONS / PROGRESSION
  // ════════════════════════════════════════════════════════════════
  async function ensureLocations(cached) {
    if (!book || !book.locations) return false;
    try {
      if (book.ready) await book.ready;
      if (typeof book.locations.length === 'function' && book.locations.length() > 0) return true;

      if (cached) {
        book.locations.load(cached);
        if (book.locations.length() > 0) return true;
      }

      onLocationsState && onLocationsState({ ready: false, generating: true });
      await book.locations.generate(1024);
      const saved = book.locations.save();
      onLocationsGenerated && onLocationsGenerated(saved);
      return typeof book.locations.length === 'function' && book.locations.length() > 0;
    } catch (e) { return false; }
  }

  function percentFromLocation(location) {
    const displayed = location && location.start && location.start.displayed;
    const p = location && location.start && location.start.percentage;
    if (typeof p === 'number' && isFinite(p)) {
      const pp = Math.max(0, Math.min(1, p));
      if (!(displayed && displayed.page && displayed.total && displayed.page < displayed.total && pp > 0.99)) return pp;
    }
    const cfi = location && location.start && location.start.cfi;
    if (!cfi || !book || !book.locations || typeof book.locations.length !== 'function') return null;
    if (book.locations.length() === 0) return null;
    if (typeof book.locations.percentageFromCfi === 'function') {
      const px = book.locations.percentageFromCfi(cfi);
      if (typeof px === 'number' && isFinite(px)) {
        const pp = Math.max(0, Math.min(1, px));
        if (displayed && displayed.page && displayed.total && displayed.page < displayed.total && pp > 0.99) return null;
        return pp;
      }
    }
    return null;
  }

  function emitRelocate(location) {
    const displayed = location && location.start && location.start.displayed;
    onRelocate && onRelocate({
      cfi: location && location.start ? location.start.cfi : null,
      percent: percentFromLocation(location),
      page: displayed && displayed.page ? displayed.page : null,
      total: displayed && displayed.total ? displayed.total : null,
    });
  }

  // ════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ════════════════════════════════════════════════════════════════
  function hasSelection() {
    try {
      if (rendition && typeof rendition.getContents === 'function') {
        const list = rendition.getContents() || [];
        for (const c of list) {
          const w = c && c.window;
          if (!w || !w.getSelection) continue;
          const sel = w.getSelection();
          if (sel && String(sel.toString() || '').trim()) return true;
        }
      }
      return false;
    } catch (e) { return false; }
  }
  function getSafeLocation() { try { return rendition && rendition.currentLocation ? rendition.currentLocation() : null; } catch (e) { return null; } }
  function locSig(loc) {
    const idx = loc && loc.start ? loc.start.index : null;
    const cfi = loc && loc.start ? loc.start.cfi : null;
    return String(idx) + '|' + String(cfi || '');
  }
  async function goToSpineIndex(index) {
    if (!book || !rendition) return false;
    try {
      const items = book.spine && book.spine.items ? book.spine.items : [];
      const it = (index != null && index >= 0 && index < items.length) ? items[index] : null;
      if (!it) return false;
      await rendition.display(it.href);
      return true;
    } catch (e) { return false; }
  }
  async function forceNextSpine() {
    const loc = getSafeLocation();
    const idx = loc && loc.start ? loc.start.index : null;
    if (idx == null) return false;
    return await goToSpineIndex(idx + 1);
  }
  async function forcePrevSpine() {
    const loc = getSafeLocation();
    const idx = loc && loc.start ? loc.start.index : null;
    if (idx == null) return false;
    return await goToSpineIndex(idx - 1);
  }

  // ════════════════════════════════════════════════════════════════
  // TEMPS DE LECTURE (rafLoop par tranches de 30 s)
  // ════════════════════════════════════════════════════════════════
  function isReadingActive() {
    return !destroyed && !!book && (typeof document === 'undefined' || document.visibilityState === 'visible');
  }
  function commitChunks() {
    const chunks = Math.floor(carryMs / CHUNK_MS);
    if (chunks > 0) {
      readingSeconds += chunks * 30;
      carryMs -= chunks * CHUNK_MS;
      onTick && onTick(readingSeconds);
    }
  }
  function rafLoop(ts) {
    if (lastTs === null) lastTs = ts;
    let dt = ts - lastTs;
    lastTs = ts;
    if (!Number.isFinite(dt) || dt < 0) dt = 0;
    if (dt > 5000) dt = 0;
    if (isReadingActive()) { carryMs += dt; commitChunks(); }
    rafId = requestAnimationFrame(rafLoop);
  }
  function startTimer() {
    stopTimer();
    carryMs = 0; lastTs = null;
    rafId = requestAnimationFrame(rafLoop);
  }
  function stopTimer() {
    if (rafId) cancelAnimationFrame(rafId);
    rafId = null;
    commitChunks();
    carryMs = 0; lastTs = null;
  }
  function onVisibility() { lastTs = null; }

  // ════════════════════════════════════════════════════════════════
  // API PUBLIQUE
  // ════════════════════════════════════════════════════════════════
  const api = {
    async open(bookData, openOpts = {}) {
      clear();
      readingSeconds = Number(openOpts.initialSeconds) || 0;
      locationsReady = false;

      let arrayBuffer = bookData;
      if (bookData instanceof Blob) arrayBuffer = await bookData.arrayBuffer();

      try {
        book = ePub(arrayBuffer);
        langHookInstalled = hardCssHookInstalled = noteHookInstalled = contentHookInstalled = false;

        const locPromise = (book.ready ? book.ready.then(() => ensureLocations(openOpts.locations)) : ensureLocations(openOpts.locations));
        locPromise.then((ok) => {
          locationsReady = !!ok;
          onLocationsState && onLocationsState({ ready: !!ok, generating: false });
        }).catch(() => { locationsReady = false; onLocationsState && onLocationsState({ ready: false, generating: false }); });

        rendition = book.renderTo(container, { width: '100%', height: '100%', spread: 'none' });

        applyThemeToRendition();
        await applyFlow(false);

        rendition.on('relocated', (location) => { emitRelocate(location); });
        rendition.on('rendered', () => { applyThemeToRendition(); });

        const startCfi = openOpts.startCfi;
        if (startCfi) {
          try { await rendition.display(startCfi); }
          catch (e) { try { await rendition.display(); } catch (_) {} }
        } else {
          try { await rendition.display(); } catch (e) {}
        }
        applyThemeToRendition();
        await applyFlow(true);

        try {
          await locPromise;
          const loc = getSafeLocation();
          if (loc) emitRelocate(loc);
        } catch (e) {}

        if (typeof document !== 'undefined') document.addEventListener('visibilitychange', onVisibility);
        startTimer();
        onReady && onReady();
      } catch (err) {
        emitErr(err);
        throw err;
      }
    },

    setTheme(next = {}) { theme = { ...theme, ...next }; applyThemeToRendition(); },
    getTheme() { return { ...theme }; },

    setPrefs(next = {}) {
      const prevFont = prefs.fontPct;
      prefs = { ...prefs, ...next };
      if (next.fontPct != null && next.fontPct !== prevFont) safe(() => rendition && rendition.themes.fontSize(prefs.fontPct + '%'));
      applyThemeToRendition();
      if (next.spread != null) applyFlow(true);
    },
    getPrefs() { return { ...prefs }; },

    next() { return safeNav('next', () => rendition && rendition.next()); },
    prev() { return safeNav('prev', () => rendition && rendition.prev()); },

    async chapterStart() {
      if (!rendition || !book) return;
      const loc = getSafeLocation();
      const idx = loc && loc.start ? loc.start.index : null;
      if (idx != null) await goToSpineIndex(idx);
    },
    async chapterEnd() {
      if (!rendition || !book) return;
      const loc0 = getSafeLocation();
      const idx0 = loc0 && loc0.start ? loc0.start.index : null;
      if (idx0 == null) return;
      let lastSig = locSig(loc0);
      for (let i = 0; i < 220; i++) {
        try { await rendition.next(); } catch (e) {}
        const loc = getSafeLocation();
        const sig = locSig(loc);
        const idx = loc && loc.start ? loc.start.index : null;
        if (idx != null && idx !== idx0) { try { await rendition.prev(); } catch (e) {} break; }
        if (sig === lastSig) break;
        lastSig = sig;
      }
    },

    async goToCfi(cfi) { if (rendition && cfi) { try { await rendition.display(cfi); } catch (e) {} } },
    async goToHref(href) { if (rendition && href) { try { await rendition.display(href); } catch (e) {} } },
    async jumpToPercent(percent01) {
      if (!rendition || !book || !book.locations || !locationsReady) return;
      const p = Math.max(0, Math.min(1, Number(percent01) || 0));
      if (typeof book.locations.cfiFromPercentage === 'function') {
        const cfi = book.locations.cfiFromPercentage(p);
        if (cfi) { try { await rendition.display(cfi); } catch (e) {} }
      }
    },

    async getToc() {
      try {
        const nav = book && book.loaded && book.loaded.navigation ? await book.loaded.navigation : (book && book.navigation);
        const toc = nav && nav.toc ? nav.toc : [];
        return flattenToc(toc, 0, []);
      } catch (e) { return []; }
    },

    isLocationsReady() { return locationsReady; },
    getReadingSeconds() { return readingSeconds; },

    destroy() {
      if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', onVisibility);
      stopTimer();
      clear();
      destroyed = true;
    },
  };

  async function safeNav(dir, navFn) {
    if (!rendition || hasSelection()) return;
    const before = locSig(getSafeLocation());
    try { await navFn(); } catch (e) {}
    setTimeout(async () => {
      const after = locSig(getSafeLocation());
      if (after === before) { if (dir === 'next') await forceNextSpine(); else await forcePrevSpine(); }
    }, 60);
  }

  function flattenToc(list, level, out) {
    level = level || 0; out = out || [];
    if (!Array.isArray(list)) return out;
    for (const item of list) {
      if (!item) continue;
      out.push({ label: item.label || item.title || '—', href: item.href || '', level });
      if (Array.isArray(item.subitems) && item.subitems.length) flattenToc(item.subitems, level + 1, out);
    }
    return out;
  }

  function clear() {
    if (rendition) { safe(() => rendition.destroy()); rendition = null; }
    if (book) { safe(() => book.destroy && book.destroy()); book = null; }
    safe(() => { if (container) container.innerHTML = ''; });
  }

  return api;
}

export default createEpubEngine;
