// @vitest-environment node
//
// E4 (20/10/2026) — l'italien applique sa convention des paires irrégulières.
//
// La charte (docs/notes-audit/anarbib-charte-langage-inclusif-v2.md, § Italien,
// adoptée le 05/06) : astérisque pour les paires régulières (`compagn*`), SLASH
// ABRÉGÉ pour les irrégulières en -tore/-trice (`lettore/trice`, pluriel
// `lettori/trici`) ; l'astérisque y est fautif (`lettor*` suppose un féminin
// `lettora` qui n'existe pas), le point médian n'est jamais un marqueur de
// genre. Le 20/10, l'interface et les courriels portaient encore 51 astérisques
// fautifs (`amministratori*`, `autor*`, `Lettor*rice`…), 6 paires développées
// (`autore/autrice`) et 4 points médians ; rien ne gardait la règle.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const it_ = JSON.parse(readFileSync(path.join(RACINE, 'src/i18n/locales/it.json'), 'utf8'));
const MAILS = readFileSync(path.join(RACINE, 'supabase/functions/_shared/i18n/mail-strings.ts'), 'utf8');

function feuilles(o, p = '') {
  if (o && typeof o === 'object') return Object.entries(o).flatMap(([k, v]) => feuilles(v, p ? `${p}.${k}` : k));
  return typeof o === 'string' ? [[p, o]] : [];
}
const CHAINES = [
  ...feuilles(it_),
  ...MAILS.split('\n').map((l, i) => [`mail-strings.ts:${i + 1}`, l]).filter(([, l]) => /^\s*it:\s*["'`]/.test(l)),
];
const fautes = (re) => CHAINES.filter(([, v]) => re.test(v)).map(([k, v]) => `${k} : ${v.slice(0, 90)}`);

describe('E4 — paires irrégulières de l’italien (charte § Italien)', () => {
  it('jamais d’astérisque sur une forme en -tore/-tori (lettor*, amministratori*)', () => {
    expect(fautes(/\p{L}+tor[ei]?\*/u)).toEqual([]);
  });

  it('jamais de paire développée (autore/autrice) : le slash abrégé (autore/trice)', () => {
    // une lettre avant le slash : une adresse (https://editrice.example…) n'est pas une paire
    expect(fautes(/\p{L}\/\p{L}+tric[ei]\b/u)).toEqual([]);
  });

  it('jamais de point médian comme marqueur de genre (lettore·trice)', () => {
    expect(fautes(/\p{L}·\p{L}/u)).toEqual([]);
  });

  it('la forme de la charte est bien celle de l’interface', () => {
    const tout = CHAINES.map(([, v]) => v).join('\n');
    for (const f of ['lettore/trice', 'amministratore/trice', 'coordinatore/trice', 'amministratori/trici', 'autore/trice']) {
      expect(tout).toContain(f);
    }
  });
});
