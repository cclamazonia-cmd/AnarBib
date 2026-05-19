// src/components/UserHeroBadge.jsx
//
// Rend le bloc identité partagé en tête des héros de page :
//   [Nom prénom] [Rôle effectif] [ID public] [Sigle biblio] [(Statut conta)]
//
// Cf. docs/decisions/CHANTIER_harmonisation_heros_2026-05-19.md §2.1 et §3.1

import { useIntl } from 'react-intl';
import useEffectiveScope from '@/hooks/useEffectiveScope';
import './UserHeroBadge.css';

/**
 * @param {object} props
 * @param {('active'|'attention'|'blocked'|null)} [props.accountStatus]
 *   Statut du compte, uniquement utile sur /conta. null = ne pas afficher la pill statut.
 */
export default function UserHeroBadge({ accountStatus = null }) {
  const intl = useIntl();
  const scope = useEffectiveScope();

  if (!scope.isAuthenticated) return null;
  if (!scope.fullName && !scope.publicId) return null; // profil pas encore chargé

  const variantClass = scope.roleVariant
    ? `ab-hero-badge--${scope.roleVariant}`
    : '';

  const roleLabel = scope.roleLabelKey
    ? intl.formatMessage({ id: scope.roleLabelKey })
    : null;

  const ariaLabel = intl.formatMessage({
    id: 'hero.identity.aria',
    defaultMessage: 'Identidade do(a/e) usuário(a/e)',
  });

  return (
    <div className="ab-hero-badge-row" role="group" aria-label={ariaLabel}>
      {scope.fullName && (
        <span className={`ab-hero-badge ${variantClass}`}>
          <span aria-hidden="true" className="ab-hero-badge__icon">
            {/* Icône inline pour éviter dépendance externe */}
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none"
                 stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="8" r="4" />
              <path d="M4 21v-1a7 7 0 0 1 14 0v1" />
            </svg>
          </span>
          <span>{scope.fullName}</span>
        </span>
      )}

      {roleLabel && (
        <span className={`ab-hero-badge ${variantClass}`}>
          <span>{roleLabel}</span>
        </span>
      )}

      {scope.publicId && (
        <span className="ab-hero-badge ab-hero-badge--neutral">
          <span className="ab-hero-badge__id">{scope.publicId}</span>
        </span>
      )}

      {scope.showLibraryAcronym && scope.libraryAcronym && (
        <span className="ab-hero-badge ab-hero-badge--neutral">
          <span>{scope.libraryAcronym}</span>
        </span>
      )}

      {accountStatus === 'active' && (
        <span className="ab-hero-badge ab-hero-badge--status-ok">
          <span>{intl.formatMessage({ id: 'account.status.active' })}</span>
        </span>
      )}
      {accountStatus === 'attention' && (
        <span className="ab-hero-badge ab-hero-badge--status-warn">
          <span>{intl.formatMessage({ id: 'account.status.attention' })}</span>
        </span>
      )}
      {accountStatus === 'blocked' && (
        <span className="ab-hero-badge ab-hero-badge--status-danger">
          <span>{intl.formatMessage({ id: 'account.status.blocked' })}</span>
        </span>
      )}
    </div>
  );
}
