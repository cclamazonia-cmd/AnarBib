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
//   4. le sélecteur d'autorité (état, recherche, liaison) a suivi le panneau ;
//   5. (refonte du 17/10/2026) l'ajout passe par un seul champ à autocomplétion.

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
    for (const gone of ['addEntry', 'removeContributor', 'updateContributor', 'togglePrimary', 'linkAuthorToRow', 'unlinkAuthorFromRow']) {
      expect(form.includes(gone), `${gone} encore dans BookDraftForm`).toBe(false);
      expect(panel.includes(gone), `${gone} absent de ContributorsPanel`).toBe(true);
    }
    expect(panel).toMatch(/supabase\.rpc\('search_authors_by_name'/);
  });

  // Refonte du 17/10/2026 : un seul champ d'ajout à autocomplétion.
  it('ajoute par un seul champ : autorités à la frappe, nom libre en dernier recours', () => {
    expect(panel).toMatch(/role="combobox"/);
    expect(panel).toMatch(/catalogacao\.contributor\.addFree/);
    // plus de bouton par rôle (doublon du menu de chaque ligne), plus de « Lier » à part
    for (const gone of ['addAuthor', 'addCoauthor', 'addCollective', 'addTranslator', 'searchAuthorForRow', 'authlink.needName']) {
      expect(panel.includes(gone), `${gone} encore dans ContributorsPanel`).toBe(false);
    }
    // le rôle se déduit de la position : 1re entrée auteur·rice, les suivantes coauteur·rice
    expect(panel).toMatch(/role: kept\.length \? 'coautor' : 'autor'/);
    // l'entrée principale se marque d'une étoile, plus d'un bouton radio
    expect(panel).toMatch(/<AppIcon name="star"/);
    expect(panel.includes('type="radio"')).toBe(false);
    // une ligne non liée cherche d'elle-même son autorité et propose la liaison
    expect(panel).toMatch(/catalogacao\.authlink\.suggest/);
  });

  it('ne touche ni le formulaire ni l’état du brouillon', () => {
    for (const forbidden of ['setDraftState', 'draftState', 'setForm(', 'setMany(', "set('autor'"]) {
      expect(panel.includes(forbidden), `${forbidden} dans ContributorsPanel`).toBe(false);
    }
    // six gestes qui rendent le brouillon à enregistrer : ajout, retrait,
    // modification, choix de la principale, liaison, déliaison — chacun
    // prévient le parent
    expect((panel.match(/onDirty\(\);/g) || []).length).toBe(6);
    // le champ « autor » synthétisé est lu par prop, en lecture seule
    expect(panel).toMatch(/value=\{autor\} readOnly/);
  });
});
