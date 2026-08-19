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

  return (
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
}
