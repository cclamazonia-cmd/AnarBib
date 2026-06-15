import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui';

// ═══════════════════════════════════════════════════════════
// CardScanner — scan caméra du QR de carte-lecteur (MOBILE Paquet 2)
// ───────────────────────────────────────────────────────────
// Universel : utilise l'API native BarcodeDetector quand elle existe
// (Android/Chrome — zéro dépendance), sinon charge jsQR À LA DEMANDE
// (iOS/Safari, Firefox). Décodage 100 % LOCAL : aucune image n'est
// envoyée nulle part. Le QR ne porte qu'un jeton opaque (cf. CARD-TOKEN) ;
// onScan(token) est appelé au 1er code lu, puis la caméra est relâchée.
// Repli ultime si rien ne marche : la saisie manuelle de ResolveCardBox.
// ═══════════════════════════════════════════════════════════
export default function CardScanner({ t, onScan, onClose }) {
  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const rafRef = useRef(0);
  const onScanRef = useRef(onScan);
  const tRef = useRef(t);
  onScanRef.current = onScan;
  tRef.current = t;

  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    let detector = null;
    let decodeJsqr = null;
    let canvas = null;

    const stopCamera = () => {
      cancelAnimationFrame(rafRef.current);
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((tr) => tr.stop());
        streamRef.current = null;
      }
    };

    const handleToken = (raw) => {
      const tok = (raw || '').trim();
      if (!tok) return false;
      stopCamera();
      onScanRef.current?.(tok);
      return true;
    };

    const tick = async () => {
      if (cancelled) return;
      const video = videoRef.current;
      if (video && video.readyState >= 2 && video.videoWidth) {
        try {
          if (detector) {
            const codes = await detector.detect(video);
            if (codes && codes.length && handleToken(codes[0].rawValue)) return;
          } else if (decodeJsqr) {
            if (!canvas) canvas = document.createElement('canvas');
            canvas.width = video.videoWidth;
            canvas.height = video.videoHeight;
            const ctx = canvas.getContext('2d', { willReadFrequently: true });
            ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
            const img = ctx.getImageData(0, 0, canvas.width, canvas.height);
            const res = decodeJsqr(img.data, img.width, img.height);
            if (res && res.data && handleToken(res.data)) return;
          }
        } catch { /* frame illisible : on continue */ }
      }
      rafRef.current = requestAnimationFrame(tick);
    };

    (async () => {
      // 1) Choix du décodeur : BarcodeDetector natif d'abord, sinon jsQR lazy.
      try {
        if ('BarcodeDetector' in window) {
          const fmts = await window.BarcodeDetector.getSupportedFormats?.();
          if (!fmts || fmts.includes('qr_code')) {
            detector = new window.BarcodeDetector({ formats: ['qr_code'] });
          }
        }
      } catch { detector = null; }
      if (!detector) {
        try {
          const mod = await import('jsqr');
          decodeJsqr = mod.default || mod;
        } catch {
          if (!cancelled) setError(tRef.current({ id: 'card.resolve.scan.error.unsupported' }));
          return;
        }
      }

      // 2) Ouverture de la caméra arrière.
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: 'environment' } },
          audio: false,
        });
        if (cancelled) { stream.getTracks().forEach((tr) => tr.stop()); return; }
        streamRef.current = stream;
        const video = videoRef.current;
        if (!video) { stopCamera(); return; }
        video.srcObject = stream;
        video.setAttribute('playsinline', 'true');
        await video.play();
        rafRef.current = requestAnimationFrame(tick);
      } catch (e) {
        if (cancelled) return;
        const name = e && e.name;
        const key = (name === 'NotAllowedError' || name === 'SecurityError')
          ? 'card.resolve.scan.error.permission'
          : (name === 'NotFoundError' || name === 'OverconstrainedError')
            ? 'card.resolve.scan.error.nocamera'
            : 'card.resolve.scan.error.generic';
        setError(tRef.current({ id: key, defaultMessage: tRef.current({ id: 'card.resolve.scan.error.generic' }) }));
      }
    })();

    return () => { cancelled = true; stopCamera(); };
    // Effet de montage : décodeur + caméra ouverts une fois, relâchés au démontage.
    // onScan/t sont lus via refs pour ne pas relancer la caméra à chaque rendu.
  }, []);

  return (
    <div style={{ margin: '10px 0', display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'flex-start' }}>
      {error ? (
        <p className="ab-painel-msg">{error}</p>
      ) : (
        <>
          <video
            ref={videoRef}
            muted
            playsInline
            style={{ width: '100%', maxWidth: 320, aspectRatio: '1 / 1', objectFit: 'cover', borderRadius: 10, background: '#000' }}
          />
          <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', margin: 0 }}>
            {t({ id: 'card.resolve.scan.prompt' })}
          </p>
        </>
      )}
      <Button onClick={onClose}>{t({ id: 'card.resolve.scan.close' })}</Button>
    </div>
  );
}
