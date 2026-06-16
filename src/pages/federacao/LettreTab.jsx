import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import Markdown from 'react-markdown';
import { apiRpc, apiQuery } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════════════════════
// LettreTab — onglet « Lettre » de la face fédération (carta).
// (1) Lecture in-app du dernier numéro ENVOYÉ (vues api.lettre(_locales)_public_v1,
//     corps markdown via react-markdown, sélecteur de locale).
// (2) Abonnement opt-in (double opt-in) — clés account.lettre.* + RPC via apiRpc.
// Ouvert à tout membre rattaché ; lecture publique (anon) des numéros envoyés.
// ═══════════════════════════════════════════════════════════════════════════

const LOCALE_NAMES = {
  'pt-BR': 'Português (BR)', fr: 'Français', es: 'Castellano', en: 'English',
  it: 'Italiano', de: 'Deutsch', el: 'Ελληνικά', ca: 'Català', eo: 'Esperanto', nl: 'Nederlands',
};
const LOC_ORDER = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'el', 'ca', 'eo', 'nl'];

export default function LettreTab() {
  const { formatMessage: t, locale: appLocale } = useIntl();

  // — Lecture du dernier numéro envoyé —
  const [letter, setLetter] = useState(null);   // { number, byLocale }
  const [readLoc, setReadLoc] = useState(null);

  // — Abonnement —
  const [consent, setConsent] = useState({ consent_lettre: false, pending: false });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      // Abonnement (premier·e personne)
      const { data } = await apiRpc('fn_get_my_lettre_consent');
      if (Array.isArray(data) && data.length > 0) {
        setConsent({ consent_lettre: !!data[0].consent_lettre, pending: !!data[0].pending });
      }
      // Dernier numéro envoyé + ses locales
      const iss = await apiQuery('lettre_public_v1', { order: 'number.desc' });
      const latest = iss.data?.[0];
      if (latest) {
        const locs = await apiQuery('lettre_locales_public_v1', { filters: { issue_number: `eq.${latest.number}` } });
        const byLocale = Object.fromEntries((locs.data || []).map((r) => [r.locale, r]));
        setLetter({ number: latest.number, byLocale });
        setReadLoc(byLocale[appLocale] ? appLocale : (byLocale.fr ? 'fr' : Object.keys(byLocale)[0] || null));
      }
    } finally {
      setLoading(false);
    }
  }, [appLocale]);
  useEffect(() => { load(); }, [load]);

  async function toggle(want) {
    setSaving(true);
    setMsg('');
    try {
      if (want) {
        const { data, error } = await apiRpc('fn_lettre_request_optin');
        if (error) throw error;
        if (data === 'already_subscribed') setConsent({ consent_lettre: true, pending: false });
        else { setConsent((c) => ({ ...c, pending: true })); setMsg(t({ id: 'account.lettre.confirmationSent' })); }
      } else {
        const { error } = await apiRpc('fn_lettre_cancel');
        if (error) throw error;
        setConsent({ consent_lettre: false, pending: false });
        setMsg(t({ id: 'account.lettre.unsubscribed' }));
      }
    } catch (e) {
      setMsg(localizeError(e, t));
    } finally {
      setSaving(false);
    }
  }

  const subscribed = consent.consent_lettre || consent.pending;
  const readableLocs = letter ? LOC_ORDER.filter((l) => letter.byLocale[l]) : [];
  const current = letter && readLoc ? letter.byLocale[readLoc] : null;

  return (
    <div className="ab-fed-inicio">
      <div className="ab-fed-welcome">
        <h3>{t({ id: 'account.lettre.title' })}</h3>
        <p>{t({ id: 'account.lettre.intro' })}</p>
      </div>

      {/* ── Lecture du dernier numéro envoyé ── */}
      {current && (
        <div className="ab-fed-inicio-box" style={{ maxWidth: 760 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 10 }}>
            <div className="ab-fed-label" style={{ margin: 0 }}>
              {current.title || `N°${String(letter.number).padStart(2, '0')}`}
            </div>
            {readableLocs.length > 1 && (
              <select
                value={readLoc} onChange={(e) => setReadLoc(e.target.value)}
                style={{ padding: '6px 10px', borderRadius: 8, border: '1px solid var(--brand-panel-border)', background: 'rgba(255,255,255,.05)', color: 'var(--brand-text)', fontSize: '.85rem' }}
              >
                {readableLocs.map((l) => <option key={l} value={l}>{LOCALE_NAMES[l] || l}</option>)}
              </select>
            )}
          </div>
          <div className="ab-fed-lettre-body" style={{ lineHeight: 1.6 }}>
            <Markdown>{current.body_md || ''}</Markdown>
          </div>
        </div>
      )}

      {/* ── Abonnement opt-in ── */}
      <div className="ab-fed-inicio-box" style={{ maxWidth: 580 }}>
        {loading ? (
          <p className="ab-fed-hint">{t({ id: 'common.loading' })}</p>
        ) : (
          <>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: saving ? 'wait' : 'pointer' }}>
              <input type="checkbox" checked={subscribed} disabled={saving} onChange={(e) => toggle(e.target.checked)} />
              <span>{t({ id: 'account.lettre.toggle' })}</span>
            </label>
            {consent.pending && (
              <p className="ab-fed-hint" style={{ marginTop: 10, marginBottom: 0 }}>{t({ id: 'account.lettre.pending' })}</p>
            )}
            {consent.consent_lettre && !consent.pending && (
              <p className="ab-fed-hint" style={{ marginTop: 10, marginBottom: 0 }}>{t({ id: 'account.lettre.subscribed' })}</p>
            )}
            {msg && (
              <p className="ab-fed-hint" style={{ marginTop: 10, marginBottom: 0, color: 'var(--brand-text)' }}>{msg}</p>
            )}
            <p className="ab-fed-hint" style={{ marginTop: 12, marginBottom: 0, fontSize: '.78rem', fontStyle: 'italic' }}>
              {t({ id: 'account.lettre.note' })}
            </p>
          </>
        )}
      </div>
    </div>
  );
}
