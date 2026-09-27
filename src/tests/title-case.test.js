// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/title-case.test.js
//
// C6 §7.2 — la règle de casse côté saisie est le MIROIR de
// public.fn_conv_lower_stopwords. Les cas ci-dessous sont repris à l'identique
// dans tests/sql/title_case_tests.sql, qui les passe à la fonction SQL : si
// l'une des deux implémentations dérive, l'un des deux bancs rougit.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { lowerStopwords, hasTitleCaseRule } from '../lib/titleCase.js';

export const CAS = [
  ['A Revolução Desconhecida', 'pt-BR', 'A Revolução Desconhecida'],
  ['História Do Anarquismo No Brasil', 'pt-BR', 'História do Anarquismo no Brasil'],
  ['La C.N.T. Y La Revolución', 'es', 'La C.N.T. y la Revolución'],
  ['Durruti - Da Revolta a Revolução', 'pt-BR', 'Durruti - Da Revolta a Revolução'],
  ['The Story Of Crass', 'en', 'The Story of Crass'],
  ['Die Revolution Und Der Staat', 'de', 'Die Revolution und der Staat'],
  ['Ελευθερία Και Αναρχία', 'el', 'Ελευθερία Και Αναρχία'],
  ['O Anarquismo: Uma Introdução', 'pt-BR', 'O Anarquismo: Uma Introdução'],
  ['Anarquia  E   Organização', 'pt-BR', 'Anarquia e Organização'],
  ['Capítulo IV Do Livro', 'pt-BR', 'Capítulo IV do Livro'],
  ['Le Monde Et La Guerre Des Classes', 'fr', 'Le Monde et la Guerre des Classes'],
  ['Storia Dell Anarchismo In Italia', 'it', 'Storia Dell Anarchismo in Italia'],
];

describe('titleCase — miroir de fn_conv_lower_stopwords', () => {
  for (const [titre, langue, attendu] of CAS) {
    it(`${langue} : ${titre}`, () => expect(lowerStopwords(titre, langue)).toBe(attendu));
  }

  it('sans langue, ou langue non couverte : rien ne bouge et le bouton est inactif', () => {
    expect(lowerStopwords('A Revolução', null)).toBe('A Revolução');
    expect(hasTitleCaseRule('')).toBe(false);
    expect(hasTitleCaseRule('el')).toBe(false);
    expect(hasTitleCaseRule('pt-BR')).toBe(true);
  });

  it('les listes de mots-outils sont celles de la fonction SQL', () => {
    const racine = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
    const sql = readFileSync(path.join(racine, 'supabase/migrations/20260821090000_conventions_07_tiret_sous_titre.sql'), 'utf8');
    const js = readFileSync(path.join(racine, 'src/lib/titleCase.js'), 'utf8');
    const listesSql = [...sql.matchAll(/when p_lang like '(\w+)%' then array\[([\s\S]*?)\]/g)]
      .map(([, l, mots]) => [l, [...mots.matchAll(/'([^']+)'/g)].map((m) => m[1])]);
    expect(listesSql).toHaveLength(8);
    for (const [langue, mots] of listesSql) {
      const bloc = js.match(new RegExp(`\\['${langue}', \\[([\\s\\S]*?)\\]\\]`));
      expect(bloc, `liste ${langue} absente du JS`).not.toBeNull();
      expect([...bloc[1].matchAll(/'([^']+)'/g)].map((m) => m[1])).toEqual(mots);
    }
  });

  it('le formulaire de notice monte l’assistant sous le titre', () => {
    const racine = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
    const src = readFileSync(path.join(racine, 'src/pages/catalogacao/BookDraftForm.jsx'), 'utf8');
    expect(src).toMatch(/<TitleCaseAssist titulo=\{f\('titulo'\)\} subtitulo=\{f\('subtitulo'\)\} idioma=\{f\('idioma'\)\}/);
  });
});
