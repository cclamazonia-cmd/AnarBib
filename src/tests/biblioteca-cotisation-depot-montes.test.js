// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/biblioteca-cotisation-depot-montes.test.js
//
// CE QUE CE TEST PROTÈGE. E6, BibliotecaPage lot 3 (29/09/2026) : la cotisation
// associative et le dépôt de garantie sortent de BibliotecaPage.jsx
// (MembershipSection.jsx, DepositSection.jsx). Même méthode que les lots 1 et
// 2 : on lit la SOURCE et on garde le contrat que ni lint, ni build, ni suite
// ne verraient casser :
//   1. les deux sections sont MONTÉES dans l'onglet `regulation`, après le
//      gestionnaire des jeux de règles, la cotisation avant le dépôt ;
//   2. chacune reçoit la fiche de la bibliothèque et SA liste de règles avec
//      leur setter — les listes restent chargées par le parent (loadCore) ;
//   3. l'état d'édition et les fonctions ont suivi ; les sections écrivent les
//      tables de règles et la fiche, rien d'autre.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const page = src('pages/biblioteca/BibliotecaPage.jsx');
const membership = src('pages/biblioteca/MembershipSection.jsx');
const deposit = src('pages/biblioteca/DepositSection.jsx');

describe('cotisation et dépôt de garantie (E6, lot 3) — réellement montés', () => {
  it('sont rendus dans l’onglet regulation, la cotisation avant le dépôt', () => {
    const tab = page.indexOf("{tab==='regulation'");
    const policies = page.indexOf('<PolicySetManager', tab);
    const m = page.indexOf('<MembershipSection');
    const d = page.indexOf('<DepositSection');
    const docs = page.indexOf("{tab==='documents'");
    expect(tab).toBeGreaterThan(-1);
    expect(m).toBeGreaterThan(policies);
    expect(d).toBeGreaterThan(m);
    expect(d).toBeLessThan(docs);
    expect(page.indexOf("import MembershipSection from './MembershipSection';")).toBeGreaterThan(-1);
    expect(page.indexOf("import DepositSection from './DepositSection';")).toBeGreaterThan(-1);
  });

  it('reçoivent la fiche et leur liste de règles, avec les setters', () => {
    const m = page.slice(page.indexOf('<MembershipSection'), page.indexOf('/>', page.indexOf('<MembershipSection')));
    const d = page.slice(page.indexOf('<DepositSection'), page.indexOf('/>', page.indexOf('<DepositSection')));
    expect(m).toMatch(/libraryId=\{libraryId\} lib=\{lib\} setLib=\{setLib\}/);
    expect(m).toMatch(/rules=\{membershipRules\} setRules=\{setMembershipRules\} setMsg=\{setMsg\}/);
    expect(d).toMatch(/libraryId=\{libraryId\} lib=\{lib\} setLib=\{setLib\}/);
    expect(d).toMatch(/rules=\{depositRules\} setRules=\{setDepositRules\} setMsg=\{setMsg\}/);
    // les listes restent chargées par le parent
    expect(page).toMatch(/const \[membershipRules, setMembershipRules\] = useState\(\[\]\)/);
    expect(page).toMatch(/const \[depositRules, setDepositRules\] = useState\(\[\]\)/);
    expect(page).toMatch(/setMembershipRules\(mrR\.data \|\| \[\]\)/);
    expect(page).toMatch(/setDepositRules\(drData \|\| \[\]\)/);
  });

  it('ont emporté l’état d’édition et les fonctions', () => {
    for (const gone of ['editingMembershipRule', 'toggleMembershipEnabled', 'saveMembershipRule', 'toggleMembershipRuleActive', 'deleteMembershipRule']) {
      expect(page.includes(gone), `${gone} encore dans BibliotecaPage`).toBe(false);
      expect(membership.includes(gone), `${gone} absent de MembershipSection`).toBe(true);
    }
    for (const gone of ['editingDepositRule', 'toggleDepositEnabled', 'saveDepositLimit', 'saveDepositRule', 'toggleDepositRuleActive', 'deleteDepositRule']) {
      expect(page.includes(gone), `${gone} encore dans BibliotecaPage`).toBe(false);
      expect(deposit.includes(gone), `${gone} absent de DepositSection`).toBe(true);
    }
    expect(membership).toMatch(/const membershipRules = rules;\s+const setMembershipRules = setRules;/);
    expect(deposit).toMatch(/const depositRules = rules;\s+const setDepositRules = setRules;/);
  });

  it('n’écrivent que leurs règles et la fiche de la bibliothèque', () => {
    const tables = (s) => [...s.matchAll(/supabase\.from\('([a-z_]+)'\)/g)].map(m => m[1]);
    expect([...new Set(tables(membership))].sort()).toEqual(['libraries', 'library_membership_rules']);
    expect([...new Set(tables(deposit))].sort()).toEqual(['libraries', 'library_deposit_rules']);
    // la suppression d'une cotisation garde sa confirmation à deux niveaux
    expect(membership).toMatch(/const typed = prompt\(/);
    expect(membership).toMatch(/if \(typed !== rule\.name\)/);
    // le dépôt reste un opt-in : ses règles ne s'affichent que si le système est activé
    expect(deposit).toMatch(/\{lib\?\.deposit_enabled && \(<>/);
    for (const s of [membership, deposit]) {
      // l'appel, pas le mot : l'en-tête de la section cite loadCore pour dire qui charge
      expect(s.includes('loadAll(')).toBe(false);
      expect(s.includes('loadCore(')).toBe(false);
    }
  });
});
