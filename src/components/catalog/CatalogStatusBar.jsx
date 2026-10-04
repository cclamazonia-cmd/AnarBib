import { useEffect, useRef } from 'react';
import { useIntl } from 'react-intl';

/* ════════════════════════════════════════════════════════════════════════
   AnarBib — barre d'état du catalogage (Xavier, 04/10/2026 : « barre collante
   + toast »). Remplace les huit boîtes de message recopiées panneau par
   panneau (couleurs en dur, « warn » sans style, erreurs affichées en vert…).

   <CatalogStatusBar msg={msg} onClose={() => setMsg({ text: '', kind: '' })} />

   - Collante en haut du panneau : visible où que l'on soit dans le formulaire,
     sans faire sauter la page.
   - kind : 'ok' | 'warn' | 'error' | 'info' (tout autre type vaut 'info',
     jamais une fausse alerte rouge ni un faux succès vert).
   - Un succès s'efface seul après SUCCESS_TTL ; avertissement et erreur
     restent jusqu'à ce qu'on les ferme (ou qu'une autre action les remplace).
   - Accessibilité : l'erreur est un role="alert", le reste un role="status"
     (aria-live polite).
   ════════════════════════════════════════════════════════════════════════ */

const SUCCESS_TTL = 10000;
const KINDS = new Set(['ok', 'warn', 'error', 'info']);
const ICONES = { ok: '✓', warn: '!', error: '✕', info: 'i' };

export default function CatalogStatusBar({ msg, onClose }) {
  const { formatMessage: t } = useIntl();
  const text = typeof msg === 'string' ? msg : msg?.text;
  const brut = typeof msg === 'string' ? 'ok' : msg?.kind;
  const kind = KINDS.has(brut) ? brut : 'info';

  // onClose est le plus souvent une lambda en ligne, neuve à chaque rendu : on
  // la lit dans une ref pour que le minuteur ne reparte pas à chaque frappe.
  const fermer = useRef(onClose);
  fermer.current = onClose;
  useEffect(() => {
    if (!text || kind !== 'ok') return undefined;
    const h = setTimeout(() => fermer.current?.(), SUCCESS_TTL);
    return () => clearTimeout(h);
  }, [text, kind]);

  if (!text) return null;
  return (
    <div className={`cat-status cat-status--${kind}`} role={kind === 'error' ? 'alert' : 'status'}
      aria-live={kind === 'error' ? 'assertive' : 'polite'}>
      <span className="cat-status__icon" aria-hidden="true">{ICONES[kind]}</span>
      <span className="cat-status__text">{text}</span>
      {onClose && (
        <button type="button" className="cat-status__close" onClick={onClose}
          aria-label={t({ id: 'common.close' })} title={t({ id: 'common.close' })}>×</button>
      )}
    </div>
  );
}
