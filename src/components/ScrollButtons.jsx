import { useState, useEffect, useCallback } from 'react';
import { useLocation } from 'react-router-dom';
import { useIntl } from 'react-intl';

/* ════════════════════════════════════════════════════════════════════════
   AnarBib — ScrollButtons
   Deux boutons flottants « aller en haut / aller en bas de page ».

   Monté UNE SEULE FOIS dans App.jsx, à côté de <Routes>. Étant en
   position fixe, il flotte au-dessus de n'importe quelle page sans avoir
   à toucher chaque page individuellement.

   Comportement contextuel :
   - le bouton « haut » n'apparaît que si la page a été défilée vers le bas ;
   - le bouton « bas » n'apparaît que s'il reste du contenu en dessous ;
   - si la page n'est pas défilable, aucun bouton ne s'affiche.

   Routes exclues : la liseuse (/ler*) gère son propre défilement ; le
   catalogue (/ et /catalogo*) a déjà ses boutons de saut de tableau.
   ════════════════════════════════════════════════════════════════════════ */

// Seuil en pixels au-delà duquel on considère qu'il « reste » du contenu.
// Évite de clignoter quand on est à quelques pixels du bord.
const EDGE_THRESHOLD = 80;

export default function ScrollButtons() {
  const { pathname } = useLocation();
  const { formatMessage: t } = useIntl();

  const [canScrollUp, setCanScrollUp] = useState(false);
  const [canScrollDown, setCanScrollDown] = useState(false);

  // Routes exclues : liseuse et catalogue (qui a ses propres boutons).
  const isExcluded =
    pathname === '/' ||
    pathname.startsWith('/catalogo') ||
    pathname.startsWith('/ler');

  // Recalcule l'état des deux boutons en fonction de la position de défilement.
  const evaluate = useCallback(() => {
    const scrollY = window.scrollY || document.documentElement.scrollTop;
    const viewport = window.innerHeight;
    const total = document.documentElement.scrollHeight;
    setCanScrollUp(scrollY > EDGE_THRESHOLD);
    setCanScrollDown(scrollY + viewport < total - EDGE_THRESHOLD);
  }, []);

  useEffect(() => {
    if (isExcluded) return undefined;
    // Évaluation initiale (au montage et à chaque changement de route).
    evaluate();
    window.addEventListener('scroll', evaluate, { passive: true });
    window.addEventListener('resize', evaluate);
    return () => {
      window.removeEventListener('scroll', evaluate);
      window.removeEventListener('resize', evaluate);
    };
  }, [isExcluded, pathname, evaluate]);

  if (isExcluded) return null;
  // Rien à afficher si la page n'est pas défilable dans aucun sens.
  if (!canScrollUp && !canScrollDown) return null;

  const goTop = () =>
    window.scrollTo({ top: 0, behavior: 'smooth' });
  const goBottom = () =>
    window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'smooth' });

  return (
    <div className="ab-scroll-buttons" aria-hidden="false">
      {canScrollUp && (
        <button
          type="button"
          className="ab-scroll-button"
          onClick={goTop}
          title={t({ id: 'scroll.toTop' })}
          aria-label={t({ id: 'scroll.toTop' })}
        >
          ↑
        </button>
      )}
      {canScrollDown && (
        <button
          type="button"
          className="ab-scroll-button"
          onClick={goBottom}
          title={t({ id: 'scroll.toBottom' })}
          aria-label={t({ id: 'scroll.toBottom' })}
        >
          ↓
        </button>
      )}
    </div>
  );
}
