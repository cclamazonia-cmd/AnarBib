// ═══════════════════════════════════════════════════════════════════════════
// ficedlMatch — les cinq relations d'un alignement sur le thésaurus FICEDL.
//
// Domaine de subject_ficedl_links.match_type (migration 20260907172508), ouvert
// à l'application le 25/09/2026 (H9). La relation est déclarée DEPUIS le sujet
// AnarBib VERS le descripteur FICEDL : `broad` = le descripteur est plus large.
// Le rendu SKOS est dans skosExport.js (SKOS_MATCH) ; ici, l'ordre et les clés
// de libellé, partagés par la page-sujet et l'éditeur de la coordination.
// Une valeur hors de cette table n'a pas de libellé : on n'affiche rien plutôt
// que « exact » par défaut.
// ═══════════════════════════════════════════════════════════════════════════

export const MATCH_TYPES = ['exact', 'close', 'broad', 'narrow', 'related'];

export const MATCH_LABEL_KEY = {
  exact: 'subject.matchExact',
  close: 'subject.matchClose',
  broad: 'subject.matchBroad',
  narrow: 'subject.matchNarrow',
  related: 'subject.matchRelated',
};
