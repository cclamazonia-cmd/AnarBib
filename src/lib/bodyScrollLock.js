// ============================================================================
// src/lib/bodyScrollLock.js
// ============================================================================
//
// Verrou de défilement du <body>, à COMPTEUR.
//
// Pourquoi un compteur plutôt qu'une simple sauvegarde/restauration locale :
// plusieurs verrous peuvent se CHEVAUCHER (deux modales sur la même page, ou
// une modale pendant la visite guidée du panel). Le motif naïf
//
//     const prev = document.body.style.overflow;
//     document.body.style.overflow = 'hidden';
//     return () => { document.body.style.overflow = prev; };
//
// corrompt la valeur sauvegardée dès que deux verrous se recouvrent : le
// second capture 'hidden' — posé par le premier — comme étant l'état
// « d'origine », puis le restaure en se fermant. Le body reste alors bloqué :
// ascenseur du navigateur disparu, défilement vertical impossible, sans
// qu'aucune modale ne soit visible. Constaté le 19/08/2026 sur la page de
// catalogage, qui porte deux modales (avertissement de doublon, et choix
// œuvre / nouvelle édition).
//
// Ici, seul le PREMIER verrou mémorise l'état réel, et seul le DERNIER le
// restaure : l'ordre de fermeture n'a plus d'importance.
//
// À utiliser partout plutôt que de manipuler document.body.style.overflow
// directement.
// ============================================================================

let locks = 0;
let savedOverflow = '';

/** Pose un verrou. Idempotent par appelant : à appairer avec unlockBodyScroll. */
export function lockBodyScroll() {
  if (typeof document === 'undefined') return;
  if (locks === 0) {
    savedOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
  }
  locks += 1;
}

/** Retire un verrou. Ne restaure qu'une fois le dernier verrou levé. */
export function unlockBodyScroll() {
  if (typeof document === 'undefined') return;
  if (locks === 0) return;
  locks -= 1;
  if (locks === 0) {
    document.body.style.overflow = savedOverflow;
  }
}
