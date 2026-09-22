// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/css-accolades-equilibrees.test.js
//
// Du 15/09 au 22/09/2026, `npm run build` a répété à chaque passage
// `[esbuild css minify] ▲ [WARNING] Unexpected "}" [css-syntax-error]
// <stdin>:632:0`, et le build restait vert : un avertissement du minifieur ne
// fait rien rougir, et `<stdin>` ne nomme pas la feuille. C'était une accolade
// fermante restée seule dans PanelPage.css après le retrait d'une règle
// (commit 83e68421) — sans effet dans les navigateurs, qui jettent une
// fermante orpheline, mais un avertissement qu'on apprend à ne plus lire ne
// dit plus rien le jour où il change de sens (E22).
//
// Cette garde compte les accolades de chaque feuille, hors commentaires et
// chaînes, et refuse qu'une fermante précède son ouvrante. Elle rougit AVANT
// le build, en nommant la feuille et la ligne.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const racine = new URL('../../', import.meta.url);
const feuilles = execSync('git ls-files -- "src/**/*.css" "public/**/*.css"', { cwd: racine })
  .toString().split('\n').filter((f) => f.endsWith('.css'));

function premiereOrpheline(css) {
  let prof = 0, ligne = 1, i = 0;
  while (i < css.length) {
    const c = css[i];
    if (c === '\n') { ligne++; i++; continue; }
    if (c === '/' && css[i + 1] === '*') {
      const fin = css.indexOf('*/', i + 2);
      const bloc = css.slice(i, fin < 0 ? css.length : fin + 2);
      ligne += (bloc.match(/\n/g) || []).length; i += bloc.length; continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < css.length && css[j] !== c) { if (css[j] === '\\') j++; j++; }
      i = j + 1; continue;
    }
    if (c === '{') prof++;
    if (c === '}') { prof--; if (prof < 0) return `ligne ${ligne}`; }
    i++;
  }
  return prof === 0 ? null : `fin de fichier avec ${prof} bloc(s) non fermé(s)`;
}

describe('feuilles de style — accolades équilibrées', () => {
  it('le dépôt a des feuilles à vérifier', () => {
    expect(feuilles.length).toBeGreaterThan(20);
  });
  for (const f of feuilles) {
    it(f, () => {
      const defaut = premiereOrpheline(readFileSync(new URL(f, racine), 'utf8'));
      expect(defaut, `${f} : accolade orpheline (${defaut})`).toBeNull();
    });
  }
});
