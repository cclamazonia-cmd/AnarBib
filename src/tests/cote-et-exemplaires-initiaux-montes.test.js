// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/cote-et-exemplaires-initiaux-montes.test.js
//
// CE QUE CE TEST PROTÈGE. E6 lot 6 (28/09/2026) sort deux blocs d'affichage de
// BookDraftForm.jsx : la prévia de cote (ShelfLabelPreview.jsx) et les
// exemplaires initiaux (InitialCopiesBlock.jsx). Même méthode que les lots 3 à
// 5 : on lit la SOURCE et on garde le contrat que ni lint, ni build, ni suite
// ne verraient casser :
//   1. la prévia est MONTÉE dans la grille, au palier 3 seulement, entre la
//      circulation et les sujets, et calcule la cote depuis la lib ;
//   2. les exemplaires initiaux sont MONTÉS avant les boutons d'action, pour une
//      fiche non publiée seulement, et remontent leurs saisies par onChange
//      câblé sur `set` du parent ;
//   3. aucun des deux n'écrit le formulaire ni ne lit un état du parent.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const form = src('pages/catalogacao/BookDraftForm.jsx');
const shelf = src('pages/catalogacao/ShelfLabelPreview.jsx');
const copies = src('pages/catalogacao/InitialCopiesBlock.jsx');

describe('prévia de cote (E6 lot 6) — réellement montée', () => {
  it('est rendue au palier 3, entre la circulation et les sujets', () => {
    const circ = form.indexOf("{rrf('circulation_default')}");
    const mount = form.indexOf('<ShelfLabelPreview');
    const subjects = form.indexOf("{rrf('subjects')}");
    expect(circ).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(circ);
    expect(mount).toBeLessThan(subjects);
    expect(form.slice(mount - 40, mount)).toMatch(/catalogTier >= 3 && $/);
    expect(form.slice(mount, form.indexOf('/>', mount))).toMatch(/author=\{f\('autor'\)\} title=\{f\('titulo'\)\} cdd=\{f\('cdd'\)\}/);
  });

  it('calcule la cote depuis la lib et n’écrit rien', () => {
    expect(shelf).toMatch(/import \{ buildShelfLabel \} from '@\/lib\/catalogacao\/bookDraft';/);
    expect(shelf).toMatch(/const label = buildShelfLabel\(\{ author, title, cdd \}\);/);
    expect(form.includes('buildShelfLabel')).toBe(false);
    for (const forbidden of ["f('", 'set(', 'useState', 'supabase']) {
      expect(shelf.includes(forbidden), `${forbidden} dans ShelfLabelPreview`).toBe(false);
    }
  });
});

describe('exemplaires initiaux (E6 lot 6) — réellement montés', () => {
  it('sont rendus avant les boutons d’action, pour une fiche non publiée', () => {
    const review = form.indexOf('<ReviewPanel');
    const mount = form.indexOf('<InitialCopiesBlock');
    const actions = form.indexOf('Action buttons');
    expect(mount).toBeGreaterThan(review);
    expect(mount).toBeLessThan(actions);
    expect(form.slice(mount - 80, mount)).toMatch(/\{!f\('published_book_id'\) && \(/);
    const props = form.slice(mount, form.indexOf('/>', mount));
    expect(props).toMatch(/importedItems=\{importedItems\} copies=\{f\('initial_copies'\)\}/);
    expect(props).toMatch(/libraryIdValue=\{f\('initial_copies_library_id'\)\} isNetworkAdmin=\{isNetworkAdmin\}/);
    expect(props).toMatch(/libraries=\{catalogLibraries\} onChange=\{set\}/);
  });

  it('remontent leurs deux saisies par onChange et n’écrivent rien', () => {
    expect(copies).toMatch(/onChange=\{e => onChange\('initial_copies', e\.target\.value\)\}/);
    expect(copies).toMatch(/onChange=\{e => onChange\('initial_copies_library_id', e\.target\.value\)\}/);
    expect(copies).toMatch(/data-testid="copies-imported"/);
    for (const forbidden of ["f('", ' set(', 'useState', 'supabase', 'catalogLibraries']) {
      expect(copies.includes(forbidden), `${forbidden} dans InitialCopiesBlock`).toBe(false);
    }
    // la publication lit toujours ces deux champs dans le parent
    expect(form).toMatch(/initial_copies: Math\.max\(1, Math\.min\(50, parseInt\(f\('initial_copies'\), 10\) \|\| 1\)\)/);
  });
});
