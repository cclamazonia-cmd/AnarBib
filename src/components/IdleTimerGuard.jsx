// ============================================================================
// src/components/IdleTimerGuard.jsx
// ============================================================================
//
// Composant transparent qui active la protection « idle timeout » pour les
// utilisateur·rices staff (librarian/coordenador/administrador), et rend
// la modal d'avertissement quand le timer atteint sa phase de warning.
//
// Paquet 23a (2026-05-11) — backlog item #76, volet A.
//
// Doctrine :
//   - Composant placé à l'intérieur de <AuthProvider><LibraryProvider>,
//     ce qui lui permet de consommer les 2 contextes
//   - Si l'utilisateur·rice n'est pas staff (ou n'est pas connecté·e),
//     le composant rend juste {children} sans rien faire
//   - Si staff : active useIdleTimer avec 60 min / 60 sec warning,
//     rend les children + la modal en superposition
//   - Au timeout effectif : signOut + navigate('/login?reason=idle')
//
// Architecture : ce composant ne touche pas à AuthContext ni LibraryContext.
// Toute la logique idle est isolée ici, pour ne pas alourdir les contextes
// centraux et pour faciliter un retrait/désactivation future.
//
// ============================================================================

import { useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useIdleTimer } from '@/hooks/useIdleTimer';
import IdleWarningModal from '@/components/IdleWarningModal';

const IDLE_MINUTES = 60;
const WARNING_SECONDS = 60;

export default function IdleTimerGuard({ children }) {
  const { user, signOut } = useAuth();
  const { role } = useLibrary();
  const navigate = useNavigate();

  // Le idle timer ne s'active QUE pour les utilisateur·rices staff connecté·es.
  // Anonymes et lecteurs : aucune protection idle (leur usage ne le justifie pas).
  console.log('[IdleTimerGuard] render: user=', user?.id || 'anon', 'role=', role);
  const isStaff =
    !!user &&
    (role === 'librarian' || role === 'coordenador' || role === 'administrador');

  const handleTimeout = useCallback(async () => {
    try {
      await signOut();
    } catch (err) {
      console.warn('[IdleTimerGuard] signOut failed:', err);
    }
    // Toujours rediriger vers /login avec reason=idle, même si signOut a planté
    // (de toute façon la session est dans un état incohérent à ce stade)
    navigate('/login?reason=idle', { replace: true });
  }, [signOut, navigate]);

  const { showWarning, secondsRemaining, stayLoggedIn, forceLogout } =
    useIdleTimer({
      enabled: isStaff,
      idleMinutes: IDLE_MINUTES,
      warningSeconds: WARNING_SECONDS,
      onTimeout: handleTimeout,
    });

  return (
    <>
      {children}
      {isStaff && (
        <IdleWarningModal
          isOpen={showWarning}
          secondsRemaining={secondsRemaining}
          onStay={stayLoggedIn}
          onLogout={forceLogout}
        />
      )}
    </>
  );
}
