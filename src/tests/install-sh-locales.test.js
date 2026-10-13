// install.sh ne peut rien importer : il garde ses listes de langues, et ce test
// les tient contre la source unique (DOC-I18N-4, 13/10/2026). Avant le 20/09,
// install.sh ne connaissait que fr, en et pt et refusait les sept autres par
// `exit 2` — alors que les dix pages « auto-hébergement » de la vitrine
// donnaient `./install.sh --lang <leur locale>` (DOC-I18N-2). Une langue
// ajoutée à src/i18n/locales.js fait désormais échouer ce test tant qu'install.sh
// ne la connaît pas partout : en-tête, détection, --lang (deux fois), message
// d'erreur et table t() complète.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { SITE_CODES } from '../i18n/locales.js';

const script = readFileSync(resolve(__dirname, '../../install.sh'), 'utf8');
const trie = (xs) => [...xs].sort();
const alternance = (ligne) => ligne.trim().split(')')[0].split('|');
// Lignes « a|b|c) LANG_CODE=… » : la détection et les deux lectures de --lang.
const cas = [...script.matchAll(/^\s*([a-z]{2}(?:\|[a-z]{2})+)\)\s*LANG_CODE=/gm)].map((m) => alternance(m[1]));
// La table t() : de « t() { » à la première accolade fermante en colonne 0.
const debutT = script.indexOf('\nt() {');
const tableT = script.slice(debutT, script.indexOf('\n}', debutT));

describe('install.sh connaît exactement les langues de l’app (codes du site)', () => {
  it("l'en-tête d'usage les annonce", () => {
    const m = script.match(/^#\s+--lang:\s+(.+)$/m);
    expect(m).not.toBeNull();
    expect(trie(m[1].trim().split(/\s+/))).toEqual(trie(SITE_CODES));
  });

  it('trois lignes de cas : la détection (en en repli) puis --lang lu deux fois', () => {
    expect(cas).toHaveLength(3);
    const [detection, prescan, analyse] = cas;
    expect(trie([...detection, 'en'])).toEqual(trie(SITE_CODES));
    expect(script).toMatch(/^\s*\*\)\s+LANG_CODE="en" ;;$/m);
    expect(trie(prescan)).toEqual(trie(SITE_CODES));
    expect(trie(analyse)).toEqual(trie(SITE_CODES));
  });

  it('le message err_lang existe dans chaque langue et énumère toutes les valeurs acceptées', () => {
    for (const l of SITE_CODES) {
      const m = tableT.match(new RegExp(`^\\s+${l}:err_lang\\)\\s+echo "(.*)" ;;$`, 'm'));
      expect(m, l).not.toBeNull();
      const valeurs = m[1].match(/([a-z]{2}(?:, [a-z]{2})+)\s*$/);
      expect(valeurs, l).not.toBeNull();
      expect(trie(valeurs[1].split(', ')), l).toEqual(trie(SITE_CODES));
    }
  });

  it('la table t() a les mêmes clés dans chaque langue, et aucune autre langue', () => {
    const cles = {};
    for (const m of tableT.matchAll(/^\s+([a-z]{2}):([A-Za-z0-9_]+)\)/gm)) {
      (cles[m[1]] ||= new Set()).add(m[2]);
    }
    expect(trie(Object.keys(cles))).toEqual(trie(SITE_CODES));
    const reference = trie(cles.en);
    expect(reference.length).toBeGreaterThanOrEqual(83);   // 83 clés au 20/09/2026 (DOC-I18N-2)
    for (const l of SITE_CODES) expect(trie(cles[l]), l).toEqual(reference);
  });
});
