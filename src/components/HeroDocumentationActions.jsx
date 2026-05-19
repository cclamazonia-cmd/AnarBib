// src/components/HeroDocumentationActions.jsx
//
// Rend la rangee de boutons documentation en tete du hero, selon le scope
// de la page et le role effectif. Cf. CHANTIER §2.5 et §3.2

import { useIntl } from 'react-intl';
import useEffectiveScope from '@/hooks/useEffectiveScope';

// URLs des documents - voir CHANTIER §2.6.
// Le PDF guide-gouvernance v1.0 (11 mai 2026) doit avoir ete uploade dans
// le bucket library-ui-assets/manuals/network/published/ avant le deploiement.
const MANUAL_URLS = {
  reader:
    'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/manuals/network/published/Manual%20Leitor-a-e.pdf',
  complete:
    'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/manuals/network/published/Manual_do_AnarBib.pdf',
  governance:
    'https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/manuals/network/published/Guia_de_governanca_AnarBib.pdf',
};

// Icone livre (SVG inline pour eviter dependance externe)
function BookIcon() {
  return (
    <svg viewBox="0 0 24 24" width="14" height="14" fill="none"
         stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
         aria-hidden="true">
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    </svg>
  );
}

// Icone balance/justice (SVG inline)
function ScaleIcon() {
  return (
    <svg viewBox="0 0 24 24" width="14" height="14" fill="none"
         stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
         aria-hidden="true">
      <path d="M12 3v18" />
      <path d="M5 21h14" />
      <path d="M19 6l-2 6h4z" />
      <path d="M5 6l-2 6h4z" />
      <path d="M5 6h14" />
    </svg>
  );
}

/**
 * Rangee de boutons documentation. Rendu intelligent selon scope + role.
 *
 * @param {object} props
 * @param {React.ReactNode} [props.extraActions]
 *   Boutons additionnels specifiques a la page (ex. Exportar PDF/CSV sur /catalogo,
 *   Atualizar dados sur /rede). Rendus AVANT les boutons documentation.
 */
export default function HeroDocumentationActions({ extraActions = null }) {
  const intl = useIntl();
  const scope = useEffectiveScope();
  const { documents } = scope;

  const hasDoc =
    documents.showReaderManual ||
    documents.showCompleteManual ||
    documents.showGovernanceGuide;
  if (!hasDoc && !extraActions) return null;

  return (
    <div className="ab-hero-doc-actions">
      {extraActions}

      {documents.showReaderManual && (
        <a
          href={MANUAL_URLS.reader}
          target="_blank"
          rel="noopener noreferrer"
          className="ab-hero-doc-btn ab-hero-doc-btn--primary"
        >
          <span className="ab-hero-doc-btn__icon"><BookIcon /></span>
          <span>{intl.formatMessage({ id: 'nav.manual.reader' })}</span>
        </a>
      )}

      {documents.showCompleteManual && (
        <a
          href={MANUAL_URLS.complete}
          target="_blank"
          rel="noopener noreferrer"
          className="ab-hero-doc-btn ab-hero-doc-btn--primary"
        >
          <span className="ab-hero-doc-btn__icon"><BookIcon /></span>
          <span>{intl.formatMessage({ id: 'nav.manual.complete' })}</span>
        </a>
      )}

      {documents.showGovernanceGuide && (
        <a
          href={MANUAL_URLS.governance}
          target="_blank"
          rel="noopener noreferrer"
          className="ab-hero-doc-btn ab-hero-doc-btn--gov"
        >
          <span className="ab-hero-doc-btn__icon"><ScaleIcon /></span>
          <span>{intl.formatMessage({ id: 'nav.governance.guide' })}</span>
        </a>
      )}
    </div>
  );
}
