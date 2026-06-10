import { useState, useEffect, useRef, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useParams, useSearchParams, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell } from '@/components/layout';
import { Button, Pill, Spinner, EmptyState } from '@/components/ui';
import { LocaleSwitcher } from '@/components/LocaleSwitcher';
import AudioPlayer from '@/components/viewers/AudioPlayer';
import VideoPlayer from '@/components/viewers/VideoPlayer';
import ImageViewer from '@/components/viewers/ImageViewer';
import './ReaderPage.css';

const SUPABASE_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
const EDGE_URL = `${SUPABASE_URL}/functions/v1/read-digital-asset`;
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
//
// Note v3 : pour les viewers Audio/Video/Image qui ont leur propre
// scope anti-copie interne, ce hook reste actif mais redondant. Pas de
// dégât : les listeners sont identiques, les preventDefault aussi.

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
// ReaderPage — lecteur multi-format de la rede AnarBib
// ═══════════════════════════════════════════════════════════
//
// v3.0 (2026-05-08) : ReaderPage devient le lecteur multi-format
// unique de l'application. Dispatch sur viewer_kind retourné par
// l'Edge Function read-digital-asset :
//   - pdf            → rendu interne avec scroll continu + filigrane
//                      (logique préservée de v2.1, c'est l'atout
//                      politique de cette page)
//   - audio          → <AudioPlayer />
//   - video          → <VideoPlayer />
//   - image          → <ImageViewer />
//   - external_link  → notice + lien externe
//   - generic        → fallback ouverture nouvelle fenêtre
//
// La nav custom, le filigrane (wm = AnarBib · libraryName · userEmail),
// et le scroll continu PDF restent intacts. Le LocaleSwitcher est
// désormais accessible aussi depuis cette page.

export default function ReaderPage() {
  const { formatMessage: t } = useIntl();
  const { id } = useParams();
  const [params] = useSearchParams();
  const { user } = useAuth();
  const { libraryName } = useLibrary();

  const publicBucket = params.get('public_bucket');
  const publicPath = params.get('public_path');
  const queryAssetId = params.get('asset_id') || params.get('assetId');
  // Stabilisation : on ne dépend que de l'identifiant utilisateur,
  // pas de l'objet `user` entier (qui change de référence à chaque
  // re-vérification de session Supabase au focus de l'onglet).
  const userId = user?.id || null;
  const userEmail = user?.email || '';

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [assetMeta, setAssetMeta] = useState(null);
  const [bookTitle, setBookTitle] = useState('');

  // Dispatch multi-format
  const [viewerKind, setViewerKind] = useState(null);  // 'pdf' | 'audio' | 'video' | 'image' | 'external_link' | 'generic'
  const [accessUrl, setAccessUrl] = useState('');
  const [resolvedAssetId, setResolvedAssetId] = useState(null);
  // Book ID résolu : soit l'URL `:id`, soit déduit de la réponse Edge Function.
  // Utilisé pour les liens "Voltar à ficha do livro" quand on arrive par
  // /ler-recurso?asset_id=X (legacy) sans :id dans l'URL.
  const [resolvedBookId, setResolvedBookId] = useState(null);

  // PDF-specific (legacy state, n'est rempli que si viewerKind === 'pdf')
  const [pdfDoc, setPdfDoc] = useState(null);
  const [totalPages, setTotalPages] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [scale, setScale] = useState(1.2);
  const [fitWidth, setFitWidth] = useState(false);

  // Plein écran (PDF uniquement ; les autres viewers gèrent en interne)
  const [isFullscreen, setIsFullscreen] = useState(false);

  const viewerRef = useRef(null);
  const scrollRef = useRef(null);
  const pagesRef = useRef(null);
  const renderedRef = useRef(new Set());
  const renderingRef = useRef(new Set());
  const observerRef = useRef(null);

  useViewerCopyProtection(viewerRef);

  // ── Chargement de l'asset (multi-format via Edge Function) ─

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError('');
      setPdfDoc(null);
      setTotalPages(0);
      setCurrentPage(1);
      setViewerKind(null);
      setAccessUrl('');
      setResolvedAssetId(null);
      setResolvedBookId(null);
      renderedRef.current = new Set();
      renderingRef.current = new Set();

      try {
        // Récupérer le titre du livre si l'id est fourni en URL
        if (id) {
          const { data } = await supabase.from('books').select('titulo').eq('id', id).maybeSingle();
          if (data && !cancelled) setBookTitle(data.titulo || '');
        }

        // ── Détermination de l'asset_id à charger ───────────
        // Priorité : query (?asset_id=) > primary_public via book_id
        let assetIdToLoad = queryAssetId ? Number(queryAssetId) : null;
        const bookId = Number(id) || 0;

        if (!assetIdToLoad && bookId > 0) {
          // Pas d'asset_id explicite : on demande à la RPC l'asset
          // primaire public du livre
          try {
            const rpc = await supabase.rpc('get_book_primary_public_digital_asset_v2', { p_book_id: bookId });
            const row = Array.isArray(rpc.data) ? rpc.data?.[0] : rpc.data;
            if (row?.asset_id) {
              assetIdToLoad = Number(row.asset_id);
            } else if (row && row.storage_bucket && row.storage_path) {
              // Fallback : on a un row mais pas d'asset_id explicite
              // (RPC ancienne forme ?). On fabrique l'URL publique
              // directement et on assume que c'est un PDF.
              if (!cancelled) {
                setAssetMeta(row);
                setViewerKind('pdf');
                setAccessUrl(`${SUPABASE_URL}/storage/v1/object/public/${row.storage_bucket}/${row.storage_path}`);
              }
              return await loadPdfFromUrl(`${SUPABASE_URL}/storage/v1/object/public/${row.storage_bucket}/${row.storage_path}`);
            }
          } catch {
            // continue vers fallback
          }
        }

        // ── Mode legacy ?public_bucket=&public_path= ────────
        // Si on n'a pas d'asset_id et qu'on a les params legacy, on
        // assume un PDF public (c'est le contrat de l'ancien lien)
        if (!assetIdToLoad && publicBucket && publicPath) {
          if (cancelled) return;
          setViewerKind('pdf');
          const legacyUrl = `${SUPABASE_URL}/storage/v1/object/public/${publicBucket}/${publicPath}`;
          setAccessUrl(legacyUrl);
          return await loadPdfFromUrl(legacyUrl);
        }

        if (!assetIdToLoad) {
          if (!cancelled) setError(t({ id: 'reader.error.noPdf' }));
          return;
        }

        if (!cancelled) setResolvedAssetId(assetIdToLoad);

        // ── Appel à l'Edge Function read-digital-asset ──────
        // Note CORS : la fonction n'autorise que 'authorization' et
        // 'content-type' dans Access-Control-Allow-Headers. On évite
        // donc d'envoyer un header 'apikey' qui ferait échouer le
        // preflight (constaté en session 3 — le header apikey est
        // superflu dès lors qu'on passe Authorization: Bearer <token>).
        const { data: sessionData } = await supabase.auth.getSession();
        const token = sessionData?.session?.access_token;
        const apiKey = import.meta.env.VITE_SUPABASE_ANON_KEY || '';
        const headers = { 'Content-Type': 'application/json' };
        if (token) {
          headers['Authorization'] = `Bearer ${token}`;
        } else if (apiKey) {
          headers['Authorization'] = `Bearer ${apiKey}`;
        }

        const res = await fetch(EDGE_URL, {
          method: 'POST',
          headers,
          body: JSON.stringify({ asset_id: assetIdToLoad }),
        });

        if (!res.ok) {
          const text = await res.text();
          throw new Error(`${res.status}: ${text || 'Edge function error'}`);
        }

        const payload = await res.json();
        if (!payload.ok) throw new Error(payload.error || 'Asset not accessible');

        if (cancelled) return;
        setAssetMeta(payload.asset || null);
        setViewerKind(payload.viewer_kind || 'generic');
        setAccessUrl(payload.access_url || '');

        // Si on n'avait pas de :id dans l'URL (mode /ler-recurso?asset_id=X),
        // on déduit le book_id depuis la réponse Edge et on récupère
        // le titre maintenant qu'on le connaît.
        const apiBookId = payload.asset?.book_id ? Number(payload.asset.book_id) : null;
        if (apiBookId && !cancelled) {
          setResolvedBookId(apiBookId);
          if (!bookTitle && !id) {
            try {
              const { data: bookData } = await supabase
                .from('books')
                .select('titulo')
                .eq('id', apiBookId)
                .maybeSingle();
              if (bookData && !cancelled) setBookTitle(bookData.titulo || '');
            } catch {
              // ignore : le titre reste vide, pas bloquant
            }
          }
        }

        // Pour le PDF : déclencher le chargement pdfjs
        if (payload.viewer_kind === 'pdf' && payload.access_url) {
          await loadPdfFromUrl(payload.access_url);
        }
      } catch (err) {
        if (!cancelled) setError(`${t({ id: 'reader.errorOpening' })}: ${localizeError(err, t)}`);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    // Charge un PDF depuis une URL en blob et initialise pdfjs.
    // Définie en interne pour partager le scope de cancelled, et
    // appelée depuis 3 endroits (RPC primary, mode legacy, Edge).
    async function loadPdfFromUrl(pdfUrl) {
      const pdfjsLib = await loadPdfJs();
      if (cancelled) return;
      const response = await fetch(pdfUrl);
      if (!response.ok) throw new Error(`${response.status}`);
      const blob = await response.blob();
      const blobUrl = URL.createObjectURL(blob);
      try {
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
        if (cancelled) return;
        setPdfDoc(doc);
        setTotalPages(doc.numPages);
      } finally {
        URL.revokeObjectURL(blobUrl);
      }
    }

    return () => { cancelled = true; };
    // userId au lieu de user : évite le rechargement au focus de l'onglet
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, publicBucket, publicPath, queryAssetId, userId]);

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

    if (observerRef.current) observerRef.current.disconnect();

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            const pageNo = Number(entry.target.dataset.page);
            if (pageNo > 0) {
              renderPage(pageNo);
              if (pageNo > 1) renderPage(pageNo - 1);
              if (pageNo < totalPages) renderPage(pageNo + 1);
            }
          }
        }
        const visible = entries.filter(e => e.isIntersecting);
        if (visible.length > 0) {
          const best = visible.reduce((a, b) => b.intersectionRatio > a.intersectionRatio ? b : a);
          const p = Number(best.target.dataset.page);
          if (p > 0) setCurrentPage(p);
        }
      },
      { root: scrollRef.current, rootMargin: '200px 0px', threshold: [0, 0.25, 0.5] }
    );

    observerRef.current = observer;

    const wraps = pagesRef.current.querySelectorAll('[data-page]');
    wraps.forEach((w) => observer.observe(w));

    for (let p = 1; p <= Math.min(3, totalPages); p++) renderPage(p);

    return () => observer.disconnect();
  }, [pdfDoc, totalPages, scale, fitWidth, renderPage]);

  // ── Re-render au changement de zoom ou de fit-width ──────

  useEffect(() => {
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

  // ── Plein écran (PDF uniquement) ─────────────────────────

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
    const onFsChange = () => setIsFullscreen(Boolean(document.fullscreenElement));
    document.addEventListener('fullscreenchange', onFsChange);
    return () => document.removeEventListener('fullscreenchange', onFsChange);
  }, []);

  // ── Navigation par boutons (PDF) ─────────────────────────

  function goToPage(pageNo) {
    const p = Math.min(totalPages, Math.max(1, pageNo));
    setCurrentPage(p);
    const wrap = pagesRef.current?.querySelector(`[data-page="${p}"]`);
    if (wrap && scrollRef.current) {
      wrap.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }

  useDocumentTitle(bookTitle || t({ id: 'reader.title' }));

  // Filigrane email/timestamp pour identifier l'utilisateur connecté
  // (passé en prop aux viewers Audio/Video/Image, et utilisé inline
  // pour le PDF dans la canvas-container).
  const wm = userEmail
    ? `AnarBib · ${libraryName} · ${userEmail}`
    : `AnarBib · ${libraryName}`;

  // Clé de bookmark pour les viewers temporels (audio/video).
  // On utilise l'asset_id résolu pour avoir une clé stable.
  const bookmarkKey = resolvedAssetId ? `asset-${resolvedAssetId}` : null;

  // Book ID effectif pour les liens "Voltar à ficha do livro".
  // Priorité : :id en URL > book_id déduit de la réponse Edge Function
  // (utile quand on arrive par /ler-recurso?asset_id=X sans :id).
  const effectiveBookId = id || resolvedBookId;

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
          {effectiveBookId && <Link to={`/livro/${effectiveBookId}`} className="ab-button ab-button--secondary ab-button--mini">{t({id:'reader.backToBook'})}</Link>}
          {user
            ? <Link to="/conta" className="ab-button ab-button--secondary ab-button--mini">{t({id:'reader.myAccount'})}</Link>
            : <Link to="/cadastro" className="ab-button ab-button--mini">{t({id:'reader.signIn'})}</Link>}
          {/* Sélecteur de langue accessible aussi sur la page de lecture */}
          <LocaleSwitcher variant="header" />
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
            {effectiveBookId && <Link to={`/livro/${effectiveBookId}`}><Button variant="secondary">{t({id:'reader.backToBook'})}</Button></Link>}
          </EmptyState>
        </div>
      ) : viewerKind === 'pdf' && pdfDoc ? (
        // ────────────────────────────────────────────────────
        // PDF — rendu interne avec scroll continu (legacy v2.1)
        // ────────────────────────────────────────────────────
        <div
          ref={viewerRef}
          className={`ab-reader-viewer ${isFullscreen ? 'ab-reader-viewer--fullscreen' : ''}`}
          tabIndex={0}
        >
          <div className="ab-reader-toolbar">
            <div className="ab-reader-toolbar__group">
              {effectiveBookId && <Link to={`/livro/${effectiveBookId}`} className="ab-button ab-button--secondary ab-button--mini">{t({id:'reader.backToBook'})}</Link>}
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

          <div className="ab-reader-sheet">
            <div className="ab-reader-sheet__head">
              <span>{t({id:'reader.onlineReading'})}</span>
              {assetMeta?.attribution_text && <span className="ab-reader-sheet__attr">{assetMeta.attribution_text}</span>}
            </div>

            <div className="ab-reader-canvas-container" ref={scrollRef}>
              <div className="ab-reader-watermark" aria-hidden="true">
                {[...Array(6)].map((_, i) => <span key={i}>{wm}</span>)}
              </div>

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
      ) : viewerKind === 'audio' && accessUrl ? (
        // ────────────────────────────────────────────────────
        // Audio
        // ────────────────────────────────────────────────────
        <div className="ab-reader-viewer-shell">
          <AudioPlayer
            src={accessUrl}
            fileName={assetMeta?.label || bookTitle}
            watermark={wm}
            bookmarkKey={bookmarkKey}
            onError={(msg) => setError(msg)}
          />
        </div>
      ) : viewerKind === 'video' && accessUrl ? (
        // ────────────────────────────────────────────────────
        // Vidéo
        // ────────────────────────────────────────────────────
        <div className="ab-reader-viewer-shell">
          <VideoPlayer
            src={accessUrl}
            fileName={assetMeta?.label || bookTitle}
            watermark={wm}
            bookmarkKey={bookmarkKey}
            onError={(msg) => setError(msg)}
          />
        </div>
      ) : viewerKind === 'image' && accessUrl ? (
        // ────────────────────────────────────────────────────
        // Image
        // ────────────────────────────────────────────────────
        <div className="ab-reader-viewer-shell">
          <ImageViewer
            src={accessUrl}
            fileName={assetMeta?.label || bookTitle}
            watermark={wm}
            onError={(msg) => setError(msg)}
          />
        </div>
      ) : viewerKind === 'external_link' && accessUrl ? (
        // ────────────────────────────────────────────────────
        // Lien externe
        // ────────────────────────────────────────────────────
        <div className="ab-reader-external">
          <h2>{t({id:'reader.external.title'})}</h2>
          <p>{t({id:'reader.external.notice'})}</p>
          <a
            href={accessUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="ab-button"
          >
            {t({id:'reader.external.open'})}
          </a>
          {assetMeta?.source_name && (
            <p className="ab-reader-external__attribution">
              {t({id:'reader.source'}, { name: assetMeta.source_name })}
            </p>
          )}
        </div>
      ) : viewerKind === 'generic' && accessUrl ? (
        // ────────────────────────────────────────────────────
        // Type non reconnu (fallback)
        // ────────────────────────────────────────────────────
        <div className="ab-reader-external">
          <h2>{t({id:'reader.generic.title'})}</h2>
          <p>{t({id:'reader.generic.notice'})}</p>
          <a
            href={accessUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="ab-button ab-button--secondary"
          >
            {t({id:'reader.generic.open'})}
          </a>
        </div>
      ) : null}
    </PageShell>
  );
}
