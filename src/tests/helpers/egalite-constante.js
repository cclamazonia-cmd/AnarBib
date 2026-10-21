// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : src/tests/helpers/egalite-constante.js
//
// Le VRAI supabase/functions/_shared/core/egalite-constante.ts (comparaison de
// secrets à durée constante, 21/10/2026), transpilé une fois, pour les bancs
// dont le `require` détourné n'admet qu'une liste fermée d'imports :
//   if (spec.endsWith('egalite-constante.ts')) return EGALITE;
// ═══════════════════════════════════════════════════════════

import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../../supabase/functions/_shared/core/egalite-constante.ts', import.meta.url);
const m = { exports: {} };
new Function('require', 'module', 'exports', transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code)(
  () => { throw new Error('egalite-constante.ts : aucun import attendu'); }, m, m.exports,
);
export const EGALITE = m.exports;
