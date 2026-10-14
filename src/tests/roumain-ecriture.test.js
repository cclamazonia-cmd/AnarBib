// Le roumain s'écrit à la virgule souscrite et au tutoiement (DOC-I18N-5, D3 et
// D4, décisions du 13/10/2026). Deux règles mécaniques, posées AVANT ro.json pour
// qu'aucune traduction, aucun courriel ni aucun copier-coller ne les manque :
//   (D4) ș ț Ș Ț (U+0219 U+021B U+0218 U+021A) — jamais ş ţ Ş Ţ à cédille
//        (U+015F U+0163 U+015E U+0162), reste des vieux claviers et des
//        traductions automatiques. Aucune langue servie n'en a l'usage (le turc
//        n'est pas une locale) : la règle vaut pour TOUS les textes, dès maintenant.
//   (D3) tutoiement sans exception (DOC-ADDR-1) : jamais « dumneavoastră » ni
//        l'abréviation « dvs. ». ANGLE MORT déclaré : le vouvoiement par la 2e
//        personne du pluriel (« introduceți ») a la même forme que l'adresse à
//        un collectif ; il se relit, il ne se détecte pas.
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { resolve, join, relative } from 'node:path';
import { LOCALE_CODES } from '../i18n/locales.js';

const RACINE = resolve(__dirname, '../..');
const CEDILLE = /[ŞşŢţ]/u;
const VOUVOIEMENT_RO = /(?<![\p{L}])(dumneavoastr[ăa]|dvs\.)/iu;

/** Fautes d'écriture roumaine d'un texte : cédilles, vouvoiement explicite. */
export function fautesRoumain(texte) {
  const f = [];
  const c = texte.match(CEDILLE);
  if (c) f.push(`cédille « ${c[0]} » (U+${c[0].codePointAt(0).toString(16).toUpperCase().padStart(4, '0')})`);
  const v = texte.match(VOUVOIEMENT_RO);
  if (v) f.push(`vouvoiement « ${v[1]} »`);
  return f;
}

function fichiers(dir, ext) {
  const out = [];
  for (const n of readdirSync(join(RACINE, dir))) {
    const rel = `${dir}/${n}`;
    if (n === 'node_modules') continue;
    if (statSync(join(RACINE, rel)).isDirectory()) out.push(...fichiers(rel, ext));
    else if (ext.test(n)) out.push(rel);
  }
  return out;
}

// Tous les textes que lit une personne : locales de l'app, Edge Functions
// (courriels, messages), install.sh, manuels du dépôt.
const TEXTES = [
  ...fichiers('src/i18n/locales', /\.json$/),
  ...fichiers('supabase/functions', /\.ts$/),
  'install.sh',
  ...readdirSync(join(RACINE, 'docs')).filter((n) => /^manual.*\.md$/.test(n)).map((n) => `docs/${n}`),
];

describe('écriture roumaine (D3, D4)', () => {
  it('témoin : la règle voit cédille et vouvoiement, et laisse passer le roumain juste', () => {
    expect(fautesRoumain('Aşteaptă confirmarea')).toHaveLength(1);
    expect(fautesRoumain('Introduceţi parola dumneavoastră')).toHaveLength(2);
    expect(fautesRoumain('Verificați datele dvs. înainte')).toHaveLength(1);
    expect(fautesRoumain('Așteaptă confirmarea ; introdu parola ta, ți-o trimitem.')).toEqual([]);
  });

  it('aucun texte du dépôt n’a de ş ţ à cédille ni de « dumneavoastră »', () => {
    const fautes = [];
    for (const f of TEXTES) {
      if (!existsSync(join(RACINE, f))) continue;
      readFileSync(join(RACINE, f), 'utf8').split('\n').forEach((ligne, i) => {
        for (const x of fautesRoumain(ligne)) fautes.push(`${f}:${i + 1} ${x}`);
      });
    }
    expect(fautes, 'Écris ș ț (virgule souscrite, U+0219 U+021B) et tutoie (DOC-I18N-5)').toEqual([]);
  });

  it('le témoin a de quoi lire : locales, fonctions, install.sh et manuels sont bien parcourus', () => {
    const rel = TEXTES.map((f) => relative(RACINE, join(RACINE, f)).replace(/\\/g, '/'));
    expect(rel.filter((f) => f.startsWith('src/i18n/locales/'))).toHaveLength(LOCALE_CODES.length);
    expect(rel.some((f) => f.endsWith('_shared/i18n/mail-strings.ts'))).toBe(true);
    expect(rel).toContain('install.sh');
    expect(rel.some((f) => /^docs\/manual.*\.md$/.test(f))).toBe(true);
  });
});
