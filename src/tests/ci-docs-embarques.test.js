// Garde (08/09/2026) : aucun document embarqué dans le front (`import … from
// '../../../docs/….md?raw'`) ne doit être couvert par le `paths-ignore` de
// .forgejo/workflows/ci.yml — sinon une retouche de ce document ne déclenche
// aucun build et l'écran en ligne garde l'ancien texte, sans rouge nulle part.
// Vécu : la note ajoutée au cadrage Entraide (1f2d9aba) sous « docs/** ».
//
// Motifs gérés : `**` (tout, y compris /), `*` (tout sauf /). C'est la grammaire
// des filtres Forgejo/GitHub, dont on ne suppose rien d'autre.
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = process.cwd();

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(jsx?|tsx?)$/.test(name)) out.push(p);
  }
  return out;
}

function importsRaw() {
  const found = new Set();
  for (const f of walk(join(ROOT, 'src'))) {
    const src = readFileSync(f, 'utf8');
    const dirOfFile = join(f, '..');
    for (const m of src.matchAll(/from\s+['"]([^'"]+)\?raw['"]/g)) {
      const abs = join(dirOfFile, m[1]);
      found.add(relative(ROOT, abs).split('\\').join('/'));
    }
  }
  return [...found].sort();
}

function pathsIgnore() {
  const yml = readFileSync(join(ROOT, '.forgejo/workflows/ci.yml'), 'utf8');
  const block = yml.match(/^\s*paths-ignore:\s*\n((?:\s*-\s*'[^']+'\s*\n)+)/m);
  if (!block) throw new Error('paths-ignore introuvable dans ci.yml');
  return [...block[1].matchAll(/-\s*'([^']+)'/g)].map((m) => m[1]);
}

function globToRegExp(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === '*') {
      if (glob[i + 1] === '*') { re += '.*'; i++; if (glob[i + 1] === '/') i++; }
      else re += '[^/]*';
    } else re += c.replace(/[.+?^${}()|[\]\\]/g, '\\$&');
  }
  return new RegExp(`^${re}$`);
}

describe('CI : les documents embarqués ne sont pas ignorés par le filtre', () => {
  const docs = importsRaw();
  const ignores = pathsIgnore();

  it('au moins un document est embarqué et le filtre existe', () => {
    expect(docs.length).toBeGreaterThan(50);
    expect(ignores.length).toBeGreaterThan(5);
    expect(ignores).not.toContain('docs/**');
    expect(ignores).not.toContain('**/*.md');
  });

  it('aucun motif de paths-ignore ne couvre un document importé en ?raw', () => {
    const couverts = [];
    for (const d of docs) {
      for (const g of ignores) if (globToRegExp(g).test(d)) couverts.push(`${d}  ←  ${g}`);
    }
    expect(couverts).toEqual([]);
  });

  it('chaque document importé existe sur le disque', () => {
    const absents = docs.filter((d) => { try { statSync(join(ROOT, d)); return false; } catch { return true; } });
    expect(absents).toEqual([]);
  });
});
