// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/title-case.test.js
//
// C6 §7.2 — la règle de casse côté saisie est le MIROIR de
// public.fn_conv_lower_stopwords. Les cas ci-dessous sont repris à l'identique
// dans tests/sql/title_case_tests.sql, qui les passe à la fonction SQL : si
// l'une des deux implémentations dérive, l'un des deux bancs rougit.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { lowerStopwords, hasTitleCaseRule, normaliserCasse, proposerCasse, stopwordsFor } from '../lib/titleCase.js';

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
    expect(hasTitleCaseRule('el')).toBe(true);     // casse de phrase depuis le 27/09
    expect(hasTitleCaseRule('ru')).toBe(false);
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

// Le bouton, depuis le 27/09 : la casse de la langue (spec §4.1), pas seulement
// les mots-outils. Le premier cas est la remarque de Xavier.
export const CAS_BOUTON = [
  ['lE tRuc qui FAIT cHIER', 'fr', 'Le truc qui fait chier'],
  ['Le Mouvement Anarchiste En France', 'fr', 'Le mouvement anarchiste en France'],
  ['Le mouvement anarchiste en France', 'fr', 'Le mouvement anarchiste en France'],
  ['La C.N.T. Y La Revolución', 'es', 'La C.N.T. y la revolución'],
  ['La CNT Y La Revolución', 'es', 'La CNT y la revolución'],
  ['¿QUÉ ES LA PROPIEDAD?', 'es', '¿Qué es la propiedad?'],
  ['Capítulo IV Do Livro XIX', 'pt-BR', 'Capítulo IV do livro XIX'],
  ['O Anarquismo: Uma Introdução', 'pt-BR', 'O anarquismo: Uma introdução'],
  ["L'ANARCHIE", 'fr', "L'anarchie"],
  ['MI VIDA', 'es', 'Mi vida'],
  ['CNT', 'es', 'CNT'],
  ['the story of CRASS', 'en', 'The Story of Crass'],
  ["A PEOPLE'S HISTORY OF THE UNITED STATES", 'en', "A People's History of the United States"],
  ['Die Revolution Und Der Staat', 'de', 'Die Revolution und der Staat'],
  ['ΕΛΕΥΘΕΡΙΑ ΚΑΙ ΑΝΑΡΧΙΑ', 'el', 'Ελευθερια και αναρχια'],
];

// Les noms propres attestés (src/lib/nomsPropres.js). Mêmes cas dans tests/sql/casse_titre_tests.sql.
export const CAS_DICO = [
  ['Tratado Geral Do Brasil', 'pt-BR', 'Tratado geral do Brasil'],
  ['La Guerra Civil En España', 'es', 'La guerra civil en España'],
  ['Da Escravidao Nos Estados Unidos', 'pt-BR', 'Da escravidao nos Estados Unidos'],
  ['Conversaciones Con Bakunin', 'es', 'Conversaciones con Bakunin'],
  ['The doctrine of anarchism of Michael A. Bakunin', 'en', 'The Doctrine of Anarchism of Michael A. Bakunin'],
  ['Congreso De La Confederación Nacional Del Trabajo', 'es', 'Congreso de la Confederación Nacional del Trabajo'],
  ['Anarquismo e Estado', 'pt-BR', 'Anarquismo e estado'],
];

describe('normaliserCasse — le bouton (spec §4.1)', () => {
  for (const [titre, langue, attendu] of [...CAS_BOUTON, ...CAS_DICO]) {
    it(`${langue} : ${titre}`, () => expect(normaliserCasse(titre, langue)).toBe(attendu));
  }

  it('le sous-titre ne prend pas de majuscule initiale', () => {
    expect(normaliserCasse('Uma Introdução Ao Tema', 'pt-BR', { sousTitre: true })).toBe('uma introdução ao tema');
  });

  it('sigles et chiffres romains sont marqués figés (le clic « nom propre » ne les touche pas)', () => {
    const { mots } = proposerCasse('La CNT En 1936 Tomo II', 'es');
    expect(mots.filter((m) => m.fige).map((m) => m.texte)).toEqual(['CNT', '1936', 'II']);
  });

  it('langue sans règle : rien', () => {
    expect(proposerCasse('Война И Мир', 'ru')).toBeNull();
    expect(normaliserCasse('Война И Мир', 'ru')).toBe('Война И Мир');
  });
});

describe('la règle côté base est le miroir du bouton', () => {
  const racine = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
  const dir = path.join(racine, 'supabase/migrations');
  const derniere = (motif) => readdirSync(dir).filter((x) => motif.test(x)).sort().pop();
  const mig = readFileSync(path.join(dir, derniere(/^\d{14}_c6_la_casse_de_la_langue_cote_base\.sql$/)), 'utf8');
  const tableauSql = (nom) => {
    const bloc = mig.match(new RegExp(`function private\\.${nom}\\(\\)[\\s\\S]*?select array\\[([\\s\\S]*?)\\]::text\\[\\]`));
    return [...bloc[1].matchAll(/'((?:[^']|'')*)'/g)].map((m) => m[1].replace(/''/g, "'"));
  };

  it('le dictionnaire SQL est celui de src/lib/nomsPropres.js', async () => {
    const { NOMS_PROPRES_MOTS, NOMS_PROPRES_PHRASES } = await import('../lib/nomsPropres.js');
    expect(tableauSql('conv_noms_propres_mots')).toEqual(NOMS_PROPRES_MOTS);
    expect(tableauSql('conv_noms_propres_phrases')).toEqual(NOMS_PROPRES_PHRASES);
  });

  it('les mots-outils SQL sont ceux du JS', () => {
    for (const l of ['pt', 'es', 'fr', 'it', 'en', 'ca', 'eo', 'de']) {
      const bloc = mig.match(new RegExp(`when p_lang like '${l}%' then array\\[([^\\]]*)\\]`));
      expect(bloc, l).not.toBeNull();
      expect([...bloc[1].matchAll(/'((?:[^']|'')*)'/g)].map((m) => m[1]), l).toEqual([...stopwordsFor(l)]);
    }
  });

  it('la suite SQL porte les mêmes cas que ce banc', () => {
    const suite = readFileSync(path.join(racine, 'tests/sql/casse_titre_tests.sql'), 'utf8');
    for (const [titre, , attendu] of [...CAS_BOUTON, ...CAS_DICO]) {
      expect(suite.includes(`'${titre.replace(/'/g, "''")}'`), titre).toBe(true);
      expect(suite.includes(`'${attendu.replace(/'/g, "''")}'`), attendu).toBe(true);
    }
  });
});
