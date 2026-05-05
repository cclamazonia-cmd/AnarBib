import { useEffect } from 'react';

const BASE_TITLE = 'AnarBib';

/**
 * Met à jour `document.title` à chaque changement de pageTitle.
 *
 * Appelé par chaque page de l'app pour éviter que le title du navigateur
 * reste bloqué sur celui d'une page précédente lors d'une navigation SPA.
 *
 * Format produit :
 *   - pageTitle vide ou égal à BASE_TITLE → "AnarBib"
 *   - sinon                              → "<pageTitle> — AnarBib"
 *
 * Usage :
 *   useDocumentTitle(t({ id: 'pageTitle.account' }));     // page fixe
 *   useDocumentTitle(book?.titulo);                       // page dynamique
 *
 * Ne PAS restaurer le title au démontage : entre l'unmount d'une page et
 * le mount de la suivante, ça ferait clignoter le title vers BASE_TITLE.
 * Le hook de la page suivante prend le relais immédiatement.
 */
export function useDocumentTitle(pageTitle) {
  useEffect(() => {
    document.title = pageTitle && pageTitle !== BASE_TITLE
      ? `${pageTitle} — ${BASE_TITLE}`
      : BASE_TITLE;
  }, [pageTitle]);
}
