import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { applyScrollRestoreIfAny } from './i18n';
import './styles/fonts.css';
import './styles/theme-base.css';
import './styles/catalog.css';

// Restaure la position de scroll si on revient d'un changement de langue
// (consommé une seule fois grâce à sessionStorage).
applyScrollRestoreIfAny();

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>
);
