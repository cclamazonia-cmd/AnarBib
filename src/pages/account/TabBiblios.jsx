import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// MULTI P5a/P5c — Onglet « Mes biblios » : vue agrégée des appartenances de la
// lectrice (spec §3 lecture agrégée, §5 numéro local, §17.2 statut par biblio) +
// auto-inscription (P5c, spec §8 : request_membership, garde β.1 côté backend).
// Consomme api.fn_my_memberships_status (RPC P2) et api.request_membership (P4).

const STATUS_KEY = {
  active: 'account.biblios.status.active',
  pending_validation: 'account.biblios.status.pending_validation',
  suspended: 'account.biblios.status.suspended',
  pending_removal: 'account.biblios.status.pending_removal',
  left_with_pending_circulation: 'account.biblios.status.left_with_pending_circulation',
  terminated: 'account.biblios.status.terminated',
  inactive: 'account.biblios.status.inactive',
  removed: 'account.biblios.status.removed',
};
const STATUS_COLOR = {
  active: '#4ade80',
  pending_validation: '#fbbf24',
  suspended: '#f87171',
  pending_removal: '#fbbf24',
  left_with_pending_circulation: '#fbbf24',
  terminated: '#9ca3af',
  inactive: '#9ca3af',
  removed: '#9ca3af',
};

export default function TabBiblios() {
  const { formatMessage: t } = useIntl();
  const [rows, setRows] = useState(null);
  const [joinable, setJoinable] = useState([]);
  const [selectedLib, setSelectedLib] = useState('');
  const [joining, setJoining] = useState(false);
  const [joinMsg, setJoinMsg] = useState(null); // { kind: 'ok' | 'err', text }
  // Lot 3 — invitations à rejoindre une équipe (accueil d'équipe)
  const [invitations, setInvitations] = useState([]);
  const [invMsg, setInvMsg] = useState(null);
  const [invBusy, setInvBusy] = useState(false);

  const load = useCallback(async () => {
    let memberships = [];
    try {
      const { data } = await supabase.schema('api').rpc('fn_my_memberships_status');
      memberships = Array.isArray(data) ? data : [];
    } catch { memberships = []; }
    setRows(memberships);

    // Biblios joignables = inscriptions publiques ouvertes, hors celles où la
    // lectrice est déjà membre (RLS libraries_public_signup_read le permet).
    const memberIds = new Set(memberships.map((m) => m.library_id));
    try {
      const { data: libs } = await supabase
        .from('libraries')
        .select('id, slug, name, short_name')
        .eq('accepts_public_signup', true)
        .eq('is_active', true)
        .order('name');
      setJoinable((libs || []).filter((l) => !memberIds.has(l.id)));
    } catch { setJoinable([]); }

    // Invitations à rejoindre une équipe (RPC publique fn_team_my_invitations).
    try {
      const { data: inv } = await supabase.rpc('fn_team_my_invitations');
      setInvitations(Array.isArray(inv) ? inv : []);
    } catch { setInvitations([]); }
  }, []);

  const handleInvitation = useCallback(async (id, kind) => {
    if (invBusy) return;
    setInvBusy(true);
    setInvMsg(null);
    try {
      const fn = kind === 'accept' ? 'fn_team_accept_invitation' : 'fn_team_decline_invitation';
      const { data, error } = await supabase.rpc(fn, { p_invitation_id: id });
      if (error) throw error;
      const row = (data && typeof data === 'object') ? data : null;
      if (row && row.ok === false) {
        setInvMsg({ kind: 'err', text: row.message || t({ id: 'account.invitations.error' }) });
      } else {
        setInvMsg({ kind: 'ok', text: t({ id: kind === 'accept'
          ? 'account.invitations.acceptSuccess' : 'account.invitations.declineSuccess' }) });
        await load();
      }
    } catch (e) {
      setInvMsg({ kind: 'err', text: localizeError(e, t, 'account.invitations.error') });
    } finally {
      setInvBusy(false);
    }
  }, [invBusy, load, t]);

  useEffect(() => {
    let cancelled = false;
    (async () => { if (!cancelled) await load(); })();
    return () => { cancelled = true; };
  }, [load]);

  const handleJoin = useCallback(async () => {
    if (!selectedLib || joining) return;
    setJoining(true);
    setJoinMsg(null);
    try {
      const { data, error } = await supabase.schema('api').rpc('request_membership', {
        p_library_id: selectedLib,
      });
      if (error) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (row && row.ok === false) {
        // Cas non-exception (ex. déjà membre) — message renvoyé par la RPC.
        setJoinMsg({ kind: 'err', text: row.message || t({ id: 'account.biblios.joinError' }) });
      } else {
        setJoinMsg({ kind: 'ok', text: t({ id: 'account.biblios.joinSuccess' }) });
        setSelectedLib('');
        await load();
      }
    } catch (e) {
      setJoinMsg({ kind: 'err', text: localizeError(e, t, 'account.biblios.joinError') });
    } finally {
      setJoining(false);
    }
  }, [selectedLib, joining, load, t]);

  if (rows === null) {
    return <p className="ab-conta-hint">{t({ id: 'common.loading' })}</p>;
  }

  return (
    <div>
      {/* ── Invitations à rejoindre une équipe (lot 3 — accueil d'équipe) ── */}
      {invitations.length > 0 && (
        <div style={{ marginBottom: 24, padding: '14px 16px', borderRadius: 10, border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', background: 'var(--brand-panel-bg, rgba(255,255,255,.03))' }}>
          <h3 className="ab-conta-section-title" style={{ fontSize: '1rem', marginTop: 0 }}>
            {t({ id: 'account.invitations.heading' })}
          </h3>
          <div className="ab-conta-items">
            {invitations.map((inv) => {
              const ready = inv.status === 'ready';
              return (
                <div key={inv.id} className="ab-conta-item" style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
                  <div className="ab-conta-item__main" style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>
                    <span className="ab-conta-item__title">{inv.library_name}</span>
                    {/* Depuis la migration 20260826120000, une invitation peut
                        porter sur la coordination et plus seulement sur l'accueil
                        dans l'équipe : il faut dire de quoi il s'agit. */}
                    <span className="ab-conta-item__meta">
                      {t({ id: inv.role_proposed === 'coordenador'
                        ? 'team.invitations.role.coordenador'
                        : 'team.invitations.role.librarian' })}
                    </span>
                    <span className="ab-conta-item__meta">
                      {inv.proposed_by_name
                        ? t({ id: 'account.invitations.proposedBy' }, { name: inv.proposed_by_name })
                        : t({ id: 'account.invitations.asLibrarian' })}
                    </span>
                    <span className="ab-conta-item__meta" style={{ marginTop: 4, color: ready ? '#4ade80' : '#fbbf24' }}>
                      {ready ? t({ id: 'account.invitations.ready' }) : t({ id: 'account.invitations.pending' })}
                    </span>
                  </div>
                  <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                    {ready && (
                      <button type="button" className="ab-button ab-button--secondary" disabled={invBusy} onClick={() => handleInvitation(inv.id, 'accept')}>
                        {t({ id: 'account.invitations.accept' })}
                      </button>
                    )}
                    <button type="button" className="ab-button ab-button--mini" disabled={invBusy} onClick={() => handleInvitation(inv.id, 'decline')}>
                      {t({ id: 'account.invitations.decline' })}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
          {invMsg && (
            <p style={{ marginTop: 10, fontSize: '.85rem', color: invMsg.kind === 'ok' ? '#4ade80' : '#f87171' }}>
              {invMsg.text}
            </p>
          )}
        </div>
      )}

      <h2 className="ab-conta-section-title">{t({ id: 'account.biblios.title' })}</h2>
      <p className="ab-conta-hint">{t({ id: 'account.tab.libraries.hint' })}</p>

      {rows.length === 0 ? (
        <p className="ab-conta-empty">{t({ id: 'account.biblios.empty' })}</p>
      ) : (
        <div className="ab-conta-items">
          {rows.map((m) => (
            <div key={m.library_id} className="ab-conta-item" style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <div className="ab-conta-item__main" style={{ flex: 1, minWidth: 'min(180px, 100%)' }}>
                <span className="ab-conta-item__title">
                  {m.library_name}
                  {m.is_primary && (
                    <span style={{ marginLeft: 8, fontSize: '.72rem', color: 'var(--brand-muted)' }}>
                      · {t({ id: 'account.biblios.primary' })}
                    </span>
                  )}
                </span>
                <span className="ab-conta-item__meta">
                  {t({ id: `account.biblios.role.${m.role}`, defaultMessage: m.role })}
                  {m.local_reader_number && ` · ${t({ id: 'account.biblios.localNumber' })}: ${m.local_reader_number}`}
                </span>
                <span className="ab-conta-item__meta" style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 4 }}>
                  <span style={{ color: STATUS_COLOR[m.status] || '#9ca3af', fontWeight: 600 }}>
                    {STATUS_KEY[m.status] ? t({ id: STATUS_KEY[m.status] }) : m.status}
                  </span>
                  {m.physically_validated && <span style={{ color: '#4ade80' }}>✓ {t({ id: 'account.biblios.validated' })}</span>}
                  {m.is_restricted && <span style={{ color: '#f87171' }}>⚠ {t({ id: 'account.biblios.restricted' })}</span>}
                  {m.dues_blocking && <span style={{ color: '#fbbf24' }}>⚠ {t({ id: 'account.biblios.duesDue' })}</span>}
                </span>
              </div>
              {m.library_slug && (
                <div style={{ flexShrink: 0, alignSelf: 'center' }}>
                  <Link to={`/catalogo/${m.library_slug}`}>
                    <span className="ab-button ab-button--mini ab-button--secondary">
                      {t({ id: 'account.biblios.seeCatalog' })}
                    </span>
                  </Link>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* ── Auto-inscription (MULTI P5c, spec §8) ─────────────────────────── */}
      <div style={{ marginTop: 24, padding: '14px 16px', borderRadius: 10, border: '1px solid var(--brand-panel-border, rgba(255,255,255,.14))', background: 'var(--brand-panel-bg, rgba(255,255,255,.03))' }}>
        <h3 className="ab-conta-section-title" style={{ fontSize: '1rem', marginTop: 0 }}>
          {t({ id: 'account.biblios.joinTitle' })}
        </h3>
        <p className="ab-conta-hint">{t({ id: 'account.biblios.joinHint' })}</p>
        {joinable.length === 0 ? (
          <p className="ab-conta-empty">{t({ id: 'account.biblios.joinNone' })}</p>
        ) : (
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <select
              className="ab-input"
              value={selectedLib}
              onChange={(e) => { setSelectedLib(e.target.value); setJoinMsg(null); }}
              disabled={joining}
              style={{ flex: 1, minWidth: 'min(200px, 100%)' }}
            >
              <option value="">{t({ id: 'account.biblios.joinPlaceholder' })}</option>
              {joinable.map((l) => (
                <option key={l.id} value={l.id}>{l.name || l.short_name || l.slug}</option>
              ))}
            </select>
            <button
              type="button"
              className="ab-button ab-button--secondary"
              onClick={handleJoin}
              disabled={!selectedLib || joining}
            >
              {joining ? t({ id: 'common.loading' }) : t({ id: 'account.biblios.joinButton' })}
            </button>
          </div>
        )}
        {joinMsg && (
          <p style={{ marginTop: 10, fontSize: '.85rem', color: joinMsg.kind === 'ok' ? '#4ade80' : '#f87171' }}>
            {joinMsg.text}
          </p>
        )}
      </div>
    </div>
  );
}
