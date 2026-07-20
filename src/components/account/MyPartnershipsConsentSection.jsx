import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { Button } from '@/components/ui';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

/**
 * MyPartnershipsConsentSection — §21 PARTNER, sous-lot P6b
 * --------------------------------------------------------------------------
 * Encart `/conta` (onglet « Mes bibliothèques ») : consentement opt-in de la
 * lectrice à la transparence enrichie d'un partenariat (PARTNER-D1/D8).
 * Effet immédiat (la RLS de transparence lit le consentement à la lecture).
 *
 * Lecture  : RPC fn_reader_my_partnerships (P6a) — n'affiche que les partenariats
 *            actifs où elle est membre des deux biblios et le droit transparence
 *            est actif. Si aucun, le composant ne rend rien.
 * Écritures: RPC P3 fn_partnership_consent / fn_partnership_revoke_consent.
 */
export default function MyPartnershipsConsentSection() {
  const { formatMessage: t } = useIntl();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error: e } = await supabase.rpc('fn_reader_my_partnerships');
      if (e) throw e;
      setRows(data || []);
      setError('');
    } catch (err) {
      setError(localizeError(err, t));
    } finally {
      setLoading(false);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { load(); }, [load]);

  const act = async (id, consent) => {
    if (busy) return;
    setBusy(true); setError('');
    try {
      const fn = consent ? 'fn_partnership_consent' : 'fn_partnership_revoke_consent';
      const { error: e } = await supabase.rpc(fn, { p_partnership_id: id });
      if (e) throw e;
      await load();
    } catch (err) {
      setError(localizeError(err, t));
    } finally {
      setBusy(false);
    }
  };

  // Discret : rien tant que ça charge, et rien si aucun partenariat ne la concerne.
  if (loading || rows.length === 0) return null;

  const rowStyle = {
    display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap',
    padding: '10px 12px', borderRadius: 8, marginBottom: 6,
    background: 'rgba(0,0,0,.08)', border: '1px solid rgba(255,255,255,.06)',
  };

  return (
    <div style={{ marginTop: 20 }}>
      <h2 className="ab-conta-section-title">{t({ id: 'account.partnerships.title' })}</h2>
      <p className="ab-conta-hint">{t({ id: 'account.partnerships.hint' })}</p>
      {error && <p className="ab-conta-hint" style={{ color: '#f87171' }}>{error}</p>}
      {rows.map(r => (
        <div key={r.partnership_id} style={rowStyle}>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 600 }}>
              {t({ id: 'account.partnerships.between' }, { a: r.library_a_name, b: r.library_b_name })}
            </div>
            <div className="ab-conta-hint" style={{ margin: 0 }}>
              {t({ id: `account.partnerships.state.${r.consent_state}` })}
            </div>
          </div>
          {r.consent_state === 'valid' ? (
            <Button variant="secondary" disabled={busy} onClick={() => act(r.partnership_id, false)}>
              {t({ id: 'account.partnerships.revoke' })}
            </Button>
          ) : (
            <Button disabled={busy} onClick={() => act(r.partnership_id, true)}>
              {t({ id: 'account.partnerships.consent' })}
            </Button>
          )}
        </div>
      ))}
    </div>
  );
}
