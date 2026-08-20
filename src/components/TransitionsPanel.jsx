import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';

// =============================================================================
// TransitionsPanel (paquet E.5, 20/05/2026)
// =============================================================================
// Onglet de gouvernance pour les biblios en governance_mode IN
// ('staff_roles', 'full_governance').
//
// Permet aux staff de la biblio (librarian, coordenador, administrador) :
//   - proposer un changement de profil (un des 4 axes)
//   - voter pour/contre/abstain sur les propositions ouvertes
//   - annuler une proposition qu'on a soumise
//   - consulter l'historique des transitions
//
// Backend :
//   - fn_propose_library_profile_change(library_id, axis, new_value, motivation)
//   - fn_vote_library_profile_change(proposal_id, vote, rationale_against)
//   - fn_cancel_library_profile_change(proposal_id, motivation)
//   - fn_execute_library_profile_change(proposal_id)  -- usage system, pas exposed
//
// Doctrine paquet B/E.5 :
//   - Type 1 (direct) : execute immediatement, pas de vote
//   - Type 2 (majority) : majorite simple des staff actifs
//   - Type 3 (unanimous) : tous les staff actifs doivent voter "pro"
//   - Type 4 (unanimous_extended) : unanimite + grace period 30 jours
// =============================================================================

const VALID_AXES = ['catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode'];

const AXIS_VALUES = {
  catalog_mode:     ['local_only', 'network_published'],
  circulation_mode: ['off', 'informal', 'full_sigb'],
  network_mode:     ['isolated', 'observer', 'federated'],
  governance_mode:  ['informal', 'staff_roles', 'full_governance'],
};

function fmtD(d) {
  if (!d) return '—';
  try { return new Date(d).toLocaleDateString(); }
  catch { return d; }
}

function fmtDT(d) {
  if (!d) return '—';
  try { return new Date(d).toLocaleString(); }
  catch { return d; }
}

export default function TransitionsPanel({ libraryId, role }) {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();

  const isStaff = role === 'librarian' || role === 'coordenador' || role === 'administrador';

  // ---- States ----
  const [openProposals, setOpenProposals]   = useState([]);
  const [history, setHistory]               = useState([]);
  const [loading, setLoading]               = useState(true);
  const [globalMsg, setGlobalMsg]           = useState({ text: '', kind: '' });

  // Formulaire propose
  const [proposeAxis, setProposeAxis]       = useState('');
  const [proposeValue, setProposeValue]     = useState('');
  const [proposeMotivation, setProposeMotivation] = useState('');
  const [proposeSubmitting, setProposeSubmitting] = useState(false);

  // Etat votes par proposition : { [proposalId]: { vote, rationale, submitting } }
  const [voteDrafts, setVoteDrafts]         = useState({});

  // Mes votes existants par proposition : { [proposalId]: { vote, voted_at } }
  const [myVotes, setMyVotes]               = useState({});

  // Etat cancel par proposition : { [proposalId]: { motivation, submitting } }
  const [cancelDrafts, setCancelDrafts]     = useState({});

  // ---- Load propositions + history + my votes ----
  const reload = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      // 1. Propositions ouvertes
      const { data: openData, error: openErr } = await supabase
        .from('library_profile_proposals')
        .select('*, profiles:proposed_by(first_name, last_name)')
        .eq('library_id', libraryId)
        .eq('status', 'open')
        .order('proposed_at', { ascending: false });
      if (openErr) throw openErr;
      setOpenProposals(openData || []);

      // 2. Historique recent (10 dernieres completed/cancelled/expired)
      const { data: histData, error: histErr } = await supabase
        .from('library_profile_proposals')
        .select('*, profiles:proposed_by(first_name, last_name)')
        .eq('library_id', libraryId)
        .in('status', ['completed', 'cancelled', 'expired'])
        .order('proposed_at', { ascending: false })
        .limit(10);
      if (histErr) throw histErr;
      setHistory(histData || []);

      // 3. Mes votes sur les propositions ouvertes
      const proposalIds = (openData || []).map(p => p.id);
      if (proposalIds.length > 0 && user?.id) {
        const { data: votesData } = await supabase
          .from('library_profile_votes')
          .select('proposal_id, vote, voted_at')
          .in('proposal_id', proposalIds)
          .eq('voter_id', user.id);
        const map = {};
        (votesData || []).forEach(v => { map[v.proposal_id] = v; });
        setMyVotes(map);
      } else {
        setMyVotes({});
      }
    } catch (e) {
      console.warn('TransitionsPanel reload:', e);
      setGlobalMsg({ text: t({ id: 'transitions.error.loadFailed' }, { msg: localizeError(e, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, user?.id, t]);

  useEffect(() => { reload(); }, [reload]);

  // ---- Submit propose ----
  async function handlePropose() {
    setGlobalMsg({ text: '', kind: '' });
    if (!proposeAxis || !proposeValue) {
      setGlobalMsg({ text: t({ id: 'transitions.error.axisAndValueRequired' }), kind: 'error' }); return;
    }
    if (proposeMotivation.trim().length < 5) {
      setGlobalMsg({ text: t({ id: 'transitions.error.motivationTooShort' }), kind: 'error' }); return;
    }
    setProposeSubmitting(true);
    try {
      const { data, error } = await supabase.rpc('fn_propose_library_profile_change', {
        p_library_id: libraryId,
        p_axis: proposeAxis,
        p_new_value: proposeValue,
        p_motivation: proposeMotivation.trim(),
      });
      if (error) throw error;
      const isImmediate = data?.executed_immediately === true;
      setGlobalMsg({
        text: t({ id: isImmediate ? 'transitions.success.executedImmediately' : 'transitions.success.proposed' }),
        kind: 'ok',
      });
      setProposeAxis('');
      setProposeValue('');
      setProposeMotivation('');
      await reload();
    } catch (e) {
      const hint = e?.hint || '';
      let msg = localizeError(e, t);
      if (hint === 'error.profile_change.motivation_too_short') msg = t({ id: 'transitions.error.motivationTooShort' });
      else if (hint === 'error.profile_change.axis_already_open') msg = t({ id: 'transitions.error.axisLocked' });
      else if (hint === 'error.profile_change.quorum_not_met') msg = t({ id: 'transitions.error.quorumNotMet' });
      else if (hint === 'error.profile_change.not_staff') msg = t({ id: 'transitions.error.notStaff' });
      setGlobalMsg({ text: msg, kind: 'error' });
    } finally {
      setProposeSubmitting(false);
    }
  }

  // ---- Vote on a proposal ----
  function setVoteDraft(proposalId, patch) {
    setVoteDrafts(prev => ({ ...prev, [proposalId]: { ...(prev[proposalId] || {}), ...patch } }));
  }

  async function handleVote(proposalId) {
    const draft = voteDrafts[proposalId] || {};
    if (!draft.vote) {
      setGlobalMsg({ text: t({ id: 'transitions.error.voteRequired' }), kind: 'error' }); return;
    }
    if (draft.vote === 'contre' && (!draft.rationale || draft.rationale.trim().length < 5)) {
      setGlobalMsg({ text: t({ id: 'transitions.error.rationaleRequired' }), kind: 'error' }); return;
    }
    setVoteDraft(proposalId, { submitting: true });
    setGlobalMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('fn_vote_library_profile_change', {
        p_proposal_id: proposalId,
        p_vote: draft.vote,
        p_rationale_against: draft.vote === 'contre' ? draft.rationale.trim() : null,
      });
      if (error) throw error;
      setGlobalMsg({ text: t({ id: 'transitions.success.voted' }), kind: 'ok' });
      setVoteDrafts(prev => { const next = { ...prev }; delete next[proposalId]; return next; });
      await reload();
    } catch (e) {
      setGlobalMsg({ text: localizeError(e, t), kind: 'error' });
      setVoteDraft(proposalId, { submitting: false });
    }
  }

  // ---- Cancel a proposal (proposeur uniquement) ----
  function setCancelDraft(proposalId, patch) {
    setCancelDrafts(prev => ({ ...prev, [proposalId]: { ...(prev[proposalId] || {}), ...patch } }));
  }

  async function handleCancel(proposalId) {
    const draft = cancelDrafts[proposalId] || {};
    if (!draft.motivation || draft.motivation.trim().length < 5) {
      setGlobalMsg({ text: t({ id: 'transitions.error.cancelMotivationRequired' }), kind: 'error' }); return;
    }
    setCancelDraft(proposalId, { submitting: true });
    setGlobalMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('fn_cancel_library_profile_change', {
        p_proposal_id: proposalId,
        p_motivation: draft.motivation.trim(),
      });
      if (error) throw error;
      setGlobalMsg({ text: t({ id: 'transitions.success.cancelled' }), kind: 'ok' });
      setCancelDrafts(prev => { const next = { ...prev }; delete next[proposalId]; return next; });
      await reload();
    } catch (e) {
      setGlobalMsg({ text: localizeError(e, t), kind: 'error' });
      setCancelDraft(proposalId, { submitting: false });
    }
  }

  // ---- Styles partages ----
  const fs = { width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };
  const ls = { display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' };
  const card = { padding: '14px 16px', borderRadius: 10, marginBottom: 12, border: '1px solid rgba(255,255,255,.1)', background: 'rgba(255,255,255,.02)' };

  // ---- Render ----
  if (!isStaff) {
    return (
      <div style={{ padding: 20 }}>
        <p style={{ color: 'var(--brand-muted)' }}>
          {t({ id: 'transitions.notStaff' })}
        </p>
      </div>
    );
  }

  if (loading) {
    return <div style={{ padding: 20, color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</div>;
  }

  return (
    <div>
      <h2 className="ab-painel-h2">{t({ id: 'transitions.title' })}</h2>
      <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem', marginBottom: 18 }}>
        {t({ id: 'transitions.intro' })}
      </p>

      {globalMsg.text && (
        <div style={{
          padding: '10px 14px', borderRadius: 8, marginBottom: 16,
          background: globalMsg.kind === 'ok' ? 'rgba(34,197,94,.1)' : 'rgba(248,113,113,.1)',
          border: `1px solid ${globalMsg.kind === 'ok' ? 'rgba(34,197,94,.3)' : 'rgba(248,113,113,.3)'}`,
          color: globalMsg.kind === 'ok' ? '#86efac' : '#fca5a5', fontSize: '.88rem',
        }}>
          {globalMsg.text}
        </div>
      )}

      {/* ============ SECTION 1 : Formulaire propose ============ */}
      <section style={{ ...card, marginBottom: 24 }}>
        <h3 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 4 }}>
          {t({ id: 'transitions.propose.title' })}
        </h3>
        <p style={{ color: 'var(--brand-muted)', fontSize: '.82rem', marginBottom: 14 }}>
          {t({ id: 'transitions.propose.hint' })}
        </p>

        <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)', gap: 12, marginBottom: 12 }}>
          <div>
            <label style={ls}>{t({ id: 'transitions.field.axis' })}</label>
            <select value={proposeAxis} onChange={e => { setProposeAxis(e.target.value); setProposeValue(''); }}
                    style={fs} disabled={proposeSubmitting}>
              <option value="">{t({ id: 'transitions.field.axis.placeholder' })}</option>
              {VALID_AXES.map(axis => (
                <option key={axis} value={axis}>{t({ id: `wizard.profile.axis.${axis}.title` })}</option>
              ))}
            </select>
          </div>
          <div>
            <label style={ls}>{t({ id: 'transitions.field.newValue' })}</label>
            <select value={proposeValue} onChange={e => setProposeValue(e.target.value)}
                    style={fs} disabled={proposeSubmitting || !proposeAxis}>
              <option value="">{t({ id: 'transitions.field.newValue.placeholder' })}</option>
              {proposeAxis && AXIS_VALUES[proposeAxis].map(v => (
                <option key={v} value={v}>{t({ id: `wizard.profile.option.${proposeAxis}.${v}.title` })}</option>
              ))}
            </select>
          </div>
        </div>

        <div style={{ marginBottom: 12 }}>
          <label style={ls}>{t({ id: 'transitions.field.motivation' })}</label>
          <textarea value={proposeMotivation} onChange={e => setProposeMotivation(e.target.value)}
                    style={{ ...fs, resize: 'vertical', minHeight: 80 }}
                    disabled={proposeSubmitting}
                    placeholder={t({ id: 'transitions.field.motivation.placeholder' })} />
          <div style={{ fontSize: '.75rem', color: 'var(--brand-muted)', marginTop: 4 }}>
            {t({ id: 'transitions.field.motivation.hint' })}
          </div>
        </div>

        <button onClick={handlePropose} disabled={proposeSubmitting || !proposeAxis || !proposeValue}
                className="ab-button ab-button--primary">
          {proposeSubmitting ? t({ id: 'transitions.propose.submitting' }) : t({ id: 'transitions.propose.submit' })}
        </button>
      </section>

      {/* ============ SECTION 2 : Propositions ouvertes ============ */}
      <section style={{ marginBottom: 24 }}>
        <h3 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 12 }}>
          {t({ id: 'transitions.open.title' }, { count: openProposals.length })}
        </h3>

        {openProposals.length === 0 ? (
          <div style={{ ...card, color: 'var(--brand-muted)', fontStyle: 'italic', fontSize: '.88rem' }}>
            {t({ id: 'transitions.open.empty' })}
          </div>
        ) : openProposals.map(p => {
          const myVote = myVotes[p.id];
          const draft = voteDrafts[p.id] || {};
          const cancelDraft = cancelDrafts[p.id] || {};
          const isProposeur = p.proposed_by === user?.id;
          const proposerName = p.profiles
            ? [p.profiles.first_name, p.profiles.last_name].filter(Boolean).join(' ').trim()
            : '—';

          return (
            <div key={p.id} style={card}>
              {/* Header proposition */}
              <div style={{ marginBottom: 10 }}>
                <div style={{ fontSize: '.95rem', fontWeight: 700, marginBottom: 4 }}>
                  {t({ id: `wizard.profile.axis.${p.axis}.title` })}
                  {' : '}
                  <span style={{ color: 'var(--brand-muted)', fontWeight: 400 }}>
                    {t({ id: `wizard.profile.option.${p.axis}.${p.old_value}.title` })}
                  </span>
                  {' → '}
                  <span style={{ color: '#86efac' }}>
                    {t({ id: `wizard.profile.option.${p.axis}.${p.new_value}.title` })}
                  </span>
                </div>
                <div style={{ display: 'flex', gap: 12, fontSize: '.78rem', color: 'var(--brand-muted)', flexWrap: 'wrap' }}>
                  <span>{t({ id: `transitions.type.${p.transition_type}` })}</span>
                  <span>·</span>
                  <span>{t({ id: 'transitions.governance.' + p.governance_required })}</span>
                  <span>·</span>
                  <span>{t({ id: 'transitions.proposedBy' }, { name: proposerName, date: fmtD(p.proposed_at) })}</span>
                  {p.expires_at && (<><span>·</span><span>{t({ id: 'transitions.expiresAt' }, { date: fmtD(p.expires_at) })}</span></>)}
                </div>
              </div>

              {/* Motivation */}
              <div style={{ padding: '10px 12px', borderRadius: 6, background: 'rgba(0,0,0,.15)',
                            marginBottom: 12, fontSize: '.85rem', fontStyle: 'italic' }}>
                « {p.motivation} »
              </div>

              {/* Mon vote OU formulaire de vote */}
              {myVote ? (
                <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', marginBottom: 10 }}>
                  ✓ {t({ id: 'transitions.alreadyVoted' }, {
                    vote: t({ id: `transitions.vote.${myVote.vote}` }),
                    date: fmtDT(myVote.voted_at),
                  })}
                </div>
              ) : (
                <div style={{ marginBottom: 10 }}>
                  <div style={{ display: 'flex', gap: 8, marginBottom: 8, flexWrap: 'wrap' }}>
                    {['pro', 'contre', 'abstain'].map(v => (
                      <button key={v} type="button"
                              onClick={() => setVoteDraft(p.id, { vote: v })}
                              disabled={draft.submitting}
                              className={`ab-button ab-button--mini ${draft.vote === v ? '' : 'ab-button--ghost'}`}
                              style={{ fontSize: '.82rem' }}>
                        {t({ id: `transitions.vote.${v}` })}
                      </button>
                    ))}
                  </div>
                  {draft.vote === 'contre' && (
                    <div style={{ marginBottom: 8 }}>
                      <textarea value={draft.rationale || ''}
                                onChange={e => setVoteDraft(p.id, { rationale: e.target.value })}
                                placeholder={t({ id: 'transitions.field.rationaleAgainst.placeholder' })}
                                style={{ ...fs, resize: 'vertical', minHeight: 60, fontSize: '.82rem' }}
                                disabled={draft.submitting} />
                    </div>
                  )}
                  {draft.vote && (
                    <button onClick={() => handleVote(p.id)} disabled={draft.submitting}
                            className="ab-button ab-button--primary ab-button--mini">
                      {draft.submitting ? t({ id: 'transitions.vote.submitting' }) : t({ id: 'transitions.vote.submit' })}
                    </button>
                  )}
                </div>
              )}

              {/* Bouton annuler (proposeur uniquement) */}
              {isProposeur && (
                <details style={{ marginTop: 10 }}>
                  <summary style={{ cursor: 'pointer', fontSize: '.78rem', color: 'var(--brand-muted)' }}>
                    {t({ id: 'transitions.cancel.toggle' })}
                  </summary>
                  <div style={{ marginTop: 8 }}>
                    <textarea value={cancelDraft.motivation || ''}
                              onChange={e => setCancelDraft(p.id, { motivation: e.target.value })}
                              placeholder={t({ id: 'transitions.cancel.motivation.placeholder' })}
                              style={{ ...fs, resize: 'vertical', minHeight: 60, fontSize: '.82rem', marginBottom: 6 }}
                              disabled={cancelDraft.submitting} />
                    <button onClick={() => handleCancel(p.id)} disabled={cancelDraft.submitting}
                            className="ab-button ab-button--danger ab-button--mini">
                      {cancelDraft.submitting ? t({ id: 'transitions.cancel.submitting' }) : t({ id: 'transitions.cancel.submit' })}
                    </button>
                  </div>
                </details>
              )}
            </div>
          );
        })}
      </section>

      {/* ============ SECTION 3 : Historique ============ */}
      <section>
        <h3 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 12 }}>
          {t({ id: 'transitions.history.title' })}
        </h3>

        {history.length === 0 ? (
          <div style={{ ...card, color: 'var(--brand-muted)', fontStyle: 'italic', fontSize: '.88rem' }}>
            {t({ id: 'transitions.history.empty' })}
          </div>
        ) : history.map(h => {
          const proposerName = h.profiles
            ? [h.profiles.first_name, h.profiles.last_name].filter(Boolean).join(' ').trim()
            : '—';
          const statusColor = h.status === 'completed' ? '#86efac'
                            : h.status === 'cancelled' ? '#fbbf24'
                            : '#94a3b8';
          return (
            <div key={h.id} style={{ ...card, padding: '10px 14px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12,
                            alignItems: 'flex-start', flexWrap: 'wrap' }}>
                <div style={{ flex: 1, minWidth: 'min(220px, 100%)' }}>
                  <div style={{ fontSize: '.88rem', fontWeight: 600, marginBottom: 3 }}>
                    {t({ id: `wizard.profile.axis.${h.axis}.title` })}
                    {' : '}
                    <span style={{ color: 'var(--brand-muted)', fontWeight: 400 }}>
                      {t({ id: `wizard.profile.option.${h.axis}.${h.old_value}.title` })}
                    </span>
                    {' → '}
                    <span>{t({ id: `wizard.profile.option.${h.axis}.${h.new_value}.title` })}</span>
                  </div>
                  <div style={{ fontSize: '.76rem', color: 'var(--brand-muted)' }}>
                    {t({ id: 'transitions.proposedBy' }, { name: proposerName, date: fmtD(h.proposed_at) })}
                    {h.completed_at && (<> · {t({ id: 'transitions.completedAt' }, { date: fmtD(h.completed_at) })}</>)}
                    {h.cancelled_at && (<> · {t({ id: 'transitions.cancelledAt' }, { date: fmtD(h.cancelled_at) })}</>)}
                  </div>
                </div>
                <div style={{ fontSize: '.78rem', fontWeight: 600, color: statusColor }}>
                  {t({ id: `transitions.status.${h.status}` })}
                </div>
              </div>
            </div>
          );
        })}
      </section>
    </div>
  );
}
