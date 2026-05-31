import { useIntl } from 'react-intl';
import { Pill } from '@/components/ui';

/**
 * Composant BookAvailability (chantier #CL.1 + #CL.9, 31/05/2026)
 *
 * Affiche l'état de stock courant et prospectif d'un livre dans la biblio
 * par défaut de la lectrice. Conçu pour être inséré dans une ligne
 * d'historique (#CL.1), une carte wishlist (#CL.9), ou toute autre surface
 * où l'on veut signaler la dispo d'un titre.
 *
 * **Composant pur** : ne fait aucun appel réseau. Le parent (typiquement
 * AccountPage) appelle `useBookAvailability(bookIds)` une fois, et passe
 * la `availabilityMap.get(bookId)` correspondante en prop à chaque instance
 * de ce composant. Si la valeur est `undefined` (livre non trouvé ou pas
 * encore chargé), le composant rend `null` — pas d'état d'incertitude
 * affiché à la lectrice.
 *
 * **Variants** :
 *  - `inline` (défaut) : un Pill compact, adapté à une ligne d'historique
 *    dense (date + dispo sur la même ligne)
 *  - `compact` : Pill + date next_available_on en dessous si pertinent,
 *    adapté à une carte wishlist (un peu plus d'air)
 *
 * **Clés i18n nécessaires (à créer dans les 8 locales)** :
 *  - account.availability.no_acervo_da_sua_biblioteca
 *  - account.availability.indisponivel_no_momento
 *  - account.availability.consultavel_no_local
 *  - account.availability.indisponivel_para_voce
 *  - account.availability.sem_biblioteca_de_sessao
 *  - account.availability.nextOn (avec {date})
 *
 * **Doctrine** : la dispo est celle de la biblio courante de la lectrice,
 * pas celle de la biblio où le livre a été emprunté historiquement. Cf.
 * docs/decisions/DECISION_validation_par_appartenance_2026-05-30.md (α).
 */
export default function BookAvailability({ availability, variant = 'inline' }) {
  const { formatMessage: t, formatDate } = useIntl();

  if (!availability) return null;

  const {
    session_status_hint,
    session_available_count,
    session_exemplares_total,
    session_next_available_on,
  } = availability;

  // Sélection du variant Pill selon le statut.
  // Variants CSS effectivement disponibles dans le projet (src/components/ui/ui.css) :
  //   'ok'      → vert
  //   'warn'    → orange
  //   'bad'     → rouge
  //   'default' → neutre (pas de classe modificatrice)
  // Autres valeurs sont silencieusement traitées comme 'default'.
  const pillVariant = (() => {
    switch (session_status_hint) {
      case 'no_acervo_da_sua_biblioteca':
        return session_available_count > 0 ? 'ok' : 'warn';
      case 'indisponivel_no_momento':
        return 'warn';
      case 'consultavel_no_local':
        return 'default';   // modalité, pas état problématique
      case 'indisponivel_para_voce':
        return 'bad';       // livre inaccessible à la lectrice : signal fort
      case 'sem_biblioteca_de_sessao':
        return 'default';   // état d'attente/configuration, pas négatif
      default:
        return 'default';
    }
  })();

  // Libellé principal traduit depuis le hint backend.
  const label = t(
    { id: `account.availability.${session_status_hint}` },
    {
      available: session_available_count,
      total: session_exemplares_total,
    }
  );

  // Date prospective si présente et pertinente.
  // On ne l'affiche que pour 'indisponivel_no_momento' — pour les autres
  // statuts (consultation seule, sans biblio, etc.), elle n'a pas de sens.
  const showNextDate =
    session_status_hint === 'indisponivel_no_momento' &&
    session_next_available_on;

  if (variant === 'compact') {
    return (
      <div className="ab-book-availability ab-book-availability--compact">
        <Pill variant={pillVariant}>{label}</Pill>
        {showNextDate && (
          <small className="ab-book-availability__next">
            {t(
              { id: 'account.availability.nextOn' },
              { date: formatDate(session_next_available_on, { day: '2-digit', month: '2-digit', year: 'numeric' }) }
            )}
          </small>
        )}
      </div>
    );
  }

  // variant 'inline' (défaut)
  return (
    <span className="ab-book-availability ab-book-availability--inline">
      <Pill variant={pillVariant}>{label}</Pill>
      {showNextDate && (
        <span className="ab-book-availability__next">
          {' · '}
          {t(
            { id: 'account.availability.nextOn' },
            { date: formatDate(session_next_available_on, { day: '2-digit', month: '2-digit', year: 'numeric' }) }
          )}
        </span>
      )}
    </span>
  );
}
