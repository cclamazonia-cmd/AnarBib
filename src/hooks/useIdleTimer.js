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
// PATCH v2 (2026-05-11) : fix bug de cascade. La v1 avait des callbacks dans
// les dependances du useEffect, ce qui faisait que chaque changement de state
// (notamment showWarning passant a true) rejouait le useEffect, qui appelait
// startIdleTimer qui faisait setShowWarning(false) → la modal se fermait
// immediatement. Resolution : tout passer par des refs, useEffect avec
// uniquement [enabled] en dependance.
//
// Doctrine :
//   - Cible postes partages en bibliotheque militante (catalogage commun)
//   - Active uniquement pour le staff (librarian/coordenador/administrador)
//   - Apres `idleMinutes` minutes sans activite (mousedown, keydown, scroll),
//     declenche un modal d'avertissement de `warningSeconds` secondes
//   - Si l'utilisateur clique « Rester connecte·e » → timer reset
//   - Si l'utilisateur ne reagit pas → onTimeout() declenche
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

  // ── Refs pour tout (config + timers + state miroir) ──────
  // L'idee : tout passer par des refs pour que le useEffect principal
  // n'ait QUE [enabled] comme dependance, et ne se rejoue donc pas a
  // chaque changement de state interne.
  const idleTimerRef = useRef(null);
  const warningTimerRef = useRef(null);
  const countdownIntervalRef = useRef(null);
  const lastActivityRef = useRef(Date.now());
  const onTimeoutRef = useRef(onTimeout);
  const showWarningRef = useRef(false);
  const idleMinutesRef = useRef(idleMinutes);
  const warningSecondsRef = useRef(warningSeconds);

  // Sync refs avec les props (sans rejouer le useEffect principal)
  useEffect(() => { onTimeoutRef.current = onTimeout; }, [onTimeout]);
  useEffect(() => { idleMinutesRef.current = idleMinutes; }, [idleMinutes]);
  useEffect(() => { warningSecondsRef.current = warningSeconds; }, [warningSeconds]);

  // Setter wrapped qui maintient showWarningRef en sync
  const setShowWarningSafe = useCallback((value) => {
    showWarningRef.current = value;
    setShowWarning(value);
  }, []);

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
    setShowWarningSafe(false);

    const idleMinutesNow = idleMinutesRef.current;
    const warningSecondsNow = warningSecondsRef.current;
    const idleMs = (idleMinutesNow * 60 - warningSecondsNow) * 1000;

    idleTimerRef.current = setTimeout(() => {
      // Phase 1 → phase 2 : on affiche le warning et on demarre
      // le compte a rebours visible
      setShowWarningSafe(true);
      setSecondsRemaining(warningSecondsNow);

      // Decompte visible chaque seconde
      countdownIntervalRef.current = setInterval(() => {
        setSecondsRemaining((s) => Math.max(0, s - 1));
      }, 1000);

      // Timer final : signOut effectif a la fin
      warningTimerRef.current = setTimeout(() => {
        clearAllTimers();
        setShowWarningSafe(false);
        if (onTimeoutRef.current) {
          onTimeoutRef.current();
        }
      }, warningSecondsNow * 1000);
    }, idleMs);
  }, [clearAllTimers, setShowWarningSafe]);

  // ── Activite detectee : reset du timer ────────────────────
  const handleActivity = useCallback(() => {
    const now = Date.now();
    if (now - lastActivityRef.current < ACTIVITY_THROTTLE_MS) return;
    lastActivityRef.current = now;

    // Lit l'etat via le ref (pas via le closure) pour avoir la valeur courante
    if (showWarningRef.current) return;

    startIdleTimer();
  }, [startIdleTimer]);

  // ── Bouton « Rester connecte·e » ──────────────────────────
  const stayLoggedIn = useCallback(() => {
    lastActivityRef.current = Date.now();
    startIdleTimer();
  }, [startIdleTimer]);

  // ── Bouton « Se deconnecter maintenant » ──────────────────
  const forceLogout = useCallback(() => {
    clearAllTimers();
    setShowWarningSafe(false);
    if (onTimeoutRef.current) {
      onTimeoutRef.current();
    }
  }, [clearAllTimers, setShowWarningSafe]);

  // ── Mise en place / nettoyage des listeners + timer ───────
  // CRUCIAL : seul `enabled` est en dependance. NE PAS rajouter handleActivity,
  // startIdleTimer ou clearAllTimers ici — ils sont stables via leurs refs.
  // C'est la cle du fix v2 : ne pas rejouer le useEffect a chaque render.
  useEffect(() => {
    if (!enabled) {
      clearAllTimers();
      setShowWarningSafe(false);
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled]);

  return {
    showWarning,
    secondsRemaining,
    stayLoggedIn,
    forceLogout,
  };
}

export default useIdleTimer;
