// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : src/tests/helpers/journal-masque.js
//
// Le VRAI module de masque des adresses (F19, 30/09/2026), pour les bancs qui
// chargent une fonction Edge avec une liste fermée d'imports : la couche d'envoi
// et plusieurs fonctions l'importent désormais. Il n'importe rien lui-même et ne
// s'installe pas sous Node (il attend `Deno.inspect`) : le rendre tel quel
// n'altère pas la console de vitest, et les journaux des bancs sont masqués
// comme en production par les appels explicites à `masquerAdresse`.
// ═══════════════════════════════════════════════════════════

import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../../supabase/functions/_shared/core/journal-masque.ts', import.meta.url);
const code = transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const mod = { exports: {} };
new Function('module', 'exports', code)(mod, mod.exports);

export const JOURNAL_MASQUE = mod.exports;
