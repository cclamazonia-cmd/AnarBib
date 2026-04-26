import { useState, useEffect, useRef, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { useParams, useSearchParams, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell } from '@/components/layout';
import { Button, Pill, Spinner, EmptyState } from '@/components/ui';
import './ReaderPage.css';

const SUPABASE_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
const PDFJS_BASE = import.meta.env.BASE_URL + 'vendor/pdfjs/build';

// ═══════════════════════════════════════════════════════════
// Protection anti-copie
// ═══════════════════════════════════════════════════════════

function useCopyProtection() {
  useEffect(() => {
    function block(e) { e.preventDefault(); e.stopPropagation(); return false; }
    function blockKeys(e) {
      const k = (e.key || '').toLowerCase();
      if (
        (e.ctrlKey && !e.shiftKey && ['s','p','a','c','u'].includes(k)) ||
        (e.ctrlKey && e.shiftKey && ['i','j','c'].includes(k)) ||
        k === 'f12' || k === 'printscreen'
      ) { e.preventDefault(); e.stopPropagation(); }
    }
    document.addEventListener('contextmenu', block, true);
    window.addEventListener('contextmenu', block, true);
    document.addEventListener('keydown', blockKeys, true);
    document.addEventListener('dragstart', block, true);
    document.addEventListener('copy', block, true);
    document.addEventListener('selectstart', block, true);
    const prev = document.body.oncontextmenu;
    document.body.oncontextmenu = () => false;
    return () => {
      document.removeEventListener('contextmenu', block, true);
      window.removeEventListener('contextmenu', block, true);
      document.removeEventListener('keydown', blockKeys, true);
      document.removeEventListener('dragstart', block, true);
      document.removeEventListener('copy', block, true);
      document.removeEventListener('selectstart', block, true);
      document.body.oncontextmenu = prev;
    };
  }, []);
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

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [assetMeta, setAssetMeta] = useState(null);
  const [bookTitle, setBookTitle] = useState('');

  const [pdfDoc, setPdfDoc] = useState(null);
  const [totalPages, setTotalPages] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [scale, setScale] = useState(1.2);

  const scrollRef = useRef(null);    // le conteneur scrollable
  const pagesRef = useRef(null);     // le div qui contient les page-wraps
  const renderedRef = useRef(new Set());
  const renderingRef = useRef(new Set());
  const observerRef = useRef(null);

  useCopyProtection();

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
          disableAutoFetch: true,
          disableStream: true,
          isEvalSupported: false,
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
  }, [id, publicBucket, publicPath, user]);

  // ── Rendu d'une page sur canvas ──────────────────────────

  const renderPage = useCallback(async (pageNo) => {
    if (!pdfDoc || !pagesRef.current) return;
    const key = `${pageNo}@${scale}`;
    if (renderedRef.current.has(key) || renderingRef.current.has(key)) return;

    const wrap = pagesRef.current.querySelector(`[data-page="${pageNo}"]`);
    if (!wrap) return;

    renderingRef.current.add(key);
    try {
      const page = await pdfDoc.getPage(pageNo);
      const viewport = page.getViewport({ scale });

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
        host.style.maxWidth = '100%';
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
  }, [pdfDoc, scale]);

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
  }, [pdfDoc, totalPages, scale, renderPage]);

  // ── Re-render au changement de zoom ──────────────────────

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
  }, [scale]);

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

  useEffect(() => {
    document.title = bookTitle ? t({id:'reader.pageTitle'},{title:bookTitle}) : t({id:'reader.title'}) + ' — AnarBib';
  }, [bookTitle]);

  const wm = user?.email ? `AnarBib · ${libraryName} · ${user.email}` : `AnarBib · ${libraryName}`;

  // ── Rendu ────────────────────────────────────────────────

  return (
    <PageShell>
      <nav className="ab-reader-nav">
        <div className="ab-reader-nav__left">
          <Link to="/" className="ab-reader-nav__logo">
            <img src="https://cclamazonia.noblogs.org/files/2026/03/AnarBib_logo.png" alt="AnarBib" />
          </Link>
          <div className="ab-reader-nav__title">
            <span className="ab-reader-nav__heading">Leitor PDF</span>
            {bookTitle && <span className="ab-reader-nav__book">{bookTitle}</span>}
          </div>
        </div>
        <div className="ab-reader-nav__actions">
          <Link to="/" className="ab-button ab-button--secondary ab-button--mini">Catálogos</Link>
          {id && <Link to={`/livro/${id}`} className="ab-button ab-button--secondary ab-button--mini">Voltar ao livro</Link>}
          {user
            ? <Link to="/conta" className="ab-button ab-button--secondary ab-button--mini">Minha conta</Link>
            : <Link to="/cadastro" className="ab-button ab-button--mini">Entrar</Link>}
        </div>
      </nav>

      <div className="ab-reader-hero">
        <h1>{bookTitle || 'Leitor PDF'}</h1>
        {assetMeta && (
          <div className="ab-reader-meta">
            {assetMeta.source_name && (
              <Pill>Fonte: {assetMeta.source_url
                ? <a href={assetMeta.source_url} target="_blank" rel="noopener noreferrer">{assetMeta.source_name}</a>
                : assetMeta.source_name}</Pill>
            )}
            {assetMeta.rights_status && <Pill>{assetMeta.rights_status}</Pill>}
          </div>
        )}
      </div>

      {loading ? (
        <div className="ab-reader-loading"><Spinner size={36} /><p>Preparando a leitura…</p></div>
      ) : error ? (
        <div className="ab-reader-error">
          <EmptyState message={error}>
            {!user && <Link to="/cadastro"><Button>{t({id:'reader.loginToAccess'})}</Button></Link>}
            {id && <Link to={`/livro/${id}`}><Button variant="secondary">{t({id:'reader.backToBook'})}</Button></Link>}
          </EmptyState>
        </div>
      ) : pdfDoc ? (
        <div className="ab-reader-viewer">
          {/* Toolbar */}
          <div className="ab-reader-toolbar">
            <div className="ab-reader-toolbar__group">
              {id && <Link to={`/livro/${id}`} className="ab-button ab-button--secondary ab-button--mini">Voltar ao livro</Link>}
              <button className="ab-button ab-button--secondary ab-button--mini" onClick={() => window.location.reload()}>Recarregar</button>
            </div>
            <div className="ab-reader-toolbar__group">
              <button className="ab-reader-tb-btn" onClick={() => goToPage(currentPage - 1)} disabled={currentPage <= 1}>← Página</button>
              <span className="ab-reader-tb-info">
                <input type="number" className="ab-reader-page-input" min={1} max={totalPages} value={currentPage}
                  onChange={(e) => goToPage(parseInt(e.target.value) || 1)} />
                / {totalPages}
              </span>
              <button className="ab-reader-tb-btn" onClick={() => goToPage(currentPage + 1)} disabled={currentPage >= totalPages}>{t({id:'reader.pageNav'})}</button>
            </div>
            <div className="ab-reader-toolbar__group">
              <button className="ab-reader-tb-btn" onClick={() => setScale(s => Math.max(0.5, +(s - 0.15).toFixed(2)))}>− Zoom</button>
              <button className="ab-reader-tb-btn" onClick={() => setScale(s => Math.min(3, +(s + 0.15).toFixed(2)))}>+ Zoom</button>
              <span className="ab-reader-tb-info">{Math.round(scale * 100)}%</span>
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
            Este conteúdo é disponibilizado para leitura em linha pela rede AnarBib.
            A reprodução não autorizada é proibida.
          </p>
        </div>
      ) : null}
    </PageShell>
  );
}
