// ============================================================================
// src/components/rede/NetworkAdminBadge.jsx
// ============================================================================
//
// Badge visuel pour identifier un(e/x) administrateur(rice/x) de reseau actif.
// Utilise dans AdminsPanel, TeamPanel, et tout listing oo l'identification
// du statut admin reseau est pertinente.
//
// Props :
//   - compact : boolean (default false)
//       false => libelle long "Admin rede" + tooltip detaille
//       true  => libelle court "Rede" (pour grilles serrees, mobile, etc.)
//   - title : string (optional)
//       override le tooltip par defaut. Utile si le badge est imbrique
//       dans un contexte qui a deja un tooltip parent.
//
// Style : reutilise les classes cat-pill existantes (pas de css dedie pour
// rester coherent avec les badges de statut).
//
// i18n :
//   rede.networkAdminBadge.label     (long)
//   rede.networkAdminBadge.shortLabel (compact)
//   rede.networkAdminBadge.tooltip
// Ces cles ont ete livrees en E.2.
//
// Doctrine : ce badge est visuellement distinct des badges de role local
// (administrador / coordenador / librarian / reader). Couleur de fond
// volontairement marquee (info) pour souligner le caractere transversal.
// ============================================================================

import { useIntl } from 'react-intl';

export default function NetworkAdminBadge({ compact = false, title }) {
  const { formatMessage: t } = useIntl();

  const label = compact
    ? t({ id: 'rede.networkAdminBadge.shortLabel' })
    : t({ id: 'rede.networkAdminBadge.label' });

  const tooltipText = title ?? t({ id: 'rede.networkAdminBadge.tooltip' });

  return (
    <span
      className="cat-pill info ab-network-admin-badge"
      style={{
        fontSize: compact ? '.62rem' : '.7rem',
        fontWeight: 700,
        letterSpacing: compact ? '.02em' : 'normal',
      }}
      title={tooltipText}
      aria-label={tooltipText}
    >
      {label}
    </span>
  );
}
