// ═══════════════════════════════════════════════════════════════════════════
// AltchaWidget — preuve de travail anti-robots, sans aucun service tiers
// ═══════════════════════════════════════════════════════════════════════════
//
// Remplace <Turnstile>. Cf. docs/journal/arbitrages/DECISION_anti_robots_2026-08-20.md
//
// Le principe : le serveur émet un défi signé, on le résout ici par force
// brute dans un Web Worker, on renvoie la solution. Personne d'autre n'est
// dans la boucle — aucune requête ne part vers Cloudflare ni ailleurs.
//
// CE QUE ÇA ARRÊTE, ET CE QUE ÇA N'ARRÊTE PAS. Une preuve de travail ne stoppe
// pas un attaquant déterminé : sa vraie valeur ici est d'obliger quiconque
// veut poster ce formulaire à exécuter notre JavaScript et à suivre un
// protocole en deux temps. Un script qui se contente d'appeler l'endpoint
// échoue. C'est l'essentiel du déversement automatisé.
//
// Démarre tout seul au montage : rien à cliquer, rien à déchiffrer, aucune
// image de passage piéton. C'est aussi ça, l'intérêt.
// ═══════════════════════════════════════════════════════════════════════════

import { useEffect, useRef, useState, useCallback } from 'react';
import { useIntl } from 'react-intl';

const FONCTION_DEFI = 'altcha-challenge';

/**
 * @param {(charge: string|null) => void} onSolved  reçoit la charge base64, ou
 *        null quand la solution devient caduque (échec, remise à zéro).
 * @param {number} resetKey  changer cette valeur relance un nouveau défi. À
 *        incrémenter après chaque soumission refusée : une solution ne vaut
 *        qu'une fois, l'anti-rejeu côté serveur la refuserait (AR-4).
 */
export default function AltchaWidget({ onSolved, resetKey = 0 }) {
  const { formatMessage } = useIntl();
  const t = (id) => formatMessage({ id });
  const [etat, setEtat] = useState('attente'); // attente | calcul | ok | erreur
  const [ratio, setRatio] = useState(0);
  const workerRef = useRef(null);
  const vivantRef = useRef(true);

  const lancer = useCallback(async () => {
    setEtat('calcul');
    setRatio(0);
    onSolved(null);

    let defi;
    try {
      const base = import.meta.env.VITE_SUPABASE_URL;
      const r = await fetch(`${base}/functions/v1/${FONCTION_DEFI}`, {
        headers: { apikey: import.meta.env.VITE_SUPABASE_ANON_KEY },
      });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      defi = await r.json();
    } catch {
      if (vivantRef.current) setEtat('erreur');
      return;
    }
    if (!vivantRef.current) return;

    // Worker créé à chaque défi : un worker mort ne laisse rien traîner, et
    // ça évite d'avoir à gérer l'état d'un worker réutilisé.
    workerRef.current?.terminate();
    const w = new Worker(new URL('../../lib/altcha/solver.worker.js', import.meta.url), { type: 'module' });
    workerRef.current = w;

    w.onmessage = (e) => {
      const m = e.data || {};
      if (!vivantRef.current) return;
      if (m.type === 'progres') { setRatio(m.ratio); return; }
      if (m.type === 'ok') {
        const charge = btoa(JSON.stringify({
          algorithm: defi.algorithm,
          challenge: defi.challenge,
          number: m.number,
          salt: defi.salt,
          signature: defi.signature,
        }));
        setEtat('ok');
        setRatio(1);
        onSolved(charge);
        w.terminate();
        return;
      }
      setEtat('erreur');
      onSolved(null);
      w.terminate();
    };
    w.onerror = () => { if (vivantRef.current) { setEtat('erreur'); onSolved(null); } };
    w.postMessage({ salt: defi.salt, challenge: defi.challenge, maxnumber: defi.maxnumber });
  }, [onSolved]);

  useEffect(() => {
    vivantRef.current = true;
    lancer();
    return () => { vivantRef.current = false; workerRef.current?.terminate(); };
    // resetKey dans les dépendances : c'est lui qui relance un défi neuf.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [resetKey]);

  const messages = {
    attente: t('altcha.attente'),
    calcul: t('altcha.calcul'),
    ok: t('altcha.ok'),
    erreur: t('altcha.erreur'),
  };

  return (
    <div
      role="status"
      aria-live="polite"
      style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '10px 12px', margin: '4px 0',
        border: '1px solid rgba(255,255,255,.14)', borderRadius: 8,
        fontSize: '.85rem', color: 'var(--brand-muted)',
      }}
    >
      <span aria-hidden="true" style={{ fontSize: '1rem', lineHeight: 1 }}>
        {etat === 'ok' ? '✓' : etat === 'erreur' ? '!' : '·'}
      </span>

      <span style={{ flex: 1 }}>{messages[etat]}</span>

      {etat === 'calcul' && (
        <span
          aria-hidden="true"
          style={{
            width: 70, height: 4, borderRadius: 2,
            background: 'rgba(255,255,255,.12)', overflow: 'hidden',
          }}
        >
          <span style={{
            display: 'block', height: '100%',
            width: `${Math.round(ratio * 100)}%`,
            background: 'var(--brand-red, #B32025)',
            transition: 'width .2s linear',
          }} />
        </span>
      )}

      {etat === 'erreur' && (
        <button
          type="button"
          className="cat-btn secondary"
          onClick={lancer}
          style={{ padding: '2px 10px', fontSize: '.8rem' }}
        >
          {t('altcha.reessayer')}
        </button>
      )}
    </div>
  );
}
