// ============================================================================
// src/components/rede/AdminsPanel.jsx — E.4.b v0.3 (cooptation UI)
// ============================================================================
//
// Onglet "Administradores" de RedePage. v0.3.
//
// E.4.a (precedent) : adapter la source de donnees a v0.3 (api.network_
// administrators_public_v1), retirer le code obsolete.
//
// E.4.b (ce paquet) : ajouter le workflow de cooptation cote UI :
//   - section "Propostas em curso de cooptacao" (vue api.cooptation_proposals_
//     current_v1, livree dans la migration E.4.b)
//   - bouton "Propor cooptacao" -> <ProposeCooptationModal />
//   - bouton "Votar" sur chaque proposition -> <VoteCooptationModal />
//   - toasts de succes
//
// E.4.c (a venir) : workflow retrait collectif (D.6).
//
// ============================================================================

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import NetworkAdminBadge from './NetworkAdminBadge';
import ProposeCooptationModal from './ProposeCooptationModal';
import VoteCooptationModal from './VoteCooptationModal';

export default function AdminsPanel() {
  const { user } = useAuth();
  const { formatMessage: t, locale } = useIntl();

  const [admins, setAdmins] = useState([]);
  const [proposals, setProposals] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const [proposeOpen, setProposeOpen] = useState(false);
  const [voteProposal, setVoteProposal] = useState(null); // proposal active pour vote, ou null
  const [toast, setToast] = useState(null);

  // ── Chargement combiné : admins + propositions en cours ──
  const loadAll = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [adminsResult, proposalsResult] = await Promise.all([
        supabase
          .schema('api')
          .from('network_administrators_public_v1')
          .select('user_id, public_id, first_name, last_name, email, coopted_at, last_seen_at')
          .order('coopted_at', { ascending: true }),
        supabase
          .schema('api')
          .from('cooptation_proposals_current_v1')
          .select('*')
          .order('proposed_at', { ascending: false }),
      ]);

      if (adminsResult.error) throw adminsResult.error;
      if (proposalsResult.error) throw proposalsResult.error;

      setAdmins(adminsResult.data || []);
      setProposals(proposalsResult.data || []);
    } catch (err) {
      console.warn('AdminsPanel loadAll:', err);
      setError(err.message || String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadAll(); }, [loadAll]);

  // Auto-dismiss toast apres 4s
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(timer);
  }, [toast]);

  // ── Handlers ────────────────────────────────────────
  const handleProposeSuccess = useCallback(() => {
    setToast({ text: t({ id: 'rede.cooptation.toast.proposed' }), kind: 'ok' });
    setProposeOpen(false);
    loadAll();
  }, [loadAll, t]);

  const handleVoteSuccess = useCallback(() => {
    setToast({ text: t({ id: 'rede.cooptation.toast.voted' }), kind: 'ok' });
    setVoteProposal(null);
    loadAll();
  }, [loadAll, t]);

  // ── Rendu ───────────────────────────────────────────
  if (error) {
    return (
      <div style={{ padding: 16, fontSize: '.88rem', color: '#f87171' }}>
        {t({ id: 'common.errorPrefix' }, { message: error })}
      </div>
    );
  }

  return (
    <div className="ab-admins-panel">

      {/* ── Toast ── */}
      {toast && (
        <div className={`ab-team-toast ab-team-toast--${toast.kind}`}>
          {toast.text}
        </div>
      )}

      {/* ── Intro admins actifs ── */}
      <div style={{ marginBottom: 14 }}>
        <h3 style={{ margin: '0 0 4px' }}>
          {t({ id: 'rede.admins.title' })} ({admins.length})
        </h3>
        <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
          {t({ id: 'rede.admins.subtitle' })}
        </div>
      </div>

      {/* ── Action : proposer cooptacao ── */}
      <div style={{ marginBottom: 16 }}>
        <button
          type="button"
          className="cat-btn primary"
          onClick={() => setProposeOpen(true)}
        >
          {t({ id: 'rede.cooptation.propose.cta' })}
        </button>
      </div>

      {/* ── Liste des admins actifs ── */}
      {loading && (
        <div style={{ padding: 16, fontSize: '.88rem', color: 'var(--brand-muted)', textAlign: 'center' }}>
          {t({ id: 'common.loading' })}
        </div>
      )}

      {!loading && admins.length === 0 && (
        <div style={{ padding: 16, fontSize: '.88rem', color: 'var(--brand-muted)' }}>
          {t({ id: 'rede.admins.empty' })}
        </div>
      )}

      {!loading && admins.length > 0 && (
        <div className="ab-team-list">
          {admins.map((a, i) => (
            <AdminRow
              key={a.user_id}
              admin={a}
              index={i}
              isCurrentUser={a.user_id === user?.id}
              locale={locale}
            />
          ))}
        </div>
      )}

      {/* ── Section "Propostas em curso" ── */}
      <div style={{ marginTop: 32 }}>
        <h3 style={{ margin: '0 0 8px' }}>
          {t({ id: 'rede.cooptation.openProposals.title' })} ({proposals.length})
        </h3>

        {!loading && proposals.length === 0 && (
          <div
            style={{
              padding: 16,
              fontSize: '.88rem',
              color: 'var(--brand-muted)',
              fontStyle: 'italic',
            }}
          >
            {t({ id: 'rede.cooptation.empty' })}
          </div>
        )}

        {!loading && proposals.length > 0 && (
          <div className="ab-team-list">
            {proposals.map((p, i) => (
              <ProposalRow
                key={p.proposal_id}
                proposal={p}
                index={i}
                locale={locale}
                onVoteClick={() => setVoteProposal(p)}
              />
            ))}
          </div>
        )}
      </div>

      {/* ── Modals ── */}
      <ProposeCooptationModal
        isOpen={proposeOpen}
        onClose={() => setProposeOpen(false)}
        onSuccess={handleProposeSuccess}
      />

      <VoteCooptationModal
        isOpen={voteProposal !== null}
        proposal={voteProposal}
        onClose={() => setVoteProposal(null)}
        onSuccess={handleVoteSuccess}
      />
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// AdminRow : ligne admin actif (badge + identite + dates)
// (inchange depuis E.4.a)
// ────────────────────────────────────────────────────────────

function AdminRow({ admin: a, index, isCurrentUser, locale }) {
  const { formatMessage: t } = useIntl();

  const name = [a.first_name, a.last_name].filter(Boolean).join(' ')
    || a.email
    || t({ id: 'team.unnamedMember' });

  const cooptedDate = a.coopted_at
    ? new Date(a.coopted_at).toLocaleDateString(locale)
    : null;

  const lastSeenDate = a.last_seen_at
    ? new Date(a.last_seen_at).toLocaleDateString(locale)
    : null;

  return (
    <div
      className="ab-team-row"
      data-admin-reseau="true"
      style={{
        padding: '12px 14px',
        background: index % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
        borderBottom: '1px solid rgba(255,255,255,.04)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        gap: 12,
      }}
    >
      <div className="ab-team-row__main">
        <div className="ab-team-row__name">
          {name}
          {isCurrentUser && (
            <span className="ab-team-self-tag">
              ({t({ id: 'team.selfTag' })})
            </span>
          )}
        </div>
        <div className="ab-team-row__meta">
          {a.email && <span>{a.email}</span>}
          {a.public_id && <span>{' · '}{a.public_id}</span>}
          {cooptedDate && (
            <span>{' · '}{t({ id: 'team.memberSince' }, { date: cooptedDate })}</span>
          )}
          {lastSeenDate && (
            <span>{' · '}{`vu ${lastSeenDate}`}</span>
          )}
        </div>
      </div>
      <div className="ab-team-row__badges">
        <NetworkAdminBadge />
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// ProposalRow E.4.b : ligne proposition de cooptation en cours
// Affiche identite proposed + proposeur + motivation (preview) + comptes
// votes + bouton "Votar" (sauf si caller_is_target ou caller_has_voted ne
// le permettent pas)
// ────────────────────────────────────────────────────────────

function ProposalRow({ proposal: p, index, locale, onVoteClick }) {
  const { formatMessage: t } = useIntl();

  const targetName = [p.proposed_first_name, p.proposed_last_name].filter(Boolean).join(' ')
    || p.proposed_email
    || t({ id: 'team.unnamedMember' });

  const proposerName = [p.proposer_first_name, p.proposer_last_name].filter(Boolean).join(' ')
    || p.proposer_email
    || t({ id: 'team.unnamedMember' });

  const expiresDate = p.expires_at
    ? new Date(p.expires_at).toLocaleDateString(locale)
    : null;

  // Le caller peut voter si :
  //   - il n'est pas la cible (caller_is_target = false)
  //   - la proposition est ouverte (deja garantie par la vue, status='open')
  // Note : il PEUT changer son vote (UPSERT cote DB).
  const canVote = !p.caller_is_target;

  return (
    <div
      className="ab-team-row"
      style={{
        padding: '12px 14px',
        background: index % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
        borderBottom: '1px solid rgba(255,255,255,.04)',
        display: 'flex',
        flexDirection: 'column',
        gap: 8,
      }}
    >
      {/* En-tete : identite + statut */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
        <div>
          <div className="ab-team-row__name" style={{ fontWeight: 600 }}>
            {targetName}
            {p.caller_is_target && (
              <span className="ab-team-self-tag">
                ({t({ id: 'team.selfTag' })})
              </span>
            )}
          </div>
          <div className="ab-team-row__meta" style={{ fontSize: '.82rem' }}>
            {t({ id: 'rede.cooptation.proposal.proposedBy' }, { name: proposerName })}
            {expiresDate && (
              <span>{' · '}{t({ id: 'rede.cooptation.proposal.expiresAt' }, { date: expiresDate })}</span>
            )}
          </div>
        </div>
        <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
          <span className="cat-pill info" style={{ fontSize: '.7rem' }}>
            {t({ id: 'rede.cooptation.proposal.status.open' })}
          </span>
        </div>
      </div>

      {/* Comptes de votes + motivation preview */}
      <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
        <span style={{ fontWeight: 600, color: 'var(--brand-fg, inherit)' }}>
          {t(
            { id: 'rede.cooptation.proposal.votesProgress' },
            { count: p.favorable_count, total: p.required_votes }
          )}
        </span>
        {p.opposed_count > 0 && (
          <span style={{ marginLeft: 8, color: '#f87171' }}>
            · {p.opposed_count} {t({ id: 'rede.cooptation.vote.opposed' }).toLowerCase()}
          </span>
        )}
        {p.abstain_count > 0 && (
          <span style={{ marginLeft: 8 }}>
            · {p.abstain_count} {t({ id: 'rede.cooptation.vote.abstain' }).toLowerCase()}
          </span>
        )}
      </div>

      {/* Motivation (preview limitee) */}
      {p.motivation && (
        <div
          style={{
            fontSize: '.85rem',
            fontStyle: 'italic',
            padding: '6px 10px',
            background: 'rgba(0,0,0,.15)',
            borderRadius: 4,
            borderLeft: '3px solid rgba(255,255,255,.15)',
          }}
        >
          {p.motivation.length > 200
            ? p.motivation.slice(0, 200) + '…'
            : p.motivation}
        </div>
      )}

      {/* Actions : bouton Vote */}
      {canVote && (
        <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
          <button
            type="button"
            className="cat-btn"
            onClick={onVoteClick}
            style={{ fontSize: '.82rem' }}
          >
            {p.caller_has_voted
              ? t({ id: 'rede.cooptation.vote.modal.title' }) + ' …'
              : t({ id: 'rede.cooptation.vote.submit' })}
          </button>
        </div>
      )}
    </div>
  );
}
