// ============================================================================
// src/components/ui/Modal.jsx
// ============================================================================
//
// Composant <Modal /> générique réutilisable. Léger, sans dépendance externe.
//
// Features :
//   - Overlay sombre qui ferme la modale au clic
//   - Touche ESC pour fermer
//   - Focus trap léger (le bouton "Annuler" reçoit le focus à l'ouverture)
//   - Empêche le scroll du body pendant l'affichage
//   - Cohérent avec la grammaire visuelle AnarBib (.ab-modal-*)
//   - Accessible (role=dialog, aria-modal, label optionnel)
//
// Usage :
//   <Modal isOpen={open} onClose={() => setOpen(false)} title="Mon titre">
//     <p>Contenu</p>
//     <div className="ab-modal__actions">
//       <button onClick={() => setOpen(false)}>Annuler</button>
//       <button onClick={handleConfirm}>Confirmer</button>
//     </div>
//   </Modal>
//
// ============================================================================

import { useEffect, useRef } from 'react';
import './Modal.css';
import { createPortal } from 'react-dom';
import { lockBodyScroll, unlockBodyScroll } from '@/lib/bodyScrollLock';

export default function Modal({
  isOpen,
  onClose,
  title,
  children,
  size = 'medium', // 'small' | 'medium' | 'large'
  closeOnOverlayClick = true,
}) {
  const dialogRef = useRef(null);
  const cancelButtonRef = useRef(null);

  // ── Touche ESC pour fermer + lock du scroll body ─────
  useEffect(() => {
    if (!isOpen) return;

    const handleKey = (e) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onClose();
      }
    };

    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [isOpen, onClose]);

  // ── Blocage du défilement de page ────────────────────
  // Effet SÉPARÉ, et dépendant du seul `isOpen` : `onClose` est presque
  // toujours une lambda inline chez les appelants, donc d'identité nouvelle à
  // chaque rendu — le verrou serait relâché puis reposé en boucle.
  // Le compteur partagé (lib/bodyScrollLock) gère le chevauchement de
  // plusieurs modales, cas où la sauvegarde/restauration locale laissait le
  // body bloqué pour de bon.
  useEffect(() => {
    if (!isOpen) return;
    lockBodyScroll();
    return unlockBodyScroll;
  }, [isOpen]);

  // ── Focus initial sur la modale ─────────────────────
  useEffect(() => {
    if (isOpen && dialogRef.current) {
      // Focus sur le premier élément focusable (souvent le bouton Annuler)
      const focusable = dialogRef.current.querySelector(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      );
      if (focusable) focusable.focus();
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleOverlayClick = (e) => {
    if (closeOnOverlayClick && e.target === e.currentTarget) {
      onClose();
    }
  };

  // Rendu dans un PORTAIL vers <body>, et non a l'emplacement de l'appelant.
  //
  // Pourquoi : une modale rendue en place herite du sort de ses ancetres. Sur
  // la page de catalogage, les 11 panneaux d'onglets restent MONTES en
  // permanence et ne sont masques que par du CSS (.cat-panel { display:none }).
  // Une modale ouverte dans un panneau inactif etait donc INVISIBLE et
  // impossible a fermer — tout en gardant le verrou de defilement du body :
  // plus d'ascenseur sur toute la page, sans rien a l'ecran (19/08/2026).
  // Meme famille de pieges avec un ancetre en overflow:hidden ou creant un
  // contexte d'empilement, qui rognait ou masquait la modale.
  //
  // Avec le portail, une modale ouverte est TOUJOURS visible et fermable. Sans
  // risque de regression visuelle : le voile est deja en position:fixed
  // (Modal.css) et les variables de theme sont posees sur :root par
  // lib/theme.js — donc parfaitement heritees depuis <body>.
  //
  // NB React : le portail ne deplace que le DOM. La propagation des evenements
  // et le contexte React continuent de suivre l'arbre des composants, donc les
  // gestionnaires et les contextes des appelants fonctionnent inchanges.
  const overlay = (
    <div
      className="ab-modal-overlay"
      onClick={handleOverlayClick}
      role="presentation"
    >
      <div
        ref={dialogRef}
        className={`ab-modal ab-modal--${size}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? 'ab-modal-title' : undefined}
      >
        {title && (
          <header className="ab-modal__header">
            <h2 id="ab-modal-title" className="ab-modal__title">{title}</h2>
            <button
              type="button"
              className="ab-modal__close"
              onClick={onClose}
              aria-label="Fermer"
            >
              ×
            </button>
          </header>
        )}
        <div className="ab-modal__body">
          {children}
        </div>
      </div>
    </div>
  );

  return typeof document === 'undefined' ? overlay : createPortal(overlay, document.body);
}
