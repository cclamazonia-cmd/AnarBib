// =====================================================================
// NUMDIF D14 (15/10/2026, REGISTRE §47 NUMDIF-1, NUMDIF-2) — l'outil de
// recherche propose, il ne décide pas ; mais ce qu'il propose doit tenir.
// Session : File de candidats PDF.
//
// La recette réelle (Archive.org, 15/10) : notices 86 et 96 (Reclus, Harper
// 1873 et 1872) classées « même édition », fichiers identiques au SHA-256 près
// aux ressources 77 et 78 ; le scan Harper 1874 de la 86, « autre édition ».
// Ici, les mêmes situations sur des pages de titre écrites à la main, pour
// que la règle ne dérive pas sans bruit.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { proposer, nettoyerPage, classerResultats, pertinentSansAuteur, annees } from '../../scripts/numdif_recherche_pdf.mjs';

const HARPER_1873 = {
  id: 86, titulo: 'The Ocean, Atmosphere, and Life', autor: 'RECLUS, Élisée',
  editora: 'Harper & Brothers Publishers', local_publicacao: 'New York', ano: '1873', isbn: null, tradutor: null,
};
const pageTitre = (annee) => `THE OCEAN,
ATMOSPHERE, AND LIFE.
BEING THE SECOND SERIES OF A
DESCRIPTIVE HISTORY OF THE LIFE OF THE GLOBE.
By ELISEE RECLUS,
NEW YORK:
HARPER & BROTHERS, PUBLISHERS,
FRANKLIN SQUARE.
${annee}.`;
const remplissage = 'Chapter I. General considerations on the seas and their basins. '.repeat(8);
const RECLUS = [{ name: 'Élisée Reclus', death_year: 1905 }];

describe('NUMDIF-1 — le verdict se lit sur la page de titre', () => {
  it('Harper, New York, 1873 : même édition ; domaine public proposé (Reclus †1905)', () => {
    const r = proposer(HARPER_1873, ['', pageTitre(1873), remplissage], { auteurs: RECLUS });
    expect(r.proposed_verdict).toBe('meme_edition');
    expect(r.title_page_number).toBe(2);
    expect(r.found.found_year).toBe('1873');
    expect(r.proposed_case).toBe('domaine_public');
    expect(r.title_page_text).toContain('FRANKLIN SQUARE');
  });

  it('le même titre chez le même éditeur, mais 1874 : autre édition, avec l’année trouvée', () => {
    const r = proposer(HARPER_1873, ['', pageTitre(1874), remplissage], { auteurs: RECLUS });
    expect(r.proposed_verdict).toBe('autre_edition');
    expect(r.found.found_year).toBe('1874');
    expect(r.found.found_publisher).toBe('Harper & Brothers Publishers');
  });

  it('un « 1873 » cité dans une préface ne fait pas l’édition', () => {
    const preface = `PREFACE.\n${remplissage}\nThe first French edition appeared in 1873, and was much praised.`;
    const r = proposer(HARPER_1873, [pageTitre(1874), preface, preface], { auteurs: RECLUS });
    expect(r.proposed_verdict).toBe('autre_edition');
  });

  it('la page d’avertissement de Google Books est retirée avant lecture', () => {
    const google = 'This is a digital copy of a book that was preserved for generations on library shelves before it was carefully scanned by Google as part of a project to make the world\'s books discoverable online.';
    expect(nettoyerPage(google)).toBe('');
    expect(nettoyerPage('Digitized by Google\nNEW YORK')).toBe('NEW YORK');
    const r = proposer(HARPER_1873, [google, pageTitre(1873), remplissage], { auteurs: RECLUS });
    expect(r.proposed_verdict).toBe('meme_edition');
    expect(r.found.found_publisher).not.toMatch(/discoverable/);
  });

  it('un ISBN différent tranche : autre édition', () => {
    const notice = { id: 1870, titulo: 'Por un marxismo libertario', autor: 'GUÉRIN, Daniel', editora: 'Biblioteca Jucar',
      local_publicacao: 'Madrid', ano: '1979', isbn: '84-334-1060-1' };
    const page = `DANIEL GUÉRIN\nPOR UN MARXISMO LIBERTARIO\nBIBLIOTECA JÚCAR\nMadrid 1979\nISBN 84-7354-001-2\n${remplissage}`;
    const r = proposer(notice, [page, remplissage], {});
    expect(r.proposed_verdict).toBe('autre_edition');
    expect(r.tool_notes.avertissements).toContain('isbn_different');
  });

  it('un texte ressaisi (traitement de texte, aucun éditeur) : texte_ressaisi', () => {
    const notice = { id: 1, titulo: 'La sociedad moribunda y la anarquía', autor: 'GRAVE, Jean', editora: 'F. Sempere',
      local_publicacao: 'Valencia', ano: '1909' };
    const page = `LA SOCIEDAD MORIBUNDA Y LA ANARQUÍA\nJuan Grave\n${remplissage}`;
    const r = proposer(notice, [page, remplissage], { infos: { producer: 'Microsoft® Word 2016' } });
    expect(r.proposed_verdict).toBe('texte_ressaisi');
  });

  it('sans couche texte : aucun verdict, et l’avertissement le dit', () => {
    const r = proposer(HARPER_1873, ['', '  ', ''], { auteurs: RECLUS });
    expect(r.proposed_verdict).toBeNull();
    expect(r.tool_notes.avertissements).toContain('sans_couche_texte');
  });
});

describe('NUMDIF-2 — le cas se lit dans l’édition, et le doute tranche vers (c)', () => {
  const ALTAMIRA = { id: 2195, titulo: 'El Anarquismo', autor: 'GUÉRIN, Daniel', editora: 'Altamira / Nordan Comunidad',
    local_publicacao: 'Buenos Aires / Montevideo', ano: '1992' };
  const anarres = `DANIEL GUÉRIN\nEL ANARQUISMO\nAnarres\nCorrientes 4790\nBuenos Aires / Argentina\nISBN: 987-20875-0-4\n`
    + 'La reproducción de este libro, a través de medios ópticos, electrónicos, químicos, fotográficos o de fotocopias, '
    + 'está permitida y alentada por los editores.\n';

  it('Anarres au lieu d’Altamira : autre édition, diffusion autorisée par l’éditeur, mention citée avec sa page', () => {
    const r = proposer(ALTAMIRA, [anarres, remplissage], {});
    expect(r.proposed_verdict).toBe('autre_edition');
    expect(r.proposed_case).toBe('diffusion_autorisee');
    expect(r.proposed_mention).toMatch(/alentada por los editores/);
    expect(r.proposed_mention_page).toBe('1');
  });

  it('la vraie page de copyright d’Anarres (césures, « © Anarres ») : mention trouvée, éditeur lu, pas d’année inventée', () => {
    // pdftotext du fichier archive.org guerin-d.-el-anarquismo, p. 3 (recette du 15/10)
    const copyright = '© Anarres\n   Corrientes 4790\n   Buenos Aires / Argentina\n   Tel: 4857-1248\n\nISBN: 987-20875-0-4\n\n'
      + 'La reproducción de este libro, a través de medios ópti-\ncos, electrónicos, químicos, fotográficos o de fotoco-\n'
      + 'pias son permitidos y alentados por los editores.\n\nQueda hecho el depósito que marca la ley 11.723\nImpreso en Argentina / Printed in Argentina';
    const r = proposer(ALTAMIRA, ['EL ANARQUISMO', 'DANIEL GUÉRIN\n\nEL ANARQUISMO', copyright, remplissage], {});
    expect(r.proposed_verdict).toBe('autre_edition');
    expect(r.proposed_case).toBe('diffusion_autorisee');
    expect(r.proposed_mention).toMatch(/medios ópticos, electrónicos/);
    expect(r.proposed_mention_page).toBe('3');
    expect(r.found.found_publisher).toBe('Anarres');
    expect(r.found.found_year).toBeNull();
  });

  it('« Copyleft » imprimé : anti_copyright', () => {
    const r = proposer(ALTAMIRA, [`EL ANARQUISMO\nAltamira\nBuenos Aires 1992\nCopyleft: se permite la libre reproducción.\n${remplissage}`, remplissage], {});
    expect(r.proposed_case).toBe('anti_copyright');
  });

  it('« Todos los derechos reservados » ne vaut pas licence ; décès inconnu : statut_inconnu', () => {
    const r = proposer(ALTAMIRA, [`EL ANARQUISMO\nAltamira\nBuenos Aires 1992\nTodos los derechos reservados. Prohibida la reproducción.\n${remplissage}`, remplissage],
      { auteurs: [{ name: 'Daniel Guérin', death_year: 1988 }] });
    expect(r.proposed_case).toBe('statut_inconnu');
  });
});

describe('ce qu’on télécharge d’abord (les métadonnées classent, elles ne prouvent rien)', () => {
  it('l’année et l’éditeur de la notice passent devant', () => {
    const docs = [
      { identifier: 'a', title: 'The Earth and its inhabitants', date: '1882', publisher: 'Appleton' },
      { identifier: 'b', title: 'The earth : a descriptive history', date: '1872', publisher: 'New York : Harper & Brothers' },
    ];
    const notice = { titulo: 'The Earth', editora: 'Harper & Brothers Publishers', ano: '1872' };
    expect(classerResultats(notice, docs).map((d) => d.identifier)).toEqual(['b', 'a']);
  });

  it('sans l’auteur dans la requête, un livre d’un autre auteur est écarté', () => {
    const notice = { titulo: 'Lenin', autor: 'GUÉRIN, Daniel' };
    expect(pertinentSansAuteur(notice, { title: 'Bolshevism from Moses to Lenin', creator: 'Eckart, Dietrich' })).toBe(false);
    expect(pertinentSansAuteur(notice, { title: 'Lénine', creator: 'Guérin, Daniel' })).toBe(true);
    // sans créateur aux métadonnées (vu le 15/10 sur « El Anarquismo »)
    const anarquismo = { titulo: 'El Anarquismo', autor: 'GUÉRIN, Daniel' };
    expect(pertinentSansAuteur(anarquismo, { title: 'ANARQUISMO Y REVOLUCIÓN EN RUSIA (1917-1921) - Carlos Taibo' })).toBe(false);
    expect(pertinentSansAuteur(notice, { title: 'Bolshevism Moses Lenin' })).toBe(false);
    expect(pertinentSansAuteur(anarquismo, { title: 'El anarquismo' })).toBe(true);
    expect(pertinentSansAuteur(anarquismo, { title: 'Daniel Guérin - El anarquismo, de la doctrina a la acción' })).toBe(true);
  });

  it('les années futures ne sont pas des années d’édition', () => {
    expect(annees('Madrid 1979 — 2999')).toEqual([1979]);
  });
});
