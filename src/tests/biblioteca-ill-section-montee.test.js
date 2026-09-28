// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/biblioteca-ill-section-montee.test.js
//
// CE QUE CE TEST PROTÈGE. E6, BibliotecaPage lot 1 (28/09/2026) : l'onglet
// « Empréstimos interbibliotecas » (PEB) sort de BibliotecaPage.jsx
// (IllSection.jsx). Même méthode que les lots de BookDraftForm : on lit la
// SOURCE et on garde le contrat que ni lint, ni build, ni suite ne verraient
// casser :
//   1. la section est MONTÉE sous l'onglet `ill`, entre les échanges et les
//      rapports, et reçoit les prêts, leurs exemplaires, les bibliothèques et
//      `onChanged` ;
//   2. les prêts et leurs exemplaires restent chargés par le parent (le rapport
//      les lit) ; les sept états du formulaire et du pointage ont suivi ;
//   3. la section appelle les RPC PEB et prévient par onChanged, jamais par
//      loadAll ; les styles partagés viennent du module commun.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const page = src('pages/biblioteca/BibliotecaPage.jsx');
const section = src('pages/biblioteca/IllSection.jsx');
const styles = src('pages/biblioteca/styles.js');

describe('section PEB de la page Bibliothèque (E6, lot 1) — réellement montée', () => {
  it('est rendue sous l’onglet ill, entre les échanges et les rapports', () => {
    const exchanges = page.indexOf("{tab==='exchanges'");
    const mount = page.indexOf('<IllSection');
    const reports = page.indexOf("{tab==='reports'");
    expect(exchanges).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(exchanges);
    expect(mount).toBeLessThan(reports);
    expect(page.slice(mount - 40, mount)).toMatch(/\{tab==='ill' && \(\s*$/);
    expect(page.indexOf("import IllSection from './IllSection';")).toBeGreaterThan(-1);
  });

  it('reçoit les prêts, leurs exemplaires, les bibliothèques et onChanged', () => {
    const mount = page.indexOf('<IllSection');
    const props = page.slice(mount, page.indexOf('/>', mount));
    expect(props).toMatch(/libraryId=\{libraryId\} illLoans=\{illLoans\} illItemsByLoan=\{illItemsByLoan\}/);
    expect(props).toMatch(/allLibraries=\{allLibraries\} pebEligibleLibraries=\{pebEligibleLibraries\} isCoord=\{isCoord\}/);
    expect(props).toMatch(/setMsg=\{setMsg\} onChanged=\{loadAll\}/);
    // la liste et ses exemplaires restent au parent : loadHeavy les charge, le rapport les lit
    expect(page).toMatch(/const \[illLoans, setIllLoans\] = useState\(\[\]\)/);
    expect(page).toMatch(/const \[illItemsByLoan, setIllItemsByLoan\] = useState\(\{\}\)/);
    expect(page).toMatch(/const items = illItemsByLoan\[loan\.id\] \|\| \[\];/);
  });

  it('a emporté ses sept états, ses fonctions et le partage numérique', () => {
    for (const gone of ['illForm', 'illDocSearch', 'illDocResults', 'illExpanded', 'illReturnDraft', 'illReturnFeedback', 'searchIllDocs', 'saveIll', 'updateIllStatus', 'submitIllItemReturn', 'deleteIll', 'archiveIllLoan', 'LibraryDigitalSharesSection']) {
      expect(page.includes(gone), `${gone} encore dans BibliotecaPage`).toBe(false);
      expect(section.includes(gone), `${gone} absent de IllSection`).toBe(true);
    }
    expect((section.match(/useState\(/g) || []).length).toBe(8); // sept états + saving local
    for (const rpc of ['fn_peb_search_exemplares', 'fn_peb_create_loan_with_items', 'fn_peb_update_status', 'fn_peb_update_item_status', 'fn_peb_delete_loan', 'fn_peb_archive_loan']) {
      expect(section.includes(rpc), `${rpc} absent de IllSection`).toBe(true);
    }
  });

  it('prévient par onChanged et prend ses styles au module commun', () => {
    expect((section.match(/await onChanged\?\.\(\);/g) || []).length).toBe(5);
    expect(section.includes('loadAll')).toBe(false);
    expect(section).toMatch(/import \{ fs, ls, bx, lr, lw \} from '\.\/styles';/);
    expect(page).toMatch(/import \{ fs, ls, bx, lr, lw \} from '\.\/styles';/);
    for (const name of ['fs', 'ls', 'bx', 'lr', 'lw']) {
      expect(styles).toMatch(new RegExp(`^export const ${name} = `, 'm'));
    }
    expect(page.includes("const fs = { width:'100%'")).toBe(false);
  });
});
