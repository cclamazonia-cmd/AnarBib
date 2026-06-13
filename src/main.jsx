import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { applyScrollRestoreIfAny } from './i18n';
import { reloadOnceForStaleChunk } from './lib/chunkReload';
import './styles/fonts.css';
import './styles/theme-base.css';
import './styles/catalog.css';

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
