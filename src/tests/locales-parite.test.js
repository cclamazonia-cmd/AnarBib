// La liste des locales a une source par couche (DOC-I18N-4, 13/10/2026) — côté
// front, src/i18n/locales.js. Ce test tient ce qui ne peut pas l'importer :
// les fichiers JSON des traductions et les dictionnaires indexés par langue
// (noms de langues de la gazette, pistes de sous-titres, pages des recueils,
// documents des Communs). Ajouter une langue à locales.js sans compléter l'un
// d'eux le fait échouer, au lieu d'une langue servie à moitié en silence.
import { describe, it, expect } from 'vitest';
import { readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  LOCALES, LOCALE_CODES, SITE_CODES, SITE_CODE, PHRASE_CASE_CODES, DEFAULT_LOCALE,
} from '../i18n/locales.js';
import { SUPPORTED_LOCALES, isSupported } from '../i18n/index.js';
import { LOCALE_OPTIONS } from '../components/library/LocaleSelector.jsx';
import { LOCALE_NAMES as NOMS_GAZETTE, UI as UI_GAZETTE } from '../pages/federacao/GazetteTab.jsx';
import { LOCALE_NAMES as NOMS_LETTRE } from '../pages/federacao/LettreTab.jsx';
import { BIO_TITLE_KEYS } from '../pages/catalogacao/AuthorDraftForm.jsx';
import { SUBTITLE_LANG } from '../components/account/ReaderTutorialsCard.jsx';
import { COMPLETE_BLOCKS, READER_START, GOVERNANCE_START } from '../lib/docLinks.js';
import { COMMUNS_DOCS } from '../pages/federacao/communsRegistry.js';
import { titleCaseRule } from '../lib/titleCase.js';

const trie = (xs) => [...xs].sort();
const memesCles = (dico) => expect(trie(Object.keys(dico))).toEqual(trie(LOCALE_CODES));

describe('la source unique (src/i18n/locales.js)', () => {
  it('des codes uniques, la locale par défaut en tête', () => {
    expect(new Set(LOCALE_CODES).size).toBe(LOCALES.length);
    expect(LOCALE_CODES[0]).toBe(DEFAULT_LOCALE);
    expect(new Set(SITE_CODES).size).toBe(LOCALES.length);
    expect(SITE_CODE['pt-BR']).toBe('pt');
    for (const l of LOCALES) {
      expect(typeof l.label, l.code).toBe('string');
      expect(typeof l.phraseCase, l.code).toBe('boolean');
      expect(typeof l.listed, l.code).toBe('boolean');
    }
  });

  it('un fichier de traductions par code, ni plus ni moins', () => {
    const fichiers = readdirSync(resolve(__dirname, '../i18n/locales'))
      .filter((f) => f.endsWith('.json')).map((f) => f.replace(/\.json$/, ''));
    expect(trie(fichiers)).toEqual(trie(LOCALE_CODES));
  });

  it("SUPPORTED_LOCALES en dérive, dans l'ordre", () => {
    expect(SUPPORTED_LOCALES.map((l) => l.code)).toEqual(LOCALE_CODES);
    for (const c of LOCALE_CODES) expect(isSupported(c), c).toBe(true);
    expect(isSupported('xx')).toBe(false);
  });

  it('le sélecteur de la langue par défaut d’une bibliothèque offre toutes les langues (6 → 10, 13/10/2026)', () => {
    expect(trie(LOCALE_OPTIONS.map((o) => o.code))).toEqual(trie(LOCALE_CODES));
    expect(LOCALE_OPTIONS[0].code).toBe('pt-BR');
    const suite = LOCALE_OPTIONS.slice(1).map((o) => o.code);
    expect(suite).toEqual([...suite].sort((a, b) => a.localeCompare(b)));
    expect(LOCALE_OPTIONS.find((o) => o.code === 'el').name).toBe('Ελληνικά');
  });

  it('la casse de phrase suit l’attribut phraseCase', () => {
    for (const l of LOCALES) {
      expect(titleCaseRule(l.code), l.code).toBe(l.phraseCase ? 'phrase' : l.code === 'en' ? 'titre' : 'outils');
    }
    expect(trie(PHRASE_CASE_CODES)).toEqual(trie(LOCALES.filter((l) => l.phraseCase).map((l) => l.siteCode)));
  });
});

describe('les dictionnaires indexés par langue ont exactement les clés de LOCALE_CODES', () => {
  it('gazette et lettre : noms des langues, chaînes de rendu', () => {
    memesCles(NOMS_GAZETTE);
    memesCles(UI_GAZETTE);
    memesCles(NOMS_LETTRE);
  });
  it('fiche d’autorité : titres des biographies par langue', () => memesCles(BIO_TITLE_KEYS));
  it('tutoriels vidéo : une piste de sous-titres par langue', () => memesCles(SUBTITLE_LANG));
  it('recueils PDF : pages de départ par langue', () => {
    memesCles(COMPLETE_BLOCKS);
    memesCles(READER_START);
    memesCles(GOVERNANCE_START);
  });
  it('Communs : chaque document traduit l’est dans toutes les langues', () => {
    // Une seule exception, déclarée dans communsRegistry.js : un texte de
    // délibération laissé en français jusqu'à la décision de l'AG.
    const UNE_SEULE_LANGUE = new Set(['note-ag-samizdats']);
    for (const d of COMMUNS_DOCS.filter((x) => x.byLocale)) {
      if (UNE_SEULE_LANGUE.has(d.id)) expect(Object.keys(d.byLocale), d.id).toEqual(['fr']);
      else expect(trie(Object.keys(d.byLocale)), d.id).toEqual(trie(LOCALE_CODES));
    }
  });
});
