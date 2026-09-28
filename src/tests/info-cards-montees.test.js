// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/info-cards-montees.test.js
//
// CE QUE CE TEST PROTÈGE. E6 lot 8 (28/09/2026) sort les cartes « para
// informação » de l'aperçu (auteur·rices, exemplaires existants) de
// BookDraftForm.jsx (InfoCards.jsx). Même méthode que les lots 3 à 7 : on lit
// la SOURCE et on garde le contrat que ni lint, ni build, ni suite ne verraient
// casser :
//   1. les cartes sont MONTÉES dans l'aperçu live de la fiche ;
//   2. elles reçoivent la notice publiée, les contributeur·rices et les deux
//      rappels de navigation (onglet auteurs, onglet exemplaires) ;
//   3. le chargement des exemplaires (fonds → exemplaires) vit dans le panneau
//      avec ses deux états, plus dans le parent ; rien n'y écrit le formulaire.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const form = src('pages/catalogacao/BookDraftForm.jsx');
const panel = src('pages/catalogacao/InfoCards.jsx');

describe('cartes « para informação » (E6 lot 8) — réellement montées', () => {
  it('sont rendues dans l’aperçu live de la fiche', () => {
    const preview = form.indexOf('function renderLivePreview()');
    const mount = form.indexOf('<InfoCards');
    const previewEnd = form.indexOf('</aside>', preview);
    expect(preview).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(preview);
    expect(mount).toBeLessThan(previewEnd);
    expect(form.indexOf("import InfoCards from './InfoCards';")).toBeGreaterThan(-1);
  });

  it('reçoivent la notice, les contributeur·rices et les rappels de navigation', () => {
    const mount = form.indexOf('<InfoCards');
    const props = form.slice(mount, form.indexOf('/>', mount));
    expect(props).toMatch(/publishedBookId=\{form\.published_book_id\} catalogLibraries=\{catalogLibraries\} libraryId=\{libraryId\}/);
    expect(props).toMatch(/contributors=\{contributors\} onNavigateTab=\{onNavigateTab\} onEditExemplar=\{onEditExemplar\}/);
    expect(panel).toMatch(/onNavigateTab\?\.\('authorsPanel'\)/);
    expect(panel).toMatch(/onNavigateTab\?\.\('indexPanel'\)/);
    expect(panel).toMatch(/onEditExemplar\?\.\(ex\.id\)/);
  });

  it('portent le chargement des exemplaires et n’écrivent rien', () => {
    for (const gone of ['linkedExemplars', 'myExemplars', 'renderInfoCards']) {
      expect(form.includes(gone), `${gone} encore dans BookDraftForm`).toBe(false);
    }
    expect(panel).toMatch(/const \[linkedExemplars, setLinkedExemplars\] = useState\(\[\]\)/);
    expect(panel).toMatch(/const \[myExemplars, setMyExemplars\] = useState\(\[\]\)/);
    expect(panel).toMatch(/\}, \[publishedBookId, catalogLibraries, libraryId\]\);/);
    expect(panel).toMatch(/supabase\.from\('book_holdings'\)/);
    expect(panel).toMatch(/supabase\.from\('exemplares'\)/);
    for (const forbidden of ["f('", 'setForm(', 'setMany(', 'form.published_book_id', 'setContributors']) {
      expect(panel.includes(forbidden), `${forbidden} dans InfoCards`).toBe(false);
    }
  });
});
