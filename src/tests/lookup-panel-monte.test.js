// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/lookup-panel-monte.test.js
//
// CE QUE CE TEST PROTÈGE. E6 lot 3 (28/09/2026) sort le panneau de recherche
// catalographique de BookDraftForm.jsx (LookupPanel.jsx) par déplacement de
// lignes. Comme pour le sélecteur de revue (serial-picker-monte), rendre le
// formulaire entier serait fragile ; on lit la SOURCE et on garde le contrat
// qui peut casser sans que lint, build ni suite ne le voient :
//   1. le panneau est MONTÉ dans la colonne « Lookup panel (next to cover) »,
//      et ses trois rappels sont câblés sur les écrivains du parent ;
//   2. le parent ne porte plus l'état ni la logique de recherche ;
//   3. le panneau n'écrit jamais le formulaire lui-même (pas de setForm, pas de
//      setMany) : tout passe par les rappels ;
//   4. le panneau se remet à zéro quand le brouillon change (résultats BN
//      compris) — avant l'extraction, seule la fiche vierge le faisait.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const form = src('pages/catalogacao/BookDraftForm.jsx');
const panel = src('pages/catalogacao/LookupPanel.jsx');

describe('panneau de recherche catalographique (E6 lot 3) — réellement monté', () => {
  it('est rendu dans la colonne du lookup, après la galerie de couvertures', () => {
    const column = form.indexOf('Lookup panel (next to cover)');
    const mount = form.indexOf('<LookupPanel');
    const grid = form.indexOf('<div className="cat-book-grid">', column);
    expect(column).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(column);
    expect(mount).toBeLessThan(grid);
    expect(form.indexOf("import LookupPanel from './LookupPanel';")).toBeGreaterThan(-1);
  });

  it('câble ses trois rappels sur les écrivains du parent', () => {
    const mount = form.indexOf('<LookupPanel');
    const props = form.slice(mount, form.indexOf('/>', mount));
    expect(props).toMatch(/draftId=\{f\('id'\)\}/);
    expect(props).toMatch(/onIsbnScanned=\{\(isbn\) => setForm\(prev => \(\{ \.\.\.prev, isbn \}\)\)\}/);
    expect(props).toMatch(/onApplyCandidate=\{applyCandidate\}/);
    expect(props).toMatch(/onApplyBnResult=\{applyBnResult\}/);
    // les écrivains restent dans le parent : ce sont eux qui touchent le
    // formulaire, les contributeurs et l'état du brouillon
    expect(form).toMatch(/async function applyCandidate\(candidate\)/);
    expect(form).toMatch(/function applyBnResult\(item\)/);
  });

  it('a emporté l’état et la logique de recherche hors du parent', () => {
    for (const gone of ['lookupResult', 'runCatalogLookup', 'runBnIsbnLookup', 'openWorldCat', 'openIssnPortal', 'isbnScanning', 'setBnResult']) {
      expect(form.includes(gone), `${gone} encore dans BookDraftForm`).toBe(false);
      expect(panel.includes(gone), `${gone} absent de LookupPanel`).toBe(true);
    }
    // le lecteur de code-barres et la normalisation BN suivent la logique
    expect(form.includes('CardScanner')).toBe(false);
    expect(panel).toMatch(/import CardScanner from '@\/pages\/painel\/tabs\/CardScanner';/);
    expect(form.includes('normalizeBnToCandidate')).toBe(false);
    expect(panel).toMatch(/import \{ normalizeBnToCandidate \} from '@\/lib\/catalogacao\/bookDraft';/);
  });

  it('n’écrit jamais le formulaire lui-même', () => {
    expect(panel.includes('setForm(')).toBe(false);
    expect(panel.includes('setMany(')).toBe(false);
    expect(panel.includes('setContributors(')).toBe(false);
    expect(panel).toMatch(/onIsbnScanned\(clean\);/);
    expect(panel).toMatch(/await onApplyCandidate\(/);
    expect(panel).toMatch(/onClick=\{\(\) => onApplyBnResult\(item\)\}/);
  });

  it('se remet à zéro quand le brouillon change, résultats BN compris', () => {
    expect(panel).toMatch(/useEffect\(\(\) => \{ setLookupResult\(null\); setSelectedCandidate\(0\); setBnResult\(null\); \}, \[draftId\]\);/);
    // et le parent ne le fait plus à sa place
    const reset = form.slice(form.indexOf('function resetForm()'), form.indexOf('function resetForm()') + 800);
    expect(reset.includes('setLookupResult')).toBe(false);
    expect(reset.includes('setBnResult')).toBe(false);
    expect(reset).toMatch(/LookupPanel/);
  });
});
