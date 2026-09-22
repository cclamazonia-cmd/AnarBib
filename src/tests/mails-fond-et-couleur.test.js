// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mails-fond-et-couleur.test.js
//
// Le 21/09/2026, le premier courriel réel de la sonde `images_pins` est arrivé
// BLANC SUR BLANC : son bloc `<pre>` fixait un fond clair (#f4f4f4) sans fixer
// la couleur du texte, qui héritait du blanc du corps. Ce n'était pas un défaut
// de « thème sombre » du client : c'est de l'héritage, et il se produit dans
// n'importe quel client. Le même soir, 27 des 48 styles en ligne à fond de
// nos courriels ne fixaient pas leur couleur (F11).
//
// Deux règles, tenues ici :
//   1. tout élément qui a un fond ET un contenu déclare sa couleur de texte
//      (un trait — élément vide — en est dispensé) ;
//   2. tout document de courriel se déclare sombre (`color-scheme: dark`),
//      puisqu'il l'est par conception : un client qui respecte la déclaration
//      ne l'inversera pas. Ceux qui l'ignorent (Gmail, Outlook) sont couverts
//      par la règle 1, la seule qui ne dépende de personne.
// Ce que cette garde NE prouve PAS : un rendu. Elle lit du HTML. Un courriel
// de chaque famille reste à regarder dans un vrai client (F11, troisième
// critère).

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const racine = new URL('../../', import.meta.url);
const fichiers = execSync('git ls-files -- "supabase/functions/**/*.ts"', { cwd: racine })
  .toString().split('\n').filter(Boolean);

const FOND = /background(?:-color)?\s*:\s*([^;"]+)/;
const COULEUR = /(?<![-\w])color\s*:/;

function fondsSansCouleur(src) {
  const defauts = [];
  for (const m of src.matchAll(/style="([^"]*)"(\s*[^>]*>)/g)) {
    const st = m[1];
    const fond = st.match(FOND);
    if (!fond || ['transparent', 'none'].includes(fond[1].trim()) || COULEUR.test(st)) continue;
    if (src.slice(m.index + m[0].length).startsWith('</')) continue; // élément vide
    defauts.push(`ligne ${src.slice(0, m.index).split('\n').length} : ${st.slice(0, 80)}`);
  }
  return defauts;
}

describe('courriels — tout fond porte sa couleur de texte', () => {
  let vus = 0;
  for (const f of fichiers) {
    const src = readFileSync(new URL(f, racine), 'utf8');
    if (!src.includes('style="')) continue;
    vus++;
    it(f, () => {
      expect(fondsSansCouleur(src)).toEqual([]);
    });
  }
  it('des fichiers ont été lus', () => { expect(vus).toBeGreaterThan(10); });
});

describe('courriels — chaque document se déclare sombre', () => {
  const documents = fichiers.filter((f) => /<body style="[^"]*background/.test(readFileSync(new URL(f, racine), 'utf8')));
  it('les documents de courriel sont trouvés (gabarit commun compris)', () => {
    expect(documents).toContain('supabase/functions/_shared/mail/layout.ts');
    expect(documents.length).toBeGreaterThanOrEqual(8);
  });
  for (const f of documents) {
    it(f, () => {
      const src = readFileSync(new URL(f, racine), 'utf8');
      expect(src).toContain('<meta name="color-scheme" content="dark">');
      expect(src).toContain('<meta name="supported-color-schemes" content="dark">');
    });
  }
});
