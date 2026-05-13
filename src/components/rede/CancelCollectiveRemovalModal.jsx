// ============================================================================
// src/components/rede/CancelCollectiveRemovalModal.jsx
// ============================================================================
//
// Modal pour annuler une proposition de retrait collectif (avant execution).
// Appelle fn_network_admin_cancel_collective_removal (D.6) avec :
//   - p_proposal_id (uuid)
//   - p_reason (text >= 20 chars)
//
// Doctrine v0.3 (D.6) :
//   - L'annulation est possible tant que la proposition n'est pas executee
//     (status 'open' ou 'unanimous' avec carence en cours)
//   - reason obligatoire >= 20 chars
//   - Garde DB cote RPC sur qui peut annuler (a priori : tout admin reseau)
//
// i18n : rede.collectiveRemoval.cancel.* (livre en E.2)
// ============================================================================

import { useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

const MIN_REASON_CHARS = 20;

export default function CancelCollectiveRemovalModal({
  isOpen,
  proposal,
  onClose,
  onSuccess,
}) {
  const { formatMessage: t } = useIntl();

  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const reasonLen = reason.trim().length;
  const reasonValid = reasonLen >= MIN_REASON_CHARS;
  const canSubmit = reasonValid && !submitting && proposal;

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
        'fn_network_admin_cancel_collective_removal',
        {
          p_proposal_id: proposal.proposal_id,
          p_reason: reason.trim(),
        }
      );

      if (rpcErr) {
        setError(t({ id: 'common.errorPrefix' }, { message: rpcErr.message || '' }));
        return;
      }

      setReason('');
      if (onSuccess) onSuccess();
    } catch (err) {
      console.warn('CancelCollectiveRemovalModal:', err);
      setError(t({ id: 'common.errorPrefix' }, { message: err.message || String(err) }));
    } finally {
      setSubmitting(false);
    }
  }, [proposal, reason, onSuccess, t]);

  const handleClose = useCallback(() => {
    if (submitting) return;
    setReason('');
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
          borderRadius: 8, padding: 24, maxWidth: 560,
          width: 'calc(100% - 32px)', maxHeight: '90vh', overflowY: 'auto',
        }}
      >
        <h3 style={{ margin: '0 0 4px' }}>
          {t({ id: 'rede.collectiveRemoval.cancel.modal.title' })}
        </h3>
        <div style={{ fontSize: '.92rem', fontWeight: 600, marginBottom: 16 }}>
          {targetName}
        </div>

        {/* Raison */}
        <div style={{ marginBottom: 14 }}>
          <label
            htmlFor="cr-cancel-reason"
            style={{ display: 'block', fontSize: '.85rem', marginBottom: 4 }}
          >
            {t({ id: 'rede.collectiveRemoval.cancel.modal.reasonLabel' })}
          </label>
          <textarea
            id="cr-cancel-reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
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
              color: reasonValid ? 'var(--brand-muted)' : '#fbbf24',
              marginTop: 4,
            }}
          >
            {t(
              { id: 'rede.cooptation.propose.modal.motivationMinChars' },
              { count: reasonLen }
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
          >
            {submitting
              ? t({ id: 'common.loading' })
              : t({ id: 'rede.collectiveRemoval.cancel.modal.submit' })}
          </button>
        </div>
      </div>
    </div>
  );
}
