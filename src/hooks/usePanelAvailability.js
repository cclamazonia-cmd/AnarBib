import { useMemo } from 'react';
import { useLibrary } from '@/contexts/LibraryContext';

/**
 * Hook usePanelAvailability (paquet E.1, mis a jour paquet E.5.1, 20/05/2026)
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
 * | transicoes     | governance_mode IN ('staff_roles', 'full_governance')   |
 * | contribuicoes  | membership_enabled ET circulation_mode != 'off'         |
 *
 * Paquet E.5.1 (20/05/2026) : ajout de 'transicoes' (vote sur transitions de
 * profil). Masque pour governance_mode='informal' qui n'a pas de gouvernance
 * formelle structuree.
 */
export function usePanelAvailability() {
  const library = useLibrary();
  return useMemo(() => {
    const cm = library?.circulation_mode || 'full_sigb';
    const gm = library?.governance_mode || 'full_governance';
    const me = library?.membership_enabled === true;
    const allowsLoanFlow = cm === 'informal' || cm === 'full_sigb';
    const isFullSigb = cm === 'full_sigb';
    const hasStructuredGovernance = gm === 'staff_roles' || gm === 'full_governance';
    return {
      'trabalho-do-dia': true,
      'acoes': true,
      'reservas': isFullSigb,
      'consultas-locais': allowsLoanFlow,
      'emprestimos-livro': allowsLoanFlow,
      'emprestimos-lote': isFullSigb,
      'leitor': true,
      'historico': true,
      'transicoes': hasStructuredGovernance,
      'contribuicoes': me && cm !== 'off',
    };
  }, [library?.circulation_mode, library?.governance_mode, library?.membership_enabled]);
}
