// ============================================================================
// src/components/rede/ProposeCooptationModal.jsx
// ============================================================================
//
// Modal pour proposer la cooptation d'une personne comme administrateur de
// reseau. Appelle la RPC fn_network_admin_propose_cooptation (D.5) avec
// p_user_id (uuid de la cible) et p_motivation (texte >= 20 chars).
//
// Workflow utilisateur :
//   1. Saisir l'email de la personne (auto-completion via SELECT profiles)
//   2. Saisir la motivation politique (textarea, min 20 chars)
//   3. Soumettre -> RPC, refresh listing, fermeture modal
//
// Doctrine v0.3 :
//   - Motivation obligatoire (>= 20 chars)
//   - Ne peut proposer soi-meme (garde DB cote SQL)
//   - Ne peut proposer une personne deja admin reseau actif (garde DB)
//   - Une seule proposition en cours par personne (garde DB)
//
// i18n : rede.cooptation.propose.* (livre en E.2)
// ============================================================================

import { useState, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

const MIN_MOTIVATION_CHARS = 20;

export default function ProposeCooptationModal({ isOpen, onClose, onSuccess }) {
  const { formatMessage: t } = useIntl();

  const [targetEmail, setTargetEmail] = useState('');
  const [motivation, setMotivation] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const motivationLen = motivation.trim().length;
  const motivationValid = motivationLen >= MIN_MOTIVATION_CHARS;
  const emailValid = /^\S+@\S+\.\S+$/.test(targetEmail.trim());

  const canSubmit = emailValid && motivationValid && !submitting;

  const handleSubmit = useCallback(async () => {
    setError(null);
    setSubmitting(true);
    try {
      // 1. Resoudre l'email en user_id via SELECT profiles
      const emailLc = targetEmail.trim().toLowerCase();
      const { data: targetProfile, error: profErr } = await supabase
        .from('profiles')
        .select('id, email')
        .ilike('email', emailLc)
        .maybeSingle();

      if (profErr) throw profErr;
      if (!targetProfile) {
        setError(t({ id: 'rede.cooptation.propose.errors.targetNotFound' }));
        return;
      }

      // 2. Appel RPC
      const { error: rpcErr } = await supabase.rpc(
        'fn_network_admin_propose_cooptation',
        {
          p_user_id: targetProfile.id,
          p_motivation: motivation.trim(),
        }
      );

      if (rpcErr) {
        // Gardes DB : already_admin, proposal_exists, etc.
        const msg = rpcErr.message || '';
        if (msg.includes('already_admin')) {
          setError(t({ id: 'rede.cooptation.propose.errors.alreadyAdmin' }));
        } else if (msg.includes('proposal_exists')) {
          setError(t({ id: 'rede.cooptation.propose.errors.proposalExists' }));
        } else {
          setError(t({ id: 'common.errorPrefix' }, { message: msg }));
        }
        return;
      }

      // 3. Succes
      setTargetEmail('');
      setMotivation('');
      if (onSuccess) onSuccess();
    } catch (err) {
      console.warn('ProposeCooptationModal:', err);
      setError(t({ id: 'common.errorPrefix' }, { message: err.message || String(err) }));
    } finally {
      setSubmitting(false);
    }
  }, [targetEmail, motivation, onSuccess, t]);

  const handleClose = useCallback(() => {
    if (submitting) return;
    setTargetEmail('');
    setMotivation('');
    setError(null);
    onClose();
  }, [submitting, onClose]);

  if (!isOpen) return null;

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
        <h3 style={{ margin: '0 0 8px' }}>
          {t({ id: 'rede.cooptation.propose.modal.title' })}
        </h3>
        <p style={{ fontSize: '.88rem', color: 'var(--brand-muted)', margin: '0 0 16px' }}>
          {t({ id: 'rede.cooptation.propose.modal.description' })}
        </p>

        {/* Email cible */}
        <div style={{ marginBottom: 14 }}>
          <label
            htmlFor="propose-target-email"
            style={{ display: 'block', fontSize: '.85rem', marginBottom: 4 }}
          >
            {t({ id: 'rede.cooptation.propose.modal.targetLabel' })}
          </label>
          <input
            id="propose-target-email"
            type="email"
            value={targetEmail}
            onChange={(e) => setTargetEmail(e.target.value)}
            placeholder={t({ id: 'rede.cooptation.propose.modal.targetPlaceholder' })}
            disabled={submitting}
            style={{
              width: '100%',
              padding: '8px 10px',
              background: 'rgba(0,0,0,.3)',
              border: '1px solid rgba(255,255,255,.1)',
              borderRadius: 4,
              color: 'inherit',
              fontSize: '.9rem',
            }}
          />
        </div>

        {/* Motivation */}
        <div style={{ marginBottom: 14 }}>
          <label
            htmlFor="propose-motivation"
            style={{ display: 'block', fontSize: '.85rem', marginBottom: 4 }}
          >
            {t({ id: 'rede.cooptation.propose.modal.motivationLabel' })}
          </label>
          <textarea
            id="propose-motivation"
            value={motivation}
            onChange={(e) => setMotivation(e.target.value)}
            placeholder={t({ id: 'rede.cooptation.propose.modal.motivationPlaceholder' })}
            disabled={submitting}
            rows={5}
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
              color: motivationValid ? 'var(--brand-muted)' : '#fbbf24',
              marginTop: 4,
            }}
          >
            {t(
              { id: 'rede.cooptation.propose.modal.motivationMinChars' },
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
              : t({ id: 'rede.cooptation.propose.modal.submit' })}
          </button>
        </div>
      </div>
    </div>
  );
}
