import { useEffect, useRef, useState } from 'react';
import { useIntl } from 'react-intl';

// ═══════════════════════════════════════════════════════════════════════════
// VisioRoom — visio Jitsi embarquée (degré 3 de l'entraide, cadrage §8).
//
// Intégration via l'iframe External API, **domaine en configuration**
// (VITE_JITSI_DOMAIN, défaut meet.jit.si) → jamais verrouillé à un fournisseur ;
// swappable vers une instance militante libre sans toucher au code. Salle =
// nom passé par l'appelant (anarbib-entraide-<uuid> : l'uuid de l'appel rend la
// salle non-devinable). Repli « ouvrir dans un onglet » si l'API ne charge pas
// (CSP, réseau). Zéro serveur, zéro secret, zéro coût (client d'une instance).
// ═══════════════════════════════════════════════════════════════════════════

const JITSI_DOMAIN = (import.meta.env.VITE_JITSI_DOMAIN || 'meet.jit.si')
  .replace(/^https?:\/\//, '').replace(/\/+$/, '');

export default function VisioRoom({ roomName, onClose }) {
  const { formatMessage: t } = useIntl();
  const containerRef = useRef(null);
  const apiRef = useRef(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    const start = () => {
      if (cancelled || !containerRef.current || !window.JitsiMeetExternalAPI) { setFailed(true); return; }
      try {
        apiRef.current = new window.JitsiMeetExternalAPI(JITSI_DOMAIN, {
          roomName,
          parentNode: containerRef.current,
          width: '100%', height: '100%',
          configOverwrite: { prejoinPageEnabled: true, disableDeepLinking: true },
          interfaceConfigOverwrite: { MOBILE_APP_PROMO: false },
        });
        apiRef.current.addEventListener('readyToClose', () => onClose?.());
      } catch { setFailed(true); }
    };
    if (window.JitsiMeetExternalAPI) { start(); return () => { cancelled = true; try { apiRef.current?.dispose(); } catch { /* noop */ } }; }
    const script = document.createElement('script');
    script.src = `https://${JITSI_DOMAIN}/external_api.js`;
    script.async = true;
    script.onload = start;
    script.onerror = () => { if (!cancelled) setFailed(true); };
    document.body.appendChild(script);
    return () => { cancelled = true; try { apiRef.current?.dispose(); } catch { /* noop */ } };
  }, [roomName, onClose]);

  const directUrl = `https://${JITSI_DOMAIN}/${roomName}`;

  return (
    <div style={overlay} role="dialog" aria-modal="true">
      <div style={bar}>
        <span style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'federacao.entraide.visio' })} · {JITSI_DOMAIN}</span>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <a href={directUrl} target="_blank" rel="noopener noreferrer" style={linkBtn}>{t({ id: 'federacao.entraide.visioNewTab' })} ↗</a>
          <button type="button" onClick={onClose} style={closeBtn} aria-label={t({ id: 'common.close' })}>✕</button>
        </div>
      </div>
      {failed ? (
        <div style={fallback}>
          <p style={{ marginBottom: 14 }}>{t({ id: 'federacao.entraide.visioFallback' })}</p>
          <a href={directUrl} target="_blank" rel="noopener noreferrer" className="cat-btn primary">{t({ id: 'federacao.entraide.visioNewTab' })} ↗</a>
        </div>
      ) : (
        <div ref={containerRef} style={{ flex: 1, minHeight: 0 }} />
      )}
    </div>
  );
}

const overlay = { position: 'fixed', inset: 0, zIndex: 1000, display: 'flex', flexDirection: 'column', background: 'rgba(8,8,8,.97)' };
const bar = { display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 14px', borderBottom: '1px solid rgba(255,255,255,.1)', flex: 'none' };
const linkBtn = { fontSize: '.8rem', color: 'var(--brand-text, #f5f2ea)', textDecoration: 'none', padding: '4px 10px', borderRadius: 8, border: '1px solid var(--brand-panel-border, rgba(255,255,255,.18))' };
const closeBtn = { background: 'transparent', border: 'none', color: 'var(--brand-text, #f5f2ea)', fontSize: '1.1rem', cursor: 'pointer', lineHeight: 1, padding: '2px 6px' };
const fallback = { flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', color: 'var(--brand-text, #f5f2ea)', padding: 24 };
