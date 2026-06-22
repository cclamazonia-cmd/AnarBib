import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

// Écran bloquant affiché quand l'unique appartenance du compte est encore
// `pending_validation` (biblio en mode présentiel/remote, pas encore validée par
// le staff). La création de réservation/consultation est de toute façon refusée
// côté base (trigger fn_trg_require_active_membership) ; ici on EXPLIQUE l'attente
// plutôt que de laisser un espace compte vide + une erreur opaque au moment d'agir.
// Branché par ContaRouter, qui ne le rend que pour un compte sans aucune
// appartenance active mais avec une appartenance en attente.
export default function PendingValidationScreen({ membership }) {
  const { formatMessage: t } = useIntl();
  const { signOut } = useAuth();
  useDocumentTitle(t({ id: 'account.pending.title' }));

  const libraryName = membership?.library_name || membership?.library_slug || 'AnarBib';

  return (
    <div
      style={{
        minHeight: '70vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 24,
      }}
    >
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
        <div style={{ fontSize: 40, marginBottom: 12 }} aria-hidden="true">⏳</div>
        <h1 style={{ fontSize: '1.4rem', margin: '0 0 16px' }}>
          {t({ id: 'account.pending.title' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', lineHeight: 1.6, margin: '0 0 12px' }}>
          {t({ id: 'account.pending.body' }, { library: libraryName })}
        </p>
        <p style={{ color: 'var(--brand-muted)', lineHeight: 1.6, margin: '0 0 24px' }}>
          {t({ id: 'account.pending.contact' })}
        </p>
        <div style={{ display: 'flex', gap: 10, justifyContent: 'center', flexWrap: 'wrap' }}>
          <Link to="/catalogo" className="ab-button">
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
