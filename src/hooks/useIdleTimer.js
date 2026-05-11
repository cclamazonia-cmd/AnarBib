// ============================================================================
// src/hooks/useIdleTimer.js
// ============================================================================
//
// Hook reutilisable pour detecter l'inactivite utilisateur et declencher
// une deconnexion automatique apres X minutes sans activite.
//
// Paquet 23a (2026-05-11) — backlog item #76 « Delogging automatique a la
// fermeture du navigateur » (volet A uniquement : idle timeout).
//
// Doctrine :
//   - Cible postes partages en bibliotheque militante (catalogage commun)
//   - Active uniquement pour le staff (librarian/coordenador/administrador)
//   - Apres `idleMinutes` minutes sans activite (mousedown, keydown, scroll),
//     declenche un modal d'avertissement de `warningSeconds` secondes
//   - Si l'utilisateur clique « Rester connecte·e » → timer reset
//   - Si l'utilisateur ne reagit pas → onTimeout() declenche (typiquement
//     signOut + redirect)
//   - Throttle des events d'activite a 1s pour ne pas saturer
//
// Usage :
//   const { showWarning, secondsRemaining, stayLoggedIn, forceLogout } =
//     useIdleTimer({
//       enabled: isStaff,
//       idleMinutes: 60,
//       warningSeconds: 60,
//       onTimeout: () => signOut().then(() => navigate('/login?reason=idle')),
//     });
//
// ============================================================================

import { useEffect, useRef, useState, useCallback } from 'react';

const ACTIVITY_EVENTS = ['mousedown', 'keydown', 'scroll', 'touchstart'];
const ACTIVITY_THROTTLE_MS = 1000;

export function useIdleTimer({
  enabled = false,
  idleMinutes = 60,
  warningSeconds = 60,
  onTimeout,
}) {
  const [showWarning, setShowWarning] = useState(false);
  const [secondsRemaining, setSecondsRemaining] = useState(warningSeconds);

  // Refs : pour pouvoir reset les timers depuis n'importe quel callback
  // sans creer de closures stale
  const idleTimerRef = useRef(null);
  const warningTimerRef = useRef(null);
  const countdownIntervalRef = useRef(null);
  const lastActivityRef = useRef(Date.now());
  const onTimeoutRef = useRef(onTimeout);

  // Garde onTimeout a jour dans le ref pour eviter les re-renders
  // qui re-creeraient tout l'effet a chaque render
  useEffect(() => {
    onTimeoutRef.current = onTimeout;
  }, [onTimeout]);

  // ── Nettoyage de tous les timers ──────────────────────────
  const clearAllTimers = useCallback(() => {
    if (idleTimerRef.current) {
      clearTimeout(idleTimerRef.current);
      idleTimerRef.current = null;
    }
    if (warningTimerRef.current) {
      clearTimeout(warningTimerRef.current);
      warningTimerRef.current = null;
    }
    if (countdownIntervalRef.current) {
      clearInterval(countdownIntervalRef.current);
      countdownIntervalRef.current = null;
    }
  }, []);

  // ── Demarrage du timer principal (avant warning) ──────────
  const startIdleTimer = useCallback(() => {
    clearAllTimers();
    setShowWarning(false);

    const idleMs = (idleMinutes * 60 - warningSeconds) * 1000;

    idleTimerRef.current = setTimeout(() => {
      // Phase 1 → phase 2 : on affiche le warning et on demarre
      // le compte a rebours visible
      setShowWarning(true);
      setSecondsRemaining(warningSeconds);

      // Decompte visible chaque seconde
      countdownIntervalRef.current = setInterval(() => {
        setSecondsRemaining((s) => Math.max(0, s - 1));
      }, 1000);

      // Timer final : signOut effectif a la fin
      warningTimerRef.current = setTimeout(() => {
        clearAllTimers();
        setShowWarning(false);
        if (onTimeoutRef.current) {
          onTimeoutRef.current();
        }
      }, warningSeconds * 1000);
    }, idleMs);
  }, [idleMinutes, warningSeconds, clearAllTimers]);

  // ── Activite detectee : reset du timer ────────────────────
  const handleActivity = useCallback(() => {
    const now = Date.now();
    // Throttle : on ne reset pas plus d'une fois par seconde
    if (now - lastActivityRef.current < ACTIVITY_THROTTLE_MS) return;
    lastActivityRef.current = now;

    // Si on est en phase warning, l'activite NE reset PAS — l'utilisateur
    // doit cliquer explicitement sur « Rester connecte·e ». C'est important
    // pour eviter qu'un mouvement involontaire (clic sur fermeture d'onglet
    // qui passe par l'overlay, par exemple) reset le timer alors que la
    // personne est partie.
    if (showWarning) return;

    startIdleTimer();
  }, [showWarning, startIdleTimer]);

  // ── Bouton « Rester connecte·e » ──────────────────────────
  const stayLoggedIn = useCallback(() => {
    lastActivityRef.current = Date.now();
    startIdleTimer();
  }, [startIdleTimer]);

  // ── Bouton « Se deconnecter maintenant » ──────────────────
  const forceLogout = useCallback(() => {
    clearAllTimers();
    setShowWarning(false);
    if (onTimeoutRef.current) {
      onTimeoutRef.current();
    }
  }, [clearAllTimers]);

  // ── Mise en place / nettoyage des listeners + timer ───────
  useEffect(() => {
    if (!enabled) {
      clearAllTimers();
      setShowWarning(false);
      return;
    }

    // Demarrer le timer
    startIdleTimer();

    // Brancher les listeners d'activite
    ACTIVITY_EVENTS.forEach((event) => {
      window.addEventListener(event, handleActivity, { passive: true });
    });

    return () => {
      clearAllTimers();
      ACTIVITY_EVENTS.forEach((event) => {
        window.removeEventListener(event, handleActivity);
      });
    };
  }, [enabled, handleActivity, startIdleTimer, clearAllTimers]);

  return {
    showWarning,
    secondsRemaining,
    stayLoggedIn,
    forceLogout,
  };
}

export default useIdleTimer;
