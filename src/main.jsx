import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { applyScrollRestoreIfAny } from './i18n';
import { reloadOnceForStaleChunk } from './lib/chunkReload';
import './styles/fonts.css';
import './styles/theme-base.css';
import './styles/breakpoints.css';
import './styles/catalog.css';
// Filet anti-débordement mobile — chargé en dernier pour passer devant les CSS
// de composants (cf. en-tête de mobile.css).
import './styles/mobile.css';

// Chunk lazy introuvable (onglet ouvert avant un déploiement → ancien hash en
// 404) : Vite émet 'vite:preloadError'. On recharge une fois pour récupérer le
// index.html à jour, AVANT que l'échec ne remonte en erreur React. C'est le
// correctif principal du « clic mort sur les liens du header » ; l'ErrorBoundary
// (App.jsx) reste le filet pour les cas résiduels. On ne preventDefault PAS :
// si la garde anti-boucle bloque le reload, Vite relaie l'erreur jusqu'au
// boundary, qui affiche un écran « Recarregar » au lieu de figer.
window.addEventListener('vite:preloadError', () => {
  reloadOnceForStaleChunk();
});

// Restaure la position de scroll si on revient d'un changement de langue
// (consommé une seule fois grâce à sessionStorage).
applyScrollRestoreIfAny();

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>
);

// Service worker (socle PWA — MOBILE Paquet 0). Enregistré UNIQUEMENT en prod :
// en dev il interférerait avec le HMR Vite et cacherait des assets de dev.
// Le SW ne cache que le shell same-origin ; il n'intercepte jamais l'API/Storage
// Supabase ni l'auth (stratégie documentée en en-tête de public/sw.js).
if (import.meta.env.PROD && 'serviceWorker' in navigator) {
  // Quand un nouveau SW prend le contrôle (déploiement → skipWaiting +
  // clients.claim), on recharge UNE fois pour servir le build à jour, au lieu
  // de laisser tourner l'ancien code avec des chunks périmés. Gardes :
  //  - seulement si la page était déjà contrôlée (hadController) → pas de reload
  //    parasite à la toute première visite ;
  //  - 'refreshing' empêche toute boucle de rechargement.
  const hadController = !!navigator.serviceWorker.controller;
  let refreshing = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (refreshing || !hadController) return;
    refreshing = true;
    window.location.reload();
  });
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').then((reg) => {
      // Vérifie une mise à jour du SW à chaque chargement (sinon le navigateur
      // ne re-fetch sw.js qu'à la navigation ou ~24 h).
      reg.update?.();
    }).catch((err) => {
      console.warn('[PWA] enregistrement du service worker échoué :', err);
    });
  });
}
