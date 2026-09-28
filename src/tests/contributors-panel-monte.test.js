// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/contributors-panel-monte.test.js
//
// CE QUE CE TEST PROTÈGE. E6 lot 4 (28/09/2026) sort le bloc des contributeurs
// de BookDraftForm.jsx (ContributorsPanel.jsx) par déplacement de lignes. Même
// méthode que lookup-panel-monte : on lit la SOURCE et on garde le contrat que
// ni lint, ni build, ni suite ne verraient casser :
//   1. le panneau est MONTÉ dans la grille, après l'aide à la casse du titre ;
//   2. la LISTE reste au parent (sauvegarde, chargement, synthèse d'autor,
//      candidates, publication la lisent) et lui est passée avec son setter ;
//   3. le panneau ne touche ni le formulaire ni l'état du brouillon : il
//      prévient par onDirty, câblé sur la règle « saved/ready → dirty » ;
//   4. le sélecteur d'autorité (état, recherche, liaison) a suivi le panneau.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const form = src('pages/catalogacao/BookDraftForm.jsx');
const panel = src('pages/catalogacao/ContributorsPanel.jsx');

describe('panneau des contributeurs (E6 lot 4) — réellement monté', () => {
  it('est rendu dans la grille, juste après l’aide à la casse du titre', () => {
    const titleCase = form.indexOf('<TitleCaseAssist');
    const mount = form.indexOf('<ContributorsPanel');
    expect(titleCase).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(titleCase);
    expect(mount - titleCase).toBeLessThan(600);
    expect(form.indexOf("import ContributorsPanel from './ContributorsPanel';")).toBeGreaterThan(-1);
  });

  it('reçoit la liste du parent, avec son setter, et prévient par onDirty', () => {
    const mount = form.indexOf('<ContributorsPanel');
    const props = form.slice(mount, form.indexOf('/>', mount));
    expect(props).toMatch(/contributors=\{contributors\}/);
    expect(props).toMatch(/setContributors=\{setContributors\}/);
    expect(props).toMatch(/availableRoleKeys=\{availableRoleKeys\}/);
    expect(props).toMatch(/roleLabel=\{roleLabel\}/);
    expect(props).toMatch(/autor=\{f\('autor'\)\}/);
    expect(props).toMatch(/onDirty=\{\(\) => \{ if \(draftState === 'saved' \|\| draftState === 'ready'\) setDraftState\('dirty'\); \}\}/);
    // la liste et ses lecteurs restent au parent
    expect(form).toMatch(/const \[contributors, setContributors\] = useState\(/);
    for (const stays of ['function syncAutorFromContributors()', 'async function loadContributors(', 'async function saveContributors(', 'async function applyCandidate(']) {
      expect(form.includes(stays), `${stays} devrait rester dans BookDraftForm`).toBe(true);
    }
  });

  it('a emporté la gestion des lignes et le sélecteur d’autorité', () => {
    for (const gone of ['addContributor', 'removeContributor', 'updateContributor', 'togglePrimary', 'searchAuthorForRow', 'linkAuthorToRow', 'unlinkAuthorFromRow', 'authorSearch']) {
      expect(form.includes(gone), `${gone} encore dans BookDraftForm`).toBe(false);
      expect(panel.includes(gone), `${gone} absent de ContributorsPanel`).toBe(true);
    }
    expect(panel).toMatch(/const \[authorSearch, setAuthorSearch\] = useState\(/);
    expect(panel).toMatch(/supabase\.rpc\('search_authors_by_name'/);
  });

  it('ne touche ni le formulaire ni l’état du brouillon', () => {
    for (const forbidden of ['setDraftState', 'draftState', 'setForm(', 'setMany(', "set('autor'"]) {
      expect(panel.includes(forbidden), `${forbidden} dans ContributorsPanel`).toBe(false);
    }
    // cinq gestes qui rendent le brouillon à enregistrer : ajout, retrait,
    // modification, liaison, déliaison — chacun prévient le parent
    expect((panel.match(/onDirty\(\);/g) || []).length).toBe(5);
    // le champ « autor » synthétisé est lu par prop, en lecture seule
    expect(panel).toMatch(/value=\{autor\} readOnly/);
  });
});
