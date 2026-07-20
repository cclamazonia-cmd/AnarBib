import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

/**
 * StabilizedPartnershipsSection — §21 PARTNER, sous-lot P5b
 * --------------------------------------------------------------------------
 * Console coordenador des partenariats STABILISÉS (au-dessus de l'annuaire
 * déclaratif géré par LibraryPartnershipsSection). Cycle de vie « deux pour
 * s'unir, un seul pour partir » (PARTNER-D7) + activation des droits réciproques
 * droit par droit (D2/D9).
 *
 * Lecture  : RPC fn_partnership_list_mine (P5a).
 * Écritures: RPC P2 fn_partnership_propose / accept / refuse / break / set_right.
 * Droits   : réservé au staff de coordination (prop canEdit = isCoord).
 */

const RIGHT_KEYS = ['transparence', 'digital_share', 'mutualisation', 'peb'];

export default function StabilizedPartnershipsSection({ libraryId, canEdit, allLibraries = [] }) {
  const intl = useIntl();
  const t = (d, v) => intl.formatMessage(d, v);

  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [proposing, setProposing] = useState(false);
  const [selectedLib, setSelectedLib] = useState('');

  const bx = { padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)',
    border: '1px solid rgba(255,255,255,.08)', marginTop: 16 };
  const lw = { border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, overflow: 'hidden' };
  const lr = (i) => ({ padding: '10px 12px',
    background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
    borderBottom: '1px solid rgba(255,255,255,.04)' });
  const muted = { fontSize: '.82rem', color: 'var(--brand-muted)' };
  const subTitle = { fontSize: '.8rem', fontWeight: 600, margin: '12px 0 6px' };

  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const { data, error: e } = await supabase.rpc('fn_partnership_list_mine', { p_library_id: libraryId });
      if (e) throw e;
      setRows(data || []);
      setError('');
    } catch (err) {
      setError(localizeError(err, t));
    } finally {
      setLoading(false);
    }
  }, [libraryId]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { load(); }, [load]);

  const incoming = useMemo(() => rows.filter(r => r.direction === 'incoming'), [rows]);
  const outgoing = useMemo(() => rows.filter(r => r.direction === 'outgoing'), [rows]);
  const active = useMemo(() => rows.filter(r => r.direction === 'active'), [rows]);

  const partneredIds = useMemo(
    () => new Set(rows.filter(r => ['incoming', 'outgoing', 'active'].includes(r.direction))
      .map(r => r.partner_library_id)),
    [rows]
  );
  const availableLibraries = useMemo(
    () => allLibraries.filter(l => l.network_mode === 'federated' && l.id !== libraryId && !partneredIds.has(l.id)),
    [allLibraries, libraryId, partneredIds]
  );

  const run = async (fn) => {
    if (busy) return;
    setBusy(true); setError('');
    try { await fn(); await load(); }
    catch (err) { setError(localizeError(err, t)); }
    finally { setBusy(false); }
  };
  const propose = () => run(async () => {
    const { error: e } = await supabase.rpc('fn_partnership_propose',
      { p_library_id: libraryId, p_partner_library_id: selectedLib });
    if (e) throw e;
    setProposing(false); setSelectedLib('');
  });
  const accept = (id) => run(async () => {
    const { error: e } = await supabase.rpc('fn_partnership_accept', { p_partnership_id: id });
    if (e) throw e;
  });
  const refuse = (id) => run(async () => {
    const { error: e } = await supabase.rpc('fn_partnership_refuse', { p_partnership_id: id });
    if (e) throw e;
  });
  const breakPartnership = (id) => {
    if (!confirm(t({ id: 'biblioteca.stabPartners.breakConfirm' }))) return;
    run(async () => {
      const { error: e } = await supabase.rpc('fn_partnership_break', { p_partnership_id: id, p_reason: null });
      if (e) throw e;
    });
  };
  const toggleRight = (id, key, enabled) => run(async () => {
    const { error: e } = await supabase.rpc('fn_partnership_set_right',
      { p_partnership_id: id, p_right_key: key, p_enabled: enabled });
    if (e) throw e;
  });

  const libLabel = (l) => l.short_name || l.name || l.slug;

  return (
    <div style={bx}>
      <h4 style={{ margin: '0 0 4px' }}>{t({ id: 'biblioteca.stabPartners.title' })}</h4>
      <div style={{ ...muted, marginBottom: 10 }}>{t({ id: 'biblioteca.stabPartners.hint' })}</div>

      {error && (
        <div className="cat-pill warn" style={{ display: 'block', marginBottom: 10, fontSize: '.78rem' }}>{error}</div>
      )}
      {loading && <div style={muted}>{t({ id: 'biblioteca.partnerships.loading' })}</div>}

      {!loading && incoming.length === 0 && outgoing.length === 0 && active.length === 0 && (
        <div style={muted}>{t({ id: 'biblioteca.stabPartners.empty' })}</div>
      )}

      {/* Propositions entrantes */}
      {!loading && incoming.length > 0 && (
        <>
          <div style={subTitle}>{t({ id: 'biblioteca.stabPartners.incomingTitle' })}</div>
          <div style={lw}>
            {incoming.map((r, i) => (
              <div key={r.partnership_id} style={{ ...lr(i), display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                <span style={{ fontSize: '.9rem', fontWeight: 600 }}>{r.partner_name}</span>
                {canEdit && (
                  <span style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                    <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => accept(r.partnership_id)}>
                      {t({ id: 'biblioteca.stabPartners.accept' })}
                    </button>
                    <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => refuse(r.partnership_id)}>
                      {t({ id: 'biblioteca.stabPartners.refuse' })}
                    </button>
                  </span>
                )}
              </div>
            ))}
          </div>
        </>
      )}

      {/* Propositions sortantes */}
      {!loading && outgoing.length > 0 && (
        <>
          <div style={subTitle}>{t({ id: 'biblioteca.stabPartners.outgoingTitle' })}</div>
          <div style={lw}>
            {outgoing.map((r, i) => (
              <div key={r.partnership_id} style={{ ...lr(i), display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                <span style={{ fontSize: '.9rem', fontWeight: 600 }}>{r.partner_name}</span>
                <span className="cat-pill" style={{ fontSize: '.66rem' }}>{t({ id: 'biblioteca.stabPartners.pending' })}</span>
              </div>
            ))}
          </div>
        </>
      )}

      {/* Partenariats actifs + droits */}
      {!loading && active.length > 0 && (
        <>
          <div style={subTitle}>{t({ id: 'biblioteca.stabPartners.activeTitle' })}</div>
          <div style={lw}>
            {active.map((r, i) => {
              const rights = r.rights || [];
              return (
                <div key={r.partnership_id} style={lr(i)}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    <span style={{ fontSize: '.9rem', fontWeight: 600 }}>{r.partner_name}</span>
                    {canEdit && (
                      <button className="cat-tab-btn" style={{ fontSize: '.74rem', flexShrink: 0 }} disabled={busy}
                        onClick={() => breakPartnership(r.partnership_id)}>
                        {t({ id: 'biblioteca.stabPartners.break' })}
                      </button>
                    )}
                  </div>
                  <div style={{ marginTop: 6 }}>
                    <div style={muted}>{t({ id: 'biblioteca.stabPartners.rightsLabel' })}</div>
                    <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginTop: 4 }}>
                      {RIGHT_KEYS.map(key => (
                        <label key={key} style={{ ...muted, display: 'flex', alignItems: 'center', gap: 4 }}>
                          <input type="checkbox" checked={rights.includes(key)} disabled={!canEdit || busy}
                            onChange={(e) => toggleRight(r.partnership_id, key, e.target.checked)} />
                          {t({ id: `biblioteca.stabPartners.right.${key}` })}
                        </label>
                      ))}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}

      {/* Proposer un nouveau partenariat */}
      {canEdit && !loading && (
        <div style={{ marginTop: 12 }}>
          {!proposing ? (
            <button className="cat-tab-btn" style={{ fontSize: '.78rem' }}
              disabled={availableLibraries.length === 0}
              onClick={() => { setProposing(true); setSelectedLib(''); }}>
              {t({ id: 'biblioteca.stabPartners.propose' })}
            </button>
          ) : (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
              <select value={selectedLib} onChange={(e) => setSelectedLib(e.target.value)} style={{ flex: '1 1 220px', minWidth: 0 }}>
                <option value="">{t({ id: 'biblioteca.stabPartners.selectLibrary' })}</option>
                {availableLibraries.map(l => <option key={l.id} value={l.id}>{libLabel(l)}</option>)}
              </select>
              <button className="cat-tab-btn" style={{ fontSize: '.78rem' }} disabled={!selectedLib || busy} onClick={propose}>
                {t({ id: 'biblioteca.stabPartners.confirmPropose' })}
              </button>
              <button className="cat-tab-btn" style={{ fontSize: '.78rem' }} disabled={busy}
                onClick={() => { setProposing(false); setSelectedLib(''); }}>
                {t({ id: 'biblioteca.stabPartners.cancel' })}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
