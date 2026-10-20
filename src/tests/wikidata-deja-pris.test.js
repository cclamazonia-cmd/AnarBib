// 20/10/2026 — Un Wikidata, une seule fiche (cas Q51862284).
//
// La base refuse un Wikidata déjà porté par une autre fiche (déclencheur sur
// public.authors, 20261020174755) : hint 'error.catalog.wikidata_already_used',
// DETAIL JSON {qid, author_id, name}. Le refus ne sert que s'il nomme l'autre
// fiche — c'est elle qu'il faut fusionner. Ici : localizeError passe le DETAIL
// à la traduction, et la clé existe partout avec ses trois valeurs.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createIntl, createIntlCache } from 'react-intl';
import { localizeError } from '../lib/localizeError';
import { LOCALE_CODES } from '../i18n/locales.js';

const ROOT = join(__dirname, '..', '..');
const CLE = 'error.catalog.wikidata_already_used';
const locale = (loc) => JSON.parse(readFileSync(join(ROOT, `src/i18n/locales/${loc}.json`), 'utf8'));

// L'erreur telle que PostgREST la rend pour le RAISE de private.fn_autorite_wikidata_libre.
const refus = {
  code: 'P0001',
  message: 'Wikidata Q51862284 déjà porté par la fiche n° 10907 (José Luis Gutiérrez Molina) — fusionner les deux fiches plutôt que recopier l\'identifiant',
  hint: CLE,
  details: '{"qid": "Q51862284", "name": "José Luis Gutiérrez Molina", "author_id": 10907}',
};

describe('localizeError — Wikidata déjà porté par une autre fiche', () => {
  it('le message nomme l\'autre fiche (DETAIL → valeurs de la traduction)', () => {
    const intl = createIntl({ locale: 'fr', messages: locale('fr') }, createIntlCache());
    const texte = localizeError(refus, intl.formatMessage);
    expect(texte).toContain('Q51862284');
    expect(texte).toContain('José Luis Gutiérrez Molina');
    expect(texte).toContain('10907');
    expect(texte).toMatch(/fusionne/);
  });
  it('un DETAIL qui n\'est pas du JSON ne change rien', () => {
    const t = ({ id }, values) => `<${id}${values ? ' avec valeurs' : ''}>`;
    expect(localizeError({ code: 'P0001', message: 'x', hint: 'error.foo.bar', details: 'texte libre' }, t))
      .toBe('<error.foo.bar>');
    expect(localizeError({ code: 'P0001', message: 'x', hint: 'error.foo.bar' }, t)).toBe('<error.foo.bar>');
  });
  it('la clé existe dans toutes les locales, avec {qid}, {name} et {author_id}', () => {
    for (const loc of LOCALE_CODES) {
      const m = locale(loc)[CLE];
      expect(m, loc).toBeTruthy();
      for (const v of ['{qid}', '{name}', '{author_id}']) expect(m, `${loc} ${v}`).toContain(v);
    }
  });
});

describe('wd-rapprocher.mjs écarte un qid déjà en base', () => {
  const src = readFileSync(join(ROOT, 'docs/journal/operations/enrichissement-autorites-2026-09-26/wd-rapprocher.mjs'), 'utf8');
  it('exige le relevé QIDS_EN_BASE (authors.json ne dit pas tout ce qui est pris)', () => {
    expect(src).toMatch(/process\.env\.QIDS_EN_BASE/);
    expect(src).toMatch(/process\.exit\(2\)/);
  });
  it('un qid porté ailleurs donne « deja_pris », sans qid retenu', () => {
    expect(src).toMatch(/decision = 'deja_pris'; retenu = null;/);
  });
});
