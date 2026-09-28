// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/review-panel-monte.test.js
//
// CE QUE CE TEST PROTÈGE. E6 lot 5 (28/09/2026) sort le « Painel de revisão da
// ficha » de BookDraftForm.jsx (ReviewPanel.jsx) par déplacement de lignes.
// Même méthode que les lots 3 et 4 : on lit la SOURCE et on garde le contrat
// que ni lint, ni build, ni suite ne verraient casser :
//   1. le panneau est MONTÉ après la grille des champs, avant les exemplaires
//      initiaux ;
//   2. l'état ISBD, sa préparation (qui écrit marc_json) et les libellés de
//      zones restent au parent et lui sont passés en props ;
//   3. le panneau n'écrit rien : ni formulaire, ni état ISBD, ni brouillon ;
//   4. l'onglet courant vit dans le panneau et revient au résumé quand le
//      brouillon change.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const form = src('pages/catalogacao/BookDraftForm.jsx');
const panel = src('pages/catalogacao/ReviewPanel.jsx');

describe('panneau de révision de la fiche (E6 lot 5) — réellement monté', () => {
  it('est rendu après la grille des champs, avant les exemplaires initiaux', () => {
    const marc = form.indexOf("{rrf('marc_json')}");
    const mount = form.indexOf('<ReviewPanel');
    const copies = form.indexOf('Exemplaires initiaux');
    expect(marc).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(marc);
    expect(mount).toBeLessThan(copies);
    expect(form.indexOf("import ReviewPanel from './ReviewPanel';")).toBeGreaterThan(-1);
  });

  it('reçoit l’ISBD du parent, qui garde sa préparation', () => {
    const mount = form.indexOf('<ReviewPanel');
    const props = form.slice(mount, form.indexOf('/>', mount));
    expect(props).toMatch(/draftId=\{f\('id'\)\}/);
    expect(props).toMatch(/isbdEnabled=\{isbdEnabled\} isbdData=\{isbdData\} zoneLabels=\{ZONE_LABELS\}/);
    expect(props).toMatch(/onPrepareIsbd=\{prepareIsbd\} onClearIsbd=\{clearIsbd\}/);
    expect(props).toMatch(/materialLabel=\{MATERIAL_TYPES\.find\(m => m\.value === materialType\)\?\.label \|\| materialType\}/);
    for (const stays of ['function prepareIsbd()', 'function clearIsbd()', 'const ZONE_LABELS = {', 'const [isbdEnabled, setIsbdEnabled]']) {
      expect(form.includes(stays), `${stays} devrait rester dans BookDraftForm`).toBe(true);
    }
  });

  it('n’écrit rien : ni formulaire, ni ISBD, ni brouillon', () => {
    for (const forbidden of ['setForm(', 'setMany(', "set('", 'setIsbd', 'setDraftState', "f('marc_json')", 'construireZonesIsbd']) {
      expect(panel.includes(forbidden), `${forbidden} dans ReviewPanel`).toBe(false);
    }
    expect(panel).toMatch(/onClick=\{onPrepareIsbd\}/);
    expect(panel).toMatch(/onClick=\{onClearIsbd\}/);
    expect(panel).toMatch(/zoneLabels\[z\]/);
  });

  it('porte les trois onglets et revient au résumé quand le brouillon change', () => {
    expect(panel).toMatch(/const \[reviewTab, setReviewTab\] = useState\('summary'\);/);
    expect(panel).toMatch(/useEffect\(\(\) => \{ setReviewTab\('summary'\); \}, \[draftId\]\);/);
    for (const tab of ["reviewTab === 'summary'", "reviewTab === 'public'", "reviewTab === 'isbd'"]) {
      expect(panel.includes(tab), `${tab} absent`).toBe(true);
    }
    expect(form.includes('reviewTab')).toBe(false);
  });
});
