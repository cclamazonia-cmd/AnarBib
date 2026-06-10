// ============================================================================
// src/components/rede/VoteCooptationModal.jsx
// ============================================================================
//
// Modal pour voter sur une proposition de cooptation. Appelle la RPC
// fn_network_admin_vote_cooptation (D.5) avec :
//   - p_proposal_id (uuid)
//   - p_vote ('favorable' | 'opposed' | 'abstain')
//   - p_disclose_identity (boolean, choix explicite obligatoire)
//   - p_rationale (text, obligatoire >= 20 chars si vote='opposed')
//
// Workflow utilisateur :
//   1. Choisir un vote (radio favorable / opposed / abstain)
//   2. Si opposed : saisir une justification politique (textarea, min 20 chars)
//   3. Choisir explicitement disclose_identity (checkbox obligatoire)
//   4. Soumettre -> RPC, refresh listing, fermeture modal
//
// Doctrine v0.3 (D.5) :
//   - Le proposeur a deja vote favorable implicite a la creation
//   - Garde DB : ne peut voter sur sa propre cooptation
//   - rationale obligatoire si opposed (garde DB cote SQL)
//   - disclose_identity NON-NULL obligatoire (choix explicite, pas de DEFAULT)
//   - UPSERT : peut changer son vote tant que la proposition est ouverte
//
// i18n : rede.cooptation.vote.* (livre en E.2)
// ============================================================================

import { useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

const MIN_RATIONALE_CHARS = 20;

export default function VoteCooptationModal({
  isOpen,
  proposal,    // { proposal_id, proposed_first_name, proposed_last_name, proposed_email, ... }
  onClose,
  onSuccess,
}) {
  const { formatMessage: t } = useIntl();

  const [vote, setVote] = useState(null);         // 'favorable' | 'opposed' | 'abstain' | null
  const [rationale, setRationale] = useState('');
  const [disclose, setDisclose] = useState(null); // null = pas encore choisi
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const rationaleLen = rationale.trim().length;
  const rationaleRequired = vote === 'opposed';
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
        'fn_network_admin_vote_cooptation',
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
          setError(t({ id: 'common.errorPrefix' }, { message: localizeError(rpcErr, t) }));
        }
        return;
      }

      // Reset + succes
      setVote(null);
      setRationale('');
      setDisclose(null);
      if (onSuccess) onSuccess();
    } catch (err) {
      console.warn('VoteCooptationModal:', err);
      setError(t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }));
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
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,.6)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
      }}
    >
      <div
        className="ab-modal"
        onClick={(e) => e.stopPropagation()}
        style={{
          background: 'var(--brand-surface, #1a1a1a)',
          border: '1px solid rgba(255,255,255,.1)',
          borderRadius: 8,
          padding: 24,
          maxWidth: 560,
          width: 'calc(100% - 32px)',
          maxHeight: '90vh',
          overflowY: 'auto',
        }}
      >
        <h3 style={{ margin: '0 0 4px' }}>
          {t({ id: 'rede.cooptation.vote.modal.title' })}
        </h3>
        <div style={{ fontSize: '.92rem', fontWeight: 600, marginBottom: 8 }}>
          {targetName}
        </div>
        <p style={{ fontSize: '.85rem', color: 'var(--brand-muted)', margin: '0 0 16px' }}>
          {t({ id: 'rede.cooptation.vote.modal.description' })}
        </p>

        {/* Choix du vote (radio group) */}
        <div style={{ marginBottom: 14 }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {['favorable', 'opposed', 'abstain'].map((v) => (
              <label
                key={v}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  padding: '8px 10px',
                  background: vote === v ? 'rgba(255,255,255,.06)' : 'transparent',
                  border: '1px solid rgba(255,255,255,.08)',
                  borderRadius: 4,
                  cursor: submitting ? 'not-allowed' : 'pointer',
                }}
              >
                <input
                  type="radio"
                  name="vote"
                  value={v}
                  checked={vote === v}
                  onChange={() => setVote(v)}
                  disabled={submitting}
                />
                <span style={{ fontSize: '.9rem' }}>
                  {t({ id: `rede.cooptation.vote.${v}` })}
                </span>
              </label>
            ))}
          </div>
        </div>

        {/* Rationale (visible si opposed) */}
        {vote === 'opposed' && (
          <div style={{ marginBottom: 14 }}>
            <label
              htmlFor="vote-rationale"
              style={{ display: 'block', fontSize: '.85rem', marginBottom: 4 }}
            >
              {t({ id: 'rede.cooptation.vote.rationaleLabel' })}
            </label>
            <textarea
              id="vote-rationale"
              value={rationale}
              onChange={(e) => setRationale(e.target.value)}
              placeholder={t({ id: 'rede.cooptation.vote.rationalePlaceholder' })}
              disabled={submitting}
              rows={4}
              style={{
                width: '100%',
                padding: '8px 10px',
                background: 'rgba(0,0,0,.3)',
                border: '1px solid rgba(255,255,255,.1)',
                borderRadius: 4,
                color: 'inherit',
                fontSize: '.9rem',
                resize: 'vertical',
                fontFamily: 'inherit',
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

        {/* Disclose identity (checkbox tri-state) */}
        <div
          style={{
            marginBottom: 14,
            padding: '10px 12px',
            background: 'rgba(0,0,0,.2)',
            border: '1px solid rgba(255,255,255,.08)',
            borderRadius: 4,
          }}
        >
          <div style={{ fontSize: '.85rem', marginBottom: 6 }}>
            {t({ id: 'rede.cooptation.vote.discloseIdentityLabel' })}
          </div>
          <div style={{ display: 'flex', gap: 12 }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <input
                type="radio"
                name="disclose"
                value="true"
                checked={disclose === true}
                onChange={() => setDisclose(true)}
                disabled={submitting}
              />
              <span style={{ fontSize: '.88rem' }}>{t({ id: 'common.yes' })}</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <input
                type="radio"
                name="disclose"
                value="false"
                checked={disclose === false}
                onChange={() => setDisclose(false)}
                disabled={submitting}
              />
              <span style={{ fontSize: '.88rem' }}>{t({ id: 'common.no' })}</span>
            </label>
          </div>
          <div
            style={{
              fontSize: '.78rem',
              color: 'var(--brand-muted)',
              marginTop: 6,
              fontStyle: 'italic',
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
              borderRadius: 4,
              color: '#f87171',
              fontSize: '.88rem',
              marginBottom: 14,
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
