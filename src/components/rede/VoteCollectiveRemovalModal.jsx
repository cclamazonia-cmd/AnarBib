// ============================================================================
// src/components/rede/VoteCollectiveRemovalModal.jsx
// ============================================================================
//
// Modal pour voter sur une proposition de retrait collectif.
// Appelle fn_network_admin_vote_collective_removal (D.6) avec :
//   - p_proposal_id (uuid)
//   - p_vote ('favor' | 'against')  -- pas d'abstention (doctrine D.6)
//   - p_disclose_identity (boolean)
//   - p_rationale (text, obligatoire >= 20 chars si 'against')
//
// Doctrine v0.3 (D.6) :
//   - Vote binaire : favor ou against (pas d'abstention contrairement a cooptation)
//   - rationale obligatoire si against (>= 20 chars)
//   - disclose_identity NON-NULL (choix explicite, pas de DEFAULT)
//   - UPSERT : peut changer son vote tant que la proposition est ouverte
//   - Ne peut voter sur son propre retrait (caller_is_target)
//   - Une fois unanimite atteinte, status passe a 'unanimous', carence 7j
//
// i18n : rede.collectiveRemoval.vote.* (livre en E.2)
// ============================================================================

import { useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

const MIN_RATIONALE_CHARS = 20;

export default function VoteCollectiveRemovalModal({
  isOpen,
  proposal,
  onClose,
  onSuccess,
}) {
  const { formatMessage: t } = useIntl();

  const [vote, setVote] = useState(null);         // 'favor' | 'against' | null
  const [rationale, setRationale] = useState('');
  const [disclose, setDisclose] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const rationaleLen = rationale.trim().length;
  const rationaleRequired = vote === 'against';
  const rationaleValid = !rationaleRequired || rationaleLen >= MIN_RATIONALE_CHARS;
  const discloseChosen = disclose !== null;
  const voteChosen = vote !== null;

  const canSubmit = voteChosen && rationaleValid && discloseChosen && !submitting;

  const targetName = proposal
    ? [proposal.proposed_first_name, proposal.proposed_last_name].filter(Boolean).join(' ')
      || proposal.proposed_email
      || t({ id: 'team.unnamedMember' })
    : '';

  const handleSubmit = useCallback(async () => {
    setError(null);
    setSubmitting(true);
    try {
      const { error: rpcErr } = await supabase.rpc(
        'fn_network_admin_vote_collective_removal',
        {
          p_proposal_id: proposal.proposal_id,
          p_vote: vote,
          p_disclose_identity: disclose,
          p_rationale: rationaleRequired ? rationale.trim() : null,
        }
      );

      if (rpcErr) {
        const msg = rpcErr.message || '';
        if (msg.includes('rationale_required')) {
          setError(t({ id: 'rede.cooptation.vote.errors.rationaleRequired' }));
        } else if (msg.includes('disclose_identity_required')) {
          setError(t({ id: 'rede.cooptation.vote.errors.discloseRequired' }));
        } else {
          setError(t({ id: 'common.errorPrefix' }, { message: msg }));
        }
        return;
      }

      setVote(null);
      setRationale('');
      setDisclose(null);
      if (onSuccess) onSuccess();
    } catch (err) {
      console.warn('VoteCollectiveRemovalModal:', err);
      setError(t({ id: 'common.errorPrefix' }, { message: err.message || String(err) }));
    } finally {
      setSubmitting(false);
    }
  }, [proposal, vote, rationale, rationaleRequired, disclose, onSuccess, t]);

  const handleClose = useCallback(() => {
    if (submitting) return;
    setVote(null);
    setRationale('');
    setDisclose(null);
    setError(null);
    onClose();
  }, [submitting, onClose]);

  if (!isOpen || !proposal) return null;

  return (
    <div
      className="ab-modal-backdrop"
      onClick={handleClose}
      style={{
        position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000,
      }}
    >
      <div
        className="ab-modal"
        onClick={(e) => e.stopPropagation()}
        style={{
          background: 'var(--brand-surface, #1a1a1a)',
          border: '1px solid rgba(255,255,255,.1)',
          borderRadius: 8, padding: 24, maxWidth: 600,
          width: 'calc(100% - 32px)', maxHeight: '90vh', overflowY: 'auto',
        }}
      >
        <h3 style={{ margin: '0 0 4px' }}>
          {t({ id: 'rede.collectiveRemoval.vote.modal.title' })}
        </h3>
        <div style={{ fontSize: '.92rem', fontWeight: 600, marginBottom: 16 }}>
          {targetName}
        </div>

        {/* Choix du vote (2 options : favor / against) */}
        <div style={{ marginBottom: 14 }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {['favor', 'against'].map((v) => (
              <label
                key={v}
                style={{
                  display: 'flex', alignItems: 'center', gap: 8,
                  padding: '8px 10px',
                  background: vote === v ? 'rgba(255,255,255,.06)' : 'transparent',
                  border: '1px solid rgba(255,255,255,.08)',
                  borderRadius: 4,
                  cursor: submitting ? 'not-allowed' : 'pointer',
                }}
              >
                <input
                  type="radio"
                  name="cr-vote"
                  value={v}
                  checked={vote === v}
                  onChange={() => setVote(v)}
                  disabled={submitting}
                />
                <span style={{ fontSize: '.9rem' }}>
                  {t({ id: `rede.collectiveRemoval.vote.${v}` })}
                </span>
              </label>
            ))}
          </div>
        </div>

        {/* Rationale (visible si against, obligatoire) */}
        {vote === 'against' && (
          <div style={{ marginBottom: 14 }}>
            <label
              htmlFor="cr-vote-rationale"
              style={{ display: 'block', fontSize: '.85rem', marginBottom: 4 }}
            >
              {t({ id: 'rede.collectiveRemoval.vote.rationaleLabel' })}
            </label>
            <textarea
              id="cr-vote-rationale"
              value={rationale}
              onChange={(e) => setRationale(e.target.value)}
              disabled={submitting}
              rows={4}
              style={{
                width: '100%', padding: '8px 10px',
                background: 'rgba(0,0,0,.3)', border: '1px solid rgba(255,255,255,.1)',
                borderRadius: 4, color: 'inherit', fontSize: '.9rem',
                resize: 'vertical', fontFamily: 'inherit',
              }}
            />
            <div
              style={{
                fontSize: '.78rem',
                color: rationaleValid ? 'var(--brand-muted)' : '#fbbf24',
                marginTop: 4,
              }}
            >
              {t(
                { id: 'rede.cooptation.propose.modal.motivationMinChars' },
                { count: rationaleLen }
              )}
            </div>
          </div>
        )}

        {/* Disclose identity */}
        <div
          style={{
            marginBottom: 14, padding: '10px 12px',
            background: 'rgba(0,0,0,.2)',
            border: '1px solid rgba(255,255,255,.08)', borderRadius: 4,
          }}
        >
          <div style={{ fontSize: '.85rem', marginBottom: 6 }}>
            {t({ id: 'rede.cooptation.vote.discloseIdentityLabel' })}
          </div>
          <div style={{ display: 'flex', gap: 12 }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <input
                type="radio"
                name="cr-disclose"
                checked={disclose === true}
                onChange={() => setDisclose(true)}
                disabled={submitting}
              />
              <span style={{ fontSize: '.88rem' }}>{t({ id: 'common.yes' })}</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <input
                type="radio"
                name="cr-disclose"
                checked={disclose === false}
                onChange={() => setDisclose(false)}
                disabled={submitting}
              />
              <span style={{ fontSize: '.88rem' }}>{t({ id: 'common.no' })}</span>
            </label>
          </div>
          <div
            style={{
              fontSize: '.78rem', color: 'var(--brand-muted)',
              marginTop: 6, fontStyle: 'italic',
            }}
          >
            {t({ id: 'rede.cooptation.vote.discloseIdentityHint' })}
          </div>
        </div>

        {/* Erreur */}
        {error && (
          <div
            style={{
              padding: '8px 12px',
              background: 'rgba(248,113,113,.1)',
              border: '1px solid rgba(248,113,113,.3)',
              borderRadius: 4, color: '#f87171',
              fontSize: '.88rem', marginBottom: 14,
            }}
          >
            {error}
          </div>
        )}

        {/* Actions */}
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <button
            type="button"
            className="cat-btn"
            onClick={handleClose}
            disabled={submitting}
          >
            {t({ id: 'rede.cooptation.propose.modal.cancel' })}
          </button>
          <button
            type="button"
            className="cat-btn primary"
            onClick={handleSubmit}
            disabled={!canSubmit}
          >
            {submitting
              ? t({ id: 'common.loading' })
              : t({ id: 'rede.cooptation.vote.submit' })}
          </button>
        </div>
      </div>
    </div>
  );
}
