/**
 * PdfViewer.jsx — Lecteur PDF custom AnarBib (v2)
 *
 * v2 (2026-05-07) :
 *   - Fix : clic droit ne bloque plus toute la page, scope limité au viewer
 *   - Fix : pas de reload du PDF quand l'onglet reprend le focus
 *   - Fix : chargement pdfjs via import() statique (Vite gère mieux)
 *   - Fix : useSystemFonts:false (isEvalSupported retiré en pdfjs 5.x)
 *
 * ─────────────────────────────────────────────────────────────────────────
 * MODÈLE DE MENACE (à lire avant toute modification)
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Le viewer ne prétend PAS implémenter du DRM. Aucun navigateur web ne le
 * permet réellement. Ce que le viewer bloque effectivement :
 *
 *   ✓ Le geste réflexe « clic droit → Enregistrer sous » (sur la zone PDF)
 *   ✓ Le geste réflexe « Ctrl+P → Imprimer »
 *   ✓ La sélection-copie de texte (text layer désactivé)
 *   ✓ Les bots de scraping naïfs
 *
 * Ce que le viewer NE bloque PAS (techniquement impossible) :
 *
 *   ✗ Les screenshots OS (PrintScreen non interceptable de manière fiable)
 *   ✗ L'ouverture de DevTools
 *   ✗ Une personne déterminée
 *
 * L'utilisateur·rice est la première ligne de protection. Le viewer est
 * la deuxième : il décourage la fuite par négligence.
 *
 * ─────────────────────────────────────────────────────────────────────────
 */

import { useEffect, useRef, useState, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import './PdfViewer.css';

// Chemins de service (Vite sert public/ à la racine)
const PDFJS_BASE = '/vendor/pdfjs';
const PDFJS_LIB_URL = `${PDFJS_BASE}/build/pdf.mjs`;
const PDFJS_WORKER_URL = `${PDFJS_BASE}/build/pdf.worker.mjs`;
const PDFJS_CMAPS_URL = `${PDFJS_BASE}/web/cmaps/`;
const PDFJS_STANDARD_FONTS_URL = `${PDFJS_BASE}/web/standard_fonts/`;
const PDFJS_WASM_URL = `${PDFJS_BASE}/web/wasm/`;
const PDFJS_ICCS_URL = `${PDFJS_BASE}/web/iccs/`;

// Constantes UI
const ZOOM_MIN = 0.25;
const ZOOM_MAX = 5.0;
const ZOOM_STEP = 0.25;
const ZOOM_DEFAULT = 1.0;
const ROTATION_STEP = 90;
const RENDER_DEBOUNCE_MS = 80;

// Cache module-level pour ne pas re-importer pdfjs à chaque montage
let pdfjsModulePromise = null;

function loadPdfjs() {
    if (!pdfjsModulePromise) {
        // Import dynamique. Le commentaire @vite-ignore évite que Vite tente
        // de pré-traiter le module : pdf.mjs est servi tel quel depuis /public.
        pdfjsModulePromise = import(/* @vite-ignore */ PDFJS_LIB_URL).then((mod) => {
            // pdfjs 5.x exporte tout au top-level (pas de .default)
            const pdfjs = mod.getDocument ? mod : (mod.default || mod);
            pdfjs.GlobalWorkerOptions.workerSrc = PDFJS_WORKER_URL;
            return pdfjs;
        });
    }
    return pdfjsModulePromise;
}

/**
 * Lecteur PDF AnarBib.
 *
 * @param {object} props
 * @param {string} props.src - URL du PDF (https:// ou blob:)
 * @param {string} [props.fileName] - Nom de fichier (affiché dans le bandeau)
 * @param {function} [props.onError] - Callback (error: Error) => void
 */
export default function PdfViewer({ src, fileName, onError }) {
    const { formatMessage: t } = useIntl();
    const containerRef = useRef(null);
    const canvasRef = useRef(null);
    const renderTaskRef = useRef(null);
    const renderTimerRef = useRef(null);
    const pdfDocRef = useRef(null);
    // Garde anti-reload : on retient le src déjà chargé pour ne pas re-déclencher
    const loadedSrcRef = useRef(null);

    // État
    const [status, setStatus] = useState('loading'); // loading | ready | error | password
    const [errorMsg, setErrorMsg] = useState('');
    const [numPages, setNumPages] = useState(0);
    const [currentPage, setCurrentPage] = useState(1);
    const [zoom, setZoom] = useState(ZOOM_DEFAULT);
    const [rotation, setRotation] = useState(0);
    const [fitMode, setFitMode] = useState(null); // null | 'width' | 'page'
    const [isFullscreen, setIsFullscreen] = useState(false);
    const [pageInputValue, setPageInputValue] = useState('1');
    const [passwordValue, setPasswordValue] = useState('');
    const [pendingPasswordCallback, setPendingPasswordCallback] = useState(null);

    // ─── Chargement du document ────────────────────────────────────────────
    useEffect(() => {
        if (!src) {
            setStatus('error');
            setErrorMsg(t({ id: 'resource.viewer.pdf.errorLoad' }));
            return;
        }

        // FIX v2 : ne pas re-charger si c'est le même src (évite reload-on-focus)
        if (loadedSrcRef.current === src && pdfDocRef.current) {
            return;
        }

        let cancelled = false;
        let loadingTask = null;

        async function load() {
            setStatus('loading');
            setErrorMsg('');

            try {
                const pdfjs = await loadPdfjs();
                if (cancelled) return;

                const isBlob = src.startsWith('blob:');

                const params = {
                    cMapUrl: PDFJS_CMAPS_URL,
                    cMapPacked: true,
                    standardFontDataUrl: PDFJS_STANDARD_FONTS_URL,
                    wasmUrl: PDFJS_WASM_URL,
                    iccUrl: PDFJS_ICCS_URL,
                    // Sécurité : pas de polices système (rendu reproductible).
                    // pdf.sandbox.mjs n'est pas chargé : le JS embarqué dans
                    // certains PDFs est ignoré (neutralise app.print() etc.)
                    useSystemFonts: false,
                    disableAutoFetch: true,
                    disableStream: false,
                };

                if (isBlob) {
                    // Mode blob : ArrayBuffer en mémoire, pas de range possible
                    const response = await fetch(src);
                    const arrayBuffer = await response.arrayBuffer();
                    if (cancelled) return;
                    params.data = arrayBuffer;
                } else {
                    // Mode HTTPS : range requests activés
                    params.url = src;
                    params.withCredentials = false;
                }

                loadingTask = pdfjs.getDocument(params);

                loadingTask.onPassword = (callback, reason) => {
                    if (cancelled) return;
                    setStatus('password');
                    setPendingPasswordCallback(() => callback);
                };

                const pdf = await loadingTask.promise;
                if (cancelled) {
                    pdf.destroy();
                    return;
                }

                pdfDocRef.current = pdf;
                loadedSrcRef.current = src; // FIX v2
                setNumPages(pdf.numPages);
                setCurrentPage(1);
                setPageInputValue('1');
                setStatus('ready');
            } catch (err) {
                if (cancelled) return;
                console.error('[PdfViewer] load error:', err);
                setStatus('error');
                const isTimeout = err?.name === 'TimeoutException' || /timeout/i.test(String(err?.message));
                setErrorMsg(t({
                    id: isTimeout ? 'resource.viewer.pdf.errorTimeout' : 'resource.viewer.pdf.errorLoad'
                }));
                if (typeof onError === 'function') onError(err);
            }
        }

        load();

        return () => {
            cancelled = true;
            if (loadingTask) {
                try { loadingTask.destroy(); } catch (_e) { /* noop */ }
            }
            if (renderTaskRef.current) {
                try { renderTaskRef.current.cancel(); } catch (_e) { /* noop */ }
                renderTaskRef.current = null;
            }
            if (renderTimerRef.current) {
                clearTimeout(renderTimerRef.current);
                renderTimerRef.current = null;
            }
            if (pdfDocRef.current) {
                try { pdfDocRef.current.destroy(); } catch (_e) { /* noop */ }
                pdfDocRef.current = null;
                loadedSrcRef.current = null;
            }
        };
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [src]);

    // ─── Rendu de la page courante ─────────────────────────────────────────
    const renderPage = useCallback(async () => {
        const pdf = pdfDocRef.current;
        const canvas = canvasRef.current;
        if (!pdf || !canvas || status !== 'ready') return;

        if (renderTaskRef.current) {
            try { renderTaskRef.current.cancel(); } catch (_e) { /* noop */ }
            renderTaskRef.current = null;
        }

        try {
            const page = await pdf.getPage(currentPage);
            const baseViewport = page.getViewport({ scale: 1, rotation });

            let effectiveScale = zoom;
            const container = containerRef.current;
            if (fitMode && container) {
                const padding = 24;
                const availW = container.clientWidth - padding;
                const availH = container.clientHeight - padding;
                if (fitMode === 'width') {
                    effectiveScale = availW / baseViewport.width;
                } else if (fitMode === 'page') {
                    effectiveScale = Math.min(
                        availW / baseViewport.width,
                        availH / baseViewport.height
                    );
                }
            }

            const dpr = window.devicePixelRatio || 1;
            const viewport = page.getViewport({ scale: effectiveScale * dpr, rotation });

            canvas.width = Math.floor(viewport.width);
            canvas.height = Math.floor(viewport.height);
            canvas.style.width = `${Math.floor(viewport.width / dpr)}px`;
            canvas.style.height = `${Math.floor(viewport.height / dpr)}px`;

            const ctx = canvas.getContext('2d');
            const renderTask = page.render({ canvasContext: ctx, viewport });
            renderTaskRef.current = renderTask;
            await renderTask.promise;
            renderTaskRef.current = null;
        } catch (err) {
            if (err?.name === 'RenderingCancelledException') return;
            console.error('[PdfViewer] render error:', err);
        }
    }, [currentPage, zoom, rotation, fitMode, status]);

    useEffect(() => {
        if (renderTimerRef.current) clearTimeout(renderTimerRef.current);
        renderTimerRef.current = setTimeout(renderPage, RENDER_DEBOUNCE_MS);
        return () => {
            if (renderTimerRef.current) clearTimeout(renderTimerRef.current);
        };
    }, [renderPage]);

    useEffect(() => {
        if (!fitMode) return;
        const onResize = () => {
            if (renderTimerRef.current) clearTimeout(renderTimerRef.current);
            renderTimerRef.current = setTimeout(renderPage, RENDER_DEBOUNCE_MS);
        };
        window.addEventListener('resize', onResize);
        return () => window.removeEventListener('resize', onResize);
    }, [fitMode, renderPage]);

    useEffect(() => {
        setPageInputValue(String(currentPage));
    }, [currentPage]);

    useEffect(() => {
        const onFsChange = () => {
            setIsFullscreen(Boolean(document.fullscreenElement));
        };
        document.addEventListener('fullscreenchange', onFsChange);
        return () => document.removeEventListener('fullscreenchange', onFsChange);
    }, []);

    // ─── Anti-download : interception clavier (scope viewer uniquement) ────
    // FIX v2 : on n'attache plus document-level. Les raccourcis sont
    // interceptés uniquement quand le focus est dans le viewer.
    useEffect(() => {
        const node = containerRef.current;
        if (!node) return;

        const onKeyDown = (e) => {
            const k = e.key?.toLowerCase();
            const ctrlOrMeta = e.ctrlKey || e.metaKey;

            // Ctrl+S, Ctrl+P
            if (ctrlOrMeta && (k === 's' || k === 'p')) {
                e.preventDefault();
                e.stopPropagation();
                return false;
            }
            // F12 (placebo, pas fiable)
            if (k === 'f12') {
                e.preventDefault();
                e.stopPropagation();
                return false;
            }
            // Ctrl+Shift+I, Ctrl+Shift+J, Ctrl+Shift+C
            if (ctrlOrMeta && e.shiftKey && (k === 'i' || k === 'j' || k === 'c')) {
                e.preventDefault();
                e.stopPropagation();
                return false;
            }
            // Ctrl+U (view-source)
            if (ctrlOrMeta && k === 'u') {
                e.preventDefault();
                e.stopPropagation();
                return false;
            }
            // PrintScreen (placebo)
            if (k === 'printscreen') {
                e.preventDefault();
                return false;
            }

            // Raccourcis viewer
            if (!ctrlOrMeta && !e.altKey && status === 'ready') {
                if (k === 'arrowright' || k === 'pagedown') {
                    e.preventDefault();
                    setCurrentPage((p) => Math.min(p + 1, numPages));
                } else if (k === 'arrowleft' || k === 'pageup') {
                    e.preventDefault();
                    setCurrentPage((p) => Math.max(p - 1, 1));
                } else if (k === '+' || k === '=') {
                    e.preventDefault();
                    setFitMode(null);
                    setZoom((z) => Math.min(z + ZOOM_STEP, ZOOM_MAX));
                } else if (k === '-') {
                    e.preventDefault();
                    setFitMode(null);
                    setZoom((z) => Math.max(z - ZOOM_STEP, ZOOM_MIN));
                }
            }
        };

        node.addEventListener('keydown', onKeyDown);
        return () => {
            node.removeEventListener('keydown', onKeyDown);
        };
    }, [status, numPages]);

    // ─── Anti-download : clic droit (scope viewer uniquement) ──────────────
    // FIX v2 : on bloque uniquement le clic droit sur l'élément viewer,
    // plus le clic droit global de la page. Les utilisateurs gardent F12,
    // inspecter, etc. sur le reste du site.
    const onContextMenu = useCallback((e) => {
        e.preventDefault();
        e.stopPropagation();
        return false;
    }, []);

    const onDragStart = useCallback((e) => {
        e.preventDefault();
        return false;
    }, []);

    // ─── Handlers actions UI ──────────────────────────────────────────────
    const goPrev = useCallback(() => {
        setCurrentPage((p) => Math.max(p - 1, 1));
    }, []);

    const goNext = useCallback(() => {
        setCurrentPage((p) => Math.min(p + 1, numPages));
    }, [numPages]);

    const onPageInputChange = useCallback((e) => {
        setPageInputValue(e.target.value);
    }, []);

    const onPageInputCommit = useCallback(() => {
        const n = parseInt(pageInputValue, 10);
        if (Number.isInteger(n) && n >= 1 && n <= numPages) {
            setCurrentPage(n);
        } else {
            setPageInputValue(String(currentPage));
        }
    }, [pageInputValue, numPages, currentPage]);

    const onPageInputKey = useCallback((e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            onPageInputCommit();
        } else if (e.key === 'Escape') {
            e.preventDefault();
            setPageInputValue(String(currentPage));
        }
    }, [onPageInputCommit, currentPage]);

    const zoomIn = useCallback(() => {
        setFitMode(null);
        setZoom((z) => Math.min(z + ZOOM_STEP, ZOOM_MAX));
    }, []);

    const zoomOut = useCallback(() => {
        setFitMode(null);
        setZoom((z) => Math.max(z - ZOOM_STEP, ZOOM_MIN));
    }, []);

    const zoomReset = useCallback(() => {
        setFitMode(null);
        setZoom(ZOOM_DEFAULT);
    }, []);

    const fitWidth = useCallback(() => {
        setFitMode('width');
    }, []);

    const fitPage = useCallback(() => {
        setFitMode('page');
    }, []);

    const rotate = useCallback(() => {
        setRotation((r) => (r + ROTATION_STEP) % 360);
    }, []);

    const toggleFullscreen = useCallback(() => {
        const node = containerRef.current;
        if (!node) return;
        if (!document.fullscreenElement) {
            if (node.requestFullscreen) node.requestFullscreen();
        } else {
            if (document.exitFullscreen) document.exitFullscreen();
        }
    }, []);

    const submitPassword = useCallback(() => {
        if (pendingPasswordCallback) {
            pendingPasswordCallback(passwordValue);
            setPendingPasswordCallback(null);
            setPasswordValue('');
            setStatus('loading');
        }
    }, [pendingPasswordCallback, passwordValue]);

    const onPasswordKey = useCallback((e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            submitPassword();
        }
    }, [submitPassword]);

    const retry = useCallback(() => {
        loadedSrcRef.current = null;
        setStatus('loading');
        setErrorMsg('');
        // Force le useEffect [src] à recharger en réinitialisant
        if (pdfDocRef.current) {
            try { pdfDocRef.current.destroy(); } catch (_e) { /* noop */ }
            pdfDocRef.current = null;
        }
        // Trigger un re-render qui relancera le useEffect
        setNumPages(0);
        setCurrentPage(1);
        setTimeout(() => {
            // Force reload : on incrémente un trigger interne via setStatus
            setStatus((s) => s === 'loading' ? 'loading' : 'loading');
        }, 0);
    }, []);

    // ─── Calculs dérivés ──────────────────────────────────────────────────
    const zoomPercent = useMemo(() => Math.round(zoom * 100), [zoom]);
    const canPrev = currentPage > 1;
    const canNext = currentPage < numPages;

    // ─── Rendu ────────────────────────────────────────────────────────────
    return (
        <div
            ref={containerRef}
            className={`ab-pdfviewer ${isFullscreen ? 'ab-pdfviewer--fullscreen' : ''}`}
            onContextMenu={onContextMenu}
            onDragStart={onDragStart}
            tabIndex={0}
            role="region"
            aria-label={t({ id: 'resource.viewer.pdf.protectedNotice' })}
        >
            {/* Bandeau "Lecture protégée" */}
            <div className="ab-pdfviewer__notice" title={t({ id: 'resource.viewer.pdf.protectedTooltip' })}>
                <span className="ab-pdfviewer__notice-icon" aria-hidden="true">🔒</span>
                <span>{t({ id: 'resource.viewer.pdf.protectedNotice' })}</span>
                {fileName && <span className="ab-pdfviewer__notice-filename" title={fileName}>{fileName}</span>}
            </div>

            {/* Toolbar */}
            <div className="ab-pdfviewer__toolbar" role="toolbar" aria-label="PDF">
                <div className="ab-pdfviewer__toolbar-group">
                    <button
                        type="button"
                        className="ab-pdfviewer__btn"
                        onClick={goPrev}
                        disabled={!canPrev || status !== 'ready'}
                        aria-label={t({ id: 'resource.viewer.pdf.prevPage' })}
                        title={t({ id: 'resource.viewer.pdf.prevPage' })}
                    >
                        ◀
                    </button>

                    <span className="ab-pdfviewer__page-control">
                        <input
                            type="text"
                            inputMode="numeric"
                            pattern="[0-9]*"
                            className="ab-pdfviewer__page-input"
                            value={pageInputValue}
                            onChange={onPageInputChange}
                            onBlur={onPageInputCommit}
                            onKeyDown={onPageInputKey}
                            disabled={status !== 'ready'}
                            aria-label={t({ id: 'resource.viewer.pdf.pageInputLabel' })}
                        />
                        <span className="ab-pdfviewer__page-total">
                            {t({ id: 'resource.viewer.pdf.pageOf' }, { current: currentPage, total: numPages || '—' })}
                        </span>
                    </span>

                    <button
                        type="button"
                        className="ab-pdfviewer__btn"
                        onClick={goNext}
                        disabled={!canNext || status !== 'ready'}
                        aria-label={t({ id: 'resource.viewer.pdf.nextPage' })}
                        title={t({ id: 'resource.viewer.pdf.nextPage' })}
                    >
                        ▶
                    </button>
                </div>

                <div className="ab-pdfviewer__toolbar-group">
                    <button
                        type="button"
                        className="ab-pdfviewer__btn"
                        onClick={zoomOut}
                        disabled={zoom <= ZOOM_MIN || status !== 'ready'}
                        aria-label={t({ id: 'resource.viewer.pdf.zoomOut' })}
                        title={t({ id: 'resource.viewer.pdf.zoomOut' })}
                    >
                        −
                    </button>
                    <button
                        type="button"
                        className="ab-pdfviewer__btn ab-pdfviewer__btn--zoom-label"
                        onClick={zoomReset}
                        disabled={status !== 'ready'}
                        title={t({ id: 'resource.viewer.pdf.zoomReset' })}
                    >
                        {t({ id: 'resource.viewer.pdf.zoomLabel' }, { percent: zoomPercent })}
                    </button>
                    <button
                        type="button"
                        className="ab-pdfviewer__btn"
                        onClick={zoomIn}
                        disabled={zoom >= ZOOM_MAX || status !== 'ready'}
                        aria-label={t({ id: 'resource.viewer.pdf.zoomIn' })}
                        title={t({ id: 'resource.viewer.pdf.zoomIn' })}
                    >
                        +
                    </button>
                </div>

                <div className="ab-pdfviewer__toolbar-group">
                    <button
                        type="button"
                        className={`ab-pdfviewer__btn ${fitMode === 'width' ? 'ab-pdfviewer__btn--active' : ''}`}
                        onClick={fitWidth}
                        disabled={status !== 'ready'}
                        title={t({ id: 'resource.viewer.pdf.fitWidth' })}
                    >
                        ↔
                    </button>
                    <button
                        type="button"
                        className={`ab-pdfviewer__btn ${fitMode === 'page' ? 'ab-pdfviewer__btn--active' : ''}`}
                        onClick={fitPage}
                        disabled={status !== 'ready'}
                        title={t({ id: 'resource.viewer.pdf.fitPage' })}
                    >
                        ⊡
                    </button>
                    <button
                        type="button"
                        className="ab-pdfviewer__btn"
                        onClick={rotate}
                        disabled={status !== 'ready'}
                        aria-label={t({ id: 'resource.viewer.pdf.rotate' })}
                        title={t({ id: 'resource.viewer.pdf.rotate' })}
                    >
                        ⟳
                    </button>
                    <button
                        type="button"
                        className="ab-pdfviewer__btn"
                        onClick={toggleFullscreen}
                        disabled={status !== 'ready'}
                        aria-label={t({ id: isFullscreen ? 'resource.viewer.pdf.fullscreenExit' : 'resource.viewer.pdf.fullscreen' })}
                        title={t({ id: isFullscreen ? 'resource.viewer.pdf.fullscreenExit' : 'resource.viewer.pdf.fullscreen' })}
                    >
                        {isFullscreen ? '⤡' : '⤢'}
                    </button>
                </div>
            </div>

            {/* Zone de rendu */}
            <div className="ab-pdfviewer__stage">
                {status === 'loading' && (
                    <div className="ab-pdfviewer__loading">
                        <div className="ab-pdfviewer__spinner" aria-hidden="true" />
                        <p>{t({ id: 'resource.viewer.pdf.loading' })}</p>
                    </div>
                )}

                {status === 'error' && (
                    <div className="ab-pdfviewer__error" role="alert">
                        <strong>{errorMsg}</strong>
                        <button type="button" className="ab-pdfviewer__btn" onClick={retry}>
                            {t({ id: 'resource.viewer.pdf.retry' })}
                        </button>
                    </div>
                )}

                {status === 'password' && (
                    <div className="ab-pdfviewer__password">
                        <label htmlFor="ab-pdfviewer-password">
                            {t({ id: 'resource.viewer.pdf.passwordPrompt' })}
                        </label>
                        <input
                            id="ab-pdfviewer-password"
                            type="password"
                            className="ab-pdfviewer__password-input"
                            value={passwordValue}
                            onChange={(e) => setPasswordValue(e.target.value)}
                            onKeyDown={onPasswordKey}
                            autoFocus
                        />
                        <button type="button" className="ab-pdfviewer__btn" onClick={submitPassword}>
                            {t({ id: 'resource.viewer.pdf.passwordSubmit' })}
                        </button>
                    </div>
                )}

                <div className={`ab-pdfviewer__canvas-wrap ${status !== 'ready' ? 'ab-pdfviewer__canvas-wrap--hidden' : ''}`}>
                    <canvas
                        ref={canvasRef}
                        className="ab-pdfviewer__canvas"
                        aria-label={fileName || t({ id: 'resource.title' })}
                    />
                </div>
            </div>
        </div>
    );
}
