// src/components/catalog/AuthorLinks.jsx — E6, Catalogue public, lot 4 (10/10/2026) : sorti de CatalogPage.jsx tel quel.
import { useIntl } from 'react-intl';
import { Link } from 'react-router-dom';
import { authorLabel } from '@/lib/authorLabel';

// ── Composant liens auteurs ────────────────────────────────

export default function AuthorLinks({ book }) {
  // CONV-8 : « AA. VV. » / « Anônimo » sans autorité → étiquette localisée entre crochets.
  const { formatMessage: t } = useIntl();
  // author_chips est un JSON array [{ author_id, label }]
  let chips = book.author_chips;
  if (typeof chips === 'string') {
    try { chips = JSON.parse(chips); } catch { chips = null; }
  }

  if (Array.isArray(chips) && chips.length > 0) {
    return chips.map((chip, i) => (
      <span key={chip.author_id || `unlinked-${i}`}>
        {i > 0 && ' ; '}
        {chip.author_id ? (
          <Link to={`/autor/${chip.author_id}`} className="ab-author-link">
            {chip.label || chip.preferred_name || '?'}
          </Link>
        ) : (
          <span>{chip.label || '?'}</span>
        )}
      </span>
    ));
  }

  // Fallback : author_id unique
  if (book.author_id) {
    return (
      <Link to={`/autor/${book.author_id}`} className="ab-author-link">
        {authorLabel(book, t) || '—'}
      </Link>
    );
  }

  return <>{authorLabel(book, t) || '—'}</>;
}
