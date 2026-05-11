// ============================================================================
// src/components/IdleWarningModal.jsx
// ============================================================================
//
// Modal d'avertissement affichee avant la deconnexion automatique pour
// inactivite. Affiche un compte a rebours et deux boutons :
//   - « Rester connecte·e » : reset le timer (l'utilisateur reste connecte·e)
//   - « Se deconnecter maintenant » : force la deconnexion immediate
//
// Paquet 23a (2026-05-11) — backlog item #76, volet A (idle timeout).
//
// Couple avec le hook useIdleTimer qui gere toute la logique de timing :
//
//   const { showWarning, secondsRemaining, stayLoggedIn, forceLogout } =
//     useIdleTimer({...});
//
//   <IdleWarningModal
//     isOpen={showWarning}
//     secondsRemaining={secondsRemaining}
//     onStay={stayLoggedIn}
//     onLogout={forceLogout}
//   />
//
// Important : le Modal ne se ferme PAS via overlay click ni ESC, parce qu'un
// utilisateur qui n'est plus la ne doit pas pouvoir « fermer accidentellement »
// l'avertissement. La seule sortie c'est cliquer un des deux boutons.
//
// ============================================================================

import { useIntl } from 'react-intl';
import Modal from '@/components/ui/Modal';
import { Button } from '@/components/ui';

export default function IdleWarningModal({
  isOpen,
  secondsRemaining,
  onStay,
  onLogout,
}) {
  const { formatMessage: t } = useIntl();

  // onClose = no-op : impossible de fermer la modale sans choisir une option.
  // C'est volontaire : on veut que la personne qui revient au poste prenne
  // une decision explicite.
  const noop = () => {};

  return (
    <Modal
      isOpen={isOpen}
      onClose={noop}
      title={t({ id: 'idle.warning.title' })}
      size="small"
      closeOnOverlayClick={false}
    >
      <p style={{ marginTop: 0 }}>
        {t(
          { id: 'idle.warning.message' },
          { seconds: secondsRemaining }
        )}
      </p>

      <div
        className="ab-modal__actions"
        style={{
          display: 'flex',
          gap: 12,
          justifyContent: 'flex-end',
          marginTop: 24,
        }}
      >
        <Button variant="secondary" onClick={onLogout}>
          {t({ id: 'idle.warning.logout' })}
        </Button>
        <Button onClick={onStay} autoFocus>
          {t({ id: 'idle.warning.stay' })}
        </Button>
      </div>
    </Modal>
  );
}
