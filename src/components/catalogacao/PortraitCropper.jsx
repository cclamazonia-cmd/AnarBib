import { useState, useRef, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';

/**
 * PortraitCropper — recadrage manuel au format « photo d'identité » (foto 3×4).
 * Aucune IA : la personne cadre le visage à la main (glisser + zoom).
 * Sortie : JPEG 600×800 (ratio 3:4). src doit être une URL same-origin
 * (blob: / data:) pour éviter de souiller le canvas.
 */
const VIEW_W = 270;
const VIEW_H = 360; // 3:4
const OUT_W = 600;
const OUT_H = 800;

export default function PortraitCropper({ src, onConfirm, onCancel }) {
  const { formatMessage: t } = useIntl();
  const imgRef = useRef(null);
  const drag = useRef(null);
  const [nat, setNat] = useState(null); // { w, h }
  const [zoom, setZoom] = useState(1);
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const [busy, setBusy] = useState(false);

  const baseScale = nat ? Math.max(VIEW_W / nat.w, VIEW_H / nat.h) : 1;
  const scale = baseScale * zoom;

  const clamp = useCallback((p, s) => {
    if (!nat) return p;
    const dw = nat.w * s, dh = nat.h * s;
    return {
      x: Math.min(0, Math.max(VIEW_W - dw, p.x)),
      y: Math.min(0, Math.max(VIEW_H - dh, p.y)),
    };
  }, [nat]);

  // Centre l'image au chargement
  useEffect(() => {
    if (!nat) return;
    const s = Math.max(VIEW_W / nat.w, VIEW_H / nat.h);
    setZoom(1);
    setPos({ x: (VIEW_W - nat.w * s) / 2, y: (VIEW_H - nat.h * s) / 2 });
  }, [nat]);

  function onImgLoad(e) {
    setNat({ w: e.target.naturalWidth, h: e.target.naturalHeight });
  }
  function onPointerDown(e) {
    drag.current = { sx: e.clientX, sy: e.clientY, px: pos.x, py: pos.y };
    e.currentTarget.setPointerCapture?.(e.pointerId);
  }
  function onPointerMove(e) {
    if (!drag.current) return;
    setPos(clamp({
      x: drag.current.px + (e.clientX - drag.current.sx),
      y: drag.current.py + (e.clientY - drag.current.sy),
    }, scale));
  }
  function onPointerUp() { drag.current = null; }
  function onZoom(e) {
    const z = Number(e.target.value);
    setZoom(z);
    setPos((p) => clamp(p, baseScale * z));
  }

  async function confirm() {
    if (!nat || !imgRef.current) return;
    setBusy(true);
    try {
      const canvas = document.createElement('canvas');
      canvas.width = OUT_W; canvas.height = OUT_H;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, OUT_W, OUT_H);
      // Rectangle source (en pixels natifs) correspondant à la fenêtre de cadrage
      const sx = -pos.x / scale;
      const sy = -pos.y / scale;
      ctx.drawImage(imgRef.current, sx, sy, VIEW_W / scale, VIEW_H / scale, 0, 0, OUT_W, OUT_H);
      const blob = await new Promise((res) => canvas.toBlob(res, 'image/jpeg', 0.9));
      if (blob) onConfirm(blob);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
      <div style={{ background: 'var(--brand-panel-bg, #1a1a1a)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 10, padding: 16, maxWidth: '92vw' }}>
        <div style={{ fontWeight: 700, marginBottom: 6 }}>{t({ id: 'catalogacao.author.cropTitle' })}</div>
        <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)', marginBottom: 10, maxWidth: VIEW_W + 40 }}>
          {t({ id: 'catalogacao.author.cropHint' })}
        </div>
        <div
          style={{ width: VIEW_W, height: VIEW_H, overflow: 'hidden', position: 'relative', margin: '0 auto', borderRadius: 6, border: '1px solid rgba(255,255,255,.25)', touchAction: 'none', cursor: 'grab', background: '#222' }}
          onPointerDown={onPointerDown} onPointerMove={onPointerMove} onPointerUp={onPointerUp} onPointerLeave={onPointerUp}
        >
          <img
            ref={imgRef} src={src} alt="" onLoad={onImgLoad} draggable={false}
            style={{ position: 'absolute', left: pos.x, top: pos.y, width: nat ? nat.w * scale : 'auto', height: nat ? nat.h * scale : 'auto', maxWidth: 'none', userSelect: 'none', pointerEvents: 'none' }}
          />
        </div>
        <input type="range" min="1" max="3" step="0.01" value={zoom} onChange={onZoom} style={{ width: VIEW_W, display: 'block', margin: '12px auto 4px' }} />
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 8 }}>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={onCancel} disabled={busy}>
            {t({ id: 'common.cancel' })}
          </button>
          <button type="button" className="ab-button ab-button--sm" onClick={confirm} disabled={busy || !nat}>
            {busy ? '…' : t({ id: 'catalogacao.author.cropConfirm' })}
          </button>
        </div>
      </div>
    </div>
  );
}
