import { useIntl } from 'react-intl';
import { Pill } from '@/components/ui';

// =============================================================================
// NegotiationStateBadge
// =============================================================================
// Affiche un badge représentant l'état de négociation symétrique d'un créneau
// de retrait (workflow réservation v2 phase 5). Réutilisable côté staff
// (PanelPage) et côté lecteur·rice (AccountPage paquet 4).
//
// Props :
//   - proposedBy     : 'biblio' | 'leitor' | null
//   - iterationCount : entier 0..3 (compteur de contre-propositions lecteur)
//   - stage          : workflow_stage_effective (texte)
//   - viewerRole     : 'staff' | 'reader'
//
// Sortie :
//   - null si stage hors {retirada_agendada, re-retirada_agendada}
//     OU si proposedBy = NULL (la négociation est close, pas de badge utile)
//   - <Pill> avec libellé et variant adaptés au rôle de qui regarde :
//       * staff voit "Esperando leitor(a/e)" quand biblio a proposé
//       * staff voit "Contra-proposta" (en orange) quand leitor a proposé
//       * leitor voit "Resposta esperada" (en orange) quand biblio a proposé
//       * leitor voit "Esperando biblioteca" quand leitor a proposé
//
// Le compteur d'itérations s'affiche en suffixe "n/3" dès qu'il est > 0.
// =============================================================================

const NEGOTIATION_STAGES = ['retirada_agendada', 're-retirada_agendada'];
const MAX_ITERATIONS = 3;

export default function NegotiationStateBadge({ proposedBy, iterationCount = 0, stage, viewerRole = 'staff' }) {
  const { formatMessage: t } = useIntl();

  // Hors stages de négociation OU négociation close → pas de badge
  if (!NEGOTIATION_STAGES.includes(stage)) return null;
  if (!proposedBy) return null;

  // Détermination du libellé et de la variante visuelle selon qui regarde
  // et qui a proposé en dernier.
  let labelKey;
  let variant;

  if (viewerRole === 'staff') {
    if (proposedBy === 'biblio') {
      // Notre biblio a proposé, elle attend la réponse du lecteur·rice
      labelKey = 'panel.reservations.negotiation.waitingReader';
      variant = 'default';
    } else {
      // Le lecteur·rice a contre-proposé, action requise du staff
      labelKey = 'panel.reservations.negotiation.counterProposed';
      variant = 'warn';
    }
  } else {
    // viewerRole === 'reader'
    if (proposedBy === 'biblio') {
      // La biblio a proposé, c'est au lecteur·rice de répondre
      labelKey = 'reservation.negotiation.responseExpected';
      variant = 'warn';
    } else {
      // Le lecteur·rice a contre-proposé, attend la biblio
      labelKey = 'reservation.negotiation.waitingLibrary';
      variant = 'default';
    }
  }

  const label = t({ id: labelKey });
  const counterSuffix = iterationCount > 0
    ? ' · ' + t({ id: 'panel.reservations.negotiation.iterationBadge' }, { count: iterationCount, max: MAX_ITERATIONS })
    : '';

  return (
    <Pill variant={variant}>
      {label}{counterSuffix}
    </Pill>
  );
}
