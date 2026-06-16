import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// ═══════════════════════════════════════════════════════════════════════════
// LettreTab — onglet « Lettre » de la face fédération (carta).
// Abonnement à la Lettre de la fédération (newsletter opt-in, double opt-in).
// Ouvert à tout membre rattaché. Réutilise les clés account.lettre.* (mêmes que
// la carte de /conta) et les RPC api.fn_* via apiRpc (schéma `api`).
// ═══════════════════════════════════════════════════════════════════════════
export default function LettreTab() {
  const { formatMessage: t } = useIntl();
  const [consent, setConsent] = useState({ consent_lettre: false, pending: false });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await apiRpc('fn_get_my_lettre_consent');
      if (Array.isArray(data) && data.length > 0) {
        setConsent({ consent_lettre: !!data[0].consent_lettre, pending: !!data[0].pending });
      }
    } finally {
      setLoading(false);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function toggle(want) {
    setSaving(true);
    setMsg('');
    try {
      if (want) {
        const { data, error } = await apiRpc('fn_lettre_request_optin');
        if (error) throw error;
        if (data === 'already_subscribed') {
          setConsent({ consent_lettre: true, pending: false });
        } else {
          setConsent((c) => ({ ...c, pending: true }));
          setMsg(t({ id: 'account.lettre.confirmationSent' }));
        }
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

  return (
    <div className="ab-fed-inicio">
      <div className="ab-fed-welcome">
        <h3>{t({ id: 'account.lettre.title' })}</h3>
        <p>{t({ id: 'account.lettre.intro' })}</p>
      </div>

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
