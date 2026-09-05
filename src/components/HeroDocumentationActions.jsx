// src/components/HeroDocumentationActions.jsx
//
// Rangée de boutons « documentation » du hero : le bon recueil, ouvert à la
// bonne page, dans la langue de la personne — plus les vade-mecums des
// Communs quand la page s'y prête (catalogage, autorités).
//
// Ce que l'on montre est décidé par src/lib/docLinks.js (page → documents)
// via useEffectiveScope ; ici on ne fait que rendre. Les PDF sont ceux du
// bucket library-ui-assets/manuals/network/published/ (01-03/09/2026).

import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import useEffectiveScope from '@/hooks/useEffectiveScope';

function BookIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
      <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    </svg>
  );
}

function ScaleIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 3v18" /><path d="M5 7h14" />
      <path d="M3 13l2-6 2 6a2 2 0 0 1-4 0z" /><path d="M17 13l2-6 2 6a2 2 0 0 1-4 0z" />
    </svg>
  );
}

function LeafIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M11 20A7 7 0 0 1 4 13c0-5 4-9 16-9-1 12-5 16-9 16z" /><path d="M4 20l7-7" />
    </svg>
  );
}

// Titres des vade-mecums : les clés existantes du registre des Communs.
const COMMUNS_TITLE_KEY = {
  'guide-conventions': 'federacao.communs.doc.guideConventions.title',
  'guide-indexar': 'federacao.communs.doc.indexarAssunto.title',
  'guide-scan': 'federacao.communs.doc.guideScan.title',
  'guide-numerisation': 'federacao.communs.doc.guideNumerisation.title',
  cotation: 'federacao.communs.doc.cotation.title',
  'thesaurus-ficedl': 'federacao.communs.doc.thesaurusFicedl.title',
};

/**
 * @param {object} props
 * @param {React.ReactNode} [props.extraActions]
 *   Boutons additionnels spécifiques à la page (ex. Exportar PDF/CSV sur /catalogo,
 *   pastilles de compteurs sur /painel), rendus AVANT les liens de documentation.
 */
export default function HeroDocumentationActions({ extraActions = null }) {
  const intl = useIntl();
  const { documents } = useEffectiveScope();

  const hasDoc =
    documents.showReaderManual ||
    documents.showCompleteManual ||
    documents.showGovernanceGuide ||
    (documents.communs && documents.communs.length > 0);
  if (!hasDoc && !extraActions) return null;

  return (
    <div className="ab-hero-doc-actions">
      {extraActions}

      {documents.showReaderManual && (
        <a href={documents.readerManualUrl} target="_blank" rel="noopener noreferrer"
          className="ab-hero-doc-btn ab-hero-doc-btn--primary">
          <span className="ab-hero-doc-btn__icon"><BookIcon /></span>
          <span>{intl.formatMessage({ id: 'nav.manual.reader' })}</span>
        </a>
      )}

      {documents.showCompleteManual && (
        <a href={documents.completeManualUrl} target="_blank" rel="noopener noreferrer"
          className="ab-hero-doc-btn ab-hero-doc-btn--primary">
          <span className="ab-hero-doc-btn__icon"><BookIcon /></span>
          <span>{intl.formatMessage({ id: 'nav.manual.complete' })}</span>
        </a>
      )}

      {documents.showGovernanceGuide && (
        <a href={documents.governanceGuideUrl} target="_blank" rel="noopener noreferrer"
          className="ab-hero-doc-btn ab-hero-doc-btn--gov">
          <span className="ab-hero-doc-btn__icon"><ScaleIcon /></span>
          <span>{intl.formatMessage({ id: 'nav.governance.guide' })}</span>
        </a>
      )}

      {(documents.communs || []).map((c) => (
        COMMUNS_TITLE_KEY[c.id] ? (
          <Link key={c.id} to={c.to} className="ab-hero-doc-btn ab-hero-doc-btn--gov">
            <span className="ab-hero-doc-btn__icon"><LeafIcon /></span>
            <span>{intl.formatMessage({ id: COMMUNS_TITLE_KEY[c.id] })}</span>
          </Link>
        ) : null
      ))}
    </div>
  );
}
