// src/components/UserHeroBadge.jsx
//
// Rend le bloc identité partagé en tête des héros de page :
//   [Nom prénom] [Rôle effectif] [ID public] [Sigle biblio] [(Statut conta)]
//
// IMPORTANT : couleurs en style INLINE pour battre theme.js qui setProperty
// les --brand-* sur le hero. Le CSS gère uniquement la mise en page.
// Note : color: inherit explicite sur les <span> enfants pour bloquer
// la cascade de --brand-text qui les forcerait en blanc.
//
// Cf. mémoire AnarBib "theme.js inline style prioritaire" (02/05/2026)

import { useIntl } from 'react-intl';
import useEffectiveScope from '@/hooks/useEffectiveScope';
import './UserHeroBadge.css';

// --- Palette de couleurs (doctrine §2.2) ---------------------------------
const ROLE_COLORS = {
  // Doctrine couleurs (ramps c-amber/c-blue/c-green) - contraste invers
  // (fond fonc stop 900, texte clair stop 100/200) pour lisibilit
  // sur le fond rouge profond AnarBib du hero.
  leitor: { bg: '#412402', fg: '#FAC775', border: '#BA7517' },
  staff:  { bg: '#042C53', fg: '#85B7EB', border: '#185FA5' },
  admin:  { bg: '#173404', fg: '#C0DD97', border: '#3B6D11' },
};

const NEUTRAL_PALETTE = {
  bg: 'rgba(245, 233, 216, 0.08)',
  fg: '#d9c9b0',
  border: 'rgba(245, 233, 216, 0.2)',
};

const STATUS_PALETTES = {
  active:    { bg: 'rgba(99, 153, 34, 0.18)',  fg: '#C0DD97', border: 'rgba(99, 153, 34, 0.5)' },
  attention: { bg: 'rgba(186, 117, 23, 0.18)', fg: '#FAC775', border: 'rgba(186, 117, 23, 0.5)' },
  blocked:   { bg: 'rgba(226, 75, 74, 0.18)',  fg: '#F09595', border: 'rgba(226, 75, 74, 0.5)' },
};

function pillStyle(palette) {
  if (!palette) return null;
  return {
    backgroundColor: palette.bg,
    color: palette.fg,
    borderColor: palette.border,
  };
}

// Style enfant : force color: inherit pour bloquer la cascade des --brand-*
const CHILD_TEXT_STYLE = { color: 'inherit' };

/**
 * @param {object} props
 * @param {('active'|'attention'|'blocked'|null)} [props.accountStatus]
 */
export default function UserHeroBadge({ accountStatus = null }) {
  const intl = useIntl();
  const scope = useEffectiveScope();

  if (!scope.isAuthenticated) return null;
  if (!scope.fullName && !scope.publicId) return null;

  const rolePalette = ROLE_COLORS[scope.roleVariant] || null;
  const roleStyle = pillStyle(rolePalette);
  const neutralStyle = pillStyle(NEUTRAL_PALETTE);

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
        <span className="ab-hero-badge" style={roleStyle}>
          <span aria-hidden="true" className="ab-hero-badge__icon" style={CHILD_TEXT_STYLE}>
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none"
                 stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="8" r="4" />
              <path d="M4 21v-1a7 7 0 0 1 14 0v1" />
            </svg>
          </span>
          <span style={CHILD_TEXT_STYLE}>{scope.fullName}</span>
        </span>
      )}

      {roleLabel && (
        <span className="ab-hero-badge" style={roleStyle}>
          <span style={CHILD_TEXT_STYLE}>{roleLabel}</span>
        </span>
      )}

      {scope.publicId && (
        <span className="ab-hero-badge" style={neutralStyle}>
          <span className="ab-hero-badge__id" style={CHILD_TEXT_STYLE}>{scope.publicId}</span>
        </span>
      )}

      {scope.showLibraryAcronym && scope.libraryAcronym && (
        <span className="ab-hero-badge" style={neutralStyle}>
          <span style={CHILD_TEXT_STYLE}>{scope.libraryAcronym}</span>
        </span>
      )}

      {accountStatus === 'active' && (
        <span className="ab-hero-badge" style={pillStyle(STATUS_PALETTES.active)}>
          <span style={CHILD_TEXT_STYLE}>{intl.formatMessage({ id: 'account.status.active' })}</span>
        </span>
      )}
      {accountStatus === 'attention' && (
        <span className="ab-hero-badge" style={pillStyle(STATUS_PALETTES.attention)}>
          <span style={CHILD_TEXT_STYLE}>{intl.formatMessage({ id: 'account.status.attention' })}</span>
        </span>
      )}
      {accountStatus === 'blocked' && (
        <span className="ab-hero-badge" style={pillStyle(STATUS_PALETTES.blocked)}>
          <span style={CHILD_TEXT_STYLE}>{intl.formatMessage({ id: 'account.status.blocked' })}</span>
        </span>
      )}
    </div>
  );
}