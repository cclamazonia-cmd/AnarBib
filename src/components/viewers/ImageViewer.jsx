// ═══════════════════════════════════════════════════════════
// ImageViewer — visualiseur d'image AnarBib
// ═══════════════════════════════════════════════════════════
//
// Composant standalone pour afficher des images (JPG, PNG, WebP, GIF…)
// avec un niveau de qualité comparable aux autres viewers.
//
// Particularités image (par rapport à Audio/Video) :
//   - Pas de timeline ni de contrôles temporels
//   - Zoom à la mollette + boutons + double-click
//   - Pan : glisser-déposer quand zoomé > 1
//   - Reset : retour à l'échelle 1 centrée
//   - Filigrane par-dessus l'image (capturable avec)
//   - draggable=false sur le <img> (anti-copie native)
//   - "Save image as" via clic droit déjà bloqué par useViewerCopyProtection
//
// Props :
//   src        : string — URL de l'image
//   fileName   : string — étiquette affichée
//   onError    : (msg) => void
//   watermark  : string — texte filigrane (optionnel)
//
// Pas de bookmark localStorage — il n'y a pas de position à mémoriser
// dans une image fixe (contrairement à audio/video).

import { useEffect, useRef, useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { localizeError } from '@/lib/localizeError';
import './ImageViewer.css';

const ZOOM_MIN = 0.25;
const ZOOM_MAX = 8.0;
const ZOOM_STEP = 0.25;
const ZOOM_DEFAULT = 1.0;
const WHEEL_SENSITIVITY = 0.0015;

export default function ImageViewer({ src, fileName, onError, watermark }) {
  const { formatMessage: t } = useIntl();
  const playerRef = useRef(null);
  const stageRef = useRef(null);
  const imgRef = useRef(null);
  const blobUrlRef = useRef(null);

  // État chargement
  const [src_, setSrc] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [naturalSize, setNaturalSize] = useState({ w: 0, h: 0 });

  // Zoom et pan
  const [scale, setScale] = useState(ZOOM_DEFAULT);
  const [tx, setTx] = useState(0);
  const [ty, setTy] = useState(0);
  const [isPanning, setIsPanning] = useState(false);
  const panStartRef = useRef({ x: 0, y: 0, tx: 0, ty: 0 });

  const [isFullscreen, setIsFullscreen] = useState(false);

  // ── Anti-copie scopée ──────────────────────────────────────

  useEffect(() => {
    function inPlayer(e) {
      const node = playerRef.current;
      return Boolean(node && e.target && node.contains(e.target));
    }
    function block(e) {
      if (!inPlayer(e)) return;
      e.preventDefault();
      e.stopPropagation();
    }
    function blockKeys(e) {
      if (!playerRef.current) return;
      const k = (e.key || '').toLowerCase();
      if (
        (e.ctrlKey && !e.shiftKey && ['s', 'c'].includes(k)) ||  // Ctrl+S, Ctrl+C
        (e.ctrlKey && e.shiftKey && ['i', 'j', 'c'].includes(k))
      ) {
        e.preventDefault();
        e.stopPropagation();
      }
    }
    document.addEventListener('contextmenu', block, true);
    document.addEventListener('dragstart', block, true);
    document.addEventListener('copy', block, true);
    document.addEventListener('keydown', blockKeys, true);
    return () => {
      document.removeEventListener('contextmenu', block, true);
      document.removeEventListener('dragstart', block, true);
      document.removeEventListener('copy', block, true);
      document.removeEventListener('keydown', blockKeys, true);
    };
  }, []);

  // ── Chargement en blob ─────────────────────────────────────

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError('');

    if (!src) { setError(t({ id: 'image.error.noSource' })); setLoading(false); return; }

    if (src.startsWith('blob:')) {
      setSrc(src);
      setLoading(false);
      return;
    }

    (async () => {
      try {
        const res = await fetch(src);
        if (!res.ok) throw new Error(`${res.status}`);
        const blob = await res.blob();
        if (cancelled) return;
        const blobUrl = URL.createObjectURL(blob);
        blobUrlRef.current = blobUrl;
        setSrc(blobUrl);
      } catch (err) {
        if (!cancelled) {
          const msg = t({ id: 'image.error.loading' }, { error: localizeError(err, t) });
          setError(msg);
          if (onError) onError(msg);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
      if (blobUrlRef.current) {
        URL.revokeObjectURL(blobUrlRef.current);
        blobUrlRef.current = null;
      }
    };
  }, [src, onError, t]);

  // ── Plein écran ────────────────────────────────────────────

  useEffect(() => {
    const onFsChange = () => setIsFullscreen(Boolean(document.fullscreenElement));
    document.addEventListener('fullscreenchange', onFsChange);
    return () => document.removeEventListener('fullscreenchange', onFsChange);
  }, []);

  const toggleFullscreen = useCallback(() => {
    const node = playerRef.current;
    if (!node) return;
    if (!document.fullscreenElement) {
      if (node.requestFullscreen) node.requestFullscreen();
    } else {
      if (document.exitFullscreen) document.exitFullscreen();
    }
  }, []);

  // ── Zoom ──────────────────────────────────────────────────

  const resetView = useCallback(() => {
    setScale(ZOOM_DEFAULT);
    setTx(0);
    setTy(0);
  }, []);

  const zoomBy = useCallback((delta, originX = null, originY = null) => {
    setScale((s) => {
      const next = Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, +(s + delta).toFixed(2)));
      if (next === s) return s;
      // Si on a un point d'origine (ex: position de la souris), ajuster
      // tx/ty pour que le zoom soit centré sur ce point.
      if (originX !== null && originY !== null && stageRef.current) {
        const rect = stageRef.current.getBoundingClientRect();
        const cx = originX - rect.left - rect.width / 2;
        const cy = originY - rect.top - rect.height / 2;
        const ratio = next / s;
        setTx((t) => (t - cx) * ratio + cx);
        setTy((t) => (t - cy) * ratio + cy);
      }
      // Si on revient à 1, recentrer
      if (next === ZOOM_DEFAULT) {
        setTx(0);
        setTy(0);
      }
      return next;
    });
  }, []);

  const zoomIn = useCallback(() => zoomBy(ZOOM_STEP), [zoomBy]);
  const zoomOut = useCallback(() => zoomBy(-ZOOM_STEP), [zoomBy]);

  // Mollette = zoom centré sur la position de la souris
  const onWheel = useCallback((e) => {
    e.preventDefault();
    const delta = -e.deltaY * WHEEL_SENSITIVITY;
    zoomBy(delta, e.clientX, e.clientY);
  }, [zoomBy]);

  // Double-click = toggle zoom 1× ↔ 2×
  const onDoubleClick = useCallback((e) => {
    if (scale > ZOOM_DEFAULT) {
      resetView();
    } else {
      zoomBy(1.0, e.clientX, e.clientY);
    }
  }, [scale, resetView, zoomBy]);

  // ── Pan ───────────────────────────────────────────────────

  const onMouseDown = useCallback((e) => {
    if (scale <= ZOOM_DEFAULT) return;
    if (e.button !== 0) return;  // bouton gauche uniquement
    e.preventDefault();
    setIsPanning(true);
    panStartRef.current = { x: e.clientX, y: e.clientY, tx, ty };
  }, [scale, tx, ty]);

  const onMouseMove = useCallback((e) => {
    if (!isPanning) return;
    const dx = e.clientX - panStartRef.current.x;
    const dy = e.clientY - panStartRef.current.y;
    setTx(panStartRef.current.tx + dx);
    setTy(panStartRef.current.ty + dy);
  }, [isPanning]);

  const onMouseUp = useCallback(() => {
    setIsPanning(false);
  }, []);

  // Reset à chaque changement d'image
  useEffect(() => {
    resetView();
  }, [src_, resetView]);

  // ── Image natural size ────────────────────────────────────

  const onImgLoad = useCallback((e) => {
    const img = e.target;
    setNaturalSize({ w: img.naturalWidth, h: img.naturalHeight });
  }, []);

  const onImgError = useCallback(() => {
    const msg = t({ id: 'image.error.decode' });
    setError(msg);
    if (onError) onError(msg);
  }, [t, onError]);

  // ── Rendu ──────────────────────────────────────────────────

  if (loading) {
    return (
      <div ref={playerRef} className="ab-image-viewer ab-image-viewer--loading">
        <p>{t({ id: 'image.loading' })}</p>
      </div>
    );
  }

  if (error) {
    return (
      <div ref={playerRef} className="ab-image-viewer ab-image-viewer--error">
        <p>{error}</p>
      </div>
    );
  }

  return (
    <div
      ref={playerRef}
      className={`ab-image-viewer ${isFullscreen ? 'ab-image-viewer--fullscreen' : ''}`}
      tabIndex={0}
    >
      {/* Header */}
      {fileName && !isFullscreen && (
        <div className="ab-image-header">
          <span className="ab-image-header__title">{fileName}</span>
          {naturalSize.w > 0 && (
            <span className="ab-image-header__dim">
              {t({ id: 'image.dimensions' }, { w: naturalSize.w, h: naturalSize.h })}
            </span>
          )}
        </div>
      )}

      {/* Stage */}
      <div
        ref={stageRef}
        className={`ab-image-stage ${isPanning ? 'ab-image-stage--panning' : ''} ${scale > ZOOM_DEFAULT ? 'ab-image-stage--zoomed' : ''}`}
        onWheel={onWheel}
        onMouseDown={onMouseDown}
        onMouseMove={onMouseMove}
        onMouseUp={onMouseUp}
        onMouseLeave={onMouseUp}
        onDoubleClick={onDoubleClick}
      >
        <img
          ref={imgRef}
          src={src_}
          alt={fileName || t({ id: 'image.altDefault' })}
          className="ab-image-element"
          draggable={false}
          onLoad={onImgLoad}
          onError={onImgError}
          onContextMenu={(e) => e.preventDefault()}
          style={{
            transform: `translate(${tx}px, ${ty}px) scale(${scale})`,
            transition: isPanning ? 'none' : 'transform 0.15s',
          }}
        />

        {/* Filigrane par-dessus l'image, en position fixe sur le stage
            (ne suit pas le zoom/pan, donc capturable mais pas déformable
            par le zoom utilisateur). */}
        {watermark && (
          <div className="ab-image-watermark" aria-hidden="true">
            {[...Array(5)].map((_, i) => <span key={i}>{watermark}</span>)}
          </div>
        )}
      </div>

      {/* Contrôles */}
      <div className="ab-image-controls">
        <div className="ab-image-controls__group">
          <button
            type="button"
            className="ab-image-btn"
            onClick={zoomOut}
            disabled={scale <= ZOOM_MIN}
            aria-label={t({ id: 'image.zoomOut' })}
            title={t({ id: 'image.zoomOut' })}
          >
            −
          </button>
          <span className="ab-image-zoom-info">{Math.round(scale * 100)}%</span>
          <button
            type="button"
            className="ab-image-btn"
            onClick={zoomIn}
            disabled={scale >= ZOOM_MAX}
            aria-label={t({ id: 'image.zoomIn' })}
            title={t({ id: 'image.zoomIn' })}
          >
            +
          </button>
          <button
            type="button"
            className="ab-image-btn"
            onClick={resetView}
            disabled={scale === ZOOM_DEFAULT && tx === 0 && ty === 0}
            aria-label={t({ id: 'image.reset' })}
            title={t({ id: 'image.reset' })}
          >
            ↺
          </button>
        </div>

        <div className="ab-image-controls__group">
          <button
            type="button"
            className="ab-image-btn"
            onClick={toggleFullscreen}
            aria-label={t({ id: isFullscreen ? 'image.fullscreenExit' : 'image.fullscreen' })}
            title={t({ id: isFullscreen ? 'image.fullscreenExit' : 'image.fullscreen' })}
          >
            {isFullscreen ? '⤡' : '⤢'}
          </button>
        </div>
      </div>

      {/* Notice */}
      {!isFullscreen && (
        <p className="ab-image-notice">
          {t({ id: 'image.notice' })}
        </p>
      )}
    </div>
  );
}
