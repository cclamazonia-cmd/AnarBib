// CHEMIN DÉPÔT : src/tests/appicon-sans-emoji.test.js
//
// E32 (IDENT-Q1, 10/10/2026) : plus aucune déclaration d'icône en emoji dans
// src/ — `icon: '📚'`, `icon="📚"`, `name="📚"` sont des noms AppIcon désormais
// (IDENT-5 à IDENT-8), et la table LEGACY d'AppIcon, déclarée transitoire le
// 05/10, est sortie. La garde lit tout src/ hors tests et locales : une
// déclaration d'icône qui porte un pictogramme rougit, avec le fichier
// et la ligne. Un pictogramme (U+1F000 et au-delà, ou l'un des signes que
// LEGACY traduisait : ⚠ ✅ ✍ ✒ ✉ ☀ ⚖ ⏳) est une icône ; un glyphe typographique
// (◐ ↕ ↖ ⏸ ⌨ ⛓ ✓, rendu en texte par le widget d'accessibilité ou une pastille
// d'état) n'en est pas une et reste du ressort des écrans.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '..');
function fichiers(dir, out = []) {
  for (const f of readdirSync(dir)) {
    const p = path.join(dir, f);
    if (statSync(p).isDirectory()) { if (!['tests', 'locales'].includes(f)) fichiers(p, out); }
    else if (/\.(jsx?|tsx?)$/.test(f)) out.push(p);
  }
  return out;
}
const PICTO = /[\u{1F000}-\u{1FAFF}⚠✅✍✒✉☀⚖⏳]/u;
const DECLARATION = /(?:icon:\s*|icon=|name=)(['"])([^'"\n]+)\1/g;

describe('AppIcon — plus aucune icône déclarée en emoji (E32)', () => {
  it('aucune déclaration icon:/icon=/name= ne porte un pictogramme dans src/', () => {
    const fautes = [];
    for (const p of fichiers(RACINE)) {
      const lignes = readFileSync(p, 'utf8').split('\n');
      lignes.forEach((l, i) => {
        for (const m of l.matchAll(DECLARATION)) {
          if (PICTO.test(m[2])) fautes.push(`${path.relative(RACINE, p)}:${i + 1} ${m[0]}`);
        }
      });
    }
    expect(fautes, fautes.join('\n')).toEqual([]);
  });

  it('AppIcon n’a plus de table LEGACY', () => {
    const src = readFileSync(path.join(RACINE, 'components/ui/AppIcon.jsx'), 'utf8');
    expect(src).not.toContain('const LEGACY');
  });
});
