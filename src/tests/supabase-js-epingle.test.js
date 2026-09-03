// I16 (03/09/2026) — supabase-js est épinglé en UN SEUL endroit : `_shared/deps.ts`.
// Ce banc casse si une Edge Function importe `@supabase/supabase-js` directement
// (esm.sh, npm:, jsr:) au lieu de passer par le module partagé, ou si `deps.ts`
// épingle autre chose qu'une version exacte. Il relit les fichiers, il n'exécute
// rien : c'est un garde de forme, comme la garde i18n.
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

// vitest tourne depuis la racine du dépôt (comme la garde i18n).
const ROOT = resolve(process.cwd(), 'supabase', 'functions') + '/';

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(ts|js|mjs)$/.test(name)) out.push(p);
  }
  return out;
}

const DIRECT = /from\s+['"](?:https:\/\/esm\.sh\/|npm:|jsr:)@supabase\/supabase-js[@'"]/;

describe('supabase-js : un régime, pas un mélange (I16)', () => {
  const files = walk(ROOT);
  const deps = join(ROOT, '_shared', 'deps.ts');

  it('deps.ts épingle une version exacte, pas une majeure flottante', () => {
    const src = readFileSync(deps, 'utf8');
    const m = src.match(/@supabase\/supabase-js@(\d+\.\d+\.\d+)/);
    expect(m, 'deps.ts doit épingler x.y.z').toBeTruthy();
    expect(src).not.toMatch(/supabase-js@2['"]/);
  });

  it('aucune fonction n’importe supabase-js ailleurs que par deps.ts', () => {
    const fautifs = files
      .filter((f) => f !== deps)
      .filter((f) => DIRECT.test(readFileSync(f, 'utf8')))
      .map((f) => f.slice(ROOT.length));
    expect(fautifs, 'imports directs de supabase-js : ' + fautifs.join(', ')).toEqual([]);
  });

  it('les fonctions qui créent un client passent par deps.ts', () => {
    const viaDeps = files.filter((f) => /from\s+['"](?:\.\.\/)+_shared\/deps\.ts['"]|from\s+['"]\.\.\/deps\.ts['"]/.test(readFileSync(f, 'utf8')));
    // 30 fonctions + env.ts le 03/09 ; le seuil ne fige pas le nombre, il refuse le zéro.
    expect(viaDeps.length).toBeGreaterThanOrEqual(20);
  });
});
