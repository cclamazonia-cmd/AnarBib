// CHEMIN DÉPÔT : src/tests/provenance-candidate.test.js
//
// 13/10/2026 — le bouton « Chercher à la Bibliothèque Nationale (ISBN) » est
// retiré du panneau de recherche : il refaisait la requête que « Rechercher
// métadonnées » lance déjà avec un ISBN. Son seul apport propre était la note
// de provenance (« BN Brasil — lien »), désormais posée par applyCandidate pour
// toutes les sources via provenanceFromCandidate.

import { describe, it, expect } from 'vitest';
import { provenanceFromCandidate } from '@/lib/catalogacao/bookDraft';

describe('provenanceFromCandidate — d où vient la notice appliquée', () => {
  it('source avec lien de notice : « Libellé — lien »', () => {
    expect(provenanceFromCandidate({ source: 'dbnl', source_record_id: 'eede003vand04', source_url: 'https://www.dbnl.org/titels/titel.php?id=eede003vand04' }))
      .toBe('DBNL — https://www.dbnl.org/titels/titel.php?id=eede003vand04');
    expect(provenanceFromCandidate({ source: 'bn_brasil', source_record_id: '', source_url: 'https://acervo.bn.gov.br/sophia_web/acervo/detalhe/123' }))
      .toBe('BN Brasil — https://acervo.bn.gov.br/sophia_web/acervo/detalhe/123');
  });

  it('source SRU : l URL est la requête, on garde l identifiant de la notice', () => {
    expect(provenanceFromCandidate({ source: 'bnf', source_record_id: 'FRBNF35612345', source_url: 'https://catalogue.bnf.fr/api/SRU?operation=searchRetrieve&query=bib.isbn' }))
      .toBe('BnF FRBNF35612345');
    expect(provenanceFromCandidate({ source: 'iccu', source_record_id: 'IT\\ICCU\\X', source_url: 'https://opac.sbn.it/opacmobilegw/search.json?isbn=8432302120' }))
      .toBe('ICCU/SBN IT\\ICCU\\X');
  });

  it('sans source connue ni lien : le nom brut de la source, ou rien', () => {
    expect(provenanceFromCandidate({ source: 'autre', source_url: '' })).toBe('autre');
    expect(provenanceFromCandidate({})).toBe('');
    expect(provenanceFromCandidate(null)).toBe('');
  });
});
