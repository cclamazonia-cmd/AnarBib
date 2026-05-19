import { useMemo } from 'react';
import { useLibrary } from '@/contexts/LibraryContext';

/**
 * Hook usePanelAvailability (paquet E.1, 19/05/2026)
 *
 * Retourne la matrice de disponibilite des onglets du painel staff selon le
 * profil de la biblio courante (4 axes orthogonaux + membership_enabled).
 *
 * Pattern d'utilisation :
 *   const availability = usePanelAvailability();
 *   const tabs = TABS.filter(t => availability[t.key]);
 *
 * Doctrine de masquage paquet E (cf. spec-profils-bibliotheque-v0.6.md sec 9.5) :
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
 * Note paquet E (et non E.2 ou ulterieur) :
 *   - Onglets sensibles a governance_mode (vote transitions, etc.) pas
 *     encore presents dans PanelPage ; rajouter quand le frontend voting
 *     sera livre (cf backlog spec v0.6 section 11.5)
 *   - Onglets sensibles a network_mode (PEB interlibrary loan visible si
 *     federated) deja masques par le filtre archived_at au backend ;
 *     cote frontend, l'onglet PEB n'a pas encore d'entree dans TABS
 *     (livraison ulterieure cf backlog)
 */
export function usePanelAvailability() {
  const library = useLibrary();
  return useMemo(() => {
    // library est toujours defini (DEFAULT_CONTEXT en fallback), mais defensif :
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
