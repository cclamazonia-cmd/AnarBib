// ═══════════════════════════════════════════════════════════
// AnarBib — une grille rétrécit avec son conteneur (MOB-1, E9 ; 05/10/2026).
//
// Une piste `1fr` vaut `minmax(auto, 1fr)` : son minimum est la largeur
// min-content du contenu, et un formulaire dense fait sortir la grille du
// panneau. De même `repeat(auto-fit, minmax(240px, 1fr))` impose 240 px à une
// colonne seule dans un conteneur plus étroit. Les formes gardées :
// `minmax(0, 1fr)` et `minmax(min(240px, 100%), 1fr)`.
//
// a0daa480 (20/08) avait gardé les 24 grilles inline (MOB-Q1) — sans garde de
// test : cinq déclarations non gardées sont revenues avec des écrans neufs
// (numérotation 15/09, dédoublonnage 28/09, panneau de catalogue 04/10).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const SRC = path.resolve(__dirname, '..');
function fichiers(dossier, ext) {
  const out = [];
  for (const n of readdirSync(dossier)) {
    const p = path.join(dossier, n);
    if (statSync(p).isDirectory()) { if (n !== 'tests') out.push(...fichiers(p, ext)); } else if (ext.test(n)) out.push(p);
  }
  return out;
}
const rel = (f) => path.relative(SRC, f).replace(/\\/g, '/');

// Retire les minmax(…) (parenthèses imbriquées comprises) et rend ce qui reste.
function horsMinmax(v) {
  let s = '', i = 0;
  while (i < v.length) {
    if (v.startsWith('minmax(', i)) {
      let j = i + 7, prof = 1;
      while (j < v.length && prof) { if (v[j] === '(') prof++; else if (v[j] === ')') prof--; j++; }
      s += ' '; i = j;
    } else s += v[i++];
  }
  return s;
}
// Une piste fr hors de tout minmax(…).
export const pisteNue = (v) => /(^|[\s,(])\d*\.?\d+fr\b/.test(horsMinmax(v));
// Un minmax(<longueur fixe>, …) : le minimum ne cède pas sous la largeur du conteneur.
export const minimumFixe = (v) => /minmax\(\s*\d*\.?\d+(px|rem|em|ch)\s*,/.test(v);

// Les valeurs de grille : en JSX/JS, les littéraux d'une propriété gridTemplate* ;
// en CSS, la valeur des déclarations grid-template-*.
function valeursJs(src) {
  const out = [];
  for (const m of src.matchAll(/gridTemplate(?:Columns|Rows)\s*:\s*([^\n]*)/g)) {
    for (const l of m[1].matchAll(/(['"`])([^'"`]*?)\1/g)) if (/fr\b|minmax/.test(l[2])) out.push(l[2]);
  }
  return out;
}
function valeursCss(src) {
  const sansCommentaires = src.replace(/\/\*[\s\S]*?\*\//g, '');
  return [...sansCommentaires.matchAll(/grid-template-(?:columns|rows)\s*:\s*([^;}]*)/g)].map((m) => m[1]);
}

const FAUTES = [];
for (const f of fichiers(SRC, /\.(jsx?|tsx?)$/)) for (const v of valeursJs(readFileSync(f, 'utf8'))) {
  if (pisteNue(v) || minimumFixe(v)) FAUTES.push(`${rel(f)} : ${v}`);
}
for (const f of fichiers(SRC, /\.css$/)) for (const v of valeursCss(readFileSync(f, 'utf8'))) {
  if (pisteNue(v) || minimumFixe(v)) FAUTES.push(`${rel(f)} : ${v.trim()}`);
}

describe('les grilles rétrécissent avec leur conteneur (MOB-1)', () => {
  it('le lecteur reconnaît les formes fautives et les formes gardées', () => {
    expect(pisteNue('1fr 1fr')).toBe(true);
    expect(pisteNue('repeat(3, 1fr)')).toBe(true);
    expect(pisteNue('minmax(0, 1fr) 340px')).toBe(false);
    expect(pisteNue('repeat(auto-fit, minmax(min(240px, 100%), 1fr))')).toBe(false);
    expect(minimumFixe('repeat(auto-fit, minmax(240px, 1fr))')).toBe(true);
    expect(minimumFixe('repeat(auto-fit, minmax(min(240px, 100%), 1fr))')).toBe(false);
    expect(minimumFixe('minmax(0, 1fr)')).toBe(false);
  });

  it('aucune grille de src/ ne garde une piste fr nue ni un minimum fixe', () => {
    expect(FAUTES).toEqual([]);
  });
});
