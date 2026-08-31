// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/build-backlog-engendrement.test.js
//
// CE QUE CE TEST PROTÈGE. Le backlog v34 vit dans docs/backlogs/backlog-v34.json,
// et trois fichiers en sont engendrés par scripts/build-backlog.cjs : les deux
// .md (fr, pt-BR) et le .html. La doctrine est « on modifie le JSON, on rejoue
// le script, on commite les quatre ensemble » — mais jusqu'au 31/08/2026 rien
// ne la faisait respecter : un commit qui éditait un fichier engendré à la main,
// ou qui poussait le JSON sans rejouer le script, passait la CI sans un mot, et
// la divergence ne se voyait qu'à la session suivante, chez quelqu'un d'autre.
//
// Ce test rejoue le VRAI script sur une COPIE du JSON dans un répertoire
// temporaire (le script écrit ses sorties à côté de sa source, c'est prévu pour)
// puis compare octet à octet ce qu'il produit avec ce que le dépôt porte. Toute
// divergence est nommée fichier par fichier. Il vérifie aussi que la ligne de
// fraîcheur — recalculée à chaque engendrement — compte bien les items portant
// un champ `verif`, puisque c'est elle qui empêche le rapport de vieillir en
// silence.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, readFileSync, copyFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const SCRIPT = fileURLToPath(new URL('../../scripts/build-backlog.cjs', import.meta.url));
const DOCS = fileURLToPath(new URL('../../docs/backlogs', import.meta.url));
const SORTIES = [
  'AnarBib-Backlog-2026-08-29-v34.md',
  'AnarBib-Backlog-2026-08-29-v34.pt-BR.md',
  'backlog-v34.html',
];

let bac;

beforeAll(() => {
  bac = mkdtempSync(path.join(tmpdir(), 'backlog-v34-'));
  copyFileSync(path.join(DOCS, 'backlog-v34.json'), path.join(bac, 'backlog-v34.json'));
  execFileSync('node', [SCRIPT, path.join(bac, 'backlog-v34.json')], { encoding: 'utf8' });
});

afterAll(() => {
  rmSync(bac, { recursive: true, force: true });
});

describe('backlog v34 — les fichiers engendrés correspondent au JSON', () => {
  for (const f of SORTIES) {
    it(`${f} est exactement ce que le script produit depuis le JSON`, () => {
      const engendre = readFileSync(path.join(bac, f), 'utf8');
      const commite = readFileSync(path.join(DOCS, f), 'utf8');
      // Comparaison stricte : un fichier engendré édité à la main, ou un JSON
      // poussé sans rejouer le script, échoue ici avec le nom du fichier.
      expect(commite).toBe(engendre);
    });
  }

  it('la ligne de fraîcheur compte les items vérifiés du JSON', () => {
    const D = JSON.parse(readFileSync(path.join(DOCS, 'backlog-v34.json'), 'utf8'));
    const verifies = D.items.filter((i) => i.verif).map((i) => i.id);
    const md = readFileSync(path.join(bac, 'AnarBib-Backlog-2026-08-29-v34.md'), 'utf8');
    expect(md).toContain(`**${verifies.length} items sur ${D.items.length}**`);
    for (const id of verifies) expect(md).toContain(id);
  });
});
