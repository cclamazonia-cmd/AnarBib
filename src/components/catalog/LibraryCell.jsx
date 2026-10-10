// src/components/catalog/LibraryCell.jsx — E6, Catalogue public, lot 2 (10/10/2026) : sortie de CatalogPage.jsx telle quelle.
import { useState } from 'react';
import { MAX_VISIBLE_LIBS } from '@/lib/catalogOpac';

// Le compteur est un bouton, pas une infobulle : le catalogue se lit aussi au
// doigt, et un survol n'existe pas sur mobile.
export default function LibraryCell({ names, t }) {
  const [expanded, setExpanded] = useState(false);
  if (!names.length) return '\u2014';
  const hidden = names.length - MAX_VISIBLE_LIBS;
  if (hidden <= 0) return names.join(', ');
  if (expanded) {
    return (
      <>
        {names.join(', ')}{' '}
        <button type="button" className="ab-libs-more" onClick={() => setExpanded(false)}>
          {t({ id: 'catalog.libraries.less' })}
        </button>
      </>
    );
  }
  return (
    <>
      {names.slice(0, MAX_VISIBLE_LIBS).join(', ')}{' '}
      <button
        type="button"
        className="ab-libs-more"
        onClick={() => setExpanded(true)}
        aria-label={t({ id: 'catalog.libraries.moreAria' }, { count: hidden })}
      >
        {t({ id: 'catalog.libraries.more' }, { count: hidden })}
      </button>
    </>
  );
}
