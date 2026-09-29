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
import { readFileSync, readdirSync } from 'node:fs';
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
    // la page n'importe que les styles qu'elle emploie encore : `lr` est parti au lot 2,
    // `lw` au lot 3 (les listes vivent dans les sections)
    expect(page).toMatch(/import \{ (fs|ls|bx|lr|lw)(, (fs|ls|bx|lr|lw))* \} from '\.\/styles';/);
    for (const name of ['fs', 'ls', 'bx', 'lr', 'lw']) {
      expect(styles).toMatch(new RegExp(`^export const ${name} = `, 'm'));
    }
    expect(page.includes("const fs = { width:'100%'")).toBe(false);
  });
});

// 29/09/2026 — Xavier a voulu supprimer un PEB en partie rendu : l'écran offrait
// « Supprimer » à tout prêt non terminé, la base ne laisse supprimer qu'un prêt
// jamais sorti, et le refus s'affichait en jargon (« refusé par RLS »). L'écran
// lit désormais la même liste que la politique DELETE, et dit le refus en clair.
describe('suppression d’un PEB — l’écran suit la base', () => {
  it('le bouton ne s’offre qu’aux statuts que la politique DELETE accepte', () => {
    const dir = path.resolve(here, '..', '..', 'supabase', 'migrations');
    let valeurs = null;
    for (const f of readdirSync(dir).filter(n => /^\d{14}_.*\.sql$/.test(n)).sort()) {
      const m = readFileSync(path.join(dir, f), 'utf8')
        .match(/CREATE POLICY "interlibrary_loans_v2_delete"[^;]*?"status_global" = ANY \(ARRAY\[([^\]]+)\]/);
      if (m) valeurs = [...m[1].matchAll(/'([a-z_]+)'/g)].map(x => x[1]);
    }
    expect(valeurs, 'politique DELETE introuvable').toBeTruthy();
    const liste = section.match(/const ILL_DISCARDABLE = \[([^\]]+)\];/);
    expect(liste).toBeTruthy();
    expect([...liste[1].matchAll(/'([a-z_]+)'/g)].map(x => x[1]).sort()).toEqual([...valeurs].sort());
    expect(section).toMatch(/\{ILL_DISCARDABLE\.includes\(loan\.status_global\) && \(\s*<button[^>]*onClick=\{\(\)=>deleteIll\(loan\.id\)\}/);
    expect(section.includes('{!isTerminal && (')).toBe(false);
  });

  it('un refus de la base se dit en clair, dans les dix langues', () => {
    const del = section.slice(section.indexOf('async function deleteIll'), section.indexOf('async function archiveIllLoan'));
    expect(del).toMatch(/refus\[ée\] par RLS\|row-level security/);
    expect(del).toMatch(/t\(\{ id: 'biblioteca\.ill\.discardAfterDeparture' \}, \{ id: loanId \}\)/);
    const dossier = path.resolve(here, '..', 'i18n', 'locales');
    const locales = readdirSync(dossier).filter(f => f.endsWith('.json'));
    expect(locales.length).toBe(10);
    for (const f of locales) {
      const v = JSON.parse(readFileSync(path.join(dossier, f), 'utf8'))['biblioteca.ill.discardAfterDeparture'];
      expect(typeof v, f).toBe('string');
      expect(v, f).toMatch(/\{id\}/);
      expect(/RLS|row-level/i.test(v), f).toBe(false);
    }
  });
});
