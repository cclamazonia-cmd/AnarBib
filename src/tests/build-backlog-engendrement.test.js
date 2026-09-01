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
import { mkdtempSync, rmSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs';
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

describe('build-backlog — un item incomplet ne fait ni planter ni mentir', () => {
  // CE QUE CE TEST PROTÈGE, et pourquoi il existe depuis le 01/09/2026.
  //
  // Deux défauts du même genre, découverts le même soir en ajoutant l'item F8 :
  //
  //   * un item sans champ `r` faisait PLANTER le script (`i.r.map` non gardé),
  //     alors que rien ne documentait `r` comme obligatoire — 76 items sur 77
  //     l'avaient, la contrainte existait de fait et jamais par écrit ;
  //   * un item sans `w`, `y` ou `dep` écrivait littéralement « undefined »
  //     dans les DEUX backlogs publiés, sans erreur ni avertissement. F8 en a
  //     porté trois dans chaque livrable, poussés en production.
  //
  // Le second est le pire : un plantage se voit, un « undefined » publié se lit
  // par quelqu'un d'autre, des semaines plus tard, et passe pour du contenu.
  // Depuis, les blocs facultatifs sont OMIS quand le champ manque. Ce test tient
  // les deux garanties à la fois, sur une copie jetable du backlog réel.
  it('un item amputé de r, w, y, dep, f, sk et verif s\'engendre sans erreur et sans « undefined »', () => {
    const bac2 = mkdtempSync(path.join(tmpdir(), 'backlog-ampute-'));
    try {
      const D = JSON.parse(readFileSync(path.join(DOCS, 'backlog-v34.json'), 'utf8'));
      const nu = { ...D.items[0] };
      for (const champ of ['r', 'w', 'y', 'dep', 'f', 'sk', 'verif']) delete nu[champ];
      nu.id = 'ZZ9';
      D.items.push(nu);
      writeFileSync(path.join(bac2, 'backlog-v34.json'), JSON.stringify(D), 'utf8');

      // 1. le script ne doit pas s'interrompre
      expect(() => execFileSync('node', [SCRIPT, path.join(bac2, 'backlog-v34.json')], {
        encoding: 'utf8',
      })).not.toThrow();

      // 2. et aucun livrable ne doit contenir « undefined » de rendu
      for (const f of SORTIES) {
        const texte = readFileSync(path.join(bac2, f), 'utf8');
        expect(texte).toContain('ZZ9');
        // Le HTML porte deux `!==undefined` dans le script de la page : ce sont
        // des comparaisons JavaScript légitimes, pas du rendu. On les neutralise
        // avant de chercher, plutôt que d'exempter le fichier entier.
        const rendu = f.endsWith('.html') ? texte.split('!==undefined').join('') : texte;
        expect(rendu).not.toMatch(/undefined/);
      }
    } finally {
      rmSync(bac2, { recursive: true, force: true });
    }
  });
});
