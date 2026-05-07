import { useState, useEffect, useRef, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useParams, useSearchParams, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell } from '@/components/layout';
import { Button, Pill, Spinner, EmptyState } from '@/components/ui';
import './ReaderPage.css';

const SUPABASE_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
const PDFJS_BASE = import.meta.env.BASE_URL + 'vendor/pdfjs/build';
const PDFJS_ASSETS_BASE = import.meta.env.BASE_URL + 'vendor/pdfjs/web/';
const PDFJS_CMAPS_URL = PDFJS_ASSETS_BASE + 'cmaps/';
const PDFJS_STANDARD_FONTS_URL = PDFJS_ASSETS_BASE + 'standard_fonts/';
const PDFJS_WASM_URL = PDFJS_ASSETS_BASE + 'wasm/';
const PDFJS_ICCS_URL = PDFJS_ASSETS_BASE + 'iccs/';

// ═══════════════════════════════════════════════════════════
// Protection anti-copie SCOPÉE au viewer
// ═══════════════════════════════════════════════════════════
//
// v2.1 : on attache au document (capture phase) et on filtre par
// containment. Avantages :
//  - marche même si viewerRef.current est encore null au moment où le
//    useEffect s'exécute (le test se fait au moment de l'event, pas du mount)
//  - capture phase : on intercepte avant que le canvas ait pu poser son
//    propre handler bloquant
//  - le filtre `viewerRef.current?.contains(e.target)` garantit que clic
//    droit / drag / copy restent libres en dehors du viewer
//
// Limites connues : F12 et PrintScreen ne sont pas réellement bloquables
// dans un navigateur ; ces interceptions sont du décourageant, pas du DRM.

function useViewerCopyProtection(viewerRef) {
  useEffect(() => {
    function inViewer(e) {
      const node = viewerRef.current;
      return Boolean(node && e.target && node.contains(e.target));
    }
    function block(e) {
      if (!inViewer(e)) return;
      e.preventDefault();
      e.stopPropagation();
    }
    function blockKeys(e) {
      // Pour les raccourcis on ne teste pas le containment — ils s'appliquent
      // dès que le focus est dans le document, donc on ne bloque que si le
      // viewer est dans la page (peu importe l'élément actif).
      if (!viewerRef.current) return;
      const k = (e.key || '').toLowerCase();
      if (
        (e.ctrlKey && !e.shiftKey && ['s','p','a','c','u'].includes(k)) ||
        (e.ctrlKey && e.shiftKey && ['i','j','c'].includes(k)) ||
        k === 'f12' || k === 'printscreen'
      ) {
        e.preventDefault();
        e.stopPropagation();
      }
    }

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

// ═══════════════════════════════════════════════════════════
// Chargement pdf.js local ESM
// ═══════════════════════════════════════════════════════════

let pdfjsPromise = null;
function loadPdfJs() {
  if (pdfjsPromise) return pdfjsPromise;
  pdfjsPromise = (async () => {
    if (window.__pdfjsLib) return window.__pdfjsLib;
    const lib = await import(/* @vite-ignore */ `${PDFJS_BASE}/pdf.mjs`);
    lib.GlobalWorkerOptions.workerSrc = `${PDFJS_BASE}/pdf.worker.mjs`;
    window.__pdfjsLib = lib;
    return lib;
  })();
  return pdfjsPromise;
}

// ═══════════════════════════════════════════════════════════

export default function ReaderPage() {
  const { formatMessage: t } = useIntl();
  const { id } = useParams();
  const [params] = useSearchParams();
  const { user } = useAuth();
  const { libraryName } = useLibrary();

  const publicBucket = params.get('public_bucket');
  const publicPath = params.get('public_path');
  // ── Stabilisation : on ne dépend que de l'identifiant utilisateur,
  // pas de l'objet `user` entier (qui change de référence à chaque
  // re-vérification de session Supabase au focus de l'onglet).
  const userId = user?.id || null;
  const userEmail = user?.email || '';

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [assetMeta, setAssetMeta] = useState(null);
  const [bookTitle, setBookTitle] = useState('');

  const [pdfDoc, setPdfDoc] = useState(null);
  const [totalPages, setTotalPages] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [scale, setScale] = useState(1.2);
  const [fitWidth, setFitWidth] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);

  const viewerRef = useRef(null);    // conteneur viewer entier (scope anti-copie + fullscreen)
  const scrollRef = useRef(null);    // le conteneur scrollable
  const pagesRef = useRef(null);     // le div qui contient les page-wraps
  const renderedRef = useRef(new Set());
  const renderingRef = useRef(new Set());
  const observerRef = useRef(null);

  useViewerCopyProtection(viewerRef);

  // ── Chargement du PDF ────────────────────────────────────

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError('');
      setPdfDoc(null);
      setTotalPages(0);
      setCurrentPage(1);
      renderedRef.current = new Set();
      renderingRef.current = new Set();

      try {
        if (id) {
          const { data } = await supabase.from('books').select('titulo').eq('id', id).maybeSingle();
          if (data && !cancelled) setBookTitle(data.titulo || '');
        }

        const bookId = Number(id) || 0;
        let pdfUrl = '';

        if (bookId > 0) {
          try {
            const rpc = await supabase.rpc('get_book_primary_public_digital_asset_v2', { p_book_id: bookId });
            const row = Array.isArray(rpc.data) ? rpc.data?.[0] : rpc.data;
            if (row && !cancelled) {
              setAssetMeta(row);
              if (row.storage_bucket && row.storage_path)
                pdfUrl = `${SUPABASE_URL}/storage/v1/object/public/${row.storage_bucket}/${row.storage_path}`;
            }
          } catch {}
        }

        if (!pdfUrl && publicBucket && publicPath)
          pdfUrl = `${SUPABASE_URL}/storage/v1/object/public/${publicBucket}/${publicPath}`;

        if (!pdfUrl) { if (!cancelled) setError(t({id:'reader.error.noPdf'})); return; }

        const pdfjsLib = await loadPdfJs();
        if (cancelled) return;

        // Charger en blob pour ne pas exposer l'URL
        const response = await fetch(pdfUrl);
        if (!response.ok) throw new Error(`Erro ${response.status}`);
        const blob = await response.blob();
        const blobUrl = URL.createObjectURL(blob);

        const doc = await pdfjsLib.getDocument({
          url: blobUrl,
          cMapUrl: PDFJS_CMAPS_URL,
          cMapPacked: true,
          standardFontDataUrl: PDFJS_STANDARD_FONTS_URL,
          wasmUrl: PDFJS_WASM_URL,
          iccUrl: PDFJS_ICCS_URL,
          useSystemFonts: false,
          disableAutoFetch: true,
          disableStream: true,
        }).promise;

        if (cancelled) { URL.revokeObjectURL(blobUrl); return; }

        setPdfDoc(doc);
        setTotalPages(doc.numPages);
        URL.revokeObjectURL(blobUrl);
      } catch (err) {
        if (!cancelled) setError(`Erro ao abrir a leitura: ${err.message}`);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
    // userId au lieu de user : évite le rechargement du PDF au focus de l'onglet
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, publicBucket, publicPath, userId]);

  // ── Calcul de l'échelle effective (fit-width vs zoom manuel) ─

  const computeEffectiveScale = useCallback(async (page) => {
    if (!fitWidth || !scrollRef.current) return scale;
    const baseViewport = page.getViewport({ scale: 1 });
    const padding = 32;
    const availW = scrollRef.current.clientWidth - padding;
    return availW / baseViewport.width;
  }, [scale, fitWidth]);

  // ── Rendu d'une page sur canvas ──────────────────────────

  const renderPage = useCallback(async (pageNo) => {
    if (!pdfDoc || !pagesRef.current) return;
    const key = `${pageNo}@${scale}@${fitWidth ? 'fw' : 'fz'}`;
    if (renderedRef.current.has(key) || renderingRef.current.has(key)) return;

    const wrap = pagesRef.current.querySelector(`[data-page="${pageNo}"]`);
    if (!wrap) return;

    renderingRef.current.add(key);
    try {
      const page = await pdfDoc.getPage(pageNo);
      const effectiveScale = await computeEffectiveScale(page);
      const viewport = page.getViewport({ scale: effectiveScale });

      const canvas = document.createElement('canvas');
      const ctx = canvas.getContext('2d', { alpha: false });
      canvas.width = Math.ceil(viewport.width);
      canvas.height = Math.ceil(viewport.height);
      canvas.style.display = 'block';
      canvas.style.maxWidth = '100%';
      canvas.style.height = 'auto';
      canvas.oncontextmenu = (e) => e.preventDefault();
      canvas.draggable = false;

      // Placeholder de hauteur pour le wrap (avant render)
      const host = wrap.querySelector('.ab-reader-page-host');
      if (host) {
        host.style.minHeight = `${Math.ceil(viewport.height)}px`;
        host.style.width = `${Math.ceil(viewport.width)}px`;
      }

      await page.render({ canvasContext: ctx, viewport }).promise;

      // Injecter le canvas
      if (host) host.replaceChildren(canvas);
      page.cleanup();
      renderedRef.current.add(key);
    } catch (err) {
      console.warn(`Render page ${pageNo} failed:`, err);
    } finally {
      renderingRef.current.delete(key);
    }
  }, [pdfDoc, scale, fitWidth, computeEffectiveScale]);

  // ── IntersectionObserver pour le rendu au scroll ─────────

  useEffect(() => {
    if (!pdfDoc || !pagesRef.current || !scrollRef.current) return;

    // Nettoyer l'ancien observer
    if (observerRef.current) observerRef.current.disconnect();

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            const pageNo = Number(entry.target.dataset.page);
            if (pageNo > 0) {
              renderPage(pageNo);
              // Render les voisines aussi
              if (pageNo > 1) renderPage(pageNo - 1);
              if (pageNo < totalPages) renderPage(pageNo + 1);
            }
          }
        }
        // Mettre à jour la page courante basée sur la plus visible
        const visible = entries.filter(e => e.isIntersecting);
        if (visible.length > 0) {
          // La page avec le plus grand ratio d'intersection
          const best = visible.reduce((a, b) => b.intersectionRatio > a.intersectionRatio ? b : a);
          const p = Number(best.target.dataset.page);
          if (p > 0) setCurrentPage(p);
        }
      },
      { root: scrollRef.current, rootMargin: '200px 0px', threshold: [0, 0.25, 0.5] }
    );

    observerRef.current = observer;

    // Observer toutes les page-wraps
    const wraps = pagesRef.current.querySelectorAll('[data-page]');
    wraps.forEach((w) => observer.observe(w));

    // Rendre les premières pages immédiatement
    for (let p = 1; p <= Math.min(3, totalPages); p++) renderPage(p);

    return () => observer.disconnect();
  }, [pdfDoc, totalPages, scale, fitWidth, renderPage]);

  // ── Re-render au changement de zoom ou de fit-width ──────

  useEffect(() => {
    renderedRef.current = new Set();
    renderingRef.current = new Set();
    // Re-render les pages visibles
    if (pdfDoc && pagesRef.current) {
      const wraps = pagesRef.current.querySelectorAll('[data-page]');
      wraps.forEach((w) => {
        const host = w.querySelector('.ab-reader-page-host');
        if (host) host.replaceChildren(); // vider le canvas existant
      });
      // Re-render les premières et la courante
      for (let p = Math.max(1, currentPage - 1); p <= Math.min(totalPages, currentPage + 1); p++) renderPage(p);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scale, fitWidth]);

  // ── Re-render sur resize quand fit-width est actif ──────

  useEffect(() => {
    if (!fitWidth) return;
    let timer = null;
    const onResize = () => {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => {
        renderedRef.current = new Set();
        renderingRef.current = new Set();
        if (pdfDoc && pagesRef.current) {
          const wraps = pagesRef.current.querySelectorAll('[data-page]');
          wraps.forEach((w) => {
            const host = w.querySelector('.ab-reader-page-host');
            if (host) host.replaceChildren();
          });
          for (let p = Math.max(1, currentPage - 1); p <= Math.min(totalPages, currentPage + 1); p++) renderPage(p);
        }
      }, 200);
    };
    window.addEventListener('resize', onResize);
    return () => {
      window.removeEventListener('resize', onResize);
      if (timer) clearTimeout(timer);
    };
  }, [fitWidth, pdfDoc, currentPage, totalPages, renderPage]);

  // ── Plein écran ──────────────────────────────────────────

  const toggleFullscreen = useCallback(() => {
    const node = viewerRef.current;
    if (!node) return;
    if (!document.fullscreenElement) {
      if (node.requestFullscreen) node.requestFullscreen();
    } else {
      if (document.exitFullscreen) document.exitFullscreen();
    }
  }, []);

  useEffect(() => {
    const onFsChange = () => {
      setIsFullscreen(Boolean(document.fullscreenElement));
    };
    document.addEventListener('fullscreenchange', onFsChange);
    return () => document.removeEventListener('fullscreenchange', onFsChange);
  }, []);

  // ── Navigation par boutons ───────────────────────────────

  function goToPage(pageNo) {
    const p = Math.min(totalPages, Math.max(1, pageNo));
    setCurrentPage(p);
    // Scroller vers la page
    const wrap = pagesRef.current?.querySelector(`[data-page="${p}"]`);
    if (wrap && scrollRef.current) {
      wrap.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }

  useDocumentTitle(bookTitle || t({ id: 'reader.title' }));

  const wm = userEmail ? `AnarBib · ${libraryName} · ${userEmail}` : `AnarBib · ${libraryName}`;

  // ── Rendu ────────────────────────────────────────────────

  return (
    <PageShell>
      <nav className="ab-reader-nav">
        <div className="ab-reader-nav__left">
          <Link to="/" className="ab-reader-nav__logo">
            <img src="https://cclamazonia.noblogs.org/files/2026/03/AnarBib_logo.png" alt="AnarBib" />
          </Link>
          <div className="ab-reader-nav__title">
            <span className="ab-reader-nav__heading">{t({id:'reader.brand'})}</span>
            {bookTitle && <span className="ab-reader-nav__book">{bookTitle}</span>}
          </div>
        </div>
        <div className="ab-reader-nav__actions">
          <Link to="/" className="ab-button ab-button--secondary ab-button--mini">{t({id:'reader.catalogs'})}</Link>
          {id && <Link to={`/livro/${id}`} className="ab-button ab-button--secondary ab-button--mini">{t({id:'reader.backToBook'})}</Link>}
          {user
            ? <Link to="/conta" className="ab-button ab-button--secondary ab-button--mini">{t({id:'reader.myAccount'})}</Link>
            : <Link to="/cadastro" className="ab-button ab-button--mini">{t({id:'reader.signIn'})}</Link>}
        </div>
      </nav>

      <div className="ab-reader-hero">
        <h1>{bookTitle || t({id:'reader.brand'})}</h1>
        {assetMeta && (
          <div className="ab-reader-meta">
            {assetMeta.source_name && (
              <Pill>{t({id:'reader.source'},{name: assetMeta.source_url
                ? <a href={assetMeta.source_url} target="_blank" rel="noopener noreferrer">{assetMeta.source_name}</a>
                : assetMeta.source_name})}</Pill>
            )}
            {assetMeta.rights_status && <Pill>{assetMeta.rights_status}</Pill>}
          </div>
        )}
      </div>

      {loading ? (
        <div className="ab-reader-loading"><Spinner size={36} /><p>{t({id:'reader.loadingPrep'})}</p></div>
      ) : error ? (
        <div className="ab-reader-error">
          <EmptyState message={error}>
            {!user && <Link to="/cadastro"><Button>{t({id:'reader.loginToAccess'})}</Button></Link>}
            {id && <Link to={`/livro/${id}`}><Button variant="secondary">{t({id:'reader.backToBook'})}</Button></Link>}
          </EmptyState>
        </div>
      ) : pdfDoc ? (
        <div
          ref={viewerRef}
          className={`ab-reader-viewer ${isFullscreen ? 'ab-reader-viewer--fullscreen' : ''}`}
          tabIndex={0}
        >
          {/* Toolbar */}
          <div className="ab-reader-toolbar">
            <div className="ab-reader-toolbar__group">
              {id && <Link to={`/livro/${id}`} className="ab-button ab-button--secondary ab-button--mini">{t({id:'reader.backToBook'})}</Link>}
              <button className="ab-button ab-button--secondary ab-button--mini" onClick={() => window.location.reload()}>{t({id:'reader.reload'})}</button>
            </div>
            <div className="ab-reader-toolbar__group">
              <button className="ab-reader-tb-btn" onClick={() => goToPage(currentPage - 1)} disabled={currentPage <= 1}>{t({id:'reader.prevPage'})}</button>
              <span className="ab-reader-tb-info">
                <input type="number" className="ab-reader-page-input" min={1} max={totalPages} value={currentPage}
                  onChange={(e) => goToPage(parseInt(e.target.value) || 1)} />
                / {totalPages}
              </span>
              <button className="ab-reader-tb-btn" onClick={() => goToPage(currentPage + 1)} disabled={currentPage >= totalPages}>{t({id:'reader.pageNav'})}</button>
            </div>
            <div className="ab-reader-toolbar__group">
              <button
                className="ab-reader-tb-btn"
                onClick={() => { setFitWidth(false); setScale(s => Math.max(0.5, +(s - 0.15).toFixed(2))); }}
                disabled={!fitWidth && scale <= 0.5}
              >
                {t({id:'reader.zoomOut'})}
              </button>
              <button
                className="ab-reader-tb-btn"
                onClick={() => { setFitWidth(false); setScale(s => Math.min(3, +(s + 0.15).toFixed(2))); }}
                disabled={!fitWidth && scale >= 3}
              >
                {t({id:'reader.zoomIn'})}
              </button>
              <span className="ab-reader-tb-info">{fitWidth ? '↔' : `${Math.round(scale * 100)}%`}</span>
              <button
                className={`ab-reader-tb-btn ${fitWidth ? 'ab-reader-tb-btn--active' : ''}`}
                onClick={() => setFitWidth(f => !f)}
                title={t({id:'reader.fitWidth'})}
              >
                {t({id:'reader.fitWidth'})}
              </button>
              <button
                className="ab-reader-tb-btn"
                onClick={toggleFullscreen}
                title={t({id: isFullscreen ? 'reader.fullscreenExit' : 'reader.fullscreen'})}
              >
                {isFullscreen ? '⤡' : '⤢'}
              </button>
            </div>
          </div>

          {/* Sheet */}
          <div className="ab-reader-sheet">
            <div className="ab-reader-sheet__head">
              <span>{t({id:'reader.onlineReading'})}</span>
              {assetMeta?.attribution_text && <span className="ab-reader-sheet__attr">{assetMeta.attribution_text}</span>}
            </div>

            <div className="ab-reader-canvas-container" ref={scrollRef}>
              {/* Filigrane */}
              <div className="ab-reader-watermark" aria-hidden="true">
                {[...Array(6)].map((_, i) => <span key={i}>{wm}</span>)}
              </div>

              {/* Pages */}
              <div className="ab-reader-pages" ref={pagesRef}>
                {[...Array(totalPages)].map((_, i) => (
                  <div key={i} className="ab-reader-page-wrap" data-page={i + 1}>
                    <div className="ab-reader-page-host" />
                    <p className="ab-reader-page-label">{t({id:'reader.page'},{num:i+1})}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <p className="ab-reader-notice">
            {t({id:'reader.notice'})}
          </p>
        </div>
      ) : null}
    </PageShell>
  );
}
