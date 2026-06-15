import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui';

// ═══════════════════════════════════════════════════════════
// CardScanner — scan caméra du QR de carte-lecteur (MOBILE Paquet 2)
// ───────────────────────────────────────────────────────────
// Universel : API native BarcodeDetector quand elle existe (Android/Chrome),
// sinon repli chargé À LA DEMANDE — jsQR pour le QR, ZXing pour les codes-barres
// 1D (ISBN/EAN) — couvrant Brave, iOS/Safari, Firefox. Décodage 100 % LOCAL :
// aucune image n'est
// envoyée nulle part. Le QR ne porte qu'un jeton opaque (cf. CARD-TOKEN) ;
// onScan(token) est appelé au 1er code lu, puis la caméra est relâchée.
// Repli ultime si rien ne marche : la saisie manuelle de ResolveCardBox.
// ═══════════════════════════════════════════════════════════
export default function CardScanner({ t, onScan, onClose, formats = ['qr_code'], prompt }) {
  const videoRef = useRef(null);
  const streamRef = useRef(null);
  const rafRef = useRef(0);
  const onScanRef = useRef(onScan);
  const tRef = useRef(t);
  const formatsRef = useRef(formats); // capturé au montage (stable par ouverture)
  onScanRef.current = onScan;
  tRef.current = t;

  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    let detector = null;
    let decodeJsqr = null;
    let canvas = null;
    let zxingControls = null; // ZXing : repli 1D (code-barres ISBN/EAN sans BarcodeDetector)

    const stopCamera = () => {
      cancelAnimationFrame(rafRef.current);
      if (streamRef.current) {
        streamRef.current.getTracks().forEach((tr) => tr.stop());
        streamRef.current = null;
      }
      if (zxingControls) { try { zxingControls.stop(); } catch { /* déjà arrêté */ } zxingControls = null; }
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
      // 1) Choix du décodeur : BarcodeDetector natif (multi-format) d'abord.
      const wanted = formatsRef.current;
      try {
        if ('BarcodeDetector' in window) {
          const supported = (await window.BarcodeDetector.getSupportedFormats?.()) || wanted;
          const usable = wanted.filter((fmt) => supported.includes(fmt));
          if (usable.length) detector = new window.BarcodeDetector({ formats: usable });
        }
      } catch { detector = null; }
      // 2) Repli jsQR : QR UNIQUEMENT. Si un format 1D (ex. code-barres ISBN/EAN)
      //    est demandé sans BarcodeDetector, aucun décodeur → saisie manuelle.
      if (!detector) {
        const onlyQr = wanted.every((fmt) => fmt === 'qr_code');
        if (onlyQr) {
          try {
            const mod = await import('jsqr');
            decodeJsqr = mod.default || mod;
          } catch {
            if (!cancelled) setError(tRef.current({ id: 'card.resolve.scan.error.unsupported' }));
            return;
          }
        } else {
          // Format 1D (code-barres ISBN/EAN) SANS BarcodeDetector (Brave,
          // iOS/Safari, Firefox) → ZXing (pur-JS, universel), chargé à la demande.
          // ZXing ouvre et gère sa propre caméra arrière sur l'élément vidéo.
          try {
            const [{ BrowserMultiFormatReader }, zxlib] = await Promise.all([
              import('@zxing/browser'),
              import('@zxing/library'),
            ]);
            const zxMap = {
              qr_code: zxlib.BarcodeFormat.QR_CODE,
              ean_13: zxlib.BarcodeFormat.EAN_13,
              ean_8: zxlib.BarcodeFormat.EAN_8,
            };
            const hints = new Map([
              [zxlib.DecodeHintType.POSSIBLE_FORMATS, wanted.map((fmt) => zxMap[fmt]).filter((v) => v !== undefined)],
              [zxlib.DecodeHintType.TRY_HARDER, true], // décodage plus insistant (utile webcam desktop)
            ]);
            const reader = new BrowserMultiFormatReader(hints);
            zxingControls = await reader.decodeFromConstraints(
              { video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } } },
              videoRef.current,
              (result) => { if (result) handleToken(result.getText()); },
            );
            if (cancelled && zxingControls) { try { zxingControls.stop(); } catch { /* */ } }
          } catch (e) {
            if (!cancelled) {
              const name = e && e.name;
              const key = (name === 'NotAllowedError' || name === 'SecurityError')
                ? 'card.resolve.scan.error.permission'
                : 'card.resolve.scan.error.unsupported';
              setError(tRef.current({ id: key, defaultMessage: tRef.current({ id: 'card.resolve.scan.error.generic' }) }));
            }
          }
          return; // ZXing gère sa caméra → ne pas passer par le getUserMedia ci-dessous.
        }
      }

      // 2) Ouverture de la caméra arrière.
      try {
        const stream = await navigator.mediaDevices.getUserMedia({
          // Haute résolution : plus de pixels sur le code-barres (1D exigeant),
          // décisif sur webcam desktop ; `ideal` retombe sur le mieux disponible.
          video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } },
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
            style={{ width: '100%', maxWidth: 420, aspectRatio: '4 / 3', objectFit: 'cover', borderRadius: 10, background: '#000' }}
          />
          <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', margin: 0 }}>
            {prompt || t({ id: 'card.resolve.scan.prompt' })}
          </p>
        </>
      )}
      <Button onClick={onClose}>{t({ id: 'card.resolve.scan.close' })}</Button>
    </div>
  );
}
