import { useMemo } from 'react';
import { useLibrary } from '@/contexts/LibraryContext';

/**
 * Hook usePanelAvailability (paquet E.1, paquet E.5 refactor 20/05/2026)
 *
 * Retourne la matrice de disponibilite des onglets du painel staff selon le
 * profil de la biblio courante.
 *
 * Pattern d'utilisation :
 *   const availability = usePanelAvailability();
 *   const tabs = TABS.filter(t => availability[t.key]);
 *
 * Doctrine de masquage paquet E (cf. spec-profils-bibliotheque-v0.7.md sec 9.5) :
 *
 * | Onglet         | Visible si                                              |
 * |----------------|---------------------------------------------------------|
 * | trabalho-do-dia| toujours (vue d'ensemble)                               |
 * | acoes          | toujours (actions admin)                                |
 * | reservas       | circulation_mode = 'full_sigb'                          |
 * | consultas      | circulation_mode IN ('informal', 'full_sigb')           |
 * | emprestimos    | circulation_mode IN ('informal', 'full_sigb')           |
 * | emprestimos-lt | circulation_mode = 'full_sigb' (lotes = mecanique SIGB) |
 * | leitor         | toujours (recherche lecteur)                            |
 * | historico      | toujours (couche D.4 masque deja si circulation = off)  |
 * | contribuicoes  | membership_enabled ET circulation_mode != 'off'         |
 *
 * Note paquet E.5 refactor (20/05/2026) :
 *   L'onglet 'transicoes' (vote sur transitions de profil) a ete deplace de
 *   PanelPage vers BibliotecaPage. C'est de la gouvernance politique, pas
 *   du travail operationnel quotidien. La condition governance_mode reste
 *   inchangee, mais elle est appliquee dans BibliotecaPage maintenant.
 */
export function usePanelAvailability() {
  const library = useLibrary();
  return useMemo(() => {
    const cm = library?.circulation_mode || 'full_sigb';
    const me = library?.membership_enabled === true;
    const allowsLoanFlow = cm === 'informal' || cm === 'full_sigb';
    const isFullSigb = cm === 'full_sigb';
    return {
      'trabalho-do-dia': true,
      'acoes': true,
      'reservas': isFullSigb,
      'consultas-locais': allowsLoanFlow,
      'emprestimos-livro': allowsLoanFlow,
      'emprestimos-lote': isFullSigb,
      'leitor': true,
      'historico': true,
      'contribuicoes': me && cm !== 'off',
    };
  }, [library?.circulation_mode, library?.membership_enabled]);
}
