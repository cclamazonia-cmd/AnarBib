// _shared/i18n/locales.ts (DOC-I18N-4, 13/10/2026) pour les harnais qui
// évaluent une Edge Function avec un `require` détourné : le VRAI module,
// transpilé une fois (il n'importe rien), rendu à tout import de « …/locales.ts ».
// Sans lui, mail-strings.ts & co. évalués avec `() => ({})` perdaient leur
// liste de locales, et les harnais à liste fermée refusaient l'import neuf.
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../../supabase/functions/_shared/i18n/locales.ts', import.meta.url);
const CODE = transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;

let module_ = null;

/** Les exports du vrai locales.ts. */
export function localesTs() {
  if (!module_) {
    const m = { exports: {} };
    new Function('module', 'exports', CODE)(m, m.exports);
    module_ = m.exports;
  }
  return module_;
}

/** Enrobe un `require` détourné : locales.ts est servi, le reste délégué. */
export const avecLocales = (req) => (spec) => (/(^|\/)locales\.ts$/.test(spec) ? localesTs() : req(spec));
