// OaiSourcePanel — onglet « Être source » de la page rede (paquet OAI-O3, 12/06/2026).
//
// Gouvernance de l'ouverture du endpoint OAI-PMH (« ser fonte », spec
// importacoes-exportacoes §8 / OAI-O1). DEUX sens :
//   - ASCENDANT  : le coordenador demande l'ouverture de SA biblio aux admins ;
//     un seul admin approuve. Fermeture manuelle par le coordenador ou un admin.
//   - DESCENDANT : un admin propose d'ouvrir le catalogue réseau à une entité
//     externe ; vote unanime des biblios concernées (21 j, silence = oui), une
//     voix par biblio (coordenador). Fermeture manuelle par un admin.
//
// Composant AUTONOME (n'écrit que via les RPC fn_oai_*). Bannière d'alerte
// permanente tant qu'une ouverture concerne l'usager·ère.

import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';

function Pill({ children, variant }) {
  return <span className={`cat-pill${variant ? ` ${variant}` : ''}`} style={{ fontSize: '.66rem' }}>{children}</span>;
}

export default function OaiSourcePanel() {
  const { formatMessage: t, locale } = useIntl();
  const { user } = useAuth();
  const { isNetworkAdmin } = useLibrary();

  const [requests, setRequests] = useState([]);
  const [votes, setVotes] = useState([]);          // votes des biblios coordonnées par l'usager·ère
  const [voteProgress, setVoteProgress] = useState({}); // {req_id: {concerned, consented, pending}} — agrégat SANS identité
  const [myCoordLibs, setMyCoordLibs] = useState([]); // [{ library_id, name, slug }]
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [extEntity, setExtEntity] = useState('');
  const [extNotes, setExtNotes] = useState('');

  const fmtDate = useCallback((d) => (d ? new Date(d).toLocaleDateString(locale) : '—'), [locale]);
  const flash = (text, kind = 'ok') => setMsg({ text, kind });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const reqP = supabase
        .from('oai_opening_requests')
        .select('*')
        .order('created_at', { ascending: false });

      const coordP = user
        ? supabase
            .from('user_library_memberships')
            .select('library_id, role, status, libraries(id, slug, name)')
            .eq('user_id', user.id)
            .eq('role', 'coordenador')
            .eq('status', 'active')
        : Promise.resolve({ data: [] });

      const [{ data: reqs, error: reqErr }, { data: mems }] = await Promise.all([reqP, coordP]);
      if (reqErr) throw reqErr;
      setRequests(reqs || []);

      // Progression des votes (agrégat sans identité) pour l'aperçu admin.
      const pendingVoteIds = (reqs || []).filter((r) => r.kind === 'network' && r.status === 'pending_vote').map((r) => r.id);
      if (pendingVoteIds.length) {
        const prog = await Promise.all(pendingVoteIds.map(async (id) => {
          const { data } = await supabase.rpc('fn_oai_network_vote_progress', { p_request_id: id });
          return [id, Array.isArray(data) ? data[0] : data];
        }));
        setVoteProgress(Object.fromEntries(prog));
      } else {
        setVoteProgress({});
      }

      const libs = (mems || []).map((m) => ({
        library_id: m.library_id,
        name: m.libraries?.name || m.library_id,
        slug: m.libraries?.slug || '',
      }));
      setMyCoordLibs(libs);

      // Votes en cours pour les biblios coordonnées (sens descendant).
      const libIds = libs.map((l) => l.library_id);
      if (libIds.length) {
        const { data: vrows } = await supabase
          .from('oai_opening_votes')
          .select('request_id, library_id, vote')
          .in('library_id', libIds);
        setVotes(vrows || []);
      } else {
        setVotes([]);
      }
    } catch (err) {
      flash(localizeError(err, t), 'error');
    } finally {
      setLoading(false);
    }
  }, [user, t]);

  useEffect(() => { load(); }, [load]);

  async function call(fn, args, okMsg) {
    setBusy(true);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc(fn, args);
      if (error) throw error;
      flash(okMsg);
      await load();
    } catch (err) {
      flash(localizeError(err, t), 'error');
    } finally {
      setBusy(false);
    }
  }

  // ── Dérivés ───────────────────────────────────────────────
  const myLibIds = useMemo(() => new Set(myCoordLibs.map((l) => l.library_id)), [myCoordLibs]);

  const libraryReqByLib = useMemo(() => {
    // dernière demande vivante (pending_admin|open) par biblio
    const map = new Map();
    for (const r of requests) {
      if (r.kind !== 'library') continue;
      if (!['pending_admin', 'open'].includes(r.status)) continue;
      if (!map.has(r.library_id)) map.set(r.library_id, r);
    }
    return map;
  }, [requests]);

  const pendingAdminReqs = useMemo(
    () => requests.filter((r) => r.kind === 'library' && r.status === 'pending_admin'),
    [requests],
  );
  const networkOpen = useMemo(() => requests.filter((r) => r.kind === 'network' && r.status === 'open'), [requests]);
  const networkPendingVote = useMemo(
    () => requests.filter((r) => r.kind === 'network' && r.status === 'pending_vote'),
    [requests],
  );
  const openLibraryReqs = useMemo(() => requests.filter((r) => r.kind === 'library' && r.status === 'open'), [requests]);

  // Mes votes en attente (biblio coordonnée, proposition descendante non encore votée).
  const myPendingVotes = useMemo(() => {
    const out = [];
    for (const req of networkPendingVote) {
      for (const lib of myCoordLibs) {
        const v = votes.find((x) => x.request_id === req.id && x.library_id === lib.library_id);
        if (v && (v.vote === null || v.vote === undefined)) out.push({ req, lib });
      }
    }
    return out;
  }, [networkPendingVote, myCoordLibs, votes]);

  // Bannière : une de mes biblios a une ouverture active (propre) OU le réseau est ouvert.
  const myOpenLib = useMemo(
    () => openLibraryReqs.find((r) => myLibIds.has(r.library_id)),
    [openLibraryReqs, myLibIds],
  );
  const showBanner = Boolean(myOpenLib) || networkOpen.length > 0;

  // ── Styles locaux (alignés sur la norme rede) ─────────────
  const sheet = { padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16 };
  const fs = { width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.9rem' };
  const note = { fontSize: '.85rem', color: 'var(--brand-muted)', lineHeight: 1.6 };

  if (loading) {
    return <div style={note}>{t({ id: 'common.loading' })}</div>;
  }

  return (
    <div>
      <h3 style={{ marginBottom: 6 }}>{t({ id: 'rede.oai.title' })}</h3>
      <p style={{ ...note, marginBottom: 16 }}>{t({ id: 'rede.oai.intro' })}</p>

      {msg.text && (
        <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.9rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>
          {msg.text}
        </div>
      )}

      {/* ── Bannière d'alerte permanente (ouverture active) ── */}
      {showBanner && (
        <div style={{ padding: '14px 16px', borderRadius: 10, marginBottom: 16, background: 'rgba(220,38,38,.14)', border: '1px solid rgba(248,113,113,.45)', color: '#fecaca' }}>
          <div style={{ fontWeight: 800, marginBottom: 4 }}>⚠️ {t({ id: 'rede.oai.banner.title' })}</div>
          <div style={{ fontSize: '.86rem', lineHeight: 1.6 }}>{t({ id: 'rede.oai.banner.body' })}</div>
          {myOpenLib && (
            <button className="cat-btn ghost" disabled={busy} style={{ marginTop: 10, color: '#fca5a5' }}
              onClick={() => call('fn_oai_close_opening', { p_request_id: myOpenLib.id, p_reason: null }, t({ id: 'rede.oai.closed' }))}>
              {t({ id: 'rede.oai.closeMine' })}
            </button>
          )}
        </div>
      )}

      {/* ════════ ESPACE COORDENADOR ════════ */}
      {myCoordLibs.length > 0 && (
        <div style={sheet}>
          <div style={{ fontWeight: 700, marginBottom: 4 }}>{t({ id: 'rede.oai.coord.title' })}</div>
          <p style={{ ...note, marginBottom: 12 }}>{t({ id: 'rede.oai.coord.desc' })}</p>

          {myCoordLibs.map((lib) => {
            const req = libraryReqByLib.get(lib.library_id);
            const status = req?.status;
            const coveredByNetwork = networkOpen.length > 0;
            return (
              <div key={lib.library_id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,.06)', flexWrap: 'wrap' }}>
                <div>
                  <div style={{ fontWeight: 600 }}>{lib.name}</div>
                  <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>
                    {status === 'open' && <Pill variant="danger">{t({ id: 'rede.oai.state.open' })}</Pill>}
                    {status === 'pending_admin' && <Pill variant="warn">{t({ id: 'rede.oai.state.pendingAdmin' })}</Pill>}
                    {!status && !coveredByNetwork && <Pill>{t({ id: 'rede.oai.state.closed' })}</Pill>}
                    {!status && coveredByNetwork && <Pill variant="danger">{t({ id: 'rede.oai.state.networkOpen' })}</Pill>}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 6 }}>
                  {!status && (
                    <button className="cat-btn primary" disabled={busy}
                      onClick={() => call('fn_oai_request_open_library', { p_library_id: lib.library_id, p_notes: null }, t({ id: 'rede.oai.requested' }))}>
                      {t({ id: 'rede.oai.requestOpen' })}
                    </button>
                  )}
                  {status === 'open' && (
                    <button className="cat-btn ghost" disabled={busy} style={{ color: '#f87171' }}
                      onClick={() => call('fn_oai_close_opening', { p_request_id: req.id, p_reason: null }, t({ id: 'rede.oai.closed' }))}>
                      {t({ id: 'rede.oai.close' })}
                    </button>
                  )}
                </div>
              </div>
            );
          })}

          {/* Votes en attente (sens descendant) */}
          {myPendingVotes.length > 0 && (
            <div style={{ marginTop: 14 }}>
              <div style={{ fontWeight: 700, marginBottom: 6 }}>{t({ id: 'rede.oai.votes.title' })}</div>
              {myPendingVotes.map(({ req, lib }) => (
                <div key={`${req.id}:${lib.library_id}`} style={{ padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,.06)' }}>
                  <div style={{ fontSize: '.88rem' }}>
                    {t({ id: 'rede.oai.votes.prompt' }, { entity: req.external_entity, lib: lib.name })}
                  </div>
                  <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', margin: '2px 0 8px' }}>
                    {t({ id: 'rede.oai.votes.deadline' }, { date: fmtDate(req.vote_deadline) })}
                  </div>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="cat-btn primary" disabled={busy}
                      onClick={() => call('fn_oai_cast_vote', { p_request_id: req.id, p_library_id: lib.library_id, p_vote: 'yes' }, t({ id: 'rede.oai.votes.cast' }))}>
                      {t({ id: 'rede.oai.votes.yes' })}
                    </button>
                    <button className="cat-btn ghost" disabled={busy} style={{ color: '#f87171' }}
                      onClick={() => call('fn_oai_cast_vote', { p_request_id: req.id, p_library_id: lib.library_id, p_vote: 'no' }, t({ id: 'rede.oai.votes.cast' }))}>
                      {t({ id: 'rede.oai.votes.no' })}
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ════════ ESPACE ADMIN RÉSEAU ════════ */}
      {isNetworkAdmin && (
        <>
          {/* Demandes ascendantes à instruire */}
          <div style={sheet}>
            <div style={{ fontWeight: 700, marginBottom: 4 }}>{t({ id: 'rede.oai.admin.requests.title' })}</div>
            <p style={{ ...note, marginBottom: 10 }}>{t({ id: 'rede.oai.admin.requests.desc' })}</p>
            {pendingAdminReqs.length === 0 && <div style={note}>{t({ id: 'common.empty' })}</div>}
            {pendingAdminReqs.map((r) => (
              <div key={r.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,.06)', flexWrap: 'wrap' }}>
                <div style={{ fontSize: '.88rem' }}>
                  {t({ id: 'rede.oai.admin.requests.row' }, { date: fmtDate(r.requested_at) })}
                  {r.notes && <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)' }}>{r.notes}</div>}
                </div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button className="cat-btn primary" disabled={busy}
                    onClick={() => call('fn_oai_admin_decide_library', { p_request_id: r.id, p_approve: true }, t({ id: 'rede.oai.admin.approved' }))}>
                    {t({ id: 'rede.oai.admin.approve' })}
                  </button>
                  <button className="cat-btn ghost" disabled={busy} style={{ color: '#f87171' }}
                    onClick={() => call('fn_oai_admin_decide_library', { p_request_id: r.id, p_approve: false }, t({ id: 'rede.oai.admin.refused' }))}>
                    {t({ id: 'rede.oai.admin.refuse' })}
                  </button>
                </div>
              </div>
            ))}
          </div>

          {/* Proposer une ouverture réseau (descendant) */}
          <div style={sheet}>
            <div style={{ fontWeight: 700, marginBottom: 4 }}>{t({ id: 'rede.oai.admin.network.title' })}</div>
            <p style={{ ...note, marginBottom: 10 }}>{t({ id: 'rede.oai.admin.network.desc' })}</p>
            <input style={{ ...fs, marginBottom: 8 }} value={extEntity} disabled={busy}
              onChange={(e) => setExtEntity(e.target.value)}
              placeholder={t({ id: 'rede.oai.admin.network.entityPlaceholder' })} />
            <textarea style={{ ...fs, marginBottom: 8, resize: 'vertical' }} rows={2} value={extNotes} disabled={busy}
              onChange={(e) => setExtNotes(e.target.value)}
              placeholder={t({ id: 'rede.oai.admin.network.notesPlaceholder' })} />
            <button className="cat-btn primary" disabled={busy || !extEntity.trim()}
              onClick={() => call('fn_oai_propose_network_open', { p_external_entity: extEntity.trim(), p_notes: extNotes.trim() || null }, t({ id: 'rede.oai.admin.network.proposed' })).then(() => { setExtEntity(''); setExtNotes(''); })}>
              {t({ id: 'rede.oai.admin.network.propose' })}
            </button>
          </div>

          {/* Ouvertures en cours (à fermer) */}
          {(openLibraryReqs.length > 0 || networkOpen.length > 0 || networkPendingVote.length > 0) && (
            <div style={sheet}>
              <div style={{ fontWeight: 700, marginBottom: 10 }}>{t({ id: 'rede.oai.admin.active.title' })}</div>
              {networkPendingVote.map((r) => (
                <div key={r.id} style={{ padding: '8px 0', borderBottom: '1px solid rgba(255,255,255,.06)', fontSize: '.85rem' }}>
                  <Pill variant="warn">{t({ id: 'rede.oai.state.pendingVote' })}</Pill>{' '}
                  {t({ id: 'rede.oai.admin.active.networkVote' }, { entity: r.external_entity, date: fmtDate(r.vote_deadline) })}
                  {voteProgress[r.id] && (
                    <span style={{ color: 'var(--brand-muted)' }}> — {t({ id: 'rede.oai.admin.active.progress' }, { consented: voteProgress[r.id].consented, concerned: voteProgress[r.id].concerned })}</span>
                  )}
                </div>
              ))}
              {networkOpen.map((r) => (
                <div key={r.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, padding: '8px 0', borderBottom: '1px solid rgba(255,255,255,.06)', flexWrap: 'wrap' }}>
                  <div style={{ fontSize: '.85rem' }}><Pill variant="danger">{t({ id: 'rede.oai.state.networkOpenShort' })}</Pill> {r.external_entity}</div>
                  <button className="cat-btn ghost" disabled={busy} style={{ color: '#f87171' }}
                    onClick={() => call('fn_oai_close_opening', { p_request_id: r.id, p_reason: null }, t({ id: 'rede.oai.closed' }))}>
                    {t({ id: 'rede.oai.close' })}
                  </button>
                </div>
              ))}
              {openLibraryReqs.map((r) => (
                <div key={r.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, padding: '8px 0', borderBottom: '1px solid rgba(255,255,255,.06)', flexWrap: 'wrap' }}>
                  <div style={{ fontSize: '.85rem' }}><Pill variant="danger">{t({ id: 'rede.oai.state.open' })}</Pill> {t({ id: 'rede.oai.admin.active.libraryRow' }, { date: fmtDate(r.admin_decided_at) })}</div>
                  <button className="cat-btn ghost" disabled={busy} style={{ color: '#f87171' }}
                    onClick={() => call('fn_oai_close_opening', { p_request_id: r.id, p_reason: null }, t({ id: 'rede.oai.closed' }))}>
                    {t({ id: 'rede.oai.close' })}
                  </button>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {myCoordLibs.length === 0 && !isNetworkAdmin && (
        <div style={note}>{t({ id: 'rede.oai.noAccess' })}</div>
      )}
    </div>
  );
}
