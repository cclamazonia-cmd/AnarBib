import { useState } from 'react';
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useToast } from '@/contexts/ToastContext';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// Écran bloquant pour un compte dont l'unique/primaire appartenance est REFUSÉE
// (refonte du refus, modèle à 2 passages). Branché par ContaRouter.
//   - isFinal=false (refusal_count < 2) : on propose une 2ᵉ demande (réexamen) ;
//     resubmit_membership repasse l'appartenance en pending_validation → au reload,
//     ContaRouter affiche l'écran d'attente et le staff revoit la demande.
//   - isFinal=true (refusal_count >= 2) : refus DÉFINITIF, pas de re-soumission.
// Dans les deux cas, l'espace compte complet reste inaccessible (gating).
export default function RefusedValidationScreen({ membership, isFinal }) {
  const { formatMessage: t } = useIntl();
  const { user, signOut } = useAuth();
  const { notifyError } = useToast();
  const [busy, setBusy] = useState(false);

  useDocumentTitle(t({ id: isFinal ? 'account.refused.final.title' : 'account.refused.retry.title' }));
  const libraryName = membership?.library_name || membership?.library_slug || 'AnarBib';

  async function resubmit() {
    if (busy) return;
    setBusy(true);
    try {
      // membership_id absent de fn_my_memberships_status → on le résout
      // (RLS ulm_select_own_memberships autorise la lecture de sa propre ligne).
      const { data: m, error: e1 } = await supabase
        .from('user_library_memberships')
        .select('id')
        .eq('user_id', user.id)
        .eq('library_id', membership.library_id)
        .eq('status', 'refused')
        .maybeSingle();
      if (e1) throw e1;
      if (!m?.id) throw new Error('membership_not_found');
      const { data, error } = await supabase.schema('api').rpc('resubmit_membership', {
        p_membership_id: m.id,
      });
      if (error) throw error;
      const row = Array.isArray(data) ? data[0] : data;
      if (row && row.ok === false) throw new Error(row.message || 'resubmit_failed');
      // Repassée en pending_validation → recharger pour afficher l'écran d'attente.
      window.location.reload();
    } catch (e) {
      notifyError(localizeError(e, t, 'account.refused.retry.error'), e);
      setBusy(false);
    }
  }

  return (
    <div style={{ minHeight: '70vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div
        style={{
          maxWidth: 540,
          width: '100%',
          textAlign: 'center',
          border: '1px solid rgba(0,0,0,0.12)',
          borderRadius: 12,
          padding: '40px 32px',
        }}
      >
        <div style={{ fontSize: 40, marginBottom: 12 }} aria-hidden="true">{isFinal ? '⛔' : '✋'}</div>
        <h1 style={{ fontSize: '1.4rem', margin: '0 0 16px' }}>
          {t({ id: isFinal ? 'account.refused.final.title' : 'account.refused.retry.title' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', lineHeight: 1.6, margin: '0 0 24px' }}>
          {t({ id: isFinal ? 'account.refused.final.body' : 'account.refused.retry.body' }, { library: libraryName })}
        </p>
        <div style={{ display: 'flex', gap: 10, justifyContent: 'center', flexWrap: 'wrap' }}>
          {!isFinal && (
            <button type="button" className="ab-button" onClick={resubmit} disabled={busy}>
              {busy ? t({ id: 'common.loading' }) : t({ id: 'account.refused.retry.button' })}
            </button>
          )}
          <Link to="/catalogo" className="ab-button ab-button--secondary">
            {t({ id: 'account.pending.browseCatalog' })}
          </Link>
          <button type="button" className="ab-button ab-button--secondary" onClick={signOut}>
            {t({ id: 'account.pending.logout' })}
          </button>
        </div>
      </div>
    </div>
  );
}
