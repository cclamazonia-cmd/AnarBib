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

   Route exclue : la liseuse (/ler*) gère son propre défilement.
   Le catalogue N'EST PAS exclu : ses flèches ↑/↓ d'en-tête de tableau ne
   défilent que le conteneur du tableau (scrollTable), pas la page — or la
   zone de facettes au-dessus est longue. L'exclure privait la page de tout
   moyen de remonter/descendre (constaté le 31/08/2026, desktop et mobile).
   ════════════════════════════════════════════════════════════════════════ */

// Seuil en pixels au-delà duquel on considère qu'il « reste » du contenu.
// Évite de clignoter quand on est à quelques pixels du bord.
const EDGE_THRESHOLD = 80;

export default function ScrollButtons() {
  const { pathname } = useLocation();
  const { formatMessage: t } = useIntl();

  const [canScrollUp, setCanScrollUp] = useState(false);
  const [canScrollDown, setCanScrollDown] = useState(false);

  // Route exclue : la liseuse seulement (cf. en-tête).
  const isExcluded = pathname.startsWith('/ler');

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
    // Le contenu arrive souvent APRÈS le montage (catalogue : facettes puis
    // tableau chargés en async). Sans observer, la page devient défilable
    // sans qu'aucun événement scroll/resize ne relance evaluate(), et le
    // bouton « bas » n'apparaît jamais tant qu'on n'a pas déjà défilé.
    const ro = new ResizeObserver(evaluate);
    ro.observe(document.body);
    return () => {
      window.removeEventListener('scroll', evaluate);
      window.removeEventListener('resize', evaluate);
      ro.disconnect();
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
