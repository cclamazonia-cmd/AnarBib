// Garde anti-dérive des locales (DOC-I18N-4, 13/10/2026).
//
// La liste des locales a une source par couche, et nulle part ailleurs :
//   front           src/i18n/locales.js
//   Edge Functions  supabase/functions/_shared/i18n/locales.ts
//   SQL             public.fn_supported_locales() (dernière migration qui la définit)
//   vitrine         tools/locales.json (dépôt anarbib/pages, gardé là-bas)
// install.sh garde sa liste, tenue par install-sh-locales.test.js ; les
// dictionnaires indexés par langue sont tenus par locales-parite.test.js et
// par les tests de parité des chaînes de mails.
//
// Ce test (1) vérifie que les trois sources du dépôt disent la même chose, dans
// le même ordre ; (2) parcourt src/, supabase/functions/ et les migrations
// postérieures au lot, et ÉCHOUE dès qu'une liste littérale d'au moins cinq
// codes de locale apparaît hors des sources — c'est ainsi qu'une copie oubliée
// refusait une langue en silence (register sans nl ni el le 27/08, install.sh à
// trois langues jusqu'au 20/09, LocaleSelector à six jusqu'au 13/10).
//
// Les listes d'une AUTRE nature (langues d'un fond de carte, d'un thésaurus,
// de mots-outils…) sont nommées une à une dans AUTRES_LISTES, avec leur raison.
// Liste fermée dans les deux sens : une entrée qui ne contient plus de liste
// fait échouer le test (elle ment, on la retire).
//
// Le test n'écrit aucune liste de codes lui-même : ses motifs sont construits
// depuis LOCALE_CODES, pour ne pas se dénoncer.
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve, relative, join } from 'node:path';
import { LOCALES, LOCALE_CODES, SITE_CODES } from '../i18n/locales.js';

const RACINE = resolve(__dirname, '../..');
const lire = (rel) => readFileSync(join(RACINE, rel), 'utf8');

// La migration du lot : les migrations plus anciennes sont des traces (on ne
// réécrit pas l'histoire) ; les suivantes sont gardées.
const LOT = '20261013194812';
const SOURCE_SQL = /CREATE OR REPLACE FUNCTION public\.fn_supported_locales\(\)/;

const SOURCES = new Set([
  'src/i18n/locales.js',
  'supabase/functions/_shared/i18n/locales.ts',
]);

const AUTRES_LISTES = {
  'src/lib/countries.js': 'langues des données i18n-iso-countries (pas d’espéranto), pour relire les pays du fonds hérité',
  'src/lib/languages.js': 'les 36 langues d’un DOCUMENT (champ idioma), pas celles de l’interface',
  'src/lib/mapTiles.js': 'langues d’étiquettes présentes dans le fond Protomaps v4 (ni ca ni eo)',
  'src/lib/nameEntry.js': 'langues dont on a les mots-outils pour la casse des collectivités',
  'src/pages/public/AuthorPage.jsx': 'ordre de priorité des formes variantes d’une autorité (Wikidata)',
  'src/pages/public/FicedlTermPage.jsx': 'les dix langues du thésaurus FICEDL, qui a son propre périmètre',
  'supabase/functions/_shared/capas/sources.ts': 'langues préférées pour le nom d’un éditeur lu chez Inventaire',
  'src/tests/title-case.test.js': 'langues des mots-outils de la migration de casse de phrase (20260904130100)',
};

// ── Détecteur ────────────────────────────────────────────────────────────────
const echappe = (s) => s.replace(/[-]/g, '\\-');
const CODES = [...new Set([...LOCALE_CODES, ...SITE_CODES])].sort((a, b) => b.length - a.length);
const QUOTE = '[\'"`]';
const UN = `${QUOTE}(?:${CODES.map(echappe).join('|')})${QUOTE}(?:::text)?`;
const SEP = '(?:\\s|,|\\|)*';
const LISTE = new RegExp(`${UN}(?:${SEP}${UN}){4,}`, 'g');
const CODE = new RegExp(`(?:${CODES.map(echappe).join('|')})`, 'g');

/** Listes de ≥ 5 codes DISTINCTS, hors lignes de commentaire. */
export function listesDeLocales(texte) {
  const sansCommentaires = texte.split('\n')
    .map((l) => (/^\s*(\/\/|\/\*|\*|--|#)/.test(l) ? '' : l))
    .join('\n');
  const trouvees = [];
  for (const m of sansCommentaires.matchAll(LISTE)) {
    const codes = new Set(m[0].match(CODE));
    if (codes.size >= 5) {
      trouvees.push({ ligne: sansCommentaires.slice(0, m.index).split('\n').length, codes: [...codes] });
    }
  }
  return trouvees;
}

function fichiers(dir, ext) {
  const out = [];
  for (const nom of readdirSync(join(RACINE, dir))) {
    const rel = `${dir}/${nom}`;
    if (nom === 'node_modules') continue;
    if (statSync(join(RACINE, rel)).isDirectory()) out.push(...fichiers(rel, ext));
    else if (ext.test(nom)) out.push(rel);
  }
  return out;
}

const migrations = readdirSync(join(RACINE, 'supabase/migrations'))
  .filter((f) => /^\d{14}_.*\.sql$/.test(f)).sort();

describe('les trois sources du dépôt disent la même chose', () => {
  it('Edge Functions : _shared/i18n/locales.ts = src/i18n/locales.js (champs et ordre)', () => {
    const ts = lire('supabase/functions/_shared/i18n/locales.ts');
    const lignes = [...ts.matchAll(/\{\s*code:\s*"([^"]+)",\s*label:\s*"([^"]+)",\s*siteCode:\s*"([^"]+)",\s*phraseCase:\s*(true|false),\s*listed:\s*(true|false)\s*\}/g)]
      .map((m) => ({ code: m[1], label: m[2], siteCode: m[3], phraseCase: m[4] === 'true', listed: m[5] === 'true' }));
    expect(lignes).toEqual(LOCALES);
  });

  it('SQL : la dernière définition de public.fn_supported_locales() rend LOCALE_CODES, dans l’ordre', () => {
    const def = migrations.filter((f) => SOURCE_SQL.test(lire(`supabase/migrations/${f}`))).pop();
    expect(def, 'aucune migration ne définit fn_supported_locales').toBeDefined();
    const corps = lire(`supabase/migrations/${def}`).split(SOURCE_SQL)[1];
    const tableau = corps.match(/ARRAY\[([^\]]*)\]/);
    expect(tableau).not.toBeNull();
    expect(tableau[1].split(',').map((s) => s.trim().replace(/^'|'$/g, ''))).toEqual(LOCALE_CODES);
  });
});

describe('aucune liste de locales en dur hors des sources', () => {
  const cibles = [
    ...fichiers('src', /\.(js|jsx|mjs|cjs|ts|tsx)$/),
    ...fichiers('supabase/functions', /\.(ts|js|mjs)$/),
    ...migrations.filter((f) => f.slice(0, 14) >= LOT).map((f) => `supabase/migrations/${f}`),
  ];

  it('le détecteur voit une liste et ignore un commentaire (témoin)', () => {
    const q = (c) => `'${c}'`;
    const liste = `const X = [${LOCALE_CODES.slice(0, 5).map(q).join(', ')}];`;
    expect(listesDeLocales(liste)).toHaveLength(1);
    expect(listesDeLocales(`// ${liste}`)).toHaveLength(0);
    expect(listesDeLocales(`const Y = [${LOCALE_CODES.slice(0, 4).map(q).join(', ')}];`)).toHaveLength(0);
  });

  it('chaque liste trouvée est une source ou une exception nommée', () => {
    const fautes = [];
    for (const f of cibles) {
      if (SOURCES.has(f) || AUTRES_LISTES[f]) continue;
      if (f.startsWith('supabase/migrations/') && SOURCE_SQL.test(lire(f))) continue;
      for (const l of listesDeLocales(lire(f))) fautes.push(`${f}:${l.ligne} [${l.codes.join(',')}]`);
    }
    expect(fautes, `liste de locales recopiée — importer LOCALE_CODES (src/i18n/locales.js, _shared/i18n/locales.ts) ou lire public.fn_supported_locales()`).toEqual([]);
  });

  it('les exceptions nommées contiennent encore une liste (liste fermée dans les deux sens)', () => {
    for (const f of Object.keys(AUTRES_LISTES)) {
      expect(listesDeLocales(lire(f)).length, `${f} n'a plus de liste : retirer l'entrée`).toBeGreaterThan(0);
    }
  });
});
