import { useMemo } from 'react';
import { useLibrary } from '@/contexts/LibraryContext';

/**
 * Hook useAccountAvailability (paquet E.4, 20/05/2026)
 *
 * Retourne la matrice de disponibilite des sections du AccountPage (cote
 * lecteur·rice) selon le profil de la biblio courante.
 *
 * Doctrine ancrage : un·e lecteur·rice = une seule biblio (cf. session 20/05).
 * Pas de multi-biblio. La biblio courante est celle du contexte (libraryId).
 *
 * Pattern d'utilisation :
 *   const availability = useAccountAvailability();
 *   if (availability.reservations) { ... }
 *
 * Doctrine de masquage (cf. spec-profils-bibliotheque-v0.6.md sec 9.5) :
 *
 * | Section / Onglet | Visible si                                              |
 * |------------------|---------------------------------------------------------|
 * | perfil           | toujours (compte personnel)                             |
 * | reservar         | circulation_mode = 'full_sigb' (reservations = SIGB)    |
 * | curso (emp.)     | circulation_mode IN ('informal', 'full_sigb')           |
 * | historico        | circulation_mode != 'off' (pas d'historique sur off)    |
 * | consultas        | circulation_mode IN ('informal', 'full_sigb')           |
 * | avisos           | toujours                                                |
 * | desejos          | toujours (wishlist marche sans circulation)             |
 * | cotisacoes       | membership_enabled ET circulation_mode != 'off'         |
 *
 * Note : les chips dans le Hero (reservas, consultas, emprestimos) sont
 * filtrees par la meme matrice cote rendu.
 */
export function useAccountAvailability() {
  const library = useLibrary();
  return useMemo(() => {
    const cm = library?.circulation_mode || 'full_sigb';
    const me = library?.membership_enabled === true;
    const rc = library?.reader_cards_enabled === true;
    const allowsLoanFlow = cm === 'informal' || cm === 'full_sigb';
    const isFullSigb = cm === 'full_sigb';
    return {
      // Onglets AccountPage
      'perfil': true,
      'reservar': isFullSigb,
      'curso': allowsLoanFlow,
      'historico': cm !== 'off',
      'avisos': true,
      'desejos': true,
      // Chips Hero
      'chip_reservas': isFullSigb,
      'chip_consultas': allowsLoanFlow,
      'chip_emprestimos': allowsLoanFlow,
      // Sections internes
      'cotisacoes': me && cm !== 'off',
      // Carte-lecteur (chantier mobile, 28/05/2026) : visible si la biblio
      // d'attache a active la capacite. Independant de circulation_mode.
      'reader_card': rc,
    };
  }, [library?.circulation_mode, library?.membership_enabled, library?.reader_cards_enabled]);
}
