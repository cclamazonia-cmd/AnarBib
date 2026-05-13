// ============================================================================
// src/components/rede/ProposeCollectiveRemovalModal.jsx
// ============================================================================
//
// Modal pour proposer le retrait collectif d'un(e/x) administrateur(rice/x)
// de reseau. Appelle la RPC fn_network_admin_propose_collective_removal (D.6)
// avec p_proposed_user_id (uuid pre-rempli depuis AdminRow) et p_motivation
// (text >= 50 chars).
//
// Doctrine v0.3 :
//   - Motivation obligatoire >= 50 chars (plus exigeante que cooptation : c'est
//     une decision politique grave)
//   - Le target est pre-rempli depuis la ligne AdminRow (clique sur le bouton
//     "Propor retirada coletiva" sur la ligne de la personne ciblee)
//   - Garde DB : ne peut se cibler soi-meme, ne peut cibler un non-admin,
//     une seule proposition ouverte par target
//
// i18n : rede.collectiveRemoval.propose.* (livre en E.2)
// ============================================================================

import { useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

const MIN_MOTIVATION_CHARS = 50;

export default function ProposeCollectiveRemovalModal({
  isOpen,
  target,      // { user_id, first_name, last_name, email }
  onClose,
  onSuccess,
}) {
  const { formatMessage: t } = useIntl();

  const [motivation, setMotivation] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const motivationLen = motivation.trim().length;
  const motivationValid = motivationLen >= MIN_MOTIVATION_CHARS;
  const canSubmit = motivationValid && !submitting && target;

  const targetName = target
    ? [target.first_name, target.last_name].filter(Boolean).join(' ')
      || target.email
      || t({ id: 'team.unnamedMember' })
    : '';

  const handleSubmit = useCallback(async () => {
    setError(null);
    setSubmitting(true);
    try {
      const { error: rpcErr } = await supabase.rpc(
        'fn_network_admin_propose_collective_removal',
        {
          p_proposed_user_id: target.user_id,
          p_motivation: motivation.trim(),
        }
      );

      if (rpcErr) {
        const msg = rpcErr.message || '';
        if (msg.includes('quorum_too_small')) {
          setError(t({ id: 'rede.collectiveRemoval.propose.errors.quorumTooSmall' }));
        } else if (msg.includes('proposal_already_open') || msg.includes('already_open')) {
          setError(t({ id: 'rede.collectiveRemoval.propose.errors.proposalAlreadyOpen' }));
        } else {
          setError(t({ id: 'common.errorPrefix' }, { message: msg }));
        }
        return;
      }

      setMotivation('');
      if (onSuccess) onSuccess();
    } catch (err) {
      console.warn('ProposeCollectiveRemovalModal:', err);
      setError(t({ id: 'common.errorPrefix' }, { message: err.message || String(err) }));
    } finally {
      setSubmitting(false);
    }
  }, [target, motivation, onSuccess, t]);

  const handleClose = useCallback(() => {
    if (submitting) return;
    setMotivation('');
    setError(null);
    onClose();
  }, [submitting, onClose]);

  if (!isOpen || !target) return null;

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
          {t({ id: 'rede.collectiveRemoval.propose.modal.title' })}
        </h3>
        <div style={{ fontSize: '.92rem', fontWeight: 600, marginBottom: 8 }}>
          {targetName}
        </div>

        {/* Warning politique */}
        <div
          style={{
            padding: '10px 12px',
            background: 'rgba(251,191,36,.08)',
            border: '1px solid rgba(251,191,36,.3)',
            borderRadius: 4,
            fontSize: '.85rem',
            color: '#fbbf24',
            marginBottom: 16,
          }}
        >
          ⚠ {t({ id: 'rede.collectiveRemoval.propose.modal.warning' })}
        </div>

        {/* Motivation */}
        <div style={{ marginBottom: 14 }}>
          <label
            htmlFor="cr-propose-motivation"
            style={{ display: 'block', fontSize: '.85rem', marginBottom: 4 }}
          >
            {t({ id: 'rede.collectiveRemoval.propose.modal.motivationLabel' })}
          </label>
          <textarea
            id="cr-propose-motivation"
            value={motivation}
            onChange={(e) => setMotivation(e.target.value)}
            placeholder={t({ id: 'rede.collectiveRemoval.propose.modal.motivationPlaceholder' })}
            disabled={submitting}
            rows={6}
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
              color: motivationValid ? 'var(--brand-muted)' : '#fbbf24',
              marginTop: 4,
            }}
          >
            {t(
              { id: 'rede.collectiveRemoval.propose.modal.motivationMinChars' },
              { count: motivationLen }
            )}
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
            style={{ background: 'rgba(248,113,113,.2)' }}
          >
            {submitting
              ? t({ id: 'common.loading' })
              : t({ id: 'rede.collectiveRemoval.propose.modal.submit' })}
          </button>
        </div>
      </div>
    </div>
  );
}
